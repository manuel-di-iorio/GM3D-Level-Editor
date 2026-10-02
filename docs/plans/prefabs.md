# Plan: prefab con default transform + scene negli included files

Stato: proposta — NON implementare finché non è fixato (lato runtime) il fatto che
le istanze non sono scrivibili. Questo documento raccoglie le decisioni prese in
discussione, pronto da eseguire dopo lo sblocco.

## 1. Motivazione (il "caso gatto")

Il modello `Cat.glb` in scena è sdraiato: l'orientamento grezzo del file. Oggi ogni drop
dalla libreria spawna l'orientamento grezzo e il raddrizzamento va rifatto a mano per
ogni istanza. Serve un default transform per asset, modificabile dal dev una volta sola.

## 2. Stato attuale (riferimenti)

- `gm3d_editor_asset_add(_name, _model, _thumb)` (`gm3d_ed_registry.gml:2`) salva solo
  `{ name, model }`: nessun default transform.
- Al drop (`gm3d_ed_input.gml:284`) chiama
  `__gm3d_ed_place(..., undefined, [1,1,1], ...)` (`gm3d_ed_registry.gml:349`): rotazione
  sempre `undefined`, quindi il nodo tiene l'orientamento del GLB. Stessa cosa nel
  preview (`gm3d_ed_core.gml:615`: solo `spawnInto` + scala 1).
- Ogni istanza serializza la rotazione **assoluta**
  (`__gm3d_ed_asset_desc`, `gm3d_ed_registry.gml:605`): il default applicato allo spawn
  resta congelato lì. Cambiare il default dopo NON si propaga da solo — vale anche
  riesportando il GLB.
- La tabella `_def` con rot/scale in `scr_demo.gml:51` vale solo per i nodi pre-piazzati
  della demo, non per la libreria.
- Proprietà dati già divisa: **libreria asset = del dev** (via funzione ogni sessione,
  mai persistita dall'editor; `gm3d_editor_asset_clear` svuota solo l'array),
  **istanze = dell'editor** (nodi + registry, salvati nello scene JSON). Svuotare la
  lista non cancella le istanze piazzate, ma al reload i nodi senza asset registrato
  vengono saltati (`gm3d_load.gml:76`, `failed++`).

## 3. Decisione centrale: modello Unity, adattato alla proprietà dev/editor

Si adotta la semantica Unity dei prefab — **eredita-finché-non-tocchi**:

- Il prefab (default sull'asset) è il template; l'istanza eredita pos/rot/scale finché il
  designer non le tocca.
- Il valore toccato diventa **override** (come il grassetto nell'Inspector Unity) e non
  segue più il prefab su quella proprietà.
- Editare il prefab si propaga a tutte le istanze senza override lì; comandi
  Apply (istanza → prefab) e Revert (prefab → istanza), anche per singola proprietà.
- Così il designer che ha ruotato un gatto a mano non se lo vede sovrascrivere quando
  il dev sistema il default.

## 4. Dove vivono i prefab: `__gm3dEditor/prefabs/<name>.prefab`

L'editor è incluso col gioco: i prefab modificati si salvano negli **included files**,
non in strutture solo-in-memoria:

- Path: `__gm3dEditor/prefabs/<name>.prefab` (un file per asset, `<name>` = nome asset).
- Regola di precedenza: il prefab salvato viene **caricato solo se il dev NON ha
  fornito l'asset originale** via `gm3d_editor_asset_add`; se la funzione è stata
  chiamata per quell'asset, il prefab su file viene **skippato** (la funzione vince).
- Contenuto proposto (JSON): `{ name, rotation: [x,y,z,w], scale: [x,y,z],
  position_offset?: [x,y,z] }` — solo default transform, mai mesh (la mesh resta del
  dev via funzione o GLB negli included files).
- Al drop e nel preview, `__gm3d_ed_place` e `__gm3d_ed_drop_preview_update` usano
  rot/scale dal prefab invece di `undefined`/`[1,1,1]` quando presente.

## 5. Scene in `__gm3dEditor/scenes/<name>.json` + dialog solo-nome

- Le scene salvate vanno in `__gm3dEditor/scenes/<name>.json` (included files).
- Questo richiede di rimpiazzare `get_save_filename` (`gm3d_ed_files.gml:4`) e
  `get_open_filename` (`gm3d_ed_files.gml:46`) con una finestrella di dialogo interna
  che chiede **solo il nome scena** (niente path: la cartella è fissa).
- Formato JSON scena invariato (`{ version, nodes }` con rotazioni assolute per nodo
  come oggi); la risoluzione default-vs-override avviene a load/drop, non nel file.

## 6. Override tracking (dettaglio implementativo, post-sblocco)

- La registry entry (`__gm3d_ed_kind_register`, `gm3d_ed_registry.gml:235`) guadagna un
  campo `over`: `{ pos: bool, rot: bool, scale: bool }`, default tutto `false`.
- Gizmo/inspector che scrivono pos/rot/scale marcano il flag corrispondente `true`.
- A load e a cambio prefab: per ogni proprietà NON flaggata, l'istanza eredita il
  valore corrente del prefab; le flaggate restano intatte.
- UI minima: voce "Revert to prefab" (per proprietà o per nodo) e "Apply to prefab"
  (promuove il transform dell'istanza a default dell'asset + salva il `.prefab`).
- Fallback esplicito (costa poco, utile subito): comando "riapplica default a tutte le
  istanze dell'asset" — solo rotazione, tenendo posizione/scala.

## 7. Cosa NON si fa (v1)

1. **Nessun nuovo dato persistito oltre `.prefab` e scene JSON.** Niente database,
   niente sidecar per-asset fuori dalle due cartelle fissate.
2. **Nessuna simulazione/anteprima del prefab nella libreria.** Il thumbnail resta
   quello attuale; il default si vede al drop/preview.
3. **Nessun merge a tre vie tra funzione/prefab/scena.** Precedenza rigida:
   funzione > `.prefab` > default grezzo del GLB. Niente UI di conflitto v1.
4. **Niente override su light/camera/environment.** Solo nodi asset mesh, come il
   resto dell'editing transform.

## 8. Fasi (dopo lo sblocco istanze-scrivibili)

1. Entry asset con `rot`/`scale` opzionali + uso in `__gm3d_ed_place` e preview
   (default statico, senza override tracking). DECISO: il dev NON passa
   rot/scale via codice — li modifica dall'Inspector cliccando il modello
   ("prefab") nel pannello Models. Click-seleziona vs trascina-spawna con la
   stessa soglia di movimento già usata per il drop (`drag_moved`).
2. Save/load `.prefab` in `__gm3dEditor/prefabs/` + regola skip-se-funzione.
   DECISO: nessun problema di round-trip — l'area di salvataggio è sempre la
   stessa (letture e scritture coincidono), quindi niente copia manuale.
3. Override tracking + Apply/Revert + comando "riapplica a esistenti".
   DECISO (semplificazione): singolo flag "customized" per istanza
   (tutto-o-niente) invece di flag per proprietà. Undo deve snapshotare
   anche il flag. Il comando "riapplica a esistenti" salta le istanze
   customized; per proteggerne solo alcune c'è un checkbox "protect" per
   istanza nell'Inspector, persistito nel descrittore di scena (accanto a
   `flags`), che esclude l'istanza dal reapply.
4. ✅ FATTO (2026-10-03): scene in `__gm3dEditor/scenes/` + dialog solo-nome
   (modale `_ed.scene_dlg`, rimpiazzo `get_open/save_filename` in
   `gm3d_ed_files.gml`). Sandbox ricomparsa: non serve più disabiltarla
   (`options_windows_disable_sandbox: false`, README/index aggiornati).

## 9. Questioni aperte

- Formato `.prefab`: JSON come le scene o formato dedicato? Proposto: JSON, stessa
  convenzione nomi-campo delle scene.
- `<name>` con caratteri non-file (spazi, unicode)? Sanitizzare o slug? Proposto: slug
  + mappa nome→file in memoria a runtime.
- Se il devRN rimuove un asset dalla funzione ma esiste il `.prefab`: il prefab da solo
  basta per lo spawn (serve anche il modello — da dove? included files obbligatorio?).
  Proposto: senza modello registrato via funzione, il prefab è inerte (skip con warning).
- Undo del cambio prefab: rientra nella history esistente o operazione separata?
