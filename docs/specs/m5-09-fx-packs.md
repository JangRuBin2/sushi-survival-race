status: ready
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-09 — 연출 팩 비주얼: 고양이 손님(탈락)·불꽃놀이(우승)

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §7(탈락 연출 3종·말풍선·"탈락 연출 팩(고양이 손님, 상어 손님 등)은 M5 상품"), §8(우승 연출·"우승 연출 팩(불꽃놀이, 고래 타고 퇴장 등)은 M5 상품"), §9.1(겉모습만)
- 레퍼런스: [`docs/REFERENCE-roblox-monetization.md`](../REFERENCE-roblox-monetization.md) 8.1(탈락·처치 연출은 로블록스에서 파는 코스메틱 — Epic Minigames "death", Arsenal "kill effect")
- 담당 개발 worktree: `m5-fx` (Rojo 포트 34877)
- 공용 파일 수정 담당: 없음 (`FxCatalog`, Player 속성 `EliminationFx`·`VictoryFx`, `CatMeow`·`Fireworks` cue는 m5-03)
- 의존: **m5-03 머지 후 시작**. 연출 소유·장착·속성 달기는 m5-08(병렬) — 이 스펙은 **속성을 읽어 모습만 바꿔요**. m5-08 전에는 Studio에서 속성을 손으로 달아 확인.
- **이 스펙이 고치는 파일**: `src/shared/EliminationCutsceneLogic.luau`, `src/client/fx/EliminationCutsceneController.luau`, `src/client/fx/EliminationCutsceneScreen.luau`(필요하면), `src/client/fx/CutsceneProps.luau`, `src/shared/VictoryCutsceneLogic.luau`, `src/client/fx/VictoryCutsceneController.luau`, `src/client/fx/VictoryProps.luau`, 테스트 `tests/elimination-cutscene.spec.luau`(추가), `tests/victory-cutscene.spec.luau`(추가)

## 목표
고양이 손님 연출을 입은 사람이 먹히면, 방 사람 모두가 **고양이 손님**이 그 초밥을 먹는 모습을 본다("냥!"). 불꽃놀이 연출을 입은 사람이 우승하면 바다로 뛰어드는 장면 하늘에 **불꽃놀이**가 터진다. 길이·흐름·카메라는 그대로라 게임 진행은 똑같다.

## 규칙
### 어느 연출을 쓸지
- 탈락 연출을 재생하는 모든 클라이언트가 **탈락한 사람의** Player 속성 `EliminationFx`를 읽어요(그 사람이 이미 나갔으면 기본). 우승 연출은 **우승자의** `VictoryFx`.
- 속성 값이 `FxCatalog`에 없거나 slot이 다르면 기본 연출(지금 그대로). 클라이언트는 속성으로 **보여 주기만** — 소유 판단은 서버(m5-08)가 속성을 달 때 했어요.
- 순수 함수: `EliminationCutsceneLogic.skinFor(fxId?) -> "Default" | "Cat"`, `VictoryCutsceneLogic.extraFor(fxId?) -> "None" | "Fireworks"`.

### 고양이 손님 (`cat-customer`, 탈락)
- 연출 3종(`Chopsticks`·`Mouth`·`ChefHand`)의 **흐름·박자·길이(3초)는 그대로**, 먹는 쪽 모습만 바꿔요:
  | 변형 | 기본 | 고양이 손님 |
  |---|---|---|
  | Chopsticks | 젓가락 → 간장 종지 → 손님 입 | 젓가락은 고양이 발(주황 털 + 분홍 발바닥)로 집고 → 간장 종지 → **고양이 얼굴**(주황, 세모 귀, 수염, 입) "냠!" |
  | Mouth | 아래 손님 입 | 아래에서 **고양이 입**(분홍 혀·송곳니 둥글게)이 벌림 |
  | ChefHand | 셰프 손 | **커다란 고양이 앞발**이 내려와 움켜쥠 |
- 말풍선: 고양이 전용 대사 중 하나 — "냥~ 신선하다냥!", "생선은 역시 최고냥", "한 접시 더 달라냥!" (스킨 전용·결승 전용 대사 대신. `linesFor(appearanceId, variant, fxSkin)`에 고양이면 이 목록).
- 효과음: `Chomp` 박자 바로 뒤에 `CatMeow` 한 번(무음이면 없음).
- 소품은 `CutsceneProps`의 기존 소품과 같은 방식(클라이언트 로컬 파츠, 충돌 없음, 연출 끝나면 정리). 파츠 수는 기본 소품 + 20 이하.

### 불꽃놀이 (`fireworks`, 우승)
- 우승 연출 6초 중 **다이빙(풍덩) 박자부터 끝까지**, 부두 위 하늘에서 불꽃 **6번** 터짐(색 5가지 돌아가며, 파티클 버스트 + 짧은 PointLight 0.3초). 박자 `VictoryCutsceneLogic.fireworksTimeline(duration)` — 연출 시작 기준 초 목록, 전부 [풍덩 시각, duration − 0.3] 안, 간격 0.4초 이상.
- 효과음: 터질 때마다 `Fireworks`(같은 소리 0.4초 간격 제한은 `Sfx` 규칙 그대로).
- 카메라·물고기 박수·순위표는 그대로. 방 전원이 같은 불꽃을 봐요(로컬 장면이 같은 박자로 재생).
- 파티클 한도: 불꽃 소품 파티클 이미터 3개 이하(재사용), 조명 2개 이하.

## 범위
- 포함: 위 두 연출, 속성 읽기, 대사·박자 순수 로직.
- 제외: 판매·장착·속성 달기(m5-08), 다른 팩(상어 손님·고래 타고 퇴장 — 후속), 연출 미리보기 버튼(탈의실·상점에서 재생), 본인 탈락 화면 도장·카메라 변경.

## 수용 기준
### 순수 로직 (lune 테스트)
- [ ] AC1: `skinFor("cat-customer") == "Cat"`, `skinFor(nil)`·`skinFor("fireworks")`(slot 다름)·`skinFor("x") == "Default"`. `extraFor("fireworks") == "Fireworks"`, 그 밖은 `"None"`.
- [ ] AC2: 고양이면 `linesFor`가 고양이 대사 3개만 돌려주고(결승 ChefHand여도), 기본이면 지금 대사 규칙 그대로(기존 테스트 통과).
- [ ] AC3: `timeline(variant, 3)`은 고양이여도 길이·박자가 기본과 같고, `CatMeow`가 `Chomp`(또는 ChefHand 박자) 뒤 0.3초 안에 한 번 더해진다.
- [ ] AC4: `fireworksTimeline(6)`이 6개, 전부 풍덩 시각 이상·5.7 이하, 간격 ≥ 0.4, 오름차순.
- [ ] AC5: 검증 5단계 통과.

### Studio 확인 (사용자 확인 필요)
설정: m5-08 전이면 Studio 명령줄(Server)에서 `game.Players.<이름>:SetAttribute("EliminationFx", "cat-customer")`, `SetAttribute("VictoryFx", "fireworks")`. m5-08 뒤면 상점에서 (가짜 결제로) 사서 입기. `forceMapPlan`으로 Race·Survival·결승을 한 번씩.
- [ ] AC6: Race에서 떨어지면 고양이 발이 집어 간장에 찍은 뒤 고양이 얼굴이 "냠!", 말풍선이 고양이 대사. Survival 낙하는 아래 고양이 입, 결승은 고양이 앞발.
- [ ] AC7: 2명 테스트에서 고양이 연출을 입은 사람이 먹히면 **다른 사람 화면에도** 고양이로 보이고, 안 입은 사람은 지금 연출 그대로.
- [ ] AC8: 불꽃놀이를 입은 사람이 우승하면 다이빙 뒤 하늘에 불꽃이 6번 터지고, 2명 모두 같은 장면을 본다. 안 입은 사람 우승은 지금 그대로.
- [ ] AC9: 연출 길이가 바뀌지 않는다(탈락 3초 뒤 관전으로, 우승 단계 10초). 연출 뒤 고양이·불꽃 소품이 남지 않는다(Explorer).
- [ ] AC10: 한 화면에 고양이 탈락 연출 여러 개(동시 6개 한도)가 겹쳐도 프레임이 크게 떨어지지 않는다(친구 테스트 체감).

## 공용 파일 변경
- 없음

## 사용자 작업
- `CatMeow`·`Fireworks` 소리 id(USER-TODO A2). 고양이·불꽃 모습이 마음에 드는지(친구 테스트).

## 결정 기록
<!-- 날짜 · 질문 · 결정 · 누가 -->
- 2026-10-08 · D1 첫 연출 팩 2개 · GDD 7·8의 예시 중 탈락 "고양이 손님"(먹는 쪽만 바꿔서 3변형 모두 적용 가능), 우승 "불꽃놀이"(기존 장면 위에 얹기만 하면 됨)를 먼저. 상어 손님·고래 타고 퇴장은 장면 구조가 달라 후속 · planner
- 2026-10-08 · D2 흐름·길이 그대로 · 연출 길이는 서버 진행(탈락 3초 뒤 관전, 우승 10초)과 묶여 있어서 팩이 바꾸면 안 됨. 겉모습만 바꿔 Pay-to-Win·진행 차이 없음(GDD 9.1) · planner
- 2026-10-08 · D3 고양이 대사가 스킨 대사보다 우선 · 먹는 쪽이 고양이라 말투를 맞춤. 스킨 전용 대사는 기본 연출에서 그대로 · **기본값, 사용자 수정 가능** · planner

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
