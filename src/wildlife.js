import * as T from 'three';

function ellipsoid(group,color,x,y,z,w,h,d){
  const mesh=new T.Mesh(new T.SphereGeometry(1,10,7),new T.MeshStandardMaterial({color,roughness:.8}));
  mesh.scale.set(w,h,d);mesh.position.set(x,y,z);mesh.castShadow=true;group.add(mesh);return mesh;
}
function birdModel(){
  const bird=new T.Group();
  ellipsoid(bird,0x80624a,0,.11,0,.12,.115,.21);
  ellipsoid(bird,0x55504b,0,.22,.13,.101,.106,.11);
  ellipsoid(bird,0xe5c19a,0,.14,.13,.092,.083,.095);
  ellipsoid(bird,0xc19658,0,.2,.235,.044,.028,.067);
  for(const side of [-1,1])ellipsoid(bird,0x211e1c,side*.083,.241,.172,.015,.015,.015);
  ellipsoid(bird,0x4c453e,0,.12,-.217,.063,.043,.158);
  const wings=[-1,1].map(side=>{
    const wing=new T.Group();wing.position.set(side*.069,.15,-.013);
    ellipsoid(wing,0x68584a,side*.15,0,-.03,.205,.031,.103);
    ellipsoid(wing,0x453e38,side*.295,0,-.094,.124,.021,.055);
    bird.add(wing);return wing;
  });
  bird.scale.setScalar(1.35);return {bird,wings};
}
export function createWildlife(scene,world){
  const {bird,wings}=birdModel();
  scene.add(bird);bird.visible=false;
  // A school of ten swims the pond below the surface; now and then one of them leaps.
  const {height,waterY}=world,deep=(x,z)=>waterY-height(x,z);
  const inPond=(x,z)=>deep(x,z)>.3&&x<12.6;
  const palettes=[[0x62796b,0xadb18b,0x806b52],[0x8a6f4c,0xd2b27c,0x9b6b3d],[0xe2dccb,0xf2eee2,0xd8783c],[0xb06a3a,0xe7c08a,0xa65a2f]];
  const school=Array.from({length:10},(_,i)=>{
    const group=new T.Group(),[back,belly,fin]=palettes[i%palettes.length];
    ellipsoid(group,back,0,0,0,.092,.12,.34);
    ellipsoid(group,belly,0,-.055,.07,.073,.065,.21);
    const tail=ellipsoid(group,fin,0,0,-.36,.028,.14,.14);
    ellipsoid(group,fin,0,.11,-.05,.025,.055,.11);
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
  let state='away',since=0,duration=2.5,perchIndex=world.perches.length-5;
  const start=new T.Vector3(),end=new T.Vector3(),pos=new T.Vector3(),ahead=new T.Vector3();
  function flight(t){
    const u=T.MathUtils.clamp(t,0,1);
    pos.lerpVectors(start,end,u);pos.y+=Math.sin(u*Math.PI)*4.2;return pos;
  }
  function launch(out,now,wind){
    start.copy(bird.position);
    if(out){end.set(21+Math.random()*6,10+Math.random()*4,4+Math.random()*12);state='departing'}
    else{end.copy(world.perches[perchIndex]);state='arriving'}
    duration=out&&wind>=10?2.5:4.6;since=now;bird.visible=true;
  }
  let last=0,nextLeap=5;
  return (seconds,wind,night)=>{
    if(!last){since=seconds;nextLeap=seconds+4}
    const dt=Math.min(.1,last?seconds-last:0);last=seconds;
    let age=seconds-since;
    if(state==='away'&&age>=duration&&wind<10&&night<.8){
      bird.position.set(-18,10,-11);launch(false,seconds,wind);age=0;
    }
    if(state==='perched'&&(wind>=10||night>.85||age>=duration)){launch(true,seconds,wind);age=0}
    if(state==='arriving'&&wind>=10){launch(true,seconds,wind);age=0}
    if(state==='arriving'||state==='departing'){
      const t=age/duration;bird.position.copy(flight(t));ahead.copy(flight(t+.012)).sub(bird.position);
      bird.rotation.y=Math.atan2(ahead.x,ahead.z);bird.rotation.x=-Math.atan2(ahead.y,Math.hypot(ahead.x,ahead.z))*.5;
      wings.forEach((w,i)=>{w.rotation.y=0;w.rotation.z=(i?1:-1)*(.13+.76*Math.sin(seconds*24))});
      if(t>=1){
        if(state==='arriving'){state='perched';duration=7+Math.random()*8;bird.rotation.x=0}
        else{state='away';duration=9+Math.random()*13;bird.visible=false;
          perchIndex=Math.random()<.5?world.perches.length-1-Math.floor(Math.random()*5):Math.floor(Math.random()*(world.perches.length-5))}
        since=seconds;
      }
    }
    if(state==='perched'){
      wings.forEach((w,i)=>{w.rotation.z=0;w.rotation.y=(i?1:-1)*1.2});
      bird.rotation.z=Math.sin(seconds*2.4)*.033;
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
