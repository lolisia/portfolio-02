const coverage=[0,1,2,1,1,2],density=[1,1,1,3.8,1.4,2.4];
export function createWeatherTransition(){
  const weights=[1,0,0,0,0,0];let target=0;
  const state={coverage:0,density:1,rain:0,snow:0,storm:0,active:false};
  return Object.assign(state,{
    select(index){target=index;state.active=true},
    update(dt){
      const k=1-Math.exp(-Math.max(0,dt)*.85);let difference=0;
      for(let i=0;i<weights.length;i++){
        const wanted=i===target?1:0;
        weights[i]+=(wanted-weights[i])*k;difference=Math.max(difference,Math.abs(wanted-weights[i]));
      }
      if(difference<.0005){weights.fill(0);weights[target]=1;state.active=false}
      state.coverage=weights.reduce((sum,w,i)=>sum+w*coverage[i],0);
      state.density=weights.reduce((sum,w,i)=>sum+w*density[i],0);
      state.rain=weights[2];state.snow=weights[4]+weights[5];state.storm=weights[5];
      return state;
    }
  });
}
