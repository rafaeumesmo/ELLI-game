extends Control

## Sempre entra pelo Mundo (scenes/mundo.gd) -- é ele quem mantém o Elísio
## vivo entre trocas de tela e decide se carrega a tela_inicial (New Game)
## ou retoma na tela salva (Continue, via SaveManager.checkpoint_scene).
const MUNDO_SCENE := "res://scenes/mundo.tscn"
const SETTINGS_PATH := "user://settings.cfg"
const FADE_DURATION := 0.3

@onready var continue_button: Button = %ContinueButton
@onready var new_game_button: Button = %NewGameButton
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton

@onready var options_panel: Panel = %OptionsPanel
@onready var volume_slider: HSlider = %VolumeSlider
@onready var fullscreen_toggle: CheckButton = %FullscreenToggle
@onready var options_back_button: Button = %OptionsBackButton

@onready var confirm_dialog: ConfirmationDialog = %ConfirmDialog
@onready var fade_overlay: ColorRect = %FadeOverlay
@onready var footer_label: Label = %FooterLabel

var _main_buttons: Array[Button]
var _options_controls: Array[Control]
var _master_bus_index: int
var _transitioning: bool = false

func _ready() -> void:
	_main_buttons = [continue_button, new_game_button, options_button, quit_button]
	_options_controls = [volume_slider, fullscreen_toggle, options_back_button]
	_master_bus_index = AudioServer.get_bus_index("Master")

	_load_settings()

	options_panel.hide()
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	continue_button.disabled = not SaveManager.has_save()
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	options_back_button.pressed.connect(_close_options)
	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)

	confirm_dialog.confirmed.connect(_on_new_game_confirmed)
	confirm_dialog.get_cancel_button().text = "Cancel"

	footer_label.text = "v%s   @rafaeumesmo" % _get_version_string()

	_setup_focus_chain()

func _unhandled_input(event: InputEvent) -> void:
	if options_panel.visible and event.is_action_pressed("ui_cancel"):
		_close_options()
		get_viewport().set_input_as_handled()

func _get_version_string() -> String:
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	return version if version != "" else "dev"

func _setup_focus_chain() -> void:
	var active: Array[Button] = []
	for button in _main_buttons:
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
		if not button.disabled:
			active.append(button)

	for i in active.size():
		var prev_button: Button = active[(i - 1 + active.size()) % active.size()]
		var next_button: Button = active[(i + 1) % active.size()]
		active[i].focus_neighbor_top = active[i].get_path_to(prev_button)
		active[i].focus_neighbor_bottom = active[i].get_path_to(next_button)

	if not active.is_empty():
		active[0].grab_focus()

	for i in _options_controls.size():
		var prev_control: Control = _options_controls[(i - 1 + _options_controls.size()) % _options_controls.size()]
		var next_control: Control = _options_controls[(i + 1) % _options_controls.size()]
		_options_controls[i].focus_neighbor_top = _options_controls[i].get_path_to(prev_control)
		_options_controls[i].focus_neighbor_bottom = _options_controls[i].get_path_to(next_control)

func _set_main_buttons_focusable(enabled: bool) -> void:
	for button in _main_buttons:
		if button.disabled:
			continue
		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE

func _on_continue_pressed() -> void:
	SaveManager.load_progress()
	_change_scene_with_fade(MUNDO_SCENE)

func _on_new_game_pressed() -> void:
	if SaveManager.has_save():
		confirm_dialog.popup_centered()
		confirm_dialog.get_cancel_button().grab_focus()
	else:
		_start_new_game()

func _on_new_game_confirmed() -> void:
	_start_new_game()

func _start_new_game() -> void:
	SaveManager.clear_save()
	SaveManager.clear_checkpoint()
	_change_scene_with_fade(MUNDO_SCENE)

func _on_options_pressed() -> void:
	options_panel.show()
	_set_main_buttons_focusable(false)
	volume_slider.grab_focus()

func _close_options() -> void:
	options_panel.hide()
	_set_main_buttons_focusable(true)
	options_button.grab_focus()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(_master_bus_index, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(_master_bus_index, value <= 0.0)
	_save_settings()

func _on_fullscreen_toggled(enabled: bool) -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	_save_settings()

func _load_settings() -> void:
	var config := ConfigFile.new()
	var volume: float = 1.0
	var fullscreen: bool = false
	if config.load(SETTINGS_PATH) == OK:
		volume = config.get_value("audio", "master_volume", 1.0)
		fullscreen = config.get_value("display", "fullscreen", false)

	# MainMenu is the project's run/main_scene, so this is guaranteed to run
	# once at boot before any gameplay scene, re-applying saved settings globally.
	AudioServer.set_bus_volume_db(_master_bus_index, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(_master_bus_index, volume <= 0.0)
	volume_slider.value = volume

	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	fullscreen_toggle.button_pressed = fullscreen

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", volume_slider.value)
	config.set_value("display", "fullscreen", fullscreen_toggle.button_pressed)
	config.save(SETTINGS_PATH)

func _change_scene_with_fade(target_scene: String) -> void:
	if _transitioning or target_scene == "":
		return
	_transitioning = true
	_set_main_buttons_focusable(false)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, FADE_DURATION)
	tween.tween_callback(get_tree().change_scene_to_file.bind(target_scene))
