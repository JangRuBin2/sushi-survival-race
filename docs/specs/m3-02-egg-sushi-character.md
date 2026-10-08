status: done
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m3-02 — 계란초밥 캐릭터 (`applyAppearance`) · 걷기/넘어짐 연출

- 마일스톤: M3
- GDD 근거: `docs/GDD.md` §6(캐릭터 몸: 밥 블록 + 토핑, 넘어짐 1초, 모든 스킨 히트박스·속도 동일), §9.1(기본 스킨 계란초밥), CLAUDE.md "캐릭터 외형 적용 지점은 `applyAppearance` 한 곳"
- 참고: `docs/REFERENCE-party-royale.md` §3 (Bro Falls 음식 캐릭터, Fall Guys 래그돌 개그)
- 담당 개발 worktree: `m3-character` (Rojo 포트 34872)
- 공용 파일 수정 담당: 없음
- 의존: **m3-01 머지 후 시작**
- **이 스펙이 고치는 파일**: `src/shared/SushiBody.luau`, `src/server/AppearanceService.luau`, `src/client/fx/CharacterFxController.luau`, 새 파일 `tests/sushi-body.spec.luau`

## 목표
모든 플레이어가 로비와 매치에서 똑같은 크기의 **계란초밥**(밥 블록 + 계란 토핑 + 김 띠 + 눈)으로 보인다. 움직이면 통통 튀고, 넘어지면 버둥거려서 보기만 해도 웃기다. 나중에 스킨이 붙을 수 있게 외형은 `applyAppearance` 한 곳에서만 입힌다.

## 범위
- 포함:
  1. **`SushiBody`** (shared, 서버 캐릭터와 클라이언트 연출 인형이 같이 씀):
     - `SushiBody.layout(appearanceId: string): { PartSpec }` — **순수 함수**. 파츠 이름·크기·색·재질·`Body` 기준 오프셋(CFrame 성분)을 돌려준다. 지금은 `"tamago"` 하나, 모르는 id면 `"tamago"`로.
     - `SushiBody.build(appearanceId: string): Model` — layout대로 파츠를 만들고 서로 용접한 Model. PrimaryPart = `Body`. 연출(m3-03, m3-05)이 이 함수로 "인형"을 만든다.
     - 계란초밥 생김새 (기본값, 수정 가능): **세워진 초밥** — 흰 밥 블록(몸통, 폭 약 2.4 × 높이 3 × 두께 1.8), 그 위와 등을 덮는 노란 계란(약 2.8 × 0.8 × 2.2, 살짝 둥글게 `SmoothPlastic`), 가운데를 두르는 검은 김 띠, 앞면(-Z)에 까만 눈 2개 + 작은 입, 아래에 짧은 발 2개. 전체 외곽은 **지금 휴머노이드 히트박스 높이(약 5 studs)·폭에 맞춘다** — 꼬치 높이처럼 M2 맵이 맞춰 둔 판정 감각이 바뀌지 않게.
  2. **`AppearanceService.applyAppearance(character, appearanceId?)`** — 외형을 입히는 **유일한 함수**:
     - 캐릭터의 원래 몸 파츠·얼굴·액세서리를 안 보이게 하고(`Transparency = 1`, 얼굴 decal 제거), `SushiBody`로 만든 파츠를 `HumanoidRootPart`에 용접한다.
     - 초밥 파츠는 `Massless = true`, `CanCollide = false`, `CanQuery = false`, `CanTouch = false` — **히트박스·물리·맵 판정은 지금 휴머노이드 그대로**다 (모든 스킨이 같음).
     - 캐릭터에 `AppearanceId` 속성(`shared/Attributes.luau`)을 단다. 같은 캐릭터에 두 번 불러도 파츠가 두 벌 생기지 않는다(이미 있으면 바꿔 끼움).
     - `appearanceId`가 nil이면 `Config.Appearance.Default`. 모든 `CharacterAdded`(첫 스폰·리스폰)에서 서버가 부른다.
     - 이름표(DisplayName)는 머리 위에 그대로 보인다.
  3. **`CharacterFxController`** (클라이언트, 보이는 모든 초밥 캐릭터에 로컬로 적용 — 판정과 무관):
     - **걷기 통통**: 땅 위에서 움직이면 초밥 파츠가 위아래로 살짝 튀고 좌우로 기우뚱한다 (속도에 비례, 서 있으면 멈춤).
     - **넘어짐 버둥**: 캐릭터 Humanoid가 `PlatformStand`인 동안(날치알 공·꼬치에 맞음 = GDD 6 넘어짐 1초) 초밥 파츠가 옆으로 눕고 바르르 떤다. 머리 위에 "@_@" 같은 어지러움 표시. 시작할 때 `Sfx.play("Knockdown", 그 캐릭터의 HumanoidRootPart)` 한 번.
     - 탈락 연출로 숨겨진 캐릭터(m3-03이 로컬로 숨김)에는 아무것도 하지 않는다.
- 제외:
  - 다른 스킨, 탈의실, 상점 (M4 이후 — CLAUDE.md "스킨은 마지막")
  - 진짜 래그돌 물리 (GDD 13: 래그돌은 클라 연출로 충분)
  - 다이브 자세 (m3-06), 잡기 표시 (m3-07)

## 수용 기준
### 순수 로직 (lune 테스트로 확인, `tests/sushi-body.spec.luau`)
- [ ] AC1: `SushiBody.layout("tamago")`에 `Body`(밥), 계란, 김 띠, 눈 2개가 있고 이름이 겹치지 않는다.
- [ ] AC2: layout 전체 외곽(바닥~꼭대기)이 높이 4.5~5.5, 폭 3.2 이하, 두께 3.2 이하다.
- [ ] AC3: `SushiBody.layout("no-such-skin")`은 `"tamago"`와 같은 결과다.
- [ ] AC4: `lune run tests` 전체 통과.

### Studio 확인
- [ ] AC5: 혼자 F5 — 로비에서 내 캐릭터가 계란초밥으로 보이고 로블록스 아바타 몸·옷·액세서리가 안 보인다. 1인칭으로 줌인했을 때 초밥 파츠가 화면을 가리지 않거나, 가려도 1인칭 기본 동작(내 몸 숨김)과 같다.
- [ ] AC6: 리셋해서 리스폰해도 다시 계란초밥이고, 서버 Explorer에서 캐릭터 아래 초밥 파츠가 한 벌만 있다. 캐릭터 `AppearanceId` = `"tamago"`.
- [ ] AC7: 2명(Clients and Servers) — 서로 상대가 계란초밥으로 보이고 이름표가 머리 위에 있다. 서버 Command bar로 두 캐릭터의 `HumanoidRootPart.Size`와 `Humanoid.HipHeight`가 같다.
- [ ] AC8: 걸으면 초밥이 통통 튀고, 멈추면 가만히 있다. 다른 사람 화면에서도 내가 튀며 걷는 게 보인다.
- [ ] AC9: 간장 늪의 날치알 공이나 꼬치 쇼다운의 꼬치에 맞아 넘어지면 초밥이 옆으로 누워 떨고 "@_@"가 뜨며, 약 1초 뒤 일어나면 원래대로 돌아온다.
- [ ] AC10: (회귀) 4개 맵을 `forceMapPlan`으로 한 번씩 돌았을 때 결승선 통과·낙하 탈락·철판 타일 밟기·젓가락 포획·와사비 튕김이 M2와 같게 동작한다 (초밥 파츠가 판정에 끼지 않음).

## 공용 파일 변경
- 없음 (`Config.Appearance.Default`, `Attributes.AppearanceId`, `SfxCues.Knockdown`은 m3-01이 이미 만듦 — 읽기만)

## 결정 기록
- 2026-10-08 · 히트박스 · 초밥은 보이기만 하는 파츠이고 히트박스는 지금 휴머노이드 그대로(M2 맵 판정 감각 유지). 초밥 외곽을 히트박스 크기에 맞춤. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 생김새 · 세워진 계란초밥(밥 몸통 + 계란 지붕 + 김 띠 + 눈 + 짧은 발). 회색 박스 단계라 단순 파츠로. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 걷기·넘어짐 · 애니메이션 에셋 없이 클라이언트에서 초밥 파츠를 흔드는 방식(Studio 에셋 의존 없음, CLAUDE.md 맵 원칙과 같음) · planner
- 2026-10-08 · 같은 히트박스 보장 · 아바타 체형(scale)이 사람마다 달라 HRP·HipHeight가 달라질 수 있어서, `AppearanceService`에서 `StarterPlayer.LoadCharacterAppearance = false` + 플레이어마다 `CanLoadCharacterAppearance = false`로 기본 체형만 쓰게 함 (AC7, GDD 6 "모든 스킨 히트박스 동일"). 숨김 처리(Transparency 1, 얼굴 decal 제거, 늦게 붙는 파츠도 숨김)는 그대로 둠. 아바타 외형을 다시 불러와야 하면 이 두 줄만 빼면 됨 · developer
- 2026-10-08 · 초밥을 붙이는 관절 · `Body`를 `HumanoidRootPart`에 `Motor6D`(`SushiJoint`)로 붙이고, 클라이언트 연출은 `Motor6D.Transform`만 로컬로 바꿈 (복제되지 않고 판정과 무관). 초밥 Model 이름은 `SushiBody`. 공용 상수 파일(Attributes)을 못 고쳐서 이름은 `AppearanceService.MODEL_NAME/JOINT_NAME`과 `CharacterFxController` 안 상수로 두 번 적음 — m3-09에서 공용 상수로 옮길지 결정 · developer
- 2026-10-08 · 외곽 크기 · 계란초밥 높이 4.7(발 0.7 + 밥 3.2 + 계란 0.8), 폭 2.8, 두께 약 2.3. Body 중심은 발바닥에서 2.3 위(`SushiBody.GROUND_OFFSET`), 휴머노이드 발바닥(R15: HipHeight + HRP 높이/2, R6: 3)에 맞춰 붙임 · developer

## 개발 메모
- 바뀐 파일
  - `src/shared/SushiBody.luau` — `layout`(파츠 9개: Body, Egg, EggBack, Nori, EyeLeft/Right, Mouth, FootLeft/Right), `bounds`, `GROUND_OFFSET`, `build`(WeldConstraint로 Body에 용접, Body만 Anchored, 모두 Massless·충돌/쿼리/터치 없음, 원점에 만들어짐 → `PivotTo`로 옮김)
  - `src/server/AppearanceService.luau` — `applyAppearance`: AppearanceId 속성, 기존 `SushiBody` 있으면 지우고 다시 붙임, 원래 몸·액세서리·decal 숨김(늦게 붙는 것도 `DescendantAdded`로 숨김), `SushiJoint` Motor6D로 HRP에 붙임. CharacterAdded마다 HRP를 기다렸다가 호출. 아바타 외형 로딩 끔(결정 기록).
  - `src/client/fx/CharacterFxController.luau` — RenderStepped에서 모든 플레이어 캐릭터의 `SushiJoint.Transform`을 바꿈. 걷기: 위치 변화로 속도 계산(다른 사람도 같음), 수평 속도 > 1이고 위아래 속도 < 4일 때 |sin| 통통 + 좌우 기우뚱. 넘어짐: `PlatformStand`이고 살아 있으면 바닥(레이캐스트)에 옆으로 누워 떨고 "@_@" BillboardGui(로컬), 시작할 때 `Sfx.play("Knockdown", HRP)`. Body의 `LocalTransparencyModifier ≥ 0.99`(m3-03 숨김)면 다른 사람 캐릭터는 Transform을 원래대로 두고 아무것도 안 함 (내 캐릭터의 1인칭 숨김일 때는 소리만 남김).
  - `tests/sushi-body.spec.luau` — 7개 (AC1~AC3, GROUND_OFFSET, 복사본)
- Studio 확인 방법
  - AC5·AC6·AC8: 혼자 F5. 로비에서 계란초밥인지, 마우스 휠로 1인칭까지 줌인, 걷고 멈추기, 리셋 후 다시 확인. Server 보기 Explorer에서 `Workspace.<이름>.SushiBody`가 하나뿐이고 캐릭터 속성 `AppearanceId = "tamago"`.
  - AC7: Test → Clients and Servers 2명. 서버 Command bar: `for _,p in game.Players:GetPlayers() do print(p.Name, p.Character.HumanoidRootPart.Size, p.Character.Humanoid.HipHeight) end`
  - AC9: `Config.DEBUG.forceMapPlan = { "soy-swamp", "hot-plate", "rotating-belt", "skewer-showdown" }`(커밋 금지)로 날치알 공·꼬치에 맞아보기. 빨리 보려면 서버 Command bar: `game.Players:GetPlayers()[1].Character.Humanoid.PlatformStand = true` → 몇 초 뒤 `false`.
  - AC10: 위 forceMapPlan으로 4맵 회귀.
- 남은 이슈
  - 플레이 솔로에서 서버 스크립트보다 플레이어가 먼저 들어오면 첫 캐릭터는 아바타 체형으로 나올 수 있음 (외형은 숨겨지고, 리스폰부터 기본 체형). Studio에서 확인 필요.
  - 이름표: Head를 투명하게 해도 DisplayName이 머리 위에 뜨는 것이 Roblox 기본 동작이라 따로 손대지 않음 — AC7에서 확인.
