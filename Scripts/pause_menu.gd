extends Control
var options_menu := "res://Scenes/options_menu.tscn"



func _ready():
	ResourceLoader.load_threaded_request(options_menu)
	$AnimationPlayer.play("RESET")

func resume():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().paused = false
	$AnimationPlayer.play_backwards("blur")
	await $AnimationPlayer.animation_finished
	self.visible = false

func pause():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
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

func _process(delta):
	testEsc()


func _on_options_pressed():
	resume()
	var options_scene = ResourceLoader.load_threaded_get(options_menu)
	get_tree().change_scene_to_packed(options_scene)


func _on_restart_pressed():
	resume()
	get_tree().reload_current_scene()
