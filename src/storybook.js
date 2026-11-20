import * as T from 'three';
import {mergeGeometries} from 'three/addons/utils/BufferGeometryUtils.js';
import {surface} from './surfaces.js';

function oakCrown(spread){
  const pieces=[];
  const lobe=(x,y,z,w,h,d,phase,detail)=>{
    const geo=new T.SphereGeometry(1,detail,Math.ceil(detail/2)+1);
    const p=geo.attributes.position;
    for(let i=0;i<p.count;i++){
      const a=p.getX(i),b=p.getY(i),c=p.getZ(i);
      const r=1+.12*Math.sin(7*a+phase)*Math.cos(6*c-5*b)+.058*Math.sin(13*b+8*c+phase);
      p.setXYZ(i,a*r*w,b*r*h,c*r*d);
    }
    geo.computeVertexNormals();
    geo.translate(x,y,z);pieces.push(geo);
  };
  lobe(0,3.04,0,.91,.74,.89,8,15);
  for(let i=0;i<8;i++){
    const a=i*2.399963,reach=(i<6?1.03:.48)*spread;
    const x=Math.cos(a)*reach,z=Math.sin(a)*reach;
    const y=(i<6?2.71:3.36)+.18*Math.sin(i*4.6);
    lobe(x,y,z,.62,.47,.61,i,12);
    for(let j=0;j<5;j++){
      const b=a+j*Math.PI*.4, size=.27+.10*Math.sin(i+j*2.3)**2;
      lobe(x+Math.cos(b)*.48,y+.07+.15*Math.cos(j*3+i),z+Math.sin(b)*.46,size,size*.67,size*.86,j+i,12);
    }
  }
  const crown=mergeGeometries(pieces);
  pieces.forEach(geo=>geo.dispose());
  return crown;
}

function pineCrown(){
  // Curved, overlapping whorls with staggered tips give the fir its tiered silhouette.
  const positions=[],indices=[],segments=32;
  for(let tier=0;tier<8;tier++){
    const base=positions.length/3,y=1.03+tier*.41;
    const reach=1.57*(1-tier/8)**1.12+.13;
    const rings=[[.11,-.04],[.64,-.11],[1,0],[.76,.13],[.46,.35],[.23,.61],[.008,.79]];
    rings.forEach(([radius,height],ring)=>{
      for(let k=0;k<segments;k++){
        const a=k/segments*Math.PI*2;
        const lobes=.83+.16*Math.cos(a*8+tier*1.9)+.07*Math.cos(a*5-tier);
        const r=reach*radius*lobes;
        positions.push(Math.cos(a)*r,y+height+.08*radius*Math.sin(a*8+tier*1.9),Math.sin(a)*r);
        const i=base+ring*segments+k,next=base+ring*segments+(k+1)%segments;
        if(ring)indices.push(i-segments,i,next,i-segments,next,next-segments);
      }
    });
  }
  const geo=new T.BufferGeometry();
  geo.setAttribute('position',new T.Float32BufferAttribute(positions,3));
  geo.setIndex(indices);geo.computeVertexNormals();return geo;
}

function pineTrunk(){
  const trunk=new T.CylinderGeometry(.026,.19,4.24,9,4);
  trunk.translate(0,2.12,0);
  trunk.setAttribute('color',new T.Float32BufferAttribute(new Float32Array(trunk.attributes.position.count*3).fill(1),3));
  return trunk;
}

export function createStorybook(scene){
  const swaps=[];
  const palette={
    oakALeaves:['story-oak',0xb4cf49,()=>oakCrown(1)],
    oakBLeaves:['story-oak',0xa1bc43,()=>oakCrown(1.12)],
    pineANeedles:['story-pine',0x367e69,pineCrown],
    pineABark:['bark',0x745133,pineTrunk]
  };
  const matrix=new T.Matrix4(),color=new T.Color();
  for(const [name,[material,tint,createGeometry]] of Object.entries(palette)){
    const original=scene.getObjectByName(name);
    if(!original)continue;
    const geometry=createGeometry();
    for(const attribute of ['bendRoot','plantMask'])geometry.setAttribute(attribute,original.geometry.getAttribute(attribute));
    const alternate=new T.InstancedMesh(geometry,surface(material),original.count);
    for(let i=0;i<original.count;i++){
      original.getMatrixAt(i,matrix);original.getColorAt(i,color);
      alternate.setMatrixAt(i,matrix);
      const lightness=T.MathUtils.clamp(color.g*.6+.73,.85,1.06);
      alternate.setColorAt(i,color.setHex(tint).multiplyScalar(lightness));
    }
    alternate.name='storybook-'+name;
    alternate.castShadow=original.castShadow;alternate.receiveShadow=true;
    alternate.visible=false;alternate.userData.styleVariant=true;
    original.userData.styleVariant=true;
    scene.add(alternate);swaps.push([original,alternate]);
  }
  for(let i=0;i<3;i++){
    const original=scene.getObjectByName('turf'+i);
    if(!original)continue;
    const geometry=original.geometry.clone(),indices=[];
    // Spread the retained tufts over the entire island while keeping their wind roots.
    for(let j=0;j<original.count;j++)if(((Math.imul(j+17,0x9e3779b1)>>>0)%11)<3)indices.push(j);
    const alternate=new T.InstancedMesh(geometry,original.material,indices.length);
    const bend=original.geometry.getAttribute('bendRoot'),plant=original.geometry.getAttribute('plantMask');
    geometry.setAttribute('bendRoot',new T.InstancedBufferAttribute(new Float32Array(indices.flatMap(j=>Array.from(bend.array.subarray(j*4,j*4+4)))),4));
    geometry.setAttribute('plantMask',new T.InstancedBufferAttribute(new Float32Array(indices.map(j=>plant.getX(j))),1));
    indices.forEach((index,j)=>{
      original.getMatrixAt(index,matrix);original.getColorAt(index,color);
      alternate.setMatrixAt(j,matrix);alternate.setColorAt(j,color);
    });
    alternate.name='storybook-'+original.name;alternate.receiveShadow=true;
    alternate.visible=false;alternate.userData.styleVariant=true;
    original.userData.styleVariant=true;
    scene.add(alternate);swaps.push([original,alternate]);
  }
  return enabled=>{
    for(const [original,alternate] of swaps){
      original.visible=!enabled;alternate.visible=enabled;
    }
  };
}

export function paintClouds(){
  const canvas=document.createElement('canvas');canvas.width=1536;canvas.height=1024;
  const ctx=canvas.getContext('2d');
  const clusters=[[16,218,1.02],[210,308,.63],[878,149,.8],[1138,249,1.2],[1275,341,.58]];
  for(const [x,y,s] of clusters){
    ctx.save();ctx.translate(x,y);ctx.scale(s,s);ctx.rotate(-.12);
    const body=new Path2D('M0 0 Q62 -10 120 -27 Q143 -41 162 -39 C162 -56 177 -75 199 -80 Q223 -102 247 -84 C276 -93 297 -66 279 -48 Q313 -53 349 -45 L400 -49 Q341 -26 282 -20 Q238 -11 217 -10 L134 -5 L174 -18 Q77 1 0 0 Z');
    ctx.fillStyle='#fff1d8';ctx.fill(body);
    ctx.save();ctx.clip(body);
    const shadow=new Path2D('M64 3 Q113 -11 148 -17 Q180 -25 210 -39 Q229 -53 216 -60 Q239 -57 240 -70 Q250 -83 270 -77 Q277 -65 263 -52 Q253 -45 246 -38 Q284 -48 304 -47 L395 -44 L440 14 Z');
    ctx.fillStyle='#d9d9d9';ctx.fill(shadow);ctx.restore();
    ctx.fillStyle='#fff4de';
    ctx.fill(new Path2D('M52 11 Q108 3 140 -7 L124 3 Z M275 -11 L331 -21 L305 -13 Z'));
    ctx.restore();
  }
  const texture=new T.CanvasTexture(canvas);texture.colorSpace=T.SRGBColorSpace;
  return texture;
}
