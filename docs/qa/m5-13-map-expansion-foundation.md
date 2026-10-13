# QA — m5-13 맵 확장 1차 기반: 신규 맵 6개 껍데기 + 풀 등록

- 스펙: `docs/specs/m5-13-map-expansion-foundation.md`
- 검증 커밋: `2042751`(m5-13 단독 커밋, 압축 해제한 사본에서 5단계 전부) + `4192744`(현재 `main`, m5-14~m5-19 병합 뒤 — 등록 계약이 아직 지켜지는지)
- 결과: **통과** (P0/P1/P2 없음, P3 1건) → 스펙 상태 `qa-passed`. Studio 확인(AC7·AC8)은 사용자 확인 필요.

## 자동 검증
| 명령 | `2042751` (m5-13 시점) | `4192744` + QA 테스트 (현재 main) |
|---|---|---|
| `rojo build -o build.rbxl` | 통과 | 통과 |
| `stylua --check src tests` | 통과 | 통과 |
| `selene src` | 0 errors / 0 warnings | 0 errors / 0 warnings |
| `lune run tests` | 1135 passed, 0 failed | 1258 passed, 0 failed (QA 추가 전 1233) |
| `luau-lsp analyze` (타입 검사) | 끝 코드 0 | 끝 코드 0 |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `m5-03-foundation` AC1(개발), QA `m5-13 QA: 신규 6개 id·kind·displayName이 스펙 표 그대로, validate 통과, Final은 overtime 함수`(현재 main에서도) |
| AC2 | 통과 (m5-13 시점) | `2042751`에서 `allInfos` 15 / `infos` 6. 현재 main은 m5-14~m5-19가 `inPool`을 풀어서 `infos`가 늘어난 게 정상 — QA `allInfos는 맵 모듈과 1:1(15개, 중복 없음), infos는 inPool ~= false인 것만`으로 규칙 자체를 고정 |
| AC3 | 통과 | `maps.spec` "m5-13 AC3"(개발), 15개 require 모두 통과(중복 id assert 통과) |
| AC4 | 통과 | `maps.spec` "m5-13 AC4", QA `신규 6개는 어떤 조합으로도 강제 플랜이 그 순서대로 돼요`(6³ = 216조합 + 4라운드) |
| AC5 | 통과 | `m5-03-foundation` AC2(1,000회), QA `랜덤 판(2,000번)은 첫 판 Race·마지막 Final·중복 없음, inPool=false 맵은 안 나와요` |
| AC6 | 통과 | 위 표 — 두 커밋 모두 5단계 통과 |
| AC7 | 사용자 확인 필요 | 껍데기는 이미 m5-14~m5-19가 덮어써서 지금 main에서는 "껍데기"로 돌릴 수 없음. 아래 체크리스트는 현재 맵으로 강제 플랜 경로를 확인 |
| AC8 | 사용자 확인 필요 | 로비 변화 없음(코드상 `Maps.infos`만 랜덤 판에 쓰임 — `MatchService` 수정 없음) |

`2042751`의 Final 껍데기 2개(`TugOfWarPlatform`·`ClawMachinePrize`) `overtime`은 `IkuraBombs` 패턴 그대로(`task.delay`를 `ctx.cleanup:add`, 훅은 바로 반환, `ctx.isActive()` 확인 뒤 바닥 `CanCollide=false`·`Transparency=1`)임을 코드로 확인.

## 버그
### [P3] `shared/maps/init.luau` 주석이 아직 "(inPool = false)"
- 재현: `src/shared/maps/init.luau:19-24`를 본다.
- 기대: 풀에 들어간 맵(`bouncy-castle-maze`·`lantern-bridge`·`giant-jenga` 등)은 주석에서 "(inPool = false)"가 빠짐.
- 실제: 6줄 모두 "m5-13 껍데기 → m5-1X (inPool = false)" 그대로. 동작에는 영향 없음(실제 값은 각 모듈).
- 위치: `src/shared/maps/init.luau:19-24` (공용 파일 — 다음에 이 파일을 맡는 스펙에서 정리)

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자 검증 — 이 스펙은 리모트를 만들거나 바꾸지 않음
- [x] 통과·탈락·순위 판정이 서버에만 있다 — 껍데기는 `ctx.pass`/`ctx.eliminate`만 부름
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — 껍데기 6개 모두 상태 없음
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다 — Heartbeat 연결·연장전 `task.delay` 모두 `ctx.cleanup`

## 사용자 Studio 확인 체크리스트
1. `src/shared/Config.luau`의 `Config.DEBUG.forceMapPlan = { "bouncy-castle-maze", "giant-jenga", "lantern-bridge", "tug-of-war-platform" }`로 바꾸고 Play(혼자).
2. 4라운드가 그 순서로 나오고 라운드 소개 이름이 "방방 미로 → 와르르 나무 블록 → 등불 다리 건너기 → 줄다리기 발판"인지 본다.
3. Output에 `[MapTypes]`·`unknown map`·`duplicate map id` 같은 에러가 없는지 본다.
4. `forceMapPlan`을 `nil`로 되돌리고 Play → 로비에 새 버튼·표시가 없는지 본다(AC8).
5. 끝나면 `forceMapPlan = nil`인지 다시 확인(테스트가 커밋 값을 고정한다).

## 추가한 테스트
- `tests/m5-13-qa.spec.luau` (4개): 신규 6개 id·kind·displayName(+rule, 바뀐 jenga 제외)·validate·overtime / `allInfos`↔모듈 1:1·`infos`는 `inPool ~= false`만 / 신규 6개 강제 플랜 216조합+4라운드 / 랜덤 판 2,000번 규칙(첫 Race·끝 Final·중복 없음·껍데기 없음).

## 인계 메모
- 브랜치: `m5-qa-maps-a` (worktree `worktree-agent-a6ab6cbf0bef38302`에서 push)
- 끝난 것: 두 커밋에서 5단계, AC1~AC6 확인, QA 테스트 4개, 리포트, 스펙 `qa-passed`.
- 남은 것: AC7·AC8 Studio 확인(사용자), P3 주석 정리(다음 `maps/init.luau` 담당 스펙).
- 다음 첫 단계: docs-writer가 CHANGELOG 반영 후 `done`.
- 막힌 점: 없음.
