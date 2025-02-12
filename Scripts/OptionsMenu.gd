extends Control

var screen_offset = DisplayServer.screen_get_size().x
#var main_scene := "res://Scenes/world.tscn"

# Called when the node enters the scene tree for the first time.
func _ready():
	#ResourceLoader.load_threaded_request(main_scene)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_confirm_pressed():
	#var main = ResourceLoader.load_threaded_get(main_scene)
	#get_tree().change_scene_to_packed(main)
	AudioServer.set_bus_volume_db(0, linear_to_db($AudioOptions/VBoxContainer/MasterSlider.value))
	AudioServer.set_bus_volume_db(1, linear_to_db($AudioOptions/VBoxContainer/SFXSlider.value))
	AudioServer.set_bus_volume_db(2, linear_to_db($AudioOptions/VBoxContainer/MusicSlider.value))
	var options_tween = get_tree().create_tween()
	options_tween.tween_property(self, "position", Vector2(screen_offset,self.position.y), 0.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_ELASTIC)
