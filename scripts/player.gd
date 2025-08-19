extends CharacterBody2D
class_name Player

# Constantes de movimento
const SPEED = 200.0
const RUN_SPEED = 450.0
const JUMP_VELOCITY = -400.0
const LONG_JUMP_VELOCITY = -480.0

# Constantes de empurrão simples
const PUSH_FORCE = 300.0
const PUSH_MULTIPLIER_RUNNING = 4.0
const PUSH_DAMPING = 0.85

# Mecânicas avançadas
const COYOTE_TIME = 0.1
const JUMP_BUFFER_TIME = 0.1

# Variáveis de estado
var is_running = false
var coyote_timer = 0.0
var jump_buffer_timer = 0.0
var was_on_floor = false

# Variável de empurrão simples
var push_velocity = Vector2.ZERO

# MULTIPLAYER - Variáveis de rede
@export var player_id: int = 1
@export var player_name: String = "Player"
@export var player_color: Color = Color.RED

# Variáveis para sincronização suave
var network_position = Vector2()
var network_velocity = Vector2()

func _ready():
	# Só o dono do player pode controlá-lo
	set_multiplayer_authority(player_id)
	
	# Configura cor do player
	if has_node("Sprite2D"):
		$Sprite2D.modulate = player_color
	
	if has_node("PlayerLabel"):
		$PlayerLabel.text = player_name
	
	# Só ativa a câmera para o player local
	if has_node("Camera2D"):
		$Camera2D.enabled = (player_id == multiplayer.get_unique_id())
		$Camera2D.offset = Vector2.ZERO  # Reset da posição da câmera
	
	print("Player criado! ID:", player_id, " Nome:", player_name, " | É meu:", is_multiplayer_authority())

func _physics_process(delta):
	if is_multiplayer_authority():
		# DONO: Processa input e movimento local
		handle_timers(delta)
		handle_gravity(delta)
		handle_jump()
		handle_movement()
		
		# Aplica empurrão
		apply_push_velocity(delta)
		
		# Detecta colisões simples
		handle_simple_collisions()
		
		move_and_slide()
		
		# Sincroniza posição e velocidade para outros
		sync_movement.rpc(position, velocity, is_running)
	else:
		# REMOTO: Interpola suavemente para a posição de rede
		handle_remote_movement(delta)
	
	# Atualiza estado do chão
	was_on_floor = is_on_floor()

# Função simples de colisão
func handle_simple_collisions():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider is Player and collider != self:
			var other_player = collider as Player
			
			# Calcula direção do empurrão
			var push_direction = (other_player.global_position - global_position).normalized()
			
			# Calcula força baseada na velocidade e se está correndo
			var my_speed = velocity.length()
			var force = PUSH_FORCE
			
			if is_running:
				force *= PUSH_MULTIPLIER_RUNNING
			
			# Só empurra se há velocidade suficiente
			if my_speed > 50:
				# Envia empurrão para o outro player
				other_player.receive_push.rpc(push_direction, force)
				print(player_name, " empurrou ", other_player.player_name, " | Força: ", force)

# RPC para receber empurrão
@rpc("any_peer", "reliable")
func receive_push(direction: Vector2, force: float):
	if is_multiplayer_authority():
		# Aplica empurrão horizontal
		push_velocity.x += direction.x * force
		
		# Pequeno impulso vertical se estiver no chão
		if is_on_floor() and abs(direction.x) > 0.5:
			push_velocity.y = -80

# Aplica velocidade de empurrão
func apply_push_velocity(delta):
	# Adiciona empurrão à velocidade
	velocity += push_velocity * delta
	
	# Reduz empurrão gradualmente
	push_velocity = push_velocity * PUSH_DAMPING
	
	# Para quando fica muito pequeno
	if push_velocity.length() < 5:
		push_velocity = Vector2.ZERO

# RPC para sincronizar movimento
@rpc("any_peer", "unreliable")
func sync_movement(net_pos: Vector2, net_vel: Vector2, net_running: bool):
	if not is_multiplayer_authority():
		network_position = net_pos
		network_velocity = net_vel
		is_running = net_running

# Função para interpolar movimento de players remotos
func handle_remote_movement(delta):
	# Interpola suavemente para a posição de rede
	position = position.lerp(network_position, 10.0 * delta)
	velocity = velocity.lerp(network_velocity, 5.0 * delta)
	
	# Aplica o movimento interpolado
	move_and_slide()

# Resto das funções permanecem iguais
func handle_timers(delta):
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer -= delta
	
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer -= delta

func handle_gravity(delta):
	if not is_on_floor():
		velocity += get_gravity() * delta

func handle_jump():
	var can_jump = is_on_floor() or coyote_timer > 0
	var wants_to_jump = Input.is_action_just_pressed("ui_accept") or jump_buffer_timer > 0
	
	if wants_to_jump and can_jump:
		if is_running:
			velocity.y = LONG_JUMP_VELOCITY
		else:
			velocity.y = JUMP_VELOCITY
		
		coyote_timer = 0
		jump_buffer_timer = 0

func handle_movement():
	is_running = Input.is_action_pressed("ui_select")
	var direction = Input.get_axis("ui_left", "ui_right")
	
	if direction != 0:
		var current_speed = RUN_SPEED if is_running else SPEED
		velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 3)
