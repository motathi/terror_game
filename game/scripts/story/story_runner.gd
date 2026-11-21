extends RefCounted
## Executa uma história em JSON (ver docs/FORMATO_HISTORIA.md).
##
## Não sabe nada de 3D nem de UI: só carrega o arquivo, guarda as variáveis,
## avalia condições e diz qual é o próximo nó. O GameScreen consome isso.
## As mesmas regras estão replicadas em tools/story_check.py — se mudar uma,
## mude a outra.

var story: Dictionary = {}
var vars: Dictionary = {}
var campaign_id: String = ""
var history: PackedStringArray = []


func load_file(path: String) -> bool:
	var text := ""
	if FileAccess.file_exists(path):
		text = FileAccess.get_file_as_string(path)
	if text.is_empty():
		# Em builds exportados o .json pode ter virado recurso JSON importado.
		var res = load(path)
		if res is JSON:
			story = res.data
		else:
			push_error("StoryRunner: não consegui abrir %s" % path)
			return false
	else:
		var parsed = JSON.parse_string(text)
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("StoryRunner: JSON inválido em %s" % path)
			return false
		story = parsed
	campaign_id = story.get("id", path.get_file().get_basename())
	reset()
	return true


func reset() -> void:
	vars = story.get("vars", {}).duplicate(true)
	history.clear()


func start_node() -> String:
	return story.get("start", "")


func character(id: String) -> Dictionary:
	return story.get("characters", {}).get(id, {})


func enter_node(id: String) -> Dictionary:
	var node: Dictionary = story.get("nodes", {}).get(id, {})
	if node.is_empty():
		push_error("StoryRunner: nó inexistente '%s'" % id)
		return {}
	history.append(id)
	apply_set(node.get("set", {}))
	return node


func visible_lines(node: Dictionary) -> Array:
	var out: Array = []
	for line in node.get("lines", []):
		if not line.has("if") or eval_condition(line["if"]):
			out.append(line)
	return out


func available_options(choice: Dictionary) -> Array:
	var out: Array = []
	for opt in choice.get("options", []):
		if not opt.has("if") or eval_condition(opt["if"]):
			out.append(opt)
	return out


## Saída de um nó sem escolha. Retorna {"next": id} ou {"ending": id}.
func resolve_exit(node: Dictionary) -> Dictionary:
	if node.has("branch"):
		for b in node["branch"]:
			if not b.has("if") or eval_condition(b["if"]):
				return _target(b)
		push_error("StoryRunner: nenhum branch válido")
		return {}
	return _target(node)


func choose(option: Dictionary) -> Dictionary:
	apply_set(option.get("set", {}))
	return _target(option)


## Teste de dado numa opção ("teste"): calcula o que entra na rolagem.
## Retorna {"nome", "cd", "mods": [{"texto", "valor"}], "vantagem", "desvantagem"}.
func test_info(t: Dictionary) -> Dictionary:
	var key: String = t.get("atributo", "")
	var a: Dictionary = story.get("atributos", {}).get(key, {})
	var nome: String = a.get("nome", key.capitalize())
	var mods: Array = []
	if not a.is_empty():
		mods.append({"texto": nome, "valor": int(a.get("valor", 0))})
	for m in t.get("mods", []):
		if not m.has("if") or eval_condition(m["if"]):
			mods.append({"texto": m.get("texto", ""), "valor": int(m.get("valor", 0))})
	var adv: bool = t.has("vantagem") and eval_condition(t["vantagem"])
	var dis: bool = t.has("desvantagem") and eval_condition(t["desvantagem"])
	return {"nome": nome, "cd": int(t.get("cd", 10)), "mods": mods, "vantagem": adv and not dis, "desvantagem": dis and not adv}


## Depois da rolagem: aplica o "set" da opção e o do resultado ("sucesso"/"falha").
## r: 2 = sucesso crítico, 1 = sucesso, 0 = falha, -1 = falha crítica (DiceRoll.run).
## "sucesso_critico" / "falha_critica" são opcionais; sem eles vale sucesso/falha.
func resolve_test(option: Dictionary, r: int) -> Dictionary:
	apply_set(option.get("set", {}))
	var t: Dictionary = option["teste"]
	var key := "sucesso" if r > 0 else "falha"
	if r == 2 and t.has("sucesso_critico"):
		key = "sucesso_critico"
	elif r == -1 and t.has("falha_critica"):
		key = "falha_critica"
	var out: Dictionary = t.get(key, {})
	apply_set(out.get("set", {}))
	return _target(out)


func timeout(choice: Dictionary) -> Dictionary:
	vars["hesitou"] = int(vars.get("hesitou", 0)) + 1
	var t: Dictionary = choice.get("timeout", {})
	apply_set(t.get("set", {}))
	return _target(t)


func ending(id: String) -> Dictionary:
	var e: Dictionary = story.get("endings", {}).get(id, {}).duplicate(true)
	var extras: PackedStringArray = []
	for x in e.get("extra", []):
		if eval_condition(x["if"]):
			extras.append(x["text"])
	e["id"] = id
	e["extra_text"] = "\n".join(extras)
	return e


func ending_ids() -> Array:
	return story.get("endings", {}).keys()


func apply_set(sets: Dictionary) -> void:
	for key in sets:
		var v = sets[key]
		if typeof(v) == TYPE_STRING and v.begins_with("="):
			vars[key] = evaluate(v.substr(1))
		else:
			vars[key] = v


func eval_condition(expr: String) -> bool:
	return bool(evaluate(expr))


func evaluate(expr: String) -> Variant:
	var e := Expression.new()
	var err := e.parse(expr, PackedStringArray(vars.keys()))
	if err != OK:
		push_error("StoryRunner: expressão inválida '%s': %s" % [expr, e.get_error_text()])
		return false
	var result = e.execute(vars.values(), null, false)
	if e.has_execute_failed():
		push_error("StoryRunner: falha ao avaliar '%s'" % expr)
		return false
	return result


func _target(d: Dictionary) -> Dictionary:
	if d.has("ending"):
		return {"ending": d["ending"]}
	if d.has("next"):
		return {"next": d["next"]}
	return {}
