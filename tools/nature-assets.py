# Procedural nature assets for the diorama (Blender 5.x).
#
#   blender -b --factory-startup --python tools/nature-assets.py -- public/models/nature.glb
#
# Every object is authored at the origin, base on the ground (Z=0), in diorama tiles.
# Materials are applied in three.js by object name, so only geometry, UVs, custom
# normals and a 'Col' colour attribute (used as a shading gradient) are exported.
import bpy, bmesh, sys, math, random
from mathutils import Vector, Matrix, Quaternion

OUT = sys.argv[sys.argv.index('--')+1]
bpy.ops.wm.read_factory_settings(use_empty=True)
TAU = math.tau


def finish(name, bm, normals=None):
    """normals: callable(co: Vector, face_normal: Vector, color) -> Vector for custom split normals."""
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    obj = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(obj)
    if 'Col' not in me.color_attributes:
        attr = me.color_attributes.new('Col', 'FLOAT_COLOR', 'CORNER')
        for d in attr.data: d.color = (1, 1, 1, 1)
    me.color_attributes.active_color = me.color_attributes['Col']
    if normals:
        col = me.color_attributes['Col'].data
        loops = []
        for poly in me.polygons:
            for li in poly.loop_indices:
                v = me.vertices[me.loops[li].vertex_index].co
                loops.append(normals(v, poly.normal, col[li].color).normalized())
        me.normals_split_custom_set(loops)
    return obj


def layers(bm):
    uv = bm.loops.layers.uv.verify()
    col = bm.loops.layers.float_color.get('Col') or bm.loops.layers.float_color.new('Col')
    return uv, col


def frame(direction):
    d = direction.normalized()
    up = Vector((0, 0, 1)) if abs(d.z) < .95 else Vector((1, 0, 0))
    a = d.cross(up).normalized(); b = d.cross(a).normalized()
    return a, b


def tube(bm, points, radii, sides=7, shade=(1, 1), uv_scale=(1, 1)):
    """Tapered tube along a polyline with cylindrical UVs and an end cap."""
    uv, col = layers(bm)
    rings, length = [], 0
    for i, p in enumerate(points):
        d = (points[min(i+1, len(points)-1)] - points[max(i-1, 0)])
        a, b = frame(d)
        if i: length += (p - points[i-1]).length
        ring = [bm.verts.new(p + (a*math.cos(k/sides*TAU) + b*math.sin(k/sides*TAU))*radii[i]) for k in range(sides)]
        rings.append((ring, length))
    total = max(length, 1e-4)
    for i in range(len(rings)-1):
        (r0, l0), (r1, l1) = rings[i], rings[i+1]
        for k in range(sides):
            f = bm.faces.new((r0[k], r0[(k+1) % sides], r1[(k+1) % sides], r1[k]))
            for loop, (u, v, t) in zip(f.loops, ((k, l0, i), (k+1, l0, i), (k+1, l1, i+1), (k, l1, i+1))):
                loop[uv].uv = (u/sides*uv_scale[0], v*uv_scale[1])
                g = shade[0] + (shade[1]-shade[0])*(t/(len(rings)-1))
                loop[col] = (g, g, g, 1)
    cap = bm.faces.new(rings[-1][0])
    for loop in cap.loops:
        loop[uv].uv = (.5, total*uv_scale[1]); loop[col] = (shade[1],)*3 + (1,)
    return rings


def curve(start, direction, length, segments, droop=0., wobble=0., rng=random):
    pts, p, d = [start.copy()], start.copy(), direction.normalized()
    for i in range(segments):
        d = (d + Vector((rng.uniform(-wobble, wobble), rng.uniform(-wobble, wobble), -droop))).normalized()
        p = p + d*(length/segments); pts.append(p.copy())
    return pts


def card(bm, center, normal, size, spin, tilt_axis=None, uv_rect=(0, 0, 1, 1), shade=1.):
    """A textured quad; the sprig in the texture grows from v=0 toward v=1."""
    uv, col = layers(bm)
    a, b = frame(normal)
    q = Quaternion(normal, spin); a, b = q @ a, q @ b
    w, h = size
    corners = [center - a*w/2 - b*h*.1, center + a*w/2 - b*h*.1, center + a*w/2 + b*h*.9, center - a*w/2 + b*h*.9]
    f = bm.faces.new([bm.verts.new(c) for c in corners])
    u0, v0, u1, v1 = uv_rect
    for loop, t in zip(f.loops, ((u0, v0), (u1, v0), (u1, v1), (u0, v1))):
        loop[uv].uv = t; loop[col] = (shade,)*3 + (1,)
    return f


def directed_card(bm, base, out, width, length, shade=1.):
    """Quad whose v axis runs from base outward along `out` (needle sprigs)."""
    uv, col = layers(bm)
    a, _ = frame(out)
    tip = base + out.normalized()*length
    corners = [base - a*width/2, base + a*width/2, tip + a*width/2, tip - a*width/2]
    f = bm.faces.new([bm.verts.new(c) for c in corners])
    for loop, t, g in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1)), (shade*.7, shade*.7, shade, shade)):
        loop[uv].uv = t; loop[col] = (g, g, g, 1)


def outward(center, up_bias=.35):
    return lambda co, n, c: (co - center).normalized() + Vector((0, 0, up_bias))


# ---------------------------------------------------------------- broadleaf tree
def oak(name, seed, spread=1.):
    rng = random.Random(seed)
    bark = bmesh.new(); leaves = bmesh.new()
    trunk = curve(Vector((0, 0, 0)), Vector((rng.uniform(-.05, .05), rng.uniform(-.05, .05), 1)), 2.15, 7, wobble=.04, rng=rng)
    tube(bark, trunk, [.27 - .1*i/7 for i in range(8)], sides=9, shade=(.55, 1), uv_scale=(1, .9))
    for k in range(5):  # root flare
        a = k/5*TAU + rng.uniform(-.2, .2)
        pts = curve(Vector((0, 0, .32)), Vector((math.cos(a), math.sin(a), -.75)), .52, 3, droop=.12, rng=rng)
        tube(bark, pts, [.12, .09, .06, .03], sides=6, shade=(.5, .6))
    limbs = []  # every branch polyline that carries leaves
    for k in range(6):
        a = k/6*TAU + rng.uniform(-.3, .3)
        base = trunk[5 + k % 3]
        d = Vector((math.cos(a), math.sin(a), rng.uniform(.75, 1.2)))
        main = curve(base, d, rng.uniform(1.0, 1.35)*spread, 5, droop=-.02, wobble=.08, rng=rng)
        tube(bark, main, [.11 - .018*i for i in range(6)], sides=6, shade=(.7, 1))
        limbs.append(main)
        for j in (2, 3, 4):
            sa = a + rng.choice((-1, 1))*rng.uniform(.5, 1.1)
            sub = curve(main[j], Vector((math.cos(sa), math.sin(sa), rng.uniform(.5, 1.))), rng.uniform(.4, .7)*spread, 3, wobble=.1, rng=rng)
            tube(bark, sub, [.045, .035, .025, .015], sides=5, shade=(.8, 1))
            limbs.append(sub)
    # A leader continues the trunk so the crown's top cluster has wood under it.
    leader = curve(trunk[-1], Vector((0, 0, 1)), .7, 3, wobble=.08, rng=rng)
    tube(bark, leader, [.07, .05, .03, .015], sides=5, shade=(.8, 1)); limbs.append(leader)
    pts = [p for limb in limbs for p in limb]
    center = Vector((0, 0, sum(p.z for p in pts)/len(pts) + .25))
    # Sprigs grow out of points on the outer part of every branch: the texture's stem
    # (v=0) sits on the wood, so no leaf hangs in the air.
    for limb in limbs:
        seg = [(limb[i], limb[i+1]) for i in range(len(limb)-1)]
        for i, (p0, p1) in enumerate(seg):
            if i < len(seg)*.25: continue
            for _ in range(13 if len(limb) > 5 else 11):
                t = rng.random(); base = p0.lerp(p1, t)
                along = (p1 - p0).normalized()
                # Sprigs fan around their own twig (not around the crown centre) and lean upward.
                sd = along.cross(Vector((0, 0, 1)))
                sd = (sd.normalized() if sd.length > 1e-4 else Vector((1, 0, 0)))*rng.choice((-1, 1))
                out = (along*.7 + sd*rng.uniform(.3, 1.) + Vector((rng.uniform(-.25, .25), rng.uniform(-.25, .25), rng.uniform(0, .6)))).normalized()
                ln = rng.uniform(.5, .78)
                shade = .62 + .38*max(0, min(1, (base.z - center.z + .9)/1.7))
                directed_card(leaves, base, out, ln*.85, ln, shade=shade)
    finish(name+'Bark', bark)
    finish(name+'Leaves', leaves, outward(center, .3))


# ---------------------------------------------------------------- conifer
def flat_card(bm, base, along, width, length, droop=.0, shade=1.):
    """A spray lying roughly flat: v runs from the twig (base) toward the tip along `along`."""
    uv, col = layers(bm)
    d = Vector((along.x, along.y, along.z)).normalized()
    side = d.cross(Vector((0, 0, 1)))
    side = side.normalized() if side.length > 1e-4 else Vector((1, 0, 0))
    tip = base + d*length + Vector((0, 0, -droop))
    corners = [base - side*width*.3, base + side*width*.3, tip + side*width*.5, tip - side*width*.5]
    f = bm.faces.new([bm.verts.new(c) for c in corners])
    for loop, t, g in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1)), (shade*.75, shade*.75, shade, shade)):
        loop[uv].uv = t; loop[col] = (g, g, g, 1)


def pine(name, seed):
    rng = random.Random(seed)
    bark = bmesh.new(); needles = bmesh.new()
    height = 4.35
    trunk = curve(Vector((0, 0, 0)), Vector((0, 0, 1)), height, 10, wobble=.02, rng=rng)
    tube(bark, trunk, [.22 - .019*i for i in range(11)], sides=8, shade=(.55, 1), uv_scale=(1, .8))
    for k in range(4):
        a = k/4*TAU + .4
        tube(bark, curve(Vector((0, 0, .25)), Vector((math.cos(a), math.sin(a), -.8)), .4, 2, rng=rng), [.09, .06, .03], sides=5, shade=(.5, .6))
    # Irregular whorls of real branches; each carries flat, drooping sprays along its length,
    # so the crown reads as stacked boughs instead of cards fanned out from the trunk.
    z, azimuth = 1.0, rng.uniform(0, TAU)
    while z < height - .45:
        t = (z - 1.0)/(height - 1.45)
        reach = (1.55*(1 - t)**.9 + .25)*rng.uniform(.85, 1.1)
        for k in range(rng.randint(4, 6)):
            azimuth += 2.39996 + rng.uniform(-.35, .35)
            ln = reach*rng.uniform(.75, 1.15)
            d = Vector((math.cos(azimuth), math.sin(azimuth), rng.uniform(-.05, .12)))
            branch = curve(Vector((0, 0, z + rng.uniform(-.05, .05))), d, ln, 4, droop=.05, wobble=.06, rng=rng)
            # tips lift a little, like a real fir bough
            branch[-1] = branch[-1] + Vector((0, 0, .05*ln))
            tube(bark, branch, [.035, .028, .02, .013, .006], sides=4, shade=(.6, .8))
            for i in range(1, len(branch)):
                p0, p1 = branch[i-1], branch[i]
                along = p1 - p0
                for side in (-1, 1):
                    base = p0.lerp(p1, rng.uniform(.1, .9))
                    sd = along.normalized().cross(Vector((0, 0, 1)))*side
                    out = (along.normalized()*.55 + sd*.8 + Vector((0, 0, rng.uniform(-.15, .05)))).normalized()
                    size = ln*(.42 - .06*i)*rng.uniform(.85, 1.15) + .12
                    flat_card(needles, base, out, size*.9, size, droop=size*.18, shade=.55 + .35*t + .1*(i/len(branch)))
            # a spray capping the branch tip
            tipdir = branch[-1] - branch[-2]
            flat_card(needles, branch[-2], tipdir, ln*.32 + .1, ln*.38 + .12, droop=.04, shade=.8 + .2*t)
        z += rng.uniform(.26, .36)
    for k in range(3):  # leader
        a = k/3*TAU
        flat_card(needles, Vector((0, 0, height - .55 + k*.12)), Vector((math.cos(a), math.sin(a), 1.4)), .28, .5, shade=1)
    finish(name+'Bark', bark)
    finish(name+'Needles', needles, lambda co, n, c: Vector((co.x, co.y, 0)).normalized()*.45 + Vector((0, 0, 1)))


# ---------------------------------------------------------------- undergrowth
def grass(name, seed, blades=9, height=.42, spread=.07, segments=3):
    rng = random.Random(seed)
    bm = bmesh.new(); uv, col = layers(bm)
    for _ in range(blades):
        a = rng.uniform(0, TAU); r = spread*math.sqrt(rng.random())
        base = Vector((math.cos(a)*r, math.sin(a)*r, 0))
        b = rng.uniform(0, TAU)
        lean = Vector((math.cos(b), math.sin(b), 0))*rng.uniform(.12, .5)
        h = height*rng.uniform(.55, 1.15); w = rng.uniform(.026, .042)
        side = Vector((-math.sin(b+1.2), math.cos(b+1.2), 0))
        if segments == 1:  # a single tapered triangle: cheapest blade that still reads as grass
            tip = base + Vector((0, 0, h)) + lean*h
            f = bm.faces.new((bm.verts.new(base - side*w*.6), bm.verts.new(base + side*w*.6), bm.verts.new(tip)))
            for loop, (u, t) in zip(f.loops, ((0, 0), (1, 0), (.5, 1))):
                loop[uv].uv = (u, t); g = .42 + .58*t; loop[col] = (g, g, g, 1)
            continue
        rows = []
        for s_ in range(segments+1):
            t = s_/segments
            c = base + Vector((0, 0, h*t)) + lean*h*t*t
            half = w*(1-t*.92)/2
            rows.append((bm.verts.new(c - side*half), bm.verts.new(c + side*half), t))
        for s_ in range(segments):
            (a0, b0, t0), (a1, b1, t1) = rows[s_], rows[s_+1]
            f = bm.faces.new((a0, b0, b1, a1))
            for loop, (u, t) in zip(f.loops, ((0, t0), (1, t0), (1, t1), (0, t1))):
                loop[uv].uv = (u, t); g = .42 + .58*t; loop[col] = (g, g, g, 1)
    finish(name, bm, lambda co, n, c: Vector((0, 0, 1)) + n*.25)


def bush(name, seed, radius=.5):
    rng = random.Random(seed)
    twigs = bmesh.new(); leaves = bmesh.new()
    center = Vector((0, 0, radius*.75))
    for k in range(7):
        a = k/7*TAU + rng.uniform(-.3, .3)
        pts = curve(Vector((0, 0, 0)), Vector((math.cos(a)*.6, math.sin(a)*.6, 1)), radius*1.2, 3, wobble=.15, rng=rng)
        tube(twigs, pts, [.03, .022, .014, .006], sides=5, shade=(.5, .8))
    for _ in range(95):
        d = Vector((rng.gauss(0, 1), rng.gauss(0, 1), abs(rng.gauss(0, .9)) - .1)).normalized()
        p = center + Vector((d.x*radius, d.y*radius, d.z*radius*.8))*rng.uniform(.55, 1.)
        p.z = max(p.z, .08)
        s = rng.uniform(.32, .48)
        card(leaves, p, (d + Vector((0, 0, .3))).normalized(), (s, s), rng.uniform(0, TAU), shade=.55 + .45*min(1, p.z/(radius*1.4)))
    finish(name+'Twigs', twigs)
    finish(name+'Leaves', leaves, outward(center, .45))


def flower(name, seed, petals=6):
    rng = random.Random(seed)
    stem = bmesh.new(); head = bmesh.new()
    h = .32
    pts = curve(Vector((0, 0, 0)), Vector((rng.uniform(-.1, .1), rng.uniform(-.1, .1), 1)), h, 4, wobble=.05, rng=rng)
    tube(stem, pts, [.011, .01, .009, .008, .007], sides=5, shade=(.5, .9))
    uv, col = layers(stem)
    for k, z in enumerate((.08, .15)):  # two lanceolate leaves
        a = k*2.6 + rng.uniform(-.3, .3)
        d = Vector((math.cos(a), math.sin(a), .55)).normalized(); side = Vector((-math.sin(a), math.cos(a), 0))
        base = pts[1] if k == 0 else pts[2]
        ring = [(0, 0), (.3, .028), (.65, .03), (1, 0)]
        vs = []
        for t, w in ring:
            c = base + d*.13*t + Vector((0, 0, -.03*t*t))
            vs.append((stem.verts.new(c - side*w), stem.verts.new(c + side*w)))
        for i in range(3):
            f = stem.faces.new((vs[i][0], vs[i][1], vs[i+1][1], vs[i+1][0]))
            for loop in f.loops: loop[col] = (.75, .75, .75, 1)
    top = pts[-1]
    uvh, colh = layers(head)
    for k in range(petals):  # cupped petals, white so the instance colour tints them
        a = k/petals*TAU
        d = Vector((math.cos(a), math.sin(a), .35)).normalized(); side = Vector((-math.sin(a), math.cos(a), 0))
        rows = []
        for t, w in ((0, .008), (.4, .026), (.8, .022), (1, 0)):
            c = top + d*.07*t + Vector((0, 0, .025*t*t))
            rows.append((head.verts.new(c - side*w), head.verts.new(c + side*w), t))
        for i in range(3):
            f = head.faces.new((rows[i][0], rows[i][1], rows[i+1][1], rows[i+1][0]))
            for loop in f.loops: loop[colh] = (1, 1, 1, 1)
    disc = [head.verts.new(top + Vector((math.cos(k/8*TAU)*.018, math.sin(k/8*TAU)*.018, .012))) for k in range(8)]
    f = head.faces.new(disc)
    for loop in f.loops: loop[colh] = (1.6, 1.25, .35, 1)  # golden centre, survives the tint
    finish(name+'Stem', stem, lambda co, n, c: n + Vector((0, 0, .6)))
    finish(name+'Head', head, lambda co, n, c: Vector((0, 0, 1)) + n*.3)


def cabbage(name, seed):
    rng = random.Random(seed)
    bm = bmesh.new(); uv, col = layers(bm)
    leaves = 11
    for k in range(leaves):
        inner = k >= 6
        a = k*2.4 + rng.uniform(-.2, .2)
        d = Vector((math.cos(a), math.sin(a), 0)); side = Vector((-math.sin(a), math.cos(a), 0))
        length = .11 if inner else .19; rise = .1 if inner else .05
        rows = []
        for t in (0, .25, .5, .75, 1):
            w = length*.62*math.sin(math.pi*min(1, t*1.1+.05))
            curl = .55 if inner else .25
            c = d*length*t*(1-curl*t*.4) + Vector((0, 0, .02 + rise*t + (curl*.12)*t*t))
            rows.append([bm.verts.new(c + side*w*s + Vector((0, 0, abs(s)*w*.35))) for s in (-1, -.4, .4, 1)])
        for i in range(4):
            for j in range(3):
                f = bm.faces.new((rows[i][j], rows[i][j+1], rows[i+1][j+1], rows[i+1][j]))
                for loop in f.loops:
                    g = (1.15 if inner else .7) + .25*(i/4)
                    loop[col] = (g, g, g, 1)
    finish(name, bm, lambda co, n, c: Vector((co.x, co.y, .0)).normalized()*.4 + Vector((0, 0, 1)))


def carrot_tops(name, seed):
    grass(name, seed, blades=7, height=.22)


# ---------------------------------------------------------------- vegetable bed
def plank(bm, center, size, rot=0., shade=1.):
    uv, col = layers(bm)
    before = set(bm.faces)
    res = bmesh.ops.create_cube(bm, size=1)
    m = Matrix.Translation(center) @ Matrix.Rotation(rot, 4, 'Z') @ Matrix.Diagonal((*size, 1))
    bmesh.ops.transform(bm, matrix=m, verts=res['verts'])
    verts = set(res['verts'])
    bmesh.ops.bevel(bm, geom=[e for e in bm.edges if all(v in verts for v in e.verts)], offset=.012, segments=1, affect='EDGES')
    for f in set(bm.faces) - before:
        for loop in f.loops:
            co = loop.vert.co
            loop[uv].uv = ((co.x + co.y)*1.7, co.z*1.7 + co.x*.3)
            loop[col] = (shade,)*3 + (1,)


def vegetable_bed():
    frame_bm = bmesh.new()
    W, D, H = 1.3, 1.7, .22
    for k in (-1, 1):
        for y, h in ((.06, .11), (.17, .11)):
            plank(frame_bm, Vector((k*(W/2 - .045), 0, y)), (.07, D, h), shade=.85 + .15*(y > .1))
            plank(frame_bm, Vector((0, k*(D/2 - .045), y)), (W - .16, .07, h), shade=.9 + .1*(y > .1))
        for j in (-1, 1):
            plank(frame_bm, Vector((k*(W/2 - .05), j*(D/2 - .05), .13)), (.09, .09, .27), shade=.75)
    finish('bedFrame', frame_bm)
    soil = bmesh.new(); uv, col = layers(soil)
    nx, ny = 10, 13
    grid = [[soil.verts.new(Vector(((i/nx - .5)*(W - .14), (j/ny - .5)*(D - .14),
              .17 + .045*abs(math.sin((i/nx)*math.pi*4)) + .012*math.sin(j*1.7 + i))))
             for j in range(ny+1)] for i in range(nx+1)]
    for i in range(nx):
        for j in range(ny):
            f = soil.faces.new((grid[i][j], grid[i+1][j], grid[i+1][j+1], grid[i][j+1]))
            for loop in f.loops:
                loop[uv].uv = (loop.vert.co.x*2, loop.vert.co.y*2)
                g = .75 + 1.6*(loop.vert.co.z - .17); loop[col] = (g, g, g, 1)
    finish('bedSoil', soil)


def stump(seed):
    rng = random.Random(seed)
    bark = bmesh.new()
    rings = tube(bark, [Vector((0, 0, 0)), Vector((0, 0, .25)), Vector((0, 0, .52))], [.36, .3, .28], sides=12, shade=(.55, .95), uv_scale=(1.5, 1.2))
    for k in range(6):
        a = k/6*TAU + rng.uniform(-.25, .25)
        pts = curve(Vector((math.cos(a)*.18, math.sin(a)*.18, .25)), Vector((math.cos(a), math.sin(a), -.8)), .5, 3, droop=.15, rng=rng)
        tube(bark, pts, [.13, .1, .07, .03], sides=6, shade=(.5, .7))
    finish('stumpBark', bark)
    top = bmesh.new(); uv, col = layers(top)
    centre = top.verts.new(Vector((0, 0, .525)))
    ring = [top.verts.new(Vector((math.cos(k/12*TAU)*.28, math.sin(k/12*TAU)*.28, .52))) for k in range(12)]
    for k in range(12):
        f = top.faces.new((centre, ring[k], ring[(k+1) % 12]))
        for loop in f.loops:
            co = loop.vert.co; loop[uv].uv = (co.x*1.8 + .5, co.y*1.8 + .5)
            r = math.hypot(co.x, co.y)/.28; g = .85 + .25*math.cos(r*9)
            loop[col] = (g, g, g, 1)
    finish('stumpTop', top)


oak('oakA', 11); oak('oakB', 23, spread=1.12)
pine('pineA', 5)
for i in range(3): grass(f'grass{i}', 100 + i, segments=2)
for i in range(3): grass(f'turf{i}', 300 + i, blades=15, height=.36, spread=.24, segments=1)
grass('reed', 200, blades=7, height=.75)
bush('bushA', 31); bush('bushB', 47, radius=.42)
flower('flower', 3)
cabbage('cabbage', 9); carrot_tops('carrot', 77)
vegetable_bed(); stump(5)

for o in bpy.data.objects: print('ASSET', o.name, len(o.data.polygons))
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_yup=True, export_normals=True,
                          export_vertex_color='ACTIVE', export_all_vertex_colors=False,
                          export_active_vertex_color_when_no_material=True, export_materials='NONE')
