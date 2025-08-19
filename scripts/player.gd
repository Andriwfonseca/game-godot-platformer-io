extends CharacterBody2D

# Constantes de movimento
const SPEED = 200.0
const RUN_SPEED = 450.0
const JUMP_VELOCITY = -400.0
const LONG_JUMP_VELOCITY = -480.0  # Pulo mais alto quando correndo

# Mecânicas avançadas
const COYOTE_TIME = 0.1  # Tempo para pular após sair da plataforma
const JUMP_BUFFER_TIME = 0.1  # Tempo para registrar pulo antecipado

# Variáveis de estado
var is_running = false
var coyote_timer = 0.0
var jump_buffer_timer = 0.0
var was_on_floor = false

func _ready():
	print("Player criado!")

func _physics_process(delta):
	handle_timers(delta)
	handle_gravity(delta)
	handle_jump()
	handle_movement()
	
	# Atualiza estado do chão
	was_on_floor = is_on_floor()
	
	move_and_slide()

func handle_timers(delta):
	# Coyote time - permite pular um pouquinho após sair da plataforma
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer -= delta
	
	# Jump buffer - registra input de pulo antecipado
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer -= delta

func handle_gravity(delta):
	if not is_on_floor():
		velocity += get_gravity() * delta

func handle_jump():
	# Verifica se pode pular (no chão OU ainda no coyote time)
	var can_jump = is_on_floor() or coyote_timer > 0
	
	# Verifica se quer pular (pressionou agora OU ainda no buffer)
	var wants_to_jump = Input.is_action_just_pressed("ui_accept") or jump_buffer_timer > 0
	
	if wants_to_jump and can_jump:
		# Pulo longo se estiver correndo
		if is_running:
			velocity.y = LONG_JUMP_VELOCITY
			print("PULO LONGO!")
		else:
			velocity.y = JUMP_VELOCITY
			print("Pulo normal")
		
		# Zera os timers
		coyote_timer = 0
		jump_buffer_timer = 0

func handle_movement():
	# Verifica se está correndo
	is_running = Input.is_action_pressed("ui_select")
	
	# Pega direção do movimento
	var direction = Input.get_axis("ui_left", "ui_right")
	
	if direction != 0:
		var current_speed = RUN_SPEED if is_running else SPEED
		velocity.x = direction * current_speed
	else:
		# Para mais rápido para controle mais responsivo
		velocity.x = move_toward(velocity.x, 0, SPEED * 3)
