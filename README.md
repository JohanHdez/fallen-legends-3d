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

`main.gd` era un monolito de 4.600 líneas por su origen de maqueta. El 2026-09-16 se partió sin
cambiar el juego (comprobado con trazas deterministas de la Horda): los datos de leyendas en
`data/legend_data.gd`, los efectos en `fx/vfx.gd`, el combate de cualquier leyenda en
`game/combat.gd` + `game/fighter.gd`, y los modos por equipos en `game/` y `ui/`. Arquitectura y
reglas para trabajar en él: `CLAUDE.md`.

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

## Menú y modos de juego

Al abrir el juego sale un **menú de inicio** sobre el mapa: eliges modo y leyenda y pulsas JUGAR
(también con ratón, dedo o flechas y Enter). Con cualquier opción de línea de comandos, o en
headless, se salta y se juega la Horda como siempre; `--mode=` elige directamente.

| Modo | Qué es |
|---|---|
| **Horda** | **10 oleadas** de criaturas, **solo o con 1-3 compañeros bot** (selector "Equipo" del menú). Se pierde si cae todo el equipo y **se gana superando la oleada 10**. |
| **1v1, 2v2, 3v3, 4v4** | Tú más compañeros bot contra rivales bot, **al mejor de 3 rondas**. |

**Derribo y reanimaciones** (Horda y PvP; petición del usuario, 2026-09-17, cifras del 2D): a 0 de
vida una leyenda **no muere: queda DERRIBADA**, arrastrándose a un cuarto de su velocidad, sin atacar
y con un letrero "¡DERRIBADO! N s" encima. Tiene **45 s** para que **un compañero en pie se agache a
su lado (a menos de 1,4 m) 3 s**, y se levanta con media vida y 3 s de inmunidad (burbuja dorada); si
el que ayuda se va, el progreso baja al mismo ritmo. Mientras la levantan, la cuenta se para. **Los
golpes rematan**: el daño equivalente a 1,5 veces su vida máxima le quita los 45 s enteros (un golpe
normal, ~1 s). Si se le acaba la cuenta, o no queda nadie de su equipo en pie, **muere y la baja es de
quien la derribó**; muerta ya no se levanta: en PvP vuelve en la ronda siguiente y en la Horda al
empezar la oleada siguiente. Antes volvía sola a los 15/30/60 s; eso se quitó a petición del usuario
("me gusta que duren un poco las partidas"). Los bots van a levantar a un compañero si no tienen un
rival a menos de 8 m, y un derribado se arrastra hacia el compañero en pie más cercano. Animaciones:
el derribado **gatea de verdad** (`Crawl_Fwd/_Bwd/_Left/_Right/_Idle`, de la biblioteca Pro) y quien
levanta se arrodilla (`Fixing_Kneeling`). Medido con bots
(4v4): 12 derribos, 4 levantados (12,6 s de media derribados) y 2 muertos desangrados.

**Las 10 oleadas y los jefes** (esquema del usuario, 2026-09-17): la Horda dura **10 oleadas** y
superarlas es **ganar** (antes no acababan nunca). Los **Rompemareas** empiezan en la **oleada 5** y
van a más: **1 en la 5, 2 en la 6, 3 en la 7 y 4 de la 8 a la 10**. Cuando salen varios, la vida de
cada uno se reparte por la raíz del número (cuatro jefes no son cuatro veces la vida, sino el doble
en total): con la vida entera eran 9.200 puntos de jefe y no había por dónde. Al empezar cada oleada
se anuncia en pantalla ("Oleada 6 de 10 · ¡2 ROMPEMAREAS!").

Con el equipo salen **más criaturas**: +6 por compañero en cada oleada (antes +3) y +10 vivas a la
vez (antes +8), así que un equipo de cuatro se enfrenta a 44 criaturas en la oleada 5 con hasta 70
vivas. Medido con bots: tanto en solitario como en equipo de cuatro se cae en la **oleada 5** a los
~5,5 minutos; de la 6 en adelante los bots aguantan menos de un minuto, así que el tramo con varios
jefes es, hoy por hoy, contenido al que llegar jugando bien.

**Horda en equipo**: tus compañeros salen a tu lado con leyendas distintas. Las criaturas persiguen a
la leyenda que tengan más cerca, y las oleadas crecen como en el 2D: 3 criaturas más por compañero y
8 más a la vez. Las bajas de tus compañeros no cuentan para tus insignias. Por fin la Horda respeta la
leyenda elegida en el menú (antes salías siempre con el Tormentero).

Reglas por equipos (a petición del usuario, 2026-09-16):

- **Una ronda la gana el equipo que deja al rival sin nadie en pie a la vez.** Un derribado sigue
  contando como caído: vuelve solo si un compañero lo levanta (ver **Derribo y reanimaciones**,
  arriba), y si muere ya no vuelve hasta la ronda siguiente; mientras tanto la cámara sigue a un
  compañero vivo. La partida la gana el primero que se lleva
  **2 rondas**; si caen los dos equipos a la vez, la ronda no es de nadie.
- Entre rondas hay **4 s de descanso** con el cartel del resultado; después todo lo que quedó en el
  suelo desaparece, cada leyenda vuelve entera a su zona de salida y el gas se reinicia.
- **Ritmo de pelea** (a petición del usuario, 2026-09-16, tras medir peleas de ~7 s):
  - **Vida ×3** en todas las leyendas. La curación y el daño del gas también van ×3, para que no
    pierdan peso.
  - **Definitiva por carga**, no por recarga: empieza vacía en cada ronda y se llena con el daño que
    haces con la básica y la táctica (el de 6 s de tu básica sin fallar, ×3 por la vida), más un
    goteo de 45 s por si no pegas. Lo que hace la propia definitiva no la recarga. El botón enseña
    el porcentaje.
  - **Las básicas teledirigidas pueden fallar**: vuelan recto hacia donde apuntaste, solo corrigen
    en los últimos 2 m y como mucho 40°/s, impactan al tocar a alguien por el camino y se apagan al
    llegar a su alcance. En la Horda siguen sin fallar.
  - **Mapa más corto**: el área limpia arranca al 65 % del mapa, así que las zonas de salida quedan
    más cerca y cuevas y esquinas son gas desde el principio. El gas espera 25 s y cierra ×1,5.
  - **Munición en la básica** (idea del usuario, estilo Brawl; el 2D no la tiene): 3 disparos que
    vuelven de uno en uno. Se pueden soltar seguidos y luego hay que esperar, así que fallar cuesta.
    Se ve en tres segmentos naranjas bajo tu vida y en arcos alrededor del botón de ataque; sin
    munición suena a hueco y la barra parpadea. Solo ves la tuya. **La Ilusionista no tiene**: no
    tiene habilidades de daño y su ventaja es la cantidad de disparos. La carga de la definitiva se
    calcula igual que sin munición (rebajarla casi duplicaba las definitivas).

    | Leyenda | Básica | Vuelve 1 disparo cada | Daño sostenido de la básica |
    |---|---|---|---|
    | Tormentero, Trasgo Nox, Clérigo | cada 0,6 s | 1,0 s | −40 % |
    | Rey liche | cada 0,7 s | 1,15 s | −40 % |
    | Caballero esqueleto | cada 0,8 s | 1,0 s | −20 % |
    | Rompemareas | cada 1,1 s | 1,4 s | −20 % |
    | Ilusionista | cada 0,18 s | sin límite | ×1,6 (ver abajo) |
  - **Trampa eléctrica y Baliza Nox tardan 3 s en activarse** (ver "Baliza Nox del Trasgo Nox").
  - **Pistola de la Ilusionista ×1,6** por equipos (petición del usuario; 9 → 14,4 por bala; en la
    Horda sigue en 9): necesitaba ~70 balas para tumbar a cualquiera y ganaba 8 de 36 duelos. Medido
    con 36 duelos por valor: ×1,3 gana 13, ×1,6 gana 16 y ×2,0 gana 19, pero con ×2,0 ya gana el
    67 % por equipos; con ×1,6 gana el 50 %. Ni con ×2,0 le gana un duelo al Tormentero (su trampa
    la deja aturdida dentro) ni al Rey liche (los esqueletos se comen las balas).
- Tope de ronda: 150 s; si se agota, gana quien tenga más leyendas en pie y, si hay las mismas,
  más vida.
- **Regeneración**: tras **10 s sin recibir daño** (a petición del usuario; el 2D usa 4 s), cada
  leyenda recupera el 8 % de su vida máxima por segundo (`player.REGEN_RATE` del 2D). Vale también
  en la Horda.
- Leyendas: la tuya, y las de los bots sin repetir dentro de un equipo (entre equipos sí; en el
  duelo, contra otra distinta). Nombres encima de la barra, en azul los tuyos y en rojo los rivales.
- Los bots (`game/bot_brain.gd`, adaptado del 2D) buscan al rival **visible** más cercano, pelean a
  la distancia de su leyenda, huyen con poca vida, vuelven al área limpia si les pilla el gas y
  caminan por la rejilla con A*. Agacharte en la hierba alta y la invisibilidad del Ilusionista les
  despistan, y sus señuelos les engañan. Como haría una persona, **rodean lo que el rival dejó puesto
  y se ve** (trampas, balizas, nubes, tormentas y espinas) y salen si les pilla dentro; antes lo
  pisaban a ciegas y las trampas hacían el 36 % del daño. Con munición guardan el último disparo
  para cuando el rival está cerca (a menos del 70 % del alcance).
- **Pausa**: botón ☰ arriba a la izquierda o tecla **P**: Seguir, Reiniciar o volver al Menú (vale
  también en la Horda). Al acabar la partida, pantalla final con rondas, bajas y caídas de cada
  leyenda, y botones Revancha y Menú.

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

Persiguen a la leyenda del equipo más cercana con un **campo de flujo** BFS sobre la rejilla (una
sola búsqueda cada 0,4 s, con todas las leyendas vivas de fuente, sirve para todos, en vez de una
ruta por bicho). Se separan entre ellos, muerden al alcance y la oleada siguiente sale 4 s después de
limpiar la anterior.

**El jefe** (oleada 5 y sus múltiplos, o `--boss`) es una **leyenda Rompemareas llevada por un bot del
bando de la horda**, como el jefe-leyenda del 2D: usa sus poderes (mandoble cargado, Enganche que te
arrastra, Ancla clavada). Antes era un zombi grande con su modelo que solo pegaba de cerca (el
usuario: "nunca usó sus poderes contra mí"). Vida ×4 la del Rompemareas más un 20 % por compañero,
todo su daño ×1,5 (2D), un 30 % más grande, **sin regeneración** (con 1.700 de vida el 8 %/s eran
138 por segundo) y no se reanima. La oleada no acaba hasta tumbarlo. Medido con bots: cuatro lo
tumban en 33 s; dos caen en 15 s (su mandoble cargado pega ~190): se ajusta en la etapa de
dificultad.

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

**Biblioteca Pro** (Universal Animation Library [Pro] de Quaternius, CC0, 2026-09-17): sustituye a la
gratuita y pasa de 43 a 120 animaciones. Con ella, las leyendas ya no giran siempre hacia donde andan:
**tu leyenda mira a donde apunta la cámara** y **un bot a su objetivo**, así que el movimiento se
dibuja con la animación que toca según hacia dónde va respecto a donde mira — `Jog_Fwd`, `Jog_Bwd`,
`Jog_Left`, `Jog_Right`, sus versiones agachadas (`Crouch_*`) y, derribado, las de gatear (`Crawl_*`).
La regla vive en `Combat.move_anim` y hacia dónde mira cada uno en `Combat.face_dir`.

**Al recibir un golpe se quejan** (petición del usuario, 2026-09-17): una animación corta de encogerse
**por donde le han dado** — `Hit_Chest` de frente, `Hit_Head` por la espalda y `Hit_Shoulder_L/R` por
los lados (`Combat.hit_anim`). Solo con golpes que quiten al menos el **4 % de su vida máxima** y como
mucho una queja cada **1,2 s**, para que el veneno, el gas o una ráfaga no los dejen tiesos; el conjuro
que estén echando manda sobre la queja. **Con menos de media vida** se quedan **encorvados** al pararse
(`Idle_Tired`).

Para juzgar una animación en una captura: `--poseanim=Crawl_Fwd`, y con `--roster --poseanim=Idle_Tired`
salen las siete leyendas haciéndola en fila.

**Cada habilidad con su gesto** (peticiones e ideas del usuario, 2026-09-17). Antes las 21
habilidades de las 7 leyendas salían con dos animaciones: un tajo para lo cuerpo a cuerpo y un
conjuro para todo lo demás. Ahora:

| Leyenda | Habilidad | Animación |
|---|---|---|
| Tormentero | Trampa eléctrica · Tormenta | `OverhandThrow` · `Spell_Double_Shoot` |
| Clérigo | Sanación · Esporas | `Spell_Double_Shoot` · **`Consume`** (se bebe el frasco) |
| Ilusionista | Pistola espectral · Fiesta de clones | **`Pistol_Shoot`** · `Spell_Double_Shoot` |
| Caballero esqueleto | Lanzada · Corte de hacha · Muro de espinas | `Sword_Regular_A` · **`Sword_Dash`** · `OverhandThrow` |
| Rompemareas | Mandoble (normal · **cargado**) · Enganche · Ancla clavada | **`Sword_Regular_C`** · **`Sword_Regular_Combo`** · `OverhandThrow` · `Sword_Regular_B` |
| Rey liche | Alzar esqueleto · Alzar ejército · dar órdenes | `Spell_Double_Shoot` · `Spell_Double_Enter` · **`Idle_Rail_Call`** |
| Trasgo Nox | Frasco · Baliza · Granada | `OverhandThrow` (los tres, a distinta velocidad) |

El campo nuevo **`anim_charged`** (con su `adur_charged`) es para el mandoble: al cargarlo sale el
combo en vez del tajo normal. Las órdenes del Rey liche usan `Combat.gesture`, que reserva la
animación unos segundos sin ser una habilidad. `tests/test_anim_map.gd` carga las dos bibliotecas de
verdad y falla si una habilidad pide una animación que no existe, que no está injertada o que sale
fuera de 0,4-3× al estirarla al preaviso.

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

## Aviso de media vida

Petición del usuario (2026-09-17): **por equipos no ves la barra de vida del rival**, así que cuando
tu equipo le baja del **50 %** suena algo que se quiebra (cristal del pack de golpes de Kenney, CC0),
en la posición del rival y con el volumen según lo lejos que esté. Solo suena **una vez por cruce**
(si ya estaba por debajo, no vuelve a sonar) y **no suena si ese golpe lo derriba**, porque eso ya se
ve y se oye. Reglas en `Combat.crossed_half`; medido: 7 avisos en una partida 2v2 de bots.

## Toxina del Clérigo

Desviación del 2D (petición del usuario, 2026-09-17, "para que el Clérigo coja más fuerza"): **cada
Golpe sagrado que impacta envenena**. El veneno quita **8 de vida por segundo** y cada golpe le suma
**2 s**, hasta un tope de **6 s**; es decir, **16 de daño extra por golpe**, tanto como el impacto,
y mientras dure impide que el rival empiece a regenerar (la regeneración pide 10 s sin
recibir daño). Pica cada 0,5 s con una bocanada verde, se acredita a la básica —así que carga su
definitiva igual que el impacto— y vale contra criaturas, leyendas, esbirros y señuelos. Entre rondas
se limpia. En datos son dos campos de la habilidad (`toxin` y `tdmg` en `LegendData.ABILITIES`), así
que cualquier otra habilidad puede envenenar añadiéndolos.

**Medido** (el Clérigo en los 4 modos × 4 semillas, 16 partidas por versión): su daño con la básica
sube de **1.124 a 1.630 por partida** (+45 %; la toxina pide 910 por partida, parte se la comen
inmunidades y objetivos que no son leyendas). **Sus victorias no se mueven**: 42 % antes, 40 %
después. El cuello de botella no es su daño, sino que en partidas de bots muere mucho (K/D 19/27) y
su cerebro pelea a 4,7 m pudiendo disparar a 10,6 (`BotBrain.DESIRED_RANGE`). Cuando lo llevas tú,
la toxina es daño limpio que además impide que el rival empiece a regenerar.

## Esporas del Clérigo

Cuánto quitan, medido en partidas de bots (2v2, vida ×3): **~250 de vida por lanzamiento** con
varios infectados, y **~175 a una leyenda sola** (un cuarto de sus 720). Es su definitiva, así que
sale 2-5 veces por partida.

Con la mecánica real de `player.gd` (SPORE_*): infecta al apuntado y a los de alrededor, cada
infectado lleva **cuatro bultos pegados al cuerpo**, el daño empieza en 10/s y sube +1,5 por
infectado (contando 7 como mucho), y **al morir un infectado los bultos revientan**: la plaga salta
a los que estén a 5 m y el daño se multiplica por 1,25, hasta un techo de 60/s. También contagia
por cercanía a 2 m en cada tick. Los jefes resisten.

## Órdenes de los esqueletos del Rey liche

Petición del usuario (2026-09-17; `game/minions.gd`). Con esqueletos vivos aparece el **botón de
órdenes** (▲ Atacar, ● Reagrupar, ▼ Emboscada, con la orden puesta debajo), y en teclado la **F**:

- **Tocar** (o pulsar F): alterna **Atacar** y **Reagrupar**.
- **Arrastrar y soltar** (o mantener F y apuntar con el ratón): **Emboscada** donde sueltes, hasta 12 m,
  con un aro de 3 m que marca la zona.

| Orden | Qué hacen |
|---|---|
| **Atacar** (la de partida) | cada uno va al enemigo visible más cercano a él, esté donde esté, rodeando obstáculos; si no hay nadie, vuelve con el Rey |
| **Reagrupar** | le siguen en dos anillos (4 a 2 m y 6 a 3,5 m), separados unos de otros; golpean a quien tengan a 2 m, sin perseguir |
| **Emboscada** | van al punto, se reparten en 3 m y **se entierran**: medio hundidos, sin chocar, translúcidos para tu equipo e **invisibles para el otro bando** (ni bots, ni teledirigidos, ni zonas, ni criaturas los ven). **Si un enemigo pasa a 4 m de cualquiera, salen todos y pasan a Atacar** |

Antes iban en línea recta al enemigo visible a menos de 18 m (se atascaban en las rocas) y, sin nadie,
se quedaban quietos donde nacían. Ahora andan a 3,1 m/s por la rejilla, los nuevos obedecen la orden
puesta, y por equipos tienen vida ×3 como las leyendas (180). Los bots Rey liche mandan Atacar
mientras pelean y Reagrupar cuando huyen; no emboscan. `tests/minion_probe.gd`: Atacar llega a una
diana a 20 m en 5,6 s, Reagrupar los deja a 2,9 m de media tras andar 20 m, la emboscada los entierra
en 4 s y salen a Atacar en cuanto aparece alguien a su lado.

## Señuelos del Ilusionista

Repiten tu desplazamiento girado a su propia orientación (SPREAD) o salen de largo (FORWARD),
y **copian tu animación**: si conjuras, conjuran. **Sin tinte a propósito** (petición del usuario):
el `decoy.gd` del juego los pinta de violeta para que TÚ los distingas, pero aquí la idea es que
el enemigo no sepa cuál eres. Son **inmunes a las esporas**.

**Si la derriban, sus señuelos también lo parecen** (petición del usuario, 2026-09-17): llevan **su
mismo letrero** (el nombre, y "¡DERRIBADO! N s" cuando cae), **su misma animación** —también la de
arrastrarse—, **se arrastran a su paso** (los de largo dejan de correr) y **se quedan sin barra de
vida** igual que ella. Sin eso, el letrero y la barra decían al momento cuál era la de verdad.

**Cuánto aguantan**: un solo golpe disipa el **Señuelo** (la táctica), como en el 2D. Los **cinco
clones de la Fiesta**, en cambio, tienen **vida ×3 como las leyendas** (decisión del usuario,
2026-09-17: querían que duraran sus 20 s; con un golpe duraban 5,5 s de media). Medido ahora:
**14,6-17,7 s de media** por clon.

**Romper un señuelo marca a quien lo rompió** (idea del usuario, 2026-09-16; el 2D no lo tiene):
durante **5 s** el equipo de la Ilusionista lo ve con un **contorno rojo a través de muros, rocas y
hierba**, no puede esconderse agachado y los bots de ese equipo van a por él. Cuenta también si lo
rompe su trampa, su zona o su esbirro; no cuenta si el señuelo caduca o si ella se intercambia con
él. Romper otro vuelve a 5 s, no suma. Si te marcan a ti, un aviso rojo arriba te lo dice con la
cuenta atrás. El contorno (`fx/mark_fx.gd`) son dos pasadas en `material_overlay`: la silueta
escribe en el stencil sin mirar la profundidad y el borde, engordado en píxeles de pantalla, se
pinta solo fuera de ella. Funciona en Forward+ y en Compatibilidad (móvil).

## Rayos del Tormentero

La **Trampa eléctrica** puesta es una **esfera eléctrica que flota** sobre su aro, con **diez brazos
de plasma finos** que se encienden y se apagan por turnos cada 0,09 s, para que parezca electricidad
y no una estrella fija (peticiones del usuario, 2026-09-17; antes era un disco pequeño en el suelo
que no se leía, y luego cuatro brazos gruesos y fijos). Los brazos se rehacen con senos del reloj, no con el `rng`, para no cambiar las
trazas deterministas. Cada descarga suelta un rayo del cielo sobre cada víctima y **suena**
(`shock.ogg` de Flare, el mismo del 2D). La **Tormenta eléctrica** tira siete rayos al caer y,
además, **un rayo con trueno sobre cada enemigo que siga dentro** en el golpe y en cada descarga de
su campo (cada 2 s durante 10 s; `thunder.ogg`). Petición del usuario, 2026-09-17. Ojo con el
determinismo: los rayos sortean su zigzag con el `rng` de la partida, así que añadir rayos cambia la
traza del Tormentero (las demás salen iguales).

## Baliza Nox del Trasgo Nox

Con `beacon.gd` del juego: una **esfera de 60 de vida apoyada en el suelo que bloquea el paso**
(petición del usuario, 2026-09-17; antes era un poste). Al activarse **crece y late**; llevó humo
saliendo de ella un rato y el usuario lo quitó ("no generes 3 bolas arriba, me parece innecesario"). Espera dormido y lo
despierta un enemigo a 2 m **o cualquier golpe** — las criaturas la muelen a golpes si la tienen a
mano. Al reventar suelta humo Nox de 5 m durante 10 s: 8 de daño cada 0,5 s y **velocidad a la
mitad**. 3 cargas, una cada 10 s, hasta 5 puestas.

**Por equipos, la Baliza Nox y la Trampa eléctrica tardan 3 s en activarse** (petición del usuario,
2026-09-17; en la Horda y en el 2D saltan al momento). Mientras se activan se ven pero no saltan;
al activarse la trampa enseña su aro con un chispazo y la baliza da un destello. Antes el Tormentero
lanzaba la trampa encima del rival y saltaba en el acto (340 de 344): era un aturdimiento seguro y
ganaba el 81 %. Medido con 28 partidas: con 2 s bajaba al 45 %, pero el Trasgo Nox y el Rompemareas subían
al 80 % y 72 %; con 3 s todas las leyendas quedan entre el 30 % y el 56 %. Contra: las peleas se
alargan (1v1 de 22 a 57 s, 4v4 de 34 a 43 s).

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

**Pensado para PvP** (1v1 a 4v4, petición del usuario). Corre en la Horda y en los modos por
equipos; en estos arranca al 65 % del mapa, espera 25 s, cierra ×1,5 más rápido, quema ×3 y se
reinicia en cada ronda (ver "Menú y modos
de juego"). Daña a todas las leyendas y criaturas que pille fuera. `--nozone` lo apaga.

El gas **está en el borde del mapa desde el primer segundo**: el área limpia arranca siendo el
círculo inscrito en el mapa, así que las cuatro esquinas ya son gas. A los **2 minutos** empieza a
cerrarse a 0,24 m/s y mientras encoge **el centro se va desplazando** hacia un punto sorteado: si
solo encogiera, la partida acabaría siempre en el mismo sitio y el cementerio y las cuevas dejarían
de existir a partir de la mitad. **En la Horda se para al 60 % del radio inicial** (unos 38 m,
alcanzados en ~1,8 min; petición del usuario, 2026-09-17: "no es necesario que la zona avance tanto
en el modo zombie"); por equipos sigue cerrando hasta 10 m.

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

## Minimapa

Arriba a la derecha, un cuadro de 190 px (petición del usuario, 2026-09-17) con el terreno alrededor
de tu leyenda: **gira con la cámara**, así que lo que tienes delante queda arriba. Tú eres la **flecha
blanca** del centro (naranja si te derriban), tus compañeros **puntos azules** (naranjas si están
derribados), el borde del área limpia es el **aro violeta**, y los enemigos salen en **rojo**:

- los que **ve tu equipo**: a 23,4 m o menos de ti o de un compañero que no haya muerto (lo mismo que
  ve un bot) y sin esconderse (agachado en hierba alta o invisible por la Fiesta de clones no sale);
- los **marcados** por romper un señuelo, con un aro, estén donde estén;
- **quien acaba de atacar** (`spotted`), esté donde esté: disparar te delata también en el mapa.

Lo que cae fuera del cuadro se pega al borde en su dirección. En la Horda salen igual las criaturas y
el jefe. El terreno es una imagen de un píxel por celda hecha al empezar (suelo, hierba alta, agua y
lo que bloquea), y el mapa se redibuja 20 veces por segundo, no en cada fotograma. Las bajas recientes
(PvP) y el panel del equipo (Horda) van justo debajo. Código: `ui/minimap.gd`; pruebas:
`tests/test_minimap.gd` y `tests/minimap_probe.gd`.

## Cubrirse y esconderse

- **Peñascos** (`_scatter_cover`, ~47 por mapa). **Los personajes se metían dentro de ellos**
  (2026-09-16): las rocas `Rock_Medium` miden ~3,2 m con el pivote desplazado casi 1 m, y puestas a
  escala 1,4-2,1 con un cilindro de colisión de ~1 m, la roca visible era 3-5 veces su colisión
  (`tests/rocks_probe.gd` lo medía en 3.300 de 3.600 fotogramas). Ahora cada peñasco ocupa **una
  celda despejada** que pasa a bloqueada (el campo de flujo y los bots la rodean), se escala y se
  centra por su huella real para caber en 1,3 m de radio, estirado a lo alto (~1,7-2 m, tapa a
  alguien de pie), y **choca con su envolvente convexa real**. Se eligen con
  `MapLayout.pick_cover_cells` sin cerrar pasillos ni dejar callejones, y nunca a menos de 3 celdas
  de donde aparece el jugador (una vez le tocó uno encima y arrancó subido a él).
- **Rocas de las cuevas**: las que dan a un pasillo se encajan en su celda (`MapLayout.fit_in_cell`):
  hacia el suelo no asoman más de 10 cm y hacia las vecinas de muro se solapan, así que la pared se
  ve continua y no hay huecos con pared invisible.
- **Lápidas** del cementerio: medían 31 × 37 cm y no chocaban; ahora ~75 × 90 cm con caja de
  colisión, y las criaturas brotan sobre la losa, delante de la piedra.
- **Tres alturas de hierba** (petición del usuario, 2026-09-17; `MapLayout.grass_tier`):
  **alta** (`tall_grass`, 16 manchas de hasta 3 celdas de radio): el triple de matas, solo las
  variedades altas y a escala 1,0-1,5, para que se vea de lejos que ahí cabe alguien — y es la única
  donde te escondes; **media** (`mid_grass`, 22 manchas de hasta 5 celdas): por la cintura, escala
  0,75-1,05 y densidad intermedia, **solo paisaje: no esconde a nadie**; y **matas bajas** en el
  resto de la pradera (0,45-0,8).
- **Eriales** (7 manchas, zona 3 de `zones`): tierra pelada con guijarros y algún matojo seco, sin
  hierba, y las rocas del mapa que caen ahí salen de roca en vez de árbol. Da mezcla de pasto, tierra
  y roca sin tocar el generador del 2D: las manchas se marcan en el 3D, antes de construir el suelo
  (de ahí salen el color del terreno, los bloqueadores y la decoración). **Solo guijarros de adorno**:
  una `Rock_Medium` decorativa se ve como un peñasco pero no tiene colisión y las criaturas la
  atravesaban (lo cazó `rocks_probe`). Las manchas se sortean con su PROPIO generador aleatorio: si
  gastaran del sorteo de la partida moverían los peñascos de cobertura, que se eligen después.
- **Agacharse con Ctrl**: frena al 45 %, baja la cámara y usa las animaciones `Crouch_Idle` /
  `Crouch_Fwd` del pack. Agachado **dentro de una mancha de hierba alta eres invisible** para las
  criaturas; atacar te delata 3 s (`SPOTTED_TIME`). En táctil, el botón **▼ Agacharse** junto al
  joystick: un toque lo activa y otro lo quita (mantenerlo mientras mueves y atacas pedía tres
  dedos); se suelta solo al caer. La pausa recuerda los controles de teclado.
- **Las criaturas buscan** (petición del usuario, 2026-09-17; `game/creature_senses.gd`). Antes
  sabían siempre dónde estabas (un campo de flujo hacia ti) y, si te escondías, se quedaban quietas
  donde te vieron. Ahora cada una va por su cuenta, mirando cada 0,25 s:
  - **Deambulan** buscando: la mitad de sus metas al azar a 10 celdas o menos, la otra mitad cerca
    del centro del área limpia (donde el gas acaba empujando a todos); esperan un poco en cada meta.
  - **Te ven a 12 m de día y a 8 m de noche**, si no hay muro ni roca en medio (el agua no tapa).
  - **Agachado en hierba alta (o invisible) solo te descubren si pasan a 1,5 m o menos**, casi
    encima. La que ya te persigue te sigue viendo a 4 m: agacharte 2 m más allá no basta.
  - **La que te descubre grita** ("!" rojo y un sonido) y **avisa a todas las que estén a 30 m**:
    saben a quién y dónde.
  - **Si pasan 3 s sin verte**, van al último sitio donde te vieron, **rebuscan 8 s** alrededor y
    vuelven a deambular. Atacar te delata 3 s, como siempre.
  - Deambulando van despacio (55 %), rebuscando al 80 % y persiguiendo a tope. Esbirros y señuelos
    siguen siendo presa a 14 m: los señuelos están para engañar.
  - **Más difícil según avanza** (misma petición): las criaturas pegan ×1,3 respecto al 2D, cada
    oleada sale con +10 % de vida (el `HP_PER_WAVE` del 2D) y el cierre del gas va en 4 tramos: en
    cada uno, +15 % de vida para lo que salga, y +10 % de daño y +5 % de velocidad para todas ("¡La
    horda se endurece!"). El gas cierra del todo hacia el minuto 4. Medido con bots en 10 min:
    | | antes | ahora |
    |---|---|---|
    | Solo (7 leyendas) | todas caen en la oleada 5, la del jefe (271-354 s) | caen en las oleadas 3-5 (206-340 s) |
    | Equipo de 4 (3 partidas) | oleada 9-10 sin perder | 2 caen en la oleada 5 (~300 s); 1 llega a la 10 |
  - Medido con dos bots quietos en el centro: la primera detección llega a los ~25 s y la oleada 1
    se limpia en ~85 s. `tests/senses_probe.gd` comprueba que cada detección cumple las reglas, que el
    grito no pasa de 30 m y que las que deambulan se mueven.
- **La horda aprieta** (2026-09-17): una criatura que lleva **20 s deambulando sin ver a nadie**
  (`CreatureSenses.HUNT_AFTER`) se lanza hacia la leyenda más cercana. Sin eso, una sola criatura
  perdida en una esquina dejaba la oleada sin acabar nunca —lo cazó `horde_probe` al cambiar el
  terreno— y la horda no presionaba: con la correa, un equipo de 4 bots pasa de 27 a 59 bajas en los
  mismos 120 s.

## Premios de racha

Las 10 insignias del juego (`hud.KILL_REWARD_NAMES`, no existe la 2), con sus mismas imágenes y la
misma presentación. Insignia 1 en la primera baja, de la 3 a la 9 por racha, 10 y 11 ("La parca")
al llegar a 10 bajas. La racha se pierde al morir. **Diferencia con el juego**: aquí no hay rotación
de "La parca" porque solo juegas tú, así que el título se gana por bajas totales.

**Dónde y cómo suenan** (peticiones del usuario, 2026-09-17): la insignia sale **justo debajo de tu
leyenda** (antes tapaba sus piernas) y en el centro de abajo, que está libre —el joystick va a la
izquierda y las habilidades a la derecha—; y **se oye**: `badge.wav` a volumen pleno más un golpe de
campana que sube con la racha (antes sonaba a −4 dB y pasaba desapercibida). Para verla y oírla sin
jugar: `--badge=3`.

## Controles

| Tecla | Qué hace |
|---|---|
| WASD | mover (relativo a la cámara) |
| Shift | correr |
| ratón | girar la cámara |
| rueda | acercar / alejar |
| clic izquierdo o Q | básica (mantener: carga el mandoble del Rompemareas) |
| clic derecho o E | táctica (mantener para ver el radio, soltar para lanzar) |
| R | definitiva (igual) |
| Ctrl | agacharse (en el móvil, el botón ▼ junto al joystick: un toque lo activa y otro lo quita) |
| F | Rey liche con esqueletos: alterna Atacar/Reagrupar; mantenida, apunta una Emboscada (en el móvil, botón de órdenes) |
| **C** | cambiar cámara: sobre el hombro ↔ vista alta tipo ARPG |
| Tab, 1-7 | cambiar de leyenda (solo en la Horda) |
| P o ☰ | pausa: Seguir, Reiniciar, Menú |
| Esc | soltar el ratón |
| F10 | salir |

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
  una atadura nueva, pero hay que respetarla. Los rayos (`shock.ogg`, `thunder.ogg`) son de Flare,
  con la misma licencia, copiados del 2D.
- El resto (partículas y música de Kenney, cynicmusic, Juhani Junkala) es CC0.

## Opciones útiles para probar

```
--near=5        las criaturas salen a 5 celdas de ti, para pelear ya
--zombies=N     tamaño de la oleada
--win-now       (horde_probe) barre la última oleada para comprobar la victoria
--wave=N        empezar en la oleada N
--nodecor       sin hierba ni flores
--noshadow      sin sombras
--log           traza por consola (headless)
--bench         FPS y tiempos por fotograma
--fxtest        mantiene rayos, una esfera y la trampa o baliza de tu leyenda puestas, para juzgar los efectos
--poseanim=N    fija esa animación en tu leyenda (Crawl_Fwd, Jog_Left, Idle_Tired...) para juzgarla en
                una captura; con --roster, la hacen las siete leyendas en fila
--badge=N       enseña la insignia de racha N al empezar (sitio y sonido)
--sporelog      traza el contagio y el daño creciente de la plaga del Clérigo
--dashlog       mide si el Corte de hacha recorre lo que debe y a quién arrolla
--meleelog      radio, apertura y a cuántos tocó cada golpe cuerpo a cuerpo, y cada tirón del ancla
--dianas=N      N criaturas quietas en fila a 6, 11, 16... m, con su distancia escrita
--cd=N          recorta todas las recargas a N s (solo prueba)
--nozone        sin gas que se cierre
--zonewait=N    segundos hasta que el gas empieza a cerrar (por defecto 120)
--zonefast=N    multiplica la velocidad de cierre, para verlo sin esperar
--mode=M        horda | 1v1 | 2v2 | 3v3 | 4v4 | menu (sin menú; menu sirve para capturarlo)
--legend=N      tu leyenda (0-6; 7-9 son las retiradas, solo en la Horda)
--autoplay      tu leyenda la lleva un bot (partidas enteras sin jugar), por equipos y en la Horda
--team=N        Horda con N leyendas (1 = solo, hasta 4): tú y N-1 compañeros bot
--down-one=S    (horde_probe) tumba a un compañero bot a los S s para probar las reanimaciones
--down-player=S (horde_probe) te tumba a ti a los S s, para probar la derrota sin depender del balance
--down-decoys   (decoy_probe) derriba a la Ilusionista en cuanto tenga un señuelo, para ver si la copian
--expect-defeat (horde_probe) la partida tiene que acabar en derrota antes de --secs
--seed=N        cambia el sorteo de la partida (leyendas, decoración) sin mover el mapa: sirve para medir
                varias partidas distintas del mismo escenario (sin el flag, la de siempre: 1234)
--rounds=N      rondas para ganar la partida (por defecto 2: al mejor de 3)
--roundtime=S   tope de una ronda (por defecto 150 s)
--autocast      en la Horda, lanza solo lo que esté listo hacia la criatura más cercana
--probe=nombre  engancha tests/nombre.gd (rocks_probe, match_probe, decoy_probe, minimap_probe,
                horde_probe, boss_probe, senses_probe, minion_probe) y sale con 0 o 1
```

Partida de bots en headless, al mejor de 3, con traza cada 5 s:

```
godot --headless --fixed-fps 60 --path . -- --mode=4v4 --autoplay --log --probe=match_probe
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

12. **`set_anchors_preset` con el nodo ya en el árbol conserva su tamaño** (2026-09-16): el menú,
    el marcador y la pantalla final salían pegados arriba a la izquierda porque su raíz medía 0×0
    pese a las anclas a pantalla completa. Con el nodo en el árbol hay que usar
    `set_anchors_and_offsets_preset`.
13. **`godot --check-only` no detecta llamadas a métodos inexistentes** sobre variables tipadas
    (`main.no_existe()` parsea bien): solo identificadores sueltos y tipos. La red de seguridad de
    verdad son las sondas en ejecución (`tools/check.sh`).
14. **`match` es palabra reservada** en GDScript: no vale como nombre de variable.
15. **`DisplayServer.is_touchscreen_available()` es true en cualquier escritorio** si
    `emulate_touch_from_mouse` está activo: el Mac arrancaba en modo móvil (joystick en pantalla,
    sin sombras, oleada 2). La emulación no cuenta; `--touch` sigue forzándolo.
16. **En headless el renderizador de relleno no guarda las transformadas de un MultiMesh**
    (`get_instance_transform` da la identidad): por eso `_multimesh` registra dónde coloca cada copia
    (`_placed`) y las sondas leen de ahí.
17. **Las rocas de Quaternius tienen el pivote descentrado** hasta 0,85 m y miden ~3,2 m: colocarlas
    por su pivote y con una colisión "a ojo" las deja invadiendo pasillos. Se encajan por su huella.
18. **Una barra por trozos no puede llevar `billboard` en cada trozo**: el billboard gira cada malla
    sobre su propio origen, pero el desplazamiento lateral de cada segmento se queda en el mundo, así
    que al girar la cámara los segmentos se montan. La barra de munición gira el nodo entero hacia la
    cámara (`global_basis = cam.global_basis`) y sus trozos van sin billboard.
19. **Medir el balance con bots engaña si los bots no ven lo que ve una persona**: pisaban todas las
    trampas y balizas (36 % del daño). Rodearlas bajó al Trasgo Nox del 80 % al 40 % de victorias.

**Trampa del `--shot` en headless**: sin ventana, `get_viewport().get_texture().get_image()`
devuelve nulo, y llamar a `save_png` sobre nulo **aborta la función** en GDScript. El `quit()` que
va justo después nunca se ejecutaba: seis pruebas de fondo se quedaron corriendo para siempre
comiéndose la CPU, y las capturas con ventana que lanzaba después salían muertas de hambre. Ahora
hay guarda, y `--shot` con `--wait=N` en headless sirve de "corre N fotogramas y sal".
