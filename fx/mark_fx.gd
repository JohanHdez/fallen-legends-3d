## Contorno rojo, visible a través de muros y rocas, sobre quien rompió un señuelo de la Ilusionista
## (idea del usuario). Va en `material_overlay` de cada malla del modelo, así que no toca sus
## materiales (se comparten entre leyendas iguales y teñirlos marcaría a las dos). Dos pasadas:
##  1. la silueta sin color: solo escribe 1 en el stencil, sin mirar la profundidad;
##  2. la silueta engordada unos píxeles de pantalla, roja, sin mirar la profundidad y solo donde el
##     stencil NO es 1. Queda el borde, del mismo grosor lejos o cerca, aunque haya una roca delante.
## Un solo par de materiales para todas las leyendas marcadas.
class_name MarkFx
extends RefCounted

const WIDTH_PX := 3.5
const COLOR := Color(1.0, 0.12, 0.08, 0.95)

const _SILHOUETTE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled;
stencil_mode write, compare_always, 1;
void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
"""

const _OUTLINE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled;
stencil_mode read, compare_not_equal, 1;
uniform vec4 color : source_color = vec4(1.0, 0.12, 0.08, 0.95);
uniform float width_px = 3.5;
void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 n = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	vec2 dir = (PROJECTION_MATRIX * vec4(n, 0.0)).xy;
	if (length(dir) > 0.00001) {
		dir = normalize(dir);
	}
	clip.xy += dir * width_px * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}
void fragment() {
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
"""

static var _material: ShaderMaterial = null


## El material de la marca (la silueta con el contorno como siguiente pasada), creado una vez.
static func material() -> ShaderMaterial:
	if _material == null:
		var sil := Shader.new()
		sil.code = _SILHOUETTE
		var out := Shader.new()
		out.code = _OUTLINE
		var outline := ShaderMaterial.new()
		outline.shader = out
		outline.set_shader_parameter("color", COLOR)
		outline.set_shader_parameter("width_px", WIDTH_PX)
		outline.render_priority = 21
		_material = ShaderMaterial.new()
		_material.shader = sil
		_material.render_priority = 20
		_material.next_pass = outline
	return _material


## Pone o quita el contorno a todas las mallas de un modelo. Solo al empezar y acabar la marca.
static func apply(model: Node3D, on: bool) -> void:
	if model == null:
		return
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = material() if on else null
