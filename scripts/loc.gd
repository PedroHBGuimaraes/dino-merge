class_name Loc
extends RefCounted

## Idiomas que o jogo suporta de fato (têm coluna em translations.csv). A
## ordem aqui é a ordem de exibição no seletor de idioma (Configurações).
const SUPPORTED_LOCALES: Array[String] = ["pt", "en", "es", "de", "fr"]

## Usado quando o idioma do sistema não é nenhum dos suportados. Bate com
## locale/fallback em project.godot.
const FALLBACK_LOCALE := "pt"

## Nome de cada idioma escrito NO PRÓPRIO idioma (fica reconhecível
## independente do idioma atual da UI). Não entra em translations.csv.
const LOCALE_NATIVE_NAMES := {
	"pt": "Português",
	"en": "English",
	"es": "Español",
	"de": "Deutsch",
	"fr": "Français",
}


## Reduz um código de locale cru (OS.get_locale(): "en_US", "pt-BR", "de",
## "zh_Hans_CN", ...) a um dos SUPPORTED_LOCALES olhando só a parte de
## língua antes do primeiro separador. FALLBACK_LOCALE se não houver match.
static func resolve_supported_locale(raw: String) -> String:
	var lang := raw.strip_edges().to_lower().replace("-", "_").get_slice("_", 0)
	return lang if lang in SUPPORTED_LOCALES else FALLBACK_LOCALE


## Helper de tradução pra texto montado em runtime (código).
##
## Resolve a chave pela TranslationServer (que já trata o locale atual e o
## fallback pt configurado em project.godot), aplica os placeholders no
## formato {nome} do Godot e normaliza "\n" literal.
##
## Labels ESTÁTICOS nas .tscn não passam por aqui: basta pôr a chave no
## campo `text` e o auto-translate do Godot (Control.auto_translate_mode,
## AUTO por padrão) resolve, inclusive reagindo à troca de idioma em runtime.
##
## Ex.: Loc.t("HUD_SCORE", {"score": 120})
static func t(key: StringName, params: Dictionary = {}) -> String:
	var result := TranslationServer.translate(key)
	if not params.is_empty():
		result = result.format(params)
	return result.replace("\\n", "\n")
