import * as T from 'three';
import {RoundedBoxGeometry} from 'three/addons/geometries/RoundedBoxGeometry.js';
import {createColliders} from './colliders.js';
import {createGridPaths} from './pathgrid.js';

// The cottage interior: a dollhouse cut-away of a living room with a kitchen beside it, in a
// scene of its own, drawn instead of the island while she is inside. The windows show the sky
// and the weather outside (a sky shader fed from the island's own sky colours, clouds, fog,
// snow and rain on the glass). Two pendant lamps hang from the ceiling beams: each casts a
// spotlight that sways very slightly, so its shadows move. Furniture can be used, and the
// door leads back outside.
// The back wall stays at Z0; the room runs forward to the open (cut-away) front at Z1.
const W=8.2,Z0=-2.1,Z1=3.0,D=Z1-Z0,ZC=(Z0+Z1)/2,H=2.6,X0=-W/2,XK=.6;   // XK: where the living room ends and the kitchen begins
const FIRE_SECONDS=600,READ_COOLDOWN=300,COOK_COOLDOWN=300;

// ---------- Canvas textures ----------
function canvasTexture(w,h,paint,srgb=true){
  const c=document.createElement('canvas');c.width=w;c.height=h;paint(c.getContext('2d'),w,h);
  const t=new T.CanvasTexture(c);if(srgb)t.colorSpace=T.SRGBColorSpace;t.wrapS=t.wrapT=T.RepeatWrapping;t.anisotropy=8;return t;
}
const rand=(()=>{let s=9137;return()=>((s=(Math.imul(s,1664525)+1013904223)>>>0)/4294967296)})();
function grain(g,w,h,base,dark,lines=60){
  g.fillStyle=base;g.fillRect(0,0,w,h);
  for(let i=0;i<lines;i++){
    const y=rand()*h,a=.05+rand()*.12;g.strokeStyle=`rgba(${dark},${a})`;g.lineWidth=.6+rand()*1.6;
    g.beginPath();g.moveTo(0,y);for(let x=0;x<=w;x+=16)g.lineTo(x,y+Math.sin(x*.02+i)*3+rand()*1.5);g.stroke();
  }
}
const woodTex=(base,dark)=>canvasTexture(256,256,(g,w,h)=>grain(g,w,h,base,dark));
const floorTex=canvasTexture(512,512,(g,w,h)=>{
  const tones=['#a8754a','#9d6c43','#b07d50','#956640','#a2714a'];
  for(let r=0;r<8;r++){
    let x=-rand()*200;const y=r*h/8;
    while(x<w){const l=180+rand()*220;g.fillStyle=tones[Math.floor(rand()*tones.length)];g.fillRect(x,y,l,h/8);
      for(let i=0;i<10;i++){g.strokeStyle=`rgba(70,40,20,${.06+rand()*.1})`;g.lineWidth=.8;const yy=y+rand()*h/8;g.beginPath();g.moveTo(x,yy);g.bezierCurveTo(x+l*.3,yy+rand()*6-3,x+l*.6,yy+rand()*6-3,x+l,yy);g.stroke()}
      g.fillStyle='rgba(40,22,10,.55)';g.fillRect(x,y,2,h/8);g.fillStyle='rgba(30,16,8,.45)';g.fillRect(x+6,y+h/16-2,3,3);g.fillRect(x+l-9,y+h/16-2,3,3);
      x+=l}
    g.fillStyle='rgba(40,22,10,.6)';g.fillRect(0,y,w,2);
  }
});
const plasterTex=canvasTexture(256,256,(g,w,h)=>{
  g.fillStyle='#efe3cb';g.fillRect(0,0,w,h);
  for(let i=0;i<3000;i++){g.fillStyle=`rgba(${130+rand()*60},${105+rand()*40},70,${rand()*.05})`;g.fillRect(rand()*w,rand()*h,2+rand()*7,2+rand()*7)}
});
const fabricTex=(base)=>canvasTexture(128,128,(g,w,h)=>{
  g.fillStyle=base;g.fillRect(0,0,w,h);
  for(let y=0;y<h;y+=2)for(let x=0;x<w;x+=2){g.fillStyle=`rgba(${(x+y)%4?255:0},${(x+y)%4?255:0},${(x+y)%4?255:0},.05)`;g.fillRect(x,y,2,2)}
  for(let i=0;i<500;i++){g.fillStyle=`rgba(0,0,0,${rand()*.06})`;g.fillRect(rand()*w,rand()*h,1,3)}
});
const quiltTex=canvasTexture(256,256,(g,w,h)=>{
  const c=['#5f7fae','#e9dcc2','#b8574a','#7f9c6a','#d9b35a','#4f6d97','#f2ead8'];
  for(let j=0;j<8;j++)for(let i=0;i<8;i++){
    g.fillStyle=c[Math.floor(rand()*c.length)];g.fillRect(i*32,j*32,32,32);
    if(rand()<.4){g.fillStyle=c[Math.floor(rand()*c.length)];g.beginPath();g.moveTo(i*32,j*32);g.lineTo(i*32+32,j*32+32);g.lineTo(i*32,j*32+32);g.fill()}
    g.strokeStyle='rgba(255,255,255,.35)';g.setLineDash([3,3]);g.strokeRect(i*32+2,j*32+2,28,28);g.setLineDash([]);
  }
});
const rugTex=canvasTexture(512,512,(g,w,h)=>{
  const bands=['#8f3a2e','#d8b46a','#3f5f7a','#e9dcc2','#8f3a2e','#c46a3a','#f0e4c8','#3f5f7a'];
  bands.forEach((c,i)=>{g.fillStyle=c;g.beginPath();g.ellipse(w/2,h/2,w/2-i*22,h/2-i*22,0,0,7);g.fill()});
  g.fillStyle='#8f3a2e';for(let i=0;i<24;i++){const a=i/24*Math.PI*2;g.beginPath();g.arc(w/2+Math.cos(a)*(w/2-33),h/2+Math.sin(a)*(h/2-33),6,0,7);g.fill()}
  for(let i=0;i<4000;i++){g.fillStyle=`rgba(0,0,0,${rand()*.08})`;g.fillRect(rand()*w,rand()*h,1,2)}
});
const stoneTex=canvasTexture(256,256,(g,w,h)=>{
  g.fillStyle='#5d574c';g.fillRect(0,0,w,h);
  for(let r=0;r<7;r++){let x=-rand()*30;while(x<w){const sw=34+rand()*30,c=110+rand()*50;
    g.fillStyle=`rgb(${c+8},${c+2},${c-12})`;g.beginPath();g.roundRect(x+2,r*37+2,sw-4,33,7);g.fill();
    g.fillStyle='rgba(255,255,255,.08)';g.fillRect(x+5,r*37+4,sw-12,4);x+=sw}}
});
const tileTex=canvasTexture(256,256,(g,w,h)=>{
  g.fillStyle='#cfc6b4';g.fillRect(0,0,w,h);
  for(let j=0;j<8;j++)for(let i=0;i<8;i++){const c=226+rand()*18;g.fillStyle=`rgb(${c},${c-4},${c-14})`;g.fillRect(i*32+(j%2)*16+1.5,j*32+1.5,29,29)}
});
const rainTex=canvasTexture(128,256,(g,w,h)=>{
  g.clearRect(0,0,w,h);g.strokeStyle='rgba(225,235,245,.55)';g.lineCap='round';
  for(let i=0;i<70;i++){const x=rand()*w,y=rand()*h,l=8+rand()*22;g.lineWidth=.8+rand()*1.4;g.beginPath();g.moveTo(x,y);g.lineTo(x+1,y+l);g.stroke()}
  g.fillStyle='rgba(235,242,250,.5)';for(let i=0;i<40;i++){g.beginPath();g.arc(rand()*w,rand()*h,.8+rand()*1.8,0,7);g.fill()}
},false);

// ---------- The view beyond the windows ----------
// Each pane is a little camera: a ray per pixel from an eye standing back in the room, out
// through the glass. Up the ray meets a cloud deck (so the clouds foreshorten toward the
// horizon), level with the eye it meets layered hills fading into the distance, and the sky
// grades by elevation. Rain and snow fall in three depths at different speeds.
const skyVertex='varying vec2 vUv;void main(){vUv=uv;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}';
const skyFragment=`
varying vec2 vUv;
uniform vec3 top,bottom,glow,sunDir;uniform float sunAmt,moonAmt,stars,cover,haze,time,night,snow,rain,whiteGround,seed,aspect,day;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
  return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){float v=0.,a=.5;for(int i=0;i<5;i++){v+=a*noise(p);p=p*2.03+vec2(1.7,.3);a*=.5;}return v;}
float ridge(float az,float seed,float amp,float base){return base+amp*(fbm(vec2(az*3.+seed,seed))-.45);}
void main(){
  // Ray from an eye 1.1 pane-heights back in the room, a little above the pane's lower third.
  vec3 ray=normalize(vec3((vUv.x-.5)*aspect,vUv.y-.36,-1.1));
  float elev=ray.y,az=atan(ray.x,-ray.z)+seed;
  vec3 sky=mix(bottom,top,smoothstep(-.05,.55,elev));
  // Sun or moon, with a halo.
  float cosA=dot(ray,normalize(sunDir));
  sky+=glow*sunAmt*(smoothstep(.9992,.9996,cosA)*2.+pow(max(cosA,0.),60.)*.6+pow(max(cosA,0.),6.)*.15);
  sky=mix(sky,vec3(.93,.95,1.),moonAmt*smoothstep(.9993,.9996,cosA));
  sky+=vec3(.55,.65,.9)*moonAmt*pow(max(cosA,0.),40.)*.25;
  // Stars, only up in clear sky.
  vec2 sc=floor(vec2(az*90.,elev*90.));float tw=hash(sc+seed);
  sky+=vec3(step(.988,tw)*stars*(.55+.45*sin(time*2.3+tw*40.)))*smoothstep(.02,.12,elev);
  // Clouds on a deck overhead: foreshortened toward the horizon, thicker and greyer with weather.
  if(elev>0.){
    vec2 deck=ray.xz/max(elev,.04)*.5+vec2(time*.02,seed*3.);
    float c=fbm(deck*vec2(1.,1.6)),thr=mix(.62,.28,clamp(cover*.5,0.,1.)),amount=smoothstep(thr,thr+.22,c);
    vec3 cloud=mix(vec3(1.),vec3(.52,.55,.6),clamp(cover-.6,0.,1.))*mix(1.,.16,night);
    cloud=mix(cloud,glow*1.15,.35*sunAmt*(1.-night));
    cloud*=.78+.3*smoothstep(.25,.85,fbm(deck*2.3+5.));
    amount*=smoothstep(.0,.18,elev);
    sky=mix(sky,cloud,amount*.94);
  }
  // Haze thickens toward the horizon.
  vec3 hazeCol=mix(bottom,vec3(.8,.82,.85)*mix(1.,.2,night),.4);
  sky=mix(sky,hazeCol,(1.-smoothstep(0.,.25,abs(elev)))*.35);
  vec3 col=sky;
  // Hills in three distances, each paler and bluer the farther it is (aerial perspective).
  vec3 lit=mix(vec3(.05,.07,.1),vec3(1.),day);
  vec3 farC=mix(vec3(.42,.52,.6),bottom,.55)*mix(.35,1.,day),midC=vec3(.32,.44,.3)*lit,nearC=vec3(.17,.27,.15)*lit;
  vec3 snowC=vec3(.88,.9,.94)*mix(.2,1.,day);
  farC=mix(farC,mix(snowC,bottom,.4),whiteGround*.8);midC=mix(midC,snowC*.92,whiteGround);nearC=mix(nearC,snowC*.8,whiteGround*.9);
  float fr=ridge(az,seed+1.,.16,.02),mr=ridge(az*1.8,seed+5.,.1,-.01),nr=ridge(az*4.,seed+9.,.06,-.035)+.03*step(.5,noise(vec2(az*60.,seed)))*noise(vec2(az*140.,1.));
  if(elev<fr)col=mix(farC,hazeCol,.45);
  if(elev<mr)col=mix(midC*(.85+.15*noise(vec2(az*20.,elev*30.))),hazeCol,.22);
  if(elev<nr)col=nearC*(.8+.25*noise(vec2(az*40.,elev*60.)));
  if(elev<nr-.06)col=mix(nearC*1.1,snowC*.85,whiteGround)*(.75+.2*noise(vec2(az*25.,elev*25.)));
  // Fog swallows the distance first.
  col=mix(col,hazeCol*1.05,haze*mix(.95,.6,smoothstep(-.1,.0,elev)));
  // Rain and snow in three depths: near drops big and fast, far ones fine and slow.
  for(int l=0;l<3;l++){
    float k=float(l),depth=1.+k*.9;
    vec2 p=vUv*vec2(aspect,1.)*vec2(18.,6.)*depth;p.x+=p.y*.12;p.y+=time*(9.-k*2.5);
    vec2 id=floor(p);float r=hash(id+k*7.);
    float streak=smoothstep(.09,.0,abs(fract(p.x)-.5-r*.3))*smoothstep(.0,.5,fract(p.y))*step(.72,r);
    col=mix(col,vec3(.82,.86,.92)*mix(1.,.3,night),streak*rain*(.55-k*.13));
    vec2 q=vUv*vec2(aspect,1.)*vec2(9.,7.)*depth;q.y+=time*(.9-k*.22);q.x+=sin(time*.7+q.y*.5+k)*.35;
    vec2 qi=floor(q),o=vec2(hash(qi+3.),hash(qi+7.))*.6+.2;
    float flake=smoothstep(.16/depth+.02,.0,length(fract(q)-o))*step(.45,hash(qi+k*13.));
    col=mix(col,vec3(.97)*mix(1.,.35,night),flake*snow*(1.-k*.25));
  }
  // The glass darkens a touch toward the recess of the frame.
  col*=.86+.14*smoothstep(.0,.12,min(min(vUv.x,1.-vUv.x),min(vUv.y,1.-vUv.y)));
  gl_FragColor=vec4(col,1.);
  #include <tonemapping_fragment>
  #include <colorspace_fragment>
}`;

export function createRoom({renderer,world,character,canvas,controls,hooks}){
  const scene=new T.Scene();scene.background=new T.Color(0x1c1815);
  const camera=new T.OrthographicCamera(-5,5,3,-3,.1,80);
  const target=new T.Vector3(.1,.95,.6);camera.position.copy(target).add(new T.Vector3(6.4,6.6,8.6));camera.lookAt(target);
  const anchorTex=t=>{const c=t.clone();c.needsUpdate=true;return c};
  const std=(o)=>new T.MeshStandardMaterial({roughness:.75,...o});
  const M={
    floor:std({map:floorTex,roughness:.62}),
    plaster:std({map:plasterTex,roughness:.95}),
    oak:std({map:woodTex('#9a6a42','60,32,14'),roughness:.6}),
    walnut:std({map:woodTex('#6a4429','35,18,8'),roughness:.55}),
    pine:std({map:woodTex('#c3965e','90,55,25'),roughness:.6}),
    painted:std({color:0x6f8a74,roughness:.55}),
    cream:std({color:0xeee4cf,roughness:.5}),
    linen:std({map:fabricTex('#f3eee2'),roughness:1}),
    quilt:std({map:quiltTex,roughness:.95}),
    sofa:new T.MeshPhysicalMaterial({map:fabricTex('#6e8456'),roughness:.95,sheen:.6,sheenColor:new T.Color(0xc8d8a8)}),
    cushion:new T.MeshPhysicalMaterial({map:fabricTex('#d8a85a'),roughness:.95,sheen:.5,sheenColor:new T.Color(0xffe0a0)}),
    curtain:new T.MeshPhysicalMaterial({map:fabricTex('#b5574a'),roughness:.95,sheen:.4,sheenColor:new T.Color(0xffb0a0)}),
    stone:std({map:stoneTex,roughness:.92}),
    tile:std({map:tileTex,roughness:.3}),
    iron:std({color:0x2b2a28,metalness:.7,roughness:.45}),
    brass:std({color:0xc9a35a,metalness:.85,roughness:.3}),
    copper:std({color:0xc2733f,metalness:.85,roughness:.32}),
    ceramic:std({color:0xf4f0e6,roughness:.25}),
    blue:std({color:0x4f7a9a,roughness:.3}),
    soot:std({color:0x141110,roughness:1}),
    leaf:std({color:0x527d3d,roughness:.7}),
    terracotta:std({color:0xb0623e,roughness:.85})
  };
  M.floor.map.repeat.set(W/4,D/4);M.plaster.map.repeat.set(3,1);M.stone.map.repeat.set(1,1.4);M.tile.map.repeat.set(5,1);
  const shadow=m=>{m.castShadow=m.receiveShadow=true;return m};
  function rbox(parent,w,h,d,x,y,z,mat,r=.025){
    const m=shadow(new T.Mesh(new RoundedBoxGeometry(w,h,d,3,Math.min(r,w/2-1e-3,h/2-1e-3,d/2-1e-3)),mat));m.position.set(x,y,z);parent.add(m);return m;
  }
  function box(parent,w,h,d,x,y,z,mat){const m=shadow(new T.Mesh(new T.BoxGeometry(w,h,d),mat));m.position.set(x,y,z);parent.add(m);return m}
  function cyl(parent,rt,rb,h,x,y,z,mat,seg=16){const m=shadow(new T.Mesh(new T.CylinderGeometry(rt,rb,h,seg),mat));m.position.set(x,y,z);parent.add(m);return m}
  const pick=a=>a[Math.floor(rand()*a.length)];

  // ---------- Shell ----------
  const shell=new T.Group();scene.add(shell);
  box(shell,W+.36,.32,D+.36,0,-.164,ZC,M.walnut).receiveShadow=true;
  const floor=new T.Mesh(new T.PlaneGeometry(W,D),M.floor);floor.rotation.x=-Math.PI/2;floor.position.z=ZC;floor.receiveShadow=true;floor.name='floor';shell.add(floor);
  box(shell,W+.16,H,.16,0,H/2,Z0-.08,M.plaster);box(shell,.16,H,D,X0-.08,H/2,ZC,M.plaster);
  // Board-and-batten wainscot with a rail, skirting, and a cut-section cap on the wall tops.
  for(let i=0;i<Math.round(W/.32);i++)rbox(shell,.3,.95,.035,X0+(i+.5)*W/Math.round(W/.32),.48,Z0+.018,M.oak,.008);
  for(let i=0;i<Math.round(D/.32);i++)rbox(shell,.035,.95,.3,X0+.018,.48,Z0+(i+.5)*D/Math.round(D/.32),M.oak,.008);
  rbox(shell,W,.06,.07,0,.98,Z0+.04,M.walnut,.012);rbox(shell,.07,.06,D,X0+.04,.98,ZC,M.walnut,.012);
  box(shell,W,.12,.04,0,.06,Z0+.04,M.walnut);box(shell,.04,.12,D,X0+.04,.06,ZC,M.walnut);
  box(shell,W+.2,.05,.2,0,H+.025,Z0-.08,M.cream);box(shell,.2,.05,D+.04,X0-.08,H+.025,ZC,M.cream);
  // Joist ends where the (cut-away) ceiling meets the back wall.
  for(const x of [-3.4,-2.35,-1.1,1.3,2.35,3.5])rbox(shell,.16,.2,.34,x,H-.1,Z0+.17,M.walnut,.02);
  // A stub wall and header beam between living room and kitchen.
  rbox(shell,.18,H,1.15,XK,H/2,Z0+.575,M.plaster,.01);
  rbox(shell,.24,.95,1.17,XK,.48,Z0+.585,M.oak,.01);

  // ---------- Windows: sky and weather ----------
  const skies=[],wets=[];
  function windowAt(w,h,x,y,z,ry,seed){
    const g=new T.Group();g.position.set(x,y,z);g.rotation.y=ry;scene.add(g);
    const sky=new T.ShaderMaterial({vertexShader:skyVertex,fragmentShader:skyFragment,uniforms:{
      top:{value:new T.Color()},bottom:{value:new T.Color()},glow:{value:new T.Color()},sunDir:{value:new T.Vector3(0,1,-1)},
      sunAmt:{value:0},moonAmt:{value:0},stars:{value:0},cover:{value:0},haze:{value:0},time:{value:0},night:{value:0},snow:{value:0},
      rain:{value:0},whiteGround:{value:0},day:{value:1},seed:{value:seed},aspect:{value:w/h}}});
    const pane=new T.Mesh(new T.PlaneGeometry(w,h),sky);pane.position.z=.012;g.add(pane);skies.push(sky);
    const wet=new T.Mesh(new T.PlaneGeometry(w,h),new T.MeshBasicMaterial({map:anchorTex(rainTex),transparent:true,opacity:0,depthWrite:false}));
    wet.material.map.repeat.set(w/.6,h/.9);wet.position.z=.018;g.add(wet);wets.push(wet);
    // A deep reveal: plaster returns standing out from the wall, so the glass sits back in a recess.
    const reveal=std({color:0xcdbd9f,roughness:.95});
    for(const [ww,hh,xx,yy] of [[w+.2,.06,0,h/2+.13],[.06,h+.2,-w/2-.13,0],[.06,h+.2,w/2+.13,0]])box(g,ww,hh,.09,xx,yy,.045,M.plaster);
    for(const [ww,hh,xx,yy] of [[w+.02,.005,0,h/2+.1],[.005,h+.2,-w/2-.1,0],[.005,h+.2,w/2+.1,0]])box(g,ww,hh,.09,xx,yy,.045,reveal);
    g.translateZ(.09);pane.position.z=-.09+.012;wet.position.z=-.09+.018;
    // Glass sheen, sash, glazing bars, sill and apron, curtains on a pole.
    const sheen=new T.Mesh(new T.PlaneGeometry(w,h),new T.MeshPhysicalMaterial({color:0xffffff,transparent:true,opacity:.06,roughness:.05,depthWrite:false}));sheen.position.z=-.09+.022;g.add(sheen);
    for(const [ww,hh,xx,yy] of [[w+.16,.09,0,h/2+.045],[w+.16,.09,0,-h/2-.045],[.09,h,-w/2-.045,0],[.09,h,w/2+.045,0]])rbox(g,ww,hh,.1,xx,yy,.03,M.painted,.015);
    rbox(g,.035,h,.045,0,0,.04,M.painted,.008);rbox(g,w,.035,.045,0,h*.08,.04,M.painted,.008);
    rbox(g,w+.34,.05,.18,0,-h/2-.12,.08,M.oak,.015);rbox(g,w+.2,.1,.03,0,-h/2-.2,.02,M.oak,.01);
    cyl(g,.015,.015,w+1,0,h/2+.22,.11,M.brass).rotation.z=Math.PI/2;
    for(const s of [-1,1]){
      const geo=new T.PlaneGeometry(.34,h+.42,8,1),p=geo.attributes.position;
      for(let i=0;i<p.count;i++)p.setZ(i,Math.sin(p.getX(i)*28)*.025);
      geo.computeVertexNormals();
      const c=shadow(new T.Mesh(geo,M.curtain));c.position.set(s*(w/2+.24),.02,.1);g.add(c);
    }
    return g;
  }
  windowAt(1.0,1.0,-3.05,1.68,Z0+.02,0,.3);
  windowAt(1.0,.95,1.95,1.72,Z0+.02,0,1.7);
  windowAt(1.0,.95,X0+.02,1.68,-1.2,Math.PI/2,4.1);

  // ---------- Furniture. A usable piece is a group tagged with what it does ----------
  const usable=[],colliders=createColliders();
  function piece(key,name,icon,spot,x,z,ry=0){
    const g=new T.Group();g.position.set(x,0,z);g.rotation.y=ry;g.userData={key,name,icon,spot};scene.add(g);usable.push(g);return g;
  }
  function prop(x,z,ry=0){const g=new T.Group();g.position.set(x,0,z);g.rotation.y=ry;scene.add(g);return g}

  // Bed along the west wall, headboard to the wall, quilt folded back.
  const bed=piece('bed','침대','🛏️',{x:-3.15,z:-.25,face:Math.PI},-3.17,-1.2);
  rbox(bed,1.9,.26,1.2,0,.24,0,M.walnut,.03);
  for(const [x,z] of [[-.88,-.54],[.88,-.54],[-.88,.54],[.88,.54]])cyl(bed,.04,.035,.14,x,.07,z,M.walnut,10);
  rbox(bed,1.82,.2,1.1,.02,.47,0,M.linen,.07);
  rbox(bed,1.15,.07,1.16,.36,.6,0,M.quilt,.03);rbox(bed,.16,.1,1.16,-.25,.6,0,M.quilt,.04);
  for(const z of [-.27,.27])rbox(bed,.34,.12,.48,-.7,.63,z,M.linen,.06).rotation.z=.12;
  rbox(bed,.1,1.15,1.28,-.98,.58,0,M.walnut,.03);rbox(bed,.14,.08,1.34,-.98,1.18,0,M.walnut,.03);
  for(let i=0;i<5;i++)rbox(bed,.03,.75,.12,-.93,.62,-.44+i*.22,M.oak,.01);
  rbox(bed,.1,.62,1.28,.97,.4,0,M.walnut,.03);
  colliders.box(-3.17,-1.2,1.95,1.25,0,'bed');
  const nightstand=prop(-3.75,-1.98);
  rbox(nightstand,.42,.5,.36,0,.25,0,M.oak,.02);rbox(nightstand,.36,.14,.02,0,.33,.18,M.walnut,.01);cyl(nightstand,.012,.012,.03,0,.33,.2,M.brass,8);
  cyl(nightstand,.06,.07,.08,0,.54,0,M.ceramic);const candle=cyl(nightstand,.022,.022,.1,0,.63,0,M.cream,10);
  const flame=new T.Mesh(new T.SphereGeometry(.014,8,6),new T.MeshBasicMaterial({color:0xffc070}));flame.scale.y=1.8;flame.position.set(0,.71,0);nightstand.add(flame);
  colliders.box(-3.75,-1.98,.45,.4,0,'stand');
  // Sofa along the west wall, front part, with cushions and throw pillows.
  const sofa=piece('sofa','소파','🛋️',{x:-2.95,z:.55,face:-Math.PI/2},-3.66,.55);
  rbox(sofa,.82,.32,1.62,0,.25,0,M.sofa,.06);
  for(const z of [-.38,.38])rbox(sofa,.66,.14,.76,.06,.47,z,M.sofa,.06);
  for(const z of [-.38,.38])rbox(sofa,.2,.5,.74,-.29,.72,z,M.sofa,.08).rotation.z=-.12;
  rbox(sofa,.24,.66,1.62,-.33,.55,0,M.sofa,.07);
  for(const s of [-1,1])rbox(sofa,.82,.5,.18,0,.4,s*.84,M.sofa,.08);
  for(const [x,z] of [[-.32,-.72],[.32,-.72],[-.32,.72],[.32,.72]])cyl(sofa,.03,.025,.1,x,.05,z,M.walnut,8);
  rbox(sofa,.12,.3,.3,-.1,.68,-.48,M.cushion,.06).rotation.z=-.3;
  colliders.box(-3.66,.55,.86,1.7,0,'sofa');
  // Rug, coffee table with a mug, a book and a bowl of fruit.
  // Rug: a plush checked wool (Poly Haven "Curly Teddy Checkered", CC0; public/textures/rug), bound
  // with a navy edge and fringed.
  {
    const loader=new T.TextureLoader(),base=import.meta.env.BASE_URL+'textures/rug/curly_teddy_checkered_';
    const map=(name,srgb)=>{const t=loader.load(base+name+'_1k.jpg');if(srgb)t.colorSpace=T.SRGBColorSpace;t.wrapS=t.wrapT=T.RepeatWrapping;t.repeat.set(1.1,.78);t.anisotropy=8;return t};
    const woven=new T.MeshStandardMaterial({map:map('diff',true),normalMap:map('nor_gl'),roughnessMap:map('rough'),normalScale:new T.Vector2(1.2,1.2)});
    const edge=new T.MeshStandardMaterial({map:fabricTex('#2c3a4e'),roughness:1});
    const rug=new T.Group();rug.position.set(-2.35,0,.55);scene.add(rug);
    rbox(rug,2.36,.016,1.72,0,.008,0,edge,.006).castShadow=false;
    rbox(rug,2.2,.02,1.56,0,.012,0,woven,.004).castShadow=false;
    const fringe=new T.MeshStandardMaterial({color:0xefe4cc,roughness:1});
    for(const s of [-1,1])for(let i=0;i<26;i++){const f=new T.Mesh(new T.BoxGeometry(.06,.008,.012),fringe);f.position.set(s*1.21,.006,-.8+i*1.6/25);f.rotation.y=(rand()-.5)*.3;f.receiveShadow=true;rug.add(f)}
  }
  const table=prop(-2.35,.55);
  rbox(table,.62,.06,1.0,0,.38,0,M.oak,.02);rbox(table,.56,.03,.94,0,.12,0,M.oak,.01);
  for(const [x,z] of [[-.26,-.44],[.26,-.44],[-.26,.44],[.26,.44]])rbox(table,.05,.38,.05,x,.19,z,M.walnut,.01);
  cyl(table,.04,.035,.09,.08,.46,.22,M.blue,12);rbox(table,.18,.035,.25,-.08,.43,-.18,M.painted,.006);
  const bowl=new T.Mesh(new T.SphereGeometry(.11,16,8,0,Math.PI*2,Math.PI/2,Math.PI/2),M.ceramic);bowl.position.set(.06,.52,-.02);bowl.castShadow=true;table.add(bowl);
  for(let i=0;i<4;i++){const f=new T.Mesh(new T.SphereGeometry(.04,10,8),std({color:pick([0xd8402a,0xe8b53a,0x8cbf4a])}));f.position.set(.06+(rand()-.5)*.1,.47,-.02+(rand()-.5)*.1);f.castShadow=true;table.add(f)}
  colliders.box(-2.35,.55,.66,1.04,0,'table');
  // Stone fireplace: jambs and a lintel round an open, soot-blackened firebrick box, a mantel, a
  // chimney breast to the ceiling, logs on an iron grate, and a fire of shader flames.
  const hearth=piece('fire','벽난로','🔥',{x:-.45,z:-1.05,face:Math.PI},-.45,Z0+.25);
  const fs=new T.Group();hearth.add(fs);
  const firebrick=std({map:canvasTexture(128,128,(g,w,h)=>{
    g.fillStyle='#1c1612';g.fillRect(0,0,w,h);
    for(let r=0;r<8;r++)for(let c=0;c<4;c++){const v=40+rand()*30;g.fillStyle=`rgb(${v+18},${v*.6},${v*.45})`;g.fillRect(c*32+(r%2)*16+1,r*16+1,30,14)}
    const soot=g.createLinearGradient(0,0,0,h);soot.addColorStop(0,'rgba(8,6,5,.95)');soot.addColorStop(.7,'rgba(8,6,5,.45)');soot.addColorStop(1,'rgba(8,6,5,.2)');g.fillStyle=soot;g.fillRect(0,0,w,h);
  }),roughness:1});
  for(const s of [-1,1])box(fs,.34,1.2,.42,s*.505,.6,0,M.stone);
  box(fs,.67,.42,.42,0,.99,0,M.stone);
  box(fs,.68,.78,.04,0,.39,-.19,firebrick);
  for(const s of [-1,1]){const side=box(fs,.04,.78,.38,s*.315,.39,0,firebrick);side.rotation.y=s*.12}
  box(fs,.66,.03,.4,0,.015,0,M.soot);
  box(fs,.95,H-1.2,.34,0,1.2+(H-1.2)/2,-.04,M.stone);
  rbox(fs,1.55,.09,.5,0,1.24,.04,M.walnut,.02);rbox(fs,1.5,.06,.62,0,.03,.14,M.stone,.02);
  for(const [x,c] of [[-.5,0xc9a35a],[.48,0x5e8fa8]])cyl(fs,.05,.06,.18,x,1.37,.04,std({color:c,metalness:.5,roughness:.4}),12);
  rbox(fs,.36,.26,.03,0,1.42,-.18,M.walnut,.01);rbox(fs,.3,.2,.01,0,1.42,-.16,std({color:0xc98a5a}),.005);
  // Iron grate and logs; the log ends glow while the fire burns.
  for(let i=0;i<5;i++)cyl(fs,.008,.008,.32,-.2+i*.1,.08,-.02,M.iron,6).rotation.x=Math.PI/2;
  cyl(fs,.01,.01,.46,0,.08,-.15,M.iron,6).rotation.z=Math.PI/2;cyl(fs,.01,.01,.46,0,.08,.12,M.iron,6).rotation.z=Math.PI/2;
  const ember=new T.MeshStandardMaterial({color:0x3a2416,roughness:.9,emissive:0xff4a10,emissiveIntensity:0});ember.userData.glow=true;
  for(const [r,y,z] of [[.35,.13,-.06],[-.3,.13,.02],[0,.21,-.03]]){const log=cyl(fs,.048,.052,.46,0,y,z,ember,12);log.rotation.set(0,r,Math.PI/2)}
  // Flames: camera-facing sheets drawn by a noise shader, additive.
  const flameVertex='varying vec2 vUv;void main(){vUv=uv;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}';
  const flameFragment=`varying vec2 vUv;uniform float time,seed,power;
    float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
    float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
    float fbm(vec2 p){float v=0.,a=.5;for(int i=0;i<5;i++){v+=a*noise(p);p=p*2.1+vec2(3.1,1.7);a*=.5;}return v;}
    void main(){
      vec2 uv=vUv;float y=uv.y,x=(uv.x-.5)*2.;
      float n=fbm(vec2(uv.x*2.6+seed,y*2.2-time*2.3)),n2=fbm(vec2(uv.x*5.5-seed,y*4.8-time*3.6));
      float width=mix(.9,.04,pow(y,.85));
      float d=abs(x+(n-.5)*.75*y)/width;
      float shape=(1.-smoothstep(.45,1.,d))*(1.-smoothstep(.5,.95,y+(n2-.5)*.45))*smoothstep(.0,.1,y);
      float heat=shape*(1.15-y)*(.75+.5*n2);
      vec3 col=mix(vec3(.85,.16,.02),vec3(1.,.5,.06),smoothstep(.12,.42,heat));
      col=mix(col,vec3(1.,.9,.55),smoothstep(.55,.95,heat));
      float a=smoothstep(.02,.3,shape)*power;
      gl_FragColor=vec4(col*a*1.7,a);
    }`;
  const flames=[];
  for(const [x,w,h,s] of [[0,.42,.62,1.3],[-.12,.3,.46,4.7],[.13,.28,.42,8.1],[.02,.24,.34,12.5]]){
    const f=new T.Mesh(new T.PlaneGeometry(w,h),new T.ShaderMaterial({vertexShader:flameVertex,fragmentShader:flameFragment,
      uniforms:{time:{value:0},seed:{value:s},power:{value:0}},transparent:true,depthWrite:false,blending:T.AdditiveBlending}));
    f.position.set(x,.15+h/2,-.02);f.renderOrder=3;fs.add(f);flames.push(f);
  }
  // A soft glow in the firebox and sparks rising up the flue.
  const glowTex=canvasTexture(64,64,(g,w,h)=>{const r=g.createRadialGradient(32,32,0,32,32,32);r.addColorStop(0,'rgba(255,170,80,1)');r.addColorStop(.4,'rgba(255,110,30,.35)');r.addColorStop(1,'rgba(255,80,20,0)');g.fillStyle=r;g.fillRect(0,0,w,h)});
  const glow=new T.Mesh(new T.PlaneGeometry(1.1,.9),new T.MeshBasicMaterial({map:glowTex,transparent:true,depthWrite:false,blending:T.AdditiveBlending,opacity:0}));
  glow.position.set(0,.32,.0);glow.renderOrder=2;fs.add(glow);
  const SPARKS=28,sparkPos=new Float32Array(SPARKS*3),sparkState=Array.from({length:SPARKS},()=>({t:Math.random(),x:0,z:0,v:.5+Math.random()*.6}));
  const sparks=new T.Points(new T.BufferGeometry().setAttribute('position',new T.BufferAttribute(sparkPos,3)),
    new T.PointsMaterial({color:0xffb050,size:3,sizeAttenuation:false,transparent:true,blending:T.AdditiveBlending,depthWrite:false}));
  sparks.frustumCulled=false;fs.add(sparks);
  const fireLight=new T.PointLight(0xff8a3a,0,7,1.4);fireLight.position.set(0,.45,.45);hearth.add(fireLight);
  colliders.box(-.45,Z0+.25,1.5,.66,0,'fire');

  // Bookshelf on the back wall: books of every height, some leaning, a stack lying flat.
  const shelf=piece('books','책장','📚',{x:-1.75,z:-1.25,face:Math.PI},-1.75,Z0+.19);
  // An open case: back board, sides, top and plinth.
  rbox(shelf,.86,1.9,.03,0,.95,-.155,M.oak,.005);
  for(const s of [-1,1])rbox(shelf,.04,1.95,.34,s*.43,.975,0,M.walnut,.012);
  rbox(shelf,.94,.05,.36,0,1.95,0,M.walnut,.015);rbox(shelf,.9,.1,.34,0,.05,0,M.walnut,.012);
  const bookColors=[0x7a3b32,0x3f6c8a,0xc49a3a,0x4e7a4a,0x8b5a8c,0xd4c3a0,0x2f4a60,0x9a4a2a];
  for(let r=0;r<4;r++){
    rbox(shelf,.82,.03,.3,0,.14+r*.46,.01,M.oak,.008);
    let x=-.38;
    while(x<.3){
      if(rand()<.12){for(let k=0;k<3;k++)rbox(shelf,.24,.04,.18,x+.13,.175+r*.46+k*.042,.02,std({color:pick(bookColors),roughness:.8}),.008);x+=.28;continue}
      const w=.035+rand()*.045,h=.24+rand()*.13,lean=rand()<.15?.18:0;
      const b=rbox(shelf,w,h,.21,x+w/2,.157+r*.46+h/2,.03,std({color:pick(bookColors),roughness:.8}),.006);b.rotation.z=lean;
      x+=w+.006+lean*.12;
    }
  }
  colliders.box(-1.75,Z0+.19,.94,.42,0,'shelf');
  // A potted fern by the door, pictures on the west wall.
  const fern=prop(-3.75,1.6);cyl(fern,.17,.13,.32,0,.16,0,M.terracotta,18);
  for(let i=0;i<14;i++){const a=i*2.4,leaf=shadow(new T.Mesh(new T.SphereGeometry(.2,10,6),M.leaf));leaf.scale.set(.25,.08,1);leaf.position.set(Math.sin(a)*.12,.42+rand()*.18,Math.cos(a)*.12);leaf.rotation.set(-.6,a,0);fern.add(leaf)}
  colliders.circle(-3.75,1.6,.22,'fern');
  for(const [z,y,w,h,c] of [[.3,1.7,.55,.42,0x5e8a6a],[.95,1.62,.36,.46,0xc98a5a]]){
    const pic=new T.Group();pic.position.set(X0+.02,y,z);pic.rotation.y=Math.PI/2;scene.add(pic);
    rbox(pic,w+.08,h+.08,.035,0,0,0,M.walnut,.01);box(pic,w,h,.01,0,0,.02,std({color:c,roughness:1}));
  }
  // Door out, in the west wall, clear of the sofa.
  const door=piece('door','문','🚪',{x:-3.45,z:2.35,face:-Math.PI/2},X0+.03,2.35,Math.PI/2);
  rbox(door,1.04,2.12,.08,0,1.06,0,M.walnut,.01);
  rbox(door,.88,2.0,.05,0,1.0,.04,M.oak,.01);
  for(const [x,y,w,h] of [[-.2,1.45,.34,.8],[.2,1.45,.34,.8],[-.2,.5,.34,.65],[.2,.5,.34,.65]])rbox(door,w,h,.03,x,y,.075,M.walnut,.012);
  const knob=new T.Mesh(new T.SphereGeometry(.04,14,10),M.brass);knob.position.set(.34,1.0,.1);knob.castShadow=true;door.add(knob);
  // ---- Kitchen ----
  // Counter run along the back wall: cabinets, a butcher-block top, a sink under the window,
  // a cast-iron range with a kettle and a stovepipe, tiles, open shelves, hanging pans.
  const counterL=XK+.15,counterR=W/2-.05,stoveX=3.35,sinkX=1.95;
  for(let x=counterL;x<counterR-.01;x+=.6){
    const w=Math.min(.6,counterR-x),cx=x+w/2;
    if(Math.abs(cx-stoveX)<.4)continue;
    rbox(scene,w-.01,.84,.58,cx,.42,Z0+.31,M.painted,.015);
    rbox(scene,w-.08,.66,.03,cx,.43,Z0+.6,M.painted,.02);
    cyl(scene,.012,.012,.05,cx+w/2-.12,.68,Z0+.62,M.brass,8).rotation.x=Math.PI/2;
  }
  for(const [a,b] of [[counterL,stoveX-.4],[stoveX+.4,counterR]])box(scene,b-a,.06,.64,(a+b)/2,.87,Z0+.32,M.pine);
  const backsplash=new T.Mesh(new T.PlaneGeometry(counterR-counterL,.6),M.tile);backsplash.position.set((counterL+counterR)/2,1.2,Z0+.012);backsplash.receiveShadow=true;scene.add(backsplash);
  const sink=piece('sink','개수대','🚰',{x:sinkX,z:-1.25,face:Math.PI},sinkX,Z0+.32);
  box(sink,.62,.05,.46,0,.905,0,M.ceramic);box(sink,.52,.18,.36,0,.84,0,std({color:0xd8d4cc,roughness:.2,metalness:.3}));
  const tap=new T.Group();tap.position.set(0,.93,-.22);sink.add(tap);cyl(tap,.02,.025,.25,0,.12,0,M.brass,10);
  const spout=cyl(tap,.015,.015,.18,0,.24,.08,M.brass,10);spout.rotation.x=Math.PI/2;
  for(const s of [-1,1]){const h=cyl(tap,.02,.02,.05,s*.07,.06,0,M.brass,8);h.rotation.z=Math.PI/2}
  const drips=[];
  const stove=piece('stove','화덕','🍲',{x:stoveX,z:-1.2,face:Math.PI},stoveX,Z0+.33);
  rbox(stove,.78,.86,.62,0,.43,0,M.iron,.025);rbox(stove,.56,.36,.03,0,.42,.315,M.iron,.02);
  rbox(stove,.4,.03,.02,0,.62,.33,M.brass,.008);
  for(const x of [-.18,.18])cyl(stove,.12,.12,.012,x,.87,.04,std({color:0x1a1918,metalness:.5,roughness:.6}),20);
  const pot=new T.Group();pot.position.set(-.18,.88,.04);stove.add(pot);
  cyl(pot,.12,.11,.17,0,.085,0,M.copper,20);cyl(pot,.125,.125,.015,0,.18,0,M.copper,20);cyl(pot,.02,.02,.04,0,.2,0,M.brass,8);
  const kettle=new T.Group();kettle.position.set(.18,.88,.04);stove.add(kettle);
  const kb=shadow(new T.Mesh(new T.SphereGeometry(.1,16,10),M.blue));kb.scale.y=.85;kb.position.y=.08;kettle.add(kb);
  const ks=cyl(kettle,.015,.025,.12,.1,.12,0,M.blue,8);ks.rotation.z=-.9;
  cyl(stove,.06,.06,H-.9,0,.86+(H-.9)/2,-.2,M.iron,12);
  const steam=[];
  for(let i=0;i<8;i++){const s=new T.Mesh(new T.SphereGeometry(.05,8,6),new T.MeshBasicMaterial({color:0xffffff,transparent:true,opacity:0,depthWrite:false}));s.position.set(-.18,1.1,.04);stove.add(s);steam.push({mesh:s,t:i/8})}
  colliders.box(stoveX,Z0+.33,.82,.66,0,'stove');colliders.box((counterL+counterR)/2,Z0+.32,counterR-counterL,.66,0,'counter');
  // Open shelves with plates and jars, a rail of copper pans.
  for(const [x0,x1,y] of [[counterL+.05,1.45,1.62],[2.6,counterR-.95,1.62]]){
    rbox(scene,x1-x0,.04,.26,(x0+x1)/2,y,Z0+.14,M.pine,.01);
    for(let x=x0+.1;x<x1-.08;x+=.15){
      if(rand()<.5){const j=cyl(scene,.045,.045,.14,x,y+.09,Z0+.14,new T.MeshPhysicalMaterial({color:pick([0xd8b46a,0xa04a3a,0x6a8a4a]),roughness:.2,transmission:.2,thickness:.1}),14);
        cyl(scene,.048,.048,.025,x,y+.17,Z0+.14,M.brass,14);j.castShadow=true}
      else{const p=cyl(scene,.07,.07,.012,x,y+.08,Z0+.06,M.ceramic,20);p.rotation.x=Math.PI/2-.25}
    }
  }
  cyl(scene,.012,.012,.9,stoveX+.0,1.85,Z0+.08,M.brass,8).rotation.z=Math.PI/2;
  for(const [dx,r] of [[-.3,.1],[0,.13],[.3,.09]]){
    const pan=new T.Group();pan.position.set(stoveX+dx,1.83,Z0+.1);scene.add(pan);
    cyl(pan,.006,.006,.12,0,-.06,0,M.brass,6);const p=cyl(pan,r,r*.9,.04,0,-.15-r,0,M.copper,20);p.rotation.x=Math.PI/2;
  }
  // Kitchen table, two chairs, a vase and a bread basket.
  const dine=prop(2.35,1.15);
  rbox(dine,1.05,.06,.8,0,.74,0,M.oak,.02);
  for(const [x,z] of [[-.45,-.32],[.45,-.32],[-.45,.32],[.45,.32]])rbox(dine,.07,.72,.07,x,.36,z,M.walnut,.015);
  for(const s of [-1,1]){const ch=new T.Group();ch.position.set(s*.75,0,0);ch.rotation.y=-s*Math.PI/2;dine.add(ch);
    rbox(ch,.44,.05,.44,0,.45,0,M.oak,.015);for(const [x,z] of [[-.18,-.18],[.18,-.18],[-.18,.18],[.18,.18]])rbox(ch,.045,.45,.045,x,.225,z,M.walnut,.01);
    for(let i=0;i<4;i++)rbox(ch,.04,.5,.03,-.15+i*.1,.72,-.2,M.walnut,.008);rbox(ch,.44,.06,.05,0,.98,-.2,M.oak,.015)}
  const vase=cyl(dine,.05,.07,.2,-.2,.87,0,M.blue,14);vase.castShadow=true;
  for(let i=0;i<6;i++){const fl=new T.Mesh(new T.SphereGeometry(.035,10,8),std({color:pick([0xe85a78,0xf2c430,0xf4f1e4])}));fl.position.set(-.2+(rand()-.5)*.14,1.0+rand()*.08,(rand()-.5)*.14);fl.castShadow=true;dine.add(fl)}
  const basket=cyl(dine,.14,.11,.1,.22,.82,0,std({color:0xb98a4a,roughness:1}),16);basket.castShadow=true;
  for(let i=0;i<3;i++){const loaf=new T.Mesh(new T.SphereGeometry(.07,12,8),std({color:0xc8843f,roughness:.8}));loaf.scale.set(1.3,.7,.8);loaf.position.set(.22+(i-1)*.06,.9,(i-1)*.04);loaf.castShadow=true;dine.add(loaf)}
  colliders.box(2.35,1.15,2.1,.9,0,'dine');

  // ---------- Pendant lamps: enamel shades on cords from the joists, spotlights that sway ----------
  const lamps=[];
  function pendant(key,name,x,z,spotZ){
    // Hung from a ceiling rose at ceiling height (the ceiling itself is cut away).
    const rose=cyl(scene,.07,.09,.04,x,H-.02,z,M.brass,16);rose.castShadow=false;
    const pivot=new T.Group();pivot.position.set(x,H-.04,z);scene.add(pivot);
    const drop=.42;cyl(pivot,.006,.006,drop,0,-drop/2,0,M.iron,6);
    const shade=new T.Group();shade.position.y=-drop;pivot.add(shade);
    const pts=[];for(let i=0;i<=10;i++){const u=i/10;pts.push(new T.Vector2(.04+.24*Math.pow(u,1.6),-.03-u*.2))}
    const enamel=new T.MeshStandardMaterial({color:0x3f6a5a,roughness:.35,metalness:.2,side:T.DoubleSide});
    const sh=shadow(new T.Mesh(new T.LatheGeometry(pts,28),enamel));sh.castShadow=false;shade.add(sh);
    cyl(shade,.045,.045,.06,0,-.01,0,M.brass,12);
    const bulb=new T.Mesh(new T.SphereGeometry(.05,16,12),new T.MeshStandardMaterial({color:0xfff4e0,emissive:0xffcf8a,emissiveIntensity:0}));bulb.position.y=-.14;shade.add(bulb);
    const spot=new T.SpotLight(0xffd6a0,0,12,1.18,.6,1.25);spot.position.y=-.1;spot.castShadow=true;spot.shadow.mapSize.set(1024,1024);spot.shadow.bias=-.0006;spot.shadow.normalBias=.02;spot.shadow.camera.near=.1;
    spot.target.position.set(0,-3,0);shade.add(spot,spot.target);
    // A pull-cord to switch it; the lamp group is what the player taps.
    const g=piece(key,name,'💡',{x,z:spotZ,face:Math.atan2(0,z-spotZ)},x,z);
    const hit=new T.Mesh(new T.CylinderGeometry(.3,.3,.4,8),new T.MeshBasicMaterial({visible:false}));hit.position.set(0,H-1.05,0);g.add(hit);
    lamps.push({pivot,spot,bulb,on:null,phase:x*1.7});
    return g;
  }
  pendant('lamp','거실 전등',-2.35,.55,1.38);
  pendant('lamp2','부엌 전등',2.35,1.15,1.95);
  for(const g of usable)g.traverse(o=>{if(o.isMesh&&o.material.isMeshStandardMaterial&&!o.material.userData.glow)o.material=o.material.clone()});

  // ---------- Base light: daylight from the open side, a soft sky fill ----------
  const hemi=new T.HemisphereLight(0xe6eef6,0x6a4c36,.6);scene.add(hemi);
  const ambient=new T.AmbientLight(0xffe2c0,.12);scene.add(ambient);
  const day=new T.DirectionalLight(0xfff1dc,1.4);day.position.set(5,8,6);day.target.position.set(-.4,0,-.5);
  day.castShadow=true;day.shadow.mapSize.set(2048,2048);Object.assign(day.shadow.camera,{left:-6,right:6,top:5,bottom:-5,near:.5,far:25});
  day.shadow.bias=-.0004;day.shadow.normalBias=.025;day.shadow.radius=3;scene.add(day,day.target);

  // ---------- Walking inside: the grid path finder over the furnished floor ----------
  const inside=(x,z)=>x>X0+.22&&x<W/2-.15&&z>Z0+.22&&z<Z1-.12;
  const paths=createGridPaths({x0:X0+.1,x1:W/2-.1,z0:Z0+.1,z1:Z1-.1,step:.15,open:(x,z)=>inside(x,z)&&!colliders.blocked(x,z,.22)});
  const roomPlace={scene,
    route:(a,b)=>{const r=paths.route(a,b);return r.length?r:[{x:b.x,z:b.z}]},
    resolve(b){colliders.resolve(b);b.x=Math.min(W/2-.18,Math.max(X0+.24,b.x));b.z=Math.min(Z1-.15,Math.max(Z0+.24,b.z))},
    stand:()=>0,walkable:(x,z)=>paths.free(x,z),
    closest:p=>paths.closest(p)
  };

  // ---------- Screen-side UI: fade, hover label, status tag, exit button ----------
  const fade=document.createElement('div');fade.className='room-fade';document.body.append(fade);
  const label=document.createElement('div');label.className='room-label';label.hidden=true;document.body.append(label);
  const status=document.createElement('div');status.className='plot-tag room-status';status.dataset.state='pending';status.hidden=true;
  status.innerHTML='<span class="plot-icon"></span><span class="plot-text"></span>';document.body.append(status);
  const exitHint=document.createElement('button');exitHint.type='button';exitHint.className='room-exit';exitHint.textContent='🚪 밖으로 나가기';exitHint.hidden=true;document.body.append(exitHint);
  const fadeTo=(on,text='')=>new Promise(r=>{fade.textContent=text;fade.classList.toggle('on',on);setTimeout(r,on?480:20)});

  let active=false,busy=null,fireLeft=0,lastRead=-Infinity,lastCook=-Infinity,cooking=0,washing=0,hover=null;
  async function enter(){
    if(active)return;
    await fadeTo(true);
    active=true;controls.enabled=false;hooks.indoor(true);
    character.enterRoom(roomPlace,{x:-3.45,z:2.35,heading:Math.PI/2});
    character.walkTo(-2.7,2.1);
    exitHint.hidden=false;
    await fadeTo(false);
  }
  async function leave(){
    if(!active)return;
    await fadeTo(true);
    active=false;busy=null;status.hidden=true;label.hidden=true;exitHint.hidden=true;highlight(null);
    controls.enabled=true;hooks.indoor(false);character.leaveRoom();
    await fadeTo(false);status.hidden=true;
  }
  exitHint.addEventListener('click',()=>use(door));
  function job(piece,steps,{start,done,text}){
    busy={piece,text:'이동 중'};
    character.work({spots:[piece.userData.spot],steps,
      onStart(){busy={piece,text};start?.()},
      onDone(){busy=null;done?.()},
      onCancel(){busy=null;character.setPose(null);cooking=washing=0},
      onFail(){busy=null;hooks.toast('🚧 그곳으로 갈 수 없어요')}});
  }
  const now=()=>performance.now()/1000;
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
          character.setPose({x:-2.55,y:.6,z:-1.2,heading:Math.PI/2,tilt:-Math.PI/2,sleep:true});
          fadeTo(true,'💤').then(()=>{if(night)hooks.sleep();setTimeout(()=>fadeTo(false),1700)});
        },
        done(){character.setPose(null);hooks.toast(night?'☀️ 푹 자고 일어났어요. 좋은 아침!':'😌 개운하게 낮잠을 잤어요');hooks.earn(0,1,'💤')}});
      return;
    }
    if(key==='sofa'){
      job(piece,[{clip:'KneelDown',time:5.5,fade:.25},{clip:'KneelDownToUp',fade:.15}],{text:'쉬는 중',
        start(){character.setPose({x:-3.6,y:.36,z:.55,heading:Math.PI/2})},
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
        if(now()-lastRead<READ_COOLDOWN){hooks.toast('📖 방금 읽은 책이에요. 조금 뒤에 다시 읽어요');return}
        lastRead=now();hooks.earn(0,3,'📖 독서');
      }});
      return;
    }
    if(key==='stove'){
      job(piece,[{clip:'Gathering',time:3.6}],{text:'요리하는 중',start(){cooking=1},done(){
        cooking=0;
        if(now()-lastCook<COOK_COOLDOWN){hooks.toast('🍲 아직 배가 불러요. 조금 뒤에 또 해요');return}
        lastCook=now();hooks.earn(0,4,'🍲 수프 완성');
      }});
      return;
    }
    if(key==='sink'){job(piece,[{clip:'Gathering',time:2.6}],{text:'설거지하는 중',start(){washing=1},done(){washing=0;hooks.earn(0,1,'🍽️ 설거지')}});return}
    if(key==='lamp'||key==='lamp2'){
      const lamp=lamps[key==='lamp'?0:1];
      job(piece,[{clip:'Gathering',time:.9}],{text:'전등 줄 당기는 중',done(){lamp.on=!(lamp.on??lamp.lit)}});
    }
  }

  // ---------- Input ----------
  const raycaster=new T.Raycaster(),pointer=new T.Vector2(),hit=new T.Vector3(),floorPlane=new T.Plane(new T.Vector3(0,1,0),0);
  function aim(x,y){const r=canvas.getBoundingClientRect();pointer.set((x-r.left)/r.width*2-1,-(y-r.top)/r.height*2+1);raycaster.setFromCamera(pointer,camera)}
  function pickPiece(){
    const hits=raycaster.intersectObjects(usable,true);if(!hits.length)return null;
    let o=hits[0].object;while(o&&!o.userData.key)o=o.parent;return o;
  }
  function highlight(piece){
    if(hover===piece)return;
    for(const g of [hover,piece])g?.traverse(o=>{if(o.isMesh&&o.material.emissive&&!o.material.userData.glow)o.material.emissive.setHex(g===piece?0x2a2014:0)});
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
    const aspect=w/h,span=Math.max(7.8,13.4/aspect);
    camera.left=-span*aspect/2;camera.right=span*aspect/2;camera.top=span/2;camera.bottom=-span/2;camera.updateProjectionMatrix();
  }
  resize(innerWidth,innerHeight);
  const anchor=new T.Vector3(),night=new T.Color(0x0e1424),base=new T.Color(0x1c1815),sunDir=new T.Vector3();
  return {
    get active(){return active},
    enter,leave,resize,
    // env: {night, cover (0-2), haze, rain, snow, sun (Color), sky: {top,bottom,glow,glowAmount,stars,sunY,hour}}
    render(dt,env){
      const t=performance.now()/1000;
      // Daylight from the open side, dimmed by cloud and gone at night.
      const daylight=(1-env.night)*(env.cover<1?1-.35*env.cover:.65-.25*(env.cover-1))*(1-.4*env.haze);
      day.intensity=2.5*daylight;day.color.copy(env.sun).lerp(base.setHex(0xe8eef4),.5);
      hemi.intensity=.22+.75*daylight;ambient.intensity=.1+.05*env.night;
      scene.background.setHex(0x1c1815).lerp(night,env.night*.6);
      // Pendant lamps: on by themselves once it gets dark (unless switched), swaying a touch.
      lamps.forEach((l,i)=>{
        l.lit=env.night>.3||daylight<.25;const on=l.on??l.lit;
        l.spot.intensity=on?34:0;l.bulb.material.emissiveIntensity=on?2.4:0;
        l.pivot.rotation.z=.028*Math.sin(t*.83+l.phase)+.01*Math.sin(t*2.1+l.phase*2);
        l.pivot.rotation.x=.022*Math.sin(t*.67+l.phase*1.3);
      });
      flame.visible=env.night>.3;
      // Fire, steam from the pot, water from the tap.
      fireLeft=Math.max(0,fireLeft-dt);const burning=fireLeft>0;
      // The fire: flames flicker in strength, the logs glow, sparks drift up, the light dances.
      const flicker=.82+.18*Math.sin(t*11)*Math.sin(t*6.3+1.7);
      flames.forEach((f,i)=>{f.visible=burning;f.quaternion.copy(camera.quaternion);const u=f.material.uniforms;u.time.value=t;u.power.value=burning?(.85+.15*Math.sin(t*(5+i*1.7)+i))*flicker:0});
      glow.visible=burning;glow.material.opacity=.55*flicker;glow.quaternion.copy(camera.quaternion);
      ember.emissiveIntensity=burning?1.6+.6*Math.sin(t*3.1):0;
      sparks.visible=burning;
      if(burning){sparkState.forEach((s,i)=>{s.t+=dt*s.v*.5;if(s.t>1){s.t=0;s.x=(Math.random()-.5)*.35;s.z=(Math.random()-.5)*.15}
        sparkPos[i*3]=s.x+Math.sin(t*3+i)*.04*s.t;sparkPos[i*3+1]=.18+s.t*.9;sparkPos[i*3+2]=s.z-.05});
        sparks.geometry.attributes.position.needsUpdate=true;sparks.material.opacity=.9*flicker}
      fireLight.intensity=burning?5.5*flicker:0;
      for(const s of steam){s.t=(s.t+dt*.5)%1;s.mesh.position.set(-.18+Math.sin(s.t*9+s.mesh.id)*.04,1.08+s.t*.6,.04);s.mesh.scale.setScalar(.6+s.t*1.6);s.mesh.material.opacity=cooking?.35*(1-s.t)*Math.min(1,s.t*5):0}
      // The sky beyond the windows.
      const sky=env.sky,elev=sky.sunY;
      // Sun (or moon) direction in the panes' frame: it climbs with its elevation and crosses the
      // panes from left to right through the day (the moon through the night).
      const across=(((sky.hour-6+24)%24)%12)/12;
      sunDir.set((across-.5)*1.6,Math.max(.08,Math.abs(elev)*1.3),-1);
      for(const m of skies){
        const u=m.uniforms;u.top.value.copy(sky.top);u.bottom.value.copy(sky.bottom);u.glow.value.copy(sky.glow);u.sunDir.value.copy(sunDir);
        u.sunAmt.value=elev>0?(1-Math.min(1,env.cover*.6)):0;u.moonAmt.value=elev<0?env.night*(1-Math.min(1,env.cover*.7)):0;
        u.stars.value=sky.stars;u.cover.value=env.cover;u.haze.value=env.haze;u.time.value=t;u.night.value=env.night;
        u.snow.value=env.snow;u.rain.value=env.rain;u.whiteGround.value=env.snowDepth??0;u.day.value=Math.max(.06,daylight+.15*(1-env.night));
      }
      for(const w of wets){w.material.opacity=env.rain*.8;w.material.map.offset.y+=dt*.35}
      if(busy&&active){
        busy.piece.getWorldPosition(anchor);anchor.y+=({door:2.3,lamp:H-.2,lamp2:H-.2})[busy.piece.userData.key]??1.5;anchor.project(camera);
        const r=canvas.getBoundingClientRect();
        status.hidden=false;status.style.left=Math.round(r.left+(anchor.x+1)/2*r.width)+'px';status.style.top=Math.round(r.top+(1-anchor.y)/2*r.height)+'px';
        status.children[0].textContent=busy.piece.userData.icon;status.children[1].textContent=busy.text;
      }else status.hidden=true;
      renderer.shadowMap.needsUpdate=true;
      renderer.render(scene,camera);
    }
  };
}
