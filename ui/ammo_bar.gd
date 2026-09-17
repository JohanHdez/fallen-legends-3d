## Munición de TU básica por equipos (idea del usuario, estilo Brawl): segmentos naranjas justo
## debajo de tu barra de vida. El disparo que está volviendo se va llenando más apagado; disparar
## sin munición suena a hueco y la barra parpadea en rojo. Solo se ve la tuya: la del rival no, y
## adivinar si va vacío es parte de la pelea. La Ilusionista no tiene (dispara sin límite).
##
## Mira a la cámara girando el nodo entero. Con `billboard` en cada segmento no valía: el
## desplazamiento lateral de cada uno se aplica en el mundo y, al girar la cámara, se montaban.
class_name AmmoBar
extends Node3D

const COL_FULL := Color(1.0, 0.62, 0.15)
const COL_PART := Color(0.8, 0.45, 0.12, 0.75)
const COL_BACK := Color(0.06, 0.06, 0.08, 0.75)
const COL_DRY := Color(0.9, 0.12, 0.1, 0.9)
const HEIGHT := 0.07
const GAP := 0.04
const FLASH := 0.35
const DRY_SOUND := "res://assets/audio/sfx/impactTin_medium_000.ogg"

var f: Fighter
var _width := 0.95
var _backs: Array[MeshInstance3D] = []
var _fills: Array[MeshInstance3D] = []
var _mat_full: StandardMaterial3D
var _mat_part: StandardMaterial3D
var _mat_back: StandardMaterial3D
var _flash := 0.0
var _sound: AudioStreamPlayer


## Cuánto se llena el segmento `i` (0..1) con `level` disparos (Fighter.ammo_level: 1,25 = uno
## lleno y el segundo a un cuarto).
static func segment_fill(level: float, i: int) -> float:
	return clampf(level - float(i), 0.0, 1.0)


## ¿El segmento `i` es el que está volviendo (a medias)?
static func is_partial(level: float, i: int) -> bool:
	var fill := segment_fill(level, i)
	return fill > 0.0 and fill < 1.0


## `height`: altura sobre los pies (debajo de la barra de vida); `width`: la de la barra de vida.
func setup(p_f: Fighter, height: float, width: float) -> void:
	f = p_f
	_width = width
	position = Vector3(0, height, 0)
	_mat_back = _material(COL_BACK, 8)
	_mat_full = _material(COL_FULL, 9)
	_mat_part = _material(COL_PART, 9)
	var n := f.ammo_max
	var seg := (width - GAP * float(n - 1)) / float(n)
	for i in n:
		var x := -width * 0.5 + seg * 0.5 + float(i) * (seg + GAP)
		_backs.append(_quad(seg, _mat_back, Vector3(x, 0, 0)))
		_fills.append(_quad(seg, _mat_full, Vector3(x, 0, 0.01)))
	_sound = AudioStreamPlayer.new()
	if ResourceLoader.exists(DRY_SOUND):
		_sound.stream = load(DRY_SOUND)
	_sound.volume_db = -4.0
	add_child(_sound)


## Disparar sin munición: parpadeo rojo y sonido a hueco.
func dry_fire() -> void:
	_flash = FLASH
	if _sound != null and _sound.stream != null:
		_sound.play()


func _process(delta: float) -> void:
	if f == null:
		return
	visible = f.alive()
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		global_basis = cam.global_basis
	_flash = maxf(0.0, _flash - delta)
	_mat_back.albedo_color = COL_DRY if _flash > 0.0 and fmod(_flash, 0.14) > 0.07 else COL_BACK
	var level := f.ammo_level()
	var seg := (_width - GAP * float(_fills.size() - 1)) / float(maxi(_fills.size(), 1))
	for i in _fills.size():
		var fill := segment_fill(level, i)
		var q := _fills[i]
		q.visible = fill > 0.001
		q.material_override = _mat_part if is_partial(level, i) else _mat_full
		q.scale.x = maxf(fill, 0.001)
		q.position.x = -_width * 0.5 + float(i) * (seg + GAP) + seg * fill * 0.5


func _material(col: Color, priority: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.render_priority = priority
	m.albedo_color = col
	return m


func _quad(w: float, mat: StandardMaterial3D, at: Vector3) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(w, HEIGHT)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
