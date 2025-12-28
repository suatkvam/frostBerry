extends Node
class_name RewindEnergyComponent

@export var max_energy: float = 4.0  # 4 saniye maksimum
var current_energy: float = 4.0      # Başlangıç dolu

signal energy_changed(current: float, max: float)
signal energy_depleted()
signal energy_restored()

func has_energy() -> bool:
	return current_energy > 0.0

func consume_energy(delta: float) -> void:
	if current_energy > 0:
		var old_energy = current_energy
		current_energy = max(0.0, current_energy - delta)  # 0'ın altına düşmesin
		energy_changed.emit(current_energy, max_energy)

		# Enerji bitti mi?
		if old_energy > 0 and current_energy <= 0:
			energy_depleted.emit()
			print("RewindEnergyComponent: Enerji tükendi!")

func add_energy(amount: float) -> void:
	var old_energy = current_energy
	current_energy = min(max_energy, current_energy + amount)
	energy_changed.emit(current_energy, max_energy)

	# Enerji geri geldi mi?
	if old_energy <= 0 and current_energy > 0:
		energy_restored.emit()
		print("RewindEnergyComponent: Enerji geri geldi!")
