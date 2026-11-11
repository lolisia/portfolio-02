import * as T from 'three';
import {surface} from './surfaces.js';

// Module coordinates are measured in tiles. The builder batches repeated pieces by geometry.
export function builder(scene, seed = 41573, assets = new Map()) {
  const batches = new Map(), dummy = new T.Object3D();
  const geo = {spray:new T.PlaneGeometry(1,1),needle:new T.PlaneGeometry(1,1),box:new T.BoxGeometry(1,1,1), rock:new T.DodecahedronGeometry(.52), cone:new T.ConeGeometry(.55,1,7), trunk:new T.CylinderGeometry(.40,.53,1,7)};
  const types={wood:'box',stone:'box',clay:'box',plaster:'box',glass:'box',iron:'box',leaf:'rock',boulder:'rock'};
  let parent = new T.Matrix4(), windRoot=null,plantGroup=false;
  function vegetation(fn){const old=plantGroup;plantGroup=true;try{fn()}finally{plantGroup=old}}
  function canopy(fn){
    windRoot=new T.Vector3().setFromMatrixPosition(parent);
    try{fn()}finally{windRoot=null}
  }
  const rand = () => ((seed = (Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);
  const pick = a => a[Math.floor(rand()*a.length)];
  function part(kind,x,y,z,w,h,d,color,rx=0,ry=0,rz=0) {
    dummy.position.set(x,y,z); dummy.scale.set(w,h,d); dummy.rotation.set(rx,ry,rz); dummy.updateMatrix();
    if (!batches.has(kind)) batches.set(kind,[]);
    const matrix=new T.Matrix4().multiplyMatrices(parent,dummy.matrix);
    const asset=assets.get(kind);
    const root=asset?.sway?new T.Vector3(x,y,z).applyMatrix4(parent):null;
    const bend=windRoot?[windRoot.x,windRoot.y,windRoot.z,.014]:
      root?[root.x,root.y,root.z,asset.sway]:
      kind==='cone'?[x,y-h*.5,z,.39]:[0,0,0,0];
    const evergreen=kind==='needle'||(kind==='cone'&&windRoot!==null);
    const plant=asset?(asset.plant?1:0):!evergreen&&(plantGroup||['spray','leaf','cone','rock'].includes(kind))?1:0;
    batches.get(kind).push([matrix,new T.Color(color),bend,plant]);
  }
  function place(x,y,z,scale,angle,fn) {
    const old=parent;
    const local=new T.Matrix4().compose(new T.Vector3(x,y,z),new T.Quaternion().setFromAxisAngle(new T.Vector3(0,1,0),angle),new T.Vector3(scale,scale,scale));
    parent=old.clone().multiply(local); fn(); parent=old;
  }
  function finish(){
    for(const [kind,items] of batches){
      const asset=assets.get(kind);
      const mesh=new T.InstancedMesh((asset?.geometry??geo[types[kind]??kind]).clone(),
        surface(asset?.material??(kind==='trunk'?'bark':kind==='boulder'?'stone':kind)),items.length);
      mesh.name=kind;
      items.forEach(([m,c],i)=>{mesh.setMatrixAt(i,m);mesh.setColorAt(i,c)});
      mesh.geometry.setAttribute('bendRoot',new T.InstancedBufferAttribute(new Float32Array(items.flatMap(item=>item[2])),4));
      mesh.geometry.setAttribute('plantMask',new T.InstancedBufferAttribute(new Float32Array(items.map(item=>item[3])),1));
      mesh.castShadow=asset?.shadow!==false;mesh.receiveShadow=true;scene.add(mesh);
    }
  }
  return {part,place,rand,pick,finish,canopy,vegetation};
}

// Family cottage dimensions (local tiles, front faces +z); world.js reuses them for the porch
// floor, steps, roof and colliders.
export const COTTAGE={W:3.3,D:3,F:.45,H:1.6,knee:.5,P:1.15,B:1,BW:2.4,slope:.8,over:.38,E:2.32,run:.3,chimney:[.85,-.6]};
export const cottageSteps=drop=>Math.max(1,Math.round(drop/.16));

export function modules(b) {
  const {rand:r,pick,part:p,place}=b;
  const box=(...a)=>p('wood',...a), rock=(...a)=>p('leaf',...a);
  const bark=['#55412b','#655034','#493c2d'], wood=['#815133','#986342','#70432e','#aa7650'];
  // Trees, flowers and beds are Blender meshes (tools/nature-assets.py) authored base-at-origin.
  function tree(pine=false){
    if(pine){
      p('pineABark',0,0,0,1,1,1,pick(bark));
      p('pineANeedles',0,0,0,1,1,1,pick(['#5d7a45','#678449','#55703f']));
      return;
    }
    const kind=r()>.5?'oakA':'oakB',light=r()>.32;
    const greens=light?['#8fa553','#9cb35c','#a9b660','#88a14f']:['#7d9447','#8ba14a','#90a451','#76903f'];
    p(kind+'Bark',0,0,0,1,1,1,pick(bark));
    p(kind+'Leaves',0,0,0,1,1,1,pick(greens));
  }
  const timber=['#9c6a44','#a9764b','#8d5d3c','#b27e54','#a06c46','#956540'];
  const shakes=['#7b5a43','#6d4e3a','#866550','#5f4434','#8a6a52','#735240','#6a5342'];
  const trim='#563a27',core='#3a281c';
  // Window set into a wall whose outer face is z (facing +z): panes, trim, muntins, sill, shutters.
  function window(x,y,z,w=.62,h=.74,shutters=true){
    p('glass',x,y,z+.02,w-.06,h-.06,.04,'#ffcc72');
    for(const s of [-1,1]){box(x+s*w/2,y,z+.045,.08,h+.08,.07,trim);box(x,y+s*h/2,z+.045,w-.08,.08,.07,trim)}
    box(x,y,z+.05,.035,h-.08,.03,trim);box(x,y,z+.045,w-.08,.035,.02,trim);
    box(x,y-h/2-.07,z+.07,w+.2,.06,.14,'#6b4a33');
    if(shutters)for(const s of [-1,1]){
      const sx=x+s*(w/2+.17);
      box(sx,y,z+.025,.26,h+.02,.05,'#6f7a55');
      for(const f of [-.3,.3])box(sx,y+f*h,z+.06,.24,.06,.02,'#5d6847');
    }
  }
  // Plank door (facing +z) on a wall whose outer face is z, standing on y0.
  function door(x,y0,z,w=.74,h=1.3){
    box(x,y0+h/2,z+.005,w,h,.01,'#211811');
    for(let i=0;i<5;i++)box(x-w/2+(i+.5)*w/5,y0+h/2,z+.03,w/5-.012,h-.02,.04,pick(['#6a432b','#73492f','#5f3c27']));
    for(const f of [.22,.78])box(x,y0+h*f,z+.06,w-.08,.08,.02,'#4e3322');
    for(const s of [-1,1])box(x+s*(w/2+.05),y0+(h+.08)/2,z+.045,.1,h+.08,.09,trim);
    box(x,y0+h+.08,z+.05,w+.22,.1,.1,trim);
    p('iron',x+w/2-.12,y0+h*.5,z+.075,.04,.1,.04,'#2f2a24');
  }
  // Open railing from a to b (local, level): top and bottom rails with balusters.
  function railing(ax,az,bx,bz,y,height=.55,endPost=true){
    const len=Math.hypot(bx-ax,bz-az),n=Math.max(1,Math.round(len/.13));
    place((ax+bx)/2,y,(az+bz)/2,1,Math.atan2(bx-ax,bz-az),()=>{
      box(0,height,0,.09,.06,len,trim);
      box(0,.1,0,.05,.05,len,trim);
      for(let i=1;i<n;i++)box(0,(.125+height-.03)/2,-len/2+i*len/n,.045,height-.155,.045,pick(timber));
      for(const end of endPost?[-1,1]:[-1])box(0,(height+.05)/2,end*len/2,.1,height+.05,.1,trim);
    });
  }
  // Shed and coop: a board shed raised on legs; the coop leaves a doorway for the hens.
  function house(coop=false){
    const w=1.76,d=1.82,h=1.48;
    for(const x of [-.71,.71])for(const z of [-.73,.73])box(x,.32,z,.18,.64,.18,'#59422c');
    place(0,.38,0,1,0,()=>{
    if(coop){
      box(0,h/2+.2,-d/2,w,h,.12,'#855438');
      for(const side of [-1,1])box(side*(w/2-.06),h/2+.2,0,.12,h,d,'#855438');
      for(const side of [-1,1])box(side*(w/4+.18),h/2+.2,d/2,w/2-.36,h,.12,'#855438');
      box(0,h+.12,d/2,w,.2,.12,'#855438');
    }else box(0,h/2+.2,0,w,h,d,'#855438');
    // Planks sit proud of the wall; corner posts (.15) and belts stand proud of both, so no faces coincide.
    for(let i=0;i<9;i++){if(coop&&i>=3&&i<=5)continue;box(-w/2+(i+.5)*w/9,h/2+.2,d/2+(coop?.085:.02),w/9-.016,h,.05,pick(wood))}
    for(const x of [-w/2,0,w/2])for(const z of [-d/2,d/2]){if(coop&&x===0&&z>0)continue;box(x,h/2+.19,z,.15,h+.1,.15,'#5f412d')}
    for(const y of [.28,h+.12]){box(0,y,0,w+.2,.17,d+.2,'#674832')}
    const front=d/2+.09;
    if(coop){
      box(0,.88,front-.26,.69,1.3,.045,'#29251e');
      place(-.37,0,front,1,-1.35,()=>box(.34,.87,0,.68,1.3,.08,'#70432e'));
    }else{
      box(0,.87,front+.04,.69,1.36,.12,'#53392a');
      for(let i=0;i<4;i++)box(-.24+i*.16,.85,front+.12,.145,1.23,.04,pick(wood));
    }
    // Steps down from the doorway: each block runs to the ground and none overlap.
    for(let i=0;i<8;i++){const tread=.385-i*.09;box(0,(tread-.42)/2,front+.13+i*.14,.81,tread+.42,.14,pick(wood))}
    const roofWidth=d, span=w/2+.22, slope=.60, pitch=Math.atan(slope),base=h+.29;
    place(0,0,0,1,Math.PI/2,()=>{
    for(let side of [-1,1]){
      const angle=side*pitch;
      box(0,base+span*slope/2,side*span/2,roofWidth+.48,.16,span*Math.sqrt(1+slope*slope),'#793f2e',angle);
      const rows=5,cols=8;
      // Each tile row tips its lower edge up a little so overlapping rows never share a plane.
      for(let j=0;j<rows;j++)for(let i=0;i<cols;i++){
        const t=(j+.5)/rows;
        p('clay',(i+.5-cols/2)*(roofWidth+.4)/cols,base+(1-t)*span*slope+.105,side*t*span,(roofWidth+.4)/cols-.012,.08,span/rows*1.19,pick(['#a64e35','#b45739','#aa5137','#c06b45','#98432f','#b96141']),angle-side*.06);
      }
    }
    for(let i=0;i<7;i++){const f=(i+.5)/7;box(0,base+f*span*slope,0,roofWidth+.01,span*slope/7+.01,w*(1-f),pick(wood))}
    });
    });
  }
  // The family cottage: stone plinth, board-clad walls, a front porch with steps and a gable
  // balcony under a deep shake roof. `drop` is how far the porch floor sits above the ground
  // in front of the steps.
  function cottage(drop=.3){
    const {W,D,F,H,knee,P,B,BW,slope,over,E,run}=COTTAGE,top=F+H,span=W/2+over,pitch=Math.atan(slope);
    p('stone',0,F/2-.2,0,W+.1,F+.4,D+.1,'#7a7262');
    for(const [axis,s] of [['x',1],['x',-1],['z',-1]])for(const y of [.1,.3]){
      const len=axis==='x'?D:W;let a=-len/2+.03+(y>.2?.12:0);
      while(a<len/2-.1){
        const l=Math.min(.28+r()*.26,len/2-.03-a),c=a+l/2,col=pick(['#8b8371','#7a7364','#958d79','#6f6a5d']);
        if(axis==='x')p('stone',s*(W/2+.07),y,c,.06,.18,l-.025,col);else p('stone',c,y,s*(D/2+.07),l-.025,.18,.06,col);
        a+=l;
      }
    }
    box(0,F+(H+knee)/2,0,W-.12,H+knee,D-.12,core);
    // Horizontal cladding, each course butt-jointed at a random point.
    const siding=(len,height,rows,put)=>{for(let k=0;k<rows;k++){
      const y=F+(k+.5)*height/rows,cut=-len/2+len*(.3+.4*r());
      for(const [a,b] of [[-len/2,cut],[cut,len/2]])put((a+b)/2,y,b-a-.012,height/rows-.016);
    }};
    for(const s of [-1,1]){
      siding(D-.14,H+knee,10,(c,y,l,t)=>box(s*(W/2-.03),y,c,.06,t,l,pick(timber)));
      siding(W-.14,H,8,(c,y,l,t)=>box(c,y,s*(D/2-.03),l,t,.06,pick(timber)));
    }
    for(const x of [-W/2,W/2])for(const z of [-D/2,D/2])box(x,F+(H+knee)/2,z,.2,H+knee,.2,trim);
    box(0,F+.06,0,W+.26,.12,D+.26,trim);
    box(0,top+.07,0,W+.26,.14,D+.26,trim);
    door(0,F+.12,D/2);
    for(const x of [-.95,.95])window(x,F+.95,D/2);
    for(const z of [-.65,.75])place(W/2,0,z,1,Math.PI/2,()=>window(0,F+.95,0));
    place(-W/2,0,0,1,-Math.PI/2,()=>window(0,F+.95,0));
    place(0,0,-D/2,1,Math.PI,()=>{window(0,F+.95,0);window(0,top+.75,0,.5,.6,false)});
    // Gable ends: vertical boards up under the roof, and a door out onto the balcony.
    for(const s of [-1,1])for(let i=0;i<16;i++){
      const x=-W/2+.1+i*.2,yl=E+(span-Math.abs(x))*slope-.075,y0=top+.14;
      if(yl>y0+.05)box(x,(yl+y0)/2,s*(D/2-.03),.19,yl-y0,.06,pick(timber));
    }
    door(0,top+.14,D/2,.7,1.1);
    // Balcony: joists and planks flush with the floor band, braced posts down to the porch.
    const ry=top+.14,bz=D/2+B;
    box(0,top,bz-.08,BW+.1,.12,.14,trim);
    for(const s of [-1,1])box(s*(BW/2-.05),top,D/2+.13+(B-.28)/2,.12,.12,B-.28,trim);
    for(let i=0;i<15;i++)box(-BW/2+(i+.5)*BW/15,top+.1,D/2+.13+(B-.13)/2,BW/15-.012,.08,B-.13,pick(timber));
    for(const s of [-1,1]){
      const px=s*(BW/2-.05);
      box(px,(F+top-.06)/2,bz-.08,.14,top-.06-F,.14,trim);
      box(px-s*.17,top-.25,bz-.08,.07,.46,.07,trim,0,0,s*.75);
      railing(px,D/2+.14,px,bz-.05,ry,.55,false);
    }
    railing(-BW/2+.05,bz-.05,BW/2-.05,bz-.05,ry);
    // Porch: deck boards, fascia, dark skirt, railings and steps at the door.
    for(let i=0;i<20;i++)box(-W/2+(i+.5)*W/20,F-.04,D/2+.13+(P-.13)/2,W/20-.012,.08,P-.13,pick(timber));
    box(0,F-.14,D/2+P-.01,W,.14,.06,trim);
    box(0,(F-.21-.45)/2,D/2+.13+(P-.13)/2,W-.12,F-.21+.45,P-.3,core);
    for(const s of [-1,1]){
      railing(s*(W/2-.06),D/2+.15,s*(W/2-.06),D/2+P-.06,F,.5,false);
      railing(s*(W/2-.06),D/2+P-.06,s*.58,D/2+P-.06,F,.5);
    }
    const n=cottageSteps(drop),foot=F-drop-.25;
    for(let k=1;k<=n;k++){
      const tread=F-k*drop/(n+1),z=D/2+P+(k-.5)*run;
      box(0,(tread-.05+foot)/2,z,.94,tread-.05-foot,run,trim);
      box(0,tread-.025,z+.02,1.0,.05,run+.04,pick(timber));
    }
    // Shake roof: sheathing, staggered courses of split shingles, ridge cap and barge boards.
    const L=span*Math.hypot(1,slope),zFront=bz+.28,zBack=-D/2-.35,Lz=zFront-zBack,zc=(zFront+zBack)/2;
    for(const s of [-1,1]){
      const rz=-s*pitch,nx=s*Math.sin(pitch),ny=Math.cos(pitch),at=(t,lift)=>[s*t*span+nx*lift,E+(1-t)*span*slope+ny*lift];
      const [sx,sy]=at(.5,0);box(sx,sy,zc,L,.1,Lz,core,0,0,rz);
      const rows=12,step=L/rows,cols=Math.round(Lz/.27),cw=Lz/cols;
      // Courses lie a little flatter than the roof so each butt end rides on the course below.
      for(let j=0;j<rows;j++){
        const [x,y]=at((j+.6)/rows,.085),shift=j%2?cw/2:0;
        for(let i=0;i<=cols;i++){
          const a=Math.max(zBack,zBack+i*cw-shift),b=Math.min(zFront,zBack+(i+1)*cw-shift);
          if(b-a<.06)continue;
          box(x,y,(a+b)/2,step*1.42,.035,b-a-.018-r()*.02,pick(shakes),0,0,rz+s*.075);
        }
      }
      const [cx,cy]=at(.11/span,.135);box(cx,cy,zc,.26,.05,Lz+.06,core,0,0,rz);
      for(const z of [zFront+.03,zBack-.03]){const [gx,gy]=at(.5,.03);box(gx,gy,z,L+.02,.2,.06,trim,0,0,rz)}
    }
    const [cx,cz]=COTTAGE.chimney,chTop=E+span*slope+.35;
    p('stone',cx,(top+chTop)/2,cz,.52,chTop-top,.52,'#8a8170');
    p('stone',cx,chTop+.07,cz,.64,.14,.64,'#a39b87');
    box(cx,chTop+.145,cz,.32,.02,.32,'#2a2a26');
  }
  function flowers(){
    const c=pick(['#ed8d48','#d55a3e','#e7c464','#e9e2c4','#a1a6c6','#e58fae']);
    for(let i=0;i<7;i++){
      const x=(r()-.5)*.8,z=(r()-.5)*.76,s=.75+r()*.6,turn=r()*6.28;
      p('flowerStem',x,0,z,s,s,s,'#6f8f45',0,turn);
      p('flowerHead',x,0,z,s,s,s,c,0,turn);
    }
    for(let i=0;i<3;i++){const s=.45+r()*.3;p(pick(['grass0','grass1','grass2']),(r()-.5)*.7,0,(r()-.5)*.7,s,s,s,'#86a24c',0,r()*6.28)}
  }
  function bed(){
    p('bedFrame',0,0,0,1,1,1,'#9a6c47');
    p('bedSoil',0,0,0,1,1,1,'#6a4630');
    for(let j=0;j<5;j++)for(let i=0;i<3;i++){
      const x=(i-1)*.36+(r()-.5)*.04,z=(j-2)*.3+(r()-.5)*.04,s=.8+r()*.35;
      if(j%2===0)p('cabbage',x,.19,z,s,s,s,pick(['#93b65a','#a3c063','#86a84f']),0,r()*6.28);
      else p('carrot',x,.18,z,s,s,s,pick(['#6f9a3e','#7ea946']),0,r()*6.28);
    }
  }
  function bridge(len){
    for(let i=0;i<Math.ceil(len/.22);i++)box(0,.1,-len/2+i*.22,1.23,.14,.205,pick(wood));
    for(const side of [-1,1]){
      for(let i=0;i<=4;i++)box(side*.57,.25,-len/2+i*len/4,.10,1.1,.11,'#70523a');
      for(const y of [.43,.74])box(side*.57,y,0,.08,.085,len+.1,'#a77c50');
    }
  }
  function lantern(section){
    if(section!=='pendant'){
    p('stone',0,.13,0,.46,.26,.43,'#7a7867');
    box(0,1.27,0,.14,2.36,.15,'#865e3e');
    box(.24,2.39,0,.65,.13,.16,'#946b46');
    box(.17,2.15,0,.085,.55,.10,'#684832',0,0,-.67);
    }
    if(section==='post')return;
    p('iron',.48,2.26,0,.045,.25,.05,'#403b32');
    p('iron',.48,2.12,0,.39,.095,.36,'#4d493e');
    p('glass',.48,1.90,0,.265,.35,.25,'#f5d69b');
    for(const x of [.33,.63])for(const z of [-.14,.14])p('iron',x,1.90,z,.035,.38,.035,'#453c32');
    p('iron',.48,1.68,0,.36,.085,.33,'#443c32');
  }
  return {tree,house,cottage,flowers,bed,bridge,lantern};
}
