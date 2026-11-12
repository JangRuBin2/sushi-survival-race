# QA — m6-02 대형 맵 기반 (방 32·40명, 인원 맞춤 판 계획)

- 스펙: `docs/specs/m6-02-large-map-foundation.md`
- 검증 커밋: `3d50551` (브랜치 `claude/m6-01-07-qa`, main/develop과 같음 — m6-03~07 맵과 m6-08~12가 들어간 상태)
- 결과: **통과** (P0·P1·P2 없음, P3 2개) — 스펙 상태 **`qa-passed`**. AC1(화면)은 **사용자 확인 필요**.
- 범위: 기반(Config·Rules·MapTypes·Maps 풀 정보·PlacePayload·예산·방 인원 검증)만. 맵 5개(m6-03~07)는 다른 QA가 따로 봄.

## 자동 검증 (클라우드 세션, 2026-11-12)
| 명령 | 결과 |
|---|---|
| `rojo build` | 통과 (`/tmp`로 출력) |
| `stylua --check src tests tools` | 통과 (새 테스트 포함) |
| `selene src` | Roblox API 덤프를 못 받음(프록시) → **근사 std**로 0 errors / 0 warnings — Roblox API 검사 없음, 로컬에서 한 번 더 |
| `lune run tests` (전체) | **QA 미실행**(메인 세션이 전체 실행). 개별: `m6-02-large-foundation` 11/0, **새 `m6-02-qa` 7/0** |
| `luau-lsp analyze` (새 검사기) | 끝 코드 0, 오류 0 |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 방 만들기 32·40 버튼, 휴대폰에서 안 잘림 | **Studio 사용자 확인 필요** | `LobbyScreen.luau:222-237`(옵션 7개 버튼), `:444-447`(`UiLayout.gridRows`로 줄바꿈, 줄 수만큼 높이) |
| AC2 40명 → 1R 대형 Race, 40 → 24 → 11 → 4 | 통과 | `m6-02-large-foundation` "통과 인원"·"buildRoundPlan: 25~40명" + `m6-02-qa` "실제 풀 판 계획"(실제 26개 풀, 4~40명 × 시드 80: 25명 이상이면 1R은 언제나 capacity 40 Race) |
| AC3 예상 11명 이하 라운드엔 대형 맵 없음, 24명 방 1·2R엔 나올 수 있음 | 통과 | `m6-02-large-foundation` + `m6-02-qa`(실제 풀에서 대형 맵이 나오면 그 라운드 예상 인원 ≥ 12, 시작 12명 미만 판엔 대형 맵 0) |
| AC4 기존 맵 21개 스폰 24개 그대로 | 통과 | **새** `m6-02-qa` "26개 맵을 실제로 지으면 Spawns 수 = capacity"(렌더러 가짜 환경으로 26개 모두 `build` → 기존 21개 24, 대형 5개 40). 전에는 맵 묶음별 테스트만 있었고 전체를 한 번에 세는 테스트가 없었음 |
| AC5 40명 텔레포트 매니페스트 | 통과 | `m6-02-qa` "텔레포트 매니페스트"(40/40·32/32 통과, 32방 33명·41명 거절), `MAX_MEMBERS` = 옵션 끝(기존 테스트) |

통과 4 / 실패 0 — Studio 확인 1개 남음.

## 추가로 확인한 것
- **2라운드부터는 기존 맵이 언제나 받음**: 시작 4~40명 × 가운데 Race/Survival 모든 조합에서 2라운드 이후 최대 인원(`upper`) ≤ 24, 예상 ≥ 2(`m6-02-qa`). 대형 맵 풀이 비거나 다 써도 인원 때문에 막히는 라운드가 없음. 1라운드(25명 이상)만 대형 Race 3개에 기대고, 그 셋은 1R에서 처음 고르니 늘 남아 있음.
- **통과 비율 경계**: 24명 판 0.65(24 → 16), 25명 판 0.60(25 → 15). 비율은 판을 시작한 인원으로 고르고 계산은 출발 때 살아 있는 인원(이탈 반영 — 40명 판 2R에 20명이면 9). 25~40명 × 1~3라운드 × 살아 있는 3~시작 인원 모두 2 ≤ 통과 ≤ 남은 인원 − 1.
- **`MatchService`가 `startCount`를 판 계획·통과 인원 둘 다에 넘김**(`MatchService.luau:268,337`, 기존 테스트가 고정).
- **방 인원 검증(클라이언트가 못 고르는 값)**: `RoomLogic.validateSettings`·`PlacePayload.validateSettings`가 `table.find(MaxPlayerOptions)` 정확히 일치만 받음 — 33·41·48·50·0·−40·39.5·NaN·inf·문자열·불리언 모두 거절(`m6-02-qa`). 방 설정을 바꾸는 다른 리모트는 없음.
- **예산**: `MapKitLogic.BUDGETS.Large` 값과 `MapKit` 런타임 경고가 Large 기준(기존 테스트). 기존 맵의 맵별 예산은 맵 테스트가 계속 검사.
- **DEBUG 커밋 값**: `Config.DEBUG` 전부 기본값(`minPlayersToStart = 1`, `forceMapPlan(s) = nil`, `persistDataInStudio`·`simulateMatchServer`·`logArenaStats`·`fakeRobuxInStudio`·`fakeVipInStudio = false`, `overtimeAt`·`eventNow = nil`, `unlockAllSkinsInStudio = true`), `AdminConfig` `StudioAllAdmins = true`·`LiveEnabled = true`.
- **40명 방과 다른 기능**: 잡기·공격·다이너마이트·이동 감시는 방마다 레이서를 다 도는 단순 반복이라 40명도 0.1초 틱에서 문제 될 양이 아님(잡기 후보 40 × 40). 공격 대상 수 상한은 없음(반지름 10 안 전부) — 출발 직후 몰린 40명에서 한 번에 여럿이 튕길 수 있음. 플레이테스트 확인 항목(아래 Studio 5번).

## 버그
### [P3-1] 디버그·관리자 강제 플랜은 맵 인원을 보지 않아요
- 재현: `Config.DEBUG.forceMapPlan = { "rotating-belt", ... }`(또는 관리자 `plan` 명령)으로 25명 이상 판을 시작.
- 기대: 스폰이 모자라면 경고 한 줄 정도.
- 실제: 강제 플랜은 `Rules.resolveForcedPlan` 그대로 쓰고(`src/server/MatchService.luau:251-263`), 스폰 24개를 돌려 써서(`src/server/RoundService.luau:594-597` `% #spawns`) 두 사람이 한 스폰에 섬. 디버그 전용이라 P3.
- 고칠 방향: `Rules.forcedPlanWarning`처럼 시작 인원 > `Rules.capacityOf(plan[1])`이면 경고 문구를 돌려주는 순수 함수 하나.

### [P3-2] 다이너마이트 방 상한이 방 크기와 상관없이 2개예요 (튜닝 메모)
- `Config.Dynamite.MaxPerRoom = 2`(`src/shared/Config.luau:141`), `Interval` 18초 — 40명 대형 Race에서는 4명 방과 같은 개수라 거의 안 보일 수 있음. 버그가 아니라 플레이테스트 조정 항목(사용자 결정). 공격 대상 수 상한 없음도 같은 성격.

## 서버 판정 · 보안 체크
- [x] 방 최대 인원은 서버가 정해진 옵션 7개만 받음(`RoomLogic.luau:152-154`, 매치 플레이스 매니페스트는 `PlacePayload.luau:108`), 매니페스트 멤버 ≤ `maxPlayers` ≤ 40.
- [x] 판 계획·통과 인원은 서버(`MatchService` + 순수 `Rules`). 클라이언트 입력 없음.
- [x] 맵 정보는 모듈 상수(`capacity`·`minPlayers`) → `MapTypes.validate`가 양의 정수·`minPlayers ≤ capacity` 검사. 라운드 상태 변화 없음.
- [x] 새 연결·스레드 없음(정리 대상 없음).

## 사용자 Studio 확인 체크리스트 (`docs/DEV-SETUP.md` 3-17 1·2번 + 추가)
1. **방 만들기 (AC1)**: 로비 → 방 만들기 → 최대 인원 4·8·12·16·24·**32·40** 7개가 보임. Device 에뮬레이터 휴대폰 가로에서 버튼이 두 줄로 줄바꿈되고 잘리지 않음, 32·40을 눌러 선택 표시가 바뀜. 패드(Xbox 에뮬레이션)로 방향키 이동이 두 줄 사이를 오감.
2. **만든 방**: 40으로 만든 방의 대기실·로비 방 목록에 "1/40"처럼 보임.
3. **작은 판에 대형 맵 없음**: `forceMapPlan = nil`, 혼자(또는 Clients and Servers 2~4명)로 3판 → 대형 맵(초밥집 카운터·도시락 뚜껑·팬트리 선반·회전 원판·연회상) 안 나옴.
4. **긴 목록**: 대기실·순위표·관전 목록이 많은 줄에서 스크롤됨(Clients and Servers 최대 인원으로 확인, 40명 실제는 비공개 테스트).
5. **40명 혼잡(비공개 테스트)**: 1라운드 대형 Race 출발 몰림, 💥 공격 한 번에 여러 명이 튕기는 빈도, 다이너마이트 라운드에서 아이템이 너무 드문지(P3-2), 서버 프레임.
6. **Creator Hub 서버 최대 인원**: 분리 모드면 Match 40·Lobby 50, 한 플레이스 모드면 50(`docs/USER-TODO.md` C2 아래 "서버 최대 인원").

## 추가한 테스트
- `tests/m6-02-qa.spec.luau` (7개)
  - 실제 풀 구성(대형 Race 3·Survival 2, capacity 40·minPlayers 12, 나머지 비어 있음, 26개)
  - 실제 풀 판 계획: 4~40명 × 시드 80 — 1R Race·마지막 Final·가운데 Race/Survival·중복 없음·4라운드 Survival ≥ 1·스폰 ≥ 최대 인원·대형 맵은 예상 ≥ 12·25명 이상 1R 대형·12명 미만 판 대형 없음
  - 2라운드부터 최대 인원 ≤ 24 (모든 종류 조합)
  - 통과 인원 경계(24 ↔ 25 비율 전환, 이탈 반영, clamp)
  - 방 인원 검증(RoomLogic·PlacePayload, 잘못된 값 11종)
  - 40명 매니페스트(40/40·32/32 통과, 33/32·41명 거절)
  - 26개 맵 실제 build → Spawns 수 = capacity

## 인계 메모
- 브랜치: `claude/m6-01-07-qa` (QA 커밋, push 안 함 — 지시).
- 끝난 것: 기반 코드 리뷰, 순수 로직·실제 build 테스트 7개, 리포트, 스펙 `qa-passed`.
- 남은 것: 사용자 Studio 확인 1~4, 비공개 테스트 5, Creator Hub 설정 6. 맵 5개 QA(m6-03~07)는 다른 QA 세션.
- 다음 첫 단계: 메인 세션이 전체 `lune run tests` 확인(새 `m6-02-qa`는 맵 26개를 지어 약 3초).
- 막힌 점: 없음. 클라우드라 `selene`은 근사 std만.
