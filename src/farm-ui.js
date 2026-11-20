// DOM side of the farm game: the coin/level HUD, a tag floating over each bed, the seed
// picker, crop info, harvest rewards and level-up toasts. farm.js owns the rules and state.
const el=(tag,cls,html)=>{const e=document.createElement(tag);if(cls)e.className=cls;if(html!==undefined)e.innerHTML=html;return e};
export function duration(seconds){
  seconds=Math.ceil(seconds);
  if(seconds<60)return seconds+'초';
  const m=Math.floor(seconds/60),s=seconds%60;
  return s?m+'분 '+s+'초':m+'분';
}
const clock=seconds=>{seconds=Math.ceil(seconds);return Math.floor(seconds/60)+':'+String(seconds%60).padStart(2,'0')};

export function createFarmUI({crops,levels,levelOf,plant,clear}){
  const layer=el('div','farm-layer');layer.id='farmLayer';
  const hud=el('div','farm-hud',`
    <div class="farm-level" aria-label="레벨"><b>Lv.1</b><span class="farm-xp"><i></i></span><small></small></div>
    <div class="farm-coins" aria-label="코인"><span aria-hidden="true">🪙</span><output>0</output></div>`);
  hud.id='farmHud';
  const popup=el('div','farm-popup');popup.hidden=true;popup.setAttribute('role','dialog');
  layer.append(popup);
  document.querySelector('main').append(layer,hud);
  const tags=[],spots=[];let openIndex=-1,state=null,api;
  const coins=hud.querySelector('output');let shownCoins=null;

  function tagFor(index){
    if(tags[index])return tags[index];
    const tag=el('button','plot-tag');tag.type='button';tag.dataset.state='empty';
    tag.innerHTML='<span class="plot-icon"></span><span class="plot-meter"><i></i></span><span class="plot-text"></span>';
    tag.addEventListener('click',e=>{e.stopPropagation();api.onTag?.(index)});
    layer.insertBefore(tag,popup);tags[index]={tag,key:'',bar:tag.querySelector('.plot-meter i'),text:tag.querySelector('.plot-text'),icon:tag.querySelector('.plot-icon')};
    return tags[index];
  }
  function position(){
    if(openIndex<0||!spots[openIndex])return;
    const {x,y}=spots[openIndex],w=popup.offsetWidth,h=popup.offsetHeight,pad=10;
    const left=Math.min(innerWidth-w-pad,Math.max(pad,x-w/2));
    let top=y-h-26;if(top<pad)top=Math.min(innerHeight-h-pad,y+30);
    popup.style.transform=`translate(${Math.round(left)}px,${Math.round(top)}px)`;
  }
  function open(index,html){
    openIndex=index;popup.innerHTML=html;popup.hidden=false;popup.classList.remove('show');
    void popup.offsetWidth;popup.classList.add('show');position();
    popup.querySelector('.farm-close')?.addEventListener('click',close);
    tags.forEach((t,i)=>t?.tag.classList.toggle('selected',i===index));
  }
  function close(){
    if(openIndex<0)return;openIndex=-1;popup.hidden=true;popup.innerHTML='';
    tags.forEach(t=>t?.tag.classList.remove('selected'));
  }
  addEventListener('keydown',e=>{if(e.key==='Escape')close()});
  const header=(title,index)=>`<header><strong>${title}</strong><span class="farm-plot-no">${index+1}번 밭</span><button type="button" class="farm-close" aria-label="닫기">✕</button></header>`;

  api={
    onTag:null,close,
    refresh(next){
      state=next;
      const level=levelOf(state.xp),from=levels[level-1],to=levels[level];
      hud.querySelector('.farm-level b').textContent='Lv.'+level;
      hud.querySelector('.farm-xp i').style.width=(to===undefined?100:(state.xp-from)/(to-from)*100)+'%';
      hud.querySelector('.farm-level small').textContent=to===undefined?'MAX':`${state.xp-from} / ${to-from} XP`;
      if(shownCoins!==null&&state.coins>shownCoins){coins.parentElement.classList.remove('bump');void coins.offsetWidth;coins.parentElement.classList.add('bump')}
      shownCoins=state.coins;coins.textContent=state.coins.toLocaleString('ko-KR');
      if(openIndex>=0&&popup.querySelector('.seed-list'))api.openPicker(openIndex,state,true);
    },
    openPicker(index,current,refresh=false){
      const level=levelOf(current.xp);
      const items=crops.map(c=>{
        const locked=level<c.level,poor=current.coins<c.cost;
        return `<button type="button" class="seed" data-crop="${c.id}" ${locked||poor?'disabled':''} ${locked?'data-locked':''}>
          <span class="seed-icon">${c.icon}</span>
          <span class="seed-name">${c.name}<small>${locked?'🔒 Lv.'+c.level+' 해금':'⏱ '+duration(c.seconds)}</small></span>
          <span class="seed-price"><span class="${poor&&!locked?'short':''}">🪙 ${c.cost}</span><small>수확 ${c.sell}</small></span>
        </button>`;
      }).join('');
      const scroll=refresh?popup.querySelector('.seed-list')?.scrollTop:0;
      open(index,header('씨앗 심기',index)+`<div class="seed-list">${items}</div>`);
      if(scroll)popup.querySelector('.seed-list').scrollTop=scroll;
      popup.querySelectorAll('.seed').forEach(b=>b.addEventListener('click',()=>{if(plant(index,b.dataset.crop))close()}));
      if(!refresh)popup.querySelector('.seed:not([disabled])')?.focus({preventScroll:true});
    },
    openInfo(index,info){
      open(index,header(info.crop.icon+' '+info.crop.name,index)+`
        <div class="farm-info"><div class="farm-info-row"><span>수확까지</span><b class="farm-left">${clock(info.left)}</b></div>
        <span class="farm-bar"><i style="width:${info.growth*100}%"></i></span>
        <div class="farm-info-row"><span>예상 수확</span><b>🪙 ${info.crop.sell} · ${info.crop.xp} XP</b></div>
        <button type="button" class="farm-clear">갈아엎기</button></div>`);
      const button=popup.querySelector('.farm-clear');
      button.addEventListener('click',()=>{
        if(button.dataset.confirm){clear(index);close()}
        else{button.dataset.confirm='1';button.textContent='씨앗값은 돌려받지 못해요. 정말 갈아엎을까요?'}
      });
    },
    compact(on){if(layer.classList.contains('compact')!==on)layer.classList.toggle('compact',on)},
    hover(index){tags.forEach((t,i)=>t?.tag.classList.toggle('hovered',i===index))},
    place(index,x,y,visible,info){
      const t=tagFor(index);spots[index]={x,y};
      t.tag.hidden=!visible;
      if(visible)t.tag.style.transform=`translate(${Math.round(x)}px,${Math.round(y)}px)`;
      const ready=info&&info.growth>=1;
      const key=!info?'empty':ready?'ready:'+info.crop.id:'grow:'+info.crop.id+':'+Math.ceil(info.left);
      if(key!==t.key){
        const changed=t.key.split(':')[0]!==key.split(':')[0];t.key=key;
        t.tag.dataset.state=!info?'empty':ready?'ready':'growing';
        t.icon.textContent=info?info.crop.icon:'＋';
        t.text.textContent=!info?'':ready?'수확':clock(info.left);
        t.tag.setAttribute('aria-label',(index+1)+'번 밭: '+(!info?'비어 있음, 심기':ready?info.crop.name+' 수확하기':info.crop.name+' 자라는 중, '+duration(info.left)+' 남음'));
        if(changed&&openIndex===index&&ready)close();
        if(openIndex===index&&!info&&!popup.querySelector('.seed-list'))close();
      }
      if(info&&!ready){t.bar.style.width=(info.growth*100).toFixed(1)+'%';t.tag.style.setProperty('--p',info.growth.toFixed(3))}
      if(openIndex===index){
        position();
        const left=popup.querySelector('.farm-left'),bar=popup.querySelector('.farm-bar i');
        if(left&&info){left.textContent=clock(info.left);bar.style.width=(info.growth*100).toFixed(1)+'%'}
      }
    },
    reward(index,crop){
      const spot=spots[index];if(!spot)return;
      const float=el('div','farm-float',`<span>${crop.icon} +${crop.sell} 🪙</span><small>+${crop.xp} XP</small>`);
      float.style.left=spot.x+'px';float.style.top=spot.y+'px';
      layer.append(float);float.addEventListener('animationend',()=>float.remove());
    },
    levelUp(level,unlocked){
      const toast=el('div','farm-toast',`<strong>레벨 업! Lv.${level}</strong>${unlocked.length?'<span>'+unlocked.map(c=>c.icon+' '+c.name).join(', ')+' 씨앗 해금</span>':''}`);
      toast.setAttribute('role','status');
      layer.append(toast);toast.addEventListener('animationend',()=>toast.remove());
    }
  };
  return api;
}
