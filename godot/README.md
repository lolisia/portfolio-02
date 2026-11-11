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
- `-- --house`, `-- --char` 개발용 카메라 프리셋 지원

## 현재 이식된 범위

- 30×30 타일 지형(높이 함수·테라스·연못·경계 암반)
- 농가/헛간/닭장(간략화한 모듈 빌더), 정원 침대, 돌길, 램프 5개
- `nature.glb` 기반 나무·풀·꽃·작물 인스턴싱(바람 셰이더)
- Unity-chan GLB 임포트(90본, 10개 클립), Standing 재생, 깜빡임, 크기/접지 보정
- 시각/바람 슬라이더, 날씨/계절 선택, 자동 시간, 패널 접기, 리셋
- 태양/하늘/안개/톤매핑/글로우/SSAO 기본 환경
- **WebP → PNG로 변환한 Unity-chan GLB** (`convert_unitychan_glb.py`)

## 아직 남은 작업

- 표면 셰이더 전체 이식: 젖은 표면·웅덩이·눈 덮임·trample·눈 반짝임
- 커스텀 HDR 후처리(레이마칭 안개·GTAO·블룸·패널 렌즈)
- 평면 물 반사(SubViewport 미러 카메라), 폭포/다리/물고기
- 계절/날씨 파티클(벚꽃·낙엽·눈·비) 및 지면 변위
- 농장 생활(닭·새·굴뚝 연기·풍향계), Unity-chan 행동 AI/경로 탐색
- 모바일 품질 프로파일, 배터리/발열/해상도 스케일링 튜닝
- 실기기 프로파일링(중급 Android 우선)

## 변환 노트

원본 `public/models/unitychan/sd_unitychan.glb`는 `EXT_texture_webp`를 필수로 요구해 Godot 코어 glTF 임포터가 거부합니다. `convert_unitychan_glb.py`가 임베디드 WebP를 PNG로 바꾸고 `godot/assets/models/unitychan/`에 다시 저장합니다. 원본 에셋과 라이선스는 `public/models/unitychan/`을 참고하세요.
