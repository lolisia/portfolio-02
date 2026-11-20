// A small shared walking graph keeps long excursions clear of houses, beds and water.
// The default covers the front yard (the chickens' range); {island:true} spans the whole island,
// stairs and terraces included, for the player-driven character.
export function createFarmPaths(world,{island=false}={}){
  const nodes=[],cells=new Map(),step=.6;
  const [x0,x1,z0,z1]=island?[-14.1,14.1,-14.1,14.1]:[-8.4,8.4,.6,10.2];
  for(let i=0,x=x0;x<=x1+1e-6;i++,x=x0+i*step)for(let j=0,z=z0;z<=z1+1e-6;j++,z=z0+j*step){
    if(world.walkable(x,z)){cells.set(i+','+j,nodes.length);nodes.push({x,z,i,j,edges:[]})}
  }
  const clear=(a,b)=>{
    const length=Math.hypot(a.x-b.x,a.z-b.z),steps=Math.ceil(length/.18);
    for(let i=0;i<=steps;i++){
      const u=i/Math.max(1,steps),x=a.x+(b.x-a.x)*u,z=a.z+(b.z-a.z)*u;
      if(!world.walkable(x,z))return false;
    }
    return Math.abs(world.height(a.x,a.z)-world.height(b.x,b.z))<length*.55+.05;
  };
  // Grid neighbours only: at .6 spacing every pair closer than .9 is one of the eight around a node.
  nodes.forEach((a,ia)=>{
    for(const [di,dj] of [[1,0],[0,1],[1,1],[1,-1]]){
      const ib=cells.get((a.i+di)+','+(a.j+dj));if(ib===undefined)continue;
      const b=nodes[ib],d=Math.hypot(a.x-b.x,a.z-b.z);
      if(clear(a,b)){a.edges.push([ib,d]);b.edges.push([ia,d])}
    }
  });
  const closest=p=>{
    // Nearest-first: only line-of-sight test the closest few nodes instead of the whole graph.
    const near=nodes.map((n,i)=>[Math.hypot(n.x-p.x,n.z-p.z),i]).sort((a,b)=>a[0]-b[0]);
    for(let k=0;k<Math.min(near.length,16);k++)if(clear(p,nodes[near[k][1]]))return near[k][1];
    // Standing somewhere off the graph (a ramp, a bank): head for the nearest node anyway;
    // the collision world slides the walker around whatever is in the way.
    return near.length?near[0][1]:-1;
  };
  function route(from,to){
    const start=closest(from),end=closest(to);if(start<0||end<0)return [];
    const cost=new Map([[start,0]]),previous=new Map(),open=new Set([start]);
    while(open.size){
      let current=-1,score=Infinity;
      for(const i of open){const n=nodes[i],h=cost.get(i)+Math.hypot(n.x-nodes[end].x,n.z-nodes[end].z);if(h<score){score=h;current=i}}
      if(current===end){
        const path=[{x:to.x,z:to.z}];let i=end;
        while(i!==start){path.unshift(nodes[i]);i=previous.get(i)}
        path.unshift(nodes[start]);return path;
      }
      open.delete(current);
      for(const [next,d] of nodes[current].edges){const value=cost.get(current)+d;if(value<(cost.get(next)??Infinity)){cost.set(next,value);previous.set(next,current);open.add(next)}}
    }
    return [];
  }
  return {nodes,route,closest:p=>nodes[closest(p)]};
}
