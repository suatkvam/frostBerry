extends Node

# ═══════════════════════════════════════════════════════════
# GAME MANAGER - Oyun Durumu Yöneticisi
# ═══════════════════════════════════════════════════════════
# Player öldüğünde:
#   1. Player death_flag=true döndürür
#   2. Enemy saldırı animasyonu bitene kadar bekler
#   3. Player ölüm animasyonu bitene kadar bekler
#   4. 1 saniye bekler
#   5. "GAME OVER" gösterir ve oyunu dondurur
# ═══════════════════════════════════════════════════════════

var player: CharacterBody2D = null
var is_game_over: bool = false
var player_death_anim_finished: bool = false
var enemy_attack_anim_finished: bool = false

func _ready() -> void:
	print("╔═══════════════════════════════════════╗")
	print("║   GAME MANAGER BAŞLATILIYOR         ║")
	print("╚═══════════════════════════════════════╝")
	is_game_over = false

func player_died() -> void:
	if is_game_over:
		return
	
	print("╔═══════════════════════════════════════╗")
	print("║   GAME MANAGER: Player öldü!        ║")
	print("╚═══════════════════════════════════════╝")
	
	is_game_over = true
	
	# 1 saniye bekle
	print("  ⏳ 1 saniye bekleniyor...")
	await get_tree().create_timer(1.0).timeout
	
	# Game Over (Ana menüye dön)
	show_game_over()

func show_game_over() -> void:
	print("╔═══════════════════════════════════════╗")
	print("║                                       ║")
	print("║          G A M E   O V E R            ║")
	print("║                                       ║")
	print("╚═══════════════════════════════════════╝")
	
	# Reset state
	is_game_over = false

	# Death scene'i yükle
	print("  ✓ Death scene yükleniyor...")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scene/death_scene.tscn")
