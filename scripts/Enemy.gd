## Enemy.gd
## Simple patrol enemy that walks between two wall/ledge boundaries.
## The player can stomp it from above to defeat it;
## touching it from the side kills the player.
class_name Enemy
extends CharacterBody2D

@export var speed: float = 80.0
@export var gravity: float = 980.0
@export var stomp_bounce: float = -320.0   # player bounce on stomp

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var stomp_area: Area2D = $StompArea        # thin area on top
@onready var hurt_area: Area2D = $HurtArea          # body of the enemy
@onready var wall_detector_left: RayCast2D = $WallDetectorLeft
@onready var wall_detector_right: RayCast2D = $WallDetectorRight
@onready var ledge_detector: RayCast2D = $LedgeDetector
@onready var death_particles: GPUParticles2D = $DeathParticles

var _direction: float = 1.0   # 1 = right, -1 = left
var _dead: bool = false
var _stomp_bounce_value: float

func _ready() -> void:
	_stomp_bounce_value = stomp_bounce
	stomp_area.body_entered.connect(_on_stomp)
	hurt_area.body_entered.connect(_on_hurt)

func _physics_process(delta: float) -> void:
	if _dead:
		return

	velocity.y += gravity * delta
	velocity.x = speed * _direction

	# Turn at walls or ledge edges
	if wall_detector_left.is_colliding() or not _has_ground_ahead(-1):
		_direction = 1.0
	if wall_detector_right.is_colliding() or not _has_ground_ahead(1):
		_direction = -1.0

	sprite.flip_h = (_direction < 0)
	sprite.play("walk")
	move_and_slide()

func _has_ground_ahead(dir: float) -> bool:
	# Cast a short ray downward slightly ahead to detect ledge
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(dir * 20.0, 0),
		global_position + Vector2(dir * 20.0, 40.0),
		collision_mask
	)
	var result := space.intersect_ray(query)
	return not result.is_empty()

func _on_stomp(body: Node) -> void:
	if _dead or body is not Player:
		return
	var player := body as Player
	# Give the player an upward bounce
	player.velocity.y = _stomp_bounce_value
	_die()

func _on_hurt(body: Node) -> void:
	if _dead or body is not Player:
		return
	(body as Player).die()

func _die() -> void:
	_dead = true
	velocity = Vector2.ZERO
	GameManager.add_score(50)
	death_particles.emitting = true
	sprite.play("dead")
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	await get_tree().create_timer(0.6).timeout
	queue_free()
