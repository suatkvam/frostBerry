extends Node
class_name HealthComponent

# Sinyaller
signal health_changed(current_health: int, max_health: int)
signal damage_taken(amount: int)
signal healed(amount: int)
signal died()

# Health özellikleri
@export var max_health: int = 100
@export var current_health: int = 100
@export var invincibility_duration: float = 0.0  # Hasar alındıktan sonra geçici dokunulmazlık

var is_invincible: bool = false
var invincibility_timer: float = 0.0

func _ready() -> void:
	current_health = max_health

func _process(delta: float) -> void:
	# Geçici dokunulmazlık sayacı
	if is_invincible:
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			is_invincible = false

func take_damage(amount: int) -> void:
	if is_invincible or current_health <= 0:
		return
	
	current_health = max(0, current_health - amount)
	damage_taken.emit(amount)
	health_changed.emit(current_health, max_health)
	
	print("HealthComponent: %d hasar alındı! Kalan can: %d/%d" % [amount, current_health, max_health])
	
	# Geçici dokunulmazlık başlat
	if invincibility_duration > 0:
		is_invincible = true
		invincibility_timer = invincibility_duration
	
	# Ölüm kontrolü
	if current_health <= 0:
		die()

func heal(amount: int) -> void:
	if current_health <= 0:
		return
	
	var old_health = current_health
	current_health = min(max_health, current_health + amount)
	var actual_heal = current_health - old_health
	
	if actual_heal > 0:
		healed.emit(actual_heal)
		health_changed.emit(current_health, max_health)
		print("HealthComponent: %d can yenilendi! Can: %d/%d" % [actual_heal, current_health, max_health])

func die() -> void:
	print("HealthComponent: Öldü!")
	died.emit()

func is_alive() -> bool:
	return current_health > 0

func get_health_percentage() -> float:
	return float(current_health) / float(max_health) * 100.0
