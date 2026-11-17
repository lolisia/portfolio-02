// Keep the desktop image unchanged. A coarse pointer and a small viewport select
// the phone profile; the query override makes same-device A/B checks repeatable.
const override=new URLSearchParams(location.search).get('quality');
const smallViewport=Math.min(innerWidth,innerHeight)<=900;
const mobile=override==='mobile'||(override!=='desktop'&&smallViewport&&matchMedia('(pointer: coarse)').matches);

export const quality=Object.freeze({
  mobile,
  targetFPS:60,
  reflectionScale:mobile?.5:1,
  reflectionInterval:mobile?1/30:0,
  fogScale:mobile?.33:.5,
  fogHighSteps:mobile?4:6,
  fogLowSteps:mobile?12:18,
  aoSamples:8,
  trampleSlots:mobile?4:16,
  snowCount:mobile?2500:9000,
  snowSizeScale:mobile?1.25:1,
  cascadeDrops:mobile?300:900,
  cascadeMist:mobile?12:24,
  rainCount:mobile?1200:1600,
  rainSplashes:mobile?100:300,
  sunShadowSize:2048
});
