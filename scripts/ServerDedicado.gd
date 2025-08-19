extends Node

const PORT = 7000
const MAX_PLAYERS = 10
const VPS_IP = "69.62.102.211"  # IP da sua VPS

var players = {}
var game_started = false

# Cenas
var player_scene = preload("res://scenes/Player.tscn")

func _ready():
	print("=== SERVIDOR DEDICADO INICIANDO ===")
	print("Modo headless detectado")
	
	# Conecta sinais de multiplayer
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	
	# Inicia servidor
	start_dedicated_server()

func start_dedicated_server():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_PLAYERS)
	
	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("✅ SERVIDOR RODANDO NA PORTA ", PORT)
		print("Aguardando jogadores...")
		
		# Carrega level do jogo
		get_tree().change_scene_to_file("res://scenes/TestLevel.tscn")
	else:
		print("❌ ERRO AO CRIAR SERVIDOR: ", error)
		get_tree().quit()

func _on_player_connected(id):
	print("🎮 JOGADOR CONECTADO: ", id)
	
	# Cria player para o jogador conectado
	create_player_for_client.rpc_id(id, id, "Player_" + str(id))
	
	# Envia players existentes para o novo jogador
	for existing_id in players.keys():
		create_player_for_client.rpc_id(id, existing_id, players[existing_id].player_name)

func _on_player_disconnected(id):
	print("❌ JOGADOR DESCONECTADO: ", id)
	
	# Remove player
	if players.has(id):
		players[id].queue_free()
		players.erase(id)
	
	# Notifica outros clientes
	remove_player_for_all.rpc(id)

# RPC para criar player no cliente
@rpc("authority", "reliable")
func create_player_for_client(id: int, player_name: String):
	pass  # Implementado no cliente

# RPC para remover player de todos
@rpc("authority", "reliable")  
func remove_player_for_all(id: int):
	pass  # Implementado no cliente

# Registra player no servidor (sem criar instância visual)
func register_player(id: int, player_name: String):
	if not players.has(id):
		var player_data = {
			"id": id,
			"name": player_name,
			"position": Vector2(100 + players.size() * 150, -100)
		}
		players[id] = player_data
		print("✅ Player registrado: ", player_name, " (ID: ", id, ")")
