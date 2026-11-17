# Forest Farm Diorama — Godot port

Godot 4.7 프로젝트. 원본 Three.js 디오라마(`../src`)를 PC/모바일 네이티브로 옮기는 작업 공간입니다.

## 실행

리포지토리 루트의 `start-godot.bat`을 더블클릭하거나:

```bat
start-godot.bat
```

Godot 실행 파일이 다른 곳에 있으면 `GODOT_EXE` 환경 변수로 지정할 수 있습니다.
추가 인자는 그대로 전달됩니다 (예: `start-godot.bat -- --dawn`).

```powershell
# Windows PowerShell
& 'D:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --path .
```

```powershell
# 헤드리스 스모크 테스트
& 'D:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' `
  --headless --path . --script 'res://tools/smoke_test.gd'
```

또는 Godot 에디터에서 `godot/project.godot`을 열고 F6/F5.

- 데스크톱: Forward+
- 모바일: Mobile (`project.godot`의 `renderer/rendering_method.mobile`)
- 조작: 좌클릭 드래그/한 손가락 드래그로 지면 이동, 우클릭(또는 좌우 동시 클릭) 드래그/두 손가락 드래그로 회전, 휠/핀치로 포인터·손가락 중심 기준 확대/축소
- 개발용 프리셋: `-- --house`, `-- --pond`, `-- --pondside`, `-- --char`, `-- --char2`, `-- --charclose`, `-- --panel`, `-- --fishtest`, `-- --door`, `-- --front`, `-- --garden`
- 날씨/계절 프리뷰: `-- --winter`, `-- --snow`, `-- --rain`, `-- --spring`, `-- --autumn`, `-- --night`, `-- --dusk`, `-- --dawn`, `-- --sunrise`
- 태스크 프리뷰: `-- --gather`, `-- --fish`, `-- --salute`, `-- --fishnear`, `-- --gathernear`, `-- --snowtest`
- 품질 프리뷰: `-- --high`, `-- --medium`, `-- --low`
- 스크린샷: `-- --shot C:/path.png` (현재 창 해상도, 개발용)

## 현재 이식된 범위

- 30×30 타일 지형(높이 함수·테라스·연못·경계 암반), 암반 절벽과 폭포 출구
- 농가/헛간/닭장(간략화한 모듈 빌더), 정원 침대, 꽃정원(튤립·라벤더·해바라기·폭스글러브·장미), 돌길, 램프 5개
- `nature.glb` 기반 나무·풀·꽃·작물 인스턴싱(바람 셰이더) + 절차적 꽃 메시
- Unity-chan GLB 임포트(90본, 10개 클립), Standing/Walking 전환, A* 경로 걷기(포치/계단 포함), 깜빡임, 크기/접지 보정
- Unity-chan 태스크 AI: 앞마당 채소밭 `Gathering`, 연못가 `FishingBegin/Loop/Stop`(낚싯대·낚싯줄·찌), `Salute`, `KneelDown`, 경례 시 문 여닫기 후 실내 4.5초 방문
- 닭 2마리 + 병아리 4마리(배회·쪼기·도망·낮/날씨에 따른 은신), 지붕 풍향계/수탉/풍속계, 굴뚝 연기
- 연못 물고기 10마리(수면 점프), 나무/램프/지붕을 옮겨 앉는 새
- 시각/바람 슬라이더, 날씨/계절 선택, 자동 시간, 패널 접기, 리셋
- 모션 프리뷰 카드: 지평선(시각), 풍속계(바람), 날씨 아이콘
- 반응형 UI: 실제 창 크기 기준 content scale, 360px 폭/세로 모드 대응, 터치 타깃, 패널 열림 시에도 게임 화면의 위치·배율 유지
- 품질 프리셋: 높음/보통/낮음 (MSAA, 3D 해상도 스케일, SSAO/볼류메트릭, 물 반사, 잔디/파티클 밀도), 선택한 품질의 고정 해상도(자동 품질 저하 없음)
- 태양/하늘/안개/톤매핑/글로우/SSAO 기본 환경, 원본 backdrop 기반 하늘 그라데이션과 분할 톤(그림자/하이라이트) 그레이드
- Forward+ 볼류메트릭 미스트(FogVolume)와 **SubViewport 평면 물 반사**(모바일은 화면공간 반사 폴백), 4옥타브 advected wave normal·바람 기반 slope·slope 반사 왜곡
- 표면 셰이더: 나무결·석재·기와·흙 디테일, 절벽 지층, foliage dapple, 젖은 표면, 눈 덮임
- 봄 벚꽃잎/가을 낙엽 파티클과 지면 레이어, 계절 foliage tint, 겨울 연못 결빙/균열, 폭포 white-water foam·spray, 비 파문, 바람/눈보라 파티클 drift
- 밤 별 dome·달, 램프별 플리커/후광, 램프 주변 나방, 여름밤 반딧불
- Forward+ 하프레스 레이마칭 안개·광선(CompositorEffect: 높이/노이즈/저지대 미스트/램프 산란) + Mobile canvas 광선 폴백, 태양 글레어, 비 지붕/수목 캐노피 충돌·수면/지면 파문
- 커스텀 1024² sun shadow depth pass(태양 이동 시에만 갱신)로 안개/광선에 실제 수목·건물 그림자 투영 (`--noshadow` 폴백, `--shadowdebug` 마스크 뷰)
- 농가 창문 안쪽 실내(가구/커튼/램프/TV) 셰이더, 창문/TV 컬러 플리커, 사람이 지날 때 창문 광량 감소와 창문 앞 실루엣
- 겨울 지면 융기(셰이더)와 눈 위 부츠/닭 발자국, 눈이 쌓이면 서서히 메워지고 눈보라에는 더 빠르게 메워짐
- 캐릭터/닭이 지나간 자리의 풀 눌림과 회복 트레일(16슬롯 트램플 셰이더)
- 계절/날씨 상태: 여름/가을/겨울 색조, 비/눈 파티클 크로스페이드, 겨울 낙엽/풀 제거
- 지형 경로 마스크(돌길 주변 흙 노출), 웅덩이/습기 표현
- 화면 후처리: UI 패널 유리 렌즈·프로스트 블러, 원본식 분할 톤/날씨 무드 그레이드, 비네트
- **WebP → PNG로 변환한 Unity-chan GLB** (`convert_unitychan_glb.py`)
- 개발용 오버레이: `--pathdebug`로 A* 그래프 노드/엣지와 캐릭터 경로 표시

## 아직 남은 작업

- 추가 Android GPU/중급 기기 프로파일링과 60 FPS 목표 최적화
- Android 실기기 설치·성능 검증(현재 ADB 연결 기기 없음). 세로 고정 debug APK 빌드·서명 검증 및 Mali-G720 실기기 실행·프로파일링 완료.

## 다음 작업

남은 작업의 우선순위·파일·완료 기준은 [ROADMAP.md](ROADMAP.md)에 정리되어 있습니다.

## 변환 노트

원본 `public/models/unitychan/sd_unitychan.glb`는 `EXT_texture_webp`를 필수로 요구해 Godot 코어 glTF 임포터가 거부합니다. `convert_unitychan_glb.py`가 임베디드 WebP를 PNG로 바꾸고 `godot/assets/models/unitychan/`에 다시 저장합니다. 원본 에셋과 라이선스는 `public/models/unitychan/`을 참고하세요.

## 2차 감사 반영

수정 내용과 검증 범위는 [PARITY_AUDIT_2_RESULT.md](PARITY_AUDIT_2_RESULT.md)를 참고하세요.
`-- --ui-scale 2`로 UI 배율을 명시할 수 있습니다. 근접 프리셋은 `-- --garden --yaw 30 --zoom 5`처럼 웹과 같은 yaw/zoom을 지정할 수 있습니다.
회귀 검사: `Godot --headless --path godot --script res://tools/parity_test.gd` (리포지토리 루트에서 실행).

## Android 세로 APK

- 결과: `build/android/ForestFarmDiorama-portrait.apk` (설치용 debug 서명, ARM64 + ARMv7)
- 패키지: `com.lolis.forestfarmdiorama`, 버전 `0.1.1` (code 2)
- 방향: Portrait 고정. 모바일 기준 뷰포트 720×1280, 화면 배율·안전 영역 대응 UI.
- Android는 Mobile 렌더러와 ETC2/ASTC 텍스처 사용. PC Mobile 렌더러 세로 화면 검사 완료. Mali-G720 실기기에서 실행·프로파일링 완료.
- 이 프로젝트에는 C# 코드가 없으므로 표준 Godot 4.7.2와 표준 Android export template을 사용한다.

리포지토리 루트에서 재빌드:

```powershell
& 'D:\Godot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe' --headless --path godot --editor --import --quit
& 'D:\Godot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe' --headless --path godot --export-debug 'Android Portrait' build/android/ForestFarmDiorama-portrait.apk
```

스토어 제출용 release 키 서명은 포함하지 않는다.

모바일 수정과 실측 결과: [reports/mobile-2026-11-14/REPORT.md](reports/mobile-2026-11-14/REPORT.md).
