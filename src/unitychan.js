import * as T from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {createFarmPaths} from './farm-paths.js';

// SD Unity-chan © Unity Technologies Japan/UCL — see public/models/unitychan/.
// Gathering / Fishing clips are retargeted from Kevin Iglesias "Human Crafting Animations FREE".
const URL=import.meta.env.BASE_URL+'models/unitychan/sd_unitychan.glb';
const HEIGHT=1.02, RADIUS=.2;
const LOOPS=new Set(['Standing','Walking','Running','Gathering','FishingLoop']);
const BEDS=[[1.1,3.3],[2.7,3.3]], POND={x:10.7,z:6.3};

function toonRamp(){
  const data=new Uint8Array([96,96,96,255, 182,182,182,255, 255,255,255,255]);
  const ramp=new T.DataTexture(data,3,1);ramp.minFilter=ramp.magFilter=T.NearestFilter;ramp.needsUpdate=true;
  return ramp;
}

// Clips come out of the combined Unity take with absolute times and a drifting root;
// rebase them to zero and pin the horizontal root motion so the script owns locomotion.
function tidy(clip){
  let start=Infinity;
  for(const t of clip.tracks)start=Math.min(start,t.times[0]);
  for(const t of clip.tracks){
    // Tracks share one time accessor, so copy before rebasing.
    t.times=t.times.map(v=>v-start);
    if(/(center|Hips)\.position$/.test(t.name)&&LOOPS.has(clip.name)){
      const v=t.values=t.values.slice();for(let i=3;i<v.length;i+=3){v[i]=v[0];v[i+2]=v[2]}
    }
  }
  clip.resetDuration();return clip;
}

// Work spots on the shared path graph, each with a short final step off the graph
// so she stands right at the bed edge or the shoreline.
function findSpots(world,paths){
  const facing=(n,x,z)=>Math.atan2(x-n.x,z-n.z);
  // Step from the nearest graph nodes toward each bed until her body would touch the frame.
  const beds=BEDS.flatMap(([bx,bz])=>paths.nodes
    .map(n=>({n,d:Math.hypot(n.x-bx,n.z-bz)})).sort((a,b)=>a.d-b.d).slice(0,3)
    .map(({n,d})=>{
      let t=0;while(t<d&&!world.colliders.blocked(n.x+(bx-n.x)*(t+.02)/d,n.z+(bz-n.z)*(t+.02)/d,RADIUS+.03))t+=.02;
      return {node:n,x:n.x+(bx-n.x)*t/d,z:n.z+(bz-n.z)*t/d,face:facing(n,bx,bz)};
    }));
  // The north bank is the stretch the default camera sees past the trees; she faces the viewer there.
  const shore=[165,180,195,210,225].map(deg=>{
    const a=deg*Math.PI/180,dx=Math.sin(a),dz=Math.cos(a);
    let t=.5;while(t<7&&world.height(POND.x+dx*t,POND.z+dz*t)<world.waterY+.1)t+=.05;
    const x=POND.x+dx*(t+.15),z=POND.z+dz*(t+.15);
    const node=paths.nodes.reduce((best,n)=>Math.hypot(n.x-x,n.z-z)<Math.hypot(best.x-x,best.z-z)?n:best);
    return {node,x,z,face:Math.atan2(-dx,-dz)};
  });
  return {beds,shore};
}

export function createUnityChan(scene,world,onReady,prints,art){
  const paths=createFarmPaths(world),spots=findSpots(world,paths);
  const {door,apron,threshold,doorLeaf}=world.cottage;
  const root=new T.Group();root.name='sd-unity-chan';root.visible=false;scene.add(root);
  const s={state:'inside',x:door.x,z:door.z,heading:0,route:[],wait:0,pace:0,intent:false,reaction:2,
    rng:90731,action:null,anchor:null,stuck:0,blink:2,blinkT:0,task:null,steps:[],stepTime:0,face:0,prop:null};
  let mixer=null,actions={},face=null,blinkIndex=-1,ready=false,hands=[];
  const body=world.colliders.body(door.x,door.z,RADIUS,3);body.kind='unitychan';
  const random=()=>{s.rng=(Math.imul(s.rng,1664525)+1013904223)>>>0;return s.rng/4294967296};

  // Fishing rod, line and float are simple props kept in world space.
  const rod=new T.Group();rod.visible=false;scene.add(rod);
  const rodLength=1.15,rodGeo=new T.CylinderGeometry(.007,.016,rodLength,6);rodGeo.translate(0,rodLength/2,0);
  const rodMesh=new T.Mesh(rodGeo,new T.MeshStandardMaterial({color:0x6b4a2c,roughness:.7}));rodMesh.castShadow=true;rod.add(rodMesh);
  const lineGeo=new T.BufferGeometry().setAttribute('position',new T.BufferAttribute(new Float32Array(10*3),3));
  const line=new T.Line(lineGeo,new T.LineBasicMaterial({color:0xe9e4d2,transparent:true,opacity:.7}));line.frustumCulled=false;scene.add(line);
  const bobber=new T.Mesh(new T.SphereGeometry(.035,8,6),new T.MeshStandardMaterial({color:0xd84a32,roughness:.5}));scene.add(bobber);
  line.visible=bobber.visible=false;

  new GLTFLoader().load(URL,gltf=>{
    const model=gltf.scene,ramp=toonRamp(),cache=new Map();
    model.traverse(o=>{
      if(/^Character1_(Left|Right)Hand$/.test(o.name))hands.push(o);
      if(!o.isMesh)return;
      o.castShadow=true;o.receiveShadow=true;o.frustumCulled=false;
      const list=(Array.isArray(o.material)?o.material:[o.material]).map(m=>{
        if(!cache.has(m.name)){
          if(m.map)m.map.colorSpace=T.SRGBColorSpace;
          const toon=new T.MeshToonMaterial({name:m.name,map:m.map,gradientMap:ramp,alphaTest:.5,
            side:/hair|nol/.test(m.name)?T.DoubleSide:T.FrontSide});
          cache.set(m.name,art.shade(toon,/face|eye/.test(m.name.toLowerCase())?.18:.50));
        }
        return cache.get(m.name);
      });
      o.material=list.length>1?list:list[0];
      if(o.morphTargetDictionary&&'EYE_blkShape' in o.morphTargetDictionary){face=o;blinkIndex=o.morphTargetDictionary.EYE_blkShape}
    });
    root.add(model);
    mixer=new T.AnimationMixer(model);
    for(const clip of gltf.animations){
      const a=mixer.clipAction(tidy(clip));
      if(!LOOPS.has(clip.name)){a.setLoop(T.LoopOnce,1);a.clampWhenFinished=true}
      actions[clip.name]=a;
    }
    play('Standing',0);mixer.update(0);
    // Measure the posed figure (skinned body + bone-parented head/hair) to fit the diorama.
    const box=new T.Box3();model.updateMatrixWorld(true);box.setFromObject(model,true);
    model.scale.multiplyScalar(HEIGHT/box.getSize(new T.Vector3()).y);
    model.updateMatrixWorld(true);box.setFromObject(model,true);model.position.y-=box.min.y;
    ready=true;onReady();
  },undefined,e=>console.warn('SD Unity-chan failed to load',e));

  function play(name,fade=.3){
    const next=actions[name];if(!next||s.action===next)return;
    next.reset().setEffectiveWeight(1).play();
    if(s.action)s.action.crossFadeTo(next,fade,false);
    s.action=next;
  }
  const length=name=>actions[name]?actions[name].getClip().duration:0;
  // Work spots sit just off the walking graph, so leave them via the node they came from.
  function plan(goal){
    const from=s.anchor||s,route=paths.route(from,goal);
    if(route.length&&s.anchor)route.unshift({x:s.anchor.x,z:s.anchor.z});
    if(route.length)s.anchor=null;
    return route;
  }
  function routeTo(target){
    for(let i=0;i<8;i++){
      const goal=target();if(!goal)return false;
      s.route=plan(goal);if(s.route.length)return goal;
    }
    return false;
  }
  function setTrip(home=false){
    s.task=null;
    if(home){s.route=plan(apron);s.route.push(door,threshold);return}
    const far=random()>.5;
    const candidates=paths.nodes.filter(n=>{
      const r=Math.hypot(n.x-apron.x,n.z-apron.z);
      return r>(far?3.5:1.2)&&r<(far?8.5:4)&&Math.hypot(n.x-s.x,n.z-s.z)>1.2;
    });
    routeTo(()=>candidates[Math.floor(random()*candidates.length)]);
  }
  // Walk to a work spot, then run its clip sequence facing the bed / water.
  function setTask(list,steps,prop=null){
    const spot=list[Math.floor(random()*list.length)];
    if(!spot||!routeTo(()=>spot.node))return false;
    s.route.push({x:spot.x,z:spot.z});s.anchor=spot.node;
    s.task={face:spot.face,steps,prop};return true;
  }
  function begin(steps,faceAngle=s.heading,prop=null){
    s.state='activity';s.steps=steps.slice();s.face=faceAngle;s.prop=prop;s.stepTime=0;nextStep();
  }
  function nextStep(){
    const step=s.steps.shift();
    if(!step){s.state='strolling';s.prop=null;s.wait=1.5+random()*3;play('Standing',.4);setTrip();return}
    play(step.clip,step.fade??.3);s.stepTime=step.time??length(step.clip);
  }
  function chooseNext(){
    const r=random();
    if(r<.3&&setTask(spots.beds,[{clip:'Gathering',time:5+random()*5}]))return;
    const frozen=world.water.userData.freeze.value>.3;
    if(r<.55&&!frozen&&setTask(spots.shore,[{clip:'FishingBegin'},{clip:'FishingLoop',time:12+random()*12,fade:.2},{clip:'FishingStop',fade:.2}],'rod'))return;
    if(r<.75){
      const kneel=random()<.45;
      begin(kneel?[{clip:'KneelDown',fade:.25,time:length('KneelDown')+.2},{clip:'KneelDownToUp',fade:.15}]:[{clip:'Salute',fade:.25}]);
      return;
    }
    s.wait=2+random()*5;setTrip();
  }
  function walk(dt,speed){
    const target=s.route[0];if(!target){s.pace=T.MathUtils.damp(s.pace,0,6,dt);return true}
    const dx=target.x-s.x,dz=target.z-s.z,d=Math.hypot(dx,dz);
    s.pace=T.MathUtils.damp(s.pace,speed,3,dt);
    const step=Math.min(d,dt*s.pace);
    if(d>.001){
      body.x=s.x+dx/d*step;body.z=s.z+dz/d*step;world.colliders.resolve(body);
      const moved=Math.hypot(body.x-s.x,body.z-s.z);
      s.x=body.x;s.z=body.z;
      turn(Math.atan2(dx,dz),dt);
      // Blocked (another walker parked on the waypoint): give up on it after a moment.
      s.stuck=moved<step*.3?s.stuck+dt:0;
      if(s.stuck>1.2){s.stuck=0;s.route.shift()}
    }
    if(d<.05)s.route.shift();
    return s.route.length===0;
  }
  function turn(angle,dt,rate=6){
    s.heading+=Math.atan2(Math.sin(angle-s.heading),Math.cos(angle-s.heading))*(1-Math.exp(-dt*rate));
  }

  const v=new T.Vector3(),w=new T.Vector3(),up=new T.Vector3(0,1,0),dir=new T.Vector3(),fwd=new T.Vector3(),tip=new T.Vector3(),q=new T.Quaternion();
  function updateRod(seconds){
    const show=s.prop==='rod'&&root.visible&&hands.length===2;
    rod.visible=show;
    const casting=show&&s.action===actions.FishingLoop;
    line.visible=bobber.visible=casting;
    if(!show)return;
    hands[0].getWorldPosition(v);hands[1].getWorldPosition(w);v.add(w).multiplyScalar(.5);
    fwd.set(Math.sin(s.heading),0,Math.cos(s.heading));
    dir.copy(fwd).multiplyScalar(.72).addScaledVector(up,.62+.03*Math.sin(seconds*1.7)).normalize();
    rod.position.copy(v).addScaledVector(fwd,.04);rod.quaternion.copy(q.setFromUnitVectors(up,dir));
    if(!casting)return;
    tip.copy(rod.position).addScaledVector(dir,rodLength);
    bobber.position.set(s.x+fwd.x*2.1,world.waterY+.012+.01*Math.sin(seconds*2.3),s.z+fwd.z*2.1);
    const pos=lineGeo.attributes.position;
    for(let i=0;i<10;i++){
      const u=i/9;w.lerpVectors(tip,bobber.position,u);w.y-=Math.sin(Math.PI*u)*.18;pos.setXYZ(i,w.x,w.y,w.z);
    }
    pos.needsUpdate=true;
  }

  // The front door swings out when she comes or goes and falls shut behind her.
  let doorOpen=0,doorWant=0;
  function swingDoor(dt){
    const rate=doorWant>doorOpen?1.6:1.15;
    doorOpen=doorWant>doorOpen?Math.min(doorWant,doorOpen+dt*rate):Math.max(doorWant,doorOpen-dt*rate);
    // ease out on opening; closing speeds up and lands with a small rebound off the jamb
    const k=doorWant>=doorOpen?1-(1-doorOpen)**2:doorOpen**1.6;
    doorLeaf.rotation.y=-1.68*k+(doorWant===0&&doorOpen<.06?.025*Math.sin(doorOpen/.06*Math.PI):0);
    doorLeaf.userData.open=doorOpen;
  }
  // Footprints: one print per stride, alternating feet either side of her path.
  let strideLeft=0,foot=1;
  function trackFeet(moved,running){
    strideLeft-=moved;
    if(strideLeft>0)return;
    strideLeft=running?.3:.19;foot=-foot;
    const h=s.heading;
    prints?.press('boot',s.x+Math.cos(h)*foot*.055+Math.sin(h)*.04,s.z-Math.sin(h)*foot*.055+Math.cos(h)*.04,h);
  }
  const inDoorway=()=>Math.abs(s.x-threshold.x)<.45&&s.z<door.z+.08;
  return (dt,seconds,hour,weather,wind)=>{
    if(!ready)return;
    swingDoor(dt);
    // Light snow does not keep her in; rain, fog, a blizzard or a gale do.
    const outside=hour>=7&&hour<19&&(weather<=1||weather===4)&&wind<11;
    if(s.intent!==outside&&s.reaction<=0)s.reaction=2+random()*5;
    s.reaction=Math.max(0,s.reaction-dt);
    const want=s.reaction===0?outside:s.intent;s.intent=want;

    if(s.state==='inside'){
      root.visible=false;
      if(want){s.state='opening';doorWant=1}
      else doorWant=0;
    }else if(s.state==='opening'){
      // Step out once the door is most of the way open.
      if(!want){s.state='inside';doorWant=0}
      else if(doorOpen>.55){s.state='exiting';s.x=threshold.x;s.z=threshold.z;s.heading=0;s.route=[door,apron];s.pace=0;root.visible=true;play('Walking',0);
        root.position.set(s.x,world.stand(s.x,s.z),s.z);root.rotation.y=0}
    }else{
      if(!want&&s.state!=='returning'){s.state='returning';s.wait=0;s.prop=null;s.steps=[];setTrip(true)}
      let moving=false,speed=.62;
      if(s.state==='activity'){
        turn(s.face,dt,4);
        s.stepTime-=dt;if(s.stepTime<=0)nextStep();
      }else if(s.wait>0){s.wait-=dt;s.pace=T.MathUtils.damp(s.pace,0,6,dt)}
      else if(s.state==='exiting'){
        moving=true;
        if(Math.hypot(s.x-threshold.x,s.z-threshold.z)>.62)doorWant=0;
        if(walk(dt,speed)){s.state='strolling';s.wait=1+random()*2;setTrip()}
      }
      else if(s.state==='returning'){
        speed=weather>=2?1.45:.75;moving=true;
        // Reach for the door a few steps out, so it is open by the time she gets there.
        if(Math.hypot(s.x-door.x,s.z-door.z)<1.15&&s.route.length<=2)doorWant=1;
        if(walk(dt,speed)){s.state='inside';root.visible=false;body.active=false;s.pace=0;play('Standing',0);doorWant=0}
      }else if(s.state==='strolling'){
        moving=true;
        if(walk(dt,speed)){
          moving=false;
          if(s.task){const {steps,face:f,prop}=s.task;s.task=null;begin(steps,f,prop)}
          else chooseNext();
        }
      }
      if(s.state!=='activity'){
        if(moving&&s.pace>.05){
          const running=s.pace>1.1;play(running?'Running':'Walking',.25);
          s.action.timeScale=s.pace/(running?1.7:.62);
        }else{play('Standing',.35);if(s.action)s.action.timeScale=1}
      }else if(s.action)s.action.timeScale=1;
      // Standing still she is still solid: chickens bump off her and she never ends inside a prop.
      body.active=root.visible;body.x=s.x;body.z=s.z;body.ignore=inDoorway()?'house':'';world.colliders.resolve(body);
      if(s.state!=='activity'){s.x=body.x;s.z=body.z;trackFeet(Math.hypot(s.x-(s.px??s.x),s.z-(s.pz??s.z)),s.pace>1.1)}
      s.px=s.x;s.pz=s.z;
      root.position.set(s.x,world.stand(s.x,s.z),s.z);root.rotation.y=s.heading;
    }
    mixer.update(dt);
    updateRod(seconds);
    // Blink on a loose rhythm so the face never freezes.
    if(face){
      s.blink-=dt;
      if(s.blink<=0){s.blinkT=.16;s.blink=2.2+random()*3.5}
      s.blinkT=Math.max(0,s.blinkT-dt);
      face.morphTargetInfluences[blinkIndex]=Math.sin(Math.PI*s.blinkT/.16);
    }
  };
}
