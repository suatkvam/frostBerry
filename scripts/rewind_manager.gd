extends Node

# ═══════════════════════════════════════════════════════════
# REWIND MANAGER
# ═══════════════════════════════════════════════════════════
# Shift basılı tutulduğunda:
#   1. Player'ın bulunduğu pozisyonda collision'lı gölge bırakır
#   2. Player zamanda geriye gider (max 4 saniye)
#   3. Tüm enemy ve objeler donar
# Shift bırakıldığında normal akışa döner
# ═══════════════════════════════════════════════════════════

signal rewind_started()
signal rewind_stopped()

# Ayarlar
@export var max_rewind_duration: float = 4.0  # Maksimum 4 saniye geri gidebilir
@export var rewind_input_action: String = "rewind"  # Input action name
@export var ghost_opacity: float = 0.5  # Gölge opaklığı
@export var ghost_color: Color = Color(0.5, 0.5, 1.0, 0.5)  # Mavi tonlu gölge
@export var max_ghosts: int = 3  # Maksimum ghost sayısı
@export var rewind_playback_speed: float = 1.0  # Rewind oynatma hızı (1.0 = normal, 2.0 = 2x hızlı)
@export var ghost_duration: float = 8.0  # Ghost'ların yaşam süresi (saniye, 0 = sınırsız)
@export var ghost_health: float = 1.0  # Ghost'ların can miktarı (1 = tek vuruşta ölür)

# State
var is_rewinding: bool = false
var rewind_time: float = 0.0
var ghost_nodes: Array[Node2D] = []  # Player'ın bıraktığı gölgeler (max 3)

# Kayıtlı component'ler
var rewindable_objects: Array[RewindComponent] = []
var player: CharacterBody2D = null
var player_rewind_component: RewindComponent = null
var player_energy_component: RewindEnergyComponent = null

# Frozen objeler
var frozen_enemies: Array = []
var frozen_objects: Array = []

func _ready() -> void:
	add_to_group("rewind_manager")
	print("╔═══════════════════════════════════════╗")
	print("║   REWIND MANAGER BAŞLATILIYOR       ║")
	print("╚═══════════════════════════════════════╝")

	# Player'ı bul
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")

	if player:
		print("  ✓ Player bulundu:", player.name)
	else:
		print("  ✗ Player bulunamadı!")

# RewindComponent'leri kaydet
func register_rewindable(component: RewindComponent) -> void:
	if component not in rewindable_objects:
		rewindable_objects.append(component)

		# Player'ın component'ini özel olarak sakla
		if component.parent_node == player:
			player_rewind_component = component
			print("  ✓ Player RewindComponent kaydedildi")

# RewindComponent kaydını sil
func unregister_rewindable(component: RewindComponent) -> void:
	rewindable_objects.erase(component)

func _process(delta: float) -> void:
	# Rewind input kontrolü
	if Input.is_action_just_pressed(rewind_input_action):
		start_rewind()
	elif Input.is_action_pressed(rewind_input_action) and is_rewinding:
		update_rewind(delta)
	elif Input.is_action_just_released(rewind_input_action) and is_rewinding:
		stop_rewind()

func start_rewind() -> void:
	# Player'ı lazy olarak bul
	if not player:
		player = get_tree().get_first_node_in_group("player")

	# Player'ın rewind component'ini bul
	if not player_rewind_component:
		for comp in rewindable_objects:
			if not is_instance_valid(comp): continue
			if comp.parent_node == player or comp.parent_node.is_in_group("player"):
				player_rewind_component = comp
				player = comp.parent_node
				print("  ✓ Player RewindComponent bulundu!")
				break

	# Energy component'i bul
	if not player_energy_component and player:
		if player.has_node("RewindEnergyComponent"):
			player_energy_component = player.get_node("RewindEnergyComponent")
			print("  ✓ Player RewindEnergyComponent bulundu!")

	if not player or not player_rewind_component:
		print("⚠ RewindManager: Player veya RewindComponent yok!")
		return

	# ENERJİ KONTROLÜ - Enerji yoksa rewind başlatma!
	if player_energy_component and not player_energy_component.has_energy():
		print("⚠ RewindManager: Rewind enerjisi yok! (0/", player_energy_component.max_energy, "s)")
		return

	# Player'ın history'si var mı kontrol et
	if player_rewind_component.get_history_size() == 0:
		print("⚠ RewindManager: Player history boş, rewind yapılamıyor")
		return

	print("╔═══════════════════════════════════════╗")
	print("║   REWIND BAŞLADI!                   ║")
	print("╚═══════════════════════════════════════╝")

	is_rewinding = true
	rewind_time = 0.0
	rewind_started.emit()

	# 1. Player'ın bulunduğu pozisyonda gölge oluştur
	create_player_ghost()

	# 2. Tüm enemy'leri ve objeleri dondur
	freeze_world()

	# 3. Tüm rewindable objelere rewind başlat sinyali gönder
	for component in rewindable_objects:
		if is_instance_valid(component):
			component.start_rewind(max_rewind_duration)

func update_rewind(delta: float) -> void:
	rewind_time += delta

	# ENERJİ TÜKETİMİ - Shift basılıyken her frame enerji azalır
	if player_energy_component:
		player_energy_component.consume_energy(delta)

		# Enerji bitti mi? Otomatik durdur!
		if not player_energy_component.has_energy():
			print("  ⚠ Rewind enerjisi tükendi!")
			stop_rewind()
			return

	# Maksimum süreyi aştı mı?
	if rewind_time >= max_rewind_duration:
		print("  ⚠ Maksimum rewind süresi aşıldı (", max_rewind_duration, "s)")
		stop_rewind()
		return

	# Player'ın history'si bitti mi?
	if player_rewind_component and player_rewind_component.get_history_size() == 0:
		print("  ⚠ Player history bitti")
		stop_rewind()
		return

	# Tüm rewindable objelere snapshot uygula
	for component in rewindable_objects:
		if is_instance_valid(component) and component.enabled:
			component.apply_rewind(rewind_playback_speed, delta)

func stop_rewind() -> void:
	if not is_rewinding:
		return

	print("╔═══════════════════════════════════════╗")
	print("║   REWIND DURDU! (%0.1fs)             ║" % rewind_time)
	print("╚═══════════════════════════════════════╝")

	is_rewinding = false
	rewind_stopped.emit()

	# 1. Tüm rewindable objelere rewind durdur sinyali
	for component in rewindable_objects:
		if is_instance_valid(component):
			component.stop_rewind()

	# 2. Dünyayı unfreeze et
	unfreeze_world()

	# 3. Gölgeyi SİLME - parkour için kalmalı!
	# Ghost node sahnede kalacak

# Player gölgesi oluştur
func create_player_ghost() -> void:
	if not player:
		return

	# Maksimum ghost sayısı kontrolü - 3'ten fazlaysa en eskisini sil
	if ghost_nodes.size() >= max_ghosts:
		var oldest_ghost = ghost_nodes.pop_front()  # En eski ghost'u çıkar
		if oldest_ghost and is_instance_valid(oldest_ghost):
			oldest_ghost.queue_free()
			print("  ► En eski ghost silindi (max: ", max_ghosts, ")")

	# CharacterBody2D kullanıyoruz
	var new_ghost = CharacterBody2D.new()
	new_ghost.name = "PlayerGhost_" + str(Time.get_ticks_msec())
	new_ghost.add_to_group("player") # Player grubuna ekle
	new_ghost.add_to_group("ghost") # Ghost grubuna da ekle (enemy detection için)

	# Layer 1 ve 2'yi kapsayan Layer 3 (Binary 11)
	new_ghost.collision_layer = 3
	new_ghost.collision_mask = 0

	new_ghost.global_position = player.global_position
	
	# Şekli ve Transformu kopyala
	var player_coll = player.get_node_or_null("CollisionShape2D")
	if player_coll and player_coll.shape:
		var coll_shape = CollisionShape2D.new()
		coll_shape.name = "CollisionShape2D"
		coll_shape.shape = player_coll.shape.duplicate()
		coll_shape.transform = player_coll.transform # ÖNEMLİ: Offset'i kopyala
		new_ghost.add_child(coll_shape)

	# Sprite kopyala (görsel)
	var player_sprite = player.get_node_or_null("AnimatedSprite2D")
	if player_sprite:
		var ghost_sprite = AnimatedSprite2D.new()
		ghost_sprite.sprite_frames = player_sprite.sprite_frames
		ghost_sprite.animation = player_sprite.animation
		ghost_sprite.frame = player_sprite.frame
		ghost_sprite.flip_h = player_sprite.flip_h

		# Yarı saydam mavi renk
		ghost_sprite.modulate = ghost_color

		new_ghost.add_child(ghost_sprite)

	# HealthComponent ekle (ghost can sistemi)
	var health_comp = HealthComponent.new()
	health_comp.name = "HealthComponent"
	health_comp.max_health = int(ghost_health)
	health_comp.current_health = int(ghost_health)
	new_ghost.add_child(health_comp)

	# HurtboxComponent ekle (ghost hasar alabilir)
	var hurtbox_comp = HurtboxComponent.new()
	hurtbox_comp.name = "HurtboxComponent"
	hurtbox_comp.health_component_path = NodePath("../HealthComponent")
	hurtbox_comp.can_be_knocked_back = false  # Ghost knockback almaz
	new_ghost.add_child(hurtbox_comp)

	# Ghost öldüğünde sil
	health_comp.died.connect(func():
		if new_ghost and is_instance_valid(new_ghost):
			ghost_nodes.erase(new_ghost)
			new_ghost.queue_free()
			print("  ✗ Ghost öldürüldü!")
	)

	# Sahneye güvenli ekle
	player.get_parent().call_deferred("add_child", new_ghost)
	ghost_nodes.append(new_ghost)  # Array'e ekle

	# Ghost duration - otomatik silinme timer'ı
	if ghost_duration > 0:
		var timer = Timer.new()
		timer.wait_time = ghost_duration
		timer.one_shot = true
		timer.autostart = true # Sahneye girince otomatik başlasın
		timer.timeout.connect(func():
			if new_ghost and is_instance_valid(new_ghost):
				ghost_nodes.erase(new_ghost)  # Array'den çıkar
				new_ghost.queue_free()  # Sil
				print("  ✗ Ghost yaşam süresi doldu, silindi (", ghost_duration, "s)")
		)
		new_ghost.add_child(timer)

	print("  ✓ Player ghost oluşturuldu: ", new_ghost.global_position, " (", ghost_nodes.size(), "/", max_ghosts, ", duration: ", ghost_duration, "s)")


# Dünyayı dondur
func freeze_world() -> void:
	print("  ► Dünya donduruluyor...")

	# Enemy'leri dondur
	frozen_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in frozen_enemies:
		if enemy.has_method("freeze"):
			enemy.freeze()
			print("    ✓ Enemy donduruldu: ", enemy.name)

	# Diğer objeleri dondur (platformlar, trap'ler vs.)
	# TODO: Eğer moving platform'larda freeze metodu varsa çağır
	var moving_platforms = get_tree().get_nodes_in_group("moving_platforms")
	for platform in moving_platforms:
		if platform.has_method("freeze"):
			platform.freeze()
			frozen_objects.append(platform)

	print("  ✓ %d enemy, %d obje donduruldu" % [frozen_enemies.size(), frozen_objects.size()])

# Dünyayı unfreeze et
func unfreeze_world() -> void:
	print("  ► Dünya çözülüyor...")

	# Enemy'leri unfreeze et
	for enemy in frozen_enemies:
		if enemy and is_instance_valid(enemy) and enemy.has_method("unfreeze"):
			enemy.unfreeze()
			print("    ✓ Enemy çözüldü: ", enemy.name)

	# Diğer objeleri unfreeze et
	for obj in frozen_objects:
		if obj and is_instance_valid(obj) and obj.has_method("unfreeze"):
			obj.unfreeze()

	frozen_enemies.clear()
	frozen_objects.clear()

	print("  ✓ Dünya çözüldü")

# Debug: Rewind state
func get_rewind_state() -> Dictionary:
	return {
		"is_rewinding": is_rewinding,
		"rewind_time": rewind_time,
		"registered_objects": rewindable_objects.size(),
		"player_history_size": player_rewind_component.get_history_size() if player_rewind_component else 0,
		"frozen_enemies": frozen_enemies.size(),
		"frozen_objects": frozen_objects.size()
	}
