class_name UFODeliveryManager
extends Node

signal delivery_started
signal delivery_ready

var config: FarmConfig
var eggs: EggManager

func setup(value: FarmConfig, egg_manager: EggManager) -> void:
	config = value
	eggs = egg_manager
	if Game.delivery_remaining_for() <= 0.0:
		Game.set_delivery_remaining(config.delivery_interval(Game.delivery_level_for()))

func step(delta: float) -> void:
	if not eggs.can_receive():
		return
	var remaining := Game.delivery_remaining_for() - delta
	Game.set_delivery_remaining(remaining)
	if remaining <= 0.0:
		delivery_started.emit()
		eggs.deliver()
		Game.set_delivery_remaining(config.delivery_interval(Game.delivery_level_for()))
		delivery_ready.emit()

func upgrade() -> bool:
	var level := Game.delivery_level_for()
	if level >= config.delivery_intervals.size() - 1:
		return false
	var cost := config.delivery_upgrade_cost(level)
	if Game.coins < cost:
		return false
	Game.coins -= cost
	Game.set_delivery_level(level + 1)
	Game.set_delivery_remaining(minf(Game.delivery_remaining_for(), config.delivery_interval(level + 1)))
	return true
