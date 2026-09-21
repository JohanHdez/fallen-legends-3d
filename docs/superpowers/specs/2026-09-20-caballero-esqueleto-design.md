# Caballero esqueleto: tres cortes, más aguante al cuerpo a cuerpo y combo — diseño

Fecha: 2026-09-20. Pedido por el usuario: "al Caballero esqueleto, la habilidad de corte de hacha
permitir tener 3 oportunidades, hacerlo más resistente al golpe cuerpo a cuerpo y permitir pegar más
rápido (podríamos considerar agregarle la animación de golpes consecutivos que tenemos, que se active
automáticamente después de hacer varios golpes básicos)".

## Por qué tiene sentido

El Caballero es **la leyenda más floja en duelos: 33 %** (empatada con el Trasgo Nox; el Rey liche va
al 86 %). Tiene la vida más alta (380) y la velocidad más baja (200), o sea que su papel es aguantar
y llegar — y hoy no llega: muere en el camino y, cuando llega, pega despacio. Los cuatro cambios
refuerzan justo ese papel. No es un capricho de números: es la leyenda que peor está.

## Qué tiene hoy

| Cosa | Valor |
|---|---|
| Vida / velocidad | 380 (la mayor) / 200 (la menor) |
| Básica "Lanzada" | cuerpo a cuerpo cada **0,8 s**, 30 de daño, radio 115 px (1,8 m), `Sword_Regular_A` |
| "Corte de hacha" | embestida, recarga **5 s**, 32 de daño, radio 130 px, empuja 5,5 |
| Definitiva "Muro de espinas" | recarga 25 s |
| Guardia automática | quieto 0,4 s → recibe **45 % menos** de TODO (ya existe, `GUARD_DAMAGE_MULT`) |

## Los cuatro cambios

1. **Corte de hacha con 3 cargas** — `"chg": 3` en la habilidad, con la recarga de 5 s por carga (el
   sistema de cargas ya existe: lo usan "Alzar esqueleto" del Rey liche y las trampas, y el HUD
   táctil ya dibuja un arco por carga). Guarda hasta tres embestidas: puede encadenar dos para
   alcanzar a alguien y dejarse la tercera para escapar, que es lo que el usuario pidió en su día
   ("debería poder escapar usando esa habilidad muy rápido").
2. **Aguante al cuerpo a cuerpo** — campo nuevo `"melee_armor": 0.25` en la leyenda: **25 % menos de
   daño** cuando el golpe viene de una habilidad cuerpo a cuerpo (`k` = `melee` o `dash`). Se aplica
   en `Combat.hurt`, que ya sabe de qué ranura y de qué tipo viene cada daño. **Se acumula con la
   guardia**: quieto y cubriéndose, un golpe cuerpo a cuerpo le hace 0,55 × 0,75 = **41 %** del daño.
   Empieza en 25 % justo por eso; si al medir resulta intocable, baja.
3. **Pegar más rápido** — básica de **0,8 → 0,65 s**. Sube su daño sostenido un 23 %. La munición por
   equipos (vuelve un golpe cada 1,0 s) **no se toca**: así el empujón es mayor en el cuerpo a cuerpo
   corto, que es donde tiene que ganar, y no en el desgaste a distancia, donde no debe.
4. **Combo automático** — dos golpes básicos que **acierten** en menos de 2 s hacen que el tercero
   salga con `Sword_Regular_Combo` (la animación ya está injertada; la usa el Rompemareas al cargar)
   y con **arco más ancho** (radio 115 → 150 px): premia quedarse pegado en vez de tocar y huir. El
   tercero **no hace más daño**: primero se mide con el arco solo. Si se queda corto, se sube el daño
   en una segunda pasada y se vuelve a medir. Fallar o pasar 2 s sin acertar reinicia la cuenta.

## Cómo se sabe que está

- **Prueba pura** de la cuenta del combo (dos aciertos seguidos → el tercero es el combo; un fallo o
  2 s lo reinician) y del aguante (25 % menos de un golpe cuerpo a cuerpo, nada de uno a distancia,
  y que se multiplica con la guardia).
- **Medición de duelos**, el método del repo: 6 semillas × `--foe=N` contra las otras seis leyendas,
  antes y después. Se apunta la tabla en el README. **Si el Caballero se va por encima del 65 %, los
  números se bajan**: el objetivo es que deje de ser el peor, no que sea el mejor.
- **Captura mirada** del combo: que el tercer golpe se vea distinto y no a cámara rápida (la trampa
  de `adur` que ya documenta el README).
- Puerta completa en verde. Las trazas deterministas **cambian a propósito**: se toca el balance.

## Desviaciones del 2D (van con su comentario y su fila en el README)

Las cuatro son desviaciones nuevas a petición del usuario, encima de la que ya había (recarga 7 → 5 s,
radio 70 → 130 px, daño 25 → 32 y sin `sync`, del 2026-09-18).

## Fuera de alcance

Tocar a las otras seis leyendas, la Guardia (no se cambia), y el combo para quien no sea el
Caballero. Si el Rompemareas acaba pidiendo lo mismo, será otra petición y otra medición.
