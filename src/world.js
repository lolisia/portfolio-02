import * as T from 'three';
import {dressGround} from './ground.js';
import {makeWater} from './water.js';
import {builder,modules,COTTAGE,cottageSteps} from './modules.js';
import {createColliders} from './colliders.js';

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
  const obstacles=[],bushes=[],stumps=[],colliders=createColliders();
  function occupy(x,z,rad){obstacles.push([x,z,rad])}
  function free(x,z,pad=0){return obstacles.every(([a,c,d])=>(x-a)**2+(z-c)**2>(d+pad)**2)}
  const props=[[-1,-2.5,1,0],[2.25,-1.92,1,.025],[4.45,-1.9,1,-.035]];
  // The cottage (prop 0, unrotated) sits on its plinth; the porch steps make up the drop to the
  // ground in front of them.
  const [hx,hz]=props[0],{W,D,F,P,B,E,slope,over,run}=COTTAGE,houseY=height(hx,hz);
  const porchZ=hz+D/2+P,drop=Math.max(.12,houseY+F-height(hx,porchZ+.35)),steps=cottageSteps(drop);
  props.forEach(([x,z,s,a],i)=>{at(x,z,s,a,()=>i?kit.house(i===1):kit.cottage(drop));occupy(x,z,i?1.4:2.3)});
  occupy(hx,porchZ+.2,.75);
  // Collision footprints: house walls and porch railings, plus the coop / shed ramps.
  colliders.box(hx,hz,W+.26,D+.26,0,'house');
  for(const s of [-1,1]){
    colliders.box(hx+s*(W/2-.06),hz+D/2+.13+(P-.13)/2,.14,P-.13,0,'house');
    colliders.box(hx+s*(W/2+.58)/2,porchZ-.06,W/2-.58,.14,0,'house');
    colliders.circle(hx+s*(COTTAGE.BW/2-.05),hz+D/2+B-.08,.1,'house');
  }
  props.forEach(([x,z,s,a],i)=>{
    if(!i)return;
    const w=1.76,d=1.82,tag=i===1?'coop':'';
    colliders.box(x,z,w*s,d*s,a,tag);
    const f=d/2+.6;colliders.box(x+Math.sin(a)*f,z+Math.cos(a)*f,.86,1.2,a,tag);
  });
  // Standing height: the porch deck and its steps, otherwise the ground.
  function stand(x,z){
    const lx=x-hx,lz=z-hz,ground=height(x,z);
    if(Math.abs(lx)<W/2&&lz>D/2&&lz<D/2+P)return houseY+F;
    const k=Math.floor((lz-D/2-P)/run)+1;
    if(Math.abs(lx)<.5&&k>=1&&k<=steps)return Math.max(ground,houseY+F-k*drop/(steps+1));
    return ground;
  }
  const span=W/2+over,zFront=D/2+B+.28,zBack=-D/2-.35;
  const roofs=[{x:hx,z:hz+(zFront+zBack)/2,rx:span,rz:(zFront-zBack)/2,y:houseY+E,slope},
    ...props.slice(1).map(([x,z])=>({x,z,rx:1.10,rz:1.1,y:height(x,z)+2.15,slope:.6}))];
  const cottage={door:{x:hx,z:hz+D/2+.4},apron:{x:hx,z:porchZ+steps*run+.3},
    chimney:new T.Vector3(hx+COTTAGE.chimney[0],houseY+E+span*slope+.58,hz+COTTAGE.chimney[1]),
    ridge:new T.Vector3(hx,houseY+E+span*slope+.1,hz-.5),window:new T.Vector3(hx,houseY+F+1.1,hz+D/2+.7)};
  for(const [x,z] of [[1.1,3.3],[2.7,3.3],[-7,-9.5],[-5.45,-9.5]]){at(x,z,1,0,kit.bed);occupy(x,z,1);colliders.box(x,z,1.32,1.72,0,'bed')}
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
  // Hillside stairs: a switchback across the slope with level treads and ~0.11 risers, sized
  // for the SD character instead of slabs laid on the raw 25-degree terrain.
  function stairs(points){
    const legs=[];let total=0;
    for(let i=1;i<points.length;i++){const [ax,az]=points[i-1],[bx,bz]=points[i],len=Math.hypot(bx-ax,bz-az);legs.push({ax,az,bx,bz,len,start:total});total+=len}
    const top=height(...points[0]),bottom=height(...points.at(-1)),count=Math.max(Math.ceil(Math.abs(top-bottom)/.11),Math.ceil(total/.42));
    const run=total/count,list=[];
    for(let k=0;k<count;k++){
      const at=(k+.5)*run,leg=legs.find(l=>at<=l.start+l.len)||legs.at(-1),u=(at-leg.start)/leg.len;
      const x=leg.ax+(leg.bx-leg.ax)*u,z=leg.az+(leg.bz-leg.az)*u,angle=Math.atan2(leg.bx-leg.ax,leg.bz-leg.az);
      // Each tread sits just above the highest ground under its footprint (never sunk into the
      // slope); where the hillside bulges the flight simply climbs over it.
      let ground=-Infinity,low=Infinity;
      for(const a of [-.52,0,.52])for(const c of [-.5,0,.5]){
        const gx=x+Math.cos(angle)*a+Math.sin(angle)*c*run,gz=z-Math.sin(angle)*a+Math.cos(angle)*c*run,g=height(gx,gz);
        ground=Math.max(ground,g);low=Math.min(low,g);
      }
      list.push({x,z,angle,low,tread:ground+.11});
    }
    for(const {x,z,angle,low,tread} of list){
      const base=low-.18;
      p('stone',x,(tread+base)/2,z,1.0+r()*.1,tread-base,run+.07,pick(['#aaa58b','#92967e','#a7a48a','#9d9a82']),0,angle+(r()-.5)*.05);
      paths.push([x,z]);
    }
  }
  // Wooden post-and-rail fence along a polyline of world points.
  function fence(points){
    const posts=[];
    for(let i=1;i<points.length;i++){
      const [ax,az]=points[i-1],[bx,bz]=points[i],len=Math.hypot(bx-ax,bz-az),n=Math.max(1,Math.round(len/.85));
      for(let k=i>1?1:0;k<=n;k++)posts.push([ax+(bx-ax)*k/n,az+(bz-az)*k/n]);
      colliders.box((ax+bx)/2,(az+bz)/2,.16,len,Math.atan2(bx-ax,bz-az),'fence');
    }
    posts.forEach(([x,z],i)=>{
      const y=height(x,z);
      p('wood',x,y+.31,z,.1,.74,.1,pick(['#6b4b33','#5e4230','#735139']),0,r()*.3);
      p('wood',x,y+.7,z,.13,.04,.13,'#4f3725',0,r()*.3);
      occupy(x,z,.22);
      if(!i)return;
      const [px,pz]=posts[i-1],py=height(px,pz),len=Math.hypot(x-px,z-pz);
      place((x+px)/2,(y+py)/2,(z+pz)/2,1,Math.atan2(x-px,z-pz),()=>{
        for(const h of [.26,.55])p('wood',0,h,0,.045,.075,len+.06,pick(['#8f6644','#9b7049','#86603f']),-Math.atan2(y-py,len));
      });
    });
  }
  fence([[hx-W/2-.1,porchZ-.03],[hx-W/2-.6,porchZ-.03],[hx-W/2-.6,hz-D/2+.05],[hx-W/2-.08,hz-D/2+.05]]);
  fence([[hx+W/2+.1,porchZ-.03],[hx+W/2+.42,porchZ-.03],[hx+W/2+.42,porchZ-.9]]);
  fence([[hx+W/2+.42,porchZ-1.7],[hx+W/2+.42,hz-D/2+.05],[hx+W/2+.08,hz-D/2+.05]]);
  path(-7,-10,-5,-6.3);stairs([[-5,-6.3],[-6.4,-5.0],[-5.0,-3.9],[-4.4,-2.25]]);path(-4.4,-2.25,-3.85,.25);path(-3.85,.25,-2,.8);path(-2,.8,5.5,.82);path(5.5,.82,10.8,3.0);path(1,.8,1,2.6);
  place(13.7,waterY+.48,6.1,1,0,()=>kit.bridge(3.9));
  const treeList=[[-13,-12,1.40],[-10.8,-13.9,1.02],[-9,-12.1,1.22],[-5,-13.5,1.26],[-1.8,-13,1.28],[2,-13.6,1.45],[5.6,-12.1,1.12],[9.5,-12.8,1.35],[12.5,-10,1.45],[-13,-8.7,1.18],[-11,-6.4,1.25],[-13,-3.8,1.52],[-12,.2,1.13],[-13.4,3.7,1.21],[-11.8,7.2,1.28],[-13,11.4,1.35],[-8.9,12.7,1.27],[-5,13.1,1.36],[-1.4,12.1,1.05],[3.1,13.2,1.24],[7.4,12.7,1.13],[12.1,11.8,1.25],[12.2,.1,1.28],[10.5,-3.5,1.16],[12.5,-5.6,1.1],[-6.1,1.8,.76],[-3.95,2.0,.69],[-8.5,6.2,.83],[6.1,-8.2,.88],[.4,-9.8,1.08],[-9, -2.7,.77]];
  dressGround(ground,cv,treeList,paths,wet);
  treeList.forEach(([x,z,s],i)=>{at(x,z,s,r()*6,()=>b.canopy(()=>kit.tree([3,6,12,24,29].includes(i))));occupy(x,z,.58*s);colliders.circle(x,z,.32*s,'tree')});
  function clear(x,z){return free(x,z,.16)&&wet(x,z)<-.13&&!paths.some(([a,c])=>(a-x)**2+(c-z)**2<.42)}
  for(let i=0;i<440;i++){const x=r()*28.4-14.2,z=r()*28.4-14.2;if(!clear(x,z))continue;
    if(i%4===0){at(x,z,.6+r()*.76,r()*6,kit.flowers)}
    else if(i%5===0){for(let j=0;j<5;j++){const a=x+(r()-.5)*.75,c=z+(r()-.5)*.75,s=.18+r()*.5;p('boulder',a,height(a,c)+s*.16,c,s,s*.74,s*.88,pick(['#82877a','#989c87','#747b73','#a3a48d']),0,r()*5)}}
    else if(i%6===0){const kind=r()>.5?'bushA':'bushB',s=.8+r()*.55,turn=r()*6.28;
      p(kind+'Twigs',x,height(x,z)-.02,z,s,s,s,'#5b4632',0,turn);p(kind+'Leaves',x,height(x,z)-.02,z,s,s*(.85+r()*.3),s,pick(['#6f8d40','#7e9949','#8b9f4f']),0,turn);bushes.push([x,z,.42*s])}
  }
  // Dense turf: one jittered patch of 16 blades per .26-tile cell; a few taller tufts on top.
  const greens=['#536e37','#718a40','#98aa58','#899d4c','#647f3b'];
  for(let gx=-14.85;gx<14.9;gx+=.26)for(let gz=-14.85;gz<14.9;gz+=.26){
    const x=gx+(r()-.5)*.24,z=gz+(r()-.5)*.24;if(!clear(x,z))continue;
    const lush=.5+.5*Math.sin(x*.83+Math.cos(z*1.1))*Math.sin(z*.67-x*.31),s=.8+r()*.45;
    // keep every blade (patch radius .24 x scale, plus lean) on the tile, not hanging past its rim
    const edge=14.97-.36*s;if(Math.abs(x)>edge||Math.abs(z)>edge)continue;
    p(pick(['turf0','turf1','turf2']),x,height(x,z)-.01,z,s,s*(.55+.75*lush+r()*.25),s,pick(greens),0,r()*6.28);
    if(r()<.12&&Math.max(Math.abs(x),Math.abs(z))<14.6){const k=.5+r()*.5;p(pick(['grass0','grass1','grass2']),x,height(x,z)-.01,z,k,k*(.9+r()*.6),k,pick(greens),0,r()*6.28)}
  }
  for(const [x,z] of [[-8.5,-4.2],[7.6,10.4],[-6,8]]){at(x,z,1,r()*6.28,()=>{p('stumpBark',0,-.04,0,1,1,1,'#7a5a3a');p('stumpTop',0,-.04,0,1,1,1,'#d1b07a')});occupy(x,z,.45);stumps.push([x,z,.4])}
  // Gravel in the shallows and clumps of reeds give the transparent shoreline scale.
  for(let i=0;i<850;i++){
    const x=6+r()*8.75,z=2.45+r()*8,depth=waterY-height(x,z);
    if(depth<-.12 || depth>.49 || x>13.1)continue;
    const size=.055+r()*.17;
    p('boulder',x,waterY-depth+.024,z,size,size*.58,size*.79,pick(['#888979','#9e997c','#667568']),0,r()*6);
    if(depth<.17 && Math.sin(x*1.8+z*.62)>.48){
      for(let k=0;k<5;k++){
        const a=x+(r()-.5)*.23,c=z+(r()-.5)*.21,h=.26+r()*.37;
        p('reed',a,height(a,c)-.02,c,.7,h*1.6,.7,pick(['#768449','#8c9751','#516f42']),0,r()*6.28);
      }
    }
  }
  const lamps=[];
  for(const [x,z,angle] of [[-6.1,-7.35,0],[-3.75,-2.5,2.7],[.04,1.58,-1],[6.3,.60,1.35],[13.07,3.74,0]]){
    at(x,z,1,angle,()=>kit.lantern('post'));colliders.circle(x,z,.2,'lamp');
    const pivot=new T.Group(),parts=builder(pivot);
    pivot.position.set(x+.48*Math.cos(angle),height(x,z)+2.385,z-.48*Math.sin(angle));
    pivot.rotation.y=angle;
    parts.place(-.48,-2.385,0,1,0,()=>modules(parts).lantern('pendant'));
    parts.finish();scene.add(pivot);lamps.push(pivot);
  }
  const perches=treeList.map(([x,z,s])=>new T.Vector3(x+.36*s,height(x,z)+3.97*s,z+.25*s));
  perches.push(...lamps.map(p=>p.position.clone().add(new T.Vector3(0,.08,0))));
  ground.material.name='terrain';
  for(const [x,z,rad] of [...bushes,...stumps])colliders.circle(x,z,rad,'plant');
  return {water,floor,waterY,lamps,height,stand,roofs,cottage,perches,props,ground,colliders,
    walkable:(x,z)=>!colliders.blocked(x,z,.26)&&wet(x,z)<-.2};
}
