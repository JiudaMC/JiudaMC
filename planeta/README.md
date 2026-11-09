# 🌍 Planeta Criaturas (nombre provisional)

Un juego de Roblox en un **planeta redondo de verdad**. Domas criaturas, te subes
encima y, según su elemento y rareza, puedes explorar el **agua**, el **subsuelo** y el **cielo**.
Para entrar a las zonas especiales hay que derrotar a sus **guardianes**.

> ⚠️ Primera versión, todavía sin probar en Roblox Studio. La gravedad redonda es lo más
> delicado: si algo falla, copia los errores de la ventana **Output** y pásalos para arreglarlos.

## Cómo se juega

1. Empiezas en el polo norte con **30 🪙** y **3 🍬**.
2. **Doma criaturas** acercándote y manteniendo la tecla del aviso (*Domar*).
   Cuesta golosinas y puede fallar (las raras se escapan más).
3. Al domarla **te subes encima**. Cambia de criatura en el menú **🐾 Criaturas**.
4. **Excava tesoros** (montoncitos que brillan) para conseguir monedas y golosinas.
5. Compra cosas en la **🛒 Tienda**.
6. Derrota a los **guardianes** con el botón **⚔️ Atacar** (o clic izquierdo) para abrir zonas nuevas.

### Elementos y rareza

| Elemento | Qué te da | Común | Rara | Legendaria |
|---|---|---|---|---|
| 🌊 Agua | Aire bajo el mar y nado rápido | aire ×2.5 | aire ×6 | aire infinito |
| ⛰️ Tierra | Aire en el subsuelo, más velocidad y más tesoro al excavar | aire ×2.5 | aire ×6 | aire infinito |
| ☁️ Cielo | Volar (tecla **F** o botón **Volar**) | vuela bajito | llega al Templo | sin límite |

- **Comunes**: 1 elemento · **Raras**: 2 elementos · **Legendarias**: los 3.
- El oxígeno se gasta bajo el agua **y en el subsuelo**, y **más rápido entre más profundo**.

### Zonas y guardianes

| Zona | Dónde está | Guardián |
|---|---|---|
| Superficie | Continentes | — |
| Océano | Alrededor de los continentes | — |
| **Subsuelo** | Cueva que rodea el núcleo (pozo junto al inicio) | Guardián de Roca |
| **Fosa Abisal** | Hoyo en el fondo del mar | Guardián Abisal |
| **Templo Celeste** | Isla flotante con cúpula | Guardián Celeste |
| Islas del cielo | Flotando alrededor del planeta | — |

### Tienda

Golosinas · Pala de hierro (×2) · Pala de diamante (×4) · **Radar** (marca la criatura y el tesoro
más cercanos a través de paredes) · Tanques de oxígeno (×2 y ×3).

### Controles

| Acción | PC | Celular |
|---|---|---|
| Moverse | WASD | Joystick |
| Saltar / subir nadando o volando | Espacio | Botón saltar / ▲ |
| Bajar nadando o volando | Q o Ctrl | ▼ |
| Volar / dejar de volar | F | Botón Volar |
| Girar cámara | Clic derecho + mover | Deslizar el dedo |
| Zoom | Rueda del ratón | Pellizcar |
| Atacar jefe | Clic izquierdo | Botón Atacar |

## Archivos

| Archivo | En Roblox Studio | Tipo |
|---|---|---|
| `src/shared/Config.luau` | `ReplicatedStorage › Shared › Config` | ModuleScript |
| `src/shared/CreatureModel.luau` | `ReplicatedStorage › Shared › CreatureModel` | ModuleScript |
| `src/server/WorldBuilder.luau` | `ServerScriptService › Server › WorldBuilder` | ModuleScript |
| `src/server/Main.server.luau` | `ServerScriptService › Server › Main` | Script |
| `src/client/Gravedad.client.luau` | `StarterPlayer › StarterPlayerScripts › Gravedad` | LocalScript |
| `src/client/Interfaz.client.luau` | `StarterPlayer › StarterPlayerScripts › Interfaz` | LocalScript |

## Cómo meterlo en Roblox Studio

**Con Rojo** (recomendado): desde esta carpeta, `rojo serve` y conecta el plugin.

**Copiando y pegando**:
1. Crea un juego con la plantilla **Baseplate** (el script borra el suelo y crea el planeta).
2. En **ReplicatedStorage** crea una carpeta `Shared` con dos **ModuleScript**: `Config` y `CreatureModel`.
3. En **ServerScriptService** crea una carpeta `Server` con un **ModuleScript** `WorldBuilder` y un **Script** `Main`.
4. En **StarterPlayer › StarterPlayerScripts** crea dos **LocalScript**: `Gravedad` e `Interfaz`.
5. Pega el código de cada archivo (los nombres deben ser exactos).
6. Recomendado: en **Game Settings › Avatar** elige **R15**.
7. Pulsa **Play**. Al empezar, el servidor tarda unos segundos en crear el planeta.

Para guardar el progreso en Studio: publica el juego y activa
**Game Settings › Security › Enable Studio Access to API Services**.

## Personalizar

Casi todo está en `Config.luau`: tamaño del planeta, criaturas, dónde viven, rarezas,
aire, altura de vuelo, precios, jefes (vida, daño, recompensa), etc.
