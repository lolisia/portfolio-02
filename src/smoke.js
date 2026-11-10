import * as T from 'three';

export function createChimneySmoke(scene,world){
  const source=new T.Vector3(-1.78,world.height(-1,-1.8)+3.82,-2.35);
  const count=144,centers=new Float32Array(count*3),sizes=new Float32Array(count),ages=new Float32Array(count),seeds=new Float32Array(count);
  const plane=new T.PlaneGeometry(1,1),geo=new T.InstancedBufferGeometry();
  geo.index=plane.index;geo.attributes.position=plane.attributes.position;geo.attributes.uv=plane.attributes.uv;geo.instanceCount=count;
  geo.setAttribute('smokeCenter',new T.InstancedBufferAttribute(centers,3).setUsage(T.DynamicDrawUsage));
  geo.setAttribute('smokeSize',new T.InstancedBufferAttribute(sizes,1).setUsage(T.DynamicDrawUsage));
  geo.setAttribute('smokeAge',new T.InstancedBufferAttribute(ages,1).setUsage(T.DynamicDrawUsage));
  geo.setAttribute('smokeSeed',new T.InstancedBufferAttribute(seeds,1));
  const material=new T.ShaderMaterial({transparent:true,depthWrite:false,uniforms:{clock:{value:0},night:{value:0}},
    vertexShader:`
      attribute vec3 smokeCenter;attribute float smokeSize,smokeAge,smokeSeed;
      varying vec2 smokeUv;varying float age,seed;
      void main(){
        smokeUv=uv;age=smokeAge;seed=smokeSeed;
        float a=smokeSeed+smokeAge*2.;mat2 spin=mat2(cos(a),sin(a),-sin(a),cos(a));
        vec4 center=modelViewMatrix*vec4(smokeCenter,1.);
        center.xy+=spin*position.xy*smokeSize;
        gl_Position=projectionMatrix*center;
      }`,
    fragmentShader:`
      uniform float clock,night;varying vec2 smokeUv;varying float age,seed;
      float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
      float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.),f.x),f.y);}
      float fbm(vec2 p){float n=0.,a=.5;for(int i=0;i<4;i++){n+=a*noise(p);p=mat2(.8,.6,-.6,.8)*p*2.03+7.1;a*=.5;}return n;}
      void main(){
        vec2 p=smokeUv*2.-1.;
        vec2 flow=vec2(seed,clock*.07);
        float billow=fbm(p*2.5+flow);
        float detail=fbm(p*7.+flow*.6);
        float edge=1.-smoothstep(.22,1.,length(p)+(billow-.5)*.34);
        float density=smoothstep(.16,.76,billow*.75+detail*.25);
        float life=smoothstep(0.,.035,age)*(1.-smoothstep(.68,1.,age));
        float alpha=edge*density*life*.24;
        vec3 soot=mix(vec3(.13,.135,.13),vec3(.42,.43,.40),smoothstep(0.,.55,age));
        soot+=vec3(.08,.075,.065)*detail;
        soot*=1.-night*.46;
        gl_FragColor=vec4(soot,alpha);
        #include <tonemapping_fragment>
        #include <colorspace_fragment>
      }`});
  const smoke=new T.Mesh(geo,material);smoke.name='chimney-smoke';smoke.frustumCulled=false;smoke.renderOrder=5;scene.add(smoke);
  const puffs=Array.from({length:count},(_,i)=>{
    const age=i/count*32,seed=i*2.399;
    seeds[i]=seed;
    return {age,life:32,seed,x:source.x+Math.log(1+age*.12)*3*.075/.12,y:source.y+.94*age+.009*age*age,z:source.z+Math.log(1+age*.12)*3*.027/.12};
  });
  const projected=new T.Vector3(),up=new T.Vector3();
  return (dt,seconds,wind,camera,night=0)=>{
    let rise=32;
    if(camera){
      projected.copy(source).project(camera);up.copy(source).add(new T.Vector3(0,1,0)).project(camera);
      rise=T.MathUtils.clamp((1.14-projected.y)/Math.max(.015,up.y-projected.y),18,64);
    }
    const lifetime=T.MathUtils.clamp((- .94+Math.sqrt(.94*.94+.036*rise))/.018+5,24,54);
    let highest=source.y;
    puffs.forEach((p,i)=>{
      p.age+=dt;
      if(p.age>=p.life){p.age=0;p.life=lifetime;p.x=source.x;p.y=source.y;p.z=source.z}
      const age=p.age,turbulence=Math.min(1,age*.17);
      p.x+=dt*(wind*.075/(1+age*.12)+Math.sin(seconds*.73+p.seed)*.16*turbulence);
      p.z+=dt*(wind*.027/(1+age*.12)+Math.cos(seconds*.61+p.seed)*.13*turbulence);
      p.y+=dt*(.94+age*.018+Math.sin(seconds*.6+p.seed)*.09*turbulence);
      centers.set([p.x,p.y,p.z],i*3);sizes[i]=.26+Math.pow(age,.85)*.23;ages[i]=age/p.life;
      highest=Math.max(highest,p.y);
    });
    for(const name of ['smokeCenter','smokeSize','smokeAge'])geo.attributes[name].needsUpdate=true;
    material.uniforms.clock.value=seconds;material.uniforms.night.value=night;
    Object.assign(smoke.userData,{windSpeed:wind,highest,screenRise:rise,lifetime});
  };
}
