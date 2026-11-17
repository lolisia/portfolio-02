import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {OrthographicCamera} from 'three';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {attachMapControls} from '../src/map-controls.js';

// A small DOM event fixture, with capture before bubble listeners, runs the real
// OrbitControls camera math without a WebGL context or a lingering test server.
class Target{
  listeners=new Map();
  addEventListener(type,fn,options={}){
    const capture=options===true||Boolean(options.capture),list=this.listeners.get(type)||[];
    if(!list.some(x=>x.fn===fn&&x.capture===capture))list.push({fn,capture});
    this.listeners.set(type,list);
  }
  removeEventListener(type,fn,options={}){
    const capture=options===true||Boolean(options.capture);
    this.listeners.set(type,(this.listeners.get(type)||[]).filter(x=>x.fn!==fn||x.capture!==capture));
  }
  deliver(event,capture){
    event.currentTarget=this;
    for(const listener of [...(this.listeners.get(event.type)||[])]){
      if(listener.capture!==capture)continue;
      listener.fn(event);if(event.immediateStopped)break;
    }
  }
}
function fixture(){
  const doc=new Target(),canvas=new Target(),win=new Target();
  const frames=new Map();let frameId=0;
  win.requestAnimationFrame=fn=>{frames.set(++frameId,fn);return frameId};
  win.cancelAnimationFrame=id=>frames.delete(id);
  Object.assign(globalThis,{window:win,document:doc,
    requestAnimationFrame:win.requestAnimationFrame,cancelAnimationFrame:win.cancelAnimationFrame});
  Object.assign(canvas,{ownerDocument:doc,style:{},clientWidth:400,clientHeight:800,
    getBoundingClientRect:()=>({left:0,top:0,width:400,height:800}),
    setPointerCapture(){},releasePointerCapture(){},hasPointerCapture:()=>true,getRootNode:()=>doc});
  doc.defaultView=win;
  const camera=new OrthographicCamera(-10,10,20,-20,.1,180);
  camera.position.set(15,20,25);camera.lookAt(0,0,0);camera.updateMatrixWorld();
  const controls=new OrbitControls(camera,canvas);
  controls.minZoom=.7;controls.maxZoom=10;
  controls.minPolarAngle=.35;controls.maxPolarAngle=1.18;
  let pans=0;
  const detach=attachMapControls(controls,canvas,()=>pans++);
  function event(type,id,x,y,extra={}){
    const e={type,pointerId:id,pointerType:'touch',clientX:x,clientY:y,pageX:x,pageY:y,
      button:0,buttons:type==='pointerup'||type==='pointercancel'?0:1,
      target:canvas,cancelable:true,preventDefault(){this.defaultPrevented=true},
      stopPropagation(){this.propagationStopped=true},
      stopImmediatePropagation(){this.immediateStopped=true;this.propagationStopped=true},...extra};
    // Document capture also receives events before canvas handlers, just as in
    // the browser. Native OrbitControls listens for mouse moves on the document.
    for(const target of [win,doc,canvas]){target.deliver(e,true);if(e.propagationStopped)break;}
    if(!e.propagationStopped)for(const target of [canvas,doc,win]){target.deliver(e,false);if(e.propagationStopped)break;}
    controls.update();camera.updateMatrixWorld();return e;
  }
  function flush(){
    const pending=[...frames.values()];frames.clear();pending.forEach(fn=>fn(performance.now()));
    controls.update();camera.updateMatrixWorld();
  }
  return {camera,controls,event,flush,get pans(){return pans},close(){if(typeof detach==='function')detach();controls.dispose()}};
}
const near=(a,b,label)=>assert(Math.abs(a-b)<1e-6,label);
const pose=f=>({position:f.camera.position.clone(),target:f.controls.target.clone(),
  yaw:f.controls.getAzimuthalAngle(),pitch:f.controls.getPolarAngle(),zoom:f.camera.zoom});
function noPan(f,before,label){
  assert.equal(f.pans,0,label+' must not turn off tracking');
  assert(f.controls.target.distanceTo(before.target)<1e-6,label+' must not pan the map');
}
function test(run){const f=fixture();try{run(f)}finally{f.close()}}

test(f=>{
  const before=pose(f);
  f.event('pointerdown',1,100,100);f.event('pointermove',1,102,101);f.flush();f.event('pointerup',1,102,101);
  noPan(f,before,'tap');
  f.event('pointerdown',2,100,100);f.event('pointermove',2,140,100);f.flush();f.event('pointermove',2,175,120);f.flush();f.event('pointerup',2,175,120);
  assert.equal(f.pans,1,'one-finger pan notifies once per gesture');
  assert(f.controls.target.distanceTo(before.target)>.1,'one-finger drag moves actual camera target');
  assert(f.camera.position.clone().sub(before.position).distanceTo(f.controls.target.clone().sub(before.target))<1e-6,'pan preserves orbit offset');
});
test(f=>{
  const before=pose(f);
  f.event('pointerdown',1,100,100);f.event('pointerdown',2,200,100);
  f.event('pointermove',1,130,100);f.event('pointermove',2,230,100);
  f.flush();
  noPan(f,before,'two-finger horizontal translation');
  near(f.controls.getAzimuthalAngle(),before.yaw,'centroid translation must not rotate yaw');
  f.event('pointerup',1,130,100);f.event('pointerup',2,230,100);
});
test(f=>{
  const before=pose(f);
  f.event('pointerdown',1,130,100);f.event('pointerdown',2,230,100);
  for(let y=101;y<=140;y++){
    f.event('pointermove',1,130,y);f.event('pointermove',2,230,y);f.flush();
  }
  noPan(f,before,'two-finger vertical translation');
  assert(Math.abs(f.controls.getPolarAngle()-before.pitch)>.01,'two-finger vertical translation tilts view');
  f.event('pointerup',2,230,140);
  const remaining=pose(f);
  f.event('pointermove',1,180,170);f.flush();f.event('pointerup',1,180,170);
  noPan(f,before,'two-to-one transition');
  assert(f.camera.position.distanceTo(remaining.position)<1e-6,'remaining finger must not jump camera');
});
test(f=>{
  const before=pose(f);
  f.event('pointerdown',1,100,100);f.event('pointerdown',2,200,100);
  f.event('pointermove',1,75,100);f.event('pointermove',2,225,100);
  f.flush();
  noPan(f,before,'pinch');
  assert(f.camera.zoom>before.zoom,'spreading fingers zooms in');
  f.event('pointerup',1,75,100);f.event('pointerup',2,225,100);
});
test(f=>{
  const before=pose(f);
  f.event('pointerdown',1,100,100);f.event('pointerdown',2,200,100);
  f.event('pointermove',1,150,50);f.event('pointermove',2,150,150);
  f.flush();
  noPan(f,before,'twist');
  assert(Math.abs(f.controls.getAzimuthalAngle()-before.yaw)>.3,'twist rotates yaw with a stationary centroid');
  near(f.camera.zoom,before.zoom,'pure twist retains zoom');
  f.event('pointercancel',1,150,50);const cancelled=pose(f);
  f.event('pointermove',2,170,190);f.flush();f.event('pointercancel',2,170,190);
  noPan(f,before,'cancelled two-finger gesture');
  assert(f.camera.position.distanceTo(cancelled.position)<1e-6,'cancelled gesture must not jump camera');
  f.event('pointerdown',3,100,100);f.event('pointermove',3,140,100);f.flush();f.event('pointerup',3,140,100);
  assert.equal(f.pans,1,'fresh single-finger gesture works after cancellation');
});
test(f=>{
  const before=pose(f),mouse={pointerType:'mouse',button:0};
  f.event('pointerdown',1,100,100,mouse);f.event('pointermove',1,140,100,mouse);f.event('pointerup',1,140,100,mouse);
  assert.equal(f.pans,1,'PC left drag pans and turns off tracking once');
  assert(f.controls.target.distanceTo(before.target)>.1,'PC left drag changes target');
  const afterPan=pose(f),right={pointerType:'mouse',button:2,buttons:2};
  f.event('pointerdown',2,100,100,right);f.event('pointermove',2,150,120,right);f.event('pointerup',2,150,120,right);
  assert.equal(f.pans,1,'PC right rotation retains tracking');
  assert(f.controls.target.distanceTo(afterPan.target)<1e-6,'PC right drag preserves target');
  assert(Math.abs(f.controls.getAzimuthalAngle()-afterPan.yaw)>.01,'PC right drag rotates camera');
});
test(f=>{
  const before=pose(f);
  f.event('pointerdown',1,100,100);f.event('pointermove',1,150,100);
  f.event('pointercancel',1,150,100);f.flush();
  noPan(f,before,'cancel before queued pan');
  assert(f.camera.position.distanceTo(before.position)<1e-6,'cancel discards pending motion');
});

// Execute the application's actual reset body, rather than copying its reset
// algorithm into the test. Pending OrbitControls damping must stay gone after
// the reset and through subsequent animation frames.
const main=await readFile(new URL('../src/main.js',import.meta.url),'utf8');
const homeFunction=main.match(/^function home\(\)\{([\s\S]*?)\}\r?\nhome\(\);/m);
assert(homeFunction,'application home entrypoint must be available');
test(f=>{
  const followCharacter={checked:true};
  const home=Function('controls','camera','followCharacter',`return function home(){${homeFunction[1]}}`)(f.controls,f.camera,followCharacter);
  f.controls.enableDamping=true;
  f.controls.pan(80,30);f.controls.rotateLeft(.4);f.controls.rotateUp(.1);
  f.camera.zoom=4;f.camera.updateProjectionMatrix();
  home();
  assert.equal(followCharacter.checked,false,'home disables character tracking');
  assert.equal(f.controls.enableDamping,true,'home preserves configured damping');
  function assertHome(){
    [0,1,0].forEach((v,i)=>near(f.controls.target.getComponent(i),v,'home target must remain fixed'));
    [31,34,41].forEach((v,i)=>near(f.camera.position.getComponent(i),v,'home camera must remain fixed'));
    near(f.camera.zoom,1,'home restores zoom');
  }
  assertHome();
  for(let frame=0;frame<120;frame++)f.controls.update();
  assertHome();
});
console.log('map controls: tap, pan, pinch, twist, tilt, pointer transitions, PC mappings and stable home reset passed');
