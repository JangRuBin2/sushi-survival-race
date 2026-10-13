status: in-qa
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
- 2026-10-13 · D4 (질문, 확인 필요) 불꽃 위치: "부두 위 하늘" 대신 **인형 뒤 바다 위 낮은 곳** · 카메라를 바꾸지 않는다는 규칙과 부딪쳐요. 박수 장면 카메라는 수면 위 높이 6에서 인형을 26도 내려다봐서 수평선 위 하늘이 화면 맨 위 13%뿐이고, 부두는 카메라 뒤에 있어요. 하늘에 띄운 시안을 `tools/render`로 그려 보니 불꽃이 작고 위가 잘리고 밝은 하늘에 묻혔어요. 그래서 수면 위 2.5~3.5에서 좌우로 번갈아 터뜨려 화면 위쪽 1/3을 채우고, 파란 바다를 배경으로 색을 살렸어요(불티가 바다로 흘러내림). 진짜 "하늘 높이"를 원하면 불꽃놀이일 때만 박수 카메라를 조금 들어 올려야 해서 기획 결정이 필요해요 · 개발 판단, planner·사용자 확인 대기 · developer
- 2026-10-13 · D5 (해석) Chopsticks "젓가락은 고양이 발로 집고" → 젓가락은 그대로 두고 **고양이 발(주황 털 + 분홍 발바닥)이 젓가락 위쪽을 쥐어요**. 흐름(집기·간장·입)이 그대로 보이게. 젓가락 없이 발로만 집기를 원하면 알려 주세요 · developer
- 2026-10-13 · D6 (해석) ChefHand 변형에는 Chomp 박자가 없어서, CatMeow는 `ChefHand` 박자(앞발이 내려오기 시작, 0초) 뒤 0.12초(3초 기준)에 울려요 (AC3의 "또는 ChefHand 박자") · developer
- 2026-10-13 · D7 불꽃 색 5가지 중 "하늘색" 대신 **산호색**: 뒤가 파란 바다라 하늘색이 묻혀서 바다와 대비되는 금·분홍·산호·연두·보라로 · developer

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
2026-10-13 · developer · 브랜치 `m5-09-fx` (commit 75467c9~)

### 바뀐 파일 (스펙 목록 안만, 공용 파일 변경 없음)
- `src/shared/EliminationCutsceneLogic.luau` — `skinFor(fxId)`(FxCatalog로 slot 확인), `CAT_LINES`, `linesFor/pickLine`의 선택 인자 `fxSkin`(고양이면 고양이 대사 3개만), `timeline(variant, duration, fxSkin)`(고양이면 `Chomp`/`ChefHand` 뒤 0.12×(길이/3)초에 `CatMeow` 하나 끼움, 나머지 박자 그대로). 인자를 안 주면 지금과 똑같아요.
- `src/client/fx/CutsceneProps.luau` — `catChopsticks/poseCatChopsticks`(발이 쥔 젓가락), `catHead/poseCatHead`(주황 머리, 네모를 45도 돌려 반만 내민 세모 귀 + 분홍 속귀·가끔 쫑긋, 눈·하이라이트, 볼터치, "ω" 주둥이 두 개, 분홍 코, 수염 4가닥, 둥근 송곳니, 분홍 혀, 주로 아래턱이 벌어짐), `catPaw/poseCatPaw`(둥근 발바닥 + 줄무늬 팔, 발가락 4개 + 분홍 젤리 4개 + 큰 젤리, 쥘 때 흰 발톱이 쏙). 기본 소품과 같은 pose 인자. WedgePart는 안 써요(방향 착오 위험).
  - 파츠 수(말풍선 자리·간장 방울 포함): Chopsticks 39(기본 19 + 20), Mouth 24(기본 7 + 17), ChefHand 18(기본 8 + 10) — 모두 기본 + 20 이하. Chopsticks는 한도에 딱 맞아서 고양이 얼굴에 파츠를 더하려면 다른 걸 빼야 해요.
- `src/client/fx/EliminationCutsceneController.luau` — 탈락한 **사람의** `EliminationFx` 속성을 읽어(나갔으면 기본) 세 변형 함수에 `cat`을 넘겨 소품·pose만 바꿈. 고양이는 다 먹은 뒤 오물오물, 말풍선 자리가 조금 더 위.
- `src/shared/VictoryCutsceneLogic.luau` — `extraFor(fxId)`, `fireworksTimeline(duration)`(풍덩+0.05 ~ 길이−0.34, 같은 간격 0.432초), `fireworks(duration)`(시각·자리·반지름·색 번호), `FIREWORK_COLORS`(금·분홍·산호·연두·보라), `fireworkColor`, `rocketAlpha`(로켓 0.45초, 풍덩 전엔 안 쏨), `flash`(0.3초 섬광·조명 곡선).
- `src/client/fx/VictoryProps.luau` — `buildFireworks`(ParticleEmitter **3개**·PointLight **2개**·로켓 2개(Neon + Trail)·섬광 공 1개), `burstFirework`(이미터 돌려 쓰기, 흰빛 → 색 → 어두워지는 색, 끝에 깜빡이는 크래클, 버드나무처럼 늘어짐, 바깥 꽃 + 안쪽 작은 꽃 두 겹), `poseRocket/poseFlash/poseGlow`(빛은 인형 쪽으로 끌어와 물·인형·물고기를 물들임). 불티 텍스처는 내장 `rbxasset://textures/particles/sparkles_main.dds`.
- `src/client/fx/VictoryCutsceneController.luau` — 우승자의 `VictoryFx`가 불꽃놀이면 장면에 불꽃 소품을 지어 매 프레임 `updateFireworks`. 터질 때마다 `Sfx.play("Fireworks")`(2D). 장면·박자·카메라·물고기·순위표는 그대로, 장면 Model째 지워져서 남는 것 없음.
- 테스트: `tests/elimination-cutscene.spec.luau`(+4: AC1·AC2 두 개·AC3), `tests/victory-cutscene.spec.luau`(+5: AC1·AC4·색 순환·**화면 안 확인**(박수 카메라로 투영해서 화면 안·수면 위·인형 머리보다 위)·로켓/섬광).

### 검증 (2026-10-13, 로컬 Windows)
`rojo build` OK · `stylua --check` OK · `selene` 0 errors/0 warnings · `lune run tests` **1272 passed / 0 failed** · `luau-lsp analyze` exit 0.
모습은 `tools/render`(m5-23)로 고양이 소품 3종과 불꽃 구도를 PNG로 그려 보며 다듬었어요(임시 스크립트, 커밋 안 함). 렌더러는 실제 Roblox와 다르고 파티클 버스트는 근사라서 최종 판단은 Studio에서.

### Studio 확인 방법 (AC6~AC10)
1. `Config.DEBUG.forceMapPlan`에 Race·Survival·Final 맵을 하나씩 넣어요(예: `{ "rotating-belt", "hot-plate", "skewer-showdown" }`). 커밋하지 말 것.
2. Play(혼자) 또는 Test → Clients and Servers(2명). 서버 쪽 명령줄(Server로 바꾼 Command Bar)에서:
   ```lua
   for _, p in game.Players:GetPlayers() do p:SetAttribute("EliminationFx", "cat-customer") p:SetAttribute("VictoryFx", "fireworks") end
   ```
   한 사람만 확인하려면 `game.Players.Player1:SetAttribute(...)`. 끄려면 `SetAttribute("EliminationFx", nil)`. (m5-08이 머지되면 서버가 장착에 맞춰 이 속성을 덮어쓸 수 있어요 — 그 뒤엔 상점에서 가짜 결제로 사서 입기.)
3. AC6: Race에서 떨어지기 → 고양이 발이 젓가락을 쥐고 집어 간장에 찍은 뒤 고양이 얼굴이 "냠!", 말풍선은 "냥~ 신선하다냥!"·"생선은 역시 최고냥"·"한 접시 더 달라냥!" 중 하나. Survival에서 떨어지기 → 아래에서 고양이가 입을 벌려 받아먹고 오물오물. 결승에서 떨어지기 → 줄무늬 앞발이 내려와 발톱을 내밀며 움켜쥐고 위로.
4. AC7: 2명 중 Player1에만 속성을 달고, Player1이 떨어질 때 Player2 화면에도 고양이, Player2가 떨어질 때는 지금 연출.
5. AC8: 불꽃놀이를 입은 사람이 우승 → 다이빙(풍덩) 뒤 인형 뒤 바다 위에서 6번(좌·우 번갈아, 마지막 가운데 큰 금색) 터짐, 로켓 꼬리·섬광·물이 색으로 물듦. 두 화면 모두 같은 장면. 안 입은 사람 우승은 지금 그대로.
6. AC9: 탈락 3초 뒤 관전으로, 우승 단계 10초 그대로. 끝난 뒤 Explorer의 `Workspace.EliminationCutscenes`가 비어 있고, `VictoryCutscene` 모델이 없어야 해요.
7. AC10: 4명 이상 Clients and Servers에서 모두 고양이를 입고 한꺼번에 떨어지기(동시 6개 한도) → 프레임 체감.
8. 소리: `CatMeow`·`Fireworks`는 아직 무음(USER-TODO A2). id를 넣으면 고양이는 Chomp 직후, 불꽃은 터질 때마다.

### 남은 이슈·질문
- D4(불꽃 위치) 확인 필요 — 기획이 "부두 위 높은 하늘"을 꼭 원하면 불꽃놀이일 때만 박수 카메라를 바꾸는 후속 스펙이 필요해요.
- 첫 불꽃(풍덩 +0.05초)은 아직 옆 카메라(다이빙)라 화면 밖이에요. 불티가 1초 넘게 남아서 카메라가 돌아오면 보여요. 스펙의 "풍덩부터 6번, 간격 0.4초 이상, 5.7초까지"를 지키면 피할 수 없어요.
- 마지막 불꽃의 불티는 연출이 끝나는 6초에 장면과 함께 사라져요(그때 카메라가 로비로 바뀌어서 눈에 띄지 않음).
- `Sfx`의 같은 cue 간격 제한은 지금 코드에선 0.05초(스펙 문구의 0.4초와 다름) — 불꽃 간격이 0.43초라 어느 쪽이든 매번 울려요.

