// A small shared walking graph keeps long excursions clear of houses, beds and water.
export function createFarmPaths(world){
  const nodes=[];
  for(let x=-8.4;x<=8.4;x+=.6)for(let z=.6;z<=10.2;z+=.6){
    if(world.walkable(x,z))nodes.push({x,z,edges:[]});
  }
  const clear=(a,b)=>{
    const length=Math.hypot(a.x-b.x,a.z-b.z),steps=Math.ceil(length/.18);
    for(let i=0;i<=steps;i++){
      const u=i/Math.max(1,steps),x=a.x+(b.x-a.x)*u,z=a.z+(b.z-a.z)*u;
      if(!world.walkable(x,z))return false;
    }
    return Math.abs(world.height(a.x,a.z)-world.height(b.x,b.z))<length*.55+.05;
  };
  for(let i=0;i<nodes.length;i++)for(let j=i+1;j<nodes.length;j++){
    const a=nodes[i],b=nodes[j],d=Math.hypot(a.x-b.x,a.z-b.z);
    if(d<.9&&clear(a,b)){a.edges.push([j,d]);b.edges.push([i,d])}
  }
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
  return {nodes,route};
}
