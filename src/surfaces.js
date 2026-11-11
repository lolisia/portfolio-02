import * as T from 'three';
import {leafSpray} from './foliage.js';
import {shadeWater} from './water.js';
import {shadeCascade} from './cascade.js';

export function field(size,seed,rows=size){
  const values=new Float32Array(size*rows);
  for(let i=0;i<values.length;i++){seed=(Math.imul(seed,1664525)+1013904223)>>>0;values[i]=seed/4294967296}
  return (u,v)=>{
    const x=(u-Math.floor(u))*size,y=(v-Math.floor(v))*rows,i=Math.floor(x),j=Math.floor(y);
    let a=x-i,b=y-j;a=a*a*(3-2*a);b=b*b*(3-2*b);
    const at=(m,n)=>values[(n%rows)*size+m%size];
    return (1-b)*((1-a)*at(i,j)+a*at(i+1,j))+b*((1-a)*at(i,j+1)+a*at(i+1,j+1));
  };
}
// three.js shades every point and spot light at every fragment, shadow lookups included, even
// where the light cannot reach or is switched off (the lanterns stay in the scene all day at
// zero intensity). Skip the shadow filter and the BRDF for lights that contribute nothing.
{
  const chunk=T.ShaderChunk.lights_fragment_begin,from=chunk.indexOf('#if ( NUM_POINT_LIGHTS > 0 )'),to=chunk.indexOf('#if ( NUM_SUN_LIGHTS > 0 )');
  const call='RE_Direct( directLight, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );';
  const reaches=' if(directLight.visible&&directLight.color.r+directLight.color.g+directLight.color.b>0.){';
  const local=chunk.slice(from,to)
    .replace('getPointLightInfo( pointLight, geometryPosition, directLight );','getPointLightInfo( pointLight, geometryPosition, directLight );'+reaches)
    .replace('getSpotLightInfo( spotLight, geometryPosition, directLight );','getSpotLightInfo( spotLight, geometryPosition, directLight );'+reaches)
    .replaceAll(call,call+' }');
  if(!chunk.includes(reaches)){  // a hot reload runs this module again with the chunk already patched
    if(from<0||to<0||local.split(reaches).length!==3)throw new Error('light loop patch no longer matches three.js');
    T.ShaderChunk.lights_fragment_begin=chunk.slice(0,from)+local+chunk.slice(to);
  }
}
export const TRAMPLE_SLOTS=16;
const coarse=field(5,722),fine=field(27,998),grit=field(96,417);
// Wood fibres: many cells across the grain, few along it, so streaks run the length of a board.
const fibre=field(180,5113,6),streak=field(46,2741,3);
const knots=[[.21,.27],[.68,.71],[.43,.93]];
function grain(u,v){
  let bend=.022*coarse(u,v)+.008*Math.sin(v*6.283*2);
  let knot=0;
  for(const [ku,kv] of knots){
    const du=((u-ku+1.5)%1-.5)*6,dv=((v-kv+1.5)%1-.5)*1.3,d=du*du+dv*dv;
    knot=Math.max(knot,Math.exp(-d*38));bend+=.05*Math.exp(-d*9)*Math.sign(du||1)/(1+d*30);
  }
  const ring=.5+.5*Math.sin(6.283*(26*(u+bend)+1.3*coarse(u*2,v)));
  const late=Math.pow(ring,7),fib=fibre(u+bend,v),str=streak(u+bend*.5,v);
  return {late,fib,str,knot};
}
function texture(size,paint,color=false){
  const cv=document.createElement('canvas');cv.width=cv.height=size;
  const ctx=cv.getContext('2d'),data=ctx.createImageData(size,size),d=data.data;
  for(let j=0;j<size;j++)for(let i=0;i<size;i++){
    const c=paint(i/size,j/size),k=(j*size+i)*4;d[k]=c[0];d[k+1]=c[1];d[k+2]=c[2];d[k+3]=255;
  }
  ctx.putImageData(data,0,0);
  const map=new T.CanvasTexture(cv);map.wrapS=map.wrapT=T.RepeatWrapping;
  map.anisotropy=4;if(color)map.colorSpace=T.SRGBColorSpace;return map;
}

const recipes={
  // Box faces are mapped at world scale (one texture per tile), grain along each board's length.
  wood:{rough:.8,depth:2.4,size:512,relief:(u,v)=>{
    const g=grain(u,v);
    return .5-.34*g.late+.24*g.fib+.12*g.str-.3*g.knot+.06*grit(u*2,v*2);
  },paint:(u,v)=>{
    const g=grain(u,v),tone=.86+.16*coarse(u*2,v)-.1*g.str;
    const dark=Math.min(1,.42*g.late+.22*(1-g.fib)+.7*g.knot);
    return [255*tone*(1-.42*dark),238*tone*(1-.5*dark),214*tone*(1-.58*dark)].map(c=>Math.min(255,c));
  }},
  bark:{rough:.98,depth:1.9,relief:(u,v)=>.6*fine(u, .15*Math.sin(v*6.283)+u*.08)+.26*coarse(u*3,v)+.14*grit(u,v)},
  // Dressed stone: broad mottling, pitted grain, hairline veins and patches of lichen.
  stone:{rough:.91,depth:2.2,size:512,relief:(u,v)=>{
    const vein=Math.pow(1-Math.abs(fine(u+.15*coarse(u,v),v)-.5)*2,40);
    return .36*coarse(u,v)+.3*fine(u,v)+.24*grit(u,v)+.1*grit(u*2,v*2)-.2*vein-.18*Math.max(0,grit(u*3,v*3)-.72)*3;
  },paint:(u,v)=>{
    const vein=Math.pow(1-Math.abs(fine(u+.15*coarse(u,v),v)-.5)*2,40);
    const tone=.8+.2*coarse(u,v)+.08*fine(u*2,v*2)-.1*grit(u,v)-.16*vein-.14*Math.max(0,grit(u*3,v*3)-.7)*3;
    const lichen=Math.max(0,Math.min(1,(fine(u*2+.3,v*2)*coarse(u+.5,v)-.38)*7));
    return [255*tone*(1-.06*lichen),255*tone*(1+.03*lichen),255*tone*(1-.22*lichen)].map(c=>Math.max(0,Math.min(255,c)));
  }},
  clay:{rough:.74,depth:.85,relief:(u,v)=>.26*coarse(u,v)+.18*fine(u,v)+.18*grit(u,v)+.38*Math.cos(u*6.283)**2},
  plaster:{rough:.98,depth:.95,relief:(u,v)=>.32*coarse(u,v)+.33*fine(u,v)+.35*grit(u,v)},
  soil:{rough:.97,depth:1.4,relief:(u,v)=>.45*fine(u*2,v*2)+.3*grit(u,v)+.25*coarse(u*4,v*4)},
  leaf:{rough:.66,depth:.58,relief:(u,v)=>.62*coarse(u,v)+.28*fine(u,v)+.1*grit(u,v)}
};
const cache=new Map();
// Box-built kinds get world-scale UVs (see createAtmosphere); '-uv' variants keep a mesh's own UVs.
const BOXED=['wood','stone','clay','plaster'];
export function surface(name){
  if(cache.has(name))return cache.get(name);
  const recipe=recipes[name.replace(/-uv$/,'')];
  const mat=new T.MeshStandardMaterial({name,flatShading:true,roughness:recipe?.rough??.9});
  if(recipe){
    const h=recipe.relief,n=recipe.size??128;
    mat.map=texture(n,recipe.paint??((u,v)=>{const a=183+70*h(u,v);return [a,a,a]}),true);
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
  const rainNow={value:0},WATER=world.waterY.toFixed(3);
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
          // lateral push fades to zero at the centre, so a blade never flips sides
          parted+=away/max(dist,t.z*.7)*f;pressed=max(pressed,f);
        }
        parted/=max(1.,length(parted));
        swaying[3].xz+=parted*h*.8;swaying[3].y-=pressed*h*.45;
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
  scene.traverse(o=>{if(o.material?.isMeshStandardMaterial&&!o.material.userData.clock)materials.add(o.material)});  // the foam disc keeps its own shader
  for(const mat of materials){
    const isWater=mat===water.material;
    mat.onBeforeCompile=shader=>{
      if(bendingMaterials.has(mat))sway(shader,mat.name==='grass');
      else shader.vertexShader='uniform float elapsed,wet,breeze;\n'+shader.vertexShader;
      if(BOXED.includes(mat.name)){
        // World-scale box mapping: each face samples the texture at its true size, with the
        // grain (texture v) along the longer in-plane edge and a per-instance offset, instead
        // of one stretched copy per face.
        shader.vertexShader=shader.vertexShader.replace('#include <uv_vertex>',`#include <uv_vertex>
          #if defined(USE_INSTANCING) && defined(USE_MAP)
          {
            vec3 sc=vec3(length(instanceMatrix[0].xyz),length(instanceMatrix[1].xyz),length(instanceMatrix[2].xyz));
            vec3 bp=position*sc,an=abs(normal);
            vec2 q=an.x>.5?(sc.z>sc.y?bp.yz:bp.zy):an.y>.5?(sc.z>sc.x?bp.xz:bp.zx):(sc.y>sc.x?bp.xy:bp.yx);
            vec3 o=instanceMatrix[3].xyz;
            q+=fract(sin(vec2(dot(o,vec3(12.99,78.23,37.72)),dot(o,vec3(39.35,11.13,83.17))))*43758.55)*vec2(5.,9.);
            vMapUv=q*${({wood:1,stone:.75,clay:1.4,plaster:.8})[mat.name].toFixed(2)};
            #ifdef USE_NORMALMAP
            vNormalMapUv=vMapUv;
            #endif
          }
          #endif`);
      }
      Object.assign(shader.uniforms,{cloudMap,cloudAmount,wind,elapsed:clock,breeze,wet,snowDepth,foliageTint,rainNow});
      shader.vertexShader='varying vec3 landPosition;\n'+shader.vertexShader.replace('#include <project_vertex>',`
        vec4 land=vec4(transformed,1.);
        #ifdef USE_INSTANCING
          land=instanceMatrix*land;
        #endif
        landPosition=(modelMatrix*land).xyz;
        #include <project_vertex>`);
      shader.fragmentShader='varying vec3 landPosition; uniform sampler2D cloudMap; uniform float cloudAmount,elapsed,wet,breeze,rainNow; uniform vec2 wind;\n'+shader.fragmentShader;
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
        shader.uniforms.winterBare=winterBare;shader.uniforms.soilMap={value:mat.userData.soilMap};
        shader.fragmentShader='uniform float winterBare; uniform sampler2D soilMap;\n'+shader.fragmentShader.replace('#include <color_fragment>',`
          #include <color_fragment>
          float trailMask=texture2D(roughnessMap,vRoughnessMapUv).b;
          vec3 soilDetail=texture2D(soilMap,vBumpMapUv).rgb*2.;
          diffuseColor.rgb*=mix(vec3(1.),soilDetail,.25+.75*trailMask);
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
          float coverSnow=0.,crystal=0.;vec3 crystalNormal=normal;
          float grainSpan=max(length(dFdx(landPosition)),length(dFdy(landPosition)));
          if(snowDepth>0.){
          // Triplanar noise: projecting along the surface normal avoids the streaks a single
          // top-down lookup smears down trunks, cones and walls.
          vec3 tri=pow(abs(snowNormal),vec3(4.));tri/=dot(tri,vec3(1.));
          vec3 q=landPosition;
          #define SNOW_NOISE(s,o) (texture2D(cloudMap,q.yz*s+o).r*tri.x+texture2D(cloudMap,q.xz*s+o).r*tri.y+texture2D(cloudMap,q.xy*s+o).r*tri.z)
          float uneven=SNOW_NOISE(.21,0.)*.6+SNOW_NOISE(.83,.37)*.3+SNOW_NOISE(3.1,.71)*.1;
          float settle=smoothstep(.14,.84,snowNormal.y)*smoothstep(.43,.69,landPosition.y);
          // Steep and thin spots thaw first, open flat ground holds snow longest.
          float hold=mix(.6,1.,smoothstep(.35,.95,snowNormal.y));
          coverSnow=smoothstep(.0,.16,snowDepth*1.55*hold-uneven*.82)*settle;
          diffuseColor.rgb=mix(diffuseColor.rgb,vec3(.80,.88,.95)*(.87+.17*uneven),coverSnow);
          roughnessFactor=mix(roughnessFactor,.87,coverSnow);
          // Snow sparkle: scattered ice facets, about two pixels across, each tilted its own way.
          // The few that mirror the sun toward the eye flash (see the glint added to the sun's
          // light below), and which ones do changes as the view turns.
          vec3 grain=floor(landPosition*exp2(-floor(log2(grainSpan*1.6))));
          vec3 facet=fract(sin(vec3(dot(grain,vec3(127.1,311.7,74.7)),dot(grain,vec3(269.5,183.3,246.1)),dot(grain,vec3(113.5,271.9,124.6))))*43758.5453);
          crystal=step(.7,facet.x)*coverSnow;
          crystalNormal=normalize(normal+(vec3(facet.y,facet.z,fract(facet.x*57.))-.5)*1.1);
          }
          if(wet>0.){
          // Rain soaks in: wet surfaces turn darker and richer, and shine. Faces turned to the
          // sky take the most water.
          float wetness=wet*mix(.35,1.,smoothstep(-.1,.7,snowNormal.y))*(1.-coverSnow);
          diffuseColor.rgb=pow(diffuseColor.rgb,vec3(1.+.36*wetness));
          roughnessFactor*=1.-.38*wetness;
          ${['terrain','stone'].includes(mat.name)?`
          // Puddles gather in level hollows of the ground and on the paving slabs, and mirror the
          // sky and lanterns. Falling drops ring them.
          float basin=texture2D(cloudMap,landPosition.xz*.12+.31).r*.6+texture2D(cloudMap,landPosition.xz*.41).r*.4;
          float brim=mix(.95,.52,wet)${mat.name==='terrain'?'-.14*trailMask':'+.04'};
          float puddle=smoothstep(brim,brim+.035,basin)*smoothstep(.965,.995,inverseTransformDirection(nonPerturbedNormal,viewMatrix).y)
            *(1.-coverSnow)*step(${WATER}+.03,landPosition.y)*smoothstep(0.,.15,wet);
          if(puddle>.001){
            vec2 push=vec2(0.);
            for(int layer=0;layer<2;layer++){
              vec2 rq=landPosition.xz*(3.1+1.3*float(layer))+float(layer)*17.3,cell=floor(rq);
              float seed=fract(sin(dot(cell,vec2(127.1,311.7)))*43758.5453);
              vec2 delta=fract(rq)-(.5+.3*(vec2(seed,fract(seed*91.7))-.5));
              float age=fract(elapsed*(.8+.6*seed)+seed*7.),crest=length(delta)-age*.33;
              push+=delta/max(.02,length(delta))*sin(crest*42.)*exp(-abs(crest)*16.)*(1.-age);
            }
            push*=.45*rainNow;
            normal=normalize(mix(normal,normalize((viewMatrix*vec4(push.x,1.,push.y,0.)).xyz),puddle));
            diffuseColor.rgb*=1.-.55*puddle;roughnessFactor=mix(roughnessFactor,.045,puddle);
          }`:''}
          }`);
        const direct='RE_Direct( directLight, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );';
        const index=shader.fragmentShader.indexOf(direct,shader.fragmentShader.indexOf('getDirectionalLightInfo( directionalLight, directLight );'));
        shader.fragmentShader=shader.fragmentShader.slice(0,index)+`
            if(crystal>0.)reflectedLight.directSpecular += directLight.color * crystal * 7.
              * pow(max(0.,dot(crystalNormal,normalize(directLight.direction+geometryViewDir))),900.);
          `+shader.fragmentShader.slice(index);
      }
      if(isWater)shadeWater(shader,water);
      if(mat.name==='cascade')shadeCascade(shader,water);
    };
    mat.customProgramCacheKey=()=>isWater?'pond':mat.name;
  }
  return {cloudMap,breeze,snowDepth,winterBare,foliageTint,trample,wet,update(seconds){clock.value=seconds;wind.value.set(seconds*.0019,seconds*.0008)},
    // Surfaces soak within a few seconds of rain and take about half a minute to dry again.
    soak(rain,dt){
      rainNow.value=rain;
      wet.value=rain>wet.value?wet.value+(rain-wet.value)*(1-Math.exp(-dt*.5)):Math.max(rain,wet.value-dt*.035);
    },
    set(t,w){
    cloudAmount.value=(.80-.54*t.night)*(w<1?T.MathUtils.lerp(.85,1.18,w):T.MathUtils.lerp(1.18,1.22,w-1))}};
}
