import * as T from 'three';
import {leafSpray} from './foliage.js';
import {shadeWater} from './water.js';
import {shadeCascade} from './cascade.js';

function field(size,seed){
  const values=new Float32Array(size*size);
  for(let i=0;i<values.length;i++){seed=(Math.imul(seed,1664525)+1013904223)>>>0;values[i]=seed/4294967296}
  return (u,v)=>{
    const x=(u-Math.floor(u))*size,y=(v-Math.floor(v))*size,i=Math.floor(x),j=Math.floor(y);
    let a=x-i,b=y-j;a=a*a*(3-2*a);b=b*b*(3-2*b);
    const at=(m,n)=>values[(n%size)*size+m%size];
    return (1-b)*((1-a)*at(i,j)+a*at(i+1,j))+b*((1-a)*at(i,j+1)+a*at(i+1,j+1));
  };
}
export const TRAMPLE_SLOTS=12;
const coarse=field(5,722),fine=field(27,998),grit=field(96,417);
function texture(size,paint,color=false){
  const cv=document.createElement('canvas');cv.width=cv.height=size;
  const ctx=cv.getContext('2d'),data=ctx.createImageData(size,size);
  for(let j=0;j<size;j++)for(let i=0;i<size;i++)
    data.data.set([...paint(i/size,j/size),255],(j*size+i)*4);
  ctx.putImageData(data,0,0);
  const map=new T.CanvasTexture(cv);map.wrapS=map.wrapT=T.RepeatWrapping;
  map.anisotropy=4;if(color)map.colorSpace=T.SRGBColorSpace;return map;
}

const recipes={
  wood:{rough:.78,depth:1.2,relief:(u,v)=>{
    const bend=.045*coarse(u,v)+.015*Math.sin(v*6.283);
    const ring=Math.sin(6.283*(10*(u+bend)+coarse(u*2,v)*1.6));
    return .26*coarse(u*3,v)+.29*(1-Math.pow(.5+.5*ring,5))+.30*fine(u+bend,v*.22)+.15*grit(u,v);
  }},
  bark:{rough:.98,depth:1.9,relief:(u,v)=>.6*fine(u, .15*Math.sin(v*6.283)+u*.08)+.26*coarse(u*3,v)+.14*grit(u,v)},
  stone:{rough:.91,depth:1.6,relief:(u,v)=>.43*coarse(u,v)+.35*fine(u,v)+.22*grit(u,v)},
  clay:{rough:.74,depth:.85,relief:(u,v)=>.26*coarse(u,v)+.18*fine(u,v)+.18*grit(u,v)+.38*Math.cos(u*6.283)**2},
  plaster:{rough:.98,depth:.95,relief:(u,v)=>.32*coarse(u,v)+.33*fine(u,v)+.35*grit(u,v)},
  soil:{rough:.97,depth:1.4,relief:(u,v)=>.45*fine(u*2,v*2)+.3*grit(u,v)+.25*coarse(u*4,v*4)},
  leaf:{rough:.66,depth:.58,relief:(u,v)=>.62*coarse(u,v)+.28*fine(u,v)+.1*grit(u,v)}
};
const cache=new Map();
export function surface(name){
  if(cache.has(name))return cache.get(name);
  const recipe=recipes[name];
  const mat=new T.MeshStandardMaterial({name,flatShading:true,roughness:recipe?.rough??.9});
  if(recipe){
    const h=recipe.relief,n=128;
    mat.map=texture(n,(u,v)=>{const a=183+70*h(u,v);return [a,a,a]},true);
    mat.normalMap=texture(n,(u,v)=>{
      const x=(h(u-1/n,v)-h(u+1/n,v))*recipe.depth,y=(h(u,v+1/n)-h(u,v-1/n))*recipe.depth;
      const scale=127/Math.hypot(x,y,1);return [128+x*scale,128+y*scale,128+scale];
    });
  }
  if(name==='spray'||name==='needle'){
    mat.map=leafSpray(name==='needle');mat.side=T.DoubleSide;mat.shadowSide=T.DoubleSide;
    mat.alphaTest=.29;mat.roughness=.78;
  }
  // Blender nature meshes carry smooth custom normals and a baked shading gradient.
  if(['bark','spray','needle','grass','petal','cabbage'].includes(name)){mat.flatShading=false;mat.vertexColors=true}
  if(['grass','petal','cabbage'].includes(name)){mat.side=T.DoubleSide;mat.shadowSide=T.DoubleSide;mat.roughness=name==='petal'?.6:.82}
  if(name==='iron'){mat.metalness=.55;mat.roughness=.55}
  if(name==='glass'){mat.roughness=.23;mat.emissive.set(0xffac46);mat.emissiveIntensity=.025}
  cache.set(name,mat);return mat;
}

export function createAtmosphere(scene,world){
  const water=world.water;
  const clock={value:0},cloudAmount={value:.72},wind={value:new T.Vector2()},wet={value:0},breeze={value:.3};
  const clouds=texture(256,(u,v)=>{const n=255*(.60*coarse(u,v)+.25*coarse(2*u,2*v)+.12*coarse(4*u,4*v)+.03*fine(u,v));return [n,n,n]});
  const cloudMap={value:clouds};
  const snowDepth={value:0},winterBare={value:0},foliageTint={value:new T.Vector3(1,1,1)};
  const trample={value:Array.from({length:TRAMPLE_SLOTS},()=>new T.Vector4(0,0,1,0))};
  const windVertex=`
    #ifdef USE_INSTANCING
      vec3 wp=(instanceMatrix*vec4(position,1.)).xyz;
      float h=max(0.,wp.y-bendRoot.y);
      float phase=dot(bendRoot.xz,vec2(.39,.23));
      float gust=sin(elapsed*1.37-phase)+.42*sin(elapsed*2.31-phase*.71);
      float bend=bendRoot.w*(bendRoot.w>.1?h:h*h)*gust*breeze;
      mat4 swaying=instanceMatrix;
      swaying[3].xz+=vec2(bend,bend*.36);
      #ifdef TRAMPLE
        // Walkers part the turf around them and leave a slowly recovering trail.
        vec2 parted=vec2(0.);float pressed=0.;
        for(int i=0;i<TRAMPLE;i++){
          vec4 t=trample[i];
          if(t.w<.01)continue;
          vec2 away=wp.xz-t.xy;
          if(abs(away.x)+abs(away.y)>t.z*2.4)continue;
          float dist=length(away);
          float f=t.w*(1.-smoothstep(t.z*.35,t.z*1.7,dist));
          parted+=away/max(dist,.001)*f;pressed=max(pressed,f);
        }
        swaying[3].xz+=parted*h*.85;swaying[3].y-=pressed*h*.5;
      #endif
      #define instanceMatrix swaying
    #endif`;
  function sway(shader,turf=false){
    Object.assign(shader.uniforms,{elapsed:clock,breeze,wet,winterBare});
    if(turf){shader.uniforms.trample=trample;shader.vertexShader=`#define TRAMPLE ${TRAMPLE_SLOTS}
uniform vec4 trample[${TRAMPLE_SLOTS}];
`+shader.vertexShader}
    shader.vertexShader="attribute float plantMask; varying float seasonalPlant; varying float plantRank;\n"+shader.vertexShader.replace("#include <uv_vertex>","#include <uv_vertex>\nseasonalPlant=plantMask;plantRank=fract(dot(instanceMatrix[3].xyz,vec3(16.321,28.735,9.135)));");
    shader.fragmentShader="uniform float winterBare; varying float seasonalPlant; varying float plantRank;\n"+shader.fragmentShader.replace("#include <alphatest_fragment>","#include <alphatest_fragment>\nif(seasonalPlant>.5 && plantRank<winterBare)discard;");
    shader.vertexShader='uniform float elapsed,wet,breeze;\n#ifdef USE_INSTANCING\nattribute vec4 bendRoot;\n#endif\n'+shader.vertexShader.replace('#include <begin_vertex>',windVertex+'\n#include <begin_vertex>');
  }
  const shadowDepth=new T.MeshDepthMaterial({depthPacking:T.RGBADepthPacking});
  shadowDepth.onBeforeCompile=sway;
  const bendingMaterials=new Set();
  scene.traverse(o=>{
    if(!o.isInstancedMesh||!o.geometry.hasAttribute('bendRoot'))return;
    bendingMaterials.add(o.material);
    if(o.material.alphaTest){
      const cutout=shadowDepth.clone();cutout.map=o.material.map;cutout.alphaTest=o.material.alphaTest;
      cutout.side=T.DoubleSide;
      cutout.onBeforeCompile=shader=>{sway(shader)};
      cutout.customProgramCacheKey=()=>o.material.name+'-shadow';o.customDepthMaterial=cutout;
    }else o.customDepthMaterial=shadowDepth;
  });
  const materials=new Set();
  scene.traverse(o=>{if(o.material?.isMeshStandardMaterial)materials.add(o.material)});
  for(const mat of materials){
    const isWater=mat===water.material;
    mat.onBeforeCompile=shader=>{
      if(bendingMaterials.has(mat))sway(shader,mat.name==='grass');
      else shader.vertexShader='uniform float elapsed,wet,breeze;\n'+shader.vertexShader;
      Object.assign(shader.uniforms,{cloudMap,cloudAmount,wind,elapsed:clock,breeze,wet,snowDepth,foliageTint});
      shader.vertexShader='varying vec3 landPosition;\n'+shader.vertexShader.replace('#include <project_vertex>',`
        vec4 land=vec4(transformed,1.);
        #ifdef USE_INSTANCING
          land=instanceMatrix*land;
        #endif
        landPosition=(modelMatrix*land).xyz;
        #include <project_vertex>`);
      shader.fragmentShader='varying vec3 landPosition; uniform sampler2D cloudMap; uniform float cloudAmount,elapsed,wet,breeze; uniform vec2 wind;\n'+shader.fragmentShader;
      shader.fragmentShader=shader.fragmentShader.replace('#include <lights_fragment_begin>',T.ShaderChunk.lights_fragment_begin.replace('getDirectionalLightInfo( directionalLight, directLight );',`
        getDirectionalLightInfo( directionalLight, directLight );
        #if UNROLLED_LOOP_INDEX == 0
        float cover=smoothstep(.31,.66,texture2D(cloudMap,(landPosition.xz+landPosition.y*vec2(.25,-.16))*.024+wind).r);
        directLight.color *= 1.-cover*cloudAmount;
        #endif`));
      shader.fragmentShader=shader.fragmentShader.replace('#include <roughnessmap_fragment>','#include <roughnessmap_fragment>\nroughnessFactor *= 1.-.32*wet;');
      if(mat.alphaTest){
        const direct='RE_Direct( directLight, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );';
        const start=shader.fragmentShader.indexOf('getDirectionalLightInfo( directionalLight, directLight );');
        const index=shader.fragmentShader.indexOf(direct,start);
        shader.fragmentShader=shader.fragmentShader.slice(0,index)+`
            reflectedLight.directDiffuse += directLight.color * diffuseColor.rgb * vec3(.38,.48,.16)
              * (.12+.88*max(0.,-dot(normal,directLight.direction)));
          `+shader.fragmentShader.slice(index);
      }
      if(mat.name==='stone'){
        shader.fragmentShader=shader.fragmentShader.replace('#include <color_fragment>',`
          #include <color_fragment>
          float wetFoot=(1.-smoothstep(.44,.83,landPosition.y))*smoothstep(5.5,7.,landPosition.x)
            *(1.-smoothstep(3.3,4.7,abs(landPosition.z-6.1)));
          diffuseColor.rgb*=1.-wetFoot*.38;`).replace('roughnessFactor *=','roughnessFactor=mix(roughnessFactor,.28,wetFoot);roughnessFactor *=');
      }
      if(['spray','leaf','cone','rock','needle','terrain','grass','cabbage'].includes(mat.name)){
        const influence=mat.name==='needle'?.19:mat.name==='terrain'?.42:1;
        shader.fragmentShader='uniform vec3 foliageTint;\n'+shader.fragmentShader.replace('#include <color_fragment>',
          '#include <color_fragment>\ndiffuseColor.rgb*=mix(vec3(1.),foliageTint,'+influence.toFixed(2)+');');
      }
      if(mat.name==='terrain'){
        shader.uniforms.winterBare=winterBare;
        shader.fragmentShader='uniform float winterBare;\n'+shader.fragmentShader.replace('#include <color_fragment>',`
          #include <color_fragment>
          float soilGrain=dot(diffuseColor.rgb,vec3(.3,.5,.2));
          diffuseColor.rgb=mix(diffuseColor.rgb,vec3(.36,.235,.135)*(soilGrain*1.8+.25),winterBare);`);
      }
      if(mat.name==='spray'){

        shader.fragmentShader=shader.fragmentShader.replace('#include <map_fragment>',`
          #include <map_fragment>
          float blossom=smoothstep(.56,.72,texture2D(cloudMap,landPosition.xz*.28+landPosition.y*.11).r)
            *clamp((foliageTint.g-1.)*5.5,0.,1.);
          diffuseColor.rgb=mix(diffuseColor.rgb,vec3(1.,.69,.80),blossom);`);
      }
      if(!isWater && !['glass','cascade',''].includes(mat.name)){
        shader.fragmentShader='uniform float snowDepth;\n'+shader.fragmentShader.replace('#include <normal_fragment_maps>',`
          #include <normal_fragment_maps>
          vec3 snowNormal=inverseTransformDirection(normal,viewMatrix);
          // Triplanar noise: projecting along the surface normal avoids the streaks a single
          // top-down lookup smears down trunks, cones and walls.
          vec3 tri=pow(abs(snowNormal),vec3(4.));tri/=dot(tri,vec3(1.));
          vec3 q=landPosition;
          #define SNOW_NOISE(s,o) (texture2D(cloudMap,q.yz*s+o).r*tri.x+texture2D(cloudMap,q.xz*s+o).r*tri.y+texture2D(cloudMap,q.xy*s+o).r*tri.z)
          float uneven=SNOW_NOISE(.21,0.)*.6+SNOW_NOISE(.83,.37)*.3+SNOW_NOISE(3.1,.71)*.1;
          float settle=smoothstep(.14,.84,snowNormal.y)*smoothstep(.43,.69,landPosition.y);
          // Steep and thin spots thaw first, open flat ground holds snow longest.
          float hold=mix(.6,1.,smoothstep(.35,.95,snowNormal.y));
          float coverSnow=smoothstep(.0,.16,snowDepth*1.55*hold-uneven*.82)*settle;
          diffuseColor.rgb=mix(diffuseColor.rgb,vec3(.80,.88,.95)*(.87+.17*uneven),coverSnow);
          roughnessFactor=mix(roughnessFactor,.87,coverSnow);`);
      }
      if(isWater)shadeWater(shader,water);
      if(mat.name==='cascade')shadeCascade(shader,water);
    };
    mat.customProgramCacheKey=()=>isWater?'pond':mat.name;
  }
  return {cloudMap,breeze,snowDepth,winterBare,foliageTint,trample,update(seconds){clock.value=seconds;wind.value.set(seconds*.0019,seconds*.0008)},set(t,w,raining){
    cloudAmount.value=(.80-.54*t.night)*(w<1?T.MathUtils.lerp(.85,1.18,w):T.MathUtils.lerp(1.18,1.22,w-1));wet.value=Number(raining)}};
}
