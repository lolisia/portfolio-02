# Godot 이식 로드맵 / 핸드오프

- 기준일: 2026-11-12
- 엔진: Godot 4.7.2 stable (mono)
- 경로: `D:\Godot\Godot_v4.7.2-stable_mono_win64`
- 프로젝트: `D:\DEV\portfolio-02\godot\project.godot`
- 문서 작성 기준 커밋: `3f00ce8` 이후 이번 세션 변경 포함
- 타깃: PC 네이티브(Forward+) / 모바일 네이티브(Mobile). 웹 배포는 고려하지 않음.

---

## 1. 실행 / 검증

### 실행

```powershell
& 'D:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' `
  --path 'D:\DEV\portfolio-02\godot'
```

또는 Godot 에디터에서 `godot/project.godot` 열기.

### 렌더러 전환

```powershell
# Mobile 렌더러로 실행 (실기기 검증 전 단계)
... --rendering-method mobile
```

### 개발용 카메라/상태 프리셋

Godot의 사용자 인자는 `--` 뒤에 전달합니다.

```powershell
... -- --house          # 농가 근처
... -- --pond           # 연못
... -- --pondside       # 연못을 낮은 각도에서 (수면 반사 확인)
... -- --door           # 정문 근처
... -- --fishtest       # 연못가 낚시 확인
... -- --char           # 캐릭터 근처
... -- --char2          # 캐릭터 측면
... -- --charclose      # 캐릭터/발자국 근접
... -- --panel          # 환경 설정 패널 펼침

... -- --gather         # 채소밭 수확 태스크
... -- --fish           # 연못 낚시 태스크
... -- --salute         # 경례 + 문 열기
... -- --fishnear       # 연못 근처에서 낚시 시작
... -- --gathernear     # 채소밭 근처에서 수확 시작
... -- --snowtest       # 눈 위 이동/발자국/풀 눌림 확인
... -- --spring         # 봄(벚꽃잎) 프리셋
... -- --autumn         # 가을(낙엽/tint) 프리셋
... -- --night          # 밤 22:00, 별/나방/램프/창문 확인
... -- --dusk           # 해질녘 18:36
... -- --dawn           # 새벽 6:24
... -- --front          # 농가 정면 낮은 각도
... -- --garden         # 농가 뒤 꽃정원
... -- --high           # 품질 높음
... -- --medium         # 품질 보통 (모바일 기본)
... -- --low            # 품질 낮음
... -- --shot C:/path.png   # 현재 창 해상도로 스크린샷 저장 (개발용)

... -- --winter         # 겨울 상태 즉시 적용
... -- --snow           # 눈 날씨
... -- --rain           # 비 + 젖은 지면
```

### 빠른 헤드리스 검증

```powershell
& 'D:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' `
  --headless --path 'D:\DEV\portfolio-02\godot' --quit-after 3
```

```powershell
# 코어 시스템/에셋/경로/눈 표면 스모크 테스트 (실패 시 exit 1)
& '...\Godot...console.exe' `
  --headless --path 'D:\DEV\portfolio-02\godot' --script 'res://tools/smoke_test.gd'
```

- 스크립트 파싱/씬 로딩 확인
- 셰이더 컴파일 오류는 헤드리스에서 잡히지 않으므로, 실제 렌더 프리셋으로 확인 필요
- 영상 확인: `--write-movie <경로>.png --fixed-fps 30 --quit-after N`  
  (출력 폴더를 먼저 만들어야 함)

---

## 2. 현재 구현 상태

### 완료

- 30×30 타일 높이 지형, 테라스, 연못, 경계 암반, 폭포 출구
- 농가/헛간/닭장, 정원 침대, 앞마당 채소밭 2개, 돌길
- 꽃정원: 절차적 튤립·라벤더·해바라기·폭스글러브·장미 메시
- `nature.glb` 기반 나무·풀·꽃·작물 `MultiMesh` 인스턴싱
- 표면 셰이더
  - 나무결, 석재, 기와, 흙, 철
  - 젖은 표면, 웅덩이, 눈 덮임
  - 지형 경로 마스크(돌길 주변 흙)
- 계절/날씨 상태
  - 여름/가을/겨울 하늘·안개 색
  - 비/눈 GPU 파티클, 강도 크로스페이드(`amount_ratio`)
  - 봄 벚꽃잎 / 가을 낙엽 GPU 파티클
  - 겨울 낙엽/풀 제거, 눈 덮임, 연못 결빙/균열 셰이더
  - 계절별 foliage tint (봄/여름/가을/겨울)
  - 비 수면 파문 링, 폭포 spray 파티클
- Unity-chan
  - GLB 임포트(90본, 10개 애니메이션)
  - Standing/Walking 크로스페이드, A* 경유지 걷기
  - Gathering / Fishing / Salute / Kneel 태스크
  - 낚싯대·낚싯줄·찌
  - 경례 시 정문 열림/닫힘, 실내 4.5초 방문 후 복귀
  - 눈 깜빡임
- 농장 생활
  - 닭 2 + 병아리 4, 배회/쪼기/낮·날씨 은신
  - Unity-chan 접근 시 닭이 도망 (2.4배 속도, 0.8초)
  - 지붕 풍향계·풍속계, 청동 수탉 실루엣
  - 굴뚝 연기 GPU 파티클
  - 물고기 10마리, 가끔 수면 위로 점프
  - 나무/램프/지붕을 옮겨 앉는 새
- 야간 연출
  - 별 dome(절차적 텍스처, 궤도 회전), 밤 안개/별 밝기
  - 램프별 플리커/험, additive 후광, 유리 emissive
  - 램프 주변 나방, 여름밤 반딧불
  - 농가 창문/램프/TV 컬러 플리커, 사람이 지나갈 때 창문 광량 감소
- 물
  - 연못 수면 셰이더, 물고기, 다리, 폭포
  - Forward+ SubViewport 평면 반사
  - 모바일은 화면공간 반사 폴백
- 대기
  - Forward+ `FogVolume` 볼류메트릭 미스트
  - Environment depth fog / glow / SSAO / ACES
- UI
  - 시각/바람 슬라이더, 자동 시간, 날씨/계절, 품질, 리셋, 패널 접기
  - 패널 뒤 유리 렌즈 + 9탭 프로스트 블러 + 색조/비네트 후처리
  - Unity-chan 크레딧 링크
  - 반응형 레이아웃 (360px 폭까지), 세로 모드에서 날씨/계절 스택
  - 실제 창 크기 기반 content scale + 패널 열림 시 카메라 v_offset/줌 보정
  - 터치용 슬라이더/버튼 높이, `--shot <path>` 스크린샷 헬퍼
  - 품질 프리셋 높음/보통/낮음 (MSAA, 3D 스케일, SSAO/볼류메트릭, 반사, 잔디/파티클)
  - 모션 프리뷰: 지평선(시각), 풍속계(바람), 날씨 카드 (`motion.js` 포트)
- 물 반사 (이번 세션)
  - SubViewport 반사 텍스처의 상하 뒤집힘 수정 (`mirror_uv.y = 1.0 - y`)
  - Schlick 5제곱 Fresnel로 상공 시 투명, 저각 시 반사 강화
  - `--pondside`로 저각 반사 확인, Mobile은 화면공간 폴백 유지
- 눈/발자국 (이번 세션)
  - 지형 셰이더 정점 융기 + `FarmWorld.snow_surface()` 분석식 일치
  - 부츠/닭 발자국 MultiMesh 2레이어, 눈이 쌓이면 수명 감소
  - 발자국은 물가/눈 깊이 조건을 만족할 때만 생성
- 풀 눌림 (이번 세션)
  - 16슬롯 trample을 turf/grass 셰이더에만 적용, 캐릭터/닭 이동 트레일

### 주요 파일

| 파일 | 역할 |
|---|---|
| `scripts/main.gd` | 부트스트랩, 환경/조명, UI 연결, 후처리, 물 반사, 날씨/눈 상태 |
| `scripts/world.gd` | 지형/물/폭포/농가/정원/길/나무/풀/램프/충돌/문 |
| `scripts/builder.gd` | `MultiMesh` 배칭, 인스턴스 색/바람 데이터, 재질 선택 |
| `scripts/daylight.gd` | 시간대 팔레트, 태양 방향 |
| `scripts/day_cycle.gd` | 태양/하늘/안개/글로우/계절 색 |
| `scripts/orbit_camera.gd` | 직교 카메라 오빗/터치 줌 |
| `scripts/unity_chan.gd` | 캐릭터 임포트, 태스크 AI, 낚시 장비 |
| `scripts/farm_paths.gd` | 0.6 타일 워킹 그래프, A* 경로 |
| `scripts/motion_preview.gd` | 지평선/풍속계/날씨 UI 카드 |
| `scripts/garden_assets.gd` | 절차적 꽃 메시(튤립/라벤더/해바라기/폭스글러브/장미) |
| `scripts/farm_life.gd` | 닭, 풍향계/수탉, 연기, 물고기 점프, 새 |
| `scripts/weather_fx.gd` | 비/눈 강도 크로스페이드, 물보라/수면 파문, 폭포 spray |
| `scripts/seasons_fx.gd` | 봄 벚꽃잎, 가을 낙엽 |
| `scripts/night_life.gd` | 별, 나방/반딧불, 램프 플리커/후광, 실내 창문/TV |
| `scripts/quality_manager.gd` | 높음/보통/낮음 렌더 예산 |
| `scripts/post_process.gd` | 패널 렌즈/그레이드 |
| `scripts/water_reflection.gd` | Forward+ 평면 반사 SubViewport |
| `scripts/footprints.gd` | 부츠/닭 발자국 MultiMesh, 수명/눈 표면 추적 |
| `scripts/nature_assets.gd` | `nature.glb` 메시 추출 |
| `shaders/surface.gdshader` | 건축/소품 표면 |
| `shaders/terrain.gdshader` | 지형/경로/눈/습기, 겨울 정점 융기 |
| `shaders/foliage.gdshader` | 바람/눈/겨울 낙엽, 풀 눌림 |
| `shaders/footprint.gdshader` | 발자국 알파/수명 |
| `shaders/stars.gdshader` | 별 dome additive |
| `shaders/water.gdshader` | 물결/반사/색, 겨울 결빙 |
| `shaders/waterfall.gdshader` | 폭포 |
| `shaders/post_process.gdshader` | 화면 후처리 |

### 원본 참고

- 웹 원본 소스: `../src/`
- 원본 에셋: `../public/`
- `public/models/unitychan/sd_unitychan.glb`는 WebP 텍스처를 요구하므로 Godot용은 `godot/assets/models/unitychan/sd_unitychan.glb` (PNG 변환본) 사용
- 변환 스크립트: `convert_unitychan_glb.py`

---

## 3. 남은 작업 우선순위

### P0. 물 반사/미스트 검증 및 튜닝 — 반사 샘플링/프레넬 완료

**현재 상태**
- Forward+에서 SubViewport 미러 카메라가 동작.
- `mirror_uv.y` 뒤집힘을 수정해 수면이 하늘이 아니라 지형/건물을 비추던 문제를 해결.
- Fresnel을 원본과 같은 Schlick 5제곱으로 바꿔 상공 시 투명, 저각 시 반사가 강해짐.
- `--pondside` 저각 뷰에서 수면에 하늘/수변 반사가 확인됨. `--pond` 상공 뷰에서는 바닥이 비침.
- `Camera3D`에 4.7에서 `clip_plane`이 없어, 물 아래 지오메트리를 셰이더 `discard`로 제거하는 우회 사용.
- 반사 카메라가 물속 지형/암반을 보지 않도록 `surface/terrain/foliage` 셰이더에 하드코딩된 `0.44` 수면 컷이 있음.

**남은 선택 작업**
1. 여러 카메라 각도/줌에서 반사 방향 최종 확인.
2. 격프레임 갱신/반사 해상도 조절(`viewport.size`)로 비용 절감 검토.
3. 물보라/물결 노멀 디테일 추가.

**완료 기준**
- 연못에 나무/농가/하늘이 자연스럽게 비침. (저각에서 확인)
- 물속 바닥/암반이 반사면에 나타나지 않음.
- Forward+에서 프레임 저하가 과하지 않음.
- Mobile에서 오류/검은 수면이 없음. (확인)

**리스크**
- 미러 카메라의 음수 행렬식으로 인한 컬링/클리핑 이슈.
- `Camera3D.clip_plane` 부재로 인한 우회의 한계.

---

### P1. 빛줄기·커스텀 HDR 안개

**현재 상태**
- Godot `FogVolume` + Environmental volumetric fog 사용.
- `main.gd`가 golden/night/overcast/season에 따라 FogVolume density와 volumetric fog density를 보간.
- 원본의 커스텀 레이마칭 안개(구름 노이즈, 램프 산란, 새벽 저지대 안개)와는 다름.
- 태양 그림자 기반 빛줄기는 내장 볼류메트릭에 의존.
- 밤 별 dome은 `night_life.gd`로 구현.

**할 일**
1. Forward+ `CompositorEffect`로 half-res fog/light-shaft pass 구현 검토.
   - depth texture + sun shadow map 접근 제약 확인.
   - 불가능하면 screen-space light shafts + FogVolume 조합.
2. 새벽/밤/비/눈에 따른 안개 밀도·색·산란 튜닝.
3. 램프 5개의 볼류메트릭 산란(Spot/Omni light) 확인.
4. ~~밤하늘 별~~ — `night_life.gd` 별 dome + `stars.gdshader`로 구현.
5. 모바일은 depth fog로 폴백.

**파일**
- `scripts/main.gd`
- `scripts/day_cycle.gd`
- `shaders/` (새 fog/composite 셰이더)
- `project.godot` (Forward+ 렌더러 설정)

**완료 기준**
- 아침 숲 사이로 빛줄기가 보임.
- 밤 램프 주변에 따뜻한 안개 번짐.
- 비/눈 날씨에 안개가 자연스럽게 짙어짐.
- Mobile에서 성능/화면 깨짐 없음.

---

### P2. 겨울 지면 변위 + 발자국 — 완료 (셰이더 변위)

**현재 상태**
- 눈은 셰이더 색/표면 덮임 + 지형 정점 융기로 표현.
- `terrain.gdshader`가 `snow_depth`와 수면 위 은행 높이로 지형을 들어 올림.
- `FarmWorld.snow_surface()`가 같은 해석식을 제공해 발자국이 눈 표면에 정확히 놓임.
- `scripts/footprints.gd`: 부츠 360 + 닭 420 인스턴스, 64px 절차적 텍스처, 수명 감소.
- `--winter --snowtest`에서 캐릭터/닭 발자국이 남는 것 확인.
- `main.gd` trample 16슬롯 + `foliage.gdshader`로 캐릭터/닭 주변 풀이 눌리고 회복.

**메모**
- 원본 `seasons.js`는 CPU에서 `ArrayMesh` 정점을 갱신하지만, Godot에서는 14k 정점/노멀 재계산 비용을 피하려고 동일한 해석식을 정점 셰이더에 넣었음. 발자국/충돌 높이는 `snow_surface()`로 일치.
- 발자국은 원본과 동일하게 눈 깊이 0.3 이상, 물가 제외 조건에서만 생성.
- 눈이 내리는 동안 수명이 빨리 줄어들고, 눈이 그치면 약 2분 유지.

**남은 선택 작업**
1. `world.stand()`에 처마/계단 높이를 반영해 발자국이 데크 위에 남지 않게 보강.
2. 발자국 해상도/수명 모바일 프리셋.
3. 눈보라 시 발자국이 더 빨리 메워지는지 튜닝.

---

### P3. 계절 파티클/날씨 전환 완성 — 대부분 완료

**현재 상태**
- 봄 벚꽃잎/가을 낙엽 GPU 파티클 구현 (`seasons_fx.gd`).
- 비/눈 파티클 강도를 `amount_ratio`로 보간하고, `wet`/`snow_depth`와 함께 1초 내외로 전환.
- 겨울 연못 결빙 셰이더(균열/서리) + 물고기 숨김 + 폭포 spray.
- 계절 foliage tint (봄 연둣빛, 가을 주황, 겨울 청회색).
- 비/눈이 그치면 입자 수가 서서히 줄어드는 것 확인.

**남은 일**
1. 지면에 쌓였다가 사라지는 낙엽/벚꽃잎 표현.
2. 눈보라 강도에 따른 파티클 속도/바람 연동 강화.
3. 폭포 foam/vapor 디테일.

**파일**
- `scripts/weather_fx.gd`
- `scripts/seasons_fx.gd`
- `scripts/day_cycle.gd`
- `scripts/main.gd`
- `shaders/water.gdshader`

**완료 기준**
- 봄/가을에 계절 파티클이 보임. (확인)
- 날씨 변경 시 1~2초에 걸쳐 자연스럽게 전환. (파티클/젖음/눈 확인)
- 비 올 때 수면/지면 파문이 보임. (수면 파문 확인, 지면 물보라는 남음)

---

### P4. 농장/야생 디테일 — 대부분 완료

**현재 상태**
- 닭: 배회/쪼기, Unity-chan 접근 시 2.4배 속도로 도망. 밤/악천후에는 닭장 입구로 걸어 들어가 숨고, 아침에 다시 나옴.
- 새: 나무/램프/지붕 이동, 이륙 crouch → 활공 → 착륙 flare → 날개 접기.
- 물고기: 수면 위로 점프(포물선 + 회전) + 입수/이수 물보라, 결빙 시 숨김.
- 램프: 랜턴별 플리커/험, 글래스 emissive, additive 후광.
- 풍향계: 청동 수탉 실루엣/허브 디테일 추가.
- 실내: 창문/TV 컬러 플리커, 사람이 지나갈 때 창문 광량 감소.
- 반딧불/나방: 밤/계절/날씨 조건부.
- 꽃정원: 절차적 꽃 메시로 튤립·라벤더·해바라기·폭스글러브·장미 구현.
- 농가 주변 계단/울타리/먼 꽃정원 디테일은 아직 부분.

**남은 일**
1. 실내 사람 실루엣(유리 셰이더)과 TV 색 번짐 강화.
2. 농가 주변 계단/울타리/먼 꽃정원 디테일.

**파일**
- `scripts/farm_life.gd`
- `scripts/world.gd`
- `scripts/unity_chan.gd`
- `scripts/night_life.gd`
- `scripts/garden_assets.gd`
- `shaders/water.gdshader`

**완료 기준**
- 닭이 캐릭터를 피해 도망. (확인)
- 밤에 닭이 닭장으로 들어감. (걸어 들어가 숨김)
- 램프가 랜턴별로 미세하게 깜빡임. (확인)
- 실내 창문 빛이 시간/TV에 따라 변함. (확인)

---

### P5. Unity-chan 경로 탐색/실내 — A*/문 통과 완료

**현재 상태**
- `scripts/farm_paths.gd`: 0.6 타일 격자 그래프, `closest`, A* `route` 포팅.
- 태스크/산책 경로를 A*로 생성; 낚시/수확/경례 목적지까지 장애물을 피해 이동.
- 경례 후 문을 열고 실내 위치로 이동해 4.5초 숨은 뒤, 문 앞으로 돌아와 다시 보임.
- 실내 공간/가구는 없고 캐릭터 숨김으로 처리.
- `--fishnear --fishtest`에서 연못까지 이동 후 낚시 상태 진입 확인.

**남은 일**
1. 실내 방/창문/램프/가구 메시와 실내 카메라 연출.
2. 경로 캐시/그래프 디버그 시각화.
3. `stand()` 높이(데크/계단)와 경로 그래프 연동 정밀화.
4. 태스크 반복 시 장기 안정성 테스트.

**파일**
- `scripts/farm_paths.gd`
- `scripts/unity_chan.gd`
- `scripts/world.gd`

**완료 기준**
- 캐릭터가 건물/침대를 관통하지 않고 목적지까지 이동. (A* 경로)
- 문을 열고 들어갔다가 다시 나옴. (숨김 연출)
- 태스크가 막힘 없이 반복됨. (단기 확인)

---

### P6. UI/모바일 — 반응형/품질 프리셋/모션 프리뷰 완료

**현재 상태**
- `content_scale_size`를 실제 창 크기로 맞추고, 세로 화면에서는 패널을 화면 폭에 맞춤.
- 360×640에서 패널/슬라이더/옵션/리셋 버튼이 넘치지 않고 읽힘 (`--shot`으로 확인).
- 세로 모드에서 날씨/계절 행을 세로로 쌓고, 데스크톱에서는 기존 2열 유지.
- 터치 타깃 높이(슬라이더 34px, 옵션/버튼 34~36px) 적용.
- 패널이 열리면 세로 화면에서 `v_offset` + `portrait_scale`로 디오라마를 축소/상향해 가림을 줄임.
- 품질 프리셋 높음/보통/낮음:
  - MSAA, 3D 해상도 스케일, SSAO/볼류메트릭, 물 반사 해상도/비활성, 잔디 수, 파티클 비율.
  - 모바일 렌더러 기본값은 보통.
- 모션 프리뷰: `motion_preview.gd`로 지평선/풍속계/날씨 카드 포팅.
- 모바일 실기기 테스트 없음.

**남은 일**
1. 모바일 실기기 프로파일링:
   - 중급 Android 우선.
   - 발열/배터리/프레임 측정.
2. 적응형 해상도/그림자 갱신.
3. safe area(노치) 대응.
4. 프리뷰 모션 감소(prefers-reduced-motion) 옵션.

**파일**
- `scripts/game_ui.gd`
- `scripts/motion_preview.gd`
- `scripts/quality_manager.gd`
- `scripts/main.gd`
- `project.godot`

**완료 기준**
- 360px 폭에서도 패널이 넘치지 않음.
- 터치로 모든 컨트롤 조작 가능.
- 중급 Android에서 목표 FPS 달성.
- Low 프리셋에서도 씬이 깨지지 않음.

---

### P7. 빌드/배포/테스트 — 스모크 테스트 완료

**현재 상태**
- `tools/smoke_test.gd`: 월드/지형/물/자연 메시/꽃 에셋/눈 표면/A* 경로/발자국/야간/계절/품질 매니저 존재를 검사. 실패 시 exit 1.
- `--shot <path>`로 해상도별 UI/씬 캡처.
- 실제 export 템플릿과 Android SDK가 이 환경에 없어 패키징은 미검증.

**남은 일**
1. Windows/Linux/macOS/Android/iOS export preset 정리.
2. 아이콘/스플래시/앱 이름/버전.
3. Android 서명, iOS는 Mac/Xcode 필요.
4. 태스크 상태 전환/셰이더 파라미터 스모크 확장.
5. 성능 기준 문서화.
6. README/ROADMAP 최신화.

---

## 4. 알려진 이슈 / 주의점

- **물 반사**
  - `Camera3D.clip_plane`이 Godot 4.7에 없어 물 아래 지오메트리를 셰이더 `discard`로 제거.
  - `surface/terrain/foliage` 셰이더에 `0.44` 수면 컷이 하드코딩되어 있음 → 수면 높이 변경 시 함께 수정.
  - SubViewport 반사 UV는 상하 뒤집힘 보정(`mirror_uv.y = 1 - y`)이 필요. 수정 완료.
  - SubViewport가 매 프레임 렌더링됨 → 필요 시 격프레임/해상도 조정.
- **안개**
  - `FogVolume`과 Environment volumetric fog는 Forward+ 전용.
  - Mobile은 depth fog 폴백.
  - 커스텀 레이마칭/광선 샤프트는 아직 없음.
- **눈**
  - 지형 융기는 CPU 메시가 아니라 `terrain.gdshader` 정점 변위. `snow_surface()` 분석식과 반드시 함께 수정.
  - 겨울에 식물 95% discard; 일부만 남음.
  - 발자국은 투명 쿼드 데칼이며 그림자를 받지 않음(원본과 유사).
- **물/겨울**
  - 연못 결빙은 `water.gdshader`의 `freeze` uniform; `main.gd`의 `water_freeze`와 함께 조정.
  - 비 파문은 연못 수면에만 생성(지면 물보라는 아직 없음).
- **야간**
  - 별은 화면공간 합성이 아니라 145 반경 dome이므로 fog/depth에 영향받음.
  - 실내 사람 실루엣은 창문 광량 변조로 근사; 유리 셰이더 실루엣은 아직 없음.
  - 램프 유리 emissive는 5개 램프가 하나의 material을 공유해 평균 플리커만 반영.
- **태스크 AI**
  - A* 그래프는 0.6 타일이며, 최종 목적지는 그래프 밖 한 걸음이라 충돌 슬라이드에 의존.
  - 작은 덤불/램프는 통과 가능하게 처리.
  - 문 앞 경례 후 실내로 숨었다 4.5초 뒤 복귀; 실제 실내 방은 없음.
- **UI**
  - 360px 폭/세로 모드 대응 완료. 모션 프리뷰 캔버스와 safe area는 남음.
  - 품질 프리셋은 렌더러/창 크기와 무관하게 수동 선택; 자동 선택은 아직 없음.
  - `--shot <path>`는 개발용 스크린샷 헬퍼.
- **모바일**
  - PC에서 Mobile 렌더러로만 검증; 실제 Android/iOS 기기 테스트 필요.
  - iOS는 Mac/Xcode 필요.
- **에셋**
  - Unity-chan은 PNG 변환본 사용.
  - 원본 `public/`은 참고용; Godot 프로젝트에 복사된 에셋을 수정해야 함.
- **개발 프리셋**
  - `--house`, `--pond`, `--door`, `--fishtest`, `--fishnear`, `--gathernear` 등은 개발용.
  - 최종 빌드에서 제거하거나 유지 여부 결정.

---

## 5. 다음 세션 이어서 할 일 (추천 순서)

1. **빛줄기/안개 튜닝** (P1)
   - `--house` 아침/저녁, `--winter`, `--rain`에서 FogVolume/조명 확인
   - 커스텀 CompositorEffect는 리스크가 크므로 먼저 내장 볼류메트릭으로 목표치 확인
2. **모바일 품질/프로파일링** (P6)
   - High/Medium/Low 실기기 검증, 해상도 스케일/그림자/파티클 예산
   - safe area, 적응형 해상도
3. **농장/야생 남은 디테일** (P4)
   - 실내 실루엣, 농가 주변 디테일
4. **계절/날씨 남은 디테일** (P3)
   - 낙엽/벚꽃잎 지면 적재, 눈보라 바람 연동, 폭포 foam
5. **실내 공간** (P5 후속)
   - 방/가구/램프 메시와 유리 실루엣
6. **빌드/배포/스모크 테스트** (P7)

### 세션 시작 체크리스트

- [ ] `git status` 확인 (preview/reference 제외)
- [ ] `git log --oneline -3` 확인
- [ ] 헤드리스 실행으로 파싱 오류 확인
- [ ] `--pondside` / `--winter --pondside` / `--autumn` / `--night` 렌더로 회귀 확인
- [ ] 작업 후 `git add godot` + 커밋

---

## 6. 원본 ↔ Godot 매핑 요약

| 원본 | Godot | 상태 |
|---|---|---|
| `src/world.js` | `scripts/world.gd` | 대부분 이식, 계단/울타리/꽃정원 일부 누락 |
| `src/modules.js` | `scripts/builder.gd` + `world.gd` | 간략화 |
| `src/surfaces.js` | `shaders/surface.gdshader`, `terrain.gdshader` | 부분 이식 |
| `src/mist.js` | `FogVolume` + `post_process` | 근사 |
| `src/sky.js` | `day_cycle.gd` + ProceduralSky | 근사 |
| `src/water.js` | `water.gdshader` + `water_reflection.gd` | 근사 |
| `src/cascade.js` | `world.gd::_build_cascade`, `waterfall.gdshader` | 간략화 |
| `src/seasons.js` | `day_cycle.gd`, `weather_fx.gd`, shaders, `terrain.gdshader` | 겨울 지면 융기 포함 |
| `src/weather.js` | `main.gd` rain/snow intensity crossfade | 부분 |
| `src/rain.js` | `weather_fx.gd` (lines, pond ripples, spray) | 간략화 |
| `src/footprints.js` | `scripts/footprints.gd` | 완료 |
| `src/farm-life.js` | `farm_life.gd` (flee, vane, lamps) | 부분 |
| `src/wildlife.js` | `farm_life.gd` (fish leap, bird) | 부분 |
| `src/unitychan.js` | `unity_chan.gd`, `farm_paths.gd` | A* 경로/문 통과 포함 |
| `src/interior.js` | `night_life.gd` (window/TV light) | 부분 (사람 실루엣 없음) |
| `src/panel.js`, `motion.js` | `game_ui.gd`, `motion_preview.gd` | 반응형 + 모션 프리뷰 완료 |
| `src/daylight.js` | `daylight.gd` | 이식 |
| `src/garden.js` | `scripts/garden_assets.gd` | 완료 (절차적 로우폴리) |
| `src/farm-paths.js` | `scripts/farm_paths.gd` | 완료 |
| `src/colliders.js` | `world.gd` 장애물 목록 | 간략화 |

