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
| `magro` | afina o corpo (escala nos lados, ex.: 0.85) |
| `anexos` | peças presas em ossos: `{"osso": "Head", "forma": "cilindro"/"caixa"/"esfera", "tamanho": [..], "pos": [..], "rot": [..], "cor": "#hex", "emissao": 0, "piscar": 0.0, "balanca": true}` (chapéu, saco nas costas, luzinha do tênis) |
| `luzinha` | com `"offscreen": "saco"` no elenco: o saco pisca vermelho/azul por dentro |

Modelos: além dos humanos, `dog` (PSX Dog, animações `Dog1_Idle`, `Dog1_Idle_Tail_Wag`, `Dog1_Walk`, `Dog1_Run`, `Dog1_Bark`, `Dog1_Sit_Start`, `Dog1_Sit_Loop`, `Dog1_Lay_Start`, `Dog1_Lay_Loop`).

Opcional no topo do arquivo: `"musica_cenarios": {"casa": "skin_casa"}` e `"sons_cenarios": {"casa": ["arranhao"]}` trocam a música padrão e os sons soltos de um cenário só nesta campanha.

## Nó
```jsonc
"patricia": {
  "location": "escada",                  // escritorio | escritorio_escuro | escada | garagem | carro | rua | casa | campo | fazenda_casa | celeiro | elevador | quintal | avenida | festa | linha_trem | ruazinha | barraco | hospital | terreno | condominio | mercadinho | estrada
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
    // "left":  { "char": "saco_davi", "offscreen": "saco" } -> um saco de estopa no chão
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

## Direção de cena (a cena tem que acontecer de verdade)

O que a fala descreve precisa acontecer na tela: quem chega entra andando, quem desce a escada desce, quem se vira se vira. Use `"acoes"` numa **fala** (o tempo `t` conta do início da fala) ou num **nó** (conta da entrada na cena; ações com `t: 0` rodam antes da cena aparecer, bom para posicionar alguém).

```jsonc
"acoes": [
  { "t": 0,   "acao": "entrar", "who": "jorge", "de": [-4, 0, -0.5], "anim": "Run", "fim": "Idle", "dur": 1.6 },
  { "t": 0.6, "acao": "camera_andar", "pos": [0, 0.7, -2.4], "olhar": [0, -0.4, -6.5], "dur": 3 },
  { "t": 2.0, "acao": "camera_olhar", "who": "rafael", "dur": 0.8 }
]
```
Qualquer ação aceita `"if"` (mesma sintaxe das falas): `{ "t": 0, "acao": "esconder", "who": "marina", "if": "not c2_marina" }` tira do elenco quem não está naquele caminho.

`"espera": 1.2` numa fala atrasa a legenda (a ação começa antes). `"aguardar": 1.6` num nó segura a primeira fala (ex.: até quem está chegando parar de andar).

Offsets (`de`, `para`, `por`) são relativos à câmera: x = direita, y = cima, z = **para trás** (positivo vem de trás de você, negativo vai para a frente).

| ação | o que faz |
|---|---|
| `entrar` | personagem começa deslocado (`de`) e anda até o lugar dele (`anim`, depois `fim`), virando para você |
| `sair` | anda até `para` e some (`esconder: false` mantém) |
| `andar` | anda `por` a partir de onde está; `olhar_camera: false` deixa de costas; `fim` = animação de repouso |
| `mover` | vai até uma posição absoluta (`para`) |
| `olhar_camera` / `olhar_para` (`alvo`) | vira para você / para outro personagem |
| `anim` | troca a animação; `fixo: true` vira a animação de repouso |
| `esconder` / `mostrar` | some / aparece |
| `tremer` | personagem treme (`dur`) |
| `camera_andar` | câmera anda com balanço de passos: `pos` + `olhar` absolutos, ou `por` relativo |
| `camera_rel` | move a câmera relativa a ela (`por`, `olhar` opcional, `andar: true` para passos) |
| `camera_olhar` | vira a câmera para um personagem (`who`) ou ponto (`olhar`) |
| `camera` / `camera_voltar` | câmera para posição absoluta / volta à câmera do nó |
| `maos` | mão estica (`grab.L` / `grab.R`); `maos_cor` tinge as mãos (ex.: sangue); `maos_ocultar` (`lado`: `esquerda`/`direita`, `ocultar`) some com uma mão (braço cortado) |
| `texto3d` | texto no mundo (relógio, placa, número do andar); mesmo `id` substitui, texto vazio apaga. Use tamanho ≥ 34: a cena 3D roda em baixa resolução |
| `celular` | mostra a tela do celular na interface, nítida (`texto`; a primeira linha vira o cabeçalho quando há mais de uma; texto vazio guarda o celular). Use para mensagens: em `texto3d` elas viram borrão |
| `luz_no` | muda a energia de uma luz do cenário pelo nome (`nome`, `energia`, `dur`; ex.: postes apagando) |
| `susto` | **jumpscare**: com `who` alguém salta na frente da câmera e o rosto enche a tela (barulho alto, tranco, flash vermelho, mãos recuando, corte seco). `who` pode ser um personagem da história ou um nome novo com `modelo`/`tint`. Opções: `anim`, `de`/`ate` (distância 2.2 → 0.5 m), `lado`, `de_cima`, `rapido`, `segura`, `depois` (`sumir`/`recuar`), `inclinar` (graus para trás, 20; mais quando a câmera está baixa ou olhando para baixo), `som` (`susto_grito`), `volume`. Sem `who` é um susto falso: só o som e o tranco (`flash: true` para o vermelho) |
| `silencio` | a música some por `dur` segundos (o silêncio antes do susto) |
| `sfx`, `luz`, `luz_ponto`, `no`, `fx` | som, luz do ambiente, luz pontual, mover nó do cenário, efeitos (`flash`, `tremor`, `piscar`, `vermelho`, `apagar`, `acender`, `chuvisco`) |

As mesmas ações valem nas cinemáticas dos finais (`"passos"`).

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

## Mão amputada (persistente)
`"maos_ocultas": { "esquerda": "sem_braco" }` no topo da história: em toda cena, a mão daquele lado da tela some enquanto a condição valer.

## Teste de dado (estilo Baldur's Gate)
Uma opção pode virar um teste de dado. Para o jogador é simples: a opção aparece em dourado como `[DADO]  texto` e a tela pede "Tire N ou mais" no d20. Esse N é calculado da CD menos o atributo e os modificadores da cena (nada disso aparece na tela; serve para ajustar a dificuldade). N fica entre 2 e 20.
- O 20 natural sempre passa e o 1 natural sempre falha.
- Se der errado, o jogador pode rolar uma segunda vez (botões ROLAR DE NOVO / ACEITAR); a segunda rolagem vale.
- Com vantagem rolam dois dados e vale o maior; com desvantagem, vale o menor.

```jsonc
"atributos": {                                       // no topo da história: base de cada atributo
  "agilidade": { "nome": "Agilidade", "valor": 1 },
  "percepcao": { "nome": "Percepção", "valor": 2 }
},
...
{ "text": "Correr até o carro agora",
  "set": {},                                          // aplicado antes do resultado, nos dois casos
  "teste": {
    "atributo": "agilidade", "cd": 12,
    "mods": [ { "if": "patricia", "valor": -3, "texto": "A Patrícia está ferida" },
              { "valor": 1, "texto": "Carros por toda parte" } ],   // sem "if" = sempre
    "vantagem": "viu_mordida_rafael",                  // expressão (opcional); também "desvantagem"
    "sucesso": { "set": {}, "next": "carro_entrar" },  // next ou ending
    "falha":   { "next": "garagem_correr" },
    "falha_critica":   { "next": "pior_ainda" },        // opcional: 1 natural (sem ele vale "falha")
    "sucesso_critico": { "next": "melhor_ainda" }       // opcional: 20 natural (sem ele vale "sucesso")
  } }
```
O `story_check.py` segue todos os resultados de cada teste. Regra de design: a falha precisa levar a uma cena que mostre o preço na hora (não só mudar uma variável e seguir igual ao sucesso).

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
