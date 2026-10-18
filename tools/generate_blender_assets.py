#!/usr/bin/env python3
"""
tools/generate_blender_assets.py
Procedurally models, materials, and exports 14 stylized 3D assets for Ninja Run into res://assets/models/
Can be run inside Blender directly via MCP execute_blender_code or standalone blender -b -P.
"""

import os
import math
import bpy

# Set up output directory
PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
MODELS_DIR = os.path.join(PROJECT_DIR, "assets", "models")
os.makedirs(MODELS_DIR, exist_ok=True)

def reset_scene():
    """Clears all objects and materials from the Blender scene."""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for mat in bpy.data.materials:
        bpy.data.materials.remove(mat)
    for mesh in bpy.data.meshes:
        bpy.data.meshes.remove(mesh)

def create_material(name, base_color, metallic=0.0, roughness=0.5, emission_color=None, emission_strength=1.0):
    """Creates a Principled BSDF material safely looking up nodes by type."""
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf:
        if "Base Color" in bsdf.inputs:
            bsdf.inputs["Base Color"].default_value = base_color
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = metallic
        if "Roughness" in bsdf.inputs:
            bsdf.inputs["Roughness"].default_value = roughness
        if emission_color and "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = emission_color
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat

def assign_material(obj, mat):
    if len(obj.data.materials) == 0:
        obj.data.materials.append(mat)
    else:
        obj.data.materials[0] = mat

def export_glb(filename):
    """Exports all current scene objects to a GLB file."""
    filepath = os.path.join(MODELS_DIR, filename)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(
        filepath=filepath,
        export_format='GLB',
        use_selection=True,
        export_apply=True
    )
    print(f"Exported: {filepath}")

# ----------------- ASSET BUILDERS -----------------

def build_ninja():
    reset_scene()
    m_body = create_material("M_Ninja_Body", (0.1, 0.12, 0.16, 1.0), roughness=0.6)
    m_skin = create_material("M_Ninja_Skin", (0.85, 0.68, 0.55, 1.0), roughness=0.5)
    m_scarf = create_material("M_Ninja_Scarf", (0.8, 0.1, 0.1, 1.0), roughness=0.4)
    m_steel = create_material("M_Ninja_Steel", (0.7, 0.75, 0.8, 1.0), metallic=0.9, roughness=0.2)

    # Torso
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 1.0))
    torso = bpy.context.active_object
    torso.name = "Torso"
    torso.scale = (0.5, 0.35, 0.7)
    assign_material(torso, m_body)

    # Head
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.28, location=(0, 0, 1.6))
    head = bpy.context.active_object
    head.name = "Head"
    assign_material(head, m_body)

    # Mask slit (skin / eyes)
    bpy.ops.mesh.primitive_cube_add(size=0.1, location=(0, 0.25, 1.62))
    mask = bpy.context.active_object
    mask.name = "MaskEyeSlit"
    mask.scale = (2.2, 0.2, 0.6)
    assign_material(mask, m_skin)

    # Scarf / Headband knot & tails
    bpy.ops.mesh.primitive_cylinder_add(radius=0.32, depth=0.12, location=(0, 0, 1.45))
    collar = bpy.context.active_object
    collar.name = "ScarfCollar"
    assign_material(collar, m_scarf)

    bpy.ops.mesh.primitive_cube_add(size=0.1, location=(-0.1, -0.3, 1.35))
    tail1 = bpy.context.active_object
    tail1.name = "ScarfTail1"
    tail1.scale = (0.8, 2.5, 0.2)
    tail1.rotation_euler = (math.radians(-25), math.radians(10), 0)
    assign_material(tail1, m_scarf)

    # Katana Sheath on back
    bpy.ops.mesh.primitive_cylinder_add(radius=0.035, depth=1.1, location=(0.15, -0.22, 1.15))
    sheath = bpy.context.active_object
    sheath.name = "KatanaSheath"
    sheath.rotation_euler = (math.radians(-35), math.radians(20), 0)
    assign_material(sheath, m_steel)

    # Legs
    for side, x in [("L", -0.16), ("R", 0.16)]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.1, depth=0.7, location=(x, 0, 0.35))
        leg = bpy.context.active_object
        leg.name = f"Leg_{side}"
        assign_material(leg, m_body)

    # Arms
    for side, x in [("L", -0.36), ("R", 0.36)]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.09, depth=0.6, location=(x, 0, 0.95))
        arm = bpy.context.active_object
        arm.name = f"Arm_{side}"
        arm.rotation_euler = (0, math.radians(15 if side == 'R' else -15), 0)
        assign_material(arm, m_body)

    export_glb("ninja_player.glb")

def build_spirit():
    reset_scene()
    m_ghost = create_material("M_Ghost", (0.8, 0.9, 1.0, 0.8), roughness=0.2, emission_color=(0.2, 0.6, 1.0, 1.0), emission_strength=2.0)
    m_eyes = create_material("M_GhostEyes", (0.1, 0.8, 1.0, 1.0), emission_color=(0.3, 1.0, 1.0, 1.0), emission_strength=5.0)

    # Flowing shroud
    bpy.ops.mesh.primitive_cone_add(radius1=0.45, radius2=0.1, depth=1.4, location=(0, 0, 1.1))
    shroud = bpy.context.active_object
    shroud.name = "GhostBody"
    assign_material(shroud, m_ghost)

    # Head
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.32, location=(0, 0, 1.7))
    head = bpy.context.active_object
    head.name = "GhostHead"
    assign_material(head, m_ghost)

    # Glowing eyes
    for x in [-0.12, 0.12]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.06, location=(x, 0.28, 1.72))
        eye = bpy.context.active_object
        assign_material(eye, m_eyes)

    # Orbiting Hitodama flames
    for i, (ox, oy, oz) in enumerate([(-0.6, 0.2, 1.3), (0.6, -0.2, 1.5), (0.0, -0.6, 1.0)]):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.14, location=(ox, oy, oz))
        flame = bpy.context.active_object
        flame.name = f"Hitodama_{i}"
        assign_material(flame, m_eyes)

    export_glb("enemy_spirit.glb")

def build_skeleton():
    reset_scene()
    m_bone = create_material("M_Bone", (0.85, 0.82, 0.72, 1.0), roughness=0.7)
    m_eye_red = create_material("M_SkelEyes", (1.0, 0.1, 0.1, 1.0), emission_color=(1.0, 0.1, 0.1, 1.0), emission_strength=4.0)
    m_hat = create_material("M_Jingasa", (0.35, 0.25, 0.18, 1.0), roughness=0.8)
    m_spear = create_material("M_Spear", (0.4, 0.3, 0.2, 1.0), roughness=0.6)

    # Skull
    bpy.ops.mesh.primitive_cube_add(size=0.4, location=(0, 0, 1.6))
    skull = bpy.context.active_object
    skull.name = "Skull"
    assign_material(skull, m_bone)

    # Eye sockets
    for x in [-0.09, 0.09]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.045, location=(x, 0.2, 1.62))
        eye = bpy.context.active_object
        assign_material(eye, m_eye_red)

    # Jingasa conical straw hat
    bpy.ops.mesh.primitive_cone_add(radius1=0.65, depth=0.22, location=(0, 0, 1.82))
    hat = bpy.context.active_object
    hat.name = "JingasaHat"
    assign_material(hat, m_hat)

    # Spine & Ribcage
    bpy.ops.mesh.primitive_cylinder_add(radius=0.06, depth=0.7, location=(0, 0, 1.05))
    spine = bpy.context.active_object
    assign_material(spine, m_bone)

    for z in [1.25, 1.1, 0.95]:
        bpy.ops.mesh.primitive_torus_add(major_radius=0.25, minor_radius=0.03, location=(0, 0, z))
        rib = bpy.context.active_object
        rib.scale = (1.0, 0.7, 1.0)
        assign_material(rib, m_bone)

    # Yari Spear
    bpy.ops.mesh.primitive_cylinder_add(radius=0.03, depth=2.4, location=(0.4, 0.2, 1.2))
    spear = bpy.context.active_object
    spear.rotation_euler = (math.radians(15), 0, 0)
    assign_material(spear, m_spear)

    bpy.ops.mesh.primitive_cone_add(radius1=0.08, depth=0.45, location=(0.4, 0.5, 2.3))
    tip = bpy.context.active_object
    tip.rotation_euler = (math.radians(15), 0, 0)
    assign_material(tip, m_bone)

    # Legs
    for x in [-0.15, 0.15]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.04, depth=0.7, location=(x, 0, 0.35))
        leg = bpy.context.active_object
        assign_material(leg, m_bone)

    export_glb("enemy_skeleton.glb")

def build_witch():
    reset_scene()
    m_robe = create_material("M_WitchRobe", (0.25, 0.12, 0.3, 1.0), roughness=0.8)
    m_skin = create_material("M_WitchSkin", (0.55, 0.65, 0.5, 1.0), roughness=0.6)
    m_glow = create_material("M_WitchGlow", (0.8, 0.1, 0.9, 1.0), emission_color=(0.9, 0.2, 1.0, 1.0), emission_strength=4.0)

    # Hunched body
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.45, location=(0, 0, 1.1))
    body = bpy.context.active_object
    body.scale = (0.7, 0.9, 1.1)
    assign_material(body, m_robe)

    # Hunched head
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.25, location=(0, 0.3, 1.4))
    head = bpy.context.active_object
    assign_material(head, m_skin)

    # Evil glowing eyes
    for x in [-0.09, 0.09]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.04, location=(x, 0.5, 1.45))
        eye = bpy.context.active_object
        assign_material(eye, m_glow)

    # Twisted Staff
    bpy.ops.mesh.primitive_cylinder_add(radius=0.04, depth=1.8, location=(-0.45, 0.3, 0.9))
    staff = bpy.context.active_object
    assign_material(staff, m_robe)

    # Floating cursed skull/crystal on staff
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.15, location=(-0.45, 0.3, 1.85))
    orb = bpy.context.active_object
    assign_material(orb, m_glow)

    # Jorogumo spider legs on back
    for i, angle in enumerate([-60, -25, 25, 60]):
        bpy.ops.mesh.primitive_cylinder_add(radius=0.035, depth=1.3, location=(0, -0.3, 1.2))
        sleg = bpy.context.active_object
        sleg.rotation_euler = (math.radians(-30), math.radians(angle), 0)
        assign_material(sleg, m_robe)

    export_glb("enemy_witch.glb")

def build_samurai():
    reset_scene()
    m_armor = create_material("M_SamuraiArmor", (0.1, 0.1, 0.12, 1.0), metallic=0.7, roughness=0.3)
    m_gold = create_material("M_SamuraiGold", (0.9, 0.75, 0.2, 1.0), metallic=0.9, roughness=0.2)
    m_crimson = create_material("M_SamuraiRed", (0.8, 0.05, 0.05, 1.0), roughness=0.5)
    m_glow = create_material("M_SamuraiEyeGlow", (1.0, 0.05, 0.05, 1.0), emission_color=(1.0, 0.1, 0.1, 1.0), emission_strength=5.0)

    # Heavy torso armor (Do)
    bpy.ops.mesh.primitive_cube_add(size=0.8, location=(0, 0, 1.15))
    torso = bpy.context.active_object
    torso.scale = (0.7, 0.5, 0.9)
    assign_material(torso, m_armor)

    # Shoulder plates (Sode)
    for x in [-0.48, 0.48]:
        bpy.ops.mesh.primitive_cube_add(size=0.35, location=(x, 0, 1.45))
        sode = bpy.context.active_object
        sode.scale = (0.4, 0.9, 1.1)
        assign_material(sode, m_crimson)

    # Kabuto helmet
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.35, location=(0, 0, 1.75))
    kabuto = bpy.context.active_object
    assign_material(kabuto, m_armor)

    # Golden Crescent Horn (Maedate)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.3, minor_radius=0.04, location=(0, 0.32, 2.05))
    crest = bpy.context.active_object
    crest.rotation_euler = (math.radians(90), 0, 0)
    crest.scale = (1.2, 0.6, 0.6)
    assign_material(crest, m_gold)

    # Glowing red eyes inside visor
    for x in [-0.1, 0.1]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.05, location=(x, 0.3, 1.75))
        eye = bpy.context.active_object
        assign_material(eye, m_glow)

    # Large Cursed Odachi (Two-handed Katana)
    bpy.ops.mesh.primitive_cube_add(size=0.1, location=(0.4, 0.25, 1.2))
    blade = bpy.context.active_object
    blade.scale = (0.3, 0.05, 16.0)
    blade.rotation_euler = (math.radians(20), math.radians(10), 0)
    assign_material(blade, m_glow)

    # Legs
    for x in [-0.2, 0.2]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.13, depth=0.75, location=(x, 0, 0.38))
        leg = bpy.context.active_object
        assign_material(leg, m_armor)

    export_glb("enemy_samurai.glb")

def build_tengu():
    reset_scene()
    m_tengu_red = create_material("M_TenguSkin", (0.8, 0.15, 0.15, 1.0), roughness=0.5)
    m_feathers = create_material("M_TenguWings", (0.08, 0.08, 0.1, 1.0), roughness=0.6)
    m_gold = create_material("M_TenguGold", (0.9, 0.7, 0.1, 1.0), metallic=0.8, roughness=0.3)

    # Body
    bpy.ops.mesh.primitive_cube_add(size=0.7, location=(0, 0, 1.4))
    body = bpy.context.active_object
    body.scale = (0.6, 0.5, 0.9)
    assign_material(body, m_tengu_red)

    # Head
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.28, location=(0, 0, 1.9))
    head = bpy.context.active_object
    assign_material(head, m_tengu_red)

    # Long Iconic Tengu Nose
    bpy.ops.mesh.primitive_cylinder_add(radius=0.06, depth=0.45, location=(0, 0.35, 1.88))
    nose = bpy.context.active_object
    nose.rotation_euler = (math.radians(90), 0, 0)
    assign_material(nose, m_tengu_red)

    # Tokin (small black cap on forehead)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.12, depth=0.1, location=(0, 0.1, 2.15))
    tokin = bpy.context.active_object
    assign_material(tokin, m_feathers)

    # Large Black Wings (Wingspan ~2.5m)
    for side, x, rot in [("L", -0.9, -25), ("R", 0.9, 25)]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, -0.15, 1.6))
        wing = bpy.context.active_object
        wing.name = f"Wing_{side}"
        wing.scale = (1.1, 0.1, 0.6)
        wing.rotation_euler = (0, math.radians(rot), math.radians(rot * 0.5))
        assign_material(wing, m_feathers)

    export_glb("enemy_tengu.glb")

def build_oni():
    reset_scene()
    m_oni_red = create_material("M_OniSkin", (0.75, 0.08, 0.08, 1.0), roughness=0.6)
    m_horn = create_material("M_OniHorn", (0.95, 0.9, 0.75, 1.0), roughness=0.4)
    m_club = create_material("M_Kanabo", (0.1, 0.1, 0.1, 1.0), metallic=0.7, roughness=0.4)
    m_stud = create_material("M_KanaboStud", (0.7, 0.7, 0.7, 1.0), metallic=0.9, roughness=0.2)

    # Massive muscular body
    bpy.ops.mesh.primitive_cube_add(size=1.2, location=(0, 0, 1.3))
    body = bpy.context.active_object
    body.scale = (0.9, 0.7, 1.0)
    assign_material(body, m_oni_red)

    # Huge Head & Fanged Jaw
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.42, location=(0, 0, 2.05))
    head = bpy.context.active_object
    assign_material(head, m_oni_red)

    # Two Horns
    for x in [-0.22, 0.22]:
        bpy.ops.mesh.primitive_cone_add(radius1=0.08, depth=0.4, location=(x, 0.05, 2.45))
        horn = bpy.context.active_object
        horn.rotation_euler = (math.radians(-15), math.radians(15 if x > 0 else -15), 0)
        assign_material(horn, m_horn)

    # Kanabo Iron Club
    bpy.ops.mesh.primitive_cylinder_add(radius=0.16, depth=1.8, location=(0.6, 0.3, 1.0))
    club = bpy.context.active_object
    club.rotation_euler = (math.radians(20), 0, 0)
    assign_material(club, m_club)

    # Iron studs on Kanabo
    for z in [0.7, 1.1, 1.5]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.06, location=(0.6, 0.47, z))
        stud = bpy.context.active_object
        assign_material(stud, m_stud)

    # Legs
    for x in [-0.3, 0.3]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.2, depth=0.8, location=(x, 0, 0.4))
        leg = bpy.context.active_object
        assign_material(leg, m_oni_red)

    export_glb("enemy_oni.glb")

def build_lantern():
    reset_scene()
    m_paper = create_material("M_LanternPaper", (0.85, 0.8, 0.65, 1.0), roughness=0.6, emission_color=(0.9, 0.7, 0.3, 1.0), emission_strength=1.5)
    m_wood = create_material("M_LanternWood", (0.2, 0.12, 0.08, 1.0), roughness=0.7)
    m_tongue = create_material("M_LanternTongue", (0.9, 0.1, 0.15, 1.0), roughness=0.4)
    m_eye = create_material("M_LanternEye", (1.0, 1.0, 1.0, 1.0), roughness=0.3)
    m_pupil = create_material("M_LanternPupil", (0.05, 0.05, 0.05, 1.0), roughness=0.1)

    # Ribbed Paper Lantern Body
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, location=(0, 0, 1.2))
    body = bpy.context.active_object
    body.scale = (0.8, 0.8, 1.2)
    assign_material(body, m_paper)

    # Top & Bottom Wood Rims
    for z in [0.65, 1.75]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.25, depth=0.1, location=(0, 0, z))
        rim = bpy.context.active_object
        assign_material(rim, m_wood)

    # Single Giant Eye in upper center
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.16, location=(0, 0.38, 1.45))
    eye = bpy.context.active_object
    assign_material(eye, m_eye)

    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.07, location=(0, 0.51, 1.45))
    pupil = bpy.context.active_object
    assign_material(pupil, m_pupil)

    # Gaping Split Mouth
    bpy.ops.mesh.primitive_cube_add(size=0.1, location=(0, 0.38, 1.05))
    mouth = bpy.context.active_object
    mouth.scale = (3.5, 0.4, 0.8)
    assign_material(mouth, m_wood)

    # Long Red Tongue sticking out
    bpy.ops.mesh.primitive_cube_add(size=0.1, location=(0, 0.52, 0.88))
    tongue = bpy.context.active_object
    tongue.scale = (1.2, 2.5, 0.3)
    tongue.rotation_euler = (math.radians(-30), 0, 0)
    assign_material(tongue, m_tongue)

    export_glb("enemy_lantern.glb")

def build_barricade():
    reset_scene()
    m_wood = create_material("M_ObstacleWood", (0.35, 0.22, 0.14, 1.0), roughness=0.8)
    m_spike = create_material("M_SpikeBamboo", (0.6, 0.55, 0.3, 1.0), roughness=0.5)

    # Horizontal beam across single lane (width 2.4m, height 0.45m)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.1, depth=2.4, location=(0, 0, 0.35))
    beam = bpy.context.active_object
    beam.rotation_euler = (0, math.radians(90), 0)
    assign_material(beam, m_wood)

    # Crossed bamboo stakes evenly spaced across lane
    for x in [-0.9, -0.5, -0.15, 0.15, 0.5, 0.9]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.05, depth=0.85, location=(x, 0, 0.35))
        stake = bpy.context.active_object
        stake.rotation_euler = (math.radians(25 if x < 0 else -25), 0, 0)
        assign_material(stake, m_spike)

    export_glb("obstacle_barricade.glb")

def build_high_gate():
    reset_scene()
    m_wood = create_material("M_GateWood", (0.4, 0.15, 0.1, 1.0), roughness=0.7)
    m_paper = create_material("M_OfudaPaper", (0.9, 0.9, 0.85, 1.0), roughness=0.4)
    m_red = create_material("M_OfudaRed", (0.8, 0.1, 0.1, 1.0), roughness=0.5)

    # High crossbeam (width 2.4m, height 1.75m - must slide under)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 1.75))
    beam = bpy.context.active_object
    beam.scale = (2.4, 0.25, 0.25)
    assign_material(beam, m_wood)

    # Side support poles (spanning 2.24m, strictly inside single 3.6m lane)
    for x in [-1.12, 1.12]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.09, depth=2.0, location=(x, 0, 1.0))
        post = bpy.context.active_object
        assign_material(post, m_wood)

    # Hanging Ofuda Talismans (Paper banners)
    for x in [-0.8, -0.4, 0.0, 0.4, 0.8]:
        bpy.ops.mesh.primitive_cube_add(size=0.1, location=(x, 0, 1.35))
        banner = bpy.context.active_object
        banner.scale = (1.2, 0.1, 4.0)
        assign_material(banner, m_paper if abs(x) < 0.5 else m_red)

    export_glb("obstacle_high_gate.glb")

def build_pickup_slowdown():
    reset_scene()
    m_cyan_glow = create_material("M_ChronoCyan", (0.1, 0.9, 1.0, 1.0), emission_color=(0.2, 0.9, 1.0, 1.0), emission_strength=5.0)
    m_gold_ring = create_material("M_ChronoRing", (0.9, 0.8, 0.3, 1.0), metallic=0.9, roughness=0.2)

    # Central Magatama / Hourglass Crystal
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.22, location=(0, 0, 1.0))
    core = bpy.context.active_object
    core.scale = (0.7, 0.7, 1.4)
    assign_material(core, m_cyan_glow)

    # Rotating Golden Astrolabe Rings
    bpy.ops.mesh.primitive_torus_add(major_radius=0.38, minor_radius=0.03, location=(0, 0, 1.0))
    ring1 = bpy.context.active_object
    assign_material(ring1, m_gold_ring)

    bpy.ops.mesh.primitive_torus_add(major_radius=0.48, minor_radius=0.025, location=(0, 0, 1.0))
    ring2 = bpy.context.active_object
    ring2.rotation_euler = (math.radians(60), math.radians(30), 0)
    assign_material(ring2, m_gold_ring)

    export_glb("pickup_slowdown.glb")

def build_pickup_koban():
    reset_scene()
    m_gold = create_material("M_KobanGold", (0.95, 0.82, 0.2, 1.0), metallic=0.95, roughness=0.15)

    # Edo Koban Oval Coin
    bpy.ops.mesh.primitive_cylinder_add(radius=0.22, depth=0.04, location=(0, 0, 0.9))
    coin = bpy.context.active_object
    coin.scale = (0.7, 1.3, 1.0)
    assign_material(coin, m_gold)

    export_glb("pickup_koban.glb")

def build_shrine_arch():
    reset_scene()
    m_vermilion = create_material("M_ToriiRed", (0.85, 0.15, 0.08, 1.0), roughness=0.5)
    m_stone = create_material("M_LanternStone", (0.5, 0.52, 0.55, 1.0), roughness=0.8)
    m_flame = create_material("M_ShrineFire", (1.0, 0.7, 0.1, 1.0), emission_color=(1.0, 0.6, 0.1, 1.0), emission_strength=4.0)

    # Modular Torii arch spanning widened 12.4m track (width 14m, height 4.8m)
    # Lintels
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 4.6))
    kasagi = bpy.context.active_object
    kasagi.scale = (14.0, 0.6, 0.5)
    assign_material(kasagi, m_vermilion)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 3.8))
    nuki = bpy.context.active_object
    nuki.scale = (12.5, 0.45, 0.35)
    assign_material(nuki, m_vermilion)

    # Two pillars on track outer curb perimeter
    for x in [-5.8, 5.8]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.3, depth=4.6, location=(x, 0, 2.3))
        pillar = bpy.context.active_object
        assign_material(pillar, m_vermilion)

        # Stone Toro Lantern beside arch
        bpy.ops.mesh.primitive_cube_add(size=0.7, location=(x * 1.12, 0, 0.6))
        toro = bpy.context.active_object
        assign_material(toro, m_stone)

        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.18, location=(x * 1.12, 0, 1.1))
        fire = bpy.context.active_object
        assign_material(fire, m_flame)

    export_glb("env_shrine_arch.glb")

def build_goal_shrine():
    reset_scene()
    m_gold = create_material("M_GoalGold", (0.95, 0.8, 0.15, 1.0), metallic=0.9, roughness=0.15)
    m_vermilion = create_material("M_GoalRed", (0.9, 0.1, 0.05, 1.0), roughness=0.4)
    m_lantern = create_material("M_GoalLantern", (1.0, 0.4, 0.1, 1.0), emission_color=(1.0, 0.5, 0.1, 1.0), emission_strength=4.0)

    # Grand Torii with Golden Cap spanning 12.4m track
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 5.4))
    kasagi = bpy.context.active_object
    kasagi.scale = (15.5, 0.8, 0.6)
    assign_material(kasagi, m_gold)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 4.4))
    nuki = bpy.context.active_object
    nuki.scale = (13.5, 0.55, 0.4)
    assign_material(nuki, m_vermilion)

    for x in [-6.0, 6.0]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.4, depth=5.4, location=(x, 0, 2.7))
        pillar = bpy.context.active_object
        assign_material(pillar, m_vermilion)

    # Hanging Golden Bells / Lanterns
    for x in [-4.0, -2.0, 0.0, 2.0, 4.0]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.4, location=(x, 0, 3.7))
        bell = bpy.context.active_object
        assign_material(bell, m_lantern)

    export_glb("env_goal_shrine.glb")

def main():
    print("Generating all 14 stylized 3D assets in Blender...")
    build_ninja()
    build_spirit()
    build_skeleton()
    build_witch()
    build_samurai()
    build_tengu()
    build_oni()
    build_lantern()
    build_barricade()
    build_high_gate()
    build_pickup_slowdown()
    build_pickup_koban()
    build_shrine_arch()
    build_goal_shrine()
    print("Finished generating all 14 assets successfully!")

if __name__ == "__main__" or "bpy" in locals():
    main()
