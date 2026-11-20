import * as T from 'three';
import {builder} from './modules.js';
import {createFarmUI} from './farm-ui.js';

// Farming game on the vegetable beds: every bed starts empty; tapping it opens the seed picker,
// the crop grows in real time (saved with timestamps, so it keeps growing while the page is
// closed), and a ripe bed is tapped again to harvest it for coins and experience.
const ease=t=>1-(1-t)**3;
const grid=(cols,rows,dx,dz,y,size=[1,1])=>(rand)=>{
  const list=[];
  for(let j=0;j<rows;j++)for(let i=0;i<cols;i++){
    const s=size[0]+rand()*(size[1]-size[0]);
    list.push({x:(i-(cols-1)/2)*dx+(rand()-.5)*.04,z:(j-(rows-1)/2)*dz+(rand()-.5)*.04,y,s,turn:rand()*6.28});
  }
  return list;
};
// seconds: growth time; cost: seed price; sell: harvest coins; level: player level that unlocks it.
// Each part scales up over its growth window [from,to]; young/ripe tint the instances as it ripens.
export const CROPS=[
  {id:'carrot',name:'당근',icon:'🥕',seconds:30,cost:5,sell:12,xp:2,level:1,height:.3,
    layout:grid(3,5,.36,.29,.18,[.85,1.12]),parts:[{kind:'carrot',ripe:'#7ea946',young:'#9cc964'}]},
  {id:'wheat',name:'밀',icon:'🌾',seconds:60,cost:10,sell:24,xp:4,level:1,height:.5,
    layout:grid(4,6,.27,.245,.17,[.85,1.1]),parts:[{kind:'wheatStalks',ripe:'#f2c45c',young:'#8fbf58'}]},
  {id:'cabbage',name:'양배추',icon:'🥬',seconds:90,cost:15,sell:38,xp:6,level:2,height:.3,
    layout:grid(3,4,.36,.37,.19,[1,1.2]),parts:[{kind:'cabbage',ripe:'#a3c063',young:'#b9d77c'}]},
  {id:'tomato',name:'토마토',icon:'🍅',seconds:120,cost:20,sell:55,xp:8,level:3,height:.6,
    layout:grid(2,3,.46,.46,.17,[1.05,1.2]),parts:[{kind:'tomatoBush',ripe:'#ffffff',young:'#d8f0b8'},
      {kind:'tomatoFruit',ripe:'#e2402c',young:'#93c25a',from:.5}]},
  {id:'sunflower',name:'해바라기',icon:'🌻',seconds:180,cost:30,sell:85,xp:12,level:4,height:.95,
    layout:grid(2,3,.46,.46,.17,[.72,.84]),parts:[{kind:'sunflowerStem',ripe:'#6f9142',young:'#86b05a'},
      {kind:'sunflowerBloom',ripe:'#ffffff',young:'#b6d07a',from:.6}]},
  {id:'pumpkin',name:'호박',icon:'🎃',seconds:300,cost:45,sell:140,xp:18,level:5,height:.4,
    layout:grid(2,2,.5,.74,.17,[1.25,1.4]),parts:[{kind:'pumpkinVine',ripe:'#ffffff',young:'#e6f5c8',to:.7},
      {kind:'pumpkinFruit',ripe:'#f08a24',young:'#9cc25a',from:.4,offset:[.07,.06]}]}
];
const byId=new Map(CROPS.map(c=>[c.id,c]));
// Total experience needed to reach each level (index = level - 1).
export const LEVELS=[0,10,30,60,100,160,240,340,460,600];
export function levelOf(xp){let level=1;while(level<LEVELS.length&&xp>=LEVELS[level])level++;return level}
const KEY='forest-farm.farm.v1',START={coins:40,xp:0};

function load(count){
  const query=new URLSearchParams(location.search).get('farm');
  try{
    if(query==='reset')localStorage.removeItem(KEY);
    const saved=JSON.parse(localStorage.getItem(KEY)||'null');
    if(saved&&Number.isFinite(saved.coins)&&Number.isFinite(saved.xp)&&Array.isArray(saved.plots))
      return {coins:saved.coins,xp:saved.xp,plots:Array.from({length:count},(_,i)=>{
        const p=saved.plots[i];return p&&byId.has(p.crop)&&Number.isFinite(p.planted)?{crop:p.crop,planted:p.planted}:null;
      })};
  }catch{}
  return {...START,plots:Array(count).fill(null)};
}

export function createFarm(scene,world,assets,camera,canvas){
  const state=load(world.beds.length);
  const save=()=>{try{localStorage.setItem(KEY,JSON.stringify(state))}catch{}};
  const matrix=new T.Matrix4(),scale=new T.Matrix4(),lift=new T.Matrix4(),tint=new T.Color(),ripe=new T.Color();
  // Every bed gets one hidden instanced set per crop, built with the shared builder so the
  // plants sway in the wind and take the scene's surfaces; only the planted set is shown.
  const plots=world.beds.map((bed,index)=>{
    const sets=new Map();
    for(const crop of CROPS){
      const group=new T.Group();group.name='farm-'+crop.id+'-'+index;group.visible=false;
      const b=builder(group,7001+index*131+crop.id.length*17,assets);
      const plants=crop.layout(b.rand);
      b.place(bed.x,bed.y,bed.z,1,0,()=>{
        for(const p of plants)for(const part of crop.parts){
          const [ox,oz]=part.offset??[0,0],c=Math.cos(p.turn),s=Math.sin(p.turn);
          b.part(part.kind,p.x+ox*c+oz*s,p.y,p.z-ox*s+oz*c,p.s,p.s,p.s,part.ripe,0,p.turn);
        }
      });
      b.finish();
      const meshes=crop.parts.map(part=>{
        const mesh=group.getObjectByName(part.kind);
        // Crops stay through winter: the seasonal bare-plant cut is for the wild plants.
        mesh.geometry.getAttribute('plantMask').array.fill(0);
        const base=Array.from({length:mesh.count},(_,i)=>{const m=new T.Matrix4();mesh.getMatrixAt(i,m);return m});
        return {mesh,part,base};
      });
      scene.add(group);sets.set(crop.id,{group,meshes});
    }
    return {index,bed,sets,shown:null,growth:-1,drawn:-1,harvest:0,harvested:null};
  });
  const progress=(plot,now=Date.now())=>{
    const saved=state.plots[plot.index];if(!saved)return null;
    const crop=byId.get(saved.crop),elapsed=(now-saved.planted)/1000;
    return {crop,growth:Math.min(1,Math.max(0,elapsed/crop.seconds)),left:Math.max(0,crop.seconds-elapsed)};
  };
  function draw(plot,set,growth,out=1,rise=0){
    for(const {mesh,part,base} of set.meshes){
      const from=part.from??0,to=part.to??1,local=Math.min(1,Math.max(0,(growth-from)/(to-from)));
      const size=(from>0?ease(local):.14+.86*ease(local))*out;
      ripe.set(part.ripe);tint.set(part.young).lerp(ripe,T.MathUtils.smoothstep(growth,.35,1));
      lift.makeTranslation(0,rise,0);
      for(let i=0;i<mesh.count;i++){
        scale.makeScale(Math.max(1e-4,size),Math.max(1e-4,size),Math.max(1e-4,size));
        matrix.multiplyMatrices(lift,base[i]).multiply(scale);mesh.setMatrixAt(i,matrix);mesh.setColorAt(i,tint);
      }
      mesh.instanceMatrix.needsUpdate=true;mesh.instanceColor.needsUpdate=true;
    }
  }
  function show(plot,id){
    if(plot.shown===id)return;
    if(plot.shown)plot.sets.get(plot.shown).group.visible=false;
    plot.shown=id;if(id)plot.sets.get(id).group.visible=true;
  }

  const ui=createFarmUI({crops:CROPS,levels:LEVELS,levelOf,
    plant(index,id){
      const crop=byId.get(id);
      if(state.plots[index]||!crop||levelOf(state.xp)<crop.level||state.coins<crop.cost)return false;
      state.coins-=crop.cost;state.plots[index]={crop:id,planted:Date.now()};
      const plot=plots[index];plot.growth=0;plot.harvest=0;show(plot,id);save();
      ui.refresh(state);return true;
    },
    clear(index){state.plots[index]=null;show(plots[index],null);save();ui.refresh(state)}
  });
  ui.refresh(state);
  function harvest(plot){
    const info=progress(plot);if(!info||info.growth<1)return;
    const before=levelOf(state.xp);
    state.coins+=info.crop.sell;state.xp+=info.crop.xp;state.plots[plot.index]=null;save();
    plot.harvest=1;plot.harvested=info.crop.id;
    ui.reward(plot.index,info.crop);ui.refresh(state);
    const after=levelOf(state.xp);
    if(after>before)ui.levelUp(after,CROPS.filter(c=>c.level>before&&c.level<=after));
  }
  function tap(index){
    const plot=plots[index],info=progress(plot);
    if(!info)ui.openPicker(index,state);
    else if(info.growth>=1)harvest(plot);
    else ui.openInfo(index,info);
  }
  ui.onTag=tap;

  // A tap is a short press that barely moves (left drag pans the map, so the two never clash).
  // Listening on window in the capture phase sees touches before the map controls swallow them.
  const raycaster=new T.Raycaster(),pointer=new T.Vector2(),box=new T.Box3(),hit=new T.Vector3();
  function pick(x,y){
    const rect=canvas.getBoundingClientRect();
    pointer.set((x-rect.left)/rect.width*2-1,-(y-rect.top)/rect.height*2+1);
    raycaster.setFromCamera(pointer,camera);
    let best=-1,distance=Infinity;
    for(const plot of plots){
      const {x:bx,y:by,z:bz}=plot.bed,info=progress(plot),top=info?Math.max(.32,info.crop.height*(.3+.7*info.growth)):.32;
      box.min.set(bx-.66,by-.05,bz-.86);box.max.set(bx+.66,by+.2+top,bz+.86);
      if(raycaster.ray.intersectBox(box,hit)){const d=hit.distanceTo(raycaster.ray.origin);if(d<distance){distance=d;best=plot.index}}
    }
    return best;
  }
  const touches=new Set();let press=null,hover=-1;
  addEventListener('pointerdown',e=>{
    if(e.target!==canvas)return;
    if(e.pointerType==='touch')touches.add(e.pointerId);
    press=(e.pointerType!=='touch'&&e.button!==0)||touches.size>1?null:{id:e.pointerId,x:e.clientX,y:e.clientY,time:performance.now()};
  },{capture:true});
  addEventListener('pointermove',e=>{
    if(press?.id===e.pointerId&&Math.hypot(e.clientX-press.x,e.clientY-press.y)>8)press=null;
    if(e.pointerType==='mouse'&&e.target===canvas&&!e.buttons){
      const over=pick(e.clientX,e.clientY);
      if(over!==hover){hover=over;canvas.style.cursor=over>=0?'pointer':'';ui.hover(over)}
    }
  },{capture:true});
  const release=e=>{
    touches.delete(e.pointerId);
    const p=press;press=null;
    if(e.type!=='pointerup'||p?.id!==e.pointerId||performance.now()-p.time>650)return;
    const index=pick(e.clientX,e.clientY);
    if(index>=0)tap(index);else ui.close();
  };
  addEventListener('pointerup',release,{capture:true});
  addEventListener('pointercancel',release,{capture:true});

  const anchor=new T.Vector3(),spots=plots.map(()=>({x:0,y:0,on:false}));
  return dt=>{
    const now=Date.now(),rect=canvas.getBoundingClientRect();
    for(const plot of plots){
      const info=progress(plot,now);
      if(plot.harvest>0){
        // Harvest: the crop springs up out of the soil and shrinks away.
        plot.harvest=Math.max(0,plot.harvest-dt/.45);
        const t=1-plot.harvest,out=t<.3?1+.18*Math.sin(t/.3*Math.PI):1-ease((t-.3)/.7);
        draw(plot,plot.sets.get(plot.harvested),1,out,.24*ease(t));
        if(plot.harvest===0){show(plot,null);plot.drawn=-1}
      }else if(info){
        show(plot,info.crop.id);
        // Shown growth eases toward the real value, so a fresh seedling pops up out of the soil.
        plot.growth=plot.growth<0?info.growth:T.MathUtils.damp(plot.growth,info.growth,5,dt);
        if(Math.abs(info.growth-plot.growth)<1e-3)plot.growth=info.growth;
        if(Math.abs(plot.growth-plot.drawn)>1e-3||plot.drawn<0){plot.drawn=plot.growth;draw(plot,plot.sets.get(info.crop.id),plot.growth)}
      }else if(plot.shown){show(plot,null);plot.drawn=-1}
      const height=info?Math.max(.35,info.crop.height*(.3+.7*info.growth)):.3;
      anchor.set(plot.bed.x,plot.bed.y+.25+height,plot.bed.z).project(camera);
      const spot=spots[plot.index];
      spot.x=rect.left+(anchor.x+1)/2*rect.width;spot.y=rect.top+(1-anchor.y)/2*rect.height;
      spot.on=anchor.z<1&&Math.abs(anchor.x)<1.1&&Math.abs(anchor.y)<1.1;
      ui.place(plot.index,spot.x,spot.y,spot.on,info);
    }
    // Zoomed out, neighbouring beds are too close for full tags: show round icon badges instead.
    let closest=Infinity;
    for(let i=0;i<spots.length;i++)for(let j=i+1;j<spots.length;j++)
      if(spots[i].on&&spots[j].on)closest=Math.min(closest,Math.hypot(spots[i].x-spots[j].x,(spots[i].y-spots[j].y)*2.5));
    ui.compact(closest<128);
  };
}
