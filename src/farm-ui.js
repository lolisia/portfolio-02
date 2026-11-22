// DOM side of the farm game: the coin/level HUD, a tag floating over each bed, the seed
// picker, crop info, harvest rewards and level-up toasts. farm.js owns the rules and state.
const el=(tag,cls,html)=>{const e=document.createElement(tag);if(cls)e.className=cls;if(html!==undefined)e.innerHTML=html;return e};
export function duration(seconds){
  seconds=Math.ceil(seconds);
  if(seconds<60)return seconds+'초';
  const h=Math.floor(seconds/3600),m=Math.floor(seconds/60)%60,s=seconds%60;
  if(h)return m?h+'시간 '+m+'분':h+'시간';
  return s?m+'분 '+s+'초':m+'분';
}
// Countdown: m:ss under an hour, h:mm:ss above.
const clock=seconds=>{
  seconds=Math.ceil(seconds);const h=Math.floor(seconds/3600),m=Math.floor(seconds/60)%60,s=String(seconds%60).padStart(2,'0');
  return h?h+':'+String(m).padStart(2,'0')+':'+s:m+':'+s;
};

export function createFarmUI({crops,levels,levelOf,plant,clear,cancel,wallet}){
  const layer=el('div','farm-layer');layer.id='farmLayer';
  const hud=el('div','farm-hud',`
    <div class="farm-level" aria-label="레벨"><b>Lv.1</b><span class="farm-xp"><i></i></span><small></small></div>
    <div class="farm-coins farm-coin" aria-label="코인"><span aria-hidden="true">🪙</span><output>0</output></div>
    <div class="farm-coins farm-wood" aria-label="목재"><span aria-hidden="true">🪵</span><output>0</output></div>`);
  hud.id='farmHud';
  const popup=el('div','farm-popup');popup.hidden=true;popup.setAttribute('role','dialog');
  layer.append(popup);
  document.querySelector('main').append(layer,hud);
  // openIndex is a bed index, or a string key ('tree3') for a popup about something else.
  const notes=new Map(),tags=[],spots=[],picking={kind:'veg'};let openType='',openIndex=-1,repaint=null,state=null,api;
  const coins=hud.querySelector('output');let shownCoins=null;
  const woodOut=hud.querySelector('.farm-wood output');let woodShown=0,woodHeld=false;
  function showWood(value,bump=value>woodShown){
    if(bump){woodOut.parentElement.classList.remove('bump');void woodOut.offsetWidth;woodOut.parentElement.classList.add('bump')}
    woodShown=value;woodOut.textContent=value.toLocaleString('ko-KR');
  }

  function tagFor(index){
    if(tags[index])return tags[index];
    const tag=el('button','plot-tag');tag.type='button';tag.dataset.state='empty';
    tag.innerHTML='<span class="plot-icon"></span><span class="plot-meter"><i></i></span><span class="plot-text"></span>';
    tag.addEventListener('click',e=>{e.stopPropagation();api.onTag?.(index)});
    layer.insertBefore(tag,popup);tags[index]={tag,key:'',bar:tag.querySelector('.plot-meter i'),text:tag.querySelector('.plot-text'),icon:tag.querySelector('.plot-icon')};
    return tags[index];
  }
  function position(){
    if(openIndex===-1||!spots[openIndex])return;
    const {x,y}=spots[openIndex],w=popup.offsetWidth,h=popup.offsetHeight,pad=10;
    const left=Math.min(innerWidth-w-pad,Math.max(pad,x-w/2));
    let top=y-h-26;if(top<pad)top=Math.min(innerHeight-h-pad,y+30);
    popup.style.left=Math.round(left)+'px';popup.style.top=Math.round(top)+'px';
  }
  function open(index,html,type){
    openIndex=index;openType=type;repaint=null;popup.innerHTML=html;popup.hidden=false;popup.classList.remove('show');
    void popup.offsetWidth;popup.classList.add('show');position();
    popup.querySelector('.farm-close')?.addEventListener('click',close);
    tags.forEach((t,i)=>t?.tag.classList.toggle('selected',i===index));
  }
  function close(){
    if(openIndex===-1)return;openIndex=-1;openType='';repaint=null;popup.hidden=true;popup.innerHTML='';
    tags.forEach(t=>t?.tag.classList.remove('selected'));
  }
  addEventListener('keydown',e=>{if(e.key==='Escape')close()});
  const header=(title,index,label)=>`<header><strong>${title}</strong><span class="farm-plot-no">${label??(index<4?index+1+'번 밭':index-3+'번 꽃밭')}</span><button type="button" class="farm-close" aria-label="닫기">✕</button></header>`;

  api={
    onTag:null,close,isOpen:()=>openIndex!==-1,openKey:()=>openIndex,
    // opts.woodDelay: the wood counter waits for the flying firewood (collect) to arrive.
    refresh(next,opts={}){
      state=next;
      const level=levelOf(state.xp),from=levels[level-1],to=levels[level];
      hud.querySelector('.farm-level b').textContent='Lv.'+level;
      hud.querySelector('.farm-xp i').style.width=(to===undefined?100:(state.xp-from)/(to-from)*100)+'%';
      hud.querySelector('.farm-level small').textContent=to===undefined?'MAX':`${state.xp-from} / ${to-from} XP`;
      if(shownCoins!==null&&state.coins>shownCoins){coins.parentElement.classList.remove('bump');void coins.offsetWidth;coins.parentElement.classList.add('bump')}
      shownCoins=state.coins;coins.textContent=state.coins.toLocaleString('ko-KR');
      if(opts.woodDelay)woodHeld=true;
      if(!woodHeld)showWood(state.wood);
      if(openIndex!==-1)repaint?.();
    },
    openPicker(index,kind,current,refresh=false){
      picking.kind=kind;
      const level=levelOf(current.xp);
      const items=crops.filter(c=>c.bed===kind).map(c=>{
        const locked=level<c.level,poor=current.coins<c.cost;
        return `<button type="button" class="seed" data-crop="${c.id}" ${locked||poor?'disabled':''} ${locked?'data-locked':''}>
          <span class="seed-icon">${c.icon}</span>
          <span class="seed-name">${c.name}<small>${locked?'🔒 Lv.'+c.level+' 해금':'⏱ '+duration(c.seconds)}</small></span>
          <span class="seed-price"><span class="${poor&&!locked?'short':''}">🪙 ${c.cost}</span><small>수확 ${c.sell}</small></span>
        </button>`;
      }).join('');
      const scroll=refresh?popup.querySelector('.seed-list')?.scrollTop:0;
      open(index,header(kind==='flower'?'꽃 심기':'씨앗 심기',index)+`<div class="seed-list">${items}</div>`,'picker');
      if(scroll)popup.querySelector('.seed-list').scrollTop=scroll;
      popup.querySelectorAll('.seed').forEach(b=>b.addEventListener('click',()=>{if(plant(index,b.dataset.crop))close()}));
      if(!refresh)popup.querySelector('.seed:not([disabled])')?.focus({preventScroll:true});
      repaint=()=>api.openPicker(openIndex,picking.kind,wallet(),true);
    },
    // Fruit sapling picker for a tree (key 'tree<n>', at its screen point); onPick(id) -> planted?
    openTreePicker(key,at,fruits,onPick,refresh=false){
      spots[key]=at;
      const current=wallet(),level=levelOf(current.xp);
      const items=fruits.map(f=>{
        const locked=level<f.level,poor=current.coins<f.cost;
        return `<button type="button" class="seed" data-fruit="${f.id}" ${locked||poor?'disabled':''} ${locked?'data-locked':''}>
          <span class="seed-icon">${f.icon}</span>
          <span class="seed-name">${f.name}나무<small>${locked?'🔒 Lv.'+f.level+' 해금':'⏱ 열매 '+duration(f.seconds)}</small></span>
          <span class="seed-price"><span class="${poor&&!locked?'short':''}">🪙 ${f.cost}</span><small>열매 개당 ${f.sell}</small></span>
        </button>`;
      }).join('');
      const scroll=refresh?popup.querySelector('.seed-list')?.scrollTop:0;
      open(key,header('과일나무 심기',key,'묘목 고르기')+`<div class="seed-list">${items}</div>`,'tree-picker');
      if(scroll)popup.querySelector('.seed-list').scrollTop=scroll;
      popup.querySelectorAll('.seed').forEach(b=>b.addEventListener('click',()=>{if(onPick(b.dataset.fruit))close()}));
      if(!refresh)popup.querySelector('.seed:not([disabled])')?.focus({preventScroll:true});
      repaint=()=>api.openTreePicker(key,spots[key],fruits,onPick,true);
    },
    // A fruit tree whose fruit is still ripening: time left, the harvest, and an option to fell it.
    openTreeInfo(key,at,{fruit,left,growth,count},onFell){
      spots[key]=at;
      open(key,header(fruit.icon+' '+fruit.name+'나무',key,'과일나무')+`
        <div class="farm-info"><div class="farm-info-row"><span>열매가 익기까지</span><b class="farm-left">${clock(left)}</b></div>
        <span class="farm-bar"><i style="width:${growth*100}%"></i></span>
        <div class="farm-info-row"><span>예상 수확</span><b>${fruit.icon} ${count}개 · 🪙 ${count*fruit.sell} · ${fruit.xp} XP</b></div>
        <button type="button" class="farm-clear">나무 베기</button></div>`,'tree-info');
      const button=popup.querySelector('.farm-clear');
      button.addEventListener('click',()=>{
        if(button.dataset.confirm){close();onFell()}
        else{button.dataset.confirm='1';button.textContent='과일나무가 그루터기만 남아요. 정말 벨까요?'}
      });
    },
    // Keep a tree popup on its tree as the view moves; info refreshes the countdown, and a
    // ripening card closes once the fruit is ripe.
    track(key,x,y,info){
      if(openIndex!==key)return;
      spots[key]={x,y};position();
      if(info&&openType==='tree-info'){
        if(info.growth>=1){close();return}
        const left=popup.querySelector('.farm-left'),bar=popup.querySelector('.farm-bar i');
        if(left){left.textContent=clock(info.left);bar.style.width=(info.growth*100).toFixed(1)+'%'}
      }
    },
    openInfo(index,info){
      open(index,header(info.crop.icon+' '+info.crop.name,index)+`
        <div class="farm-info"><div class="farm-info-row"><span>수확까지</span><b class="farm-left">${clock(info.left)}</b></div>
        <span class="farm-bar"><i style="width:${info.growth*100}%"></i></span>
        <div class="farm-info-row"><span>예상 수확</span><b>🪙 ${info.crop.sell} · ${info.crop.xp} XP</b></div>
        <button type="button" class="farm-clear">갈아엎기</button></div>`,'info');
      const button=popup.querySelector('.farm-clear');
      button.addEventListener('click',()=>{
        if(button.dataset.confirm){clear(index);close()}
        else{button.dataset.confirm='1';button.textContent='씨앗값은 돌려받지 못해요. 정말 갈아엎을까요?'}
      });
    },
    // Free-standing status tags (trees being felled): note(key,{x,y,on,icon,text}) or note(key,null).
    note(key,info){
      let tag=notes.get(key);
      if(!info){if(tag){tag.remove();notes.delete(key)}return}
      if(!tag){
        tag=el('button','plot-tag farm-note-tag','<span class="plot-icon"></span><span class="plot-text"></span>');tag.type='button';
        tag.addEventListener('click',e=>{e.stopPropagation();tag.onClickNote?.()});
        layer.insertBefore(tag,popup);notes.set(key,tag);
      }
      tag.dataset.state=info.ready?'ready':'pending';tag.onClickNote=info.onClick;tag.classList.toggle('clickable',!!info.onClick);
      tag.hidden=!info.on;tag.style.left=Math.round(info.x)+'px';tag.style.top=Math.round(info.y)+'px';
      if(tag.dataset.text!==info.icon+info.text){tag.dataset.text=info.icon+info.text;tag.children[0].textContent=info.icon;tag.children[1].textContent=info.text}
    },
    compact(on){if(layer.classList.contains('compact')!==on)layer.classList.toggle('compact',on)},
    openPending(index,pending){
      const what=pending.type==='plant'?pending.crop.name+' 심기':pending.crop.name+' 수확';
      open(index,header(pending.crop.icon+' '+what,index)+`
        <div class="farm-info"><div class="farm-info-row"><span>${pending.phase==='walk'?'유니티짱이 밭으로 가는 중이에요':'작업하는 중이에요'}</span></div>
        <button type="button" class="farm-clear">작업 취소</button></div>`,'pending');
      popup.querySelector('.farm-clear').addEventListener('click',()=>{cancel(index);close()});
    },
    // A piece of loot flies from (x,y) along an arc into its HUD counter, which ticks up on arrival.
    collect(x,y,kind,amount,last,icon=kind==='wood'?'🪵':'🪙'){
      const target=hud.querySelector('.farm-'+(kind==='coins'?'coin':kind))?.getBoundingClientRect();if(!target)return;
      const piece=el('div','farm-fly',icon);layer.append(piece);
      const tx=target.left+22,ty=target.top+target.height/2,lift=Math.min(160,Math.max(60,(y-ty)*.35));
      const frames=[];
      for(let i=0;i<=12;i++){
        const u=i/12,e=u*u*(3-2*u),px=x+(tx-x)*e,py=y+(ty-y)*u*u-lift*4*u*(1-u)*(1-u*.4);
        frames.push({transform:`translate(${px}px,${py}px) translate(-50%,-50%) scale(${1.25-.55*u}) rotate(${u*540}deg)`,opacity:u>.92?.6:1});
      }
      const flight=piece.animate(frames,{duration:720+Math.random()*160,delay:Math.random()*90,easing:'ease-in',fill:'forwards'});
      flight.onfinish=()=>{
        piece.remove();
        if(kind==='wood'){
          woodShown=Math.min(state.wood,woodShown+amount);
          if(last){woodHeld=false;woodShown=state.wood}
          showWood(woodShown,true);
        }else{const pill=hud.querySelector('.farm-coin');pill.classList.remove('bump');void pill.offsetWidth;pill.classList.add('bump')}
      };
    },
    toast(text){
      const toast=el('div','farm-toast farm-note',`<span>${text}</span>`);toast.setAttribute('role','status');
      layer.append(toast);toast.addEventListener('animationend',()=>toast.remove());
    },
    hover(index){tags.forEach((t,i)=>t?.tag.classList.toggle('hovered',i===index))},
    // Tags are positioned with left/top; transform is left free for the hover/pop scale so it
    // grows in place instead of sliding away from the cursor.
    place(index,x,y,visible,info,pending){
      const t=tagFor(index);spots[index]={x,y};
      t.tag.hidden=!visible;
      if(visible){t.tag.style.left=Math.round(x)+'px';t.tag.style.top=Math.round(y)+'px'}
      const ready=info&&info.growth>=1;
      const key=pending?'pending:'+pending.type+':'+pending.phase+':'+pending.crop.id:!info?'empty':ready?'ready:'+info.crop.id:'grow:'+info.crop.id+':'+Math.ceil(info.left);
      if(key!==t.key){
        const changed=t.key.split(':').slice(0,2).join()!==key.split(':').slice(0,2).join();t.key=key;
        const name=index<4?(index+1)+'번 밭':(index-3)+'번 꽃밭';
        t.tag.dataset.state=pending?'pending':!info?'empty':ready?'ready':'growing';
        t.icon.textContent=pending?pending.crop.icon:info?info.crop.icon:'＋';
        t.text.textContent=pending?(pending.phase==='walk'?'이동 중':pending.type==='plant'?'심는 중':'수확 중'):!info?'':ready?'수확':clock(info.left);
        t.tag.setAttribute('aria-label',name+': '+(pending?t.text.textContent:!info?'비어 있음, 심기':ready?info.crop.name+' 수확하기':info.crop.name+' 자라는 중, '+duration(info.left)+' 남음'));
        // A popup about this bed closes once the bed has moved on to another state.
        const kind=t.tag.dataset.state;
        if(changed&&openIndex===index&&!({picker:'empty',info:'growing',pending:'pending'})[openType]?.includes(kind))close();
        else if(openIndex===index&&openType==='pending'&&pending)api.openPending(index,pending);
      }
      if(info&&!ready){t.bar.style.width=(info.growth*100).toFixed(1)+'%';t.tag.style.setProperty('--p',info.growth.toFixed(3))}
      if(openIndex===index){
        position();
        const left=popup.querySelector('.farm-left'),bar=popup.querySelector('.farm-bar i');
        if(left&&info){left.textContent=clock(info.left);bar.style.width=(info.growth*100).toFixed(1)+'%'}
      }
    },
    reward(index,icon,coins,xp){const spot=spots[index];if(spot)api.rewardAt(spot.x,spot.y,icon,coins,xp)},
    rewardAt(x,y,label,coins,xp,plain=false){
      const float=el('div','farm-float',`<span>${plain?label:label+' +'+coins+' 🪙'}</span><small>+${xp} XP</small>`);
      float.style.left=x+'px';float.style.top=y+'px';
      layer.append(float);float.addEventListener('animationend',()=>float.remove());
    },
    levelUp(level,unlocked){
      const toast=el('div','farm-toast',`<strong>레벨 업! Lv.${level}</strong>${unlocked.length?'<span>'+unlocked.map(c=>c.icon+' '+c.name).join(', ')+' 해금</span>':''}`);
      toast.setAttribute('role','status');
      layer.append(toast);toast.addEventListener('animationend',()=>toast.remove());
    }
  };
  return api;
}
