# Piano: gestione luci, camere ed environment dall'editor

> Stato: piano di lavoro, non ancora implementato (a parte `kind: "asset"`).
> Vincolo esplicito: **non cambiare `version`** del formato (resta `1` finché il formato non sarà usato da qualcuno).

## 0. Contesto e decisioni già prese

- Luci: **tutti i tipi disponibili in GM3D** — `GM3D_ELightType.Directional / Point / Spot` (cfr. `docs/GM3D.md:460-465`).
- Camere: **tutte le camere che il dev registra tramite una funzione `gm3d_editor_*`**, non la camera viewport attiva (`ed.rt.cam`). **Niente preview / look-through** in v1: solo disegno del frustum in scena.
- Environment: **incluso** (`GM3D_EnvironmentVolumeComponent`: size, ambient color, fog).
- Formato: per ora solo `kind: "asset"` aggiunto ai descrittori, `version` invariata. I file senza `kind` continuano a caricare come asset legacy.

## 1. Formato save/load (`scripts/gm3d_ed_serialize/gm3d_ed_serialize.gml`)

### 1.1 Fatto (questo commit)

- `__gm3d_ed_node_to_descriptor` scrive `kind: "asset"` (`gm3d_ed_serialize.gml:17-34`).
- `__gm3d_ed_validate_descs` accetta `kind` mancante (= legacy asset) oppure `kind == "asset"`; rifiuta altro.
- `__gm3d_ed_rebuild` tratta `kind` mancante come `"asset"` e lancia `unknown kind '...'` per il resto.
- `__gm3d_ed_save_scene` continua a scrivere `{ version: 1, nodes: [...] }`.
- Esempi aggiornati in `README.md` e `docs/index.html`.

### 1.2 Da fare (senza cambiare `version`)

Estendere gli stessi tre punti quando i kinds saranno implementati:

```json
{ "version": 1, "nodes": [
  { "kind": "asset", "asset": "Tree", "name": "Tree 2",
    "position": [1,0,2], "rotation": [0,0,0,1], "scale": [1,1,1] },
  { "kind": "light", "name": "Sun",
    "position": [0,0,0], "rotation": [0,0,0,1], "scale": [1,1,1],
    "light": { "type": "directional", "color": [255,255,255],
      "intensity": 1.0, "range": 0,
      "innerCone": 30.0, "outerCone": 45.0, "enabled": true } },
  { "kind": "camera", "name": "Cam1",
    "position": [0,2,5], "rotation": [0,0,0,1], "scale": [1,1,1],
    "camera": { "projection": "perspective",
      "fovY": 60.0, "orthoWidth": 10.0, "orthoHeight": 10.0,
      "near": 0.1, "far": 500.0, "enabled": true } },
  { "kind": "environment", "name": "Environment",
    "position": [0,0,0], "rotation": [0,0,0,1], "scale": [1,1,1],
    "environment": { "size": [20000,20000,20000], "ambient": [70,70,85],
      "fogEnabled": true, "fogColor": [192,192,192],
      "fogStart": 20.0, "fogEnd": 100.0, "enabled": true } }
]}
```

Regole:

- `kind` obbligatorio in scrittura, opzionale in lettura (mancante = `"asset"`).
- Colori `[r,g,b]` 0–255 (come `make_colour_rgb`); angoli (`innerCone`, `outerCone`, `fovY`) in **gradi** su disco, convertiti in radianti verso GM3D.
- Validazione separata per kind: `asset` richiede `asset: string` risolvibile in libreria; `light`/`camera`/`environment` richiedono la rispettiva sottostruct con tipi/range validi.
- `__gm3d_ed_rebuild`: switch su `kind` — `asset` via `spawnInto` come oggi; `light`/`camera`/`environment` via `scene.createNode + new GM3D_*Component + setter`.
- Step 0 preliminare: verificare i **getter** reali del runtime (`getType/getColor/getIntensity/getRange/getInnerConeAngle/getOuterConeAngle`, `getProjection/getFovY/getNear/getFar/getOrthoWidth/getOrthoHeight/...`, `getAmbientColor/getFog*`). Se un getter manca, quel campo diventa write-only e va tenuto in `ed.tracked`.
- `__gm3d_ed_history_*` (`scripts/gm3d_ed_history/gm3d_ed_history.gml`): nessuno cambio strutturale, lo snapshot è già il JSON; verificare che undo/redo ricostruisca anche i nuovi kinds.

## 2. Registrazione nodi e API dev (`scripts/gm3d_ed_registry/gm3d_ed_registry.gml` o nuovo `gm3d_ed_lights_cameras`)

- Nuove API pubbliche (nomi da confermare):
  - `gm3d_editor_light_add(_ed, _name, _node)`
  - `gm3d_editor_camera_add(_ed, _name, _node)`
  - `gm3d_editor_environment_set(_ed, _node)`
  - oppure `gm3d_editor_track_node` generalizzato con `kind` auto-rilevato da `getLightComponent() / getCameraComponent() / getEnvironmentVolumeComponent()`.
- `ed.tracked[]` guadagna il campo `kind` (oggi `{asset,name,label,pos}`); il matching esistente per `live name + nearest pos` va riusato invariato in v1.
- `demo_create` (`scripts/scr_demo/scr_demo.gml:24-48`): non hardcodare più `Sun / Environment / MainCamera` come nodi invisibili — crearli e registrarli con le API sopra, così appaiono subito in Scene e si salvano.
- La camera viewport (`ed.rt.cam`, pilotata da `scripts/gm3d_ed_camera/gm3d_ed_camera.gml`) **resta esclusa** da tracked/save/pick. Le camere editabili sono altri nodi. V1: nessun flag `active`; a editor chiuso il gioco continua a usare `ed.rt.cam`, le camere editabili sono solo dati che il gioco legge dal JSON con le stesse funzioni `apply_*_desc` usate dal rebuild.

## 3. Pannelli Models / Scene (`scripts/gm3d_ed_imgui/gm3d_ed_imgui.gml`)

- `Models` (`__gm3d_ed_imgui_assets`): invariato, solo libreria mesh da `gm3d_editor_asset_add`.
- `Scene` (`__gm3d_ed_imgui_scene_list`): da lista piatta mesh a lista con distinzione:
  - prefisso `[M] / [L] / [C] / [E]` + colore riga diverso per kind; label sempre rinominabile (`F2`, `__gm3d_ed_rename_*` esistenti).
  - filtro testo esistente + 4 toggle `M L C E` (o dropdown per kind).
  - context menu esistente `Focus / Rename / Duplicate / Delete` riusato per tutti i kinds; `Duplicate` per luci/camere = `createNode + clone componente + track`.
  - `Environment`: un solo nodo — voce `Create > Environment` disabilitata se già presente.
  - `__gm3d_ed_root_tracked` (`gm3d_ed_registry.gml:285-299`) deve includere i nuovi kinds; `__editor_grid` e `ed.rt.cam` restano esclusi.
- Menu `Create`: `Directional Light / Point Light / Spot Light / Perspective Camera / Ortho Camera / Environment` → `scene.createNode(nome fresco via __gm3d_ed_fresh_label) + addComponent + default sensati + track + select + history_commit`.
- `__gm3d_ed_new_scene` / delete (`scripts/gm3d_ed_scene_ops/gm3d_ed_scene_ops.gml`): oggi preservano luce/camera/ambiente perché non tracked; dopo il cambio diventano nodi tracked normali (cancellabili, resettabili).

## 4. Inspector (`__gm3d_ed_imgui_inspector`, `__gm3d_ed_imgui_axis_row`)

Sezioni condizionali sul kind del primo selezionato (se kinds misti: solo Transform):

- Sempre: `Position / Rotation / Scale` esistenti. Per `Directional` la posizione è irrilevante → hint "usa Rotation".
- `kind == "light"`: `Type` dropdown (directional/point/spot), `Color` picker, `Intensity` float, `Range` (solo point/spot), `Inner/Outer cone` in gradi (solo spot), `Enabled` checkbox.
- `kind == "camera"`: `Projection` dropdown (perspective/ortho), `FovY` (solo persp), `OrthoW/H` (solo ortho), `Near/Far`, `Enabled`. V1: niente `screenRect/order/alpha/target/renderSize` (servono solo per split-screen / render-to-texture).
- `kind == "environment"`: `Size XYZ`, `Ambient color`, `Fog enabled/color/start/end`.
- Ogni apply riusa il flusso esistente: `__gm3d_ed_inspector_apply + __gm3d_ed_rows_follow + history_commit + dirty=true`; riusare la logica `mixed` per multiselezione.

## 5. Disegno in scena, picking, gizmo

### 5.1 Cosa disegnare (obiettivo)

- Luci: icona billboard (diamante/cerchio, colore = colore luce) + `Directional`: freccia direzione da quaternion; `Point`: sfera/cerchio del `range`; `Spot`: cono da `outerCone + range` orientato come nodo.
- Camere: frustum wireframe dai suoi parametri (`fovY + aspect viewport` oppure `orthoW/H`, `near/far` clampato per disegno) + piccola icona corpo camera. Niente preview.
- Environment: box wire di `size` centrato sul nodo, tenue; solo se selezionato o con toggle `View > Show Environment`.

Tutto in `Draw_64` via `gm3d_editor_draw` (`objects/oEditor/Draw_64.gml`), usando `scripts/gm3d_ed_viewport/gm3d_ed_viewport.gml: world_to_screen`.

### 5.2 ⚠️ Nota sul limite di disegno (importante)

> Il disegno oggi disponibile è **2D in overlay** (`Draw GUI`), quindi i wireframe proiettati di luci/camere **coprirebbero gli altri oggetti** anche quando dovrebbero stare dietro: non c'è depth test contro la scena 3D. Quello che vogliamo è un **disegno 3D reale** (linee/box/coni con profondità), ma **non è possibile farlo in modo grezzo in GMRT: l'accesso WebGPU a basso livello non è disponibile**, quindi non possiamo emettere geometria debug direttamente nella scena. Finché GMRT non espone un'API debug-draw 3D, le opzioni sono: (a) overlay 2D accettandone l'overdraw, (b) mesh di debug spawnate nella scena vera (nodi transienti esclusi da save/pick come `__editor_grid`), (c) rimandare il disegno 3D. Da decidere prima di implementare §5.1.

### 5.3 Picking (`scripts/gm3d_ed_picking/gm3d_ed_picking.gml`, `__gm3d_ed_node_aabb`)

- `__gm3d_ed_node_aabb` oggi considera solo `getMeshes() + getSkinnedMeshComponent()` → luci/camere/env risultano `valid:false` e non sono mai selezionabili.
- Aggiungere fallback per nodi con componente luce/camera/env: hit test sull'icona a schermo (soglia ~12px, come il viewcube in `scripts/gm3d_ed_viewcube/gm3d_ed_viewcube.gml`) oppure AABB sintetico (cubo 0.5 m, o sfera `range` per le point). `pick_cycle` e `pick_rect` restano invariati nella logica.

### 5.4 Gizmo (`scripts/gm3d_ed_gizmo/gm3d_ed_gizmo.gml`)

- Riuso totale di Move/Rotate per luci e camere: in GM3D la direzione di una directional/spot e l'orientamento di una camera **sono** il quaternion del nodo.
- Scale gizmo: disabilitato per light/camera (per env la scala si edita da Inspector come `size`, non da gizmo).
- `range / coni / fov` in v1 solo numerici da Inspector, non maniglie 3D.

## 6. Runtime / shader

- `demo_assign_shaders` (`scr_demo.gml:117-135`): `sStatic`/`sAnimated` supportano `MAX_LIGHTS 8` ma **solo ramo directional+point**. Se si introduce lo spot editabile serve il ramo cono negli shader (direzione + falloff inner/outer), altrimenti in v1 gli spot vengono creati ma renderizzati come point.
- Viewport editor (`gm3d_ed_viewport.gml:5-58`): assume `perspective` (`GM3D_Matrix4.perspective`); per il disegno dei frustum ortho serve il ramo `ortho*`. La camera viewport resta perspective.
- Funzioni `apply_light_desc / apply_camera_desc / apply_env_desc` condivise tra rebuild editor e loader di gioco, così il gioco a runtime applica lo stesso JSON.

## 7. Ordine di implementazione proposto

1. Verifica getter GM3D (step 0 §1.2) + validazione per-kind (sempre `version: 1`).
2. API `light/camera/environment_add` + rifattorizzazione `demo_create` con nodi registrati.
3. `Create` da menu + Scene con icone/filtri + delete/duplicate/rename/focus per i nuovi kinds.
4. Inspector condizionale (§4).
5. Decisione disegno 2D-overlay vs mesh transienti vs rinvio (nota §5.2), poi icone/frustum/coni/range + picking fallback.
6. Abilitazione gizmo Move/Rotate (+ env box).
7. Ramo spot negli shader + verifica fog/ambient.
8. `datafiles/demo.json` di esempio con i 4 kinds + aggiornamento doc formato (`README.md`, `docs/index.html`).
