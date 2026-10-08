# 협업 워크플로 — 기획 · 개발 · QA · 문서화 에이전트

역할별 서브에이전트 4개가 **파일로 일을 넘기며** 협업한다. 정의는 `.claude/agents/`에 있다.

| 에이전트 | 역할 | 쓰는 곳 (소유) | 읽기만 하는 곳 |
|---|---|---|---|
| `planner` | 기획 | `docs/GDD.md`, `docs/specs/`, `docs/proposals/`, `docs/planner/` | 전부 |
| `developer` | 개발 | `src/`, `tests/`, `default.project.json`, 스펙의 "개발 메모", `docs/developer/` | `docs/` |
| `qa` | QA | `docs/qa/`, `tests/` (테스트 추가만) | `src/`, `docs/` |
| `docs-writer` | 문서화 | `CLAUDE.md`, `README.md`, `docs/DEV-SETUP.md`, `docs/CHANGELOG.md`, `docs/docs-writer/` | 전부 |

모든 에이전트는 담당 스펙의 `status:` 줄과 "결정 기록"은 수정할 수 있다.

### 작업 기록 (역할 폴더)
기존 폴더(`specs/`, `qa/`, `proposals/`)는 그대로 두고, **작업 단계 기록(인계 메모)만 자기 역할 폴더에** 남긴다.

| 역할 | 작업 기록 파일 |
|---|---|
| 기획 | `docs/planner/<스펙id>-<slug>.md` |
| 개발 | `docs/developer/<스펙id>-<slug>.md` |
| QA | `docs/qa/<스펙id>-<slug>.md` (QA 리포트가 작업 기록을 겸한다) |
| 문서화 | `docs/docs-writer/<스펙id 또는 날짜>.md` |

- 단계가 끝날 때마다 갱신한다: **지금 브랜치, 끝난 것, 남은 것, 다음에 할 첫 단계, 막힌 점**. 최신 내용을 맨 위에 둔다.
- 스펙 안의 "개발 메모"(바뀐 파일, Studio 확인 방법)와 "결정 기록"은 다른 역할이 읽는 곳이라 계속 쓴다. 작업 기록은 그와 별개로 "어디까지 했고 다음에 뭘 하는지"를 남기는 곳이다.

## 흐름

```
 planner          developer          qa                 docs-writer
 draft → ready ─▶ in-dev ─▶ in-qa ─▶ qa-passed ───────▶ done
                    ▲                 │
                    └── P0/P1 버그 ────┘  (docs/qa 리포트로 반려)
```

1. **기획** — `planner`가 `docs/specs/<id>-<slug>.md`를 쓰고 `ready`로 바꾼다.
2. **개발** — `developer`가 `ready` 스펙을 구현하고 검증을 통과시킨 뒤 커밋하고 `in-qa`로 바꾼다.
3. **QA** — `qa`가 수용 기준대로 검증하고 `docs/qa/<id>-<slug>.md`를 쓴다. P0/P1이 있으면 `in-dev`로 반려하고, 없으면 `qa-passed`로 바꾼다.
4. **문서화** — `docs-writer`가 CHANGELOG, CLAUDE.md, DEV-SETUP을 반영하고 `done`으로 바꾼다.

스펙 상태는 `grep -H "^status:" docs/specs/*.md`로 한눈에 본다. 이게 작업 보드다.

## 규칙
- **질문은 위로 올린다.** 스펙이 모호하면 개발은 추측하지 않고 스펙 "결정 기록"에 질문을 적고 멈춘다. GDD 원칙과 어긋나거나 수치를 확정해야 하는 결정은 사용자가 내린다.
- **남의 파일은 고치지 않는다.** 소유권 밖의 수정이 필요하면 보고에 "누가 무엇을 바꿔야 하는지"를 적는다.
- **공용 파일**(`shared/Config.luau`, `shared/Remotes.luau`, `shared/Types.luau`, `shared/maps/init.luau`, `default.project.json`)은 병렬 개발 중에는 스펙에 지정된 개발 에이전트 한 명만 수정한다.
- **검증 통과 전에는 넘기지 않는다**: `rojo build -o build.rbxl && stylua --check src tests && selene src && lune run tests`
- 돌려 보지 않은 것을 통과로 적지 않는다. Studio 확인이 필요한 항목은 "사용자 확인 필요"로 남긴다.

## 실행 방법

**한 세션에서 이어서 시키기 (기본)** — 메인 Claude 세션에서 역할을 지정해 요청한다.
```
planner 에이전트로 M2 Survival 맵 스펙 써줘
developer 에이전트로 docs/specs/m2-01 구현해줘
qa 에이전트로 m2-01 검증해줘
docs-writer 에이전트로 qa-passed 된 것 문서에 반영해줘
```
`/agents`로 정의를 보고 고칠 수 있다.

**병렬 개발** — 서로 다른 파일을 건드리는 스펙 여러 개는 worktree를 나눠 동시에 개발한다.
```bash
claude --worktree m2-survival   # 그 세션에서 developer 에이전트로 해당 스펙 구현
```
`claude --worktree`는 로컬 `main`이 아니라 **`origin/main`에서 브랜치를 만든다.** 로컬 `main`을 먼저 push하거나, 만든 직후 worktree에서 `git merge --ff-only main`으로 맞춘다.
Rojo 포트는 worktree마다 다르게 쓴다 (`rojo serve --port 34872`, `34873`, ...). 머지는 QA 통과 후 메인 세션에서 한다.

## 세션이 끝날 때: 클라우드 세션으로 인계
로컬 세션이 끝나도(사용량 한도, 터미널 종료, 컴퓨터 끔) 클라우드 세션(`claude --cloud`)이 이어서 작업할 수 있게 한다. 클라우드 세션은 **GitHub에 push된 것만** 볼 수 있다.

**평소에 (모든 에이전트)**
- 의미 있는 단위로 커밋할 때마다 자기 브랜치를 push한다: worktree면 `git push -u origin HEAD`, `main`은 메인 세션만 push한다.
- 자기 역할 폴더의 작업 기록(`docs/<역할>/<스펙id>-<slug>.md`, 위 "작업 기록" 참고)에 **인계 메모**를 최신으로 둔다: 지금 브랜치, 끝난 것, 남은 것, 다음에 할 첫 단계, 막힌 점.
- 끝나지 않은 작업도 세션을 마치기 전에 `wip:` 커밋으로 남기고 push한다. 커밋 안 된 변경은 인계되지 않는다.

**한도 경고가 뜨거나 세션을 마쳐야 할 때**
1. 인계 메모를 갱신하고 `wip:` 커밋 + push.
2. 이어받을 클라우드 세션을 연다 (본인이 못 하면 메인 세션이나 사용자가 연다):
   ```bash
   claude --cloud "sushi-survival-race: <역할> 에이전트(.claude/agents/<역할>.md)로 docs/specs/<스펙>.md 이어서 진행. 브랜치 <브랜치>. docs/<역할>/<스펙>.md의 인계 메모부터 읽을 것."
   ```
3. 메인 세션에 어떤 클라우드 세션으로 넘겼는지 알린다.

**클라우드 세션이 받으면**
- 그 브랜치를 체크아웃하고 `CLAUDE.md`, 이 문서, 역할 정의, `docs/<역할>/<스펙>.md`의 인계 메모 순서로 읽고 시작한다.
- 클라우드에는 Roblox Studio가 없다. Studio 확인 항목은 "사용자 확인 필요"로 남긴다. rokit 도구(rojo, stylua, selene, lune)를 설치할 수 없으면 검증하지 못한 항목을 보고에 분명히 적는다.
- 사용량 한도는 계정 단위라서, 한도 때문에 로컬이 멈췄다면 클라우드 세션도 한도가 풀린 뒤에 돈다.

## 스펙 ID
`<마일스톤>-<두 자리 번호>-<slug>.md`. 예: `m2-01-survival-hot-tiles.md`. QA 리포트는 같은 이름을 `docs/qa/`에 쓴다.
