# SD Unity-chan FBX -> glTF for the diorama (Blender 5.x).
#
#   blender -b --factory-startup --python tools/unitychan-convert.py -- \
#     <SD_unitychan_generic.fbx> <SD_unitychan_motion_Generic.fbx> <utc_all2.tga> <out.glb> \
#     [ClipName=<Kevin Iglesias Humanoid clip.fbx> ...]
#
# Extra clips (e.g. Human Crafting Animations FREE) are retargeted onto Unity-chan and baked;
# their source FBX files stay outside the repository (Asset Store EULA: no raw redistribution).
import bpy, sys
from mathutils import Matrix, Vector

argv=sys.argv[sys.argv.index('--')+1:]
model,motion,tex,out=argv[:4]
extra=[a.split('=',1) for a in argv[4:]]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=model)
arm=bpy.data.objects['center']
# FBX import leaves the skinned body lying on its back; stand it up in the rest pose.
bpy.data.objects['_body'].matrix_world=Matrix.Diagonal((.01,.01,.01,1))
bpy.context.view_layer.update()
# Face, hair and ribbons arrive bone-parented without skinning; bind them to the armature.
for o in [o for o in bpy.data.objects if o.type=='MESH' and o.parent_type=='BONE']:
    bone=o.parent_bone; mw=o.matrix_world.copy()
    o.parent=arm; o.parent_type='OBJECT'; o.matrix_world=mw
    if not o.vertex_groups:
        g=o.vertex_groups.new(name=bone); g.add(list(range(len(o.data.vertices))),1.0,'REPLACE')
    if not any(m.type=='ARMATURE' for m in o.modifiers):
        o.modifiers.new('Armature','ARMATURE').object=arm

before=set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=motion)
take=bpy.data.objects['center.001'].animation_data.action
# Bake extra clips with the root posed exactly as Unity's take poses it, so the root
# track (location/rotation/scale) of every clip shares one convention.
bpy.context.scene.frame_set(10)
arm.matrix_world=bpy.data.objects['center.001'].matrix_world.copy()
bpy.context.view_layer.update()
print('ROOT',[tuple(round(v,4) for v in r) for r in arm.matrix_world])
for o in set(bpy.data.objects)-before: bpy.data.objects.remove(o,do_unlink=True)
for o in list(bpy.data.objects):
    if o.type=='EMPTY': bpy.data.objects.remove(o,do_unlink=True)
for a in list(bpy.data.actions):
    if a!=take: bpy.data.actions.remove(a)

# ---- Retarget Humanoid clips from the Kevin Iglesias rig (B-*) onto Character1_* ----
MAP={'Character1_Hips':'B-hips','Character1_Spine':'B-spine','Character1_Spine2':'B-chest',
     'Character1_Neck':'B-neck','Character1_Head':'B-head'}
for s,S in (('L','Left'),('R','Right')):
    for t,b in (('Shoulder','shoulder'),('Arm','upperArm'),('ForeArm','forearm'),('Hand','hand'),
                ('UpLeg','thigh'),('Leg','shin'),('Foot','foot'),('ToeBase','toe')):
        MAP[f'Character1_{S}{t}']=f'B-{b}.{s}'
ROOTED=('Character1_Hips','Character1_Spine')  # Spine is a sibling of Hips in this rig

def q(M): return M.to_3x3().normalized().to_quaternion()
def frame(rest,hips,head,left):
    up=(rest[head].translation-rest[hips].translation).normalized()
    lf=rest[left].translation-rest[hips].translation; lf=(lf-up*lf.dot(up)).normalized()
    return Matrix((lf,up.cross(lf),up)).transposed().to_quaternion()

scene=bpy.context.scene
FPS=scene.render.fps  # Unity-chan motion is authored at 30 fps
arm.animation_data_create(); ad=arm.animation_data
tgt_rest={b.name:arm.matrix_world@b.matrix_local for b in arm.data.bones}
order=[b.name for b in arm.data.bones if b.name in MAP]
# Reference height comes from Unity's own standing pose, not the bind pose.
ad.action=take; ad.action_slot=take.slots[0]; scene.frame_set(10)
ref={n:(arm.matrix_world@arm.pose.bones[n].head).copy() for n in ROOTED}
ad.action=None
for pb in arm.pose.bones: pb.matrix_basis.identity()
baked=[]
for name,path in extra:
    before=set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path)
    src=[o for o in set(bpy.data.objects)-before if o.type=='ARMATURE'][0]
    src_act=src.animation_data.action; s0,s1=src_act.frame_range
    src_fps=scene.render.fps/scene.render.fps_base; scene.render.fps=FPS; scene.render.fps_base=1
    f0,f1=1,1+round((s1-s0)*FPS/src_fps)
    # The rig's root carries an extra axis/scale conversion; work relative to it.
    R0=src.data.bones['B-root'].matrix_local.inverted()
    src_rest={b.name:R0@b.matrix_local for b in src.data.bones}
    C=frame(tgt_rest,'Character1_Hips','Character1_Head','Character1_LeftUpLeg')@ \
      frame(src_rest,'B-hips','B-head','B-thigh.L').inverted()
    ratio=ref['Character1_Hips'].z/src_rest['B-hips'].translation.length
    act=bpy.data.actions.new(name); ad.action=act
    for pb in arm.pose.bones: pb.matrix_basis.identity()
    for f in range(f0,f1+1):
        t=s0+(f-f0)*src_fps/FPS; scene.frame_set(int(t),subframe=t-int(t))
        root=src.pose.bones['B-root'].matrix.inverted()
        hips=root@src.pose.bones['B-hips'].matrix
        dz=(C@((hips.translation-src_rest['B-hips'].translation)*ratio)).z
        for tb in order:
            sb=MAP[tb]; Sw=root@src.pose.bones[sb].matrix
            rot=C@q(Sw)@q(src_rest[sb]).inverted()@C.inverted()@tgt_rest[tb].to_quaternion()
            pb=arm.pose.bones[tb]; cur=arm.matrix_world@pb.matrix
            head=ref[tb]+Vector((0,0,dz)) if tb in ROOTED else cur.translation
            pb.matrix=arm.matrix_world.inverted()@Matrix.LocRotScale(head,rot,cur.to_scale())
            bpy.context.view_layer.update()
            pb.keyframe_insert('rotation_quaternion',frame=f)
            if tb in ROOTED: pb.keyframe_insert('location',frame=f)
    # Unity's clips also animate the armature root ('center'); key it too, or the mixer
    # drops it back to the node default when one of these clips plays.
    rot='rotation_quaternion' if arm.rotation_mode=='QUATERNION' else 'rotation_euler'
    for f in (f0,f1):
        for path in ('location',rot,'scale'): arm.keyframe_insert(path,frame=f)
    for o in set(bpy.data.objects)-before: bpy.data.objects.remove(o,do_unlink=True)
    bpy.data.actions.remove(src_act)
    baked.append((name,act,f0,f1)); print('RETARGET',name,f0,f1)
ad.action=None
for pb in arm.pose.bones: pb.matrix_basis.identity()

clips=[('Standing',10,70),('Walking',80,116),('Running',130,154),('Salute',520,590),('KneelDown',404,510),('KneelDownToUp',511,520)]
for name,a,b in clips+[(n,f0,f1) for n,_,f0,f1 in baked]:
    act=next((x for n,x,_,_ in baked if n==name),take)
    tr=ad.nla_tracks.new(); tr.name=name
    st=tr.strips.new(name,a,act)
    st.action_frame_start=a; st.action_frame_end=b; st.frame_start=a; st.frame_end=b
    st.action_slot=act.slots[0]

# Single atlas texture, downsized.
img=bpy.data.images.load(tex); img.scale(1024,1024)
img.filepath_raw=out.replace('.glb','.png'); img.file_format='PNG'; img.save()
for m in bpy.data.materials:
    m.use_nodes=True; nt=m.node_tree; nt.nodes.clear()
    o=nt.nodes.new('ShaderNodeOutputMaterial'); p=nt.nodes.new('ShaderNodeBsdfPrincipled'); t=nt.nodes.new('ShaderNodeTexImage'); t.image=img
    nt.links.new(t.outputs['Color'],p.inputs['Base Color']); nt.links.new(p.outputs['BSDF'],o.inputs['Surface'])
    p.inputs['Roughness'].default_value=.9
for i in list(bpy.data.images):
    if i!=img: bpy.data.images.remove(i)
scene.render.fps=FPS; scene.render.fps_base=1; print('FPS',scene.render.fps)
bpy.ops.export_scene.gltf(filepath=out,export_format='GLB',export_animation_mode='NLA_TRACKS',export_morph=True,export_skins=True,export_image_format='WEBP',export_yup=True,export_apply=False,export_optimize_animation_keep_anim_object=True)
