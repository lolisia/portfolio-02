import * as T from 'three';

// Group lighting by surface before fog and bloom are composited. The same ramp
// works on animated meshes, whose material and shadow inputs still update normally.
export function shadePixelSurface(shader,pixelStyle,foliage=false){
  shader.uniforms.pixelStyle=pixelStyle;
  shader.fragmentShader='uniform float pixelStyle;\n'+shader.fragmentShader
    .replace('#include <normal_fragment_maps>',`
      #include <normal_fragment_maps>
      if(pixelStyle>.5)normal=normalize(mix(normal,nonPerturbedNormal,.74));`)
    .replace('#include <opaque_fragment>',`
      if(pixelStyle>.5){
        const vec3 pixelWeights=vec3(.2126,.7152,.0722);
        vec3 pixelBase=diffuseColor.rgb;
        vec3 pixelDiffuse=reflectedLight.directDiffuse+reflectedLight.indirectDiffuse;
        float pixelValue=dot(pixelDiffuse,pixelWeights);
        #ifdef STANDARD
          float pixelMetalness=metalnessFactor;
        #else
          float pixelMetalness=0.;
        #endif
        float pixelLight=pixelValue/max(dot(pixelBase,pixelWeights)*(1.-pixelMetalness),.012);
        vec3 lightTint=clamp(pixelDiffuse/max(pixelBase,.012)/max(.08,pixelLight),.44,1.65);
        float pixelRamp=.14+.18*smoothstep(.16,.23,pixelLight)
          +.29*smoothstep(.37,.45,pixelLight)+.44*smoothstep(.68,.79,pixelLight)
          +.58*smoothstep(1.16,1.38,pixelLight);
        ${foliage?`
          // Group green pigments into larger teal, fern and yellow-green patches.
          float green=smoothstep(.006,.04,pixelBase.g-max(pixelBase.r,pixelBase.b));
          float pigment=dot(pixelBase,pixelWeights);
          vec3 leaf=mix(vec3(.040,.145,.114),vec3(.104,.262,.129),smoothstep(.105,.173,pigment));
          leaf=mix(leaf,vec3(.32,.445,.132),smoothstep(.235,.365,pigment));
          pixelBase=mix(pixelBase,leaf,.78*green);
        `:''}
        vec3 pixelTint=mix(vec3(.69,.89,1.22),vec3(1.11,1.02,.83),smoothstep(.24,.95,pixelLight));
        vec3 paint=pixelBase*pixelRamp*pixelTint*mix(vec3(1.),lightTint,.43);
        paint*=1.-pixelMetalness;
        paint+=(reflectedLight.directSpecular+reflectedLight.indirectSpecular)*mix(.18,.79,pixelMetalness);
        outgoingLight=mix(outgoingLight,paint+totalEmissiveRadiance,.90);
      }
      #include <opaque_fragment>`);
}

export function createPixelArt(renderer){
  const cellSize=2;
  const size=new T.Vector2();
  const scene=new T.Scene(),camera=new T.Camera();
  const target=new T.WebGLRenderTarget(1,1,{
    type:T.HalfFloatType,minFilter:T.NearestFilter,magFilter:T.NearestFilter
  });
  const material=new T.ShaderMaterial({
    depthTest:false,depthWrite:false,
    uniforms:{source:{value:target.texture},sourceSize:{value:new T.Vector2()},cellSize:{value:cellSize}},
    vertexShader:`
      void main(){gl_Position=vec4(position.xy,0.,1.);}
    `,
    fragmentShader:`
      uniform sampler2D source;
      uniform vec2 sourceSize;
      uniform float cellSize;

      float bayerPair(vec2 bit){
        return 2.*abs(bit.x-bit.y)+bit.y;
      }

      void main(){
        vec2 cell=floor(gl_FragCoord.xy/cellSize);
        gl_FragColor=texture2D(source,(cell+.5)/sourceSize);
        #include <tonemapping_fragment>
        #include <colorspace_fragment>

        // Ordered dithering stays in place while the 3D scene animates.
        vec2 pattern=mod(cell,4.);
        float threshold=(4.*bayerPair(mod(pattern,2.))+bayerPair(floor(pattern/2.))+.5)/16.;
        vec3 color=gl_FragColor.rgb;
        float luma=dot(color,vec3(.2126,.7152,.0722));
        float stepped=floor(luma*24.+threshold)/24.;
        // Step the luminance and retain the scene's hue relationships.
        float strength=gl_FragColor.a*.65*smoothstep(.03,.14,luma)*(1.-smoothstep(.83,1.,luma));
        gl_FragColor=vec4(clamp(color+(stepped-luma)*strength,0.,1.),1.);
      }
    `
  });
  const quad=new T.Mesh(new T.PlaneGeometry(2,2),material);
  quad.frustumCulled=false;scene.add(quad);

  const enabled={value:0};
  return {
    enabled,
    select(value){
      if(enabled.value&&!value)target.dispose();
      enabled.value=Number(value);
    },
    render(world,view){
      if(!enabled.value){
        renderer.setRenderTarget(null);
        renderer.render(world,view);
        return;
      }
      renderer.getDrawingBufferSize(size);
      const width=Math.max(1,Math.ceil(size.x/cellSize));
      const height=Math.max(1,Math.ceil(size.y/cellSize));
      target.setSize(width,height);
      material.uniforms.sourceSize.value.set(width,height);
      renderer.setRenderTarget(target);
      renderer.render(world,view);
      renderer.setRenderTarget(null);
      renderer.render(scene,camera);
    }
  };
}
