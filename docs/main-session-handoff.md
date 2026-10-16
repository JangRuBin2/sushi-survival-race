# 메인 세션 인계 메모

최신 내용을 맨 위에 둔다.

## 2026-10-16 — 사용자 확인 대기 중 정리 (막지 않는 P3·문서)

M5 개발 스펙은 모두 `done`, 사용자 Studio 확인 대기 그대로. 기다리는 동안 사용자 결정·플레이테스트가 필요 없는 것만 main에서 고침. 5단계: rojo OK · stylua OK · selene 0/0/0 · `lune run tests` **2381 passed, 0 failed** · luau-lsp 끝 코드 0.
- **m5-41 B1 고침**: 카운트다운(Starting)부터 버튼 위치 편집 잠금. `TouchLayoutController` `RoomUpdated`는 InMatch가 아닐 때만 phase를 지움. `m5-41-qa` 기대값 true, QA 리포트·DEV-SETUP 3-12 문구 갱신. Studio 확인은 기존 체크리스트 6.
- 코드 주석: `SushiBody` CONCEPT_BODY 10종·표정 6종, `SushiConceptSample` EXPRESSIONS 6종, `VictoryCutsceneController` 대비값 `DEFAULT_GROUND_OFFSET` 2.3 → 2.25(실제 값과 같게, 동작 영향 없음).
- GDD(기획 변경 없음): 9.2 제목 41종·판매 26종 합계 2,334 R$, 11.7 41종, 6절 캐릭터 몸을 m5-25 기준 몸·콘셉트 몸으로.
- 그대로 둔 것: 플레이테스트 판단 4개(`docs/planner/2026-10-15-doc-sync.md`), m5-41 B2(Studio AC14에서 보이면), 게임패드 P3들, worktree 정리(사용자 확인 뒤).

## 2026-10-15 — 맵 3차 배치·맵 길이·현지화·콘솔 UI 병합, M5 개발 스펙 전부 완료

main `7bf280c` 기준(push 됨). 마지막 병합 뒤 5단계: rojo OK · `stylua --check src tests tools` OK · selene 0/0/0 · `lune run tests` **2381 passed, 0 failed (163개 파일)** · luau-lsp 끝 코드 0. **`ready`·개발 중 스펙 없음** — 모든 M5 스펙 `done`. 다음은 사용자 Studio 확인·플레이테스트 결과 반영.

### 흐름
스펙마다 developer(worktree) → qa(같은 worktree) → 메인 세션이 main에 `--no-ff` 병합 → 병합마다 5단계 재실행 → push → docs-writer 문서 반영·`done`. P2 이상은 병합 전에 developer가 같은 브랜치에서 고친 뒤 병합.

### 오늘 main에 들어온 것
| 스펙 | 브랜치 | 병합 커밋 | QA 리포트 |
|---|---|---|---|
| m5-33 맵 3차 기반(껍데기 6개·등록·cue 14·파티클 3) | main 직접 | `55e578c`·`b2769b8` | `docs/qa/m5-33-map-batch-3-foundation.md` (+ P3-1·2 처리 `7ad7792`: 풀 21 숫자 고정, 연속 플랜에 배치 3) |
| m5-39 온천탕 인형뽑기 (Final) | `m5-map-onsen` | `ef281db` | `docs/qa/m5-39-onsen-claw.md` — **P2-1 충격파 고리로 걸어 들어가면 통과 → 병합 전 수정**(`ring.lastDist`) |
| m5-34 설거지통 (Race) | `m5-map-sink` | `052c08f` | `docs/qa/m5-34-map-dish-sink.md` |
| m5-35 우주 회전초밥 (Race) | `m5-map-space` | `7657320` | `docs/qa/m5-35-map-space-conveyor.md` (레일 파츠 `AssemblyLinearVelocity` 방식 D6) |
| m5-37 수산시장 (Survival) | `m5-map-fish` | `c0b23d3` | `docs/qa/m5-37-map-fish-market.md` |
| m5-36 초대형 밥솥 (Survival) | `m5-map-rice` | `0706502` | `docs/qa/m5-36-map-rice-cooker.md` — **P2 B1 끓어오름이 한 판 내내 안 나올 수 있음 → 병합 전 수정**(`math.max(elapsed(), first)`) |
| m5-38 찻잎 정원 (Final) | `m5-map-tea` | `c121dda` | `docs/qa/m5-38-map-tea-garden.md` |
| m5-40 L4 Survival 5개 75초 + 60초 서든데스 | `m5-len-d` | `773b3bd` | `docs/qa/m5-40-l4.md` |
| m5-40 L3 방방 미로·등불 다리 | `m5-len-c` | `a0e9a25` | `docs/qa/m5-40-l3.md` |
| m5-40 L1 회전 벨트·간장 늪 | `m5-len-a` | `15f2cf3` | `docs/qa/m5-40-l1.md` |
| m5-40 L2 라멘·디저트 | `m5-len-b` | `8750ee6` | `docs/qa/m5-40-l2.md` |
| m5-23 맵 비주얼 키트 재QA | `m5-23-reqa` | `3f2678c` | `docs/qa/m5-23-map-visual-kit-reqa.md` |
| m5-26 현지화(ko/en, 새 키 91 — 맵 3차·특 스킨·뽑기·버튼 편집) | `m5-26-i18n-p3` | `3893c8a` | `docs/qa/m5-26-localization-reqa.md` |
| m5-12 콘솔·게임패드 UI | `m5-12-console` | `6b50f8d` | `docs/qa/m5-12-console-ui.md` |

문서: docs-writer `c1db69c`(m5-33~40)·`e252681`(m5-26)·`ad2bec9`(m5-12 + GDD 상태 문구), planner GDD·스펙 본문 정합 `59e881f`(Survival 75초, 맵 21개, m5-34·35·15·40 본문), `fb99247` MapTypes 주석 21개, `7bf280c` GDD 뽑기 연출 1.2초(`DrawScreen.SUSPENSE_TIME`).

### 메인 세션이 정한 것
- m5-33 QA "P3 2건은 6개 병합 뒤" → 병합 뒤 테스트 고정으로 처리.
- m5-36 D7(창 햇살 대신 Lighting 해 + 걸린 등 그림자 Spot) 승인(맵 디자인 위임 범위).
- m5-40 스펙 개발 메모·결정 기록은 그룹마다 같은 자리에 덧붙여 병합 충돌이 3번 남 — 전부 양쪽 유지로 해결(코드 충돌 없음).
- m5-12는 스펙상 "main 순차"였지만 문서 작업과 겹치지 않게 worktree로 진행(다른 src 작업 없음).

### 남은 것 (막지 않음 — 플레이테스트로 판단)
- 플레이테스트 판단 4개는 `docs/planner/2026-10-15-doc-sync.md` 표 하나에: 설거지통 F 수세미 엇갈림(offset 2.75), 찻잎 정원 연장전 찻잔 3개·속도 18, 튀김 냄비 23층 동시 탈락, **방방 미로 바운스 최고점이 벽보다 0.25 높음(m5-40 L3 B1, P2 — 기둥 위에 올라서면 `WALL_HEIGHT` 14 → 16)**.
- 회전 벨트 접시 탑 0.25 턱(걸리면 작은 접시 충돌 끄기), 라멘 소개 ③ 국자 가림·X자 젓가락 끝 → 렌게 1 모서리, 수산시장 생선·얼음 넉백 겹침, 우주 회전초밥 굽은 원판 흔들림·운석 바위 겹침.
- 예산이 거의 참: 튀김 냄비 장식 1495/1500, 회전 벨트 1492/1500, 등불 다리 조명 24/24, 그림자 조명 2/2 맵 4개(dish-sink·space-conveyor·onsen-claw·dessert-fridge). 아트 더 넣을 때 먼 소품부터 덜기.
- 현지화 B7: 영어 뽑기 등급 이름이 상점 등급과 같은 단어(Rare·Epic) — 사용자 결정(USER-TODO A1). 서버 한국어 폴백 값(`ProfileView.title`, MatchPhase `mapName`·`rule`) 정리는 선택.
- 게임패드 P3: 대기실 진입 때 자동 선택 없음, 마우스로 🛠·탈의실 둘 다 연 뒤 패드로 바꾸면 가려진 🛠가 맨 위, ⓘ 확률 상세 스크롤 불가, 음소거 버튼 도달 보장 없음, 10피트 여백으로 소개 배너 아래 요소가 내려감.
- QA 리포트 일부 Studio 체크리스트의 `forceMapPlan = { "<id>" }`(1~2개)는 `Rules.resolveForcedPlan`이 거절 → 랜덤 판. 3~4개를 넣어야 함(DEV-SETUP 3-13은 고쳐 둠).

### 다음 세션 첫 단계
1. **사용자 Studio 확인 결과 받기**: `docs/DEV-SETUP.md` 3-13(새 맵·맵 길이), 3-14(영어), 3-15(게임패드). Race 완주 45~55초·한 판 4~5분 실측(m5-40 AC9·AC12). 결과가 오면 planner가 수치·스펙, developer가 코드.
2. 사용자 결정·작업: 새 맵 소리 cue 14개 id, B7 영어 뽑기 등급 이름, Roblox 현지화 표 CSV 업로드(USER-TODO C5), 그 밖에 USER-TODO 전체.
3. 그 뒤 비공개 테스트 → 공개.

### worktree 정리 (`git worktree list`, 직접 지우지 않음)
- `.claude/worktrees/` 아래 63개 중 62개는 HEAD가 main에 들어가 있고 미커밋 변경이 없음 — 오늘 것(`m5-map-*` 6, `m5-len-a~d`, `m5-23-reqa`, `m5-26-i18n-p3`, `m5-12-console`)과 예전 것 모두 지워도 됨. 예: `git worktree remove .claude/worktrees/agent-aa677ba625334f9d2`.
- `agent-a7f8f95e5a59abaa6`(`reqa`)만 main에 없는 커밋 1개(`4a3f140`, origin/main을 합친 병합 커밋 — 새 내용 없음, m5-26은 p3로 main에 들어감). 지워도 잃는 것 없음.
- 사용자 콘셉트 이미지 `docs/귀여운 초밥 서바이벌 런 콘셉트 시트.png`는 추적 안 되는 파일 그대로(커밋하지 않음).

## 2026-10-14 — 콘셉트 스킨 2차·토핑·뽑기·고등어·버튼 편집 병합, 문서 반영

main `4229e9a` 기준. 문서 반영(docs-writer) 뒤 5단계: rojo OK · `stylua --check src tests tools` OK · selene 0/0/0 · `lune run tests` **1992 passed, 0 failed (134개 파일)** · luau-lsp 끝 코드 0. 스펙 m5-24·25·28·29·30·31·32·41 → `done`(문서 반영 끝). m5-23은 `in-qa` 그대로(재QA 리포트 없음).

### 오늘 main에 들어온 것
| 스펙 | 병합 커밋 | QA 리포트 |
|---|---|---|
| m5-24 젠가 소개 카메라 수정(QA B1) | `bd0209b` | `docs/qa/m5-24-map-art-pass-v2.md` (`KNOWN_INTRO_BUG` 비움) |
| m5-29 콘셉트 스킨 2차 4종(장어·성게·문어·유부) | `f47c428` | `docs/qa/m5-29-concept-skins-2.md` |
| m5-30 콘셉트 토핑 퀄리티(상한 47 → 70) | `44df7ce` | `docs/qa/m5-30-concept-topping-quality.md` |
| m5-31 🎫 우승자 뽑기(등급별 1/5/15/30/49, 꽝 없음, 특 스킨 9종, Studio 전부 입기, 프로필 v3, `tickets`, `DrawScreen`·`DrawScreenLayout`) | `8f700a4` | `docs/qa/m5-31-winner-ticket-draw.md` (재QA 절) |
| m5-32 고등어 초밥 [신선](전설 R$ 199 + 뽑기 전설, `CharacterAnimLogic.fishPose`·`FishRig`·`DollAnimator`, 화남·슬픔, `FishFlop`·`FishSplash`, 파츠 80, 이름표 4.8) | `c3a1977` + `1218c5b`(B3 "@_@" 높이) | `docs/qa/m5-32-fresh-mackerel.md` (재QA 절) |
| m5-41 터치 버튼 위치·크기 편집(⚙, `TouchLayoutLogic`, 프로필 `settings.touchLayout`) | `4229e9a` | `docs/qa/m5-41-touch-button-layout.md` |

### 남은 P3 (막지 않음 — 각 QA 리포트)
- m5-31: 재QA R1(상세 창 빈 곳 터치가 아래 카드로 샘)·R2(큰 미리보기가 이름·대사와 겹침)는 m5-32 브랜치에서 코드로 고침 — Studio 확인만 남음(DEV-SETUP 3-12 D·E). 단상이 2D 둥근 판(3D 원기둥 아님), compact 분기 `listPanel.Size` 두 번 설정(무해).
- m5-32: 근접 정면에서 분홍 혀가 "빨간 띠"처럼 보일 수 있음, 커진 고등어가 레이스 뒤 카메라 앞 시야를 조금 더 가림, 밥이 네모·김 띠가 시트보다 좁음. planner: 스펙 AC7 연속성 문구를 결정 기록(4차 R2) 기준으로 고치기.
- m5-41: B1 "Starting"(카운트다운) 잠금이 실제 이벤트 순서에서 안 걸림(`TouchLayoutController.luau` `if not inMatch or not was then phase = nil` — 고치면 `m5-41-qa` "편집 잠금" 기대값 `startingLocked`를 true로), B2 점프를 옮긴 뒤 "기본값으로" 미리보기가 노치 기기에서 실제 기본 자리와 조금 다름. AC12(점프 버튼이 되돌아가는지)는 Studio 실측 — 되돌아가면 자체 점프 버튼(D3).
- m5-30: B-V1 장어 정면·옆에서 타레가 얇은 뚜껑으로만 보이고 주황 살이 대부분(사용자 판단 뒤 다음 패스 — USER-TODO A1), B-D1 개발 메모 파츠 수 표·`SushiConceptSample.luau` NoriBack 주석 "띠 바깥(1.43)에 붙어"(실제 0.06 틈).
- m5-29: B1·B2는 m5-30에서 고쳐짐(QA 확인). B3 스펙 AC5 inari 예외 문구(MouthCover 색) — planner.
- m5-28: 새우 꼬리 넘어질 때 묻힘 가능, 휴대폰 뒤 카메라 참치 결, 연어알 Glass, `LayoutCheck.floating` 외곽 상자 기준.
- m5-25: 바짝 줌 때 몸 속 비침, 탈락 젓가락이 인형을 뚫음, 잡기 Beam 시작점, `VictoryCutsceneController.luau:33` `DEFAULT_GROUND_OFFSET = 2.3`(안 쓰이는 대비값, 실제 2.25).
- m5-24: B2 인형뽑기 연장전에 오락실 전체가 35° 기욺(planner·사용자 판단), B4·Q1 m5-20 안개 판 처리(planner), B3 방방 플레이어 시점은 렌더러로 못 봄.
- 코드 주석 어긋남(developer, 동작 영향 없음): `src/shared/SushiBody.luau:17` "concept-* 9종"(지금 `CONCEPT_BODY`는 고등어 포함 10), `src/shared/SushiConceptSample.luau:12` EXPRESSIONS 설명이 4종(지금 6종 — Angry·Sad).
- GDD(planner): 9.2 제목 "31종 구현됨"(지금 41), 9.6 제목 "스펙 ready — 개발 전"(지금 done), 6절 버튼 위치 편집 "개발 전"(지금 done), m5-25 QA가 짚은 6절 "밥 블록 + 김 띠" 옛 몸 설명.

### 다음 세션 첫 단계
1. **새 맵은 m5-33(맵 3차 기반)부터** — main에서(공용 `shared/maps/init.luau`·SfxCues·`MapFxPresets` 담당). m5-32가 이미 main에 있어서 `SfxCues` 충돌 걱정 없음. 그다음 m5-34~39를 worktree 6개로 병렬, 이어서 m5-40(맵 길이).
2. m5-26 현지화: 작업 브랜치(`m5-26-i18n-p2` 등)가 main에 없음 — QA P1 B1(방 이름 필터) 상태부터 확인. 병합하면 특 스킨 9종·고등어·뽑기·버튼 편집 문구의 CSV 키가 필요(각 스펙 AC17/AC19 "해당 없음"으로 넘어감).
3. m5-12 콘솔 UI(`ready`), m5-23 재QA.
4. 사용자 Studio 확인: `docs/DEV-SETUP.md` 3-12 A~F(맨 위 "리포트를 쓴 뒤 바뀐 점" — 콘셉트 스킨 이름 "(특)", 확률 1/5/15/30/49), 3-10·3-11, USER-TODO B1-1(Future)·B1-2(R15 고정)·C3(고등어 상품 R$ 199).

### 정리 안 된 worktree (`git worktree list`, 직접 지우지 않음)
- **오늘 끝나서 지워도 되는 것**(브랜치 HEAD가 main에 들어감, 미커밋 변경 없음): `.claude/worktrees/agent-ab9091411269b46ae`(m5-29-concept-skins), `.claude/worktrees/m5-30-quality`(m5-30-concept-topping-quality), `.claude/worktrees/agent-a6786423e039151fb`(m5-31-winner-ticket-draw), `.claude/worktrees/agent-a10906f098e1dcf01`(m5-32-fresh-mackerel), `.claude/worktrees/agent-ae4d1902cea6f9e79`(m5-41-touch-button-layout). 예: `git worktree remove .claude/worktrees/m5-30-quality`.
- 그 밖에 예전 worktree 39개도 HEAD가 main에 들어가 있음(m5-03~m5-10, m5-24-fix-jenga-cam, m5-25-character, work-concept-skin, `worktree-agent-*` 등) — 같이 지워도 됨.
- **main에 없는 것(지우지 말 것)**: `agent-a06f37e723d85815c`(`work`, m5-26 QA 수정·2단계 메모), `agent-a7f8f95e5a59abaa6`(`reqa`, m5-26 재QA — main 병합 + 콘셉트 스킨 현지화 키), `agent-a95d1bc4c017a1335`(wip m5-26 B1 restoreRoom 필터, 중단), `agent-ae9b5a68ebafe22b1`(m5-26 개발 메모), `agent-af28d14b6bfa74cd9`(m5-26 QA 리포트, P1 B1). 모두 m5-26 현지화 계열.

## 2026-10-13 밤 — m5-24·m5-28 QA 통과, main 병합

- `m5-24-merge`(4그룹 통합, QA 65a8fbc)와 `m5-28-concept-skins`(QA 12d293b)를 main에 병합. 병합 뒤 5단계: rojo OK · stylua OK · selene 0/0/0 · `lune run tests` **1842 passed, 0 failed** · luau-lsp 끝 코드 0. 두 스펙 `qa-passed`.
- QA 리포트: `docs/qa/m5-24-map-art-pass-v2.md`, `docs/qa/m5-28-concept-skins.md`.

### 특이사항 (남은 것)
- **P2 B1 giant-jenga 소개 카메라가 탑 앞줄 블록을 뚫음** (`GiantJengaArt.luau` 경유점 2→3). `tests/m5-24-qa.spec.luau`에 "알려진 버그"로 고정 — 고치면 그 항목 삭제. developer 몫.
- **P2 B2 claw-machine-prize 연장전 때 오락실 장식 554개가 상자와 같이 35° 기욺** (판정 영향 없음, 카펫이 낙하선 위로, 매 프레임 옮기는 파츠 ~900). 받아들일지 planner 결정.
- **planner Q1**: 예전 m5-20 안개 패널 처리 — soy·chef는 방 밖으로(D5), ramen은 국물 아래로 옮김(결정 기록 없음). 규칙("안개 패널 안 씀")과 맞는지 정하기.
- P3: 새우 꼬리 넘어질 때 묻힘 가능, 휴대폰 뒤 카메라에서 참치 결 안 보임(김 띠 없음으로만 연어와 구분), 연어알 Glass 재질 Future 조명 확인, 렌더러 "떠 있는 파츠" 검사가 외곽 상자 기준(회전 파츠 늘면 보강), bouncy 플레이어 시점 렌더 불가, hot-plate 플레이어 시점 왼쪽 큰 어두운 판(예전부터).
- 예산 빠듯: lantern-bridge 조명 23/24·움직임 73/80, bouncy-castle-maze 장식 1468/1500.
- 그룹 B·C·D 병합 커밋 일부에 Co-Authored-By 줄 빠짐(이미 push, 히스토리 안 고침).
- docs-writer 할 일: CLAUDE.md 현재 상태(m5-24 done, m5-28 콘셉트 스킨 4종·스킨 36종, 테스트 수), CHANGELOG. 앞 절의 m5-26 관련 문서 수정과 함께.
- **사용자 차례**: Studio 확인 — 맵은 QA 리포트 체크리스트(`forceMapPlans` 5판, 결승 `overtimeAt = 5`, 끝나면 nil), 스킨은 m5-28 QA 리포트 7개. 결정: 콘셉트 스킨 가격·등급·이름, 다음 묶음.

## 2026-10-13 저녁 (클라우드 세션 — m5-24 4그룹 + m5-28 콘셉트 스킨)

모두 각 브랜치에 push, **main에는 아직 병합 안 함**(QA 전). 클라우드 검증 5단계는 전부 통과.

| 작업 | 브랜치 · 커밋 | 테스트 | 다음 첫 단계 |
|---|---|---|---|
| m5-24 그룹 A (rotating-belt·hot-plate·skewer-showdown) | `m5-24-art-a` d5d2781 | 1795/0 | QA → main 병합 |
| m5-24 그룹 B (soy-swamp·chef-board·tug-of-war-platform) | `m5-24-art-b` 81f7bf3 | 1794/0 | QA → 병합 |
| m5-24 그룹 C (ramen-rapids·giant-jenga·claw-machine-prize) | `m5-24-art-c` 79a7807 | 1793/0 | QA → 병합 |
| m5-24 그룹 D (bouncy-castle-maze·lantern-bridge·cat-cafe-shelves) | `m5-24-art-d` 33b749f | 1794/0 | QA → 병합 |
| m5-28 콘셉트 스킨 4종(참치·새우·계란·연어알 군함, 무료 실험 스킨) | `m5-28-concept-skins` 68283e1 | 1800/0 | 스펙 `in-qa` → QA → 병합 |

### 특이사항
- **병합 충돌 예상: `tests/m5-23-qa.spec.luau`.** A·B·C가 같은 단언("기존 6개는 프리셋을 씀"·조명/파티클 고정 수)을 각자 다르게 고침. **A의 `artModule(id)` 방식(Art 모듈을 직접 읽음)을 기준으로** 합치고 B의 soy-swamp 수치 줄만 확인. 4그룹 다 병합한 뒤 검증 5단계 다시.
- 스펙 `m5-24-map-art-pass-v2.md` `status:` 줄은 그룹마다 ready/in-dev로 제각각 — 병합 담당이 한 번에 정리. 개발 메모 그룹 B·C·D 절은 스펙에 추가됨, A는 `docs/developer/m5-24-group-a.md`가 원본.
- **planner 확인 필요 (B, D5 제안)**: m5-20 안개 패널을 지우지 않고 방 벽 밖으로 옮김(soy ±680, chef ±312). 새 맵 규칙("안개 패널 안 씀")과 맞는지 결정.
- B: `TugOfWarPlatform.luau` 아트 부착부의 `p.CastShadow = false` 한 줄 삭제(장식 그림자 기본 규칙 적용). chef-board 방 반경 300으로 키움.
- C: claw-machine-prize는 연장전에 상자가 기울어 Spin/Sway 장식이 어긋나서 **Pulse만** 씀 → 스펙의 "미러볼 회전" 빠짐. 젠가 블록 모서리 장식은 판정 코드라 안 함, 망치 흔들림 → 앞치마 흔들림.
- D: lantern-bridge 입구 도리이 기둥이 m5-15부터 원기둥 축이 뒤집혀 원판이었음 → 고침(장식만). lantern 조명 23/24로 여유 1. 소개 카메라 점 좌표 변경(lantern ③, cat ②·③).
- A: hot-plate 후드 램프 PointLight 2 → SpotLight 2(왼쪽만 그림자). skewer 셰프를 화로 뒤(+Z 72)로, 장식이 반경 640까지 퍼짐(아레나 간격 2000 안). 렌더러 Neon 번짐이 Studio보다 셀 수 있음 — skewer 거리 창 밝기 Studio 확인.
- 렌더러 한계: bouncy 플레이어 시점은 렌더러 카메라가 출발 벽 뒤라 벽만 보임, cat-cafe overview는 천장이 없어 하늘이 보임(게임 카메라는 방 안).
- m5-28: concept-salmon은 리팩터 전후 레이아웃·렌더가 바이트 단위로 같음. m5-27 테스트 기대값 "실험 스킨 1종" → "정확히 5종", 카탈로그 32 → 36. 렌더 도구에 `--sample concept-<name>` 추가. Studio에서 연어알 Glass 재질(Future 조명)·새우 꼬리(꼭대기 2.69)가 넘어질 때 묻히는지 볼 것.
- **사용자 결정 대기 (m5-28)**: 콘셉트 스킨 5종 가격·등급(무료 테스트 유지 vs 판매 — 판매면 콘셉트 몸 검사 규칙 스펙 필요), "(테스트)" 이름 정리·기존 같은 초밥 스킨과 이름 구분, 다음 묶음(장어·성게·문어 등).
- **m5-26 현지화 병합 시**: 콘셉트 스킨 5종 이름·대사 CSV 키 추가 필요(새 4종은 이름 4 + 대사 8줄).
- **클라우드 환경 메모**: rokit 설치 스크립트가 403이라 5개 도구를 GitHub 릴리스 zip으로 직접 받아 `/root/.local/bin`에 둠. selene은 프록시 인증서 때문에 Roblox 표준 라이브러리를 못 받아 curl로 받은 `~/.cache/selene/roblox.yml` 캐시로 돌림(0.32.0 그대로). Windows 로컬은 해당 없음.
- Studio 확인(각 맵 AC12~15, 스킨 확인 순서)은 전부 아직 — 순서는 각 브랜치 `docs/developer/m5-24-group-<a~d>.md`, `docs/developer/m5-28-concept-skins.md`. `forceMapPlan(s)`는 확인 뒤 nil로.

## 2026-10-13 (사용량 한도로 중단)

main은 깨끗하고 push돼 있다(3ed86cb). 진행 중이던 일은 각자 브랜치에 wip로 push했다.

| 작업 | 브랜치 | 상태 | 다음 첫 단계 |
|---|---|---|---|
| m5-26 다국어 1·2단계 + 1단계 QA 수정 | `m5-26-i18n-p2` | 재QA 대부분 끝(e415e99): P0/P1 없음(잠정), 새 P3 B6. 회귀 테스트 추가만 남음 | QA 리포트 "재QA" 인계대로 `tests/m5-26-reqa.spec.luau` 추가 → 5단계 → `qa-passed` → main 머지(사용자 지시: QA 통과 시 머지) |
| m5-27 콘셉트 시트 캐릭터 샘플 (연어초밥 1개, 게임 코드는 안 바꿈) | `m5-27-character-concept` | 견본 완료(255abcb, aa09924), 사용자 검토 대기 | 사용자가 방향을 정하면 planner가 다음 스펙(기준 몸 교체, 31종, 표정 시스템, 팔). 이미지는 원할 때만 보여 줌 |
| m5-24 기존 맵 12개 아트 v2 | `m5-24-art-a`~`d` | 보류(사용자 지시: 맵 보류) | 각 브랜치 `docs/developer/m5-24-group-<a~d>.md` |
| m5-12 콘솔 UI | — | 시작 전 | 스펙 `ready` |

알아 둘 것:
- 사용자 콘셉트 이미지가 `docs/`에 추적 안 되는 파일로 있다. **커밋하지 말 것**(사용자가 작업 뒤 지움).
- 사용자 선호: 결과 페이지(아티팩트)는 사용자가 보고 싶다고 할 때만 띄운다. 맵 세부 판단은 메인 세션이 정하고 결정 기록에 남긴다.
- 출시 계획: 먼저 16세 이상 공개(비용 없음), 모든 연령은 나중(`docs/USER-TODO.md` 답변 기록).
- `tests/init.luau`는 실패가 있으면 끝 코드 1을 낸다. 일부 문서에 "실패가 있어도 0"이라고 적힌 곳은 틀린 설명이라 고쳐야 한다(CLAUDE.md 검증 절, DEV-SETUP 2절, README).
- m5-26 머지 뒤 docs-writer 할 일: CLAUDE.md 다국어 규칙(숫자 + 단위는 키 하나, 월드 글씨는 `WorldText.mark`, `Attributes.Title`은 숫자), DEV-SETUP(Player Emulator 언어), USER-TODO(번역 CSV 업로드, 자동 수집·자동 번역 켜기).
