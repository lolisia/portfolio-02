const canvases=[...document.querySelectorAll('.motion')];
const states={hour:8.5,wind:3,weather:0};
export const drawHorizon=h=>states.hour=h;
export const drawWind=w=>states.wind=w;
export const drawWeather=i=>states.weather=i;
const tau=Math.PI*2,clamp=v=>Math.max(0,Math.min(1,v));
const palette={deep:'#526d70',mid:'#809995',light:'#b8c9c3',sun:'#c5a66d'};
let hour=8.5,wind=3,cloud=0,rain=0,snow=0,fog=0,storm=0,phase=0,previous=0;
function disc(c,x,y,r,color){c.fillStyle=color;c.beginPath();c.arc(x,y,r,0,tau);c.fill()}
function stroke(c,color,width,fn){c.strokeStyle=color;c.lineWidth=width;c.beginPath();fn();c.stroke()}
function base(c){
  c.clearRect(0,0,220,94);
  const bg=c.createLinearGradient(0,0,220,94);
  bg.addColorStop(0,'#eff4efb8');bg.addColorStop(1,'#d7e3df70');
  c.fillStyle=bg;c.fillRect(0,0,220,94);
}
function land(c,y,color,amplitude){
  c.fillStyle=color;c.beginPath();c.moveTo(0,94);c.lineTo(0,y);
  c.bezierCurveTo(42,y-amplitude,71,y-amplitude,112,y);
  c.bezierCurveTo(156,y+amplitude,184,y-amplitude,220,y-3);
  c.lineTo(220,94);c.closePath();c.fill();
}
function horizon(c){
  const isDay=hour>=6&&hour<18;
  const progress=isDay?(hour-6)/12:((hour+6)%24)/12;
  const x=30+160*progress,y=62-34*Math.sin(progress*Math.PI);
  if(isDay){
    disc(c,x,y,23,'#c5a66d16');disc(c,x,y,16,'#c5a66d24');disc(c,x,y,11,palette.sun);
  }else{
    // A filled crescent keeps the night symbol distinct without darkening the UI.
    c.save();c.translate(x,y);c.fillStyle=palette.deep;c.beginPath();
    c.arc(0,0,12,.28*Math.PI,1.72*Math.PI);
    c.bezierCurveTo(-1,-9,-2,6,7.65,9.25);c.closePath();c.fill();c.restore();
  }
  land(c,72,'#b1c4bba6',18);land(c,82,'#7e9993b8',12);
  land(c,93,'#526d707d',8);
}
function winds(c){
  c.fillStyle='#80999544';c.beginPath();c.ellipse(110,80,30,5,0,0,tau);c.fill();
  stroke(c,palette.deep,5,()=>{c.moveTo(110,77);c.lineTo(110,36)});
  // Three solid cups orbit an elliptical plane. Angular speed follows m/s.
  const cups=Array.from({length:3},(_,i)=>{const a=phase*1.8+i*tau/3;return {x:110+43*Math.cos(a),y:35+13*Math.sin(a),a}}).sort((a,b)=>a.y-b.y);
  for(const cup of cups){
    stroke(c,palette.mid,4.5,()=>{c.moveTo(110,35);c.lineTo(cup.x,cup.y)});
    c.save();c.translate(cup.x,cup.y);c.rotate(Math.cos(cup.a)*.2);
    c.fillStyle=cup.y<35?palette.mid:palette.deep;c.beginPath();
    c.moveTo(-11,-4);c.lineTo(11,-4);c.bezierCurveTo(12,12,-12,12,-11,-4);c.closePath();c.fill();
    c.fillStyle=palette.light;c.beginPath();c.ellipse(0,-4,11,4,0,0,tau);c.fill();c.restore();
  }
  disc(c,110,35,6,palette.sun);
}
function cloudShape(c,x,y,scale,color){
  c.save();c.translate(x,y);c.scale(scale,scale);c.fillStyle=color;
  c.beginPath();c.moveTo(-37,12);
  c.bezierCurveTo(-57,12,-56,-12,-37,-13);
  c.bezierCurveTo(-32,-37,1,-40,12,-17);
  c.bezierCurveTo(35,-25,53,-9,44,6);
  c.quadraticCurveTo(41,15,28,15);c.closePath();c.fill();c.restore();
}
function weather(c,t){
  const sx=110-cloud*27,sy=40-cloud*11;
  c.save();c.globalAlpha=1-cloud*.3;
  disc(c,sx,sy,25,'#c5a66d18');disc(c,sx,sy,16,palette.sun);c.restore();
  c.save();c.globalAlpha=cloud;
  const drift=Math.sin(t*.35)*3;
  cloudShape(c,133+drift,42,.77,'#9fb5af');
  cloudShape(c,106+drift,44,.8,'#dce5df');
  c.restore();
  const power=rain+snow,ice=snow/Math.max(.001,power);
  for(let i=0;i<10;i++){
    const f=(t*(.65-.4*ice+storm*.5)+i*.618)%1;
    const x=80+(i*31)%65-f*(5+storm*21)+ice*Math.sin(t+i)*3,y=60+f*27;
    c.save();c.globalAlpha=power*Math.min(1,f*7,(1-f)*5)*.85;
    if(ice>.5)disc(c,x,y,2.4,palette.deep);
    else stroke(c,palette.deep,3.2,()=>{c.moveTo(x,y);c.lineTo(x-2.2,y+5)});
    c.restore();
  }
  for(let i=0;i<3;i++){
    c.save();c.globalAlpha=fog*(.7-i*.12);
    stroke(c,i===1?palette.mid:palette.light,5,()=>{
      const offset=Math.sin(t*.35+i)*6;
      c.moveTo(60+offset+i*7,62+i*10);c.lineTo(160+offset-i*9,62+i*10);
    });c.restore();
  }
}
const queries=matchMedia('(prefers-reduced-motion: reduce)');
function animate(ms){
  requestAnimationFrame(animate);
  if(document.querySelector('#panelBody').hidden){previous=ms;return}
  const dt=Math.min(.1,Math.max(0,(ms-previous)/1000)),k=queries.matches?1:1-Math.exp(-dt*5);previous=ms;
  hour+=(((states.hour-hour+36)%24)-12)*k;hour=(hour+24)%24;
  wind+=(states.wind-wind)*k;const w=states.weather;
  cloud+=((w===0?0:w===3?.7:1)-cloud)*k;rain+=((w===2?1:0)-rain)*k;snow+=((w>=4?1:0)-snow)*k;fog+=((w===3?1:0)-fog)*k;storm+=((w===5?1:0)-storm)*k;
  if(!queries.matches)phase+=dt*wind*.32;
  canvases.forEach((el,i)=>{
    const ratio=Math.min(devicePixelRatio||1,2),width=Math.round(el.clientWidth*ratio),height=Math.round(el.clientHeight*ratio);
    if(el.width!==width||el.height!==height){el.width=width;el.height=height}
    const c=el.getContext('2d');c.setTransform(width/220,0,0,height/94,0,0);c.lineCap='round';
    base(c);[horizon,winds,weather][i](c,queries.matches?0:ms/1000);
  });
}
requestAnimationFrame(animate);
