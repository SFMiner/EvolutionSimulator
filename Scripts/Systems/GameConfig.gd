extends Node

# Easy to adjust without touching code
var energy_depletion_rates = {
	"low": 1.0,
	"medium": 2.0,
	"high": 3.0
}

var movement_speeds = {
	"slow": 20,
	"medium": 40,
	"fast": 60
}

var growth_timers = {
	"slow": 10.0,
	"normal": 7.0,
	"fast": 4.0
}

var food_spawn_interval = 2.0
var max_organisms = 50
var reproduction_energy = 80
var max_energy = 100
var mutation_chance = 0.1
var food_energy_value = 30

# Helper function to get random array element
func get_random_element(array: Array):
	if array.size() > 0:
		return array[randi() % array.size()]
	return null
