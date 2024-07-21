extends CharacterBody3D


const WALK_SPEED := 6.0
const CROUCH_SPEED := 2.0
const SPRINT_SPEED := 12.0
const JUMP_VELOCITY := 4.5
const SENSITIVITY := 0.002
const ACCELERATION := 10.0
const AIR_STRAFE_ACCELERATION := 0.1
const NORMAL_STRAFE_ACCELERATION := 2.0
# dash parameters
const DASH_SPEED := 20.0
const DASH_DURATION := 0.3
const DASH_COOLDOWN := 1.6

var is_dashing := false
var dash_timer := 0.0
var dash_direction := Vector3.ZERO
var dash_cooldown := 0.0
var speed: float
var acceleration := 2.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var head_target = $"../headTarget"
@onready var camera_target = $"../headTarget/cameraTarget"
@onready var actual_head = $"../actualHead"
@onready var actual_camera = $"../actualHead/actualCamera"

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		head_target.rotate_y(-event.relative.x * SENSITIVITY)
		camera_target.rotate_x(-event.relative.y * SENSITIVITY)
		camera_target.rotation.x = clamp(camera_target.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _physics_process(delta):
	actual_head.position.x = lerp(actual_head.position.x, position.x, ACCELERATION * 9 * delta)
	actual_head.position.z = lerp(actual_head.position.z, position.z, ACCELERATION * 9 * delta)
	actual_camera.rotation.x = lerp_angle(actual_camera.rotation.x, camera_target.rotation.x, ACCELERATION * 5 * delta)
	actual_head.rotation.y = lerp_angle(actual_head.rotation.y, head_target.rotation.y, ACCELERATION * 5 * delta)
	
	# Handle gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
		acceleration = AIR_STRAFE_ACCELERATION
	else:
		acceleration = NORMAL_STRAFE_ACCELERATION
	# Handle jump
	if Input.is_action_just_pressed("JUMP") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Handle crouch and sprint
	if Input.is_action_pressed("CROUCH"):
		speed = CROUCH_SPEED
		actual_head.position.y = lerp(actual_head.position.y, position.y - 0.5, delta * ACCELERATION * 4)
	elif Input.is_action_pressed("SPRINT"):
		speed = SPRINT_SPEED
		actual_head.position.y = lerp(actual_head.position.y, position.y, delta * ACCELERATION * 4)
	else:
		speed = WALK_SPEED
		actual_head.position.y = lerp(actual_head.position.y, position.y, delta * ACCELERATION * 4)

	# Handle movement input
	var input_dir = Input.get_vector("LEFT", "RIGHT", "FORWARD", "BACKWARD")
	var direction = (actual_head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Handle dashing
	if Input.is_action_just_pressed("DASH") and not is_dashing and dash_cooldown <= 0:
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
	# Apply movement
	if is_dashing:
		velocity.y = 3 * sin(actual_camera.rotation.x)  # Make gravity weaker during dash
	elif direction:
		velocity.x = lerp(velocity.x, direction.x * speed, ACCELERATION * delta * acceleration)
		velocity.z = lerp(velocity.z, direction.z * speed, ACCELERATION * delta * acceleration)
	else:
		velocity.x = lerp(velocity.x, 0.0, ACCELERATION * delta)
		velocity.z = lerp(velocity.z, 0.0, ACCELERATION * delta)

	move_and_slide()

