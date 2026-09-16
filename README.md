# Fallen Legends 3D

ARPG en **tercera persona 3D**, hermano de [Fallen Legends](https://github.com/JohanHdez/Fallen-Legends)
(el 2D isométrico). **Son dos juegos independientes**: comparten el mundo, las leyendas y el
balance, pero cada uno va por su cuenta y ninguno depende del otro para compilar.

Motor **Godot 4.7**, lenguaje **GDScript**. Comentarios y textos de interfaz en español,
identificadores en inglés.

## De dónde viene

Nació como maqueta desechable para ver cómo quedaría el juego en tercera persona, y creció hasta
ser jugable. Eso explica dos cosas de su forma:

- `map_builder.gd` y `dungeon_gen.gd` son **copias literales** de los del juego 2D. El mapa que
  pisas es el MISMO que genera su Horda con la semilla 1234: 42×42 celdas, 1.302 de suelo, 462
  bloqueadas, los pasillos en bucle, las dos cuevas de esquina, el cementerio del norte y sus 6
  tumbas. **Si allí cambian, aquí hay que copiarlos otra vez**: no hay nada que los sincronice.
- Las **cifras de vida, velocidad y habilidades salen de `data/*.tres` del juego 2D**, convertidas
  de píxeles a metros con `PX`. Donde una cifra ya no coincide está dicho en su sitio y por qué.

Casi todo vive en `main.gd`, que es grande. Es deuda consciente de su origen como maqueta: partirlo
es la primera tarea pendiente si esto sigue adelante.

## Cómo abrirlo

```
godot --path .
godot --headless --path . --import     # la primera vez: importa los glTF
```

Sin el `--import` previo tarda ~11 s en arrancar, porque parsea los glTF en caliente.

## Cómo exportarlo

```
godot --headless --path . --export-debug "Android" export/proto3d.apk
```

El JDK 17 está en `~/Library/Java/jdk-17` y el SDK de Android en `~/Library/Android/sdk`.

## Qué hay ahora

Oleadas de **cinco criaturas** del pack Bestiary, sorteadas por peso en la tabla `SPECIES`, que es
el único sitio donde tocar su reparto, vida, velocidad, daño, alcance, tamaño de cápsula y altura de
barra:

| Especie | Modelo | Peso | Vida | Velocidad | Daño | Aparece |
|---|---|---|---|---|---|---|
| Esqueleto | Skeleton_B (espada) | 33 | ×1,0 | ×1,0 | ×1,0 | oleada 1 |
| Esqueleto con hacha | Skeleton_A | 15 | ×1,2 | ×0,95 | ×1,25 | oleada 1 |
| Licántropo | Lycan | 19 | ×1,8 | ×1,35 | ×1,4 | oleada 1 |
| Duende | Puglin | 30 | ×0,65 | ×1,5 | ×0,6 | oleada 1 |
| Guardián infernal | Hellwarden | 7 | ×3,2 | ×0,85 | ×1,9 | oleada 3 |

Son los mismos bichos que el juego 2D tiene en la horda (licántropo y duendes existen allí como
criaturas), y agotan los tres modelos del Bestiary que no usaba nadie. El guardián es la **élite**:
raro, lento y durísimo, para que las oleadas tardías cambien de forma y no solo de número.

De las **tumbas del cementerio solo salen esqueletos** (`"grave": true`): un licántropo saliendo de
una lápida no se sostiene. El resto entra por los bordes del mapa, igual que la Horda del juego.

Persiguen al jugador con un **campo de flujo** BFS sobre la rejilla (una sola búsqueda cada 0,4 s
sirve para todos, en vez de una ruta por bicho). Se separan entre ellos, muerden al alcance y la
oleada siguiente sale 4 s después de limpiar la anterior.

Cada una lleva **brasas en los ojos** a su escala y con su color (naranja el esqueleto, ámbar el
licántropo, verde el duende, rojo el guardián). De noche es lo único que las delata a distancia, y
la luz que sueltan es lo que hace jugable el modo nocturno.

## Leyendas y habilidades

Las **7 leyendas de `Net.CLASSES`** con sus modelos, vida y velocidad reales, y **sus 21
habilidades** con las cifras de `data/abilities/*.tres` (los píxeles del juego se convierten a
metros con `PX`). Teclas **1-7 o Tab** para cambiarlas en caliente.

### Las tres retiradas, apartadas

`Net.RETIRED_CLASSES` (Guerrero, Arquero y Cíclope) está **escrito pero fuera de la rotación**
(`PLAYABLE` = 7), igual que en el juego, que las conserva con datos y habilidades pero no deja
elegirlas "hasta pulirlas". Tab y las teclas no las tocan; `--legend=7`, `8` o `9` las saca para
probarlas. Se apartaron a petición del usuario: por ahora el foco son las otras siete.

Sus 9 habilidades sí funcionan y sus cifras son las del juego. Lo que **no** sale del juego es su
aspecto, porque el juego no tiene ninguno: guerrero y arquero no están en `Wardrobe.DEFAULT_LOOKS`
(caen al atuendo del Clérigo, o sea que los tres se verían iguales) y el cíclope usa el hobgoblin 2D
"de relleno hasta tener un sprite propio". Lo de aquí es una propuesta:

- **Guerrero** (280 vida): túnica de peón, hombrera y cabeza rapada. Con `Male_Ranger` salía calcado
  al Clérigo, porque esa pieza trae capucha.
- **Arquero** (200 vida): peona con melena larga, la última pieza del pack que no usaba nadie.
- **Cíclope** (400 vida): el cíclope del juego es un hobgoblin, o sea un duende GRANDE. Aquí es el
  mismo Puglin de la horda a ×2,6, que lo deja en 2,4 m — justo sus 210 px del juego a 85,6 px/m.

Dos mecánicas nuevas hicieron falta: la carga **hacia atrás** (`"back"`, la Retirada del Arquero es
la única del juego que se aleja del cursor) y el **empujón** de las zonas (`"knock"`: Terremoto y
Golpe de tierra tiran a todo lo que pillan).

### Rompemareas: el ancla pesa

A petición del usuario, **cada golpe suyo levanta polvo** (`"dust"`) y el **Mandoble de ancla barre
180°** (`"arc"`), no el cono de 126° que usan los demás cuerpo a cuerpo (`MELEE_ARC`): todo lo que
tenga delante, de hombro a hombro. El abanico de polvo se dibuja con esa misma apertura, así que se
ve exactamente dónde ha pegado — que es lo que hace legible un área de golpe grande. El aura del
Ancla clavada levanta polvo igual, porque también es un golpe suyo.

Las cifras, tal cual del `.tres`: **2,7 m de radio** (170 px) y 180°; **mantener la tecla** lo carga
hasta ×1,9 de radio (5,1 m) y ×2,1 de daño, y entonces es un **giro de 360°**. Preaviso de 0,3 s, el
más lento del juego, y 1,1 s de recarga. Sonda: `--meleelog` imprime radio, apertura, a cuántos tocó
y a qué ángulo estaba el más abierto — así se comprueba que el abanico es de verdad 180° y no 126°.

**El Enganche** (antes "Arponazo": lo que lanza es su **ancla encadenada**, no un arpón) es su forma
de traer a alguien: daña, aturde 0,5 s y **arrastra al enemigo hasta
sus pies**. Dos cosas que había mal:

- **El empujón no existía.** `_knock` escribía `knock` y `knock_t` en la criatura y **nadie los
  leía**: ni el shove del Corte de hacha del Caballero ni el de las zonas hacían nada. Ahora se
  resuelven en `_tick_zombie`, y **antes que el aturdimiento** — si se miran después, una habilidad
  que aturda y empuje a la vez deja al enemigo clavado, que es el mismo fallo que el juego 2D
  arregló en `enemy._tick_ai`.
- **El tirón era un teletransporte** con tope de 6 m, así que desde el alcance máximo (8,3 m) ni
  llegaba a los pies. Ahora arrastra a 14 m/s y el tiempo sale de la distancia: llega venga de donde
  venga, y se ve venir.

- **No se teledirige** (petición del usuario): se clava **donde apuntaste**, no persigue. A cambio
  el radio de enganche es ancho, `"catch"` = 190 px = 3,0 m, para que quien estuviera ahí al tirarla
  siga entrando aunque se haya movido. Antes seguía al enemigo fotograma a fotograma y no fallaba
  nunca; ahora fallar es posible, que es lo que le da valor a acertar.
- **Lanzaba una bola de luz.** Todos los proyectiles del prototipo eran la misma esfera aditiva, así
  que no se entendía qué estaba tirando. Ahora sale el **ancla de verdad** (`"solid": "anchor"`):
  caña, cepo, dos uñas y argolla, girando en el aire y con la **cadena tendida hasta su mano**, que
  se redibuja cada fotograma estirando un cilindro (`_span`).

**Dos números del Enganche ya NO coinciden con `data/abilities/arponazo.tres`**, los dos a petición
del usuario: recarga **20 s** (el `.tres` dice 7) y alcance **1200 px = 19 m** (el `.tres` dice 520
= 8,3 m). Si se quedan así, hay que cambiarlos también en el `.tres` del repo.

### Montaje de prueba

- `--dianas=N` pone N criaturas **quietas** en fila delante de la cámara, a 6, 11, 16, 21... m,
  escalonadas a los lados y con **su distancia escrita encima**. Sirve para medir el alcance de una
  habilidad sin que se te echen encima mientras apuntas. Van en la dirección de la **cámara**, no la
  del modelo: al arrancar no coinciden y con la del modelo salían fuera de plano.
- `--cd=N` recorta **todas** las recargas a N segundos. Solo para probar; los valores reales no se
  tocan.

### Armas: no existen, hay que construirlas

El pack **Modular Character Outfits de Quaternius trae 24 piezas y ninguna es un arma** — solo ropa.
Es el mismo agujero que el juego 2D tiene anotado en su `CLAUDE.md`. Por eso las leyendas humanas
iban todas con las manos vacías, y en un arquero eso no se sostiene.

`_attach_weapon` cuelga geometría hecha en código de los huesos `hand_l` / `hand_r`: el **arco**
(nueve tramos siguiendo un arco, más la cuerda), la **espada** (hoja, gavilanes y empuñadura) y el
**mazo** (tronco y cabeza de piedra). Dos trampas que costaron una vuelta cada una:

- **Todo gris y liso sale AZUL.** La luz ambiental viene del cielo, así que un metal pulido lo
  refleja: con `metallic = 0.8` la espada era azul eléctrica. Va sin metal y con rugosidad 0,85.
- **El arma hereda la escala del modelo.** Colgada de un hueso del Cíclope se multiplica por 2,6:
  un mazo de tamaño humano medía 2,2 m, casi tanto como el gigante. Se dibuja a 0,5 m.

### Animaciones

`Roll`, `OverhandThrow`, `Sword_Regular_A/B` y `Shield_Dash` estaban en el pack sin que las usara
nadie. Cada habilidad puede pedir la suya con `"anim"`, y hay dos ajustes de tiempo:

- **`"adur"`** alarga solo la animación, no el preaviso. El lanzamiento de roca dura 1,33 s y
  comprimido a los 0,35 s de su preaviso salía a 3,8×.
- **`"sync"`** (solo el Corte de hacha del Caballero, a petición del usuario) hace que la carga dure
  lo que la animación. Las demás cargas mandan con su `Ability.dash_speed` y es la animación la que
  se adapta: la Embestida son 4,6 m a 700 px/s, o sea 0,31 s, y sincronizarla habría dado un paseo.

**Elegir la animación por su duración, no por su nombre.** `Sword_Heavy_Combo` parecía perfecta para
un mazazo hasta medirla: dura 4,33 s, y estirada al preaviso salía a **12×** — un temblor. Las
`Sword_Regular_A/B` duran 0,43 y 0,53 s, casi lo que dura un preaviso, y salen a 1,07×.

Diez mecánicas: proyectil (con teledirigido, aturdimiento y tirón), cono cuerpo a cuerpo, carga que
arrolla, curación, mejora con resistencia y clavado, zona con golpe y campo residual, trampa que
espera armada, baliza, muro de espinas que brota progresivamente, esbirros y señuelos.

Los enemigos **eligen objetivo**: al aliado más cercano si lo tienen a menos de 14 m, si no al jugador.

## Esporas del Clérigo

Con la mecánica real de `player.gd` (SPORE_*): infecta al apuntado y a los de alrededor, cada
infectado lleva **cuatro bultos pegados al cuerpo**, el daño empieza en 10/s y sube +1,5 por
infectado (contando 7 como mucho), y **al morir un infectado los bultos revientan**: la plaga salta
a los que estén a 5 m y el daño se multiplica por 1,25, hasta un techo de 60/s. También contagia
por cercanía a 2 m en cada tick. Los jefes resisten.

## Señuelos del Ilusionista

Repiten tu desplazamiento girado a su propia orientación (SPREAD) o salen de largo (FORWARD),
y **copian tu animación**: si conjuras, conjuran. **Sin tinte a propósito** (petición del usuario):
el `decoy.gd` del juego los pinta de violeta para que TÚ los distingas, pero aquí la idea es que
el enemigo no sepa cuál eres. Son **inmunes a las esporas** y un solo golpe los disipa.

## Baliza Nox del Químico

Con `beacon.gd` del juego: un **barril de 60 de vida que bloquea el paso**. Espera dormido y lo
despierta un enemigo a 2 m **o cualquier golpe** — las criaturas la muelen a golpes si la tienen a
mano. Al reventar suelta humo Nox de 5 m durante 10 s: 8 de daño cada 0,5 s y **velocidad a la
mitad**. 3 cargas, una cada 10 s, hasta 5 puestas.

## Gas Nox

La nube son **tres capas de humo** a distintas alturas (300-700 partículas cada una, la mitad en
móvil) en verde amarillento, que es el único que contrasta sobre hierba verde. Además de frenar a
la mitad, **ciega**: el enemigo dentro del humo pierde el rumbo y deambula 2,5 s sin poder atacar.

## Noche, suelo y barras

Ciclo día/noche con los tiempos de `level.gd` (120 día, 90 atardecer, 120 noche, 90 amanecer;
`--cycle=N` lo acorta, `--night` empieza de noche). Para que la noche se **lea**: brasas naranjas
en las cuencas de los esqueletos (colgadas del hueso de la cabeza, siguen la animación), antorcha
en el jugador que se aviva al anochecer, y suelo de oscuridad más alto que el del juego 2D.

Suelo con ruido horneado sobre el color de cada zona, hierba al doble de densidad, y **barras de
vida**: verdes los tuyos (jugador, esbirros, señuelos), rojas las criaturas. Sin prueba de
profundidad, así que se leen a través de la hierba.

**El billboard se come la escala.** La barra se vacía con `fill.scale.x`, pero un material con
`billboard_mode = BILLBOARD_ENABLED` rehace la base de la matriz para encarar la cámara y en el
camino descarta la escala del nodo. Lo único que sobrevivía era el desplazamiento: el relleno no
menguaba, se corría a la izquierda y asomaba el fondo negro por la derecha — se moría con la barra
casi llena. Hace falta **`billboard_keep_scale = true`**. Si mañana algo billboardeado no obedece a
`scale`, es esto.

La barra de una leyenda cuelga de la **altura real de su modelo** (`_model_top`, medida de las
mallas) más 30 cm, no de un número fijo: con 2,25 m para todas, al Rompemareas —2,60 m con el ancla
en alto— le quedaba cruzada por la cara. Así ninguna leyenda que se añada o se escale tiene que
acordarse de ajustar nada.

La barra de una criatura **solo se asoma cuando la golpeas** y se va sola a los 2,5 s, con los
últimos 0,7 s en desvanecido (petición del usuario): con 40 bichos a la vez el claro era una pared
de barras rojas y no se veía la pelea. La del jefe no se esconde, que es el objetivo de la oleada. Cada especie lleva la suya **a su medida**
(0,7 el duende, 1,2 el licántropo, 1,45 el guardián, 2,2 el jefe), y la escala hay que pasársela
igual a `_make_bar` y a `_set_bar`: la segunda la usa para recolocar el relleno, así que si no
coinciden la barra se vacía descentrada.

## Guardia del Caballero

El aro blanco bajo los pies se cambió por una **burbuja de escudo**: el esqueleto no lleva escudo
que levantar, y el juego 2D ya retiró en su día los círculos blancos del suelo (`CLAUDE.md`, "marcas
en el suelo"). Una esfera translúcida a secas se ve como un disco plano que tapa el fondo, así que
el brillo va por **fresnel** en un shader de cuatro líneas: enciende el borde y deja el centro casi
transparente, que es lo que la lee como cascarón. El `Shader` se guarda en `_bubble_sh` y se
reutiliza: compilarlo por burbuja cuesta y se filtra, y la guardia se enciende y apaga sin parar.

## Gas demoníaco: la zona que se cierra

**Esto es de PvP, no de la horda.** En el juego iría solo en 1v1 a 4v4 (petición del usuario);
aquí corre sobre la horda porque el prototipo no tiene PvP y es el único sitio donde se puede ver
funcionando. `--nozone` lo apaga.

El gas **está en el borde del mapa desde el primer segundo**: el área limpia arranca siendo el
círculo inscrito en el mapa, así que las cuatro esquinas ya son gas. A los **2 minutos** empieza a
cerrarse a 0,24 m/s —poco a poco, unos 3,7 min hasta el final— y mientras encoge **el centro se va
desplazando** hacia un punto sorteado: si solo encogiera, la partida acabaría siempre en el mismo
sitio y el cementerio y las cuevas dejarían de existir a partir de la mitad.

Dentro del gas: 7 de daño por segundo, y la pantalla se **tiñe de violeta por los bordes** con un
latido. Es viñeta y no un rectángulo plano a propósito: teñir el centro mientras te están matando
es lo contrario de ayudar.

Dos cosas que costaron una vuelta cada una:

- **La V del `CylinderMesh` no es la que uno supone.** Al calcular la altura con `1.0 - UV.y` el
  resplandor salía en la cresta, y con `UV.y` la pared entera se volvía transparente. Se calcula
  del **vértice** (`0.5 - VERTEX.y / wall_h`), que no depende de convenciones.
- **Negro puro no vale**: de noche es invisible y de día es un agujero recortado. El muro es negro
  violáceo y solo el último palmo tiene brillo.

Sondas: `--zonewait=N` acorta la espera y `--zonefast=N` acelera el cierre.

## Cubrirse y esconderse

- **Peñascos** (`_scatter_cover`, 50 por mapa) con colisión propia: frenan igual al jugador y a las
  criaturas. Se quedan pequeños respecto a la celda de 3 m a propósito, porque el campo de flujo de
  las criaturas razona por celdas y no sabe que están ahí: hay que dejarles sitio para rodearlos.
  Y no se ponen a menos de 3 celdas de donde aparece el jugador — en la primera prueba le tocó uno
  encima y arrancó la partida subido a él, a 2,2 m del suelo.
- **Manchas de hierba alta** (`tall_grass`, 16 manchas): el triple de matas, solo las variedades
  altas y a mayor escala, para que se vea de lejos que ahí cabe alguien.
- **Agacharse con Ctrl**: frena al 45 %, baja la cámara y usa las animaciones `Crouch_Idle` /
  `Crouch_Fwd` del pack. Agachado **dentro de una mancha de hierba alta eres invisible** para las
  criaturas; atacar te delata 3 s (`SPOTTED_TIME`). En táctil todavía no hay botón.
- De paso quedó arreglada la invisibilidad del Ilusionista: `_enemy_target` manda a las criaturas
  al **último sitio donde te vieron**, no a donde estás. Antes, si ibas solo, te seguían igual
  aunque fueras invisible, porque al no haber aliado al que perseguir caían en tu posición real.

## Premios de racha

Las 10 insignias del juego (`hud.KILL_REWARD_NAMES`, no existe la 2), con sus mismas imágenes y la
misma presentación. Insignia 1 en la primera baja, de la 3 a la 9 por racha, 10 y 11 ("La parca")
al llegar a 10 bajas. La racha se pierde al morir. **Diferencia con el juego**: aquí no hay rotación
de "La parca" porque solo juegas tú, así que el título se gana por bajas totales.

## Controles

| Tecla | Qué hace |
|---|---|
| WASD | mover (relativo a la cámara) |
| Shift | correr |
| ratón | girar la cámara |
| rueda | acercar / alejar |
| clic izquierdo | atacar |
| **C** | cambiar cámara: sobre el hombro ↔ vista alta tipo ARPG |
| Esc | soltar el ratón |
| Q | salir |

**La tecla que importa es la C.** La vista alta es la comparación honesta contra tu isométrica
actual: ahí se ve si el combate de zonas se sigue leyendo o no.

## Capturas sin jugar

```
godot --path . --resolution 1280x720 -- --shot=/tmp/a.png --cam=1 --yaw=35 --pitch=-48 --dist=17
```

Opciones: `--shot=` `--cam=0|1` `--yaw=` `--pitch=` `--dist=` `--at=x,y|cem|cueva` `--dbg`

## Licencias

Ver `assets/CREDITS.txt`. Resumen de lo que ata:

- **Modelos de Quaternius**: CC0 salvo el *Bestiary - Dungeon Monsters Kit*, que va con la QAL
  (libre para uso comercial, pero **no para redistribuir los modelos sueltos**). Por eso **este
  repositorio tiene que ser privado**: hacerlo público sería redistribuir un pack de pago.
- **Sonidos de conjuro** (p0ss, *Spell Sounds Starter Pack*): **CC-BY-SA 3.0**. Obliga a atribuir
  y a compartir igual. Es la misma licencia que el arte de Flare del juego 2D, así que no añade
  una atadura nueva, pero hay que respetarla.
- El resto (partículas y música de Kenney, cynicmusic, Juhani Junkala) es CC0.

## Opciones útiles para probar

```
--near=5        las criaturas salen a 5 celdas de ti, para pelear ya
--zombies=N     tamaño de la oleada
--wave=N        empezar en la oleada N
--nodecor       sin hierba ni flores
--noshadow      sin sombras
--log           traza por consola (headless)
--bench         FPS y tiempos por fotograma
--fxtest        mantiene rayos y una esfera en pantalla, para juzgar los efectos
--sporelog      traza el contagio y el daño creciente de la plaga del Clérigo
--dashlog       mide si el Corte de hacha recorre lo que debe y a quién arrolla
--meleelog      radio, apertura y a cuántos tocó cada golpe cuerpo a cuerpo, y cada tirón del ancla
--dianas=N      N criaturas quietas en fila a 6, 11, 16... m, con su distancia escrita
--cd=N          recorta todas las recargas a N s (solo prueba)
--nozone        sin gas que se cierre
--zonewait=N    segundos hasta que el gas empieza a cerrar (por defecto 120)
--zonefast=N    multiplica la velocidad de cierre, para verlo sin esperar
```

`--log` imprime además el reparto de especies: `vivos` por tipo y `salidas` acumuladas. Ojo al
leerlo: **el `rng` va con semilla fija** (`MAP_SEED`, para que el mapa salga siempre igual), así que
dos ejecuciones con los mismos argumentos repiten la misma tirada. Dos muestras iguales no son dos
muestras: para comprobar de verdad un sorteo por pesos hay que hacerlo aparte, con `randomize()`.

## Cosas que se aprendieron montándolo

1. **`map_builder.gd` no es autónomo**: depende de `DungeonGen`, y `DungeonGen` de `MapBuilder`.
   Son un par cerrado; nada más del juego hace falta para generar mapas.
2. Los modelos del MegaKit traen **datos de viento en `COLOR_0`**. Godot los usa como albedo y las
   copas salen rojas. Hay que apagar `vertex_color_use_as_albedo` en cada material.
3. `Leaves_TwistedTree_C.png` **es rojo de origen**: el pack trae variedades de hoja. Aquí se le
   pone la verde para que el bosque sea coherente.
4. El albedo va en **espacio lineal**: un verde 0.26 se ve casi menta. La hierba necesita ~0.1.
5. Con `ambient_light_sky_contribution = 1.0` (el valor por defecto con cielo), `ambient_light_energy`
   no hace nada. Hay que bajar la contribución para que el ajuste sirva.
6. **Los atuendos NO traen cabeza.** `Male_Peasant.gltf` son brazos, cuerpo, pies y piernas y nada
   más; los personajes salían decapitados. `Male_Ranger` sí trae `Head_Hood`, por eso el jugador se
   veía bien desde el principio.
7. **El apilado de capas del `Wardrobe` 2D no se traduce a 3D.** En el pack de cuerpos base no hay
   una malla de cabeza suelta: `Face`/`Face.001` son los ojos y todo lo demás es el cuerpo entero de
   una pieza. Ponerlo debajo de la ropa no lo tapa, lo **atraviesa**. En 3D las piezas se
   *sustituyen*, no se apilan — lo que afecta de lleno a la tienda por capas si algún día se migra.
8. **El importador de Godot RENOMBRA las animaciones**: a las que acaban en `_Loop` les quita el
   sufijo y las marca como cíclicas (`Idle_Loop` → `Idle`, `Jog_Fwd_Loop` → `Jog_Fwd`,
   `Zombie_Walk_Fwd_Loop` → `Zombie_Walk_Fwd`). Cargando el glTF en caliente con `GLTFDocument`
   los nombres son los originales; al pasar a modelos importados (obligatorio para el APK) todas
   las animaciones dejaron de encontrarse y los personajes se deslizaban en pose de reposo.
9. `Image.load_from_file` lee del disco y **dentro de un APK no existe ese fichero**: hay que usar
   `load()` para que el recurso viaje en el PCK.
10. La animación de acción hay que **protegerla del bucle de movimiento**, o al frame siguiente
    `Idle`/`Jog_Fwd` la pisan y no se ve nunca (le pasó al conjuro).
11. **No se puede medir rendimiento desde una ventana en segundo plano**: macOS la estrangula a 3 FPS
   y las cifras se contradicen (quitar 3.000 hierbas salía *más lento*). La única medida fiable se
   tomó con la ventana en primer plano: **40 esqueletos animados a 144 FPS**, física 13-16 ms.

**Trampa del `--shot` en headless**: sin ventana, `get_viewport().get_texture().get_image()`
devuelve nulo, y llamar a `save_png` sobre nulo **aborta la función** en GDScript. El `quit()` que
va justo después nunca se ejecutaba: seis pruebas de fondo se quedaron corriendo para siempre
comiéndose la CPU, y las capturas con ventana que lanzaba después salían muertas de hambre. Ahora
hay guarda, y `--shot` con `--wait=N` en headless sirve de "corre N fotogramas y sal".
