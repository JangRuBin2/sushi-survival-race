# 사용자가 직접 할 일 (USER-TODO)

에이전트가 할 수 없는 일만 모았어요. 개발은 이 일들이 없어도 대체값(메모리 저장, 한 플레이스 모드, 가짜 결제)으로 계속 진행돼요.
실제 서버에서만 확인되는 항목이 이 일들 뒤로 미뤄질 뿐이에요.

> 마지막 갱신: 2026-10-08 (M4 개발 완료 — m4-01~m4-14 전부 QA 통과·문서 반영(`done`). 이제 이 목록이 다음 단계예요. 기획서는 GDD v0.4)
> 끝낸 항목은 `- [x]`로 바꾸고, 결과·결정은 맨 아래 "답변 기록"에 적어 주세요. 에이전트가 그걸 읽고 반영해요.

---

## A. 지금 바로 (Studio 없이, 웹·문서만으로 가능)

### A1. 기본값 확인·결정 (문서 읽기)
에이전트가 임시로 정한 수치·규칙이에요. 그대로 둬도 되고, 바꿀 것만 "답변 기록"에 적으면 돼요.

- [ ] **M3 기본값** — 읽을 곳: [`docs/CHANGELOG.md`](CHANGELOG.md) M3 절의 수치 표, 자세한 근거는 [`docs/REFERENCE-party-royale.md`](REFERENCE-party-royale.md) §7
  - 우승 단계 10초, 다이브(쿨다운 1.5초·경직 0.5초·속도 40/16), 잡기(거리 5·2초·×0.5/×0.7), 탈락 연출 3초 등
  - **결승 마지막 탈락 뒤 3초 대기** — QA가 "꼭 필요하진 않다"고 정정한 항목이에요. 빼면 한 판이 3초 짧아져요. (유지/삭제)
  - 아바타 외형을 불러오지 않음(모두 같은 계란초밥) — 유지/변경
- [ ] **M4 기본값** — 읽을 곳: [`docs/planner/m4-plan.md`](planner/m4-plan.md) "기본값 결정"
  - 새 맵 2개 규칙·수치: [`docs/specs/m4-04-map-ramen-rapids.md`](specs/m4-04-map-ramen-rapids.md), [`docs/specs/m4-05-map-chef-board.md`](specs/m4-05-map-chef-board.md)
  - 하루 첫 판 보너스 기준 **UTC**(한국 오전 9시 초기화) — 유지/한국 시간으로
  - 코인: 라운드 통과 +10, 결승 출발 +30, 우승 +100, 하루 첫 판 +50 — [`docs/specs/m4-08-rewards-titles.md`](specs/m4-08-rewards-titles.md)
  - 매치 서버: 도착하면 바로 시작, 20초 안에 2명 미만이면 취소 — [`docs/specs/m4-11-place-split.md`](specs/m4-11-place-split.md)
  - 정원이 찬 방이 매치에서 돌아오면 10초 뒤 자동 출발 — 유지/끄기 ([`docs/qa/m4-11-place-split.md`](qa/m4-11-place-split.md) R6)
  - M4 로벅스 판매는 스킨 15개만(VIP·번들은 M5) — [`docs/specs/m4-14-robux-shop.md`](specs/m4-14-robux-shop.md)
  - **확정됨 (2026-10-08)**: 스킨 가격 **A안** — 로벅스 일반 29 / 레어 59 / 에픽 99 / 전설 199, 코인 일반 300 / 레어 900, 에픽·전설은 로벅스만 (GDD v0.4 §9.2, 근거 [`docs/REFERENCE-roblox-monetization.md`](REFERENCE-roblox-monetization.md) 7절)
  - **확정됨 (2026-10-08)**: 코인을 로벅스로 파는 상품은 만들지 않음
- [ ] **Survival 탈락 0명 허용 여부** — Survival 라운드에서 시간이 끝날 때까지 아무도 안 떨어지면 탈락 0명(전원 통과)이 될 수 있어요. **지금 구현은 허용**. 유지/막기 — 읽을 곳: [`docs/GDD.md`](GDD.md) §4.1, [`docs/specs/m2-05-match-flow.md`](specs/m2-05-match-flow.md) Q7
- [ ] **출시 방식 결정** — 한 플레이스 모드(로비와 매치가 한 서버, C2 불필요)로 먼저 낼지, 로비/매치 분리(C2 필요)로 낼지. 소리(A2)가 아직 없으면 무음 상태로 비공개 테스트를 시작해도 되는지.
- [ ] **이동 감시(치트 방지) 결정 2개** — 읽을 곳: [`docs/qa/m4-10-movement-guard.md`](qa/m4-10-movement-guard.md) "남은 버그" R1·R2
  - 걸리면 킥 없이 제자리로 되돌리기만 — 유지/킥 추가
  - 복제 지연 허용 0.5초 — 유지/0.75초(정상 플레이어 오탐↓, 치트 허용↑)
  - 속도 상한 약 110 studs/s — 유지/60(치트 잘 잡힘, 지연 시 오탐↑)

### A2. 소리 고르기 (브라우저로 Creator Store)
<https://create.roblox.com/store/audio> 에서 골라 **에셋 id**만 적어 주세요. 넣는 건 에이전트가 해요.
지금은 아래가 무음이에요 (`src/shared/SfxLibrary.luau`에서 `sfx(nil, …)` / `music(nil, …)`인 것).

- [ ] 배경음 4곡: `Lobby`(로비·대기실), `Round`(라운드), `Final`(결승), `Victory`(우승)
- [ ] 효과음 8개: `VictoryFanfare`(우승 팡파르), `SpeechPop`(말풍선), `ChefHand`(셰프 손 등장), `FishClap`(물고기 박수), `GrabStart`(잡기 시작), `ChopstickWarn`(젓가락 경고), `HotTileSizzle`(철판 지글), `ChefHandWarn`(셰프 손 경고)
- 반복 재생이 자연스러운 곡(루프), 저작권이 Roblox 라이선스인 것만 고르세요.

### A3. 출시 준비물 (m4-12 체크리스트에 들어갈 것)
- [ ] 게임 이름·한 줄 설명·긴 설명 (README 첫 줄 참고: "먹히기 전에 탈출하라!")
- [ ] 아이콘(512×512)·썸네일(1920×1080) 이미지 또는 컨셉 — GDD §13: "먹히는 초밥"을 전면에
- [ ] (선택) 맵·로비 컨셉 이미지 — 에이전트가 코드 장식에 참고해요

---

## B. 집에서 (Roblox Studio 필요)

### B1. 코드 받기·연결 (매번)
```powershell
cd C:\Users\inter\sushi-survival-race   # 저장소 폴더
git pull origin main
rojo serve                              # Studio의 Rojo 플러그인 → Connect
```
처음이라면 [`docs/DEV-SETUP.md`](DEV-SETUP.md) 1절(설치), 3-1(연결), 3-3(여러 명 테스트).
M4-12부터 타입 검사 도구(luau-lsp)가 추가됐어요. pull 뒤 처음 한 번 `rokit install`을 다시 실행하세요.

### B2. M3 확인 (캐릭터·연출·다이브/잡기·소리)
- [ ] [`docs/DEV-SETUP.md`](DEV-SETUP.md) **3-8** 체크리스트 A~N
  - 특히: 잡혔을 때 절반 속도로 계속 움직이는지, 이름표가 하나만 보이는지, 다이브 자세, 음소거 버튼이 위쪽 바에서 겹치지 않는지, 휴대폰 가로에서 "출발!"이 배너를 가리지 않는지
- 맵 순서 고정: `src/shared/Config.luau`의 `DEBUG.forceMapPlan`에 맵 id 3~4개 → 확인 후 **반드시 `nil`로 되돌리기**

### B3. M4 확인 (기능별 QA 리포트의 "사용자 Studio 확인 체크리스트" 절)
- [ ] [`docs/DEV-SETUP.md`](DEV-SETUP.md) **3-9** A~O에 기능별로 모아 두었어요(QA 뒤 고쳐진 것·확정 가격 반영, 디버그 설정 표와 되돌리기 포함). 원본은 아래 QA 리포트예요.

| 기능 | 읽을 파일 | 사용자 작업 먼저? |
|---|---|---|
| 기반(새 맵 빈 틀, 가로 고정) | [`docs/qa/m4-01-foundation.md`](qa/m4-01-foundation.md) | 아니요 |
| 회전 벨트·간장 늪 아트 (+ 스폰 버그 수정) | [`docs/qa/m4-02-art-race-maps.md`](qa/m4-02-art-race-maps.md) | 아니요 |
| 철판·꼬치 쇼다운 아트 | [`docs/qa/m4-03-art-survival-final-maps.md`](qa/m4-03-art-survival-final-maps.md) | 아니요 |
| 새 맵 라멘 국물 급류 | [`docs/qa/m4-04-map-ramen-rapids.md`](qa/m4-04-map-ramen-rapids.md) | 아니요 |
| 새 맵 셰프의 도마 | [`docs/qa/m4-05-map-chef-board.md`](qa/m4-05-map-chef-board.md) | 아니요 |
| 로비·우승자 단상 | [`docs/qa/m4-06-lobby-art-podium.md`](qa/m4-06-lobby-art-podium.md) | 아니요 |
| 저장(DataStore) | [`docs/qa/m4-07-data-persistence.md`](qa/m4-07-data-persistence.md) | 체크리스트 1만 아니요, 나머지는 **C1 먼저** |
| 코인·칭호 | [`docs/qa/m4-08-rewards-titles.md`](qa/m4-08-rewards-titles.md) | 재접속 유지(AC11)만 C1 먼저 |
| 모바일 UI | [`docs/qa/m4-09-mobile-ui.md`](qa/m4-09-mobile-ui.md) | 실제 휴대폰(AC9)은 C1 먼저 |
| 이동 감시 | [`docs/qa/m4-10-movement-guard.md`](qa/m4-10-movement-guard.md) | 아니요 |
| 플레이스 분리 | [`docs/qa/m4-11-place-split.md`](qa/m4-11-place-split.md) | Studio 흉내(`DEBUG.simulateMatchServer`)는 아니요, 실제 서버는 **C2 먼저** |
| 출시 점검 (연속 5판·잡기 입력·다이브 지름길·8명 부하·P3 눈 확인) | [`docs/qa/m4-12-release-hardening.md`](qa/m4-12-release-hardening.md) | 아니요 (`DEBUG.forceMapPlans`·`logArenaStats` 사용 후 되돌리기). 서버 종료 확인(7)만 C1 먼저 |
| 스킨·탈의실·코인 해금 | [`docs/qa/m4-13-skins-closet.md`](qa/m4-13-skins-closet.md) (가격은 A안: 일반 🍚300, 레어 🍚900 — 리포트의 500은 옛 값) | 아니요. 저장 유지 확인만 C1 먼저 |
| 로벅스 상점 | [`docs/qa/m4-14-robux-shop.md`](qa/m4-14-robux-shop.md) (가격은 A안 — 리포트의 R$ 49/99는 옛 값) | 가짜 결제(`DEBUG.fakeRobuxInStudio`)는 아니요, 실제 결제 창은 **C1 + C3 먼저**, 실서버 구매는 퍼블리시 후 |

공통: 다인원은 Studio **Test → Clients and Servers**, 휴대폰은 **Test → Device** 에뮬레이터. 디버그 설정(`forceMapPlan`, `forceMapPlans`, `persistDataInStudio`, `simulateMatchServer`, `logArenaStats`, `fakeRobuxInStudio`)은 확인 후 원래 값(`nil`/`false`)으로 되돌리고 커밋하지 마세요.

---

## C. 퍼블리시·대시보드 (Studio + Creator Dashboard)

순서대로 하면 돼요. 끝나면 알려 주는 값(굵게)을 "답변 기록"에 적어 주세요.

- [ ] **C1. 게임 퍼블리시 + API 접근** (저장 확인에 필요, m4-07)
  1. Studio에서 File → Publish to Roblox (지금 플레이스가 **로비 = 시작 플레이스**)
  2. Game Settings → Security → **Enable Studio Access to API Services** 켜기
  3. 저장을 Studio에서 확인할 때만 `Config.DEBUG.persistDataInStudio = true` → 확인 후 `false`
- [ ] **C2. Match 플레이스 만들기** (m4-11)
  1. Creator Dashboard → 이 게임 → Places → 새 플레이스 "Match"
  2. 같은 rojo 빌드를 그 플레이스에도 퍼블리시 (코드가 바뀔 때마다 **두 플레이스 모두** 다시 퍼블리시)
  3. 최대 인원: Match 24, Lobby 40
  4. **로비 PlaceId, 매치 PlaceId** 알려 주기 → 에이전트가 `Config.Places`에 넣어요
- [ ] **C3. 개발자 상품 15개** (m4-14, 맨 마지막)
  - Creator Dashboard → 이 게임 → Monetization → Developer Products
  - 이름·가격은 아래 표 (계란초밥은 무료라 제외). 아이콘은 탈의실 미리보기 스크린샷이면 충분
  - 만든 뒤 **상품 id 15개** 알려 주기 → `src/shared/Skins.luau`의 각 스킨 `productId = <id>,` (직접 넣어도 됨)

    | 스킨 id | 상품 이름 | 가격(R$) |
    |---|---|---|
    | salmon | 연어 | 29 |
    | tuna | 참치 | 29 |
    | shrimp | 새우 | 29 |
    | inari | 유부 | 29 |
    | kappa-maki | 오이마키 | 29 |
    | eel | 장어 | 59 |
    | uni | 성게 | 59 |
    | ikura | 연어알 군함 | 59 |
    | octopus | 문어 | 59 |
    | rainbow-roll | 무지개 롤 | 99 |
    | aburi-salmon | 불꽃 연어 | 99 |
    | california-roll | 아보카도 캘리포니아롤 | 99 |
    | golden-otoro | 황금 참치 뱃살 | 199 |
    | diamond-uni | 다이아 성게 | 199 |
    | dragon-roll | 용 롤 | 199 |
  - 그다음 Studio 테스트 구매 확인: [`docs/specs/m4-14-robux-shop.md`](specs/m4-14-robux-shop.md) 개발 메모 AC7
- [ ] **C4. 출시 설정** (m4-12) — 전체 체크리스트와 대응표: [`docs/specs/m4-12-release-hardening.md`](specs/m4-12-release-hardening.md) 개발 메모
  - 경험 설문(연령 등급), 공개 범위(비공개 테스트 → 공개)
  - 지원 기기: PC·휴대폰·태블릿 켬, **콘솔 끔** (콘솔 UI는 M5)
  - 서버 최대 인원: Lobby 40 / Match 24 (C2를 안 했으면 한 플레이스 모드라 40)
  - 개인정보 삭제 요청(Right to Erasure)이 오면 두 곳을 지워요. MemoryStore는 곧 만료되니 따로 지울 것 없음.
    1. `PlayerData_v1`: Creator Dashboard → Data Stores에서 키 `u_<UserId>` 삭제
    2. `Purchases_v1`(로벅스 구매 기록): 키가 PurchaseId라 UserId로 바로 찾을 수 없어요. 각 기록에 UserId 메타데이터가 붙어 있으니, Studio Command Bar(퍼블리시된 게임, API 접근 켬)에서 `ListKeysAsync`로 키를 돌며 `GetAsync`의 `KeyInfo:GetUserIds()`에 그 UserId가 있는 키를 `RemoveAsync`로 지워요. 요청이 오면 에이전트에게 스크립트를 달라고 하면 돼요.

---

## D. 사람 모아서

- [ ] **친구 테스트 (4명 이상, 3판 이상)** — 양식: [`docs/DEV-SETUP.md`](DEV-SETUP.md) 3-8 "N. 친구 테스트", 결과는 [`docs/playtest/m3.md`](playtest/m3.md)에 판마다 한 줄
- [ ] **실제 휴대폰 테스트** — [`docs/qa/m4-09-mobile-ui.md`](qa/m4-09-mobile-ui.md) AC9
- [ ] **실서버 다인원** — 플레이스 분리(m4-11) AC9~AC13, 저장 두 서버(m4-07 AC10)
- [ ] **비공개 테스트** — 4명 이상 × 5판 이상, 결과는 [`docs/playtest/m4.md`](playtest/m4.md)
  - 먼저 할 것: B2·B3 Studio 확인, C1(분리로 낸다면 C2도)
  - 접근 제한: Creator Dashboard → 이 게임 → **Configure → Access**(또는 Settings → Permissions)에서 비공개(Private) 유지, 테스트할 친구를 Collaborators/허용 목록에 추가. 메뉴 이름은 대시보드 버전에 따라 조금 달라요.

---

## 답변 기록
날짜와 함께 아래에 적어 주세요. 에이전트가 반영하면 "반영됨"을 붙여요.

```
(예) 2026-10-09: 하루 첫 판 기준 한국 시간으로. 결승 3초 대기 삭제. Lobby 음악 id 1234567890.
```
