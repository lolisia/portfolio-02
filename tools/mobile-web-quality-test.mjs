import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {mobileTurfGeometry} from '../src/turf-lod.js';

// Profile selection must work without changing desktop defaults or requiring a
// phone to exercise forced same-device A/B comparisons.
let profileImport=0;
async function profile({coarse=false,width=1440,height=1000,search=''}={}){
  Object.assign(globalThis,{location:{search},innerWidth:width,innerHeight:height,
    matchMedia:()=>({matches:coarse})});
  return (await import(`../src/mobile-quality.js?test=${profileImport++}`)).quality;
}
const desktop=await profile();
assert.equal(desktop.mobile,false);
assert.equal(desktop.reflectionScale,1);
assert.equal(desktop.reflectionInterval,0);
assert.equal(desktop.fogScale,.5);
assert.equal(desktop.fogHighSteps+desktop.fogLowSteps,24);
assert.equal(desktop.snowCount,9000);
assert.equal(desktop.trampleSlots,16);
const phone=await profile({coarse:true,width:412,height:915});
assert.equal(phone.mobile,true);
assert.equal((await profile({coarse:true,width:412,height:915,search:'?quality=desktop'})).mobile,false);
assert.equal((await profile({search:'?quality=mobile'})).mobile,true);
assert.equal((await profile({width:412,height:915})).mobile,false);
assert.equal((await profile({coarse:true,width:1400,height:1000})).mobile,false);
assert.equal(phone.sunShadowSize,desktop.sunShadowSize,'retain primary shadow detail');
assert.equal(phone.aoSamples,desktop.aoSamples,'retain contact shading samples');
assert(phone.fogHighSteps>0&&phone.fogLowSteps>0&&phone.fogScale>0);
assert(phone.reflectionInterval<=1/30,'reflection capture must retain at least 30 Hz');

const bytes=await readFile(new URL('../public/models/nature.glb',import.meta.url));
const gltf=await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
const meshes=new Map();gltf.scene.traverse(o=>{if(o.isMesh)meshes.set(o.name,o.geometry)});
const xyz=(attribute,index)=>[attribute.getX(index),attribute.getY(index),attribute.getZ(index)];
const average=(a,b)=>a.map((v,i)=>(v+b[i])/2);
const distance=(a,b)=>Math.hypot(...a.map((v,i)=>v-b[i]));
function triangles(geometry){
  const positions=geometry.getAttribute('position'),out=[];
  for(let i=0;i<geometry.index.count;i+=3)out.push([0,1,2].map(j=>xyz(positions,geometry.index.getX(i+j))));
  return out;
}
function endCenters(geometry,atTop){
  const uv=geometry.getAttribute('uv'),position=geometry.getAttribute('position'),out=[];
  for(let i=0;i<geometry.index.count;i+=3){
    const ends=[0,1,2].map(j=>geometry.index.getX(i+j)).filter(j=>Math.abs(uv.getY(j)-(atTop?0:1))<1e-6);
    if(ends.length===2)out.push(average(...ends.map(j=>xyz(position,j))));
  }
  return out;
}
function samePoints(actual,expected,label){
  assert.equal(actual.length,expected.length,label);
  const unmatched=expected.slice();
  for(const p of actual){
    const i=unmatched.findIndex(q=>distance(p,q)<1e-6);
    assert(i>=0,label);unmatched.splice(i,1);
  }
}
function area(list){
  return list.reduce((sum,[a,b,c])=>{
    const u=b.map((v,i)=>v-a[i]),v=c.map((x,i)=>x-a[i]);
    return sum+Math.hypot(u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0])/2;
  },0);
}
function snapshot(geometry){
  return {index:Array.from(geometry.index.array),attributes:Object.fromEntries(Object.entries(geometry.attributes).map(([name,a])=>[name,Array.from(a.array)]))};
}
for(const name of ['turf0','turf1','turf2']){
  const source=meshes.get(name),before=snapshot(source),reduced=mobileTurfGeometry(source);
  assert.notEqual(reduced,source,name+' must reduce');
  assert.deepEqual(snapshot(source),before,name+' source must stay immutable');
  const original=triangles(source),result=triangles(reduced);
  assert.equal(original.length,48);assert.equal(result.length,12);
  const roots=result.map(tri=>{
    const base=tri.filter(p=>Math.abs(p[1])<1e-6);
    assert.equal(base.length,2,'each blade retains its rooted base');return average(...base);
  });
  const tips=result.map(tri=>tri.reduce((a,b)=>a[1]>b[1]?a:b));
  samePoints(roots,endCenters(source,false),name+' retains all 12 root locations');
  samePoints(tips,endCenters(source,true),name+' retains all 12 blade tips/heights');
  const ratio=area(result)/area(original);
  assert(ratio>.9&&ratio<1.1,name+' retains grass coverage instead of thinning blades');
  for(const attribute of Object.values(reduced.attributes))assert(Array.from(attribute.array).every(Number.isFinite));
}
const unfamiliar=meshes.get('grass0'),unfamiliarBefore=snapshot(unfamiliar);
assert.equal(mobileTurfGeometry(unfamiliar),unfamiliar,'unknown topology must fall back intact');
assert.deepEqual(snapshot(unfamiliar),unfamiliarBefore);
const changed=meshes.get('turf0').clone();changed.deleteAttribute('uv');
assert.equal(mobileTurfGeometry(changed),changed,'assets without expected blade coordinates must fall back');
console.log('mobile web quality: profile selection, desktop detail, real turf blade coverage and safe fallback passed');
