# Arquitetura

## Por que Godot 4

| Critério | Godot 4 | Unity | Unreal | Web puro (Three.js) |
|---|---|---|---|---|
| Visual PS1 / low poly | Ótimo (shader próprio) | Ótimo | Pesado demais | Ótimo, tudo à mão |
| Navegador mobile (link no TikTok) | Bom (~30–40 MB, WebGL2) | Pesado | Não roda | O melhor |
| Play Store + App Store | Sim, mesmo projeto | Sim | Sim | Precisaria de um wrapper |
| Custo / licença | Grátis, MIT, sem royalties | Licença instável | 5% de royalties | Grátis |
| Tamanho de equipe | Leve, itera rápido | Médio | Pesado | Muito código de base |

O jogo precisa sair nas três plataformas a partir de um único projeto, com 3D simples. O Godot é o único da lista que atende isso sem custo e sem peso extra.

Decisões que decorrem disso:
- **GDScript, não C#.** A exportação web do Godot não suporta C#.
- **Renderer Compatibility (OpenGL ES 3 / WebGL2).** É o mesmo nas três plataformas e roda em celular fraco. O visual PS1 não precisa de mais que isso.
- **Tela vertical**, base 720×1280, que se estica para qualquer proporção. A cena 3D é renderizada a 1/4 da resolução (180×320) num `SubViewport` com filtro nearest.
- **Web single-thread** (`variant/thread_support=false`). Não exige cabeçalhos COOP/COEP, então funciona no itch.io e em qualquer hospedagem estática.

## Fluxo

```
game/story/*.json ──► StoryRunner ──► GameScreen ──► Stage (3D)      cenário, elenco, câmera, mãos
   (dados)            (lógica pura)   (orquestra)  ├► DialogueUI      legenda, escolha, timer, final
        │                                          └► Audio           voz / efeito / ambiente
        └──► tools/elevenlabs_gen.py ──► game/audio/vo/pt_BR/<id_da_fala>.mp3
        └──► tools/story_check.py   (valida e enumera todos os caminhos)
```

- **StoryRunner** (`scripts/story/story_runner.gd`) não conhece 3D nem UI. Guarda as variáveis, avalia condições com a classe `Expression` do Godot e devolve o próximo nó ou o final. O `story_check.py` replica as mesmas regras em Python: assim dá para testar os 867 caminhos sem abrir o jogo.
- **GameScreen** (`scripts/game_screen.gd`) roda um laço `await`. Para cada nó: monta a cena, toca as falas, mostra a escolha e segue o resultado.
- **Stage** (`scripts/stage/stage.gd`) monta o cenário (`locations.gd`), põe o elenco nos slots `left`/`right`/`center` virado para a câmera e controla as mãos em primeira pessoa (que esticam para o personagem escolhido), o piscar e o apagar das luzes, o tremor da câmera e o flash vermelho.
- **Actor** é o modelo + animação + nome flutuante + palavra de súplica tremendo ("Por favor"), como nos vídeos. `offscreen: "porta"` mostra só uma porta com luz por baixo (a Bia trancada no quarto).
- **AssetLib** carrega modelos com fallback e troca todos os materiais pelo shader PSX: vértices tremendo, textura afim e filtro nearest.
- **Áudio na web:** usa o modo **Sample** do Godot. O navegador toca os sons nativamente, então o áudio não trava quando o 3D pesa no celular. Por isso os buses ficam em `default_bus_layout.tres`: os criados por código não existem nesse modo. Os efeitos de bus (telefone, rádio, porta) só funcionam nos builds nativos; na web a voz sai limpa. No iOS, `navigator.audioSession.type = "playback"` (no `head_include` do preset Web) faz o som tocar mesmo com a chave de silencioso ligada.
- **Audio** procura `audio/vo|sfx|amb/<chave>`. Se não achar, usa um fallback do pacote CC-BY. Cria os buses em código: `Phone` (banda estreita, voz no celular), `Radio` (TV), `Muffled` (atrás da porta).
- **GameState** guarda os finais descobertos e as opções em `user://save.json`. No navegador isso vira IndexedDB.

## Interação (mobile primeiro)
- Toque em qualquer lugar: avança a fala (com auto-avanço quando a voz termina).
- Escolha: toque no botão **ou direto no personagem** (`Stage.actor_at_screen`).
- O timer acabou? Isso também é uma escolha: incrementa `hesitou`, e três hesitações levam ao final secreto "Congelado".
- Opção de acessibilidade: desligar o tempo de escolha no menu.

## Áudio com ElevenLabs
É gerado **antes**, nunca em tempo de execução. Gerar durante o jogo seria caro, teria latência e exporia a chave da API dentro do jogo.
- **Vozes:** Voice Design (`eleven_ttv_v3`) cria uma voz única por personagem a partir de uma descrição. Depois o TTS (`eleven_v4`, com fallback para `eleven_v3`) usa as tags de emoção do campo `tags` de cada fala (`[whispers]`, `[crying]`...).
- **Efeitos e ambientes:** Sound Effects (`eleven_text_to_sound_v3`). Os ambientes são gerados com `loop: true`.
- **Saída:** mp3 (o Godot importa direto, sem ffmpeg).
- **Antes de lançar:** confirme que o seu plano do ElevenLabs permite uso comercial.

## Assets de terceiros
`assets_manifest.json` lista cada pacote, a licença e se ele pode ir para o git.
- O repositório é **público**. Os pacotes que proíbem redistribuir os arquivos (personagens, casa, um zumbi) ficam no `.gitignore` e são baixados com `tools/fetch_assets.py`.
- Os pacotes CC0/CC-BY estão versionados.
- Todos permitem uso comercial dentro do jogo compilado.

## Limites conhecidos / próximos passos
- Este primeiro corte foi escrito **sem rodar o editor**: a sintaxe foi validada com gdtoolkit e a história com `story_check.py`. Ao abrir no Godot, confira o console e ajuste o enquadramento em `location_preview.tscn`.
- Elenco provisório: Patrícia e Seu Jorge reaproveitam os modelos da enfermeira e do funcionário com outra cor. O pacote completo "Everyday NPCs" (44 personagens) resolve isso, e a Bia ganharia um modelo próprio.
- Narração (`sistema`) não tem voz. Dá para adicionar um narrador no `audio_config.json` e marcar `voiced: true`.
