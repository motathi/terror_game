# Formato das histórias (JSON)

Uma campanha = um arquivo em `game/story/`. Valide sempre com `python3 tools/story_check.py <arquivo>`.

```jsonc
{
  "id": "cap1_surto",
  "title": "Capítulo 1 — Surto",
  "start": "inicio",                       // primeiro nó
  "vars": { "ligou": false, "culpa": 0 },  // TODAS as variáveis, com valor inicial
  "characters": {
    "rafael": { "name": "Rafael", "model": "office_worker", "tint": "#3a4a7a" },
    "bia":    { "name": "Bia", "bus": "Muffled" },   // sem model = só voz
    "sistema":{ "name": "", "voiced": false }         // narração em texto
  },
  "nodes": { ... },
  "endings": { ... }
}
```

## Personagem
| campo | o que faz |
|---|---|
| `name` | nome no balão de legenda e flutuando acima da cabeça |
| `model` | chave em `AssetLib.MODELS` (`office_worker`, `nurse`, `zombie_student`, `zombie_male`, `zombie_female`, `zombie_big`, `zombie_retro`) |
| `tint` | multiplica a cor do modelo (reaproveitar o mesmo modelo como outra pessoa) |
| `bus` | efeito na voz: `Voice` (padrão), `Phone`, `Radio`, `Muffled` |
| `voiced` | `false` = nunca procura arquivo de voz |
| `fx` | efeito extra na voz gerada: `errado` (imitação quase perfeita), `errado_abafado`, `monstro` |
| `altura` | altura em metros (o modelo é escalado pelos ossos; ex.: criança 1.3) |
| `pelagem` | recolore a textura: `caramelo`, `morta`, `cinza` ou `["#escuro", "#claro"]` |
| `em_pe` | `true` = bicho de quatro patas de pé nas patas de trás |
| `olhos` | cor dos olhos brilhando (modelos com olhos mapeados, ex.: `dog`) |

Modelos: além dos humanos, `dog` (PSX Dog, animações `Dog1_Idle`, `Dog1_Idle_Tail_Wag`, `Dog1_Walk`, `Dog1_Run`, `Dog1_Bark`, `Dog1_Sit_Start`, `Dog1_Sit_Loop`, `Dog1_Lay_Start`, `Dog1_Lay_Loop`).

Opcional no topo do arquivo: `"musica_cenarios": {"casa": "skin_casa"}` e `"sons_cenarios": {"casa": ["arranhao"]}` trocam a música padrão e os sons soltos de um cenário só nesta campanha.

## Nó
```jsonc
"patricia": {
  "location": "escada",                  // escritorio | escritorio_escuro | escada | garagem | carro | rua | casa | campo | fazenda_casa | celeiro | elevador | quintal
  "title_card": "21:30",                 // opcional: cartela no topo da tela
  "camera": { "pos": [0,1.3,0.4], "olhar": [0,0.3,-2], "slot_dist": 2.0 },  // opcional: câmera só deste nó (bom p/ cachorros)
  "ambience": "tensao",                  // opcional: troca o som ambiente
  "set": { "x": true },                  // opcional: aplicado ao entrar no nó
  "cast": {                              // quem está em cena
    "left":  { "char": "patricia", "anim": "Sit" },
    "right": { "char": "rafael", "anim": "Idle" },
    "center":{ "char": "zumbi", "anim": "ZombieIdle", "facing": "away" },
    "phone": { "char": "marina" }        // fala pelo celular (voz com filtro)
    // "right": { "char": "bia", "offscreen": "porta" }  -> só uma porta com o nome
  },
  "lines": [
    { "id": "patricia_02",               // ÚNICO: vira o nome do arquivo de voz
      "who": "patricia",
      "text": "Me leva com vocês. Por favor.",
      "tags": "[crying, relieved]",      // só para o ElevenLabs, não aparece na tela
      "anim": "Talk",                    // opcional
      "sfx": "stinger_hit",              // opcional: chave de efeito
      "fx": "flicker",                   // opcional: flicker | lights_off
      "phone": true,                     // opcional: esta fala é pelo celular
      "if": "not ligou" }                // opcional: só aparece se a condição for verdadeira
  ],
  // EXATAMENTE UMA saída:
  "next": "garagem"
  // "ending": "portas_abertas"
  // "branch": [ { "if": "patricia", "next": "x" }, { "next": "y" } ]   (último sem if = senão)
  // "choice": { ... }
}
```

## Escolha
```jsonc
"choice": {
  "prompt": "Quem você escuta?",
  "timer": 7,                                        // segundos; 0/omitido = sem tempo
  "plead": { "patricia": "Me leva", "rafael": "Deixa ela" },  // palavras tremendo sobre cada um
  "options": [
    { "text": "Levar a Patrícia", "who": "patricia",  // "who": tocar no personagem escolhe esta opção
      "set": { "patricia": true }, "next": "garagem" },
    { "text": "Deixar", "who": "rafael", "set": { "culpa": "=culpa + 1" }, "ending": "x",
      "if": "com_rafael" }                            // opção só aparece se...
  ],
  "timeout": { "set": {}, "next": "patricia_deixada" } // obrigatório com timer; soma 1 em `hesitou`
}
```

## Condições e `set`
- Condições usam a sintaxe de expressão do Godot: `and`, `or`, `not`, `==`, `>=`, `+`...
- Em `set`, um texto que começa com `=` é uma expressão: `"culpa": "=culpa + 1"`, `"marina_infectada": "=marina_saiu"`.
- `hesitou` é incrementada automaticamente quando o tempo de uma escolha acaba.

## Final
```jsonc
"familia": {
  "title": "Família",
  "kind": "sobreviveu",          // morte | sobreviveu | agridoce | secreto
  "text": "Vocês barricaram a casa...",
  "extra": [ { "if": "culpa >= 1", "text": "Mas toda noite..." } ]
}
```
