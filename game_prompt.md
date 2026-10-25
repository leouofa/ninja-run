# 🎮 Master 3D Game Builder: Reusable Autonomous Prompt Guide

> **A field-tested, production-grade prompt and architectural specification for creating complete, standalone 3D games in Godot 4.x with GDScript.**  
> Derived from the architecture of **Ninja Run**, featuring headless Blender 3D model generation, persistent high score saves, accessible pause menus, strict visual hierarchies, and a 100% headless automated verification test suite.

---

## 📋 Table of Contents

1. [How to Use This Prompt](#-how-to-use-this-prompt)
2. [Configurable Game Parameter Block](#-configurable-game-parameter-block)
3. [The Reusable Master Prompt](#-the-reusable-master-prompt)
4. [Architectural Invariants & Best Practices](#-architectural-invariants--best-practices)
   - [Autoload Singletons & State Management](#1-autoload-game-manager--persistence)
   - [Robust Pause Menu System](#2-robust-pause-system)
   - [Framerate-Independent Kinematics](#3-framerate-independent-kinematics)
   - [Threat vs. Reward Visual Hierarchy](#4-threat-vs-reward-visual-hierarchy)
5. [Procedural Asset Generation Blueprint (`tools/generate_assets.py`)](#-procedural-asset-generation-blueprint)
6. [Headless Automated Test Suite (`tools/test_game.gd`)](#-headless-automated-test-suite)
7. [Example Game Archetype Configurations](#-example-game-archetype-configurations)

---

## 🚀 How to Use This Prompt

When you want to create a new 3D game with an AI coding agent:
1. **Copy the [Configurable Game Parameter Block](#-configurable-game-parameter-block)** below.
2. Fill in your game's details (or pick one from [Example Archetypes](#-example-game-archetype-configurations)).
3. **Paste the filled parameter block directly above [The Reusable Master Prompt](#-the-reusable-master-prompt)** into your agent's chat.
4. Let the agent autonomously execute the 6-phase development plan and verify the game using the headless test runner!

---

## ⚙️ Configurable Game Parameter Block

```yaml
# ==============================================================================
# GAME SPECIFICATION INPUT
# ==============================================================================
GAME_TITLE: "Chrono Drift 3D"
GENRE_ARCHETYPE: "Endless Runner / Lane Switcher" # Options: Endless Runner, Arena Survival, 3D Platformer, Rail Shooter, Arcade Racer
CAMERA_PERSPECTIVE: "Third-Person Behind Runner (FOV 80-85, tilted downward 15 deg)"
TARGET_ENGINE: "Godot 4.3+ / 4.7+ (Forward+ / Mobile Renderer, Jolt 3D Physics)"

CORE_GAMEPLAY_LOOP: >
  The player controls a futuristic hovercraft accelerating across an infinite procedurally
  generated neon highway. Dodge obstacles (barricades, plasma walls), collect energy cells
  for speed boosts, destroy security drones with pulse lasers, and trigger bullet-time slowdowns
  when hazards become dense. The run ends when player health depletes.

KEY_MECHANICS:
  - Movement: 3 discrete lanes (-3.6m, 0.0m, +3.6m) with exponential smoothing kinematics
  - Actions: Left/Right lane shift, Jump/Hover (W / Up), Slide/Dodge (S / Down), Pulse Laser (Space / Left Click)
  - Time Dilation: Slow-motion mechanic that scales Engine.time_scale to 0.45 for 4 seconds
  - Progression: Dynamic speed scaling that increases difficulty every 30 seconds

SCORING_AND_HIGH_SCORES:
  - Distance: 10 points per meter traveled
  - Pickups: Energy Cells (+150 pts), Chrono Orbs (+300 pts)
  - Combat: Drones destroyed (+500 pts)
  - Combo Multiplier: Scales with consecutive successful dodges without taking damage
  - Persistence: Store high scores, total distance, max combo, and runs played in user://game_save.json

AUDIO_AND_VISUAL_THEME:
  - Aesthetic: Cyberpunk / Synthwave (Dark obsidian road, glowing neon lanes, wireframe mountains, low-poly sun)
  - Threat vs. Reward Hierarchy:
    - Threats (Enemies, Hazard Walls): Crimson red (#FF0033), Vermilion (#FF4500), dark obsidian cores, ground warning crosshairs
    - Rewards (Energy Cells, Time Orbs): Pure Solar Gold (#FFD700) and Electric Cyan (#00FFFF), floating hover tween, ground halo rings
  - Audio: Dynamic background synth tracks, low-pass filter on pause/slowmo, procedural UI hover/click sounds
# ==============================================================================
```

---

## 🤖 The Reusable Master Prompt

Copy and paste the text block below into your AI agent prompt:

````markdown
You are an expert 3D game developer and systems architect specializing in Godot Engine 4.x and GDScript.
Your objective is to autonomously build a fully functional, production-ready 3D game based on the GAME SPECIFICATION INPUT provided above.

You must follow an uncompromising 6-phase execution plan. Do not take shortcuts. Ensure all assets, singletons, UI components, and tests are implemented cleanly without unresolved dependencies or missing resources.

---

### Phase 1: Core Architecture, Singletons & Input Configuration
1. Create or configure `project.godot`:
   - Set viewport window size to 1280x720 (resizable, keep_aspect expand mode).
   - Register Autoload singletons: `GameManager` (`res://scripts/GameManager.gd`) and `SoundEffects` (`res://scripts/SoundEffects.gd`).
   - Register default InputMap actions: `move_left`, `move_right`, `jump`, `slide`, `primary_action`, `special_action`, and `pause` (`KEY_ESCAPE` and `KEY_P`).
2. Build `scripts/GameManager.gd`:
   - Must extend `Node` with `process_mode = Node.PROCESS_MODE_ALWAYS`.
   - Implement persistent JSON save/load to `user://game_save.json` tracking: `high_score`, `total_runs`, `max_combo`, `stats`, and `settings`.
   - Implement score update methods with differential checks (`is_new_high_score`, `score_diff`).
   - Dynamically configure audio buses ("Music", "SFX") with LowPassFilter and SpectrumAnalyzer effects.
   - Scan and connect all UI `Button` instances across the scene tree with standard hover/click sound effects and `CURSOR_POINTING_HAND`.
3. Build `scripts/SoundEffects.gd`:
   - Provide non-blocking audio playback using pooled `AudioStreamPlayer` nodes for both normal and paused game states.

---

### Phase 2: Procedural 3D Asset Pipeline (`tools/generate_assets.py`)
1. Create a standalone Python script `tools/generate_assets.py` using Blender's Python API (`bpy`).
2. The script must clear default scene elements, generate low-poly 3D models with appropriate PBR materials, and export them as `.glb` files into `assets/models/`:
   - Player character / vehicle model
   - 2-4 distinct enemy / hazard models
   - 2 distinct collectible / pickup models
   - 1-2 environment / landmark pieces
3. Execute the script via `blender -b -P tools/generate_assets.py` to produce all physical `.glb` files before assembling 3D scenes.

---

### Phase 3: Framerate-Independent Gameplay & Physics Loop
1. Build the player character (`scripts/Player.gd`, `scenes/Player.tscn`):
   - Use `CharacterBody3D` or deterministic kinematic interpolation.
   - Lateral movement must use exponential dampening `position.x = lerp(position.x, target_x, 1.0 - exp(-snapping_speed * delta))` to guarantee zero lane drift across 30, 60, 120, and 144 Hz.
   - Collision detection using appropriate Jolt 3D layers and masks (Player, Hazard, Pickup, Ground).
2. Build interactive entities (`Hazard.gd`, `Pickup.gd`, `Enemy.gd`):
   - Ensure pickups feature an idle floating tween and rotation animation.
   - Implement Area3D triggers that communicate cleanly with `GameManager`.
3. Assemble the main world scene (`scenes/GameWorld.tscn`, `scripts/GameWorld.gd`):
   - Setup `Camera3D` with smooth trailing or fixed-offset framing.
   - Setup `DirectionalLight3D` and `WorldEnvironment` with ACES tonemapping and subtle HDR bloom.
   - Setup procedural spawning / segment recycling so the game can run continuously.

---

### Phase 4: Full UI/HUD Suite, Pause System & High Score Persistence
1. Build `scenes/HUD.tscn` (`scripts/HUD.gd`):
   - Display real-time Score, Current Combo, Health/Shields, and Special Meter.
   - Add punchy tween scale animations on score increments and pickup grabs.
2. Build `scenes/PauseMenu.tscn` (`scripts/PauseMenu.gd`):
   - Set `process_mode = Node.PROCESS_MODE_ALWAYS`.
   - Intercept the `pause` input action cleanly.
   - When pausing:
     ```gdscript
     get_tree().paused = true
     if music_player:
         music_player.stream_paused = true
     resume_btn.grab_focus()
     ```
   - When unpausing:
     ```gdscript
     get_tree().paused = false
     if music_player:
         music_player.stream_paused = false
     ```
   - Provide **inline confirmation boxes** before "Restart" or "Exit to Main Menu" to prevent accidental data loss.
3. Build `scenes/MainMenu.tscn` (`scripts/MainMenu.gd`):
   - Start Game button, High Scores display modal, Settings (audio volume sliders), and Quit button.
   - Game Over screen displaying Final Score, Previous Best, New High Score banner, and Restart button.

---

### Phase 5: Shaders & Visual Hierarchy Pipeline
1. Strict Threat vs. Reward Color Palette:
   - Apply a dynamic entity shader or distinct PBR materials distinguishing threats (crimson red/orange cores, high-contrast Fresnel rim) from rewards (solar gold/emerald, electric cyan shimmer).
   - Add floor-projected decals or mesh rings (red crosshairs for threats, soft cyan/gold rings for pickups) ensuring high readability in 3D perspective.
2. Screen-Space PostFX / Atmosphere:
   - Provide a `CanvasLayer` post-processing shader or atmospheric fog (vignette, speed lines, or audio/combo reactive ripple).

---

### Phase 6: Automated Headless Test Suite (`tools/test_game.gd`)
1. Create `tools/test_game.gd` extending `SceneTree` or `MainLoop`.
2. Implement automated assertions validating the entire game headless:
   - All `.tscn` scenes load and instantiate without script errors.
   - Input actions exist and have valid key bindings.
   - `GameManager` save and load round-trips correctly in `user://`.
   - High score comparison logic triggers properly on personal bests.
   - Player lateral movement arrives within 0.01m of target across simulated 30, 60, and 144 FPS delta steps.
   - Pause menu toggles `get_tree().paused` state and recovers safely.
3. Run `godot --headless -s tools/test_game.gd` and ensure 100% of tests pass before finishing!
````

---

## 🏛 Architectural Invariants & Best Practices

When building 3D games in Godot 4, enforce these exact architectural rules:

### 1. Autoload Game Manager & Persistence

```gdscript
# scripts/GameManager.gd
extends Node

signal score_changed(new_score: int)
signal game_over(final_score: int, is_new_record: bool)

const SAVE_PATH = "user://game_save.json"

var save_data: Dictionary = {
    "high_score": 0,
    "max_combo": 1,
    "total_runs": 0,
    "audio_volume": {"master": 1.0, "music": 0.8, "sfx": 0.9}
}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _load_save()

func record_run_score(score: int, combo: int = 1) -> Dictionary:
    var prev = save_data.get("high_score", 0)
    var is_new_record = score > prev
    if is_new_record:
        save_data["high_score"] = score
    save_data["max_combo"] = max(save_data.get("max_combo", 1), combo)
    save_data["total_runs"] = save_data.get("total_runs", 0) + 1
    _save_to_disk()
    return {
        "is_new_high_score": is_new_record,
        "prev_high_score": prev,
        "score_diff": score - prev,
        "high_score": save_data["high_score"]
    }

func _save_to_disk() -> void:
    var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(save_data))

func _load_save() -> void:
    if FileAccess.file_exists(SAVE_PATH):
        var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
        if file:
            var json = JSON.new()
            if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
                for k in json.data.keys():
                    save_data[k] = json.data[k]
```

---

### 2. Robust Pause System

Key principles:
- The `PauseMenu` control root **must** have `process_mode = Node.PROCESS_MODE_ALWAYS`.
- Always pause audio stream players synchronously with `get_tree().paused = true` so music doesn't desync from gameplay state.
- Always call `resume_btn.grab_focus()` upon opening to guarantee keyboard and gamepad navigation.
- Implement inline confirmation dialogs for destructive actions ("Restart Level" / "Main Menu").

```gdscript
# scripts/PauseMenu.gd
extends Control

@onready var resume_btn: Button = $Panel/VBox/ResumeBtn
@onready var restart_btn: Button = $Panel/VBox/RestartBtn
@onready var confirm_box: VBoxContainer = $Panel/ConfirmBox

var music_player: AudioStreamPlayer

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    visible = false
    confirm_box.visible = false

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("pause") and not event.is_echo():
        get_viewport().set_input_as_handled()
        if visible:
            resume_game()
        else:
            pause_game()

func pause_game() -> void:
    get_tree().paused = true
    if music_player:
        music_player.stream_paused = true
    visible = true
    confirm_box.visible = false
    resume_btn.grab_focus()

func resume_game() -> void:
    get_tree().paused = false
    if music_player:
        music_player.stream_paused = false
    visible = false
```

---

### 3. Framerate-Independent Kinematics

Never use linear additions or Euler decays like `velocity.x *= 0.85` for lane switching or position lerping, because they drift significantly between 30 and 144 FPS. Use exact continuous exponential decay:

```gdscript
# Framerate-independent exponential smoothing
func _physics_process(delta: float) -> void:
    # Lambda value of 18.0 gives instant, crisp responsiveness
    position.x = lerp(position.x, target_lane_x, 1.0 - exp(-18.0 * delta))
```

---

### 4. Threat vs. Reward Visual Hierarchy

In fast 3D action games, players make decisions in 100 milliseconds. Keep the visual language clear:

| Entity Type | Base Color Palette | Rim / Highlight | Ground Projection | Behavior |
|:---|:---|:---|:---|:---|
| **Threats / Hazards** | Crimson (`#FF0033`), Dark Obsidian | Strong Red Fresnel Rim | Red X / Hazard Box | Damage on contact |
| **Pickups / Rewards** | Pure Gold (`#FFD700`), Neon Cyan | Soft White Iridescence | Smooth Glowing Ring | Collect on overlap |
| **Player** | White / Vibrant Neutral | Electric Cyan Accent | Drop Shadow / Foot Ring | Active controller |

---

## 🛠 Procedural Asset Generation Blueprint

Save this script as `tools/generate_assets.py` to produce low-poly `.glb` models headlessly via Blender:

```python
"""
tools/generate_assets.py
Headless 3D Asset Generator for Godot 4
Run via: blender -b -P tools/generate_assets.py
"""
import bpy
import os

OUTPUT_DIR = os.path.abspath("assets/models")
os.makedirs(OUTPUT_DIR, exist_ok=True)

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def make_material(name, diffuse_color, roughness=0.4, metallic=0.1, emission=(0, 0, 0, 1)):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = diffuse_color
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = emission
    return mat

def export_glb(filename):
    out_path = os.path.join(OUTPUT_DIR, filename)
    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format='GLB',
        use_selection=False,
        export_apply=True
    )
    print(f"[EXPORTED] {out_path}")

# Example 1: Player Ship
clear_scene()
bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.8, depth=2.4)
ship = bpy.context.active_object
ship.rotation_euler = (1.5708, 0, 0)
mat_hull = make_material("Hull", (0.1, 0.1, 0.15, 1.0), roughness=0.2, metallic=0.8)
ship.data.materials.append(mat_hull)
export_glb("player_ship.glb")

# Example 2: Hazard Barricade
clear_scene()
bpy.ops.mesh.primitive_cube_add(size=1.0)
hazard = bpy.context.active_object
hazard.scale = (2.4, 0.8, 0.4)
mat_hazard = make_material("Hazard", (0.9, 0.05, 0.05, 1.0), roughness=0.5, emission=(0.8, 0.0, 0.0, 1.0))
hazard.data.materials.append(mat_hazard)
export_glb("obstacle_barricade.glb")

# Example 3: Pickup Energy Core
clear_scene()
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.5)
pickup = bpy.context.active_object
mat_pickup = make_material("EnergyCore", (1.0, 0.8, 0.0, 1.0), roughness=0.1, emission=(1.0, 0.7, 0.0, 1.0))
pickup.data.materials.append(mat_pickup)
export_glb("pickup_energy.glb")

print("All 3D assets generated successfully!")
```

---

## 🧪 Headless Automated Test Suite

Save this script as `tools/test_game.gd`. It tests all engine systems without opening a window:

```gdscript
# tools/test_game.gd
extends SceneTree

func _init() -> void:
    print("\n=== RUNNING AUTOMATED GAME ENGINE TESTS ===")
    var passes = 0
    var failures = 0

    # 1. Verify Scenes Load Cleanly
    var scenes_to_check = [
        "res://scenes/MainMenu.tscn",
        "res://scenes/GameWorld.tscn"
    ]
    for scn_path in scenes_to_check:
        if ResourceLoader.exists(scn_path):
            var res = load(scn_path)
            if res is PackedScene:
                var inst = res.instantiate()
                assert(inst != null, "Scene failed to instantiate: %s" % scn_path)
                inst.free()
                print("[PASS] Scene loads cleanly: %s" % scn_path)
                passes += 1
            else:
                printerr("[FAIL] Resource is not a PackedScene: %s" % scn_path)
                failures += 1
        else:
            printerr("[FAIL] Scene not found: %s" % scn_path)
            failures += 1

    # 2. Verify InputMap Actions
    var required_inputs = ["move_left", "move_right", "jump", "pause"]
    for act in required_inputs:
        if InputMap.has_action(act) and not InputMap.action_get_events(act).is_empty():
            print("[PASS] InputAction registered with events: %s" % act)
            passes += 1
        else:
            printerr("[FAIL] InputAction missing or unmapped: %s" % act)
            failures += 1

    # 3. Verify High Score Logic & Persistence
    var gm = Node.new()
    gm.set_script(load("res://scripts/GameManager.gd"))
    root.add_child(gm)
    
    var res_record = gm.record_run_score(1500, 4)
    if res_record.get("is_new_high_score") == true and gm.save_data.get("high_score") >= 1500:
        print("[PASS] High score calculation and persistence verified.")
        passes += 1
    else:
        printerr("[FAIL] High score calculation failed.")
        failures += 1
    gm.free()

    # 4. Verify Framerate-Independent Lane Math
    var start_x = 0.0
    var target_x = 3.6
    var x = start_x
    for f in range(60): # 1 second at 60 FPS
        x = lerp(x, target_x, 1.0 - exp(-18.0 * (1.0 / 60.0)))
    if abs(x - target_x) < 0.01:
        print("[PASS] Kinematic exponential lane snapping converges within 0.01m.")
        passes += 1
    else:
        printerr("[FAIL] Kinematic lane switch did not converge accurately.")
        failures += 1

    print("\n=== TEST SUMMARY: %d PASSED, %d FAILED ===" % [passes, failures])
    if failures == 0:
        print("ALL SYSTEMS OPERATIONAL!\n")
        quit(0)
    else:
        printerr("TEST FAILURES DETECTED!\n")
        quit(1)
```

Run via terminal:
```bash
godot --headless -s tools/test_game.gd
```

---

## 🎨 Example Game Archetype Configurations

### Archetype A: Cyberpunk Endless Runner
```yaml
GAME_TITLE: "Neon Velocity 3D"
GENRE_ARCHETYPE: "Endless Runner / Lane Switcher"
CAMERA_PERSPECTIVE: "Behind runner (FOV 82, tilted 14 deg)"
KEY_MECHANICS: "3 lanes, jump over high lasers, slide under low barriers, katana slash on rogue drones"
SCORING: "1 pt/m + 250 pts/pickup + 500 pts/drone slash. Dynamic combo meter on consecutive slashes."
VISUAL_THEME: "Dark obsidian track with glowing cyan lane dividers, synthwave sun, ACES bloom"
```

### Archetype B: Top-Down Arena Survival
```yaml
GAME_TITLE: "Cyber Swarm 3D"
GENRE_ARCHETYPE: "Arena Survival / Twin-Stick Shooter"
CAMERA_PERSPECTIVE: "Top-down isometric 3D (FOV 60, pitched 55 deg)"
KEY_MECHANICS: "360-degree WASD movement, mouse aim shooting, dodge dash roll with invulnerability frames"
SCORING: "100 pts per enemy swarm unit, kill streaks multiply score, survive wave timer"
VISUAL_THEME: "Dark metal arena deck, red perimeter death wall, bright green energy drops"
```

### Archetype C: Low-Poly 3D Platformer
```yaml
GAME_TITLE: "Apex Ascent 3D"
GENRE_ARCHETYPE: "Precision 3D Platformer"
CAMERA_PERSPECTIVE: "Orbital Third-Person with smooth collision pull-in"
KEY_MECHANICS: "Double jump, wall slide, ledge climb, air dash"
SCORING: "Time trial completion, golden relics collected, death count deduction"
VISUAL_THEME: "Pastel floating islands, crystal checkpoints, procedural sky gradient"
```
