# QA — m6-01 Race 부활 + 부활 카운트다운

- 스펙: `docs/specs/m6-01-race-respawn.md`
- 검증 커밋: `3d50551` (브랜치 `claude/m6-01-07-qa`, main/develop과 같음 — m6-08~12 병합 뒤 상태로 검증)
- 결과: **통과** (P0·P1·P2 없음, P3 1개) — 스펙 상태 **`qa-passed`**. Studio 항목(AC1~AC6)은 **사용자 확인 필요**.

## 자동 검증 (클라우드 세션, 2026-11-12)
| 명령 | 결과 |
|---|---|
| `rojo build` | 통과 (`/tmp`로 출력) |
| `stylua --check src tests tools` | 통과 (새 테스트 포함) |
| `selene src` | Roblox API 덤프를 못 받음(프록시) → **근사 std**(`tools/cloud/selene.toml`)로 0 errors / 0 warnings — Roblox API 검사 없음, 로컬에서 한 번 더 |
| `lune run tests` (전체) | **QA 미실행**(메인 세션이 전체 실행). 개별: `m6-01-race-respawn` 7/0, **새 `m6-01-qa` 11/0**, `m6-02-large-foundation` 11/0, 새 `m6-02-qa` 7/0 |
| `luau-lsp analyze` (새 검사기) | 끝 코드 0, 오류 0 |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 낙하 → 출발점 고정 + 3·2·1 → 바로 달림 | 코드·테스트 통과 / **Studio 사용자 확인 필요** | `RoundService.luau:524-567`(`startRespawn`: `respawning` 표시 → `RespawnAt` → 출발점 `PivotTo` + `Anchored` + `MoveExempt` 4초, 3초 뒤 `standOn`이 고정 해제·`resetMovement`). `RespawnCountdownLogic`: 3→2→1, 0·음수·3 초과 없음(`m6-01-qa` "카운트다운") |
| AC2 리셋 → 같은 카운트다운 뒤 출발점 | 코드 통과 / **Studio 사용자 확인 필요** | `Died` → `queueFall(Reset)` → `startRespawn`(고정 없이 새 캐릭터 대기, `waitForCharacter` 5초) → `standOn`이 새 캐릭터를 옮기고 감시를 새로 닮(`unwatchOf`). 대기 중 또 리셋해도 `respawning`이라 무시(`:414`) |
| AC3 정원 마감 → 부활 대기자 포함 탈락, 카운트다운 사라짐 | 순수 로직 통과 / **Studio 사용자 확인 필요** | `m6-01-race-respawn` "정원이 차는 순간" + `m6-01-qa` "정원 마감: 남은 사람이 모두 부활 대기여도", "시간 종료: 부활 대기자는 출발점 진행도로"(빈 자리 순서·탈락 등수). 속성 지움: `apply`의 `clearRespawn`(`:335`) + cleanup(`:308-312`) |
| AC4 Survival·결승은 낙하 = 탈락 | 순수 로직 통과 / **Studio 사용자 확인 필요** | `m6-01-qa` "부활은 결승이 아닌 Race 방식에서만"(Survival·Final·결승 Race 맵, 소개 전·후 모두 false), `Respawn = false` 경로는 예전 낙하 + 2명 구제 |
| AC5 부활 직후 이동 감시 경고·되돌림 없음 | 코드 통과 / **Studio 사용자 확인 필요** | 부활 대기 중 `placedRoomOf` = nil → 감시 기록 삭제(`MovementGuardService.luau:122-125`), 다시 세울 때 `notifyPlaced` → 새 기록(`:114-117`). `respawning` 표시가 `PivotTo`보다 먼저(`m6-01-qa` 소스 계약) |
| AC6 휴대폰에서 글씨 안 잘림 | **Studio 사용자 확인 필요** | `RespawnCountdown.luau:80-92`(`UiLayout.textSize`로 크기, 패널 폭 `max(360, 부제 × 18)`), gui `ResetOnSpawn = false`(`LobbyController.luau:24`)라 리셋해도 패널이 살아 있음 |

통과(코드·순수 로직) 6 / 실패 0 — Studio 확인 6개 남음.

## m6-08~12와의 상호작용 (이 스펙 뒤에 병합된 기능)
| 대상 | 결과 | 근거 |
|---|---|---|
| 💥 공격(`AttackService`) | 통과 | 공격자·대상 모두 `activeRoomOf`(`AttackService.luau:81,93`) → `activeRacing`이 `not respawning` → 부활 대기자는 쏠 수도 맞을 수도 없음. 넉백 뒤 떨어져 부활하면 `lockMovement`가 `PlatformStand = false`, 넘어짐 해제 타이머는 고정 중이면 손대지 않음(`Knockback.luau` `not root.Anchored`) |
| 🧨 다이너마이트(`DynamiteService`) | 통과 | 레이서 목록이 `activeRoomOf`라 부활 대기자는 줍기·폭발 대상·떨어뜨리기 기준에서 빠짐. 폭발 → `RoundService.sendToStart` → `sendHome`이 `closed`·`round.ended`·`placed`·`respawning`·`pendingIds`·`RoundLogic.respawns`를 모두 보고 `startRespawn(userId, "Fall")`(`RoundService.luau:571-585`, `m6-01-qa`가 조건을 고정). 불붙인 채 부활 대기가 되면 터지지 않고 꺼짐(m6-12 재QA 수정 `3d50551`). 들고만 있던 다이너마이트도 부활 때 없어짐(설계 확인 — 아래 Studio 7번) |
| 잡기(`GrabService`) | 통과 | `activeRoomOf`로 0.1초마다 확인(`GrabService.luau:103-104`) → 부활 대기가 되면 잡기 끝. 용접이 아니라(클라이언트 감속) 같이 끌려가지 않음 |
| 이동 감시 | 통과 | 위 AC5 |
| 관전·보상 | 통과 | 부활 대기자는 `RoundProgress.racerUserIds`에 남음(레이서 수 그대로, 스펙 규칙 4). 보상은 `MatchEvents` 결과만 봐서 영향 없음 |
| 결승 진출 2명 보장 | 통과 | Race 낙하는 부활이라 구제 대상이 안 생김. 퇴장·캐릭터 없음(강제 `Reset`)은 구제 없음, 둘이 같이 나가 혼자 남으면 부전 통과(`m6-01-qa`) — GDD 4.1 메모와 같음 |
| 라운드 끝·취소·방 나감의 고정 해제 | 통과 | 낙하 부활 중 `Anchored = true`인 캐릭터는 통과(`toLobby`), 탈락(`EliminationService` → `toLobby`), 취소(`cancel` → `toLobby`), 방 나감(`MatchService.onMemberLeft` → `toLobby`) 모두 `CharacterUtil.toLobby`가 고정·이동 잠금을 풂(`m6-01-qa` 소스 계약) |

## 버그
### [P3-1] 부활을 기다리는 3초 동안 서버 장착 잠금(`ShopService.isLocked`)이 풀려요
- 재현 (서버 리모트를 직접 부르는 경우 — 일반 화면에서는 탈의실 버튼이 숨어 있어 못 함):
  1. Race에서 떨어지거나 리셋해 카운트다운이 뜬 동안
  2. `EquipSkin`·`DrawTicket`·`EquipFx`(또는 관리자 🛠 미리보기)를 호출
- 기대: 달리는 중(소개 포함)에는 장착·뽑기·연출 장착을 거절(CLAUDE.md "스킨 · 상점 규칙", `ShopService.isLocked` 주석 "이번 라운드 레이서 (소개 중 포함)").
- 실제: `isLocked`는 `RoundService.placedRoomOf`만 보는데(`src/server/ShopService.luau:84-90`), m6-01이 `placedRacing`에서 부활 대기자를 뺐기 때문에(`src/server/RoundService.luau:586-593`, 이동 감시용) 그 3초 동안 `false` → 장착이 받아들여지고 바로 겉모습이 바뀜. 영향은 겉모습뿐(히트박스·속도 같음)이라 P3.
- 고칠 방향: `RoundService`에 "이번 라운드 레이서인가(부활 대기 포함, `RoundLogic.isRacing`)"를 묻는 함수를 하나 더 두고 `ShopService.isLocked`가 그걸 쓰게 하거나, `isLocked`에서 `RespawnAt` 대신 서버 표를 보게. 고친 뒤 `m6-01-qa`에 소스 계약 한 줄 추가 권장.

## 서버 판정 · 보안 체크
- [x] 클라이언트 → 서버 새 리모트 없음(리모트 개수 그대로). `RespawnAt`은 서버만 달고 화면 표시에만 씀(판정·권한에 안 씀 — 서버에서 읽는 곳 없음).
- [x] 부활 여부·순서·탈락·통과 판정은 전부 서버(`RoundLogic.respawns`·`RoundService`). 시간 종료 순위는 부활 대기자를 출발점 진행도로 서버가 계산.
- [x] 부활 상태(`respawning`·`spawnOf`·`unwatchOf`)는 `prepareRound` 지역 상태 — 여러 방이 동시에 돌아도 섞이지 않음.
- [x] 부활 스레드·감시 연결은 `cleanup`에 등록, 라운드가 닫히면 `RespawnAt`을 모두 지움. 닫힌 뒤 깨어난 부활 스레드는 `closed`·`round.ended`를 보고 아무것도 안 함.
- [ ] 장착 잠금이 부활 대기 3초 동안 풀림 — P3-1.

## 사용자 Studio 확인 체크리스트 (`docs/DEV-SETUP.md` 3-16 + 상호작용)
1. **떨어지기 (AC1)**: Play → 첫 Race에서 코스 밖으로 뛰어내림 → 탈락 연출 없이 처음 섰던 출발점에 멈춤, 화면 가운데 "다시 출발까지 / 3 → 2 → 1 / 출발점에서 다시 달려요!" → 패널이 사라지는 순간 걷기·점프 가능.
2. **리셋 (AC2)**: 달리다 Esc → R → 로비에 잠깐 생겼다가 카운트다운 끝에 출발점으로. 카운트다운 중 한 번 더 리셋해도 한 번만 옮겨짐, 패널이 끊기지 않음.
3. **정원 마감 (AC3)**: Test → Clients and Servers 3명. 1명이 떨어져 카운트다운을 보는 동안 2명이 결승선 통과(정원 2) → 카운트다운이 바로 사라지고 탈락 연출 → 관전. 90초 시간 종료도 한 번(더 멀리 간 사람부터 통과).
4. **Survival·결승 (AC4)**: `Config.DEBUG.forceMapPlan = { "hot-plate", "rotating-belt", "skewer-showdown" }` 처럼 Survival을 앞에 두고 떨어짐 → 바로 탈락, 카운트다운 없음. 결승도 같음. 확인 뒤 `nil`로.
5. **이동 감시 (AC5)**: 1·2번 뒤 출력 창에 `[MovementGuard]` 경고·뒤로 튐 없음.
6. **휴대폰 (AC6)**: Device 에뮬레이터 휴대폰 가로·세로에서 패널 글씨가 잘리지 않음, 영어(Player Emulator)는 "Back in" / "Back to the start line!".
7. **다이너마이트와 같이 (m6-12)**: `Config.Dynamite.UniqueChance = 1`(확인 뒤 0.10으로)로 Race → 폭발에 맞으면 출발점에 고정 + 3·2·1(1번과 같은 모습). 다이너마이트를 **들고만 있다가**(점화 전) 떨어지면 다이너마이트가 없어지는데, 이게 괜찮은지(사용자 판단).
8. **공격과 같이 (m6-08)**: 2명 테스트에서 한 명이 카운트다운 중일 때 다른 사람이 F로 공격 → 카운트다운 중인 사람은 맞지 않음(튕김·"@_@" 없음). 공격으로 코스 밖에 떨어진 사람은 부활 뒤 넘어진 채로 남지 않음.
9. **소개 중 리셋**: 라운드 소개(맵 이름 화면) 동안 리셋 → 출발 카운트다운과 부활 카운트다운이 겹쳐 어색하지 않은지, 출발 뒤 잠긴 채 남지 않는지.

## 추가한 테스트
- `tests/m6-01-qa.spec.luau` (11개)
  - 순수: 시간 종료 때 부활 대기자 = 출발점 진행도로 빈 자리 경쟁·탈락 등수 순서, 남은 사람이 전원 부활 대기여도 정원 마감에 끝남, Race 퇴장 2명 동시 → 남은 1명 부전 통과(구제 없음), 1명 퇴장이면 계속, `Respawn = false` 경로의 예전 낙하 + 2명 구제, Survival·Final·결승 Race 맵은 부활 없음
  - 카운트다운: 지연 3초 동안 1~3만, 3·2·1 모두 보임, 숫자 아닌 값 숨김
  - 소스 계약: 부활 대기자는 공격·다이너마이트·잡기 대상 아님(`activeRoomOf`, 세 서비스에 `placedRoomOf` 없음), `sendHome` 조건 7개, `respawning` 표시가 `PivotTo`보다 먼저, `standOn`이 고정 해제·면제·배치 알림·감시, 라운드 끝·취소·방 나감에 `toLobby`가 고정 해제, 카운트다운 문구 ko·en

## 인계 메모
- 브랜치: `claude/m6-01-07-qa` (QA 커밋, push 안 함 — 지시).
- 끝난 것: 코드 리뷰(부활 흐름·m6-08~12 상호작용·보안), 순수/소스 계약 테스트 11개, 리포트, 스펙 `qa-passed`.
- 남은 것: 사용자 Studio 확인 1~9(DEV-SETUP 3-16에 7~9번 추가 권장 — docs-writer). P3-1은 developer가 다음 기회에.
- 다음 첫 단계: 메인 세션이 전체 `lune run tests` 확인 → docs-writer가 DEV-SETUP 3-16에 상호작용 항목 반영.
- 막힌 점: 없음. 클라우드라 `selene`은 근사 std만.
