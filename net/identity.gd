## Identidad del jugador en el CLIENTE: un identificador secreto por dispositivo (32 hexadecimales aleatorios)
## Copiado de arena-arpg (scripts/identity.gd) el 2026-09-18 para el juego en línea del 3D.
## que es la llave de su perfil en el servidor, más el apodo. Vive en user://identity.json y se crea la primera
## vez que arranca el juego. El "código de recuperación" que ve el jugador es ese mismo id: pegarlo en otro
## dispositivo (`restore`) recupera el progreso sin cuentas ni contraseñas. El apodo es solo una etiqueta:
## cambiarlo no toca el perfil. El servidor valida el id con `is_valid_id` y nunca lo reenvía a otros peers.
## Sin autoloads para que tests/test_identity.gd lo cargue con `godot -s`.
class_name Identity
extends RefCounted

static var PATH := "user://identity.json"   # las pruebas lo cambian; --identity=ruta en Net para varias instancias
const DEFAULT_NAME := "Jugador"
const NAME_MAX := 16
const ID_LEN := 32

## {"id": String, "name": String}; crea y guarda un id nuevo si no hay ninguno válido.
static func load_or_create() -> Dictionary:
	var d := _read()
	var id := str(d.get("id", "")).to_lower()
	var name := sanitize_name(str(d.get("name", DEFAULT_NAME)))
	if not is_valid_id(id):
		id = new_id()
		_write({"id": id, "name": name})
	return {"id": id, "name": name}

static func save(id: String, name: String) -> void:
	_write({"id": id.to_lower(), "name": sanitize_name(name)})

## Sustituye el id por un código de recuperación de otro dispositivo (conserva el apodo). false si no es válido.
static func restore(code: String) -> bool:
	var c := code.strip_edges().to_lower()
	if not is_valid_id(c):
		return false
	save(c, str(load_or_create().name))
	return true

static func new_id() -> String:
	return Crypto.new().generate_random_bytes(ID_LEN / 2).hex_encode()

static func is_valid_id(s: String) -> bool:
	return s.length() == ID_LEN and s.is_valid_hex_number(false)

## Apodo presentable: sin caracteres de control, espacios colapsados, recortado, tope NAME_MAX; vacío -> Jugador.
static func sanitize_name(raw: String) -> String:
	var out := ""
	for ch in raw:
		if ch.unicode_at(0) >= 32 and ch.unicode_at(0) != 127:
			out += ch
	var re := RegEx.new()
	re.compile("\\s+")
	out = re.sub(out, " ", true).strip_edges()
	if out == "":
		return DEFAULT_NAME
	return out.left(NAME_MAX).strip_edges()

## Si el apodo ya está en uso en la sala (sin distinguir mayúsculas) lo numera: "Kael 2", "Kael 3"...
static func unique_name(name: String, taken: Array) -> String:
	var used: Array[String] = []
	for t in taken:
		used.append(str(t).to_lower())
	if name.to_lower() not in used:
		return name
	var n := 2
	while n < 1000:
		var suffix := " %d" % n
		var candidate := name.left(NAME_MAX - suffix.length()).strip_edges() + suffix
		if candidate.to_lower() not in used:
			return candidate
		n += 1
	return name

static func _read() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}

## Vuelca y cierra explícitamente para que llegue al disco de inmediato: en Android el sistema puede matar
## la app sin avisar y el código de recuperación no debe perderse.
static func _write(d: Dictionary) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_error("No se pudo guardar la identidad en %s" % PATH)
		return
	f.store_string(JSON.stringify(d))
	f.flush()
	f.close()
