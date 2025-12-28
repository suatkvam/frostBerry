extends Node2D

@export var target_platform: Node
@onready var sprite = $Sprite2D
@onready var area = $Area2D

var is_active = false

func _ready() -> void:
	check_activation()

func _physics_process(_delta: float) -> void:
	# Her fizik karesinde "Kimse var mı?" diye sorar
	check_activation()

# Signal'leri sadece tetikleyici olarak kullanıyoruz
func _on_area_2d_body_entered(_body): check_activation()
func _on_area_2d_body_exited(_body): check_activation()

func check_activation() -> void:
	var bodies = area.get_overlapping_bodies()
	var found_valid_body = false
	
	for body in bodies:
		if is_valid_body(body):
			found_valid_body = true
			break
	
	if found_valid_body and not is_active:
		activate()
	elif not found_valid_body and is_active:
		deactivate()

func is_valid_body(body: Node) -> bool:
	# Hem Player grubunu, hem Character ismini, hem de Ghost ismini kabul et
	return body.is_in_group("player") or body.is_in_group("Player") or body.name.begins_with("PlayerGhost") or body.name == "Character"

func activate() -> void:
	is_active = true
	if target_platform and target_platform.has_method("activate"):
		target_platform.activate()
	sprite.modulate = Color(0.5, 1.0, 0.5)
	sprite.position.y += 2

func deactivate() -> void:
	is_active = false
	if target_platform and target_platform.has_method("deactivate"):
		target_platform.deactivate()
	sprite.modulate = Color(1.0, 1.0, 1.0)
	sprite.position.y -= 2