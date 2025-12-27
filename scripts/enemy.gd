extends CharacterBody2D

enum State { PATROL, CHASE, ATTACK, HITSTUN, COOLDOWN }

# Constants
const SPEED = 150.0
const PATROL_RANGE = 150.0
const DETECTION_RADIUS = 230.0
const CHASE_EXTENSION = 150.0
const ATTACK_DAMAGE = 10
const ATTACK_COOLDOWN = 0.5
const KNOCKBACK_RECOVERY = 0.4
const AFTER_HIT_WAIT = 1.0
const AFTER_DAMAGE_WAIT = 0.8

# ═══════════════════════════════════════════════════════════
# ÖLÜM ANİMASYONU SÜRESİ - BURADAN DEĞİŞTİREBİLİRSİN! 💀
# ═══════════════════════════════════════════════════════════
const DEATH_ANIMATION_DURATION = 1.7  # Saniye cinsinden
# ═══════════════════════════════════════════════════════════

# State
var current_state: State = State.PATROL
var spawn_position: Vector2
var chase_start_position: Vector2
var patrol_direction: int = 1
var attack_timer: float = 0.0
var player: CharacterBody2D = null
var returning_home: bool = false
var collision_damage_cooldown: float = 0.0
var is_in_hitstun: bool = false
var hitstun_timer: float = 0.0
var cooldown_timer: float = 0.0
var is_frozen: bool = false
var is_dead: bool = false
var is_attacking: bool = false
var hit_targets = []
var is_transitioning_to_chase: bool = false  # YENİ: chase transition flag

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var health_component: HealthComponent = $HealthComponent
@onready var enemy_attack_area: Area2D = $EnemyAttackArea
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var attack_sound: AudioStreamPlayer2D = $AttackSound

func _ready() -> void:
	add_to_group("enemies")
	spawn_position = global_position
	
	# Detection area
	if detection_area:
		if not detection_area.body_entered.is_connected(_on_detection_area_body_entered):
			detection_area.body_entered.connect(_on_detection_area_body_entered)
		if not detection_area.body_exited.is_connected(_on_detection_area_body_exited):
			detection_area.body_exited.connect(_on_detection_area_body_exited)
	
	# Animasyon sinyalleri
	if animated_sprite:
		if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)
		if not animated_sprite.frame_changed.is_connected(_on_frame_changed):
			animated_sprite.frame_changed.connect(_on_frame_changed)
	
	# Attack area
	if enemy_attack_area:
		enemy_attack_area.monitoring = false
		if not enemy_attack_area.body_entered.is_connected(_on_enemy_attack_area_body_entered):
			enemy_attack_area.body_entered.connect(_on_enemy_attack_area_body_entered)
	else:
		print("✗ HATA: EnemyAttackArea bulunamadı!")
	
	# İlk animasyon
	if animated_sprite.sprite_frames.has_animation("enemy_run"):
		animated_sprite.play("enemy_run")
	
	print("Enemy spawned at: ", spawn_position)
	
	# Health component
	if health_component:
		if not health_component.died.is_connected(_on_health_component_died):
			health_component.died.connect(_on_health_component_died)
		if not health_component.damage_taken.is_connected(_on_damage_taken):
			health_component.damage_taken.connect(_on_damage_taken)

	# Hurtbox component
	if hurtbox:
		hurtbox.hitstun_started.connect(_on_hitstun_started)
		hurtbox.hitstun_ended.connect(_on_hitstun_ended)
		print("Enemy: HurtboxComponent bağlandı")
	else:
		print("Enemy: HurtboxComponent BULUNAMADI!")

func _physics_process(delta: float) -> void:
	if is_dead or is_frozen:
		return
	
	# Sayaçlar
	if collision_damage_cooldown > 0:
		collision_damage_cooldown -= delta
	if hitstun_timer > 0:
		hitstun_timer -= delta
		if hitstun_timer <= 0:
			is_in_hitstun = false
			current_state = State.COOLDOWN
			cooldown_timer = AFTER_DAMAGE_WAIT
	if cooldown_timer > 0:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			# Cooldown bitti - player hala yakınsa CHASE, değilse PATROL
			if player != null:
				var distance_to_player = global_position.distance_to(player.global_position)
				if distance_to_player <= DETECTION_RADIUS:
					change_state(State.CHASE)
				else:
					change_state(State.PATROL)
			else:
				change_state(State.PATROL)

	# Hitstun
	if is_in_hitstun:
		if not is_on_floor():
			velocity += get_gravity() * delta
		velocity.x = move_toward(velocity.x, 0, SPEED * delta * 3)
		move_and_slide()
		return

	# Yerçekimi
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Cooldown
	if current_state == State.COOLDOWN:
		velocity.x = move_toward(velocity.x, 0, SPEED * 2)
		
		# Cooldown sırasında animasyon güncelle
		if abs(velocity.x) < 5.0:
			if animated_sprite.sprite_frames.has_animation("enemy_idle"):
				if animated_sprite.animation != "enemy_idle":
					animated_sprite.play("enemy_idle")
		
		move_and_slide()
		return

	# Saldırı animasyonu
	if is_attacking:
		velocity.x = 0
		move_and_slide()
		return

	# State
	match current_state:
		State.PATROL:
			patrol_behavior(delta)
		State.CHASE:
			chase_behavior(delta)
		State.ATTACK:
			attack_behavior(delta)

	move_and_slide()

func patrol_behavior(delta: float) -> void:
	# YENİ: transition sırasında animasyon güncelleme
	if is_transitioning_to_chase:
		velocity.x = 0  # Dur
		return
	
	velocity.x = patrol_direction * SPEED * 0.5
	var offset_from_spawn = global_position.x - spawn_position.x

	update_animation()

	if returning_home:
		if abs(offset_from_spawn) < PATROL_RANGE:
			returning_home = false

	if patrol_direction > 0 and offset_from_spawn >= PATROL_RANGE:
		patrol_direction = -1
		flip_sprite()
	elif patrol_direction < 0 and offset_from_spawn <= -PATROL_RANGE:
		patrol_direction = 1
		flip_sprite()

	if player != null and not returning_home:
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player <= DETECTION_RADIUS:
			change_state(State.CHASE)

func chase_behavior(delta: float) -> void:
	if player == null:
		change_state(State.PATROL)
		return

	update_animation()

	var offset_from_spawn = global_position.x - spawn_position.x
	var max_chase_distance = PATROL_RANGE + CHASE_EXTENSION

	if abs(offset_from_spawn) > max_chase_distance:
		returning_home = true
		change_state(State.PATROL)
		return

	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player > DETECTION_RADIUS * 1.2:
		change_state(State.PATROL)
		return

	var direction_to_player = player.global_position.x - global_position.x
	
	if abs(direction_to_player) > 5.0:
		var direction = sign(direction_to_player)
		velocity.x = direction * SPEED * 0.7
		
		if abs(direction_to_player) > 15.0:
			animated_sprite.flip_h = direction < 0
			if enemy_attack_area:
				enemy_attack_area.scale.x = -1 if direction < 0 else 1
	else:
		velocity.x = 0

	var distance_to_player_horiz = abs(direction_to_player)
	if distance_to_player_horiz < 80.0:  # 60 → 80 (daha uzaktan saldır)
		print("▶ CHASE → ATTACK (mesafe: ", distance_to_player_horiz, ")")
		change_state(State.ATTACK)

func attack_behavior(delta: float) -> void:
	# Player yoksa PATROL'e dön
	if player == null:
		change_state(State.PATROL)
		return
	
	# Player öldüyse idle'a geç ve bekle
	if player.has_method("is_alive") and not player.is_alive():
		velocity.x = 0
		if animated_sprite.sprite_frames.has_animation("enemy_idle"):
			if animated_sprite.animation != "enemy_idle":
				animated_sprite.play("enemy_idle")
		return
	
	# DEBUG: Her frame yazdırma, sadece state değişiminde
	# print("● ATTACK BEHAVIOR çalışıyor, mesafe: ", abs(player.global_position.x - global_position.x))

	velocity.x = 0

	var distance_to_player_horiz = abs(player.global_position.x - global_position.x)
	if distance_to_player_horiz > 100.0:  # 80 → 100 (daha geç bırak)
		print("▶ ATTACK → CHASE (çok uzak: ", distance_to_player_horiz, ")")
		change_state(State.CHASE)
		return

	# Player'a bak
	var direction_to_player = player.global_position.x - global_position.x
	animated_sprite.flip_h = direction_to_player < 0
	if enemy_attack_area:
		enemy_attack_area.scale.x = -1 if direction_to_player < 0 else 1
	
	# Saldırı
	if collision_damage_cooldown <= 0.0 and not is_attacking:
		perform_attack()
	elif collision_damage_cooldown > 0.0 and not is_attacking:
		# Cooldown aktif - idle'da bekle
		if animated_sprite.sprite_frames.has_animation("enemy_idle"):
			if animated_sprite.animation != "enemy_idle":
				animated_sprite.play("enemy_idle")

func perform_attack() -> void:
	print("═══ ENEMY SALDIRI BAŞLIYOR ═══")
	is_attacking = true
	hit_targets.clear()
	
	# ÇÖZÜM: Cooldown'u SALDIRI BAŞINDA set et, hit anında değil!
	collision_damage_cooldown = ATTACK_COOLDOWN
	print("► Cooldown başladı: ", ATTACK_COOLDOWN, " saniye")
	
	if animated_sprite.sprite_frames.has_animation("enemy_attack"):
		# Loop'u kapat
		animated_sprite.sprite_frames.set_animation_loop("enemy_attack", false)
		animated_sprite.play("enemy_attack")
		print("► enemy_attack oynatılıyor, loop: ", animated_sprite.sprite_frames.get_animation_loop("enemy_attack"))
	else:
		print("✗ HATA: enemy_attack animasyonu yok!")
		is_attacking = false

func update_animation() -> void:
	if not is_attacking and not is_dead and not is_transitioning_to_chase:  # YENİ: transition kontrolü eklendi
		# Eğer velocity 0 ise idle, değilse run
		if abs(velocity.x) < 5.0:
			if animated_sprite.sprite_frames.has_animation("enemy_idle"):
				if animated_sprite.animation != "enemy_idle":
					animated_sprite.play("enemy_idle")
			else:
				if animated_sprite.animation != "enemy_run":
					animated_sprite.play("enemy_run")
		else:
			if animated_sprite.animation != "enemy_run":
				animated_sprite.play("enemy_run")

func change_state(new_state: State) -> void:
	if current_state == new_state:
		return

	print("STATE: ", State.keys()[current_state], " → ", State.keys()[new_state])
	current_state = new_state

	match current_state:
		State.PATROL:
			var direction_to_spawn = sign(spawn_position.x - global_position.x)
			if direction_to_spawn != 0:
				patrol_direction = direction_to_spawn
				flip_sprite()
		State.CHASE:
			chase_start_position = global_position

func flip_sprite() -> void:
	animated_sprite.flip_h = patrol_direction < 0
	if enemy_attack_area:
		enemy_attack_area.scale.x = -1 if patrol_direction < 0 else 1

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Character":
		player = body
		print("► Player algılandı: ", body.name)
		
		# YENİ: Transition flag'i set et
		is_transitioning_to_chase = true
		
		# Player görüldüğünde idle'a geç
		if animated_sprite.sprite_frames.has_animation("enemy_idle"):
			animated_sprite.play("enemy_idle")
			# 0.3 saniye idle bekle, sonra chase başlat
			await get_tree().create_timer(0.3).timeout
			
			# YENİ: Transition flag'i kapat
			is_transitioning_to_chase = false
			
			if player != null and current_state == State.PATROL:
				change_state(State.CHASE)

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player:
		# Player öldüyse state değiştirme
		if player.has_method("is_alive") and not player.is_alive():
			print("► Player öldü, state değişmiyor")
			return
		
		player = null
		if current_state == State.CHASE or current_state == State.ATTACK:
			change_state(State.PATROL)

func _on_frame_changed() -> void:
	if is_dead:
		return
	
	var current_anim = animated_sprite.animation
	var current_frame = animated_sprite.frame
	
	if current_anim == "enemy_attack":
		print("  Frame: ", current_frame)
		if current_frame == 1:
			activate_enemy_attack()
		else:
			deactivate_enemy_attack()

func activate_enemy_attack() -> void:
	if enemy_attack_area and not enemy_attack_area.monitoring:
		enemy_attack_area.set_deferred("monitoring", true)
		print("  ╔═══ ATTACK AREA AKTİF ═══╗")

func deactivate_enemy_attack() -> void:
	if enemy_attack_area and enemy_attack_area.monitoring:
		enemy_attack_area.set_deferred("monitoring", false)
		print("  ╚═══ ATTACK AREA KAPANDI ═══╝")

func _on_enemy_attack_area_body_entered(body: Node2D) -> void:
	print("╔═══════════════════════════╗")
	print("║ ATTACK AREA: Body girdi!  ║")
	print("║ Body: ", body.name, " ║")
	print("╚═══════════════════════════╝")
	
	if body in hit_targets:
		print("⚠ Zaten vuruldu!")
		return
	
	if body.is_in_group("player") or body.name == "Character":
		# HurtboxComponent üzerinden hasar ver
		if body.has_node("HurtboxComponent"):
			var target_hurtbox = body.get_node("HurtboxComponent")
			print("💥 HASAR VERİLİYOR: ", ATTACK_DAMAGE)
			target_hurtbox.take_damage(ATTACK_DAMAGE, global_position)
			hit_targets.append(body)
			if attack_sound:
				attack_sound.play()
			print("  ✓ Hasar verildi, cooldown zaten aktif")
		else:
			print("✗ HurtboxComponent yok!")

# HITSTUN CALLBACK'LERİ
func _on_hitstun_started(duration: float) -> void:
	is_in_hitstun = true
	hitstun_timer = duration

	# Saldırıyı iptal et
	if is_attacking:
		is_attacking = false
		deactivate_enemy_attack()

	# State'i HITSTUN'a al
	current_state = State.HITSTUN

	print("Enemy: Hitstun başladı (%0.1fs)" % duration)

func _on_hitstun_ended() -> void:
	# Hitstun bitince COOLDOWN'a geç
	is_in_hitstun = false
	current_state = State.COOLDOWN
	cooldown_timer = AFTER_DAMAGE_WAIT

	print("Enemy: Hitstun bitti, COOLDOWN'a geçiliyor")

func _on_damage_taken(amount: int) -> void:
	animated_sprite.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.1).timeout
	animated_sprite.modulate = Color.WHITE

func _on_health_component_died() -> void:
	if is_dead:
		return
	
	print("╔═══════════════════╗")
	print("║  ENEMY ÖLDÜ!      ║")
	print("╚═══════════════════╝")
	is_dead = true
	is_attacking = false
	
	deactivate_enemy_attack()
	set_physics_process(false)
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	
	# Ölüm animasyonu - Süreyi yukarıdaki değişkenden al
	if animated_sprite.sprite_frames.has_animation("enemy_dead"):
		animated_sprite.play("enemy_dead")
		print("► enemy_dead başladı, süre: ", DEATH_ANIMATION_DURATION, "s")
		
		# DEATH_ANIMATION_DURATION kadar bekle
		await get_tree().create_timer(DEATH_ANIMATION_DURATION).timeout
		
		print("╔═══════════════════╗")
		print("║ ENEMY SİLİNİYOR   ║")
		print("╚═══════════════════╝")
		queue_free()
	else:
		print("✗ enemy_dead yok, hemen siliniyor")
		queue_free()

func _on_animation_finished() -> void:
	if is_dead:
		return
	
	var anim_name = animated_sprite.animation
	print("Animasyon bitti: ", anim_name)
	
	if anim_name == "enemy_attack":
		is_attacking = false
		deactivate_enemy_attack()
		print("► Saldırı tamamlandı, COOLDOWN'a geçiyor")
		
		# Saldırı bitince COOLDOWN state'ine geç
		current_state = State.COOLDOWN
		cooldown_timer = AFTER_HIT_WAIT  # 1 saniye cooldown
		
		# Cooldown sırasında idle animasyonu
		if animated_sprite.sprite_frames.has_animation("enemy_idle"):
			animated_sprite.play("enemy_idle")
		else:
			animated_sprite.play("enemy_run")

func freeze() -> void:
	print("  → Enemy freeze() çağrıldı")
	is_frozen = true
	velocity = Vector2.ZERO
	is_attacking = false
	deactivate_enemy_attack()
	
	# Animasyonu idle'a çevir (deferred kullan - signal içinde olabilir)
	if animated_sprite.sprite_frames.has_animation("enemy_idle"):
		print("    ✓ Enemy idle'a geçiyor...")
		# Önce current_state'i durdur
		current_state = State.COOLDOWN
		# Sonra animasyonu değiştir
		animated_sprite.call_deferred("play", "enemy_idle")
	else:
		# enemy_idle yoksa pause yap
		print("    ⚠ enemy_idle yok, pause yapılıyor")
		animated_sprite.pause()
