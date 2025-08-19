extends Node

const PORT = 7000
const MAX_PLAYERS = 10
const VPS_IP = "69.62.102.211"  # Substitua pelo IP real

var player_scene = preload("res://scenes/Player.tscn")
var players = {}  # Lista de players conectados (servidor)
var local_players = {}  # Lista de players visuais (cliente)

func _ready():
	# Detecta se é servidor dedicado ou cliente
	if OS.has_feature("server") or DisplayServer.get_name() == "headless":
		print("🖥️ MODO SERVIDOR DEDICADO")
		start_dedicated_server()
	else:
		print("🎮 MODO CLIENTE")
		setup_client_mode()

func start_dedicated_server():
	print("=== SERVIDOR DEDICADO INICIANDO ===")
	
	# Conecta sinais de multiplayer
	multiplayer.peer_connected.connect(_on_player_connected_server)
	multiplayer.peer_disconnected.connect(_on_player_disconnected_server)
	
	# Cria servidor
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_PLAYERS)
	
	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("✅ SERVIDOR RODANDO NA PORTA ", PORT)
		print("Aguardando jogadores...")
		
		# Carrega level do jogo diretamente
		get_tree().change_scene_to_file("res://scenes/TestLevel.tscn")
	else:
		print("❌ ERRO AO CRIAR SERVIDOR: ", error)
		get_tree().quit()

func setup_client_mode():
	# Conecta sinais normais para cliente
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

# === FUNÇÕES DO SERVIDOR DEDICADO ===
func _on_player_connected_server(id):
	print("🎮 JOGADOR CONECTADO NO SERVIDOR: ", id)
	
	# 1. ADICIONA o novo player na lista do servidor
	var player_name = "Player_" + str(id)
	players[id] = player_name
	print("📋 Players no servidor: ", players.keys())
	
	# 2. Aguarda um pouco para garantir que cliente carregou a cena
	await get_tree().create_timer(1.0).timeout
	
	# 3. ENVIA TODOS os players existentes para o NOVO cliente
	print("📤 Enviando lista completa para cliente ", id)
	for existing_id in players.keys():
		var existing_name = players[existing_id]
		print("  📤 Enviando player: ", existing_id, " - ", existing_name)
		spawn_player_for_client.rpc_id(id, existing_id, existing_name)
	
	# 4. NOTIFICA TODOS os outros clientes sobre o novo player
	print("📢 Notificando outros clientes sobre novo player ", id)
	for client_id in multiplayer.get_peers():
		if client_id != id:  # Não envia para o próprio cliente
			spawn_player_for_client.rpc_id(client_id, id, player_name)

func _on_player_disconnected_server(id):
	print("❌ JOGADOR DESCONECTADO DO SERVIDOR: ", id)
	
	# Remove da lista
	if players.has(id):
		players.erase(id)
		print("📋 Players restantes: ", players.keys())
	
	# Notifica todos os clientes
	remove_player_for_all_clients.rpc(id)

# === FUNÇÕES DO CLIENTE ===
func connect_to_vps():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(VPS_IP, PORT)
	
	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("🌐 Conectando na VPS: ", VPS_IP, ":", PORT)
		return true
	else:
		print("❌ Erro ao conectar na VPS: ", error)
		return false

func _on_connected_to_server():
	print("✅ Conectado na VPS!")
	get_tree().change_scene_to_file("res://scenes/TestLevel.tscn")

func _on_connection_failed():
	print("❌ Falha ao conectar na VPS!")

func _on_peer_connected(id):
	print("👤 Outro jogador conectou: ", id)

func _on_peer_disconnected(id):
	print("👋 Jogador desconectou: ", id)

# === RPCs CORRIGIDOS ===

# RPC do servidor para UM cliente específico criar player
@rpc("authority", "reliable")
func spawn_player_for_client(id: int, player_name: String):
	# Só funciona nos CLIENTES
	if OS.has_feature("server") or DisplayServer.get_name() == "headless":
		return
	
	# CLIENTE: cria player visual
	if get_tree().current_scene.name != "TestLevel":
		print("❌ Não está no TestLevel ainda, ignorando spawn")
		return
		
	if local_players.has(id):
		print("⚠️ Player ", id, " já existe localmente")
		return
	
	print("🎭 CRIANDO PLAYER: ", player_name, " (ID: ", id, ")")
	print("📋 Meu ID: ", multiplayer.get_unique_id())
	
	var player_instance = player_scene.instantiate()
	player_instance.player_id = id
	player_instance.player_name = player_name
	player_instance.name = "Player_" + str(id)
	
	# Cores diferentes por ID
	var colors = [Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.PURPLE, Color.ORANGE]
	player_instance.player_color = colors[id % colors.size()]
	
	# Posição com espaçamento
	player_instance.position = Vector2(100 + local_players.size() * 150, -100)
	
	get_tree().current_scene.add_child(player_instance, true)
	local_players[id] = player_instance
	
	print("✅ Player criado! Total local: ", local_players.size())
	print("📋 Players locais: ", local_players.keys())

# RPC do servidor para todos os clientes removerem player
@rpc("authority", "reliable")
func remove_player_for_all_clients(id: int):
	if local_players.has(id):
		print("🗑️ Removendo player: ", id)
		local_players[id].queue_free()
		local_players.erase(id)

# Limpa players quando sai do level
func clear_players():
	for id in local_players.keys():
		local_players[id].queue_free()
	local_players.clear()
