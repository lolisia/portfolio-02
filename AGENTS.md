# AGENTS.md

이 저장소에서 작업하는 모든 AI 코딩 에이전트(Claude Code, opencode planner/worker/reviewer/integrator)의
공통 지침. `CLAUDE.md`는 이 파일을 그대로 불러온다. 지침은 이 파일에만 작성한다.

## 프로젝트 개요

portfolio-02: "Forest Farm" 디오라마. 원본은 Three.js 웹(루트 `src/`, `index.html`, Vite), 이를 Godot 4.7로
PC/모바일 네이티브 이식하는 작업(`godot/`)이 주 개발 대상이다. 웹 버전은 시각·동작 기준(parity reference)이다.

- 웹: Node + Vite 8 + three.js (`npm run dev`, `npm run build`). 소스 `src/*.js`, 에셋 `public/`.
- Godot: `godot/project.godot` (Forward+ 데스크톱, Mobile 렌더러 모바일). 스크립트 `godot/scripts/*.gd`,
  셰이더 `godot/shaders/*.gdshader|*.glsl`, 씬 `godot/scenes/main.tscn`, 에셋 `godot/assets/`.
- Godot 헤드리스 테스트: `godot/tools/*_test.gd` (`extends SceneTree`, 실패 시 exit 1).
  `render_regression_test`는 GPU가 필요해 자동 검증에서 제외된다.
- 설계/진행 문서: `godot/README.md`, `godot/ROADMAP.md`, `godot/PARITY_AUDIT*.md`.
- 환경: Windows + Git Bash. Node 22, npm, Python 3.13, Godot 4.7.2 mono. 스크립트는 Git Bash에서 동작하게 작성한다.

## 디렉터리 규칙

- `scripts/verify.sh` — 저장소 검증 진입점 (웹 vite build + Godot import + 헤드리스 `godot/tools/*_test.gd`, 약 20초).
  새 컴포넌트는 여기에 검증을 추가한다 (`godot/tools/*_test.gd`는 자동 포함).
- `.artifact/` — 임시 파일·메모·계획 초안 (git 미추적). 임시 파일과 중간 문서는 여기에만 둔다.
- `reference/`, `preview-*` 이미지, `dist/`는 수정하지 않는다.
- 개발 파이프라인 파일(`.claude/skills/`, `.opencode/`, `opencode.json`, `.artifact/pipeline/`, `.worktrees/`)은
  이 PC에만 두며 커밋하지 않는다 (`.gitignore`로 제외). `AGENTS.md`와 `CLAUDE.md`는 커밋한다.

## 검증

- 전체: `bash scripts/verify.sh`
- Godot 실행 파일: `GODOT_EXE` 환경 변수, 없으면
  `D:/Godot/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe`.
- 단일 테스트: `"$GODOT_EXE" --headless --path godot --script res://tools/smoke_test.gd`
- 새 스크립트·셰이더의 `.uid` 파일 생성: `"$GODOT_EXE" --headless --path godot --import`
  (새 스크립트·셰이더는 `.uid` 파일을 함께 커밋한다)
- Godot import가 `*.import` 파일의 줄끝(LF)만 바꿔 놓는 경우가 있다. 내용 변화가 없으면 `git checkout -- <file>`로
  되돌린다 (`scripts/verify.sh`가 자동 처리).
- 시각 품질처럼 헤드리스로 확인할 수 없는 변경은 Godot에서 직접 확인한다 (`start-godot.bat`, 프리뷰 플래그는 `godot/README.md`).

## 코드 스타일

- GDScript는 정적 타입을 쓰고 기존 파일의 스타일(탭 들여쓰기, `snake_case`)을 따른다.

## Git (대화형 작업)

- 작업을 완료하면 항상 git commit을 진행한다. 사용자에게 다시 묻지 않는다.
  - 이번 작업으로 바뀐 파일만 스테이징한다. `preview-*` 이미지와 `reference/`는 사용자가 따로 요청하지 않으면 커밋하지 않는다.
  - 커밋 메시지는 무엇을, 왜 바꿨는지 요약한다.
- push는 사용자가 요청할 때만 한다.

## 개발 파이프라인 (문서화 → worktree 병렬 작업 → 통합)

- 구현 계획 문서를 작성하면 `.artifact/pipeline/inbox/<이름>.md`에 저장한 뒤 `dev-pipeline` skill(`/dev-pipeline`)을 실행한다.
- 흐름: opencode planner가 작업 분리 → worktree(`.worktrees/w*`)마다 opencode worker 구현 + 검증 게이트(scope·`scripts/verify.sh`)
  + opencode reviewer → 통합 브랜치 `feat/<plan>`에 순차 squash merge → 통합 검증 + opencode integrator → `master`에 `--no-ff` merge.
- `dev-pipeline` 실행 중에는 task/통합 브랜치 커밋과 `master` merge를 허용한다. push는 하지 않는다 (`config.json`의 `push: false`).
- worktree는 커밋된 `master`에서 만들어진다. 계획이 미커밋 변경에 의존하면 먼저 커밋한다.
  최종 merge는 main checkout에 미커밋 tracked 변경이 있으면 거부된다.
- opencode 모델은 `.artifact/pipeline/config.json`의 `model` (기본 `opencode-go/deepseek-v4.1-flash#max`).
- 계획 문서에는 대상 파일 경로·함수/노드 이름·셰이더 uniform·완료 기준·검증 방법(헤드리스 테스트로 확인 가능한 항목)을
  구체적으로 적는다. 시각 품질처럼 헤드리스로 확인할 수 없는 기준은 따로 표시한다.
- 오케스트레이터(Claude)는 작업 코드를 직접 구현하지 않는다. 막힌 작업은 원인 파악 후 지침을 붙여 재배정하거나 사용자에게 묻는다.

### 파이프라인 agent(opencode) 작업 규칙

위 "Git (대화형 작업)" 규칙 대신 아래를 따른다.

- 작업 파일(`.artifact/pf/task.md`)에 적힌 scope 경로만 수정한다. 다른 작업이 병렬로 진행 중이다.
- git 커밋·브랜치 변경·push는 하지 않는다. 파이프라인이 처리한다.
- `AGENTS.md`, `CLAUDE.md`, `.claude/`, `.opencode/`, `opencode.json`, `.artifact/`(입력 읽기 제외), `.worktrees/`는 수정하지 않는다.
- 작업 파일의 verify 명령을 직접 실행해 통과시킨 뒤 끝낸다. 서버·Godot 창을 띄운 채로 두지 않는다 (항상 `--headless`).
