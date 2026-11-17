extends SceneTree

## Run with a real rendering device; resize and quality changes invalidate
## compositor descriptor sets through their engine-owned scene textures.
func _initialize() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in range(3):
		for size in [Vector2i(1280, 720), Vector2i(1000, 680), Vector2i(1440, 900)]:
			root.size = size
			main._set_quality(2)
			await create_timer(0.12).timeout
			main._set_quality(0)
			await create_timer(0.18).timeout
	root.size = Vector2i(1280, 720)
	main.character.hour = 8.5
	main.character.pose_for_shot(Vector3(-1.0, main.world.stand(-1.0, 2.2), 2.2), "Standing")
	main.character.mode = "stroll"
	main.character.route.clear()
	main.character.route.append(Vector2(-1.0, 5.0))
	main.orbit.max_zoom = 12.0
	main.orbit.set_view(Vector3(-1.0, main.world.stand(-1.0, 2.2) + 0.55, 2.2), 0.0, 0.55, 9.0)
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	var output := args.find("--output")
	if output >= 0 and output + 1 < args.size():
		root.get_texture().get_image().save_png(args[output + 1])
	var cup_output := args.find("--cup-output")
	if cup_output >= 0 and cup_output + 1 < args.size():
		main.orbit.max_zoom = 30.0
		main.orbit.set_view(main.farm_life.vane_rotor.global_position, 0.7, 0.3, 24.0)
		await create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[cup_output + 1])
	print("RENDER PASS: nine viewport/quality rebuilds and walking closeup")
	quit(0)
