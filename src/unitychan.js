import * as T from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {createFarmPaths} from './farm-paths.js';

// SD Unity-chan © Unity Technologies Japan/UCL — see public/models/unitychan/.
// Gathering / Fishing / Chopping clips are retargeted from Kevin Iglesias "Human Crafting Animations FREE"
// (Chopping is its one-handed "Mining - Ground" swing, played with an axe in her right hand).
const URL=import.meta.env.BASE_URL+'models/unitychan/sd_unitychan.glb';
const HEIGHT=1.02, RADIUS=.2;
// Chopping: fraction of the swing where the blade lands (the hand's sharp drop, sampled from the clip).
const IMPACT=.41;

const LOOPS=new Set(['Standing','Walking','Running','Gathering','FishingLoop','Chopping']);
const POND={x:10.7,z:6.3};

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

// Fishing spots all round the pond bank, each facing the water.
function shoreSpots(world){
  const list=[];
  for(let deg=0;deg<360;deg+=12){
    const a=deg*Math.PI/180,dx=Math.sin(a),dz=Math.cos(a);
    let t=.5;while(t<7&&world.height(POND.x+dx*t,POND.z+dz*t)<world.waterY+.1)t+=.05;
    const x=POND.x+dx*(t+.15),z=POND.z+dz*(t+.15);
    if(t>=7||Math.abs(x)>14.2||Math.abs(z)>14.2||world.colliders.blocked(x,z,RADIUS))continue;
    list.push({x,z,face:Math.atan2(-dx,-dz)});
  }
  return list;
}

// SD Unity-chan is player-driven: she steps out of the cottage once, then waits for orders.
// walkTo() sends her somewhere; tend() and fish() queue a job that only completes (onDone)
// after she has walked there and played its animation through. Jobs run one at a time in the
// order given; walking away cancels whatever is pending (onCancel).
export function createUnityChan(scene,world,onReady,prints,art){
  const paths=createFarmPaths(world,{island:true}),shore=shoreSpots(world);
  const {door,apron,threshold,doorLeaf}=world.cottage;
  const root=new T.Group();root.name='sd-unity-chan';root.visible=false;scene.add(root);
  const s={state:'inside',x:door.x,z:door.z,heading:0,route:[],pace:0,speed:.75,
    rng:90731,action:null,stuck:0,blink:2,blinkT:0,steps:[],stepTime:0,face:0,prop:null};
  let mixer=null,actions={},face=null,blinkIndex=-1,ready=false,hands=[];const fingers={};
  const jobs=[];let job=null;
  const body=world.colliders.body(door.x,door.z,RADIUS,3);body.kind='unitychan';
  // Where she is: the island (walking graph, colliders, footprints) or a room (room.js), which
  // supplies its own route, collision, floor and scene.
  const island={route:(a,b)=>paths.route(a,b),resolve:b=>world.colliders.resolve(b),stand:(x,z)=>world.stand(x,z),
    walkable:(x,z)=>world.walkable(x,z),closest:p=>paths.closest(p),scene};
  let place=island,stayIn=false,homing=null;
  const roomBody={x:0,z:0,r:RADIUS,mass:3,active:true,ignore:''};
  const solid=()=>place===island?body:roomBody;
  root.rotation.order='YXZ';
  const random=()=>{s.rng=(Math.imul(s.rng,1664525)+1013904223)>>>0;return s.rng/4294967296};

  // Fishing rod, line and float are simple props kept in world space.
  const rod=new T.Group();rod.visible=false;scene.add(rod);
  const rodLength=1.15,rodGeo=new T.CylinderGeometry(.007,.016,rodLength,6);rodGeo.translate(0,rodLength/2,0);
  const rodMesh=new T.Mesh(rodGeo,new T.MeshStandardMaterial({color:0x6b4a2c,roughness:.7}));rodMesh.castShadow=true;rod.add(rodMesh);
  const lineGeo=new T.BufferGeometry().setAttribute('position',new T.BufferAttribute(new Float32Array(10*3),3));
  const line=new T.Line(lineGeo,new T.LineBasicMaterial({color:0xe9e4d2,transparent:true,opacity:.7}));line.frustumCulled=false;scene.add(line);
  const bobber=new T.Mesh(new T.SphereGeometry(.035,8,6),new T.MeshStandardMaterial({color:0xd84a32,roughness:.5}));scene.add(bobber);
  line.visible=bobber.visible=false;
  // Felling axe: an ash handle with a steel head, held in her right hand.
  const axe=new T.Group();axe.visible=false;scene.add(axe);
  {
    const handle=new T.Mesh(new T.CylinderGeometry(.011,.014,.42,6),new T.MeshStandardMaterial({color:0x8a6236,roughness:.75}));
    handle.position.y=.12;handle.castShadow=true;axe.add(handle);
    const steel=new T.MeshStandardMaterial({color:0x8d949a,metalness:.7,roughness:.35});
    const head=new T.Mesh(new T.BoxGeometry(.03,.07,.11),steel);head.position.set(0,.29,.045);head.castShadow=true;axe.add(head);
    const edge=new T.Mesh(new T.BoxGeometry(.012,.1,.03),steel);edge.position.set(0,.29,.105);axe.add(edge);
  }

  new GLTFLoader().load(URL,gltf=>{
    const model=gltf.scene,ramp=toonRamp(),cache=new Map();
    model.traverse(o=>{
      if(/^Character1_(Left|Right)Hand$/.test(o.name))hands.push(o);
      if(/^Character1_RightHand(Middle1|Thumb2)$/.test(o.name))fingers[o.name.endsWith('Thumb2')?'thumb':'middle']=o;
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
  // Long trips are run, short ones walked.
  function head(goal){
    s.route=place.route(s,goal);
    if(!s.route.length)s.route=[{x:goal.x,z:goal.z}];
    let distance=0,from=s;for(const p of s.route){distance+=Math.hypot(p.x-from.x,p.z-from.z);from=p}
    s.speed=distance>5?1.45:.75;s.state='walking';s.stuck=0;
  }
  function stopActivity(){
    if(s.state==='activity'){s.steps=[];s.prop=null;play('Standing',.25)}
  }
  function cancel(task){
    if(task===job){job=null;stopActivity();s.state=s.route.length?'walking':'idle';s.route=[];task.onCancel?.()}
    else{const i=jobs.indexOf(task);if(i>=0){jobs.splice(i,1);task.onCancel?.()}}
  }
  function cancelAll(){if(job)cancel(job);while(jobs.length)cancel(jobs[0])}
  function startNext(){
    if(job||!jobs.length||!['idle','walking'].includes(s.state))return;
    job=jobs.shift();
    // The nearest approach to the work spot.
    job.spot=job.spots.reduce((best,p)=>Math.hypot(p.x-s.x,p.z-s.z)<Math.hypot(best.x-s.x,best.z-s.z)?p:best);
    head(job.spot);
  }
  function arrive(){
    if(!job){s.state='idle';return}
    // Could not get there (the spot is cut off): drop the job rather than work it from afar.
    if(Math.hypot(s.x-job.spot.x,s.z-job.spot.z)>.6){const failed=job;cancel(job);failed.onFail?.();startNext();return}
    s.state='activity';s.steps=job.steps.slice();s.face=job.spot.face;s.prop=job.prop??null;s.stepTime=0;
    job.onStart?.();nextStep();
  }
  function nextStep(){
    const step=s.steps.shift();
    if(!step){
      const done=job;job=null;s.state='idle';s.prop=null;play('Standing',.4);
      done?.onDone?.();startNext();return;
    }
    play(step.clip,step.fade??.3);s.stepTime=step.time??length(step.clip);
  }
  function queue(task){
    if(s.state==='inside'&&stayIn&&place===island)stayIn=false;  // a job outdoors calls her out
    s.pose=null;
    // A new job takes over from an idle pastime (fishing) instead of waiting for it.
    if(job?.interruptible)cancel(job);
    jobs.push(task);startNext();return task;
  }
  // Stand-off points round a bed (centre x,z, size w x d), each facing the bed.
  const bedSpots=new Map();
  function spotsAround({x,z,w,d}){
    const key=x+','+z;if(bedSpots.has(key))return bedSpots.get(key);
    const list=[];
    for(const [u,v] of [[1,0],[-1,0],[0,1],[0,-1],[.5,1],[-.5,1],[.5,-1],[-.5,-1],[1,.5],[1,-.5],[-1,.5],[-1,-.5]]){
      const px=x+u*(w/2+(Math.abs(u)===1?.3:0)),pz=z+v*(d/2+(Math.abs(v)===1?.3:0));
      if(world.walkable(px,pz))list.push({x:px,z:pz,face:Math.atan2(x-px,z-pz)});
    }
    if(!list.length)list.push({x,z:z+d/2+.3,face:Math.PI});
    bedSpots.set(key,list);return list;
  }
  function walk(dt){
    const target=s.route[0];if(!target){s.pace=T.MathUtils.damp(s.pace,0,6,dt);return true}
    const dx=target.x-s.x,dz=target.z-s.z,d=Math.hypot(dx,dz);
    s.pace=T.MathUtils.damp(s.pace,s.speed,3,dt);
    const step=Math.min(d,dt*s.pace);
    if(d>.001){
      const b=solid();b.x=s.x+dx/d*step;b.z=s.z+dz/d*step;place.resolve(b);
      const moved=Math.hypot(b.x-s.x,b.z-s.z);
      s.x=b.x;s.z=b.z;
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
  // The axe is set in her fist from the hand bones: the handle runs out along her thumb and the
  // blade faces the way her fingers point, which is the way the swing strikes.
  const blade=new T.Vector3(),palm=new T.Vector3(),knuckle=new T.Vector3(),thumb=new T.Vector3(),basis=new T.Matrix4(),side=new T.Vector3();
  function updateAxe(){
    const hand=hands.find(h=>/Right/.test(h.name));
    axe.visible=s.prop==='axe'&&root.visible&&!!hand&&!!fingers.middle&&!!fingers.thumb;
    if(!axe.visible)return;
    hand.getWorldPosition(palm);fingers.middle.getWorldPosition(knuckle);fingers.thumb.getWorldPosition(thumb);
    knuckle.sub(palm);const reach=knuckle.length();knuckle.normalize();
    thumb.sub(palm);thumb.addScaledVector(knuckle,-thumb.dot(knuckle)).normalize();
    side.crossVectors(thumb,knuckle);
    basis.makeBasis(side,thumb,knuckle);axe.quaternion.setFromRotationMatrix(basis);
    axe.position.copy(palm).addScaledVector(knuckle,reach*.65);
  }
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
  const update=(dt,seconds)=>{
    if(!ready)return;
    swingDoor(dt);
    // Indoors she stays in until sent out (stayIn); otherwise she opens the door and steps out.
    if(s.state==='inside'){if(stayIn){root.visible=false;body.active=false}else{s.state='opening';doorWant=1}}
    else if(s.state==='opening'){
      if(doorOpen>.55){s.state='exiting';s.x=threshold.x;s.z=threshold.z;s.heading=0;s.route=[door,apron];s.pace=0;s.speed=.62;root.visible=true;play('Walking',0);
        root.position.set(s.x,world.stand(s.x,s.z),s.z);root.rotation.y=0}
    }else{
      let moving=false;
      if(s.state==='activity'){
        turn(s.face,dt,4);
        s.stepTime-=dt;if(s.stepTime<=0)nextStep();
      }else if(s.state==='exiting'){
        moving=true;
        if(Math.hypot(s.x-threshold.x,s.z-threshold.z)>.62)doorWant=0;
        if(walk(dt)){s.state='idle';startNext()}
      }else if(s.state==='walking'){
        moving=true;
        // Heading home: reach for the door a few steps out, so it is open when she gets there.
        if(homing&&Math.hypot(s.x-door.x,s.z-door.z)<1.15&&s.route.length<=2)doorWant=1;
        if(walk(dt)){
          moving=false;
          if(homing){const h=homing;homing=null;s.state='inside';stayIn=true;root.visible=false;body.active=false;s.pace=0;play('Standing',0);doorWant=0;h()}
          else arrive();
        }
      }else s.pace=T.MathUtils.damp(s.pace,0,6,dt);
      if(s.state!=='activity'){
        if(moving&&s.pace>.05){
          const running=s.pace>1.1;play(running?'Running':'Walking',.25);
          s.action.timeScale=s.pace/(running?1.7:.62);
        }else{play('Standing',.35);if(s.action)s.action.timeScale=1}
      }else if(s.action)s.action.timeScale=1;
      // Standing still she is still solid: chickens bump off her and she never ends inside a prop.
      if(place===island){body.active=root.visible;body.x=s.x;body.z=s.z;body.ignore=inDoorway()?'house':'';world.colliders.resolve(body)}
      else if(!s.pose){roomBody.x=s.x;roomBody.z=s.z;place.resolve(roomBody)}
      const b=solid();
      if(s.state!=='activity'&&!s.pose){s.x=b.x;s.z=b.z;if(place===island)trackFeet(Math.hypot(s.x-(s.px??s.x),s.z-(s.pz??s.z)),s.pace>1.1)}
      s.px=s.x;s.pz=s.z;
      // A pose (lying in bed, sitting on the sofa) places her outright.
      const p=s.pose;
      if(p){root.position.set(p.x,p.y,p.z);root.rotation.set(p.tilt??0,p.heading,0)}
      else{root.position.set(s.x,place.stand(s.x,s.z),s.z);root.rotation.set(0,s.heading,0)}
    }
    mixer.update(dt);
    updateRod(seconds);updateAxe();
    // Tell the job each time the axe lands, with where the blade is.
    const chop=actions.Chopping;
    if(s.state==='activity'&&job&&s.action===chop){
      const t=chop.time/chop.getClip().duration,prev=s.chopPrev??t;
      if(prev<=t?prev<IMPACT&&t>=IMPACT:prev<IMPACT||t>=IMPACT){axe.updateMatrixWorld();job.onHit?.(axe.localToWorld(blade.set(0,.29,.1)).clone())}
      s.chopPrev=t;
    }else s.chopPrev=undefined;
    // Blink on a loose rhythm so the face never freezes.
    if(face){
      s.blink-=dt;
      if(s.blink<=0){s.blinkT=.16;s.blink=2.2+random()*3.5}
      s.blinkT=Math.max(0,s.blinkT-dt);
      face.morphTargetInfluences[blinkIndex]=s.pose?.sleep?1:Math.sin(Math.PI*s.blinkT/.16);
    }
  };
  return Object.assign(update,{
    // Walk to a ground point (snapped to the walking graph when it is not walkable).
    walkTo(x,z){
      // Sent off while she is at home: she comes back out first.
      if(s.state==='inside'&&stayIn&&place===island){stayIn=false;return true}
      if(!['idle','walking','activity'].includes(s.state))return false;
      cancelAll();stopActivity();homing=null;s.pose=null;
      const goal=place.walkable(x,z)?{x,z}:place.closest({x,z});
      if(!goal)return false;
      head(goal);return true;
    },
    tend(bed,{seconds=2.4,...callbacks}={}){
      return queue({spots:spotsAround(bed),steps:[{clip:'Gathering',time:seconds}],...callbacks});
    },
    // Any job: stand at the nearest of spots ({x,z,face}) and play steps ([{clip,time?,fade?}]).
    work(job){return queue(job)},
    reachable:(x,z)=>world.walkable(x,z),
    fish(point,{seconds=6+random()*5,...callbacks}={}){
      if(!shore.length)return null;
      const near=shore.slice().sort((a,b)=>Math.hypot(a.x-point.x,a.z-point.z)-Math.hypot(b.x-point.x,b.z-point.z)).slice(0,2);
      return queue({spots:near,prop:'rod',interruptible:true,
        steps:[{clip:'FishingBegin'},{clip:'FishingLoop',time:seconds,fade:.2},{clip:'FishingStop',fade:.2}],...callbacks});
    },
    cancel,
    // Walk home and go in; onInside fires once the door has shut behind her.
    goHome(onInside){
      if(place!==island)return false;
      if(s.state==='inside'&&stayIn){onInside();return true}
      // Still in the doorway on her way out: she just stays in.
      if(s.state==='inside'||s.state==='opening'){s.state='inside';stayIn=true;doorWant=0;onInside();return true}
      if(!['idle','walking','activity','exiting'].includes(s.state))return false;
      cancelAll();stopActivity();s.pose=null;
      head(apron);s.route.push(door,threshold);homing=onInside;return true;
    },
    isHome:()=>s.state==='inside'&&stayIn&&place===island,
    homeward:()=>!!homing,
    // Move her into a room ({scene,route,resolve,stand,walkable,closest}) at a start point.
    enterRoom(room,start){
      cancelAll();stopActivity();homing=null;s.pose=null;
      place=room;room.scene.add(root);
      s.x=start.x;s.z=start.z;s.heading=start.heading??0;s.route=[];s.pace=0;s.state='idle';
      root.visible=true;body.active=false;stayIn=true;play('Standing',0);
    },
    // Back to the island: she is behind the cottage door and walks out on her own.
    leaveRoom(){
      cancelAll();stopActivity();s.pose=null;
      place=island;scene.add(root);root.visible=false;
      s.state='inside';stayIn=false;s.route=[];
    },
    setPose(pose){s.pose=pose},
    play(name,fade){play(name,fade)},
    busy:()=>job!==null||jobs.length>0,
    position:target=>target.set(s.x,root.position.y,s.z)
  });
}
