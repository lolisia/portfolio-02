import * as T from 'three';
import {quality} from './mobile-quality.js';

// The "living" graphics style: one coherent wind field (also used by the foliage vertex
// shader in surfaces.js), cherry petals falling from the canopy, sunlit dust motes and a
// warmer cottage window. Everything is created once and faded in/out so toggling the style
// neither recompiles materials nor leaves anything behind.

function petalGeometry(){
  // A small notched petal: eight rim points around a raised centre, matching the seasonal
  // petal silhouette but its own geometry so the two systems can be tuned separately.
  const s=.5,geometry=new T.BufferGeometry();
  geometry.setAttribute('position',new T.Float32BufferAttribute([
    0,0,-1, -.53*s,.12,-.46, -.72*s,.15,.20, -.31*s,.19,.72, 0,.10,.78,
    .35*s,.17,.76, .70*s,.05,.19, .47*s,.06,-.49, 0,.27,0],3));
  const indices=[];for(let i=0;i<8;i++)indices.push(i,(i+1)%8,8);
  geometry.setIndex(indices);geometry.computeVertexNormals();return geometry;
}

function softDisc(size,stops){
  const canvas=document.createElement('canvas');canvas.width=canvas.height=size;
  const ctx=canvas.getContext('2d'),grad=ctx.createRadialGradient(size/2,size/2,0,size/2,size/2,size/2);
  for(const [at,color] of stops)grad.addColorStop(at,color);
  ctx.fillStyle=grad;ctx.fillRect(0,0,size,size);
  const map=new T.CanvasTexture(canvas);map.colorSpace=T.SRGBColorSpace;return map;
}

// Stable per-system random stream: petals and motes keep their layout between reloads.
function makeRand(seed){
  return()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);
}

export function createLivingEnvironment({scene,world,atmosphere}){
  const state={target:0,value:0};
  const petals=createPetals(scene,world);
  const dust=createDust(scene,world);
  const warmth=createWindowWarmth(scene,world);
  const windDir=new T.Vector2(1,.36).normalize();
  let disposed=false;

  function update(dt,seconds,windSpeed,night,season=1,weather=0){
    if(disposed)return false;
    // Fade the whole style in/out; a 1s ramp avoids petals popping on a style switch.
    const previous=state.value;
    state.value=T.MathUtils.damp(state.value,state.target,2.6,Math.min(dt,.1));
    if(state.target>0&&state.value>.995)state.value=1;
    if(state.target===0&&state.value<.005)state.value=0;
    const amount=state.value;
    // One slowly turning wind direction for foliage, petals and dust. The slider still sets
    // the power, with a small breeze floor so leaves breathe when the weather is calm.
    const angle=.55+Math.sin(seconds*.018)*.42+Math.sin(seconds*.047)*.14;
    windDir.set(Math.cos(angle),Math.sin(angle));
    const power=amount>.001?T.MathUtils.clamp(windSpeed/7,0,1)*.86+.10:0;
    atmosphere.living.value=amount;
    atmosphere.windDir.value.copy(windDir);
    atmosphere.windPower.value=power;
    // Blossom falls with its season; snow and heavy rain thin the airborne dust.
    const petalScale=[1,1,.55,.12][season]??1;
    const dustScale=(season===3?.4:1)*(weather===2||weather>=4?.5:1);
    petals.update(amount,dt,seconds,windDir,power,petalScale);
    dust.update(amount,dt,seconds,windDir,power,dustScale);
    warmth.update(amount,seconds,night);
    return Math.abs(state.value-previous)>.0005;
  }

  function setEnabled(on){state.target=on?1:0}

  function dispose(){
    if(disposed)return;
    disposed=true;
    petals.dispose();dust.dispose();warmth.dispose();
  }

  return {update,setEnabled,dispose,state};
}

function createPetals(scene,world){
  const count=quality.mobile?70:150,rand=makeRand(1364909323);
  const mesh=new T.InstancedMesh(petalGeometry(),
    new T.MeshStandardMaterial({side:T.DoubleSide,roughness:.8,metalness:0}),count);
  mesh.name='living-petals';mesh.frustumCulled=false;mesh.visible=false;mesh.castShadow=false;
  scene.add(mesh);
  const palette=[0xffb6c9,0xffc9d7,0xf39ab2,0xffe1e8,0xf7adc2].map(c=>new T.Color(c));
  const pose=new T.Object3D(),items=[];
  // Emit from the tree crowns, plus the balcony and the flower garden so the middle of the
  // diorama (where the camera starts) gets a few petals of its own.
  const emitters=world.trees.map(t=>({x:t.x,z:t.z,y:t.y+3.2*t.s,spread:.72*t.s,top:1.2*t.s}));
  const balcony=new T.Vector3(world.cottage.window.x,world.cottage.window.y+.8,world.cottage.window.z-.25);
  emitters.push({x:balcony.x,z:balcony.z,y:balcony.y,spread:.7,top:.5});
  const bed=world.flowerBeds?.[0]??{x:-1.1,z:-7.65,y:1.6};
  emitters.push({x:bed.x,z:bed.z,y:bed.y+1.3,spread:1,top:.5});

  const floorAt=(x,z)=>Math.max(world.waterY+.05,world.height(x,z));
  function spawn(item,initial){
    const emitter=rand()<.26?emitters[emitters.length-1-Math.floor(rand()*2)]:emitters[Math.floor(rand()*world.trees.length)];
    const a=rand()*6.283,r=Math.sqrt(rand())*emitter.spread;
    item.x=emitter.x+Math.cos(a)*r;
    item.z=emitter.z+Math.sin(a)*r;
    const top=emitter.y+emitter.top*rand();
    item.y=initial?T.MathUtils.lerp(floorAt(item.x,item.z)+.2,top,rand()):top;
    item.life=7+rand()*7;
    item.age=initial?rand()*item.life:0;
    item.fall=.10+rand()*.10;
    item.drift=.35+rand()*.6;
    item.sway=.14+rand()*.22;
    item.phase=rand()*6.283;
    item.tumble=.55+rand()*1.25;
    item.size=.075+rand()*.045;
    item.tint=Math.floor(rand()*palette.length);
  }
  for(let i=0;i<count;i++){
    const item={};spawn(item,true);items.push(item);
    mesh.setColorAt(i,palette[item.tint]);
  }
  mesh.instanceColor.needsUpdate=true;
  return {update(amount,dt,time,windDir,power,scale=1){
    mesh.visible=amount>.002;
    if(!mesh.visible)return;
    mesh.count=Math.max(1,Math.round(count*scale));
    for(let i=0;i<count;i++){
      const p=items[i],wobble=p.age*.85+p.phase;
      p.age+=dt;
      p.x+=dt*(windDir.x*power*p.drift*2.3+Math.sin(wobble)*p.sway);
      p.z+=dt*(windDir.y*power*p.drift*2.3+Math.cos(wobble*.83)*p.sway);
      p.y-=dt*p.fall*(1+.34*Math.sin(p.age*.9+p.phase));
      const floor=floorAt(p.x,p.z);
      if(p.x>15.2||p.x<-15.2||p.z>15.2||p.z<-15.2||p.y<floor+.04||p.age>p.life)spawn(p,false);
      // Scale in/out instead of per-instance alpha: no sorting cost, no visible popping.
      const fade=Math.min(1,T.MathUtils.smoothstep(p.age,0,.55))*T.MathUtils.smoothstep(p.life-p.age,0,.85);
      const tumble=p.age*p.tumble+p.phase;
      pose.position.set(p.x,p.y,p.z);
      pose.rotation.set(Math.sin(tumble)*1.25,tumble*.7,Math.cos(tumble*.72)*1.1);
      pose.scale.setScalar(p.size*fade*(.9+.2*Math.sin(p.phase))*Math.min(1,amount*1.15));
      pose.updateMatrix();mesh.setMatrixAt(i,pose.matrix);
    }
    mesh.instanceMatrix.needsUpdate=true;
  },dispose(){
    scene.remove(mesh);mesh.geometry.dispose();mesh.material.dispose();
  }};
}

function createDust(scene,world){
  const count=quality.mobile?90:200,rand=makeRand(795810733);
  const positions=new Float32Array(count*3),items=[];
  const map=softDisc(64,[[0,'rgba(255,250,238,.9)'],[.23,'rgba(255,246,226,.5)'],[.62,'rgba(255,242,220,.12)'],[1,'rgba(255,240,215,0)']]);
  const geometry=new T.BufferGeometry();
  geometry.setAttribute('position',new T.BufferAttribute(positions,3));
  const material=new T.PointsMaterial({map,color:0xfff3dc,size:quality.mobile?2.1:2.7,sizeAttenuation:false,
    transparent:true,opacity:0,depthWrite:false,blending:T.NormalBlending,toneMapped:false});
  const points=new T.Points(geometry,material);
  points.name='living-dust';points.frustumCulled=false;points.visible=false;scene.add(points);
  for(let i=0;i<count;i++){
    const item={x:rand()*28-14,z:rand()*28-14,phase:rand()*6.283,
      bob:.1+rand()*.26,rise:.008+rand()*.020,size:.5+rand()*.8};
    item.y=Math.max(world.waterY+.3,world.height(item.x,item.z)+.4)+rand()*3.8;
    items.push(item);positions[i*3]=item.x;positions[i*3+1]=item.y;positions[i*3+2]=item.z;
  }
  geometry.attributes.position.needsUpdate=true;
  let seconds=0;
  return {update(amount,dt,time,windDir,power,scale=1){
    points.visible=amount>.004;
    if(!points.visible)return;
    geometry.setDrawRange(0,Math.max(1,Math.round(count*scale)));
    seconds+=dt;material.opacity=.12*amount;
    for(let i=0;i<count;i++){
      const d=items[i];
      d.x+=dt*(windDir.x*power*.22+Math.sin(seconds*.31+d.phase)*.035);
      d.z+=dt*(windDir.y*power*.22+Math.cos(seconds*.27+d.phase)*.03);
      d.y+=dt*d.rise+Math.sin(seconds*.53+d.phase)*dt*.02;
      if(d.x>14.5)d.x=-14.5;else if(d.x<-14.5)d.x=14.5;
      if(d.z>14.5)d.z=-14.5;else if(d.z<-14.5)d.z=14.5;
      if(d.y>6.4)d.y=Math.max(world.waterY+.4,world.height(d.x,d.z)+.4);
      const bob=Math.sin(seconds*.36+d.phase)*d.bob;
      positions[i*3]=d.x;positions[i*3+1]=d.y+bob;positions[i*3+2]=d.z;
    }
    geometry.attributes.position.needsUpdate=true;
  },dispose(){
    scene.remove(points);geometry.dispose();material.dispose();map.dispose();
  }};
}

function createWindowWarmth(scene,world){
  const map=softDisc(128,[[0,'rgba(255,226,184,.95)'],[.18,'rgba(255,196,126,.6)'],[.45,'rgba(255,170,92,.18)'],[1,'rgba(255,150,70,0)']]);
  const windowPosition=world.cottage.window;
  const glow=new T.Sprite(new T.SpriteMaterial({map,color:0xffbd78,transparent:true,opacity:0,
    blending:T.AdditiveBlending,depthWrite:false,toneMapped:false}));
  glow.name='living-window-glow';glow.position.set(windowPosition.x,windowPosition.y+.02,windowPosition.z+.34);
  glow.scale.set(2.1,1.45,1);scene.add(glow);
  const upper=new T.Sprite(new T.SpriteMaterial({map,color:0xffc98c,transparent:true,opacity:0,
    blending:T.AdditiveBlending,depthWrite:false,toneMapped:false}));
  // The gable door onto the balcony; a fainter, smaller spill than the porch windows.
  upper.position.set(windowPosition.x,windowPosition.y+1.05,windowPosition.z+.18);
  upper.scale.set(1.25,.95,1);scene.add(upper);
  // One extra unshadowed point light: the interior's porch light still does the main work,
  // this only warms the balcony plants and railings around the window.
  const spill=new T.PointLight(0xffb066,0,5.5,2);
  spill.position.set(windowPosition.x,windowPosition.y+.15,windowPosition.z+.5);
  scene.add(spill);
  const color=new T.Color(0xffb066);
  return {update(amount,seconds,night){
    const breath=1+.018*Math.sin(seconds*1.27)+.008*Math.sin(seconds*3.61);
    const warm=amount*breath;
    glow.material.opacity=(.075+.30*night)*warm;
    upper.material.opacity=(.045+.20*night)*warm;
    glow.visible=warm>.002;upper.visible=warm>.002;
    spill.intensity=(.25+3.1*night)*warm;
    spill.color.copy(color);
  },dispose(){
    scene.remove(glow,upper,spill);
    glow.material.dispose();upper.material.dispose();map.dispose();
  }};
}
