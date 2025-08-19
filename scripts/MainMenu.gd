extends Control

func _ready():
	print("🎮 CLIENTE - Menu Principal")
	
	var start_button = get_node("VBoxContainer/StartButton")
	start_button.pressed.connect(_on_start_pressed)

func _on_start_pressed():
	print("🚀 Iniciando jogo...")
	
	if GameManager.connect_to_vps():
		print("⏳ Conectando...")
		# O GameManager vai mudar de cena quando conectar
	else:
		print("❌ Falha na conexão!")
		# Aqui você pode mostrar uma mensagem de erro
