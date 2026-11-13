extends RefCounted
class_name FarmPaths

## Port of src/farm-paths.js: a shared 0.6-tile walking graph. Long detours
## around buildings, beds and water use A*; the walker still slides along the
## collision world for the final short step off the graph.

const STEP := 0.6

var nodes: Array = []   # {x, z, edges: [[index, distance], ...]}

func _init(world: FarmWorld) -> void:
	var x := -8.4
	while x <= 8.4001:
		var z := 0.6
		while z <= 10.2001:
			if world.walkable(x, z):
				nodes.append({"x": x, "z": z, "edges": []})
			z += STEP
		x += STEP

	for i in range(nodes.size()):
		for j in range(i + 1, nodes.size()):
			var a: Dictionary = nodes[i]
			var b: Dictionary = nodes[j]
			var dx: float = float(a["x"]) - float(b["x"])
			var dz: float = float(a["z"]) - float(b["z"])
			var distance := sqrt(dx * dx + dz * dz)
			if distance < 0.9 and _clear(world, a, b, distance):
				(a["edges"] as Array).append([j, distance])
				(b["edges"] as Array).append([i, distance])
	_add_porch_chain(world)

func _add_porch_chain(world: FarmWorld) -> void:
	# The normal grid stops at the porch obstacle. Add an explicit chain up the
	# steps and across the deck so A* can route the walker through the door.
	var chain: Array[Vector2] = [
		Vector2(-1.0, 1.8), Vector2(-1.0, 1.35), Vector2(-1.0, 1.0),
		Vector2(-1.0, 0.65), Vector2(-1.0, 0.35), Vector2(-1.0, 0.15),
		Vector2(-1.0, -0.2), Vector2(-1.0, -0.55), Vector2(-1.0, -0.9),
	]
	var indices: Array[int] = []
	var grid_count := nodes.size()
	for point in chain:
		nodes.append({"x": point.x, "z": point.y, "edges": [], "porch": true})
		indices.append(nodes.size() - 1)
	for i in range(indices.size() - 1):
		_add_edge(indices[i], indices[i + 1])
	# Join the yard end and first step to the surrounding walkable grid.
	for k in range(mini(2, indices.size())):
		var start := indices[k]
		var start_node: Dictionary = nodes[start]
		for i in range(grid_count):
			var node: Dictionary = nodes[i]
			var dx: float = float(node["x"]) - float(start_node["x"])
			var dz: float = float(node["z"]) - float(start_node["z"])
			var distance := sqrt(dx * dx + dz * dz)
			if distance < 1.5 and _clear(world, start_node, node, distance):
				_add_edge(start, i)

func _add_edge(a: int, b: int) -> void:
	var na: Dictionary = nodes[a]
	var nb: Dictionary = nodes[b]
	var dx: float = float(na["x"]) - float(nb["x"])
	var dz: float = float(na["z"]) - float(nb["z"])
	var distance := sqrt(dx * dx + dz * dz)
	(na["edges"] as Array).append([b, distance])
	(nb["edges"] as Array).append([a, distance])

func _clear(world: FarmWorld, a: Dictionary, b: Dictionary, distance: float) -> bool:
	var steps := maxi(1, int(ceil(distance / 0.18)))
	for i in range(steps + 1):
		var u := float(i) / float(steps)
		var x: float = float(a["x"]) + (float(b["x"]) - float(a["x"])) * u
		var z: float = float(a["z"]) + (float(b["z"]) - float(a["z"])) * u
		if not world.walkable(x, z):
			return false
	return absf(world.height(float(a["x"]), float(a["z"])) - world.height(float(b["x"]), float(b["z"]))) < distance * 0.55 + 0.05

func closest(world: FarmWorld, point: Vector2) -> int:
	if nodes.is_empty():
		return -1
	if world != null and world.is_on_porch(point.x, point.y):
		var best_porch := -1
		var best_distance := INF
		for i in range(nodes.size()):
			if not bool(nodes[i].get("porch", false)):
				continue
			var node: Dictionary = nodes[i]
			var dx: float = float(node["x"]) - point.x
			var dz: float = float(node["z"]) - point.y
			var distance := dx * dx + dz * dz
			if distance < best_distance:
				best_distance = distance
				best_porch = i
		if best_porch >= 0:
			return best_porch
	var order: Array = []
	for i in range(nodes.size()):
		var node: Dictionary = nodes[i]
		var dx: float = float(node["x"]) - point.x
		var dz: float = float(node["z"]) - point.y
		order.append([dx * dx + dz * dz, i])
	order.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for k in range(mini(order.size(), 16)):
		var node: Dictionary = nodes[int(order[k][1])]
		if _clear(world, {"x": point.x, "z": point.y}, node,
				Vector2(point.x - float(node["x"]), point.y - float(node["z"])).length()):
			return int(order[k][1])
	return int(order[0][1])

func route(world: FarmWorld, from: Vector2, to: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if nodes.is_empty():
		result.append(to)
		return result
	var start := closest(world, from)
	var finish := closest(world, to)
	if start < 0 or finish < 0:
		result.append(to)
		return result

	var cost := {start: 0.0}
	var previous := {}
	var open := {start: true}
	while not open.is_empty():
		var current := -1
		var best := INF
		for index in open.keys():
			var node: Dictionary = nodes[int(index)]
			var goal: Dictionary = nodes[finish]
			var heuristic: float = float(cost[int(index)]) + Vector2(
				float(node["x"]) - float(goal["x"]),
				float(node["z"]) - float(goal["z"])).length()
			if heuristic < best:
				best = heuristic
				current = int(index)
		if current == finish:
			var path: Array[Vector2] = [to]
			var cursor := finish
			while cursor != start:
				var node: Dictionary = nodes[cursor]
				path.push_front(Vector2(float(node["x"]), float(node["z"])))
				cursor = int(previous[cursor])
			var start_node: Dictionary = nodes[start]
			path.push_front(Vector2(float(start_node["x"]), float(start_node["z"])))
			return path

		open.erase(current)
		var current_node: Dictionary = nodes[current]
		for edge in current_node["edges"]:
			var next := int(edge[0])
			var candidate: float = float(cost[current]) + float(edge[1])
			if candidate < float(cost.get(next, INF)):
				cost[next] = candidate
				previous[next] = current
				open[next] = true

	result.append(to)
	return result
