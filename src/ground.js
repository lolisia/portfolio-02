import * as T from 'three';

export function dressGround(ground,canvas,trees,path,wetness){
  const size=canvas.width,ctx=canvas.getContext('2d'),image=ctx.getImageData(0,0,size,size);
  const mask=document.createElement('canvas');mask.width=mask.height=size;
  const m=mask.getContext('2d');m.fillStyle='black';m.fillRect(0,0,size,size);
  m.globalCompositeOperation='lighter';
  function stamp(x,z,r,color,opacity){
    const radius=r*size/30,u=(x+15)*size/30,v=(z+15)*size/30;
    const grad=m.createRadialGradient(u,v,0,u,v,radius);
    grad.addColorStop(0,'rgba('+color+','+opacity+')');grad.addColorStop(1,'rgba('+color+',0)');
    m.fillStyle=grad;m.fillRect(u-radius,v-radius,radius*2,radius*2);
  }
  for(const [x,z,s] of trees)stamp(x,z,2.1*s,'255,0,0',1);
  for(const [x,z] of path)stamp(x,z,1.02,'0,255,0',.91);
  const zones=m.getImageData(0,0,size,size).data,rgba=image.data;
  const roughness=new Uint8Array(size*size*4);
  for(let j=0;j<size;j++)for(let i=0;i<size;i++){
    const k=4*(j*size+i),x=i*30/size-15,z=j*30/size-15;
    const grain=rgba[k]-124,variation=.11*Math.sin(3.6*x+Math.cos(z*4.1))+.06*Math.sin(z*7.4+x*2.);
    const trail=Math.min(1,Math.max(0,zones[k+1]/205+variation*.6));
    const litter=Math.min(1,Math.max(0,zones[k]/160+variation));
    const mud=T.MathUtils.smoothstep(wetness(x,z)+variation*.3,-.23,.095);
    for(let c=0;c<3;c++){
      let shade=T.MathUtils.lerp(rgba[k+c],[97,88,54][c]+grain,litter);
      shade=T.MathUtils.lerp(shade,[153,126,83][c]+grain*1.3,trail);
      rgba[k+c]=T.MathUtils.lerp(shade,[95,88,65][c]+grain,mud);
    }
    roughness.set([255,Math.round(244-155*mud-17*trail),255,255],k);
  }
  ctx.putImageData(image,0,0);
  let seed=8712;const rand=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);
  for(const [x,z,s] of trees)for(let i=0;i<295;i++){
    const a=rand()*6.283,d=(rand()+rand())*.93*s;
    const u=(x+15+Math.cos(a)*d)*size/30,v=(z+15+Math.sin(a)*d)*size/30;
    ctx.save();ctx.translate(u,v);ctx.rotate(rand()*6.28);ctx.fillStyle=['#93733d','#75613b','#ae894d','#827343','#5f5837'][i%5];
    ctx.beginPath();ctx.moveTo(-2,0);ctx.quadraticCurveTo(0,-1.5,2.8,0);ctx.quadraticCurveTo(0,1.8,-2,0);ctx.fill();ctx.restore();
  }
  const map=new T.DataTexture(roughness,size,size);map.flipY=true;map.minFilter=T.LinearMipmapLinearFilter;map.magFilter=T.LinearFilter;map.generateMipmaps=true;map.needsUpdate=true;
  ground.material.roughnessMap=map;ground.material.map.magFilter=T.LinearFilter;ground.material.map.needsUpdate=true;
}
