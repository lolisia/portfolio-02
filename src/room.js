import * as T from 'three';
import {createColliders} from './colliders.js';

// The cottage interior: a dollhouse cutaway room in a scene of its own, drawn instead of the
// island while she is inside. Its windows look out on the real island, rendered live from the
// cottage's own windows, so the time of day and the weather show through them. Furniture can
// be used (bed, sofa, fireplace, bookshelf, floor lamp), and the door leads back outside.
const W=5.2,D=4.2,H=2.5,X0=-W/2,Z0=-D/2;
const FIRE_SECONDS=600,READ_COOLDOWN=300;

function plasterTexture(){
  const c=document.createElement('canvas');c.width=c.height=256;const g=c.getContext('2d');
  g.fillStyle='#efe2c8';g.fillRect(0,0,256,256);
  for(let i=0;i<2600;i++){g.fillStyle=`rgba(${120+Math.random()*60},${100+Math.random()*40},70,${Math.random()*.06})`;g.fillRect(Math.random()*256,Math.random()*256,2+Math.random()*6,2+Math.random()*6)}
  const t=new T.CanvasTexture(c);t.colorSpace=T.SRGBColorSpace;t.wrapS=t.wrapT=T.RepeatWrapping;return t;
}
function rainTexture(){
  const c=document.createElement('canvas');c.width=128;c.height=256;const g=c.getContext('2d');
  g.clearRect(0,0,128,256);g.strokeStyle='rgba(225,235,245,.55)';g.lineCap='round';
  for(let i=0;i<70;i++){const x=Math.random()*128,y=Math.random()*256,l=8+Math.random()*22;g.lineWidth=.8+Math.random()*1.4;g.beginPath();g.moveTo(x,y);g.lineTo(x+1,y+l);g.stroke()}
  g.fillStyle='rgba(235,242,250,.5)';for(let i=0;i<40;i++){g.beginPath();g.arc(Math.random()*128,Math.random()*256,.8+Math.random()*1.8,0,7);g.fill()}
  const t=new T.CanvasTexture(c);t.wrapS=t.wrapT=T.RepeatWrapping;return t;
}

export function createRoom({renderer,outdoor,world,character,canvas,controls,hooks}){
  const scene=new T.Scene();scene.background=new T.Color(0x1e1a17);
  const camera=new T.OrthographicCamera(-5,5,3,-3,.1,60);
  const target=new T.Vector3(0,.95,.1);camera.position.copy(target).add(new T.Vector3(6.4,6.2,8.6));camera.lookAt(target);
  const mats=new Map();
  const mat=(color,opts={})=>{const key=color+JSON.stringify(opts);if(!mats.has(key))mats.set(key,new T.MeshStandardMaterial({color,roughness:.8,...opts}));return mats.get(key)};
  function box(parent,w,h,d,x,y,z,color,opts){
    const m=new T.Mesh(new T.BoxGeometry(w,h,d),typeof color==='object'?color:mat(color,opts));
    m.position.set(x,y,z);m.castShadow=m.receiveShadow=true;parent.add(m);return m;
  }
  const rng=(()=>{let s=4441;return()=>((s=(Math.imul(s,1664525)+1013904223)>>>0)/4294967296)})();
  const pick=a=>a[Math.floor(rng()*a.length)];

  // ---- Shell: plank floor on a slab, plaster walls over board wainscot, cut-away top caps ----
  const shell=new T.Group();scene.add(shell);
  box(shell,W+.3,.3,D+.3,0,-.15,0,0x3e2e22);
  const planks=['#9b6b43','#a5744a','#8f623e','#ad7c50','#976842'];
  for(let i=0;i<14;i++){const zz=Z0+(i+.5)*D/14;box(shell,W,.04,D/14-.012,0,-.02,zz,pick(planks),{roughness:.7})}
  const plaster=new T.MeshStandardMaterial({map:plasterTexture(),roughness:.95});
  plaster.map.repeat.set(2,1);
  box(shell,W+.14,H,.14,0,H/2,Z0-.07,plaster);
  box(shell,.14,H,D,X0-.07,H/2,0,plaster);
  for(let i=0;i<20;i++)box(shell,W/20-.01,.9,.04,X0+(i+.5)*W/20,.45,Z0+.02,pick(['#7d5536','#86603d','#77502f']));
  for(let i=0;i<16;i++)box(shell,.04,.9,D/16-.01,X0+.02,.45,Z0+(i+.5)*D/16,pick(['#7d5536','#86603d','#77502f']));
  box(shell,W,.06,.07,0,.93,Z0+.05,0x5a3b25);box(shell,.07,.06,D,X0+.05,.93,0,0x5a3b25);
  box(shell,W+.16,.06,.18,0,H+.03,Z0-.07,0xd9cdb5);box(shell,.18,.06,D+.02,X0-.07,H+.03,0,0xd9cdb5);
  // Ceiling beams resting on the back wall.
  for(const x of [-1.6,0,1.6])box(shell,.16,.16,.5,x,H-.14,Z0+.25,0x5a3b25);

  // ---- Windows: live views out of the cottage, with rain running down the glass ----
  const views=[
    {rt:new T.WebGLRenderTarget(640,400),cam:new T.PerspectiveCamera(58,1.6,.1,120)},
    {rt:new T.WebGLRenderTarget(512,400),cam:new T.PerspectiveCamera(58,1.28,.1,120)}
  ];
  {
    const [hx,hz]=world.props[0],front=world.cottage.window;
    // A front window looks south over the yard; the west window looks out past the side fence.
    // Stood out past the porch edge, clear of the light the cottage's own windows throw onto it.
    views[0].cam.position.set(hx-.95,front.y+.2,front.z+1.1);views[0].cam.lookAt(hx-.95,front.y-1.1,front.z+9);
    views[1].cam.position.set(hx-1.8,front.y-.1,hz);views[1].cam.lookAt(hx-10,front.y-1.1,hz);
  }
  const rain=rainTexture(),drops=[];
  function windowAt(parent,view,w,h,x,y,z,ry){
    const g=new T.Group();g.position.set(x,y,z);g.rotation.y=ry;parent.add(g);
    const glass=new T.Mesh(new T.PlaneGeometry(w,h),new T.MeshBasicMaterial({map:view.rt.texture}));glass.position.z=.01;g.add(glass);
    const wet=new T.Mesh(new T.PlaneGeometry(w,h),new T.MeshBasicMaterial({map:rain.clone(),transparent:true,opacity:0,depthWrite:false}));
    wet.material.map.repeat.set(w/.6,h/.9);wet.position.z=.015;g.add(wet);drops.push(wet);
    const frame=0x6a4a30;
    box(g,w+.14,.08,.08,0,h/2+.04,.03,frame);box(g,w+.14,.08,.08,0,-h/2-.04,.03,frame);
    box(g,.08,h,.08,-w/2-.03,0,.03,frame);box(g,.08,h,.08,w/2+.03,0,.03,frame);
    box(g,.04,h,.04,0,0,.04,frame);box(g,w,.04,.04,0,0,.04,frame);
    box(g,w+.3,.05,.16,0,-h/2-.1,.08,0x7d5536);
    // Curtains either side.
    for(const s of [-1,1]){const c=box(g,.26,h+.3,.05,s*(w/2+.2),.05,.07,0xb4584a,{roughness:1});c.scale.x=1}
    box(g,w+.8,.04,.04,0,h/2+.2,.08,0x3b2a1e);
    return g;
  }
  windowAt(shell,views[0],.95,.95,-1.05,1.62,Z0+.02,0);
  windowAt(shell,views[0],.85,.8,1.75,1.75,Z0+.02,0);
  windowAt(shell,views[1],.95,.85,X0+.02,1.62,-.35,Math.PI/2);

  // ---- Furniture. Each usable piece is a group tagged with what it does ----
  const usable=[];
  function usableGroup(key,name,icon,spot,x,y,z){
    const g=new T.Group();g.position.set(x,y,z);g.userData={key,name,icon,spot};scene.add(g);usable.push(g);return g;
  }
  const colliders=createColliders();
  // Bed: headboard against the back wall, a quilt over the foot.
  const bed=usableGroup('bed','침대','🛏️',{x:1.02,z:-.85,face:Math.PI/2},1.75,0,-1.1);
  box(bed,1.15,.28,1.86,0,.2,0,0x7a5132);for(const [x,z] of [[-.52,.86],[.52,.86],[-.52,-.86],[.52,-.86]])box(bed,.08,.12,.08,x,.06,z,0x5a3b25);
  box(bed,1.05,.16,1.76,0,.42,0,0xf2ede2);box(bed,1.1,.07,1.2,0,.52,.28,0x5f7fae,{roughness:1});
  box(bed,1.1,.07,.12,0,.5,.9,0x4f6d97,{roughness:1});
  box(bed,.75,.12,.32,0,.56,-.68,0xfbf6ea,{roughness:1});
  box(bed,1.2,1.05,.08,0,.52,-.94,0x6a4a30);box(bed,1.26,.07,.12,0,1.06,-.94,0x5a3b25);
  colliders.box(1.75,-1.1,1.2,1.92,0,'bed');
  // Sofa against the west wall, under the side window.
  const sofa=usableGroup('sofa','소파','🛋️',{x:-1.48,z:-.35,face:-Math.PI/2},-2.17,0,-.35);
  const cloth=0x7c8f5f;
  box(sofa,.75,.3,1.7,0,.2,0,0x5f6f48);box(sofa,.62,.12,.76,.04,.41,-.4,cloth,{roughness:1});box(sofa,.62,.12,.76,.04,.41,.4,cloth,{roughness:1});
  box(sofa,.2,.62,1.7,-.3,.6,0,cloth,{roughness:1});for(const s of [-1,1])box(sofa,.75,.42,.16,0,.42,s*.85,0x5f6f48);
  box(sofa,.12,.3,.32,.1,.56,-.5,0xe7c26a,{roughness:1}).rotation.z=-.3;
  colliders.box(-2.17,-.35,.8,1.75,0,'sofa');
  // Rug and coffee table.
  const rug=new T.Mesh(new T.CylinderGeometry(1,1,.015,40),mat(0xa4483c,{roughness:1}));rug.scale.set(1.15,1,.85);rug.position.set(-.85,.008,-.3);rug.receiveShadow=true;scene.add(rug);
  const rugIn=new T.Mesh(new T.CylinderGeometry(.82,.82,.017,40),mat(0xd7b46a,{roughness:1}));rugIn.scale.set(1.15,1,.85);rugIn.position.copy(rug.position);scene.add(rugIn);
  const table=new T.Group();table.position.set(-.8,0,-.3);scene.add(table);
  box(table,.55,.05,.9,0,.36,0,0x8a5f3d);for(const [x,z] of [[-.22,-.38],[.22,-.38],[-.22,.38],[.22,.38]])box(table,.05,.34,.05,x,.17,z,0x6a4a30);
  const mug=new T.Mesh(new T.CylinderGeometry(.04,.035,.09,12),mat(0xf0ead8));mug.position.set(.05,.43,.15);table.add(mug);
  box(table,.18,.04,.25,-.05,.4,-.2,0x3f6c8a);
  colliders.box(-.8,-.3,.6,.95,0,'table');
  // Fireplace with a stone chimney breast, logs and a fire that burns on wood.
  const hearth=usableGroup('fire','벽난로','🔥',{x:.35,z:-1.25,face:Math.PI},.35,0,Z0+.25);
  const stone=['#8a8170','#958d79','#7a7364','#a39b87'];
  for(let r=0;r<6;r++)for(let c=0;c<4;c++){if(r<3&&c>0&&c<3)continue;box(hearth,.27,.2,.36,-.41+c*.275,.1+r*.2,0,pick(stone))}
  box(hearth,.6,.6,.06,0,.3,-.15,0x161210);
  box(hearth,1.3,.08,.46,0,1.25,.02,0x6a4a30);
  box(hearth,.8,1.2,.3,0,1.9,-.03,0x8a8170);
  box(hearth,1.2,.04,.5,0,.02,.1,0x6f6a5d);
  for(const [x,r] of [[-.1,.3],[.1,-.25]]){const log=new T.Mesh(new T.CylinderGeometry(.05,.05,.42,8),mat(0x5a3b25));log.rotation.set(0,r,Math.PI/2);log.position.set(x*0,.08,0);hearth.add(log)}
  const flames=[];
  for(const [x,h,c] of [[-.08,.28,0xff7a1a],[.07,.34,0xffa63a],[0,.22,0xffd36a]]){
    const f=new T.Mesh(new T.ConeGeometry(.08,h,8),new T.MeshBasicMaterial({color:c,transparent:true,opacity:.9,blending:T.AdditiveBlending,depthWrite:false}));
    f.position.set(x,.12+h/2,0);f.userData.h=h;hearth.add(f);flames.push(f);
  }
  const fireLight=new T.PointLight(0xff8a3a,0,5,1.6);fireLight.position.set(0,.45,.35);hearth.add(fireLight);
  colliders.box(.35,Z0+.25,1.3,.6,0,'fire');
  // Bookshelf in the back corner.
  const shelf=usableGroup('books','책장','📚',{x:-2.05,z:-1.15,face:Math.PI},-2.05,0,Z0+.2);
  box(shelf,.85,1.9,.3,0,.95,0,0x6a4a30);
  const bookColors=['#7a3b32','#3f6c8a','#c49a3a','#4e7a4a','#8b5a8c','#d4c3a0','#2f4a60'];
  for(let r=0;r<4;r++){
    box(shelf,.78,.03,.27,0,.15+r*.45,.03,0x7d5536);
    let x=-.36;while(x<.32){const w=.04+rng()*.05,h=.25+rng()*.12;box(shelf,w,h,.2,x+w/2,.165+r*.45+h/2,.05,pick(bookColors),{roughness:.9});x+=w+.008}
  }
  colliders.box(-2.05,Z0+.2,.9,.4,0,'shelf');
  // Floor lamp by the sofa.
  const lamp=usableGroup('lamp','스탠드','💡',{x:-1.75,z:.95,face:-Math.PI/2},-2.25,0,.95);
  const lampBase=new T.Mesh(new T.CylinderGeometry(.14,.16,.04,16),mat(0x3b2a1e));lampBase.position.y=.02;lamp.add(lampBase);
  const pole=new T.Mesh(new T.CylinderGeometry(.015,.015,1.35,8),mat(0x3b2a1e));pole.position.y=.7;lamp.add(pole);
  const shade=new T.Mesh(new T.CylinderGeometry(.13,.22,.25,16,1,true),new T.MeshStandardMaterial({color:0xf3dcae,roughness:.8,side:T.DoubleSide,emissive:0xffc070,emissiveIntensity:0}));
  shade.position.y=1.38;lamp.add(shade);
  const lampLight=new T.PointLight(0xffc27a,0,5,1.5);lampLight.position.y=1.3;lamp.add(lampLight);
  colliders.circle(-2.25,.95,.18,'lamp');
  // Dining corner: a table, two chairs, a vase of flowers; a potted plant; pictures.
  const dine=new T.Group();dine.position.set(1.45,0,1.05);scene.add(dine);
  box(dine,.9,.05,.75,0,.7,0,0x8a5f3d);for(const [x,z] of [[-.38,-.3],[.38,-.3],[-.38,.3],[.38,.3]])box(dine,.06,.68,.06,x,.34,z,0x6a4a30);
  for(const s of [-1,1]){const ch=new T.Group();ch.position.set(s*.65,0,0);ch.rotation.y=s*Math.PI/2;dine.add(ch);
    box(ch,.42,.04,.42,0,.42,0,0x8a5f3d);for(const [x,z] of [[-.17,-.17],[.17,-.17],[-.17,.17],[.17,.17]])box(ch,.04,.42,.04,x,.21,z,0x6a4a30);box(ch,.42,.45,.04,0,.66,.19,0x8a5f3d)}
  const vase=new T.Mesh(new T.CylinderGeometry(.05,.07,.18,12),mat(0x5e8fa8));vase.position.set(0,.82,0);dine.add(vase);
  for(let i=0;i<5;i++){const fl=new T.Mesh(new T.SphereGeometry(.035,8,6),mat(pick([0xe85a78,0xf2c430,0xf4f1e4])));fl.position.set((rng()-.5)*.12,.96+rng()*.06,(rng()-.5)*.12);dine.add(fl)}
  colliders.box(1.45,1.05,2.2,.85,0,'dine');
  const pot=new T.Group();pot.position.set(2.32,0,.38);scene.add(pot);
  const potBody=new T.Mesh(new T.CylinderGeometry(.16,.12,.3,14),mat(0xa65a3a));potBody.position.y=.15;pot.add(potBody);
  for(let i=0;i<7;i++){const leaf=new T.Mesh(new T.SphereGeometry(.16,8,6),mat(pick([0x4f7a3a,0x5e8a42,0x6f9a4a])));leaf.scale.set(1,.6,.5);leaf.position.set((rng()-.5)*.25,.42+rng()*.35,(rng()-.5)*.25);leaf.rotation.set(rng(),rng()*6,rng());pot.add(leaf)}
  colliders.circle(2.32,.38,.22,'pot');
  for(const [z,y,w,h,c] of [[.9,1.55,.5,.38,0x5e8a6a],[1.55,1.7,.32,.42,0xc98a5a]]){
    const pic=new T.Group();pic.position.set(X0+.03,y,z);pic.rotation.y=Math.PI/2;scene.add(pic);
    box(pic,w+.08,h+.08,.03,0,0,0,0x3b2a1e);box(pic,w,h,.01,0,0,.02,c,{roughness:1});
  }
  // Door out, in the west wall.
  const door=usableGroup('door','문','🚪',{x:-1.95,z:1.6,face:-Math.PI/2},X0+.04,0,1.6);
  {const leaf=new T.Group();leaf.rotation.y=Math.PI/2;door.add(leaf);
    box(leaf,.92,2.02,.06,0,1.01,0,0x3b2a1e);
    for(let i=0;i<4;i++)box(leaf,.2,1.9,.04,-.3+i*.2,1,.03,pick(['#6a432b','#73492f','#5f3c27']));
    for(const y of [.45,1.55])box(leaf,.8,.08,.03,0,y,.05,0x4e3322);
    const knob=new T.Mesh(new T.SphereGeometry(.035,10,8),mat(0xc9a35a,{metalness:.6,roughness:.4}));knob.position.set(.3,.98,.08);leaf.add(knob);}
  // Wall sconces either side of the chimney: lit after dark.
  const sconces=[];
  for(const x of [-.45,1.15]){
    const s=new T.Mesh(new T.SphereGeometry(.07,12,8,0,Math.PI*2,0,Math.PI/2),new T.MeshStandardMaterial({color:0xfff0d0,emissive:0xffc070,emissiveIntensity:0}));
    s.rotation.x=Math.PI;s.position.set(x,1.85,Z0+.08);scene.add(s);sconces.push(s);box(scene,.04,.12,.06,x,1.92,Z0+.04,0x3b2a1e);
  }
  // Per-piece materials, so hovering can light up just that piece.
  for(const g of usable)g.traverse(o=>{if(o.isMesh&&o.material.isMeshStandardMaterial)o.material=o.material.clone()});

  // ---- Light: daylight through the windows by the hour, a warm room after dark ----
  const hemi=new T.HemisphereLight(0xe6eef6,0x6a4c36,.6);scene.add(hemi);
  const ambient=new T.AmbientLight(0xffe2c0,.15);scene.add(ambient);
  // Daylight falls in from the open (cut-away) side, so the walls and furniture are lit as seen.
  const day=new T.DirectionalLight(0xfff1dc,1.4);day.position.set(4.5,7,5.5);day.target.position.set(-.4,0,-.5);
  day.castShadow=true;day.shadow.mapSize.set(1024,1024);Object.assign(day.shadow.camera,{left:-4,right:4,top:4,bottom:-4,near:.5,far:20});day.shadow.bias=-.0004;day.shadow.normalBias=.02;
  scene.add(day,day.target);
  const warm=new T.PointLight(0xffc68a,0,9,1.2);warm.position.set(.2,2.2,.2);scene.add(warm);

  // ---- Movement for her inside: straight lines across the floor, round furniture by way of a
  // few open waypoints when the direct line is blocked ----
  const inside=(x,z)=>x>X0+.25&&x<W/2-.15&&z>Z0+.25&&z<D/2-.15;
  const open=(x,z)=>inside(x,z)&&!colliders.blocked(x,z,.2);
  const clearLine=(a,b)=>{const n=Math.ceil(Math.hypot(b.x-a.x,b.z-a.z)/.1);for(let i=1;i<=n;i++){const u=i/n;if(!open(a.x+(b.x-a.x)*u,a.z+(b.z-a.z)*u))return false}return true};
  const waypoints=[{x:0,z:.55},{x:-.35,z:-.9},{x:.6,z:-.25},{x:-1.1,z:.75},{x:.35,z:1.6},{x:-1.6,z:-1.05},{x:1.02,z:.2}];
  const roomPlace={scene,
    route(from,goal){
      if(clearLine(from,goal))return [{x:goal.x,z:goal.z}];
      let best=null,len=Infinity;
      for(const a of waypoints){
        if(clearLine(from,a)&&clearLine(a,goal)){const l=Math.hypot(a.x-from.x,a.z-from.z)+Math.hypot(goal.x-a.x,goal.z-a.z);if(l<len){len=l;best=[a,goal]}}
        for(const b of waypoints)if(a!==b&&clearLine(from,a)&&clearLine(a,b)&&clearLine(b,goal)){
          const l=Math.hypot(a.x-from.x,a.z-from.z)+Math.hypot(b.x-a.x,b.z-a.z)+Math.hypot(goal.x-b.x,goal.z-b.z);if(l<len){len=l;best=[a,b,goal]}}
      }
      return (best??[goal]).map(p=>({x:p.x,z:p.z}));
    },
    resolve(b){colliders.resolve(b);b.x=Math.min(W/2-.2,Math.max(X0+.25,b.x));b.z=Math.min(D/2-.2,Math.max(Z0+.25,b.z))},
    stand:()=>0,
    walkable:open,
    closest:p=>({x:Math.min(W/2-.3,Math.max(X0+.35,p.x)),z:Math.min(D/2-.3,Math.max(Z0+.35,p.z))})
  };
  // colliders.resolve ignores inactive bodies; the room body is always active.

  // ---- Screen-side UI: fade, hover label, status tag ----
  const fade=document.createElement('div');fade.className='room-fade';document.body.append(fade);
  const label=document.createElement('div');label.className='room-label';label.hidden=true;document.body.append(label);
  const status=document.createElement('div');status.className='plot-tag room-status';status.dataset.state='pending';status.hidden=true;
  status.innerHTML='<span class="plot-icon"></span><span class="plot-text"></span>';document.body.append(status);
  const exitHint=document.createElement('button');exitHint.type='button';exitHint.className='room-exit';exitHint.textContent='🚪 밖으로 나가기';exitHint.hidden=true;document.body.append(exitHint);
  const fadeTo=(on,text='')=>new Promise(r=>{fade.textContent=text;fade.classList.toggle('on',on);setTimeout(r,on?480:20)});

  let active=false,busy=null,fireLeft=0,lampOn=false,lastRead=-Infinity,hover=null;
  async function enter(){
    if(active)return;
    await fadeTo(true);
    active=true;controls.enabled=false;hooks.indoor(true);
    character.enterRoom(roomPlace,{x:-1.95,z:1.6,heading:Math.PI/2});
    character.walkTo(-1.05,.85);
    exitHint.hidden=false;
    await fadeTo(false);
  }
  async function leave(){
    if(!active)return;
    await fadeTo(true);
    active=false;busy=null;status.hidden=true;label.hidden=true;exitHint.hidden=true;highlight(null);
    controls.enabled=true;hooks.indoor(false);character.leaveRoom();
    await fadeTo(false);
    status.hidden=true;
  }
  exitHint.addEventListener('click',()=>use(door));
  function job(piece,steps,{start,done,text}){
    busy={piece,text:'이동 중'};
    character.work({spots:[piece.userData.spot],steps,
      onStart(){busy={piece,text};start?.()},
      onDone(){busy=null;done?.()},
      onCancel(){busy=null;character.setPose(null)},
      onFail(){busy=null;hooks.toast('🚧 그곳으로 갈 수 없어요')}});
  }
  // What each piece does when tapped.
  function use(piece){
    const key=piece.userData.key;
    if(busy){hooks.toast('🙂 지금 하던 일을 마치고 할게요');return}
    if(key==='door'){
      busy={piece,text:'이동 중'};
      character.work({spots:[piece.userData.spot],steps:[],onDone(){busy=null;status.hidden=true;leave()},onCancel(){busy=null},onFail(){busy=null;leave()}});
      return;
    }
    if(key==='bed'){
      const night=hooks.isNight();
      job(piece,[{clip:'Standing',time:4.2,fade:.2}],{text:night?'잠자는 중':'낮잠 자는 중',
        start(){
          character.setPose({x:1.75,y:.5,z:-.42,heading:0,tilt:-Math.PI/2,sleep:true});
          fadeTo(true,'💤').then(()=>{if(night)hooks.sleep();setTimeout(()=>fadeTo(false),1700)});
        },
        done(){character.setPose(null);hooks.toast(night?'☀️ 푹 자고 일어났어요. 좋은 아침!':'😌 개운하게 낮잠을 잤어요');hooks.earn(0,1,'💤')}});
      return;
    }
    if(key==='sofa'){
      job(piece,[{clip:'KneelDown',time:5.5,fade:.25},{clip:'KneelDownToUp',fade:.15}],{text:'쉬는 중',
        start(){character.setPose({x:-2.08,y:.34,z:-.35,heading:Math.PI/2})},
        done(){character.setPose(null);hooks.earn(0,1,'😌 휴식')}});
      return;
    }
    if(key==='fire'){
      if(fireLeft>0){job(piece,[{clip:'Gathering',time:1.4}],{text:'불 끄는 중',done(){fireLeft=0}});return}
      if(!hooks.spendWood(1,true)){hooks.toast('🪵 장작이 1개 필요해요. 나무를 베어 오세요');return}
      job(piece,[{clip:'Gathering',time:1.8}],{text:'불 피우는 중',done(){
        if(!hooks.spendWood(1)){hooks.toast('🪵 장작이 부족해요');return}
        fireLeft=FIRE_SECONDS;hooks.toast('🔥 벽난로에 불을 피웠어요 (10분)');
      }});
      return;
    }
    if(key==='books'){
      job(piece,[{clip:'Gathering',time:3}],{text:'책 읽는 중',done(){
        const now=performance.now()/1000;
        if(now-lastRead<READ_COOLDOWN){hooks.toast('📖 방금 읽은 책이에요. 조금 뒤에 다시 읽어요');return}
        lastRead=now;hooks.earn(0,3,'📖 독서');
      }});
      return;
    }
    if(key==='lamp')job(piece,[{clip:'Gathering',time:.9}],{text:lampOn?'불 끄는 중':'불 켜는 중',done(){lampOn=!lampOn}});
  }

  // ---- Input: taps on furniture use it, taps on the floor walk there ----
  const raycaster=new T.Raycaster(),pointer=new T.Vector2();
  const floorPlane=new T.Plane(new T.Vector3(0,1,0),0),hit=new T.Vector3();
  function aim(x,y){const r=canvas.getBoundingClientRect();pointer.set((x-r.left)/r.width*2-1,-(y-r.top)/r.height*2+1);raycaster.setFromCamera(pointer,camera)}
  function pickPiece(){
    const hits=raycaster.intersectObjects(usable,true);if(!hits.length)return null;
    let o=hits[0].object;while(o&&!o.userData.key)o=o.parent;return o;
  }
  function highlight(piece){
    if(hover===piece)return;
    for(const g of [hover,piece])g?.traverse(o=>{if(o.isMesh&&o.material.emissive&&o!==shade)o.material.emissive.setHex(g===piece?0x2a2014:0)});
    hover=piece;canvas.style.cursor=piece?'pointer':'';
  }
  let press=null;const touches=new Set();
  addEventListener('pointerdown',e=>{
    if(!active||e.target!==canvas)return;
    if(e.pointerType==='touch')touches.add(e.pointerId);
    press=(e.pointerType!=='touch'&&e.button!==0)||touches.size>1?null:{id:e.pointerId,x:e.clientX,y:e.clientY,t:performance.now()};
  },{capture:true});
  addEventListener('pointermove',e=>{
    if(!active)return;
    if(press?.id===e.pointerId&&Math.hypot(e.clientX-press.x,e.clientY-press.y)>8)press=null;
    if(e.pointerType==='mouse'&&e.target===canvas){
      aim(e.clientX,e.clientY);const piece=pickPiece();highlight(piece);
      label.hidden=!piece;
      if(piece){label.textContent=piece.userData.icon+' '+piece.userData.name;label.style.left=e.clientX+'px';label.style.top=e.clientY+'px'}
    }
  },{capture:true});
  const release=e=>{
    touches.delete(e.pointerId);const p=press;press=null;
    if(!active||e.type!=='pointerup'||p?.id!==e.pointerId||performance.now()-p.t>650)return;
    aim(e.clientX,e.clientY);
    const piece=pickPiece();
    if(piece){use(piece);return}
    if(raycaster.ray.intersectPlane(floorPlane,hit)&&!busy)character.walkTo(hit.x,hit.z);
  };
  addEventListener('pointerup',release,{capture:true});addEventListener('pointercancel',release,{capture:true});

  function resize(w,h){
    const aspect=w/h,span=Math.max(6.4,9.6/aspect);
    camera.left=-span*aspect/2;camera.right=span*aspect/2;camera.top=span/2;camera.bottom=-span/2;camera.updateProjectionMatrix();
  }
  resize(innerWidth,innerHeight);
  const anchor=new T.Vector3(),sky=new T.Color(),night=new T.Color(0x0e1424);
  let frame=0,points=null;
  return {
    get active(){return active},
    enter,leave,resize,
    // env: {night 0-1, cover 0-2 (clouds), rain 0-1, snow 0-1, sun Color}
    render(dt,env){
      frame++;
      // Daylight in through the windows, dimmed by cloud and gone at night; warm lights after dark.
      const daylight=(1-env.night)*(env.cover<1?1-.35*env.cover:.65-.25*(env.cover-1));
      day.intensity=2.4*daylight;day.color.copy(env.sun).lerp(sky.setHex(0xdfe8f2),.5);
      hemi.intensity=.25+.75*daylight;ambient.intensity=.12+.06*env.night;
      warm.intensity=8*env.night;
      for(const s of sconces)s.material.emissiveIntensity=1.6*env.night;
      lampLight.intensity=lampOn?5:0;shade.material.emissiveIntensity=lampOn?1.1:0;
      scene.background.setHex(0x1e1a17).lerp(night,env.night*.6);
      // The fire: flickering flames and light while it has wood.
      fireLeft=Math.max(0,fireLeft-dt);
      const t=performance.now()/1000,burning=fireLeft>0;
      flames.forEach((f,i)=>{f.visible=burning;const k=.85+.25*Math.sin(t*(9+i*3)+i)*Math.sin(t*5.3+i*2);f.scale.set(1,k,1);f.position.y=.12+f.userData.h*k/2});
      fireLight.intensity=burning?3.2+.9*Math.sin(t*13)*Math.sin(t*7.7):0;
      // Rain streams down the glass.
      for(const d of drops){d.material.opacity=env.rain*.8;d.material.map.offset.y+=dt*.35}
      // Status over whatever she is busy with.
      if(busy&&active){
        busy.piece.getWorldPosition(anchor);anchor.y+=busy.piece.userData.key==='door'?2.3:1.5;anchor.project(camera);
        const r=canvas.getBoundingClientRect();
        status.hidden=false;status.style.left=Math.round(r.left+(anchor.x+1)/2*r.width)+'px';status.style.top=Math.round(r.top+(1-anchor.y)/2*r.height)+'px';
        status.children[0].textContent=busy.piece.userData.icon;status.children[1].textContent=busy.text;
      }else status.hidden=true;
      // Window views: the island from the cottage's windows, one view per frame in turn.
      // Point sprites (fireflies, moths) are sized for the island's orthographic camera and would
      // swell into huge glows through a perspective window, so they sit these renders out.
      const view=views[frame%2];
      if(!points){points=[];outdoor.traverse(o=>{if(o.isPoints)points.push(o)})}
      const shown=points.map(o=>o.visible);for(const o of points)o.visible=false;
      renderer.setRenderTarget(view.rt);renderer.render(outdoor,view.cam);renderer.setRenderTarget(null);
      points.forEach((o,i)=>o.visible=shown[i]);
      renderer.shadowMap.needsUpdate=true;
      renderer.render(scene,camera);
    }
  };
}
