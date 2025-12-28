extends Control

@onready var message_label: Label = $CenterContainer/VBoxContainer/MessageLabel
@onready var subtitle_label: Label = $CenterContainer/VBoxContainer/SubtitleLabel

func _ready() -> void:
	# Mesajı ayarla - 3 satır, son satır büyük harfle
	message_label.text = "I can finally go back to how\n"
	message_label.text = "nothings were before\n"
	message_label.text = "THE LIGHT BULB\n"
	subtitle_label.text = "- The End -"

	# Fade-in efekti
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 2.0)

	print("╔════════════════════════════════════╗")
	print("║         OYUN BİTTİ!               ║")
	print("╚════════════════════════════════════╝")

func _input(event: InputEvent) -> void:
	# Herhangi bir tuşa basınca ana menüye dön (veya oyunu kapat)
	if event.is_pressed():
		get_tree().quit()
