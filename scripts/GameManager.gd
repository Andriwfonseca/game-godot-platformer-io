extends Node

# Configurações de rede
const PORT = 7000
const MAX_PLAYERS = 10

# Cenas - CAMINHO CORRETO
var player_scene = preload("res://scenes/Player.tscn")

# Lista de jogadores conectados
var players = {}

func _ready():
	# Conecta sinais de multiplayer
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

# Função para criar servidor
func create_server():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_PLAYERS)
	
	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("Servidor criado na porta ", PORT)
		return true
	else:
		print("Erro ao criar servidor: ", error)
		return false

# Função para conectar como cliente
func join_server(ip: String):
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, PORT)
	
	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("Tentando conectar em ", ip, ":", PORT)
		return true
	else:
		print("Erro ao conectar: ", error)
		return false

# Quando um player se conecta
func _on_player_connected(id):
	print("=== EVENTO: Player conectado: ", id, " ===")
	
	# Espera um pouco e depois sincroniza
	await get_tree().create_timer(0.5).timeout
	sync_all_players()

# Quando um player se desconecta
func _on_player_disconnected(id):
	print("Player desconectado: ", id)
	remove_player.rpc(id)

# Quando conecta no servidor (só para clientes)
func _on_connected_to_server():
	print("=== EVENTO: Conectado no servidor! ===")
	
	# Espera um pouco e depois sincroniza
	await get_tree().create_timer(0.5).timeout
	sync_all_players()

# Quando falha a conexão
func _on_connection_failed():
	print("Falha na conexão!")

# Função para sincronizar todos os players
func sync_all_players():
	print("=== SINCRONIZANDO TODOS OS PLAYERS ===")
	print("Meu ID: ", multiplayer.get_unique_id())
	print("Players locais: ", players.keys())
	
	# Cada um envia sua lista para todos
	var my_players = []
	for id in players.keys():
		var player = players[id]
		my_players.append({"id": id, "name": player.player_name})
	
	print("Enviando minha lista: ", my_players)
	sync_player_list.rpc(my_players)

# RPC para sincronizar lista de players
@rpc("any_peer", "reliable")
func sync_player_list(player_list: Array):
	var sender_id = multiplayer.get_remote_sender_id()
	print("=== RECEBIDO LISTA DE PLAYERS DE ", sender_id, " ===")
	print("Lista recebida: ", player_list)
	
	for player_data in player_list:
		var id = player_data.id
		var name = player_data.name
		
		# Só cria se não existir localmente
		if not players.has(id):
			print("Criando player que não existia: ", id, " - ", name)
			add_player_local(id, name)
		else:
			print("Player já existe localmente: ", id)

# FUNÇÃO SIMPLIFICADA - Criar players no level
func spawn_players_in_level():
	print("=== SPAWN_PLAYERS_IN_LEVEL ===")
	print("É servidor: ", multiplayer.is_server())
	print("Meu ID: ", multiplayer.get_unique_id())
	
	# SEMPRE cria o player local primeiro
	var my_id = multiplayer.get_unique_id()
	var my_name = "Host" if multiplayer.is_server() else "Player_" + str(my_id)
	
	add_player_local(my_id, my_name)
	
	# Se já há conexões, sincroniza imediatamente
	if multiplayer.get_peers().size() > 0:
		print("Há peers conectados, sincronizando...")
		sync_all_players()

# Função LOCAL para criar player (não RPC)
func add_player_local(id: int, player_name: String):
	# Só cria se estiver no TestLevel
	if not get_tree().current_scene.name == "TestLevel":
		print("Não está no TestLevel, pulando criação do player")
		return
	
	if players.has(id):
		print("Player ", id, " já existe localmente - PULANDO")
		return
	
	print("=== CRIANDO PLAYER LOCAL ===")
	print("ID: ", id, " Nome: ", player_name)
	
	# Instancia o player
	var player_instance = player_scene.instantiate()
	player_instance.player_id = id
	player_instance.player_name = player_name
	player_instance.name = "Player_" + str(id)
	
	# Define cor baseada no ID
	var colors = [Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.PURPLE, Color.ORANGE]
	player_instance.player_color = colors[id % colors.size()]
	
	# Posição inicial com espaçamento
	var spawn_x = 100 + (players.size() * 150)  # Mais espaçamento
	player_instance.position = Vector2(spawn_x, -100)
	
	print("Posição do player: ", player_instance.position)
	
	# Adiciona na cena
	get_tree().current_scene.add_child(player_instance, true)
	
	# Armazena na lista
	players[id] = player_instance
	
	print("=== PLAYER CRIADO COM SUCESSO ===")
	print("Total de players: ", players.size())
	print("Lista atual: ", players.keys())

# RPC para remover um player
@rpc("any_peer", "reliable")
func remove_player(id: int):
	if players.has(id):
		print("Removendo player: ", id)
		players[id].queue_free()
		players.erase(id)

# Limpa players quando sai do level
func clear_players():
	for id in players.keys():
		players[id].queue_free()
	players.clear()
