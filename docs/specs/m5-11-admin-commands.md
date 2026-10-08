status: ready
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-11 — 관리자 명령 확장 (테스트 서버 전용)

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §11.7(테스트 도구 — 관리자 판단은 서버 UserId, 비밀번호 방식 금지, 기록 안 함, "제외: 코인 조작·강제 시작·맵 고르기 같은 다른 관리자 명령(M5 백로그)"), §11.4(판정은 서버), §9.1
- 레퍼런스: [`docs/REFERENCE-final-overtime.md`](../REFERENCE-final-overtime.md) 4절(관리자 권한 관행 — UserId 목록, 클라이언트 불신)
- 담당 개발 worktree: `m5-admin2` (Rojo 포트 34879)
- 공용 파일 수정 담당: 없음 (리모트 `AdminCommand`는 m5-03)
- 의존: **m5-03 머지 후 시작**. 이벤트 재화 명령은 프로필 칸(m5-03)만 쓰고 m5-07 파일은 안 건드려요. 연출 미리보기는 Player 속성(m5-03)만 달아요.
- **이 스펙이 고치는 파일**: `src/server/AdminConfig.luau`, `src/shared/AdminLogic.luau`, `src/server/AdminService.luau`, `src/client/ui/AdminPanel.luau`, `src/client/ui/AdminController.luau`, `src/server/RoomService.luau`(강제 시작 API 하나), `src/server/MatchService.luau`(다음 판 맵 순서 API 하나), 테스트 `tests/admin-logic.spec.luau`(추가)

## 목표
개발자가 혼자 또는 친구 몇 명과 테스트할 때 **"바로 시작", "다음 판 맵 고르기", "코인·이벤트 재화 채우기", "연출 미리보기"**를 관리자 패널 버튼으로 한다. 경제·판정에 영향을 주는 명령은 **Studio에서만**, 실서버는 사용자가 따로 켰을 때만(기본 꺼짐) 된다. 일반 플레이어는 아무것도 못 보고 못 쓴다.

## 규칙
### 권한 등급 (`AdminLogic.commandTier`, `AdminLogic.canRun`)
| 등급 | Studio (관리자) | 실서버 관리자, `AdminConfig.LiveTestCommands = false`(기본) | 실서버 관리자, `LiveTestCommands = true` |
|---|---|---|---|
| **Info** — 결과를 보기만 / 겉모습만 | 됨 | 됨 | 됨 |
| **Test** — 경제·판정에 영향 | 됨 | **안 됨** | 됨 (관리자 **본인** 것만) |
| **StudioOnly** — 되돌리기 어려움 | 됨 | 안 됨 | 안 됨 |
- 관리자 판단은 m5-02 그대로(서버 관리자 표). 관리자가 아니면 모든 명령 거절 + warn 한 번(m5-02와 같음).
- `AdminConfig`에 `LiveTestCommands = false`(새, 주석: "실서버 비공개 테스트 때만 true — 켜 두면 관리자 계정 코인이 실제로 바뀌어요") 추가.

### 명령 (`AdminCommand(command, args)`)
| command | 등급 | args | 하는 일 |
|---|---|---|---|
| `info` | Info | — | 결과 한 줄: 플레이스 역할(Single/Lobby/Match), JobId 앞 8자, 이 서버 방 수·플레이어 수, 내 방 id·상태, 내 코인·이벤트 재화(진행 중 이벤트) |
| `fx` | Info | `slot, fxId?` | **연출 미리보기**: 내 Player 속성 `EliminationFx`/`VictoryFx`를 그 값으로 잠깐 바꿈(저장·소유 안 바뀜, 나가거나 `fx slot off`면 프로필 장착값으로). 라운드 중 거절(장착 잠금과 같게). m5-02 스킨 미리보기와 같은 원칙(겉모습만, 기록 안 함). 상점에서 실제로 입기·벗기(`EquipFx`, m5-08)를 하면 속성이 그 값으로 덮여 미리보기가 끝나요 |
| `start` | Test | — | 내가 있는 방을 **인원 조건 없이 바로 시작**(혼자여도). 매치 중·카운트다운 중이면 거절 |
| `plan` | Test | `{ id1, id2, id3, id4? }` | 내 방의 **다음 매치 한 번만** 이 맵 순서로(`Rules.resolveForcedPlan` + `Maps.allInfos()` 검사, 껍데기·`inPool = false` 맵도 됨). 결승 자리가 Final이 아니면 `Rules.forcedPlanWarning` 문구를 결과에 함께 |
| `coins` | Test | `n` (정수, −10,000 ~ 10,000) | **내** 코인 +n (0 아래로 안 감), 저장 요청 |
| `tokens` | Test | `n` (정수, −500 ~ 500) | **내** 진행 중 이벤트 재화 +n (이벤트가 없으면 거절 "진행 중인 이벤트가 없어요") |
| `resetprofile` | StudioOnly | — | 내 프로필을 새 프로필로(코인·스킨·코드 기록 전부) — 메모리 프로필에서만(Studio + `persistDataInStudio = false`), 저장 켠 Studio에서도 거절 |
- 다른 사람을 대상으로 하는 명령은 **만들지 않아요**(코인 주기·킥·강제 탈락 등) — 악용·실수 범위를 본인으로 한정(결정 기록 D2).
- 서버 검증 순서: 관리자 표 → 요청 간격(`Config.Shop.RequestCooldown`) → command 문자열·args 모양(`AdminLogic.parse`) → 등급(`canRun(tier, isStudio, liveTestCommands, persistInStudio)`) → 실행. 실패 문구는 `AdminLogic.message(reason)`.
- 로그(서버 Output): `[Admin] 이름(UserId) <command> <args> -> ok|<reason>` 모든 명령.
- 서버 API (최소 추가):
  - `RoomService.forceStart(roomId): (boolean, string?)` — 대기 중인 방을 최소 인원 검사 없이 지금과 같은 시작 흐름(카운트다운 → 매치)으로. 한 플레이스 모드·로비 서버(텔레포트 흐름) 모두 기존 시작 경로를 그대로 탐.
  - `MatchService.setNextPlan(roomId, plan: { MapInfo })` — 그 방의 다음 매치 시작 때 한 번 쓰고 지움(`Config.DEBUG.forceMapPlan`보다 우선). 매치 서버로 텔레포트하는 경우(플레이스 분리)는 이번 범위 밖 — 결과 문구 "한 플레이스 모드에서만 돼요"(결정 기록 D3).

### 관리자 패널 (`AdminPanel`/`AdminController`, 관리자에게만 — m5-02 패널에 탭 추가)
- 패널 위쪽에 탭 2개: **"👕 미리보기"**(지금 스킨 16종+ 버튼) / **"🛠 명령"**(새).
- "명령" 탭: `info` 버튼 + 결과 줄, `start` 버튼, 맵 순서 칸(맵 id 버튼 9개를 눌러 순서대로 쌓기 → "다음 판에 쓰기"/"비우기"), 코인 +100 / +1000 / −1000, 재화 +10 / +80, 연출 미리보기(탈락: 기본/고양이, 우승: 기본/불꽃), `resetprofile`(Studio일 때만 보임, 두 번 눌러 확인).
- 클라이언트는 등급을 몰라요: 실서버에서 Test 명령을 누르면 서버가 "테스트 명령이 꺼져 있어요 (AdminConfig.LiveTestCommands)"로 거절하고 결과 줄에 보여요. 버튼은 Studio·실서버 같은 모양(단순하게), `resetprofile`만 Studio에서만 만들어요(`RunService:IsStudio()`).
- 결과 한 줄은 서버가 돌려준 문구.

## 범위
- 포함: 위 명령 7개, 등급, 패널 탭, 로그, 서버 API 두 개.
- 제외: 다른 플레이어 대상 명령, 채팅 명령(`/start` 같은), 그룹 랭크 권한, 서버 전체 공지, 이벤트 시각 바꾸기(Studio `Config.DEBUG.eventNow`로), 라운드 강제 종료·연장전 당기기(`Config.DEBUG.overtimeAt`로), 매치 서버(플레이스 분리)에서 다음 판 맵 고르기.

## 수용 기준
### 순수 로직 (lune 테스트, `tests/admin-logic.spec.luau`)
- [ ] AC1: `commandTier`: info·fx = Info, start·plan·coins·tokens = Test, resetprofile = StudioOnly, 모르는 명령 nil.
- [ ] AC2: `canRun` 표 9칸(등급 3 × 환경 3)이 위 표와 같다. `resetprofile`은 Studio여도 `persistInStudio = true`면 거절.
- [ ] AC3: `parse`: `coins`에 정수 −10,000~10,000만(소수·문자열·범위 밖·nil 거절), `tokens` −500~500, `plan`은 문자열 3~4개 목록만, `fx`는 slot이 Elimination/Victory이고 fxId가 nil·"off"·`FxCatalog`의 그 slot id.
- [ ] AC4: `applyCoins(현재, n)`이 0 아래로 내려가지 않는다(100에서 −1000 → 0).
- [ ] AC5: 기존 m5-02 테스트(`admin-logic`, `m5-02-qa`) 전부 통과.
- [ ] AC6: 검증 5단계 통과.

### Studio 확인 (사용자 확인 필요)
- [ ] AC7: Play Solo → "🛠" 패널에 "👕 미리보기"/"🛠 명령" 탭. `info`를 누르면 "Single · 방 0 · 플레이어 1 …" 같은 한 줄.
- [ ] AC8: 방을 만들고 `start` → 혼자인데도 카운트다운 → 매치 시작(`Config.DEBUG` 수정 없이).
- [ ] AC9: 맵 순서 `dessert-fridge, tempura-pot, ikura-bombs`를 쌓아 "다음 판에 쓰기" → `start` → 그 순서로 돈다. 그다음 판은 다시 랜덤(또는 `DEBUG.forceMapPlan`).
- [ ] AC10: 코인 +1000 → 배지가 바로 오르고 탈의실에서 해금 가능. 이벤트 시각(`DEBUG.eventNow`)이면 재화 +80 → 무료 한정 스킨 받기 가능(m5-07 뒤).
- [ ] AC11: 연출 미리보기 "고양이" → 리셋해서 탈락하면 고양이 손님 연출(m5-09 뒤). 프로필의 `equippedFx`는 바뀌지 않는다.
- [ ] AC12: `resetprofile` 두 번 → 코인 0·계란초밥만. `persistDataInStudio = true`면 거절.
- [ ] AC13: `AdminConfig.StudioAllAdmins = false`로 2명 테스트(m5-02 B5 방식) — 관리자 아닌 사람 화면엔 패널이 없고, 명령줄로 리모트를 직접 불러도 "관리자만 쓸 수 있어요" + 서버 warn. **확인 뒤 true로 되돌리기**.
- [ ] AC14 (실서버, 퍼블리시 뒤 선택): 기본 설정에서 `info`·연출 미리보기는 되고 `coins`·`start`는 "테스트 명령이 꺼져 있어요".

## 공용 파일 변경
- 없음 (`AdminConfig`는 서버 전용 파일이고 이 스펙만 고침)

## 사용자 작업
- 실서버 비공개 테스트에서 Test 명령을 쓸지 결정 → 쓸 때만 `AdminConfig.LiveTestCommands = true`로 퍼블리시, 공개 출시 전에 false (USER-TODO A1 "공개 출시 전에 다시 확인"에 추가).

## 결정 기록
<!-- 날짜 · 질문 · 결정 · 누가 -->
- 2026-10-08 · D1 실서버에서 경제·판정 명령 · **기본 꺼짐**(`LiveTestCommands = false`), 켜도 관리자 본인 것만. 판정에 영향(강제 시작·맵 고르기)·경제(코인·재화)는 Studio 또는 별도 설정에서만 — 사용자 지시 그대로. 근거: 서버 판단·클라이언트 불신, UserId 목록 관행 — REFERENCE-final-overtime 4절 · planner
- 2026-10-08 · D2 다른 사람 대상 명령 없음 · 실수·악용 범위를 줄이고, 혼자·친구 테스트에는 필요 없음(친구에게 코인을 주면 공정성 문제). 그룹 랭크 권한은 게임을 그룹으로 옮길 때 · **기본값, 사용자 수정 가능** · planner
- 2026-10-08 · D3 다음 판 맵 고르기 범위 · 한 플레이스 모드(Studio·PlaceId 없음)만. 플레이스 분리 때 매치 서버로 넘기려면 매니페스트(m4-11)에 칸을 더해야 해서 공용 범위가 커짐 → 후속 · planner
- 2026-10-08 · D4 연출 미리보기를 Info 등급으로 · 스킨 미리보기(m5-02, 실서버에서도 켬)와 같은 성격(겉모습만, 저장 안 함). m5-09 확인에도 필요 · planner
- 2026-10-08 · **사용자 결정: 실서버 테스트 명령 없음(설정으로도 못 켬)** — D1의 `LiveTestCommands`는 만들지 않음. Test·StudioOnly는 `RunService:IsStudio()`일 때만 처리, 실서버 핸들러는 무조건 거절. 틀(`AdminLogic.commandTier`·`canRun(tier, isStudio, persistInStudio)`, AdminService `onCommand` → `runCommand`)은 m5-03이 만들어 둠 · 사용자

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
