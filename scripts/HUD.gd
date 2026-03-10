## HUD.gd
## Heads-up display: score, lives, level number, and high-score banner.
## Connects to GameManager signals so it stays in sync without polling.
extends CanvasLayer

@onready var score_label: Label = $MarginContainer/HBoxContainer/ScoreLabel
@onready var lives_container: HBoxContainer = $MarginContainer/HBoxContainer/LivesContainer
@onready var level_label: Label = $MarginContainer/HBoxContainer/LevelLabel
@onready var hs_label: Label = $HighScoreLabel   # hidden by default
@onready var hs_timer: Timer = $HighScoreTimer

const HEART_ICON := preload("res://assets/heart_icon.png")

func _ready() -> void:
	GameManager.score_changed.connect(_update_score)
	GameManager.lives_changed.connect(_update_lives)
	GameManager.level_changed.connect(_update_level)
	GameManager.high_score_beaten.connect(_show_high_score_banner)
	GameManager.game_over.connect(_on_game_over)

	_update_score(GameManager.score)
	_update_lives(GameManager.lives)
	_update_level(GameManager.level)
	hs_label.hide()

func _update_score(new_score: int) -> void:
	score_label.text = "Score: %06d" % new_score

func _update_lives(new_lives: int) -> void:
	# Rebuild heart icons
	for child in lives_container.get_children():
		child.queue_free()
	for i in range(new_lives):
		var icon := TextureRect.new()
		icon.texture = HEART_ICON
		icon.custom_minimum_size = Vector2(24, 24)
		lives_container.add_child(icon)

func _update_level(new_level: int) -> void:
	level_label.text = "Level %d" % new_level

func _show_high_score_banner(new_high: int) -> void:
	hs_label.text = "✦ New High Score: %06d ✦" % new_high
	hs_label.show()
	hs_timer.start()

func _on_hs_timer_timeout() -> void:
	hs_label.hide()

func _on_game_over() -> void:
	# Show game-over overlay (handled by a separate scene / CanvasLayer)
	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")
