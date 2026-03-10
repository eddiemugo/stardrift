## KillZone.gd
## Any area tagged as a KillZone instantly kills the player.
## Used for spikes, lava, and the death pit below the level.
extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body is Player:
		(body as Player).die()
