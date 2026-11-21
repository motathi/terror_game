# Escolha-me

Jogo de terror de escolhas em primeira pessoa, no formato dos vídeos "escolha-me / pick your partner" do TikTok e Instagram: você vê pelos olhos do personagem, duas pessoas (ou coisas) imploram para você escolher uma delas, o tempo está acabando, e cada decisão leva a um dos vários finais. Visual low poly estilo PS1, vozes geradas com ElevenLabs.

**Campanhas** (menu em carrossel, definidas em `game/story/campanhas.json`):
- **Zumbi — Capítulo 1: Surto** (jogável): escritório, notícias de ataques, sua família em casa. 12 finais. Nos ataques você rola o dado (um d20: tire o número da tela ou mais): fugir do Rastejante, segurar uma porta, cortar o braço mordido e sobreviver ao corte. Sustos (jumpscares) nos momentos-chave.
- **Alien — Capítulo 1: Visitantes** (jogável): sítio do avô no interior, luzes sobre o milharal, quem volta não é igual. 11 finais. Momento-chave: duas Lias idênticas implorando "a outra é a cópia" (dá para rolar o dado e flagrar a cópia). Dados para se esconder no milho, escapar da luz, acertar o tiro e segurar a janela contra o Cinzento; quem for marcado decide se arranca o grão da nuca com uma faca.
- **Skinwalker — Capítulo 1: Caramelo** (jogável): o cachorro da família some por três dias e volta diferente. Ele não late, não manca e imita vozes. 11 finais. Momentos-chave: duas mães (uma do lado de fora da porta) e dois Caramelos implorando para entrar. Dá para ir ao terreno baldio soltar o Caramelo de verdade da armadilha enquanto a coisa de quatro caça no mato; dados para não olhar nos olhos dela, fechar a cortina, passar por ela no corredor e lutar ao lado do Caramelo; quem é arranhado decide se queima a ferida com o ferro antes que o pelo tome conta.
- **Homem do Saco — Capítulo 1: Véspera de São João** (jogável): a fogueira está apagando e você precisa levar seu irmão Davi para casa. Atalho pela linha do trem ou rua iluminada; voz da mãe na porta; dois sacos chamando seu nome no barraco do velho. 12 finais. Dados para pular do trem puxando o Davi, ficar quieto no mato com o tênis piscando, correr pela rua, agarrar o saco, espiar pela fechadura e escutar a respiração dos sacos; quem falha ao agarrar o saco fica preso pelo gancho na mão e decide se arranca.
- **Em breve:** Casa Abandonada, Fazenda.

**Capítulo 1: Surto.** Sexta-feira, 17:48. Você está no escritório quando o jornal começa a falar de pessoas mordendo pessoas. Sua esposa Marina e sua filha Bia estão em casa.
29 cenas · 89 falas · 867 caminhos · **10 finais**.

| | |
|---|---|
| Engine | Godot 4.7, GDScript, renderer Compatibility |
| Plataformas | Navegador (mobile), Google Play, App Store. Tela vertical |
| Idioma | Português (BR) |
| Áudio | ElevenLabs: vozes (TTS v4), efeitos e ambientes (Sound Effects v3) |
| Arte | Pacotes PSX gratuitos do itch.io ([CREDITS.md](CREDITS.md)) |

## Como rodar

```bash
git clone <repo> && cd terror_game
python3 tools/fetch_assets.py        # baixa os pacotes que não podem ficar no repo público
```
Depois, no Godot 4.7: **Importar** e selecione `game/project.godot`. Aperte **F5** para jogar.
Para ajustar enquadramento e luz dos cenários, abra `scenes/location_preview.tscn` e aperte **F6**.

> Sem o `fetch_assets.py` o jogo ainda roda, mas com bonecos provisórios no lugar dos personagens e da casa.

## Gerar o áudio (ElevenLabs)

```bash
export ELEVENLABS_API_KEY=...                       # ou crie .env na raiz (já está no .gitignore)
python3 tools/elevenlabs_gen.py design marina       # gera 3 vozes de teste em tools/.elevenlabs_cache/previews
python3 tools/elevenlabs_gen.py save marina 1       # escolhe a prévia 1 como voz da Marina
# ...repita para rafael, jorge, patricia, bia, tv
python3 tools/elevenlabs_gen.py all --dry-run       # mostra o que vai gerar e quantos caracteres
python3 tools/elevenlabs_gen.py all                 # gera efeitos, ambientes e todas as falas
```
Só falas alteradas são regeradas (cache por hash). Precisa de `ffmpeg`, que aplica o efeito da cena direto no arquivo de voz (telefone, TV, voz abafada atrás da porta) e normaliza o volume.

**Trilha sonora** (`python3 tools/elevenlabs_gen.py music`): 11 faixas instrumentais do Eleven Music (`music_v2_5`).
- **Músicas de cena:** tema do menu, inquietação, tensão, espera, suspense, perseguição, estrada e a canção de ninar da casa. Cada cenário tem uma faixa padrão, e a cena pode trocar com `"music"` no JSON.
- **Finais:** três faixas, para morte, sobrevivência e agridoce/secreto.
- **No jogo:** a música abaixa enquanto alguém fala. Durante as escolhas entra uma camada de tique-taque com coração, e cada cenário dispara sons soltos de fundo (gritos distantes, sirenes, vidro). O jogo funciona sem áudio: ele usa os efeitos do pacote CC-BY enquanto o ElevenLabs não foi rodado.

## Escrever história

A história fica em JSON (`game/story/cap1_surto.json`). O formato está em [docs/FORMATO_HISTORIA.md](docs/FORMATO_HISTORIA.md). Sempre valide depois de editar:

```bash
python3 tools/story_check.py game/story/cap1_surto.json          # erros + finais alcançáveis
python3 tools/story_check.py game/story/cap1_surto.json --paths  # todos os caminhos
```

## Estrutura

```
game/                      projeto Godot
  story/                   histórias em JSON (dados, sem código)
  scripts/story/           StoryRunner: variáveis, condições, próximos nós
  scripts/stage/           cenários 3D, personagens, câmera POV, materiais PSX
  scripts/ui/              legenda, escolhas com tempo, finais, menu, galeria
  autoload/                GameState (save/finais) e Audio (vozes/efeitos/ambiente)
  shaders/                 psx_lit (tremido + textura afim) e psx_post (dither + granulado)
  audio/vo|sfx|amb/        saída do ElevenLabs
  assets/models/           modelos feitos no projeto pelo Blender (d20.glb, rastejante.glb, cinzento.glb, coisa_quatro.glb, homem_saco.glb)
  assets/third_party/      pacotes PSX (ver assets_manifest.json)
tools/
  fetch_assets.py          baixa os pacotes do itch.io listados no manifesto
  itch_fetch.py            baixador de assets gratuitos do itch.io
  elevenlabs_gen.py        pipeline de vozes e efeitos
  story_check.py           validador e simulador de caminhos
  blender/make_d20.py      modela o d20 no Blender (pip install bpy) e exporta d20.glb + faces
  blender/make_rastejante.py  modela, texturiza, arma e anima o Rastejante (zumbi sem pernas)
  blender/make_cinzento.py    modela, texturiza, arma e anima o Cinzento (alienígena)
  blender/make_coisa_quatro.py modela, texturiza, arma e anima a coisa de quatro (skinwalker)
  blender/make_homem_saco.py  modela, texturiza, arma e anima o Homem do Saco (versão de perto)
docs/ARQUITETURA.md        por que Godot e como as peças se encaixam
```
