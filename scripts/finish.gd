extends Area2D

# Bitiş sahnesinin yolu
const END_SCENE_PATH = "res://scripts/finis_scene_text.tscn"

var is_triggered: bool = false

func _ready() -> void:
	# Body entered sinyalini bağla
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	print("✓ Finish area hazır")

func _on_body_entered(body: Node2D) -> void:
	# Zaten tetiklendiyse ignore
	if is_triggered:
		return

	# Player mı kontrol et
	if body.is_in_group("player") or body.name == "Character":
		is_triggered = true
		print("╔════════════════════════════════════╗")
		print("║   PLAYER FİNİSH'E ULAŞTI!         ║")
		print("╚════════════════════════════════════╝")

		# Finish'i görünmez yap ve collision'ı kapat
		visible = false
		set_deferred("monitoring", false)

		# Kısa bir gecikme sonra sahneyi değiştir
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file(END_SCENE_PATH)
