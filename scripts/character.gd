extends CharacterBody2D

const SPEED = 170.0
const JUMP_VELOCITY = -250.0
const KNOCKBACK_FORCE = 200.0  # Artırıldı - daha belirgin
const KNOCKBACK_UP_FORCE = -150.0  # Artırıldı
const HITSTUN_DURATION = 0.5  # Biraz uzatıldı

@onready var animated_sprite = $AnimatedSprite2D
@onready var attack_area = $AttackArea
@onready var health_component: HealthComponent = $HealthComponent

var is_attacking = false
var combo_queued = false
var hit_enemies = []
var is_in_hitstun = false
var hitstun_timer = 0.0

func _ready():
	add_to_group("player")
	attack_area.monitoring = false
	
	if health_component:
		health_component.died.connect(_on_health_component_died)
		health_component.damage_taken.connect(_on_damage_taken)
	
	print("Character ready! Health: ", health_component.current_health if health_component else "N/A")

func _physics_process(delta: float) -> void:
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
		print("ATTACK_AREA: Aktif edildi! Frame: ", animated_sprite.frame)

func deactivate_attack() -> void:
	if attack_area.monitoring:
		attack_area.monitoring = false
		print("ATTACK_AREA: Kapatıldı")

func _on_animated_sprite_2d_animation_finished() -> void:
	var anim_name = animated_sprite.animation
	print("ANIMATION_FINISHED: ", anim_name)
	
	deactivate_attack()
	
	if anim_name == "light_attack_1":
		if combo_queued:
			hit_enemies.clear()
			animated_sprite.play("light_attack_2")
			combo_queued = false
			print("COMBO: light_attack_2 başladı")
		else:
			animated_sprite.play("light_attack1.2")
	elif anim_name == "light_attack1.2":
		is_attacking = false
		print("ATTACK: Saldırı tamamlandı (1.2)")
	elif anim_name == "light_attack_2":
		is_attacking = false
		print("ATTACK: Combo tamamlandı")

func _on_attack_area_body_entered(body):
	print("COLLISION: Body entered - ", body.name)
	
	if body in hit_enemies:
		print("UYARI: ", body.name, " zaten vuruldu bu saldırıda!")
		return
	
	if body.has_method("take_damage"):
		# Düşmana hasar ver
		body.take_damage(10, global_position)
		hit_enemies.append(body)
		print("HASAR VERİLDİ: ", body.name, " -> 10 hasar + knockback")

# HASAR SİSTEMİ
func take_damage(amount: int, attacker_position: Vector2 = global_position) -> void:
	if is_in_hitstun:
		print("Character zaten hitstun'da, hasar ignore")
		return
	
	if health_component:
		health_component.take_damage(amount)
	
	# Knockback yönünü hesapla
	var knockback_dir = sign(global_position.x - attacker_position.x)
	if knockback_dir == 0:
		knockback_dir = -1 if animated_sprite.flip_h else 1
	
	# Knockback uygula
	apply_knockback(knockback_dir, KNOCKBACK_FORCE, KNOCKBACK_UP_FORCE)
	
	print("Character knockback: direction=", knockback_dir, " force=", KNOCKBACK_FORCE)

func apply_knockback(direction: float, force: float, up_force: float) -> void:
	# Velocity'yi direkt set et (move_toward kullanma!)
	velocity.x = direction * force
	velocity.y = up_force
	
	# Hitstun başlat
	is_in_hitstun = true
	hitstun_timer = HITSTUN_DURATION
	
	# Saldırıyı iptal et
	if is_attacking:
		is_attacking = false
		combo_queued = false
		deactivate_attack()
	
	print("Character: Knockback uygulandı! vx=", velocity.x, " vy=", velocity.y)

func _on_damage_taken(amount: int) -> void:
	# Hasar görsel efekti
	animated_sprite.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.1).timeout
	animated_sprite.modulate = Color.WHITE
	print("PLAYER: %d hasar aldı!" % amount)

func _on_health_component_died() -> void:
	print("Player öldü!")
	set_physics_process(false)
	# Ölüm animasyonu
	# animated_sprite.play("death")
	# await animated_sprite.animation_finished
	# get_tree().reload_current_scene()
