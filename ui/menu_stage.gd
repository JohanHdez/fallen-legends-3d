## Escenario del menú de inicio (2026-11-09, docs/superpowers/specs/2026-11-09-pantalla-inicio-design.md):
## tu leyenda a la vista en el centro, de frente, en el cementerio (como la pantalla de inicio del 2D),
## con la cámara cerca meciéndose despacio a los lados. Antes la leyenda se escondía y la cámara
## giraba alta sobre el mapa.
## Por qué así (vistas en captura): en la pradera la hierba alta y los arbustos tapaban la leyenda, y
## con la cámara dando la vuelta entera salía de espaldas la mitad del tiempo.
## Main solo llama a setup() al montar el menú y a tick() en cada vuelta de física del menú.
class_name MenuStage
extends RefCounted

const DIST := 3.4          # m de la cámara a la leyenda: encuadre de retrato, de cuerpo entero
# m sobre los pies a los que mira la cámara: a la altura de la cadera, para que la leyenda quede en la
# mitad de arriba y su nombre (debajo, en ModeMenu) no le tape las piernas.
const LOOK_UP := 0.6
const PITCH := -0.08       # rad: casi a la altura de los ojos, apenas desde arriba
const SWAY := 0.35         # rad que se mece la cámara a cada lado del frente de la leyenda
const SWAY_SPEED := 0.22   # rad/s de la fase del vaivén (un vaivén completo en ~29 s)
const FACING := 0.0        # hacia dónde mira la leyenda (rotation.y); la cámara se pone delante

static var _t := 0.0


static func setup(main: Main) -> void:
	_t = 0.0
	# Al cementerio: tierra despejada y tumbas de fondo, sin hierba alta delante de la leyenda.
	var c := main._cell_in_zone(2)
	if c.x >= 0 and main.player != null:
		main.player.position = main._cell_pos(c.x, c.y) + Vector3(0, 0.3, 0)
	if main.player_model != null:
		main.player_model.visible = true
	if main.pf != null and main.pf.bar != null:
		main.pf.bar.visible = false
	# La capa del HUD lleva también la mira (+) del centro: en el menú no va nada de eso.
	if main.hud != null:
		main.hud.visible = false
		var layer := main.hud.get_parent() as CanvasLayer
		if layer != null:
			layer.visible = false
	main._cam_mode = 1
	main._apply_cam_mode()
	main.spring.spring_length = DIST
	main._pitch = PITCH
	main._yaw = FACING


static func tick(main: Main, delta: float) -> void:
	_t += delta
	var f := main.pf
	if f != null and f.model != null:
		# De frente siempre, también tras cambiar de leyenda (◀ ▶ crea el modelo nuevo mirando a 0).
		f.model.rotation.y = FACING
		# Al cambiar de leyenda se crea la barra de vida si faltaba: en el menú no va.
		if f.bar != null and f.bar.visible:
			f.bar.visible = false
	main._yaw = FACING + sin(_t * SWAY_SPEED) * SWAY
	var feet := f.pos() if f != null else Vector3.ZERO
	main.pivot.global_position = feet + Vector3(0, LOOK_UP, 0)
	main.pivot.rotation.y = main._yaw
	main.spring.spring_length = DIST
	main.spring.rotation.x = main._pitch
