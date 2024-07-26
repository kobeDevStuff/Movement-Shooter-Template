extends Control
@onready var submenu = $Submenu
@onready var practice : PackedScene = preload("res://Scenes/world.tscn")

func _ready():
	submenu.visible = false


func _on_practice_pressed():
	get_tree().change_scene_to_packed(practice)


func _on_join_pressed():
	pass # Replace with function body.


func _on_host_pressed():
	pass # Replace with function body.


func _on_quit_pressed():
	get_tree().quit()


func _on_play_pressed():
	$VBoxContainer.visible = false
	submenu.visible = true


func _on_back_pressed():
	$VBoxContainer.visible = true
	submenu.visible = false
