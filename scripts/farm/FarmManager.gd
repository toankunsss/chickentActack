class_name FarmManager
extends Node

var config: FarmConfig
var creatures := CreatureManager.new()
var creature_ai := CreatureAI.new()
var eggs := EggManager.new()
var delivery := UFODeliveryManager.new()
var merge := MergeManager.new()
var fusion := FusionManager.new()
var income := PassiveIncomeManager.new()
var loot := LootManager.new()
var raids := UFORaidManager.new()
var collection := CollectionManager.new()
var saves := SaveManager.new()

func setup(value: FarmConfig) -> void:
	config = value
	for manager in [creatures, eggs, delivery, merge, fusion, income, loot, raids, collection, saves]:
		add_child(manager)
	creatures.setup(config)
	eggs.setup(config, creatures)
	delivery.setup(config, eggs)
	fusion.setup(config)
	income.setup(config)
	loot.setup(config)
	raids.setup(config, loot)

func step(delta: float, farm_visible: bool) -> void:
	delivery.step(delta)
	income.step(delta)
	raids.step(delta)
	if farm_visible:
		creature_ai.step(delta)
