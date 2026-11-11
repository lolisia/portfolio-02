import * as T from 'three';

// Linear HDR sky shared by the lighting probe and the water reflection capture.
export function createSky(renderer,scene,water){
  const width=128,height=64,data=new Float32Array(width*height*4);
  const sky=new T.DataTexture(data,width,height,T.RGBAFormat,T.FloatType);
  sky.mapping=T.EquirectangularReflectionMapping;sky.colorSpace=T.LinearSRGBColorSpace;
  sky.minFilter=sky.magFilter=T.LinearFilter;sky.wrapS=T.RepeatWrapping;
  const pmrem=new T.PMREMGenerator(renderer);
  let probe;
  const zenith=new T.Color(),horizon=new T.Color(),land=new T.Color(),dir=new T.Vector3(),pixel=new T.Color(),sunDir=new T.Vector3();
  return (time,weather,sun)=>{
    zenith.copy(time.color([0x578db7,0x518ac3,0x7677a8,0x131f37,0x4f4a8c]));
    horizon.copy(time.color([0xffdcaa,0xdbedf1,0xffae94,0x34445b,0xff7f3c]));
    land.copy(time.color([0x697153,0x737962,0x766552,0x161e21]));
    sunDir.copy(sun.position).normalize();
    for(let j=0;j<height;j++)for(let i=0;i<width;i++){
      const latitude=((j+.5)/height-.5)*Math.PI,angle=((i+.5)/width-.5)*Math.PI*2;
      dir.set(Math.cos(latitude)*Math.cos(angle),Math.sin(latitude),Math.cos(latitude)*Math.sin(angle));
      pixel.copy(horizon).lerp(dir.y>=0?zenith:land,1-Math.exp(-Math.abs(dir.y)*3.8));
      const clouds=.5+.25*Math.sin(dir.x*13+dir.y*8+2*Math.cos(dir.z*11))+.25*Math.cos(dir.z*17+dir.x*6);
      const veil=T.MathUtils.smoothstep(clouds,.54-weather*.13,.9)*Math.max(0,dir.y);
      pixel.lerp(horizon,.55*veil);
      const alignment=Math.max(0,dir.dot(sunDir));
      const glow=(2.2*alignment**24+6*alignment**750)*sun.intensity*.42;
      pixel.r+=sun.color.r*glow;pixel.g+=sun.color.g*glow;pixel.b+=sun.color.b*glow;
      pixel.multiplyScalar((1-.19*weather)*(1-.75*time.night));
      const k=4*(i+j*width);pixel.toArray(data,k);data[k+3]=1;
    }
    sky.needsUpdate=true;
    probe=pmrem.fromEquirectangular(sky,probe);
    scene.environment=probe.texture;scene.environmentIntensity=.63;
    water.userData.skyTexture=sky;
  };
}
