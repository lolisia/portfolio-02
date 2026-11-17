import * as T from 'three';
import {quality} from './mobile-quality.js';

function pieceGeometry(petal){
  const s=petal?.65:1;
  const geometry=new T.BufferGeometry();
  geometry.setAttribute('position',new T.Float32BufferAttribute([
    0,0,-1, -.53*s,.12,-.46, -.72*s,.15,.20, -.31*s,.19,.72, 0,.10,petal?.78:1.12,
    .35*s,.17,.76,.70*s,.05,.19,.47*s,.06,-.49,0,.27,0],3));
  const indices=[];for(let i=0;i<8;i++)indices.push(i,(i+1)%8,8);
  geometry.setIndex(indices);geometry.computeVertexNormals();return geometry;
}
export function createSeasons(scene,world,atmosphere){
  const trees=world.perches.slice(0,-world.lamps.length),pose=new T.Object3D(),color=new T.Color();
  const roofs=world.roofs;
  function floor(x,z){
    let y=Math.max(world.waterY,world.height(x,z));
    for(const r of roofs)if(Math.abs(x-r.x)<r.rx&&Math.abs(z-r.z)<r.rz)y=Math.max(y,r.y+(r.rx-Math.abs(x-r.x))*r.slope);
    return y;
  }
  function particles(kind,count,geometry,palette){
    const mesh=new T.InstancedMesh(geometry,new T.MeshStandardMaterial({side:T.DoubleSide,roughness:.85}),count);
    mesh.name=kind;mesh.frustumCulled=false;mesh.visible=false;scene.add(mesh);
    const flakes=kind==='snow',items=[];
    function spawn(item,initial){
      const tree=trees[Math.floor(Math.random()*trees.length)];
      item.x=flakes?Math.random()*30-15:tree.x+(Math.random()-.5)*2;
      item.z=flakes?Math.random()*30-15:tree.z+(Math.random()-.5)*2;
      const base=floor(item.x,item.z),top=flakes?11:Math.max(base+.5,tree.y-.25);
      item.y=initial?T.MathUtils.lerp(base,top,Math.random()):top;
      item.rest=0;
    }
    for(let i=0;i<count;i++){
      const item={phase:Math.random()*6.28,rate:.7+Math.random()*.7,size:(flakes?.028*quality.snowSizeScale:.072)*(.7+Math.random()*.9)};
      spawn(item,true);items.push(item);mesh.setColorAt(i,color.set(palette[i%palette.length]));
    }
    return (active,dt,t,wind,storm)=>{
      const strength=Number(active);mesh.visible=strength>.002;mesh.material.transparent=true;mesh.material.opacity=strength;if(strength<=.002)return;
      mesh.count=flakes?Math.floor(count*(.16+.84*Number(storm))):count;  // Keep gentle snow and blizzard proportional within the profile budget.
      for(let i=0;i<mesh.count;i++){
        const s=items[i],a=s.phase+t*s.rate;
        const base=floor(s.x,s.z)+.035;
        if(s.y>base){
          s.x+=dt*(wind*(flakes?.13:.11)+Math.sin(a)*.33+(Number(storm)*2.4));
          s.z+=dt*(wind*.055+Math.cos(a*.87)*.28);
          s.y-=dt*s.rate*(flakes?(1.07+Number(storm)*1.73):.57);
        }else{s.y=base;s.rest+=dt}
        if(Math.max(Math.abs(s.x),Math.abs(s.z))>15||s.rest>(flakes?.2:1.75))spawn(s,false);
        pose.position.set(s.x,s.y,s.z);pose.rotation.set(s.rest?0:a*.88,a*.5,s.rest?0:Math.sin(a)*.9);
        pose.scale.setScalar(s.size);pose.updateMatrix();mesh.setMatrixAt(i,pose.matrix);
      }
      mesh.instanceMatrix.needsUpdate=true;
    };
  }
  const petals=particles('petals',155,pieceGeometry(true),[0xffbfd1,0xffe0e4,0xe5a3b6]);
  const leaves=particles('leaves',175,pieceGeometry(false),[0xbb602b,0xe79a40,0xa83e26,0xddbb56]);
  const snow=particles('snow',quality.snowCount,new T.IcosahedronGeometry(1,0),[0xf3f9ff,0xe4eef8,0xffffff]);
  const ground=world.ground.geometry.attributes.position,base=new Float32Array(ground.count);
  for(let i=0;i<ground.count;i++)base[i]=ground.getY(i);
  const palettes=[[1.15,1.18,.95],[1,1,1],[1.95,.60,.34],[.79,.87,.83]];
  const tint=new T.Vector3();let amount=0,lastDepth=0;
  return (season,weather,dt,elapsed,time,wind,blend)=>{
    world.water.userData.freeze.value=T.MathUtils.damp(world.water.userData.freeze.value,season===3?1:0,1.1,elapsed);
    if(season===3&&world.water.userData.freeze.value>.995)world.water.userData.freeze.value=1;
    const storm=blend?blend.storm:weather===5?1:0,snowing=blend?blend.snow:weather>=4?1:0;
    petals(season===0,dt,time,wind,storm);leaves(season===2,dt,time,wind,storm);snow(snowing,dt,time,wind,storm);
    // Outside winter a snow cover is gone in a few seconds (rain clears it fastest).
    const thaw=[.14,.24,.09,.002][season];
    const melt=blend?T.MathUtils.lerp(thaw,Math.max(thaw,.3),blend.rain):weather===2?Math.max(thaw,.3):thaw;
    const rate=Number(snowing)*(.016+.017*Number(storm))-(1-Number(snowing))*melt;
    amount=T.MathUtils.clamp(amount+elapsed*rate,0,1);
    if(season===3)amount=T.MathUtils.damp(amount,1,1.25,elapsed);
    if(season===3&&amount>.995)amount=1;
    atmosphere.snowDepth.value=amount;
    atmosphere.winterBare.value=T.MathUtils.lerp(atmosphere.winterBare.value,season===3?1:0,1-Math.exp(-elapsed*1.6));
    if(season===3&&atmosphere.winterBare.value>.995)atmosphere.winterBare.value=1;
    atmosphere.foliageTint.value.lerp(tint.fromArray(palettes[season]),1-Math.exp(-elapsed*2.6));
    if(Math.abs(amount-lastDepth)>.008||(amount===0&&lastDepth!==0)){
      lastDepth=amount;
      for(let i=0;i<ground.count;i++){
        const x=ground.getX(i),z=ground.getZ(i);
        const bank=T.MathUtils.smoothstep(base[i],world.waterY+.015,world.waterY+.3);
        ground.setY(i,base[i]+amount*bank*(.078+.031*Math.sin(x*1.7+Math.cos(z*.91))));
      }
      ground.needsUpdate=true;world.ground.geometry.computeVertexNormals();
    }
  };
}
