extends KinematicBody2D

onready var screen_size = get_viewport_rect().size

enum State { WALK, FLY, ATTACK, BRAKING, FALL, DEATH }

const GRAVITY = 400.0
const INITIAL_WALK_SPEED = 40
const WALK_SPEED_INCREMENT = 20
const MAX_SPEED = 1000
const FLY_SPEED = 180
const SPRITE_WIDTH = 32
const SPRITE_HEIGHT = 64
const SPAWN_POSITION = Vector2(539, 597)
var velocity = Vector2(INITIAL_WALK_SPEED, 100) # default: right

var current_state = State.WALK
var current_animation = "walk"
var animation_speed_factor = 0.24
var animation_speed = 0



func _ready():
	current_state = State.WALK
	velocity = Vector2(INITIAL_WALK_SPEED, 100)
	$AnimationPlayer.play(current_animation, -1, animation_speed)

# Rework to go in increments and remain the same while no input is given
func _physics_process(delta):
	process_state(delta)
	
	if velocity.x < 0:
		$AnimatedSprite.flip_h = true
	elif velocity.x > 0:
		$AnimatedSprite.flip_h = false
	
	if current_state != State.DEATH:
		if is_on_floor():
			update_state(State.WALK)
		else:
			if(velocity.y > 0):
				update_state(State.FALL)
		if Input.is_action_pressed("left"):
			velocity.x -= WALK_SPEED_INCREMENT
			if velocity.x > 0 and current_state != State.FLY and current_state != State.FALL:
				$AnimationPlayer.play("brake", -1, 0.0)
			if current_state == State.FLY or current_state == State.FALL:
				$AnimatedSprite.flip_h = true
		elif Input.is_action_pressed("right"):
			velocity.x +=  WALK_SPEED_INCREMENT
			if velocity.x < 0 and current_state != State.FLY and current_state != State.FALL:
				$AnimationPlayer.play("brake", -1, 0.0)
			if current_state == State.FLY or current_state == State.FALL:
				$AnimatedSprite.flip_h = false
		
		if Input.is_action_pressed("up"):
			velocity.y = -FLY_SPEED
			update_state(State.FLY)
			if(not $AnimationPlayer.current_animation == "fly"):
				$AnimationPlayer.play("fly", -1, 2.0)
	
		velocity.x = min(MAX_SPEED, velocity.x)
		velocity.x = max(-MAX_SPEED, velocity.x)
		animation_speed = velocity.x * pow(animation_speed_factor, 2)
	
		move_and_slide(velocity, Vector2(0, -1))
		keep_in_boundaries()
		check_collisions(delta)

func keep_in_boundaries():
	position.x = wrapf(position.x, -SPRITE_WIDTH, screen_size.x + SPRITE_WIDTH / 2)
	position.y = max(position.y, SPRITE_WIDTH / 2)

func check_collisions(delta):
	var collision_info = move_and_collide(velocity * delta, true, true)
	
	# TEMP solution
	if collision_info:
		var collider = collision_info.get_collider()
		if collider.is_in_group("wall"):
			if floor(rad2deg(collision_info.get_angle())) == 90:
				velocity.x = 0
				
				if current_state == State.WALK:
					$AnimationPlayer.seek(0.0)
					$AnimationPlayer.play("walk", -1, 0.0)

func update_state(state):
	current_state = state

func process_state(delta):
	if current_state == State.WALK:
		walk()
	
	if current_state == State.FLY:
		fly(delta)
	
	if current_state == State.ATTACK:
		attack()
	
	if current_state == State.BRAKING:
		braking()
	
	if current_state == State.FALL:
		fall(delta)
	
	if current_state == State.DEATH:
		death()

func walk():
	velocity.y = 1
	
	if velocity.x < 0:
		$AnimationPlayer.play("walk", -1, -animation_speed)
	else:
		$AnimationPlayer.play("walk", -1, animation_speed)

func fly(delta):
	velocity.y += delta * GRAVITY

func attack():
	pass

func braking():
	pass

func fall(delta):
	velocity.y += delta * GRAVITY
	$AnimationPlayer.play("fall", -1, 0)

func death():
	velocity = Vector2(0, 20)
	move_and_slide(velocity, Vector2(0, -1))

func _on_Area2D_body_entered(body):
	update_state(State.DEATH)
	$AnimationPlayer.play("death", -1, 3.0)
	$DeathTimer.start()

func _on_DeathTimer_timeout():
	update_state(State.WALK)
	position = SPAWN_POSITION
	velocity = Vector2(INITIAL_WALK_SPEED, 100)
