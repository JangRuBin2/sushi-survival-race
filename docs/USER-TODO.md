# 사용자가 직접 할 일 (USER-TODO)

에이전트가 할 수 없는 일만 모았어요. 개발은 이 일들이 없어도 대체값(메모리 저장, 한 플레이스 모드, 가짜 결제)으로 계속 진행돼요.
실제 서버에서만 확인되는 항목이 이 일들 뒤로 미뤄질 뿐이에요.

> 마지막 갱신: 2026-10-13 (M5 반영 — m5-01~m5-11, m5-13~m5-22 `done`: 새 맵 9개, 시즌 이벤트, 🎁 상점·VIP, 연출 팩, 🎟 코드, 관리자 명령, 스킨 31종. m5-23 맵 비주얼 키트는 재QA 대기, m5-24 아트 패스 진행 중. 기획서 GDD v0.6 변경 이력)
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
- [ ] **M5 기본값** — 읽을 곳: [`docs/CHANGELOG.md`](CHANGELOG.md) M5 절, [`docs/planner/m5-plan.md`](planner/m5-plan.md)
  - 결승 연장전 수치: 90초에 시작, 20초 동안 접시 붕괴, 꼬치 190/150°/s — 플레이테스트 뒤 조정 ([`docs/specs/m5-01-final-overtime.md`](specs/m5-01-final-overtime.md))
  - **확정됨 (2026-10-08, 위임)**: 150초 안전 상한 판정은 **가장 높이 있는 1명 우승** (공동 우승·무승부 안 함)
  - **확정됨 (2026-10-08, 위임)**: 관리자 기능 실서버에서도 **켜 둠** (`src/server/AdminConfig.luau`의 `LiveEnabled = true`). 관리자 판단은 계정(UserId)으로만 — 비밀번호 방식은 보안상 거절됨
  - [ ] **공개 출시 전에 다시 확인**: 관리자 미리보기를 실서버에서 유지할지, 끌지(`LiveEnabled = false`). 켜 두면 관리자가 안 산 스킨을 입은 모습이 다른 사람에게 보여요(능력치 영향 없음)
  - 새 맵 9개 수치, 이벤트 재화(판 참가 1·라운드 통과 1·결승 출발 2·우승 5·오늘 첫 판 3, 교환 80), 시즌 기간(할로윈 10-16~11-05, 크리스마스 12-11~01-07), 특별 상품 가격(스타터 팩 79·에픽 세트 249·전설 세트 499·연출 59/99·VIP 149) — 읽을 곳: [`docs/CHANGELOG.md`](CHANGELOG.md) M5 "기본값으로 정한 주요 수치". 스타터 팩 조건·지역 가격은 [`docs/specs/m5-08-offers-shop.md`](specs/m5-08-offers-shop.md) "사용자 작업"
  - **확정됨 (2026-10-13)**: 디저트 냉장고 C 구간 폭 30, 튀김 냄비 나선 배치 그대로, 맵 아트 Extended 예산(장식 1500) 허용, 맵 세부 판단은 메인 세션에 위임, 저장을 켠 Studio에서 관리자 경제 명령(코인·재화) 막기 — 아래 "답변 기록"
  - 플레이테스트 뒤 정할 것(Studio·친구 테스트 결과로): 줄다리기 발판이 30°에서 미끄러지는지(안 미끄러지면 각도·마찰 조정), 캣타워 넉백 세기, 인형뽑기 2명 결승 길이, 등불 다리 3번 군중 흔들림, 연어알·젤리 높이 — [`docs/DEV-SETUP.md`](DEV-SETUP.md) 3-10 J~S
- [x] **관리자 UserId 알려 주기** — 완료 (2026-10-08): **11402290839** → `src/server/AdminConfig.luau`의 `UserIds`에 들어갔어요
- [ ] **보상 코드 정하기 (m5-10)** — 저장소가 공개라 진짜 코드는 커밋하지 않아요. `src/server/CodeList.example.luau`를 같은 폴더에 `CodeList.luau`로 복사하고 쓸 코드(대문자·숫자 3~20자)·보상·기간을 적으세요. 이 파일은 `.gitignore`라 **퍼블리시하는 PC에만** 있어야 실서버에 들어가요. **문서·테스트에 나온 예시(`SUSHI2026`, `SPOOKYSUSHI`, `EXAMPLE2026`, `EXAMPLESPOOKY`)는 공개돼 있으니 실제 코드는 다른 문자열로** 정하세요. 코드 문자열은 이 파일이나 "답변 기록"에도 적지 마세요(공개 저장소) — 에이전트에게 알려 줄 필요 없이 로컬 파일에만. 읽을 곳: [`docs/specs/m5-10-redeem-codes.md`](specs/m5-10-redeem-codes.md) "개발 메모"
- [ ] **Survival 탈락 0명 허용 여부** — Survival 라운드에서 시간이 끝날 때까지 아무도 안 떨어지면 탈락 0명(전원 통과)이 될 수 있어요. **지금 구현은 허용**. 유지/막기 — 읽을 곳: [`docs/GDD.md`](GDD.md) §4.1, [`docs/specs/m2-05-match-flow.md`](specs/m2-05-match-flow.md) Q7
- [ ] **🎫 우승자 뽑기 남은 결정 2개 (급하지 않음, 플레이테스트 뒤에 정해도 돼요)** — 읽을 곳: [`docs/specs/m5-31-winner-ticket-draw.md`](specs/m5-31-winner-ticket-draw.md) "열린 질문"
  - 천장(보장): 이제 꽝은 없지만 전설 고등어는 1%라 평균 100장, 50장 뽑아도 못 얻을 확률 약 60%(R$ 199로 살 수도 있음). 없음 유지(추천, 일단) / "N장마다 영웅 이상 보장" 추가
  - 4명 친구 방에서 우승 몰아주기로 티켓 모으기: 막지 않음 유지(추천, 일단) / "5명 이상 판에서만 티켓"
  - 기본값(바꾸고 싶으면 알려 주세요): 티켓 상한 99장, 새 스킨 자동으로 안 입힘(결과 화면 "입기"), 단상 대표 스킨 = 아직 없는 가장 높은 등급
- [ ] **🐟 고등어 초밥 [신선] 남은 결정 (급하지 않음)** — 읽을 곳: [`docs/specs/m5-32-fresh-mackerel.md`](specs/m5-32-fresh-mackerel.md) "열린 질문"
  - 파츠 상한: 콘셉트 상한 70으로 먼저 만들고, 렌더로 부족하다는 근거가 나오면 이 스킨만 80까지 올릴지
  - 시트의 화남·슬픔 표정: 이번엔 뺌(게임에서 쓰는 곳 없음) — 나중에 이모트가 생기면
  - "팔딱"·"첨벙" 효과음: 무음으로 먼저 보고 결정
  - 움직임 체감(Studio, 개발 뒤): 팔딱이 너무 잦거나 정신없으면 간격·각도를 숫자로 알려 주세요
- [ ] **출시 방식 결정** — 한 플레이스 모드(로비와 매치가 한 서버, C2 불필요)로 먼저 낼지, 로비/매치 분리(C2 필요)로 낼지. 소리(A2)가 아직 없으면 무음 상태로 비공개 테스트를 시작해도 되는지.
- [ ] **이동 감시(치트 방지) 결정 2개** — 읽을 곳: [`docs/qa/m4-10-movement-guard.md`](qa/m4-10-movement-guard.md) "남은 버그" R1·R2
  - 걸리면 킥 없이 제자리로 되돌리기만 — 유지/킥 추가
  - 복제 지연 허용 0.5초 — 유지/0.75초(정상 플레이어 오탐↓, 치트 허용↑)
  - 속도 상한 약 110 studs/s — 유지/60(치트 잘 잡힘, 지연 시 오탐↑)

### A2. 소리 고르기 (브라우저로 Creator Store)
<https://create.roblox.com/store/audio> 에서 골라 **에셋 id**만 적어 주세요. 넣는 건 에이전트가 해요.
지금은 아래가 무음이에요 (`src/shared/SfxLibrary.luau`에서 `sfx(nil, …)` / `music(nil, …)`인 것).

- [ ] 배경음 4곡: `Lobby`(로비·대기실), `Round`(라운드), `Final`(결승), `Victory`(우승)
- [ ] 효과음 — 기본 연출 8개: `VictoryFanfare`(우승 팡파르), `SpeechPop`(말풍선), `ChefHand`(셰프 손 등장), `FishClap`(물고기 박수), `GrabStart`(잡기 시작), `ChopstickWarn`(젓가락 경고), `HotTileSizzle`(철판 지글), `ChefHandWarn`(셰프 손 경고)
- [ ] 효과음 — M5 기능 5개: `Overtime`(결승 연장전 시작 — 경적·징, m5-01), `TokenGet`(이벤트 재화 받음, m5-07), `CodeRedeemed`(코드 보상 성공, m5-10), `CatMeow`(고양이 손님 연출 "냠!" 직후, m5-09), `Fireworks`(불꽃이 터질 때, m5-09)
- [ ] 효과음 — 새 맵 10개: `IkuraPop`(연어알 폭탄 터짐, m5-04), `OilSplash`(기름이 솟구침 — 지글·촤악, m5-05), `FanGust`(송풍구 바람, m5-06), `JellyBoing`(젤리 튕김, m5-06), `BounceBoing`(방방 바닥 튕김, m5-14), `BlockCreak`(블록탑 삐걱임, m5-16), `CatToyBounce`(장난감 공에 맞음, m5-17), `CatPawWarn`(고양이 발 경고, m5-17), `CatPawSwipe`(고양이 발에 밀림, m5-17), `ClawLift`(집게가 칸을 들어 올림, m5-19)
- [ ] 효과음 — 고등어 초밥 [신선] 2개 (m5-32): `FishFlop`(고등어가 팔딱 — 젖은 물고기가 튀는 "퍼덕"), `FishSplash`(첨벙 — 작은 물 튀김)
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

### B1-1. Future 조명 켜기 (한 번만, m5-23)
`Lighting.Technology`(조명 방식)는 스크립트로 바꿀 수 없는 속성이라 `default.project.json`에 `Future`로 넣어 뒀어요. Rojo 동기화가 이 값을 못 바꾸는 경우가 있어서 한 번 확인해 주세요.
- [ ] Studio 탐색기에서 **Lighting** 선택 → 속성 창 **Technology**가 `Future`인지 확인. 아니면 `Future`로 바꾸고 **File → Save / Publish** (플레이스 파일에 저장돼야 실서버에도 적용돼요)
- [ ] 확인: 맵의 등불·조명 아래에 그림자가 생기고 빛이 주변을 물들이면 성공. 로비 → 맵 들어갈 때 맵마다 조명 분위기가 바뀌는지도 같이 봐 주세요(m5-23 맵별 조명).
- 휴대폰이 느려지면 알려 주세요. 저사양 기기는 Roblox가 자동으로 품질을 낮춰요.

### B2. M3 확인 (캐릭터·연출·다이브/잡기·소리)
- [ ] [`docs/DEV-SETUP.md`](DEV-SETUP.md) **3-8** 체크리스트 A~N
  - 특히: 잡혔을 때 절반 속도로 계속 움직이는지, 이름표가 하나만 보이는지, 다이브 자세, 음소거 버튼이 위쪽 바에서 겹치지 않는지, 휴대폰 가로에서 "출발!"이 배너를 가리지 않는지
- 맵 순서 고정: `src/shared/Config.luau`의 `DEBUG.forceMapPlan`에 맵 id 3~4개 → 확인 후 **반드시 `nil`로 되돌리기**

### B3. M4·M5 확인 (기능별 QA 리포트의 "사용자 Studio 확인 체크리스트" 절)
- [ ] M5: [`docs/DEV-SETUP.md`](DEV-SETUP.md) **3-10** A~T(연장전·관리자 미리보기·기반·시즌·상점·연출·코드·관리자 명령·스킨·새 맵 9개·기존 맵 다듬기)와 **3-11**(맵 비주얼 키트 — Future 조명·맵별 조명). 디버그·관리자 설정 표와 되돌리기 포함. 새 맵은 3-10 J~S — 특히 **줄다리기 발판 30° 미끄러짐(R2)**, 캣타워 넉백(Q3), 인형뽑기 2명 결승 길이(S2)를 숫자로 적어 주세요.
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
| (M5) 결승 연장전 | [`docs/DEV-SETUP.md`](DEV-SETUP.md) **3-10 A** (원본 [`docs/qa/m5-01-final-overtime.md`](qa/m5-01-final-overtime.md)) | 아니요 (`DEBUG.forceMapPlan`·`overtimeAt` 사용 후 `nil`로) |
| (M5) 관리자 스킨 미리보기 | [`docs/DEV-SETUP.md`](DEV-SETUP.md) **3-10 B** (원본 [`docs/qa/m5-02-admin-skin-preview.md`](qa/m5-02-admin-skin-preview.md)) | 1~5 아니요 (**5번은 `AdminConfig.StudioAllAdmins = false`로 2명 테스트 뒤 `true`로 되돌리기**), 6은 C1 먼저, 7·8은 실서버 |
| (M5) 기반·시즌 이벤트 | 3-10 **C·D** (원본 [`m5-03`](qa/m5-03-foundation.md), [`m5-07`](qa/m5-07-season-events.md)) | 아니요 (`eventNow` 사용 후 `nil`). 저장 이전 확인만 C1 먼저 |
| (M5) 🎁 특별 상품·VIP | 3-10 **E** (원본 [`m5-08`](qa/m5-08-offers-shop.md)) | 가짜 결제는 아니요(`fakeRobuxInStudio`·`fakeVipInStudio`, `persistDataInStudio`는 false). 실제 결제는 C1 + C3-1 + 퍼블리시 |
| (M5) 연출 팩 | 3-10 **F** (원본 [`m5-09`](qa/m5-09-fx-packs.md)) | 아니요 |
| (M5) 🎟 코드 보상 | 3-10 **G** (원본 [`m5-10`](qa/m5-10-redeem-codes.md)) | 아니요 (로컬 `CodeList.luau` 필요). 재접속 유지만 C1 먼저 |
| (M5) 관리자 명령 | 3-10 **H** (원본 [`m5-11`](qa/m5-11-admin-commands.md)) | 아니요. 실서버 확인은 퍼블리시 뒤 |
| (M5) 스킨 10종·스킨 규칙 v2 | 3-10 **I** (원본 [`m5-21`](qa/m5-21-skin-foundation-v2.md), [`m5-22`](qa/m5-22-skin-pack-1.md)) | 아니요 |
| (M5) 새 맵 9개 | 3-10 **J~S** (원본 `docs/qa/m5-04-…`~`m5-06-…`, `m5-13-…`~`m5-19-…`, 재QA 절 포함) | 아니요 (`forceMapPlan`·`overtimeAt` 사용 후 `nil`). 체감은 친구 테스트 |
| (M5) 기존 맵 다듬기 | 3-10 **T** (원본 [`m5-20`](qa/m5-20-map-quality-pass.md)) | 아니요 |
| (M5) 맵 비주얼 키트(조명) | 3-11 (원본 [`m5-23`](qa/m5-23-map-visual-kit.md), 재QA 전) | B1-1(Future 확인) 먼저 |

공통: 다인원은 Studio **Test → Clients and Servers**, 휴대폰은 **Test → Device** 에뮬레이터. 디버그 설정(`forceMapPlan`, `forceMapPlans`, `persistDataInStudio`, `simulateMatchServer`, `logArenaStats`, `fakeRobuxInStudio`, `overtimeAt`, `eventNow`, `fakeVipInStudio`)은 확인 후 원래 값(`nil`/`false`)으로, `src/server/AdminConfig.luau`의 `StudioAllAdmins`는 `true`로 되돌리고 커밋하지 마세요. `src/server/CodeList.luau`는 커밋되지 않아요.

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
  - **M5에서 늘어난 스킨 상품 12개** (m5-22 스킨 10종 + m5-07 시즌 로벅스 스킨 2종) — 같은 방법으로 만들고 id를 `src/shared/Skins.luau`의 `productId`에

    | 스킨 id | 상품 이름 | 가격(R$) |
    |---|---|---|
    | takoyaki | 타코야키 | 29 |
    | egg-toast | 에그토스트 | 29 |
    | slider-burger | 슬라이더 버거 | 29 |
    | tonkatsu | 돈가스 | 59 |
    | cat-sushi | 고양이 초밥 | 59 |
    | robo-roll | 로보 롤 | 59 |
    | galaxy-roll | 갤럭시 롤 | 99 |
    | softserve-roll | 소프트아이스크림 롤 | 99 |
    | crown-tuna | 크라운 참치 | 199 |
    | unicorn-roll | 유니콘 롤 | 199 |
    | pumpkin-sushi | 호박 초밥 (할로윈 한정) | 99 |
    | santa-shrimp | 산타 새우 (크리스마스 한정) | 99 |
  - **m5-32 전설 스킨 1개 더** (개발 전 — 스킨이 main에 들어간 뒤 만들어도 돼요): `fresh-mackerel` · 고등어 초밥 [신선] · **199** (🎫 뽑기 전설로도 나오지만 판매도 해요). id는 `src/shared/Skins.luau`의 `fresh-mackerel` `productId`에. 스펙 [`docs/specs/m5-32-fresh-mackerel.md`](specs/m5-32-fresh-mackerel.md)
- [ ] **C3-1. 특별 상품 5개 + 게임 패스 1개** (m5-08) — 스킨 상품 id와 겹치면 안 돼요
  - Developer Products 5개 → id를 `src/shared/Offers.luau`의 각 상품 `productId`에

    | offer id | 상품 이름 | 가격(R$) |
    |---|---|---|
    | starter-pack | 스타터 팩 | 79 |
    | epic-set | 에픽 세트 | 249 |
    | legendary-set | 전설 세트 | 499 |
    | fx-cat-customer | 탈락 연출: 고양이 손님 | 59 |
    | fx-fireworks | 우승 연출: 불꽃놀이 | 99 |
  - Monetization → **Passes**에 "VIP 패스" R$ 149 → id를 `Offers.luau`의 `vip` 상품 `gamePassId`에
  - Studio 확인 순서: [`docs/qa/m5-08-offers-shop.md`](qa/m5-08-offers-shop.md) 체크리스트 (`fakeRobuxInStudio`·`fakeVipInStudio` 켜고, `persistDataInStudio`는 false, 확인 뒤 모두 false로)
- [ ] **C4. 출시 설정** (m4-12) — 전체 체크리스트와 대응표: [`docs/specs/m4-12-release-hardening.md`](specs/m4-12-release-hardening.md) 개발 메모
  - 경험 설문(연령 등급), 공개 범위(비공개 테스트 → 공개)
    - 설문의 **"유료 랜덤 아이템(paid random items)"** 질문: 🎫 우승자 뽑기(m5-31)는 우승으로만 받는 무료 티켓이라 Roblox 문서상 유료 랜덤 아이템이 아니에요 → "없음"으로 답하면 돼요(고등어 [신선]을 로벅스로 팔아도 뽑기 자체는 돈으로 못 하니 그대로 "없음"). 나중에 티켓을 파는 상품이나 확률을 올리는 상품을 만들면 답이 바뀌니(그래서 만들지 않아요) 설문 화면의 문구가 다르면 알려 주세요. 근거: [`docs/REFERENCE-winner-ticket-draw.md`](REFERENCE-winner-ticket-draw.md) §1
  - 지원 기기: PC·휴대폰·태블릿 켬, **콘솔 끔** (콘솔 UI는 m5-12, 아직 시작 전)
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
2026-10-13 VIP 패스: 코인 배수 없이 겉모습만(149 R$) — 반영됨
2026-10-13 출시 범위: 먼저 16세 이상으로 공개(비용 없음, 계정 나이 확인만). 모든 연령(Kids·Select, 1,000 R$ 환불 보증금 또는 Premium 2개월)은 반응을 본 뒤 2단계 — 반영됨
(예) 2026-10-09: 하루 첫 판 기준 한국 시간으로. 결승 3초 대기 삭제. Lobby 음악 id 1234567890.
```

- 2026-10-14 (3차): 뽑기 천장 없음, 적은 인원 방 몰아주기 일단 둠. 고등어만 파츠 상한 80, 화남·슬픔 표정 만들기(콘셉트 몸 공용), 팔딱·첨벙 효과음 넣기(id는 A2). — 스펙 반영됨(m5-31·m5-32)
- 2026-10-08: 150초 안전 상한은 가장 높이 있는 1명 우승(위임). 실서버 관리자 기능 켜 둠(`LiveEnabled = true`, 공개 출시 전 재확인). 관리자 UserId 11402290839. 실서버 테스트 명령 없음(설정으로도 못 켬). — 반영됨
- 2026-10-13 (세션 중 사용자 결정·위임) — 반영됨
  - 디저트 냉장고 C 구간 폭 **30** 그대로 (m5-06 Q1)
  - 튀김 냄비 **나선 배치 그대로** (m5-05 D4)
  - 맵 아트 **Extended 예산(장식 1500·조명 24·파티클 16·그림자 조명 2·움직임 80)** 허용 (m5-23 D3, m5-24 D2)
  - 맵 세부 판단은 **메인 세션에 위임** (연어알 폭탄 다시 뽑기, 튀는 기름 대상·높이 범위 3.5, 냉장고 송풍구 이동 감시 면제 뺌 등 — 각 스펙 결정 기록)
  - **저장을 켠 Studio(`persistDataInStudio = true`)에서는 관리자 코인·이벤트 재화 명령을 막기** (m5-11 QA B1 → `coins`·`tokens` StudioOnly 등급)
- 2026-10-14 (세션 중 사용자 결정) — 반영됨
  - 콘셉트 스킨 5종(concept-salmon·tuna·shrimp·tamago·ikura)은 **무료 테스트 그대로 유지** — 가격·등급·판매 없음 (m5-28 열린 질문 1 → 결정됨)
  - 콘셉트 스타일 스킨을 **더 만든다** — 2차 4종 장어·성게 군함·문어·유부 (m5-28 열린 질문 3 → 결정됨, 스펙 [`docs/specs/m5-29-concept-skins-2.md`](specs/m5-29-concept-skins-2.md))
  - **우승자 뽑기 티켓**: 우승 1번 = 🎫 1장, 뽑기 = 스킨 10% / 꽝 90%(🍚 +20). 뽑기 풀 = 콘셉트 스킨 9종(이제 무료 아님·판매 아님, 뽑기로만). 이름 "○○ (특)". Studio에서는 모든 스킨 장착 가능(저장 안 함, `unlockAllSkinsInStudio`). 위의 "콘셉트 스킨 무료 테스트 유지" 결정은 이것으로 바뀜 — GDD v0.7 §9.1·9.6, 스펙 [`docs/specs/m5-31-winner-ticket-draw.md`](specs/m5-31-winner-ticket-draw.md)
  - **고등어 초밥 [신선]**: 시트 `docs/고등어 초밥 캐릭터 시트.png`, 전설 등급(R$ 199), 퀄리티 매우 높게, 고등어가 팔딱거리는 움직임이 핵심, 아주 신선한 비주얼, 이름 끝 [신선] — 스펙 [`docs/specs/m5-32-fresh-mackerel.md`](specs/m5-32-fresh-mackerel.md)
- 2026-10-14 2차 (세션 중 사용자 결정 — 뽑기 화면 샘플) — 반영됨
  - 뽑기 화면은 샘플 `docs/귀여운 초밥 스킨 뽑기 UI.png`를 참고해 만든다(이미지 에셋 대신 Roblox 기본 UI 요소로)
  - **확률: 꽝 없이 등급별** — 전설 1% / 영웅 5% / 희귀 15% / 고급 30% / 일반 49%(샘플 48% → 합 100 맞춤). 등급 안에서 균등. 이미 가진 스킨이면 코인 일반 20 / 고급 40 / 희귀 80 / 영웅 150 / 전설 300. 위의 "스킨 10% / 꽝 90% +20", "9종 다 가지면 +100"은 이것으로 바뀜
  - 뽑기 등급: 연어 영웅, 성게·문어·연어알 희귀, 유부·장어·참치 고급, 새우·계란 일반. **전설 = 고등어 초밥 [신선]**
  - **고등어 [신선]은 뽑기 전설로도 나오고 R$ 199 판매도** — 뽑기로 얻든 사든 같은 보유, 이미 가졌으면 구매 막음. 뽑기 자체는 돈으로 못 함
  - 전설 스킨이 없는 동안(m5-32 전)은 전설 확률을 다른 등급에 비율대로 나누고 화면도 그 값을 보여 줌
  - 스펙 [`docs/specs/m5-31-winner-ticket-draw.md`](specs/m5-31-winner-ticket-draw.md), [`docs/specs/m5-32-fresh-mackerel.md`](specs/m5-32-fresh-mackerel.md), GDD v0.7 §9.6
