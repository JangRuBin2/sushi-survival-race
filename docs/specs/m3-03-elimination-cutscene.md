status: done
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m3-03 — 탈락 연출 ("먹혔다!")

- 마일스톤: M3
- GDD 근거: `docs/GDD.md` §1.1(탈락이 벌이 아니라 볼거리), §7(젓가락 픽업 → 간장 → 냠! → 스탬프, 맵마다 다른 연출, 말풍선), §4(결과 → 연출 뒤 자동 관전)
- 참고: `docs/REFERENCE-party-royale.md` §3 (크고 두꺼운 결과 글씨, 과장된 래그돌 개그)
- 담당 개발 worktree: `m3-elimination` (Rojo 포트 34873)
- 공용 파일 수정 담당: 없음
- 의존: **m3-01 머지 후 시작**. 인형은 `SushiBody.build`를 쓴다 — m3-02 전에는 회색 박스로 보이고, m3-02 머지 뒤 자동으로 계란초밥이 된다.
- **이 스펙이 고치는 파일**: `src/client/fx/EliminationCutsceneController.luau`, 새 파일 `src/client/fx/EliminationCutsceneScreen.luau`(스탬프·말풍선 UI), 새 파일 `src/client/fx/CutsceneProps.luau`(젓가락·간장 종지·손님 입·셰프 손 회색 박스), 새 파일 `src/shared/EliminationCutsceneLogic.luau`(순수), 새 파일 `tests/elimination-cutscene.spec.luau`, `src/client/ui/HudController.luau`(내 탈락 문구 1곳)

## 목표
탈락하는 순간 3초 동안 초밥이 젓가락에 집혀 간장에 "퐁당" 찍히고 손님 입으로 "냠!" 들어가며 말풍선이 뜬다. 본인은 카메라로 크게 보고 "먹혔다!" 스탬프와 등수를 받는다. 주변 사람과 관전자 화면에서도 그 자리에서 먹히는 모습이 보여서, **남이 먹히는 걸 보는 게 웃기다**.

## 범위
- 포함:
  1. **누가 보나** — `PlayerResult`가 `Eliminated`이고 `cause`가 `"Fall"` 또는 `"Reset"`이며 `position`이 있으면, 방의 **모든 클라이언트가 그 위치에서 같은 연출을 월드에 로컬로 재생**한다. 카메라·스탬프는 **탈락한 본인만**. `cause = "Left"`(퇴장)는 연출 없음.
  2. **인형 방식** — 진짜 캐릭터는 서버가 고정해 둔다(M2 그대로). 각 클라이언트는 그 캐릭터를 로컬로 숨기고(`LocalTransparencyModifier = 1`) 같은 자리에 `SushiBody.build(캐릭터의 AppearanceId 또는 기본)` 인형을 만들어 움직인다. 연출이 끝나면 인형·소품을 지우고 캐릭터 숨김을 푼다(그 사이 캐릭터가 바뀌거나 사라졌으면 그냥 정리만).
  3. **연출 종류** — 순수 함수 `EliminationCutsceneLogic.variantFor(mapKind, isFinal, cause)`:
     | 상황 | 종류 | 흐름 (총 `Config.Match.EliminationCutscene` = 3초) |
     |---|---|---|
     | 결승(`roundIndex == roundCount`) | `ChefHand` | 셰프의 거대한 손이 내려와 인형을 움켜쥐고(`ChefHand`) 위로 끌고 사라짐 → 말풍선 |
     | 결승 아닌 Survival 맵에서 낙하 | `Mouth` | 인형이 아래에서 입 벌린 손님 입으로 떨어지고(`MouthFall`) 입이 닫힘 "냠!"(`Chomp`) → 말풍선 |
     | 그 밖(Race 낙하, 모든 리셋) | `Chopsticks` | 젓가락이 내려와 집음(`ChopstickClack`) 0~0.6초 → 들어 올려 버둥(`Struggle`) ~1.2초 → 간장 종지에 "퐁당"(`SoyDip`, 튀는 방울) ~1.8초 → 손님 입으로 "냠!"(`Chomp`) ~2.4초 → 말풍선 |
     `mapKind`·`roundIndex`·`roundCount`는 클라이언트가 마지막으로 받은 `MatchPhase`에서 읽는다.
  4. **말풍선** — 손님(또는 셰프) 쪽에 말풍선 하나(`SpeechPop`). 대사는 순수 함수 `EliminationCutsceneLogic.pickLine(appearanceId, variant, rng)`가 "공통 + 그 스킨 전용(+ `ChefHand`면 결승 전용)" 목록에서 고른다. 기본 대사(수정 가능):
     - 공통: "음~ 신선하네!", "와사비 좀 더 주세요", "한 접시 더!", "이 집 초밥 잘하네~", "냠냠, 꿀맛!"
     - `tamago` 전용: "계란초밥은 역시 달달해", "폭신폭신 계란 최고!"
     - 결승(`ChefHand`) 전용: "오늘의 마지막 접시!", "이건 내가 먹어야지~"
  5. **본인 카메라와 스탬프** — 탈락한 본인은 `CameraDirector.request("Elimination", Priority.Elimination, …)`로 인형을 비스듬히 위에서 크게 잡는 Scriptable 카메라를 3초 동안 쓰고, 끝나면 release한다 (그 뒤 m2-06 자동 관전이 이어짐). 화면 가운데에 빨간 도장 모양 **"먹혔다!"** 스탬프가 쾅 찍히고(`Eliminated`, 살짝 커졌다 작아지는 애니메이션) 그 아래 **"n등"**. 기존 HUD의 "🥢 탈락했어요… (n등)" 문구는 연출이 재생될 때 띄우지 않는다(스탬프가 대신함).
  6. **동시에 많이 떨어질 때** — 한 클라이언트에서 동시에 재생하는 월드 연출은 최대 6개(`EliminationCutsceneLogic.MAX_CONCURRENT`). 넘으면 그 사람은 월드 연출 없이 캐릭터만 숨겼다가 푼다. **본인 연출은 항상 재생**한다(한도에 포함하지 않음).
  7. **정리** — 매치가 끝나거나(`RoomUpdated` state ≠ InMatch / nil) `Victory`가 시작되면 재생 중인 연출을 모두 지우고 숨김을 되돌린다.
- 제외:
  - 스킨별 대사 확장·탈락 연출 팩(상점) — M4 이후
  - 서버 변경 (연출에 필요한 `cause`/`position`은 m3-01이 채움)
  - 관전자가 탈락한 대상을 3초 더 비추는 것 (m3-01 SpectateController)

## 수용 기준
### 순수 로직 (lune 테스트로 확인, `tests/elimination-cutscene.spec.luau`)
- [ ] AC1: `variantFor("Race", false, "Fall")` = `Chopsticks`, `variantFor("Survival", false, "Fall")` = `Mouth`, `variantFor("Survival", false, "Reset")` = `Chopsticks`, `variantFor("Final", true, "Fall")` = `ChefHand`, `variantFor("Race", true, "Reset")` = `ChefHand`.
- [ ] AC2: `shouldPlay(cause)`는 `Fall`·`Reset`이면 true, `Left`·nil이면 false.
- [ ] AC3: `pickLine("tamago", "Chopsticks", rng)`를 시드 1~200으로 돌리면 공통 대사와 tamago 대사가 둘 다 나오고, 목록 밖 문자열·결승 대사는 나오지 않는다. `pickLine("no-such-skin", "Chopsticks", rng)`는 공통 대사만 나온다. `pickLine("tamago", "ChefHand", rng)`는 결승 대사도 나온다.
- [ ] AC4: `canStartWorld(activeCount)`는 `activeCount < 6`일 때만 true.
- [ ] AC5: `lune run tests` 전체 통과.

### Studio 확인 (Clients and Servers 3명, `forceMapPlan`으로 맵 고정)
- [ ] AC6: 회전 벨트에서 A가 코스 밖으로 떨어지면 A 화면: 카메라가 A의 초밥을 크게 잡고 젓가락이 집어 → 버둥 → 간장 퐁당 → 손님 입 "냠!" → 말풍선이 3초 안에 이어지고, "먹혔다!" 스탬프와 "n등"이 뜬다. 기존 "탈락했어요" 문구는 겹쳐 뜨지 않는다. 연출이 끝나면 자동 관전이 시작된다.
- [ ] AC7: 같은 순간 B·C 화면(달리는 중이든 관전 중이든 A가 보이는 곳이면)에서도 A가 떨어진 자리에서 같은 연출이 보이고, 그 동안 A의 진짜 캐릭터는 안 보인다. B·C의 카메라는 바뀌지 않는다.
- [ ] AC8: 라운드 중 리셋으로 탈락하면 리셋한 자리에서 젓가락 연출이 나온다.
- [ ] AC9: 뜨거운 철판(결승 아닌 2라운드 이후로 배치)에서 맨 아래층에서 떨어지면 손님 입으로 떨어지는 `Mouth` 연출이 나온다.
- [ ] AC10: 결승(회전 꼬치 쇼다운)에서 떨어지면 셰프 손이 집어 가는 `ChefHand` 연출이 나온다.
- [ ] AC11: 매치 중 방을 나간 사람은 다른 화면에 연출이 나오지 않는다.
- [ ] AC12: 연출이 끝난 뒤 Workspace에 인형·젓가락·종지·입 소품이 남지 않는다 (클라이언트 Explorer). 연출 도중 우승이 결정돼도 남지 않는다.
- [ ] AC13: 휴대폰 에뮬레이터에서 스탬프·말풍선 글씨가 잘리지 않는다.

## 공용 파일 변경
- 없음 (읽기만: `Config.Match.EliminationCutscene`, `Types.PlayerResult.cause/position`, `Attributes.AppearanceId`, `CameraDirector`, `SfxCues`)

## 결정 기록
- 2026-10-08 · 연출을 누가 보나 · 방의 모든 클라이언트가 월드에서 보고, 카메라·스탬프는 본인만. 근거: GDD 1.1 "남이 먹히는 걸 보는 웃음". **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 연출 3종 · GDD 7의 "맵마다 다름"을 Race/리셋 = 젓가락, Survival 낙하 = 손님 입, 결승 = 셰프 손으로 묶음. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 대사 목록 · 위 9줄(어린 유저 대상이라 순한 표현). **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 동시 재생 한도 6 · 24명 1라운드에 한꺼번에 떨어질 때 성능 보호. **기본값으로 진행, 사용자 수정 가능** · planner

- 2026-10-08 · `cause = nil`(시간 종료·통과 인원이 다 차서 남은 사람 탈락)일 때 · 스펙 AC2대로 **연출 없음**. 본인 화면은 기존 HUD 문구 "🥢 탈락했어요… (n등)"가 그대로 뜨고, 캐릭터는 숨기지 않으며, 3초 뒤 자동 관전. 이 경우에도 연출을 넣으려면 m3-09에서 서버가 cause(예: `"Timeout"`)를 채우고 `EliminationCutsceneLogic.shouldPlay`에 추가하면 된다 (공용 `Types` 수정은 m3-09 몫). · developer
- 2026-10-08 · 본인인데 `position`이 nil(캐릭터 없음)일 때 · 스탬프와 등수만 띄우고 월드 연출·카메라는 생략. 다른 사람 화면에는 아무것도 안 나옴. · developer
- 2026-10-08 · 캐릭터 숨김 범위 · 진짜 캐릭터의 HumanoidRootPart가 탈락 위치에서 40스터드 안일 때만 숨김 (리셋 뒤 다른 곳에 새로 생긴 캐릭터를 숨기지 않으려고). · developer
- 2026-10-08 · Victory 단계에 도착한 탈락 결과 · 연출을 시작하지 않음 (범위 7의 "Victory가 시작되면 모두 지움"과 맞춤). HUD 문구도 낙하·리셋이면 생략하므로 이때는 본인 문구가 없다 — Victory 화면이 대신함. · developer

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
### 바뀐 파일 (브랜치 `m3-03-elimination`)
- `src/shared/EliminationCutsceneLogic.luau` (새, 순수): `shouldPlay`, `isFinalRound`, `variantFor`, `linesFor`/`pickLine`, `canStartWorld`(`MAX_CONCURRENT = 6`), `timeline`(효과음 박자, 3초 기준을 `Config.Match.EliminationCutscene`에 맞춰 늘림), `scaled`, `alpha`, `smooth`
- `src/client/fx/EliminationCutsceneController.luau`: 껍데기 → 실제 구현. PlayerResult(Eliminated + Fall/Reset) → 캐릭터 로컬 숨김 + `SushiBody.build` 인형 + 소품 애니메이션(RenderStepped), 박자마다 `Sfx.play`, `SpeechPop`에 말풍선. 본인은 `CameraDirector.request("Elimination", Priority.Elimination)` + 스탬프. 동시 월드 연출 6개 한도. RoomUpdated(InMatch 아님)·MatchPhase Victory에 전부 정리. 소품은 `Workspace.EliminationCutscenes/EliminationCutscene_<userId>`에 생김.
- `src/client/fx/CutsceneProps.luau` (새): 젓가락·간장 종지(+방울)·손님 입·셰프 손·말풍선 앵커 회색 박스와 pose 함수
- `src/client/fx/EliminationCutsceneScreen.luau` (새): "먹혔다!" 도장 스탬프(UIScale 쾅 애니메이션, TextScaled + 크기 제한) + "n등", BillboardGui 말풍선
- `src/client/ui/HudController.luau`: 본인 탈락이 낙하·리셋이면 "탈락했어요" 문구를 띄우지 않음
- `tests/elimination-cutscene.spec.luau` (새, 11개): AC1~AC4 + 박자·보간 헬퍼

### Studio 확인 방법
1. `Config.DEBUG.forceMapPlan`을 로컬에서만 `{ "rotating-belt", "hot-plate", "skewer-showdown" }`로 (커밋 금지). Test → Clients and Servers 3명.
2. AC6·AC7: 1라운드 회전 벨트에서 A를 코스 밖으로 떨어뜨림. A 화면 = 카메라가 인형을 비스듬히 위에서 잡고 젓가락 → 버둥 → 간장 퐁당(방울) → 손님 입 "냠!" → 말풍선, "먹혔다!" + "n등" 스탬프, HUD "탈락했어요" 없음, 3초 뒤 자동 관전. B·C 화면 = 같은 자리에서 같은 연출, A의 진짜 캐릭터 안 보임, 카메라 그대로.
3. AC8: 라운드 중 리셋(Esc → Reset) → 리셋한 자리에서 젓가락 연출.
4. AC9: 2라운드 뜨거운 철판에서 맨 아래로 떨어짐 → 아래에서 입이 벌리고 받아먹는 `Mouth` 연출.
5. AC10: 결승 회전 꼬치 쇼다운에서 떨어짐 → 셰프 손이 내려와 움켜쥐고 위로 사라짐 + 결승 대사 가능.
6. AC11: 매치 중 한 명이 방을 나감 → 다른 화면에 연출 없음.
7. AC12: 연출 뒤·우승 직후 각 클라이언트 Explorer에서 `Workspace.EliminationCutscenes`가 비어 있음.
8. AC13: Device 에뮬레이터(휴대폰)에서 스탬프·말풍선 글씨가 잘리지 않음.

### 남은 이슈
- 인형은 m3-02(`SushiBody`) 머지 전까지 회색 박스. 소리는 m3-08 머지 전까지 무음.
- 시간 종료·정원 마감 탈락(`cause = nil`)은 연출 없음 — 결정 기록 참고, 원하면 m3-09.
- 젓가락·입·셰프 손 위치는 월드 축(X, Y) 기준이라 벽 옆에서 떨어지면 소품이 벽에 묻힐 수 있음 (회색 박스 단계라 그대로 둠, M4 아트 때 재검토).
