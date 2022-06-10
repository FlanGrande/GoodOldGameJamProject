extends Node2D

func _input(event):
	if Input.is_action_pressed("escape"):
		get_tree().quit()
