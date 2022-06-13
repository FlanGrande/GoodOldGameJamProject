extends Navigation2D

signal spawn_enemy

onready var screen_size = get_viewport_rect().size

export var minimum_spawn_time = 10
export var maximum_spawn_time = 20
export(PackedScene) var enemy_scene

const NAV_OFFSET_X = 8000
const NAV_OFFSET_Y = 80

var enemies = []
var max_enemies = 5
var target_position = Vector2()
var polygons_drawn = []

# Called when the node enters the scene tree for the first time.
func _ready():
	randomize()
	$SpawnTimer.start(rand_range(minimum_spawn_time, minimum_spawn_time))
	#spawn_enemy()
	#spawn_enemy()
	#spawn_enemy()

func _process(delta):
	pass

#func _update_navigation_path(start_position, end_position):
#	for enemy in enemies:
#		enemy.path = get_simple_path(start_position, end_position, true)
#
#		for point in enemy.path:
#			var new_polygon = Polygon2D.new()
#			new_polygon.polygon = [Vector2(0, 0), Vector2(0, 10), Vector2(10, 10), Vector2(10, 0), Vector2(0, 0)]
#			new_polygon.position = point
#			add_child(new_polygon)
#			polygons_drawn.append(new_polygon)
#		#enemy.path.remove(0)
#		#enemy.set_process(true)
#
#	# get_simple_path is part of the Navigation2D class.
#	# It returns a PoolVector2Array of points that lead you
#	# from the start_position to the end_position.
#	# The first point is always the start_position.
#	# We don't need it in this example as it corresponds to the character's position.

#func _unhandled_input(event):
#	if not event.is_action_pressed("click"):
#		return
#
#	for pol in polygons_drawn:
#		remove_child(pol)
#
#	polygons_drawn.clear()
#
#	for enemy in enemies:
#		target_position = Vector2(rand_range(0, screen_size.x), rand_range(0, screen_size.y))
#		_update_navigation_path(enemy.position, target_position)

func spawn_enemy():
	var new_enemy = enemy_scene.instance().duplicate()
	var spawn_point = get_node("Spawn" + str(randi()%4+1))
	new_enemy.position = spawn_point.position
	add_child(new_enemy)

func _on_SpawnTimer_timeout():
	emit_signal("spawn_enemy")
	
	for child in get_children():
		if child.is_in_group("enemy"):
			if not child in enemies:
				enemies.append(child)
	
	if enemies.size() < max_enemies:
		spawn_enemy()
		$SpawnTimer.start(rand_range(minimum_spawn_time, minimum_spawn_time))

func _on_RequestNewPath(enemy_that_made_the_request: KinematicBody2D):
	target_position = Vector2(rand_range(-NAV_OFFSET_X, screen_size.x + NAV_OFFSET_X), rand_range(0, screen_size.y - NAV_OFFSET_Y))
	enemy_that_made_the_request.path = get_simple_path(enemy_that_made_the_request.position, target_position, true)

func _on_EnemyDied(enemy_that_died: KinematicBody2D):
	var index = enemies.find(enemy_that_died)
	if(index != -1):
		enemies[index].queue_free()
		enemies.remove(index)
	else:
		print("enemy not found when it died")
