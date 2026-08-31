extends Node

## Autoload. Dono da preferência de idioma do jogo.
##
## Primeiro boot (ou save sem idioma gravado): detecta pelo idioma do
## sistema (OS.get_locale()) e cai em Português se não for um dos 5
## suportados. A partir daí usa o que estiver no save. A escolha manual no
## SettingsPanel sobrescreve a detecção dali em diante.
##
## Registrado ANTES de GameManager nos autoloads, pra já aplicar um idioma
## sensato no boot (antes da primeira UI montar); GameManager._load_progress
## chama load_prefs() logo depois pra corrigir se o jogador já tem escolha
## salva.

var language: String = Loc.FALLBACK_LOCALE


func _ready() -> void:
	_apply(detect_system_language())


## Idioma do sistema reduzido a um dos suportados (ou pt de fallback).
## `raw` só é usado nos testes; em runtime lê OS.get_locale().
func detect_system_language(raw: String = "") -> String:
	return Loc.resolve_supported_locale(raw if not raw.is_empty() else OS.get_locale())


## Chamado pelo GameManager._load_progress(). Retorna `true` quando o save
## não tinha idioma gravado (jogador novo ou save pré-i18n) -- sinal pro
## GameManager persistir o idioma detectado agora, cumprindo "salvo desde
## a primeira vez que o app abre".
func load_prefs(saved: String) -> bool:
	if saved.strip_edges().is_empty():
		return true
	_apply(saved if saved in Loc.SUPPORTED_LOCALES else Loc.FALLBACK_LOCALE)
	return false


## Troca manual de idioma (SettingsPanel). Persiste na hora.
func set_language(locale: String) -> void:
	if locale not in Loc.SUPPORTED_LOCALES or locale == language:
		return
	_apply(locale)
	GameManager.save_language()


## Godot posts NOTIFICATION_TRANSLATION_CHANGED to every node on set_locale(),
## so static labels re-translate on their own; the few code-built strings
## are refreshed by their own screens (see main.gd / main_menu.gd).
func _apply(locale: String) -> void:
	language = locale
	TranslationServer.set_locale(locale)
