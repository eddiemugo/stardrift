## Coin.gd
## Collectible coin that bobs up and down and spins.
## On player contact it plays a collect animation, awards score,
## and queues itself free.
class_name Coin
extends Area2D

@export var bob_height: float = 6.0
@export var bob_speed: float = 2.5
@export var spin_speed: float = 180.0  # degrees per second

@onready var sprite: Sprite2D = $Sprite2D
@onready var collect_particles: GPUParticles2D = $CollectParticles
@onready var collect_sound: AudioStreamPlayer2D = $CollectSound
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var _origin_y: float
var _collected: bool = false

func _ready() -> void:
	_origin_y = position.y
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _collected:
		return
	# Bobbing
	position.y = _origin_y + sin(Time.get_ticks_msec() * 0.001 * bob_speed) * bob_height
	# Spinning
	sprite.rotation_degrees += spin_speed * delta

func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	if body is Player:
		_collect(body as Player)

func _collect(player: Player) -> void:
	_collected = true
	set_deferred("monitoring", false)
	player.collect_coin()
	GameManager.add_coin_score()
	collect_particles.emitting = true
	if collect_sound:
		collect_sound.play()
	sprite.hide()
	# Wait for particles / sound then free
	await get_tree().create_timer(0.8).timeout
	queue_free()
