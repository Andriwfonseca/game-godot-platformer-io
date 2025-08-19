extends Control

func _ready():
	print("MainMenu carregado!")
	
	var host_button = get_node("VBoxContainer/HostButton")
	var join_button = get_node("VBoxContainer/JoinButton")
	
	if host_button:
		host_button.pressed.connect(_on_host_pressed)
		print("Botão Host conectado!")
	
	if join_button:
		join_button.pressed.connect(_on_join_pressed)
		print("Botão Join conectado!")

func _on_host_pressed():
	print("Botão Host clicado!")
	
	print("Tentando criar servidor...")
	var success = GameManager.create_server()
	
	if success:
		print("Servidor criado! Mudando para TestLevel...")
		get_tree().change_scene_to_file("res://scenes/TestLevel.tscn")
	else:
		print("ERRO: Falha ao criar servidor!")

func _on_join_pressed():
	print("Botão Join clicado!")
	
	var ip_input = get_node("VBoxContainer/IPLineEdit")
	var ip = "127.0.0.1"
	
	if ip_input:
		ip = ip_input.text
	
	print("Tentando conectar em: ", ip)
	
	if GameManager.join_server(ip):
		print("Conexão iniciada! Mudando para TestLevel...")
		get_tree().change_scene_to_file("res://scenes/TestLevel.tscn")
	else:
		print("ERRO: Falha ao conectar!")
