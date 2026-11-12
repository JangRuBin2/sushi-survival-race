status: qa-passed
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m6-12 — 🧨 다이너마이트 라운드 (유니크 라운드 + 맵 아이템)

- 마일스톤: M6 · GDD 근거: §6(조작 — 공격 버튼), §4(Race 부활), §9.1(스킨은 겉모습만 — 그대로)
- 사용자 요청 (2026-11-10): "다이너마이트 스시는 적과 나를 공격하는 스시. 스킬을 사용하고 10초 후 폭발하면 나랑 주변 플레이어를 시작 지점으로" → 질문 답 → "일반 레이스에서 10퍼센트 정도의 확률로 진행되는 유니크 라운드로. 매판 폭탄 들고 다니면 짜증나니까"
- 담당: 메인 세션(공용 파일 포함). 다이너마이트 **스킨**(m6-11)은 developer가 따로 — 이 스펙은 스킨과 무관한 아이템·라운드 규칙.

## 사용자 결정
| 질문 | 답 |
|---|---|
| 스킬을 어떻게 (9.1 "스킨은 겉모습만"과 충돌) | **맵 아이템** — 누구나 주워서 씀. 다이너마이트 스시를 입으면 폭발 연출만 더 화려 |
| 버티기 맵에서는 | **Race에서만 출발점으로**, Survival·결승은 크게 튕겨 내기 |
| 얼마나 자주 | **결승이 아닌 Race 라운드의 약 10%만 "다이너마이트 라운드"** — 그 라운드에서만 아이템이 나와요 |

## 규칙 (기본값 `Config.Dynamite`, 플레이테스트 후 조정)
- **유니크 라운드**: 라운드 준비 때 결승 아닌 Race면 `UniqueChance` 0.10으로 뽑아요(`DynamiteLogic.rollUnique`) → 맵 Model 속성 `RoundModifier = "Dynamite"`, 서버 `RoundService.modifierOf(roomId)`. 출발하면 방 사람에게 Notice "🧨 다이너마이트 라운드! …".
- **떨어뜨리기**: 출발 `FirstDelay` 12초 뒤부터 `Interval` 18초마다, 땅에 선 레이서 하나 둘레 6~12 studs에(`dropSpot`). 방에 `MaxPerRoom` 2개(바닥 + 들고 있음 + 불붙음), 레이서 2명 아래면 안 떨어뜨림, 25초 지나면 사라짐.
- **줍기**: 4.5 studs 안이면 자동(손에 하나만) → Player 속성 `HeldItem = "Dynamite"`, 공격 버튼(F·L2·💥)이 **"🧨 점화"**(공격 쿨다운과 무관).
- **점화**: `AttackInput`이 오면 `AttackService`가 먼저 `DynamiteService.tryLight` → `DynamiteFuseAt`(서버 시각) → 머리 위 "🧨 10…1"(마지막 3초 빨강).
- **폭발(10초)**: 들고 있던 사람 + 반지름 12 안 레이서(`blastTargets`, 넘어진 사람 제외 — 들고 있던 사람은 늘 포함).
  - **Race(부활 라운드)**: `RoundService.sendToStart` → 낙하와 같은 Race 부활 흐름(출발점 고정 → 3초 카운트다운 → 다시 달림).
  - **그 밖(정원 마감 뒤 등)**: 바깥으로 수평 60 + 위 35 튕김, 1.5초 넘어짐(공용 `Knockback`).
- 라운드가 끝나거나 방을 나가면 바닥·들고 있음·불붙음을 지우고 터지지 않아요.
- 연출: 서버 `DynamiteFx`(같은 방) → 불덩이·고리·조각, 소리 `DynamiteBoom`. 들고 있던 사람이 `dynamite-sushi`를 입었으면 더 크고 고리 둘(`AttackFxLogic.styleFor == "Kaboom"` — 판정 코드에는 스킨 없음).

## 수용 기준
- AC1 `DynamiteLogic`: 떨어뜨리기 일정·상한·최소 인원, 자리, 줍기(가까운·손 빈), 폭발 대상(들고 있던 사람 맨 앞), 효과, 넉백, 심지, 유니크 뽑기(Race·결승 아님만) — `tests/m6-12-dynamite.spec.luau`.
- AC2 연결: 리모트 `DynamiteFx`(16 + 14 = 30), 속성 `HeldItem`·`DynamiteFuseAt`·`RoundModifier`, 서비스·컨트롤러 등록, 공격 입력이 점화를 먼저, `sendToStart`, 문구·소리.
- Studio(사용자, DEV-SETUP 3-18 9번): `Config.Dynamite.UniqueChance = 1`로 잠깐 바꿔 Race에서 확인.

## 개발 메모
- 다이너마이트 스시(m6-11) 병합 뒤 5단계: 2561 passed, 0 failed · selene 근사 std · luau-lsp 0.

## 결정 기록
- 2026-11-10 사용자: 위 표. 메인: 버튼을 늘리지 않으려 공격 버튼을 점화로(들고 있을 때만), 아이템 자리는 맵 모양을 몰라도 되게 "땅에 선 레이서 근처", 출발점 보내기는 m6-01 부활 흐름 재사용.

## QA
- 2026-11-12 QA: **보류(in-qa 유지)** — P2-1 불붙인 다이너마이트를 든 사람이 결승선 통과·리셋으로 레이서가 아니게 되면 마지막 자리에 안 보이는 폭탄이 남아 다른 레이서를 출발점으로 보냄(`DynamiteService.luau:165-171`, `:243-257`). [`docs/qa/m6-12-dynamite-round.md`](../qa/m6-12-dynamite-round.md).
- 2026-11-12 재QA(메인 세션): P2-1 수정 확인 — 불붙인 사람이 레이서가 아니게 되면(결승선 통과·부활 대기·탈락·리셋) 터지지 않고 꺼짐(`DynamiteService` tick의 불붙음 루프, 회귀 테스트 `tests/m6-12-qa.spec.luau`). **`qa-passed`**. 예전 "부활 대기·탈락이면 마지막 자리에서 터짐" 동작은 없어졌어요.
