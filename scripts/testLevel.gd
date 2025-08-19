extends Node2D

func _ready():
	print("TestLevel carregado!")
	
	# Se for cliente, não precisa fazer nada especial
	# O servidor vai gerenciar a criação dos players via RPC

func _exit_tree():
	# Limpa players quando sai do level
	GameManager.clear_players()
