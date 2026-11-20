import * as T from 'three';
import {Reflector} from 'three/addons/objects/Reflector.js';
import {quality} from './mobile-quality.js';

export function makeWater(height,level){
  const geometry=new T.PlaneGeometry(10,9,136,120);
  const positions=geometry.attributes.position,depth=[];
  for(let i=0;i<positions.count;i++)depth.push(level-height(10+positions.getX(i),6.1-positions.getY(i)));
  geometry.setAttribute('bedDepth',new T.Float32BufferAttribute(depth,1));
  const water=new Reflector(geometry,{textureWidth:Math.round(640*quality.reflectionScale),textureHeight:Math.round(512*quality.reflectionScale),multisample:0,clipBias:.001});
  water.rotation.x=-Math.PI/2;water.position.set(10,level,6.1);
  water.userData.impacts=Array.from({length:18},()=>new T.Vector4(0,0,-100,0));
  water.userData.freeze={value:0};
  let nextImpact=0;
  water.userData.splash=(x,z,seconds,power)=>{
    water.userData.impacts[nextImpact].set(x,z,seconds,power);
    nextImpact=(nextImpact+1)%water.userData.impacts.length;
  };
  const savedClear=new T.Color();
  water.userData.reflection=water.material.uniforms;
  water.material=new T.MeshStandardMaterial({color:0xffffff,roughness:.17,transparent:true,depthWrite:true});
  water.receiveShadow=true;water.renderOrder=1;
  // The mirror pass only has to cover the part of the view the pond occupies. Rendering it with
  // the main camera's whole frame spent most of the pass (and of the texture) on reflections
  // nobody can see; cropping the camera to the pond's screen bounds lets everything else clip
  // away and gives the pond the full texture resolution.
  let west=Infinity,east=-Infinity,north=Infinity,south=-Infinity;
  for(let i=0;i<positions.count;i++)if(depth[i]>-.03){
    const x=10+positions.getX(i),z=6.1-positions.getY(i);
    west=Math.min(west,x);east=Math.max(east,x);north=Math.min(north,z);south=Math.max(south,z);
  }
  const crop=new T.OrthographicCamera(),corner=new T.Vector3(),mirrorScale={value:new T.Vector2(1,1)};
  water.userData.mirrorScale=mirrorScale;
  const reflect=water.onBeforeRender;
  const capturedWorld=new T.Matrix4(),capturedProjection=new T.Matrix4();
  let captured=false,lastCapture=-Infinity;
  water.onBeforeRender=function(renderer,scene,camera){
    // Only the reflected image is cached; surface ripples still animate every frame. Camera
    // motion and zoom invalidate it immediately so the mirror never slides during an orbit.
    const now=performance.now()/1000;
    const viewChanged=!captured||!capturedWorld.equals(camera.matrixWorld)||!capturedProjection.equals(camera.projectionMatrix);
    if(quality.reflectionInterval>0&&!viewChanged&&now-lastCapture<quality.reflectionInterval)return;
    const sourceCamera=camera;
    let l=1,r=-1,b=1,t=-1;
    for(const x of [west,east])for(const z of [north,south]){
      corner.set(x,level,z).project(camera);
      l=Math.min(l,corner.x);r=Math.max(r,corner.x);b=Math.min(b,corner.y);t=Math.max(t,corner.y);
    }
    l=Math.max(-1,l-.04);r=Math.min(1,r+.04);b=Math.max(-1,b-.04);t=Math.min(1,t+.04);
    if(r<=l||t<=b)return;
    const cx=(camera.right+camera.left)/2,dx=(camera.right-camera.left)/(2*camera.zoom);
    const cy=(camera.top+camera.bottom)/2,dy=(camera.top-camera.bottom)/(2*camera.zoom);
    crop.left=cx+l*dx;crop.right=cx+r*dx;crop.bottom=cy+b*dy;crop.top=cy+t*dy;
    crop.near=camera.near;crop.far=camera.far;crop.updateProjectionMatrix();
    crop.matrixWorld.copy(camera.matrixWorld);
    mirrorScale.value.set(2/(r-l),2/(t-b));  // keeps the ripple distortion the same size on screen
    camera=crop;
    const background=scene.background;
    const alpha=renderer.getClearAlpha();renderer.getClearColor(savedClear);
    scene.background=null;renderer.setClearColor(0,0);
    try{
      reflect.call(this,renderer,scene,camera);
      capturedWorld.copy(sourceCamera.matrixWorld);capturedProjection.copy(sourceCamera.projectionMatrix);
      // Carry the fractional interval forward rather than falling to 20 Hz when a nominal
      // 60 Hz device supplies 16.6 ms timestamps instead of exactly 1000/60 ms.
      lastCapture=quality.reflectionInterval>0&&!viewChanged?now-(now-lastCapture)%quality.reflectionInterval:now;
      captured=true;
    }finally{
      scene.background=background;renderer.setClearColor(savedClear,alpha);
    }
  };
  return water;
}

// Advected, differently oriented noise patches have finite crests and no common wavelength.
const waves=`
  float pondHash(vec2 q){
    vec3 p=fract(q.xyx*vec3(.1031,.1030,.0973));p+=dot(p,p.yzx+33.33);
    return fract((p.x+p.y)*p.z);
  }
  vec3 pondNoise(vec2 p){
    vec2 i=floor(p),f=fract(p),u=f*f*f*(f*(f*6.-15.)+10.);
    vec2 du=30.*f*f*(f-1.)*(f-1.);
    float a=pondHash(i),b=pondHash(i+vec2(1,0)),c=pondHash(i+vec2(0,1)),d=pondHash(i+1.);
    float k=a-b-c+d;
    return vec3(a+(b-a)*u.x+(c-a)*u.y+k*u.x*u.y-.5,
      du.x*(b-a+k*u.y),du.y*(c-a+k*u.x));
  }
  vec3 waterWaves(vec2 q,float t,float windPower){
    vec3 total=vec3(0.);
    mat2 axes=mat2(.86,.51,-.51,.86);
    float freq=.88,amp=.045;
    for(int i=0;i<4;i++){
      mat2 m=mat2(1.,0.,0.,1.48)*axes*freq;
      vec3 n=pondNoise(m*q+vec2(-.28,.17)*t*(.7+.24*float(i))+vec2(float(i)*31.71));
      total+=amp*vec3(n.x,n.yz*m);
      axes=axes*mat2(.48,.877,-.877,.48);freq*=2.03;amp*=.43;
    }
    return total*(.34+windPower*1.12);
  }`;
export function shadeWater(shader,water){
  const capture=water.userData.reflection;
  shader.uniforms.pondIce=water.userData.freeze;
  Object.assign(shader.uniforms,{impacts:{value:water.userData.impacts},reflectionMap:capture.tDiffuse,reflectionMatrix:capture.textureMatrix,mirrorScale:water.userData.mirrorScale,radianceMap:{value:water.userData.skyTexture}});
  shader.vertexShader=waves+'uniform float pondIce; attribute float bedDepth; varying float depthBelow; varying vec4 mirrorCoord; uniform mat4 reflectionMatrix;\n'+shader.vertexShader.replace('#include <begin_vertex>',`
    #include <begin_vertex>
    vec3 base=(modelMatrix*vec4(position,1.)).xyz;
    float bank=smoothstep(.0,.24,bedDepth)*(1.-smoothstep(14.45,15.,base.x));
    transformed.z+=waterWaves(base.xz,elapsed,breeze).x*bank*(1.-pondIce);
    depthBelow=bedDepth;mirrorCoord=reflectionMatrix*vec4(transformed,1.);`);
  shader.fragmentShader=waves+'uniform float pondIce; uniform vec2 mirrorScale; uniform vec4 impacts[18]; uniform sampler2D radianceMap; uniform sampler2D reflectionMap; varying float depthBelow; varying vec4 mirrorCoord;\n'+shader.fragmentShader;
  shader.fragmentShader=shader.fragmentShader.replace('#include <color_fragment>',`
    #include <color_fragment>
    vec2 q=landPosition.xz;
    float depth=max(0.,depthBelow);
    vec2 slope=waterWaves(q,elapsed,breeze).yz;
    float footprint=max(length(dFdx(q)),length(dFdy(q)));
    float resolved=1.-smoothstep(.022,.11,footprint);
    vec3 fine=pondNoise(q*vec2(23.,18.)+vec2(-1.1,.75)*elapsed);
    slope+=fine.yz*.024*resolved*breeze;
    float unresolved=(1.-resolved)*.004*breeze;
    for(int i=0;i<18;i++){
      float age=elapsed-impacts[i].z;
      if(age>=0.&&age<1.2){
        vec2 delta=q-impacts[i].xy;float r=length(delta),crest=r-age*.78;
        float pulse=sin(crest*57.)*exp(-abs(crest)*22.)*(1.-smoothstep(.0,1.2,age));
        slope+=delta/max(.016,r)*pulse*impacts[i].w;
      }
    }
    slope*=1.-pondIce;unresolved*=1.-pondIce;
    vec3 waterNormal=normalize(vec3(-slope.x,1.,-slope.y));
    float shallow=exp(-7.5*depth);
    diffuseColor.rgb=mix(vec3(.003,.020,.038),vec3(.07,.146,.132),shallow);
    diffuseColor.a=mix(.85,.36,shallow);
    if(storybook>.5)diffuseColor.a=mix(diffuseColor.a,mix(.97,.67,shallow),storyDay);
    if(pondIce>0.){
      vec2 cell=floor(q*1.3),local=fract(q*1.3);
      float nearest=10.,second=10.;
      for(int ix=-1;ix<=1;ix++)for(int iz=-1;iz<=1;iz++){
        vec2 offset=vec2(float(ix),float(iz));
        vec2 seed=vec2(pondHash(cell+offset),pondHash(cell+offset+19.7));
        float dist=length(offset+seed-local);
        if(dist<nearest){second=nearest;nearest=dist;}else second=min(second,dist);
      }
      float fracture=1.-smoothstep(.008,.038,second-nearest);
      float frost=smoothstep(-.3,.38,pondNoise(q*.85).x);
      vec3 iceColor=vec3(.24,.38,.40)+frost*vec3(.20,.23,.23)+fracture*.11;
      diffuseColor.rgb=mix(diffuseColor.rgb,iceColor,pondIce);
      diffuseColor.a=mix(diffuseColor.a,1.,pondIce);
    }
    `);
  shader.fragmentShader=shader.fragmentShader.replace('#include <lights_physical_fragment>',
    'roughnessFactor=clamp(sqrt(roughnessFactor*roughnessFactor+unresolved*.48),.065,.48);roughnessFactor=mix(roughnessFactor,.46,pondIce);\n#include <lights_physical_fragment>');
  shader.fragmentShader=shader.fragmentShader.replace('#include <normal_fragment_maps>',`
    #include <normal_fragment_maps>
    normal=normalize(mat3(viewMatrix)*waterNormal);`);
  shader.fragmentShader=shader.fragmentShader.replace('#include <opaque_fragment>',`
    vec4 capture=texture2D(reflectionMap,clamp(mirrorCoord.xy/mirrorCoord.w+.036*mirrorScale*(mat3(viewMatrix)*vec3(-slope.x,0.,-slope.y)).xy,.002,.998));
    vec3 eye=inverseTransformDirection(vec3(0.,0.,1.),viewMatrix);
    vec3 skyRay=reflect(-eye,waterNormal);
    vec3 sky=texture2D(radianceMap,equirectUv(skyRay)).rgb;
    vec3 reflected=capture.rgb+sky*(1.-capture.a);
    float fresnel=.022+.978*pow(1.-max(0.,dot(waterNormal,eye)),5.);
    vec3 body=outgoingLight-reflectedLight.directSpecular-reflectedLight.indirectSpecular;
    outgoingLight=mix(body,reflected,fresnel*(1.-pondIce*.8))+reflectedLight.directSpecular*mix(.60,.3,pondIce);
    if(storybook>.5){
      vec2 drift=q*vec2(.78,5.7)+vec2(elapsed*-.2,elapsed*.33);
      float marks=pondNoise(drift).x;
      float ripples=smoothstep(.27,.36,marks)*smoothstep(.05,.33,pondNoise(drift*.37+4.3).x);
      vec3 painted=mix(vec3(.020,.111,.176),vec3(.055,.31,.34),shallow);
      painted=mix(painted,reflected,.11+.11*fresnel);
      painted=mix(painted,vec3(.30,.56,.55),ripples*.55);
      outgoingLight=mix(outgoingLight,painted,storyDay*(1.-pondIce)*.92);
    }
    #include <opaque_fragment>`);
}

