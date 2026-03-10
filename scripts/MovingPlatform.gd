## MovingPlatform.gd
## An AnimatableBody2D that oscillates between two points.
## Godot's move_and_slide on CharacterBody2D automatically
## inherits velocity from AnimatableBody2D, so the player
## rides it without any extra code.
class_name MovingPlatform
extends AnimatableBody2D

enum MoveAxis { HORIZONTAL, VERTICAL }

@export var move_axis: MoveAxis = MoveAxis.HORIZONTAL
@export var travel_distance: float = 200.0   # pixels
@export var speed: float = 80.0              # pixels per second
@export var start_delay: float = 0.0         # seconds before starting

var _direction: float = 1.0
var _origin: Vector2
var _active: bool = false

func _ready() -> void:
	_origin = position
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	_active = true

func _physics_process(delta: float) -> void:
	if not _active:
		return

	var move_vec := Vector2.RIGHT if move_axis == MoveAxis.HORIZONTAL else Vector2.DOWN
	var displacement := (position - _origin).dot(move_vec)

	if displacement >= travel_distance:
		_direction = -1.0
	elif displacement <= 0.0:
		_direction = 1.0

	var velocity := move_vec * _direction * speed
	move_and_collide(velocity * delta)
