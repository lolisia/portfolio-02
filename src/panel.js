const panel=document.querySelector('#panelBody');
const toggle=document.querySelector('#panelToggle');

// The body folds with a grid-row transition; `inert` keeps the folded controls out of tab order.
const isOpen=()=>document.querySelector('#panel').classList.contains('open');
function expand(open){
  document.querySelector('#panel').classList.toggle('open',open);panel.inert=!open;
  toggle.setAttribute('aria-expanded',String(open));
  document.querySelector('#toggleLabel').textContent=open?'접기':'펼치기';
}
toggle.addEventListener('click',()=>expand(!isOpen()));
document.querySelector('#panel').addEventListener('keydown',event=>{
  if(event.key==='Escape'&&isOpen()){expand(false);toggle.focus()}
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
