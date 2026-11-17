# Forest Farm Diorama

숲속 농가를 30×30 타일로 만든 실시간 3D 디오라마. 시간, 날씨, 계절에 따라 빛과 대기가 바뀌고,
캐릭터와 동물이 스스로 돌아다니며 일한다.

- **웹 (Three.js)**: https://lolisia.github.io/portfolio-02/ (기준 구현. `master`에 push하면 GitHub Actions가 자동 배포)
- **네이티브 (Godot 4.7)**: 웹 버전을 PC(Forward+)와 Android(Mobile 렌더러)로 옮긴 버전. [`godot/`](godot/README.md)

| | 웹 | 네이티브 |
|---|---|---|
| 엔진 | three.js 0.187, Vite 8 | Godot 4.7.2 (GDScript, GLSL 컴퓨트) |
| 렌더러 | WebGL 2, 커스텀 HDR 후처리 체인 | Forward+ (PC) / Mobile (Android) |
| 셰이더 | 내장 재질 청크 주입(`onBeforeCompile`), 전체 화면 패스 | `.gdshader`, `CompositorEffect` 컴퓨트 셰이더 |
| 배포 | GitHub Pages (정적 빌드) | Windows, Android 세로 APK |

## 렌더링 기법

### 조명과 대기 (웹 `src/mist.js`, `sky.js`, `daylight.js`)

- **HDR 프레임 + 커스텀 후처리 체인.** 장면을 half-float 렌더 타깃(깊이 텍스처 포함)에 그린다.
  그다음 대기, AO, bloom, 그레이딩을 직접 작성한 패스로 합성한다. 톤 매핑은 ACES Filmic.
- **볼류메트릭 안개 레이마칭.** 깊이 버퍼로 화면 픽셀을 월드 좌표로 되돌리고, 카메라 광선을 따라
  안개 밀도와 산란을 적분한다.
  - 밀도는 높이 감쇠, 저지대 안개, 노이즈, 맵 가장자리 감쇠를 곱해 정한다.
  - 각 지점은 **태양 섀도맵(`sampler2DShadow`)으로 가려짐을 판정**한다. 그래서 나무와 건물이 안개에 실제
    빛줄기(god ray)를 만든다. 산란에는 위상 함수, 구름 그림자, 램프 5개의 원뿔 산란을 넣었다.
  - 광선은 두 구간으로 나눈다. 엷은 상층은 긴 간격으로 적은 수만 샘플링하고, 그림자가 드리우는 지면 근처에
    샘플을 몰아준다. 지터를 넣고, 반해상도 이하 버퍼에 그린 뒤 깊이를 고려해 복원한다.
- **GTAO 접촉 그림자.** 반해상도, 8샘플. 안개와 다른 그리드에서 깊이 보정 업샘플링한다.
- **Bloom.** 반해상도 밝기 추출 후 5단 mip 체인으로 축소 블러와 확대 합산을 한다. 램프 유리, 수면 반짝임,
  빛을 받은 안개가 번진다.
- **그레이딩.** 그림자와 하이라이트 분할 톤, 날씨 무드(색조, 채도, 대비), 비네트, 화면 공간 별 반짝임을 넣었다.
- **UI 유리 굴절.** 설정 패널 영역에 SDF 베벨 굴절과 프로스트 효과를 같은 합성 패스에서 처리한다.
- **하늘.** 선형 HDR 하늘 하나를 PMREM 환경광과 물 반사가 함께 쓴다. 시간에 따라 태양 고도, 색온도, 노출이 바뀐다.

### 재질 (웹 `src/surfaces.js`, `ground.js`, `foliage.js`)

- **three.js 내장 PBR 셰이더 확장.** `onBeforeCompile`로 표준 재질 셰이더 청크에 다음을 끼워 넣는다.
  - 절차적 나무결, 석재, 기와, 흙 디테일
  - 젖은 표면, 적설, 계절 색조
  - 길 마스크와 풀 눌림
  - 창문 실내광(TV 깜빡임, 지나가는 사람 실루엣)
- **텍스처 생성.** 흙, 잎, 디테일 텍스처를 런타임에 Canvas와 DataTexture로 만든다.
  외부 텍스처 다운로드 없이 512px 타일링 텍스처를 쓴다.
- **바람 애니메이션.** 식생 정점 셰이더가 바람 세기에 따라 흔들림을 만들고, 사용자 슬라이더와 날씨에 연동된다.

### 물과 입자 (웹 `src/water.js`, `cascade.js`, `rain.js`, `seasons.js`, `smoke.js`)

- **평면 반사 연못.** 미러 카메라로 반사를 렌더링한다. 4옥타브 노멀로 물결을 만들고, 반사를 왜곡하고, 겨울에는
  결빙과 균열을 표현한다.
- **폭포.** 두 겹의 연속 수막(포물선 궤적), 화면 정렬 물방울, 바닥 물보라와 거품으로 구성한다.
- **날씨 입자.** 비(지붕과 수목 충돌, 수면 파문), 눈과 눈보라, 벚꽃잎, 낙엽이 있다.
  굴뚝 연기는 불의 세기를 각 연기 입자에 담아, 진한 띠가 올라가는 모습을 만든다.
- **눈 위 발자국.** 캐릭터와 닭의 발자국을 인스턴스로 찍는다. 눈이 내리면 서서히 메워진다.

### 장면 구성과 캐릭터 (웹 `src/modules.js`, `world.js`, `unitychan.js`, `farm-life.js`)

- **모듈 빌더.** 타일 단위 모듈(벽, 창, 문, 지붕)을 형상별로 묶어 `InstancedMesh`로 그린다.
  나무, 꽃, 정원 침대는 Blender로 만든 GLB를 인스턴싱한다.
- **SD Unity-chan.** 애니메이션 클립의 루트 모션을 고정해 스크립트가 이동을 맡는다.
  클립 시간을 0 기준으로 다시 맞추고, 다른 애셋의 동작 클립을 리타깃했다.
- **행동 AI.** 공용 보행 그래프(A*)와 평면 충돌 월드(원·회전 박스, 동적 물체 밀어내기)를 쓴다.
  채소 수확, 낚시, 경례, 실내 방문 같은 일정을 수행한다. 닭, 물고기, 새, 반딧불, 나방도 각자 행동한다.

### Godot 이식 (`godot/`)

- **CompositorEffect 컴퓨트 셰이더**(`atmosphere_shafts.glsl`). Forward+에서 반해상도 깊이 인지 레이마칭으로
  안개와 광선을 만든다. Mobile 렌더러는 캔버스 광선으로 폴백한다.
- **커스텀 태양 그림자 패스**(`shadow_capture.gd`). Godot는 섀도맵을 후처리에 노출하지 않는다. 그래서 별도
  1024² 깊이 카메라의 결과를 선형 거리 텍스처로 바꿔 안개에 넘긴다. 태양이 움직일 때만 갱신한다.
- **SubViewport 평면 반사**(`water_reflection.gd`). 모바일은 화면 공간 반사로 폴백한다.
- **웹 재질 이식.** 웹의 절차적 재질 생성식(`tools/bake-godot-surfaces.mjs`)을 텍스처와 노멀 맵으로 구워
  같은 결과를 더 낮은 비용으로 낸다.
- **웹과의 일치 검증.** 카메라 입력, 캐릭터 일정, 거품, 근접 뷰 같은 웹과 같아야 할 동작을 헤드리스 테스트로
  고정했다(`godot/tools/*_test.gd`). 감사 기록은 `godot/PARITY_AUDIT*.md`에 있다.

## 최적화

원칙은 **보이는 결과를 유지하면서 보이지 않는 계산을 줄이는 것**이다. 모든 수치는 실기기(Android,
Mali-G720 MC8)에서 측정했다.

### 웹: 모바일 Chrome 31~44 FPS → 60 FPS

| 장면 | 변경 전 | 변경 후 |
|---|---:|---:|
| 기본 낮 | 44.0 FPS | 60.4 FPS |
| 야간 | 37.1 FPS | 60.4 FPS |
| 눈보라 | 31.2 FPS | 60.4 FPS |
| 비 | 38.2 FPS | 60.4 FPS |
| 정원 5배 확대 | 35.5 FPS | 60.4 FPS |

- 2분 연속 실행에서 7,243프레임, P95 16.7 ms였다. SurfaceFlinger 실제 표시 타임스탬프로도 교차 확인했다.
- 메인 캔버스 해상도는 낮추지 않았다. 데스크톱 화질도 그대로 두었다.

주요 기법:

1. **위상(topology) 분석 기반 잔디 LOD**(`turf-lod.js`). GLB의 법선 이음새를 병합해 풀잎을 식별한다.
   잎마다 사각형 2개를 삼각형 1개로 바꾼다(패치당 96→36정점, 48→12삼각형).
   - 뿌리와 끝 위치를 보존하고, 폭을 1.3배로 넓혀 덮는 면적을 원본의 ±10% 이내로 맞췄다.
   - 구조를 알 수 없는 애셋은 원본을 그대로 쓴다.
2. **반사 패스 크롭과 캐싱**(`water.js`).
   - 미러 카메라를 연못이 화면에 차지하는 영역으로 잘라, 보이지 않는 반사를 그리지 않는다.
   - 모바일은 반사 이미지만 약 30 Hz로 캐시하고, 물결은 매 프레임 움직인다.
   - 카메라나 줌이 바뀌면 즉시 무효화해, 회전할 때 반사가 미끄러지지 않는다.
3. **꺼진 광원 셰이딩 생략**(`surfaces.js`). 세기가 0인 램프는 그림자 필터와 BRDF 계산을 건너뛴다.
   three.js는 원래 꺼진 광원도 매 fragment마다 계산한다.
4. **안개 적분 재분배.** 반해상도→1/3 해상도, 24→16단계로 줄였다. 총 적분 길이는 유지하고, 샘플은 그림자가
   보이는 지면 근처에 둔다.
5. **결과에 기여하지 않는 계산 제거.** 얼지 않은 물에서는 균열 계산을, 눈이 없을 때는 반짝임 노이즈를 건너뛴다.
6. **기기 프로필**(`mobile-quality.js`). 작은 화면과 coarse pointer일 때 입자 수와 풀 눌림 슬롯을 줄인다.
   눈보라와 일반 눈의 비율 같은 연출 비율은 유지한다. `?quality=mobile|desktop`으로 같은 기기에서 A/B 비교할 수 있다.

자세한 측정 조건과 한계: [docs/mobile-web-performance.md](docs/mobile-web-performance.md)

### 네이티브 Android: GPU 36.5 ms → 31.5 ms (약 15% 향상)

- 효과를 하나씩 끄는 진단으로 병목을 찾았다(식생 → 물 → 안개). 그다음 화질을 낮추지 않는 방법만 적용했다.
  - 풀 눌림의 보수적 영향 경계 밖에서는 16슬롯 정점 루프를 건너뛴다.
  - 폭포 물방울 900개를 MultiMesh 단일 버퍼로 업로드한다.
  - 중복되던 구름 그림자를 fragment당 한 번만 계산한다.
  - 웹 절차적 재질을 텍스처로 굽는다.
- **60 FPS는 아직 달성하지 못했다(약 30 FPS).** 물, 안개, 복잡한 재질의 GPU 비용이 남은 과제다.

자세한 기록: [godot/reports/mobile-2026-11-14/REPORT.md](godot/reports/mobile-2026-11-14/REPORT.md)

## 실행과 검증

```bash
npm ci
npm run dev                # 웹 개발 서버
npm run build:pages        # GitHub Pages(/portfolio-02/)용 정적 빌드
npm run build:diorama      # 자체 서버(/diorama/)용 정적 빌드
bash scripts/verify.sh     # 웹 빌드 + Godot import + 헤드리스 테스트
```

- 근접 뷰: `?view=house|coop|stairs|garden|pond&zoom=N`
- Godot 실행과 프리뷰 플래그: [godot/README.md](godot/README.md)
- 배포: [deploy/diorama/README.md](deploy/diorama/README.md)

## 크레딧

- SD Unity-chan © Unity Technologies Japan / UCL. 라이선스는 `public/models/unitychan/`에 있다.
- 채집·낚시 애니메이션: Kevin Iglesias, "Human Crafting Animations FREE"
