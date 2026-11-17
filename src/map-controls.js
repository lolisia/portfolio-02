import {MOUSE} from 'three';

// Mouse remains native OrbitControls. Touch uses relative finger angle instead
// of the native DOLLY_ROTATE gesture's centroid drag.
export function attachMapControls(controls,canvas,onPan=()=>{}){
  const saved={enablePan:controls.enablePan,screenSpacePanning:controls.screenSpacePanning,mouseButtons:controls.mouseButtons,touchAction:canvas.style.touchAction};
  controls.enablePan=true;controls.screenSpacePanning=true;
  controls.mouseButtons={LEFT:MOUSE.PAN,MIDDLE:MOUSE.DOLLY,RIGHT:MOUSE.ROTATE};
  canvas.style.touchAction='none';
  const view=canvas.ownerDocument?.defaultView??globalThis;
  const request=view.requestAnimationFrame?.bind(view)??(fn=>setTimeout(fn,0));
  const cancel=view.cancelAnimationFrame?.bind(view)??clearTimeout;
  const fingers=new Map();let mouse=null,origin=null,previous=null,mode=null,panning=false,hadMulti=false,queued=null;
  const stop=e=>{if(e.cancelable)e.preventDefault();e.stopImmediatePropagation()};
  const cancelQueued=()=>{if(queued!==null){cancel(queued);queued=null}};
  const pair=()=>{
    const [a,b]=fingers.values(),dx=b.x-a.x,dy=b.y-a.y;
    return {x:(a.x+b.x)/2,y:(a.y+b.y)/2,distance:Math.hypot(dx,dy),angle:Math.atan2(dy,dx),ay:a.y,by:b.y};
  };
  const angleDelta=(a,b)=>Math.atan2(Math.sin(a-b),Math.cos(a-b));
  const resetGesture=()=>{
    cancelQueued();mode=null;panning=false;
    if(fingers.size===1){const p=fingers.values().next().value;origin=previous={x:p.x,y:p.y}}
    else if(fingers.size===2)origin=previous=pair();else origin=previous=null;
  };
  function moveTouch(){
    queued=null;
    if(!controls.enabled){resetGesture();return}
    if(fingers.size===1&&!hadMulti&&controls.enablePan){
      const p=fingers.values().next().value;
      if(!panning&&Math.hypot(p.x-origin.x,p.y-origin.y)<6)return;
      if(!panning){panning=true;onPan()}
      controls.pan((p.x-previous.x)*controls.panSpeed,(p.y-previous.y)*controls.panSpeed);
      previous={x:p.x,y:p.y};return;
    }
    if(fingers.size!==2||!origin)return;
    const current=pair();if(current.distance<1||previous.distance<1)return;
    if(!mode){
      const dy=current.y-origin.y,a=current.ay-origin.ay,b=current.by-origin.by;
      const spread=Math.abs(current.distance-origin.distance),twist=Math.abs(angleDelta(current.angle,origin.angle))*origin.distance*.5;
      if(a*b>0&&Math.min(Math.abs(a),Math.abs(b))>=6&&Math.abs(dy)>Math.max(spread,twist)*1.4)mode='pitch';
      else if(spread>=3||twist>=3)mode='transform';else return;
    }
    if(mode==='pitch'){
      if(controls.enableRotate)controls.rotateUp(2*Math.PI*(current.y-previous.y)/Math.max(1,canvas.clientHeight)*controls.rotateSpeed);
    }else{
      if(controls.enableZoom)controls.dollyOut((current.distance/previous.distance)**controls.zoomSpeed);
      if(controls.enableRotate)controls.rotateLeft(angleDelta(current.angle,previous.angle)*controls.rotateSpeed);
    }
    previous=current;
  }
  function down(e){
    if(e.pointerType==='touch'){
      stop(e);if(!controls.enabled)return;
      fingers.set(e.pointerId,{x:e.clientX,y:e.clientY});if(fingers.size>1)hadMulti=true;
      try{canvas.setPointerCapture(e.pointerId)}catch{}
      resetGesture();return;
    }
    const action=controls.mouseButtons[['LEFT','MIDDLE','RIGHT'][e.button]],modified=e.ctrlKey||e.metaKey||e.shiftKey;
    const pan=modified?action===MOUSE.ROTATE:action===MOUSE.PAN;
    mouse={id:e.pointerId,x:e.clientX,y:e.clientY,pan,started:false};
  }
  function move(e){
    if(fingers.has(e.pointerId)){
      stop(e);const p=fingers.get(e.pointerId);p.x=e.clientX;p.y=e.clientY;
      if(queued===null)queued=request(moveTouch);return;
    }
    if(mouse?.id===e.pointerId&&mouse.pan&&!mouse.started&&controls.enabled&&controls.enablePan&&Math.hypot(e.clientX-mouse.x,e.clientY-mouse.y)>=6){mouse.started=true;onPan()}
  }
  function end(e){
    if(fingers.has(e.pointerId)){
      stop(e);
      if(e.type==='pointerup'&&queued!==null){cancelQueued();moveTouch()}else cancelQueued();
      fingers.delete(e.pointerId);
      try{if(canvas.hasPointerCapture(e.pointerId))canvas.releasePointerCapture(e.pointerId)}catch{}
      if(fingers.size===0)hadMulti=false;
      resetGesture();return;
    }
    if(mouse?.id===e.pointerId)mouse=null;
  }
  const events={pointerdown:down,pointermove:move,pointerup:end,pointercancel:end,lostpointercapture:end};
  for(const [name,handler] of Object.entries(events))canvas.addEventListener(name,handler,{capture:true,passive:false});
  return ()=>{
    for(const [name,handler] of Object.entries(events))canvas.removeEventListener(name,handler,true);
    cancelQueued();
    for(const id of fingers.keys())try{if(canvas.hasPointerCapture(id))canvas.releasePointerCapture(id)}catch{}
    fingers.clear();mouse=null;Object.assign(controls,{enablePan:saved.enablePan,screenSpacePanning:saved.screenSpacePanning,mouseButtons:saved.mouseButtons});canvas.style.touchAction=saved.touchAction;
  };
}
