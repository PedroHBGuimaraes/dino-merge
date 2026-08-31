# Dino Merge — Plano de Melhorias

Levantamento feito jogando o build no commit `9208137` (Godot 4.6.3), via
harness headless `tools/shot.gd` — capturei menu, gameplay nos 3 tiers de
fundo (score 0 / ~300 / ~800+), tutorial, pause, game over, painel de
sequência, tela de conquistas e configurações.

Orçamento de assets/PixelLab liberado. Ordenado por impacto, não por
esforço.

---

## Progresso (2026-08-31)

Executado na ordem sugerida. Commits em `master`:

- **P0** (`341d0f6`) — B1 áudio persiste, B2 toast de conquista in-run,
  B4 janela de combo 1.5s→0.7s, B7 overlays opacos, B9 tutorial,
  B10 screen shake, B5 remoção de órfãos. B3 verificado (viewport OK em
  20:9 e 4:3, sem mudança de config).
- **P1** (`30f9815`) — `scripts/pit.gd`: poço redesenhado (interior
  opaco, chão, paredes com relevo + friso, sombra de topo, vinheta),
  linha de perigo tracejada animada com chevrons, brilho de brasa por
  tier dentro do poço.
- **Evolução + Dinopédia** (`391605a`) — merge nasce filhote→jovem→adulto
  (usa os 256 frames parados); painel de sequência com silhuetas dos não
  descobertos + contador N/32; `discovered_species` persistido.
- **Identidade** (`c2c3811`) — emblema (crânio de T-rex + ossos, PixelLab)
  no menu no lugar do app_icon; fonte pixel `DinoMerge.ttf` no título;
  game over com botão "Menu" e linha "Você chegou ao {espécie}".
- **P2 juice** (`5934c20` + `1a08c13`) — shockwave em cada fusão; preview
  do próximo dino respira + pop ao carregar; screen shake graduado a
  partir do nível 10 (era só ≥26); "+score" flutuante cresce/esquenta por
  tier.
- **P3/P4** — U6 configurações reais (sliders de volume, toggle de
  vibração via `GameManager.vibrate()`, apagar progresso com confirmação);
  U9 glow dos botões calibrado; C2 toast "Nova espécie!" na 1ª fusão de
  cada nível ≥5.
- **U5/C1 Dinopédia** (`5d9c761`) — tocar um dino descoberto abre um card
  com sprite grande, "#N/32 Nome" e um **fato paleontológico** (32 fatos
  × 5 idiomas). Não descobertos ficam silhueta e não clicáveis.
- **J7/C5** (`a021f67`) — criar o Mosasaurus dispara slow-mo de 0.6s +
  chuva de ouro atrás do banner; bater o recorde dá o mesmo tratamento na
  tela de game over.
- **U4 painéis emoldurados** (`5bdc88b`) — `assets/ui/merge/panel.png`
  extraído do kit PixelLab, montado como nine-patch (`StyleBoxTexture` em
  `PanelContainer` no tema). Pause, Configurações, Dinopédia e Conquistas
  agora são tábuas de pedra fóssil emolduradas.
- **J3** (`c10077d`) — fusão empurra + dá squash nos dinos vizinhos, a
  onda passa pela pilha em vez de ser absorvida em silêncio.

### Ainda pendente
- **U5** — setas "→" de progressão entre células da Dinopédia (grade 4-col
  torna chato; baixo valor).
- **J8** cross-fade de fundo (baixo valor agora que o poço é opaco).
- **C3** modos extras (diário / poço estreito / objetivo) — feature grande,
  decisão de design.
- HUD: mostrar os 2 próximos dinos (mexe no caminho do rewarded-continue).
- Fonte pixel só no título (atlas sem acentos — não serve de fonte global
  num jogo em 5 idiomas).

---

## P0 — Bugs e dívida técnica

| # | Problema | Correção |
|---|---|---|
| B1 | **Áudio não persiste.** `settings_panel.gd` e o mudo rápido do HUD só chamam `AudioServer.set_bus_mute()` — nada grava no save nem restaura no boot. Fechar e reabrir o app volta tudo a ligado. | Guardar `music_muted` / `sfx_muted` / `master_muted` no `GameManager` (mesmo JSON do resto) e reaplicar em `_ready`. Idealmente virar **volume 0–100** (slider), não só on/off. |
| B2 | **Conquista desbloqueia em silêncio.** `GameManager.achievement_unlocked` é emitido mas nenhum nó escuta durante a partida. O jogador só descobre indo no menu. | Toast/banner in-run (fila, ~2s cada): ícone + título deslizando do topo, som dedicado. Reaproveita a infra de `_show_legendary_banner`. |
| B3 | **Viewport regrediu.** `project.godot` está `400×700` + `stretch/aspect="expand"` — o plano do Dia 6 documentou `720×1280` + `keep` (letterbox). Com `expand`, a área jogável depende 100% do `_fit_gameplay_to_viewport` e telas muito estreitas (20:9) ou tablets podem cortar/descentralizar. | Decidir a intenção. Se `expand` é proposital, testar em 1080×2400, 1284×2778 e 4:3, e travar limites no fit. Se não, voltar pra `keep`. |
| B4 | **Variância absurda de pontuação.** 18 drops iguais deram 230 numa run e 1140 noutra, só por RNG de cascata física. `COMBO_WINDOW = 1.5s` encadeia merges que a pilha causou por reassentamento, não pelo jogador. | Reduzir a janela (~0.6–0.8s), ou exigir que o merge encadeado seja de nível ≥ ao anterior, ou dar o bônus só quando 2+ merges acontecem no mesmo frame de física. |
| B5 | **Assets órfãos no repo.** `assets/audio/music/island_theme.ogg`, `assets/audio/sfx/unlock.wav` não são mais referenciados (`canyon_theme.ogg` / `evolve.wav` os substituíram). | Remover. |
| B6 | **Idle `filhote`/`jovem` ignorados.** `dino_chain._try_load_idle_frames` casa só `dino_<sp>_idle_N.png`. Os 256 frames novos `_idle_filhote_N` / `_idle_jovem_N` (já na pasta) não entram em lugar nenhum. | Ver J6 — é feature, não bug, mas os assets estão parados. |
| B7 | **Overlays semitransparentes.** Conquistas (0.92) e Configurações (0.88) deixam o menu vazar por trás — lê como bug de render. | Painel sólido temático (nine-patch), ou overlay 1.0. |
| B8 | **Halo avermelhado na peça segurada.** Alguns dinos no spawner (ex. pterodactylus) aparecem com aura vermelha fraca. Investigar `modulate` residual / z-index / material herdado. |
| B9 | Tutorial só marca `seen` no dismiss — fechar o app no passo 1 faz reaparecer. Marcar ao abrir o passo 2. |
| B10 | `_screen_shake` roda `await create_timer(0.02)` ~17× mexendo em `camera.offset`; ao coincidir com o banner lendário (que também tween-a) o offset pode não zerar. Guardar/restaurar offset base. |

---

## P1 — Legibilidade do campo de jogo (o problema nº 1)

Nos screenshots de gameplay, **o "recipiente fechado" não existe visualmente**:
são duas linhas finas douradas + uma linha de chão. Contra o `bg_crater_high`
(rio de lava, vulcão e caveiras gigantes desenhadas no próprio fundo) a área
de jogo simplesmente some, e os dinos empilhados ficam quase invisíveis.

| # | Ação |
|---|---|
| L1 | **Dar volume ao poço.** Paredes com espessura real (pedra/terra em nine-patch), sombra projetada pra dentro, borda superior irregular. Alternativa forte: usar `assets/backgrounds/bg_gameplay.png` (já tem uma cava oval definida) como moldura fixa e rolar só o fundo distante. |
| L2 | **Separar figura de fundo.** Os 3 `bg_crater*` têm esqueletos de dino pintados — competem com os dinos de jogo. Gerar versões "limpas" dos fundos (sem ossos grandes no plano do poço) **ou** escurecer/dessaturar só a coluna vertical do poço com um overlay gradiente. |
| L3 | **Realçar cada dino.** Contorno/rim-light sutil de 1px, ou drop-shadow leve e mole por dino, ou um "chão" neutro claro dentro do poço. Testar os três. |
| L4 | **Linha de perigo viva.** Hoje é laranja fixa sobre fundo laranja — invisível. Fazer tracejada, pulsando de intensidade quando algo passa de ~80% da altura, com caveira nas duas pontas. Escurecer levemente a tela acima da linha. |
| L5 | `InteriorScrim` de 0.4 é fraco — trocar por gradiente vertical (mais escuro em cima, perto do perigo) e subir pra ~0.55 no meio. |
| L6 | Cross-fade entre tiers de fundo (hoje é troca seca de textura em `_update_background`). |

---

## P2 — Juice, animação e efeitos

| # | Ação |
|---|---|
| J1 | **Antecipação no spawner.** O próximo dino aparece instantâneo. Dar um pop/escala rápida ao carregar, e um bob sutil enquanto está "na mão". |
| J2 | **Evolução visível na fusão (usa assets já na pasta).** O dino recém-fundido nasce como `_idle_filhote` e cresce (escala + troca pra `_idle_jovem` → `_idle_adulto`) em ~0.4s antes de assentar. Aproveita os 256 frames novos. Alternativa: tiers 1–10 usam arte filhote, 11–21 jovem, 22–32 adulto — leitura real de "cresceu". |
| J3 | **Shockwave.** Anel expansivo (GradientTexture radial, aditivo) no ponto de fusão, além do flash atual. E squash nos dinos vizinhos empurrados pela fusão. |
| J4 | Screen shake proporcional já a partir do nível ~14 (hoje só ≥26), bem sutil. |
| J5 | **Combo mais físico.** Além do texto "COMBO xN", vinheta colorida pulsando nas bordas + leve zoom-in da câmera que relaxa. O pitch do som já sobe — manter. |
| J6 | Ver J2 (é o mesmo item, priorizado). |
| J7 | **Banner "Lendário!" com arte.** Hoje é um `Label`. Merece: placa/pergaminho (`assets/style/title_plank.png` serve), raios dourados, ~0.3s de slow-motion (`Engine.time_scale`), partículas douradas caindo. |
| J8 | Poeira de pouso (entregue nesta rodada) — estender: rastro de poeira quando um dino grande rola/desliza, não só no primeiro impacto. |
| J9 | **Parallax de céu** (entregue nesta rodada): as nuvens quase não aparecem porque os `bg_crater` não têm céu aberto. Ou mover as nuvens/pterossauro pra dentro da fenda do cânion (onde há "céu" visível), ou gerar fundos com faixa de céu maior. O pterossauro distante já lê bem — manter. |
| J10 | Números "+X" flutuantes: variar cor/tamanho por tier do merge, não só por combo. |
| J11 | Vibração: padrões distintos por evento (fusão normal / combo / lendário / game over) em vez de só escalar duração. |

---

## P3 — UI e telas

| # | Ação |
|---|---|
| U1 | **Logo do menu.** Hoje é o `app_icon.png` **cru, com fundo branco**, esticado como logo — feio contra o cânion. Gerar logo "DINO MERGE" com fundo transparente, tema fóssil (letras de osso/pedra), + o `title_plank` atrás se quiser. |
| U2 | **Fonte.** Tudo em fonte default do Godot. Gerar bitmap font pixel temática ("DinoMerge") via PixelLab e aplicar no `main_theme.tres` (`default_font`). O `DinoIsland.ttf` na pasta é do jogo 1 — não usar. |
| U3 | **Game over.** Só tem "Jogar de novo" — falta botão "Menu". E mostrar a conquista da run: "Você chegou ao **Triceratops**!" com o sprite, + a torre final ao fundo em destaque em vez de escondida no escuro. |
| U4 | Painel sólido temático (nine-patch madeira/pedra) para Pause, Sequência, Conquistas, Configurações — em vez de só o overlay marrom translúcido (ver B7). |
| U5 | **Painel de sequência = Dinopédia.** Hoje é uma grade de 32. Adicionar: setas "→" de progressão, silhueta preta nos que o jogador **nunca criou** (incentivo de coleção — precisa persistir "espécies vistas"), destaque no próximo alvo, e um fato curto por espécie ao tocar. |
| U6 | **Configurações.** Toggles são ícones de alto-falante ambíguos (não dá pra ler o estado). Trocar por switches reais + **sliders de volume** (música/efeitos separados). Adicionar: toggle de vibração, botão "Resetar progresso" (com confirmação dupla), link de créditos. |
| U7 | HUD "Próximo": ícone minúsculo ao lado de label textual. Aumentar o ícone, mostrar os **2 próximos**, e emoldurar. Verificar corte do painel do topo em telas estreitas. |
| U8 | Mostrar o recorde durante a partida (marca discreta na régua lateral, ou "melhor: X" apagado no HUD) pra dar tensão perto de bater. |
| U9 | Calibrar o glow laranja dos botões temáticos — no menu de pause está forte demais (`shadow_size` 10–16 no `main_theme.tres`). |
| U10 | Micro-transições: telas entram/saem com fade+escala (game over já tem; padronizar pause, sequência, conquistas, settings). |
| U11 | Boot splash usa `app_icon.png` (fundo branco) sobre fundo canyon — trocar pelo logo novo (U1). |

---

## P4 — Conteúdo e metagame

| # | Ação |
|---|---|
| C1 | **Dinopédia como progressão de longo prazo** (ver U5): cada espécie criada desbloqueia um card com nome real, período, fato. Usa filhote/jovem/adulto. É o gancho de retenção que um endless puro não tem. |
| C2 | Mais conquistas + toast in-run (B2). Ex.: "criar espécie X", "combo 5", "sobreviver 5 min", "encher metade do poço e recuperar". |
| C3 | Modos extras leves: **Desafio Diário** (seed fixa, ranking local), poço estreito ("Fenda"), objetivo ("chegue ao T-Rex em 40 drops"). |
| C4 | Sons faltando: milestone de score, unlock de espécie nova, quebra de pedra (se entrar obstáculo). Há `milestone.wav` / `sfx_dino_unlock.wav` na pasta — validar se servem ou gerar no tema. |
| C5 | Tela de "Novo Recorde" dedicada e celebratória (hoje é um `Label` extra no game over). |

---

## Apêndice — Assets dropados na pasta: destino

### Aproveitáveis no Dino Merge

| Asset | Status | Destino |
|---|---|---|
| `assets/backgrounds/cloud_a/b.png`, `pterosaur_far.png` | **Integrado** (`parallax_sky.gd`) | Refinar posição (J9) |
| `assets/particles/sand_dust.png` | **Integrado** (`dino.gd`) | Estender (J8) |
| `assets/backgrounds/bg_gameplay.png` | Na pasta, não usado | Moldura de jogo (L1) ou fundo de menu |
| `assets/style/title_plank.png` | Na pasta, não usado | Cabeçalho de painéis (U4) / banner lendário (J7) |
| `assets/dino/idle/*_filhote_*`, `*_jovem_*` (256 frames) | Na pasta, não usado | Evolução na fusão + Dinopédia (J2/C1) |
| `assets/particles/rock_shard.png` | Na pasta | Só se entrar obstáculo de pedra; senão descartar |
| `assets/audio/sfx/milestone.wav`, `poke.wav`, `sfx_dino_unlock.wav`, `desert_theme.wav` | Na pasta | Validar autoria/tema antes de usar (C4) |

### Não pertencem a este jogo (deixados untracked)

- **Match-3 (jogo 3):** `assets/ui/dino-math/*`, `assets/backgrounds/dig_grid.png`, `assets/pieces/*` (peça bone/claw/tooth/scale/footprint/egg + `special_line_overlay` / `special_area_overlay`), `assets/audio/sfx/sfx_swap|match|combo|special_activate|rock_break|level_win|level_lose.wav`, `assets/obstacles/*`.
- **Idle (jogo 1):** `assets/scenes/logo.png` ("DINO ISLAND"), `assets/fonts/DinoIsland.ttf`, `assets/scenes/feed_ground.png`, `bg_flower_cluster.png`, `bg_distant_dino.png`, `assets/ui/dino_sleeping.png`, `food_bowl_*.png`, `icon_prestige.png`, `assets/achievements/*` (conquistas de produção/taps/streak).
- **Indefinido:** `assets/ui/badges_sheet.png`, `assets/ui/ui_kit_atlas.png` (spritesheets não referenciadas — abrir e classificar).

---

## Ordem sugerida de execução

1. **P0** inteiro (bugs — rápido, destrava confiança no build).
2. **P1** (legibilidade) — maior salto de qualidade percebida; precisa de PixelLab (moldura do poço + fundos limpos).
3. **J2 + C1** (evolução na fusão + Dinopédia) — aproveita 256 assets parados e adiciona metagame de uma vez.
4. **U1/U2** (logo + fonte) — identidade.
5. Resto de P2 (juice) e P3 (telas).
6. P4 (modos/conteúdo) por último.
