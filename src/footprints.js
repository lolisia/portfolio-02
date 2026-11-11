import * as T from 'three';

// Prints pressed into the snow cover: soft blue-grey hollows with a bright packed rim, laid
// flat on the snow surface. Fresh snowfall fills them in, a thaw takes them with the cover.
function printTexture(draw){
  const cv=document.createElement('canvas');cv.width=cv.height=64;
  const ctx=cv.getContext('2d');ctx.translate(32,32);draw(ctx);
  const map=new T.CanvasTexture(cv);map.colorSpace=T.SRGBColorSpace;return map;
}
function hollow(ctx,shape,blur){
  ctx.filter=`blur(${blur}px)`;
  ctx.fillStyle='rgba(70,92,128,.9)';shape();ctx.fill();
  ctx.filter=`blur(${blur*.5}px)`;ctx.globalCompositeOperation='source-atop';
  ctx.fillStyle='rgba(40,56,86,.9)';ctx.translate(-1.5,1.5);shape();ctx.fill();ctx.translate(1.5,-1.5);
  ctx.globalCompositeOperation='source-over';ctx.filter='none';
}
const boot=printTexture(ctx=>{
  // a rounded sole: toe at -y (texture top), narrower heel below
  const shape=()=>{ctx.beginPath();ctx.ellipse(0,-9,10,15,0,0,6.283);ctx.ellipse(0,15,8,10,0,0,6.283)};
  hollow(ctx,shape,2.2);
});
const claw=printTexture(ctx=>{
  const shape=()=>{
    ctx.beginPath();ctx.lineCap='round';ctx.lineWidth=6;
    for(const a of [-.62,0,.62]){ctx.moveTo(0,10);ctx.lineTo(Math.sin(a)*24,10-Math.cos(a)*26)}
    ctx.moveTo(0,10);ctx.lineTo(0,22);
  };
  ctx.filter='blur(1.4px)';ctx.strokeStyle='rgba(60,80,116,.95)';shape();ctx.stroke();ctx.filter='none';
});

function layer(scene,map,capacity,size){
  const geometry=new T.PlaneGeometry(1,1);geometry.rotateX(-Math.PI/2);
  const fade=new Float32Array(capacity);
  geometry.setAttribute('printFade',new T.InstancedBufferAttribute(fade,1).setUsage(T.DynamicDrawUsage));
  const material=new T.MeshStandardMaterial({map,transparent:true,depthWrite:false,roughness:.9,color:0xd4e0f0,
    polygonOffset:true,polygonOffsetFactor:-2,polygonOffsetUnits:-2});
  material.onBeforeCompile=shader=>{
    shader.vertexShader='attribute float printFade;varying float vPrintFade;\n'+shader.vertexShader.replace('#include <begin_vertex>','#include <begin_vertex>\nvPrintFade=printFade;');
    shader.fragmentShader='varying float vPrintFade;\n'+shader.fragmentShader.replace('#include <alphamap_fragment>','#include <alphamap_fragment>\ndiffuseColor.a*=vPrintFade;');
  };
  const mesh=new T.InstancedMesh(geometry,material,capacity);mesh.count=0;mesh.frustumCulled=false;mesh.renderOrder=2;
  mesh.receiveShadow=true;scene.add(mesh);
  return {mesh,fade,size,items:[],next:0,capacity};
}

export function createFootprints(scene,world,atmosphere){
  const layers={boot:layer(scene,boot,360,[.1,.175]),claw:layer(scene,claw,420,[.075,.075])};
  const pose=new T.Object3D();
  // Same lift as the snow cover added to the terrain mesh in seasons.js.
  function surface(x,z){
    const base=world.height(x,z),bank=T.MathUtils.smoothstep(base,world.waterY+.015,world.waterY+.3);
    return base+atmosphere.snowDepth.value*bank*(.078+.031*Math.sin(x*1.7+Math.cos(z*.91)))+.012;
  }
  function press(kind,x,z,heading,scale=1){
    const snow=atmosphere.snowDepth.value;
    if(snow<.3||world.height(x,z)<world.waterY+.06)return;
    // Not on the porch, the steps or the coop ramp: only where the walker stands on the ground.
    if(world.stand(x,z)>world.height(x,z)+.02)return;
    const l=layers[kind],i=l.next;l.next=(i+1)%l.capacity;
    l.items[i]={x,z,heading,scale,life:1};
    l.mesh.count=Math.max(l.mesh.count,i+1);
  }
  function update(dt,snowfall){
    const cover=T.MathUtils.smoothstep(atmosphere.snowDepth.value,.3,.75);
    // Prints last about two minutes; falling snow fills them in within about forty seconds.
    const fill=dt*(1/120+snowfall/55);
    for(const l of Object.values(layers)){
      if(!l.mesh.count)continue;
      for(let i=0;i<l.mesh.count;i++){
        const p=l.items[i];
        if(!p||p.life<=0){l.fade[i]=0;continue}
        p.life-=fill;
        const y=surface(p.x,p.z);
        pose.position.set(p.x,y,p.z);pose.rotation.set(0,p.heading+Math.PI,0);  // textures are drawn toe-up
        pose.scale.set(l.size[0]*p.scale,1,l.size[1]*p.scale);pose.updateMatrix();l.mesh.setMatrixAt(i,pose.matrix);
        l.fade[i]=Math.max(0,Math.min(1,p.life*1.6))*cover;
      }
      l.mesh.instanceMatrix.needsUpdate=true;l.mesh.geometry.attributes.printFade.needsUpdate=true;
      l.mesh.visible=cover>0;
    }
  }
  return {press,update};
}
