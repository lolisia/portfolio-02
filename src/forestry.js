import * as T from 'three';
import {builder} from './modules.js';

// Tree felling. The trees are instances in the island's static batches (and in the storybook
// look's alternate crowns); a felled tree is animated by rewriting its instance matrices: it
// topples away from the axe, lies as a log until it is cut up, then leaves a stump that later
// sprouts a sapling which grows back into the full tree.
export const STUMP_SECONDS=240,REGROW_SECONDS=90;
const PARTS=['oakABark','oakALeaves','oakBBark','oakBLeaves','pineABark','pineANeedles'];
const ease=t=>t*t*(3-2*t);

export function createForestry(scene,world,assets){
  const meshes=[];
  scene.traverse(o=>{if(o.isInstancedMesh&&PARTS.includes(o.name.replace(/^storybook-/,'')))meshes.push(o)});
  const trees=world.trees.map((t,index)=>{
    const pine=t.kind?.startsWith('pine');
    const perch=world.birdPerches.find(p=>p.kind==='tree'&&Math.abs(p.root.x-t.x)<1e-4&&Math.abs(p.root.z-t.z)<1e-4)??null;
    // A stump sized to the trunk, hidden until the tree is cut.
    const stump=new T.Group();stump.name='stump-'+index;stump.visible=false;
    const b=builder(stump,9100+index,assets),k=(pine?.55:.78)*t.s;
    b.place(t.x,t.y,t.z,k,t.angle,()=>{b.part('stumpBark',0,-.04,0,1,1,1,'#7a5a3a');b.part('stumpTop',0,-.04,0,1,1,1,'#d1b07a')});
    b.finish();scene.add(stump);
    return {...t,index,pine,perch,stump,parts:[],state:'standing',tilt:0,size:1,dir:new T.Vector3(0,0,1),timer:0,felledAt:0,onLanded:null};
  });
  const m=new T.Matrix4(),p=new T.Vector3();
  for(const mesh of meshes)for(let i=0;i<mesh.count;i++){
    mesh.getMatrixAt(i,m);p.setFromMatrixPosition(m);
    const tree=trees.find(t=>Math.abs(t.x-p.x)<1e-3&&Math.abs(t.z-p.z)<1e-3);
    if(tree)tree.parts.push({mesh,i,base:m.clone()});
  }
  const root=new T.Vector3(),axis=new T.Vector3(),pose=new T.Matrix4(),turn=new T.Matrix4(),dirty=new Set();
  // Pose a tree: tipped by tilt (radians) toward dir about its base, scaled by size about its base.
  function draw(tree){
    root.set(tree.x,tree.y,tree.z);axis.set(tree.dir.z,0,-tree.dir.x).normalize();
    pose.makeTranslation(root.x,root.y,root.z)
      .multiply(turn.makeRotationAxis(axis,tree.tilt))
      .multiply(m.makeScale(tree.size,tree.size,tree.size))
      .multiply(turn.makeTranslation(-root.x,-root.y,-root.z));
    for(const part of tree.parts){
      if(tree.size<=1e-3)m.makeScale(0,0,0);else m.multiplyMatrices(pose,part.base);
      part.mesh.setMatrixAt(part.i,m);dirty.add(part.mesh);
    }
  }
  function regrowth(tree,now){
    const age=(now-tree.felledAt)/1000;
    return age<STUMP_SECONDS?0:Math.min(1,(age-STUMP_SECONDS)/REGROW_SECONDS);
  }
  const box=new T.Box3(),hit=new T.Vector3();
  return {
    trees,
    // Restore saved fellings: {index: felledAt}.
    restore(saved,now=Date.now()){
      for(const [key,at] of Object.entries(saved||{})){
        const tree=trees[Number(key)];if(!tree||!Number.isFinite(at))continue;
        tree.felledAt=at;tree.state='stump';tree.tilt=0;tree.size=0;draw(tree);
      }
    },
    pick(ray){
      let best=-1,distance=Infinity;
      for(const t of trees){
        const s=t.s,top=t.state==='fallen'||t.state==='clearing'?1:t.state==='stump'?.3:4.6*s*Math.max(.3,t.size);
        if(t.state==='fallen'||t.state==='clearing'){
          // A log lying along its fall direction.
          const len=3.6*s,r=.9*s;
          box.min.set(Math.min(t.x,t.x+t.dir.x*len)-r,t.y-.3,Math.min(t.z,t.z+t.dir.z*len)-r);
          box.max.set(Math.max(t.x,t.x+t.dir.x*len)+r,t.y+1.6*s,Math.max(t.z,t.z+t.dir.z*len)+r);
        }else{
          const r=(t.state==='stump'?.4:t.size<1?.6:1.05)*s;
          box.min.set(t.x-r,t.y-.2,t.z-r);box.max.set(t.x+r,t.y+top,t.z+r);
        }
        if(ray.intersectBox(box,hit)){const d=hit.distanceTo(ray.origin);if(d<distance){distance=d;best=t.index}}
      }
      return best;
    },
    // Where she can stand to swing at the trunk, or at the middle of the fallen log.
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
      return list.length?list:this.trunkSpots(tree);
    },
    fell(tree,dir,onLanded){
      tree.dir.set(dir.x,0,dir.z).normalize();tree.state='falling';tree.timer=0;tree.onLanded=onLanded;
      if(tree.perch)tree.perch.gone=true;
      tree.stump.visible=true;
    },
    clear(tree){tree.state='clearing';tree.timer=0;tree.felledAt=Date.now()},
    regrowth,
    update(dt,now=Date.now()){
      for(const t of trees){
        if(t.state==='falling'){
          // Slow lean that gathers speed, a thud and a small rebound off the crown.
          t.timer+=dt;
          const u=Math.min(1,t.timer/1.5),lie=1.42;
          t.tilt=u<1?lie*u*u*u:lie;
          if(t.timer>1.5)t.tilt=lie-.06*Math.sin(Math.min(1,(t.timer-1.5)/.35)*Math.PI);
          if(t.timer>1.85){t.state='fallen';t.tilt=lie;const landed=t.onLanded;t.onLanded=null;landed?.(t)}
          draw(t);
        }else if(t.state==='clearing'){
          // Cut up and carried off: the log shrinks away into its base.
          t.timer+=dt;t.size=Math.max(0,1-ease(Math.min(1,t.timer/.6)));draw(t);
          if(t.size===0){t.state='stump';t.tilt=0;draw(t)}
        }else if(t.state==='stump'||t.state==='growing'){
          const g=regrowth(t,now);
          if(g>0){
            t.state=g>=1?'standing':'growing';t.tilt=0;t.size=g>=1?1:.12+.88*ease(g);draw(t);
            t.stump.visible=g<.35;
            if(g>=1&&t.perch)t.perch.gone=false;
          }else if(!t.stump.visible){t.stump.visible=true;if(t.perch)t.perch.gone=true}
        }
      }
      for(const mesh of dirty){mesh.instanceMatrix.needsUpdate=true;mesh.computeBoundingSphere?.()}
      dirty.clear();
    }
  };
}
