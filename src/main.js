import * as T from 'three';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {builder} from './modules.js';
import {createAtmosphere,surface} from './surfaces.js';
import {makeCascade} from './cascade.js';
import {createSky} from './sky.js';
import {createVolume} from './mist.js';
import {createDayClock,drawHorizon,drawWind,drawWeather} from './panel.js';
import {createSeasons} from './seasons.js';
import {daylight} from './daylight.js';
import {createRain} from './rain.js';
import {createWildlife} from './wildlife.js';
import {createFarmLife} from './farm-life.js';
import {createUnityChan} from './unitychan.js';
import {buildWorld} from './world.js';
import {loadNature} from './nature.js';
import {createWeatherTransition} from './weather.js';

const canvas=document.querySelector('#world');
const scene=new T.Scene(), renderer=new T.WebGLRenderer({canvas,antialias:false,powerPreference:'high-performance'});
renderer.toneMapping=T.ACESFilmicToneMapping;renderer.toneMappingExposure=1.14;
renderer.shadowMap.enabled=true;renderer.shadowMap.type=T.PCFShadowMap;
const camera=new T.OrthographicCamera(-22,22,15,-15,.1,180);
const controls=new OrbitControls(camera,canvas);controls.enableDamping=true;controls.zoomToCursor=true;controls.enablePan=false;
controls.minPolarAngle=.35;controls.maxPolarAngle=1.18;controls.minZoom=.7;controls.maxZoom=3.3;
function home(){controls.target.set(0,1,0);camera.position.set(31,34,41);camera.zoom=1;camera.updateProjectionMatrix();controls.update()}
home();
const view=new URLSearchParams(location.search).get('view');
if(view==='water'||view==='falls'){
  controls.target.set(10.6,.48,6.25);camera.position.copy(controls.target).add(new T.Vector3(19,13,26));
  if(view==='falls'){
    controls.target.set(13.4,-.10,6.1);camera.position.copy(controls.target).add(new T.Vector3(26,13,18));
  }
  camera.zoom=3.25;camera.updateProjectionMatrix();controls.update();
}
const sky=new T.DirectionalLight(0xc9e1fb,1.0),sun=new T.DirectionalLight(0xffe3b4,2.25);
sky.position.set(12,19,17);scene.add(sky,sun,new T.AmbientLight(0x8798ad,.11));sun.position.set(-13,24,9);sun.castShadow=true;
Object.assign(sun.shadow.camera,{left:-24,right:24,top:24,bottom:-24,near:.1,far:78});sun.shadow.camera.updateProjectionMatrix();renderer.shadowMap.autoUpdate=true;sun.shadow.mapSize.set(2048,2048);sun.shadow.normalBias=.028;sun.shadow.bias=-.00016;
const nature=await loadNature();
const b=builder(scene,undefined,nature), world=buildWorld(scene,b);b.finish();
const windowLight=new T.PointLight(0xffaf52,0,7,1.5);windowLight.position.set(-1,2.3,.16);scene.add(windowLight);
const cascade=makeCascade(world);scene.add(cascade);
const atmosphere=createAtmosphere(scene,world);
const seasons=createSeasons(scene,world,atmosphere);
const farmLife=createFarmLife(scene,world);
const unityChan=createUnityChan(scene,world);
const setSky=createSky(renderer,scene,world.water);
const volume=createVolume(renderer,world,sun,atmosphere.cloudMap);
const glowCanvas=document.createElement('canvas');glowCanvas.width=glowCanvas.height=128;
const glowContext=glowCanvas.getContext('2d');
const halo=glowContext.createRadialGradient(64,64,0,64,64,64);
for(const [stop,alpha] of [[0,1],[.09,.8],[.22,.32],[.5,.09],[1,0]])halo.addColorStop(stop,'rgba(255,206,134,'+alpha+')');
glowContext.fillStyle=halo;glowContext.fillRect(0,0,128,128);
const haloMap=new T.CanvasTexture(glowCanvas);haloMap.colorSpace=T.SRGBColorSpace;
const lanterns=world.lamps.map(pivot=>{
  const spot=new T.SpotLight(0xffba6c,0,8,1.17,.72,1.65);
  spot.position.set(0,-.765,0);
  spot.target.position.set(0,-3.485,0);
  spot.castShadow=true;spot.shadow.mapSize.set(256,256);spot.shadow.autoUpdate=false;spot.shadow.needsUpdate=true;spot.shadow.camera.near=.12;spot.shadow.bias=-.0007;
  const glow=new T.Sprite(new T.SpriteMaterial({map:haloMap,color:0xffc179,blending:T.AdditiveBlending,depthWrite:false}));
  glow.position.set(0,-.485,0);glow.scale.setScalar(2.4);
  pivot.add(spot,spot.target,glow);return {spot,glow,pivot};
});
function particles(count,material,initializer,lines=false){
  const data=new Float32Array(count*(lines?6:3));for(let i=0;i<count;i++)initializer(data,i*(lines?6:3));
  const geometry=new T.BufferGeometry();geometry.setAttribute('position',new T.BufferAttribute(data,3));
  const mesh=lines?new T.LineSegments(geometry,material):new T.Points(geometry,material);scene.add(mesh);return mesh;
}
const rand=b.rand;
const rain=createRain(scene,world),wildlife=createWildlife(scene,world);
const flies=particles(70,new T.PointsMaterial({color:0xffe794,size:6.5,map:haloMap,transparent:true,depthWrite:false,blending:T.AdditiveBlending,toneMapped:false}), (a,i)=>{a[i]=rand()*28-14;a[i+1]=1.6+rand()*3;a[i+2]=rand()*28-14});
const time=document.querySelector('#time'),weather=document.querySelector('#weather');
const wind=document.querySelector('#wind');
let weatherIndex=0,seasonIndex=1;
const weatherBlend=createWeatherTransition();
const backdrop=new T.Color();
if(new URLSearchParams(location.search).get('time')==='night')time.value=22;
let nightLevel=0,skyTimer=0,lastProbe=-Infinity;
// Sliders set targets; the scene (and the drawn thumbs) glide toward them.
let hourShown=Number(time.value),hourTarget=hourShown,windShown=Number(wind.value),windTarget=windShown;
const slider=input=>input.closest('.slider');
function lighting(){
  const hour=hourShown<0?hourShown+24:hourShown,t=daylight(hour),w=weatherBlend.coverage;
  nightLevel=t.night;
  const moon=t.direction.y<0;
  sun.position.copy(t.direction).multiplyScalar(moon?-33:33);
  sun.color.copy(moon?new T.Color(0xa5c3ee):t.color([0xffeed4,0xfff5df,0xffad75,0xffb887]));
  const elevation=Math.abs(t.direction.y);
  sun.intensity=(moon?.34:2.85)*T.MathUtils.smoothstep(elevation,0,moon?.24:.48)* (w<1?T.MathUtils.lerp(1,.52,w):T.MathUtils.lerp(.52,.25,w-1));
  sky.color.copy(t.color([0xe8f3fc,0xf3fbff,0xffdbc1,0x97aed6]));
  sky.intensity=t.value([.54,.62,.42,.10])*(1-w*.09);
  backdrop.copy(t.color([0xacbfca,0x93b9d4,0xcc998e,0x17263f]));
  const overcast=w<1?w*.64:T.MathUtils.lerp(.64,.88,w-1);
  const dimming=w<1?T.MathUtils.lerp(1,.92,w):T.MathUtils.lerp(.92,.68,w-1);
  backdrop.lerp(t.color([0x909ea9,0xa2acb6,0x948895,0x202737]),overcast).multiplyScalar(dimming);
  if(!scene.background)scene.background=backdrop.clone();
  document.body.style.backgroundColor=backdrop.getStyle();
  clearTimeout(skyTimer);
  const updateProbe=()=>{setSky(t,w,sun);lastProbe=performance.now()};
  if(performance.now()-lastProbe>(weatherBlend.active?450:document.querySelector('#autoTime').checked?1200:350))updateProbe();else if(!document.querySelector('#autoTime').checked&&!weatherBlend.active)skyTimer=setTimeout(updateProbe,120);
  volume.set(t,w,weatherBlend.density);atmosphere.set(t,w,weatherBlend.rain);
  surface('glass').emissiveIntensity=.025+nightLevel*2.5;
  for(const {spot,glow} of lanterns){
    spot.intensity=34*nightLevel;spot.visible=nightLevel>.01;
    glow.visible=spot.visible;glow.material.opacity=nightLevel*.78;
  }
  flies.visible=nightLevel>.6&&weatherIndex<2&&seasonIndex===1;windowLight.intensity=9*nightLevel;
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
const trail=[];let trailClock=0;
function trample(dt){
  const slots=atmosphere.trample.value,live=world.colliders.bodies.filter(b=>b.active);
  trailClock+=dt;
  if(trailClock>.18){trailClock=0;for(const b of live){
    if(Math.hypot(b.x-(b.tx??1e9),b.z-(b.tz??1e9))>.12){b.tx=b.x;b.tz=b.z;trail.push({x:b.x,z:b.z,r:b.r,life:1})}
  }}
  for(const t of trail)t.life-=dt/2.4;
  while(trail.length&&(trail[0].life<=0||trail.length>slots.length-live.length))trail.shift();
  let i=0;
  for(const b of live)if(i<slots.length)slots[i++].set(b.x,b.z,b.r*1.5,1);
  for(let k=trail.length-1;k>=0&&i<slots.length;k--){const t=trail[k];slots[i++].set(t.x,t.z,t.r*1.4,.75*t.life*t.life)}
  for(;i<slots.length;i++)slots[i].w=0;
}
weather.onchange=e=>{weatherIndex=Number(e.target.value);weatherBlend.select(weatherIndex);drawWeather(weatherIndex)};
document.querySelector('#season').onchange=e=>{seasonIndex=Number(e.target.value);lighting()};
document.querySelector('#reset').onclick=home;
// Adaptive resolution: the scene, AO and fog all render into targets sized by `quality`,
// which steps down when frames run long and back up when there is headroom.
let quality=Math.min(1,Math.sqrt(1920*1080/(innerWidth*innerHeight*Math.min(devicePixelRatio||1,1.5)))),frameAverage=16,qualityClock=0;
function resize(){const w=innerWidth,h=innerHeight,aspect=w/h,span=Math.max(31.5,46/aspect);camera.left=-span*aspect/2;camera.right=-camera.left;camera.top=span/2;camera.bottom=-camera.top;camera.updateProjectionMatrix();
  const scale=quality*Math.min(devicePixelRatio||1,1.5);renderer.setPixelRatio(scale);renderer.setSize(w,h,false);volume.resize(Math.round(w*scale),Math.round(h*scale))}
function adapt(ms){
  frameAverage+=(Math.min(ms,100)-frameAverage)*.05;qualityClock+=ms;
  if(qualityClock<1500)return;
  const next=frameAverage>28?Math.max(.45,quality*.85):frameAverage<18?Math.min(1,quality*1.06):quality;
  qualityClock=0;if(Math.abs(next-quality)>.01){quality=next;resize()}
}
window.addEventListener('resize',resize);resize();
let previous=0,frameIndex=0;
renderer.shadowMap.autoUpdate=false;
renderer.setAnimationLoop(ms=>{
  advanceTime(ms);
  const elapsedFrame=Math.max(0,(ms-previous)/1000),dt=Math.min(.05,elapsedFrame);previous=ms;controls.update();
  if(!document.hidden&&elapsedFrame<.5)adapt(elapsedFrame*1000);
  // Shadows: the sun's map refreshes every other frame (swaying canopies stay smooth at 30 Hz);
  // lantern maps, which only see a slight swing, refresh one lamp per frame in turn.
  frameIndex++;renderer.shadowMap.needsUpdate=frameIndex%2===0;
  if(renderer.shadowMap.needsUpdate&&nightLevel>.01)lanterns[(frameIndex/2)%lanterns.length].spot.shadow.needsUpdate=true;
  glide(elapsedFrame);trample(dt);
  const changingWeather=weatherBlend.active;weatherBlend.update(Math.min(.1,elapsedFrame));
  if(changingWeather)lighting();
  scene.background.lerp(backdrop,1-Math.exp(-3.8*Math.min(.5,elapsedFrame)));
  atmosphere.update(ms/1000);
  rain(dt,ms/1000,windShown,weatherBlend.rain,nightLevel);
  seasons(seasonIndex,weatherIndex,Math.min(elapsedFrame,.15),Math.min(elapsedFrame,4),ms/1000,windShown,weatherBlend);
  cascade.userData.update(ms/1000,atmosphere.breeze.value,1-.85*nightLevel);
  wildlife(ms/1000,windShown,nightLevel);
  farmLife(dt,ms/1000,hourShown,weatherIndex,windShown,camera,nightLevel);
  unityChan(dt,ms/1000,hourShown,weatherIndex,windShown);
  if(flies.visible){flies.position.y=Math.sin(ms*.0015)*.14;flies.rotation.y=Math.sin(ms*.00035)*.025;flies.material.opacity=.72+.25*Math.sin(ms*.0025)}
  const seconds=ms/1000;
  for(const {pivot} of lanterns){
    const phase=pivot.position.x*.39+pivot.position.z*.23;
    const gust=Math.sin(seconds*1.37-phase)+.42*Math.sin(seconds*2.31-phase*.71);
    pivot.rotation.z=gust*.11*atmosphere.breeze.value;
    pivot.rotation.x=.037*atmosphere.breeze.value*Math.sin(seconds*1.55-phase);
  }
  volume.render(scene,camera,seconds);
});

