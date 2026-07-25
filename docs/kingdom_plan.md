# 🏘️ Rosemere — Kingdom Building Plan
> Author: Arena.ai Agent • 2026-07-24 • Status: **PROPOSAL — awaiting your pick for Phase 1**

---

## 1. Research: How Cult of the Lamb Makes 2D Look 3D

Primary-source findings (Massive Monster devs' own answers):

1. **2D art in a 3D world, writing to depth** — *"All the art is drawn in 2d, then we put it in a 3d world. The 2d Objects are also writing to depth so we are utilising quite a few 3D world techniques. Then we rotate them towards the camera."* (official dev answer, Steam forums)
2. **Characters billboarding** — sprites rotate toward the camera (Y-billboard), rendered with a **perspective camera**, giving parallax as the view moves.
3. **Static sprites tilted 30–45° backward** — characters/props lean back so you see their "top," faking volume (same family of trick as Enter the Gungeon / Don't Starve).
4. **Buildings are NOT billboards** — they stay world-fixed. The famous roof-depth trick: **multiple flat sprites stacked slightly behind each other** ("accordion effect") + perspective camera = convincing 3D roofs. Developer answer: *"it's just a bunch of sprite renderers in 3d space that are slightly tilted. Not a whole lot more to it than that!"*
5. **Spine rigged 2D animation** — mesh distortion for pseudo-3D (head turns, squash & stretch). Relevant for characters/props later, not walls.
6. **Bold art direction over tech** — thick consistent outlines, flat-ish colors with hand-painted shading, ambient occlusion baked into the base of objects, strong silhouettes. "All the art is hand drawn, minus a few shaders."

Sources: Steam forums dev answer (steamcommunity.com/app/1313140), r/Unity3D depth-trick thread w/ MMLorna + dev who "worked on this", r/gamedev CotL-style threads, ACMI interview.

---

## 2. Rosemere's Current State (verified in repo)

| System | Current setup | CotL match? |
|---|---|---|
| Player | `Sprite3D`, `billboard = 2` (Y-billboard), `shaded = true`, `alpha_cut = 2` (opaque pre-pass → **writes depth**) | ✅ This IS the CotL character setup |
| Camera | Perspective `Camera3D` on a pivot | ✅ CotL-style parallax already possible |
| Lighting | `DirectionalLight3D` w/ day/night golds+nights, `RimLight`, `WorldTint` | ✅ Strong — we can out-light CotL |
| World bounds | `-2700 … +2700` on X/Z; map 2752×1536 covers exactly this | Sync'd with new map |

**Technical note:** Godot's `Sprite3D` has **no normal-map slot**. Normal-mapped 2D-in-3D is done with `MeshInstance3D` + `QuadMesh` + `StandardMaterial3D` (albedo + normal texture, cull disabled, alpha_scissor on). This is our building pipeline.

---

## 3. The "Paper 2.5D" Building Pipeline (what we'll build)

### Scene template — `Building.tscn` (base for everything)
```
BuildingName (StaticBody3D)
├── Facade        (MeshInstance3D + QuadMesh)  ← front wall, windows, door. Tilted back ~35°
├── RoofA         (MeshInstance3D + QuadMesh)  ← roof lower, +Z offset, slightly steeper tilt
├── RoofB         (MeshInstance3D + QuadMesh)  ← roof upper/ridge, more offset  ← the "accordion"
├── (SidePlane)   (optional QuadMesh rotated 90°Y) ← gable wall for corner views
├── Collision     (CollisionShape3D — box footprint)
└── DoorArea      (Area3D → interact → future interiors)
```

### Material recipe (StandardMaterial3D per sprite)
- `albedo_texture` = hand-drawn art (PNG, transparent, darkened baked AO at base/contact)
- `normal_map` = **generated from the sprite** (Python: luminance→height→Sobel normals) so your existing day/night sun **rakes across timber frames and thatch ridges** — this is our realism edge over CotL's mostly-unlit sprites
- `transparency = alpha_scissor` (writes depth → correct shadows/sorting)
- `cull_mode = disabled` (visible from behind, cheap paranoia)
- `cast_shadow = on` — buildings must throw real shadows at golden hour
- `shading = per-pixel`, light through your existing `day_night_cycle.gd`

### Texel calibration (critical for hand-drawn coherence)
- Player painted density ≈ `pixel_size 0.01045`/px.
- **Buildings painted at same density**: 1 art pixel ≈ 0.0105 world units.
- ⇒ House facade 768 px wide ≈ 8 units wide; two-storey ≈ 5.5–7 units tall body + roof. Walls 4–5 units tall.

### Squash rules
- Characters keep Y-billboard (already correct).
- Buildings/props: world-fixed, tilted −30…−40° around X, layered.
- NEVER mix a billboarding building with a fixed one — the parallax must agree.

---

## 4. Art Direction — "Maximally Realistic Medieval" (dark-fantasy dial later)

Realism spec for houses (historically grounded peasant→burgher typology):
- **Structure**: ground-floor stone/rubble plinth; upper storey timber-frame (dark oak beams) with wattle-and-daub infill (warm off-white/grey plaster, smoke-stained near hearth gable).
- **Jettied upper floors** on burgher houses (overhangs street, casts those lovely shadows).
- **Roofs**: steep pitched 50–60°, thick layered thatch with visible straw strata, moss patches, sagging ridges; occasional wood-shingle or stone-slate for richer buildings.
- **Windows**: small, few, unglazed w/ wooden shutters + iron hinges; no symmetry.
- **Imperfections = realism**: crooked beams, patched plaster, worn dirt paths to doors, firewood stacks, hay, herb-drying poles, chickens. Hand-hewn, slightly uneven silhouette edges.
- **Palette**: timber umber, straw ochre, plaster bone, stone grey-blue, moss green accents. Muted, painterly — reads "real" under our golden-hour light.
- **Dark fantasy dial (later pass)**: elongated crooked gables, crow/skull totems, rusted iron braziers, withered topiary, cultish banners (fits your cult-ish naming scheme), sickly green window-glow at night.

---

## 5. Map-Grounded Town Layout (from kingdom_map_upscaled.png)

The drawn map **must** be matched 1:1 (it's the minimap!):
- **Walled city at world origin** (map center ≈ (0,0)): gothic cathedral quarter (west half of walls), keep/castle with twin spires (north-center), dense burgher houses, market square. Footprint on map ≈ 550×900 world units. Walls with drum towers, gate towers on E.
- **Two eastern roads** exit the city: NE fork → logging camp → hamlet at (~57% map x ≈ world +370, -700ish); SE fork → farms fields row, then village w/ church at (74% ≈ +1300, -600).
- **North road** → toward mountain pass (explains *North Road Bandit* spawn) — a north gate too.
- **West**: deep pine forests w/ **ruins** at (~22% x ≈ -1500, +250) — future dungeon. **South**: farms + another hamlet, gallows hill (dark fantasy flavor — it's literally drawn SW of the city), stone circle at (~53%, 89%).
- Lake + river NW flowing through city center-ish; river exits east w/ boats.

**Town interior proposal (Phase-by-phase)**:
```
   [N: mountain pass gate]
        Keep (N, twin spires)
                   plaza
   Cathedral (W) — Market Sq (C) — Gallows (SW, outside wall)
   Burgher rows (E of cathedral)   East Gate ×2 (NE/SE roads)
   Craft row (S): smithy, granary, stables
```

---

## 6. Recommended Build Order

| Phase | Deliverable | Why this order |
|---|---|---|
| **0** | This doc + scale constants locked (texel density, tilt angle, AoS) | Prevents 6 assets in 6 styles |
| **1** | **Pilot house**: one burgher house, full pipeline (art → normal map → stacked quads → shadows at 3 times of day) | Locks THE LOOK & THE PIPELINE on the riskiest asset before we mass-produce |
| **2** | **Outer walls + gatehouse kit** (4 straight segs, 1 corner tower, 1 drum tower, gate) | Your instinct — modular, fast, defines town silhouette on the minimap |
| **3** | House batch: 5–6 variants (hovel, byre, hall-house, jettied burgher, granary) filling layout | Fast once pipeline locked |
| **4** | Props & life: market stalls, well, carts, braziers, hay carts, signposts; villager paths | Makes it a *place* |
| **5** | Dark-fantasy pass (dial from §4) + night interiors glow | After realism base reads solid |

---

## 7. Open questions for you

## 8. PLACEMENT RULE (locked 2026-07-24, per owner)
Buildings snap to the map's own glyphs: houses go on the small rectangle-ish clusters inside the walls, NOT on landmarks (cathedral/"Massive Church", castle, gates, walls). First batch: 12 HouseBurgherA instances on residential glyphs (west row, south-of-cathedral strip, market/inner-ward rows, keep-ward). Glyph→world conversion: fx/2752*5400−2700, fy/1536*5400−2700.

### 8.1 Paper-building hard rules (learned the hard way)
- **NO YAW on buildings.** A tilted (−40° X) plane cannot be Y-rotated or the sprite shears on screen — instances must keep yaw = 0. Variety via: mirror (scale.x −1), uniform scale jitter, future art variants.
- Enterables (design rule): only **cathedral + palace** will be enterable → door interact swaps to a dedicated interior scene ("new screen", later phase). All other houses are decoration; dressing like market stalls/cafés may be added later.

### 8.2 Ground (done)
Warm slate retexture (`cobblestone_ground_warm.png`, desaturated/warmed global ops — seamless preserved), neutral albedo_color, anisotropic filtering.

### 8.3 Occlusion between camera and player — STENCIL X-RAY (shipped 2026-07-24, v2)
Problem: paper buildings hide the player behind them. After comparing the 4 industry solutions the owner chose the **stencil X-ray silhouette** (Pillars of Eternity style) over whole-building fading.

Shipped: `scripts/xray_overlay.gd` + `XRay/GhostMesh` nodes in `Player.tscn`. Sprite3D's material is auto-generated and can't hold stencil state, so a mirrored billboard QuadMesh with StandardMaterial3D carries Godot 4.5+'s built-in **STENCIL_MODE_XRAY** preset (pattern lifted from the PR #80710 author's demo): base material renders the knight and writes stencil where its pixels depth-fail (covered by a building); its `next_pass` ghost material (unshaded spirit tint, `no_depth_test`, stencil compare NOT_EQUAL) draws the silhouette only there. **Occluders need zero setup** — works against houses, future walls, anything. Per-frame sync of texture/region/flip/size/transform from the real Sprite3D; mirror nudged 0.03u toward camera.

Superseded (kept on shelf): `scripts/occlusion_fader.gd` (v1, raycast occluder-fade w/ alpha-hash) — detached from Player, retained for possible per-building ghosting of big structures (e.g. cathedral corner fade) if ever wanted.
Later: same overlay node on enemies/NPCs behind buildings; optional building-side stencil restriction; PoE-style alternate tints.

### 8.4 Player rim light / "aura" (shipped 2026-07-24)
Goal: Griffith-style luminous edge separating the knight from the ground. Fresnel rim needs curved normals a flat quad lacks, so all 14 player sheets got generated **beveled normal maps** (`art_v2/player_*_normal.png`, edge-dome pipeline). `mat_xray_base` (the X-ray mirror) has `rim_enabled`, `rim = 0.4`, `rim_tint = 0.3`, `normal_enabled`; `xray_overlay.gd` swaps the matching `<sheet>_normal.png` per frame alongside albedo (path convention, cached). Side effect: armor now reads sun direction per-pixel. Tune: `rim` (strength), `rim_tint` (0=white aura, 1=armor-colored), dome/strength constants in the generator.

### 8.5 HUD cohesion pass 1 (2026-07-24)
Desaturated UI crimson `Color(0.65, 0.2, 0.15)` → muted brick/oxblood `Color(0.522, 0.247, 0.212)` (luma-preserving ~38% desat, hue kept). Applied: HUD panel + time-card borders (`StyleBoxFlat_hud_panel`, `StyleBoxFlat_time_inner`), minimap inner ring, 4 compass letters. Deliberately untouched: HP bar red fill (function), player-dot red (wayfinding), boss-bar purple, gold text accents. Candidates for pass 2: compass ornament textures (modulate 0.8/0.85/0.9 could go warmer), gold → parchment-amber.
1. First build: **pilot house** (recommended) vs. **walls+gate** vs. **in-engine blockout** with placeholder boxes?
2. City gates: the map suggests 2 eastern gates + 1 northern — build all three now, or start with North gate (bandit road)?
3. Art generation: I generate hand-drawn-style sprites here (AI) → Python derives normal maps. OK, or will you paint/commission final art and I use placeholders for now?
