extends Node2D

func _ready():
	print("TestLevel carregado!")
	# Cria os players quando entra no level
	GameManager.spawn_players_in_level()

func _exit_tree():
	# Limpa players quando sai do level
	GameManager.clear_players()
