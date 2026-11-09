# Juegos de Roblox

- **Caza Monedas** (este archivo): juego sencillo de recoger monedas.
- **[Planeta Criaturas](planeta/README.md)** (carpeta `planeta/`): planeta redondo con criaturas para montar, zonas y jefes.

---

# 🪙 Caza Monedas

Recoge monedas por el mapa, cómpralas en mejoras de **velocidad** y **salto**
y sube a las plataformas altas, donde solo salen **monedas doradas** (valen 5).
Tu progreso se guarda automáticamente.

## Qué incluye

| Archivo | Va en Roblox Studio en… | Tipo |
|---|---|---|
| `src/shared/Config.luau` | `ReplicatedStorage › Shared › Config` | ModuleScript |
| `src/server/GameManager.server.luau` | `ServerScriptService › GameManager` | Script |
| `src/client/HUD.client.luau` | `StarterPlayer › StarterPlayerScripts › HUD` | LocalScript |

- **Mapa automático**: si no existe una carpeta `Arena` en Workspace, el servidor
  crea el suelo, los muros invisibles, 14 plataformas de colores y el punto de aparición.
  Si construyes tu propio mapa, ponlo dentro de una carpeta llamada `Arena`
  y las monedas aparecerán sobre él.
- **Leaderboard** con la estadística `Monedas`.
- **Tienda** (botón 🛒 a la izquierda) con mejoras que suben de precio en cada nivel.
- **Guardado** con DataStore: al salir, cada 60 s y al cerrar el servidor.
- **Efectos**: las monedas giran y aparece un “+1” o “+5” al recogerlas.

## Cómo ponerlo en Roblox Studio

### Opción A: copiar y pegar (la más fácil)

1. Abre Roblox Studio y crea un juego nuevo con la plantilla **Baseplate**.
2. En **ReplicatedStorage**, crea una carpeta (`Folder`) llamada **`Shared`**.
   Dentro, crea un **ModuleScript** llamado **`Config`** y pega `src/shared/Config.luau`.
3. En **ServerScriptService**, crea un **Script** llamado `GameManager` y pega
   `src/server/GameManager.server.luau`.
4. En **StarterPlayer › StarterPlayerScripts**, crea un **LocalScript** llamado `HUD` y pega
   `src/client/HUD.client.luau`.
5. (Opcional) Borra la pieza `Baseplate` y la `SpawnLocation` originales; el juego crea las suyas.
6. Pulsa **Play** ▶️.

### Opción B: con Rojo (si programas en VS Code)

```bash
rojo serve
```

Luego, en Studio, conecta con el plugin de Rojo. El archivo `default.project.json`
ya coloca cada script en su sitio.

## Activar el guardado

Para que DataStore funcione en Studio:

1. Publica el juego (**File › Publish to Roblox**).
2. Ve a **Game Settings › Security** y activa **Enable Studio Access to API Services**.

Sin esto el juego funciona igual, pero no guarda el progreso
(verás un aviso en la ventana Output).

## Personalizar

Todo se ajusta en `Config.luau`: valor de las monedas, cuántas aparecen,
cada cuánto, el tamaño del mapa, el precio de las mejoras, etc.

Para añadir una mejora nueva:
1. Añádela a `Config.UPGRADES` y a `Config.UPGRADE_ORDER`.
2. Aplica su efecto en la función `applyUpgrades` de `GameManager.server.luau`.
3. Añade su campo a `DEFAULT_DATA` y a `saveData` para que se guarde.

## Ideas para seguir

- Sonidos al recoger monedas (`Sound` con un `SoundId` de la Toolbox).
- Lava o trampas que te devuelvan al inicio.
- Mascotas que recojan monedas solas.
- Un pase de juego (Game Pass) que duplique las monedas.
- Rondas con temporizador y premio para quien más recoja.
