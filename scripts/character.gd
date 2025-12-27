extends CharacterBody2D

const SPEED = 170.0
const JUMP_VELOCITY = -250.0
const KNOCKBACK_FORCE = 200.0
const KNOCKBACK_UP_FORCE = -150.0
const HITSTUN_DURATION = 0.8  # Enemy ATTACK_COOLDOWN (1.5s) + buffer (0.3s)

@onready var animated_sprite = $AnimatedSprite2D
@onready var attack_area = $AttackArea
@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var jump_sound: AudioStreamPlayer2D = $JumpSound
@onready var landing_sound: AudioStreamPlayer2D = $LandingSound
@onready var hurt_sound: AudioStreamPlayer2D = $HurtSound
@onready var death_sound: AudioStreamPlayer2D = $DeathSound

var was_on_floor: bool = false

var is_attacking = false
var combo_queued = false
var hit_enemies = []
var is_in_hitstun = false
var hitstun_timer = 0.0
var is_dead = false  # Ölüm durumu
var death_flag = false  # GameManager için ölüm flag'i

func _ready():
	print("═══════════════════════════════════════")
	print("║   CHARACTER BAŞLATILIYOR            ║")
	print("═══════════════════════════════════════")
	
	add_to_group("player")
	attack_area.monitoring = false
	
	# AnimatedSprite'ın pause'da bile çalışmasını sağla
	if animated_sprite:
		animated_sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# AnimatedSprite sinyalleri
	if animated_sprite:
		print("✓ AnimatedSprite bulundu")
		if not animated_sprite.animation_finished.is_connected(_on_animated_sprite_2d_animation_finished):
			animated_sprite.animation_finished.connect(_on_animated_sprite_2d_animation_finished)
			print("  ✓ animation_finished bağlandı")
		else:
			print("  ⚠ animation_finished ZATEN bağlı")
			
		if not animated_sprite.frame_changed.is_connected(_on_animated_sprite_2d_frame_changed):
			animated_sprite.frame_changed.connect(_on_animated_sprite_2d_frame_changed)
			print("  ✓ frame_changed bağlandı")
		else:
			print("  ⚠ frame_changed ZATEN bağlı")
	else:
		print("✗ AnimatedSprite BULUNAMADI!")
	
	if health_component:
		health_component.died.connect(_on_health_component_died)
		health_component.damage_taken.connect(_on_damage_taken)
		print("✓ HealthComponent bağlandı, Can: ", health_component.current_health)
	else:
		print("✗ HealthComponent BULUNAMADI!")

	if hurtbox:
		hurtbox.hitstun_started.connect(_on_hitstun_started)
		hurtbox.hitstun_ended.connect(_on_hitstun_ended)
		print("✓ HurtboxComponent bağlandı")
	else:
		print("✗ HurtboxComponent BULUNAMADI!")

	print("═══════════════════════════════════════")
	print("║   CHARACTER HAZIR!                  ║")
	print("═══════════════════════════════════════")

func _physics_process(delta: float) -> void:
	# Ölüyse TAMAMEN dur - yerçekimi bile çalışmasın
	if is_dead:
		velocity = Vector2.ZERO
		return

	# Landing sesi kontrolü
	if is_on_floor() and not was_on_floor and landing_sound:
		landing_sound.play()

	was_on_floor = is_on_floor()

	# Hitstun sayacı
	if is_in_hitstun:
		hitstun_timer -= delta
		if hitstun_timer <= 0:
			is_in_hitstun = false
			print("Character hitstun bitti")

	# Hitstun sırasında yerçekimi uygula ama kontrol verme
	if is_in_hitstun:
		# Yerçekimi
		if not is_on_floor():
			velocity += get_gravity() * delta

		# Sürtünme - yavaşça dur
		velocity.x = move_toward(velocity.x, 0, SPEED * delta * 3)

		move_and_slide()
		return

	# Normal yerçekimi
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Zıplama
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		if jump_sound:
			jump_sound.play()
	
	# Saldırı girişi
	if Input.is_action_just_pressed("attack") and is_on_floor():
		if not is_attacking:
			perform_attack()
		else:
			combo_queued = true
	
	var direction := Input.get_axis("move_left", "move_right")
	
	# Saldırı sırasında hareket kontrolü
	if not is_attacking:
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 2)
	
	move_and_slide()
	
	# Animasyon güncelleme
	if not is_attacking:
		update_animation(direction)

func perform_attack() -> void:
	is_attacking = true
	combo_queued = false
	hit_enemies.clear()
	animated_sprite.play("light_attack_1")
	print("ATTACK: Saldırı başladı - light_attack_1")

func update_animation(direction: float) -> void:
	if not is_on_floor():
		animated_sprite.play("jump")
	elif direction != 0:
		animated_sprite.play("run")
		animated_sprite.flip_h = direction < 0
		if direction < 0:
			attack_area.scale.x = -1
		else:
			attack_area.scale.x = 1
	else:
		animated_sprite.play("idle")

func _on_animated_sprite_2d_frame_changed() -> void:
	var current_anim = animated_sprite.animation
	var current_frame = animated_sprite.frame
	
	# Sadece saldırı animasyonlarında frame bilgisi
	if current_anim in ["light_attack_1", "light_attack_2"]:
		print("  ├─ Frame: ", current_frame, " (", current_anim, ")")
	
	# light_attack_1: Frame 3 (4. frame)
	# light_attack_2: Frame 2 (3. frame)
	if current_anim == "light_attack_1":
		if current_frame == 3:
			activate_attack()
		else:
			deactivate_attack()
	elif current_anim == "light_attack_2":
		if current_frame == 2:
			activate_attack()
		else:
			deactivate_attack()
	elif current_anim == "light_attack1.2":
		deactivate_attack()

func activate_attack() -> void:
	if not attack_area.monitoring:
		attack_area.monitoring = true
		print("  ╔═══ PLAYER ATTACK AREA AKTİF ═══╗")

func deactivate_attack() -> void:
	if attack_area.monitoring:
		attack_area.monitoring = false
		print("  ╚═══ PLAYER ATTACK AREA KAPANDI ═══╝")

func _on_animated_sprite_2d_animation_finished() -> void:
	var anim_name = animated_sprite.animation
	print("╔═══════════════════════════════════════╗")
	print("║ ANIM FINISHED: ", anim_name.pad_zeros(20), " ║")
	print("╚═══════════════════════════════════════╝")
	
	# Die animasyonu await ile bekleniyor, burada işleme gerek yok
	if anim_name == "die":
		return
	
	deactivate_attack()
	
	if anim_name == "light_attack_1":
		if combo_queued:
			hit_enemies.clear()
			animated_sprite.play("light_attack_2")
			combo_queued = false
			print("► COMBO: light_attack_2 başladı")
		else:
			animated_sprite.play("light_attack1.2")
			print("► light_attack1.2 başladı")
	elif anim_name == "light_attack1.2":
		is_attacking = false
		print("► Saldırı tamamlandı (1.2)")
	elif anim_name == "light_attack_2":
		is_attacking = false
		print("► Combo tamamlandı")

func _on_attack_area_body_entered(body):
	print("╔═══════════════════════════════════════╗")
	print("║ PLAYER ATTACK HIT!                    ║")
	print("║ Target: ", body.name.pad_zeros(27), " ║")
	print("╚═══════════════════════════════════════╝")

	if body in hit_enemies:
		print("  ⚠ Zaten vuruldu bu saldırıda!")
		return

	# HurtboxComponent üzerinden hasar ver
	if body.has_node("HurtboxComponent"):
		var target_hurtbox = body.get_node("HurtboxComponent")
		target_hurtbox.take_damage(10, global_position)
		hit_enemies.append(body)
		print("  ✓ 10 hasar + knockback verildi")
	else:
		print("  ✗ HurtboxComponent yok!")

# HITSTUN CALLBACK'LERİ
func _on_hitstun_started(duration: float) -> void:
	is_in_hitstun = true
	hitstun_timer = duration

	# Saldırıyı iptal et
	if is_attacking:
		is_attacking = false
		combo_queued = false
		deactivate_attack()

	print("Character: Hitstun başladı (%0.1fs)" % duration)

func _on_hitstun_ended() -> void:
	is_in_hitstun = false
	print("Character: Hitstun bitti")

func _on_damage_taken(amount: int) -> void:
	print("╔═══════════════════════════════════════╗")
	print("║ PLAYER HASAR ALDI: ", str(amount).pad_zeros(16), " ║")
	print("╚═══════════════════════════════════════╝")

	# Hasar sesi
	if hurt_sound:
		hurt_sound.play()

	# Hasar görsel efekti
	animated_sprite.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.1).timeout
	animated_sprite.modulate = Color.WHITE

func _on_health_component_died() -> void:
	# ÖNEMLİ: is_dead ve death_flag'i EN BAŞTA set et
	is_dead = true
	death_flag = true

	print("╔═══════════════════════════════════════╗")
	print("║     PLAYER: Ölüm prosedürü başladı  ║")
	print("╚═══════════════════════════════════════╝")

	# Ölüm sesi
	if death_sound:
		death_sound.play()

	# 1. Fizik ve collision temizliği
	velocity = Vector2.ZERO
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	print("  ✓ Fizik ve collision kapatıldı")
	
	# 2. Attack area kapat
	if attack_area:
		attack_area.set_deferred("monitoring", false)
		print("  ✓ Attack area kapatıldı")
	
	# 3. Die animasyonu başlat (5 frame, son frame x7.0)
	if animated_sprite.sprite_frames.has_animation("die"):
		print("  ► Die animasyonu başlatılıyor...")
		print("    Frame 0-3: x1.0, Frame 4: x7.0")
		animated_sprite.sprite_frames.set_animation_loop("die", false)
		animated_sprite.play("die")
		animated_sprite.frame = 0
		print("  ✓ Animasyon başladı")
	else:
		print("  ✗ HATA: die animasyonu bulunamadı!")
		return
	
	# 4. Animasyon bitene kadar bekle
	print("  ⏳ Animasyon tamamlanıyor... (toplam ~4 + 7 = 11 frame süresi)")
	await animated_sprite.animation_finished
	print("  ✓ Die animasyonu tamamlandı")
	
	# 5. Animasyon bitti, artık GameManager devreye girecek
	print("  ► death_flag=true ile GameManager'a bildiriliyor")
	# GameManager zaten HealthComponent.died sinyalini dinliyor

func get_death_flag() -> bool:
	return death_flag

func is_alive() -> bool:
	return not is_dead

# freeze_all_enemies artık GameManager tarafından yönetiliyor
# Bu fonksiyon kullanılmıyor
