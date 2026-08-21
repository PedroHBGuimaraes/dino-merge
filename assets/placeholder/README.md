# Placeholders

Sem arte final ainda. Os visuais dos dinos são gerados em código
(`scenes/dino/Dino.gd`) como um `ColorRect` colorido por espécie
(`DinoSpeciesData.placeholder_color`) que muda de escala por estágio.

Quando houver arte final, troque o nó `Shape` (ColorRect) de `Dino.tscn` por
um `Sprite2D`/`AnimatedSprite2D` e ajuste `Dino.gd` para trocar a textura em
vez da cor. Sugestão de organização para os assets reais:

```
assets/
  sprites/
    dino/<species_id>/filhote.png, jovem.png, adulto.png
  ui/
  audio/
```
