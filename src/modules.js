import * as T from 'three';
import {surface} from './surfaces.js';

// Module coordinates are measured in tiles. The builder batches repeated pieces by geometry.
export function builder(scene, seed = 41573) {
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
    const bend=windRoot?[windRoot.x,windRoot.y,windRoot.z,.014]:
      kind==='cone'?[x,y-h*.5,z,.39]:[0,0,0,0];
    const evergreen=kind==='needle'||(kind==='cone'&&windRoot!==null);
    const plant=!evergreen&&(plantGroup||['spray','leaf','cone','rock'].includes(kind))?1:0;
    batches.get(kind).push([matrix,new T.Color(color),bend,plant]);
  }
  function place(x,y,z,scale,angle,fn) {
    const old=parent;
    const local=new T.Matrix4().compose(new T.Vector3(x,y,z),new T.Quaternion().setFromAxisAngle(new T.Vector3(0,1,0),angle),new T.Vector3(scale,scale,scale));
    parent=old.clone().multiply(local); fn(); parent=old;
  }
  function finish(){
    for(const [kind,items] of batches){
      const mesh=new T.InstancedMesh(geo[types[kind]??kind].clone(),surface(kind==='trunk'?'bark':kind==='boulder'?'stone':kind),items.length);
      items.forEach(([m,c],i)=>{mesh.setMatrixAt(i,m);mesh.setColorAt(i,c)});
      mesh.geometry.setAttribute('bendRoot',new T.InstancedBufferAttribute(new Float32Array(items.flatMap(item=>item[2])),4));
      mesh.geometry.setAttribute('plantMask',new T.InstancedBufferAttribute(new Float32Array(items.map(item=>item[3])),1));
      mesh.castShadow=true;mesh.receiveShadow=true;scene.add(mesh);
    }
  }
  return {part,place,rand,pick,finish,canopy,vegetation};
}

export function modules(b) {
  const {rand:r,pick,part:p,place}=b;
  const box=(...a)=>p('wood',...a), rock=(...a)=>p('leaf',...a);
  const bark=['#55412b','#655034','#493c2d'], wood=['#815133','#986342','#70432e','#aa7650'];
  function tree(pine=false){
    p('trunk',0,1.45,0,.46,2.9,.48,pick(bark));
    for(let i=0;i<5;i++){
      const a=i*1.26;
      p('trunk',.23*Math.cos(a),.16,.23*Math.sin(a),.19,.66,.21,pick(bark),0,-a,1.06);
    }
    if(pine){
      for(let i=0;i<5;i++){
        const width=2.65-i*.44, y=1.75+i*.51;
        for(let k=0;k<5;k++){const a=k*1.256+i*.6;place(0,y-.32,0,1,a,()=>p('trunk',width*.18,0,0,.09,width*.65,.09,pick(bark),0,0,-1.23))}
        p('cone',0,y,0,width*.72,1.41,width*.72,['#364c31','#425c32','#536d39','#637e41','#748840'][i],0,i);
        for(let j=0;j<15;j++){
          const a=j*2.4+i,rad=width*.32;
          p('needle',Math.cos(a)*rad,y-.30,Math.sin(a)*rad,width*.72,width*.69,1,pick(['#70894d','#859b5a','#506e43']),-.94,Math.PI/2-a,.12*Math.sin(a));
        }
      }
      return;
    }
    const light=r()>.32;
    const greens=light?['#758e43','#839f4c','#a0aa59','#a9b660','#678539','#889f51']:['#677c3a','#7e9244','#8ba14a','#627d3c','#90a451'];
    for(let i=0;i<9;i++){
      const a=i*2.4, rad=i<6?.94:.46, x=Math.cos(a)*rad,z=Math.sin(a)*rad,y=2.73+(i<6?r()*.36:.67+r()*.24);
      if(i<6)p('trunk',x*.49,2.15,z*.49,.2,1.16,.2,pick(bark),z*.55,0,-x*.55);
      rock(x,y,z,.84,.62,.79,pick(['#556e37','#61793f','#617a41']),r()*.3,a);
      for(let j=0;j<22;j++){
        const ang=r()*6.28, v=r()*1.65-.65,dist=Math.sqrt(1-v*v);
        const cx=x+.77*dist*Math.cos(ang),cz=z+.74*dist*Math.sin(ang);
        p('spray',cx,y-.12+.58*v,cz,.98+r()*.42,.91+r()*.52,1,pick(greens),
          -.80-v*.72,Math.PI*.5-ang,(r()-.5)*1.4);
      }
    }
  }
  function window(x,y,z){
    box(x,y,z,.73,.85,.09,'#453728');
    p('glass',x,y,z+.06,.56,.64,.05,'#ffcc72');
    box(x,y,z+.10,.055,.65,.05,'#70553a');box(x,y,z+.10,.6,.06,.05,'#70553a');
    box(x,y-.44,z+.10,.85,.09,.25,'#725138');
  }
  function house(shed=false,coop=false){
    const w=shed?1.76:2.85,d=shed?1.82:2.58,h=shed?1.48:2.05;
    if(shed){for(const x of [-.71,.71])for(const z of [-.73,.73])box(x,.32,z,.18,.64,.18,'#59422c')}
    else p('stone',0,.14,0,w+.07,.28,d+.08,'#827867');
    const lift=shed?.38:0;
    place(0,lift,0,1,0,()=>{
    if(coop){
      box(0,h/2+.2,-d/2,w,h,.12,'#855438');
      for(const side of [-1,1])box(side*(w/2-.06),h/2+.2,0,.12,h,d,'#855438');
      for(const side of [-1,1])box(side*(w/4+.18),h/2+.2,d/2,w/2-.36,h,.12,'#855438');
      box(0,h+.12,d/2,w,.2,.12,'#855438');
    }else p(shed?'wood':'plaster',0,h/2+.2,0,w,h,d,shed?'#855438':'#d4be90');
    if(shed)for(let i=0;i<9;i++){if(coop&&i>=3&&i<=5)continue;box(-w/2+(i+.5)*w/9,h/2+.2,d/2+.02,w/9-.016,h,.05,pick(wood))}
    for(const x of [-w/2,0,w/2])for(const z of [-d/2,d/2]){if(coop&&x===0&&z>0)continue;box(x,h/2+.19,z,.12,h+.1,.12,'#5f412d')}
    for(const y of [.28,h+.12]){box(0,y,0,w+.14,.17,d+.14,'#674832')}
    const front=d/2+.09;
    if(coop){
      box(0,.88,front-.26,.69,1.3,.045,'#29251e');
      place(-.37,0,front,1,-1.35,()=>box(.34,.87,0,.68,1.3,.08,'#70432e'));
    }else{
      box(shed?0:.69,.87,front,.69,1.36,.12,'#53392a');
      for(let i=0;i<4;i++)box((shed?0:.69)-.24+i*.16,.85,front+.08,.145,1.23,.04,pick(wood));
    }
    if(!shed){window(-.64,1.30,front);place(w/2+.04,1.18,.18,.87,Math.PI/2,()=>window(0,0,0))}
    else{for(let i=0;i<8;i++)box(0,.32-i*.09,front+.13+i*.14,.81,.13,.17,pick(wood))}
    const roofWidth=d, span=w/2+.22, slope=.60, pitch=Math.atan(slope),base=h+.29;
    place(0,0,0,1,Math.PI/2,()=>{
    for(let side of [-1,1]){
      const angle=side*pitch;
      box(0,base+span*slope/2,side*span/2,roofWidth+.48,.16,span*Math.sqrt(1+slope*slope),'#793f2e',angle);
      const rows=shed?5:7,cols=shed?8:11;
      for(let j=0;j<rows;j++)for(let i=0;i<cols;i++){
        const t=(j+.5)/rows;
        p('clay',(i+.5-cols/2)*(roofWidth+.4)/cols,base+(1-t)*span*slope+.095,side*t*span,(roofWidth+.4)/cols-.012,.08,span/rows*1.19,pick(['#a64e35','#b45739','#aa5137','#c06b45','#98432f','#b96141']),angle);
      }
    }
    // Fill the gable ends with successively shorter boards.
    for(let i=0;i<7;i++){const f=(i+.5)/7;box(0,base+f*span*slope,0,roofWidth+.01,span*slope/7+.01,w*(1-f),pick(wood))}
    });
    if(!shed){p('stone',-.78,h+1.02,-.55,.46,1.24,.48,'#887e68');p('stone',-.78,h+1.65,-.55,.57,.17,.58,'#a39b87');box(-.78,h+1.74,-.55,.29,.03,.3,'#46453b')}
    });
  }
  function flowers(){b.vegetation(()=>{
    const c=pick(['#ed8d48','#d55a3e','#e7c464','#d9d2b2','#a1a6c6']);
    for(let i=0;i<8;i++){const x=(r()-.5)*.75,z=(r()-.5)*.72,h=.16+r()*.24;
      box(x,h/2,z,.026,h,.026,'#54733c');rock(x+.04,h*.49,z,.17,.065,.10,'#71934a',0,r()*3,.45);
      rock(x,h,z,.14,.09,.13,c);box(x,h+.047,z,.048,.024,.05,'#f6cc66')}
  })}
  function bed(){
    box(0,.07,0,1.27,.14,1.65,'#60412c');
    for(const k of [-1,1]){box(k*.61,.17,0,.095,.17,1.7,'#8b6240');box(0,.17,k*.8,1.3,.17,.09,'#997049')}
    for(let i=0;i<4;i++)for(let j=0;j<5;j++){const x=(i-1.5)*.26,z=(j-2)*.29;rock(x,.24,z,.22,.23,.23,pick(['#698345','#779646','#52703c']));rock(x+.04,.32,z,.09,.095,.1,'#ba5032')}
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
  return {tree,house,flowers,bed,bridge,lantern};
}
