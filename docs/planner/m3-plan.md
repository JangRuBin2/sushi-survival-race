# M3 기획 작업 기록 (planner)

## 2026-10-08 — M3 스펙 9개 작성 완료 (최신)

**브랜치**: `main` (커밋 안 함 — planner는 Bash가 없음. 메인 세션이 아래 "커밋할 파일"을 커밋 + push)

### 끝난 것
- 이전 planner가 남긴 `m3-01`~`m3-04`, `docs/REFERENCE-party-royale.md` 검토 → 끊긴 곳 없음. 보완:
  - m3-01: `Sfx.start(gui)` 껍데기 추가(m3-08이 `init` 수정 없이 배경음·클릭음·음소거를 하게), m3-07의 서버 이동 파일 수정 예외 삭제, 병렬 뒤 공용 파일 담당 = m3-09
  - m3-02: `Sfx.play` 위치 인자를 HumanoidRootPart로 바로잡음
  - m3-04: 순수 함수는 `Vector3`/`CFrame` 대신 숫자 표(Lune 테스트 환경에 Roblox 자료형 없음)
  - 참고 자료: 기본 키 정보, 로블록스 구현 메모(§6), M3 기본값 색인(§7), Bro Falls 재검색 결과 추가
- 새 스펙: `m3-05` 우승 연출, `m3-06` 다이브, `m3-07` 잡기, `m3-08` 사운드, `m3-09` 통합·장애물 소리·튜닝
- 모든 M3 스펙 `status: ready`. 결정이 필요한 항목은 사용자 지시대로 **기본값으로 정하고** 각 스펙 결정 기록에 "기본값으로 진행, 사용자 수정 가능"으로 남김

### 개발 순서와 병렬 묶음
```
단계 0 (순차, main)      m3-01 foundation  ← 공용 파일·init·CameraDirector·껍데기 전부
                               │ main 병합 + push 후 worktree 생성
단계 1 (병렬, worktree)  m3-02 character    34872   m3-character
                         m3-03 elimination  34873   m3-elimination
                         m3-04 intro        34874   m3-intro
                         m3-05 victory      34875   m3-victory
                         m3-06 dive         34876   m3-dive
                         m3-07 grab         34877   m3-grab
                         m3-08 sound        34878   m3-sound
                               │ 전부 qa-passed → main 병합
단계 2 (순차, main)      m3-09 integration-polish  ← 공용 파일 담당 다시 이 스펙, 맵 파일에 소리
```
- 단계 1의 7개는 **고치는 파일이 서로 겹치지 않는다** (각 스펙 머리의 "이 스펙이 고치는 파일" 참고). HUD는 m3-03 = `HudController.luau`, m3-05 = `HudScreen.luau` Victory 분기로 나눔. 모바일 버튼은 m3-06 = 점프 왼쪽, m3-07 = 점프 위쪽, 각자 ScreenGui.
- worktree를 한 번에 7개 못 돌리면 두 물결로: **A = m3-02, m3-03, m3-06, m3-08** (캐릭터·탈락 연출이 "웃기다" 핵심, 다이브·사운드는 단순) → **B = m3-04, m3-05, m3-07**. m3-02를 먼저 병합하면 m3-03·m3-05 인형이 처음부터 계란초밥으로 보여서 확인이 쉽다(필수 의존은 아님).
- 병합 순서 권장: m3-02 → m3-08 → 나머지 (m3-02가 `SushiBody`를, m3-08이 소리를 채워야 다른 스펙의 Studio 확인이 실감 남).

### 남은 것
- 개발: m3-01부터 (developer)
- 사용자 할 일 (스펙을 막지는 않음):
  1. 배경음 4곡(로비/라운드/결승/우승) Creator Store 무료 음악 id 고르기 → m3-08 `SfxLibrary`에 넣기. 기본 소리로 못 채운 효과음 목록도 m3-08 개발 메모에 나옴
  2. M3 끝나고 친구 테스트(4명 이상) → 바꿀 수치·연출 알려 주기 (m3-09 AC15)
- 기획: 사용자가 기본값을 확인·수정하면 GDD에 반영(v0.4: §4 소개 연출, §6 다이브·잡기 수치, §7 연출 3종·대사, §8 우승 연출 타임라인, 우승 단계 10초). **지금은 GDD에 넣지 않았다** — 기본값이 사용자 확정 전이라.

### 다음에 할 첫 단계
- 메인 세션: 아래 파일 커밋 + push → `developer` 에이전트로 `docs/specs/m3-01-foundation.md` 구현 (main, 순차).

### 막힌 점
- 없음. 로블록스판 "Bro Falls"는 찾지 못함(참고 자료 §0·§7) — 사용자가 다른 게임을 뜻했다면 이름을 알려 주면 보강.

### 사용자 답을 기다리는 질문 (기본값으로 이미 진행 중, 답이 오면 스펙·GDD 수정)
- 기본값 목록 전체: `docs/REFERENCE-party-royale.md` §7 표. 특히 확인하면 좋은 것:
  - 우승 단계를 6초 → 10초로 늘림 (한 판이 4초 길어짐)
  - 로블록스 아바타를 안 불러오고 모두 계란초밥
  - 잡기는 레이서끼리만, 늦추기만(끌기·밀기 없음)
  - 다이브는 서버 검증 없음(클라이언트 물리)
  - 배경음은 사용자가 고를 때까지 무음

### 커밋할 파일
- `docs/REFERENCE-party-royale.md`
- `docs/specs/m3-01-foundation.md`, `m3-02-egg-sushi-character.md`, `m3-03-elimination-cutscene.md`, `m3-04-round-intro-flythrough.md`
- `docs/specs/m3-05-victory-cutscene.md`, `m3-06-dive.md`, `m3-07-grab.md`, `m3-08-sound.md`, `m3-09-integration-polish.md`
- `docs/planner/m3-plan.md`
