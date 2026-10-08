# 사용자가 직접 할 일 (USER-TODO)

에이전트가 할 수 없는 일만 모았어요. 개발은 이 일들이 없어도 대체값(메모리 저장, 한 플레이스 모드, 가짜 결제)으로 계속 진행돼요.
실제 서버에서만 확인되는 항목이 이 일들 뒤로 미뤄질 뿐이에요.

> 마지막 갱신: 2026-10-08 (M4 진행 중 — m4-01~10 병합, m4-11 QA 중, m4-12~14 남음)
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
  - M4 로벅스 판매는 스킨 15개만(VIP·번들은 M5) — [`docs/specs/m4-14-robux-shop.md`](specs/m4-14-robux-shop.md)
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

### B2. M3 확인 (캐릭터·연출·다이브/잡기·소리)
- [ ] [`docs/DEV-SETUP.md`](DEV-SETUP.md) **3-8** 체크리스트 A~N
  - 특히: 잡혔을 때 절반 속도로 계속 움직이는지, 이름표가 하나만 보이는지, 다이브 자세, 음소거 버튼이 위쪽 바에서 겹치지 않는지, 휴대폰 가로에서 "출발!"이 배너를 가리지 않는지
- 맵 순서 고정: `src/shared/Config.luau`의 `DEBUG.forceMapPlan`에 맵 id 3~4개 → 확인 후 **반드시 `nil`로 되돌리기**

### B3. M4 확인 (기능별 QA 리포트의 "사용자 Studio 확인 체크리스트" 절)
DEV-SETUP에는 M4 절이 아직 없어요(M4가 끝나면 docs-writer가 3-9로 모아요). 그 전까지는 QA 리포트를 보면 돼요.

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
| 플레이스 분리 | `docs/qa/m4-11-place-split.md` (QA 중) · 지금은 [`docs/specs/m4-11-place-split.md`](specs/m4-11-place-split.md) 개발 메모 | Studio 흉내(`DEBUG.simulateMatchServer`)는 아니요, 실제 서버는 **C2 먼저** |

공통: 다인원은 Studio **Test → Clients and Servers**, 휴대폰은 **Test → Device** 에뮬레이터. 디버그 설정(`forceMapPlan`, `persistDataInStudio`, `simulateMatchServer`)은 확인 후 원래 값(`nil`/`false`)으로 되돌리고 커밋하지 마세요.

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
  - 스킨 목록·가격은 m4-13/14가 끝나면 이 문서에 표로 추가할게요 → **상품 id 15개** 알려 주기
- [ ] **C4. 출시 설정** (m4-12)
  - 경험 설문(연령 등급), 지원 기기, 서버 최대 인원, 공개 범위(비공개 테스트 → 공개)
  - 개인정보 삭제 요청 처리 절차(Right to Erasure) — m4-12 체크리스트에 방법이 들어가요

---

## D. 사람 모아서

- [ ] **친구 테스트 (4명 이상, 3판 이상)** — 양식: [`docs/DEV-SETUP.md`](DEV-SETUP.md) 3-8 "N. 친구 테스트", 결과는 [`docs/playtest/m3.md`](playtest/m3.md)에 판마다 한 줄
- [ ] **실제 휴대폰 테스트** — [`docs/qa/m4-09-mobile-ui.md`](qa/m4-09-mobile-ui.md) AC9
- [ ] **실서버 다인원** — 플레이스 분리(m4-11) AC9~AC13, 저장 두 서버(m4-07 AC10)

---

## 답변 기록
날짜와 함께 아래에 적어 주세요. 에이전트가 반영하면 "반영됨"을 붙여요.

```
(예) 2026-10-09: 하루 첫 판 기준 한국 시간으로. 결승 3초 대기 삭제. Lobby 음악 id 1234567890.
```
