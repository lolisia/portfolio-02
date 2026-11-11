import * as T from 'three';
import {field} from './surfaces.js';

// Close-up soil for worn ground: grain, cracks and scattered pebbles on a tileable 512px
// square (about 1.7 tiles). Colour is a linear multiplier around 0.5; height drives bump.
function soilDetail(){
  const size=512,coarse=field(6,331),fine=field(40,977),grit=field(150,613);
  const color=document.createElement('canvas'),bump=document.createElement('canvas');
  color.width=color.height=bump.width=bump.height=size;
  const c=color.getContext('2d'),b=bump.getContext('2d');
  const ci=c.createImageData(size,size),bi=b.createImageData(size,size);
  for(let j=0;j<size;j++)for(let i=0;i<size;i++){
    const u=i/size,v=j/size,k=4*(j*size+i);
    const lump=coarse(u,v),clod=fine(u,v),g=grit(u,v);
    const crack=Math.pow(1-Math.abs(fine(u*2+.3*lump,v*2)-.5)*2,18);
    const m=.4+.16*lump+.12*clod+.1*g-.17*crack;
    ci.data.set([m*255*1.02,m*255,m*255*.96,255],k);
    const h=110+60*clod+40*g+30*lump-70*crack;bi.data.set([h,h,h,255],k);
  }
  c.putImageData(ci,0,0);b.putImageData(bi,0,0);
  let seed=5531;const rand=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);
  const tones=[[170,168,165],[150,138,120],[110,104,98],[185,176,160],[132,120,104]];
  for(let n=0;n<520;n++){
    const x=rand()*size,y=rand()*size,r=1.2+Math.pow(rand(),2.4)*7,a=rand()*Math.PI,squash=.55+rand()*.4,t=tones[n%5];
    for(const ox of [-size,0,size])for(const oy of [-size,0,size]){
      if(x+ox<-10||x+ox>size+10||y+oy<-10||y+oy>size+10)continue;
      for(const [ctx,fill,shade] of [[c,t,1],[b,null,0]]){
        ctx.save();ctx.translate(x+ox,y+oy);ctx.rotate(a);ctx.scale(1,squash);
        const g=ctx.createRadialGradient(-r*.3,-r*.35,r*.1,0,0,r);
        if(fill){
          g.addColorStop(0,'rgb('+fill.map(v=>Math.min(255,v*1.12)).join(',')+')');
          g.addColorStop(.75,'rgb('+fill.join(',')+')');g.addColorStop(1,'rgb('+fill.map(v=>v*.62).join(',')+')');
        }else{g.addColorStop(0,'rgb(255,255,255)');g.addColorStop(.7,'rgb(200,200,200)');g.addColorStop(1,'rgb(120,120,120)')}
        ctx.fillStyle=g;ctx.beginPath();ctx.arc(0,0,r,0,6.283);ctx.fill();ctx.restore();
      }
    }
  }
  const make=(cv,repeat)=>{const t=new T.CanvasTexture(cv);t.wrapS=t.wrapT=T.RepeatWrapping;t.anisotropy=8;t.repeat.set(repeat,repeat);return t};
  return {color:make(color,18),bump:make(bump,18)};
}

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
    roughness.set([255,Math.round(244-155*mud-17*trail),Math.round(255*trail),255],k);
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
  ground.material.roughnessMap=map;
  // Trail strength rides in the roughness map's blue channel; surfaces.js blends the soil in.
  const soil=soilDetail();ground.material.bumpMap=soil.bump;ground.material.bumpScale=1.6;ground.material.userData.soilMap=soil.color;ground.material.map.magFilter=T.LinearFilter;ground.material.map.needsUpdate=true;
}
