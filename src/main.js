import * as T from 'three';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {builder} from './modules.js';
import {createAtmosphere,surface} from './surfaces.js';
import {makeCascade} from './cascade.js';
import {createSky} from './sky.js';
import {createVolume} from './mist.js';
import {bindGraphicsStyle,createDayClock,drawHorizon,drawWind,drawWeather} from './panel.js';
import {createSeasons} from './seasons.js';
import {daylight} from './daylight.js';
import {createRain} from './rain.js';
import {createWildlife} from './wildlife.js';
import {createFarmLife} from './farm-life.js';
import {createUnityChan} from './unitychan.js';
import {buildWorld} from './world.js';
import {loadNature} from './nature.js';
import {createWeatherTransition} from './weather.js';
import {gardenKinds} from './garden.js';
import {cropKinds} from './crops.js';
import {createFarm} from './farm.js';
import {createInterior} from './interior.js';
import {createFootprints} from './footprints.js';
import {quality} from './mobile-quality.js';
import {attachMapControls} from './map-controls.js';
import {createStorybook,paintClouds} from './storybook.js';
import {createActorArt} from './actor-art.js';
import {createShedding} from './shed.js';
import {createRoom} from './room.js';

const canvas=document.querySelector('#world');
const scene=new T.Scene(), renderer=new T.WebGLRenderer({canvas,antialias:false,powerPreference:'high-performance'});
renderer.toneMapping=T.ACESFilmicToneMapping;renderer.toneMappingExposure=1.14;
renderer.shadowMap.enabled=true;renderer.shadowMap.type=T.PCFShadowMap;
const camera=new T.OrthographicCamera(-22,22,15,-15,.1,180);
const controls=new OrbitControls(camera,canvas);controls.enableDamping=true;controls.zoomToCursor=true;
controls.minPolarAngle=.35;controls.maxPolarAngle=1.18;controls.minZoom=.7;controls.maxZoom=10;
const followCharacter=document.querySelector('#followCharacter');
attachMapControls(controls,canvas,()=>{followCharacter.checked=false});
function home(){
  followCharacter.checked=false;
  // Drain pending pan/rotation before setting the home pose, so damping cannot
  // pull the camera away from the reset position on subsequent frames.
  const damping=controls.enableDamping;controls.enableDamping=false;controls.update();controls.enableDamping=damping;
  controls.target.set(0,1,0);camera.position.set(31,34,41);camera.zoom=1;camera.updateProjectionMatrix();controls.update();
}
home();
const view=new URLSearchParams(location.search).get('view');
if(view==='water'||view==='falls'){
  controls.target.set(10.6,.48,6.25);camera.position.copy(controls.target).add(new T.Vector3(19,13,26));
  if(view==='falls'){
    controls.target.set(13.4,-.10,6.1);camera.position.copy(controls.target).add(new T.Vector3(26,13,18));
  }
  camera.zoom=3.25;camera.updateProjectionMatrix();controls.update();
}
// Close-ups for checking details: ?view=house|coop|stairs|garden|pond|farm|grove, optionally &zoom=N.
const closeUps={grove:[-3.95,1.6,2.0,9],farm:[1.9,.5,3.3,4.2],house:[-1,1.6,-1.2,3],garden:[-1.1,3.2,-7.65,5],coop:[2.25,1.7,-1.6,3.3],stairs:[-5.4,2.2,-4.4,3],pond:[10.2,.4,6.3,5]};
if(closeUps[view]){
  const [x,y,z,zoom]=closeUps[view],yaw=Number(new URLSearchParams(location.search).get('yaw'))||0;
  controls.target.set(x,y,z);camera.position.copy(controls.target).add(new T.Vector3(24,18,30).applyAxisAngle(new T.Vector3(0,1,0),yaw*Math.PI/180));
  camera.zoom=Number(new URLSearchParams(location.search).get('zoom'))||zoom;controls.maxZoom=Math.max(controls.maxZoom,camera.zoom);camera.updateProjectionMatrix();controls.update();
}
const sky=new T.DirectionalLight(0xc9e1fb,1.0),sun=new T.DirectionalLight(0xffe3b4,2.25);
sky.position.set(12,19,17);scene.add(sky,sun,new T.AmbientLight(0x8798ad,.11));sun.position.set(-13,24,9);sun.castShadow=true;
Object.assign(sun.shadow.camera,{left:-24,right:24,top:24,bottom:-24,near:.1,far:78});sun.shadow.camera.updateProjectionMatrix();renderer.shadowMap.autoUpdate=true;sun.shadow.mapSize.set(quality.sunShadowSize,quality.sunShadowSize);sun.shadow.normalBias=.028;sun.shadow.bias=-.00016;
const nature=await loadNature();
for(const [name,kind] of [...gardenKinds(),...cropKinds()])nature.set(name,kind);
const b=builder(scene,undefined,nature), world=buildWorld(scene,b);b.finish();
// Crop meshes exist (hidden) before the atmosphere hooks up wind and shadows, and before warm-up.
const farm=createFarm(scene,world,nature,camera,canvas);
const storybook={value:0};
const switchStorybook=createStorybook(scene);
const actorArt=createActorArt(storybook);
const windowLight=new T.PointLight(0xffaf52,0,7,1.5);windowLight.position.copy(world.cottage.window);scene.add(windowLight);
const cascade=makeCascade(world,storybook);scene.add(cascade);
const atmosphere=createAtmosphere(scene,world,storybook);
const seasons=createSeasons(scene,world,atmosphere);
const prints=createFootprints(scene,world,atmosphere);
const farmLife=createFarmLife(scene,world,prints,actorArt);farmLife.onLay=farm.layEgg;
let unityChanLoaded;const unityChanReady=new Promise(r=>unityChanLoaded=r);
const unityChan=createUnityChan(scene,world,unityChanLoaded,prints,actorArt);farm.bind(unityChan);
// The cottage interior, drawn instead of the island while she is inside (room.js).
// The sky as the island shows it, kept for the cottage windows.
const skyLook={top:new T.Color(),bottom:new T.Color(),glow:new T.Color(),stars:0,sunY:1,hour:12};
const room=createRoom({renderer,world,character:unityChan,canvas,controls,hooks:{
  indoor:flag=>farm.setIndoor(flag),earn:(...a)=>farm.earn(...a),spendWood:(...a)=>farm.spendWood(...a),toast:t=>farm.toast(t),
  isNight:()=>{const h=hourShown<0?hourShown+24:hourShown;return h>=19||h<5},
  // Sleeping through the night: morning at 7:00, the scene relit at once behind the fade.
  sleep:()=>{time.value=7;time.dispatchEvent(new Event('input'));hourShown=hourTarget=7;lighting()}
}});
farm.bindRoom(room);
const trackedCharacter=scene.getObjectByName('sd-unity-chan'),followTarget=new T.Vector3(),followDelta=new T.Vector3();
const homeLife=createInterior(world,surface('glass'),windowLight);
const setSky=createSky(renderer,scene,world.water);
const volume=createVolume(renderer,world,sun,atmosphere.cloudMap,storybook,paintClouds());
let refreshStyleShadows=false;
const glowCanvas=document.createElement('canvas');glowCanvas.width=glowCanvas.height=128;
const glowContext=glowCanvas.getContext('2d');
const halo=glowContext.createRadialGradient(64,64,0,64,64,64);
// Neutral white halo: the lamps tint it a cool-white, the fireflies yellow.
for(const [stop,alpha] of [[0,1],[.09,.8],[.22,.32],[.5,.09],[1,0]])halo.addColorStop(stop,'rgba(255,248,238,'+alpha+')');
glowContext.fillStyle=halo;glowContext.fillRect(0,0,128,128);
const haloMap=new T.CanvasTexture(glowCanvas);haloMap.colorSpace=T.SRGBColorSpace;
let lampSeed=88411;const lampRand=()=>((lampSeed=(Math.imul(lampSeed,1664525)+1013904223)>>>0)/4294967296);
const lanterns=world.lamps.map(pivot=>{
  const spot=new T.SpotLight(0xfff0dc,0,8,1.17,.72,1.65);
  spot.position.set(0,-.765,0);
  spot.target.position.set(0,-3.485,0);
  spot.castShadow=true;spot.shadow.mapSize.set(256,256);spot.shadow.autoUpdate=false;spot.shadow.needsUpdate=true;spot.shadow.camera.near=.12;spot.shadow.bias=-.0007;
  const glow=new T.Sprite(new T.SpriteMaterial({map:haloMap,color:0xfff2e2,blending:T.AdditiveBlending,depthWrite:false}));
  glow.position.set(0,-.485,0);glow.scale.setScalar(2.4);
  pivot.add(spot,spot.target,glow);
  const glass=pivot.getObjectByName('lampglass').material;
  return {spot,glow,pivot,glass,level:1,flicker:0,chunk:0,next:6+lampRand()*30};
});
// Lamps burn steady but now and then one stutters: a second or so of dropouts and buzzing.
function flickerLamps(dt,seconds){
  for(const l of lanterns){
    l.next-=dt;
    if(l.next<=0&&l.flicker<=0){l.flicker=.35+lampRand()*1.4;l.next=10+lampRand()*45}
    if(l.flicker>0){
      l.flicker-=dt;l.chunk-=dt;
      if(l.chunk<=0){l.chunk=.03+lampRand()*.11;l.level=lampRand()<.45?.05+lampRand()*.3:lampRand()<.5?.6+lampRand()*.25:1}
      if(l.flicker<=0)l.level=1;
    }
    const hum=1+.025*Math.sin(seconds*47+l.pivot.position.x)*Math.sin(seconds*3.1);
    const level=l.level*hum;
    l.spot.intensity=34*nightLevel*level;
    l.glow.visible=nightLevel>.01;l.glow.material.opacity=nightLevel*.78*level;
    l.glass.emissiveIntensity=.025+nightLevel*2.6*level;
  }
}
function particles(count,material,initializer,lines=false){
  const data=new Float32Array(count*(lines?6:3));for(let i=0;i<count;i++)initializer(data,i*(lines?6:3));
  const geometry=new T.BufferGeometry();geometry.setAttribute('position',new T.BufferAttribute(data,3));
  const mesh=lines?new T.LineSegments(geometry,material):new T.Points(geometry,material);scene.add(mesh);return mesh;
}
const rand=b.rand;
const rain=createRain(scene,world),wildlife=createWildlife(scene,world,actorArt);
// A bird landing shakes loose a clump of snow, or a few leaves in the season's colours; on snowy
// days the roofs and branches also drop their load now and then.
const shed=createShedding(scene,world);
const LEAF_COLOURS=[['#9cc25a','#b6d36c','#ffc6d6','#f7dce4'],['#6f8d40','#86a24c','#9cb35c'],['#bb602b','#e79a40','#a83e26','#ddbb56'],[]];
wildlife.onPerch=(at,perch)=>{
  if(atmosphere.snowDepth.value>.35){shed.snow(at,perch.kind==='tree'?3:2);return}
  if(perch.kind==='tree'&&atmosphere.winterBare.value<.5)shed.leaves(at,LEAF_COLOURS[seasonIndex],4+Math.floor(Math.random()*4));
};
let snowSlide=3;
function slideSnow(dt){
  if(atmosphere.snowDepth.value<.5)return;
  snowSlide-=dt;if(snowSlide>0)return;
  snowSlide=2.5+Math.random()*4.5;
  const trees=world.birdPerches.filter(p=>p.kind==='tree'&&!p.gone);
  if(Math.random()<.5||!trees.length){
    // Off a roof edge: the roofs slope down to their eaves at x = centre +/- rx.
    const roof=world.roofs[Math.floor(Math.random()*world.roofs.length)],side=Math.random()<.5?-1:1;
    shed.snow(new T.Vector3(roof.x+side*(roof.rx+.05),roof.y+.05,roof.z+(Math.random()*2-1)*roof.rz*.85),4,new T.Vector3(side*.55,0,0));
  }else{
    const tree=trees[Math.floor(Math.random()*trees.length)],seat=Math.random()<.5?tree.limb:tree.crown;
    shed.snow(seat.clone().add(new T.Vector3((Math.random()-.5)*1.2,-.25,(Math.random()-.5)*1.2)),3);
  }
}
// Moths and midges whirl around each lit lamp on mild nights.
const MOTHS=16,mothCount=MOTHS*lanterns.length;
const moths=particles(mothCount,new T.PointsMaterial({color:0xfff4e4,size:2.6,transparent:true,depthWrite:false,blending:T.AdditiveBlending,toneMapped:false}),(a,i)=>{a[i]=0;a[i+1]=-99;a[i+2]=0});
moths.frustumCulled=false;moths.visible=false;
const mothState=Array.from({length:mothCount},(_,i)=>({lamp:Math.floor(i/MOTHS),angle:rand()*6.28,spin:(rand()<.5?-1:1)*(2+rand()*4),radius:.15+rand()*.35,
  height:(rand()-.5)*.4,phase:rand()*50,dart:3+rand()*5}));
const lampCenter=new T.Vector3();
function flyMoths(dt,seconds,on){
  moths.visible=on>.01;if(!moths.visible)return;
  moths.material.opacity=on;
  const pos=moths.geometry.attributes.position;
  mothState.forEach((m,i)=>{
    const l=lanterns[m.lamp];
    lampCenter.set(0,-.485,0);l.pivot.localToWorld(lampCenter);
    m.angle+=dt*m.spin*(1+.6*Math.sin(seconds*2.3+m.phase));
    if(Math.sin(seconds*1.7+m.phase*3)>.97)m.spin*=-1;  // sudden turnabouts
    // every few seconds a moth dives at the glass and bounces off
    const dive=Math.max(0,Math.sin(seconds*Math.PI*2/m.dart+m.phase))**10;
    const r=(m.radius+.08*Math.sin(seconds*5.1+m.phase))*(1-.75*dive)+.06;
    pos.setXYZ(i,lampCenter.x+Math.cos(m.angle)*r,lampCenter.y+m.height+.12*Math.sin(seconds*3.7+m.phase)+.05*Math.sin(seconds*13+m.phase*2),lampCenter.z+Math.sin(m.angle)*r);
  });
  pos.needsUpdate=true;
}
const flies=particles(70,new T.PointsMaterial({color:0xffe794,size:6.5,map:haloMap,transparent:true,depthWrite:false,blending:T.AdditiveBlending,toneMapped:false}), (a,i)=>{a[i]=rand()*28-14;a[i+1]=1.6+rand()*3;a[i+2]=rand()*28-14});
const time=document.querySelector('#time'),weather=document.querySelector('#weather');
const wind=document.querySelector('#wind');
let weatherIndex=0,seasonIndex=1;
const weatherBlend=createWeatherTransition();
const backdrop=new T.Color();
const startHour=new URLSearchParams(location.search).get('time');
if(startHour)time.value=startHour==='night'?22:Number(startHour);
let nightLevel=0,skyTimer=0,lastProbe=-Infinity;
// Sliders set targets; the scene (and the drawn thumbs) glide toward them.
let hourShown=Number(time.value),hourTarget=hourShown,windShown=Number(wind.value),windTarget=windShown;
const slider=input=>input.closest('.slider');
function lighting(){
  const hour=hourShown<0?hourShown+24:hourShown,t=daylight(hour),w=weatherBlend.coverage;
  nightLevel=t.night;
  const moon=t.direction.y<0;
  sun.position.copy(t.direction);
  if(storybook.value&&!moon)sun.position.setZ(sun.position.z+.70).normalize();
  sun.position.multiplyScalar(moon?-33:33);
  sun.color.copy(moon?new T.Color(0xa5c3ee):t.color([0xffeed4,0xfff5df,0xffb48c,0xffb887,0xff8b4a]));
  const elevation=Math.abs(t.direction.y);
  sun.intensity=(moon?.34:2.85*(1+1.1*t.golden))*(moon?T.MathUtils.smoothstep(elevation,0,.24):T.MathUtils.smoothstep(elevation,-.02,.34))* (w<1?T.MathUtils.lerp(1,.52,w):T.MathUtils.lerp(.52,.25,w-1));
  sky.color.copy(t.color([0xe8f3fc,0xf3fbff,0xbab3ea,0x97aed6,0x8e88d4]));
  sky.intensity=t.value([.54,.62,.5,.10,.48])*(1-w*.09);
  backdrop.copy(t.color([0xacbfca,0x93b9d4,0xd8aaa6,0x17263f,0xd48b6c]));
  const overcast=w<1?w*.64:T.MathUtils.lerp(.64,.88,w-1);
  const dimming=w<1?T.MathUtils.lerp(1,.92,w):T.MathUtils.lerp(.92,.68,w-1);
  backdrop.lerp(t.color([0x909ea9,0xa2acb6,0x948895,0x202737]),overcast).multiplyScalar(dimming);
  if(!scene.background)scene.background=backdrop.clone();
  // Sky backdrop gradient, sun glow and grade for the composite pass: golden hours get a warm
  // key against lavender shadows, night a cool cast.
  const clear=1-Math.min(1,overcast*1.1),golden=t.golden*clear,nightCast=.35*t.night*(1-t.golden);
  const top=backdrop.clone().lerp(t.color([0x8fb3cc,0x7fa9cf,0x8f8bc0,0x0b1428,0x5f5498]),.6*clear).multiplyScalar(dimming);
  const bottom=backdrop.clone().lerp(t.color([0xd7dfd0,0xc6dae3,0xf6c4a4,0x223150,0xf4a066]),.55*clear).multiplyScalar(dimming);
  skyLook.top.copy(top);skyLook.bottom.copy(bottom);skyLook.glow.copy(t.color([0xfff0d0,0xfff0d0,0xffb08a,0x000000,0xff8a48])).multiplyScalar(Math.max(.25,golden));
  skyLook.stars=t.night*clear*clear*(1-t.golden);skyLook.sunY=t.direction.y;skyLook.hour=hour;
  const tint=(gold,cool)=>new T.Vector3(1,1,1).addScaledVector(gold,golden).addScaledVector(cool,nightCast);
  volume.grade({top,bottom,glow:t.color([0xfff0d0,0xfff0d0,0xffb08a,0x000000,0xff8a48]),glowAmount:2*golden*(1-t.night*.6),
    shadow:tint(t.dawn?new T.Vector3(-.12,-.08,.14):new T.Vector3(-.1,-.15,.12),new T.Vector3(-.12,-.06,.16)),
    highlight:tint(t.dawn?new T.Vector3(.1,.02,-.06):new T.Vector3(.17,-.01,-.17),new T.Vector3(-.04,0,.06)),
    saturation:1+.16*golden,vignette:.2+.1*t.night,
    // Bloom: a restrained glare by day, wide warm halos once the lamps are the brightest thing left.
    bloom:.05+.06*golden+.11*t.night,threshold:T.MathUtils.lerp(1.25,.55,t.night),stars:t.night*clear*clear*(1-t.golden)});
  document.body.style.backgroundColor=backdrop.getStyle();
  clearTimeout(skyTimer);
  const updateProbe=()=>{setSky(t,w,sun);lastProbe=performance.now()};
  if(performance.now()-lastProbe>(weatherBlend.active?450:document.querySelector('#autoTime').checked?1200:350))updateProbe();else if(!document.querySelector('#autoTime').checked&&!weatherBlend.active)skyTimer=setTimeout(updateProbe,120);
  volume.set(t,w,weatherBlend.density);atmosphere.set(t,w,weatherBlend.rain);
  // Lantern spots stay in the scene all day at zero intensity: toggling them would change the
  // light count and force every material to recompile at dusk. Their level (and the window
  // glass) is set every frame by flickerLamps and the interior.
  flies.visible=nightLevel>.6&&weatherIndex<2&&seasonIndex===1;
  const minutes=Math.round(hour*60),label=String(Math.floor(minutes/60)).padStart(2,'0')+':'+String(minutes%60).padStart(2,'0');
  document.querySelector('#hourText').textContent=label;time.setAttribute('aria-valuetext',label);
  slider(time).style.setProperty('--f',hour/24);
  drawHorizon(hour);
}
function setWind(){
  drawWind(windTarget);
  slider(wind).style.setProperty('--f',windShown/16);
  atmosphere.breeze.value=windShown/8;
  const label=(Math.round(windShown*10)/10)+' m/s';
  document.querySelector('#windText').textContent=label;
  wind.setAttribute('aria-valuetext',wind.value+' m/s');
}
const advanceTime=createDayClock(time,()=>{hourTarget=Number(time.value)});
lighting();setWind();wind.oninput=()=>{windTarget=Number(wind.value)};
bindGraphicsStyle(style=>{
  const enabled=style==='storybook';
  storybook.value=Number(enabled);
  switchStorybook(enabled);
  actorArt.select(enabled);
  refreshStyleShadows=true;
  lighting();
});
function glide(dt){
  let dh=hourTarget-hourShown;
  if(dh<-12&&document.querySelector('#autoTime').checked){hourShown-=24;dh+=24}  // auto clock wraps forward through midnight
  if(Math.abs(dh)>1e-4){
    hourShown+=dh*(1-Math.exp(-dt*(document.querySelector('#autoTime').checked?10:3.2)));
    if(Math.abs(hourTarget-hourShown)<2e-3)hourShown=hourTarget;
    lighting();
  }
  const dw=windTarget-windShown;
  if(Math.abs(dw)>1e-3){windShown+=dw*(1-Math.exp(-dt*1.6));if(Math.abs(windTarget-windShown)<.01)windShown=windTarget;setWind()}
}
// Walkers flatten the turf around them and leave a short trail that springs back.
// Walkers press the turf. Every press eases in and out (no slot ever switches on or off at
// full strength), and when slots run short the faintest press is the one dropped.
const presses=new Map(),trail=[];let trailClock=0;
function trample(dt){
  const slots=atmosphere.trample.value,ease=1-Math.exp(-dt*7);
  for(const b of world.colliders.bodies){
    let p=presses.get(b);if(!p){p={x:b.x,z:b.z,r:b.r*1.5,s:0};presses.set(b,p)}
    p.x=b.x;p.z=b.z;p.s+=((b.active?1:0)-p.s)*ease;
  }
  trailClock+=dt;
  if(trailClock>.15){trailClock=0;for(const b of world.colliders.bodies){
    if(b.active&&Math.hypot(b.x-(b.tx??1e9),b.z-(b.tz??1e9))>.14){b.tx=b.x;b.tz=b.z;trail.push({x:b.x,z:b.z,r:b.r*1.4,life:1,s:0})}
  }}
  for(const t of trail){t.life-=dt/2.6;const target=.7*Math.max(0,t.life)**1.5;t.s+=(target-t.s)*ease}
  for(let k=trail.length-1;k>=0;k--)if(trail[k].life<=0&&trail[k].s<.01)trail.splice(k,1);
  const all=[...presses.values(),...trail].filter(p=>p.s>.005).sort((a,b)=>b.s-a.s);
  let i=0;
  for(;i<slots.length&&i<all.length;i++){const p=all[i];slots[i].set(p.x,p.z,p.r,p.s)}
  for(;i<slots.length;i++)slots[i].w=0;
}
weather.onchange=e=>{weatherIndex=Number(e.target.value);weatherBlend.select(weatherIndex);drawWeather(weatherIndex)};
document.querySelector('#season').onchange=e=>{seasonIndex=Number(e.target.value);lighting()};
document.querySelector('#reset').onclick=home;
function resize(){const w=innerWidth,h=innerHeight,aspect=w/h,span=Math.max(31.5,46/aspect);camera.left=-span*aspect/2;camera.right=-camera.left;camera.top=span/2;camera.bottom=-camera.top;camera.updateProjectionMatrix();renderer.setSize(w,h,false);volume.resize(w,h);room.resize(w,h)}
window.addEventListener('resize',resize);resize();
// Shader warm-up: anything that only appears later (lantern spotlights at dusk, rain, snow,
// petals, fireflies, Unity-chan) changes light counts or adds materials, which makes three.js
// compile programs mid-game. Draw one hidden frame with all of it switched on instead.
function warmUp(){
  const hidden=[];scene.traverse(o=>{if(!o.visible&&!o.userData.styleVariant){hidden.push(o);o.visible=true}});
  const saved=lanterns.map(({spot})=>spot.intensity);
  for(const {spot} of lanterns){spot.intensity=1;spot.shadow.needsUpdate=true}
  renderer.shadowMap.needsUpdate=true;sun.shadow.needsUpdate=true;
  volume.render(scene,camera,0);
  for(const o of hidden)o.visible=false;
  lanterns.forEach(({spot},i)=>spot.intensity=saved[i]);
  lighting();
}
// ?weather=0-5 and ?season=0-3 open the scene already settled in that state (for checking looks).
{
  const query=new URLSearchParams(location.search),pick=(name,count)=>{
    const value=query.get(name);if(value===null||!(Number(value)>=0&&Number(value)<count))return null;
    document.querySelector('#'+name+' input[value="'+Number(value)+'"]').checked=true;return Number(value);
  };
  const startWeather=pick('weather',6),startSeason=pick('season',4);
  if(startWeather!==null){weatherIndex=startWeather;weatherBlend.select(weatherIndex);weatherBlend.update(100);drawWeather(weatherIndex);atmosphere.soak(weatherBlend.rain,100)}
  if(startSeason!==null)seasonIndex=startSeason;
  if(startWeather!==null||startSeason!==null)seasons(seasonIndex,weatherIndex,0,60,0,windShown,weatherBlend);
}
warmUp();unityChanReady.then(warmUp);
let previous=0,frameIndex=0,mothLevel=0;
renderer.shadowMap.autoUpdate=false;sun.shadow.autoUpdate=false;
renderer.setAnimationLoop(ms=>{
  advanceTime(ms);
  const elapsedFrame=Math.max(0,(ms-previous)/1000),dt=Math.min(.05,elapsedFrame);previous=ms;controls.update();
  // Shadows: the sun's map refreshes every other frame (swaying canopies stay smooth at 30 Hz).
  // A lantern's map refreshes every frame while a walker is inside its pool of light, so the
  // walker's shadow keeps up; otherwise it only sees a slight swing and the lamps take turns.
  frameIndex++;const sunTurn=refreshStyleShadows||frameIndex%2===0;let lampTurn=false;
  sun.shadow.needsUpdate=sunTurn;
  if(nightLevel>.01)lanterns.forEach(({spot,pivot},i)=>{
    const p=pivot.position;
    if(refreshStyleShadows||world.colliders.bodies.some(b=>b.active&&(b.x-p.x)**2+(b.z-p.z)**2<30)||(sunTurn&&(frameIndex/2)%lanterns.length===i)){spot.shadow.needsUpdate=true;lampTurn=true}
  });
  renderer.shadowMap.needsUpdate=sunTurn||lampTurn;
  refreshStyleShadows=false;
  glide(elapsedFrame);trample(dt);farm(elapsedFrame);
  const changingWeather=weatherBlend.active;weatherBlend.update(Math.min(.1,elapsedFrame));
  if(changingWeather)lighting();
  scene.background.lerp(backdrop,1-Math.exp(-3.8*Math.min(.5,elapsedFrame)));
  atmosphere.update(ms/1000);atmosphere.soak(weatherBlend.rain,Math.min(elapsedFrame,.5));
  volume.mood(atmosphere.snowDepth.value,atmosphere.wet.value,weatherBlend.rain,T.MathUtils.clamp((weatherBlend.density-1)/2.8,0,1),weatherBlend.storm,nightLevel);
  rain(dt,ms/1000,windShown,weatherBlend.rain,nightLevel);
  seasons(seasonIndex,weatherIndex,Math.min(elapsedFrame,.15),Math.min(elapsedFrame,4),ms/1000,windShown,weatherBlend);
  cascade.userData.update(ms/1000,atmosphere.breeze.value,1-.85*nightLevel);
  wildlife(ms/1000,windShown,nightLevel,atmosphere.breeze.value,atmosphere.winterBare.value);
  slideSnow(Math.min(elapsedFrame,.5));shed.update(dt,windShown);
  flickerLamps(dt,ms/1000);homeLife(dt,ms/1000,nightLevel);
  // Insects: warm, calm, dry-ish nights only; none in winter or snow.
  const mild=seasonIndex!==3&&[0,1,3].includes(weatherIndex)&&windShown<8;
  mothLevel=T.MathUtils.damp(mothLevel,mild?T.MathUtils.smoothstep(nightLevel,.3,.7):0,1.5,dt);
  flyMoths(dt,ms/1000,mothLevel*.85);
  prints.update(dt,weatherBlend.snow*(1+weatherBlend.storm));
  farmLife(dt,ms/1000,hourShown,weatherIndex,windShown,camera,nightLevel);
  unityChan(dt,ms/1000);
  if(followCharacter.checked&&trackedCharacter?.visible){
    trackedCharacter.getWorldPosition(followTarget);followTarget.y+=.55;
    followDelta.copy(followTarget).sub(controls.target).multiplyScalar(1-Math.exp(-4*elapsedFrame));
    // Equal translation preserves the user's orbit, distance and zoom. The one
    // controls.update() above handles input/damping before this tracking offset.
    controls.target.add(followDelta);camera.position.add(followDelta);
  }
  if(flies.visible){flies.position.y=Math.sin(ms*.0015)*.14;flies.rotation.y=Math.sin(ms*.00035)*.025;flies.material.opacity=.72+.25*Math.sin(ms*.0025)}
  const seconds=ms/1000;
  for(const {pivot} of lanterns){
    const phase=pivot.position.x*.39+pivot.position.z*.23;
    const gust=Math.sin(seconds*1.37-phase)+.42*Math.sin(seconds*2.31-phase*.71);
    pivot.rotation.z=gust*.11*atmosphere.breeze.value;
    pivot.rotation.x=.037*atmosphere.breeze.value*Math.sin(seconds*1.55-phase);
  }
  if(room.active)room.render(elapsedFrame,{night:nightLevel,cover:weatherBlend.coverage,haze:T.MathUtils.clamp((weatherBlend.density-1)/2.8,0,1),rain:weatherBlend.rain,snow:weatherBlend.snow,sun:sun.color,sky:skyLook});
  else volume.render(scene,camera,seconds);
});
