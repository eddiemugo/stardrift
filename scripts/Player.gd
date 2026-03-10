## Player.gd
## Handles all player movement, physics, and state management.
## Features: running, jumping (with coyote time & jump buffering),
## wall sliding, wall jumping, and dashing.
class_name Player
extends CharacterBody2D

# ── Exported Parameters ────────────────────────────────────────────
@export_group("Movement")
@export var SPEED: float = 220.0
@export var ACCELERATION: float = 1800.0
@export var FRICTION: float = 1600.0
@export var AIR_FRICTION: float = 600.0

@export_group("Jump")
@export var JUMP_VELOCITY: float = -480.0
@export var GRAVITY: float = 980.0
@export var FALL_GRAVITY_MULTIPLIER: float = 1.6   # heavier fall arc
@export var COYOTE_TIME: float = 0.12              # seconds after leaving ledge
@export var JUMP_BUFFER_TIME: float = 0.12         # pre-land jump input window

@export_group("Wall")
@export var WALL_SLIDE_GRAVITY: float = 120.0
@export var WALL_JUMP_VELOCITY: Vector2 = Vector2(260.0, -400.0)
@export var WALL_JUMP_LOCK_TIME: float = 0.18      # time horizontal input locked

@export_group("Dash")
@export var DASH_SPEED: float = 580.0
@export var DASH_DURATION: float = 0.18
@export var DASH_COOLDOWN: float = 0.7

# ── Signals ───────────────────────────────────────────────────────
signal coin_collected(total: int)
signal player_died
signal player_landed

# ── State Machine ─────────────────────────────────────────────────
enum State { IDLE, RUN, JUMP, FALL, WALL_SLIDE, DASH, DEAD }
var state: State = State.IDLE

# ── Internal Variables ────────────────────────────────────────────
var coins: int = 0
var facing_right: bool = true

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var wall_jump_lock_timer: float = 0.0

var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var can_dash: bool = true

var was_on_floor: bool = false

# ── Node References ───────────────────────────────────────────────
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var coyote_timer_node: Timer = $CoyoteTimer
@onready var dash_trail: GPUParticles2D = $DashTrail
@onready var land_particles: GPUParticles2D = $LandParticles
@onready var jump_particles: GPUParticles2D = $JumpParticles

# ── Lifecycle ─────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("player")

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_update_timers(delta)
	_apply_gravity(delta)
	_handle_input(delta)
	_update_state()
	_update_animation()

	var was_airborne := not was_on_floor
	move_and_slide()

	# Landing detection
	if is_on_floor() and was_airborne:
		_on_landed()

	was_on_floor = is_on_floor()

# ── Timer Updates ─────────────────────────────────────────────────
func _update_timers(delta: float) -> void:
	# Coyote time: grace period after walking off a ledge
	if was_on_floor and not is_on_floor():
		coyote_timer = COYOTE_TIME
	coyote_timer = maxf(coyote_timer - delta, 0.0)

	# Jump buffer: remember jump input before landing
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

	# Wall-jump horizontal lock
	wall_jump_lock_timer = maxf(wall_jump_lock_timer - delta, 0.0)

	# Dash timers
	if state == State.DASH:
		dash_timer -= delta
		if dash_timer <= 0.0:
			_end_dash()
	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)
	if dash_cooldown_timer <= 0.0:
		can_dash = true

# ── Gravity ───────────────────────────────────────────────────────
func _apply_gravity(delta: float) -> void:
	if state == State.DASH or is_on_floor():
		return

	var grav := GRAVITY
	if _is_wall_sliding():
		grav = WALL_SLIDE_GRAVITY
	elif velocity.y > 0:
		grav *= FALL_GRAVITY_MULTIPLIER

	velocity.y += grav * delta

# ── Input & Movement ──────────────────────────────────────────────
func _handle_input(delta: float) -> void:
	if state == State.DASH:
		velocity = dash_direction * DASH_SPEED
		return

	var dir := Input.get_axis("move_left", "move_right")

	# Horizontal movement
	if wall_jump_lock_timer > 0.0:
		dir = 0.0  # lock horizontal input briefly after wall jump

	var target_speed := dir * SPEED
	var accel := ACCELERATION if is_on_floor() else AIR_FRICTION
	if dir == 0:
		accel = FRICTION if is_on_floor() else AIR_FRICTION

	velocity.x = move_toward(velocity.x, target_speed, accel * delta)

	# Facing direction
	if dir > 0:
		facing_right = true
	elif dir < 0:
		facing_right = false

	# Jump
	var can_jump := is_on_floor() or coyote_timer > 0.0
	if jump_buffer_timer > 0.0 and can_jump:
		_do_jump()
	elif jump_buffer_timer > 0.0 and _is_wall_sliding():
		_do_wall_jump()

	# Variable jump height: release early → cut velocity
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= 0.45

	# Dash
	if Input.is_action_just_pressed("dash") and can_dash and dash_cooldown_timer <= 0.0:
		_start_dash()

# ── Jump Actions ──────────────────────────────────────────────────
func _do_jump() -> void:
	velocity.y = JUMP_VELOCITY
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	jump_particles.restart()
	jump_particles.emitting = true

func _do_wall_jump() -> void:
	var wall_normal := get_wall_normal()
	velocity = Vector2(wall_normal.x * WALL_JUMP_VELOCITY.x, WALL_JUMP_VELOCITY.y)
	jump_buffer_timer = 0.0
	wall_jump_lock_timer = WALL_JUMP_LOCK_TIME
	jump_particles.restart()
	jump_particles.emitting = true

# ── Dash ──────────────────────────────────────────────────────────
func _start_dash() -> void:
	state = State.DASH
	can_dash = false
	dash_timer = DASH_DURATION
	dash_cooldown_timer = DASH_COOLDOWN
	dash_direction = Vector2(1.0 if facing_right else -1.0, 0.0)
	velocity.y = 0.0
	dash_trail.emitting = true

func _end_dash() -> void:
	dash_trail.emitting = false
	velocity.x = dash_direction.x * SPEED  # preserve some momentum
	state = State.IDLE

# ── Helpers ───────────────────────────────────────────────────────
func _is_wall_sliding() -> bool:
	return is_on_wall() and not is_on_floor() and velocity.y > 0

# ── State Machine Update ──────────────────────────────────────────
func _update_state() -> void:
	if state == State.DASH or state == State.DEAD:
		return

	if is_on_floor():
		state = State.IDLE if absf(velocity.x) < 10.0 else State.RUN
	elif _is_wall_sliding():
		state = State.WALL_SLIDE
	elif velocity.y < 0:
		state = State.JUMP
	else:
		state = State.FALL

# ── Animation ─────────────────────────────────────────────────────
func _update_animation() -> void:
	sprite.flip_h = not facing_right

	match state:
		State.IDLE:       sprite.play("idle")
		State.RUN:        sprite.play("run")
		State.JUMP:       sprite.play("jump")
		State.FALL:       sprite.play("fall")
		State.WALL_SLIDE: sprite.play("wall_slide")
		State.DASH:       sprite.play("dash")
		State.DEAD:       sprite.play("dead")

# ── Events ────────────────────────────────────────────────────────
func _on_landed() -> void:
	land_particles.restart()
	land_particles.emitting = true
	emit_signal("player_landed")

func collect_coin() -> void:
	coins += 1
	emit_signal("coin_collected", coins)

func die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	velocity = Vector2.ZERO
	emit_signal("player_died")
	# Brief pause then respawn handled by GameManager
	await get_tree().create_timer(1.2).timeout
	get_tree().reload_current_scene()
