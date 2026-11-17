import * as T from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {quality} from './mobile-quality.js';
import {mobileTurfGeometry} from './turf-lod.js';

// Blender-built nature meshes (tools/nature-assets.py). Each mesh becomes an instanced
// builder kind; `material` picks the shared surface so wind, seasons and snow still apply.
const KINDS={
  oakABark:{material:'bark'},oakBBark:{material:'bark'},pineABark:{material:'bark'},
  oakALeaves:{material:'spray',plant:true},oakBLeaves:{material:'spray',plant:true},
  pineANeedles:{material:'needle'},
  bushATwigs:{material:'bark'},bushBTwigs:{material:'bark'},
  bushALeaves:{material:'spray',plant:true,sway:.05},bushBLeaves:{material:'spray',plant:true,sway:.05},
  grass0:{material:'grass',plant:true,sway:.39,shadow:false},grass1:{material:'grass',plant:true,sway:.39,shadow:false},grass2:{material:'grass',plant:true,sway:.39,shadow:false},
  turf0:{material:'grass',plant:true,sway:.39,shadow:false},turf1:{material:'grass',plant:true,sway:.39,shadow:false},turf2:{material:'grass',plant:true,sway:.39,shadow:false},
  reed:{material:'grass',plant:true,sway:.3},carrot:{material:'grass',plant:true,sway:.3},
  flowerStem:{material:'grass',plant:true,sway:.25},flowerHead:{material:'petal',plant:true,sway:.25},
  cabbage:{material:'cabbage',plant:true},
  bedFrame:{material:'wood-uv'},bedSoil:{material:'soil'},
  stumpBark:{material:'bark'},stumpTop:{material:'wood-uv'}
};

export async function loadNature(url=import.meta.env.BASE_URL+'models/nature.glb'){
  const gltf=await new GLTFLoader().loadAsync(url),kinds=new Map();
  gltf.scene.updateMatrixWorld(true);
  gltf.scene.traverse(o=>{
    const spec=KINDS[o.name];if(!o.isMesh||!spec)return;
    let geometry=o.geometry.clone().applyMatrix4(o.matrixWorld);
    if(!geometry.hasAttribute('color')){
      geometry.setAttribute('color',new T.Float32BufferAttribute(new Float32Array(geometry.attributes.position.count*3).fill(1),3));
    }
    if(quality.mobile&&/^turf[0-2]$/.test(o.name)){
      const reduced=mobileTurfGeometry(geometry);
      if(reduced!==geometry){geometry.dispose();geometry=reduced}
    }
    kinds.set(o.name,{geometry,...spec});
  });
  for(const name of Object.keys(KINDS))if(!kinds.has(name))console.warn('nature asset missing',name);
  return kinds;
}
