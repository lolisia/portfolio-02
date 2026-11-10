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
  const {bird,wings}=birdModel(),fish=new T.Group();
  ellipsoid(fish,0x62796b,0,0,0,.092,.12,.34);
  ellipsoid(fish,0xadb18b,0,-.055,.07,.073,.065,.21);
  const tail=ellipsoid(fish,0x806b52,0,0,-.36,.028,.14,.14);
  ellipsoid(fish,0x403d31,0,.11,-.05,.025,.055,.11);
  for(const s of [-1,1])ellipsoid(fish,0x27281d,s*.074,.024,.208,.016,.016,.016);
  scene.add(bird,fish);bird.visible=fish.visible=false;
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
  let last=0,fishStart=4,fishWasAirborne=false,fishX=10,fishZ=6.3;
  return (seconds,wind,night)=>{
    if(!last){since=seconds;fishStart=seconds+4}last=seconds;
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
    const f=seconds-fishStart;
    fish.visible=f>=0&&f<5.4&&world.water.userData.freeze.value<.15;
    if(fish.visible){
      const leap=T.MathUtils.clamp((f-2.05)/.91,0,1),arc=Math.sin(Math.PI*leap);
      fish.position.set(fishX+.18*Math.sin(f*1.4),world.waterY-.19+arc*.83,fishZ-1.24+f*.45);
      fish.rotation.y=Math.atan2(.252*Math.cos(f*1.4),.45);
      fish.rotation.x=arc>0?-.82*Math.cos(leap*Math.PI):.04*Math.sin(f*4);
      tail.rotation.y=Math.sin(f*16)*.47;
      const airborne=fish.position.y>world.waterY;
      if(airborne!==fishWasAirborne)world.water.userData.splash(fish.position.x,fish.position.z,seconds,.29);
      fishWasAirborne=airborne;
    }else if(f>=5.4){
      fishStart=seconds+9+Math.random()*14;fishX=9.7+Math.random()*1.9;fishZ=6+Math.random()*.7;fishWasAirborne=false;
    }
    bird.userData.state=state;
  };
}
