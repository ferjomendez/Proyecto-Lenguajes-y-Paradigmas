# ============================================================================
#  UAI QUEST: El Camino del Estudiante
#  Lenguajes y Paradigmas de la Programacion - Universidad Adolfo Ibanez 2026
# ----------------------------------------------------------------------------
#  Videojuego arcade 2D estilo 8-bit (motor: naylib / raylib).
#
#  Historia: un estudiante de la UAI recorre la universidad y enfrenta a los
#  lenguajes vistos en clase (C, Java y Haskell). Al derrotarlos absorbe sus
#  habilidades, y con todo el arsenal se enfrenta al jefe final: el profesor
#  Matias Greco.
#
#  ESTRUCTURA: Menu -> Mapa1 (intro) -> Mapa2 (C) -> Mapa3 (Java) ->
#              Mapa4 (Haskell) -> Mapa5 (Profesor) -> Victoria / Derrota
#
#  Combate hibrido: exploracion en plataformas + batallas por turnos.
#
#  ------------------------------------------------------------------------
#  PARADIGMAS DE PROGRAMACION DEMOSTRADOS (requisito del enunciado, punto 6):
#
#    * IMPERATIVO / PROCEDURAL : el bucle principal, la maquina de estados y
#      la fisica de plataformas (mutacion de estado paso a paso).
#    * ORIENTADO A OBJETOS     : jerarquia Entity -> Player / Enemy con
#      'ref object of', metodos con despacho dinamico ('method', polimorfismo)
#      y encapsulamiento de estado. (Seccion marcada [OOP].)
#    * FUNCIONAL               : las habilidades de Haskell estan implementadas
#      con funciones puras ('func'), recursion, lambdas y funciones de orden
#      superior (map / foldl). (Seccion marcada [FUNCIONAL].)
#
#  NO HARDCODE DE DATOS: el nombre y el genero del jugador NO estan en el
#  codigo, se ingresan por teclado al inicio (pantalla de creacion). Las
#  estadisticas de combate son parametros de diseno del juego, no datos.
#
#  ------------------------------------------------------------------------
#  COMO EJECUTAR:
#    1) Instalar Nim 2.x         (https://nim-lang.org)
#    2) nimble install naylib
#    3) nim c -r -d:release uai_quest.nim
#
#  CONTROLES:
#    Menus / dialogos : ENTER o ESPACIO para avanzar
#    Exploracion      : FLECHAS o A/D para moverse, ESPACIO/ARRIBA para saltar
#    Batalla          : FLECHAS ARRIBA/ABAJO eligen habilidad, ENTER confirma
#                       (tambien teclas 1..9 para uso rapido)
# ============================================================================

import raylib
import std/[random, tables, strutils, sequtils]

# ----------------------------------------------------------------------------
#  Constantes de pantalla
# ----------------------------------------------------------------------------
const
  AnchoPantalla = 800
  AltoPantalla  = 480
  PisoY         = 400        # altura del suelo en exploracion
  Gravedad      = 0.55
  FuerzaSalto    = -11.0
  VelMov         = 3.6

# ----------------------------------------------------------------------------
#  Helpers de dibujo (envuelven la API de raylib usando int en vez de int32)
#  [IMPERATIVO] efectos sobre el framebuffer.
# ----------------------------------------------------------------------------
proc rgb(r, g, b: int): Color = Color(r: r.uint8, g: g.uint8, b: b.uint8, a: 255)

proc dtext(s: string; x, y, size: int; c: Color) =
  drawText(s, x.int32, y.int32, size.int32, c)

proc dtextC(s: string; cx, y, size: int; c: Color) =
  let w = measureText(s, size.int32).int
  drawText(s, (cx - w div 2).int32, y.int32, size.int32, c)

proc box(x, y, w, h: int; c: Color) =
  drawRectangle(x.int32, y.int32, w.int32, h.int32, c)

proc boxLines(x, y, w, h: int; c: Color) =
  drawRectangleLines(x.int32, y.int32, w.int32, h.int32, c)

# Paleta retro
let
  NegroNES   = rgb(20, 18, 30)
  AzulUAI    = rgb(0, 51, 102)
  CelesteUAI = rgb(0, 120, 190)
  RojoC      = rgb(200, 50, 50)
  NaranjaJv  = rgb(225, 130, 30)
  MoradoHk   = rgb(140, 70, 200)
  VerdePiso  = rgb(70, 150, 70)
  GrisProf   = rgb(90, 90, 110)
  CremaTxt   = rgb(245, 240, 220)
  DoradoUAI  = rgb(240, 200, 60)

# ----------------------------------------------------------------------------
#  Sprites pixel-art (8-bit) dibujados con rectangulos, sin archivos externos.
#  Un humanoide generico recoloreable + iconos. [IMPERATIVO]
# ----------------------------------------------------------------------------
# Pelo corto (masculino / enemigos)
const HumCorto = [
  "  HHHH  ",
  " HHHHHH ",
  " HFFFFH ",
  " FEFFEF ",
  " FFFFFF ",
  "  FFFF  ",
  " SSSSSS ",
  "SSSSSSSS",
  " SSSSSS ",
  "  PPPP  ",
  " OO  OO "
]

# Pelo largo (femenino)
const HumLargo = [
  "  HHHH  ",
  " HHHHHH ",
  " HFFFFH ",
  " HEFFEH ",
  " HFFFFH ",
  " HFFFFH ",
  " HSSSSH ",
  "SSSSSSSS",
  " SSSSSS ",
  "  PPPP  ",
  " OO  OO "
]

# Profesor: igual que corto pero con una veta de pelo BLANCO ('W') a la derecha
const HumProf = [
  "  HHHW  ",
  " HHHHHW ",
  " HFFFFW ",
  " FEFFEF ",
  " FFFFFF ",
  "  FFFF  ",
  " SSSSSS ",
  "SSSSSSSS",
  " SSSSSS ",
  "  PPPP  ",
  " OO  OO "
]

proc drawSprite(art: openArray[string]; ox, oy, px: int;
                pelo, piel, camisa, pantalon: Color) =
  let pal = {
    'H': pelo, 'F': piel, 'E': NegroNES,
    'S': camisa, 'P': pantalon, 'O': rgb(40, 40, 40),
    'W': rgb(235, 235, 235)            # veta de pelo blanco
  }.toTable
  for r in 0 ..< art.len:
    let fila = art[r]
    for c in 0 ..< fila.len:
      let ch = fila[c]
      if ch != ' ' and pal.hasKey(ch):
        box(ox + c * px, oy + r * px, px, px, pal[ch])

# ----------------------------------------------------------------------------
#  TIPOS DE DOMINIO  [OOP]
# ----------------------------------------------------------------------------
type
  Genero = enum
    genMasc = "Masculino"
    genFem  = "Femenino"
    genOtro = "No binario"

  # Efectos especiales de las habilidades
  Efecto = enum
    # basicas
    efAtaque, efDefender
    # C  (memoria y tipos de datos)
    efPuntero, efTipos, efMalloc, efSegfault
    # Java (orientacion a objetos)
    efHerencia, efPolimorfismo, efEncapsulamiento, efAbstraccion, efGC
    # Haskell (funcional)
    efRecursividad, efLambda, efShadowing, efPura, efLazy, efFold
    # Profesor (jefe final)
    efExamen, efRecursionInf, efDeadline, efCodeReview, efTrampa

  Skill = ref object
    nombre: string
    lenguaje: string         # "Base", "C", "Java", "Haskell", "Profesor"
    descripcion: string
    danoBase: int
    efecto: Efecto
    color: Color

  # ----- Jerarquia de entidades (herencia + despacho dinamico) [OOP] --------
  Entity = ref object of RootObj
    nombre: string
    genero: Genero
    vidaMax: int
    vida: int
    escudo: int              # encapsulamiento / defender
    ignorarProximo: bool     # abstraccion
    contador: int            # usado por recursion infinita del profesor
    x, y: float              # posicion en el mundo (exploracion)
    vx, vy: float            # velocidad
    enSuelo: bool

  Player = ref object of Entity
    skills: seq[Skill]
    ultimaSkill: Skill       # para Herencia
    boostNext: int           # Shadowing (bono al proximo ataque)
    lazyCargado: int         # Evaluacion Perezosa (thunk acumulado)
    modoPrivate: bool        # Encapsulamiento

  Enemy = ref object of Entity
    skills: seq[Skill]
    recompensa: string       # lenguaje cuyo arsenal entrega al morir
    descripcion: string
    pelo, camisa: Color

  GameState = enum
    gsMenu, gsCrear, gsNivelSel, gsIntro, gsExplorar, gsBatalla,
    gsRecompensa, gsCodex, gsVictoria, gsDerrota

  Nivel = object
    nombre: string
    fondo: Color
    tieneJefe: bool
    jefeIdx: int
    intro: seq[string]

  Game = ref object
    estado: GameState
    player: Player
    enemigos: seq[Enemy]
    niveles: seq[Nivel]
    nivelActual: int
    enemigo: Enemy           # enemigo de la batalla actual
    bitacora: seq[string]    # log de combate
    menuSel: int
    turnoJugador: bool
    msgTimer: float
    introLinea: int
    nombreTmp: string
    generoSel: int
    nivelSel: int            # cursor de la pantalla de seleccion de nivel
    estadoPrevio: GameState  # para volver desde el Codex
    flashTimer: float
    parpadeo: float

# ----------------------------------------------------------------------------
#  METODOS con despacho dinamico (polimorfismo real)  [OOP]
# ----------------------------------------------------------------------------
method etiqueta(e: Entity): string {.base.} = e.nombre
method etiqueta(e: Enemy): string = e.nombre & " [" & e.descripcion & "]"
method etiqueta(p: Player): string = p.nombre & " (estudiante UAI)"

# Recibir dano respeta escudo (encapsulamiento) e ignorar (abstraccion).
method recibirDano(e: Entity; dmg: int): string {.base.} =
  if e.ignorarProximo:
    e.ignorarProximo = false
    return e.nombre & " IGNORA el golpe (Abstraccion)!"
  var d = dmg
  var bloqueado = 0
  if e.escudo > 0:
    bloqueado = min(e.escudo, d)
    e.escudo -= bloqueado
    d -= bloqueado
  e.vida = max(0, e.vida - d)        # el dano sobrante SIEMPRE pasa a la vida
  if bloqueado > 0:
    return e.nombre & " bloquea " & $bloqueado & " y recibe " & $d & " de dano"
  return e.nombre & " recibe " & $d & " de dano"

proc curar(e: Entity; cantidad: int) =
  e.vida = min(e.vidaMax, e.vida + cantidad)

# ----------------------------------------------------------------------------
#  [FUNCIONAL] Habilidades de Haskell como FUNCIONES PURAS.
#  Sin efectos secundarios: misma entrada -> misma salida (excepto donde el
#  diseno pide azar, que se inyecta explicitamente).
# ----------------------------------------------------------------------------

# Recursion: n golpes decrecientes, sumados recursivamente (funcion pura).
func danoRecursivo(n, golpe: int): int =
  if n <= 0: 0
  else: golpe + danoRecursivo(n - 1, golpe)

# Orden superior + foldl: pliega una lista de golpes en su total (puro).
func danoPlegado(golpes: seq[int]): int =
  foldl(golpes, a + b, 0)

# Funcion pura: transparencia referencial, resultado fijo y determinista.
func danoPuro(base: int): int = base * 2

# Lambda + orden superior: una funcion anonima aplicada dentro de un fold.
func danoLambda(semillas: seq[int]): int =
  let f = proc (x: int): int = x mod 5 + 2   # lambda  (\x -> x mod 5 + 2)
  foldl(semillas, a + f(b), 0)               # foldl de orden superior (puro)

# ----------------------------------------------------------------------------
#  Catalogo de habilidades. Cada lenguaje aporta un set tematico. [OOP/datos]
# ----------------------------------------------------------------------------
proc nuevaSkill(n, lang, desc: string; dano: int; ef: Efecto; col: Color): Skill =
  Skill(nombre: n, lenguaje: lang, descripcion: desc,
        danoBase: dano, efecto: ef, color: col)

proc skillsBase(): seq[Skill] =
  @[
    nuevaSkill("Variable", "Base", "Ataque generico de estudiante.", 6,
               efAtaque, CelesteUAI),
    nuevaSkill("Punto y Coma", "Base", "Cierra una sentencia: genera 8 de escudo.",
               0, efDefender, CelesteUAI)
  ]

proc skillsC(): seq[Skill] =
  @[
    nuevaSkill("Puntero", "C",
      "Referencia directa a memoria: golpe veloz e infalible de 8.", 8,
      efPuntero, RojoC),
    nuevaSkill("Tipos de Datos", "C",
      "Asigna un tipo al azar; el dano = bytes que ocupa en memoria.", 0,
      efTipos, RojoC),
    nuevaSkill("malloc()", "C",
      "Reserva memoria y te cura 14 HP (cuidado con el memory leak).", 0,
      efMalloc, RojoC),
    nuevaSkill("Segmentation Fault", "C",
      "Comportamiento indefinido: 50% 22 de dano, 50% te golpea a ti.", 0,
      efSegfault, RojoC)
  ]

proc skillsJava(): seq[Skill] =
  @[
    nuevaSkill("Herencia", "Java",
      "Hereda y reutiliza tu ultima habilidad usada.", 0,
      efHerencia, NaranjaJv),
    nuevaSkill("Polimorfismo", "Java",
      "Una misma llamada, multiples formas: dano aleatorio ponderado.", 0,
      efPolimorfismo, NaranjaJv),
    nuevaSkill("Encapsulamiento", "Java",
      "Alterna private/public: en private ganas escudo, al volver public atacas.",
      0, efEncapsulamiento, NaranjaJv),
    nuevaSkill("Abstraccion", "Java",
      "Abstraes el peligro: ignoras el proximo golpe recibido. Dano 5.", 5,
      efAbstraccion, NaranjaJv),
    nuevaSkill("Garbage Collector", "Java",
      "Recolecta basura: limpia tus penalizaciones y recuperas 12 HP.", 0,
      efGC, NaranjaJv)
  ]

proc skillsHaskell(): seq[Skill] =
  @[
    nuevaSkill("Recursividad", "Haskell",
      "Muchos golpes pequenos encadenados (caso base + paso recursivo).", 0,
      efRecursividad, MoradoHk),
    nuevaSkill("Lambda", "Haskell",
      "Funciones anonimas rapidas (\\x -> ...) mapeadas en rafaga.", 0,
      efLambda, MoradoHk),
    nuevaSkill("Shadowing", "Haskell",
      "Sombrea un valor: +10 de bono a tu PROXIMO ataque. Dano 4.", 4,
      efShadowing, MoradoHk),
    nuevaSkill("Funcion Pura", "Haskell",
      "Transparencia referencial: SIEMPRE exactamente 16 de dano.", 16,
      efPura, MoradoHk),
    nuevaSkill("Evaluacion Perezosa", "Haskell",
      "Crea un thunk: 0 ahora, pero +18 a tu siguiente ataque.", 0,
      efLazy, MoradoHk)
  ]

proc skillsProfesor(): seq[Skill] =
  @[
    nuevaSkill("Examen Sorpresa", "Profesor", "Golpe contundente de 16.", 16,
               efExamen, GrisProf),
    nuevaSkill("Recursion Infinita", "Profesor",
      "Stack overflow: el dano crece con cada repeticion.", 6,
      efRecursionInf, GrisProf),
    nuevaSkill("Deadline 23:59", "Profesor",
      "Atraviesa tu escudo: 14 de dano puro.", 14, efDeadline, GrisProf),
    nuevaSkill("Code Review", "Profesor",
      "Expone tus bugs: borra tus buffs/escudo y pega 10.", 10,
      efCodeReview, GrisProf),
    nuevaSkill("Pregunta Trampa", "Profesor", "Golpe rapido de 8.", 8,
               efTrampa, GrisProf)
  ]

proc skillsDeLenguaje(lang: string): seq[Skill] =
  case lang
  of "C": skillsC()
  of "Java": skillsJava()
  of "Haskell": skillsHaskell()
  else: @[]

# ----------------------------------------------------------------------------
#  RESOLUCION DE HABILIDADES DEL JUGADOR (mezcla imperativa + funcional)
# ----------------------------------------------------------------------------
proc usarSkillJugador(g: Game; s: Skill): seq[string] =
  result = @[]
  let p = g.player
  let e = g.enemigo
  let prev = p.ultimaSkill        # snapshot para Herencia
  var dmg = 0
  var esAtaque = true

  case s.efecto
  of efAtaque:
    dmg = s.danoBase
    result.add p.nombre & " ataca con Variable."
  of efDefender:
    p.escudo += 8
    esAtaque = false
    result.add "Punto y Coma: +8 de escudo (escudo = " & $p.escudo & ")."
  of efPuntero:
    dmg = 8
    result.add "Puntero: dereferencia veloz, 8 de dano garantizado."
  of efTipos:
    let tipos = @[("char", 1), ("short int", 2), ("int", 4),
                  ("float", 4), ("long int", 8), ("double", 8)]
    let t = sample(tipos)
    dmg = t[1] * 2
    result.add "Tipos de Datos: '" & t[0] & "' ocupa " & $t[1] &
               " bytes -> " & $dmg & " de dano."
  of efMalloc:
    esAtaque = false
    if rand(1..100) <= 80:
      p.curar(14)
      result.add "malloc(): reservas memoria y recuperas 14 HP."
    else:
      result.add "malloc(): MEMORY LEAK, la memoria se perdio (sin efecto)."
  of efSegfault:
    if rand(1..100) <= 50:
      dmg = 22
      result.add "SEGFAULT: acceso valido inesperado -> 22 de dano!"
    else:
      esAtaque = false
      let auto = p.recibirDano(6)
      result.add "SEGFAULT: comportamiento indefinido, te golpea a ti."
      result.add auto
  of efHerencia:
    if prev != nil and prev.efecto notin {efHerencia, efDefender}:
      dmg = max(prev.danoBase, 6)
      result.add "Herencia: reutilizas '" & prev.nombre & "' -> " & $dmg & "."
    else:
      dmg = 6
      result.add "Herencia: no hay metodo padre claro, dano base 6."
  of efPolimorfismo:
    let r = rand(1..100)
    if r <= 50: dmg = 6
    elif r <= 80: dmg = 12
    else: dmg = 18
    result.add "Polimorfismo: una llamada, muchas formas -> " & $dmg & "."
  of efEncapsulamiento:
    esAtaque = false
    if not p.modoPrivate:
      p.modoPrivate = true
      p.escudo += 14
      result.add "Encapsulamiento: campos en private, +14 de escudo."
    else:
      p.modoPrivate = false
      dmg = 12
      esAtaque = true
      result.add "Encapsulamiento: expones getters (public) -> 12 de dano."
  of efAbstraccion:
    p.ignorarProximo = true
    dmg = s.danoBase
    result.add "Abstraccion: ignoraras el proximo golpe. Dano 5."
  of efGC:
    esAtaque = false
    p.boostNext = 0
    p.lazyCargado = 0
    p.modoPrivate = false
    p.curar(12)
    result.add "Garbage Collector: limpias tu estado y recuperas 12 HP."
  of efRecursividad:
    dmg = danoRecursivo(5, 3)        # [FUNCIONAL] 3+3+3+3+3 = 15
    result.add "Recursividad: 5 golpes encadenados (3 c/u) -> " & $dmg & "."
  of efLambda:
    let semillas = @[rand(0..20), rand(0..20), rand(0..20)]
    dmg = danoLambda(semillas)       # [FUNCIONAL] map + fold
    result.add "Lambda: rafaga de (\\x -> x%5+2) -> " & $dmg & " de dano."
  of efShadowing:
    p.boostNext += 10
    dmg = s.danoBase
    result.add "Shadowing: sombreas el valor, +10 a tu proximo ataque."
  of efPura:
    dmg = danoPuro(8)                # [FUNCIONAL] determinista: siempre 16
    result.add "Funcion Pura: resultado constante y determinista -> 16."
  of efLazy:
    esAtaque = false
    p.lazyCargado += 18
    result.add "Evaluacion Perezosa: creas un thunk (+18 al siguiente golpe)."
  else:
    dmg = 6
    result.add p.nombre & " improvisa un ataque."

  # Consumo de bonos diferidos (Shadowing + Lazy) en el proximo ataque real.
  if esAtaque and dmg > 0:
    let bono = p.boostNext + p.lazyCargado
    if bono > 0:
      result.add "  (bono acumulado +" & $bono & ")"
      dmg += bono
      p.boostNext = 0
      p.lazyCargado = 0
    result.add e.recibirDano(dmg)

  p.ultimaSkill = s

# ----------------------------------------------------------------------------
#  RESOLUCION DE HABILIDADES DEL ENEMIGO (IA simple)
# ----------------------------------------------------------------------------
proc usarSkillEnemigo(g: Game; s: Skill): seq[string] =
  result = @[]
  let p = g.player
  let e = g.enemigo
  var dmg = 0
  result.add ">> " & e.nombre & " usa " & s.nombre & "."

  case s.efecto
  of efPuntero: dmg = 8
  of efTipos:
    let tam = sample(@[1, 2, 4, 4, 8, 8])
    dmg = tam * 2
  of efSegfault: dmg = (if rand(1..100) <= 50: 14 else: 6)
  of efPolimorfismo:
    let r = rand(1..100)
    dmg = (if r <= 50: 7 elif r <= 80: 12 else: 17)
  of efEncapsulamiento:
    # No apila escudo infinito: solo se protege si esta descubierto (tope 10).
    if e.escudo <= 0:
      e.escudo = 10
      result.add "   (se cubre con 10 de escudo)"
    dmg = 6
  of efHerencia:
    dmg = (if p.ultimaSkill != nil: max(p.ultimaSkill.danoBase, 7) else: 7)
    result.add "   (copia tu ultima tecnica)"
  of efRecursividad: dmg = danoRecursivo(4, 3)   # 12
  of efLambda: dmg = danoLambda(@[rand(0..20), rand(0..20)])
  of efPura: dmg = 14
  of efExamen: dmg = 16
  of efRecursionInf:
    e.contador += 1
    dmg = min(6 + 3 * e.contador, 16)   # crece pero con tope (sin one-shot)
    result.add "   (profundidad " & $e.contador & ", el stack crece!)"
  of efDeadline:
    # Atraviesa el escudo (dano puro), pero respeta Abstraccion.
    if p.ignorarProximo:
      p.ignorarProximo = false
      result.add "   pero lo ignoras con Abstraccion!"
    else:
      p.vida = max(0, p.vida - 14)
      result.add "   Deadline ignora tu escudo: -14 HP."
    return
  of efCodeReview:
    p.escudo = 0
    p.boostNext = 0
    p.lazyCargado = 0
    dmg = 10
    result.add "   (borra tus buffs y escudo)"
  of efTrampa: dmg = 8
  else: dmg = 6

  if dmg > 0:
    result.add "   " & p.recibirDano(dmg)

# ----------------------------------------------------------------------------
#  CONSTRUCCION DEL MUNDO
# ----------------------------------------------------------------------------
proc crearEnemigos(): seq[Enemy] =
  result = @[]
  result.add Enemy(
    nombre: "C", descripcion: "el lenguaje de sistemas", recompensa: "C",
    vidaMax: 42, vida: 42, pelo: rgb(120, 30, 30), camisa: RojoC,
    skills: @[skillsC()[0], skillsC()[1], skillsC()[3]])
  result.add Enemy(
    nombre: "Java", descripcion: "la maquina virtual", recompensa: "Java",
    vidaMax: 55, vida: 55, pelo: rgb(150, 90, 20), camisa: NaranjaJv,
    skills: @[skillsJava()[1], skillsJava()[2], skillsJava()[0]])
  result.add Enemy(
    nombre: "Haskell", descripcion: "puro y perezoso", recompensa: "Haskell",
    vidaMax: 70, vida: 70, pelo: rgb(90, 40, 130), camisa: MoradoHk,
    skills: @[skillsHaskell()[0], skillsHaskell()[1], skillsHaskell()[3]])
  result.add Enemy(
    nombre: "Prof. Matias Greco", descripcion: "jefe final del curso",
    recompensa: "", vidaMax: 115, vida: 115,
    pelo: rgb(60, 50, 50), camisa: GrisProf, skills: skillsProfesor())

proc crearNiveles(): seq[Nivel] =
  @[
    Nivel(nombre: "Entrada de la UAI - Penalolen", fondo: rgb(120, 190, 240),
      tieneJefe: false, jefeIdx: -1, intro: @[
        "Primer dia de Lenguajes y Paradigmas.",
        "Cruzas el hall de la UAI con tu mochila...",
        "...y los lenguajes del curso cobran vida.",
        "Avanza a la derecha para comenzar tu camino."]),
    Nivel(nombre: "Laboratorio de Sistemas", fondo: rgb(60, 70, 90),
      tieneJefe: true, jefeIdx: 0, intro: @[
        "LABORATORIO 1: te espera C.",
        "Rapido, cercano al metal y sin red de seguridad.",
        "Un puntero mal usado y es segfault asegurado."]),
    Nivel(nombre: "Sala de Objetos", fondo: rgb(70, 60, 50),
      tieneJefe: true, jefeIdx: 1, intro: @[
        "SALA 2: aparece Java.",
        "Todo es un objeto y todo lleva ceremonia.",
        "Cuidado con su escudo encapsulado."]),
    Nivel(nombre: "Aula Funcional", fondo: rgb(45, 35, 60),
      tieneJefe: true, jefeIdx: 2, intro: @[
        "AULA 3: surge Haskell.",
        "Puro, perezoso y profundamente recursivo.",
        "Sin efectos secundarios... salvo los suyos."]),
    Nivel(nombre: "Oficina del Profesor", fondo: rgb(30, 30, 45),
      tieneJefe: true, jefeIdx: 3, intro: @[
        "OFICINA FINAL: el Prof. Matias Greco.",
        "Domina todos los paradigmas a la vez.",
        "Usa TODO tu arsenal. El semestre depende de esto."])
  ]

proc nuevoJugador(nombre: string; gen: Genero): Player =
  Player(nombre: nombre, genero: gen, vidaMax: 60, vida: 60,
         skills: skillsBase(), x: 80, y: PisoY.float - 66, modoPrivate: false)

proc iniciarJuego(g: Game) =
  g.player = nuevoJugador(g.nombreTmp, Genero(g.generoSel))
  g.enemigos = crearEnemigos()
  g.niveles = crearNiveles()
  g.nivelActual = 0
  g.introLinea = 0
  g.nivelSel = 0
  g.estado = gsNivelSel

proc entrarNivel(g: Game) =
  g.player.x = 80
  g.player.y = PisoY.float - 66
  g.player.vx = 0
  g.player.vy = 0
  g.introLinea = 0
  g.estado = gsIntro

proc iniciarBatalla(g: Game; idx: int) =
  g.enemigo = g.enemigos[idx]
  g.enemigo.vida = g.enemigo.vidaMax
  g.enemigo.contador = 0
  # etiqueta() usa despacho dinamico (polimorfismo): elige la version de Enemy.
  g.bitacora = @[g.enemigo.etiqueta() & " bloquea el camino!", "Tu turno."]
  g.menuSel = 0
  g.turnoJugador = true
  g.msgTimer = 0
  g.estado = gsBatalla

proc agregar(g: Game; lineas: seq[string]) =
  for l in lineas: g.bitacora.add l
  while g.bitacora.len > 7: g.bitacora.delete(0)

# Otorga el arsenal del lenguaje derrotado (sin duplicar). [FUNCIONAL: filter]
proc otorgarArsenal(g: Game; lang: string) =
  if lang.len == 0: return
  let nuevas = skillsDeLenguaje(lang)
  let existentes = g.player.skills.map(proc (s: Skill): string = s.nombre)
  for s in nuevas:
    if s.nombre notin existentes:
      g.player.skills.add s

# Empezar en un nivel elegido: otorga arsenales de los jefes previos y ajusta vida.
proc comenzarEnNivel(g: Game; idx: int) =
  g.nivelActual = idx
  for lvl in 1 ..< idx:
    let niv = g.niveles[lvl]
    if niv.tieneJefe:
      otorgarArsenal(g, g.enemigos[niv.jefeIdx].recompensa)
      g.player.vidaMax += 20
  g.player.vida = g.player.vidaMax
  entrarNivel(g)

# ----------------------------------------------------------------------------
#  ENTRADA: helper de teclas numericas
# ----------------------------------------------------------------------------
proc teclaNum(n: int): bool =
  case n
  of 1: isKeyPressed(One)
  of 2: isKeyPressed(Two)
  of 3: isKeyPressed(Three)
  of 4: isKeyPressed(Four)
  of 5: isKeyPressed(Five)
  of 6: isKeyPressed(Six)
  of 7: isKeyPressed(Seven)
  of 8: isKeyPressed(Eight)
  of 9: isKeyPressed(Nine)
  else: false

# ----------------------------------------------------------------------------
#  UPDATE por estado  [IMPERATIVO: maquina de estados]
# ----------------------------------------------------------------------------
proc updateMenu(g: Game) =
  if isKeyPressed(Enter) or isKeyPressed(Space):
    g.estado = gsCrear
    g.nombreTmp = ""
    g.generoSel = 0

proc updateCrear(g: Game) =
  # Entrada de texto: el nombre NO esta hardcodeado, lo escribe el usuario.
  var ch = getCharPressed().int
  while ch > 0:
    if ch >= 32 and ch <= 125 and g.nombreTmp.len < 14:
      g.nombreTmp.add(chr(ch))
    ch = getCharPressed().int
  if isKeyPressed(Backspace) and g.nombreTmp.len > 0:
    g.nombreTmp.setLen(g.nombreTmp.len - 1)
  if isKeyPressed(Left): g.generoSel = (g.generoSel + 2) mod 3
  if isKeyPressed(Right): g.generoSel = (g.generoSel + 1) mod 3
  if isKeyPressed(Enter) and g.nombreTmp.strip().len > 0:
    g.nombreTmp = g.nombreTmp.strip()
    iniciarJuego(g)

proc updateNivelSel(g: Game) =
  let n = g.niveles.len
  if isKeyPressed(Up): g.nivelSel = (g.nivelSel + n - 1) mod n
  if isKeyPressed(Down): g.nivelSel = (g.nivelSel + 1) mod n
  if isKeyPressed(Enter) or isKeyPressed(Space):
    comenzarEnNivel(g, g.nivelSel)

proc updateIntro(g: Game) =
  if isKeyPressed(Enter) or isKeyPressed(Space):
    inc g.introLinea
    if g.introLinea >= g.niveles[g.nivelActual].intro.len:
      g.estado = gsExplorar

proc updateExplorar(g: Game; dt: float) =
  let p = g.player
  # Movimiento horizontal [IMPERATIVO + fisica]
  p.vx = 0
  if isKeyDown(Right) or isKeyDown(D): p.vx = VelMov
  if isKeyDown(Left) or isKeyDown(A): p.vx = -VelMov
  if (isKeyPressed(Space) or isKeyPressed(Up) or isKeyPressed(W)) and p.enSuelo:
    p.vy = FuerzaSalto
    p.enSuelo = false
  # Gravedad
  p.vy += Gravedad
  p.x += p.vx
  p.y += p.vy
  # Colision con el piso
  let pies = PisoY.float - 66
  if p.y >= pies:
    p.y = pies
    p.vy = 0
    p.enSuelo = true
  # Limites
  if p.x < 0: p.x = 0
  # Abrir codex
  if isKeyPressed(C):
    g.estadoPrevio = gsExplorar
    g.estado = gsCodex
  # Llegar al borde derecho -> jefe o siguiente nivel
  if p.x > AnchoPantalla - 70:
    let niv = g.niveles[g.nivelActual]
    if niv.tieneJefe:
      iniciarBatalla(g, niv.jefeIdx)
    else:
      inc g.nivelActual
      entrarNivel(g)

proc updateBatalla(g: Game; dt: float) =
  if g.enemigo.vida <= 0:
    g.estado = gsRecompensa
    return
  if g.player.vida <= 0:
    g.estado = gsDerrota
    return

  if g.turnoJugador:
    let n = g.player.skills.len
    if isKeyPressed(Up): g.menuSel = (g.menuSel + n - 1) mod n
    if isKeyPressed(Down): g.menuSel = (g.menuSel + 1) mod n
    var idx = -1
    for k in 1 .. min(9, n):
      if teclaNum(k): idx = k - 1
    if isKeyPressed(Enter) or isKeyPressed(Space): idx = g.menuSel
    if idx >= 0:
      g.agregar(usarSkillJugador(g, g.player.skills[idx]))
      if g.enemigo.vida <= 0:
        g.estado = gsRecompensa
        return
      g.turnoJugador = false
      g.msgTimer = 1.1
  else:
    g.msgTimer -= dt
    if g.msgTimer <= 0:
      let s = sample(g.enemigo.skills)
      g.agregar(usarSkillEnemigo(g, s))
      g.flashTimer = 0.18
      if g.player.vida <= 0:
        g.estado = gsDerrota
        return
      g.agregar(@["Tu turno."])
      g.turnoJugador = true

proc updateRecompensa(g: Game) =
  if isKeyPressed(Enter) or isKeyPressed(Space):
    let lang = g.enemigo.recompensa
    if g.enemigo.nombre.startsWith("Prof"):
      g.estado = gsVictoria
      return
    otorgarArsenal(g, lang)
    g.player.vidaMax += 20
    g.player.vida = g.player.vidaMax
    inc g.nivelActual
    if g.nivelActual >= g.niveles.len:
      g.estado = gsVictoria
    else:
      entrarNivel(g)

proc updateCodex(g: Game) =
  if isKeyPressed(C) or isKeyPressed(Enter) or isKeyPressed(Space):
    g.estado = g.estadoPrevio

proc updateFin(g: Game) =
  if isKeyPressed(Enter) or isKeyPressed(Space):
    g.estado = gsMenu

# ----------------------------------------------------------------------------
#  DIBUJO por estado
# ----------------------------------------------------------------------------
proc barraVida(x, y, w: int; vida, vidaMax: int; col: Color; etiq: string) =
  box(x, y, w, 18, rgb(40, 40, 40))
  let frac = (if vidaMax > 0: vida / vidaMax else: 0.0)
  box(x, y, int(w.float * frac), 18, col)
  boxLines(x, y, w, 18, CremaTxt)
  dtext(etiq & "  " & $vida & "/" & $vidaMax, x, y - 18, 16, CremaTxt)

proc fondoEstrellado(g: Game; base: Color) =
  clearBackground(base)
  # Patron de ladrillos retro en la parte superior
  var i = 0
  while i < AnchoPantalla:
    box(i, 0, 38, 20, rgb(base.r.int + 12, base.g.int + 12, base.b.int + 12))
    i += 42

proc drawMenu(g: Game) =
  clearBackground(NegroNES)
  for k in 0 ..< 40:
    let sx = (k * 97 + 13) mod AnchoPantalla
    let sy = (k * 53 + 7) mod 220
    box(sx, sy, 2, 2, rgb(180, 180, 220))
  dtextC("UAI QUEST", AnchoPantalla div 2, 110, 64, DoradoUAI)
  dtextC("El Camino del Estudiante", AnchoPantalla div 2, 185, 24, CelesteUAI)
  dtextC("Lenguajes y Paradigmas de la Programacion - UAI 2026",
         AnchoPantalla div 2, 250, 16, CremaTxt)
  if (int(g.parpadeo * 10) mod 10) < 6:
    dtextC("- Presiona ENTER para comenzar -", AnchoPantalla div 2, 330, 20,
           CremaTxt)
  dtextC("C = C    Java = Java    Haskell = Haskell    Jefe = Prof. M. Greco",
         AnchoPantalla div 2, 420, 14, GrisProf)

proc drawCrear(g: Game) =
  clearBackground(AzulUAI)
  dtextC("CREA TU ESTUDIANTE", AnchoPantalla div 2, 70, 32, DoradoUAI)
  dtext("Nombre (escribe con el teclado):", 180, 170, 18, CremaTxt)
  box(180, 200, 440, 44, rgb(20, 20, 30))
  boxLines(180, 200, 440, 44, CremaTxt)
  let cursor = (if (int(g.parpadeo * 2) mod 2) == 0: "_" else: " ")
  dtext(g.nombreTmp & cursor, 196, 210, 26, DoradoUAI)
  dtext("Genero (FLECHAS izq/der para cambiar):", 180, 280, 18, CremaTxt)
  let gens = ["Masculino", "Femenino", "No binario"]
  for i in 0 .. 2:
    let bx = 180 + i * 150
    let sel = (i == g.generoSel)
    box(bx, 310, 140, 38, (if sel: CelesteUAI else: rgb(20, 20, 30)))
    boxLines(bx, 310, 140, 38, CremaTxt)
    dtextC(gens[i], bx + 70, 320, 16, CremaTxt)
  dtextC("ENTER para iniciar tu aventura", AnchoPantalla div 2, 410, 20,
         DoradoUAI)

# Avatar del jugador segun su genero (sprite y colores distintos).
proc drawJugador(p: Player; ox, oy, px: int) =
  let piel = rgb(245, 210, 170)
  case p.genero
  of genMasc:
    drawSprite(HumCorto, ox, oy, px, rgb(70, 45, 25), piel, CelesteUAI, AzulUAI)
  of genFem:
    drawSprite(HumLargo, ox, oy, px, rgb(95, 50, 30), piel,
               rgb(210, 70, 140), rgb(120, 40, 90))
  of genOtro:
    drawSprite(HumCorto, ox, oy, px, rgb(40, 160, 150), piel,
               VerdePiso, rgb(40, 90, 60))

# Avatar del enemigo (el profesor lleva la veta de pelo blanco).
proc drawEnemigo(e: Enemy; ox, oy, px: int) =
  let piel = rgb(220, 200, 180)
  if e.nombre.startsWith("Prof"):
    drawSprite(HumProf, ox, oy, px, e.pelo, piel, e.camisa, NegroNES)
  else:
    drawSprite(HumCorto, ox, oy, px, e.pelo, piel, e.camisa, NegroNES)

proc drawNivelSel(g: Game) =
  clearBackground(AzulUAI)
  dtextC("SELECCIONA EL NIVEL", AnchoPantalla div 2, 40, 30, DoradoUAI)
  dtextC("Empezar mas adelante te da las habilidades de los jefes previos.",
         AnchoPantalla div 2, 80, 14, CremaTxt)
  for i in 0 ..< g.niveles.len:
    let y = 120 + i * 56
    let sel = (i == g.nivelSel)
    box(120, y, AnchoPantalla - 240, 48, (if sel: CelesteUAI else: rgb(20, 25, 45)))
    boxLines(120, y, AnchoPantalla - 240, 48, CremaTxt)
    dtext((if sel: "> " else: "  ") & "Mapa " & $(i + 1) & ": " & g.niveles[i].nombre,
          140, y + 8, 18, (if sel: NegroNES else: CremaTxt))
    let extra = (if g.niveles[i].tieneJefe: "Jefe en este mapa"
                 else: "Introduccion (sin jefe)")
    dtext(extra, 140, y + 28, 13, (if sel: NegroNES else: GrisProf))
  dtextC("FLECHAS para elegir  -  ENTER para comenzar",
         AnchoPantalla div 2, AltoPantalla - 28, 16, DoradoUAI)

proc drawEscenaExplorar(g: Game) =
  let niv = g.niveles[g.nivelActual]
  fondoEstrellado(g, niv.fondo)
  # Piso
  box(0, PisoY, AnchoPantalla, AltoPantalla - PisoY, VerdePiso)
  var i = 0
  while i < AnchoPantalla:
    box(i, PisoY, 30, 8, rgb(50, 110, 50))
    i += 34
  # Cartel del nivel
  dtextC(niv.nombre, AnchoPantalla div 2, 30, 22, DoradoUAI)
  # Meta a la derecha
  box(AnchoPantalla - 40, PisoY - 120, 8, 120, CremaTxt)
  box(AnchoPantalla - 40, PisoY - 120, 36, 24,
      (if niv.tieneJefe: RojoC else: DoradoUAI))
  dtext((if niv.tieneJefe: "JEFE" else: "->"), AnchoPantalla - 38,
        PisoY - 116, 14, NegroNES)
  # Jugador
  let p = g.player
  drawJugador(p, p.x.int, p.y.int, 6)
  # HUD
  barraVida(20, 40, 220, p.vida, p.vidaMax, rgb(220, 60, 60), p.nombre)
  dtext("Mover: FLECHAS / A-D    Saltar: ESPACIO    Habilidades: C",
        20, AltoPantalla - 26, 14, CremaTxt)

proc drawIntro(g: Game) =
  drawEscenaExplorar(g)
  box(60, 300, AnchoPantalla - 120, 130, rgb(10, 10, 20))
  boxLines(60, 300, AnchoPantalla - 120, 130, CremaTxt)
  let lineas = g.niveles[g.nivelActual].intro
  let hasta = min(g.introLinea, lineas.len - 1)
  for i in 0 .. hasta:
    dtext(lineas[i], 80, 320 + i * 26, 18, CremaTxt)
  dtext("[ENTER]", AnchoPantalla - 160, 400, 16, DoradoUAI)

proc drawBatalla(g: Game) =
  let niv = g.niveles[g.nivelActual]
  clearBackground(rgb(niv.fondo.r.int div 2, niv.fondo.g.int div 2,
                      niv.fondo.b.int div 2))
  box(0, 300, AnchoPantalla, 180, rgb(30, 25, 40))
  # Flash al recibir dano
  if g.flashTimer > 0:
    box(0, 0, AnchoPantalla, AltoPantalla, rgb(180, 40, 40))
  let e = g.enemigo
  let p = g.player
  # Enemigo (arriba derecha)
  drawEnemigo(e, 560, 70, 9)
  dtextC(e.nombre, 600, 60, 18, CremaTxt)
  barraVida(420, 250, 330, e.vida, e.vidaMax, e.camisa, e.nombre)
  # Jugador (abajo izquierda)
  drawJugador(p, 120, 230, 8)
  barraVida(40, 220, 300, p.vida, p.vidaMax, rgb(220, 60, 60), p.nombre)
  if p.escudo > 0:
    dtext("Escudo: " & $p.escudo, 40, 240, 14, CelesteUAI)
  # Bitacora
  box(360, 300, 420, 170, rgb(12, 12, 20))
  boxLines(360, 300, 420, 170, CremaTxt)
  for i in 0 ..< g.bitacora.len:
    dtext(g.bitacora[i], 372, 308 + i * 22, 14, CremaTxt)
  # Menu de habilidades
  box(20, 300, 320, 170, rgb(12, 12, 20))
  boxLines(20, 300, 320, 170, CremaTxt)
  dtext("HABILIDADES", 32, 306, 16, DoradoUAI)
  if g.turnoJugador:
    # Ventana con scroll: muestra hasta 8 habilidades centradas en la seleccion.
    const visibles = 8
    let n = g.player.skills.len
    var inicio = 0
    if n > visibles:
      inicio = max(0, min(g.menuSel - 3, n - visibles))
    for fila in 0 ..< min(visibles, n):
      let i = inicio + fila
      let s = g.player.skills[i]
      let y = 328 + fila * 17
      let sel = (i == g.menuSel)
      if sel: box(26, y - 2, 308, 17, rgb(40, 40, 70))
      dtext((if sel: "> " else: "  ") & $(i + 1) & ". " & s.nombre,
            32, y, 14, (if sel: DoradoUAI else: s.color))
    if inicio + visibles < n:
      dtext("  v mas...", 250, 328 + (visibles) * 17 - 17, 12, CremaTxt)
  else:
    dtext("Turno del enemigo...", 40, 360, 16, RojoC)
  # Descripcion de la habilidad seleccionada
  if g.turnoJugador and g.menuSel < g.player.skills.len:
    let s = g.player.skills[g.menuSel]
    dtextC(s.descripcion, AnchoPantalla div 2, 2, 13, CremaTxt)

proc drawRecompensa(g: Game) =
  clearBackground(rgb(20, 40, 25))
  let e = g.enemigo
  dtextC(e.nombre & " DERROTADO!", AnchoPantalla div 2, 90, 34, DoradoUAI)
  if e.recompensa.len > 0:
    dtextC("Absorbes el arsenal de " & e.recompensa & ":",
           AnchoPantalla div 2, 160, 20, CremaTxt)
    let nuevas = skillsDeLenguaje(e.recompensa)
    for i in 0 ..< nuevas.len:
      dtextC("+ " & nuevas[i].nombre & " : " & nuevas[i].descripcion,
             AnchoPantalla div 2, 200 + i * 26, 14, nuevas[i].color)
  dtextC("Tu vida maxima aumenta (+20).", AnchoPantalla div 2, 360, 16,
         CelesteUAI)
  dtextC("[ENTER para continuar]", AnchoPantalla div 2, 420, 18, DoradoUAI)

proc drawCodex(g: Game) =
  clearBackground(NegroNES)
  dtextC("CODEX DE HABILIDADES", AnchoPantalla div 2, 24, 26, DoradoUAI)
  for i in 0 ..< g.player.skills.len:
    let s = g.player.skills[i]
    let y = 70 + i * 30
    dtext($(i + 1) & ". " & s.nombre & " [" & s.lenguaje & "]", 40, y, 16,
          s.color)
    dtext(s.descripcion, 60, y + 14, 12, CremaTxt)
  dtextC("[C o ENTER para volver]", AnchoPantalla div 2, AltoPantalla - 30,
         16, DoradoUAI)

proc drawVictoria(g: Game) =
  clearBackground(AzulUAI)
  for k in 0 ..< 60:
    let sx = (k * 137 + 11) mod AnchoPantalla
    let sy = (k * 71 + 5) mod AltoPantalla
    box(sx, sy, 3, 3, DoradoUAI)
  dtextC("VICTORIA!", AnchoPantalla div 2, 120, 60, DoradoUAI)
  dtextC(g.player.nombre & " aprobo Lenguajes y Paradigmas.",
         AnchoPantalla div 2, 210, 22, CremaTxt)
  dtextC("Derrotaste a C, Java, Haskell y al Prof. Matias Greco",
         AnchoPantalla div 2, 250, 16, CremaTxt)
  dtextC("dominando los paradigmas imperativo, OOP y funcional.",
         AnchoPantalla div 2, 275, 16, CremaTxt)
  dtextC("[ENTER para volver al menu]", AnchoPantalla div 2, 380, 18,
         CelesteUAI)

proc drawDerrota(g: Game) =
  clearBackground(rgb(40, 10, 10))
  dtextC("GAME OVER", AnchoPantalla div 2, 150, 60, RojoC)
  dtextC("Reprobaste... pero hay recuperativo.", AnchoPantalla div 2, 240, 20,
         CremaTxt)
  dtextC("[ENTER para volver al menu]", AnchoPantalla div 2, 330, 18, CremaTxt)

# ----------------------------------------------------------------------------
#  MAIN  [IMPERATIVO: bucle principal del juego]
# ----------------------------------------------------------------------------
proc main() =
  randomize()
  initWindow(AnchoPantalla.int32, AltoPantalla.int32,
             "UAI Quest - Lenguajes y Paradigmas")
  setTargetFPS(60)

  let g = Game(estado: gsMenu, nombreTmp: "", generoSel: 0)

  while not windowShouldClose():
    let dt = getFrameTime().float
    g.parpadeo += dt
    if g.flashTimer > 0: g.flashTimer -= dt

    # ----- UPDATE -----
    case g.estado
    of gsMenu: updateMenu(g)
    of gsCrear: updateCrear(g)
    of gsNivelSel: updateNivelSel(g)
    of gsIntro: updateIntro(g)
    of gsExplorar: updateExplorar(g, dt)
    of gsBatalla: updateBatalla(g, dt)
    of gsRecompensa: updateRecompensa(g)
    of gsCodex: updateCodex(g)
    of gsVictoria, gsDerrota: updateFin(g)

    # ----- DRAW -----
    beginDrawing()
    case g.estado
    of gsMenu: drawMenu(g)
    of gsCrear: drawCrear(g)
    of gsNivelSel: drawNivelSel(g)
    of gsIntro: drawIntro(g)
    of gsExplorar: drawEscenaExplorar(g)
    of gsBatalla: drawBatalla(g)
    of gsRecompensa: drawRecompensa(g)
    of gsCodex: drawCodex(g)
    of gsVictoria: drawVictoria(g)
    of gsDerrota: drawDerrota(g)
    endDrawing()

  closeWindow()

when isMainModule:
  main()
