status: in-qa
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# f1-01 — 스시 파이트 핵심 로직 (간장 게이지·넉백·장외·목숨)

- 마일스톤: F1 (스시 파이트 MVP)
- GDD 근거: `docs/fight/GDD.md` §3·§5·§7
- 담당 개발 worktree: `sushi-fight` 브랜치
- 공용 파일 수정 담당: 없음 (파이트 수치는 `src/shared/fight/FightConfig.luau`에 따로 둠 — 스시런 `Config.luau`는 안 건드림)

## 목표
서버가 스시 파이트 판정에 쓸 순수 로직을 Roblox API 없이 만들고 테스트로 고정한다. 플레이어가 보는 것은 아직 없다(F1-03부터).

## 범위
- 포함: 간장 게이지(더하기·상한·회복·색 진하기), 넉백 속도·방향·경직, 장외 판정, 타격 장부(무적·같은 기술 잠금·KO 점수), 매치(목숨·탈락 순서·우승·순위·시간 종료 1등·서든데스 시작), 젓가락 소환 대상.
- 제외: 서버 서비스·리모트·플레이스 역할(F1-03), 조작·버튼(F1-04), 아레나 연결(F1-05), 연출·UI(F1-07), 아이템 생성·물리(F1-08). 특수 스킬은 F1-02.

## 수용 기준
### 순수 로직 (lune 테스트로 확인 — `tests/fight-logic.spec.luau`)
- [x] AC1: 게이지는 0~300으로 잘리고 초생강 회복은 0 아래로 안 내려간다.
- [x] AC2: 간장 색 진하기는 0%에서 0, 150% 이상에서 1.
- [x] AC3: 넉백 속도 = 기본 + 맞은 뒤 게이지 × 배율, 상한 220.
- [x] AC4: 넉백 방향은 때린 사람 → 맞은 사람(겹치면 facing, 없으면 -Z), 크기는 넉백 속도, 위 성분은 속도 × lift.
- [x] AC5: 경직 = 속도 × 0.004, 0.1~1.2초.
- [x] AC6: 장외 = 바닥보다 25 넘게 아래 또는 중심에서 반지름 + 60 넘게 밖. 경계는 장외 아님.
- [x] AC7: 맞으면 게이지·넉백·경직을 돌려주고 마지막 타격을 기록한다.
- [x] AC8: 자기 자신·무적 중·같은 사람에게 같은 기술 0.4초 안은 안 맞는다(다른 기술·다른 사람은 됨).
- [x] AC9: KO 점수는 장외 직전 5초 안에 마지막으로 때린 사람, 아니면 없음(자폭). 장외 뒤 기록을 지우고, 나간 사람은 때린 기록·잠금도 지운다.
- [x] AC10: 장외면 목숨 -1·게이지 0·KO +1(자기 자신·나간 사람은 점수 없음), 목숨 0이면 탈락 순서가 붙는다.
- [x] AC11: 1명 남으면 우승. 방을 나가면 탈락으로 친다.
- [x] AC12: 순위 = 살아 있는 사람 목숨 많은 순 → 게이지 낮은 순 → KO 많은 순 → 참가 순, 그다음 탈락한 사람 늦게 탈락한 순.
- [x] AC13: 시간 종료 — 목숨 1등이 1명이면 우승, 여럿이면 서든데스(1등만 남기고 목숨 1·게이지 150%), 순위표는 시간 종료 순위를 유지한다.
- [x] AC14: 젓가락 소환 대상 = 나를 뺀 살아 있는 사람 중 게이지 최고(100% 이상), 동점이면 참가 순.
- [x] AC15·AC16: 중복 userId 제거, 기본 목숨 3, 모든 기술 수치 유효.

### Studio 확인
- 없음 (순수 로직만).

## 공용 파일 변경
- 없음.

## 결정 기록
- 2026-11-11 · 시간 종료 동점 처리 · 목숨이 같으면 게이지와 상관없이 서든데스(게이지는 2등 아래 순위에만) — GDD 7.2 · 메인 세션 (기본값, 사용자 확인 필요)
- 2026-11-11 · 파이트 수치 위치 · 공용 `Config.luau` 대신 `shared/fight/FightConfig.luau` — 스시런 병렬 작업과 충돌을 피하려고. F1-03에서 `Config.Fight`로 옮길지 결정 · 메인 세션

## 개발 메모
- 새 파일: `src/shared/fight/FightConfig.luau`, `src/shared/fight/FightLogic.luau`, `tests/fight-logic.spec.luau` (19 케이스).
- 서버가 쓸 흐름(F1-03): 타격 요청 → `FightLogic.hit(book, input)` → `applied`면 `fighter.gauge = result.gauge`, `AssemblyLinearVelocity = result.velocity`, `MoveExempt.mark`, 경직 `result.hitstun`. 매 틱 `isRingOut` → `koCredit` → `ringOut` → `removeFromBook` → 부활 뒤 `setInvincible(now + Respawn.Invincible)`.
- 검증(2026-11-11, 클라우드 세션): rojo build 통과, stylua 통과, lune 2485 passed 0 failed, luau-lsp 끝 코드 0. **selene `src` 전체는 못 돌림**(Roblox API 덤프 다운로드가 프록시 인증서 때문에 실패) — 새 파일 2개만 `luau` 표준 + `script` 전역으로 따로 돌려 0 errors 0 warnings.
