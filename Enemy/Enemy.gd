extends KinematicBody2D

signal request_new_path

export var walk_fx: AudioStreamSample
export var fly_fx: AudioStreamSample
export var bounce_fx: AudioStreamSample

onready var screen_size = get_viewport_rect().size

enum State { WALK, FLY, ATTACK, FALL, DEATH, WANDER, SEEK }

const GRAVITY = 2
const INITIAL_WALK_SPEED = 0
const WALK_SPEED_INCREMENT = 8
const MAX_SPEED = 120
const MIN_SPEED = 60
const FLY_SPEED = 40
const SPRITE_WIDTH = 32
const SPRITE_HEIGHT = 64
const SPAWN_POSITION = Vector2(539, 597)
const MINIMUM_PATH_TIME = 1
const MAXIMUM_PATH_TIME = 5
const MINIMUM_FLAP_TIME = 0.3
const MAXIMUM_FLAP_TIME = 1.2

var velocity = Vector2(INITIAL_WALK_SPEED, 0) # default: right
var current_state = State.FALL
var current_animation = "fall"
var animation_speed_factor = 0.24
var animation_speed = 0
var is_on_floor = false

var has_sound_played = false

var path = []
var target_position = Vector2()
var next_position_in_path = Vector2()
var has_decided_next_movement = false
var movement_distance = 0
var distance_tolerance = 10
var almost_dies = false


func _ready():
	randomize()
	current_state = State.FALL
	velocity = Vector2(INITIAL_WALK_SPEED, 0)
	$AnimationPlayer.play(current_animation, -1, animation_speed)
	$PathTimer.start(rand_range(MINIMUM_PATH_TIME, MAXIMUM_PATH_TIME))
	$FlapTimer.start(rand_range(MINIMUM_FLAP_TIME, MAXIMUM_FLAP_TIME))
	connect("request_new_path", get_parent(), "_on_RequestNewPath", [self])
	emit_signal("request_new_path")

# Rework to go in increments and remain the same while no input is given
func _physics_process(delta):
	movement_distance = MAX_SPEED
	process_state(delta)
	
	if velocity.x < 0 and current_state != State.FLY and current_state != State.FALL:
		$AnimatedSprite.flip_h = true
	elif velocity.x > 0 and current_state != State.FLY and current_state != State.FALL:
		$AnimatedSprite.flip_h = false
	
	if current_state != State.DEATH:
		if not is_on_floor:
			update_state(State.FALL)
		
		if velocity.x < 0:
			if current_state == State.FLY or current_state == State.FALL:
				$AnimatedSprite.flip_h = true
		elif velocity.x > 0:
			if current_state == State.FLY or current_state == State.FALL:
				$AnimatedSprite.flip_h = false
		
		if velocity.y < 0:
			update_state(State.FLY)
		
		if path.size() > 0:
			var distance_to_next_point = position.distance_to(path[0])
			if not has_decided_next_movement:
				target_position = get_next_point()
				# First, force maximum speed
				velocity = (target_position - position) * MAX_SPEED
				velocity = velocity.clamped(MAX_SPEED)
				# Then randomize it a little bit a clamp it again
				velocity = velocity * rand_range(0.5, 1.0)
				velocity = velocity.clamped(MAX_SPEED)
				has_decided_next_movement = true
				
			if distance_to_next_point < distance_tolerance:
				path.remove(0)
				has_decided_next_movement = false
		else:
			emit_signal("request_new_path")
		
		animation_speed = velocity.x * pow(animation_speed_factor, 2)
		
		check_collisions(delta)
		move_and_collide(velocity * delta)
		keep_in_boundaries()
		

func keep_in_boundaries():
	position.x = wrapf(position.x, -SPRITE_WIDTH, screen_size.x + SPRITE_WIDTH / 2)
	position.y = max(position.y, SPRITE_WIDTH / 2)

func check_collisions(delta):
	var collision_info = move_and_collide(velocity * delta, true, true)
	
	if collision_info:
		var collider = collision_info.get_collider()
		
		if collider.is_in_group("wall"):
			if floor(rad2deg(collision_info.get_angle())) == 0:
				update_state(State.WALK)
			else:
				var pitch = rand_range(0.95, 1.05)
				$AudioStreamPlayer.stream = bounce_fx
				$AudioStreamPlayer.pitch_scale = pitch
				$AudioStreamPlayer.play(0.0)
				velocity = velocity.bounce(collision_info.normal) / 2.0
				update_state(State.FALL)
		
		if collider.is_in_group("enemy"):
			var pitch = rand_range(0.95, 1.05)
			$AudioStreamPlayer.stream = bounce_fx
			$AudioStreamPlayer.pitch_scale = pitch
			$AudioStreamPlayer.play(0.0)
			velocity = velocity.bounce(collision_info.normal) / 2.0
			update_state(State.FALL)
	else:
		if is_on_floor:
			update_state(State.FALL)

func update_state(state):
	if current_state != state:
		current_state = state
		
		if current_state == State.WALK:
			$AudioStreamPlayer.stream = walk_fx
		else:
			$AudioStreamPlayer.stop()
		
		if current_state == State.FLY:
			$AudioStreamPlayer.stream = fly_fx

func process_state(delta):
	if current_state == State.WALK:
		is_on_floor = true
		walk()
	
	if current_state == State.FLY:
		is_on_floor = false
		fly(delta)
	
	if current_state == State.ATTACK:
		attack()
	
	if current_state == State.FALL:
		is_on_floor = false
		fall(delta)
	
	if current_state == State.DEATH:
		is_on_floor = false
		death()

func walk():
	velocity.y = 0
	
	if velocity.x < 0:
		$AnimationPlayer.play("walk", -1, -animation_speed)
	else:
		$AnimationPlayer.play("walk", -1, animation_speed)
	
	if not has_sound_played and $AnimatedSprite.frame == 3:
		var pitch = rand_range(0.98, 1.02)
		$AudioStreamPlayer.pitch_scale = pitch
		$AudioStreamPlayer.play(0.0)
		has_sound_played = true
	
	if $AnimatedSprite.frame == 0:
		has_sound_played = false

func fly(delta):
	pass

func attack():
	pass

func fall(delta):
	if $AnimationPlayer.current_animation != "fly" and velocity.y > 0:
		$AnimationPlayer.play("fall", -1, 0)
	velocity.y += GRAVITY

func death():
	velocity = Vector2(0, 20)
	move_and_slide(velocity, Vector2(0, -1))

func get_next_point():
	if path.size() > 0:
		var current_position = position
		var next_point = path[0]
		return next_point
	return position

func _on_Area2D_body_entered(body):
	if body.is_in_group("enemy") and name == body.name:
		update_state(State.DEATH)
		$AnimationPlayer.play("death", -1, 3.0)
		$DeathTimer.start()

func _on_DeathTimer_timeout():
	queue_free()

func _on_PathTimer_timeout():
	$PathTimer.start(rand_range(MINIMUM_PATH_TIME, MAXIMUM_PATH_TIME))
	emit_signal("request_new_path")

func _on_FlapTimer_timeout():
	if current_state == State.FLY:
		if(not $AnimationPlayer.current_animation == "fly"):
			var pitch = rand_range(0.95, 1.05)
			$AudioStreamPlayer.stream = fly_fx
			$AudioStreamPlayer.pitch_scale = pitch
			$AudioStreamPlayer.play(0.0)
			$AnimationPlayer.play("fly", -1, 4.0)
	
	$FlapTimer.start(rand_range(MINIMUM_FLAP_TIME, MAXIMUM_FLAP_TIME))
