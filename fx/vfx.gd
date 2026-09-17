## Efectos visuales de Fallen Legends 3D: partículas del Kenney Particle Pack, fogonazos, rayos,
## aros y discos de zona, esferas de las trampas puestas, nubes de gas, polvo de golpe, matas de
## espinas, burbuja de guardia y la cadena del ancla. Movido desde main.gd (2026-09-16) para que el combate de cualquier leyenda,
## sea tuya o de un bot, dibuje lo mismo. Solo dibuja: no decide daño ni estado.
## Lo que es temporal se apunta en `sparks` con su vida y `tick` lo libera.
class_name Vfx
extends RefCounted

const SPARK := Color(0.62, 0.80, 1.0)
# --- esferas de las trampas puestas (petición del usuario, 2026-09-17) ---
const ORB_R := 0.30                   # radio del núcleo de la esfera eléctrica
const ORB_H := 0.95                   # a qué altura flota
const ORB_ARMS := 4                   # brazos de plasma que le saltan alrededor
const ORB_SEGS := 3                   # tramos de cada brazo
const ORB_STEP := 0.09                # cada cuánto se rehacen los brazos (s)
const NOX_R := 0.42                   # radio de la esfera de la Baliza Nox, apoyada en el suelo

var world: Node3D                     # donde cuelgan los efectos (la raíz de la escena)
var rng: RandomNumberGenerator        # el de la partida: el reparto de rayos y púas sale de él
var touch := false                    # en móvil, la mitad de partículas en las nubes
var sparks: Array = []                # efectos temporales: {node, life}
var _cache := {}
var _bubble_sh: Shader = null         # uno para todas: compilarlo por burbuja cuesta y se filtra


func _init(p_world: Node3D, p_rng: RandomNumberGenerator, p_touch: bool) -> void:
	world = p_world
	rng = p_rng
	touch = p_touch


## Libera los efectos temporales que ya han cumplido.
func tick(delta: float) -> void:
	for i in range(sparks.size() - 1, -1, -1):
		sparks[i]["life"] -= delta
		if sparks[i]["life"] <= 0.0:
			sparks[i]["node"].queue_free()
			sparks.remove_at(i)


## Material de partícula: cartel que siempre mira a cámara, sin iluminar, teñible.
## Las texturas de Kenney son blancas, así que el color sale del `color` del emisor.
func _fx_mat(tex: String) -> QuadMesh:
	var key := "mesh:" + tex
	if _cache.has(key):
		return _cache[key]
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Aditivo para lo que brilla (chispas, magia, luz); mezcla normal para humo y tierra,
	# que en aditivo se lavan a blanco y parecen vapor.
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX if tex.begins_with("smoke") or tex.begins_with("dirt") \
		else BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = load("res://assets/particles/%s.png" % tex)
	m.vertex_color_use_as_albedo = true
	m.disable_receive_shadows = true
	q.material = m
	_cache[key] = q
	return q


## Estallido de una sola vez: se libera solo al terminar.
func burst(tex: String, pos: Vector3, color: Color, amount := 16, life := 0.6,
		speed := 4.0, size := 0.6, grav := -2.0, spread := 60.0, from_radius := 0.1) -> void:
	var p := CPUParticles3D.new()
	p.mesh = _fx_mat(tex)
	p.position = pos
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, grav, 0)
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	p.color = color
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = from_radius
	world.add_child(p)
	sparks.append({"node": p, "life": life + 0.4})


## Emisor continuo colgado de un nodo: la nube de gas, el aura de la mejora.
func emitter(parent: Node3D, tex: String, color: Color, radius: float,
		amount := 40, life := 2.0, rise := 0.35, size := 2.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = _fx_mat(tex)
	p.amount = amount
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = rise * 0.4
	p.initial_velocity_max = rise
	p.gravity = Vector3.ZERO
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	p.color = color
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.position = Vector3(0, 0.3, 0)
	parent.add_child(p)
	return p


## Fogonazo esférico que crece y se apaga. Lee como "aquí ha impactado algo".
func flash(at: Vector3, color: Color, size := 1.2, life := 0.18) -> void:
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = size * 0.5
	sph.height = size
	sph.radial_segments = 10
	sph.rings = 6
	mi.mesh = sph
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = color
	mi.material_override = m
	mi.position = at
	world.add_child(mi)
	var tw := world.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 1.8, life)
	tw.tween_property(m, "albedo_color:a", 0.0, life)
	tw.chain().tween_callback(mi.queue_free)


## Rayo: una línea QUEBRADA de arriba abajo. Antes era un cilindro recto, que no lee como rayo.
func spark(at: Vector3, col := Color(0.85, 0.92, 1.0)) -> void:
	var root := Node3D.new()
	world.add_child(root)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(col.r, col.g, col.b, 1.0)
	var top := 9.0
	var segs := 7
	var pts: Array[Vector3] = []
	for i in segs + 1:
		var t := float(i) / segs
		var wob := (1.0 - absf(t - 0.5) * 1.6) * 0.55      # más quebrado por el centro
		pts.append(at + Vector3(rng.randf_range(-wob, wob), top * (1.0 - t), rng.randf_range(-wob, wob)))
	for i in segs:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var d := b - a
		var c := CylinderMesh.new()
		c.top_radius = 0.05
		c.bottom_radius = 0.05
		c.height = d.length()
		c.radial_segments = 4
		var mi := MeshInstance3D.new()
		mi.mesh = c
		mi.material_override = mat
		mi.transform = Transform3D(Basis(Quaternion(Vector3.UP, d.normalized())), a + d * 0.5)
		root.add_child(mi)
	sparks.append({"node": root, "life": 0.18})
	flash(at + Vector3(0, 0.3, 0), col, 1.6, 0.22)


## Esfera ELÉCTRICA flotante de la Trampa eléctrica (petición del usuario, 2026-09-17; antes era un
## disco pequeño en el suelo que no se leía como trampa): un núcleo que late y flota, con brazos
## quebrados saltando alrededor como una bola de plasma. Los brazos se rehacen con senos del reloj y
## NO con `rng`: dibujar no puede cambiar las trazas deterministas de la Horda.
func electric_orb(color: Color) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(0, ORB_H, 0)
	var core := MeshInstance3D.new()
	core.name = "Core"
	var sph := SphereMesh.new()
	sph.radius = ORB_R
	sph.height = ORB_R * 2.0
	sph.radial_segments = 12
	sph.rings = 7
	core.mesh = sph
	# Bola sólida clara con un halo que suma luz: en un claro soleado, una esfera solo aditiva se
	# lavaba con el fondo y no se veía.
	var solid := StandardMaterial3D.new()
	solid.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	solid.albedo_color = Color(minf(color.r + 0.35, 1.0), minf(color.g + 0.3, 1.0), 1.0)
	core.material_override = solid
	root.add_child(core)
	var halo := MeshInstance3D.new()
	halo.name = "Halo"
	var hs := SphereMesh.new()
	hs.radius = ORB_R * 1.7
	hs.height = ORB_R * 3.4
	hs.radial_segments = 10
	hs.rings = 6
	halo.mesh = hs
	halo.material_override = _glow(color, 0.30)
	root.add_child(halo)
	# Los brazos son cilindros finos (como los rayos): una línea de un píxel se perdía a dos metros.
	var arms := Node3D.new()
	arms.name = "Arms"
	var bolt := CylinderMesh.new()
	bolt.top_radius = 0.035
	bolt.bottom_radius = 0.035
	bolt.height = 1.0
	bolt.radial_segments = 4
	var mat := _glow(Color(minf(color.r + 0.3, 1.0), minf(color.g + 0.3, 1.0), 1.0), 1.0)
	for i in ORB_ARMS * ORB_SEGS:
		var mi := MeshInstance3D.new()
		mi.mesh = bolt
		mi.material_override = mat
		arms.add_child(mi)
	root.add_child(arms)
	return root


## Esfera de la Baliza Nox apoyada en el suelo (petición del usuario, 2026-09-17; antes era un poste):
## una bola turbia que, al activarse, se enciende y empieza a echar humo.
func nox_orb(color: Color) -> Node3D:
	var root := Node3D.new()
	var core := MeshInstance3D.new()
	core.name = "Core"
	var sph := SphereMesh.new()
	sph.radius = NOX_R
	sph.height = NOX_R * 2.0
	sph.radial_segments = 16
	sph.rings = 9
	core.mesh = sph
	core.position = Vector3(0, NOX_R * 0.95, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r * 0.9, color.g * 1.15, color.b * 0.8)
	m.emission_enabled = true
	m.emission = color * 0.35
	m.roughness = 0.45
	core.material_override = m
	root.add_child(core)
	var smoke := emitter(root, "smoke_04", Color(color.r * 0.75, color.g, color.b * 0.45, 0.5), NOX_R * 0.8,
		14, 1.8, 0.6, 0.5)
	smoke.name = "Smoke"
	smoke.position = Vector3(0, NOX_R, 0)
	smoke.emitting = false                 # humo solo cuando se activa
	return root


## Anima una esfera puesta: late, flota, rehace los brazos y, si ya está activa, echa humo. `t` son
## los segundos que lleva puesta; `live` es si ya está armada (por equipos tarda PVP_ARM_TIME).
func tick_orb(root: Node3D, t: float, live: bool) -> void:
	if root == null or not is_instance_valid(root):
		return
	var core := root.get_node_or_null("Core") as MeshInstance3D
	if core != null:
		core.scale = Vector3.ONE * ((1.0 + 0.08 * sin(t * 7.0)) if live else 0.78)
	var arms := root.get_node_or_null("Arms") as Node3D
	if arms != null:
		root.position.y = ORB_H + 0.07 * sin(t * 2.6)
		var step := int(t / ORB_STEP)
		if step != int(root.get_meta("fx_step", -1)):
			root.set_meta("fx_step", step)
			_plasma(arms, float(step), live)
	var smoke := root.get_node_or_null("Smoke") as CPUParticles3D
	if smoke != null and smoke.emitting != live:
		smoke.emitting = live


## Recoloca los brazos de plasma en el paso `k`: ORB_ARMS quebradas cortas que salen del núcleo. No
## crea nada: mueve los cilindros que ya tiene (ORB_ARMS × ORB_SEGS).
func _plasma(arms: Node3D, k: float, live: bool) -> void:
	arms.visible = live
	if not live:
		return
	var n := 0
	for i in ORB_ARMS:
		var a := TAU * i / ORB_ARMS + k * 0.7
		var dir := Vector3(cos(a), sin(k * 1.3 + i * 2.1) * 0.6, sin(a)).normalized()
		var prev := dir * ORB_R
		for s in range(1, ORB_SEGS + 1):
			var p := dir * (ORB_R + s * 0.17) + Vector3(
				sin(k * 3.1 + s * 2.3 + i), cos(k * 2.7 + s * 1.7 + i), sin(k * 4.3 + s * 1.1 - i)) * 0.10
			span(arms.get_child(n) as MeshInstance3D, prev, p)
			prev = p
			n += 1


## Material que brilla por sí solo y suma luz: el de rayos, núcleos y brazos.
func _glow(color: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	return m


func ring(radius: float, color: Color, alpha := 0.9) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = maxf(0.05, radius - 0.12)
	t.outer_radius = radius
	var mi := MeshInstance3D.new()
	mi.mesh = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	return mi


## Disco tenue para el relleno de una zona ya colocada (sin borde duro, como en el juego 2D).
func disc(radius: float, color: Color, alpha := 0.18) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = 0.04
	var mi := MeshInstance3D.new()
	mi.mesh = c
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	mi.material_override = m
	return mi


## Nube densa: tres capas de humo a distintas alturas y velocidades. Una sola capa se veía
## rala y no tapaba nada.
func gas_cloud(node: Node3D, rad: float, col: Color) -> void:
	# Muchas bocanadas MEDIANAS, no pocas gigantes: con partículas de 6 m la cámara se metía
	# dentro de ellas y no se veía nada.
	# En móvil, la mitad: son ~1.500 partículas por nube entre las tres capas.
	var n := int(clampf(rad * (35.0 if touch else 70.0), 110.0, 700.0))
	# Verde amarillento y bien opaco: sobre hierba verde, un verde apagado no se ve.
	var tint := Color(0.72, 1.0, 0.25, 0.95)
	var low := emitter(node, "smoke_04", tint, rad * 0.92, n, 3.6, 0.14, rad * 0.40)
	low.position = Vector3(0, 0.30, 0)
	var mid := emitter(node, "smoke_02", Color(tint.r, tint.g, tint.b, 0.80), rad * 0.80,
		int(n * 0.7), 4.2, 0.30, rad * 0.32)
	mid.position = Vector3(0, 1.00, 0)
	var top := emitter(node, "smoke_09", Color(tint.r * 0.9, tint.g, tint.b, 0.60), rad * 0.62,
		int(n * 0.45), 4.8, 0.52, rad * 0.26)
	top.position = Vector3(0, 1.80, 0)


## El ancla pesa: cada mandoble levanta el suelo (petición del usuario). El abanico de polvo sigue
## al golpe — el cono de ~63° a cada lado en el mandoble normal, la vuelta entera si va cargado —
## así que se ve DÓNDE ha pegado, que es justo lo que hace legible un área de golpe grande.
func swing_dust(origin: Vector3, face: Vector3, rad: float, full: bool, arc: float,
		amount := 1.0) -> void:
	var span := TAU if full else deg_to_rad(arc)
	var n := maxi(int(clampi(int(span / 0.42), 5, 11) * amount), 3)
	var base_a := atan2(face.x, face.z)
	for k in n:
		var a: float = base_a + lerpf(-span * 0.5, span * 0.5, float(k) / float(n - 1))
		var p := origin + Vector3(sin(a), 0.0, cos(a)) * rad * 0.75 + Vector3(0, 0.08, 0)
		burst("dirt_02", p, Color(0.72, 0.62, 0.45, 0.95), maxi(int(16 * amount), 4), 0.85, 3.0, 0.55, -3.2, 72.0, 0.4)
		burst("dirt_03", p, Color(0.58, 0.48, 0.34, 0.9), maxi(int(6 * amount), 2), 0.6, 3.6, 0.3, -5.0, 45.0, 0.25)
	# Una polvareda baja que une el abanico, para que no se vean matas sueltas. Clara a propósito:
	# sobre hierba verde un marrón oscuro no se lee.
	burst("smoke_04", origin + face * rad * (0.0 if full else 0.45) + Vector3(0, 0.15, 0),
		Color(0.80, 0.74, 0.62, 0.62), maxi(int(28 * amount), 8), 1.3, 1.3, 1.15, 0.3, 78.0, rad * 0.6)


## El estallido de una zona. Rayos para la tormenta, una corona de tierra para los golpes de
## suelo (Terremoto y Golpe de tierra) y una andanada que cae del cielo para la Lluvia de flechas.
func zone_burst(st: Dictionary, at: Vector3, rad: float) -> void:
	var col: Color = st.get("col", SPARK)
	match String(st.get("fx", "spark")):
		"dust":
			# Ojo con el orden: el penúltimo par es (gravedad, apertura) y el último el radio de
			# emisión. El TAMAÑO es el argumento 7: ponerle ahí el radio de la zona daba
			# partículas de 3 m y la cámara se metía dentro, como ya pasó con el gas.
			burst("dirt_02", at + Vector3(0, 0.2, 0), Color(0.62, 0.52, 0.38, 0.95),
				90, 1.1, 3.5, 0.9, -3.0, 80.0, rad * 0.8)
			burst("smoke_04", at + Vector3(0, 0.3, 0), Color(0.70, 0.62, 0.50, 0.7),
				45, 1.6, 1.6, 1.5, 0.3, 70.0, rad * 0.9)
			for k in 8:
				var a := TAU * k / 8.0
				burst("dirt_03", at + Vector3(cos(a), 0.1, sin(a)) * rad * 0.85,
					Color(0.55, 0.46, 0.33, 0.9), 12, 0.9, 2.6, 0.5, -3.0, 85.0, 0.4)
		"arrows":
			# Caen de arriba: nacen a 6 m y la gravedad fuerte las clava en el suelo. `_burst`
			# siempre lanza hacia arriba, así que la caída tiene que salir de la gravedad.
			# Pocas y finas: 70 partículas aditivas en una bola de 2,5 m se suman hasta dar un
			# disco crema opaco, no una andanada. Se ven mejor 34 estrías que 70 manchas.
			burst("trace_01", at + Vector3(0, 6.0, 0), Color(col.r, col.g, col.b, 0.5),
				34, 0.85, 0.6, 0.22, -18.0, 15.0, rad * 0.95)
			burst("dirt_01", at + Vector3(0, 0.15, 0), Color(0.6, 0.55, 0.4, 0.8),
				30, 0.8, 1.6, 0.5, -2.0, 80.0, rad * 0.8)
		_:
			for k in int(st.get("bolts", 0)):
				var a := TAU * k / maxi(1, int(st["bolts"]))
				spark(at + Vector3(cos(a), 0, sin(a)) * rad * 0.6 * rng.randf())


## Mata de púas: tres conos inclinados que salen del suelo. Antes era un disco plano de 70 cm
## sobre hierba verde y sencillamente no se veía.
func spike_clump(rad: float) -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.86, 0.87, 0.78)
	mat.roughness = 0.6
	var grow := clampf(rad / 0.72, 1.0, 3.0)       # 0,72 m era el radio original
	for i in int(3 * grow):
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = 0.13 * grow
		c.height = rng.randf_range(1.0, 1.5) * grow
		c.radial_segments = 6
		var mi := MeshInstance3D.new()
		mi.mesh = c
		mi.material_override = mat
		var a := TAU * i / float(maxi(1, int(3 * grow))) + rng.randf() * 0.7
		mi.position = Vector3(cos(a), 0, sin(a)) * rad * rng.randf_range(0.15, 0.75) + Vector3(0, c.height * 0.45, 0)
		mi.rotation = Vector3(rng.randf_range(-0.25, 0.25), a, rng.randf_range(-0.25, 0.25))
		root.add_child(mi)
	# marca oscura en el suelo, aplastada como las zonas del juego
	var mark := disc(rad, Color(0.25, 0.2, 0.12), 0.35)
	mark.position = Vector3(0, 0.03, 0)
	root.add_child(mark)
	return root


## Burbuja de guardia. El aro en el suelo era otro círculo blanco de los que el juego ya quitó
## (CLAUDE.md, "marcas en el suelo"), y encima el esqueleto no lleva escudo que levantar. Esta es
## la misma idea que la burbuja de inmunidad del 2D, pero en 3D una esfera translúcida a secas se
## ve como un disco plano que tapa el fondo: el brillo va por FRESNEL, así que enciende el borde
## y deja el centro casi transparente, que es lo que la lee como cascarón y no como mancha.
func bubble(radius: float, color: Color) -> MeshInstance3D:
	var sph := SphereMesh.new()
	sph.radius = radius
	sph.height = radius * 2.0
	sph.radial_segments = 24
	sph.rings = 12
	var mi := MeshInstance3D.new()
	mi.mesh = sph
	var sh: Shader = _bubble_sh
	if sh == null:
		sh = Shader.new()
		_bubble_sh = sh
		sh.code = """
shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, depth_draw_never, shadows_disabled;
uniform vec4 col : source_color;
uniform float power = 3.0;
void fragment() {
	float f = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), power);
	ALBEDO = col.rgb;
	ALPHA = col.a * f;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("col", Color(color.r, color.g, color.b, 0.62))
	m.set_shader_parameter("power", 3.4)
	mi.material_override = m
	return mi


## Estira un cilindro de altura 1 para que vaya de `a` a `b`. Es como se dibuja la cadena, que
## cambia de largo cada fotograma mientras el ancla vuela.
func span(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var dir := b - a
	var len := dir.length()
	if len < 0.01:
		mi.visible = false
		return
	mi.visible = true
	var y := dir / len
	var ref := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	mi.transform = Transform3D(Basis(x * 1.0, y * len, z * 1.0), (a + b) * 0.5)
