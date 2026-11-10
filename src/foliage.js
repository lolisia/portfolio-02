import * as T from 'three';

// A branching spray of lanceolate leaves, shared by the canopy and its shadow caster.
export function leafSpray(needles=false){
  const canvas=document.createElement('canvas');canvas.width=canvas.height=256;
  const c=canvas.getContext('2d');
  function sprig(x,y,length,angle,levels){
    const ex=x+length*Math.cos(angle),ey=y+length*Math.sin(angle);
    c.strokeStyle=levels?'#78774d':'#9a9b67';c.lineWidth=levels+1.1;
    c.beginPath();c.moveTo(x,y);c.lineTo(ex,ey);c.stroke();
    const count=needles?15:5;
    for(let i=1;i<=count;i++)for(const side of [-1,1]){
      const t=(i-.26*(side+1))/(count+1),a=angle+side*(.68+.24*Math.sin(i));
      const bx=x+(ex-x)*t,by=y+(ey-y)*t;
      if(levels){if(i%2===1)sprig(bx,by,length*(.47-.19*t),a,levels-1);continue}
      const n=(needles?17:25)*(1-.38*t),w=needles?1.6:8;
      c.save();c.translate(bx,by);c.rotate(a);
      c.fillStyle=['#dce4be','#d1d9ac','#f0edc7','#bac791'][(i+(side+1))%4];
      c.beginPath();c.moveTo(0,0);c.quadraticCurveTo(n*.44,-w,n,0);c.quadraticCurveTo(n*.5,w,0,0);c.fill();
      if(!needles){c.strokeStyle='#a5b388';c.lineWidth=.85;c.beginPath();c.moveTo(0,0);c.lineTo(n*.84,0);c.stroke()}
      c.restore();
    }
  }
  sprig(111,239,201,-1.43,1);sprig(111,229,133,-2.04,1);sprig(111,224,122,-.94,1);
  const map=new T.CanvasTexture(canvas);map.colorSpace=T.SRGBColorSpace;map.anisotropy=4;return map;
}
