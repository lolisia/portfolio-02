import * as T from 'three';
import {GTAOShader,generateMagicSquareNoise} from 'three/addons/shaders/GTAOShader.js';

const fullscreenVertex=`
  varying vec2 screenUv;
  void main(){
    screenUv=uv;
    gl_Position=vec4(position.xy,0.,1.);
  }`;

export function createVolume(renderer,world,sun,clouds){
  const frame=new T.WebGLRenderTarget(1,1,{type:T.HalfFloatType});
  frame.depthTexture=new T.DepthTexture(1,1,T.UnsignedIntType);
  const fog=new T.WebGLRenderTarget(1,1,{type:T.HalfFloatType,depthBuffer:false});
  const aoTarget=new T.WebGLRenderTarget(1,1,{depthBuffer:false});
  const ao=new T.ShaderMaterial({...GTAOShader,uniforms:T.UniformsUtils.clone(GTAOShader.uniforms),
    defines:{...GTAOShader.defines,NORMAL_VECTOR_TYPE:0,PERSPECTIVE_CAMERA:0,SAMPLES:8},
    depthTest:false,depthWrite:false});
  ao.uniforms.tDepth.value=frame.depthTexture;ao.uniforms.tNoise.value=generateMagicSquareNoise();
  ao.uniforms.radius.value=.58;ao.uniforms.thickness.value=.42;
  const uniforms={
    depthMap:{value:frame.depthTexture}, shadowDepth:{value:null}, cloudMap:clouds,
    toWorld:{value:new T.Matrix4()},lightMatrix:{value:sun.shadow.matrix},
    sunDir:{value:new T.Vector3()},sunColor:{value:new T.Color()},density:{value:.046},
    scatterColor:{value:new T.Color()},clock:{value:0},cloudAmount:{value:.5},
    lampPower:{value:0},lamps:{value:world.lamps.map(()=>new T.Vector3())},golden:{value:0},mistLow:{value:0}
  };
  const march=new T.ShaderMaterial({uniforms,depthTest:false,depthWrite:false,
    vertexShader:fullscreenVertex,fragmentShader:`
    varying vec2 screenUv;
    uniform sampler2D depthMap,cloudMap;
    uniform highp sampler2DShadow shadowDepth;
    uniform mat4 toWorld,lightMatrix;
    uniform vec3 sunDir,sunColor,scatterColor,lamps[5];
    uniform float clock,density,lampPower,cloudAmount,golden,mistLow;
    void main(){
      vec2 ndc=screenUv*2.-1.;
      vec3 origin=(toWorld*vec4(ndc,-1.,1.)).xyz;
      vec3 farPoint=(toWorld*vec4(ndc,1.,1.)).xyz;
      vec3 ray=normalize(farPoint-origin);
      float surfaceDist=texture2D(depthMap,screenUv).r*length(farPoint-origin);
      vec3 inv=1./(sign(ray+vec3(.0000001))*max(abs(ray),vec3(.00001)));
      vec3 a=(vec3(-17.,-.7,-17.)-origin)*inv;
      vec3 b=(vec3(17.,10.,17.)-origin)*inv;
      vec3 lo=min(a,b),hi=max(a,b);
      float start=max(0.,max(lo.x,max(lo.y,lo.z)));
      float end=min(surfaceDist,min(hi.x,min(hi.y,hi.z)));
      float ds=max(0.,end-start)/36.;
      vec3 sum=vec3(0.);float through=1.;
      if(ds>0.){
        float jitter=fract(52.9829189*fract(dot(gl_FragCoord.xy,vec2(.06711056,.00583715))));
        vec3 p=origin+ray*(start+ds*(.25+.5*jitter));
        // Low sun: a tighter, brighter forward lobe turns shafts through the trees golden.
        float phase=.35+(.75+1.9*golden)*pow(max(dot(sunDir,ray),0.),3.+4.*golden);
        for(int i=0;i<36;i++,p+=ray*ds){
          float edge=1.-smoothstep(13.4,17.,max(abs(p.x),abs(p.z)));
          float bank=texture2D(cloudMap,p.xz*.039+p.y*vec2(.019,-.027)+clock*vec2(-.0014,.0008)).r;
          float pool=exp(-.029*dot(p.xz-vec2(10.5,6.),p.xz-vec2(10.5,6.)));
          float rho=density*edge*mix(.20,1.15,smoothstep(.24,.70,bank))*(1.-.73*pool)
            *exp(-.38*max(0.,p.y-1.3))*smoothstep(-.7,.65,p.y)
            *(1.+mistLow*2.4*exp(-2.2*max(0.,p.y-.85)));  // dawn mist pools in the low ground
          float opacity=1.-exp(-rho*ds);
          vec3 shadowCoord=(lightMatrix*vec4(p,1.)).xyz;
          float lit=texture(shadowDepth,vec3(shadowCoord.xy,shadowCoord.z-.00045));
          float cover=texture2D(cloudMap,(p.xz+p.y*vec2(.25,-.16))*.024+clock*vec2(.0019,.0008)).r;
          vec3 incident=scatterColor+sunColor*(phase*lit*(1.-cloudAmount*smoothstep(.31,.66,cover)));
          if(lampPower>.01){
            for(int j=0;j<5;j++){
              vec3 v=p-lamps[j];float d2=dot(v,v);
              float cone=smoothstep(.22,.72,-v.y*inversesqrt(d2+.001));
              incident+=lampPower*vec3(2.8,1.45,.50)*cone*exp(-d2*.26)/(1.+d2*.45);
            }
          }
          sum+=through*opacity*incident;
          through*=1.-opacity;
        }
      }
      gl_FragColor=vec4(sum,through);
    }`});
  const composite=new T.ShaderMaterial({depthTest:false,depthWrite:false,
    uniforms:{bgTop:{value:new T.Color()},bgBottom:{value:new T.Color()},sunScreen:{value:new T.Vector2(.5,2)},glowColor:{value:new T.Color()},glowAmount:{value:0},
      shadowTint:{value:new T.Vector3(1,1,1)},highlightTint:{value:new T.Vector3(1,1,1)},saturation:{value:1},vignette:{value:.2},
      glassRect:{value:new T.Vector4()},viewport:{value:new T.Vector2()},contact:{value:aoTarget.texture},sceneColor:{value:frame.texture},depthMap:{value:frame.depthTexture},volume:{value:fog.texture},fogSize:{value:new T.Vector2()}},
    vertexShader:fullscreenVertex,fragmentShader:`
    varying vec2 screenUv;uniform sampler2D sceneColor,depthMap,volume,contact;uniform vec2 fogSize;
    uniform vec4 glassRect;uniform vec2 viewport,sunScreen;
    uniform vec3 bgTop,bgBottom,glowColor,shadowTint,highlightTint;uniform float glowAmount,saturation,vignette;
    void main(){
      vec2 pixel=screenUv*viewport,local=pixel-glassRect.xy;
      float radius=min(19.,glassRect.w);
      vec2 corner=abs(local)-glassRect.zw+radius;
      float sd=length(max(corner,vec2(0.)))+min(max(corner.x,corner.y),0.)-radius;
      float bevel=(1.-smoothstep(0.,16.,-sd))*smoothstep(0.,2.,-sd);
      vec2 direction=normalize(sign(local)*(max(corner,vec2(0.))+.001*step(corner.yx,corner))+.00001);
      vec2 lensUv=clamp(screenUv-direction*bevel*8./viewport,0.,1.);
      float z=texture2D(depthMap,lensUv).r;
      vec2 p=lensUv*fogSize-.5, f=fract(p);
      vec4 v=vec4(0.);float total=0.,visibility=0.;
      for(int i=0;i<4;i++){
        vec2 corner=vec2(i%2,i/2);vec2 uv=(floor(p)+corner+.5)/fogSize;
        vec2 blend=mix(1.-f,f,corner);
        float weight=blend.x*blend.y/(1.+2400.*abs(texture2D(depthMap,uv).r-z));
        visibility+=texture2D(contact,uv).r*weight;v+=texture2D(volume,uv)*weight;total+=weight;
      }
      v/=max(total,.00001);
      float contactLight=z>=1.?1.:mix(.68,1.,clamp(visibility/max(total,.00001),0.,1.));
      vec3 base=texture2D(sceneColor,lensUv).rgb;
      if(z>=1.){
        // Behind the island: a vertical sky gradient with the low sun's glow toward its side.
        base=mix(bgBottom,bgTop,smoothstep(0.,1.,lensUv.y));
        float d=length((lensUv-sunScreen)*vec2(viewport.x/viewport.y,1.));
        base+=glowColor*glowAmount*(.55*exp(-d*1.6)+.6*exp(-d*6.));
      }
      vec3 color=base*contactLight*v.a+v.rgb;
      // Grade: split-tone shadows / highlights, a touch of saturation, soft vignette.
      float lum=dot(color,vec3(.2126,.7152,.0722));
      color*=mix(shadowTint,highlightTint,smoothstep(.02,.45,lum));
      lum=dot(color,vec3(.2126,.7152,.0722));
      color=max(vec3(0.),mix(vec3(lum),color,saturation));
      vec2 edge=(screenUv-.5)*vec2(viewport.x/viewport.y,1.);
      color*=1.-vignette*smoothstep(.25,1.05,length(edge));
      gl_FragColor=vec4(color,1.);
      #include <tonemapping_fragment>
      #include <colorspace_fragment>
    }`});
  const sunPoint=new T.Vector3(),sunOrigin=new T.Vector3();
  const quad=new T.Mesh(new T.PlaneGeometry(2,2),march),screen=new T.Scene(),ortho=new T.Camera();
  quad.frustumCulled=false;screen.add(quad);
  const panel=document.querySelector('#panel');
  function measureGlass(){
    const r=panel.getBoundingClientRect();
    composite.uniforms.glassRect.value.set(r.left+r.width/2,innerHeight-r.top-r.height/2,r.width/2,r.height/2);
    composite.uniforms.viewport.value.set(innerWidth,innerHeight);
  }
  new ResizeObserver(measureGlass).observe(panel);
  return {
    resize(w,h){
      measureGlass();
      frame.setSize(w,h);const x=Math.ceil(w*.5),y=Math.ceil(h*.5);fog.setSize(x,y);aoTarget.setSize(x,y);ao.uniforms.resolution.value.set(x,y);
      composite.uniforms.fogSize.value.set(x,y);
    },
    set(t,w,densityScale){
      uniforms.density.value=t.value([.033,.016,.045,.032,.03])*(1+.38*w)*densityScale;
      uniforms.scatterColor.value.copy(t.color([0x657577,0x768183,0x957a8c,0x192d45,0x8d5a44])).multiplyScalar(.55);
      uniforms.lampPower.value=t.night;uniforms.golden.value=t.golden*(1-.6*Math.min(1,w));
      uniforms.mistLow.value=(t.dawn?1:.3)*t.golden*(1-.5*Math.min(1,w));uniforms.cloudAmount.value=w<1?T.MathUtils.lerp(.63,.84,w):T.MathUtils.lerp(.84,.94,w-1);
    },
    grade({top,bottom,glow,glowAmount,shadow,highlight,saturation,vignette}){
      const u=composite.uniforms;
      u.bgTop.value.copy(top);u.bgBottom.value.copy(bottom);u.glowColor.value.copy(glow);u.glowAmount.value=glowAmount;
      u.shadowTint.value.copy(shadow);u.highlightTint.value.copy(highlight);u.saturation.value=saturation;u.vignette.value=vignette;
    },
    render(scene,camera,seconds){
      renderer.setRenderTarget(frame);renderer.render(scene,camera);
      ao.uniforms.cameraProjectionMatrix.value.copy(camera.projectionMatrix);
      ao.uniforms.cameraProjectionMatrixInverse.value.copy(camera.projectionMatrixInverse);
      ao.uniforms.cameraNear.value=camera.near;ao.uniforms.cameraFar.value=camera.far;
      quad.material=ao;renderer.setRenderTarget(aoTarget);renderer.render(screen,ortho);
      uniforms.clock.value=seconds;
      uniforms.toWorld.value.multiplyMatrices(camera.matrixWorld,camera.projectionMatrixInverse);
      uniforms.shadowDepth.value=sun.shadow.map.depthTexture;
      uniforms.sunDir.value.copy(sun.position).normalize();
      // Glow sits just inside the screen edge on the side the sun lies toward.
      sunPoint.copy(uniforms.sunDir.value).multiplyScalar(20).add(camera.position).project(camera);
      sunOrigin.copy(camera.position).project(camera);
      sunPoint.sub(sunOrigin);sunPoint.z=0;sunPoint.normalize();
      composite.uniforms.sunScreen.value.set(.5+sunPoint.x*.56,.5+sunPoint.y*.6);
      uniforms.sunColor.value.copy(sun.color).multiplyScalar(sun.intensity*.68);
      world.lamps.forEach((pivot,i)=>pivot.localToWorld(uniforms.lamps.value[i].set(0,-.485,0)));
      quad.material=march;renderer.setRenderTarget(fog);renderer.render(screen,ortho);
      quad.material=composite;renderer.setRenderTarget(null);renderer.render(screen,ortho);
    }
  };
}
