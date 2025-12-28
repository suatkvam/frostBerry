extends StaticBody2D

@onready var collision_shape = $CollisionShape2D
@onready var sprite = $Sprite2D

func _ready():
	# Başlangıçta kapı kapalı
	close()

func activate():
	# Basınç plakası tetiklendiğinde kapı açılır
	open()

func deactivate():
	# Basınç plakası bırakıldığında kapı kapanır
	close()

func open():
	# Görseli ve çarpışmayı kapat
	sprite.visible = false
	collision_shape.set_deferred("disabled", true)
	print("Door: OPEN")

func close():
	# Görseli ve çarpışmayı aç
	sprite.visible = true
	collision_shape.set_deferred("disabled", false)
	print("Door: CLOSED")
