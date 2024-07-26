extends CharacterBody3D
class_name PlayerInstance
signal health_changed(health_value)

@export_group("Camera")
@export var base_fov : float = 80
@export var dashing_fov_multiplier : float = 1.8
@export var sliding_fov_multiplier : float = 1.6
@export var max_fov : float = 120
@export var min_fov : float = 70
@export var camera_position_lerp : float = 6.0
@export var camera_rotation_lerp : float = 0.999
@export var normal_camera_fov_lerp : float = 0.2
@export var SENSITIVITY : float = 0.002

@export_group("Movement")
@export var WALK_SPEED : float = 6.0
@export var CROUCH_SPEED : float = 3.0
@export var SPRINT_SPEED : float = 15.0
@export var JUMP_VELOCITY : float = 9.5
@export var ACCELERATION : float = 10.0
@export var DECELERATION : float = 6.0
@export var AIR_STRAFE_ACCELERATION : float = 0.1
@export var NORMAL_STRAFE_ACCELERATION : float = 2.0
@export var WALL_RUN_GRAVITY : float = 0.1
@export var NORMAL_GRAVITY : float = 9.8

@export_subgroup("Dash")
@export var DASH_SPEED : float = 25.0
@export var DASH_DURATION : float = 0.25
@export var DASH_COOLDOWN : float = 2.5

@export_subgroup("Slide")
@export var SLIDE_SPEED : float = 30.0
@export var SLIDE_DURATION : float = 0.35
@export var SLIDE_COOLDOWN : float = 0.6

var normal_fov_multiplier : float = 1

var is_dashing := false
var dash_timer := 0.0
var dash_direction := Vector3.ZERO
var dash_cooldown := 0.0

var is_sliding := false
var slide_timer := 0.0
var slide_direction := Vector3.ZERO
var slide_cooldown := 0.0

var debug := false

var pickable : bool = false

var speed: float
var acceleration := 2.0

var gravity = 9.8
var direction : Vector3 = Vector3.ZERO

const SPAWN_POS : Vector3 = Vector3(0,1,0)
const MAX_HEALTH : int = 20

var health = MAX_HEALTH

@onready var animation_player = $AnimationPlayer
@onready var head = $Head
@onready var camera = $Head/Camera
@onready var collect_ray = $Head/Camera/CollectRay
@onready var shoot_ray = $Head/Camera/ShootRay
@onready var muzzle_flash = $Head/Camera/Gun/MuzzleFlash
@onready var speed_label = $CanvasLayer/SpeedLabel
@onready var dash_label = $CanvasLayer/DashLabel
@onready var slide_label = $CanvasLayer/SlideLabel
@onready var crosshair = $CanvasLayer/GUI/Crosshair
@onready var collect_label = $CanvasLayer/GUI/CollectLabel

@onready var ball = preload("res://Scenes/item.tscn")

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

func _ready():
	if not is_multiplayer_authority(): return
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true


func _physics_process(delta):
	if not is_multiplayer_authority(): return
	apply_gravity(delta)
	handle_movement_speeds(delta)
	direction = get_movement_dir()
	handle_sliding(delta)
	handle_dashing(delta)
	apply_movement(delta)
	apply_jump()
	handle_wall_running()
	normal_fov()
	move_and_slide()
	update_text()
	spawn_item()
	handle_pickable()
	handle_item_pickup()


#region camera
func _unhandled_input(event):
	if not is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))
	
	if Input.is_action_just_pressed("SHOOT") \
			and animation_player.current_animation != "shoot":
		play_shoot_effects.rpc()
		if shoot_ray.is_colliding() && shoot_ray.get_collider() is PlayerInstance:
			var hit_player = shoot_ray.get_collider()
			hit_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())

func normal_fov():
	var target_fov = base_fov * sqrt(get_real_velocity().length())/sqrt(SPRINT_SPEED) * normal_fov_multiplier
	camera.fov = lerp(camera.fov, clamp(target_fov, min_fov ,max_fov), normal_camera_fov_lerp)

func slide_fov():
	var fov_tween = get_tree().create_tween()
	fov_tween.tween_property(camera, "fov", clamp(base_fov * sliding_fov_multiplier, min_fov, max_fov), SLIDE_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	fov_tween.tween_property(camera, "fov", camera.fov, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func dash_fov():
	var fov_tween = get_tree().create_tween()
	fov_tween.tween_property(camera, "fov", clamp(base_fov * dashing_fov_multiplier, min_fov, max_fov), DASH_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	fov_tween.tween_property(camera, "fov", camera.fov, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

#endregion


#region y movement
func apply_gravity(delta: float) -> void:
	if !is_on_floor():
		velocity.y -= gravity * delta
		acceleration = AIR_STRAFE_ACCELERATION
	else:
		acceleration = NORMAL_STRAFE_ACCELERATION


func apply_jump() -> void:
	if Input.is_action_just_pressed("JUMP") && is_on_floor():
		velocity.y = JUMP_VELOCITY

#endregion


#region basic movement
func handle_movement_speeds(delta: float) -> void:
	if Input.is_action_pressed("CROUCH"):
		speed = CROUCH_SPEED
		head.position.y = lerp(head.position.y, -0.1, camera_position_lerp * delta)
	elif Input.is_action_pressed("SPRINT"):
		speed = SPRINT_SPEED
		head.position.y =  lerp(head.position.y, 0.6, camera_position_lerp * delta)
	else:
		speed = WALK_SPEED
		head.position.y =  lerp(head.position.y, 0.6, camera_position_lerp * delta)

func get_movement_dir() -> Vector3:
	var input_dir = Input.get_vector("LEFT", "RIGHT", "FORWARD", "BACKWARD")
	return (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

func apply_movement(delta: float) -> void:
	if is_dashing:
		velocity.y = JUMP_VELOCITY * sin(camera.rotation.x)  # Apply a vertcal force with dash
	elif direction:
		velocity.x = lerp(velocity.x, direction.x * speed, ACCELERATION * delta * acceleration)
		velocity.z = lerp(velocity.z, direction.z * speed, ACCELERATION * delta * acceleration)
	else:
		velocity.x = lerp(velocity.x, 0.0, DECELERATION * delta)
		velocity.z = lerp(velocity.z, 0.0, DECELERATION * delta)

#endregion


#region sliding
func handle_sliding(delta: float) -> void:
	if Input.is_action_just_pressed("CROUCH") && (is_on_floor() || is_on_wall()) && get_real_velocity().length() > WALK_SPEED:
		if slide_cooldown <= 0:
			is_sliding = true
			slide_direction = direction
			if is_on_floor():
				normal_fov_multiplier = 1
				slide_fov()
			else:
				normal_fov_multiplier = 3
		else:
			reset_slide()
		
	if Input.is_action_pressed("CROUCH") && (is_on_floor() || is_on_wall()) && is_sliding && get_real_velocity().length() > WALK_SPEED:
		if is_on_floor():
			slide_timer -= delta
		velocity = lerp(velocity, slide_direction.normalized() * SLIDE_SPEED, ACCELERATION * delta * 5)
	else:
		is_sliding = false
	if slide_timer <= 0 || (Input.is_action_just_released("CROUCH") && !is_sliding && ((is_on_floor() || is_on_wall()) || normal_fov_multiplier == 3)):
		reset_slide()
	slide_cooldown -= delta


func reset_slide() -> void:
	is_sliding = false
	slide_cooldown = SLIDE_COOLDOWN
	slide_timer = SLIDE_DURATION
	normal_fov_multiplier = 1
#endregion


#region dashing
func handle_dashing(delta: float) -> void:
	if Input.is_action_just_pressed("DASH") && !is_dashing && dash_cooldown <= 0 && !is_on_floor():
		dash_fov()
		is_dashing = true
		dash_timer = DASH_DURATION
		
		dash_direction = direction if direction != Vector3.ZERO else -head.transform.basis.z

	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			dash_cooldown = DASH_COOLDOWN
			is_dashing = false
		else:
			velocity = lerp(velocity, dash_direction.normalized() * DASH_SPEED, ACCELERATION * delta * 5)
	dash_cooldown -= delta
#endregion


#region wall running
func handle_wall_running() -> void:
	if is_on_wall() && is_sliding:
		gravity = WALL_RUN_GRAVITY
	else:
		gravity = NORMAL_GRAVITY
		
#endregion

#region animations
@rpc("call_local")
func play_shoot_effects():
	animation_player.stop()
	animation_player.play("shoot")
	muzzle_flash.restart()
	muzzle_flash.emitting = true

@rpc("any_peer")
func receive_damage():
	health -= 1
	if health <= 0:
		health = MAX_HEALTH
		position = SPAWN_POS
	health_changed.emit(health)

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "shoot":
		animation_player.play("idle")

func update_animations() -> void:
	if animation_player.current_animation == "shoot":
		pass
	elif direction != Vector3.ZERO and is_on_floor():
		animation_player.play("move")
	else:
		animation_player.play("idle")

#endregion

#region debug
func update_text() -> void:
	if Input.is_action_just_pressed("DEBUG") && !debug:
		debug = true
		speed_label.visible = true
		dash_label.visible = true
		slide_label.visible = true
	elif Input.is_action_just_pressed("DEBUG") && debug:
		debug = false
		speed_label.visible = false
		dash_label.visible = false
		slide_label.visible = false
	speed_label.text = str(snappedf(get_real_velocity().length(), 0.01))
	dash_label.text = "Dash cooldwon: " + str(snappedf(dash_cooldown, 0.1))
	slide_label.text = "Slide cooldown: " + str(snappedf(slide_cooldown, 0.1))

func spawn_item() -> void:
	if Input.is_action_just_pressed("SPAWN_BALL"):
		var instance = ball.instantiate()
		get_tree().current_scene.add_child(instance)
		instance.global_position = Vector3(randf_range(-30, 30), randf_range(5,50),randf_range(-30, 30))
#endregion

#region GUI
func check_if_hovering() -> bool:
	var intersecting = false
	if collect_ray.get_collider() is Item:
		intersecting = true
	return intersecting

func handle_pickable() -> void:
	if check_if_hovering():
		pickable = true
		collect_label.visible = true
		crosshair.visible = false
	else:
		pickable = false
		crosshair.visible = true
		collect_label.visible = false

func handle_item_pickup() -> void:
	if pickable && Input.is_action_just_pressed("PICKUP"):
		collect_ray.get_collider().hide()
		pickable = false
#endregion
