import * as T from 'three';

export function createRain(scene,world){
  const count=1600,vertices=new Float32Array(count*6),speed=new Float32Array(count);
  const geo=new T.BufferGeometry(),attr=new T.BufferAttribute(vertices,3).setUsage(T.DynamicDrawUsage);
  geo.setAttribute('position',attr);
  const colors=new Float32Array(vertices.length),colorAttr=new T.BufferAttribute(colors,3).setUsage(T.DynamicDrawUsage);
  geo.setAttribute('color',colorAttr);
  const drops=new T.LineSegments(geo,new T.LineBasicMaterial({color:0xffffff,vertexColors:true,transparent:true,opacity:.27,depthWrite:false}));
  const size=300,spray=new Float32Array(size*3),velocity=new Float32Array(size*3),life=new Float32Array(size);
  spray.fill(-100);
  const splashGeo=new T.BufferGeometry(),splashAttr=new T.BufferAttribute(spray,3).setUsage(T.DynamicDrawUsage);
  splashGeo.setAttribute('position',splashAttr);
  const splashes=new T.Points(splashGeo,new T.PointsMaterial({size:1.7,color:0xc7dddf,transparent:true,opacity:.53,depthWrite:false}));
  scene.add(drops,splashes);drops.frustumCulled=splashes.frustumCulled=false;
  let cursor=0,lastRing=-1;
  const roofs=world.roofs;
  function reset(i,initial){
    const k=i*6;vertices[k]=Math.random()*30-15;vertices[k+2]=Math.random()*30-15;
    vertices[k+1]=initial?2+Math.random()*14:12+Math.random()*4;speed[i]=8+Math.random()*6;
  }
  for(let i=0;i<count;i++)reset(i,true);
  function sprayAt(x,y,z){
    for(let j=0;j<3;j++){
      const n=cursor++%size,k=n*3;
      spray.set([x,y+.018,z],k);velocity.set([(Math.random()-.5)*1.3,.38+Math.random()*.7,(Math.random()-.5)*1.3],k);life[n]=.17+Math.random()*.10;
    }
  }
  return (dt,seconds,wind,on,night)=>{
    const intensity=Number(on);drops.visible=splashes.visible=intensity>.002;if(intensity<=.002)return;
    splashes.material.opacity=.53*intensity;
    drops.material.opacity=(.33-.06*night)*intensity;const dx=wind*.43,dz=wind*.16;
    for(let i=0;i<count;i++){
      const k=i*6,x=vertices[k]+=dx*dt,y=vertices[k+1]-=speed[i]*dt,z=vertices[k+2]+=dz*dt;
      const h=world.height(x,z);let hit=Math.max(world.waterY,h);
      for(const roof of roofs)if(Math.abs(x-roof.x)<roof.rx&&Math.abs(z-roof.z)<roof.rz)hit=Math.max(hit,roof.y+(roof.rx-Math.abs(x-roof.x))*roof.slope);
      if(y<=hit||x>15||z>15){
        if(y<=hit&&x<=15&&z<=15){
          if(h<world.waterY&&world.water.userData.freeze.value<.15&&seconds-lastRing>.052/Math.max(.01,intensity)){world.water.userData.splash(x,z,seconds,.12);lastRing=seconds}
          if(i%4===0)sprayAt(x,hit,z);
        }
        reset(i,false);
      }
      let light=0;
      if(night>.02){
        for(const lamp of world.lamps){
          const p=lamp.position,dy=y-p.y;
          if(dy>.15||dy< -3.4)continue;
          const dist=(x-p.x)**2+(z-p.z)**2;
          light=Math.max(light,Math.exp(-dist*.82)*night);
        }
      }
      const ambient=.7-.54*night;
      for(const j of [k,k+3]){
        colors[j]=ambient*.67+light*1.75;colors[j+1]=ambient*.80+light*.89;colors[j+2]=ambient+light*.31;
      }
      const tail=.019+speed[i]*.0008;
      vertices[k+3]=vertices[k]-dx*tail;vertices[k+4]=vertices[k+1]+speed[i]*tail;vertices[k+5]=vertices[k+2]-dz*tail;
    }
    for(let i=0;i<size;i++)if(life[i]>0){
      const k=i*3;life[i]-=dt;velocity[k+1]-=6*dt;
      for(let j=0;j<3;j++)spray[k+j]+=velocity[k+j]*dt;
      if(life[i]<=0)spray[k+1]=-100;
    }
    attr.needsUpdate=colorAttr.needsUpdate=splashAttr.needsUpdate=true;
  };
}
