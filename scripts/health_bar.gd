extends ProgressBar
class_name HealthBar

# ═══════════════════════════════════════════════════════════
# HEALTH BAR - Can Barı
# ═══════════════════════════════════════════════════════════
# ProgressBar node'una eklenir.
# Player'ın HealthComponent'ini dinler ve can barını günceller.
# ═══════════════════════════════════════════════════════════

# Ayarlar
@export var player_path: NodePath  # Player node'unun path'i (Inspector'dan ayarla)
@export var smooth_transition: bool = true  # Yumuşak geçiş
@export var transition_speed: float = 5.0  # Geçiş hızı
@export var show_numbers: bool = true  # "50/100" gibi text göster
@export var damage_flash_color: Color = Color(1, 0, 0, 0.3)  # Hasar aldığında kırmızı flaş
@export var heal_flash_color: Color = Color(0, 1, 0, 0.3)  # İyileştiğinde yeşil flaş
@export var flash_duration: float = 0.2  # Flaş süresi

# Referanslar
var player: Node2D
var health_component: HealthComponent
var target_value: float = 100.0
var is_flashing: bool = false
var flash_timer: float = 0.0
var current_flash_color: Color = Color.WHITE

# Label (opsiyonel - eğer ProgressBar'ın child'ı olarak Label varsa)
var health_label: Label

func _ready() -> void:
	# Player'ı bul
	if player_path:
		player = get_node(player_path)
	else:
		# Otomatik bul
		player = get_tree().get_first_node_in_group("player")
	
	if not player:
		print("⚠ HealthBar: Player bulunamadı!")
		return
	
	# HealthComponent'i bul
	health_component = player.get_node("HealthComponent") if player.has_node("HealthComponent") else null
	
	if not health_component:
		print("⚠ HealthBar: Player'da HealthComponent bulunamadı!")
		return
	
	# HealthComponent sinyallerini dinle
	health_component.health_changed.connect(_on_health_changed)
	health_component.damage_taken.connect(_on_damage_taken)
	health_component.healed.connect(_on_healed)
	health_component.died.connect(_on_player_died)
	
	# İlk değerleri ayarla
	max_value = health_component.max_health
	value = health_component.current_health
	target_value = value
	
	# Label'i bul (eğer varsa)
	health_label = _find_label(self)
	
	# İlk text'i ayarla
	update_health_text()
	
	print("✓ HealthBar: Bağlandı - ", player.name)
	print("  Can: ", health_component.current_health, "/", health_component.max_health)

func _find_label(node: Node) -> Label:
	if node is Label:
		return node
	for child in node.get_children():
		if child is Label:
			return child
		var result = _find_label(child)
		if result:
			return result
	return null

func _process(delta: float) -> void:
	# Yumuşak geçiş
	if smooth_transition and abs(value - target_value) > 0.1:
		value = lerp(value, target_value, transition_speed * delta)
	elif not smooth_transition:
		value = target_value
	
	# Flaş efekti
	if is_flashing:
		flash_timer -= delta
		if flash_timer <= 0:
			is_flashing = false
			modulate = Color.WHITE
			update_bar_color()  # Flaş bittikten sonra normal renge dön
		else:
			# Flaş alpha'sını azalt
			var alpha = flash_timer / flash_duration
			modulate = Color.WHITE.lerp(current_flash_color, alpha)
	else:
		# Flaş yoksa gradient renk uygula
		update_bar_color()

# Can yüzdesine göre renk değiştir (yeşil → sarı → kırmızı)
func update_bar_color() -> void:
	var percentage = get_health_percentage()
	
	if percentage >= 66.0:
		# Yüksek can: Yeşil
		modulate = Color(0.2, 1.0, 0.2, 1.0)
	elif percentage >= 33.0:
		# Orta can: Sarı
		modulate = Color(1.0, 1.0, 0.2, 1.0)
	else:
		# Düşük can: Kırmızı
		modulate = Color(1.0, 0.2, 0.2, 1.0)

# HealthComponent sinyalleri
func _on_health_changed(current_health: int, max_health: int) -> void:
	max_value = max_health
	target_value = float(current_health)
	update_health_text()
	
	# Debug
	# print("HealthBar: Güncellendi - ", current_health, "/", max_health)

func _on_damage_taken(amount: int) -> void:
	# Hasar flaş efekti
	trigger_flash(damage_flash_color)
	print("HealthBar: ", amount, " hasar alındı!")

func _on_healed(amount: int) -> void:
	# İyileşme flaş efekti
	trigger_flash(heal_flash_color)
	print("HealthBar: ", amount, " can yenilendi!")

func _on_player_died() -> void:
	print("HealthBar: Player öldü - can barı sıfırlandı")
	target_value = 0.0

# Flaş efekti
func trigger_flash(color: Color) -> void:
	is_flashing = true
	flash_timer = flash_duration
	current_flash_color = color
	modulate = color

# Health text güncelle
func update_health_text() -> void:
	if not show_numbers or not health_label:
		return
	
	if health_component:
		health_label.text = "%d / %d" % [int(target_value), health_component.max_health]

# Public metodlar - dışarıdan çağrılabilir
func set_player(new_player: Node2D) -> void:
	if player and health_component:
		# Eski sinyalleri kopar
		if health_component.health_changed.is_connected(_on_health_changed):
			health_component.health_changed.disconnect(_on_health_changed)
		if health_component.damage_taken.is_connected(_on_damage_taken):
			health_component.damage_taken.disconnect(_on_damage_taken)
		if health_component.healed.is_connected(_on_healed):
			health_component.healed.disconnect(_on_healed)
		if health_component.died.is_connected(_on_player_died):
			health_component.died.disconnect(_on_player_died)
	
	player = new_player
	health_component = player.get_node("HealthComponent") if player.has_node("HealthComponent") else null
	
	if health_component:
		# Yeni sinyalleri bağla
		health_component.health_changed.connect(_on_health_changed)
		health_component.damage_taken.connect(_on_damage_taken)
		health_component.healed.connect(_on_healed)
		health_component.died.connect(_on_player_died)
		
		# Değerleri güncelle
		max_value = health_component.max_health
		value = health_component.current_health
		target_value = value
		update_health_text()
		
		print("✓ HealthBar: Yeni player bağlandı - ", player.name)

func get_current_health() -> int:
	return int(target_value)

func get_max_health() -> int:
	return int(max_value)

func get_health_percentage() -> float:
	if max_value <= 0:
		return 0.0
	return (target_value / max_value) * 100.0
