# Dino Merge — Documento de Planejamento

Segundo jogo mobile de dinossauros da série, estilo fusão (merge, tipo Suika Game/2048 físico). Feito em Godot 4.6 com apoio do Claude Code, reaproveitando os 32 sprites de dino já gerados no primeiro jogo (idle).

## Contexto

- Parte de um objetivo maior de criar de 3 a 5 jogos de dinossauro, publicados um atrás do outro na mesma conta de desenvolvedor Google Play.
- Primeiro jogo da série: idle game (ver documento separado `dino-idle-game-plano.md`).
- Terceiro jogo já cogitado (não iniciado): match-3 temático de dinossauros — decisão de fazer um jogo de cada vez, não simultâneo.

## Conceito

- **Mecânica:** o jogador solta itens de cima de um recipiente fechado (física 2D), controlando a posição horizontal antes de soltar (toque/arraste). Dois itens do mesmo nível que colidem se fundem, virando o próximo nível da cadeia (surge na posição média das duas).
- **Cadeia de fusão:** os 32 dinos (mesmos do jogo idle) organizados numa ordem curada do menor ao maior, terminando no Mosasaurus como "chefão" do topo.
- **Fim de jogo:** se algum item fica acima da linha de perigo por 3 segundos seguidos, a partida termina.
- **Pontuação:** soma a cada fusão, proporcional ao nível fundido; recorde pessoal salvo entre sessões.
- **Plataforma:** Mobile (Android inicialmente), orientação retrato, Godot 4.6, 2D.
- **Monetização:** AdMob — rewarded para continuar após perder (esvazia parcialmente o recipiente, mantém pontuação) e interstitial a cada 3 partidas encerradas (mostrado após o jogador ver a tela de game over).
- **Identidade visual própria:** tema "cânion fóssil" com fissuras de lava e ossos, paleta terracota/dourado/osso — deliberadamente diferente do visual "ilha tropical" do primeiro jogo, para não parecer o mesmo app.

## Plano de execução (7 dias)

1. **Setup e física básica de queda/fusão** — projeto Godot novo, RigidBody2D para os itens, spawn controlável, detecção de colisão/fusão com placeholders.
2. **Cadeia de fusão e pontuação** — mapeamento dos 32 níveis para os sprites de dino existentes, pontuação por fusão.
3. **Fim de jogo e recorde** — linha de perigo com timer de 3s, recorde persistente em save JSON, tela de game over com reinício.
4. **Anúncios (AdMob)** — rewarded para continuar após perder, interstitial a cada 3 partidas.
5. **Assets visuais** — aplicação/correção de escala dos sprites de dino, novo background, ícones de UI, ícone do app.
6. **Sons e polimento (juice)** — efeitos sonoros, música ambiente, números flutuantes, partículas, squash/bounce, screen shake, transições.
7. **Testes, build e publicação** — pendente.

## Status da implementação

### Dia 1 — Setup e física
- Projeto Godot 4.6 criado (mobile, retrato, viewport 720x1280).
- Sprites dos 32 dinos reaproveitados diretamente (`assets/dino/dino_<espécie>_adulto.png`), background e áudio também reaproveitados do protótipo anterior (depois parcialmente substituídos — ver Dia 5/6).
- Autoloads GameManager e DinoChain; cadeia completa de 32 níveis já montada nesse dia (curadoria manual da ordem, editável em `scripts/dino_chain.gd`).
- Física de queda/fusão implementada (`scripts/dino.gd`), com fallback visual (círculo colorido) caso falte algum sprite.
- Ferramental de qualidade (gdtoolkit, hooks de formatação/proteção) configurado.
- Validação: sem Godot no PATH inicialmente, revisão só por leitura de código nesse dia — validação real ficou para dias seguintes.

### Dia 3 — Fim de jogo e recorde
- Implementado e testado pelo próprio Claude Code (conseguiu rodar o Godot real, achado depois em `~/Downloads`).

### Dia 4 — Anúncios (AdMob)
- `AdsManager` construído contra a API real do plugin `godot-sdk-integrations/godot-admob` (baseado no demo oficial do repositório).
- Rewarded ao perder: continua a partida mantendo pontuação, removendo a metade superior da pilha de dinos.
- Interstitial a cada 3 partidas encerradas, mostrado após o jogador ver a tela de game over/recorde.
- Validado com 31/31 testes usando um MockAdmob, rodando Godot 4.6.3 headless.
- Bug de closures do GDScript encontrado e corrigido durante os próprios testes (lambdas capturam variáveis locais por valor, não por referência).
- **Pendência do usuário:** instalar o addon binário via AssetLib no Editor (GDExtension com binários nativos Android/iOS não pode ser feito pelo Claude Code), habilitar o plugin, adicionar o node Admob como filho de AdsManager, configurar `is_real = false` com os IDs de teste oficiais do Google.

### Dia 5 — Assets visuais
- Bug real corrigido: os 32 sprites compartilhavam canvas 64×64, mas o conteúdo real variava de tamanho — escalar pelo canvas fazia 9 das 31 transições da cadeia parecerem menores que o nível anterior. Corrigido para escalar pela bounding box real de cada sprite (medida via Pillow), garantindo crescimento monotônico.
- Novo background gerado via PixelLab: cânion fóssil com fissuras de lava e ossos (substituindo o `bg_island.png` do protótipo antigo, que não combinava tematicamente).
- Ícones de UI gerados via PixelLab: pontuação, troféu, anúncio, restart, som on/off — aplicados nos botões e HUD. Botão de mudo real implementado (toggle do bus master de áudio).
- Identidade visual distinta: paredes do recipiente com preenchimento terracota e friso dourado, linha de perigo laranja-brasa, paleta terrosa/osso/dourada.
- Ícone do app gerado com o Mosasaurus (nível mais alto) como referência, 3 alternativas disponíveis em `assets/app_icon/`, já configurado como ícone do projeto.
- Bug real corrigido: o background não renderizava (TextureRect sem CanvasLayer/Control ancestral, colapsando os anchors) — bug pré-existente do protótipo, não introduzido nesta etapa.
- Validação: jogo rodado de verdade (não headless), prints reais capturados via `get_viewport().get_texture()`.
- Ponto identificado nesse dia: container com posição fixa (LEFT_X/RIGHT_X para 720px) ficava deslocado em telas mais largas que 9:16 — corrigido no Dia 6.

### Dia 6 — Sons e polimento (juice)
- Bug de viewport corrigido: `window/size` restaurado para 720×1280 (resolução de design), stretch mode trocado de `expand` para `keep` — o conteúdo sempre renderiza na proporção correta, com letterbox (barras pretas) preenchendo o excedente em vez de descentralizar o recipiente. Validado em janelas de 400×700 e 500×500.
- Sons sintetizados via numpy/scipy (sem ferramenta de geração de áudio por IA disponível): queda/soltar (reaproveitado), fusão (reaproveitado, com pitch e volume crescendo conforme o nível fundido), clique de UI, game over (novo, tom grave descendente), novo recorde (novo, arpejo ascendente celebratório).
- Música de fundo antiga (`island_theme.ogg`, identificada por metadado como uma faixa genérica de ilha tropical sem relação com o jogo) substituída por uma faixa ambiente sintetizada de 32s em loop, clima "deserto misterioso" (drone grave, percussão esparsa, flauta em escala frígia).
- Volume: botão de mudo já cobre música e efeitos (mesmo bus de áudio); não foi necessário separar em dois controles.
- Juice implementado: números "+X" flutuando ao fundir, partículas crescendo com o nível (bug de cor idêntica ao dino, ficando invisível contra o fundo, corrigido para uma cor clara/dessaturada), squash/bounce no dino recém-fundido, screen shake sutil só nas fusões dos 6 níveis mais altos, tela de game over com entrada em fade + escala.
- Validação: jogo rodado de verdade várias vezes, incluindo teste isolado que capturou o bug da cor da partícula antes de ficar pronto.

### Menus (pós Dia 6)
- `MainMenu.tscn` como cena de abertura: logo/ícone do app, título, recorde pessoal, botões Jogar e Configurações.
- Pausa: botão no HUD, usa `get_tree().paused = true` (física e timers pausam nativamente); overlay em `process_mode = ALWAYS`; reiniciar pede confirmação.
- Configurações como overlay reutilizável (`SettingsPanel.tscn`, não cena separada — evita destruir partida pausada ao abrir configurações), com toggles separados de Música e Efeitos (bus de áudio distintos); botão de mudo rápido do HUD continua controlando tudo via Master.
- `SceneTransition` autoload com fade, usado nas únicas trocas de cena reais (Jogar, Voltar ao menu).
- Botão voltar (Android/Esc): despacho único por cena (`_handle_back_button`), evitando depender de ordem de propagação entre Controls aninhados.
- Reiniciar e voltar ao menu contam no mesmo contador de interstitial que o game over por morte.
- Validado com driver de teste real (menu → configurações → jogar → pausa → reiniciar → configurações pela pausa), sem erros.

### Polimento de jogabilidade (5 pontos)
- Pool de spawn: já estava correto (sorteia só entre os 5 níveis mais baixos da cadeia, `MAX_SPAWN_LEVEL := 4`) — confirmado, sem necessidade de correção.
- Tutorial de 2 passos (toque/arraste para soltar; dois iguais se fundem), aparece só na primeira vez (flag `seen_tutorial` no save), dispensável e reaberto pelo botão voltar.
- Boot splash configurado com o ícone do app sobre fundo marrom-canyon — validável só em dispositivo/build real, não em screenshot.
- Banner "Lendário!" dourado ao criar o Mosasaurus via fusão durante o jogo (não em game over), com partículas.
- Vibração (`Input.vibrate_handheld()`) em cada fusão (20-80ms, escalando com o nível) e buzz extra de 200ms na fusão lendária — validável só em Android real.

## Melhorias visuais avançadas — rodada 2 (assets sem limite de orçamento)

Rodada de polimento visual mais substancial, com orçamento de assets liberado (PixelLab):

1. **Animação idle nos dinos** — sequência de frames (respirar/balançar) para as 32 espécies, priorizando as ~10 primeiras da cadeia (mais vistas no gameplay).
2. **Animação de transformação na fusão** — os dois dinos se aproximam, flash/morph no ponto de encontro, novo dino nasce com leve compressão antes de acomodar (substituindo o "pop" instantâneo).
3. **Sombra de "onde vai cair"** — indicador semitransparente no fundo do recipiente, seguindo a posição X do próximo dino em tempo real.
4. **Sistema de conquistas/badges** — conjunto de conquistas salvas no save (ex. primeira fusão de cada espécie marco, chegar ao Mosasaurus, recordes, partidas jogadas), ícones via PixelLab, tela própria acessível pelo menu inicial (bloqueadas em silhueta).
5. **Cenário evolutivo** (se der tempo) — variações do background por threshold de pontuação dentro da mesma partida (mais ossos visíveis, fissuras de lava mais intensas).

Itens 1-3 priorizados e validados primeiro; 4-5 depois. Resultado avaliado pelo usuário como "melhorou um tanto bom".

## Rodada 3 — colisão realista, física livre e HUD de próximo/sequência

Ainda não commitada (trabalho corrente, aguardando revisão do usuário).

### Colisão pixel-perfeita
- Bug real identificado: o collider de cada dino era sempre um círculo dimensionado pelo lado mais longo do sprite. Para espécies bem assimétricas (ictiossauro, mosassauro, compsognathus, kentrosaurus, pteranodon, ouranosaurus...) isso deixava uma folga grande no eixo curto — o collider não ficava rente ao desenho.
- Corrigido gerando, para as 32 espécies, a decomposição convexa exata da silhueta real (alfa não-transparente) via `BitMap.opaque_to_polygons` + `Geometry2D.decompose_polygon_in_convex` do próprio Godot — o mesmo algoritmo por trás do "Create Collision Polygon" do editor. Script novo `tools/gen_collision.gd`; dado gerado em `assets/dino/collision_data.json` (consumido por `DinoChain`/`dino.gd`, que monta um `CollisionPolygon2D` por parte convexa). Área do collider ficou entre 92-102% da área real de pixels não-transparentes nas 32 espécies.
- Círculo mantido só como fallback para espécie sem sprite.
- Não reabre o bug de sobreposição que motivou usar círculo originalmente (dois dinos do mesmo nível encostando pela silhueta real, não por um círculo uniformemente encolhido).
- Skill `add-dino-species` atualizada com o passo de regerar `collision_data.json` ao cadastrar uma espécie nova.
- Validação: jogo rodado de verdade (headless não renderiza collider/sprite, usada instância janelada à parte), soltando os piores casos de assimetria e ativando o debug de colisão do Godot — contorno rente ao sprite confirmado visualmente.

### Física de rotação livre
- `lock_rotation` removido do RigidBody2D dos dinos — agora tombam, caem de lado ou de cabeça para baixo ao assentar, em vez de ficarem sempre eretos (pedido do usuário, deixa a queda com física real em vez de "empilhamento tipo Suika").
- Checagem da linha de perigo (game over) ajustada: como o topo de um contorno irregular muda conforme o bicho gira, o ponto mais alto real é recalculado a cada frame a partir dos vértices do collider transformados pela rotação atual, em vez de um deslocamento fixo que só valia com tudo em pé.
- Validação: jogo rodado de verdade, screenshot mostrando dinos tombados/inclinados após a queda.
- Atenção futura: vale observar se a física de rotação livre atrapalha o "encaixe" da pilha (cantos travando, fusões difíceis de perceber com bichos tombados) — fácil de ajustar depois (fricção/damping angular) se necessário.

### HUD: "próximo" real, em imagem, e tela de sequência
- Bug real corrigido: o indicador "Próximo:" mostrava o dino atual (o que já ia cair ao soltar), não o que vem depois dele.
- `next_level_index` separado em `current_level_index` (o que está na mão) e `next_level_index` (sorteado com antecedência, é o que aparece no indicador).
- Nome em texto trocado por imagem: ícone com o sprite real do próximo dino ao lado do texto "Próximo:".
- Novo botão "i" (`icon_info.png`, pixel art gerada combinando com a paleta dos outros ícones da UI) ao lado do botão de pause. Abre uma tela cheia com a sequência completa das 32 espécies em ordem (imagem + número, grade de 4 colunas, scrollável), construída dinamicamente a partir do `DinoChain` — não precisa editar a cena ao adicionar espécie nova. Pausa o jogo enquanto está aberta, mesmo padrão do menu de pause.
- Validação: jogo rodado de verdade, screenshot confirmando o ícone do próximo dino no HUD e a grade completa das 32 espécies.

### Pendente
- Nenhuma mudança da Rodada 3 foi commitada ainda — aguardando revisão/aprovação do usuário.
- Revisão visual completa do usuário (prints/vídeo) do resultado acumulado de todas as etapas.
- Observar em jogo real se a rotação livre pede ajuste de física (fricção/damping) para a pilha continuar legível.
- Dia 7: build, testes em dispositivo real, publicação — ainda não iniciado.
