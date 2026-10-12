class_name PassiveIncomeManager
extends Node

signal income_collected(amount: int)

var config: FarmConfig
var elapsed := 0.0

func setup(value: FarmConfig) -> void:
	config = value

func step(delta: float) -> void:
	elapsed += delta
	if elapsed < config.income_tick_seconds:
		return
	elapsed = fmod(elapsed, config.income_tick_seconds)
	var amount := Game.passive_income_after_damage()
	Game.coins += amount
	income_collected.emit(amount)
