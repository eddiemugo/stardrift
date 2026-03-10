## GameManager.gd
## Autoload singleton that tracks global game state:
## score, lives, level progression, and high score (persisted via
## Godot's built-in ConfigFile so it survives between sessions).
extends Node

# ── Signals ───────────────────────────────────────────────────────
signal score_changed(new_score: int)
signal lives_changed(new_lives: int)
signal level_changed(new_level: int)
signal high_score_beaten(new_high: int)
signal game_over

# ── Constants ─────────────────────────────────────────────────────
const SAVE_PATH := "user://save_data.cfg"
const COIN_VALUE := 10
const MAX_LIVES := 3
const STARTING_LEVEL := 1

# ── State ─────────────────────────────────────────────────────────
var score: int = 0
var lives: int = MAX_LIVES
var level: int = STARTING_LEVEL
var high_score: int = 0
var _config := ConfigFile.new()

# ── Lifecycle ─────────────────────────────────────────────────────
func _ready() -> void:
	_load_save()

# ── Score ─────────────────────────────────────────────────────────
func add_coin_score() -> void:
	score += COIN_VALUE
	emit_signal("score_changed", score)
	if score > high_score:
		high_score = score
		_save()
		emit_signal("high_score_beaten", high_score)

func add_score(amount: int) -> void:
	score += amount
	emit_signal("score_changed", score)
	if score > high_score:
		high_score = score
		_save()
		emit_signal("high_score_beaten", high_score)

# ── Lives ─────────────────────────────────────────────────────────
func lose_life() -> void:
	lives -= 1
	emit_signal("lives_changed", lives)
	if lives <= 0:
		emit_signal("game_over")

func reset_lives() -> void:
	lives = MAX_LIVES
	emit_signal("lives_changed", lives)

# ── Level ─────────────────────────────────────────────────────────
func advance_level() -> void:
	level += 1
	emit_signal("level_changed", level)

# ── Full Reset ────────────────────────────────────────────────────
func reset_game() -> void:
	score = 0
	lives = MAX_LIVES
	level = STARTING_LEVEL
	emit_signal("score_changed", score)
	emit_signal("lives_changed", lives)
	emit_signal("level_changed", level)

# ── Persistence ───────────────────────────────────────────────────
func _save() -> void:
	_config.set_value("player", "high_score", high_score)
	_config.save(SAVE_PATH)

func _load_save() -> void:
	if _config.load(SAVE_PATH) == OK:
		high_score = _config.get_value("player", "high_score", 0)
