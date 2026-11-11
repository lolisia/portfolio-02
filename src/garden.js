import * as T from 'three';
import {mergeGeometries} from 'three/addons/utils/BufferGeometryUtils.js';

// Garden flowers for the bed behind the cottage. Each kind is authored base-at-origin like the
// Blender nature meshes, so it bends in the wind from its base and goes bare in winter. Stems
// and blooms are separate kinds placed with the same transform: the instance colour tints the
// bloom without tinting the stem. Vertex colours carry fixed two-tone detail (sunflower discs).
function piece(geometry,color=[1,1,1],matrix=null){
  let g=geometry.index?geometry.toNonIndexed():geometry;
  if(matrix)g.applyMatrix4(matrix);
  if(!g.hasAttribute('uv'))g.setAttribute('uv',new T.Float32BufferAttribute(new Float32Array(g.attributes.position.count*2),2));
  const c=new Float32Array(g.attributes.position.count*3);
  for(let i=0;i<c.length;i+=3)c.set(color,i);
  g.setAttribute('color',new T.Float32BufferAttribute(c,3));
  for(const name of Object.keys(g.attributes))if(!['position','normal','uv','color'].includes(name))g.deleteAttribute(name);
  return g;
}
const m4=()=>new T.Matrix4();
function at(x,y,z,rx=0,ry=0,rz=0,sx=1,sy=1,sz=1){
  return m4().compose(new T.Vector3(x,y,z),new T.Quaternion().setFromEuler(new T.Euler(rx,ry,rz,'YXZ')),new T.Vector3(sx,sy,sz));
}
// A thin curved stem from the origin up to `top`, leaning by `lean` toward (dx,dz).
function stem(parts,top,radius,dx=0,dz=0,color=[1,1,1]){
  const pts=[];for(let i=0;i<=5;i++){const u=i/5;pts.push(new T.Vector3(dx*u*u,top*u,dz*u*u))}
  parts.push(piece(new T.TubeGeometry(new T.CatmullRomCurve3(pts),6,radius,4),color));
  return pts[5];
}
// Strap leaf from the base, arching outward.
function strap(parts,angle,length,width,rise=.6,color=[1,1,1]){
  const shape=new T.PlaneGeometry(width,length,1,4);shape.translate(0,length/2,0);
  const p=shape.attributes.position;
  for(let i=0;i<p.count;i++){const v=p.getY(i)/length;p.setX(i,p.getX(i)*(1-v*.85));p.setZ(i,v*v*length*(1-rise))}
  shape.computeVertexNormals();
  parts.push(piece(shape,color,at(0,0,0,0,angle,0)));
}
function build(parts){const g=mergeGeometries(parts);g.computeBoundingSphere();return g}

export function gardenKinds(){
  const kinds=new Map(),rng=(()=>{let s=7741;return()=>((s=(Math.imul(s,1664525)+1013904223)>>>0)/4294967296)})();
  const add=(name,parts,spec)=>kinds.set(name,{geometry:build(parts),...spec});
  const stemSpec={material:'grass',plant:true,sway:.22},bloomSpec={material:'petal',plant:true,sway:.22};

  // Tulip: one stem with two strap leaves, and a closed cup of six petals on top.
  {
    const stems=[],blooms=[];
    const tip=stem(stems,.34,.009,.02,.01);
    strap(stems,.4,.2,.05,.7);strap(stems,3.4,.17,.045,.6);
    for(let i=0;i<6;i++){
      const petal=new T.SphereGeometry(.03,6,6,0,Math.PI,0,Math.PI);petal.scale(1,1.9,.55);
      blooms.push(piece(petal,[1,1,1],at(tip.x,tip.y+.045,tip.z,.18*(i%2?1:.6),i*Math.PI/3,0).multiply(at(0,0,.012))));
    }
    add('tulipStem',stems,stemSpec);add('tulipBloom',blooms,bloomSpec);
  }
  // Lavender: a tuft of wiry stems, each topped by a dense purple spike.
  {
    const stems=[],blooms=[];
    for(let i=0;i<13;i++){
      const a=i*2.4+rng()*.5,lean=.05+rng()*.09,top=.26+rng()*.12;
      const tip=stem(stems,top,.004,Math.sin(a)*lean,Math.cos(a)*lean);
      for(let k=0;k<5;k++){
        const bud=new T.IcosahedronGeometry(.013-k*.0012,0);bud.scale(1,1.5,1);
        blooms.push(piece(bud,[1,1,1],at(tip.x*(1+k*.04),tip.y+.005+k*.022,tip.z*(1+k*.04))));
      }
    }
    for(let i=0;i<6;i++)strap(stems,i*1.05,.11,.012,.4);
    add('lavenderStem',stems,{...stemSpec,sway:.3});add('lavenderBloom',blooms,{...bloomSpec,sway:.3});
  }
  // Sunflower: a tall stalk with broad leaves and a heavy head turned to the viewer; the brown
  // disc and the ring of yellow rays are baked in vertex colour.
  {
    const stems=[],blooms=[];
    const tip=stem(stems,.98,.018,.03,.06);
    for(const [y,a,s] of [[.28,.3,1],[.46,2.6,.95],[.63,4.6,.85],[.8,1.4,.7]]){
      const leaf=new T.SphereGeometry(.075*s,7,5);leaf.scale(1,.12,1.35);leaf.translate(0,0,.1*s);
      stems.push(piece(leaf,[1,1,1],at(0,y,0,-.35,a,0)));
    }
    const head=at(tip.x,tip.y,tip.z,-.55,0,0);
    const disc=new T.CylinderGeometry(.075,.08,.035,14);disc.rotateX(Math.PI/2);
    blooms.push(piece(disc,[.32,.19,.08],head));
    for(let i=0;i<18;i++){
      const ray=new T.SphereGeometry(.024,5,4);ray.scale(1,2.6,.25);ray.translate(0,.12,0);
      blooms.push(piece(ray,[1,.78,.12],head.clone().multiply(at(0,0,-.004,0,0,i*Math.PI/9+(i%2)*.1))));
    }
    add('sunflowerStem',stems,{...stemSpec,sway:.12});add('sunflowerBloom',blooms,{...bloomSpec,sway:.12});
  }
  // Foxglove: a spike of nodding bells, largest at the bottom, on a leafy rosette.
  {
    const stems=[],blooms=[];
    const tip=stem(stems,.62,.008,0,.015);
    for(let i=0;i<7;i++)strap(stems,i*.9,.15,.04,.75);
    for(let k=0;k<14;k++){
      const u=k/13,y=.32+u*.29,a=k*2.2,size=1.15-u*.65;
      const bell=new T.CylinderGeometry(.018*size,.009*size,.05*size,7,1,true);bell.translate(0,-.025*size,0);
      blooms.push(piece(bell,[1,1,1],at(Math.sin(a)*.025+tip.x*u,y,Math.cos(a)*.025+tip.z*u,1.1,a,0)));
    }
    const bud=new T.ConeGeometry(.01,.05,5);blooms.push(piece(bud,[.55,.75,.4],at(tip.x,tip.y+.02,tip.z)));
    add('foxgloveStem',stems,stemSpec);add('foxgloveBloom',blooms,bloomSpec);
  }
  // Rose: a layered bloom of curled petals, scattered over a small bush.
  {
    const blooms=[];
    for(let ring=0;ring<3;ring++)for(let i=0;i<5;i++){
      const petal=new T.SphereGeometry(.022-ring*.004,6,5,0,Math.PI,0,Math.PI*.6);petal.scale(1,1,.5);
      blooms.push(piece(petal,[1,1,1],at(0,.01,0,-.9+ring*.35,i*1.257+ring*.6,0).multiply(at(0,0,.008+.006*(2-ring)))));
    }
    add('roseBloom',blooms,{...bloomSpec,sway:.05});
  }
  return kinds;
}
