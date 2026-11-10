import * as T from 'three';
import {dressGround} from './ground.js';
import {makeWater} from './water.js';
import {builder,modules} from './modules.js';

export function buildWorld(scene,b){
  const {rand:r,pick,place,part:p}=b, kit=modules(b);
  const clamp=n=>Math.min(1,Math.max(0,n)), smooth=n=>(n=clamp(n))*n*(3-2*n);
  const pond=(x,z)=>1-((x-10.7)/4.5)**2-((z-6.3)/3.5)**2 +.11*Math.sin(z*2+x*.4);
  const outlet=(x,z)=>Math.min((x-11)*.9,1-Math.abs(z-6.1)/1.38);
  const wet=(x,z)=>Math.max(pond(x,z),outlet(x,z));
  function height(x,z){
    const terrace=smooth((-z-4+.7*Math.sin(x*.57)+.33*Math.cos(x*1.17))/2.05);
    return 1.05+terrace*1.85+.105*Math.sin(x*.63+z*.48)+.08*Math.cos(z*.91)-1.12*smooth((wet(x,z)+.19)*2.9);
  }
  const waterY=.44, floor=-2.48;
  const cv=document.createElement('canvas');cv.width=cv.height=1024;
  const ctx=cv.getContext('2d'), im=ctx.createImageData(1024,1024);
  for(let j=0;j<1024;j++)for(let i=0;i<1024;i++){
    const x=i*30/1024-15,z=j*30/1024-15;
    const field=Math.sin(x*1.4+Math.sin(z))*3+Math.cos(z*.94+x*.55)*5+Math.sin(z*3.2-x*2.2)*2;
    const n=field+(r()-.5)*11, shore=wet(x,z)>-.13;
    const k=(j*1024+i)*4;
    im.data[k]=(shore?125:123)+n;im.data[k+1]=(shore?129:149)+n;im.data[k+2]=(shore?87:73)+n*.62;im.data[k+3]=255;
  }ctx.putImageData(im,0,0);
  for(let i=0;i<55000;i++){const x=r()*1024,y=r()*1024;ctx.fillStyle=pick(['#53783a55','#cad57377','#839b4a88','#435d3655']);ctx.fillRect(x,y,1+r()*4,1+r()*3)}
  const tex=new T.CanvasTexture(cv);tex.colorSpace=T.SRGBColorSpace;tex.magFilter=T.NearestFilter;tex.anisotropy=4;
  const terrain=new T.PlaneGeometry(30,30,120,120);terrain.rotateX(-Math.PI/2);
  const pos=terrain.attributes.position;
  for(let i=0;i<pos.count;i++)pos.setY(i,height(pos.getX(i),pos.getZ(i)));
  terrain.computeVertexNormals();
  const ground=new T.Mesh(terrain,new T.MeshStandardMaterial({map:tex,roughness:1}));ground.receiveShadow=true;ground.castShadow=true;scene.add(ground);
  // Exposed soil and chipped stone strata follow the perimeter of all 900 tiles.
  for(let side=0;side<4;side++)for(let i=0;i<120;i++){
    const t=(i+.5)*.25-15,x=side===0?15:side===1?-15:t,z=side===2?15:side===3?-15:t;
    const top=height(x,z), earth=.36+.055*Math.sin(t), w=side<2?.08:.255,d=side<2?.255:.08;
    p('stone',x,top-earth/2-.015,z,w,earth+.015,d,pick(['#815a3c','#80583b','#896346']));
    const rockH=top-earth-floor;
    for(let j=0;j<4;j++)p('stone',x,floor+(j+.5)*rockH/4,z,w,rockH/4+.013,d,pick([['#474f54','#4d5559'],['#545d60','#586165'],['#667070','#61696a'],['#737771','#707571']][j]));
  }
  const water=makeWater(height,waterY);scene.add(water);
  const at=(x,z,scale,angle,fn)=>place(x,height(x,z),z,scale,angle,fn);
  const obstacles=[];
  function occupy(x,z,rad){obstacles.push([x,z,rad])}
  function free(x,z,pad=0){return obstacles.every(([a,c,d])=>(x-a)**2+(z-c)**2>(d+pad)**2)}
  const props=[[-1,-1.8,1,0],[2.25,-1.92,1,.025],[4.45,-1.9,1,-.035]];
  props.forEach(([x,z,s,a],i)=>{at(x,z,s,a,()=>kit.house(i>0,i===1));occupy(x,z,i?1.4:1.95)});
  for(const [x,z] of [[1.1,3.3],[2.7,3.3],[-7,-9.5],[-5.45,-9.5]]){at(x,z,1,0,kit.bed);occupy(x,z,1)}
  const paths=[];
  function path(ax,az,bx,bz,stair=false){
    const len=Math.hypot(ax-bx,az-bz),count=Math.ceil(len/(stair?.46:.73));
    for(let i=0;i<count;i++){
      const f=i/count,x=ax+(bx-ax)*f+(r()-.5)*.12,z=az+(bz-az)*f+(r()-.5)*.13;
      if(wet(x,z)>-.19)continue;
      p('stone',x,height(x,z)+.024,z,stair?1.15:.65+r()*.17,stair?.19:.09,stair?.55:.47+r()*.14,pick(stair?['#aaa58b','#92967e','#a7a48a']:['#c5ae84','#d3b990','#baaa81']),0,Math.atan2(bx-ax,bz-az)+(r()-.5)*.18);
      paths.push([x,z]);
    }
  }
  path(-7,-10,-5,-6.3);path(-5,-6.3,-4.4,-2.25,true);path(-4.4,-2.25,-2,.8);path(-2,.8,5.5,.82);path(5.5,.82,10.8,3.0);path(1,.8,1,2.6);
  place(13.7,waterY+.48,6.1,1,0,()=>kit.bridge(3.9));
  const treeList=[[-13,-12,1.40],[-10.8,-13.9,1.02],[-9,-12.1,1.22],[-5,-13.5,1.26],[-1.8,-13,1.28],[2,-13.6,1.45],[5.6,-12.1,1.12],[9.5,-12.8,1.35],[12.5,-10,1.45],[-13,-8.7,1.18],[-11,-6.4,1.25],[-13,-3.8,1.52],[-12,.2,1.13],[-13.4,3.7,1.21],[-11.8,7.2,1.28],[-13,11.4,1.35],[-8.9,12.7,1.27],[-5,13.1,1.36],[-1.4,12.1,1.05],[3.1,13.2,1.24],[7.4,12.7,1.13],[12.1,11.8,1.25],[12.2,.1,1.28],[10.5,-3.5,1.16],[12.5,-5.6,1.1],[-6.1,1.8,.76],[-3.95,2.0,.69],[-8.5,6.2,.83],[6.1,-8.2,.88],[.4,-9.8,1.08],[-9, -2.7,.77]];
  dressGround(ground,cv,treeList,paths,wet);
  treeList.forEach(([x,z,s],i)=>{at(x,z,s,r()*6,()=>b.canopy(()=>kit.tree([3,6,12,24,29].includes(i))));occupy(x,z,.58*s)});
  function clear(x,z){return free(x,z,.16)&&wet(x,z)<-.13&&!paths.some(([a,c])=>(a-x)**2+(c-z)**2<.42)}
  for(let i=0;i<440;i++){const x=r()*29.2-14.6,z=r()*29.2-14.6;if(!clear(x,z))continue;
    if(i%4===0){at(x,z,.6+r()*.76,r()*6,kit.flowers)}
    else if(i%5===0){for(let j=0;j<5;j++){const a=x+(r()-.5)*.75,c=z+(r()-.5)*.75,s=.18+r()*.5;p('boulder',a,height(a,c)+s*.16,c,s,s*.74,s*.88,pick(['#82877a','#989c87','#747b73','#a3a48d']),0,r()*5)}}
    else if(i%6===0){for(let j=0;j<9;j++){const a=x+(r()-.5)*.8,c=z+(r()-.5)*.8;p('rock',a,height(a,c)+.21,c,.48,.47+r()*.26,.52,pick(['#607d3d','#7e9949','#8b9f4f']),0,r()*5)}}
  }
  for(let i=0;i<9500;i++){const x=r()*29.85-14.925,z=r()*29.85-14.925;if(!clear(x,z)||Math.sin(x*1.45+Math.cos(z*2))+Math.sin(z*1.2+x*.6)<-.72)continue;
    for(let j=0;j<3;j++){const a=x+(r()-.5)*.2,c=z+(r()-.5)*.2,h=.07+r()*.22;p('cone',a,height(a,c)+h*.45,c,.04+r()*.07,h,.055,pick(['#536e37','#718a40','#98aa58','#899d4c']),0,r()*5,(r()-.5)*.64)}
  }
  for(const [x,z] of [[-8.5,-4.2],[7.6,10.4],[-6,8]]){at(x,z,1,r()*2,()=>{p('trunk',0,.27,0,.48,1.67,.5,'#6c4f32',0,0,1.50);p('trunk',.835,.22,0,.39,.028,.39,'#c4a471',0,0,1.50)})}
  // Gravel in the shallows and clumps of reeds give the transparent shoreline scale.
  for(let i=0;i<850;i++){
    const x=6+r()*8.75,z=2.45+r()*8,depth=waterY-height(x,z);
    if(depth<-.12 || depth>.49 || x>13.1)continue;
    const size=.055+r()*.17;
    p('boulder',x,waterY-depth+.024,z,size,size*.58,size*.79,pick(['#888979','#9e997c','#667568']),0,r()*6);
    if(depth<.17 && Math.sin(x*1.8+z*.62)>.48){
      for(let k=0;k<5;k++){
        const a=x+(r()-.5)*.23,c=z+(r()-.5)*.21,h=.26+r()*.37;
        p('cone',a,height(a,c)+h*.46,c,.052,h,.045,pick(['#768449','#8c9751','#516f42']),0,r()*5,(r()-.5)*.57);
      }
    }
  }
  const lamps=[];
  for(const [x,z,angle] of [[-6.1,-7.35,0],[-3.75,-2.5,2.7],[.04,1.58,-1],[6.3,.60,1.35],[13.07,3.74,0]]){
    at(x,z,1,angle,()=>kit.lantern('post'));
    const pivot=new T.Group(),parts=builder(pivot);
    pivot.position.set(x+.48*Math.cos(angle),height(x,z)+2.385,z-.48*Math.sin(angle));
    pivot.rotation.y=angle;
    parts.place(-.48,-2.385,0,1,0,()=>modules(parts).lantern('pendant'));
    parts.finish();scene.add(pivot);lamps.push(pivot);
  }
  const perches=treeList.map(([x,z,s])=>new T.Vector3(x+.36*s,height(x,z)+3.97*s,z+.25*s));
  perches.push(...lamps.map(p=>p.position.clone().add(new T.Vector3(0,.08,0))));
  ground.material.name='terrain';
  return {water,floor,waterY,lamps,height,perches,props,ground,walkable:(x,z)=>free(x,z,.24)&&wet(x,z)<-.2};
}
