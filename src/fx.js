import * as T from 'three';

// Woodcutting effects: chips that spray from an axe blow and bounce on the ground, and the
// firewood a cut-up log splits into, which hops up before flying off to the HUD.
export function createWoodFx(scene,world){
  const wood=new T.MeshStandardMaterial({color:0xd8b07a,roughness:.8});
  const chipGeo=new T.BoxGeometry(.075,.022,.045),CHIPS=72;
  const chips=new T.InstancedMesh(chipGeo,wood,CHIPS);chips.frustumCulled=false;chips.castShadow=true;chips.name='wood-chips';
  const barkTone=[0xd8b07a,0xc89a5e,0x8a6240,0xe4c48f];
  const chipState=Array.from({length:CHIPS},()=>({life:0,p:new T.Vector3(),v:new T.Vector3(),r:new T.Euler(),spin:new T.Vector3(),s:1}));
  const color=new T.Color();chipState.forEach((_,i)=>chips.setColorAt(i,color.setHex(barkTone[i%barkTone.length])));
  // Split firewood: a half-round billet with pale split faces.
  const billet=new T.CylinderGeometry(.06,.06,.26,8,1,false,0,Math.PI);billet.rotateZ(Math.PI/2);
  const logs=new T.InstancedMesh(billet,new T.MeshStandardMaterial({color:0xb98a55,roughness:.85,side:T.DoubleSide}),24);
  logs.frustumCulled=false;logs.castShadow=true;logs.name='firewood';
  const logState=Array.from({length:24},()=>({life:0,p:new T.Vector3(),v:new T.Vector3(),r:new T.Euler(),spin:new T.Vector3(),done:null}));
  const hidden=new T.Matrix4().makeScale(0,0,0);
  for(let i=0;i<CHIPS;i++)chips.setMatrixAt(i,hidden);for(let i=0;i<24;i++)logs.setMatrixAt(i,hidden);
  chips.visible=logs.visible=false;scene.add(chips,logs);
  let nextChip=0,nextLog=0;
  const pose=new T.Object3D();
  return {
    // A spray of chips from point, flung mostly back toward the swing (away from dir).
    chips(point,dir,count=9){
      for(let k=0;k<count;k++){
        const c=chipState[nextChip];nextChip=(nextChip+1)%CHIPS;
        c.life=1.1+Math.random()*.5;c.p.copy(point);c.s=.7+Math.random()*.8;
        const a=Math.random()*Math.PI*2,spread=.9+Math.random()*.9;
        c.v.set(-dir.x*1.1+Math.cos(a)*spread,1.4+Math.random()*1.6,-dir.z*1.1+Math.sin(a)*spread);
        c.r.set(Math.random()*6,Math.random()*6,Math.random()*6);c.spin.set(Math.random()*20-10,Math.random()*20-10,Math.random()*20-10);
      }
      chips.visible=true;
    },
    // Billets pop up from each point; done(position) fires as each reaches the top of its hop.
    firewood(points,done){
      for(const point of points){
        const l=logState[nextLog];nextLog=(nextLog+1)%24;
        l.life=.55;l.p.copy(point);l.v.set((Math.random()-.5)*.8,2.6+Math.random()*.6,(Math.random()-.5)*.8);
        l.r.set(0,Math.random()*6,0);l.spin.set(Math.random()*8-4,Math.random()*6-3,Math.random()*8-4);l.done=done;
      }
      logs.visible=true;
    },
    update(dt){
      if(chips.visible){
        let alive=false;
        chipState.forEach((c,i)=>{
          if(c.life<=0)return;
          c.life-=dt;alive=true;
          c.v.y-=9.8*dt;c.p.addScaledVector(c.v,dt);
          const floor=world.stand(c.p.x,c.p.z)+.01;
          if(c.p.y<floor){c.p.y=floor;c.v.multiplyScalar(.35);c.v.y=Math.abs(c.v.y)*.4;c.spin.multiplyScalar(.5)}
          c.r.x+=c.spin.x*dt;c.r.y+=c.spin.y*dt;c.r.z+=c.spin.z*dt;
          pose.position.copy(c.p);pose.rotation.copy(c.r);pose.scale.setScalar(c.s*Math.min(1,c.life/.3));pose.updateMatrix();
          chips.setMatrixAt(i,c.life>0?pose.matrix:hidden);
        });
        chips.instanceMatrix.needsUpdate=true;if(!alive)chips.visible=false;
      }
      if(logs.visible){
        let alive=false;
        logState.forEach((l,i)=>{
          if(l.life<=0)return;
          l.life-=dt;alive=true;
          l.v.y-=7*dt;l.p.addScaledVector(l.v,dt);
          l.r.x+=l.spin.x*dt;l.r.y+=l.spin.y*dt;l.r.z+=l.spin.z*dt;
          pose.position.copy(l.p);pose.rotation.copy(l.r);pose.scale.setScalar(Math.min(1,(.55-l.life)/.12+.2));pose.updateMatrix();
          logs.setMatrixAt(i,l.life>0?pose.matrix:hidden);
          if(l.life<=0){const done=l.done;l.done=null;done?.(l.p.clone())}
        });
        logs.instanceMatrix.needsUpdate=true;if(!alive)logs.visible=false;
      }
    }
  };
}
