import * as T from 'three';

// Things shaken loose: a bird landing on a branch knocks off a few leaves (or a clump of snow
// in winter), and now and then snow slides off a laden roof edge or branch, falling to the
// ground with a soft puff.
export function createShedding(scene,world){
  const LEAVES=60,CLUMPS=24,PUFF=90;
  const leafGeo=new T.PlaneGeometry(.075,.05);leafGeo.translate(0,0,0);
  const leaves=new T.InstancedMesh(leafGeo,new T.MeshStandardMaterial({side:T.DoubleSide,roughness:.8}),LEAVES);
  const clumps=new T.InstancedMesh(new T.IcosahedronGeometry(.09,0),new T.MeshStandardMaterial({color:0xf6f9ff,roughness:.9}),CLUMPS);
  const puffs=new T.InstancedMesh(new T.IcosahedronGeometry(.035,0),new T.MeshStandardMaterial({color:0xffffff,roughness:1,transparent:true,opacity:.85}),PUFF);
  const hidden=new T.Matrix4().makeScale(0,0,0);
  for(const [mesh,n] of [[leaves,LEAVES],[clumps,CLUMPS],[puffs,PUFF]]){
    mesh.frustumCulled=false;mesh.visible=false;mesh.castShadow=mesh!==puffs;
    for(let i=0;i<n;i++)mesh.setMatrixAt(i,hidden);scene.add(mesh);
  }
  const color=new T.Color();for(let i=0;i<LEAVES;i++)leaves.setColorAt(i,color.set(0x7d9a45));
  const make=n=>Array.from({length:n},()=>({life:0,p:new T.Vector3(),v:new T.Vector3(),r:new T.Euler(),spin:new T.Vector3(),s:1,rest:0,phase:0}));
  const leafState=make(LEAVES),clumpState=make(CLUMPS),puffState=make(PUFF);
  let nl=0,nc=0,np=0;
  const pose=new T.Object3D();
  const floor=(x,z)=>Math.max(world.waterY,world.stand(x,z));
  function puff(at,count=7){
    for(let k=0;k<count;k++){
      const q=puffState[np];np=(np+1)%PUFF;
      const a=Math.random()*Math.PI*2,sp=.35+Math.random()*.5;
      q.life=q.s=.6+Math.random()*.3;q.p.copy(at);q.v.set(Math.cos(a)*sp,.5+Math.random()*.6,Math.sin(a)*sp);
    }
    puffs.visible=true;
  }
  const api={
    // A few leaves of the given colours drift down from point.
    leaves(point,palette,count=5){
      for(let k=0;k<count;k++){
        const l=leafState[nl];leaves.setColorAt(nl,color.set(palette[Math.floor(Math.random()*palette.length)]));nl=(nl+1)%LEAVES;
        l.life=1;l.rest=0;l.p.copy(point).add(new T.Vector3((Math.random()-.5)*.4,-.05-Math.random()*.15,(Math.random()-.5)*.4));
        l.v.set((Math.random()-.5)*.3,-.35-Math.random()*.25,(Math.random()-.5)*.3);l.phase=Math.random()*6;
        l.r.set(Math.random()*3,Math.random()*6,Math.random()*3);l.spin.set(2+Math.random()*3,1+Math.random()*2,2+Math.random()*3);
      }
      leaves.instanceColor.needsUpdate=true;leaves.visible=true;
    },
    // Clumps of snow tumble off from point (with a little sideways shove).
    snow(point,count=3,push=new T.Vector3()){
      for(let k=0;k<count;k++){
        const c=clumpState[nc];nc=(nc+1)%CLUMPS;
        c.life=1;c.s=.6+Math.random()*.8;c.p.copy(point).add(new T.Vector3((Math.random()-.5)*.25,-Math.random()*.08,(Math.random()-.5)*.25));
        c.v.copy(push).add(new T.Vector3((Math.random()-.5)*.3,Math.random()*.2,(Math.random()-.5)*.3));
        c.r.set(Math.random()*6,Math.random()*6,0);c.spin.set(Math.random()*4,Math.random()*4,0);
      }
      // A fine dusting puffs out where it breaks loose.
      puff(point,4);
      clumps.visible=true;
    },
    update(dt,wind=0){
      if(leaves.visible){
        let alive=false;
        leafState.forEach((l,i)=>{
          if(l.life<=0)return;alive=true;
          const ground=floor(l.p.x,l.p.z)+.012;
          if(l.p.y>ground){
            l.phase+=dt*3.2;
            l.p.x+=(l.v.x+Math.sin(l.phase)*.45+wind*.03)*dt;l.p.z+=(l.v.z+Math.cos(l.phase*.8)*.3)*dt;l.p.y+=l.v.y*dt;
            l.r.x+=l.spin.x*dt;l.r.y+=l.spin.y*dt;l.r.z+=l.spin.z*dt;
          }else{l.p.y=ground;l.r.x=-Math.PI/2;l.r.z=0;l.rest+=dt;if(l.rest>2.5)l.life=Math.max(0,l.life-dt*2)}
          pose.position.copy(l.p);pose.rotation.copy(l.r);pose.scale.setScalar(Math.min(1,l.life*2));pose.updateMatrix();
          leaves.setMatrixAt(i,l.life>0?pose.matrix:hidden);
        });
        leaves.instanceMatrix.needsUpdate=true;if(!alive)leaves.visible=false;
      }
      if(clumps.visible){
        let alive=false;
        clumpState.forEach((c,i)=>{
          if(c.life<=0)return;alive=true;
          c.v.y-=9.8*dt;c.p.addScaledVector(c.v,dt);c.r.x+=c.spin.x*dt;c.r.y+=c.spin.y*dt;
          const ground=floor(c.p.x,c.p.z);
          if(c.p.y<=ground){c.life=0;c.p.y=ground+.02;puff(c.p,6)}
          pose.position.copy(c.p);pose.rotation.copy(c.r);pose.scale.set(c.s,c.s*.75,c.s);pose.updateMatrix();
          clumps.setMatrixAt(i,c.life>0?pose.matrix:hidden);
        });
        clumps.instanceMatrix.needsUpdate=true;if(!alive)clumps.visible=false;
      }
      if(puffs.visible){
        let alive=false;
        puffState.forEach((q,i)=>{
          if(q.life<=0)return;alive=true;
          q.life-=dt;q.v.multiplyScalar(1-dt*3);q.v.y-=.6*dt;q.p.addScaledVector(q.v,dt);
          const k=Math.max(0,q.life/q.s);
          pose.position.copy(q.p);pose.rotation.set(q.life*3,q.life*2,0);pose.scale.setScalar((1.6-k)*k*1.6);pose.updateMatrix();
          puffs.setMatrixAt(i,q.life>0?pose.matrix:hidden);
        });
        puffs.instanceMatrix.needsUpdate=true;if(!alive)puffs.visible=false;
      }
    }
  };
  return api;
}
