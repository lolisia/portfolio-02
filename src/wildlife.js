import * as T from 'three';

function coloredEllipsoid(art,group,color,x,y,z,w,h,d){
  const mesh=new T.Mesh(new T.SphereGeometry(1,10,7),art.shade(new T.MeshStandardMaterial({color,roughness:.8})));
  mesh.scale.set(w,h,d);mesh.position.set(x,y,z);mesh.castShadow=true;group.add(mesh);return mesh;
}
function birdModel(ellipsoid,art){
  const bird=new T.Group();
  bird.name='wild-bird';
  ellipsoid(bird,0x80624a,0,.11,0,.12,.115,.21);
  ellipsoid(bird,0x55504b,0,.22,.13,.101,.106,.11);
  ellipsoid(bird,0xe5c19a,0,.14,.13,.092,.083,.095);
  ellipsoid(bird,0xc19658,0,.2,.235,.044,.028,.067);
  for(const side of [-1,1]){
    ellipsoid(bird,0x211e1c,side*.083,.241,.172,.015,.015,.015);
    art.detail(ellipsoid(bird,0xffebcb,side*.095,.246,.177,.005,.005,.005));
    art.detail(ellipsoid(bird,0xead1a1,side*.073,.204,.192,.032,.028,.043));
  }
  ellipsoid(bird,0x4c453e,0,.12,-.217,.063,.043,.158);
  const wings=[-1,1].map(side=>{
    const wing=new T.Group();wing.position.set(side*.069,.15,-.013);
    ellipsoid(wing,0x68584a,side*.15,0,-.03,.205,.031,.103);
    ellipsoid(wing,0x453e38,side*.295,0,-.094,.124,.021,.055);
    for(let i=0;i<3;i++){
      const plume=art.detail(ellipsoid(wing,0xad8058,side*(.11+i*.074),.022,-.013-i*.018,.072,.013,.023));
      plume.rotation.y=side*.28;
    }
    bird.add(wing);return wing;
  });
  // Thin legs: tucked in flight, reaching forward for the touchdown, standing on the perch.
  const legs=[-1,1].map(side=>{
    const leg=new T.Group();leg.position.set(side*.04,.07,.01);
    const shank=new T.Mesh(new T.CylinderGeometry(.008,.008,.07,4),art.shade(new T.MeshStandardMaterial({color:0x8a6a45,roughness:.8})));
    shank.position.y=-.035;leg.add(shank);bird.add(leg);return leg;
  });
  bird.scale.setScalar(1.35);return {bird,wings,legs};
}
export function createWildlife(scene,world,art){
  const ellipsoid=coloredEllipsoid.bind(null,art);
  const {bird,wings,legs}=birdModel(ellipsoid,art);
  scene.add(bird);bird.visible=false;
  // A school of ten swims the pond below the surface; now and then one of them leaps.
  const {height,waterY}=world,deep=(x,z)=>waterY-height(x,z);
  const inPond=(x,z)=>deep(x,z)>.3&&x<12.6;
  const palettes=[[0x62796b,0xadb18b,0x806b52],[0x8a6f4c,0xd2b27c,0x9b6b3d],[0xe2dccb,0xf2eee2,0xd8783c],[0xb06a3a,0xe7c08a,0xa65a2f]];
  const school=Array.from({length:10},(_,i)=>{
    const group=new T.Group(),[back,belly,fin]=palettes[i%palettes.length];
    group.name='pond-fish-'+i;
    ellipsoid(group,back,0,0,0,.092,.12,.34);
    ellipsoid(group,belly,0,-.055,.07,.073,.065,.21);
    const tail=ellipsoid(group,fin,0,0,-.36,.028,.14,.14);
    ellipsoid(group,fin,0,.11,-.05,.025,.055,.11);
    for(const side of [-1,1]){
      const finTip=art.detail(ellipsoid(group,fin,side*.075,-.028,.015,.06,.018,.097));
      finTip.rotation.y=side*.58;
    }
    for(const s of [-1,1])ellipsoid(group,0x27281d,s*.074,.024,.208,.016,.016,.016);
    group.scale.setScalar(.62+.3*((i*37)%10)/10);scene.add(group);
    let x,z;do{x=7.5+Math.random()*5;z=3.5+Math.random()*5.5}while(!inPond(x,z));
    return {group,tail,x,z,heading:Math.random()*6.28,speed:.3,target:null,depth:.2+Math.random()*.3,phase:Math.random()*9,leap:-1,airborne:false};
  });
  function retarget(f){
    for(let k=0;k<20;k++){
      const x=7.5+Math.random()*5,z=3.5+Math.random()*5.5;
      if(inPond(x,z)){f.target=[x,z];f.depth=.18+Math.random()*.32;return}
    }
  }
  // The bird's day: away, arriving (a long glide that slows into a flare), landing (wings
  // fold, the body rocks to rest), perched, taking off (a crouch and a hop) and departing.
  let state='away',since=0,duration=2.5,perch=null,seat='crown';
  const perches=world.birdPerches,trees=perches.filter(p=>p.kind==='tree'),lamps=perches.filter(p=>p.kind==='lamp');
  const start=new T.Vector3(),end=new T.Vector3(),pos=new T.Vector3(),ahead=new T.Vector3(),c1=new T.Vector3(),c2=new T.Vector3();
  // Felled trees (forestry.js marks their perch gone) are skipped until they regrow.
  const choose=()=>{const standing=trees.filter(t=>!t.gone);perch=Math.random()<.5||!standing.length?lamps[Math.floor(Math.random()*lamps.length)]:standing[Math.floor(Math.random()*standing.length)]};
  choose();
  // Where the seat is right now: the canopy bends in the wind (surfaces.js windVertex), and
  // the bird rides along with the branch it sits on.
  function seatAt(out,seconds,breeze){
    out.copy(seat==='limb'?perch.limb:perch.crown);
    if(perch.root){
      const h=Math.max(0,out.y-perch.root.y),phase=perch.root.x*.39+perch.root.z*.23;
      const gust=Math.sin(seconds*1.37-phase)+.42*Math.sin(seconds*2.31-phase*.71),bend=.014*h*h*gust*breeze;
      out.x+=bend;out.z+=bend*.36;
    }
    return out;
  }
  // Arrival path: a cubic that comes in high and drops onto the seat from behind and above,
  // so the last stretch is a descending glide.
  function arrival(t,out){
    const u=1-Math.pow(1-T.MathUtils.clamp(t,0,1),1.7),v=1-u;
    return out.set(0,0,0).addScaledVector(start,v*v*v).addScaledVector(c1,3*v*v*u).addScaledVector(c2,3*v*u*u).addScaledVector(end,u*u*u);
  }
  function departure(t,out){
    const u=T.MathUtils.clamp(t,0,1);
    out.lerpVectors(start,end,u*u*(1.6-.6*u));out.y+=Math.sin(u*Math.PI)*2.2+u*.4;return out;
  }
  function aim(next,current,pitchScale=.5){
    ahead.copy(next).sub(current);
    if(ahead.lengthSq()<1e-8)return;
    bird.rotation.y=Math.atan2(ahead.x,ahead.z);bird.rotation.x=-Math.atan2(ahead.y,Math.hypot(ahead.x,ahead.z))*pitchScale;
  }
  function launch(out,now,wind,seconds,breeze){
    start.copy(bird.position);
    if(out){end.set(21+Math.random()*6,10+Math.random()*4,4+Math.random()*12);state='departing';duration=wind>=10?2.5:4.6}
    else{
      seat=perch.kind==='tree'&&bare>.5?'limb':'crown';
      seatAt(end,seconds,breeze);state='arriving';duration=5.2;
      c1.lerpVectors(start,end,.35);c1.y+=3.2;
      ahead.set(end.x-start.x,0,end.z-start.z).normalize();
      c2.copy(end).addScaledVector(ahead,-1.6);c2.y+=1.1;
    }
    since=now;bird.visible=true;
  }
  function flap(seconds,rate,amp,sweep=0){
    wings.forEach((w,i)=>{w.rotation.y=(i?1:-1)*sweep;w.rotation.z=(i?1:-1)*(.13+amp*Math.sin(seconds*rate))});
  }
  function fold(k){  // k: 0 spread, 1 folded along the back
    wings.forEach((w,i)=>{w.rotation.z=(i?1:-1)*.5*(1-k)*(1-k);w.rotation.y=(i?1:-1)*1.2*k});
  }
  const legPose=a=>legs.forEach(l=>l.rotation.x=a);
  let last=0,nextLeap=5,bare=0;
  return (seconds,wind,night,breeze=0,bareness=0)=>{
    bare=bareness;
    if(!last){since=seconds;nextLeap=seconds+4}
    const dt=Math.min(.1,last?seconds-last:0);last=seconds;
    let age=seconds-since;
    if(state==='away'&&age>=duration&&wind<10&&night<.8){
      bird.position.set(-18,10,-11);launch(false,seconds,wind,seconds,breeze);age=0;
    }
    if((state==='perched'||state==='landing')&&(wind>=10||night>.85||(state==='perched'&&age>=duration))){state='takeoff';since=seconds;age=0}
    if(state==='arriving'&&wind>=10){launch(true,seconds,wind);age=0}
    if(perch.gone&&(state==='perched'||state==='landing')){state='takeoff';since=seconds;age=0}
    if(perch.gone&&state==='arriving'){launch(true,seconds,wind);age=0}
    if(state==='arriving'){
      const t=age/duration;
      // The seat keeps swaying; steer the end of the path onto it.
      seatAt(end,seconds,breeze);
      arrival(t,bird.position);arrival(t+.01,pos);
      const flare=T.MathUtils.smoothstep(t,.72,1);
      aim(pos,bird.position,.5*(1-flare));
      bird.rotation.x=T.MathUtils.lerp(bird.rotation.x,-.75,flare);
      // Cruise flapping with short glides, then slow, deep back-strokes to brake.
      const glide=t<.72&&Math.sin(seconds*1.9)>.55?.25:1;
      flap(seconds,T.MathUtils.lerp(24,13,flare),T.MathUtils.lerp(.76*glide,1.05,flare),-.35*flare);
      legPose(T.MathUtils.lerp(1.3,-.5,flare));
      if(t>=1){state='landing';since=seconds;age=0;bird.position.copy(end)}
    }
    if(state==='landing'){
      // Touchdown: the body rocks forward and settles with a damped bob, the wings close.
      const k=Math.min(1,age/.7);
      seatAt(bird.position,seconds,breeze);
      bird.position.y-=.035*Math.sin(Math.PI*Math.min(1,age/.35))*(1-k);
      bird.rotation.x=-.75*Math.exp(-age*7)*Math.cos(age*11)+.12*Math.sin(Math.PI*k)*(1-k);
      if(age<.3)flap(seconds,13,.9*(1-age/.3),-.35*(1-age/.3));else fold(T.MathUtils.smoothstep(age,.3,.7));
      legPose(-.5*(1-k));
      if(age>=.7){state='perched';since=seconds;duration=7+Math.random()*8;bird.rotation.x=0;fold(1)}
    }
    if(state==='perched'){
      seatAt(bird.position,seconds,breeze);
      fold(1);legPose(0);
      bird.rotation.z=Math.sin(seconds*2.4)*.033;
      bird.rotation.x=.05*Math.max(0,Math.sin(seconds*.7))**8;  // the odd glance down
    }
    if(state==='takeoff'){
      // Crouch, open the wings, spring.
      seatAt(bird.position,seconds,breeze);
      const k=Math.min(1,age/.28);
      bird.position.y-=.03*Math.sin(Math.PI*k);
      bird.rotation.x=.25*Math.sin(Math.PI*k);
      fold(1-T.MathUtils.smoothstep(age,0,.2));
      if(age>=.28){launch(true,seconds,wind);age=0}
    }
    if(state==='departing'){
      const t=age/duration;departure(t,bird.position);departure(t+.012,pos);aim(pos,bird.position);
      bird.rotation.x*=Math.min(1,age/.4);  // pitch into the climb instead of snapping
      flap(seconds,24,.76);legPose(T.MathUtils.lerp(.5,1.3,Math.min(1,t*4)));
      if(t>=1){state='away';duration=9+Math.random()*13;bird.visible=false;choose();since=seconds}
    }
    const frozen=world.water.userData.freeze.value>.15;
    if(!frozen&&seconds>nextLeap){
      const f=school[Math.floor(Math.random()*school.length)];
      if(f.leap<0&&inPond(f.x+Math.sin(f.heading)*1.4,f.z+Math.cos(f.heading)*1.4))f.leap=0;
      nextLeap=seconds+4+Math.random()*8;
    }
    for(const f of school){
      f.group.visible=!frozen;if(frozen)continue;
      let y;
      if(f.leap>=0){
        f.leap+=dt/1.15;const u=Math.min(1,f.leap);
        f.x+=Math.sin(f.heading)*dt*1.15;f.z+=Math.cos(f.heading)*dt*1.15;
        y=waterY-.22+Math.sin(Math.PI*u)*.95;
        f.group.rotation.set(-.95*Math.cos(Math.PI*u),f.heading,0,'YXZ');
        f.tail.rotation.y=Math.sin(seconds*22)*.5;
        if(f.leap>=1)f.leap=-1;
      }else{
        if(!f.target||Math.hypot(f.target[0]-f.x,f.target[1]-f.z)<.5)retarget(f);
        const want=Math.atan2(f.target[0]-f.x,f.target[1]-f.z);
        let turn=Math.atan2(Math.sin(want-f.heading),Math.cos(want-f.heading));
        f.heading+=T.MathUtils.clamp(turn,-1.4*dt,1.4*dt)+.25*Math.sin(seconds*1.3+f.phase)*dt;
        f.speed=.22+.14*Math.max(0,Math.sin(seconds*.6+f.phase))**3*3;
        const nx=f.x+Math.sin(f.heading)*f.speed*dt,nz=f.z+Math.cos(f.heading)*f.speed*dt;
        if(inPond(nx,nz)){f.x=nx;f.z=nz}else{retarget(f);f.heading+=2.5*dt}
        y=waterY-Math.max(.1,Math.min(f.depth,deep(f.x,f.z)-.14))+.03*Math.sin(seconds*.9+f.phase);
        f.group.rotation.set(.06*Math.sin(seconds*.9+f.phase+1.5),f.heading,0,'YXZ');
        f.tail.rotation.y=Math.sin(seconds*(6+f.speed*22)+f.phase)*.42;
      }
      f.group.position.set(f.x,y,f.z);
      const airborne=y>waterY;
      if(airborne!==f.airborne)world.water.userData.splash(f.x,f.z,seconds,.26);
      f.airborne=airborne;
    }
    // Keep the school from swimming through one another.
    for(let i=0;i<school.length;i++)for(let j=i+1;j<school.length;j++){
      const a=school[i],b=school[j],dx=a.x-b.x,dz=a.z-b.z,d=Math.hypot(dx,dz);
      if(d>1e-4&&d<.42&&a.leap<0&&b.leap<0){const k=(.42-d)*.5*Math.min(1,dt*4)/d;a.x+=dx*k;a.z+=dz*k;b.x-=dx*k;b.z-=dz*k}
    }
    bird.userData.state=state;
  };
}
