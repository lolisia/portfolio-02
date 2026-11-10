const panel=document.querySelector('#panelBody');
const toggle=document.querySelector('#panelToggle');

function expand(open){
  panel.hidden=!open;toggle.setAttribute('aria-expanded',String(open));
  document.querySelector('#toggleLabel').textContent=open?'접기':'펼치기';
}
toggle.addEventListener('click',()=>expand(panel.hidden));
document.querySelector('#panel').addEventListener('keydown',event=>{
  if(event.key==='Escape'&&!panel.hidden){expand(false);toggle.focus()}
});

export {drawHorizon,drawWind,drawWeather} from './motion.js';

// The clock is anchored to elapsed real time so skipped frames do not slow the day.
export function createDayClock(slider,apply){
  const auto=document.querySelector('#autoTime');
  let origin=0,startHour=0,dragging=false;
  function anchor(now=performance.now()){origin=now;startHour=Number(slider.value)}
  function advance(now){
    const elapsed=Math.max(0,now-origin);
    const minutes=Math.floor(((startHour*60+elapsed*1440/120000)%1440)+1e-7)%1440;
    if(minutes!==Math.round(Number(slider.value)*60)){slider.value=minutes/60;apply()}
  }
  auto.addEventListener('change',()=>{
    if(auto.checked)anchor();
    else if(!dragging)advance(performance.now());
  });
  slider.addEventListener('input',()=>{anchor();apply()});
  slider.addEventListener('pointerdown',event=>{dragging=true;slider.setPointerCapture(event.pointerId)});
  slider.addEventListener('lostpointercapture',()=>{dragging=false;anchor()});
  return now=>{if(auto.checked&&!dragging)advance(now)};
}
