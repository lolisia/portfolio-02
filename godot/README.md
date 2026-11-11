# Forest Farm Diorama — Godot port

Godot 4.7 프로젝트. 원본 Three.js 디오라마(`../src`)를 PC/모바일 네이티브로 옮기는 작업 공간입니다.

## 실행

```powershell
# Windows PowerShell
& 'D:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --path .
```

또는 Godot 에디터에서 `godot/project.godot`을 열고 F6/F5.

- 데스크톱: Forward+
- 모바일: Mobile (`project.godot`의 `renderer/rendering_method.mobile`)
- 조작: 좌클릭 드래그 회전, 휠 확대/축소, 터치 한 손가락 회전, 두 손가락 핀치 확대/축소
- 개발용 프리셋: `-- --house`, `-- --pond`, `-- --char`, `-- --panel`, `-- --fishtest`, `-- --door`
- 날씨/계절 프리뷰: `-- --winter`, `-- --snow`, `-- --rain`
- 태스크 프리뷰: `-- --gather`, `-- --fish`, `-- --salute`, `-- --fishnear`, `-- --gathernear`

## 현재 이식된 범위

- 30×30 타일 지형(높이 함수·테라스·연못·경계 암반), 암반 절벽과 폭포 출구
- 농가/헛간/닭장(간략화한 모듈 빌더), 정원 침대, 돌길, 램프 5개
- `nature.glb` 기반 나무·풀·꽃·작물 인스턴싱(바람 셰이더)
- Unity-chan GLB 임포트(90본, 10개 클립), Standing/Walking 전환, 경유지 걷기, 깜빡임, 크기/접지 보정
- Unity-chan 태스크 AI: 앞마당 채소밭 `Gathering`, 연못가 `FishingBegin/Loop/Stop`(낚싯대·낚싯줄·찌), `Salute`, `KneelDown`, 경례 시 문 여닫기
- 닭 2마리 + 병아리 4마리(배회·쪼기·낮/날씨에 따른 은신), 지붕 풍향계/풍속계, 굴뚝 연기
- 연못 물고기 10마리, 나무/램프/지붕을 옮겨 앉는 새
- 시각/바람 슬라이더, 날씨/계절 선택, 자동 시간, 패널 접기, 리셋
- 태양/하늘/안개/톤매핑/글로우/SSAO 기본 환경
- Forward+ 볼류메트릭 미스트(FogVolume)와 **SubViewport 평면 물 반사**(모바일은 화면공간 반사 폴백)
- 표면 셰이더: 나무결·석재·기와·흙 디테일, 젖은 표면, 눈 덮임
- 계절/날씨 상태: 여름/가을/겨울 색조, 비/눈 파티클, 겨울 낙엽/풀 제거
- 지형 경로 마스크(돌길 주변 흙 노출), 웅덩이/습기 표현
- 화면 후처리: UI 패널 유리 렌즈, 톤 그레이드, 비네트
- **WebP → PNG로 변환한 Unity-chan GLB** (`convert_unitychan_glb.py`)

## 아직 남은 작업

- 커스텀 HDR 레이마칭 안개·광선 샤프트·GTAO·블룸 (현재는 Godot 볼류메트릭 미스트 사용)
- 물 반사 해상도/격프레임 갱신 및 물보라 디테일
- 벚꽃/낙엽 파티클의 계절별 밀도와 지면 변위(눈 높이)
- Unity-chan 실내 이동/실내 소품과 경로 그래프 기반 탐색(현재는 근거리 웨이포인트 이동)
- 모바일 품질 프로파일, 배터리/발열/해상도 스케일링 튜닝
- 실기기 프로파일링(중급 Android 우선)

## 변환 노트

원본 `public/models/unitychan/sd_unitychan.glb`는 `EXT_texture_webp`를 필수로 요구해 Godot 코어 glTF 임포터가 거부합니다. `convert_unitychan_glb.py`가 임베디드 WebP를 PNG로 바꾸고 `godot/assets/models/unitychan/`에 다시 저장합니다. 원본 에셋과 라이선스는 `public/models/unitychan/`을 참고하세요.
