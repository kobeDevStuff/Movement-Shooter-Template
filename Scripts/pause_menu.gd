extends Control
#var options_menu := "res://Scenes/options_menu.tscn"
var screen_offset = DisplayServer.screen_get_size().x


func _ready():
	$OptionsMenu.position.x = screen_offset
	#ResourceLoader.load_threaded_request(options_menu)
	$AnimationPlayer.play("RESET")

func resume():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	$AnimationPlayer.play_backwards("blur")
	await $AnimationPlayer.animation_finished
	self.visible = false

func pause():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$AnimationPlayer.play("blur")

func testEsc():
	if Input.is_action_just_pressed("ESC") and !get_tree().paused:
		pause()
	elif Input.is_action_just_pressed("ESC") and get_tree().paused:
		resume()


func _on_resume_pressed():
	resume()


func _on_quit_pressed():
	get_tree().quit()

func _process(_delta):
	testEsc()


func _on_options_pressed():
	var options_tween = get_tree().create_tween()
	options_tween.tween_property($OptionsMenu, "position", Vector2(0,$OptionsMenu.position.y), 0.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_ELASTIC)
	
	#resume()
	
	#var options_scene = ResourceLoader.load_threaded_get(options_menu)
	#get_tree().change_scene_to_packed(options_scene)


func _on_restart_pressed():
	resume()
	get_tree().reload_current_scene()
