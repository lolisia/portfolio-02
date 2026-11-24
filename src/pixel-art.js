import * as T from 'three';

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
