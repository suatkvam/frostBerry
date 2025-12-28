extends Node
class_name RewindComponent

# ═══════════════════════════════════════════════════════════
# REWIND COMPONENT
# ═══════════════════════════════════════════════════════════
# Bu component enemy, platform veya diğer objelere eklenir.
# Her frame'de durumu kaydeder ve rewind tetiklendiğinde geri sarar.
# ═══════════════════════════════════════════════════════════

signal rewind_started()
signal rewind_finished()

# Ayarlar
@export var max_history_seconds: float = 5.0  # Kaç saniye geriye gidebilir
@export var record_interval: float = 0.016  # ~60 FPS (her frame kaydet)
@export var enabled: bool = true  # Bu obje rewind'e dahil mi?

# State snapshot yapısı
class StateSnapshot:
	var timestamp: float
	var position: Vector2
	var velocity: Vector2
	var rotation: float
	var scale: Vector2
	var animation: String
	var animation_frame: int
	var flip_h: bool
	var custom_data: Dictionary  # Özel veriler için
	
	func _init(_timestamp: float = 0.0):
		timestamp = _timestamp
		position = Vector2.ZERO
		velocity = Vector2.ZERO
		rotation = 0.0
		scale = Vector2.ONE
		animation = ""
		animation_frame = 0
		flip_h = false
		custom_data = {}

# History buffer
var state_history: Array[StateSnapshot] = []
var max_snapshots: int = 300  # 5 saniye * 60 FPS
var record_timer: float = 0.0
var is_rewinding: bool = false
var rewind_accumulator: float = 0.0  # Rewind hızı için accumulator

# Parent referansları
var parent_node: Node2D
var animated_sprite: AnimatedSprite2D
var character_body: CharacterBody2D

func _ready() -> void:
	parent_node = get_parent()
	
	if not parent_node is Node2D:
		print("⚠ RewindComponent: Parent Node2D değil!")
		enabled = false
		return
	
	# AnimatedSprite2D bul
	animated_sprite = _find_animated_sprite(parent_node)
	
	# CharacterBody2D mi kontrol et
	if parent_node is CharacterBody2D:
		character_body = parent_node as CharacterBody2D
	
	# Max snapshot sayısını hesapla
	max_snapshots = int(max_history_seconds / record_interval)
	
	# RewindManager'a kayıt ol
	var rewind_manager = get_tree().get_first_node_in_group("rewind_manager")
	if rewind_manager and rewind_manager.has_method("register_rewindable"):
		rewind_manager.register_rewindable(self)
		print("✓ RewindComponent: ", parent_node.name, " kaydedildi")
	else:
		print("⚠ RewindComponent: RewindManager bulunamadı!")

func _find_animated_sprite(node: Node) -> AnimatedSprite2D:
	if node is AnimatedSprite2D:
		return node
	for child in node.get_children():
		if child is AnimatedSprite2D:
			return child
		var result = _find_animated_sprite(child)
		if result:
			return result
	return null

func _physics_process(delta: float) -> void:
	if not enabled or is_rewinding:
		return
	
	# Kayıt timer'ı
	record_timer += delta
	if record_timer >= record_interval:
		record_state()
		record_timer = 0.0

func record_state() -> void:
	var snapshot = StateSnapshot.new(Time.get_ticks_msec() / 1000.0)
	
	# Pozisyon ve transform
	snapshot.position = parent_node.global_position
	snapshot.rotation = parent_node.rotation
	snapshot.scale = parent_node.scale
	
	# Velocity (eğer CharacterBody2D ise)
	if character_body:
		snapshot.velocity = character_body.velocity
	
	# Animasyon durumu
	if animated_sprite:
		snapshot.animation = animated_sprite.animation
		snapshot.animation_frame = animated_sprite.frame
		snapshot.flip_h = animated_sprite.flip_h
	
	# Custom data (override edilebilir)
	snapshot.custom_data = capture_custom_data()
	
	# History'ye ekle
	state_history.append(snapshot)
	
	# Eski snapshot'ları sil
	while state_history.size() > max_snapshots:
		state_history.pop_front()

# Override edilebilir - özel veriler için
func capture_custom_data() -> Dictionary:
	var data = {}
	
	# Enemy için özel veriler
	if parent_node.has_method("get_current_state"):
		data["enemy_state"] = parent_node.get_current_state()

	# Moving platform için
	if "direction" in parent_node:
		data["direction"] = parent_node.direction
	if "wait_timer" in parent_node:
		data["wait_timer"] = parent_node.wait_timer
	
	return data

# Rewind başlat (RewindManager tarafından çağrılır)
func start_rewind(rewind_duration: float) -> void:
	if state_history.is_empty():
		print("⚠ RewindComponent: History boş, rewind yapılamıyor")
		return
	
	is_rewinding = true
	rewind_started.emit()
	print("▶ REWIND BAŞLADI: ", parent_node.name)

# Rewind sırasında her frame (RewindManager tarafından çağrılır)
func apply_rewind(playback_speed: float, delta: float) -> void:
	if state_history.is_empty():
		return

	# Rewind hızı ile accumulator artır
	rewind_accumulator += playback_speed * delta

	# record_interval'e göre snapshot pop et (60 FPS → 0.016s)
	while rewind_accumulator >= record_interval and not state_history.is_empty():
		var snapshot = state_history.pop_back()
		apply_snapshot(snapshot)
		rewind_accumulator -= record_interval

# Snapshot'ı uygula
func apply_snapshot(snapshot: StateSnapshot) -> void:
	# Pozisyon ve transform
	parent_node.global_position = snapshot.position
	parent_node.rotation = snapshot.rotation
	parent_node.scale = snapshot.scale
	
	# Velocity
	if character_body:
		character_body.velocity = snapshot.velocity
	
	# Animasyon
	if animated_sprite:
		if animated_sprite.sprite_frames.has_animation(snapshot.animation):
			animated_sprite.animation = snapshot.animation
			animated_sprite.frame = snapshot.animation_frame
			animated_sprite.flip_h = snapshot.flip_h
	
	# Custom data uygula
	apply_custom_data(snapshot.custom_data)

# Override edilebilir
func apply_custom_data(data: Dictionary) -> void:
	# Enemy state
	if data.has("enemy_state") and parent_node.has_method("set_current_state"):
		parent_node.set_current_state(data["enemy_state"])

	# Moving platform
	if data.has("direction") and "direction" in parent_node:
		parent_node.direction = data["direction"]
	if data.has("wait_timer") and "wait_timer" in parent_node:
		parent_node.wait_timer = data["wait_timer"]

# Rewind bitir (RewindManager tarafından çağrılır)
func stop_rewind() -> void:
	is_rewinding = false
	rewind_accumulator = 0.0  # Accumulator'ı sıfırla
	rewind_finished.emit()
	print("▶ REWIND BİTTİ: ", parent_node.name)

# History'yi temizle
func clear_history() -> void:
	state_history.clear()
	print("RewindComponent: History temizlendi - ", parent_node.name)

# Debug: kaç snapshot var?
func get_history_size() -> int:
	return state_history.size()

func get_max_rewind_time() -> float:
	return state_history.size() * record_interval
