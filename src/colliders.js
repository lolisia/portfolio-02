// Flat (XZ) collision world: static circles / oriented boxes for props, and dynamic
// circular bodies for walkers that push each other apart and slide along statics.
export function createColliders(){
  const statics=[],bodies=[];

  // Penetration of a circle (x,z,r) into a static; returns push vector or null.
  function push(o,x,z,r){
    if(o.kind==='circle'){
      const dx=x-o.x,dz=z-o.z,d=Math.hypot(dx,dz),min=o.r+r;
      if(d>=min)return null;
      return d>1e-6?[dx/d*(min-d),dz/d*(min-d)]:[min,0];
    }
    const dx=x-o.x,dz=z-o.z;
    const lx=dx*o.c-dz*o.s,lz=dx*o.s+dz*o.c;
    const cx=Math.max(-o.hx,Math.min(o.hx,lx)),cz=Math.max(-o.hz,Math.min(o.hz,lz));
    let px=lx-cx,pz=lz-cz,d=Math.hypot(px,pz),nx,nz,depth;
    if(d>1e-6){if(d>=r)return null;nx=px/d;nz=pz/d;depth=r-d}
    else{ // centre inside the box: leave through the nearest face
      const ex=o.hx-Math.abs(lx),ez=o.hz-Math.abs(lz);
      if(ex<ez){nx=Math.sign(lx)||1;nz=0;depth=ex+r}else{nx=0;nz=Math.sign(lz)||1;depth=ez+r}
    }
    return [(nx*o.c+nz*o.s)*depth,(-nx*o.s+nz*o.c)*depth];
  }

  return {
    statics,bodies,
    circle(x,z,r,tag=''){statics.push({kind:'circle',x,z,r,tag})},
    box(x,z,w,d,angle=0,tag=''){statics.push({kind:'box',x,z,hx:w/2,hz:d/2,c:Math.cos(angle),s:Math.sin(angle),tag})},
    blocked(x,z,r=0,skip){return statics.some(o=>o.tag!==skip&&push(o,x,z,r))},
    body(x,z,r,mass=1){const b={x,z,r,mass,active:false,ignore:''};bodies.push(b);return b},
    // Settle one body against statics (except its `ignore` tag) and the other active bodies.
    resolve(b){
      if(!b.active)return;
      for(let pass=0;pass<3;pass++){
        for(const o of statics){
          if(o.tag&&o.tag===b.ignore)continue;
          const v=push(o,b.x,b.z,b.r);if(v){b.x+=v[0];b.z+=v[1]}
        }
        for(const other of bodies){
          if(other===b||!other.active)continue;
          const dx=b.x-other.x,dz=b.z-other.z,d=Math.hypot(dx,dz),min=b.r+other.r;
          if(d>=min)continue;
          const share=other.mass/(b.mass+other.mass),k=(min-d)*share;
          if(d>1e-6){b.x+=dx/d*k;b.z+=dz/d*k}else b.x+=k;
        }
      }
    }
  };
}
