// Grid path finding over an occupancy test: A* on an 8-connected grid of open nodes, then
// string-pulled with line-of-sight checks so walkers take straight runs between corners
// instead of the grid's zig-zags, and never cut through anything solid.
export function createGridPaths({x0,x1,z0,z1,step=.3,open,link=()=>true}){
  // Occupancy, sampled once at half the node spacing; lookups are nearest-cell.
  const fine=step/2,fx=Math.floor((x1-x0)/fine)+1,fz=Math.floor((z1-z0)/fine)+1,grid=new Uint8Array(fx*fz);
  for(let j=0;j<fz;j++)for(let i=0;i<fx;i++)grid[j*fx+i]=open(x0+i*fine,z0+j*fine)?1:0;
  const free=(x,z)=>{
    const i=Math.round((x-x0)/fine),j=Math.round((z-z0)/fine);
    return i>=0&&j>=0&&i<fx&&j<fz&&grid[j*fx+i]===1;
  };
  const clear=(a,b)=>{
    const n=Math.ceil(Math.hypot(b.x-a.x,b.z-a.z)/(fine*.7));
    for(let k=1;k<=n;k++){const u=k/n;if(!free(a.x+(b.x-a.x)*u,a.z+(b.z-a.z)*u))return false}
    return link(a,b);
  };
  const nodes=[],cells=new Map();
  for(let i=0,x=x0;x<=x1+1e-6;i++,x=x0+i*step)for(let j=0,z=z0;z<=z1+1e-6;j++,z=z0+j*step){
    if(free(x,z)){cells.set(i+','+j,nodes.length);nodes.push({x,z,i,j,edges:[]})}
  }
  nodes.forEach((a,ia)=>{
    for(const [di,dj] of [[1,0],[0,1],[1,1],[1,-1]]){
      const ib=cells.get((a.i+di)+','+(a.j+dj));if(ib===undefined)continue;
      const b=nodes[ib];if(clear(a,b)){const d=Math.hypot(a.x-b.x,a.z-b.z);a.edges.push([ib,d]);b.edges.push([ia,d])}
    }
  });
  // Nearest node in plain sight of p (else simply the nearest).
  function closest(p){
    const near=[];
    for(let i=0;i<nodes.length;i++){const d=Math.hypot(nodes[i].x-p.x,nodes[i].z-p.z);if(d<3)near.push([d,i])}
    if(!near.length)for(let i=0;i<nodes.length;i++)near.push([Math.hypot(nodes[i].x-p.x,nodes[i].z-p.z),i]);
    near.sort((a,b)=>a[0]-b[0]);
    for(let k=0;k<Math.min(near.length,20);k++)if(clear(p,nodes[near[k][1]]))return near[k][1];
    return near.length?near[0][1]:-1;
  }
  // A* with a binary heap.
  const g=new Float64Array(nodes.length),from=new Int32Array(nodes.length),seen=new Uint32Array(nodes.length);let stamp=0;
  function search(start,end){
    stamp++;const heap=[[0,start]];g[start]=0;from[start]=-1;seen[start]=stamp;
    const ex=nodes[end].x,ez=nodes[end].z;
    const push=item=>{heap.push(item);let i=heap.length-1;while(i){const p=(i-1)>>1;if(heap[p][0]<=heap[i][0])break;[heap[p],heap[i]]=[heap[i],heap[p]];i=p}};
    const pop=()=>{const top=heap[0],last=heap.pop();if(heap.length){heap[0]=last;let i=0;for(;;){const l=2*i+1,r=l+1;let m=i;if(l<heap.length&&heap[l][0]<heap[m][0])m=l;if(r<heap.length&&heap[r][0]<heap[m][0])m=r;if(m===i)break;[heap[m],heap[i]]=[heap[i],heap[m]];i=m}}return top};
    while(heap.length){
      const [,cur]=pop();
      if(cur===end){const path=[];for(let i=end;i!==-1;i=from[i])path.unshift(nodes[i]);return path}
      for(const [next,d] of nodes[cur].edges){
        const cost=g[cur]+d;
        if(seen[next]!==stamp||cost<g[next]){seen[next]=stamp;g[next]=cost;from[next]=cur;push([cost+Math.hypot(nodes[next].x-ex,nodes[next].z-ez),next])}
      }
    }
    return null;
  }
  // Route from a point to a point: [waypoint..., goal], smoothed by line of sight.
  function route(a,b){
    const start=closest(a),end=closest(b);if(start<0||end<0)return [];
    const found=search(start,end);if(!found)return [];
    const pts=[{x:a.x,z:a.z},...found.map(n=>({x:n.x,z:n.z})),{x:b.x,z:b.z}];
    const out=[];let i=0;
    while(i<pts.length-1){
      let j=pts.length-1;while(j>i+1&&!clear(pts[i],pts[j]))j--;
      out.push(pts[j]);i=j;
    }
    return out;
  }
  return {nodes,route,closest:p=>{const i=closest(p);return i<0?null:nodes[i]},free,clear};
}
