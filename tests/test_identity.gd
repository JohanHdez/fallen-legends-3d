## Prueba de lógica pura de la identidad del jugador: `godot --headless --path . -s tests/test_identity.gd`
## `Identity` (traída del 2D el 2026-09-18 para el juego en línea del 3D) genera y guarda un identificador
## secreto por dispositivo, sanea el apodo y resuelve apodos repetidos en una sala.
extends SceneTree

func _init() -> void:
	var failures := 0
	Identity.PATH = "user://identity_test.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Identity.PATH))

	# Primera ejecución: crea un id de 32 hexadecimales y lo persiste; la segunda devuelve el mismo.
	var first := Identity.load_or_create()
	failures += _check("id válido al crearlo", Identity.is_valid_id(str(first.id)), first)
	failures += _check("apodo por defecto", first.name == "Jugador", first)
	var again := Identity.load_or_create()
	failures += _check("el id se conserva entre arranques", again.id == first.id, [first.id, again.id])
	# Dos dispositivos distintos no comparten id.
	Identity.PATH = "user://identity_test2.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Identity.PATH))
	var other := Identity.load_or_create()
	failures += _check("ids distintos por dispositivo", other.id != first.id, [first.id, other.id])
	Identity.save(str(other.id), "Kael")
	failures += _check("apodo guardado", Identity.load_or_create().name == "Kael", Identity.load_or_create())
	# Restaurar con restore(): cambiar el id guardado.
	failures += _check("restaurar con código válido", Identity.restore(str(first.id)) and Identity.load_or_create().id == first.id, Identity.load_or_create())
	failures += _check("restaurar con código inválido falla", not Identity.restore("no-es-un-id") and Identity.load_or_create().id == first.id, "")

	# Validación del id (lo que manda el cliente al servidor: nunca se confía en él).
	failures += _check("id corto inválido", not Identity.is_valid_id("abc"), "")
	failures += _check("id no hexadecimal inválido", not Identity.is_valid_id("zz" + "0".repeat(30)), "")
	failures += _check("id en mayúsculas se acepta", Identity.is_valid_id("ABCDEF0123456789ABCDEF0123456789"), "")

	# Apodo: recorte, tope de 16, sin caracteres de control, vacío -> Jugador.
	failures += _check("apodo recortado", Identity.sanitize_name("   Kael  ") == "Kael", Identity.sanitize_name("   Kael  "))
	failures += _check("apodo a 16", Identity.sanitize_name("abcdefghijklmnopqrstuvwxyz").length() == 16, "")
	failures += _check("apodo vacío", Identity.sanitize_name("   ") == "Jugador", "")
	failures += _check("apodo sin caracteres de control", Identity.sanitize_name("Ka\nel\tX") == "KaelX", Identity.sanitize_name("Ka\nel\tX"))
	failures += _check("espacios internos colapsados", Identity.sanitize_name("Ka    el") == "Ka el", "")

	# Apodos repetidos en la sala: se numeran; sin conflicto se devuelve tal cual.
	failures += _check("apodo libre", Identity.unique_name("Kael", ["Ana", "Bo"]) == "Kael", "")
	failures += _check("apodo repetido", Identity.unique_name("Kael", ["Kael"]) == "Kael 2", Identity.unique_name("Kael", ["Kael"]))
	failures += _check("apodo repetido dos veces", Identity.unique_name("Kael", ["Kael", "Kael 2"]) == "Kael 3", "")
	failures += _check("numerar respeta el tope de 16", Identity.unique_name("abcdefghijklmnop", ["abcdefghijklmnop"]).length() <= 16, "")
	failures += _check("comparación sin mayúsculas", Identity.unique_name("kael", ["Kael"]) == "kael 2", "")

	for p in ["user://identity_test.json", "user://identity_test2.json"]:
		var rm := DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		failures += _check("limpieza de %s" % p, rm == OK and not FileAccess.file_exists(p), rm)
	# Los autoloads se instancian DESPUÉS de este _init (Net._ready llama a Identity.load_or_create):
	# si no se restaura la ruta, Net volvería a crear el fichero de prueba al salir.
	Identity.PATH = "user://identity.json"
	print("test_identity: %d fallos" % failures)
	quit(1 if failures > 0 else 0)

func _check(name: String, ok: bool, got: Variant) -> int:
	if not ok:
		print("FALLO: %s -> %s" % [name, got])
	return 0 if ok else 1
