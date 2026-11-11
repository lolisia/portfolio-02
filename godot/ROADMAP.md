# Godot 이식 로드맵 / 핸드오프

- 기준일: 2026-11-11
- 엔진: Godot 4.7.2 stable (mono)
- 경로: `D:\Godot\Godot_v4.7.2-stable_mono_win64`
- 프로젝트: `D:\DEV\portfolio-02\godot\project.godot`
- 문서 작성 기준 커밋: `c93dd0b Add Forward+ planar pond reflection and volumetric mist`
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
... -- --door           # 정문 근처
... -- --fishtest       # 연못가 낚시 확인
... -- --char           # 캐릭터 근처
... -- --char2          # 캐릭터 측면
... -- --panel          # 환경 설정 패널 펼침

... -- --gather         # 채소밭 수확 태스크
... -- --fish           # 연못 낚시 태스크
... -- --salute         # 경례 + 문 열기
... -- --fishnear       # 연못 근처에서 낚시 시작
... -- --gathernear     # 채소밭 근처에서 수확 시작

... -- --winter         # 겨울 상태 즉시 적용
... -- --snow           # 눈 날씨
... -- --rain           # 비 + 젖은 지면
```

### 빠른 헤드리스 검증

```powershell
& 'D:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' `
  --headless --path 'D:\DEV\portfolio-02\godot' --quit-after 3
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
- `nature.glb` 기반 나무·풀·꽃·작물 `MultiMesh` 인스턴싱
- 표면 셰이더
  - 나무결, 석재, 기와, 흙, 철
  - 젖은 표면, 웅덩이, 눈 덮임
  - 지형 경로 마스크(돌길 주변 흙)
- 계절/날씨 상태
  - 여름/가을/겨울 하늘·안개 색
  - 비/눈 GPU 파티클
  - 겨울 낙엽/풀 제거, 눈 덮임
- Unity-chan
  - GLB 임포트(90본, 10개 애니메이션)
  - Standing/Walking 크로스페이드, 경유지 걷기
  - Gathering / Fishing / Salute / Kneel 태스크
  - 낚싯대·낚싯줄·찌
  - 경례 시 정문 열림/닫힘
  - 눈 깜빡임
- 농장 생활
  - 닭 2 + 병아리 4, 배회/쪼기/낮·날씨 은신
  - 지붕 풍향계·풍속계
  - 굴뚝 연기 GPU 파티클
  - 물고기 10마리
  - 나무/램프/지붕을 옮겨 앉는 새
- 물
  - 연못 수면 셰이더, 물고기, 다리, 폭포
  - Forward+ SubViewport 평면 반사
  - 모바일은 화면공간 반사 폴백
- 대기
  - Forward+ `FogVolume` 볼류메트릭 미스트
  - Environment depth fog / glow / SSAO / ACES
- UI
  - 시각/바람 슬라이더, 자동 시간, 날씨/계절, 리셋, 패널 접기
  - 패널 뒤 유리 렌즈 + 색조/비네트 후처리
  - Unity-chan 크레딧 링크

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
| `scripts/farm_life.gd` | 닭, 풍향계, 연기, 물고기, 새 |
| `scripts/weather_fx.gd` | 비/눈 GPU 파티클 |
| `scripts/post_process.gd` | 패널 렌즈/그레이드 |
| `scripts/water_reflection.gd` | Forward+ 평면 반사 SubViewport |
| `scripts/nature_assets.gd` | `nature.glb` 메시 추출 |
| `shaders/surface.gdshader` | 건축/소품 표면 |
| `shaders/terrain.gdshader` | 지형/경로/눈/습기 |
| `shaders/foliage.gdshader` | 바람/눈/겨울 낙엽 |
| `shaders/water.gdshader` | 물결/반사/색 |
| `shaders/waterfall.gdshader` | 폭포 |
| `shaders/post_process.gdshader` | 화면 후처리 |

### 원본 참고

- 웹 원본 소스: `../src/`
- 원본 에셋: `../public/`
- `public/models/unitychan/sd_unitychan.glb`는 WebP 텍스처를 요구하므로 Godot용은 `godot/assets/models/unitychan/sd_unitychan.glb` (PNG 변환본) 사용
- 변환 스크립트: `convert_unitychan_glb.py`

---

## 3. 남은 작업 우선순위

### P0. 물 반사/미스트 검증 및 튜닝

**현재 상태**
- Forward+에서 SubViewport 미러 카메라가 동작.
- 반사 텍스처는 생성되지만, 수면 Fresnel/블렌딩이 약해 눈에 띄는 반사가 부족할 수 있음.
- `Camera3D`에 4.7에서 `clip_plane`이 없어, 물 아래 지오메트리를 셰이더 `discard`로 제거하는 우회 사용.
- 반사 카메라가 물속 지형/암반을 보지 않도록 `surface/terrain/foliage` 셰이더에 하드코딩된 `0.44` 수면 컷이 있음.

**할 일**
1. 여러 카메라 각도/줌에서 반사 방향/상하 반전이 맞는지 확인.
2. `water_reflection.gd`의 미러 카메라 목표/업 벡터 검증.
3. `reflection_strength`, Fresnel, 수면 알파 튜닝.
4. 필요 시 격프레임 갱신/반사 해상도 조절(`viewport.size`).
5. 물 반사가 필요 없는 Mobile에서는 현재처럼 비활성화 유지.

**파일**
- `scripts/water_reflection.gd`
- `shaders/water.gdshader`
- `scripts/main.gd` (`high_end_rendering`)

**완료 기준**
- 연못에 나무/농가/하늘이 자연스럽게 비침.
- 물속 바닥/암반이 반사면에 나타나지 않음.
- Forward+에서 프레임 저하가 과하지 않음.
- Mobile에서 오류/검은 수면이 없음.

**리스크**
- 미러 카메라의 음수 행렬식으로 인한 컬링/클리핑 이슈.
- `Camera3D.clip_plane` 부재로 인한 우회의 한계.

---

### P1. 빛줄기·커스텀 HDR 안개

**현재 상태**
- Godot `FogVolume` + Environmental volumetric fog 사용.
- 원본의 커스텀 레이마칭 안개(구름 노이즈, 램프 산란, 새벽 저지대 안개)와는 다름.
- 태양 그림자 기반 빛줄기는 내장 볼류메트릭에 의존.

**할 일**
1. Forward+ `CompositorEffect`로 half-res fog/light-shaft pass 구현 검토.
   - depth texture + sun shadow map 접근 제약 확인.
   - 불가능하면 screen-space light shafts + FogVolume 조합.
2. 새벽/밤/비/눈에 따른 안개 밀도·색·산란 튜닝.
3. 램프 5개의 볼류메트릭 산란(Spot/Omni light) 확인.
4. 밤하늘 별/달(원본 `sky.js`의 별) 추가.
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

### P2. 겨울 지면 변위 + 발자국

**현재 상태**
- 눈은 셰이더 색/표면 덮임만 적용.
- 실제 지형 정점 융기 없음.
- 캐릭터/닭 발자국 없음.

**할 일**
1. `world.gd`의 지형 `ArrayMesh` 정점을 `snow_depth`에 따라 융기.
   - `seasons.js`의 `ground.setY` 로직 참고.
   - 변경 시 `computeVertexNormals`/`surface update` 비용 주의.
2. `footprints.gd` 신규 포트:
   - `MultiMesh` 평면/발자국 텍스처.
   - `snow_depth`와 이동 거리 기반 스폰.
   - 눈이 내리면 서서히 메워짐.
3. 캐릭터/닭 이동 시 발자국 API 호출.
4. 지면 변위와 경로 마스크/발자국이 겹치지 않게 처리.
5. 풀 trample: 걷는 캐릭터/닭 주변 풀이 눌리고 회복되는 셰이더/데이터 추가.

**파일**
- `scripts/world.gd`
- `scripts/unity_chan.gd`
- `scripts/farm_life.gd`
- 신규 `scripts/footprints.gd`
- `shaders/terrain.gdshader`

**완료 기준**
- 겨울에 지면이 실제로 눈 높이만큼 올라감.
- 캐릭터/닭이 지나간 자리에 발자국이 남고 시간이 지나면 사라짐.
- 경사면/물가에서 발자국이 떠 보이지 않음.

---

### P3. 계절 파티클/날씨 전환 완성

**현재 상태**
- 비/눈 파티클만 있음.
- 벚꽃/낙엽 파티클 없음.
- 날씨 전환이 즉시적이며 원본의 크로스페이드 느낌이 약함.

**할 일**
1. `seasons.js` 포트:
   - 봄 벚꽃잎, 가을 낙엽.
   - 나무 위치 기반 스폰, 바람에 따른 이동.
   - 지면에 잠시 쌓였다가 사라지는 표현(선택).
2. `weather.js`식 크로스페이드:
   - 날씨 상태 가중치 보간.
   - 안개 밀도/하늘/글로우/파티클 강도 연동.
3. 비 물보라/수면 파문.
4. 눈보라 강도에 따른 파티클 수/속도/바람.
5. 겨울 물 동결/얼음 셰이더, 폭포 spray/foam/vapor 디테일.

**파일**
- `scripts/weather_fx.gd`
- `scripts/day_cycle.gd`
- `scripts/main.gd`
- 신규 `scripts/seasons_fx.gd`

**완료 기준**
- 봄/가을에 계절 파티클이 보임.
- 날씨 변경 시 1~2초에 걸쳐 자연스럽게 전환.
- 비 올 때 수면/지면 파문이 보임.

---

### P4. 농장/야생 디테일

**현재 상태**
- 닭은 배회/쪼기만; 원본의 놀람/도망/닭장 출입 없음.
- 새는 나무/램프/지붕 이동; 원본의 체류/이착륙 연출은 단순화.
- 물고기는 헤엄만; 점프/물보라 없음.
- 램프는 점등만; 깜빡임/글래스 발광/후광 없음.
- 풍향계는 화살표만; 원본의 수탉 실루엣 없음.
- 실내 TV/사람 실루엣 없음.
- 반딧불/나방 없음.

**할 일**
1. 닭:
   - Unity-chan 접근 시 도망.
   - 밤/비에 닭장 안으로 들어가고 나오는 사이클.
   - 발자국/모이 쪼기 디테일.
2. 새:
   - 체류 시간, 이착륙 flare, 날개 접기.
   - 나뭇가지 흔들림과 함께 앉기.
3. 물고기:
   - 가끔 수면 위로 점프 + 물보라.
4. 램프:
   - 랜턴별 재질/점멸, 글래스 emissive, 후광 스프라이트.
5. 실내:
   - TV 색 번짐, 지나가는 사람 실루엣, 창문 조명.
6. 반딧불/나방:
   - 밤, 따뜻하고 바람 약한 날에만.
7. 풍향계 수탉 실루엣/브라스 디테일.
8. 농가 주변 디테일: 정원 계단/flight, 울타리, 먼 꽃정원.
9. 원본 `garden.js`의 꽃(튤립·라벤더·해바라기·폭스글러브·장미) 이식.

**파일**
- `scripts/farm_life.gd`
- `scripts/world.gd`
- `scripts/unity_chan.gd`
- 신규 `scripts/interior.gd`
- 신규 `scripts/night_life.gd` (반딧불/나방)

**완료 기준**
- 닭이 캐릭터를 피해 도망.
- 밤에 닭이 닭장으로 들어감.
- 램프가 랜턴별로 미세하게 깜빡임.
- 실내 창문 빛이 시간/TV에 따라 변함.

---

### P5. Unity-chan 경로 탐색/실내

**현재 상태**
- 근거리 웨이포인트 + 충돌 슬라이드.
- A* 그래프 없음.
- 문 앞 경례만 하고 실내로 들어가지 않음.

**할 일**
1. `farm-paths.js` 포트:
   - 0.6 타일 격자 그래프.
   - `closest`, `route` A*.
   - `world.walkable` 연동.
2. 태스크 목적지까지 A* 경로 사용.
3. 정문 통과:
   - 문 열기 → 문 안/밖 상태.
   - 실내에서 잠시 머문 뒤 다시 나오기.
4. 실내 공간:
   - 최소한의 방/창문/램프, 또는 실내 상태에서 캐릭터 숨김.
5. 낚시/밭일 중 장애물 회피 안정화.

**파일**
- 신규 `scripts/farm_paths.gd`
- `scripts/unity_chan.gd`
- `scripts/world.gd`

**완료 기준**
- 캐릭터가 건물/침대를 관통하지 않고 목적지까지 이동.
- 문을 열고 들어갔다가 다시 나옴.
- 태스크가 막힘 없이 반복됨.

---

### P6. UI/모바일

**현재 상태**
- 패널 최소 폭 650px → 세로 모바일에서 넘칠 수 있음.
- 모바일 실기기 테스트 없음.
- 품질 설정/해상도 스케일/그림자 예산 없음.
- 원본의 캔버스 모션 프리뷰(시각/바람/날씨) 없음.
- 접근성(터치 타깃, safe area) 일부만 반영.

**할 일**
1. UI 반응형:
   - 패널을 화면 폭에 맞게 축소.
   - 세로/가로 모드, safe area.
   - 터치 슬라이더/옵션 버튼 크기.
2. 원본 모션 프리뷰 포트:
   - `motion.js`의 지평선/풍속계/날씨 드로잉을 `Control._draw`로.
3. 품질 프리셋:
   - High/Medium/Low.
   - 해상도 스케일, 그림자 램프 수, 파티클 수, 잔디 밀도.
4. 모바일 실기기 프로파일링:
   - 중급 Android 우선.
   - 발열/배터리/프레임 측정.
5. 적응형 해상도/그림자 갱신.

**파일**
- `scripts/game_ui.gd`
- `scripts/main.gd`
- `project.godot`
- 신규 `scripts/quality_manager.gd`

**완료 기준**
- 360px 폭에서도 패널이 넘치지 않음.
- 터치로 모든 컨트롤 조작 가능.
- 중급 Android에서 목표 FPS 달성.
- Low 프리셋에서도 씬이 깨지지 않음.

---

### P7. 빌드/배포/테스트

**할 일**
1. Windows/Linux/macOS/Android/iOS export preset 정리.
2. 아이콘/스플래시/앱 이름/버전.
3. Android 서명, iOS는 Mac/Xcode 필요.
4. 헤드리스 스모크 테스트 추가:
   - 월드 빌드, 태스크 상태 전환, 셰이더 파라미터.
5. 성능 기준 문서화.
6. README/ROADMAP 최신화.

---

## 4. 알려진 이슈 / 주의점

- **물 반사**
  - `Camera3D.clip_plane`이 Godot 4.7에 없어 물 아래 지오메트리를 셰이더 `discard`로 제거.
  - `surface/terrain/foliage` 셰이더에 `0.44` 수면 컷이 하드코딩되어 있음 → 수면 높이 변경 시 함께 수정.
  - 반사 텍스처의 상하/좌우가 카메라 각도에 따라 뒤집힐 수 있음 → 여러 각도에서 확인.
  - SubViewport가 매 프레임 렌더링됨 → 필요 시 격프레임/해상도 조정.
- **안개**
  - `FogVolume`과 Environment volumetric fog는 Forward+ 전용.
  - Mobile은 depth fog 폴백.
  - 커스텀 레이마칭/광선 샤프트는 아직 없음.
- **눈**
  - 지형 변위가 아니라 셰이더 색만 적용.
  - 겨울에 식물 95% discard; 일부만 남음.
- **태스크 AI**
  - A* 그래프가 아니라 근거리 웨이포인트 + 충돌 슬라이드.
  - 작은 덤불/램프는 통과 가능하게 처리.
  - 문 앞 경례만 하고 실내 진입은 없음.
- **UI**
  - 패널 최소 650px; 세로 모바일 대응 필요.
  - 원본 모션 프리뷰 캔버스 없음.
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

## 5. 내일 이어서 할 일 (추천 순서)

1. **물 반사 검증/튜닝** (P0)
   - `--pond` + 여러 각도/줌에서 반사 확인
   - 필요 시 `WaterReflection` 미러 목표/업 벡터 수정
2. **빛줄기/안개 튜닝** (P1)
   - `--house` 아침/저녁, `--winter`, `--rain`에서 FogVolume/조명 확인
   - 커스텀 CompositorEffect는 리스크가 크므로 먼저 내장 볼류메트릭으로 목표치 확인
3. **눈 지면 변위 + 발자국** (P2)
   - 눈 높이와 캐릭터/닭 발자국이 눈에 띄는 개선
4. **경로 그래프/A* + 실내** (P5)
5. **모바일 UI/품질 프로파일** (P6)

### 세션 시작 체크리스트

- [ ] `git status` 확인 (preview/reference 제외)
- [ ] `git log --oneline -3` 확인
- [ ] 헤드리스 실행으로 파싱 오류 확인
- [ ] `--pond` / `--house` 렌더로 회귀 확인
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
| `src/seasons.js` | `day_cycle.gd`, `weather_fx.gd`, shaders | 부분 |
| `src/weather.js` | `main.gd` wet/snow state | 부분 |
| `src/rain.js` | `weather_fx.gd` | 간략화 |
| `src/footprints.js` | 없음 | 미이식 |
| `src/farm-life.js` | `farm_life.gd` | 부분 |
| `src/wildlife.js` | `farm_life.gd` | 부분 |
| `src/unitychan.js` | `unity_chan.gd` | 부분 |
| `src/interior.js` | 없음 | 미이식 |
| `src/panel.js`, `motion.js` | `game_ui.gd` | 모션 프리뷰 누락 |
| `src/daylight.js` | `daylight.gd` | 이식 |
| `src/garden.js` | `world.gd::_build_garden_beds` | 꽃정원 대신 작물밭으로 대체 |
| `src/farm-paths.js` | 없음 | 미이식 |
| `src/colliders.js` | `world.gd` 장애물 목록 | 간략화 |

