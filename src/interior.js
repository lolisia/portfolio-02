import * as T from 'three';
import {interior} from './surfaces.js';
import {COTTAGE} from './modules.js';

// Someone is at home: room lamps are switched up and down, a TV in the living room throws
// shifting colour at the windows near it, and a person crossing a room dims the window they
// pass. Drives the window glass, its emissive colour and the porch window light.
export function createInterior(world,glass,windowLight){
  const {W,D}=COTTAGE,hx=world.cottage.door.x,hz=world.cottage.door.z-D/2-.4,floorTop=world.cottage.window.y+.75;
  let seed=40213;const rand=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);
  const warmBase=new T.Color(0xffac46),lampWarm=new T.Color(0xffb35a),reading=new T.Color(0xffd29a);
  const palette=[0x7aa2ff,0xdfe8ff,0x9fe6c0,0xffd8a8,0xff9078,0xb7a6ff,0xf2f6ff].map(c=>new T.Color(c));
  const tv={on:false,until:6+rand()*10,cut:0,color:new T.Color(),target:new T.Color(),level:0,bright:0};
  interior.tvAt.value.set(hx-.95,hz+.55);  // living room, behind the front-left window
  const person={x:hx,z:hz,tx:hx,tz:hz,wait:2,shade:0};
  const lamps={level:1,target:1,next:12,tint:0,tintTarget:0};
  const glow=new T.Color(),tvLight=new T.Color(),light=new T.Color();
  return (dt,seconds,night)=>{
    // Room lamps: now and then someone switches a lamp on or off, or settles in to read.
    lamps.next-=dt;
    if(lamps.next<=0){lamps.next=14+rand()*30;lamps.target=[.62,.85,1,1,1.18][Math.floor(rand()*5)];lamps.tintTarget=rand()<.3?1:0}
    lamps.level=T.MathUtils.damp(lamps.level,lamps.target,4,dt);lamps.tint=T.MathUtils.damp(lamps.tint,lamps.tintTarget,3,dt);
    // TV: long sessions on and off; while it plays, the picture cuts every second or few and
    // the brightness shimmers frame to frame.
    tv.until-=dt;
    if(tv.until<=0){tv.on=!tv.on;tv.until=tv.on?25+rand()*50:12+rand()*35}
    tv.cut-=dt;
    if(tv.cut<=0){tv.cut=.6+rand()**2*3.6;tv.target.copy(palette[Math.floor(rand()*palette.length)]);tv.bright=.45+rand()*.55}
    tv.color.lerp(tv.target,1-Math.exp(-dt*22));
    tv.level=T.MathUtils.damp(tv.level,tv.on?tv.bright*(.86+.14*Math.sin(seconds*31)*Math.sin(seconds*7.3)):0,18,dt);
    // A person wanders between rooms, pausing here and there.
    if(person.wait>0)person.wait-=dt;
    else{
      const dx=person.tx-person.x,dz=person.tz-person.z,d=Math.hypot(dx,dz),step=Math.min(d,dt*.45);
      if(d<.02){person.wait=2+rand()*9;person.tx=hx+(rand()-.5)*(W-.5);person.tz=hz+(rand()-.5)*(D-.5)}
      else{person.x+=dx/d*step;person.z+=dz/d*step}
    }
    person.shade=T.MathUtils.damp(person.shade,.62,2,dt);
    interior.person.value.set(person.x,person.z,person.shade*night,floorTop);
    // Glass: the warm lamp level times the night, plus TV colour around the living room.
    glow.copy(warmBase).lerp(reading,lamps.tint*.5);
    glass.emissive.copy(glow);glass.emissiveIntensity=.025+night*2.5*lamps.level;
    interior.tv.value.set(tv.color.r,tv.color.g,tv.color.b).multiplyScalar(tv.level*night*1.6);
    // The window light by the porch picks up a little of everything.
    const near=1-T.MathUtils.smoothstep(Math.hypot(person.x-world.cottage.window.x,person.z-(hz+D/2)),.2,.8);
    light.copy(lampWarm).multiplyScalar(lamps.level*(1-.45*near*person.shade));
    tvLight.copy(tv.color).multiplyScalar(tv.level*.35);
    light.add(tvLight);
    const strength=Math.max(light.r,light.g,light.b)||1;
    windowLight.color.copy(light).multiplyScalar(1/strength);windowLight.intensity=9*night*strength;
  };
}
