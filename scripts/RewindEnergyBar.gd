extends ProgressBar
class_name RewindEnergyBar

# ═══════════════════════════════════════════════════════════
# REWIND ENERGY BAR - Mavi Enerji Barı
# ═══════════════════════════════════════════════════════════
# Rewind enerjisini gösteren mavi progress bar.
# Shift basılıyken azalır, kristal toplayınca artar.
# ═══════════════════════════════════════════════════════════

# Ayarlar
@export var player_path: NodePath  # Player node'unun path'i
@export var smooth_transition: bool = true  # Yumuşak geçiş
@export var transition_speed: float = 5.0  # Geçiş hızı
@export var show_numbers: bool = true  # "2.5s" göster
@export var bar_color: Color = Color(0.2, 0.5, 1.0, 1.0)  # Mavi renk

# Referanslar
var player: Node2D
var energy_component: RewindEnergyComponent
var target_value: float = 4.0

# Label (opsiyonel)
var energy_label: Label

func _ready() -> void:
	# Player'ı bul
	if player_path:
		player = get_node(player_path)
	else:
		player = get_tree().get_first_node_in_group("player")
	
	if not player:
		print("⚠ RewindEnergyBar: Player bulunamadı!")
		return
	
	# RewindEnergyComponent'i bul
	energy_component = player.get_node("RewindEnergyComponent") if player.has_node("RewindEnergyComponent") else null
	
	if not energy_component:
		print("⚠ RewindEnergyBar: RewindEnergyComponent bulunamadı!")
		return
	
	# Sinyalleri bağla
	energy_component.energy_changed.connect(_on_energy_changed)
	energy_component.energy_depleted.connect(_on_energy_depleted)
	energy_component.energy_restored.connect(_on_energy_restored)
	
	# İlk değerleri ayarla
	max_value = energy_component.max_energy
	value = energy_component.current_energy
	target_value = value
	
	# Mavi rengi uygula
	modulate = bar_color
	
	# Label'i bul
	energy_label = _find_label(self)
	
	# İlk text'i ayarla
	update_energy_text()
	
	print("✓ RewindEnergyBar: Bağlandı - ", player.name)
	print("  Enerji: ", energy_component.current_energy, "/", energy_component.max_energy, "s")

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
	if smooth_transition and abs(value - target_value) > 0.01:
		value = lerp(value, target_value, transition_speed * delta)
	else:
		value = target_value

# Energy Component sinyalleri
func _on_energy_changed(current_energy: float, max_energy: float) -> void:
	max_value = max_energy
	target_value = current_energy
	update_energy_text()

func _on_energy_depleted() -> void:
	print("RewindEnergyBar: Enerji bitti!")
	# Opsiyonel: Görsel feedback (örn: yanıp sönme)
	flash_bar()

func _on_energy_restored() -> void:
	print("RewindEnergyBar: Enerji geri geldi!")

# Görsel feedback
func flash_bar() -> void:
	# Kırmızıya dön, sonra tekrar maviye
	var original_color = modulate
	modulate = Color(1, 0.2, 0.2, 1.0)  # Kırmızı
	await get_tree().create_timer(0.2).timeout
	modulate = original_color  # Mavi

# Text güncelle
func update_energy_text() -> void:
	if not show_numbers or not energy_label:
		return
	
	if energy_component:
		# Sadece saniye göster
		energy_label.text = "%.1fs" % target_value
		
		# veya maksimum ile birlikte:
		# energy_label.text = "%.1f / %.1f" % [target_value, energy_component.max_energy]

# Public metodlar
func set_player(new_player: Node2D) -> void:
	if player and energy_component:
		# Eski sinyalleri kopar
		if energy_component.energy_changed.is_connected(_on_energy_changed):
			energy_component.energy_changed.disconnect(_on_energy_changed)
		if energy_component.energy_depleted.is_connected(_on_energy_depleted):
			energy_component.energy_depleted.disconnect(_on_energy_depleted)
		if energy_component.energy_restored.is_connected(_on_energy_restored):
			energy_component.energy_restored.disconnect(_on_energy_restored)
	
	player = new_player
	energy_component = player.get_node("RewindEnergyComponent") if player.has_node("RewindEnergyComponent") else null
	
	if energy_component:
		energy_component.energy_changed.connect(_on_energy_changed)
		energy_component.energy_depleted.connect(_on_energy_depleted)
		energy_component.energy_restored.connect(_on_energy_restored)
		
		max_value = energy_component.max_energy
		value = energy_component.current_energy
		target_value = value
		modulate = bar_color
		update_energy_text()
		
		print("✓ RewindEnergyBar: Yeni player bağlandı - ", player.name)

func get_current_energy() -> float:
	return target_value

func get_max_energy() -> float:
	return max_value

func get_energy_percentage() -> float:
	if max_value <= 0:
		return 0.0
	return (target_value / max_value) * 100.0
