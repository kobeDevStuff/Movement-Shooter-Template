extends CharacterBody3D

@export_group("Movement")
@export var WALK_SPEED : float = 4.0
@export var CROUCH_SPEED : float = 2.0
@export var SPRINT_SPEED : float = 10.0
@export var JUMP_VELOCITY : float = 4.5
@export var SENSITIVITY : float = 0.002
@export var ACCELERATION : float = 10.0
@export var AIR_STRAFE_ACCELERATION : float = 0.1
@export var NORMAL_STRAFE_ACCELERATION : float = 2.0

@export_subgroup("Dash")
@export var DASH_SPEED : float = 16.0
@export var DASH_DURATION : float = 0.25
@export var DASH_COOLDOWN : float = 2.5

@export_subgroup("Slide")
@export var SLIDE_SPEED : float = 20.0
@export var SLIDE_DURATION : float = 0.9
@export var SLIDE_COOLDOWN : float = 1.6

var is_dashing := false
var dash_timer := 0.0
var dash_direction := Vector3.ZERO
var dash_cooldown := 0.0


var is_sliding := false
var slide_timer := 0.0
var slide_direction := Vector3.ZERO
var slide_cooldown := 0.0

var debug := false

var speed: float
var acceleration := 2.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var head_target = $"../headTarget"
@onready var camera_target = $"../headTarget/cameraTarget"
@onready var actual_head = $"../actualHead"
@onready var actual_camera = $"../actualHead/actualCamera"
@onready var label = $"../CanvasLayer/Label"
@onready var dash_label = $"../CanvasLayer/Label2"
@onready var slide_label = $"../CanvasLayer/Label3"

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta):
	update_camera_transform(delta)
	apply_gravity(delta)
	apply_jump()
	handle_movement_speeds(delta)
	var direction = get_movement_dir()
	handle_sliding(direction, delta)
	handle_dashing(direction, delta)
	apply_movement(direction, delta)
	move_and_slide()
	update_text()

#region camera
func _unhandled_input(event):
	if event is InputEventMouseMotion:
		head_target.rotate_y(-event.relative.x * SENSITIVITY)
		camera_target.rotate_x(-event.relative.y * SENSITIVITY)
		camera_target.rotation.x = clamp(camera_target.rotation.x, deg_to_rad(-80), deg_to_rad(80))


func update_camera_transform(delta: float) -> void:
	actual_head.position.x = lerp(actual_head.position.x, position.x, ACCELERATION * 9 * delta)
	actual_head.position.z = lerp(actual_head.position.z, position.z, ACCELERATION * 9 * delta)
	actual_camera.rotation.x = lerp_angle(actual_camera.rotation.x, camera_target.rotation.x, ACCELERATION * 5 * delta)
	actual_head.rotation.y = lerp_angle(actual_head.rotation.y, head_target.rotation.y, ACCELERATION * 5 * delta)
#endregion


#region y movement
func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
		acceleration = AIR_STRAFE_ACCELERATION
	else:
		acceleration = NORMAL_STRAFE_ACCELERATION


func apply_jump() -> void:
	if Input.is_action_just_pressed("JUMP") and is_on_floor():
		velocity.y = JUMP_VELOCITY
#endregion


#region basic movement
func handle_movement_speeds(delta: float) -> void:
	if Input.is_action_pressed("CROUCH"):
		speed = CROUCH_SPEED
		actual_head.position.y = lerp(actual_head.position.y, position.y - 0.5, delta * ACCELERATION * 4)
	elif Input.is_action_pressed("SPRINT"):
		speed = SPRINT_SPEED
		actual_head.position.y = lerp(actual_head.position.y, position.y, delta * ACCELERATION * 4)
	else:
		speed = WALK_SPEED
		actual_head.position.y = lerp(actual_head.position.y, position.y, delta * ACCELERATION * 4)


func get_movement_dir() -> Vector3:
	var input_dir = Input.get_vector("LEFT", "RIGHT", "FORWARD", "BACKWARD")
	return (actual_head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()


func apply_movement(direction: Vector3, delta: float) -> void:
	if is_dashing:
		velocity.y = 3 * sin(actual_camera.rotation.x)  # Make gravity weaker during dash
	elif direction:
		velocity.x = lerp(velocity.x, direction.x * speed, ACCELERATION * delta * acceleration)
		velocity.z = lerp(velocity.z, direction.z * speed, ACCELERATION * delta * acceleration)
	else:
		velocity.x = lerp(velocity.x, 0.0, ACCELERATION * delta)
		velocity.z = lerp(velocity.z, 0.0, ACCELERATION * delta)
#endregion


#region sliding
func handle_sliding(direction: Vector3, delta: float) -> void:
	if Input.is_action_just_pressed("CROUCH") && is_on_floor():
		if slide_cooldown <= 0:
			is_sliding = true
			slide_direction = direction if direction != Vector3.ZERO else -head_target.transform.basis.z
		else:
			reset_slide()
		
	if Input.is_action_pressed("CROUCH") && is_on_floor() && is_sliding && velocity.length() > WALK_SPEED:
		slide_timer -= delta
		velocity = slide_direction.normalized() * SLIDE_SPEED
	else:
		is_sliding = false
	if slide_timer <= 0 || (Input.is_action_just_released("CROUCH") && is_on_floor()):
		reset_slide()
	slide_cooldown -= delta


func reset_slide() -> void:
	is_sliding = false
	slide_cooldown = SLIDE_COOLDOWN
	slide_timer = SLIDE_DURATION
#endregion


#region dashing
func handle_dashing(direction: Vector3, delta: float) -> void:
	if Input.is_action_just_pressed("DASH") and not is_dashing and dash_cooldown <= 0 && !is_on_floor():
		is_dashing = true
		dash_timer = DASH_DURATION
		
		dash_direction = direction if direction != Vector3.ZERO else -head_target.transform.basis.z

	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			dash_cooldown = DASH_COOLDOWN
			is_dashing = false
		else:
			velocity = dash_direction.normalized() * DASH_SPEED
	dash_cooldown -= delta
#endregion

func update_text() -> void:
	if Input.is_action_just_pressed("DEBUG") and !debug:
		debug = true
		label.visible = true
		dash_label.visible = true
		slide_label.visible = true
	elif Input.is_action_just_pressed("DEBUG") and debug:
		debug = false
		label.visible = false
		dash_label.visible = false
		slide_label.visible = false
	label.text = str(snappedf(velocity.length(), 0.01))
	dash_label.text = "Dash cooldwon: " + str(snappedf(dash_cooldown, 0.1))
	slide_label.text = "Slide cooldown: " + str(snappedf(slide_cooldown, 0.1))
