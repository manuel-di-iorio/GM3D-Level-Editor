# Plan: supporto fisica nell'editor

Stato: proposta. Riferimenti API: `notes/GM3D_API.md` nel repo `GM3D-Samples` (branch
`develop`, tutto experimental). Esempi: `objSample_4_Physics`, `objSample_5_Vehicle`,
`objSample_6_FPS`, `scrSamplePhysicsSpawn`, `scrSampleVehicleSetup`.

## 1. Decisione centrale: mondo fisico OPT-IN per scena (default OFF)

Il mondo fisico **non** è sempre attivo. Si crea solo se la scena lo richiede, cioè se il
JSON contiene il blocco `world` (vedi §4). Senza blocco: nessun `GM3D_PhysicsWorld`,
nessun costo, comportamento identico a oggi.

Motivi:

- **Compatibilità**: le scene/JSON esistenti devono girare byte-identici a prima. Creare e
  steppare un mondo cambia l'ordine del loop (`scene.update → step → interpolateForRender`)
  e il timing — inaccettabile come default silenzioso.
- **Costo**: Jolt fa broadphase + stepping anche a vuoto (`maxBodies` default 512 nei
  sample). Su scene statiche è lavoro buttato.
- **Esplicito > implicito**: gravità, timestep e layer matrix sono scelte di progetto,
  vanno viste e versionate nel JSON, non nascoste in un default.
- **Unity fa così, a due livelli**: il mondo c'è sempre (`Physics.autoSimulation`,
  `Time.fixedDeltaTime`, gravità nei Project Settings), ma un GameObject entra in fisica
  solo con un componente Rigidbody/Collider. Noi replichiamo entrambi i livelli:
  (a) scena senza blocco `world` = fisica assente del tutto (equivalente a scena Unity
  senza alcun Rigidbody, ma senza nemmeno pagare il mondo); (b) con blocco `world`,
  ogni nodo entra in fisica solo col suo blocco `physics` (opt-in per corpo).

Conseguenza: l'editor mostra UI fisica solo quando serve (§3). Il loader standalone
`gm3d_load` crea il mondo solo se il JSON ha `world` e lo restituisce nel report
(`{ placed, failed, physics: true/false }`).

## 2. Cosa mostra l'editor

### 2a. Scena SENZA fisica (default): niente di nuovo

Nessuna icona, nessuna sezione, nessun overlay. L'unico punto di ingresso è esplicito:

- Menu o pulsante per abilitare la fisica sulla scena (`Create → Physics World` o toggle
  in una sezione scena). Crea il blocco `world` con default sample
  (`gravity [0,-9.81,0]`, `fixedTimeStep 1/60`, `maxSubSteps 4`, `maxBodies 512`,
  matrice layer tutta attiva, `debugDraw false`) e marca dirty.
- Disabilitare la fisica rimuove il blocco `world` (i blocchi `physics` per-nodo restano
  nel JSON ma inerti? NO — scelta: rimozione del mondo chiede se tenere i dati per-nodo
  come dormienti o eliminarli; default: tenerli, ignorati senza mondo).

### 2b. Scena CON fisica

**Scene Panel**

- Badge sul nodo: `D` verde (dynamic), `K` giallo (kinematic), `S` grigio (static),
  `T` ciano (sensor/trigger), capsula magenta per character. Solo testo/colore, niente
  sprite nuovi (riuso `__gm3d_ed_imgui_kind_icon` + suffisso).
- Filtro `Filters` esistente: si aggiunge voce `Physics` (mostra solo nodi con blocco
  `physics`)? Opzionale fase 2; intanto i badge bastano.

**Inspector** (pattern esistente: `CollapsingHeader` + `history_snap → apply → props_end`)

Principio: l'editor è **generico rispetto ai componenti**. Ogni nodo ha una lista
`Add Component` (`Rigidbody`, `Collider`, `Character`, e in futuro `Vehicle`,
`Constraint`, o qualunque tipo definito dal gioco); ogni componente disegna la sua
sezione. Tipi noti (body/shape/character) hanno drawer dedicati; per tutti gli altri
c'è un **drawer generico a reflection**: ogni campo dello struct viene renderizzato dal
suo tipo (`bool`→checkbox, numero→dragfloat, stringa→text, array di N numeri→N float,
riferimento a nodo→picker per label, lista→tabella righe). Così veicoli e constraint
funzionano senza una riga di UI dedicata: sono solo componenti con parametri.

Regole generali: sezioni fisica solo su nodi modello (asset con mesh — niente fisica su
light/camera/environment v1) e solo a selezione singola (stessa regola delle sezioni
Light/Camera; con multi-selezione restano nascoste, Transform resta multiplo). Body e
Character restano mutuamente esclusivi (radio `None / Rigidbody / Character`), con
`Add`/`Remove` che creano/cancellano il blocco.

Rigidbody (default tra parentesi, presi dai sample):

| Campo | Widget (helper esistenti) | Default | Note |
|---|---|---|---|
| Motion | Radio `Static/Kinematic/Dynamic` (come i radio luce) | `Static` — quasi tutto ciò che si piazza è statico nei sample; chi vuole cadute passa a Dynamic (e come in Unity cade) | |
| Mass (kg) | dragfloat | `1.0`, attivo solo se Dynamic | |
| Linear / Angular damping | dragfloat x2 | `0.0` | unitless |
| Gravity factor | dragfloat | `1.0` | moltiplicatore gravità mondo |
| Allow sleeping / Start awake | 2 checkbox | `true / true` | |
| Motion quality (CCD) | Radio `Discrete/LinearCast` | `Discrete` | anti-tunneling |
| Center of mass | 3 float | `0,0,0` | |
| Freeze position / rotation | 6 checkbox XYZ+XYZ → mask `EPhysicsAxisLock` | tutto off | |
| Layer | Radio verticale a scelta SINGOLA (5 voci) | `Default` | il runtime richiede un bit solo: mai mask/multi-selezione |
| Is sensor | checkbox | off | indipendente dal motion (coin=Static+sensor, ammo=Kinematic+sensor) |
| Group / SubGroup | 2 int, advanced collassata | `0 / 0` | esclusione fine, raro |

Collider[N] (lista con `+`/`-`, uno per shape component; header `Box 1`, `Sphere 2`…):

- **Box**: `Center` + `Size` (default `1,1,1`) + bottone **`Fit to mesh`** (adatta il box
  alla bbox della mesh, come i sample fanno per coni/ruote — la feature più utile).
- **Sphere**: `Center` + `Radius` (default `0.5`).
- **Capsule/Cylinder**: `Radius` + `HalfHeight` (default `0.5/0.5`).
- **Mesh/ConvexHull/ConvexDecomp**: niente size — etichetta fissa `from child meshes`
  (la geometria deriva dalle mesh figlie, i sample non chiamano mai `setHalfExtents`
  per questi tipi) + offset `Center/Rotation`.
- Sempre: `Friction` (default `0.5`), `Restitution` clamp `[0,1]` (default `0`),
  `Subshape layer` visibile solo con >1 collider.

Character (alternativa al body): `Radius 0.32, HalfHeight 0.9, StepHeight 0.35,
Slope 55°` (gradi in UI come la Rotation esistente), `Mass 80, MaxStrength 160` +
advanced (`PredictiveContactDistance 0.12, Padding, PenetrationRecovery, EdgeRemoval,
PushFlags`) — numeri pari pari dai due sample.

Sezione `Physics World` a livello scena (visibile a selezione vuota, dove oggi c'è
"No selection"): `gravity xyz`, `fixedTimeStep`, `maxSubSteps`, `maxBodies`, matrice
collisioni 5×5 (`Static/Default/Character/Trigger/Debris` via `setLayerCollision`),
`Debug draw` toggle (mappa su `setDebugDrawEnabled`, come `P` nei sample).

**Viewport** (estendere `__gm3d_ed_overlay_draw`, mai stepping in editor)

- Wireframe collider: box da `halfExtents*2` con `node world * localOffset/Rotation`
  (stessa tecnica del box env esistente); sfere/capsule come anelli billboard;
  mesh/hull = bbox arancione "derivato, non editabile".
- Colori per motionType come i badge; trigger ciano trasparente; toggle `Show colliders`.
- Picking esistente (`gm3d_ed_gpu_pick`): selezionare per collider quando il click non
  prende mesh (fase 2; v1 basta la selezione da Scene Panel).

### 2c. Cosa NON si fa (v1) — e perché

1. **Contact callback.** Sono closure GML registrate via `addContactCallback(fn, mask)` —
   l'editor non può autore codice né serializzare funzioni in JSON. L'editor fornisce i
   prerequisiti (`Is sensor` + layer `Trigger`); il wiring (5 righe come nei sample per
   coin/ammo) resta nel gioco. Alternativa scartata: dropdown "on trigger → nome
   funzione" — magia che si rompe al rename e mente su Stay/Exit (mai dimostrati).
   Implicazione pratica: un pickup = flag nell'editor + poche righe nel gioco.
2. **UI dedicata ai veicoli.** Non esisterà mai: ruote/powertrain/differenziali sono
   solo componenti con parametri e viaggiano sul drawer generico (fase 4) + node picker
   per i riferimenti (ruota FL/FR/…, `nodeB` dei constraint). Resta al gioco
   l'assemblaggio e la taratura — che comunque richiede guidare davvero (vedi punto 4).
3. **Constraint.** Mai esercitati nei sample (solo doc experimental): finché il gioco non
   li valida a runtime, l'editor li persiste come componenti generici senza prometterne
   la correttezza. Stesso meccanismo dei veicoli, nessuna UI dedicata.
4. **Simulazione live nell'editor.** Jolt scriverebbe i transform dei nodi: servirebbero
   snapshot/restore, loop separato e determinismo con l'undo. No stepping in editor;
   il debug resta quello runtime (`P` nel gioco). Un futuro "simulate" è esplicito e
   fuori fase. Di conseguenza l'overlay wireframe mostra la configurazione, mai lo
   stato simulato.
5. **Editing fisica multi-selezione.** Liste collider + radio esclusivi + default
   condizionali rendono il mixed-state ambiguo (cosa mostra `Collider[2]` di 3 nodi
   diversi?). Sezioni nascoste oltre il singolo, Transform resta multiplo. Rivalutabile
   con un "applica a tutti" esplicito, mai implicito.
6. **Fisica su luci/camere/environment.** Nicchia anche in Unity. Il trigger invisibile
   si fa come i sample: nodo asset con mesh + sensor (+ luce figlia per i coin).
7. **Mask multi-bit e CCD oltre LinearCast.** Il runtime vuole un bit solo per `setLayer`
   (la UI usa radio apposta); tuning Jolt profondo resta codice, non checkbox.

## 3. Modello dati

Registry (`_en.data.physics`, vedi `gm3d_ed_registry.gml`): i pattern `__gm3d_ed_*_defaults/read/apply`
esistono già per light/camera/env — si aggiungono
`__gm3d_ed_physics_defaults/read/apply` che costruiscono
`new GM3D_PhysicsBodyComponent/ShapeComponent`, chiamano i setter e fanno `addComponent`.
La fisica è un **blocco su nodi asset esistenti** (come `castShadows`), non un `kind` nuovo:
mute/restore/save/load per-kind restano invariati. Il blocco è una lista componenti
generica (`components: [{type, params}]`); body/collider/character sono tipi noti con
drawer dedicati, tutto il resto passa dal drawer generico senza codice dedicato.

JSON per-nodo (accanto a `position/rotation/scale`):

```json
"physics": {
  "body": { "motion": "dynamic", "mass": 2, "linDamp": 0.15, "angDamp": 0.35,
    "gravityFactor": 1, "sleeping": true, "awake": false, "quality": "discrete",
    "com": [0,0,0], "lockLin": [0,0,0], "lockAng": [0,0,0],
    "layer": "Default", "sensor": false },
  "colliders": [ { "shape": "box", "center": [0,0,0], "size": [1,1,1],
    "friction": 0.9, "restitution": 0 } ],
  "character": null
}
```

Header scena (oggi il JSON è solo `{version, nodes}`):

```json
{ "version": 1,
  "world": { "gravity": [0,-9.81,0], "fixedTimeStep": 0.0166, "maxSubSteps": 4,
    "maxBodies": 512, "debugDraw": false, "layerMatrix": { "Static": ["Static", "..."] } },
  "nodes": [ ... ] }
```

`world` assente = fisica OFF (vecchi JSON validi senza toccarli; validatore
`__gm3d_ed_is_physics_struct` solo su blocchi presenti). `character` e `body` mai
contemporaneamente (validazione in load + UI).

## 4. Runtime / lato gioco

- `gm3d_load` (`gm3d_ed_serialize.gml:597`): dopo i nodi, se `world` presente crea
  `new GM3D_PhysicsWorld(scene, cfg)`, applica gravità/layer matrix, registra
  (`addNode` per body+shape, `addCharacter` per character) dopo `scene.update(0)` +
  `syncScene()` — stesso ordine dei sample. Ritorna `physics` nel report.
- Loop di gioco (responsabilità del gioco, documentata in `docs/GM3D.md`):
  `scene.update(dt) → world.step(dt) → world.interpolateForRender()`,
  `world.destroy()` in cleanup. L'editor NON steppa mai (nessuna simulazione live v1;
  eventuale "simulate" è fase futura).
- Editor aperto: nodi con fisica si editano come gli altri (transform via gizmo =
  teletrasporto cinematico, coerente coi sample che muovono i kinematic per transform);
  undo/duplicate/delete/focus gratis dall'infrastruttura esistente (duplicate copia il
  blocco; validazione layer singolo e restitution nel load).

## 5. Validazioni (dal confronto API index)

Layer = singolo bit (mai mask); `restitution/friction ∈ [0,1]`; setter shape con range
`[0,5]` che escluderebbe `ConvexDecomposition=6` (discrepanza da verificare a runtime);
`setMaxSteerAngle<0`, `suspensionFrequency≤0`, inerzie `≤0` ignorati; character e body
mutuamente esclusivi; callback solo `Enter` nei sample (Stay/Exit non dimostrati).

## 6. Fasi

1. Persistenza JSON (`world` + `physics`) + Inspector Rigidbody/Collider + overlay wireframe.
2. Character controller (sezione + capsula magenta).
3. World-level (gravità, matrice layer, debug draw), trigger `Enter`, picking per collider.
4. Drawer generico a reflection + node picker: da qui veicoli, constraint e qualunque
   componente futuro funzionano senza UI dedicata (solo validazione strutturale in load,
   l'interpretazione resta al gioco).

## 7. Questioni aperte

- Blocco `world` rimosso: tenere i blocchi `physics` per-nodo dormienti (ignorati) o
  eliminarli? Default proposto: tenerli.
- `Fit to mesh`: bbox in spazio locale o world (con scala nodo applicata)? Proposto:
  locale + scala, come i sample.
