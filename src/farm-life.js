import * as T from 'three';
import {createFarmPaths} from './farm-paths.js';
import {createChimneySmoke} from './smoke.js';

const windHeading=Math.atan2(1,.36);
export function createFarmLife(scene,world){
  const metal=new T.MeshStandardMaterial({color:0x504d40,metalness:.65,roughness:.46});
  const brass=new T.MeshStandardMaterial({color:0xb49a62,metalness:.65,roughness:.42});
  function mesh(group,geometry,material,x,y,z){
    const m=new T.Mesh(geometry,material);m.position.set(x,y,z);m.castShadow=true;group.add(m);return m;
  }
  const vane=new T.Group();vane.name='roof-weather-vane';
  const roofY=world.height(-1,-1.8)+3.36;
  vane.position.set(-.45,roofY,-1.4);scene.add(vane);
  mesh(vane,new T.CylinderGeometry(.025,.04,.9,8),metal,0,.45,0);
  const arrow=new T.Group();arrow.position.y=.82;vane.add(arrow);
  mesh(arrow,new T.BoxGeometry(.045,.045,1.35),metal,0,0,0);
  const arrowhead=new T.ConeGeometry(.15,.3,3);arrowhead.rotateX(Math.PI/2);
  mesh(arrow,arrowhead,brass,0,0,.8);
  // Traditional rooster silhouette, cut from brass in the plane of the vane.
  const rooster=new T.Shape();
  rooster.moveTo(-.37,.10);rooster.bezierCurveTo(-.65,.30,-.68,.69,-.40,.63);
  rooster.lineTo(-.52,.48);rooster.bezierCurveTo(-.22,.57,-.30,.26,-.03,.28);
  rooster.bezierCurveTo(.14,.29,.13,.50,.17,.57);
  rooster.lineTo(.13,.65);rooster.lineTo(.21,.62);rooster.lineTo(.25,.69);rooster.lineTo(.29,.62);rooster.lineTo(.36,.66);rooster.lineTo(.35,.56);
  rooster.lineTo(.46,.51);rooster.lineTo(.34,.47);rooster.bezierCurveTo(.37,.34,.24,.29,.22,.18);
  rooster.bezierCurveTo(.12,.05,-.19,.03,-.37,.10);rooster.closePath();
  const roosterMesh=mesh(arrow,new T.ExtrudeGeometry(rooster,{depth:.035,bevelEnabled:false}),brass,0,.04,0);
  roosterMesh.rotation.y=Math.PI/2;roosterMesh.name='rooster-silhouette';
  for(const z of [-.12,.12])mesh(arrow,new T.BoxGeometry(.035,.16,.025),brass,0,.13,z);
  mesh(arrow,new T.SphereGeometry(.065,10,7),brass,0,0,0);
  arrow.rotation.y=windHeading;
  // Cardinal cross stays fixed while the rooster turns and the cups spin.
  const compass=new T.Group();compass.position.y=.33;vane.add(compass);
  mesh(compass,new T.BoxGeometry(1.05,.025,.025),metal,0,0,0);
  mesh(compass,new T.BoxGeometry(.025,.025,1.05),metal,0,0,0);
  const rotor=new T.Group();rotor.name='roof-anemometer';rotor.position.y=1.65;vane.add(rotor);
  mesh(vane,new T.CylinderGeometry(.018,.018,.8,8),metal,0,1.24,0);
  const cupGeo=new T.SphereGeometry(.115,12,8,0,Math.PI*2,0,Math.PI/2);
  const cupMaterial=brass.clone();cupMaterial.side=T.DoubleSide;
  for(let i=0;i<3;i++){
    const arm=new T.Group();arm.rotation.y=i*Math.PI*2/3;rotor.add(arm);
    mesh(arm,new T.BoxGeometry(.38,.025,.025),metal,.19,0,0);
    const cup=mesh(arm,cupGeo,cupMaterial,.4,0,0);cup.rotation.x=Math.PI/2;
  }
  let rotorSpeed=0;

  const updateSmoke=createChimneySmoke(scene,world);

  const sphere=new T.SphereGeometry(1,12,8),legGeo=new T.CylinderGeometry(.018,.014,.19,5);
  const mats=new Map();
  function mat(color){if(!mats.has(color))mats.set(color,new T.MeshStandardMaterial({color,roughness:.87}));return mats.get(color)}
  function egg(group,color,x,y,z,w,h,d){const m=mesh(group,sphere,mat(color),x,y,z);m.scale.set(w,h,d);return m}
  function chicken(chick,index){
    const group=new T.Group();group.name=chick?'chick-'+index:'hen-'+index;
    const feather=chick?0xe4c47a:index?0xb78352:0xe6dbbc;
    egg(group,feather,0,.29,0,.19,.23,.27);
    for(const side of [-1,1])egg(group,chick?0xd4b36c:0x9f7952,side*.16,.3,-.02,.055,.15,.2);
    const head=new T.Group();head.position.set(0,.46,.18);group.add(head);
    egg(head,feather,0,.03,.025,.12,.135,.13);
    egg(head,0xc5994b,0,-.005,.16,.055,.035,.09);
    for(const side of [-1,1])egg(head,0x211f18,side*.104,.065,.095,.018,.019,.018);
    if(!chick){
      for(let i=0;i<3;i++)egg(head,0xa64d39,0,.165+i*.008,-.035+i*.045,.038,.057,.034);
      egg(head,0xa64d39,0,-.085,.085,.042,.066,.035);
    }
    const tail=egg(group,chick?0xd4b36c:0x7b6148,0,.37,-.27,.12,.18,.075);tail.rotation.x=-.5;
    const legs=[-1,1].map(side=>mesh(group,legGeo,mat(0xa98a52),side*.078,.1,.025));
    group.scale.setScalar(chick?.48:1);scene.add(group);group.visible=false;
    const seed=index*1.731+.53;
    const body=world.colliders.body(2.25,-1.45,chick?.09:.15,chick?.35:1);body.ignore='coop';
    return {group,head,legs,chick,index,body,state:'inside',x:2.25,z:-1.45,
      wait:0,step:seed,rng:1297+index*7919,gait:seed,pace:0,baseSpeed:(chick?.31:.27)+(.5+.5*Math.sin(seed*3.7))*.24,
      reaction:0,intent:false,noticed:null,route:[],trip:0,legSpeed:1,walked:0};
  }
  const flock=[chicken(false,0),chicken(false,1),...Array.from({length:4},(_,i)=>chicken(true,i+2))];
  const door={x:2.25,z:-1.12},apron={x:2.25,z:.38};
  const paths=createFarmPaths(world);
  function random(f){f.rng=(Math.imul(f.rng,1664525)+1013904223)>>>0;return f.rng/4294967296}
  function setTrip(f,home=false){
    if(home){f.route=paths.route(f,apron);f.route.push(door);return}
    const far=random(f)>.42;
    const candidates=paths.nodes.filter(n=>{
      const radius=Math.hypot(n.x-apron.x,n.z-apron.z);
      return radius>(far?3.5:1)&&radius<(far?9:4)&&Math.hypot(n.x-f.x,n.z-f.z)>1;
    });
    for(let i=0;i<8;i++){
      const target=candidates[Math.min(candidates.length-1,Math.floor(random(f)*candidates.length))];
      if(!target)break;
      f.route=paths.route(f,target);if(f.route.length)break;
    }
    f.trip++;f.legSpeed=.7+random(f)*.65;
  }
  function walk(f,dt,multiplier){
    const target=f.route[0];if(!target){f.pace=T.MathUtils.damp(f.pace,0,5,dt);return true}
    const dx=target.x-f.x,dz=target.z-f.z,d=Math.hypot(dx,dz);
    const desired=f.baseSpeed*f.legSpeed*multiplier*(.9+.1*Math.sin(f.step+f.gait*.17));
    f.pace=T.MathUtils.damp(f.pace,desired,2.8,dt);
    const step=Math.min(d,dt*f.pace);
    if(d>.001){
      // Chickens may use the coop ramp (its footprint is tagged 'coop'); everything else is solid.
      f.body.x=f.x+dx/d*step;f.body.z=f.z+dz/d*step;world.colliders.resolve(f.body);
      const moved=Math.hypot(f.body.x-f.x,f.body.z-f.z);
      f.x=f.body.x;f.z=f.body.z;f.walked+=step;
      f.stuck=moved<step*.3?(f.stuck||0)+dt:0;
      if(f.stuck>1.5){f.stuck=0;f.route.shift()}
      const angle=Math.atan2(dx,dz),delta=Math.atan2(Math.sin(angle-f.group.rotation.y),Math.cos(angle-f.group.rotation.y));
      f.group.rotation.y+=delta*(1-Math.exp(-dt*5));
    }
    f.gait+=step/(f.chick?.045:.085);
    if(d<.045)f.route.shift();
    return f.route.length===0;
  }
  return (dt,seconds,hour,weather,wind,camera,night=0)=>{
    const gust=Math.sin(seconds*1.37)+.42*Math.sin(seconds*2.31);
    const target=windHeading+gust*.11*Math.min(1,wind/8);
    const delta=Math.atan2(Math.sin(target-arrow.rotation.y),Math.cos(target-arrow.rotation.y));
    if(wind>.05)arrow.rotation.y+=delta*(1-Math.exp(-dt*(1+wind*.35)));
    rotorSpeed=T.MathUtils.damp(rotorSpeed,wind*.7,1.8,dt);
    rotor.rotation.y+=dt*rotorSpeed;
    rotor.userData.speed=rotorSpeed;vane.userData.windSpeed=wind;
    updateSmoke(dt,seconds,wind,camera,night);
    const outside=hour>=6&&hour<18&&weather<=1&&wind<11;
    for(const f of flock){
      if(f.noticed!==outside){
        f.noticed=outside;
        f.reaction=outside?1.5+random(f)*10:(weather>=2?1+random(f)*6:3+random(f)*11);
      }
      f.reaction=Math.max(0,f.reaction-dt);
      if(f.reaction===0)f.intent=outside;
      if(f.state==='inside'){
        f.group.visible=false;f.body.active=false;f.group.userData.activity=hour>=18||hour<6?'sleeping':'sheltered';
        if(f.intent){f.state='exiting';f.x=door.x;f.z=door.z;f.route=[apron];f.group.visible=true;f.wait=0;f.pace=0}
        continue;
      }
      if(!f.intent&&f.state!=='returning'){f.state='returning';f.wait=.4+random(f)*1.8;setTrip(f,true)}
      let moving=false;
      if(f.wait>0){f.wait=Math.max(0,f.wait-dt);f.pace=T.MathUtils.damp(f.pace,0,6,dt)}
      else if(f.state==='exiting'){
        moving=true;if(walk(f,dt,.85)){f.state='foraging';f.wait=1+random(f)*3;setTrip(f)}
      }else if(f.state==='returning'){
        moving=true;if(walk(f,dt,1.25)){f.state='inside';f.group.visible=false;f.pace=0}
      }else if(f.state==='foraging'){
        moving=true;
        if(walk(f,dt,1)){
          moving=false;f.wait=2+random(f)*6;setTrip(f);
        }else if(random(f)<dt*.025){f.wait=.8+random(f)*2.5}
      }
      const ramp=Math.abs(f.x-door.x)<.5?T.MathUtils.clamp((.35-f.z)/1.47,0,1)*.65:0;
      // Feet stay on the ground; the torso only rolls subtly with each stride.
      f.body.active=f.group.visible;f.body.x=f.x;f.body.z=f.z;world.colliders.resolve(f.body);f.x=f.body.x;f.z=f.body.z;
      f.group.position.set(f.x,world.height(f.x,f.z)+ramp,f.z);
      f.group.rotation.z=moving?Math.sin(f.gait)*.017:0;
      const peck=!moving&&f.state==='foraging'?.2+Math.max(0,Math.sin(seconds*(2.1+f.index*.19)+f.step))*.95:0;
      f.head.rotation.x=T.MathUtils.damp(f.head.rotation.x,peck,5,dt);
      f.legs.forEach((leg,i)=>leg.rotation.x=moving?Math.sin(f.gait+i*Math.PI)*.28:0);
      Object.assign(f.group.userData,{activity:f.state,speed:f.pace,walked:f.walked,trip:f.trip});
    }
  };
}
