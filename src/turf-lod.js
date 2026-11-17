import * as T from 'three';

// The generated turf has twelve disconnected blades, each made from two quads.
// Merge only their split-normal seams to identify blades; never rely on exporter
// vertex/triangle order. Unfamiliar assets retain their original geometry.
export function mobileTurfGeometry(source){
  const position=source.getAttribute('position'),normal=source.getAttribute('normal'),uv=source.getAttribute('uv'),color=source.getAttribute('color');
  const index=source.index,epsilon=1e-6;
  if(!index||position?.count!==96||normal?.count!==96||uv?.count!==96||index.count!==144||source.morphAttributes.position)return source;
  if(Object.keys(source.attributes).some(name=>!['position','normal','uv','color'].includes(name)))return source;
  const parent=Array.from({length:position.count},(_,i)=>i);
  const find=i=>{while(parent[i]!==i){parent[i]=parent[parent[i]];i=parent[i]}return i};
  const join=(a,b)=>{parent[find(a)]=find(b)};
  const welded=new Map();
  for(let i=0;i<position.count;i++){
    const key=[position.getX(i),position.getY(i),position.getZ(i)].map(v=>Math.round(v/epsilon)).join(',');
    if(welded.has(key))join(i,welded.get(key));else welded.set(key,i);
  }
  for(let i=0;i<index.count;i+=3){join(index.getX(i),index.getX(i+1));join(index.getX(i),index.getX(i+2))}
  const blades=new Map();
  for(let i=0;i<position.count;i++){
    const root=find(i);if(!blades.has(root))blades.set(root,{vertices:[],triangles:0});blades.get(root).vertices.push(i);
  }
  for(let i=0;i<index.count;i+=3)blades.get(find(index.getX(i))).triangles++;
  if(blades.size!==12)return source;
  const data={position:[],normal:[],uv:[],color:[]};
  const vector=(attribute,i)=>new T.Vector3().fromBufferAttribute(attribute,i);
  const append=(p,n,u,v,c)=>{data.position.push(p.x,p.y,p.z);data.normal.push(n.x,n.y,n.z);data.uv.push(u,v);data.color.push(...c)};
  const shade=i=>color?Array.from({length:3},(_,c)=>color.getComponent(i,c)):[1,1,1];
  for(const blade of blades.values()){
    const roots=blade.vertices.filter(i=>Math.abs(uv.getY(i)-1)<epsilon).sort((a,b)=>uv.getX(a)-uv.getX(b));
    const tips=blade.vertices.filter(i=>Math.abs(uv.getY(i))<epsilon).sort((a,b)=>uv.getX(a)-uv.getX(b));
    const middle=blade.vertices.filter(i=>Math.abs(uv.getY(i)-.5)<epsilon);
    if(blade.vertices.length!==8||blade.triangles!==4||roots.length!==2||tips.length!==2||middle.length!==4)return source;
    if([roots,tips].some(row=>Math.abs(uv.getX(row[0]))>epsilon||Math.abs(uv.getX(row[1])-1)>epsilon))return source;
    const a=vector(position,roots[0]),b=vector(position,roots[1]),base=a.clone().add(b).multiplyScalar(.5);
    const tip=vector(position,tips[0]).add(vector(position,tips[1])).multiplyScalar(.5);
    if(Math.abs(a.y-b.y)>epsilon||tip.y<=base.y+epsilon)return source;
    // Original widths are 1, .66, .32 along the blade: its area is .66*w*h.
    // A 1.3-wide triangle has almost the same area, retaining ground coverage.
    a.sub(base).multiplyScalar(1.3).add(base);b.sub(base).multiplyScalar(1.3).add(base);
    const tipNormal=vector(normal,tips[0]).add(vector(normal,tips[1])).normalize();
    const tipColor=shade(tips[0]).map((v,c)=>(v+shade(tips[1])[c])*.5);
    append(a,vector(normal,roots[0]),0,1,shade(roots[0]));
    append(b,vector(normal,roots[1]),1,1,shade(roots[1]));
    append(tip,tipNormal,.5,0,tipColor);
  }
  const geometry=new T.BufferGeometry();
  for(const [name,values] of Object.entries(data))geometry.setAttribute(name,new T.Float32BufferAttribute(values,name==='uv'?2:3));
  geometry.setIndex(Array.from({length:36},(_,i)=>i));
  geometry.computeBoundingBox();geometry.computeBoundingSphere();
  return geometry;
}
