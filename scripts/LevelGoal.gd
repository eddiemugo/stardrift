## LevelGoal.gd
## The star / portal at the end of each level.
## When the player enters it, advances to the next level.
class_name LevelGoal
extends Area2D

@export var next_scene: String = ""  # leave empty to auto-advance via GameManager

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var particles: GPUParticles2D = $GoalParticles

var _triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	anim_player.play("idle_spin")

func _on_body_entered(body: Node) -> void:
	if _triggered or body is not Player:
		return
	_triggered = true
	particles.emitting = true
	GameManager.advance_level()
	GameManager.add_score(200)   # level-clear bonus
	await get_tree().create_timer(1.0).timeout
	if next_scene != "":
		get_tree().change_scene_to_file(next_scene)
	else:
		# Default: just reload the same scene as a demo loop
		get_tree().reload_current_scene()
