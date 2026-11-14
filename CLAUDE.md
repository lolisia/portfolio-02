# Project instructions

## Git
- 작업을 완료하면 항상 git commit을 진행한다. 사용자에게 다시 묻지 않는다.
  - 이번 작업으로 바뀐 파일만 스테이징한다. `preview-*` 이미지와 `reference/`는 사용자가 따로 요청하지 않으면 커밋하지 않는다.
  - 커밋 메시지는 무엇을, 왜 바꿨는지 요약한다.
- push는 사용자가 요청할 때만 한다.

## 디렉터리 규칙
- `scripts/verify.sh` — 저장소 검증 진입점 (웹 vite build + Godot import + 헤드리스 `godot/tools/*_test.gd`). 새 컴포넌트는 여기에 검증을 추가한다.
- `.artifact/` — 임시 파일·메모·계획 초안 (git 미추적). 임시 파일과 중간 문서는 여기에만 둔다.
- 개발 파이프라인 파일(`.claude/skills/`, `.opencode/`, `opencode.json`, `.artifact/pipeline/`, `.worktrees/`, `AGENTS.md`)은 이 PC에만 두며 커밋하지 않는다 (`.gitignore`로 제외).

## 개발 파이프라인 (문서화 → worktree 병렬 작업 → 통합)
- 구현 계획 문서를 작성하면 `.artifact/pipeline/inbox/<이름>.md`에 저장한 뒤 `dev-pipeline` skill(`/dev-pipeline`)을 실행한다.
- 흐름: opencode planner가 작업 분리 → worktree(`.worktrees/w*`)마다 opencode worker 구현 + 검증 게이트(scope·`scripts/verify.sh`) + opencode reviewer → 통합 브랜치 `feat/<plan>`에 순차 squash merge → 통합 검증 + opencode integrator → `master`에 `--no-ff` merge.
- `dev-pipeline` 실행 중에는 task/통합 브랜치 커밋과 `master` merge를 허용한다. push는 하지 않는다 (`config.json`의 `push: false`).
- worktree는 커밋된 `master`에서 만들어진다. 계획이 미커밋 변경에 의존하면 먼저 커밋한다. 최종 merge는 main checkout에 미커밋 tracked 변경이 있으면 거부된다.
- opencode 모델은 `.artifact/pipeline/config.json`의 `model` (기본 `opencode-go/deepseek-v4.1-flash#max`).
- 계획 문서에는 대상 파일 경로·함수/노드 이름·셰이더 uniform·완료 기준·검증 방법(헤드리스 테스트로 확인 가능한 항목)을 구체적으로 적는다. 시각 품질처럼 헤드리스로 확인할 수 없는 기준은 따로 표시한다.
- 오케스트레이터(Claude)는 작업 코드를 직접 구현하지 않는다. 막힌 작업은 원인 파악 후 지침을 붙여 재배정하거나 사용자에게 묻는다.
