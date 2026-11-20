import * as T from 'three';
import {mergeGeometries} from 'three/addons/utils/BufferGeometryUtils.js';

// Farm crop meshes for the vegetable beds, authored base-at-origin like the garden flowers so
// they sway from the ground. Vertex colours carry fixed detail; the instance colour is free for
// ripening (farm.js lerps it from a young tint to white as the crop grows).
function piece(geometry,color=[1,1,1],matrix=null){
  const g=geometry.index?geometry.toNonIndexed():geometry;
  if(matrix)g.applyMatrix4(matrix);
  if(!g.hasAttribute('uv'))g.setAttribute('uv',new T.Float32BufferAttribute(new Float32Array(g.attributes.position.count*2),2));
  const c=new Float32Array(g.attributes.position.count*3);
  for(let i=0;i<c.length;i+=3)c.set(color,i);
  g.setAttribute('color',new T.Float32BufferAttribute(c,3));
  for(const name of Object.keys(g.attributes))if(!['position','normal','uv','color'].includes(name))g.deleteAttribute(name);
  return g;
}
function at(x,y,z,rx=0,ry=0,rz=0,sx=1,sy=1,sz=1){
  return new T.Matrix4().compose(new T.Vector3(x,y,z),new T.Quaternion().setFromEuler(new T.Euler(rx,ry,rz,'YXZ')),new T.Vector3(sx,sy,sz));
}
function stem(parts,top,radius,dx,dz,color){
  const pts=[];for(let i=0;i<=5;i++){const u=i/5;pts.push(new T.Vector3(dx*u*u,top*u,dz*u*u))}
  parts.push(piece(new T.TubeGeometry(new T.CatmullRomCurve3(pts),6,radius,4),color));
  return pts[5];
}
function build(parts){const g=mergeGeometries(parts);g.computeBoundingSphere();return g}

export function cropKinds(){
  const kinds=new Map(),rng=(()=>{let s=5113;return()=>((s=(Math.imul(s,1664525)+1013904223)>>>0)/4294967296)})();
  // Wheat: a tuft of stalks, each with a narrow leaf and a plump ear of paired grains.
  {
    const parts=[];
    for(let i=0;i<9;i++){
      const a=i*2.4+rng()*.6,lean=.025+rng()*.05,top=.36+rng()*.1;
      const tip=stem(parts,top,.0045,Math.sin(a)*lean,Math.cos(a)*lean,[.86,.78,.42]);
      const leaf=new T.PlaneGeometry(.018,.16,1,3);leaf.translate(0,.08,0);
      const p=leaf.attributes.position;
      for(let k=0;k<p.count;k++){const v=p.getY(k)/.16;p.setX(k,p.getX(k)*(1-v*.8));p.setZ(k,v*v*.07)}
      leaf.computeVertexNormals();
      parts.push(piece(leaf,[.74,.72,.38],at(0,.05+rng()*.06,0,0,a+1.6,0)));
      for(let k=0;k<7;k++)for(const side of [-1,1]){
        const grain=new T.SphereGeometry(.0085,5,4);grain.scale(1,1.7,1);
        parts.push(piece(grain,[1,.84,.46],at(tip.x+side*.006,tip.y+.008+k*.013,tip.z,0,a,side*.35)));
      }
      for(let k=0;k<4;k++){
        const awn=new T.CylinderGeometry(.0009,.0009,.06,3);awn.translate(0,.03,0);
        parts.push(piece(awn,[.95,.86,.55],at(tip.x,tip.y+.06+k*.01,tip.z,0,a+k*1.6,.35)));
      }
    }
    kinds.set('wheatStalks',{geometry:build(parts),material:'grass',plant:true,sway:.28});
  }
  // Pumpkin: a low vine of broad lobed leaves, and a ribbed fruit with a woody stalk.
  {
    const leaves=[];
    for(let i=0;i<6;i++){
      const a=i*1.05+rng()*.3,r=.08+rng()*.06,h=.08+rng()*.06;
      stem(leaves,h,.006,Math.sin(a)*r,Math.cos(a)*r,[.55,.66,.3]);
      const leaf=new T.CircleGeometry(.075,9);
      const p=leaf.attributes.position;
      for(let k=0;k<p.count;k++){
        const x=p.getX(k),y=p.getY(k),ang=Math.atan2(y,x),lobe=1+.18*Math.cos(ang*5);
        p.setXYZ(k,x*lobe,y*lobe,-.25*(x*x+y*y)/.0056*.03);
      }
      leaf.computeVertexNormals();leaf.rotateX(-Math.PI/2+.35);
      leaves.push(piece(leaf,[.24,.42,.16],at(Math.sin(a)*r,h+.005,Math.cos(a)*r,0,a,0)));
    }
    for(let i=0;i<3;i++){
      const a=i*2.1+.4;
      const pts=[0,1,2,3,4].map(k=>new T.Vector3(Math.sin(a+k*.5)*(.05+k*.04),.03+.02*Math.sin(k*1.9),Math.cos(a+k*.5)*(.05+k*.04)));
      leaves.push(piece(new T.TubeGeometry(new T.CatmullRomCurve3(pts),10,.004,4),[.55,.68,.3]));
    }
    kinds.set('pumpkinVine',{geometry:build(leaves),material:'grass',plant:true,sway:.08});
    const fruit=[];
    const body=new T.SphereGeometry(.13,18,12);
    const p=body.attributes.position;
    for(let k=0;k<p.count;k++){
      const x=p.getX(k),y=p.getY(k),z=p.getZ(k),ang=Math.atan2(z,x),rib=1-.07*Math.abs(Math.sin(ang*5));
      p.setXYZ(k,x*rib*1.15,y*.78+.1,z*rib*1.15);
    }
    body.computeVertexNormals();
    fruit.push(piece(body,[1,1,1]));
    const cap=new T.CylinderGeometry(.012,.02,.06,6);cap.translate(0,.03,0);
    fruit.push(piece(cap,[.42,.34,.2],at(0,.19,0,.2,0,.15)));
    kinds.set('pumpkinFruit',{geometry:build(fruit),material:'petal',plant:true,sway:0});
  }
  // Tomato: a staked bush with clusters of round fruit.
  {
    const bush=[];
    const stake=new T.CylinderGeometry(.008,.01,.5,5);stake.translate(0,.25,0);
    bush.push(piece(stake,[.62,.48,.32],at(.035,0,0)));
    for(let i=0;i<14;i++){
      const a=i*2.4,y=.1+i*.024,r=.04+.03*Math.sin(i);
      const leaf=new T.SphereGeometry(.05,6,4);leaf.scale(1,.28,1.5);leaf.translate(0,0,.05);
      bush.push(piece(leaf,[.3,.5,.22],at(Math.sin(a)*r*.4,y,Math.cos(a)*r*.4,-.3,a,0)));
    }
    stem(bush,.42,.007,.01,.02,[.5,.66,.32]);
    kinds.set('tomatoBush',{geometry:build(bush),material:'grass',plant:true,sway:.15});
    const fruit=[];
    for(let i=0;i<6;i++){
      const a=i*2.1+.3,y=.17+(i%3)*.08;
      const berry=new T.SphereGeometry(.028+.006*(i%2),8,6);berry.scale(1,.88,1);
      fruit.push(piece(berry,[1,1,1],at(Math.sin(a)*.07,y,Math.cos(a)*.07)));
      const calyx=new T.ConeGeometry(.012,.01,5);
      fruit.push(piece(calyx,[.45,.62,.3],at(Math.sin(a)*.07,y+.027,Math.cos(a)*.07)));
    }
    kinds.set('tomatoFruit',{geometry:build(fruit),material:'petal',plant:true,sway:.15});
  }
  return kinds;
}
