import * as T from 'three';
import {mergeGeometries} from 'three/addons/utils/BufferGeometryUtils.js';
import {builder} from './modules.js';

// Fruit trees. Every broadleaf tree on the island bears fruit and every pine bears cones: it hangs
// on the outside of the crown, swells and colours over its ripening time (saved as a timestamp,
// so it keeps ripening while the page is closed), and when ripe Unity-chan smacks the trunk, the
// tree sways, the fruit drops and bounces on the grass and she gathers it up. A stump can be
// replanted with any fruit unlocked so far; the island starts with apple trees. Pines only ever
// grow back as pines, so their cones are not in the sapling picker.
// seconds: ripening time; cost: sapling price; sell: coins per fruit; xp: per harvest;
// level: player level that unlocks it.
export const FRUITS=[
  {id:'apple',name:'사과',icon:'🍎',seconds:600,cost:20,sell:4,xp:6,level:1,mesh:'fruitApple',young:'#a7c85a',ripe:'#d4322a'},
  {id:'pear',name:'배',icon:'🍐',seconds:1800,cost:40,sell:9,xp:12,level:2,mesh:'fruitPear',young:'#a9c75c',ripe:'#dcc65a'},
  {id:'peach',name:'복숭아',icon:'🍑',seconds:3600,cost:70,sell:16,xp:20,level:3,mesh:'fruitPeach',young:'#b5cc6a',ripe:'#fbb084'},
  {id:'orange',name:'오렌지',icon:'🍊',seconds:7200,cost:120,sell:28,xp:32,level:4,mesh:'fruitOrange',young:'#7fae48',ripe:'#f28a1e'},
  {id:'lemon',name:'레몬',icon:'🍋',seconds:14400,cost:200,sell:50,xp:50,level:5,mesh:'fruitLemon',young:'#9cc25a',ripe:'#f4dc3c'}
].map(f=>({...f,tree:f.name+'나무'}));
export const PINECONE={id:'pinecone',name:'솔방울',tree:'소나무',icon:'🌰',seconds:900,cost:0,sell:3,xp:4,level:1,
  mesh:'fruitPinecone',young:'#7f9a4c',ripe:'#8d5c33',pine:true};
const ALL=[...FRUITS,PINECONE];
export const fruitById=new Map(ALL.map(f=>[f.id,f]));
export const DEFAULT_FRUIT='apple';
const ease=t=>t*t*(3-2*t);
const clamp01=t=>Math.min(1,Math.max(0,t));

// Fruit meshes, centred on the fruit with the stalk up. Vertex colours carry fixed detail (stalk,
// blush); the instance colour ripens them from green.
function piece(geometry,color=[1,1,1]){
  const g=geometry.index?geometry.toNonIndexed():geometry;
  if(!g.hasAttribute('uv'))g.setAttribute('uv',new T.Float32BufferAttribute(new Float32Array(g.attributes.position.count*2),2));
  const c=new Float32Array(g.attributes.position.count*3);
  for(let i=0;i<c.length;i+=3)c.set(color,i);
  g.setAttribute('color',new T.Float32BufferAttribute(c,3));
  for(const name of Object.keys(g.attributes))if(!['position','normal','uv','color'].includes(name))g.deleteAttribute(name);
  return g;
}
const stalk=(top,length=.07)=>{const g=new T.CylinderGeometry(.006,.009,length,5);g.translate(0,top+length/2-.01,0);return piece(g,[.42,.3,.16])};
function shape(geometry,fn){
  const p=geometry.attributes.position,v=new T.Vector3();
  for(let i=0;i<p.count;i++){v.fromBufferAttribute(p,i);fn(v);p.setXYZ(i,v.x,v.y,v.z)}
  geometry.computeVertexNormals();return geometry;
}
export function fruitKinds(){
  const kinds=new Map(),set=(name,parts)=>{const g=mergeGeometries(parts);g.computeBoundingSphere();kinds.set(name,{geometry:g,material:'petal'})};
  // Apple: round with a dimple at the stalk and a smaller one underneath.
  set('fruitApple',[piece(shape(new T.SphereGeometry(.1,12,9),v=>{
    const r=Math.hypot(v.x,v.z);
    if(v.y>0)v.y-=.035*Math.exp(-((r/.035)**2));else v.y+=.015*Math.exp(-((r/.03)**2));
    v.y*=.9;
  })),stalk(.07)]);
  // Pear: a wide bottom tapering to a neck.
  set('fruitPear',[piece(new T.LatheGeometry([[0,-.1],[.055,-.095],[.082,-.065],[.08,-.015],[.058,.03],[.042,.065],[.026,.095],[0,.105]].map(([r,y])=>new T.Vector2(r,y)),12)),stalk(.1,.05)]);
  // Peach: soft and round with a blushed side.
  {
    const g=piece(shape(new T.SphereGeometry(.095,12,9),v=>{v.y*=.95;const r=Math.hypot(v.x,v.z);if(v.y>0)v.y-=.02*Math.exp(-((r/.03)**2))}));
    const p=g.attributes.position,c=g.attributes.color;
    for(let i=0;i<p.count;i++){const k=clamp01(p.getZ(i)/.095*.8+.3);c.setXYZ(i,1,1-.32*k,1-.36*k)}
    set('fruitPeach',[g,stalk(.075,.04)]);
  }
  // Orange: a plain round fruit with a tiny stalk.
  set('fruitOrange',[piece(shape(new T.SphereGeometry(.1,14,10),v=>{v.y*=.96})),stalk(.09,.03)]);
  // Lemon: an oval with a nub at each end.
  set('fruitLemon',[piece(shape(new T.SphereGeometry(.075,12,9),v=>{
    const u=Math.abs(v.y)/.075,nub=Math.max(0,u-.75)*4;v.y*=1.3+.25*nub*nub;v.x*=1-.25*nub;v.z*=1-.25*nub;
  })),stalk(.11,.03)]);
  // Pine cone: a tapered ovoid hanging tip-down, ringed with rows of scales.
  {
    const rows=18,pts=[];
    for(let i=0;i<=rows;i++){
      const t=i/rows,y=-.1+t*.19,r=.05*Math.pow(Math.sin(Math.PI*Math.pow(t,.75)),.75)*(i%2?.8:1);
      pts.push(new T.Vector2(Math.max(i===0||i===rows?0:.004,r),y));
    }
    set('fruitPinecone',[piece(new T.LatheGeometry(pts,9)),stalk(.085,.03)]);
  }
  return kinds;
}

// Hanging spots on the outside of a crown, from the leaf mesh's own vertices (tree-local).
function slotsFor(geometry,count,seed){
  let s=seed;const rand=()=>((s=(Math.imul(s,1664525)+1013904223)>>>0)/4294967296);
  geometry.computeBoundingBox();const {min,max}=geometry.boundingBox,h=max.y-min.y;
  const cx=(min.x+max.x)/2,cz=(min.z+max.z)/2,p=geometry.attributes.position,v=new T.Vector3();
  // The crown's outline in height bands: only points out at the band's edge are on the outside.
  const BANDS=12,edge=new Float32Array(BANDS),band=y=>Math.min(BANDS-1,Math.floor((y-min.y)/h*BANDS));
  let reach=0;
  for(let i=0;i<p.count;i++){const r=Math.hypot(p.getX(i)-cx,p.getZ(i)-cz),k=band(p.getY(i));edge[k]=Math.max(edge[k],r);reach=Math.max(reach,r)}
  const candidates=[];
  for(let i=0;i<p.count;i++){
    v.fromBufferAttribute(p,i);const r=Math.hypot(v.x-cx,v.z-cz),u=(v.y-min.y)/h;
    if(u>.12&&u<.7&&r>edge[band(v.y)]*.86)candidates.push(v.clone());
  }
  for(let i=candidates.length-1;i>0;i--){const j=Math.floor(rand()*(i+1));[candidates[i],candidates[j]]=[candidates[j],candidates[i]]}
  const out=[];
  for(const c of candidates){
    if(out.length>=count)break;
    // Just inside the outline, so it hangs among the outer leaves.
    const r=Math.hypot(c.x-cx,c.z-cz),pull=Math.max(.6,(r-.05*reach)/r);
    const q=new T.Vector3(cx+(c.x-cx)*pull,c.y,cz+(c.z-cz)*pull);
    if(out.every(o=>o.distanceTo(q)>reach*.32))out.push(q);
  }
  return out;
}

// entries: the saved fruit of each tree ({index: {id, since}}), shared with farm.js's state.
export function createOrchard(scene,world,assets,forestry,entries,save){
  for(const [name,kind] of fruitKinds())assets.set(name,kind);
  const group=new T.Group();group.name='orchard';
  const b=builder(group,8807,assets);
  const trees=forestry.trees.map(tree=>{
    const crown=tree.kind+(tree.pine?'Needles':'Leaves');
    const leaves=tree.parts.find(p=>p.mesh.name===crown),geometry=assets.get(crown)?.geometry;
    if(!leaves||!geometry)return null;
    const local=slotsFor(geometry,Math.round(5+4*tree.s),3301+tree.index*97);
    const slots=local.map(p=>p.applyMatrix4(leaves.base));
    return {tree,slots,turns:slots.map((_,i)=>[(i*.7%1-.5)*.5,i*2.39]),offset:0,drops:null,key:'',kind:null};
  }).filter(Boolean);
  // One batch per fruit kind holding a copy for every slot of every tree; only the tree's own
  // fruit is ever shown.
  let total=0;for(const o of trees){o.offset=total;total+=o.slots.length}
  for(const fruit of ALL)for(const o of trees){
    const {tree}=o;
    o.slots.forEach((p,i)=>{
      const k=.9+((i*37+tree.index*11)%10)/50;
      b.place(tree.x,tree.y,tree.z,1,0,()=>b.canopy(()=>b.part(fruit.mesh,p.x-tree.x,p.y-tree.y,p.z-tree.z,k,k,k,'#ffffff',o.turns[i][0],o.turns[i][1],0)));
    });
  }
  b.finish();scene.add(group);
  const meshes=new Map(ALL.map(f=>{
    const mesh=group.getObjectByName(f.mesh);
    const base=Array.from({length:mesh.count},(_,i)=>{const m=new T.Matrix4();mesh.getMatrixAt(i,m);return m});
    return [f.id,{mesh,base}];
  }));
  const byTree=new Map(trees.map(o=>[o.tree.index,o]));
  const zero=new T.Matrix4().makeScale(0,0,0),m=new T.Matrix4(),scale=new T.Matrix4(),tint=new T.Color(),ripe=new T.Color();
  const pos=new T.Vector3(),quat=new T.Quaternion(),size=new T.Vector3(),spin=new T.Quaternion(),axis=new T.Vector3();
  const dirty=new Set();

  const entry=tree=>{
    let e=entries[tree.index];
    // A pine bears cones, a broadleaf tree fruit; anything else in the save is reset.
    if(!e||!fruitById.has(e.id)||!!fruitById.get(e.id).pine!==!!tree.pine||!Number.isFinite(e.since))
      e=entries[tree.index]={id:tree.pine?PINECONE.id:DEFAULT_FRUIT,since:0};
    return e;
  };
  // Ripeness 0..1: nothing grows on a sapling, and fruit set after planting waits for the tree.
  function info(tree,now=Date.now()){
    const o=byTree.get(tree.index);if(!o)return null;
    const e=entry(tree),fruit=fruitById.get(e.id);
    const growth=tree.state==='growing'?0:clamp01((now-e.since)/1000/fruit.seconds);
    return {fruit,growth,left:Math.max(0,fruit.seconds-(now-e.since)/1000),count:o.slots.length};
  }
  function draw(o,growth,all=false){
    const {tree}=o,id=entry(tree).id,fruit=fruitById.get(id);
    if(all||o.kind!==id){
      for(const [other,{mesh}] of meshes)if(other!==id||all){for(let i=0;i<o.slots.length;i++)mesh.setMatrixAt(o.offset+i,zero);dirty.add(mesh)}
      o.kind=id;
    }
    const {mesh,base}=meshes.get(id);
    const show=growth>.12,k=.3+.7*ease(clamp01((growth-.12)/.75));
    tint.set(fruit.young).lerp(ripe.set(fruit.ripe),T.MathUtils.smoothstep(growth,.55,1));
    for(let i=0;i<o.slots.length;i++){
      const at=o.offset+i,drop=o.drops?.[i];
      if(drop?.started){
        m.compose(drop.p,drop.q,size.setScalar(drop.s));mesh.setMatrixAt(at,m);
      }else if(drop?.gone||!show)mesh.setMatrixAt(at,zero);
      else{m.multiplyMatrices(tree.pose,base[at]).multiply(scale.makeScale(k,k,k));mesh.setMatrixAt(at,m)}
      mesh.setColorAt(at,tint);
    }
    dirty.add(mesh);mesh.instanceColor.needsUpdate=true;
  }
  const api={
    isFruitTree:tree=>byTree.has(tree.index),
    info,
    // Plant a sapling of this fruit; its first crop starts once the tree has grown.
    plant(tree,id,since){entries[tree.index]={id,since};save();const o=byTree.get(tree.index);if(o){o.drops=null;o.key=''}},
    busy:tree=>!!byTree.get(tree.index)?.drops,
    // Knock the ripe fruit loose: each one lets go a moment apart and drops off the crown.
    shake(tree,from){
      const o=byTree.get(tree.index),now=Date.now();if(!o||o.drops||info(tree,now).growth<1)return 0;
      const {base}=meshes.get(entry(tree).id);
      o.drops=o.slots.map((_,i)=>{
        m.multiplyMatrices(tree.pose,base[o.offset+i]);m.decompose(pos,quat,size);
        const out=new T.Vector3(pos.x-tree.x,0,pos.z-tree.z).normalize(),away=new T.Vector3(tree.x-from.x,0,tree.z-from.z).normalize();
        const v=out.multiplyScalar(.35+Math.random()*.5).addScaledVector(away,.25);v.y=.4+Math.random()*.6;
        return {delay:.08+Math.random()*.75,started:false,p:pos.clone(),q:quat.clone(),s:size.x,v,
          spin:new T.Vector3(Math.random()-.5,Math.random()-.5,Math.random()-.5).normalize(),rate:6+Math.random()*6,bounces:0,rest:false,gone:false};
      });
      o.key='';return o.slots.length;
    },
    // Pick the dropped fruit up: their world positions (for the fly-to-counter effect); the tree
    // starts setting its next crop.
    collect(tree,now=Date.now()){
      const o=byTree.get(tree.index);if(!o?.drops)return [];
      const points=o.drops.map((d,i)=>{
        if(d.started)return d.p.clone();
        m.multiplyMatrices(tree.pose,meshes.get(entry(tree).id).base[o.offset+i]);return new T.Vector3().setFromMatrixPosition(m);
      });
      o.drops=null;o.key='';entry(tree).since=now;save();
      return points;
    },
    update(dt,now=Date.now()){
      for(const o of trees){
        const g=info(o.tree,now).growth;
        if(o.drops){
          for(const d of o.drops){
            if(!d.started){d.delay-=dt;if(d.delay<=0)d.started=true;else continue}
            if(d.rest)continue;
            // Free fall with a tumble, then a couple of dying bounces on the ground.
            d.v.y-=9.8*dt;d.p.addScaledVector(d.v,dt);
            d.q.premultiply(spin.setFromAxisAngle(d.spin,d.rate*dt));
            const ground=world.height(d.p.x,d.p.z)+.075*d.s;
            if(d.p.y<ground){
              d.p.y=ground;
              if(d.bounces<2&&d.v.y<-.6){d.v.y*=-.32;d.v.x*=.5;d.v.z*=.5;d.rate*=.5;d.bounces++}
              else{d.rest=true;d.v.set(0,0,0)}
            }
          }
          o.key='';
        }
        const key=o.tree.rev+':'+Math.round(g*400);
        if(key!==o.key||o.kind===null){const all=o.kind===null;o.key=key;draw(o,g,all)}
      }
      for(const mesh of dirty){mesh.instanceMatrix.needsUpdate=true;mesh.computeBoundingSphere()}
      dirty.clear();
    }
  };
  api.update(0);
  return api;
}
