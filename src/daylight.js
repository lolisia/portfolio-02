import * as T from 'three';

const keys=[[0,3],[5,3],[6.3,2],[8.4,0],[12.5,1],[16,0],[18.25,2],[20,3],[24,3]];
export function daylight(hour){
  const end=keys.findIndex(([h],i)=>i>0&&h>=hour);
  const [a,from]=keys[end-1],[b,to]=keys[end];
  const f=T.MathUtils.smoothstep(hour,a,b),theta=(hour-6)*Math.PI/12;
  const direction=new T.Vector3(-Math.cos(theta),Math.sin(theta)*.90,-Math.sin(theta)*.48).applyAxisAngle(new T.Vector3(0,1,0),-.20).normalize();
  const night=1-T.MathUtils.smoothstep(direction.y,-.18,.17);
  return {
    direction,night,
    value:values=>T.MathUtils.lerp(values[from],values[to],f),
    color:colors=>new T.Color(colors[from]).lerp(new T.Color(colors[to]),f)
  };
}

