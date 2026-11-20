import * as T from 'three';
import {quality} from './mobile-quality.js';

export function makeCascade({height,waterY,floor,water},storybook){
  const group=new T.Group(),outlets=[];
  for(let z=4.25;z<=7.95;z+=.018)if(height(15,z)<waterY-.018)outlets.push(z);
  const left=outlets[0],width=outlets.at(-1)-left,drop=waterY-floor;
  // One continuous curtain (two layers for depth) instead of separate tubes: columns across
  // the outlet, rows down a ballistic arc. fallData = (layer seed, arc 0..1, across 0..1).
  const positions=[],uv=[],indices=[],flowData=[];
  const columns=44,rows=56;
  function path(across,t,layer=0){
    const a=Math.max(0,t),wave=Math.sin(across*17.3+layer*2.1)*.5+Math.sin(across*5.1+1.3)*.5;
    return [14.76+.24*Math.min(1,(t+.25)*4)+a*(.78+.05*wave)+.08*a*a+layer*.045*a,
      waterY+.012-drop*a*a,left+across*width+a*a*(across-.5)*.28];
  }
  for(let layer=0;layer<2;layer++){
    const base=positions.length/3;
    for(let j=0;j<=rows;j++){
      const t=-.25+1.25*j/rows;
      for(let i=0;i<=columns;i++){
        const across=i/columns,[x,y,z]=path(across,t,layer);
        positions.push(x,y,z);uv.push(z*1.9,t);flowData.push(layer*3.7+across*11.,Math.max(0,t),across);
        if(i&&j){const k=base+j*(columns+1)+i;indices.push(k-columns-2,k-1,k,k-columns-2,k,k-columns-1)}
      }
    }
  }
  const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(positions,3));
  g.setAttribute('uv',new T.Float32BufferAttribute(uv,2));g.setAttribute('fallData',new T.Float32BufferAttribute(flowData,3));g.setIndex(indices);g.computeVertexNormals();
  const mat=new T.MeshStandardMaterial({name:'cascade',roughness:.22,transparent:true,depthWrite:false,side:T.DoubleSide});
  const falls=new T.Mesh(g,mat);falls.receiveShadow=true;falls.renderOrder=2;group.add(falls);
  const stone=new T.DodecahedronGeometry(1,1);
  const vertices=stone.attributes.position;
  for(let i=0;i<vertices.count;i++){
    const x=vertices.getX(i),y=vertices.getY(i),z=vertices.getZ(i);
    const displacement=1+.12*Math.sin(4*x+z)*Math.cos(5*z-y);
    vertices.setXYZ(i,x*displacement,y*displacement,z*displacement);
  }
  stone.computeVertexNormals();
  const rockMat=new T.MeshStandardMaterial({color:0x515b56,roughness:.36});
  function rock(x,y,z,w,h,d,angle){
    const mesh=new T.Mesh(stone,rockMat);mesh.position.set(x,y,z);mesh.scale.set(w,h,d);
    mesh.rotation.set(.13,angle,-.14);mesh.castShadow=true;mesh.receiveShadow=true;group.add(mesh);
  }
  const middle=left+width*.5;
  rock(15.36,floor+.08,middle,1.11,.34,width*.73,.08);
  rock(15.84,floor+.10,left+.18,.49,.27,.57,.72);
  rock(15.68,floor+.07,left+width*.82,.62,.32,.52,-.4);
  for(const [z,sign] of [[left,-1],[left+width,1]]){
    rock(14.93,waterY+.03,z+sign*.12,.37,.23,.32,sign*.6);
    rock(15.10,waterY-.31,z+sign*.09,.28,.28,.41,-sign*.25);
  }
  // Soft round droplets (screen-aligned points sized in world units) replace stretched spheres.
  const count=quality.cascadeDrops,dropPos=new Float32Array(count*3),dropSize=new Float32Array(count),dropAlpha=new Float32Array(count);
  const dropGeo=new T.BufferGeometry();
  dropGeo.setAttribute('position',new T.BufferAttribute(dropPos,3).setUsage(T.DynamicDrawUsage));
  dropGeo.setAttribute('size',new T.BufferAttribute(dropSize,1).setUsage(T.DynamicDrawUsage));
  dropGeo.setAttribute('alpha',new T.BufferAttribute(dropAlpha,1).setUsage(T.DynamicDrawUsage));
  const dropMat=new T.ShaderMaterial({transparent:true,depthWrite:false,uniforms:{pixels:{value:1},light:{value:1}},
    vertexShader:`attribute float size,alpha;varying float vAlpha;uniform float pixels;
      void main(){vAlpha=alpha;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);gl_PointSize=max(1.,size*pixels);}`,
    fragmentShader:`varying float vAlpha;uniform float light;
      void main(){vec2 c=gl_PointCoord-.5;float d=1.-dot(c,c)*4.;if(d<=0.)discard;
        gl_FragColor=vec4(vec3(.82,.9,.92)*light,d*d*vAlpha);}`});
  const spray=new T.Points(dropGeo,dropMat);spray.frustumCulled=false;spray.renderOrder=3;group.add(spray);
  spray.onBeforeRender=(renderer,scene,camera)=>{
    const h=renderer.getRenderTarget()?.height??renderer.domElement.height;
    dropMat.uniforms.pixels.value=h*camera.zoom/(camera.top-camera.bottom);
  };
  const footY=floor+.27,droplets=Array.from({length:count},(_,i)=>({i,life:0,max:1,x:0,y:-99,z:0,vx:0,vy:0,vz:0,size:0,splash:i>=Math.ceil(count/3)}));
  function spawn(d,wind){
    if(!d.splash){ // shed from the curtain, mostly in the lower half
      const across=Math.random(),t=.25+.7*Math.random(),[x,y,z]=path(across,t);
      Object.assign(d,{x,y,z,vx:.7+.5*Math.random()+wind*.04,vy:-2*drop*t*.55-Math.random()*.5,vz:(across-.5)*.6+(Math.random()-.5)*.3,
        life:0,max:.35+Math.random()*.5,size:.018+Math.random()*.03});
    }else{ // kicked back up where the curtain lands on the rocks
      const across=Math.random(),[x,,z]=path(across,1),speed=.6+Math.random()*1.5,angle=Math.random()*Math.PI*2;
      Object.assign(d,{x:x+(Math.random()-.4)*.25,y:footY,z:z+(Math.random()-.5)*.25,vx:Math.cos(angle)*speed*.55+.25,vy:.8+Math.random()*1.7,
        vz:Math.sin(angle)*speed*.55,life:0,max:.45+Math.random()*.55,size:.02+Math.random()*.045});
    }
  }
  // Fine, backlit spray gathers where the free jets disintegrate at the foot.
  const puff=document.createElement('canvas');puff.width=puff.height=64;
  const ctx=puff.getContext('2d'),gradient=ctx.createRadialGradient(32,32,0,32,32,32);
  gradient.addColorStop(0,'rgba(255,255,255,.64)');gradient.addColorStop(.45,'rgba(255,255,255,.29)');gradient.addColorStop(1,'rgba(255,255,255,0)');
  ctx.fillStyle=gradient;ctx.fillRect(0,0,64,64);
  const fogMap=new T.CanvasTexture(puff);
  // Churning foam where the curtain lands: a disc whose noise scrolls outward from the impact.
  // Tileable blotchy noise for the foam (soft random dabs, wrapped at the edges).
  const noiseCanvas=document.createElement('canvas');noiseCanvas.width=noiseCanvas.height=128;
  {const c=noiseCanvas.getContext('2d');c.fillStyle='#000';c.fillRect(0,0,128,128);
    for(let i=0;i<260;i++){const x=Math.random()*128,y=Math.random()*128,r=3+Math.random()*11;
      for(const ox of [-128,0,128])for(const oy of [-128,0,128]){
        const g=c.createRadialGradient(x+ox,y+oy,0,x+ox,y+oy,r);g.addColorStop(0,'rgba(255,255,255,.55)');g.addColorStop(1,'rgba(255,255,255,0)');
        c.fillStyle=g;c.fillRect(x+ox-r,y+oy-r,r*2,r*2)}}}
  const foamNoise=new T.CanvasTexture(noiseCanvas);foamNoise.wrapS=foamNoise.wrapT=T.RepeatWrapping;
  const foamClock={value:0};
  const foam=new T.Mesh(new T.CircleGeometry(1,40),new T.MeshStandardMaterial({color:0xe4eef0,roughness:.5,transparent:true,depthWrite:false,opacity:.85}));
  foam.material.userData.clock=foamClock;
  foam.material.onBeforeCompile=shader=>{
    shader.uniforms.clock=foamClock;shader.uniforms.noiseMap={value:foamNoise};
    shader.vertexShader='varying vec2 foamUv;\n'+shader.vertexShader.replace('#include <begin_vertex>','#include <begin_vertex>\nfoamUv=position.xy;');
    shader.fragmentShader='uniform float clock;uniform sampler2D noiseMap;varying vec2 foamUv;\n'+shader.fragmentShader.replace('#include <color_fragment>',`
      #include <color_fragment>
      float r=length(foamUv);vec2 dir=foamUv/max(r,.001);
      // two noise layers drift outward from the impact at different speeds
      float n1=texture2D(noiseMap,foamUv*.9-dir*clock*.18).r,n2=texture2D(noiseMap,foamUv*1.7+vec2(.37,.11)-dir*clock*.31).r;
      float lace=smoothstep(.22,.62,n1*.6+n2*.55);
      diffuseColor.a*=lace*(1.-smoothstep(.4,1.,r));`);
  };
  foam.rotation.x=-Math.PI/2;foam.renderOrder=3;
  {const [x,,z]=path(.5,1);foam.position.set(x,footY+.01,z);foam.scale.set(width*.55+.2,width*.5+.18,1)}
  group.add(foam);
  const foamClumps=new T.InstancedMesh(new T.IcosahedronGeometry(1,1),
    new T.MeshBasicMaterial(),22);
  const shape=new T.Object3D(),shade=new T.Color();
  for(let i=0;i<foamClumps.count;i++){
    const across=(i%11)/10,outer=i>=11,scale=.11+.11*Math.sin(i*5.13)**2;
    shape.position.set(15.87+(outer?.21:0)+.11*Math.sin(i*3.1),footY+.04+.08*Math.sin(i*2.5),left+across*width);
    shape.scale.set(scale*1.7,scale*.74,scale*1.2);shape.updateMatrix();
    foamClumps.setMatrixAt(i,shape.matrix);
    foamClumps.setColorAt(i,shade.setHex([0xd2e6ea,0xf3f7ed,0xa2c5cf,0xe4eff2][i%4]));
  }
  foamClumps.visible=false;foamClumps.userData.styleVariant=true;group.add(foamClumps);
  const vapor=Array.from({length:quality.cascadeMist},(_,i)=>{
    const sprite=new T.Sprite(new T.SpriteMaterial({map:fogMap,transparent:true,depthWrite:false,color:0xb5cdd4}));
    sprite.renderOrder=4;group.add(sprite);return sprite;
  });
  group.userData.update=(seconds,wind,light=1)=>{
    const flow=1-T.MathUtils.smoothstep(water.userData.freeze.value,.08,.92);
    falls.visible=spray.visible=foam.visible=flow>.002;
    foamClumps.visible=storybook.value>0&&flow>.05;
    foamClumps.material.color.setScalar(.19+.81*light);
    foamClumps.position.y=.028*Math.sin(seconds*5.8);
    vapor.forEach(sprite=>sprite.visible=flow>.002&&storybook.value===0);
    group.userData.flow=flow;
    if(flow<=.002)return;
    const dt=Math.min(.05,Math.max(0,seconds-(group.userData.last??seconds)));group.userData.last=seconds;
    dropMat.uniforms.light.value=light;
    for(const d of droplets){
      d.life+=dt;
      if(d.life>=d.max||d.y<floor-.1)spawn(d,wind);
      d.vy-=9.8*.55*dt;d.x+=d.vx*dt;d.y+=d.vy*dt;d.z+=d.vz*dt;
      if(d.splash&&d.y<footY-.02)d.life=d.max;
      const k=d.i*3,fade=Math.sin(Math.min(1,d.life/d.max)*Math.PI);
      dropPos[k]=d.x;dropPos[k+1]=d.y;dropPos[k+2]=d.z;dropSize[d.i]=d.size;dropAlpha[d.i]=(d.splash?.75:.6)*fade*flow;
    }
    dropGeo.attributes.position.needsUpdate=dropGeo.attributes.size.needsUpdate=dropGeo.attributes.alpha.needsUpdate=true;
    foam.material.opacity=.6*flow;foam.material.userData.clock.value=seconds;
    vapor.forEach((sprite,i)=>{
      const age=(i*.618+seconds*(.44+(i%5)*.05))%1;
      const [x,y,z]=path((i*.618)%1,.9+.07*Math.sin(i*3.51));
      sprite.position.set(x+.09+age*(.24+.08*wind),y+.23*age,z+Math.sin(i*1.7)*age*.41);
      sprite.scale.setScalar(.4+age*.8);
      sprite.material.opacity=.2*Math.sin(age*Math.PI)*light*flow;
    });
  };
  group.userData.update(0,0);return group;
}

export function shadeCascade(shader,water){
  shader.uniforms.fallIce=water.userData.freeze;
  shader.uniforms.fallSky={value:water.userData.skyTexture};
  shader.vertexShader='attribute vec3 fallData; varying vec3 fallCoords; varying vec2 streamUv;\n'+shader.vertexShader.replace('#include <begin_vertex>',`
    #include <begin_vertex>
    streamUv=uv;fallCoords=fallData;
    float flight=fallData.y;
    float pulse=sin(flight*20.-elapsed*8.+fallData.x+sin(uv.x*9.+elapsed))*.020;
    transformed.x+=flight*(pulse+.015*sin(flight*42.-elapsed*14.+uv.x*8.));
    transformed.z+=flight*(.022+.013*breeze)*sin(flight*9.-elapsed*3.+fallData.x);`);
  shader.fragmentShader='uniform float fallIce; uniform sampler2D fallSky; varying vec3 fallCoords; varying vec2 streamUv;\n'+shader.fragmentShader.replace('#include <color_fragment>',`
    #include <color_fragment>
    float f=fallCoords.y,across=fallCoords.z,backLayer=step(3.,fallCoords.x-across*11.);
    vec2 flow=vec2(streamUv.x*1.2,(streamUv.y-elapsed*1.35)*.55);
    float large=texture2D(cloudMap,flow*.45).r;
    // fine vertical streaks racing down the sheet
    float fold=texture2D(cloudMap,vec2(streamUv.x*3.4+large*.3,(streamUv.y-elapsed*1.9)*.2)).r;
    float fleck=texture2D(cloudMap,flow*vec2(4.,2.5)+large*.4).r;
    float bubbles=smoothstep(.52,.86,fold*.55+fleck*.45)*(.2+.8*smoothstep(.04,.75,f));
    float breakup=smoothstep(.72,1.,f)*smoothstep(.3,.75,fleck);
    bubbles=max(bubbles,breakup*.9);
    diffuseColor.rgb=mix(vec3(.045,.15,.17),vec3(.86,.93,.94),bubbles)*mix(1.,.72,backLayer);
    float edge=smoothstep(0.,.09+.1*large,across)*smoothstep(1.,.91-.1*fleck,across);
    float sheet=.38+.36*fold;
    diffuseColor.a=mix(sheet,.95,bubbles)*edge*(1.-smoothstep(.82+.1*fleck,1.,f))*(1.-breakup*.5)*mix(1.,.75,backLayer);
    if(storybook>.5){
      float ribbon=fract(across*9.+.08*sin(f*5.+across*22.)+large*.30);
      float streak=1.-smoothstep(.07,.18,abs(ribbon-.3));
      float chalk=max(streak*.88,smoothstep(.62,.95,f)*smoothstep(.38,.64,fleck));
      diffuseColor.rgb=mix(vec3(.06,.26,.35),vec3(.87,.96,.99),chalk);
      diffuseColor.a=mix(diffuseColor.a,.88*edge,storyDay);
    }
    diffuseColor.a*=1.-smoothstep(.08,.92,fallIce);
    if(diffuseColor.a<.03)discard;`);
  shader.fragmentShader=shader.fragmentShader.replace('#include <normal_fragment_maps>',`
    #include <normal_fragment_maps>
    normal=normalize(normal+mat3(viewMatrix)*vec3((fold-.5)*.28,(fleck-.5)*.19,(large-.5)*.38));`);
  shader.fragmentShader=shader.fragmentShader.replace('#include <opaque_fragment>',`
    vec3 ray=reflect(-vec3(0.,0.,1.),normal);
    vec3 reflectedSky=texture2D(fallSky,equirectUv(inverseTransformDirection(ray,viewMatrix))).rgb;
    float fresnel=.025+.80*pow(1.-clamp(normal.z,0.,1.),5.);
    outgoingLight=mix(outgoingLight,reflectedSky,fresnel*(1.-bubbles*.78));
    if(storybook>.5)outgoingLight=mix(outgoingLight,diffuseColor.rgb,storyDay*.91);
    #include <opaque_fragment>`);
}
