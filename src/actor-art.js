import {shadePixelSurface} from './pixel-art.js';

// Shade the existing animated meshes so rigging, cutouts and face morphs stay shared.
function paintActor(material,storybook,pixelStyle,inkStrength){
  material.userData.actorArt=true;
  material.onBeforeCompile=shader=>{
    shader.uniforms.actorStorybook=storybook;
    shader.fragmentShader='uniform float actorStorybook;\n'+shader.fragmentShader.replace('#include <opaque_fragment>',`
      if(actorStorybook>.5){
        vec3 weights=vec3(.2126,.7152,.0722);
        float light=dot(outgoingLight,weights)/max(dot(diffuseColor.rgb,weights),.015);
        float day=smoothstep(.16,.48,light);
        vec3 pigment=mix(diffuseColor.rgb,diffuseColor.rgb*vec3(1.10,.99,.84),day*.66);
        float mid=smoothstep(.24,.39,light),sun=smoothstep(.67,.88,light);
        vec3 paint=pigment*mix(mix(vec3(.39,.49,.61),vec3(.77,.82,.79),mid),vec3(1.38,1.24,1.01),sun);
        float rim=abs(dot(normal,geometryViewDir));
        float ink=(1.-smoothstep(.10,.28,rim))*day*${inkStrength.toFixed(2)};
        outgoingLight=mix(outgoingLight,mix(paint,pigment*.36,ink),day*.77);
      }
      #include <opaque_fragment>`);
    shadePixelSurface(shader,pixelStyle);
  };
  material.customProgramCacheKey=()=>`actor-art-${inkStrength}`;
  return material;
}

export function createActorArt(storybook,pixelStyle){
  const details=[];
  return {
    shade(material,ink=.46){return paintActor(material,storybook,pixelStyle,ink)},
    detail(mesh){mesh.visible=false;mesh.castShadow=false;mesh.userData.styleVariant=true;details.push(mesh);return mesh},
    select(enabled){for(const mesh of details)mesh.visible=enabled}
  };
}
