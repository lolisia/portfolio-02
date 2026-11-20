import * as T from 'three';
import {builder} from './modules.js';

// Tree felling. The trees are instances in the island's static batches (and in the storybook
// look's alternate crowns); a felled tree is animated by rewriting its instance matrices: it
// shudders under each axe blow, topples away from the axe, lies as a log until it is cut up,
// and leaves a stump. Uprooting the stump plants a sapling of the same kind, which grows back
// into the full tree over a long while.
export const SAPLING_SECONDS=3600;
const PARTS=['oakABark','oakALeaves','oakBBark','oakBLeaves','pineABark','pineANeedles'];
const ease=t=>t*t*(3-2*t);
const LIE=1.42;

export function createForestry(scene,world,assets){
  const meshes=[];
  scene.traverse(o=>{if(o.isInstancedMesh&&PARTS.includes(o.name.replace(/^storybook-/,'')))meshes.push(o)});
  const trees=world.trees.map((t,index)=>{
    const pine=t.kind?.startsWith('pine');
    const perch=world.birdPerches.find(p=>p.kind==='tree'&&Math.abs(p.root.x-t.x)<1e-4&&Math.abs(p.root.z-t.z)<1e-4)??null;
    // A stump sized to the trunk, hidden until the tree is cut.
    const stump=new T.Group();stump.name='stump-'+index;stump.visible=false;
    const b=builder(stump,9100+index,assets),k=(pine?.55:.78)*t.s;
    b.place(0,0,0,k,t.angle,()=>{b.part('stumpBark',0,-.04,0,1,1,1,'#7a5a3a');b.part('stumpTop',0,-.04,0,1,1,1,'#d1b07a')});
    b.finish();stump.position.set(t.x,t.y,t.z);scene.add(stump);
    return {...t,index,pine,perch,stump,parts:[],state:'standing',tilt:0,size:1,dir:new T.Vector3(0,0,1),
      timer:0,wobble:0,wobbleTime:0,plantedAt:0,uproot:0,onLanded:null};
  });
  const m=new T.Matrix4(),p=new T.Vector3();
  for(const mesh of meshes)for(let i=0;i<mesh.count;i++){
    mesh.getMatrixAt(i,m);p.setFromMatrixPosition(m);
    const tree=trees.find(t=>Math.abs(t.x-p.x)<1e-3&&Math.abs(t.z-p.z)<1e-3);
    if(tree)tree.parts.push({mesh,i,base:m.clone()});
  }
  const root=new T.Vector3(),axis=new T.Vector3(),pose=new T.Matrix4(),turn=new T.Matrix4(),dirty=new Set();
  // Pose a tree: tipped by tilt (radians) toward dir about its base, scaled by size about its base.
  function draw(tree,tilt=tree.tilt){
    root.set(tree.x,tree.y,tree.z);axis.set(tree.dir.z,0,-tree.dir.x).normalize();
    pose.makeTranslation(root.x,root.y,root.z)
      .multiply(turn.makeRotationAxis(axis,tilt))
      .multiply(m.makeScale(tree.size,tree.size,tree.size))
      .multiply(turn.makeTranslation(-root.x,-root.y,-root.z));
    for(const part of tree.parts){
      if(tree.size<=1e-3)m.makeScale(0,0,0);else m.multiplyMatrices(pose,part.base);
      part.mesh.setMatrixAt(part.i,m);dirty.add(part.mesh);
    }
  }
  const growth=(tree,now)=>Math.min(1,Math.max(0,(now-tree.plantedAt)/1000/SAPLING_SECONDS));
  const gone=(tree,flag)=>{if(tree.perch)tree.perch.gone=flag};
  const box=new T.Box3(),hit=new T.Vector3();
  const api={
    trees,onGrown:null,
    // Restore saved trees: {index: {stump:true} | {planted:time}} (a bare number is an old stump).
    restore(saved,now=Date.now()){
      for(const [key,entry] of Object.entries(saved||{})){
        const tree=trees[Number(key)];if(!tree)continue;
        tree.tilt=0;gone(tree,true);
        if(entry&&Number.isFinite(entry.planted)){tree.state='growing';tree.plantedAt=entry.planted;tree.size=0}
        else{tree.state='stump';tree.size=0;tree.stump.visible=true}
        draw(tree);
      }
    },
    pick(ray){
      let best=-1,distance=Infinity;
      for(const t of trees){
        const s=t.s;
        if(t.state==='fallen'||t.state==='clearing'){
          // A log lying along its fall direction.
          const len=3.6*s,r=.9*s;
          box.min.set(Math.min(t.x,t.x+t.dir.x*len)-r,t.y-.3,Math.min(t.z,t.z+t.dir.z*len)-r);
          box.max.set(Math.max(t.x,t.x+t.dir.x*len)+r,t.y+1.6*s,Math.max(t.z,t.z+t.dir.z*len)+r);
        }else{
          const low=t.state==='stump'||t.state==='uprooting',r=(low?.45:t.size<.5?.6:1.05)*s,top=low?.45:Math.max(.6,4.6*s*t.size);
          box.min.set(t.x-r,t.y-.2,t.z-r);box.max.set(t.x+r,t.y+top,t.z+r);
        }
        if(ray.intersectBox(box,hit)){const d=hit.distanceTo(ray.origin);if(d<distance){distance=d;best=t.index}}
      }
      return best;
    },
    // Where she can stand to swing at the trunk, or beside the fallen log.
    trunkSpots(tree){
      const reach=.32*tree.s+.3,list=[];
      for(let k=0;k<12;k++){
        const a=k/12*Math.PI*2,x=tree.x+Math.sin(a)*reach,z=tree.z+Math.cos(a)*reach;
        if(world.walkable(x,z))list.push({x,z,face:Math.atan2(tree.x-x,tree.z-z)});
      }
      return list;
    },
    logSpots(tree){
      const list=[],cx=tree.x+tree.dir.x*1.5*tree.s,cz=tree.z+tree.dir.z*1.5*tree.s;
      for(const side of [-1,1])for(const along of [0,-.5,.5,-1,1]){
        const x=cx+tree.dir.z*side*.5+tree.dir.x*along*tree.s,z=cz-tree.dir.x*side*.5+tree.dir.z*along*tree.s;
        if(world.walkable(x,z))list.push({x,z,face:Math.atan2(-tree.dir.z*side,tree.dir.x*side)});
      }
      // Nowhere beside the log: cut it from the stump end.
      return list.length?list:api.trunkSpots(tree);
    },
    // Points along the fallen trunk, for the firewood it splits into.
    logPoints(tree,count){
      return Array.from({length:count},(_,i)=>{
        const u=(.25+i/(count-1||1)*.6)*3.2*tree.s;
        return new T.Vector3(tree.x+tree.dir.x*u,tree.y+.22*tree.s,tree.z+tree.dir.z*u);
      });
    },
    // An axe blow: a standing tree shudders away from the blade, a log jumps a little.
    hit(tree,from){
      if(tree.state==='standing'){tree.dir.set(tree.x-from.x,0,tree.z-from.z).normalize()}
      tree.wobble=1;tree.wobbleTime=0;
    },
    fell(tree,onLanded){
      tree.state='falling';tree.timer=0;tree.onLanded=onLanded;tree.wobble=0;
      gone(tree,true);tree.stump.visible=true;tree.stump.scale.setScalar(1);
    },
    clear(tree){tree.state='clearing';tree.timer=0},
    uproot(tree){tree.state='uprooting';tree.timer=0},
    plant(tree,now=Date.now()){tree.state='growing';tree.plantedAt=now;tree.size=0;tree.tilt=0;tree.stump.visible=false;draw(tree)},
    left:(tree,now=Date.now())=>Math.max(0,SAPLING_SECONDS-(now-tree.plantedAt)/1000),
    update(dt,now=Date.now()){
      for(const t of trees){
        // Shudder after a blow: a quick damped sway about the base (or a hop for a log).
        let shake=0;
        if(t.wobble>0){
          t.wobbleTime+=dt;t.wobble=Math.max(0,1-t.wobbleTime/.55);
          shake=Math.sin(t.wobbleTime*34)*t.wobble*t.wobble*(t.state==='standing'?.045:.025);
          if(t.state==='standing'||t.state==='fallen')draw(t,t.tilt+shake);
        }
        if(t.state==='falling'){
          // Slow lean that gathers speed, a thud and a small rebound off the crown.
          t.timer+=dt;
          const u=Math.min(1,t.timer/1.5);
          t.tilt=u<1?LIE*u*u*u:LIE-.06*Math.sin(Math.min(1,(t.timer-1.5)/.35)*Math.PI);
          if(t.timer>=1.5&&t.onLanded){const landed=t.onLanded;t.onLanded=null;landed(t)}
          if(t.timer>1.85){t.state='fallen';t.tilt=LIE}
          draw(t);
        }else if(t.state==='clearing'){
          // Split into firewood: the log shrinks away into its base.
          t.timer+=dt;t.size=Math.max(0,1-ease(Math.min(1,t.timer/.45)));draw(t);
          if(t.size===0){t.state='stump';t.tilt=0;draw(t)}
        }else if(t.state==='uprooting'){
          t.timer+=dt;const k=Math.max(0,1-ease(Math.min(1,t.timer/.5)));
          t.stump.scale.set(1,k,1);t.stump.position.y=t.y-(1-k)*.08;
          if(k===0){t.stump.visible=false;t.stump.scale.setScalar(1);t.stump.position.y=t.y;t.state='bare'}
        }else if(t.state==='growing'){
          // The sapling pops out of the soil, then grows slowly into the full tree.
          const g=growth(t,now),appear=Math.min(1,(now-t.plantedAt)/450);
          const size=(.13+.87*ease(g))*(appear<1?Math.sin(appear*Math.PI*.5)*(1+.25*Math.sin(appear*Math.PI)):1);
          if(Math.abs(size-t.size)>1e-4){t.size=size;draw(t)}
          if(g>=1){t.state='standing';t.size=1;draw(t);gone(t,false);api.onGrown?.(t)}
        }
      }
      for(const mesh of dirty){mesh.instanceMatrix.needsUpdate=true;mesh.computeBoundingSphere?.()}
      dirty.clear();
    }
  };
  return api;
}
