# 공격 · 공격 연출 구조 (m6-08)

공격 기능과 스킨별 공격 연출을 고치거나 새 연출을 더할 때 읽는 문서예요. 기획·수치 근거는 [`docs/specs/m6-08-attack-and-legend-skins.md`](specs/m6-08-attack-and-legend-skins.md), 규칙 요약은 `CLAUDE.md` "공격 · 연출 규칙".

## 1. 원칙
- **공격은 모두 같아요.** 범위·튕김·넘어짐·쿨다운·면역은 `Config.Attack` 하나이고 스킨과 무관해요(GDD 9.1 "스킨은 겉모습만"). 판정 코드(`AttackLogic`, `AttackService`)에는 스킨 id도 `AppearanceId`도 나오면 안 돼요 — `tests/m6-08-attack.spec.luau` "AC4: 연출 스킨은 판정 코드에 없어요"가 막아요.
- **스킨은 연출만** 바꿔요. 스킨 → 연출 연결은 `AttackFxLogic.STYLE_BY_SKIN` **표 하나**예요(스킨 id 분기를 다른 곳에 만들지 않아요).
- **캐릭터는 날지 않아요.** "자율비행"(사용자 질문 2026-11-10)은 Race 장애물 건너뛰기·Survival/결승 높이 판정을 깨서 스킨 Pay-to-Win이 되기 때문에, 제트기 스킨은 **미사일이 대상을 쫓아가는 연출**로 대신했어요. 진짜 비행을 넣으려면 모두가 쓰는 맵 아이템처럼 별도 스펙으로(판정·이동 감시 면제·연장전 영향 검토 필요).

## 2. 흐름
```
[클라이언트] AttackController  F / ButtonL2 / AttackButton(터치)
   │  관전 중·쿨다운 표시 중이면 안 보냄 (편의 — 서버가 다시 봄)
   ▼  AttackInput()  (인자 없음)
[서버] AttackService.onInput
   │  요청 간격(InputMinInterval 0.2) → AttackLogic.canAttack(쿨다운)
   │  RoundService.activeRoomOf(출발한 레이서만) → 넘어짐·젓가락·고정·죽음이면 거절(GrabService와 같은 isDown)
   │  후보 = 같은 방 레이서 → AttackLogic.pickTargets(반지름 10, 면역·넘어짐 제외, 가까운 순)
   │  AttackLogic.record(쿨다운 8, 면역 2) → Player 속성 AttackReadyAt(서버 시각, 표시용)
   │  맞은 사람마다 knock: MoveExempt.mark(1.5) + LinearVelocity "AttackKnock"(0.12초) + PlatformStand(1초)
   ▼  AttackFx({ attacker, position, hits })  — 같은 방(RoomService.getPlayers) 사람에게만
[모든 클라이언트] AttackFxController.play
      공격자 캐릭터 AppearanceId → AttackFxLogic.styleFor → 그리기 (0.6~0.9초)
      넘어짐 "@_@"·Knockdown 소리는 기존 CharacterFxController가 PlatformStand를 보고 알아서 해요
```
- 넘어짐은 `PlatformStand`라서 기존 규칙이 그대로 따라와요: 잡기 풀림(`GrabService.isDown`), 다이브 불가, 머리 위 "@_@". 탈락 고정(Anchored)이 그 사이 걸리면 일으키지 않아요.
- 같은 사람을 맵 넉백과 공격이 겹쳐 넘어뜨리면 `standUntil`이 늦은 쪽만 일으켜요(맵 모듈들과 같은 방식).

## 3. 연출 스타일 (`AttackFxLogic.STYLES`)
| 스타일 | 스킨 | 그리는 것 | 색 (ring / accent / particle) |
|---|---|---|---|
| `RiceBurst` | 기본(표에 없는 모든 스킨) | 바닥 충격파 고리 + 밥알 22개 | 아이보리 / 흰색 / 밥알색 |
| `Flame` | `dragon-sushi` | 고리 + 12조각 불꽃 띠가 1.25바퀴 돌며 감아 오름(머리 조각 금색) | 주황 / 금 / 붉은 주황 |
| `Storm` | `sky-dragon-sushi` | 도는 고리(2바퀴) + 회오리 띠 2바퀴 | 하늘 / 흰 파랑 / 파랑 |
| `Missile` | `jet-sushi` | 미사일(흰 몸 + 빨간 머리 + Trail)이 0.55초 동안 위로 휘며 맞은 사람을 **매 프레임 다시 겨눠** 쫓아감 → 도착하면 폭발 조각. 맞은 사람이 없으면 바깥 4방향 | 흰 / 빨강 / 주황 |
| `StarRibbon` | `magical-girl-sushi` (m6-09) | 분홍 고리 + 분홍·노랑 별 조각이 **번갈아**(`alternate`) 1.5바퀴 감아 오름 + 민트 별빛 조각 | 분홍 / 연노랑 / 민트 |
| `HolyHalo` | `angel-sushi` (m6-10) | 금빛 고리가 1바퀴 돌고 금·흰 조각이 번갈아 감아 오름 | 금 / 크림 흰 / 연금 |
| `DemonFlame` | `devil-sushi` (m6-10) | 보라 고리 + 보라 불꽃 띠 1.75바퀴(머리 조각 빨강) | 보라 / 빨강 / 진보라 |
| `ShadowMissile` | `shadow-jet-sushi` | 같은 미사일, 보라 꼬리·폭발 | 보라 / 보라 / 진보라 |

스타일 플래그: `band`(감아 오르는 띠), `missiles`(쫓아가는 미사일), `spin`(띠 바퀴 수), `ringSpin`(고리도 돌기 — Storm), `alternate`(띠 조각 색 번갈아 — StarRibbon).

순수 계산(테스트됨): `ringRadius`(ease-out), `fade`(끝 40%에서 사라짐), `helixPoint`(띠 조각 위치), `bandColor`(띠 조각 색), `missilePoint`(위로 휜 2차 베지어), `missileTargets`(최대 6발, 없으면 4방향).

그리기 규칙(`client/fx/AttackFxController.luau`):
- 파츠는 전부 이 클라이언트에만 있는 Anchored·CanCollide/CanQuery/CanTouch false·그림자 없음, `Workspace.AttackFx/Attack` 폴더에 연출마다 따로 넣고 끝나면 폴더째 지워요. 폭발 조각(ParticleEmitter)은 `Workspace.AttackFx` 바로 아래에서 1초 뒤 스스로 지워요.
- 캐릭터 아래에 붙이지 않아요 — `AppearanceService`가 SushiBody 밖의 파츠를 숨기기 때문이에요(붙여야 하면 `Attributes.KeepVisible`).
- 상한: 동시에 `Config.Attack.FxMaxConcurrent`(6)개, 카메라에서 `FxMaxDistance`(150) 밖은 안 그려요.
- 소리 `Attack` 한 가지(임시: 폭발음 작게·높게, `SfxLibrary`). 스타일별 소리는 아직 없어요.

## 4. 새 공격 연출 더하기 (예: 새 전설 스킨)
1. `AttackFxLogic.STYLES`에 스타일을 더하고(`duration` ≤ 1.5 — 테스트가 봄), 필요하면 `Style` 타입에 이름 추가.
2. `STYLE_BY_SKIN`에 `["<skin id>"] = "<스타일>"`.
3. 모양이 새로우면 `AttackFxController`에 updater 함수(`(t: 0~1) -> ()`)를 하나 더하고 `play`에서 `styleInfo`의 플래그로 고르게 해요. 매 프레임 계산은 `AttackFxLogic`의 순수 함수로 빼서 `tests/m6-08-attack.spec.luau`에 테스트.
4. 판정·`Config.Attack`은 건드리지 않아요. 스킨마다 다른 수치가 필요해지면 GDD 9.1을 바꾸는 기획 결정이라 사용자에게 먼저 물어요.
5. Studio에서 DEV-SETUP 3-18의 6번처럼 확인(스킨 입고 F).

## 5. 터치 버튼 (m5-41 편집과의 관계)
- `TouchLayoutLogic.NAMES`에 `attack`이 더해져 4개예요. 기본 자리 = **다이브 위·잡기 왼쪽**(`UiLayout.touchButtons().attack = { x = dive.x, y = grab.y }`), compact 프리셋은 잡기 왼쪽, large는 묶음째 1.25배.
- 저장 모양은 **v1 그대로** 두고 `attack` 칸만 선택으로 더했어요. m6-08 전에 저장한 3버튼 배치도 `sanitizeLayout`을 통과하고, `toScreen`이 공격을 다이브 x·잡기 y에 둔 뒤 `fit`이 겹치면 줄이거나 기본 배치로 돌려요.
- 버튼 글씨는 `input.attack.btn`("💥 공격"), 쿨다운 중에는 `input.attack.cooldown`("{seconds}초") + 회색.

## 6. 알려진 한계 · 다음 후보
- PC·게임패드에는 쿨다운 표시가 없어요(모바일 버튼만). 필요하면 HUD에 작은 표시.
- 공격 순간 공격자 몸 연출(드래곤이 포효, 제트기가 살짝 떠오르는 모션)은 없어요 — 넣는다면 위치를 바꾸지 않는 클라이언트 로컬 포즈로(`CharacterAnimLogic`/`CharacterFxController`).
- 40명 방에서 공격이 너무 혼잡하면 `Cooldown`·`Radius`를 조정하거나 대형 맵에서만 수치를 바꾸는 방법(기획 결정).
