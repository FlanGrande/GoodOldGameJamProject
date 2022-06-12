extends Area2D

func connect_death_signals():
	var nav_children = find_parent("MainGame").get_node("NavigationMap").get_children()
	
	for child in nav_children:
		if child.is_in_group("enemy"):
			if not is_connected("body_entered", child, "_on_Area2D_body_entered"):
				connect("body_entered", child, "_on_Area2D_body_entered")
	
	pass


func _on_NavigationMap_spawn_enemy():
	connect_death_signals()
