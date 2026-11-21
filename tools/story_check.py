#!/usr/bin/env python3
"""Valida um arquivo de história e enumera TODOS os caminhos possíveis.

  python3 tools/story_check.py game/story/cap1_surto.json
  python3 tools/story_check.py game/story/cap1_surto.json --paths   # lista cada caminho

Verifica: nós/finais inexistentes, ids de fala duplicados, personagens não
declarados, variáveis não declaradas, nós inalcançáveis e finais que nenhum
caminho alcança. Roda as mesmas regras do StoryRunner do Godot (condições,
"set" com "=expressão", timeout incrementa `hesitou`).
"""
import json
import re
import sys
from collections import Counter

KEYWORDS = {"and", "or", "not", "true", "false"}


def expr_vars(expr):
    return {t for t in re.findall(r"[A-Za-z_][A-Za-z0-9_]*", expr) if t not in KEYWORDS}


def evaluate(expr, state):
    py = expr.replace("true", "True").replace("false", "False")
    return eval(py, {"__builtins__": {}}, dict(state))  # noqa: S307 - texto controlado pelo projeto


def apply_set(sets, state):
    for k, v in (sets or {}).items():
        state[k] = evaluate(v[1:], state) if isinstance(v, str) and v.startswith("=") else v


def check(story):
    errors, warnings = [], []
    nodes, endings, chars, vars_ = story["nodes"], story["endings"], story["characters"], story["vars"]

    def ref(target, where):
        if "next" in target and target["next"] not in nodes:
            errors.append(f"{where}: nó inexistente '{target['next']}'")
        if "ending" in target and target["ending"] not in endings:
            errors.append(f"{where}: final inexistente '{target['ending']}'")
        if "next" not in target and "ending" not in target:
            errors.append(f"{where}: sem 'next' nem 'ending'")

    def check_expr(expr, where):
        for v in expr_vars(expr):
            if v not in vars_:
                errors.append(f"{where}: variável não declarada '{v}' em '{expr}'")

    def check_set(sets, where):
        for k, v in (sets or {}).items():
            if k not in vars_:
                errors.append(f"{where}: set em variável não declarada '{k}'")
            if isinstance(v, str) and v.startswith("="):
                check_expr(v[1:], where)

    ids = Counter()
    if story["start"] not in nodes:
        errors.append(f"start '{story['start']}' não existe")
    for nid, n in nodes.items():
        check_set(n.get("set"), nid)
        for slot, c in (n.get("cast") or {}).items():
            if c["char"] not in chars:
                errors.append(f"{nid}: cast com personagem desconhecido '{c['char']}'")
        for ln in n.get("lines", []):
            ids[ln["id"]] += 1
            if ln["who"] not in chars:
                errors.append(f"{nid}/{ln['id']}: personagem desconhecido '{ln['who']}'")
            if "if" in ln:
                check_expr(ln["if"], f"{nid}/{ln['id']}")
        exits = sum(k in n for k in ("next", "choice", "branch", "ending"))
        if exits != 1:
            errors.append(f"{nid}: precisa de exatamente uma saída (next|choice|branch|ending), tem {exits}")
        if "next" in n or "ending" in n:
            ref(n, nid)
        for i, b in enumerate(n.get("branch", [])):
            ref(b, f"{nid}/branch[{i}]")
            if "if" in b:
                check_expr(b["if"], f"{nid}/branch[{i}]")
        if "branch" in n and "if" in n["branch"][-1]:
            warnings.append(f"{nid}: último branch tem 'if' (sem fallback)")
        ch = n.get("choice")
        if ch:
            for i, o in enumerate(ch["options"]):
                where = f"{nid}/opção[{i}]"
                if "teste" in o:  # teste de dado: os dois resultados precisam levar a algum lugar
                    t = o["teste"]
                    if t.get("atributo") not in story.get("atributos", {}):
                        errors.append(f"{where}: atributo desconhecido '{t.get('atributo')}'")
                    for res in ("sucesso", "falha", "sucesso_critico", "falha_critica"):
                        if res not in t:
                            if res in ("sucesso", "falha"):
                                errors.append(f"{where}: teste sem '{res}'")
                            continue
                        ref(t[res], f"{where}/{res}")
                        check_set(t[res].get("set"), f"{where}/{res}")
                    for m in t.get("mods", []):
                        if "if" in m:
                            check_expr(m["if"], f"{where}/mod")
                    for k in ("vantagem", "desvantagem"):
                        if k in t:
                            check_expr(t[k], f"{where}/{k}")
                else:
                    ref(o, where)
                check_set(o.get("set"), where)
                if "if" in o:
                    check_expr(o["if"], where)
            if ch.get("timer"):
                if "timeout" not in ch:
                    errors.append(f"{nid}: choice com timer precisa de 'timeout'")
                else:
                    ref(ch["timeout"], f"{nid}/timeout")
                    check_set(ch["timeout"].get("set"), f"{nid}/timeout")
    for k, c in ids.items():
        if c > 1:
            errors.append(f"id de fala duplicado: {k}")
    for side, cond in story.get("maos_ocultas", {}).items():
        if side not in ("esquerda", "direita"):
            errors.append(f"maos_ocultas: lado desconhecido '{side}'")
        check_expr(cond, f"maos_ocultas/{side}")
    for eid, e in endings.items():
        for x in e.get("extra", []):
            check_expr(x["if"], f"final {eid}")
    return errors, warnings


def walk(story):
    """DFS sobre todas as escolhas (inclusive deixar o tempo acabar)."""
    nodes = story["nodes"]
    results = []

    def go(nid, state, path, depth=0):
        if depth > 200:
            raise RuntimeError("loop infinito? " + " > ".join(path[-10:]))
        n = nodes[nid]
        state = dict(state)
        apply_set(n.get("set"), state)
        path = path + [nid]
        if "ending" in n:
            results.append((n["ending"], path, state))
        elif "next" in n:
            go(n["next"], state, path, depth + 1)
        elif "branch" in n:
            for b in n["branch"]:
                if "if" not in b or evaluate(b["if"], state):
                    if "ending" in b:
                        results.append((b["ending"], path, state))
                    else:
                        go(b["next"], state, path, depth + 1)
                    break
        else:
            ch = n["choice"]
            outs = []
            for o in ch["options"]:
                if "if" in o and not evaluate(o["if"], state):
                    continue
                if "teste" in o:  # os dois resultados do dado
                    for res in ("sucesso", "falha", "sucesso_critico", "falha_critica"):
                        if res not in o["teste"]:
                            continue
                        r = o["teste"][res]
                        merged = dict(r, set={**(o.get("set") or {}), **(r.get("set") or {})})
                        outs.append((merged, f"{o['text']} 🎲{res}"))
                else:
                    outs.append((o, o["text"]))
            if ch.get("timer"):
                outs.append((dict(ch["timeout"], _timeout=True), "⏱ tempo esgotado"))
            for o, label in outs:
                s = dict(state)
                if o.get("_timeout"):
                    s["hesitou"] = s.get("hesitou", 0) + 1
                apply_set(o.get("set"), s)
                p = path[:-1] + [f"{nid}[{label}]"]
                if "ending" in o:
                    results.append((o["ending"], p, s))
                else:
                    go(o["next"], s, p, depth + 1)

    go(story["start"], dict(story["vars"]), [])
    return results


def _outs(story, nid, state):
    """Saídas de um nó: lista de (alvo, estado) onde alvo = ("next", id) ou ("ending", id)."""
    n = story["nodes"][nid]
    state = dict(state)
    apply_set(n.get("set"), state)
    if "ending" in n:
        return [(("ending", n["ending"]), state)]
    if "next" in n:
        return [(("next", n["next"]), state)]
    if "branch" in n:
        for b in n["branch"]:
            if "if" not in b or evaluate(b["if"], state):
                return [(("ending", b["ending"]) if "ending" in b else ("next", b["next"]), state)]
        return []
    ch = n["choice"]
    opts = []
    for o in ch["options"]:
        if "if" in o and not evaluate(o["if"], state):
            continue
        if "teste" in o:
            for res in ("sucesso", "falha", "sucesso_critico", "falha_critica"):
                if res in o["teste"]:
                    r = o["teste"][res]
                    opts.append(dict(r, set={**(o.get("set") or {}), **(r.get("set") or {})}))
        else:
            opts.append(o)
    if ch.get("timer"):
        opts.append(dict(ch["timeout"], _timeout=True))
    out = []
    for o in opts:
        s = dict(state)
        if o.get("_timeout"):
            s["hesitou"] = s.get("hesitou", 0) + 1
        apply_set(o.get("set"), s)
        out.append((("ending", o["ending"]) if "ending" in o else ("next", o["next"]), s))
    return out


def _live_vars(story):
    """Para cada nó: variáveis que ainda podem decidir o caminho dali para a frente
    (condições de branch/opção e expressões de "set" do nó e dos sucessores)."""
    nodes = story["nodes"]
    reads, succ = {}, {}
    for nid, n in nodes.items():
        r, nx = set(), set()

        def add_set(sets):
            for v in (sets or {}).values():
                if isinstance(v, str) and v.startswith("="):
                    r.update(expr_vars(v[1:]))

        def target(t):
            add_set(t.get("set"))
            if "next" in t:
                nx.add(t["next"])

        add_set(n.get("set"))
        if "next" in n:
            nx.add(n["next"])
        for b in n.get("branch", []):
            if "if" in b:
                r.update(expr_vars(b["if"]))
            target(b)
        ch = n.get("choice")
        if ch:
            for o in ch["options"]:
                if "if" in o:
                    r.update(expr_vars(o["if"]))
                add_set(o.get("set"))
                if "teste" in o:
                    for res in ("sucesso", "falha", "sucesso_critico", "falha_critica"):
                        if res in o["teste"]:
                            target(o["teste"][res])
                else:
                    target(o)
            if "timeout" in ch:
                target(ch["timeout"])
                r.add("hesitou")
        reads[nid], succ[nid] = r, nx
    live = {k: set(v) for k, v in reads.items()}
    changed = True
    while changed:
        changed = False
        for nid in nodes:
            before = len(live[nid])
            for m in succ[nid]:
                live[nid] |= live.get(m, set())
            changed |= len(live[nid]) != before
    return live


def count_paths(story):
    """Mesma regra do walk(), mas memorizando (nó, estado): conta caminhos sem enumerá-los."""
    sys.setrecursionlimit(10000)
    memo = {}
    visited = set()
    live = _live_vars(story)

    def go(nid, state, depth=0):
        if depth > 400:
            raise RuntimeError("loop infinito? em " + nid)
        # só as variáveis que ainda podem mudar o caminho daqui para a frente entram na chave
        key = (nid, tuple(sorted((k, v) for k, v in state.items() if k in live[nid])))
        if key in memo:
            return memo[key]
        visited.add(nid)
        total = Counter()
        for (kind, target), s in _outs(story, nid, state):
            if kind == "ending":
                total[target] += 1
            else:
                total.update(go(target, s, depth + 1))
        memo[key] = total
        return total

    return go(story["start"], dict(story["vars"])), visited


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    story = json.load(open(sys.argv[1], encoding="utf-8"))
    errors, warnings = check(story)
    for w in warnings:
        print("AVISO:", w)
    for e in errors:
        print("ERRO: ", e)
    if errors:
        sys.exit(1)

    if "--paths" in sys.argv:
        results = walk(story)
        visited = {p.split("[")[0] for _, path, _ in results for p in path}
        per_end = Counter(e for e, _, _ in results)
    else:
        per_end, visited = count_paths(story)
    for nid in story["nodes"]:
        if nid not in visited:
            print("AVISO: nó inalcançável:", nid)
    lines = sum(len(n.get("lines", [])) for n in story["nodes"].values())
    print(f"\n{story['title']}: {len(story['nodes'])} nós, {lines} falas, {sum(per_end.values())} caminhos possíveis\n")
    for eid, e in story["endings"].items():
        c = per_end.get(eid, 0)
        flag = "" if c else "   <-- INALCANÇÁVEL"
        print(f"  {c:4d} caminhos  ->  [{e['kind']}] {e['title']}{flag}")
    if "--paths" in sys.argv:
        print()
        for eid, path, _ in results:
            print(f"{story['endings'][eid]['title']:22s} | " + " > ".join(path))
    if any(per_end.get(e, 0) == 0 for e in story["endings"]):
        sys.exit(2)


if __name__ == "__main__":
    main()
