# M5 기획 작업 기록 (planner)

## 2026-10-08 — M5 두 번째 묶음 스펙 10개 (m5-03 ~ m5-12) (최신)

**브랜치**: `main` (347058a 위, 커밋 안 함 — planner는 Bash가 없음. 메인 세션이 아래 "커밋할 파일"을 커밋 + push)

### 끝난 것
- 사용자 지시 "M5 백로그 스펙 작성하고 개발까지 쭉 진행" → 백로그를 스펙 10개로 나눔, **전부 `status: ready`**. 결정이 필요한 것은 조사 근거로 기본값을 정하고 결정 기록에 "기본값으로 진행, 사용자 수정 가능".
- 조사 (확인일 2026-10-08):
  - 새 `docs/REFERENCE-m5-maps.md` — Fall Guys Blast Ball·Slime Climb·Roll Off·Thin Ice·시즌 3 얼음 라운드, Roblox Super Bomb Survival·The Floor Is LAVA!(방문 32억)·Flood Escape 2·얼음 오비, Stumble Guys Icy Heights, DevForum 얼음 이동 방식.
  - `docs/REFERENCE-roblox-monetization.md` **8절 추가** — Epic Minigames·Arsenal 게임 패스 API 원문(VIP·Starter·계절 번들·"death" 연출, Arsenal 1.5배 VIP 교체), MM2·Adopt Me 할로윈 이벤트 재화, 코드 관행(Epic Minigames·Arsenal·Tower of Hell), 공식 문서(개발자 상품 vs 패스, 지역 가격, managed pricing), Roblox Kids·Select(2026), 보상 피드 정책, 기만적 수익화 연구, M5 가격 제안표.
  - 새 `docs/REFERENCE-console-ui.md` — Roblox 콘솔 가이드라인 원문.
- GDD는 고치지 않음 (사용자 확정 전, 바뀔 절은 아래).

| 스펙 | 내용 | worktree / 포트 | 공용 파일 |
|---|---|---|---|
| m5-03 foundation | `inPool` 플래그 + 새 맵 껍데기 3, 프로필 v2(코드·이벤트 재화·연출·한 번 산 상품), 스킨 5종 데이터(시즌 4 + VIP 1), `Seasons`·`FxCatalog`, 판매 기간 확인, 리모트 5, 속성 3, Config(Events·Codes·DEBUG 2), cue 8, `PriceCache`, 서비스·컨트롤러 껍데기 | **main (단계 0)** | Config, Remotes, Types, Attributes, MapTypes, maps/init, init 2개 |
| m5-04 map-ikura-bombs | **두 번째 결승** 연어알 폭탄 접시: 폭탄 경고 → 넉백, 같은 칸 두 번이면 깨짐, 40/60초부터 조각 낙하, 연장전에 고리 단위 붕괴 | `m5-ikura` 34872 | 없음 |
| m5-05 map-tempura-pot | Survival 튀김 냄비 탈출: 기름이 0.4/s로 차오름, 튀김 발판 7~31층, 튀는 기름 넉백 | `m5-tempura` 34873 | 없음 |
| m5-06 map-dessert-fridge | Race 디저트 냉장고: 얼음(클라이언트 관성 `IceController`), 젤리 튕김, 송풍구 | `m5-fridge` 34874 | 없음 |
| m5-07 season-events | 할로윈·크리스마스 이벤트, 이벤트 재화 🍬/⭐, 무료 한정(재화 80)·유료 한정(R$ 99), 탈의실 이벤트 탭, 새 스킨 생김새, 로비 장식 | `m5-season` 34875 | 없음 |
| m5-08 offers-shop | "🎁 상점": 스타터 79·에픽 세트 249·전설 세트 499·연출 59/99·VIP 패스 149, 영수증 일반화, VIP 👑·[VIP] | `m5-offers` 34876 | 없음 |
| m5-09 fx-packs | 연출 비주얼: 고양이 손님(탈락 3변형)·불꽃놀이(우승) | `m5-fx` 34877 | 없음 |
| m5-10 redeem-codes | "🎟 코드": 서버 전용 목록, 계정당 1번·만료·틀린 코드 8번이면 10분 잠금, 코인 100~300 (+이벤트 재화) | `m5-codes` 34878 | 없음 |
| m5-11 admin-commands | 관리자 "🛠 명령" 탭: info·연출 미리보기(실서버 OK) / 강제 시작·다음 판 맵·코인·재화(Studio 또는 `LiveTestCommands`) / 프로필 초기화(Studio만) | `m5-admin2` 34879 | 없음 |
| m5-12 console-ui | 게임패드로 모든 창(자동 선택·B 닫기·LB/RB), 10피트 안전 여백·채팅 끄기 | **main (단계 2, 마지막)** — 미뤄도 됨 | (필요하면) init.client |

### 개발 순서
```
단계 0 (순차, main)      m5-03 foundation  ← 공용 파일·프로필 v2·카탈로그·껍데기 전부
                               │ main 병합 + push 후 worktree 생성 (claude --worktree는 origin/main 기준)
단계 1 (병렬, worktree)  8개 — 고치는 파일이 서로 겹치지 않음 (각 스펙 머리 "이 스펙이 고치는 파일")
                         한꺼번에 못 돌리면:
                         물결 1: m5-07 season(할로윈 10/16 시작이라 먼저) · m5-04 ikura(두 번째 결승) · m5-08 offers · m5-10 codes
                         물결 2: m5-05 tempura · m5-06 fridge · m5-09 fx · m5-11 admin
                               │ 각각 qa-passed → main 병합 (순서 자유. 권장: m5-08 → m5-09, m5-07·m5-09 → m5-11의 Studio AC10·11)
단계 2 (순차, main)      m5-12 console-ui   ← UI 화면을 다 고쳐서 단계 1 UI 스펙(07·08·10·11) 머지 뒤. 콘솔 출시를 안 하면 다음 묶음으로
```
- 눈여겨볼 나눔: `ShopService`·탈의실 = m5-07만(`BuyWithTokens`), 결제 영수증(`ReceiptLogic`·`RobuxShopService`) = m5-08만, `SushiBody` = m5-07만(VIP 금박 포함), 탈락·우승 연출 파일 = m5-09만, `RoomService`·`MatchService` = m5-11만(m5-03의 한 줄 뒤), `CharacterFxController` = m5-08만, 새 버튼 위치 고정(스킨 y10 · 상점 y60 · 코드 y110).
- 맵 스펙은 끝나면 자기 모듈의 `inPool = false` 줄만 지워 랜덤 풀에 넣음(공용 파일 안 고침).

### 기본값으로 정한 주요 결정 (사용자 수정 가능, 근거는 각 스펙 결정 기록·REFERENCE)
- **맵**: 결승 = 연어알 폭탄 접시(Blast Ball·Super Bomb Survival), Survival = 튀김 냄비(차오르는 기름 — Slime Climb·Floor Is LAVA), Race = 디저트 냉장고(얼음 관성 — Fall Guys 시즌 3·DevForum). "연어 왕관 쟁탈전"은 생존형 결승·"늦추기만" 잡기와 안 맞아 백로그.
- **시즌**: 이벤트마다 무료 한정 1(재화 80 ≈ 25~30판) + 유료 한정 1(R$ 99). 할로윈 10/16~11/6, 크리스마스 12/11~1/8(UTC). 재화는 보상에 얹어 지급(판 참가 1·통과 1·결승 2·우승 5·하루 첫 판 3), 기간 중에만 교환, 코인으로 안 바꿔 줌. 남은 기간은 날짜로만(카운트다운 없음), "다음 해에 다시 올 수도 있어요".
- **상품**: 스타터 79(연어·참치·새우·장어, 하나도 없을 때만, 계정당 1번), 에픽 세트 249·전설 세트 499(하나도 없을 때만), 탈락 연출 59·우승 연출 99, VIP 게임 패스 **149 — 코인 배수 없음**(겉모습 3가지). 묶음·연출 = 개발자 상품, VIP만 게임 패스. 로벅스 가격 표시는 `PriceCache`(지역 가격 준비).
- **코드**: 코인 100~300(+이벤트 재화 10), 대소문자 무시, 계정당 1번, 만료, 2초 간격, 10분에 틀린 코드 8번이면 잠금, 서버 전용 목록.
- **관리자**: 실서버 경제·판정 명령 기본 꺼짐(`LiveTestCommands = false`), 켜도 본인 것만, 다른 사람 대상 명령 없음.
- **콘솔**: 마지막 입력이 패드일 때 내비게이션, 10피트 기기만 채팅 끄기·5% 여백. 마지막 단계, 미룰 수 있음.

### 사용자 결정이 필요한 것 (기본값으로 진행 중)
1. **VIP 코인 배수**: 넣지 않음(기본, "코인 R$ 판매 안 함" 확정과 맞춤, 149) / 1.5배 넣고 199~249.
2. **이벤트 기간**: 할로윈 10/16 시작이 퍼블리시 일정과 맞는지(늦으면 `Seasons.luau` 날짜만), "다음 해에 다시 올 수도 있어요" 문구.
3. **코드가 저장소에 보여도 되는지**: GitHub 저장소가 공개면 `CodeConfig.luau`를 커밋하지 않는 방식으로 바꿔야 함(m5-10 D4).
4. 상품 가격·구성(스타터·세트·연출), 지역 가격(Managed Pricing) 켤지.
5. 콘솔 UI를 이번 묶음에 할지(m5-12) — 콘솔 출시 계획.
6. 실서버에서 관리자 Test 명령을 쓸지(`LiveTestCommands`).
7. (이월) Survival 탈락 0명 허용(GDD 4.1 Q7) — 새 Survival 맵(튀김 냄비)도 시간 종료 전원 통과 규칙을 따름.

### 사용자 작업 (USER-TODO 추가 제안 — docs-writer 담당 파일)
- A1: 위 결정 1~6, 쓸 코드 목록(코드·코인·기간).
- A2 소리 8개: `IkuraPop`, `OilSplash`, `FanGust`, `JellyBoing`, `TokenGet`, `CodeRedeemed`, `CatMeow`, `Fireworks`.
- C3 개발자 상품 **7개** 더: 호박 초밥 99, 산타 새우 99(→ `Skins.luau`), 스타터 팩 79, 에픽 세트 249, 전설 세트 499, 탈락 연출 고양이 손님 59, 우승 연출 불꽃놀이 99(→ `Offers.luau`). **게임 패스 1개**: VIP 패스 149(→ `Offers.luau` `gamePassId`).
- C4: 콘솔 켤지(m5-12 뒤), 경험 설문 완료(콘솔 필수).
- B(Studio): 각 스펙 Studio AC. 새 디버그 설정 `Config.DEBUG.eventNow`·`fakeVipInStudio`, `AdminConfig.LiveTestCommands` 되돌리기 안내.

### 바뀔 GDD 절 (사용자 확정 뒤 v0.6으로)
- §5.2 맵 목록: 맵 풀 9개(Race 4·Survival 3·Final 2), ⑦ 연어알 폭탄 접시(결승, 연장전 포함)·⑧ 튀김 냄비 탈출·⑨ 디저트 냉장고 규칙. "Final 맵" 문단에 결승 맵 2개 중 무작위.
- §5.3: 디저트 냉장고·튀김 기름 점프 → 구현으로 옮김, 연어 왕관 쟁탈전은 보류 이유 한 줄.
- §6: 얼음 위 관성 이동(클라이언트) 한 줄, 게임패드 UI(m5-12).
- §7·§8: 연출 팩(고양이 손님·불꽃놀이) — 흐름·길이 그대로, 속성으로 고름.
- §9.2: 시즌 한정 줄 → 실제 4종(무료 재화 80 / 유료 99)·이벤트 기간, VIP 전용 금박 계란초밥. 스킨 21종.
- §9.3: 상품표를 확정 가격으로(스타터 79·세트 249/499·연출 59/99·VIP 149 코인 배수 없음), 개발자 상품/패스 구분 이유, 코드 보상 규칙.
- §9.4: 이벤트 재화(🍬/⭐) 지급표, 코드 코인.
- §10: "🎁 상점"·"🎟 코드" 버튼, 탈의실 이벤트 탭·이벤트 머리줄(날짜만), 코인 배지 옆 재화, 관리자 "명령" 탭, 콘솔 내비게이션.
- §11.4: `inPool` 필드, 새 태그(`IkuraTile`, `IkuraBomb`, `HotOil`, `TempuraRaft`, `OilSplash`, `Ice`, `Jelly`, `ColdFan`). §11.5: 프로필 v2 칸. §11.7: 관리자 명령 등급.
- §12 M5 행, §13 리스크(압박 판매 → 날짜만 표시·뽑기 없음, 코드 무차별 대입 → 잠금, 묶음 중복 구매 → 조건·기록), §14.

### 다음에 할 첫 단계
- 메인 세션: 아래 파일 커밋 + push → `developer` 에이전트로 `docs/specs/m5-03-foundation.md` 구현(main). 머지·push 뒤 단계 1 worktree 8개(또는 물결 1부터).

### 막힌 점
- Fall Guys 위키(Fandom 402)·일부 기사(403/405)·MM2 위키는 원문을 못 열어 검색 요약으로 남김(각 REFERENCE "확인 못 함"). 가격 결정에 쓴 핵심(Epic Minigames·Arsenal 게임 패스, 공식 문서)은 원문 확인.

### 커밋할 파일
- `docs/REFERENCE-m5-maps.md`, `docs/REFERENCE-console-ui.md`, `docs/REFERENCE-roblox-monetization.md`
- `docs/specs/m5-03-foundation.md`, `m5-04-map-ikura-bombs.md`, `m5-05-map-tempura-pot.md`, `m5-06-map-dessert-fridge.md`, `m5-07-season-events.md`, `m5-08-offers-shop.md`, `m5-09-fx-packs.md`, `m5-10-redeem-codes.md`, `m5-11-admin-commands.md`, `m5-12-console-ui.md`
- `docs/planner/m5-plan.md`

---

## 2026-10-08 — GDD v0.5 반영

**브랜치**: `m5-01-qa-fixes` 작업 트리 (main f418857 기준, 커밋 안 함 — 메인 세션이 커밋 + push). docs-writer가 같은 때 CLAUDE.md·CHANGELOG·DEV-SETUP·README·USER-TODO를 고침 → planner는 GDD와 이 파일만.

### 끝난 것
- m5-01·m5-02 둘 다 qa-passed + 사용자 확정(위임 포함)을 받아 `docs/GDD.md`를 **v0.5**로 갱신:
  - §4 3번(결승은 시간 제한 대신 연장전), §5.1(연장전 한 줄), §5.2 Final 문단(연장전 일정 표 90/110/150초, 안전 상한 = 가장 높이 있는 1명, 결승에서만, 훅 없는 결승 맵은 시간 제한에 높이 순), ⑥(손 멈춤, 꼬치 190/150, 바깥 줄부터 약 2.7초 = 19/7초 간격 붕괴)
  - §10 HUD(연장전 표시, 관리자 "🛠" 패널 — 관리자에게만), §11.4(`overtime?` 훅·Final 필수·schedule/clockPhase), 새 §11.7 테스트 도구(관리자 판단, 비밀번호 방식을 안 쓰는 이유, 기록 안 함, MemoryStore 유지)
  - §12 M5 행(진행 중, 두 기능 개발 완료·사용자 확인 대기), §13 리스크 2줄, §14 다음 할 일, 변경 이력 v0.5
- 위 "사용자 결정" 1(150초 = 1안 높이 1명)·4(`LiveEnabled = true`)는 사용자 위임으로 확정. 3(목록 위치)은 서버 전용 `AdminConfig`로 GDD에 기록.

### 남은 것 / 다음에 할 첫 단계
- 메인 세션: GDD + 이 파일 커밋·push (docs-writer 파일과 함께).
- 두 스펙의 상태 `qa-passed` → `done`은 사용자 Studio 확인 뒤(WORKFLOW 규칙대로).
- 다음 M5 스펙 후보: 백로그(아래) 중 사용자가 고르는 것. 새 결승 맵은 `overtime` 훅 필수.

### 사용자 답을 기다리는 질문
- 연장전 수치(90/20/150초, 꼬치 190/150, 경고 1초) — 플레이테스트 뒤 조정.
- 공개 출시 때 관리자 기능 끌지(`LiveEnabled`).
- Survival 탈락 0명 허용(GDD 4.1 Q7) — 그대로.

### 막힌 점
- 없음.

### 커밋할 파일
- `docs/GDD.md`
- `docs/planner/m5-plan.md`

---

## 2026-10-08 — M5 첫 스펙 2개

**브랜치**: `main` (a96ea46 위, 커밋 안 함 — planner는 Bash가 없음. 메인 세션이 아래 "커밋할 파일"을 커밋 + push)

### 끝난 것
- 사용자 요청 2가지를 스펙으로. 둘 다 `status: ready`, 사용자 지시 "기본값으로 진행"대로 결정은 조사 근거로 기본값을 정하고 결정 기록에 "사용자 수정 가능".
- 조사: `docs/REFERENCE-final-overtime.md` — 결승·라스트맨스탠딩 시간 초과 처리 사례 12개(Fall Guys Hex-A-Gone·결승 전반·Jump Showdown·Royal Fumble·Thin Ice, Stumble Guys Laser Tracer Endless·Stumblewood, Super Bomberman, Roblox Circle Clash·MM2·NDS·Epic Minigames), 관리자 권한 관행(Roblox 커뮤니티 기준·Creator Docs·DevForum).
- GDD는 고치지 않음 (사용자 확정 전).

| 스펙 | 내용 | worktree / 포트 | 공용 파일 |
|---|---|---|---|
| m5-01 final-overtime | 결승 90초 → 연장전(꼬치 가속 + 접시가 바깥부터 20초 동안 무너짐) → 늦게 떨어진 사람 우승, 150초 안전 상한(높이 1명). RoundLogic.schedule/clockPhase, MapTypes `overtime` 훅(Final 맵 필수), HUD "⚡ 연장전", `Overtime` 효과음 | `m5-overtime` 34872 | Config, Types, MapTypes |
| m5-02 admin-skin-preview | Studio·UserId 허용 목록(11402290839)·게임 소유자만 스킨 무료 착용(미리보기, 저장 안 됨), 관리자에게만 "🛠" 패널, 서버 재검증, MemoryStore로 로비↔매치 유지 | `m5-admin` 34873 | Remotes, Attributes, init 2개 |

### 개발 순서
```
병렬:  m5-01 (m5-overtime)   ||   m5-02 (m5-admin)
       고치는 파일이 겹치지 않음 (m5-02의 ShopService 수정은 m5-01과 무관)
병합:  어느 쪽이 먼저여도 됨. 둘 다 qa-passed → main 병합
```

### 바뀔 GDD 절 (사용자 확정 뒤 v0.5로)
- §4 3번 "모든 라운드는 짧은 시간 제한" → "결승은 시간 제한 대신 연장전".
- §5.1 결승 설명 + §5.2 "Final 맵 — 최대 90초" 문단: 90초 연장전 → 20초 붕괴 → 늦게 떨어진 사람 우승, 150초 안전 상한(높이 1명). ⑥ 꼬치 쇼다운에 연장전(꼬치 190/150, 바깥 줄부터 약 2.7초(19/7초)마다).
- §10 HUD: 결승 연장전 표시("⚡ 연장전!", 빨간 "⚡ N초", "⚡ 버텨요!"), 관리자 "🛠" 패널.
- §11.4 맵 인터페이스: `overtime?(ctx, info)` (Final 필수).
- 새 §11.7 "테스트 도구": 관리자 판단(Studio·UserId 목록·개인 소유자), 미리보기 착용은 저장·결제와 분리, 서버 재검증, 비밀번호 방식 금지 이유.
- §13 리스크 표: "결승이 끝나지 않음(버티기)" → 연장전 붕괴 + 안전 상한. "관리자 기능 악용" → 서버 UserId 판단.
- §12 M5 행: 위 두 기능 추가.

### 사용자 결정·작업 (기본값으로 진행 중, 답이 오면 스펙·GDD 수정)
1. 150초 안전 상한 판정: **1안 높이 1명(기본값)** / 2안 공동 우승(Fall Guys식, 큰 변경) / 3안 무승부 — REFERENCE 3절.
2. 연장전 수치(90초 시작, 20초 붕괴, 꼬치 190/150) — 플레이테스트 뒤 조정.
3. 관리자 목록 위치: 서버 전용 `AdminConfig`(기본값, 클라이언트에 안 보임) / 메인 세션 원안 `Config.Admin`.
4. 실서버 관리자 기능 유지(`LiveEnabled = true`) — 공개 출시 때 끌지.
5. USER-TODO 추가 제안 (docs-writer 담당 파일):
   - A2 소리 고르기에 효과음 `Overtime`(연장전 경적) 추가.
   - "UserId 알려 주기" 항목은 **완료**로 기록 (2026-10-08, 11402290839).
   - B(Studio)에 m5-01 AC11~17, m5-02 AC6~11 확인, 디버그 `Config.DEBUG.overtimeAt`·`AdminConfig.StudioAllAdmins` 되돌리기 안내.

### M5 백로그 (이번에 스펙화하지 않음)
- 새 맵(GDD 5.3): 디저트 냉장고(Race), 튀김 기름 점프(Survival), 연어 왕관 쟁탈전(Final — 규칙 재검토, **m5-01 연장전 훅 필수**), 꼬치 다리 대탈출(Race 후보), 팀 라운드.
- 시즌 스킨(할로윈 호박·크리스마스 산타 새우 등, 에픽 가격대 제안), 용 롤 꼬리 애니메이션.
- 9.3 상품: 탈락·우승 연출 팩, VIP 패스, 스타터 번들(79) — 가격 재검토, 세트 할인, SNS 코드 보상, 지역 가격.
- 이벤트(기간 한정 맵·보상), 콘솔 UI, 3D 방 목록(접시).
- 관리자 명령 확장(강제 시작·맵 고르기·코인 지급 — 테스트 서버 전용), 그룹 랭크 권한.
- 남은 결정: Survival 탈락 0명 허용(GDD 4.1 Q7).

### 다음에 할 첫 단계
- 메인 세션: 아래 파일 커밋 + push → worktree 2개로 `developer` 에이전트에 m5-01, m5-02 병렬 구현.

### 막힌 점
- Fall Guys 위키(Fandom)·일부 기사(PC Gamer·GameSpot·Prima)는 403/402로 원문을 못 열어 검색 요약으로 남김(REFERENCE "확인 못 함"). 결정에 쓴 핵심(Hex-A-Gone 5분 공동 우승, Jump Showdown infinite hang 제거, Laser Tracer Endless, Bomberman Hurry Up·무승부)은 원문 확인.

### 커밋할 파일
- `docs/REFERENCE-final-overtime.md`
- `docs/specs/m5-01-final-overtime.md`
- `docs/specs/m5-02-admin-skin-preview.md`
- `docs/planner/m5-plan.md`
