import * as T from 'three';
import {GTAOShader,generateMagicSquareNoise} from 'three/addons/shaders/GTAOShader.js';
import {quality} from './mobile-quality.js';

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
    defines:{...GTAOShader.defines,NORMAL_VECTOR_TYPE:0,PERSPECTIVE_CAMERA:0,SAMPLES:quality.aoSamples},
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
      // The mist thins out with height and the tree shadows that carve shafts into it stay near
      // the ground, so samples are spent where they show: a few long steps through the thin air
      // above y=5, the rest packed into the layer below it (finer there than an even split).
      float split=ray.y<-.001?clamp((5.-origin.y)/ray.y,start,max(start,end)):start;
      float dsHigh=(split-start)/${quality.fogHighSteps}.,dsLow=max(0.,end-split)/${quality.fogLowSteps}.;
      vec3 sum=vec3(0.);float through=1.;
      if(end>start){
        float jitter=.25+.5*fract(52.9829189*fract(dot(gl_FragCoord.xy,vec2(.06711056,.00583715))));
        vec3 p=origin+ray*(start+dsHigh*jitter);float ds=dsHigh;
        // Low sun: a tighter, brighter forward lobe turns shafts through the trees golden.
        float phase=.35+(.75+1.9*golden)*pow(max(dot(sunDir,ray),0.),3.+4.*golden);
        // A lantern only lights the mist within a few metres of it: find the lamps this ray
        // passes close to once, instead of weighing all five at every step of every ray.
        bool nearLamp[5];bool anyLit=false;
        if(lampPower>.01)for(int j=0;j<5;j++){
          vec3 toLamp=lamps[j]-origin;float along=dot(toLamp,ray);
          nearLamp[j]=dot(toLamp,toLamp)-along*along<30.;anyLit=anyLit||nearLamp[j];
        }
        for(int i=0;i<${quality.fogHighSteps+quality.fogLowSteps};i++,p+=ray*ds){
          if(i==${quality.fogHighSteps}){p=origin+ray*(split+dsLow*jitter);ds=dsLow;}
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
          if(anyLit){
            for(int j=0;j<5;j++){
              if(!nearLamp[j])continue;
              vec3 v=p-lamps[j];float d2=dot(v,v);
              if(d2>30.)continue;
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
  // Bloom: bright HDR light (lantern glass, sun glitter, lit haze) bleeds into its surroundings.
  // A half-resolution bright pass is blurred down a small mip chain and summed back up.
  const blooms=Array.from({length:5},()=>new T.WebGLRenderTarget(1,1,{type:T.HalfFloatType,depthBuffer:false}));
  const pass=(uniforms,fragmentShader,extra)=>new T.ShaderMaterial({uniforms,depthTest:false,depthWrite:false,vertexShader:fullscreenVertex,fragmentShader,...extra});
  const bright=pass({sceneColor:{value:frame.texture},depthMap:{value:frame.depthTexture},volume:{value:fog.texture},texel:{value:new T.Vector2()},threshold:{value:1}},`
    varying vec2 screenUv;uniform sampler2D sceneColor,depthMap,volume;uniform vec2 texel;uniform float threshold;
    void main(){
      vec3 sum=vec3(0.);float total=0.;
      for(int i=0;i<4;i++){
        vec2 uv=screenUv+(vec2(i%2,i/2)-.5)*2.*texel;
        vec3 c=texture2D(depthMap,uv).r>=1.?vec3(0.):min(texture2D(sceneColor,uv).rgb,vec3(24.));
        vec4 v=texture2D(volume,uv);c=c*v.a+v.rgb;
        float l=max(c.r,max(c.g,c.b)),knee=.5*threshold;
        float soft=clamp(l-threshold+knee,0.,2.*knee);soft=soft*soft/(4.*knee+.0001);
        // weighting by 1/(1+l) keeps a single hot pixel from flickering through the blur
        float weight=1./(1.+l);
        sum+=c*max(soft,l-threshold)/max(l,.0001)*weight;total+=weight;
      }
      gl_FragColor=vec4(sum/total,1.);
    }`);
  const shrink=pass({source:{value:null},texel:{value:new T.Vector2()}},`
    varying vec2 screenUv;uniform sampler2D source;uniform vec2 texel;
    void main(){
      vec3 c=texture2D(source,screenUv).rgb*4.;
      for(int i=0;i<4;i++)c+=texture2D(source,screenUv+(vec2(i%2,i/2)*2.-1.)*texel).rgb;
      gl_FragColor=vec4(c/8.,1.);
    }`);
  const grow=pass({source:{value:null},texel:{value:new T.Vector2()}},`
    varying vec2 screenUv;uniform sampler2D source;uniform vec2 texel;
    void main(){
      vec3 c=vec3(0.);
      for(int i=0;i<4;i++)c+=texture2D(source,screenUv+(vec2(i%2,i/2)*2.-1.)*texel).rgb;
      gl_FragColor=vec4(c*.25,1.);
    }`,{blending:T.AdditiveBlending,transparent:true});
  const composite=new T.ShaderMaterial({depthTest:false,depthWrite:false,
    defines:{SEPARATE_CONTACT:quality.fogScale!==.5?1:0},
    uniforms:{bgTop:{value:new T.Color()},bgBottom:{value:new T.Color()},sunScreen:{value:new T.Vector2(.5,2)},glowColor:{value:new T.Color()},glowAmount:{value:0},
      shadowTint:{value:new T.Vector3(1,1,1)},highlightTint:{value:new T.Vector3(1,1,1)},saturation:{value:1},vignette:{value:.2},
      bloomMap:{value:blooms[0].texture},bloomAmount:{value:0},stars:{value:0},skyTurn:{value:0},clock:{value:0},
      moodTint:{value:new T.Vector3(1,1,1)},moodSaturation:{value:1},moodContrast:{value:1},moodBloom:{value:1},
      glassRect:{value:new T.Vector4()},viewport:{value:new T.Vector2()},contact:{value:aoTarget.texture},sceneColor:{value:frame.texture},depthMap:{value:frame.depthTexture},volume:{value:fog.texture},fogSize:{value:new T.Vector2()},contactSize:{value:new T.Vector2()}},
    vertexShader:fullscreenVertex,fragmentShader:`
    varying vec2 screenUv;uniform sampler2D sceneColor,depthMap,volume,contact,bloomMap;uniform vec2 fogSize,contactSize;
    uniform float bloomAmount,stars,skyTurn,clock,moodSaturation,moodContrast,moodBloom;uniform vec3 moodTint;
    float starHash(vec2 p){vec3 q=fract(p.xyx*vec3(.1031,.1030,.0973));q+=dot(q,q.yzx+33.33);return fract((q.x+q.y)*q.z);}
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
      vec4 v=vec4(0.);float total=0.,visibility=0.,contactTotal=0.;
      for(int i=0;i<4;i++){
        vec2 corner=vec2(i%2,i/2);vec2 uv=(floor(p)+corner+.5)/fogSize;
        vec2 blend=mix(1.-f,f,corner);
        float weight=blend.x*blend.y/(1.+2400.*abs(texture2D(depthMap,uv).r-z));
        #if !SEPARATE_CONTACT
          visibility+=texture2D(contact,uv).r*weight;
        #endif
        v+=texture2D(volume,uv)*weight;total+=weight;
      }
      v/=max(total,.00001);
      #if SEPARATE_CONTACT
        // Contact shading retains its half-resolution reconstruction even when the softer
        // atmospheric volume uses a smaller target on phones.
        vec2 contactP=lensUv*contactSize-.5,contactFraction=fract(contactP);
        for(int i=0;i<4;i++){
          vec2 corner=vec2(i%2,i/2),uv=(floor(contactP)+corner+.5)/contactSize;
          vec2 blend=mix(1.-contactFraction,contactFraction,corner);
          float weight=blend.x*blend.y/(1.+2400.*abs(texture2D(depthMap,uv).r-z));
          visibility+=texture2D(contact,uv).r*weight;contactTotal+=weight;
        }
      #else
        contactTotal=total;
      #endif
      float contactLight=z>=1.?1.:mix(.68,1.,clamp(visibility/max(contactTotal,.00001),0.,1.));
      vec3 base=texture2D(sceneColor,lensUv).rgb;
      if(z>=1.){
        // Behind the island: a vertical sky gradient with the low sun's glow toward its side.
        base=mix(bgBottom,bgTop,smoothstep(0.,1.,lensUv.y));
        float d=length((lensUv-sunScreen)*vec2(viewport.x/viewport.y,1.));
        base+=glowColor*glowAmount*(.55*exp(-d*1.6)+.6*exp(-d*6.));
        if(stars>.01){
          // Night sky: one possible star per cell, sliding sideways as the view orbits.
          vec2 s=vec2(lensUv.x*viewport.x/viewport.y,lensUv.y)*84.+vec2(skyTurn,0.);
          vec2 cell=floor(s);cell.x=mod(cell.x,336.);
          float seed=starHash(cell);
          if(seed>.88){
            vec2 spot=.2+.6*vec2(starHash(cell+7.3),starHash(cell+19.1));
            float size=mix(.07,.15,starHash(cell+3.7)),power=pow((seed-.88)/.12,3.);
            float twinkle=.72+.28*sin(clock*(1.3+3.*starHash(cell+11.9))+seed*90.);
            vec3 hue=mix(vec3(.72,.82,1.),vec3(1.,.9,.74),starHash(cell+29.3));
            base+=hue*(.14+1.9*power)*twinkle*stars*(.15+.85*lensUv.y)*smoothstep(size,size*.25,length(fract(s)-spot));
          }
        }
      }
      vec3 color=base*contactLight*v.a+v.rgb;
      color+=texture2D(bloomMap,lensUv).rgb*bloomAmount*moodBloom;
      // Grade: split-tone shadows / highlights, a touch of saturation, soft vignette.
      float lum=dot(color,vec3(.2126,.7152,.0722));
      color*=mix(shadowTint,highlightTint,smoothstep(.02,.45,lum));
      lum=dot(color,vec3(.2126,.7152,.0722));
      color=max(vec3(0.),mix(vec3(lum),color,saturation*moodSaturation))*moodTint;
      color=.18*pow(color/.18,vec3(moodContrast));  // weather contrast, pivoting on mid grey
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
      frame.setSize(w,h);const x=Math.ceil(w*.5),y=Math.ceil(h*.5);
      const fogX=Math.ceil(w*quality.fogScale),fogY=Math.ceil(h*quality.fogScale);
      fog.setSize(fogX,fogY);aoTarget.setSize(x,y);ao.uniforms.resolution.value.set(x,y);
      composite.uniforms.fogSize.value.set(fogX,fogY);
      composite.uniforms.contactSize.value.set(x,y);
      blooms.forEach((target,i)=>target.setSize(Math.max(1,Math.ceil(x/2**i)),Math.max(1,Math.ceil(y/2**i))));
      bright.uniforms.texel.value.set(1/w,1/h);
    },
    set(t,w,densityScale){
      uniforms.density.value=t.value([.033,.016,.045,.032,.03])*(1+.38*w)*densityScale;
      uniforms.scatterColor.value.copy(t.color([0x657577,0x768183,0x957a8c,0x192d45,0x8d5a44])).multiplyScalar(.55);
      uniforms.lampPower.value=t.night;uniforms.golden.value=t.golden*(1-.6*Math.min(1,w));
      uniforms.mistLow.value=(t.dawn?1:.3)*t.golden*(1-.5*Math.min(1,w));uniforms.cloudAmount.value=w<1?T.MathUtils.lerp(.63,.84,w):T.MathUtils.lerp(.84,.94,w-1);
    },
    grade({top,bottom,glow,glowAmount,shadow,highlight,saturation,vignette,bloom,threshold,stars}){
      const u=composite.uniforms;
      u.bgTop.value.copy(top);u.bgBottom.value.copy(bottom);u.glowColor.value.copy(glow);u.glowAmount.value=glowAmount;
      u.shadowTint.value.copy(shadow);u.highlightTint.value.copy(highlight);u.saturation.value=saturation;u.vignette.value=vignette;
      u.bloomAmount.value=bloom;u.stars.value=stars;bright.uniforms.threshold.value=threshold;
    },
    // Weather mood, eased every frame: rain and snowstorms mute colour, fog flattens contrast,
    // snow cover cools the picture, and damp or misty air spreads light further.
    mood(snow,wet,rain,fog,storm,night){
      const u=composite.uniforms,day=1-.6*night;
      u.moodTint.value.set(1-.035*rain-.03*snow*day-.02*storm,1-.005*snow*day,1+.03*rain+.04*snow*day+.02*storm);
      u.moodSaturation.value=1-.15*rain-.1*fog-.14*storm-.04*snow;
      u.moodContrast.value=1+.05*rain-.07*fog-.05*storm;
      u.moodBloom.value=(1+1.1*fog+.5*wet+.2*storm)*(1-.5*snow);  // lit snow is bright enough already
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
      quad.material=bright;renderer.setRenderTarget(blooms[0]);renderer.render(screen,ortho);
      quad.material=shrink;
      for(let i=1;i<blooms.length;i++){
        shrink.uniforms.source.value=blooms[i-1].texture;shrink.uniforms.texel.value.set(1/blooms[i-1].width,1/blooms[i-1].height);
        renderer.setRenderTarget(blooms[i]);renderer.render(screen,ortho);
      }
      quad.material=grow;renderer.autoClear=false;
      for(let i=blooms.length-2;i>=0;i--){
        grow.uniforms.source.value=blooms[i+1].texture;grow.uniforms.texel.value.set(1/blooms[i+1].width,1/blooms[i+1].height);
        renderer.setRenderTarget(blooms[i]);renderer.render(screen,ortho);
      }
      renderer.autoClear=true;
      composite.uniforms.clock.value=seconds;
      camera.getWorldDirection(sunOrigin);composite.uniforms.skyTurn.value=Math.atan2(sunOrigin.x,sunOrigin.z)/(2*Math.PI)*336;
      quad.material=composite;renderer.setRenderTarget(null);renderer.render(screen,ortho);
    }
  };
}
