import * as T from 'three';

export function makeCascade({height,waterY,floor,water}){
  const group=new T.Group(),outlets=[];
  for(let z=4.25;z<=7.95;z+=.018)if(height(15,z)<waterY-.018)outlets.push(z);
  const left=outlets[0],width=outlets.at(-1)-left,drop=waterY-floor;
  const positions=[],uv=[],indices=[],flowData=[];
  const streams=9,steps=48,sides=16;
  const widths=Array.from({length:streams},(_,i)=>.9+.32*Math.sin(i*2.38+.7)+.18*Math.sin(i*4.73));
  const sum=widths.reduce((a,b)=>a+b,0);
  const spans=widths.map(w=>w*width/sum);
  let at=left;
  const centers=spans.map(w=>{const mid=at+w*.5;at+=w;return mid});
  // Overlapping elliptical sections form a single lip and separate during free fall.
  function path(n,t){
    const seed=n*2.39996,a=Math.max(0,t),edge=(n+.5)/streams-.5;
    return [14.76+.24*Math.min(1,(t+.25)*4)+a*(.76+.22*Math.cos(seed))+.09*a*a,
      waterY+.009-drop*a*a,centers[n]+a*a*(edge*.22+.09*Math.sin(seed*2.7))];
  }
  for(let n=0;n<streams;n++){
    const base=positions.length/3,seed=n*2.39996;
    for(let j=0;j<=steps;j++){
      const t=-.25+1.25*j/steps,arc=Math.max(0,t),[x,y,z]=path(n,t);
      const tilt=Math.atan2(2*drop*arc,.84);
      const radius=spans[n]*(.66-.08*arc+.12*Math.cos(seed+arc*8)*arc);
      const thickness=.009+.08*Math.sin(Math.min(1,arc*4)*Math.PI*.5)+.029*arc*Math.cos(seed);
      for(let k=0;k<=sides;k++){
        const a=k/sides*2*Math.PI,side=Math.sin(a),face=Math.cos(a);
        positions.push(x+Math.sin(tilt)*face*thickness,y+Math.cos(tilt)*face*thickness,z+side*radius);
        uv.push(z+side*radius,t);flowData.push(seed,arc,face);
        if(j&&k){const i=base+j*(sides+1)+k;indices.push(i-sides-2,i,i-1,i-sides-2,i-sides-1,i)}
      }
    }
  }
  const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(positions,3));
  g.setAttribute('uv',new T.Float32BufferAttribute(uv,2));g.setAttribute('fallData',new T.Float32BufferAttribute(flowData,3));g.setIndex(indices);g.computeVertexNormals();
  const mat=new T.MeshStandardMaterial({name:'cascade',roughness:.26,transparent:true,depthWrite:true});
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
  const count=280;
  const spray=new T.InstancedMesh(new T.SphereGeometry(1,6,4),new T.MeshStandardMaterial({color:0xb2d5d8,roughness:.21,transparent:true,opacity:.52,depthWrite:false}),count);
  spray.renderOrder=3;spray.frustumCulled=false;group.add(spray);
  const pose=new T.Object3D();
  const droplets=Array.from({length:count},(_,i)=>{
    const [x,y,z]=path(i%streams,.18+.60*((i*.754877)%1));
    return {x,y,z,phase:(i*.618034)%1,speed:.8+.31*Math.sin(i*7.1),spread:Math.sin(i*2.41),radius:.013+.024*((i*.4383)%1)};
  });
  // Fine, backlit spray gathers where the free jets disintegrate at the foot.
  const puff=document.createElement('canvas');puff.width=puff.height=64;
  const ctx=puff.getContext('2d'),gradient=ctx.createRadialGradient(32,32,0,32,32,32);
  gradient.addColorStop(0,'rgba(255,255,255,.64)');gradient.addColorStop(.45,'rgba(255,255,255,.29)');gradient.addColorStop(1,'rgba(255,255,255,0)');
  ctx.fillStyle=gradient;ctx.fillRect(0,0,64,64);
  const fogMap=new T.CanvasTexture(puff);
  const vapor=Array.from({length:24},(_,i)=>{
    const sprite=new T.Sprite(new T.SpriteMaterial({map:fogMap,transparent:true,depthWrite:false,color:0xb5cdd4}));
    sprite.renderOrder=4;group.add(sprite);return sprite;
  });
  group.userData.update=(seconds,wind,light=1)=>{
    const flow=1-T.MathUtils.smoothstep(water.userData.freeze.value,.08,.92);
    falls.visible=spray.visible=flow>.002;
    spray.material.opacity=.52*flow;
    vapor.forEach(sprite=>sprite.visible=flow>.002);
    group.userData.flow=flow;
    if(flow<=.002)return;
    droplets.forEach((d,i)=>{
      const t=(seconds*d.speed+d.phase)%1;
      const y=d.y-t*(.64+d.phase)-4.3*t*t;
      const impact=i%4===0;
      const groundY=floor+.29+t*(1-t)*1.72;
      const size=d.radius*Math.min(1,t*9,impact?(1-t)*4:Math.max(0,y-floor-.14)*4);
      if(impact)pose.position.set(15.77+t*(.4+d.phase*.46),groundY,d.z+t*d.spread*.48);
      else pose.position.set(d.x+t*(.44+.44*d.phase)+t*t*wind*.12,y,d.z+t*d.spread*.33+t*t*wind*.04);
      pose.scale.set(size,size*(1.25+2.7*t),size);pose.rotation.z=.12;
      pose.updateMatrix();spray.setMatrixAt(i,pose.matrix);
    });spray.instanceMatrix.needsUpdate=true;
    vapor.forEach((sprite,i)=>{
      const age=(i*.618+seconds*(.44+(i%5)*.05))%1;
      const [x,y,z]=path(i%streams,.89+.075*Math.sin(i*3.51));
      sprite.position.set(x+.09+age*(.24+.08*wind),y+.23*age,z+Math.sin(i*1.7)*age*.41);
      sprite.scale.setScalar(.32+age*.58);
      sprite.material.opacity=.25*Math.sin(age*Math.PI)*light*flow;
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
    float f=fallCoords.y;
    vec2 flow=vec2(streamUv.x*1.35,(streamUv.y-elapsed*.66)*.60);
    float large=texture2D(cloudMap,flow*.48).r;
    float fold=texture2D(cloudMap,flow+vec2(large*.36,0.)).r;
    float fleck=texture2D(cloudMap,flow*vec2(3.5,2.)+fold*.38).r;
    float shear=sin(streamUv.x*38.+5.*large+fold*6.+.8*sin(flow.y*8.));
    float bubbles=smoothstep(.28,.69,fold*.46+fleck*.45+.12*shear)*smoothstep(.015,.46,f);
    float breakup=smoothstep(.67,1.,f)*smoothstep(.34,.75,fleck+.13*shear);
    bubbles=max(bubbles,breakup*.91);
    diffuseColor.rgb=mix(vec3(.024,.092,.11),vec3(.76,.86,.84),bubbles);
    float endFade=1.-smoothstep(.78+.09*fleck,1.,f);
    diffuseColor.a=mix(.73,.97,bubbles)*endFade*(1.-breakup*.55);
    diffuseColor.a*=1.-smoothstep(.08,.92,fallIce);
    if(diffuseColor.a<.045)discard;`);
  shader.fragmentShader=shader.fragmentShader.replace('#include <normal_fragment_maps>',`
    #include <normal_fragment_maps>
    normal=normalize(normal+mat3(viewMatrix)*vec3((fold-.5)*.28,(fleck-.5)*.19,(large-.5)*.38));`);
  shader.fragmentShader=shader.fragmentShader.replace('#include <opaque_fragment>',`
    vec3 ray=reflect(-vec3(0.,0.,1.),normal);
    vec3 reflectedSky=texture2D(fallSky,equirectUv(inverseTransformDirection(ray,viewMatrix))).rgb;
    float fresnel=.025+.80*pow(1.-clamp(normal.z,0.,1.),5.);
    outgoingLight=mix(outgoingLight,reflectedSky,fresnel*(1.-bubbles*.78));
    #include <opaque_fragment>`);
}
