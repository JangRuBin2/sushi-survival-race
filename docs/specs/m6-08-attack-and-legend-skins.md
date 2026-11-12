status: qa-passed
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m6-08 — 모두의 "공격" + 전설 스킨 4종 (드래곤·용·제트기·섀도 제트)

- 마일스톤: M6
- GDD 근거: `docs/GDD.md` §6 (조작 — 이 스펙으로 "공격" 추가, v0.10), §9.1 (스킨은 겉모습만 — 그대로), §9.2 (전설 R$ 199), §9.6 (뽑기 전설 등급)
- 사용자 시트: **`docs/드래곤·용 스시 공격 시트.png`** (드래곤 스시 "광역 화염 공격", 용 스시 "범위 회오리 공격", "주변 플레이어도 공격 가능!"). 제트기 2종은 사용자가 대화로 보낸 두 번째 시트(비행기 스시 "미사일 폭격", 악역 제트기) — 파일 없음, 아래 설명으로 대신한다.
- 담당: 공격 기능(메인 세션) / 스킨 4종 모델링(developer, 브랜치 `claude/gracious-curie-tl82em-skins` → 병합)
- 공용 파일 수정 담당: **메인 세션만** — `Config.luau`(`Config.Attack`), `Remotes.luau`(`AttackInput`, `AttackFx`), `Attributes.luau`(`AttackReadyAt`), `Types.luau`(`TouchLayout.attack?`), `src/server/init.server.luau`, `src/client/init.client.luau`.

## 사용자 결정 (2026-11-10)
| 질문 | 답 |
|---|---|
| 공격을 어떻게 넣나 (GDD 9.1 "겉모습만"과 충돌) | **모든 플레이어가 같은 공격**(효과·쿨다운 같음). 스킨은 공격 **연출**만 바꾼다 → 9.1 원칙 유지 |
| 맞으면 | **밀려남 + 1초 넘어짐**(기존 "@_@" 넘어짐). 낭떠러지 근처에서는 떨어질 수 있다 |
| 새 스킨 얻는 법 | **전설 R$ 199 + 🎫 뽑기 전설**(고등어 초밥 [신선]과 같은 방식) |
| "메가트론" | 저작권·상표 때문에 쓰지 않는다 → **오리지널 제트기 컨셉**. 시안 날개의 디셉티콘 비슷한 문양도 쓰지 않는다 |
| 자율비행 | 캐릭터가 실제로 나는 건 **넣지 않는다**(Race 장애물 건너뛰기·Survival/결승 높이 판정이 무너짐 = 스킨 Pay-to-Win). 제트기 공격의 **미사일이 맞은 상대를 자동으로 쫓아가는 연출**로 대신한다. 진짜 비행은 원하면 모두가 쓰는 맵 아이템 같은 별도 스펙 |

## 1. 공격 (모든 플레이어)

| 칸 | 기본값 (`Config.Attack`, 플레이테스트 후 조정) |
|---|---|
| 입력 | PC **F** · 게임패드 **L2** · 모바일 **공격 버튼**(다이브 위, 잡기 왼쪽 — 네 번째 터치 버튼) |
| 쓸 수 있을 때 | 출발한 라운드의 레이서(`RoundService.activeRoomOf`)이고 넘어짐·젓가락·고정·죽음이 아닐 때. 로비·소개·관전·부활 대기 중에는 안 됨 |
| 범위 | 내 주변 **반지름 10** (구, 방향 무관) |
| 맞은 사람 | 같은 방 레이서. 나에게서 바깥쪽으로 **수평 30 + 위 14** 튕김(`LinearVelocity` 0.12초) + **넘어짐 1초**(`PlatformStand`, "@_@") + `MoveExempt` |
| 쿨다운 | **8초** (서버가 셈. 버튼에 남은 초 표시 — `Player` 속성 `AttackReadyAt`) |
| 면역 | 맞은 뒤 **2초** 동안 다시 안 맞음(연속 넘어뜨리기 방지). 이미 넘어진 사람은 안 맞음 |
| 잡기와 | 맞으면 넘어짐이라 잡기가 풀린다(기존 `GrabService.isDown`). 잡힌 사람도 공격할 수 있다(잡기 반격) |
| 판정 | **전부 서버**(`AttackService` + 순수 `AttackLogic`). 클라이언트는 입력·버튼·연출만 |

- 리모트: `AttackInput()`(클라이언트 → 서버, 인자 없음, 간격 `Config.Attack.InputMinInterval`), `AttackFx(info)`(서버 → 같은 방 클라이언트: `{ attacker: userId, position: Vector3, hits: { userId } }`).
- 연출은 `AttackFxLogic.styleFor(skinId)`가 정한다 — **스킨 id 분기는 이 표 하나**:

| 스타일 | 스킨 | 모습 (약 0.9초) |
|---|---|---|
| `RiceBurst` | 그 밖의 모든 스킨 | 하얀 충격파 고리 + 밥알 튀김 |
| `Flame` | `dragon-sushi` | 금·주황 불꽃 고리 + 위로 감아 오르는 불꽃 용 띠 |
| `Storm` | `sky-dragon-sushi` | 파랑·하양 회오리 고리(회전) + 물보라 |
| `Missile` | `jet-sushi` | 위로 떠올랐다가 맞은 사람을 **쫓아가는 미사일**(맞은 사람이 없으면 바깥쪽 4방향) + 폭발 |
| `ShadowMissile` | `shadow-jet-sushi` | 같은 미사일, 보라 연기 꼬리 + 보라 폭발 |

- 연출은 판정과 무관하고(맞음·넘어짐은 이미 서버가 처리), 한 화면 동시 연출 상한 `Config.Attack.FxMaxConcurrent`(6), 거리 `FxMaxDistance`(150) 밖은 안 그린다.
- 터치 버튼(m5-41 편집)에 `attack` 추가: 기본 자리 = 다이브 위·잡기 왼쪽 대각선. **저장 모양 v1 그대로, `attack` 칸은 선택** — 예전 저장값(3개)도 그대로 읽히고 공격 버튼은 기본 자리(겹치면 `fit`이 줄이거나 기본 배치로).

## 2. 전설 스킨 4종 (겉모습만)
| id | 이름 / en | 모습 | 공격 연출 |
|---|---|---|---|
| `dragon-sushi` | 드래곤 스시 / Dragon Sushi | 빨강·금 드래곤이 밥 위에 걸쳐 있음(뿔·수염·꼬리) | `Flame` |
| `sky-dragon-sushi` | 용 스시 / Sky Dragon Sushi | 파랑·하양 청룡이 밥을 감쌈(갈기·구름) | `Storm` |
| `jet-sushi` | 제트기 스시 / Jet Sushi | 흰·회색 기체, 캐노피, 빨간 띠, 날개·꼬리날개, 엔진 | `Missile` |
| `shadow-jet-sushi` | 섀도 제트 스시 / Shadow Jet Sushi | 건메탈·보라 악역 제트기, 빨간 눈 | `ShadowMissile` |

- 모두 `tier = "Legendary"`, `robux = 199`, `drawGrade = "Legendary"`, `conceptBody = true`. 효과 2개 이하, 외곽 ±25%, 크기·히트박스·속도 같음.

## 수용 기준
### 순수 로직 (lune)
- AC1 `AttackLogic.pickTargets`: 반지름 안·같은 후보만, 나·죽음·넘어짐·면역 제외, 거리순.
- AC2 `AttackLogic.knockFor`: 바깥쪽 수평 단위 벡터 × 수평 속도 + 위 속도. 같은 자리면 공격자가 보는 방향.
- AC3 북(`newBook`·`canAttack`·`record`·`readyAt`·`isImmune`·`removePlayer`): 쿨다운·면역·나간 사람 지우기.
- AC4 `AttackFxLogic.styleFor`: 표대로, 모르는 id·nil은 `RiceBurst`. 미사일 경로가 시작·끝점을 지나고 위로 휜다.
- AC5 터치 배치: 기본·large·compact 프리셋 모두 4버튼 겹침 없음·칸 안(여러 화면), 예전 3버튼 저장값 `sanitizeLayout` 통과, `attack` 넣은 값 왕복.
- AC6 현지화: 새 키(공격 버튼·쿨다운·스킨 이름·대사) CSV에 있고 src 한국어 리터럴 없음.
### Studio 확인 (사용자)
- DEV-SETUP 3-18: F/L2/모바일 버튼으로 공격 → 주변 초밥이 튕기고 "@_@" 1초, 8초 쿨다운 표시, 면역, 잡기 풀림, 낭떠러지 낙하(Race는 부활), 스킨별 연출 5종, 버튼 위치 편집에 공격 버튼.

## 결정 기록
- 2026-11-10 사용자: 위 "사용자 결정" 표.
- 2026-11-10 메인: 키 F·L2(비어 있는 키), 연출은 서버가 방 사람에게만 `AttackFx`, 공격자 스킨은 클라이언트가 `AppearanceId`로 고름(서버는 스킨을 보내지 않음).
- 2026-11-10 메인: 스킨 4종은 developer가 별도 worktree에서 만들어 병합(`docs/developer/m6-08-legend-skins.md`). 드래곤 2종은 파츠 상한 80(고등어와 같은 예외 표), 제트기 2종은 70. 이름표 높이 예외 없음(꼭대기 ≤ 3.2).

## 개발 메모
- 공격 쪽 기록·인계: `docs/developer/m6-08-attack.md`. 검증(병합 뒤): 2499 passed, 0 failed · selene 근사 std(클라우드) · luau-lsp 0. QA 리포트는 아직 없음.

## QA
- 2026-11-12 QA: 통과(P3 5건) — [`docs/qa/m6-08-attack-and-legend-skins.md`](../qa/m6-08-attack-and-legend-skins.md). Studio 확인은 사용자(DEV-SETUP 3-18).
