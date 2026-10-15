status: ready
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-40 — 기존 맵 길이 늘리기 (Race 구간 추가 · Survival 시간 제한 75초)

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §1(한 판 4~5분), §4(매치 흐름 시간), §5.2(Race 최대 90초 · Survival 최대 60초 · Final 90초 + 연장전), §11.4
- 레퍼런스: 아트 [`docs/REFERENCE-map-art-direction.md`](../REFERENCE-map-art-direction.md) **필수**(새 구간도 같은 기준), [`m5-24`](m5-24-map-art-pass-v2.md)(지금 아트 — 되돌리지 않고 그 위에), 같은 기준을 먼저 적용한 새 맵 [`m5-34`](m5-34-map-dish-sink.md)·[`m5-35`](m5-35-map-space-conveyor.md)·[`m5-36`](m5-36-map-rice-cooker.md)·[`m5-37`](m5-37-map-fish-market.md)
- 의존: `m5-24`(아트 패스 v2)가 `main`에 있는 상태(지금 있음). **`m5-33` 머지 뒤 시작 권장**(m5-33이 공용 풀 개수 테스트를 정리함 — 이 스펙은 그 테스트를 안 건드림).
- 공용 파일 수정 담당: **없음**. 시간 제한은 `Config.TimeLimit`(공용)을 바꾸지 않고 **맵 모듈의 `timeLimit` 필드**로 정한다. `MapKit*`·`MapLighting`·`MapFxPresets`도 안 고친다(키트가 더 필요하면 결정 기록에 적고 멈춤).
- **`m5-33`~`m5-39`(새 맵 6개)와 파일이 겹치지 않는다** — 이 스펙은 기존 15개 중 아래 11개 맵 파일만.

## 배경 (사용자 요청 그대로)
사용자(2026-10-14): **"맵들이 전반적으로 좀 짧다는 느낌이 들던데 길이가 좀 있었으면 좋겠어."**

## 측정 — 지금 맵 길이와 판 시간 (코드에서 읽음, 2026-10-14)
### Race 6개 (출발 스폰 앞줄 z ≈ −2.5 → 결승선, 로컬 −Z)
| 맵 | 결승선 z (코드) | 코스 길이 | 빠른 사람 클리어 추정 | 추정 근거 (Layout·모듈 상수) |
|---|---|---|---|---|
| `rotating-belt` | −116 (`RotatingBeltArt.FINISH_LINE_Z`, 구간 14+34+24+34+14) | **약 114** | **약 15~20초** | 벨트 68 studs를 밀기 10 거슬러 순 6/s ≈ 11초 + 나머지 48 ÷ 16 ≈ 3초 + 젓가락 잡힘 0~3초 |
| `soy-swamp` | −170 (`SoySwampLayout.FINISH` −160~−174, inset 4) | **약 168** | **약 15~22초** | 간장 44 studs 50% 감속(8/s) ≈ 5.5초 + 나머지 124 ÷ 16 ≈ 8초 + 산·와사비·날치알 2~8초 |
| `ramen-rapids` | −296 (`RamenRapidsLayout.FINISH` −276~−300, inset 4) | **약 294** | **약 25~32초** | 급류 110(앞으로 밀어 줌, ≈ 5초) + 차슈 80(타이밍 점프 ≈ 10초) + 회전 막대 70(≈ 6초) + 나머지 |
| `dessert-fridge` | −250 (`DessertFridgeLayout.FINISH_LINE_Z`) | **약 248** | **약 20~28초** | 248 ÷ 16 ≈ 15.5초 + 얼음 관성·구멍·젤리·송풍구 5~12초 |
| `bouncy-castle-maze` | −134 (`BouncyCastleMazeLayout.FINISH_LINE_Z`) | 직선 약 132 (S자 미로 걷는 길 약 360) | **약 25~32초** | 미로 4레인 × 약 90 ≈ 360 ÷ 16 ≈ 22초 + 꺾기·바운스 3~10초 |
| `lantern-bridge` | −148 (`LanternBridgeLayout.FINISH` −138~−152, inset 4) | **약 146** | **약 12~20초** | 146 ÷ 16 ≈ 9초 + 흔들다리 4개 균형 3~10초 |
- 클리어 시간은 **코드 상수로 계산한 추정**(실측 아님 — 사용자 Studio 실측은 AC). Race 라운드는 목표 인원(60~65%)이 들어오면 끝나므로 라운드 길이 ≈ 빠른 사람 + 5~10초 = **약 20~40초**.

### Survival 5개 · Final 4개
| 종류 | 시간 제한 (`Config.TimeLimit`) | 실제로 끝나는 때 (추정) | 근거 |
|---|---|---|---|
| Survival (`hot-plate`, `chef-board`, `tempura-pot`, `giant-jenga`, `cat-cafe-shelves`) | 60초 | **약 35~60초** — 목표 인원 이하가 되면 바로 끝, 아니면 60초에 전원 통과 | 각 스펙 재미 AC("60초 안에 목표 인원 근처까지"), 튀김 냄비 맨 위 3층은 60초까지 안전 |
| Final (`skewer-showdown`, `ikura-bombs`, `tug-of-war-platform`, `claw-machine-prize`) | 90초 + 연장전 20초(안전 상한 150초) | **약 60~110초** | 서든데스 60초부터, 인형뽑기 B2 시뮬(4명 400판 중 51판이 연장전까지), 연장전 20초 |

### 한 판 합계 (지금, `Config.Round`: 시작 카운트 3 · 소개 3 · 결과 5 · 우승 10, 결승 마지막 탈락 뒤 3초)
| 판 | 계산 | 합계 |
|---|---|---|
| 3라운드 (4~8명) | 3 + R1 Race(3 + 30 + 5) + R2 평균(3 + 38 + 5) + 결승(3 + 75 + 3) + 10 | **약 165초 ≈ 2.8분** |
| 4라운드 (9~24명) | 위 + R3 평균(3 + 38 + 5) | **약 210초 ≈ 3.5분** |

### 판단
- **"짧다" = 둘 다 맞지만 주원인은 Race 코스 길이.** Race 빠른 사람 12~32초(기존 Race는 114~294 studs)로 라운드가 20~40초에 끝난다. Survival은 60초 상한 안에서 35~60초, Final은 이미 60~110초.
- 그 결과 **한 판이 GDD 목표 "4~5분"보다 짧은 약 2.8~3.5분**이다. 이 스펙 + 새 맵 기준으로 늘리면 목표 범위에 들어온다(아래 "바뀐 뒤 합계").

## 목표 (기본값)
| 종류 | 목표 | 방법 |
|---|---|---|
| Race | **빠른 사람 45~55초, 처음 하는 사람 60~75초**(시간 제한 90초는 그대로, 목표 인원 도착 ≈ 60~70초) | 코스 **약 380~450 studs**, 구간을 그 맵 소재 안에서 2~3개 추가 — 같은 장애물을 늘이기만 하지 않고 조합·변형을 바꿈 |
| Survival | 시간 제한 **75초**(60 + 15) | 맵 `timeLimit = 75` + **60~75초 서든데스 단계**(기존 마지막 단계보다 조금 더 빠르게/많이). 무대 크기는 그대로(넓히면 탈락이 줄어 오히려 늘어짐) |
| Final | **변경 없음** | 이미 가장 긴 라운드(90 + 20). 새 결승 2개도 같은 기준 |

### 바뀐 뒤 합계 (추정)
| 판 | 계산 | 합계 |
|---|---|---|
| 3라운드 | 3 + R1 Race(3 + 65 + 5) + R2 평균(3 + 65 + 5) + 결승(3 + 75 + 3) + 10 | **약 235초 ≈ 3.9분** |
| 4라운드 | 위 + R3 평균(3 + 65 + 5) | **약 308초 ≈ 5.1분** |
- GDD 목표 "약 4~5분"에 맞는다 → **GDD 목표 숫자는 바꾸지 않는다**(4라운드 판이 5분을 살짝 넘을 수 있음을 GDD에 메모). 더 길게(5~6분) 원하면 Race 목표를 60~70초로 올리고 Race 시간 제한을 100~110으로 — 열린 질문 Q1.

## 맵별 계획 (수치는 시작점, 개발자가 Layout 상수로 다듬고 결정 기록에)
### Race — 구간 추가 (각 맵 소재 안에서)
| 맵 | 지금 → 목표 | 추가 구간 (순서대로 끼워 넣기, 결승 구간은 맨 끝 유지) |
|---|---|---|
| `rotating-belt` | 114 → **약 400** | ① **지그재그 옆 벨트**(짧은 벨트 4장이 좌우 번갈아 옆으로 밂, 폭 16, 벽 있음 — 대각선으로 달려야 함) ② **접시 탑 슬라롬**(쌓인 색깔 접시 탑 사이 좁은 길, 고정 장애물) ③ **벨트 C + 젓가락 3개**(기존 벨트 B의 강화판: 젓가락 경고 간격 짧게) |
| `soy-swamp` | 168 → **약 400** | ① **김 징검다리**(간장 강 위 고정 김 조각 발판, 틈 3~4) ② **와사비 산 2**(와사비 패드 3개로 높은 선반에 오르는 지름길 + 걸어서 도는 느린 길) ③ **날치알 내리막 2**(공이 두 줄로 굴러옴) |
| `ramen-rapids` | 294 → **약 430** | ① **젓가락 다리**(나란한 젓가락 두 개 위 건너기, 폭 각 1.6 — 좁은 균형) ② **숟가락(렌게) 계단**(고정 숟가락 발판 오르막, 끝에서 두 번째 급류 짧게 50) |
| `dessert-fridge` | 248 → **약 420** | ① **냉동실 칸**(얼음 + 구멍 3개 + 송풍구 1, 기존 B·D보다 좁게) ② **아이스크림 스쿱 계단**(고정 스쿱 발판, 젤리 1개로 지름길) |
| `bouncy-castle-maze` | 132(걷는 길 약 360) → 직선 **약 240**(걷는 길 약 620) | ① **두 번째 미로 블록**(레인 3개, 틈 방향을 첫 블록과 반대로) ② **풍선 기둥 숲**(바운스 바닥 위 고정 풍선 기둥 사이 지그재그) |
| `lantern-bridge` | 146 → **약 380** | ① 흔들다리 **3개 + 쉼터 2개** 추가(다리마다 흔들림·폭 다르게: 폭 6 짧은 다리, 폭 10 긴 다리) ② **개울 징검돌**(고정 돌 발판, 등불 아래) |
- 공통: 시간 종료 순위가 진행도(−Z)라 **z는 출발 → 결승으로 단조 감소**. 새 구간의 낙하선은 기존 규칙(그 맵의 `fallLineAt`). 스폰 24개·출발 구간은 그대로. 이동 감시 면제 규칙(CLAUDE.md)은 기존 장애물과 같다.
- 맵마다 `Logic.estimateClearTime()`(구간 길이 ÷ 16 + 구간별 지연 상수 — 상수는 Layout) 순수 함수를 두고 42~55초 안인지 테스트한다(새 맵과 같은 방식).

### Survival — 시간 제한 75초 + 서든데스 단계
| 맵 | 60~75초 서든데스 (기본값) | 주의 |
|---|---|---|
| `hot-plate` | 타일이 달아오르는 시간 1.5 → 1.2초 | 75초까지 바닥이 모자라지 않는지 시뮬레이션(타일 재생 규칙을 코드에서 확인 — 없으면 결정 기록) |
| `chef-board` | 칼 주기 3 → 2.5초, 60·70초에 기울기 한 번씩 더 | 가운데 3×3은 그대로 끝까지 남음 |
| `tempura-pot` | 기름 상한 22 → **25**(60초부터 계속 0.4/s로 올라 약 68.5초에 25) — 23층이 약 63.5초에 잠김, 27·31층은 75초까지 안전. 튀는 기름 간격 1.5 → 1.2초 | 판정 수치 변경 — 기존 `map-tempura-pot` AC2·AC5 기대값이 바뀜(아래 테스트 규칙) |
| `giant-jenga` | 블록 뽑는 간격·기울기를 마지막 단계보다 한 단계 빠르게(코드의 마지막 단계 × 0.8) | 가운데 안전지대 규칙 유지 |
| `cat-cafe-shelves` | 공 주기 4.5 → 3.8초, 고양이 발 경고 간격을 마지막 단계 × 0.8 | 넉백 세기는 그대로(Q3 플레이테스트 대기) |
- Survival 판정 규칙(목표 인원 이하면 즉시 끝, 시간 끝나면 전원 통과)은 그대로. 75초가 늘어지면 서든데스 단계가 압박을 만든다.

### Final — 변경 없음
- `skewer-showdown`·`ikura-bombs`·`tug-of-war-platform`·`claw-machine-prize`는 이 스펙에서 손대지 않는다.

## 판정·테스트·아트에 미치는 영향
- **판정이 바뀌는 스펙이다**(m5-24 "판정 불변"과 다름). 바뀌는 것: Race 결승선 z·구간 표·`fallLineAt`·코스 시야 상자, Survival `timeLimit`과 단계 표(튀김 냄비 기름 상한). **바뀌면 안 되는 것**: 스폰 24개·출발 구간, 기존 구간의 장애물 수치·태그, `id`·`kind`·`displayName`·`rule`, Final 4개 전부, `MoveExempt` 규칙.
- **기존 테스트**: 길이·결승선 z·시간 제한·기름 상한처럼 **이 스펙이 의도해서 바꾼 값을 고정한 단언만** 고친다(파일·줄·전후를 개발 메모에, QA가 diff로 확인). 스폰·장애물·태그·카메라 경로 충돌 검사(m4-02-qa·m4-12-hardening)는 그대로 통과해야 한다.
- **아트(m5-24 위에)**: 새 구간도 아트 가이드 기준(층·히어로 색·립·무리·`anim` 규칙). **장식 예산은 Extended(1500) 그대로** — 지금 `rotating-belt` 1386·`bouncy-castle-maze` 1468·`lantern-bridge` 1412처럼 거의 찬 맵은 먼 배경·중복 소품을 덜어 새 구간에 재분배(가이드 8절 "카메라가 보는 곳에 몰기"). 1500 안에서 도저히 안 되면 결정 기록에 휴대폰 성능 메모와 함께 적고 멈춘다(메인 세션이 `MapKitLogic` 예산 단계 추가 여부를 정함 — 이 스펙은 `MapKitLogic`을 안 고침).
- **배경**: 코스가 길어진 만큼 배경 바닥·벽을 늘린다(낙하선보다 10 이상 아래, 아레나 슬롯 간격 2000 안 — 반경 800).
- **소개 카메라**: 4~5점을 새 길이에 맞게 다시 놓는다(소개 3초는 그대로 — 긴 코스는 넓은 샷 + 새 구간 1컷). 아레나 상자 + 40 안, 경로 충돌 검사 통과.
- **렌더 비평**: 맵마다 before 렌더 → 체크리스트 18개 비평 **2회 이상**(새 구간·바뀐 카메라 중심, m5-24에서 이미 3회 함) → after, `void%` 10% 이하, `docs/renders/<mapId>/after-length-*.png`.

## 작업 나눔 (worktree 병렬, 파일 안 겹침)
| 그룹 | worktree / Rojo 포트 | 맵 | 이 그룹만 고치는 파일 |
|---|---|---|---|
| L1 | `m5-len-a` / 34898 | `rotating-belt`, `soy-swamp` | `RotatingBelt*`, `SoySwamp*`(Layout·Logic·Art·Hazards 포함), 그 맵 테스트 |
| L2 | `m5-len-b` / 34899 | `ramen-rapids`, `dessert-fridge` | `RamenRapids*`, `DessertFridge*`, 그 맵 테스트 (`IceLogic`·`IceController`는 안 고침) |
| L3 | `m5-len-c` / 34900 | `bouncy-castle-maze`, `lantern-bridge` | `BouncyCastleMaze*`, `LanternBridge*`, 그 맵 테스트 |
| L4 | `m5-len-d` / 34901 | Survival 5개 | `HotPlate*`, `ChefBoard*`, `TempuraPot*`, `GiantJenga*`, `CatCafeShelves*`, 그 맵 테스트 |
- 새 테스트는 그룹마다 `tests/m5-40-<그룹>.spec.luau`. 공용 파일·`MapKit*`·다른 그룹 맵·새 맵(m5-33~39) 파일은 안 고친다. 여러 그룹이 같은 공용 테스트 줄(예: `map-art-race`·`m5-23-visual-kit`)을 바꿔야 하면 m5-24 병합 규칙처럼 같은 방식으로 맞추고 병합 메모에.
- 머지 순서 자유, 머지마다 `main`에서 검증 5단계.

## 수용 기준
### 순수 로직 (lune 테스트, 그룹마다)
- [ ] AC1: Race 6개 각각: 코스 길이(스폰 앞줄 → 결승선)가 위 목표 ±10%, 구간 z가 출발 → 결승 단조, `Logic.estimateClearTime()`이 42~55초, 새 구간마다 길 약속(틈·높이로 도달 가능 — 맵별 그래프/플러드필 테스트, 기존 방식).
- [ ] AC2: Race 새 구간의 장애물 수치가 기존 같은 종류 장애물 범위 안이고(예: 벨트 밀기 ≤ 10, 와사비 튕김 그대로), 스폰 24개·출발 구간이 바뀌지 않았다(기존 스폰 테스트 수정 없이 통과).
- [ ] AC3: Survival 5개 `timeLimit == 75`, 각 단계 함수가 60초 이상에서 서든데스 값을 돌려준다. 튀김 냄비 `oilHeight`: 60 → 21.6, 68.5 → 25, 100 → 25, 27·31층 윗면 > `oilHeight(75)` + 1. 철판은 75초 시뮬레이션에서 서 있을 타일이 0이 되지 않는다.
- [ ] AC4: Final 4개 파일·테스트에 변경 없음(diff 0).
- [ ] AC5: 장식 `checkBudget(Art.decor(), "Extended")` 통과, 새 구간 장식이 코스 시야 상자와 안 겹침, 배경 바닥이 새 구간 낙하선보다 10 이상 아래, 소개 카메라 점이 아레나 상자 + 40 안이고 경로 충돌 검사 통과.
- [ ] AC6: 바꾼 기존 단언 목록(파일·줄·전후)이 개발 메모에 있고 전부 "이 스펙이 의도한 길이·시간 값"이다.
- [ ] AC7: 검증 5단계 통과.

### 렌더 (개발 PC)
- [ ] AC8: 맵마다 before → 비평 2회 이상 → after(`after-length-*.png`), `void%` 10% 이하, 휴대폰 성능 메모(가장 무거운 뷰 tris — 코스가 길어져 늘어난 양).

### Studio 확인 (사용자 또는 개발자, 그룹 맵을 `forceMapPlan`으로, **확인 뒤 nil**)
- [ ] AC9: Race 6개: 길을 아는 사람이 혼자 45~55초, 처음 하는 사람이 60~75초에 결승(실측을 개발 메모에). 새 구간이 기존 구간과 다른 손맛이고 지루한 긴 직선이 없다.
- [ ] AC10: Survival 5개: 라운드 타이머가 75초, 60초 뒤 장애물이 눈에 띄게 빨라진다. 4~8명 판에서 75초가 늘어지지 않는다.
- [ ] AC11: 이동 감시 로그 없음, 소개 카메라가 물체를 뚫지 않음, 맵별 조명 전환 그대로.
- [ ] AC12: 한 판 전체(3라운드·4라운드 각 2판 이상, 친구 테스트)의 시간을 재서 개발 메모·플레이테스트 기록에 — 목표 3라운드 약 3.5~4분, 4라운드 약 4.5~5분.

## 공용 파일 변경
- 없음 (`Config.TimeLimit`은 그대로, 맵 `timeLimit` 필드 사용 — `MapTypes`에 이미 있음).

## 사용자 작업 (스펙을 막지 않음)
- AC9~AC12 체감·한 판 시간 실측. 열린 질문 Q1 답.

## 열린 질문 (사용자)
- ~~**Q1 한 판 전체 시간 목표**~~ → **답: 4~5분 유지(A)** (2026-10-14 사용자): 지금 실제 약 2.8~3.5분 → 이 스펙 + 새 맵 기준이면 **약 3.9~5.1분**(GDD 목표 4~5분 그대로). (A) 4~5분 유지 — 추천, 이 스펙대로 / (B) 5~6분으로 더 길게 — Race 목표를 60~70초로, Race 시간 제한 90 → 110, Survival 75 → 90. 로블록스 주 이용층(8~16세)은 한 판이 짧고 바로 다음 판으로 가는 걸 좋아해서 추천은 (A).

## 결정 기록
<!-- 날짜 · 질문 · 결정 · 누가 -->
- 2026-10-14 · 요청 · 사용자: **"맵들이 전반적으로 좀 짧다는 느낌이 들던데 길이가 좀 있었으면 좋겠어."** · 측정 결과 주원인은 Race 코스 길이(빠른 사람 12~32초) → Race 구간 추가로 45~55초, Survival 75초, Final 그대로 · planner (사용자 요청, 수치는 기본값 — 메인 세션 위임 범위)
- 2026-10-14 · D1 Survival을 무대 확장 대신 시간으로 · 무대를 넓히면 넉백·장애물이 가장자리까지 덜 미쳐 탈락이 줄고 라운드가 늘어지기만 함. 시간 + 서든데스 단계가 "길지만 긴장 있게"에 맞음 · planner
- 2026-10-14 · D2 공용 `Config.TimeLimit.Survival`을 75로 바꾸지 않는 이유 · 공용 파일이라 병렬 작업 중 한 명만 고쳐야 하고, 맵마다 서든데스 단계를 같이 넣어야 의미가 있음 → 맵 `timeLimit` 필드(새 Survival 2개도 같음). 배치가 끝난 뒤 모든 Survival이 75면 Config로 옮기는 정리는 후보 · planner
- 2026-10-14 · **Q1 답: 한 판 4~5분 유지 (A안, 이 스펙대로)** · 사용자
- 2026-10-14 · D3 GDD 한 판 목표 · 바꾼 뒤 추정이 3.9~5.1분이라 "4~5분" 그대로 둔다(Q1에서 사용자가 더 길게를 고르면 수정) · planner
- 2026-10-15 · L4-D1 철판 타일 재생 · 코드에 재생 규칙 없음(m2-03: 한 번 사라지면 끝). 서든데스 1.2초는 **60초 뒤 처음 밟힌 타일만**(이미 달아오르던 타일은 1.5초 유지 — 색이 갑자기 튀지 않게). 바닥 시뮬레이션(`HotPlateLogic.simulateFloor`)은 "조심스러운 걸음"(타일이 사라지기 직전까지 서 있다 옮김) 모델, 기준 인원은 3라운드 판(5~8명)에서 75초까지 가는 최소 인원의 최댓값 = 4명 → 75초에 31칸 남음. 9명 이상 판에서 5명 이상이 끝까지 조심스럽게 버티면 약 70초에 바닥이 바닥나는데, 그건 60초 때도 7명 이상이면 생기던 일(탈락으로 라운드가 끝남)이라 그대로 둠 · developer (맵 판단 위임)
- 2026-10-15 · L4-D2 나무 블록 "기울기" · 기울기는 시간 단계가 아니라 보드 상태(빠진 블록)에서 나와서 따로 빠르게 할 값이 없음 → 뽑는 간격만 1.5 → 1.2초(× 0.8), 개수 2 그대로. 테두리 48개는 약 69초에 다 빠지고 마지막 몇 초는 가운데 3×3(보호, 안 기욺)에서 자리싸움 · developer (맵 판단 위임)
- 2026-10-15 · L4-D3 고양이 공 주기 · 60초에 주기를 바꿔도 공이 순간 이동하지 않게 위상을 이어 붙임(`CatCafeShelvesLogic.ballCycles`) · developer
- 2026-10-15 · L4-D4 튀김 냄비 `SAFE_TIERS` · {5,6,7} 그대로 둠(60초까지의 안전 구역 정의·치수 테스트용). 23층은 약 63.5초에 잠기는 것을 주석·테스트에 적음 · developer

## 개발 메모
<!-- developer가 작성: 그룹마다 절 하나 (### L1 …). 바뀐 파일, 바꾼 기존 단언 목록, 실측 클리어 시간, 전/후 PNG, 휴대폰 메모, 남은 이슈 -->

### L4 (Survival 5개, 브랜치 `m5-len-d`)
- **바뀐 파일**: `HotPlate`·`HotPlateLogic`·`HotPlateArt`(isGlowing에 타일 시간 인자), `ChefBoard`·`ChefBoardLogic`, `TempuraPot`·`TempuraPotLogic`·`TempuraPotLayout`(주석), `GiantJenga`·`GiantJengaLogic`, `CatCafeShelves`·`CatCafeShelvesLogic`, 새 `tests/m5-40-l4.spec.luau`(16개). 각 맵 `timeLimit = Logic.TIME_LIMIT`(75), `SUDDEN_DEATH_AT = 60`. 칼·블록 일정은 `Config.TimeLimit.Survival` 대신 `Logic.TIME_LIMIT`.
- **서든데스(60초~)**: 철판 달아오름 1.5 → 1.2초(60초 뒤 처음 밟힌 타일) · 도마 칼 주기 3 → 2.5초, 기울기 60·70초 추가(7번) · 튀김 냄비 기름 상한 22 → 25(68.5초 도달, 23층 63.5초에 잠김, 27·31층 안전), 튀는 기름 1.5 → 1.2초 · 나무 블록 뽑기 1.5 → 1.2초(2개) · 캣타워 공 4.5 → 3.8초(위상 연속), 고양이 발 2 → 1.6초. 60초까지는 전부 예전과 같음.
- **바꾼 기존 단언**(전부 이 스펙이 의도한 시간·기름 값):
  - `tests/map-hot-plate*.spec`·`map-art-arena`·`m4-03-qa`: 변경 없음(`HEAT_DURATION` 1.5 그대로).
  - `tests/map-chef-board.spec.luau` 69 `timeLimit nil → 75` · 226·228·230 기울기 5번 `{10..50}` → 7번 `{10..70}`.
  - `tests/m4-05-qa.spec.luau` 150·155 마지막 기울기 ≤ `Config.TimeLimit.Survival` → `≤ Logic.TIME_LIMIT` · 274·275 소스 문자열 `Logic.strikeTimes(Config.TimeLimit.Survival)` → `Logic.strikeTimes(Logic.TIME_LIMIT)`.
  - `tests/map-tempura-pot.spec.luau` 49 `timeLimit nil → 75` · 146·151 `oilHeight(100) 22 → 25` · 272·273 "상한 < 23층" → "상한 < 27층" · 301·309 `splashInterval(60) 1.5 → 1.2`.
  - `tests/m5-05-qa.spec.luau` 579·584 `oilHeight(1000) 22 → 25` · 588·589 "23층 > OIL_MAX" → "27층 > OIL_MAX + 1" · 592·596·597 `splashInterval(60·1000) 1.5 → 1.2`.
  - `tests/map-giant-jenga.spec.luau` 76 `timeLimit nil → 75` (60초 일정 단언은 그대로 통과).
  - `tests/map-cat-cafe-shelves.spec.luau` 34 `timeLimit nil → 75` · 194 `pawInterval(60) 2 → 1.6`.
  - `tests/m5-17-qa.spec.luau` 287·295 pawInterval 하한 2 → `PAW_INTERVAL_SUDDEN`(1.6).
- **AC4**: Final 4개 파일·테스트 diff 0. **AC5**: 장식·판정 지오메트리·카메라 변경 없음(기존 예산·카메라 테스트 그대로 통과).
- **AC8 렌더**: 5개 맵 `--view all --quality high` 1회 → 비평 ① 장식·지오메트리를 안 바꿔 overview·eye가 m5-24 `after-*.png`와 **바이트 단위로 같음** ② 서든데스는 시간에 따른 동작이라 정지 렌더에 안 보임 → Studio AC10으로 확인. `docs/renders/<id>/after-length-overview.png` 5장(같은 내용 — git이 같은 blob으로 저장). `void%` 전부 0%(캣타워 overview 2%). 휴대폰: tris 변화 없음(가장 무거운 tempura-pot 113k, giant-jenga 90k, cat-cafe 79k, hot-plate 54k, chef-board 50k).
- **검증**: rojo build · stylua --check src tests tools · selene src(0/0/0) · `lune run tests` 2194 passed, 0 failed · luau-lsp analyze 끝 코드 0.
- **Studio 확인(AC10)**: `forceMapPlan = { "<id>" }`로 한 맵씩 → 라운드 타이머 75초, 60초에 철판이 더 빨리 빨개짐/칼 간격 짧아짐+60·70초 기울기/기름이 23층을 덮음·튀는 기름 잦아짐/블록이 1.2초마다 2개/공이 빨라지고 고양이 발이 잦아짐. 확인 뒤 `forceMapPlan = nil`.

### L3 (bouncy-castle-maze · lantern-bridge) — 브랜치 `m5-len-c`
- **바뀐 파일**: `src/shared/maps/BouncyCastleMaze{,Layout,Logic,Art}.luau`, `src/shared/maps/LanternBridge{,Layout,Logic,Art}.luau`, 새 `tests/m5-40-l3.spec.luau`(17개), 기존 테스트 4개(아래), `docs/renders/<id>/after-length-*.png`·`before-length-{overview,top,stats}`.
- **방방 미로**: 결승선 −134 → **−240**(코스 237.5, 걷는 길 약 680). 출구 통로 뒤에 F 두 번째 미로(−120~−176, BounceFloor, 레인 3개 — 오른쪽 입구 → 끝에서 가운데로 건너 되돌아옴 → 왼쪽 출구, 첫 미로와 반대 방향), G 쉼 통로(−176~−182, 일반 바닥), H 풍선 기둥 숲(−182~−226, BounceFloor, 기둥 줄 4개 — 줄마다 한쪽 끝 9만 열리고 좌/우 번갈아 지그재그, 기둥 높이 = 벽 14). 칸막이 두께·문 두께·벽 높이·바운스 수치·MoveExempt는 그대로. `estimateClearTime` **48.9초**.
- **등불 다리**: 결승선 −148 → **−378**(코스 377). 쉼터 3 뒤에 다리 5(폭 10·길이 60·9도) → 쉼터 4 → 다리 6(폭 6·길이 16·7도) → 쉼터 5 → 다리 7(폭 5·길이 30·6.5도) → **개울 징검돌**(앞 둑 → 돌 5 → 섬 → 돌 5 → 뒤 둑, 틈 2.5~3.8, 좌우 지그재그, 섬 위 등불 줄 가운데 등에 빛) → 다리 4(피날레, 폭·길이·10도 그대로 자리만 −338~−368). 다리 index = 배열 자리(1~4 그대로, 5~7 새로). 3번이 여전히 가장 위험, 4번이 여전히 가장 많이 흔들림(테스트). `estimateClearTime` **45.6초**.
- **결정**(위임 범위): 스펙 표의 "폭 10 긴 다리"는 기존 다리 폭 범위(4~8)를 넘지만 스펙이 명시해서 그대로. 등불 다리 조명 예산이 꽉 차서(24/24) 새 다리 등불은 빛 없는 네온, 개울 위 등 하나만 빛. 방방 미로 두 번째 미로도 BounceFloor(맵 정체성), 대신 레인 3개·넓은 레인·반대 방향·바닥 무늬(레인 색 띠)로 손맛을 다르게.
- **바꾼 기존 단언 (전부 이 스펙이 의도한 길이·구간 값)**:
  | 파일:줄 | 전 | 후 |
  |---|---|---|
  | `tests/m5-14-qa.spec.luau:78` | `t.eq(Layout.FINISH.front, Layout.EXIT.back)` | `t.eq(Layout.MAZE2.front, Layout.EXIT.back)` + `t.eq(Layout.FINISH.front, Layout.FOREST.back)` |
  | `tests/m5-14-qa.spec.luau:96` | `countMatches(source, "COLORS%.%w+, true%)") == 1` | `== 2` (새 바운스 구간 반복 한 줄) |
  | `tests/m5-24-qa.spec.luau:53~56` | 판정 지문 bouncy `n 37 …`, lantern `n 33 …` | bouncy `n 72·size 2469.80·x 555.10·y 282.40·z −8230.60·collide 48·tags 3`, lantern `n 51·size 727.80·x 106.50·y −24.60·z −5925.00·collide 27·tags 7` (전 값은 주석에) |
  | `tests/map-bouncy-castle-maze.spec.luau:90·108` | 구간 순서 5개, `-finishLineZ() == 134` | 구간 순서 8개, `== 240` |
  | `tests/map-lantern-bridge.spec.luau:68` | `#BRIDGES == 4` | `== 7` |
  | `tests/map-lantern-bridge.spec.luau:178·186` | `#sections == 9`, `totalLength() == 152` | `== 15`, `== 382` |
  | `tests/map-lantern-bridge.spec.luau:219~221` | `bridgeAt(-120).index == 4`, `bridgeAt(-145) == nil` | `bridgeAt(-350).index == 4`, `bridgeAt(-375) == nil` |
- **렌더**(before = m5-24 `after-*` = `before-length-*`, 비평 2회 → `after-length-*`): void 최대 bouncy 7%(overview, 언덕 고리 키움 전 11%) · lantern 8%(overview). 장식 bouncy 1468 → 1479 · lantern 1412 → 1468 (Extended 1500 안 — 먼 배경 둥근 상자·노점 차양·마을 줄 수·관람차 곤돌라 등을 덜어 새 구간에). 조명 bouncy 7 → 9 · lantern 23 → 24/24. anim bouncy 47 → 69 · lantern 73 → 69.
- **휴대폰 메모**: 가장 무거운 뷰 tris bouncy 127k → **149k**(+17%, 판정 파츠 38 → 73·기둥 28), lantern 112k → **129k**(+16%). 큰 반투명 판 새로 없음, 그림자 조명 맵당 1 그대로, 파티클 lantern 9 → 14(새 쉼터 불씨·반딧불 + 섬 석등).
- **Studio 확인**: `Config.DEBUG.forceMapPlans = { { "bouncy-castle-maze", "giant-jenga", "claw-machine-prize" }, { "lantern-bridge", "cat-cafe-shelves", "tug-of-war-platform" } }` → Play → 방 시작. 방방 미로: 두 번째 미로 입구가 오른쪽만 열림·가운데 레인으로 되돌아옴·왼쪽 출구, 풍선 숲 기둥 사이로 못 빠져나가고 열린 쪽으로만 지그재그, 튕김 중 기둥에 걸려 끼지 않는지. 등불 다리: 새 다리 3개 흔들림 차이, 징검돌이 점프로 무난히 닿는지(작은 돌 Stone07), 섬 위 등불 빛. 둘 다 혼자 45~55초(AC9 실측을 여기에), 이동 감시 로그 없음, 소개 ③ 새 구간 컷이 물체를 안 뚫는지. 확인 뒤 `forceMapPlans = nil`.
- **검증**: rojo build OK · stylua --check OK · selene 0/0/0 · `lune run tests` 2195 passed, 0 failed · luau-lsp analyze 끝 코드 0 (2026-10-15, 로컬 PC).
