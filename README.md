# UAI Quest: El Camino del Estudiante

Videojuego arcade 2D estilo 8-bit escrito en **Nim** con el motor **naylib / raylib**, para el proyecto de *Lenguajes y Paradigmas de la Programación* (UAI, 2026).

Un estudiante de la UAI recorre la universidad enfrentando a los lenguajes vistos en clase —**C**, **Java** y **Haskell**— y al derrotarlos absorbe sus habilidades. Con todo el arsenal se enfrenta al jefe final: el profesor **Matías Greco**.

---

## Cómo ejecutar

1. Instala **Nim 2.x** desde https://nim-lang.org
2. Instala la librería gráfica:

   ```
   nimble install naylib
   ```

3. Compila y juega:

   ```
   nim c -r -d:release uai_quest.nim
   ```

> El juego es un único archivo (`uai_quest.nim`), sin assets externos: los sprites 8-bit se dibujan con rectángulos en código.

## Controles

| Contexto | Teclas |
|---|---|
| Menús y diálogos | `ENTER` / `ESPACIO` para avanzar |
| Exploración | `←` `→` o `A` `D` mover · `ESPACIO`/`↑` saltar · `C` ver Codex |
| Batalla por turnos | `↑` `↓` elegir habilidad · `ENTER` confirmar · `1`–`9` uso rápido |
| Salir | cerrar la ventana / `ESC` |

---

## Estructura del juego

```
Menú → Crear estudiante (nombre + género) →
  Mapa 1: Entrada de la UAI   (intro, sin jefe)
  Mapa 2: Laboratorio         (jefe: C)
  Mapa 3: Sala de Objetos     (jefe: Java)
  Mapa 4: Aula Funcional      (jefe: Haskell)
  Mapa 5: Oficina del Profesor (jefe final: Matías Greco)
→ Victoria / Derrota
```

Combate **híbrido**: exploras cada mapa como un plataformas (caminar, saltar) y al llegar a la meta entras a una **batalla por turnos** contra el jefe. Al ganar, absorbes todo el arsenal de ese lenguaje y tu vida máxima sube.

---

## Paradigmas demostrados (requisito del enunciado, punto 6)

El programa combina **tres** paradigmas, etiquetados en el código fuente:

- **Imperativo / procedural** `[IMPERATIVO]` — el bucle principal (`main`), la máquina de estados (`GameState`) y la física de plataformas (`updateExplorar`): estado mutable que avanza paso a paso.
- **Orientado a objetos** `[OOP]` — jerarquía `Entity → Player / Enemy` con `ref object of`, **despacho dinámico** real vía `method` (`etiqueta`, `recibirDano`) y encapsulamiento de estado. (El propio enemigo Java es, meta-narrativamente, sobre OOP.)
- **Funcional** `[FUNCIONAL]` — las habilidades de Haskell son **funciones puras** (`func`): recursión (`danoRecursivo`), `foldl` de orden superior (`danoPlegado`), una lambda aplicada en un fold (`danoLambda`) y transparencia referencial (`danoPuro`).

**Sin datos hardcodeados:** el nombre y el género del jugador se ingresan por teclado en la pantalla de creación; no están escritos en el código.

---

## Habilidades

Se respetaron las mecánicas pedidas y se **ampliaron** con ataques extra coherentes con cada lenguaje.

### C — memoria y tipos de datos (color rojo)
- **Puntero** — golpe veloz e infalible, 8 de daño.
- **Tipos de Datos** — elige un tipo al azar; el daño depende de los bytes que ocupa (`char` 1, `short` 2, `int` 4, `float` 4, `long` 8, `double` 8) × 2.
- **malloc()** *(extra)* — reservas memoria y te curas 14 HP; 20% de *memory leak* (sin efecto).
- **Segmentation Fault** *(extra)* — comportamiento indefinido: 50% pega 22, 50% te golpea a ti.

### Java — orientación a objetos (color naranja)
- **Herencia** — reutiliza tu última habilidad usada.
- **Polimorfismo** — una llamada, varias formas: daño aleatorio ponderado (50% → 6, 30% → 12, 20% → 18).
- **Encapsulamiento** — alterna `private`/`public`: en private ganas +14 de escudo; al volver a public atacas por 12.
- **Abstracción** — ignoras el próximo golpe recibido (+5 de daño).
- **Garbage Collector** *(extra)* — limpia tus penalizaciones/buffs y recuperas 12 HP.

### Haskell — programación funcional (color morado)
- **Recursividad** — 5 golpes encadenados (caso base + paso recursivo) = 15.
- **Lambda** — ráfaga de una función anónima `(\x -> x mod 5 + 2)` plegada con `foldl`.
- **Shadowing** — sombrea un valor: +10 de bono a tu **próximo** ataque (+4 ahora).
- **Función Pura** — transparencia referencial: **siempre** exactamente 16 de daño.
- **Evaluación Perezosa** *(extra)* — crea un *thunk*: 0 ahora, +18 a tu siguiente ataque.

### Jefe final — Prof. Matías Greco (gris)
- **Examen Sorpresa** — 16 de daño.
- **Recursión Infinita** — *stack overflow*: el daño crece con cada repetición.
- **Deadline 23:59** — atraviesa tu escudo, 14 de daño puro.
- **Code Review** — borra tus buffs y escudo, y pega 10.
- **Pregunta Trampa** — golpe rápido de 8.

---

## Sistema de combate y progresión

- **Por turnos**: eliges una habilidad; se resuelve y el enemigo responde con una de las suyas.
- **Estados**: escudo (encapsulamiento / "punto y coma"), ignorar próximo golpe (abstracción), bonos diferidos (shadowing y evaluación perezosa, que se consumen en el siguiente ataque real).
- **Dificultad creciente** de los jefes: C (50 HP) → Java (72) → Haskell (92) → Profesor (150). El jugador parte con 60 HP y gana +20 de vida máxima por cada lenguaje derrotado.
- **Codex** (tecla `C` en exploración): consulta todas las habilidades acumuladas.

---

## Archivos

- `uai_quest.nim` — el juego completo.
- `README.md` — este documento.

> Nota: no se pudo compilar en el entorno de preparación (sin acceso para instalar Nim/naylib), así que el código está escrito cuidadosamente contra la API estándar de naylib. Si al compilar aparece algún ajuste menor de versión, suele ser un nombre de constante/tecla; avísame y lo corrijo.
