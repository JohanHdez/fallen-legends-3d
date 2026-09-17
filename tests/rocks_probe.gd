## Sonda: ¿se meten los personajes dentro de las piedras?
##   godot --headless --fixed-fps 60 --path . -- --probe=rocks_probe [--secs=60]
## Reconstruye el contorno VISIBLE de cada roca a la altura del cuerpo (vértices de la malla por
## debajo de BODY_H, envolvente convexa en planta) con las transformadas que main.gd registró al
## colocarlas (`_placed`), sin fiarse de cómo calcula la colisión. Simula la horda moviendo al
## jugador por el mapa y cuenta las veces que el CENTRO de un personaje cae dentro de una roca.
## Salida 0 si no pasa nunca; 1 si pasa.
extends Node

const BODY_H := 1.2          # altura a la que se mide: cintura de un personaje
const DEEP := 0.15           # el centro a menos de esto FUERA del contorno = medio cuerpo metido (cápsula 0,4 m)
const ROCK_WORDS := ["Rock_Medium", "Pebble_Square_4"]

var main: Node
var _hulls: Array = []       # [{"poly": PackedVector2Array, "kind": String, "at": Vector2}]
var _t := 0.0
var _secs := 60.0
var _hop_t := 0.0
var _inside_frames := 0
var _by_kind := {}           # tipo de roca -> muestras dentro
var _samples := 0
var _spawned_inside := 0
var _seen := {}
var _in_blocked := 0         # muestras de cuerpos con el centro en una celda bloqueada (dentro de un muro)


func _ready() -> void:
	main = get_parent()
	_secs = float(main._args.get("secs", "60"))
	if not main._args.has("zombies"):
		main.horde.left_to_spawn = 40
	_collect_rocks()
	var count := {}
	for h in _hulls:
		count[h["kind"]] = int(count.get(h["kind"], 0)) + 1
	print("[ROCAS] contornos medidos: %s" % str(count))


func _collect_rocks() -> void:
	var placed: Dictionary = main._placed
	for path: String in placed:
		var is_rock := false
		for w in ROCK_WORDS:
			if path.contains(w):
				is_rock = true
		if not is_rock:
			continue
		var local := PackedVector3Array()
		for e in main._meshes_of(main._load_gltf(path)):
			var mesh: Mesh = e["mesh"]
			var exf: Transform3D = e["xform"]
			for s in mesh.get_surface_count():
				for v: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
					local.append(exf * v)
		for xf: Transform3D in placed[path]:
			var pts := PackedVector2Array()
			for v in local:
				var w := xf * v
				if w.y <= BODY_H:
					pts.append(Vector2(w.x, w.z))
			if pts.size() < 3:
				continue
			var cell: Vector2i = main._cell_of(xf.origin)
			var on_floor: bool = main._in_map(cell) and MapBuilder.walkable(main.grid[cell.x][cell.y])
			var kind := "cobertura" if on_floor or main._cover_cells.has(cell) else "muro"
			if path.contains("Pebble"):
				# Las lápidas son el guijarro estirado a 2,2 de alto; el resto de guijarros es adorno
				# que se pisa (no cuenta).
				if xf.basis.get_scale().y < 1.8:
					continue
				kind = "lápida"
			_hulls.append({"poly": _shrink(Geometry2D.convex_hull(pts), -DEEP), "kind": kind,
				"at": Vector2(xf.origin.x, xf.origin.z)})


## Encoge un polígono convexo hacia su centroide `d` metros (aprox.): rozar no cuenta.
func _shrink(poly: PackedVector2Array, d: float) -> PackedVector2Array:
	var c := Vector2.ZERO
	for p in poly:
		c += p
	c /= maxf(poly.size(), 1)
	var out := PackedVector2Array()
	for p in poly:
		var v := p - c
		var l := v.length()
		out.append(c + v * maxf(l - d, 0.0) / maxf(l, 0.0001))
	return out


func _physics_process(delta: float) -> void:
	_t += delta
	_hop_t -= delta
	if _hop_t <= 0.0:
		_hop_t = 4.0
		_hop_player()
	var inside_now := 0
	for n in main.get_children():
		var b := n as CharacterBody3D
		if b == null:
			continue
		var p := Vector2(b.global_position.x, b.global_position.z)
		_samples += 1
		var cell: Vector2i = main._cell_of(b.global_position)
		# En la celda de un peñasco se puede estar (la roca no llena la celda): eso lo juzga su contorno.
		if main._in_map(cell) and not MapBuilder.walkable(main.grid[cell.x][cell.y]) \
				and not main._cover_cells.has(cell):
			_in_blocked += 1
			inside_now += 1
		for h in _hulls:
			if (h["at"] as Vector2).distance_to(p) > 10.0:
				continue
			if Geometry2D.is_point_in_polygon(p, h["poly"]):
				inside_now += 1
				_by_kind[h["kind"]] = int(_by_kind.get(h["kind"], 0)) + 1
				if main._args.has("rocklog"):
					print("[ROCAS] t=%.1f %s en %s dentro de %s de %s (%s)" % [_t, b.name, b.global_position, h["kind"], h["at"], "jugador" if b == main.player else "criatura"])
				if not _seen.has(b):
					_spawned_inside += 1
				break
		_seen[b] = true
	if inside_now > 0:
		_inside_frames += 1
	if _t >= _secs:
		_finish()


## Lleva al jugador a una celda de campo al azar: así las criaturas cruzan el mapa entero.
func _hop_player() -> void:
	var cells: Array = []
	for x in main.mw:
		for y in main.mh:
			if MapBuilder.walkable(main.grid[x][y]) and main.zones[x][y] == 0:
				cells.append(Vector2i(x, y))
	if cells.is_empty():
		return
	var c: Vector2i = cells[main.rng.randi() % cells.size()]
	main.player.global_position = main._cell_pos(c.x, c.y) + Vector3(0, 0.3, 0)


func _finish() -> void:
	set_physics_process(false)
	var ok := _inside_frames == 0
	print("[ROCAS] %.0f s simulados, %d muestras de cuerpos; fotogramas con alguien metido en roca o muro: %d; nacidos dentro: %d; en celda bloqueada: %d; metidos en roca por tipo: %s" % [
		_t, _samples, _inside_frames, _spawned_inside, _in_blocked, str(_by_kind)])
	print("rocks_probe: %s" % ("OK" if ok else "FALLO"))
	main.get_tree().quit(0 if ok else 1)
