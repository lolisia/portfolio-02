import * as T from 'three';
import {builder} from './modules.js';
import {createFarmUI} from './farm-ui.js';
import {createForestry} from './forestry.js';
import {createWoodFx} from './fx.js';

// Farming game on the vegetable beds and the flower garden. Every bed starts empty; tapping it
// opens the seed picker and Unity-chan walks over to plant. The crop grows in real time (saved
// with timestamps, so it keeps growing while the page is closed); a ripe bed is tapped again and
// she harvests it for coins and experience. Every job stays pending until she has reached the
// bed and finished working it. Tapping the ground walks her there; tapping the pond, she fishes.
const ease=t=>1-(1-t)**3;
const grid=(cols,rows,dx,dz,y,size=[1,1])=>(rand)=>{
  const list=[];
  for(let j=0;j<rows;j++)for(let i=0;i<cols;i++){
    const s=size[0]+rand()*(size[1]-size[0]);
    list.push({x:(i-(cols-1)/2)*dx+(rand()-.5)*.04,z:(j-(rows-1)/2)*dz+(rand()-.5)*.04,y,s,turn:rand()*6.28});
  }
  return list;
};
// bed: which beds take it; seconds: growth time; cost: seed price; sell: harvest coins;
// level: player level that unlocks it. Each part scales up over its growth window [from,to];
// young/ripe tint the instances as it ripens (palette: a ripe colour per plant).
export const CROPS=[
  {id:'carrot',bed:'veg',name:'당근',icon:'🥕',seconds:30,cost:5,sell:12,xp:2,level:1,height:.3,
    layout:grid(3,5,.36,.29,.18,[.85,1.12]),parts:[{kind:'carrot',ripe:'#7ea946',young:'#9cc964'}]},
  {id:'wheat',bed:'veg',name:'밀',icon:'🌾',seconds:60,cost:10,sell:24,xp:4,level:1,height:.5,
    layout:grid(4,6,.27,.245,.17,[.85,1.1]),parts:[{kind:'wheatStalks',ripe:'#f2c45c',young:'#8fbf58'}]},
  {id:'cabbage',bed:'veg',name:'양배추',icon:'🥬',seconds:90,cost:15,sell:38,xp:6,level:2,height:.3,
    layout:grid(3,4,.36,.37,.19,[1,1.2]),parts:[{kind:'cabbage',ripe:'#a3c063',young:'#b9d77c'}]},
  {id:'tomato',bed:'veg',name:'토마토',icon:'🍅',seconds:120,cost:20,sell:55,xp:8,level:3,height:.6,
    layout:grid(2,3,.46,.46,.17,[1.05,1.2]),parts:[{kind:'tomatoBush',ripe:'#ffffff',young:'#d8f0b8'},
      {kind:'tomatoFruit',ripe:'#e2402c',young:'#93c25a',from:.5}]},
  {id:'sunflower',bed:'veg',name:'해바라기',icon:'🌻',seconds:180,cost:30,sell:85,xp:12,level:4,height:.95,
    layout:grid(2,3,.46,.46,.17,[.72,.84]),parts:[{kind:'sunflowerStem',ripe:'#6f9142',young:'#86b05a'},
      {kind:'sunflowerBloom',ripe:'#ffffff',young:'#b6d07a',from:.6}]},
  {id:'pumpkin',bed:'veg',name:'호박',icon:'🎃',seconds:300,cost:45,sell:140,xp:18,level:5,height:.4,
    layout:grid(2,2,.5,.74,.17,[1.25,1.4]),parts:[{kind:'pumpkinVine',ripe:'#ffffff',young:'#e6f5c8',to:.7},
      {kind:'pumpkinFruit',ripe:'#f08a24',young:'#9cc25a',from:.4,offset:[.07,.06]}]},
  {id:'daisy',bed:'flower',name:'데이지',icon:'🌼',seconds:45,cost:6,sell:15,xp:3,level:1,height:.25,
    layout:grid(6,3,.25,.22,0,[.6,.85]),parts:[{kind:'flowerStem',ripe:'#6f8f45',young:'#8fb35e'},
      {kind:'flowerHead',palette:['#f4f1e4','#f2d25a','#f7f3ea'],young:'#c9dea0',from:.5}]},
  {id:'tulip',bed:'flower',name:'튤립',icon:'🌷',seconds:90,cost:14,sell:34,xp:5,level:2,height:.4,
    layout:grid(7,3,.21,.21,0,[.9,1.15]),parts:[{kind:'tulipStem',ripe:'#73964a',young:'#8db35c'},
      {kind:'tulipBloom',palette:['#e0362f','#f2c430','#f08bb0','#f7f1e6','#f07a2a','#b0367a'],young:'#bcd88f',from:.55}]},
  {id:'lavender',bed:'flower',name:'라벤더',icon:'💜',seconds:150,cost:22,sell:60,xp:9,level:3,height:.4,
    layout:grid(5,2,.3,.32,0,[.85,1.2]),parts:[{kind:'lavenderStem',ripe:'#7d9468',young:'#93b278'},
      {kind:'lavenderBloom',palette:['#8a6cc4','#9b7fd1','#7a5fb5'],young:'#a9c48c',from:.5}]},
  {id:'foxglove',bed:'flower',name:'디기탈리스',icon:'🌸',seconds:240,cost:35,sell:100,xp:14,level:4,height:.7,
    layout:grid(6,2,.25,.34,0,[1,1.3]),parts:[{kind:'foxgloveStem',ripe:'#6b8c45',young:'#86a95a'},
      {kind:'foxgloveBloom',palette:['#c76aa4','#e7a6cf','#f2eef2','#a676c8','#d9809a'],young:'#b5d08a',from:.55}]}
];
const byId=new Map(CROPS.map(c=>[c.id,c]));
// What the pond gives: weight is the relative chance of a catch.
export const FISH=[
  {name:'피라미',icon:'🐟',coins:6,xp:1,weight:45},{name:'붕어',icon:'🐟',coins:12,xp:2,weight:30},
  {name:'송어',icon:'🐠',coins:22,xp:4,weight:18},{name:'황금 잉어',icon:'🐠',coins:60,xp:10,weight:7}
];
// Total experience needed to reach each level (index = level - 1).
export const LEVELS=[0,10,30,60,100,160,240,340,460,600];
export function levelOf(xp){let level=1;while(level<LEVELS.length&&xp>=LEVELS[level])level++;return level}
const KEY='forest-farm.farm.v1',START={coins:40,xp:0,wood:0};
const POND={x:10.7,z:6.3,rx:4.5,rz:3.5};

function load(count){
  const query=new URLSearchParams(location.search).get('farm');
  try{
    if(query==='reset')localStorage.removeItem(KEY);
    const saved=JSON.parse(localStorage.getItem(KEY)||'null');
    if(saved&&Number.isFinite(saved.coins)&&Number.isFinite(saved.xp)&&Array.isArray(saved.plots))
      return {coins:saved.coins,xp:saved.xp,wood:Number.isFinite(saved.wood)?saved.wood:0,
        trees:saved.trees&&typeof saved.trees==='object'?saved.trees:{},plots:Array.from({length:count},(_,i)=>{
        const p=saved.plots[i];return p&&byId.has(p.crop)&&Number.isFinite(p.planted)?{crop:p.crop,planted:p.planted}:null;
      })};
  }catch{}
  return {...START,trees:{},plots:Array(count).fill(null)};
}

export function createFarm(scene,world,assets,camera,canvas){
  const beds=[...world.beds.map(b=>({...b,w:1.32,d:1.72,kind:'veg'})),...world.flowerBeds.map(b=>({...b,kind:'flower'}))];
  const state=load(beds.length);
  const save=()=>{try{localStorage.setItem(KEY,JSON.stringify(state))}catch{}};
  const matrix=new T.Matrix4(),scale=new T.Matrix4(),lift=new T.Matrix4(),tint=new T.Color(),ripe=new T.Color();
  let character=null,forestry=null,wood=null,forestry_onGrown=null;
  // Every bed gets one hidden instanced set per crop it can take, built with the shared builder
  // so the plants sway in the wind and take the scene's surfaces; only the planted set is shown.
  const plots=beds.map((bed,index)=>{
    const sets=new Map();
    for(const crop of CROPS.filter(c=>c.bed===bed.kind)){
      const group=new T.Group();group.name='farm-'+crop.id+'-'+index;group.visible=false;
      const b=builder(group,7001+index*131+crop.id.length*17,assets);
      const plants=crop.layout(b.rand);
      b.place(bed.x,bed.y,bed.z,1,0,()=>{
        for(const p of plants)for(const part of crop.parts){
          const [ox,oz]=part.offset??[0,0],c=Math.cos(p.turn),s=Math.sin(p.turn);
          b.part(part.kind,p.x+ox*c+oz*s,p.y,p.z-ox*s+oz*c,p.s,p.s,p.s,'#ffffff',0,p.turn);
        }
      });
      b.finish();
      const meshes=crop.parts.map(part=>{
        const mesh=group.getObjectByName(part.kind);
        // Crops stay through winter: the seasonal bare-plant cut is for the wild plants.
        mesh.geometry.getAttribute('plantMask').array.fill(0);
        const base=Array.from({length:mesh.count},(_,i)=>{const m=new T.Matrix4();mesh.getMatrixAt(i,m);return m});
        const colors=base.map((_,i)=>new T.Color(part.palette?part.palette[(i*7+index*3)%part.palette.length]:part.ripe));
        return {mesh,part,base,colors};
      });
      scene.add(group);sets.set(crop.id,{group,meshes});
    }
    return {index,bed,sets,shown:null,growth:-1,drawn:-1,harvest:0,harvested:null,pending:null};
  });
  const progress=(plot,now=Date.now())=>{
    const saved=state.plots[plot.index];if(!saved)return null;
    const crop=byId.get(saved.crop),elapsed=(now-saved.planted)/1000;
    return {crop,growth:Math.min(1,Math.max(0,elapsed/crop.seconds)),left:Math.max(0,crop.seconds-elapsed)};
  };
  function draw(set,growth,out=1,rise=0){
    for(const {mesh,part,base,colors} of set.meshes){
      const from=part.from??0,to=part.to??1,local=Math.min(1,Math.max(0,(growth-from)/(to-from)));
      const size=Math.max(1e-4,(from>0?ease(local):.14+.86*ease(local))*out),ripen=T.MathUtils.smoothstep(growth,.35,1);
      lift.makeTranslation(0,rise,0);scale.makeScale(size,size,size);
      for(let i=0;i<mesh.count;i++){
        matrix.multiplyMatrices(lift,base[i]).multiply(scale);mesh.setMatrixAt(i,matrix);
        mesh.setColorAt(i,tint.set(part.young).lerp(colors[i],ripen));
      }
      mesh.instanceMatrix.needsUpdate=true;mesh.instanceColor.needsUpdate=true;
    }
  }
  function show(plot,id){
    if(plot.shown===id)return;
    if(plot.shown)plot.sets.get(plot.shown).group.visible=false;
    plot.shown=id;if(id)plot.sets.get(id).group.visible=true;
  }
  // Seeds for queued plantings are set aside, and only paid when she actually plants them.
  const reserved=()=>plots.reduce((sum,p)=>sum+(p.pending?.type==='plant'?p.pending.crop.cost:0),0);
  const wallet=()=>({coins:state.coins-reserved(),xp:state.xp});
  function earn(coins,xp){
    const before=levelOf(state.xp);
    state.coins+=coins;state.xp+=xp;save();ui.refresh(state);
    const after=levelOf(state.xp);
    if(after>before)ui.levelUp(after,CROPS.filter(c=>c.level>before&&c.level<=after));
  }
  // Queue a job at a bed for Unity-chan; the plot shows it as pending until she is done.
  function assign(plot,type,crop,done){
    const pending={type,crop,phase:'walk'};plot.pending=pending;
    pending.task=character.tend(plot.bed,{
      onStart(){pending.phase='work'},
      onDone(){plot.pending=null;done()},
      onCancel(){if(plot.pending===pending)plot.pending=null;ui.refresh(state)}
    });
    ui.refresh(state);
  }

  const ui=createFarmUI({crops:CROPS,levels:LEVELS,levelOf,wallet,
    plant(index,id){
      const crop=byId.get(id),plot=plots[index],purse=wallet();
      if(!character||state.plots[index]||plot.pending||!crop||crop.bed!==plot.bed.kind||levelOf(state.xp)<crop.level||purse.coins<crop.cost)return false;
      assign(plot,'plant',crop,()=>{
        if(state.plots[index]||state.coins<crop.cost){ui.refresh(state);return}
        state.coins-=crop.cost;state.plots[index]={crop:id,planted:Date.now()};
        plot.growth=0;plot.harvest=0;show(plot,id);save();ui.refresh(state);
      });
      return true;
    },
    clear(index){state.plots[index]=null;show(plots[index],null);save();ui.refresh(state)},
    cancel(index){const p=plots[index].pending;if(p)character.cancel(p.task)}
  });
  ui.refresh(state);
  function harvest(plot){
    const info=progress(plot);if(!info||info.growth<1)return;
    state.plots[plot.index]=null;
    plot.harvest=1;plot.harvested=info.crop.id;
    ui.reward(plot.index,info.crop.icon,info.crop.sell,info.crop.xp);
    earn(info.crop.sell,info.crop.xp);
  }
  function tap(index){
    const plot=plots[index],info=progress(plot);
    if(!character)return;
    if(plot.pending)ui.openPending(index,plot.pending);
    else if(!info)ui.openPicker(index,plot.bed.kind,wallet());
    else if(info.growth>=1){ui.close();assign(plot,'harvest',info.crop,()=>harvest(plot))}
    else ui.openInfo(index,info);
  }
  ui.onTag=tap;

  // Felling: she chops at the trunk (it shudders and sheds chips at every blow) until it topples
  // away from her with a thud that shakes the camera, then cuts the log into firewood that flies
  // up to the wood counter. Tapping the stump digs it out and plants a sapling of the same kind.
  // Every stage is a job of its own, pending until she has worked it through.
  const clock=s=>{s=Math.ceil(s);return Math.floor(s/60)+':'+String(s%60).padStart(2,'0')};
  const saveTree=(tree,entry)=>{if(entry)state.trees[tree.index]=entry;else delete state.trees[tree.index];save()};
  const swing=(tree,shudder=true)=>point=>{
    character.position(hit);
    wood.chips(point,{x:tree.x-hit.x,z:tree.z-hit.z},shudder?10:6);
    if(shudder)forestry.hit(tree,hit);
  };
  function stage(tree,name,job){
    tree.job={stage:name,phase:'walk'};
    tree.job.task=character.work({prop:'axe',...job,
      onStart(){tree.job.phase='work'},
      onDone(){tree.job=null;job.done()},
      onCancel(){tree.job=null},
      onFail(){ui.toast('🚧 그곳으로 갈 수 없어요')}});
  }
  function chopLog(tree){
    stage(tree,'log',{spots:forestry.logSpots(tree),steps:[{clip:'Chopping',time:2.4,fade:.2}],onHit:swing(tree),done(){
      const count=Math.round((tree.pine?3.4:2.6)*tree.s+1),xp=3;
      forestry.clear(tree);saveTree(tree,{stump:true});
      state.wood+=count;save();ui.refresh(state,{woodDelay:true});
      // The log splits into billets that hop up and fly off to the wood counter.
      let landed=0;
      wood.firewood(forestry.logPoints(tree,count),position=>{
        const at=anchorOf(position.x,position.y,position.z);
        ui.collect(at.x,at.y,'wood',1,++landed===count);
      });
      const top=anchorOf(tree.x+tree.dir.x*1.5*tree.s,tree.y+1.2,tree.z+tree.dir.z*1.5*tree.s);
      ui.rewardAt(top.x,top.y,'🪵 목재 +'+count,0,xp,true);
      earn(0,xp);
    }});
  }
  function plantSapling(tree){
    stage(tree,'plant',{prop:null,spots:forestry.trunkSpots(tree),steps:[{clip:'Gathering',time:2.2}],done(){
      forestry.plant(tree);saveTree(tree,{planted:tree.plantedAt});
      const at=anchorOf(tree.x,tree.y+.6,tree.z);ui.rewardAt(at.x,at.y,'🌱 묘목 심기',0,1,true);earn(0,1);
    }});
  }
  forestry_onGrown=tree=>saveTree(tree,null);
  function tapTree(index){
    const tree=forestry.trees[index];
    if(tree.job){ui.toast('🪓 이미 작업이 예약되어 있어요');return}
    const spots=forestry.trunkSpots(tree);
    if(tree.state==='fallen'){chopLog(tree);return}
    if(tree.state==='growing'){ui.toast((tree.pine?'🌲':'🌳')+' 묘목이 자라는 중 · '+clock(forestry.left(tree)));return}
    if(!spots.length){ui.toast('🚧 이 나무에는 다가갈 수 없어요');return}
    if(tree.state==='bare'){plantSapling(tree);return}
    if(tree.state==='stump'){
      stage(tree,'stump',{spots,steps:[{clip:'Chopping',time:2,fade:.2}],onHit:swing(tree,false),done(){forestry.uproot(tree);plantSapling(tree)}});
      return;
    }
    if(tree.state!=='standing')return;
    stage(tree,'chop',{spots,steps:[{clip:'Chopping',time:3.3,fade:.2}],onHit:swing(tree),done(){
      tree.job={stage:'fall',phase:'work'};
      forestry.fell(tree,()=>{shake(.45,7);tree.job=null;chopLog(tree)});
    }});
  }
  // A short decaying camera shake, done with the projection's view offset so the orbit
  // controls never see it.
  let shakeTime=0,shakeLength=1,shakeSize=0;
  function shake(seconds,pixels){shakeTime=shakeLength=seconds;shakeSize=pixels}
  function updateShake(dt){
    if(shakeTime<=0)return;
    shakeTime=Math.max(0,shakeTime-dt);
    const w=canvas.clientWidth,h=canvas.clientHeight,k=(shakeTime/shakeLength)**2*shakeSize,t=performance.now()/1000;
    if(shakeTime===0){camera.clearViewOffset();return}
    camera.setViewOffset(w,h,Math.sin(t*61)*k,Math.sin(t*47+1.3)*k*.8,w,h);
  }

  // Fishing: one cast per tap, a random catch when she reels in.
  let fishing=null;
  const head=new T.Vector3();
  function fish(point){
    if(world.water.userData.freeze.value>.3){ui.toast('🧊 연못이 얼어서 낚시를 할 수 없어요');return}
    if(fishing)return;
    fishing=character.fish(point,{
      onDone(){
        fishing=null;
        let roll=Math.random()*FISH.reduce((sum,f)=>sum+f.weight,0),fish=FISH[0];
        for(const f of FISH){roll-=f.weight;if(roll<=0){fish=f;break}}
        character.position(head);head.y+=1.25;head.project(camera);
        const rect=canvas.getBoundingClientRect();
        ui.rewardAt(rect.left+(head.x+1)/2*rect.width,rect.top+(1-head.y)/2*rect.height,fish.icon+' '+fish.name,fish.coins,fish.xp);
        earn(fish.coins,fish.xp);
      },
      onCancel(){fishing=null}
    });
  }

  // A tap is a short press that barely moves (left drag pans the map, so the two never clash).
  // Listening on window in the capture phase sees touches before the map controls swallow them.
  const raycaster=new T.Raycaster(),pointer=new T.Vector2(),box=new T.Box3(),hit=new T.Vector3();
  const water=new T.Plane(new T.Vector3(0,1,0),-world.waterY);
  function aim(x,y){
    const rect=canvas.getBoundingClientRect();
    pointer.set((x-rect.left)/rect.width*2-1,-(y-rect.top)/rect.height*2+1);
    raycaster.setFromCamera(pointer,camera);
  }
  function pickPlot(){
    let best=-1,distance=Infinity;
    for(const plot of plots){
      const {x:bx,y:by,z:bz,w,d}=plot.bed,info=progress(plot),top=info?Math.max(.32,info.crop.height*(.3+.7*info.growth)):.32;
      box.min.set(bx-w/2,by-.2,bz-d/2);box.max.set(bx+w/2,by+.1+top,bz+d/2);
      if(raycaster.ray.intersectBox(box,hit)){const t=hit.distanceTo(raycaster.ray.origin);if(t<distance){distance=t;best=plot.index}}
    }
    return best;
  }
  function overPond(){
    if(!raycaster.ray.intersectPlane(water,hit))return null;
    const inside=((hit.x-POND.x)/POND.rx)**2+((hit.z-POND.z)/POND.rz)**2<1.6;
    return inside&&world.height(hit.x,hit.z)<world.waterY?hit.clone():null;
  }
  // A fading ring marks where she was sent.
  const marker=new T.Mesh(new T.RingGeometry(.16,.22,32),new T.MeshBasicMaterial({color:0xfff6dc,transparent:true,depthWrite:false,toneMapped:false}));
  marker.rotation.x=-Math.PI/2;marker.visible=false;marker.renderOrder=2;scene.add(marker);
  let markerLife=0;
  function walk(){
    const ground=raycaster.intersectObject(world.ground,false)[0];
    if(!ground||!character?.walkTo(ground.point.x,ground.point.z))return;
    marker.position.set(ground.point.x,world.stand(ground.point.x,ground.point.z)+.03,ground.point.z);markerLife=1;
  }
  function tapAt(x,y){
    aim(x,y);
    const index=pickPlot();
    if(index>=0){tap(index);return}
    if(ui.isOpen()){ui.close();return}
    if(!character)return;
    const tree=forestry?forestry.pick(raycaster.ray):-1;
    if(tree>=0){tapTree(tree);return}
    const pond=overPond();
    if(pond)fish(pond);else walk();
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
      aim(e.clientX,e.clientY);
      const over=pickPlot(),point=over<0&&(overPond()!==null||(forestry?.pick(raycaster.ray)??-1)>=0);
      canvas.style.cursor=over>=0||point?'pointer':'';
      if(over!==hover){hover=over;ui.hover(over)}
    }
  },{capture:true});
  const release=e=>{
    touches.delete(e.pointerId);
    const p=press;press=null;
    if(e.type!=='pointerup'||p?.id!==e.pointerId||performance.now()-p.time>650)return;
    tapAt(e.clientX,e.clientY);
  };
  addEventListener('pointerup',release,{capture:true});
  addEventListener('pointercancel',release,{capture:true});

  const anchor=new T.Vector3(),spots=plots.map(()=>({x:0,y:0,on:false})),screen={x:0,y:0,on:false};
  function anchorOf(x,y,z){
    const rect=canvas.getBoundingClientRect();anchor.set(x,y,z).project(camera);
    screen.x=rect.left+(anchor.x+1)/2*rect.width;screen.y=rect.top+(1-anchor.y)/2*rect.height;
    screen.on=anchor.z<1&&Math.abs(anchor.x)<1.1&&Math.abs(anchor.y)<1.1;return screen;
  }
  const update=dt=>{
    const now=Date.now(),rect=canvas.getBoundingClientRect();
    if(markerLife>0){
      markerLife=Math.max(0,markerLife-dt/.9);marker.visible=markerLife>0;
      marker.material.opacity=Math.min(1,markerLife*2.5)*.85;marker.scale.setScalar(1+(1-markerLife)*.6);
    }
    for(const plot of plots){
      const info=progress(plot,now);
      if(plot.harvest>0){
        // Harvest: the crop springs up out of the soil and shrinks away.
        plot.harvest=Math.max(0,plot.harvest-dt/.45);
        const t=1-plot.harvest,out=t<.3?1+.18*Math.sin(t/.3*Math.PI):1-ease((t-.3)/.7);
        draw(plot.sets.get(plot.harvested),1,out,.24*ease(t));
        if(plot.harvest===0){show(plot,null);plot.drawn=-1}
      }else if(info){
        show(plot,info.crop.id);
        // Shown growth eases toward the real value, so a fresh seedling pops up out of the soil.
        plot.growth=plot.growth<0?info.growth:T.MathUtils.damp(plot.growth,info.growth,5,dt);
        if(Math.abs(info.growth-plot.growth)<1e-3)plot.growth=info.growth;
        if(Math.abs(plot.growth-plot.drawn)>1e-3||plot.drawn<0){plot.drawn=plot.growth;draw(plot.sets.get(info.crop.id),plot.growth)}
      }else if(plot.shown){show(plot,null);plot.drawn=-1}
      const height=info?Math.max(.35,info.crop.height*(.3+.7*info.growth)):.3;
      anchor.set(plot.bed.x,plot.bed.y+.25+height,plot.bed.z).project(camera);
      const spot=spots[plot.index];
      spot.x=rect.left+(anchor.x+1)/2*rect.width;spot.y=rect.top+(1-anchor.y)/2*rect.height;
      spot.on=anchor.z<1&&Math.abs(anchor.x)<1.1&&Math.abs(anchor.y)<1.1;
      ui.place(plot.index,spot.x,spot.y,spot.on,info,plot.pending);
    }
    updateShake(dt);
    if(forestry){
      forestry.update(dt,now);wood.update(dt);
      for(const t of forestry.trees){
        const job=t.job,key='tree'+t.index;
        if(!job){ui.note(key,null);continue}
        const lying=job.stage==='log'||job.stage==='fall',at=lying?anchorOf(t.x+t.dir.x*1.5*t.s,t.y+1.3*t.s,t.z+t.dir.z*1.5*t.s):anchorOf(t.x,t.y+1.9*t.s,t.z);
        const text=job.stage==='fall'?'쿵!':job.phase==='walk'?'이동 중':({log:'장작 패는 중',stump:'그루터기 캐는 중',plant:'묘목 심는 중',chop:'벌목 중'})[job.stage];
        ui.note(key,{x:at.x,y:at.y,on:at.on,icon:job.stage==='plant'?'🌱':'🪓',text});
      }
    }
    // Zoomed out, neighbouring beds are too close for full tags: show round icon badges instead.
    let closest=Infinity;
    for(let i=0;i<spots.length;i++)for(let j=i+1;j<spots.length;j++)
      if(spots[i].on&&spots[j].on)closest=Math.min(closest,Math.hypot(spots[i].x-spots[j].x,(spots[i].y-spots[j].y)*2.5));
    ui.compact(closest<128);
  };
  return Object.assign(update,{    bind(next){
      character=next;
      // The storybook crowns exist by now, so every copy of a tree is found and felled together.
      forestry=createForestry(scene,world,assets);forestry.restore(state.trees);forestry.onGrown=forestry_onGrown;
      wood=createWoodFx(scene,world);
    }});
}
