extends KinematicBody2D

signal enemy_kill
signal player_collided_with_enemy

export var walk_fx: AudioStreamSample
export var brake_fx: AudioStreamSample
export var fly_fx: AudioStreamSample
export var bounce_fx: AudioStreamSample
export var death_by_attack_fx: AudioStreamSample
export var death_by_lava_fx: AudioStreamSample

onready var screen_size = get_viewport_rect().size

# TO DO: Kill each other

enum State { WALK, FLY, ATTACK, BRAKE, FALL, DEATH_BY_LAVA, DEATH_BY_ATTACK }

const GRAVITY = 2
const INITIAL_WALK_SPEED = 0
const WALK_SPEED_INCREMENT = 8
const MAX_SPEED = 450
const FLY_SPEED = 60
const SPRITE_WIDTH = 32
const SPRITE_HEIGHT = 64
const KILLING_TOLERANCE = 0.1
const BOUNCE_FACTOR = 1.3

var original_position = Vector2()
var current_state = State.FALL
var current_animation = "walk"
var animation_speed_factor = 0.24
var animation_speed = 0

var velocity = Vector2(INITIAL_WALK_SPEED, 100) # default: right
var is_on_floor = false

var has_sound_played = false

func _ready():
	randomize()
	original_position = get_parent().get_node("PlayerSpawn").position
	current_state = State.FALL
	velocity = Vector2(INITIAL_WALK_SPEED, 100)
	$AnimationPlayer.play(current_animation, -1, animation_speed)

# Rework to go in increments and remain the same while no input is given
func _physics_process(delta):
	connect_with_enemies()
	process_state(delta)
	
	if velocity.x < 0 and current_state != State.FLY and current_state != State.FALL:
		$AnimatedSprite.flip_h = true
	elif velocity.x > 0 and current_state != State.FLY and current_state != State.FALL:
		$AnimatedSprite.flip_h = false
	
	if current_state != State.DEATH_BY_LAVA and current_state != State.DEATH_BY_ATTACK:
		if not is_on_floor:
			update_state(State.FALL)
		
		if Input.is_action_pressed("left"):
			velocity.x -= WALK_SPEED_INCREMENT
			if velocity.x > 0 and is_on_floor:
				update_state(State.BRAKE)
				$AnimationPlayer.play("brake", -1, 0.0)
			if current_state == State.FLY or current_state == State.FALL:
				$AnimatedSprite.flip_h = true
		elif Input.is_action_pressed("right"):
			velocity.x +=  WALK_SPEED_INCREMENT
			if velocity.x < 0 and is_on_floor:
				update_state(State.BRAKE)
				$AnimationPlayer.play("brake", -1, 0.0)
			if current_state == State.FLY or current_state == State.FALL:
				$AnimatedSprite.flip_h = false
		
		if Input.is_action_just_pressed("up"):
			velocity.y += -FLY_SPEED
			update_state(State.FLY)
			if(not $AnimationPlayer.current_animation == "fly"):
				var pitch = rand_range(0.95, 1.05)
				$AudioStreamPlayer.stream = fly_fx
				$AudioStreamPlayer.pitch_scale = pitch
				$AudioStreamPlayer.play(0.0)
				$AnimationPlayer.play("fly", -1, 4.0)
	
		velocity.x = min(MAX_SPEED, velocity.x)
		velocity.x = max(-MAX_SPEED, velocity.x)
		velocity.y = min(MAX_SPEED, velocity.y)
		velocity.y = max(-MAX_SPEED, velocity.y)
		#velocity = velocity.clamped(MAX_SPEED)
		animation_speed = velocity.x * pow(animation_speed_factor, 2)
		
		check_collisions(delta)
		var collision_info = move_and_collide(velocity * delta)
		keep_in_boundaries()
		
		if collision_info:
			var collider = collision_info.get_collider()
			
			if collider.is_in_group("enemy"):
				emit_signal("player_collided_with_enemy", collision_info)
				if collision_info.normal.y > KILLING_TOLERANCE: # if player is higher (normal.y > KILLING_TOLERANCE)
					update_state(State.DEATH_BY_ATTACK) # self dies
				else:
					bounce(collision_info.normal)
					velocity *= BOUNCE_FACTOR

func keep_in_boundaries():
	position.x = wrapf(position.x, -SPRITE_WIDTH, screen_size.x + SPRITE_WIDTH / 2)
	#position.y = max(position.y, SPRITE_HEIGHT / 2)

func check_collisions(delta):
	var collision_info = move_and_collide(velocity * delta, true, true, true)
	
	if collision_info:
		var collider = collision_info.get_collider()
		
		if collider.is_in_group("wall"):
			if floor(rad2deg(collision_info.get_angle())) == 0:
				if current_state == State.BRAKE and (Input.is_action_pressed("left") or Input.is_action_pressed("right")):
					update_state(State.BRAKE)
				else:
					update_state(State.WALK)
			else:
				bounce(collision_info.normal)
	else:
		if is_on_floor:
			update_state(State.FALL)

func update_state(state):
	if current_state != state:
		current_state = state
		
		if current_state == State.WALK:
			$AudioStreamPlayer.stream = walk_fx
		
		if current_state == State.BRAKE:
			$AudioStreamPlayer.stream = brake_fx
			$AudioStreamPlayer.pitch_scale = 1
			$AudioStreamPlayer.play(0.0)
		else:
			$AudioStreamPlayer.stop()
		
		if current_state == State.FLY:
			$AudioStreamPlayer.stream = fly_fx
		
		if current_state == State.DEATH_BY_LAVA:
			var pitch = rand_range(0.80, 1.20)
			$AudioStreamPlayer.pitch_scale = pitch
			$AudioStreamPlayer.stream = death_by_lava_fx
			$AudioStreamPlayer.play(0.0)
			$AnimationPlayer.play("death_by_lava", -1, 3.0)
			$DeathTimer.start()
		
		if current_state == State.DEATH_BY_ATTACK:
			var pitch = rand_range(0.5, 1.20)
			$AudioStreamPlayer.pitch_scale = pitch
			$AudioStreamPlayer.stream = death_by_attack_fx
			$AudioStreamPlayer.play(0.0)
			$AnimationPlayer.play("death_by_attack", -1, 2.0)
			$DeathTimer.start()

func process_state(delta):
	if current_state == State.WALK:
		is_on_floor = true
		walk()
	
	if current_state == State.FLY:
		is_on_floor = false
		fly(delta)
	
	if current_state == State.ATTACK:
		attack()
	
	if current_state == State.BRAKE:
		is_on_floor = true
		brake()
	
	if current_state == State.FALL:
		is_on_floor = false
		fall(delta)
	
	if current_state == State.DEATH_BY_LAVA:
		is_on_floor = false
		death()
	
	if current_state == State.DEATH_BY_ATTACK:
		is_on_floor = false
		death()

func walk():
	velocity.y = 0
	
	if velocity.x < 0:
		$AnimationPlayer.play("walk", -1, -animation_speed)
	else:
		$AnimationPlayer.play("walk", -1, animation_speed)
	
	if not has_sound_played and $AnimatedSprite.frame == 3:
		var pitch = rand_range(0.90, 1.06)
		$AudioStreamPlayer.pitch_scale = pitch
		$AudioStreamPlayer.play(0.0)
		has_sound_played = true
	
	if $AnimatedSprite.frame == 0:
		has_sound_played = false

func fly(delta):
	pass

func attack():
	pass

func brake():
	if velocity.x >= WALK_SPEED_INCREMENT or velocity.x <= -WALK_SPEED_INCREMENT:
		update_state(State.WALK)

func fall(delta):
	if $AnimationPlayer.current_animation != "fly" and velocity.y > 0:
		$AnimationPlayer.play("fall", -1, 0)
	velocity.y += GRAVITY

func death():
	if current_state == State.DEATH_BY_ATTACK:
		velocity = Vector2()
	if current_state == State.DEATH_BY_LAVA:
		velocity = Vector2(0, 20)
		move_and_slide(velocity, Vector2(0, -1))

func bounce(collision_normal):
	var pitch = rand_range(0.95, 1.05)
	$AudioStreamPlayer.stream = bounce_fx
	$AudioStreamPlayer.pitch_scale = pitch
	$AudioStreamPlayer.play(0.0)
	velocity = velocity.bounce(collision_normal) / 2.0
	
	if current_state != State.DEATH_BY_LAVA and current_state != State.DEATH_BY_ATTACK:
		update_state(State.FALL)

func connect_with_enemies():
	for enemy in get_parent().get_node("NavigationMap").enemies:
		if not is_connected("player_collided_with_enemy", enemy, "_on_PlayerCollidedWithEnemy"):
			connect("player_collided_with_enemy", enemy, "_on_PlayerCollidedWithEnemy")

func _on_Area2D_body_entered(body):
	if body.is_in_group("player"):
		update_state(State.DEATH_BY_LAVA)

func _on_DeathTimer_timeout():
	position = original_position
	velocity = Vector2(INITIAL_WALK_SPEED, 100)
	update_state(State.FALL)

func _on_EnemyCollidedWithPlayer(collision_info):
	if collision_info.normal.y < -KILLING_TOLERANCE:
		update_state(State.DEATH_BY_ATTACK)
	else:
		bounce(collision_info.normal)
		velocity *= BOUNCE_FACTOR
