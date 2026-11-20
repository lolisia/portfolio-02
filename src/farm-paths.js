import {createGridPaths} from './pathgrid.js';

// The island's walking graph: open ground keeps a little clearance from every collider (so
// walkers route round houses, beds, trees and fences instead of grinding along them), stays
// out of the water and only links points the slope allows. The default covers the front yard
// (the chickens' range); {island:true} spans the whole island, stairs and terraces included.
export function createFarmPaths(world,{island=false}={}){
  const [x0,x1,z0,z1]=island?[-14.1,14.1,-14.1,14.1]:[-8.4,8.4,.6,10.2];
  return createGridPaths({x0,x1,z0,z1,step:.3,
    open:(x,z)=>world.walkable(x,z)&&!world.colliders.blocked(x,z,.3),
    link:(a,b)=>Math.abs(world.height(a.x,a.z)-world.height(b.x,b.z))<Math.hypot(a.x-b.x,a.z-b.z)*.55+.05});
}
