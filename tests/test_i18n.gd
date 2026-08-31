extends SceneTree

## Smoke test da estrutura de tradução. Roda headless:
##   godot --headless -s tests/test_i18n.gd --path .
## Confere: CSV importado, chaves resolvem nos 5 idiomas, placeholders {x}
## preservados em todas as traduções, Loc.t() interpola, e o mapeamento de
## OS.get_locale() -> idioma suportado (com fallback pt).


func _initialize() -> void:
	var failures := 0

	# 1. Locales configurados
	var locales := TranslationServer.get_loaded_locales()
	for expected in ["pt", "en", "es", "de", "fr"]:
		if not locales.has(expected):
			printerr("FAIL: locale '%s' não carregado (loaded: %s)" % [expected, locales])
			failures += 1

	# 2. Chave simples resolve em cada idioma
	var expected_close := {
		"pt": "Fechar", "en": "Close", "es": "Cerrar", "de": "Schließen", "fr": "Fermer"
	}
	for lc: String in expected_close:
		TranslationServer.set_locale(lc)
		var got := TranslationServer.translate("COMMON_CLOSE")
		if got != expected_close[lc]:
			printerr(
				"FAIL: COMMON_CLOSE em %s = '%s' (esperado '%s')" % [lc, got, expected_close[lc]]
			)
			failures += 1

	# 3. Placeholder interpola via Loc.t (idioma != pt pra pegar template errado)
	TranslationServer.set_locale("de")
	var score := Loc.t("HUD_SCORE", {"score": 1200})
	if score != "Punkte: 1200":
		printerr("FAIL: Loc.t HUD_SCORE (de) = '%s'" % score)
		failures += 1
	TranslationServer.set_locale("pt")

	# 4. Detecção de idioma do sistema: variantes regionais colapsam pro
	# idioma suportado; qualquer coisa fora dos 5 cai em pt.
	var cases := {
		"en_US": "en",
		"en_GB": "en",
		"en": "en",
		"pt_BR": "pt",
		"pt_PT": "pt",
		"es_ES": "es",
		"es_419": "es",
		"es-MX": "es",
		"de_DE": "de",
		"de_AT": "de",
		"fr_FR": "fr",
		"fr-CA": "fr",
		"zh_Hans_CN": "pt",
		"ja_JP": "pt",
		"it_IT": "pt",
		"": "pt",
	}
	for raw: String in cases:
		var got := Loc.resolve_supported_locale(raw)
		if got != cases[raw]:
			printerr(
				(
					"FAIL: resolve_supported_locale('%s') = '%s' (esperado '%s')"
					% [raw, got, cases[raw]]
				)
			)
			failures += 1

	# 5. Toda chave resolve (não-vazio) nos 5 idiomas + placeholders {x}
	# preservados em todas as traduções (senão o String.format quebra).
	var re := RegEx.new()
	re.compile("\\{[a-z_]+\\}")
	for key: String in _csv_keys():
		var pt_holders: PackedStringArray = []
		for lc in ["pt", "en", "es", "de", "fr"]:
			TranslationServer.set_locale(lc)
			var val := TranslationServer.translate(key)
			if val == key or val.strip_edges().is_empty():
				printerr("FAIL: %s sem tradução em %s" % [key, lc])
				failures += 1
				continue
			var holders: PackedStringArray = []
			for m in re.search_all(val):
				holders.append(m.get_string())
			holders.sort()
			if lc == "pt":
				pt_holders = holders
			elif holders != pt_holders:
				printerr(
					(
						"FAIL: %s placeholders diferem em %s: %s vs pt %s"
						% [key, lc, holders, pt_holders]
					)
				)
				failures += 1
	TranslationServer.set_locale("pt")

	if failures == 0:
		print("OK: i18n smoke test passou (", locales.size(), " locales)")
		quit(0)
	else:
		printerr("=== %d falha(s) ===" % failures)
		quit(1)


func _csv_keys() -> PackedStringArray:
	var keys: PackedStringArray = []
	for row in FileAccess.get_file_as_string("res://translations.csv").split("\n"):
		var key := row.split(",")[0].strip_edges()
		if key != "" and key != "keys":
			keys.append(key)
	return keys
