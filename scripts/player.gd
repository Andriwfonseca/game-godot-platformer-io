extends CharacterBody2D
class_name Player

# Constantes de movimento
const SPEED = 200.0
const RUN_SPEED = 450.0
const JUMP_VELOCITY = -400.0
const LONG_JUMP_VELOCITY = -480.0

# Mecânicas avançadas
const COYOTE_TIME = 0.1
const JUMP_BUFFER_TIME = 0.1

# Constantes de empurrão simples
const PUSH_FORCE = 300.0
const PUSH_MULTIPLIER_RUNNING = 4.0
const PUSH_DAMPING = 0.85

# Variáveis de estado
var is_running = false
var coyote_timer = 0.0
var jump_buffer_timer = 0.0
var was_on_floor = false

# Variáveis de empurrão
var push_velocity = Vector2.ZERO

# MULTIPLAYER - Variáveis de rede
@export var player_id: int = 1
@export var player_name: String = "Player"
@export var player_color: Color = Color.RED

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

	print("Player criado! ID:", player_id, " Nome:", player_name)

func _physics_process(delta):
	# Só o dono controla
	if is_multiplayer_authority():
		handle_timers(delta)
		handle_gravity(delta)
		handle_jump()
		handle_movement()
		apply_push_velocity(delta)  # Aplica empurrão antes do movimento
		move_and_slide()
		handle_simple_collisions()  # Verifica colisões após o movimento

		# Envia posição para outros (SEM usar MultiplayerSynchronizer)
		sync_position.rpc(position, velocity)

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

# RPC simples para sincronizar posição
@rpc("any_peer", "unreliable")
func sync_position(net_pos: Vector2, net_vel: Vector2):
	if not is_multiplayer_authority():
		# Interpola suavemente
		position = position.lerp(net_pos, 0.3)

# Resto das funções de movimento permanecem iguais...
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
