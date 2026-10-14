# REFERENCE — 맵 3차 배치 6개 (콘셉트 시트 기반) 사례 조사 · 겹침 분석

- 작성: planner, **2026-10-14** (모든 출처 확인 날짜 = 2026-10-14)
- 목적: 사용자 콘셉트 시트 [`docs/스시 서바이벌 레이스 신규 맵 6종.png`](스시%20서바이벌%20레이스%20신규%20맵%206종.png)(커밋 84ddcc1)를 스펙 `m5-33`~`m5-39`로 옮길 때 **규칙·수치·차별화**를 감이 아니라 사례로 정하기 위한 근거.
- 표기: **[원문]** = WebFetch로 원문 확인, **[검색]** = 검색 요약만(원문 403·404·405 등), **확인 못 함** = 못 찾음. 추정은 "추정"이라고 쓴다.
- 이 문서는 참고 자료다. 결정은 각 스펙 "결정 기록"에 있다(사용자가 맵 판단을 메인 세션에 위임 — `docs/USER-TODO.md` 답변 기록 2026-10-13).

---

## 0. 시트 요약 (이미지를 직접 보고 정리)

| 칸 | 시트 제목 · 모드 | 시트 한 줄 | 장애물 1 (주기) | 장애물 2 (주기) | 눈에 띄는 세트피스 |
|---|---|---|---|---|---|
| 위 왼쪽 | 깨끗하게! 설거지통 레이스 · RACE | 설거지통을 가로질러 깨끗한 접시를 향해 | 회전하는 접시 — 일정 속도로 회전하며 밀어냄 (약 5초) | 움직이는 스펀지 — 좌우로 이동하며 밀어냄 (약 8초) | 크롬 수도꼭지, 스테인리스 개수대, 노란·연두 스펀지, 파란 테 흰 접시, 거품, 결승 FINISH 아치와 접시 건조대 |
| 위 가운데 | 우주 회전초밥 레이스 · RACE | 우주를 떠다니는 회전초밥 레일을 따라 결승점까지 | 회전 레일 — 일정 속도로 계속 돎 (약 6초) | 떨어지는 운석 — 일정 간격, 장애물이 생김 (약 10초) | 남보라 별하늘, 고리 행성, 보라 로켓, 네온 테두리 S자 레일, 화살표, 네온 FINISH |
| 위 오른쪽 | 초대형 밥솥 생존 · SURVIVAL | 정해진 시간 동안 밥솥 위에서 떨어지지 않고 버티기 | 밥알 끓어오름 — 일정 시간마다 밀어냄 (약 7초) | 증기구 분사 — 좌우에서 뜨거운 증기 (약 12초) | 검은 밥솥 + 은색 테, 흰 밥 더미, 나무 주걱, 빨간 디지털 타이머 00:45, 김, 햇살 주방 |
| 아래 왼쪽 | 수산시장 생존 · SURVIVAL | 거대한 생선과 얼음 사이에서 살아남기 | 거대 생선 낙하 — ⚠ 경고 뒤 떨어짐 (약 8초) | 얼음 블록 이동 — 좌우로 움직이며 밀어냄 (약 10초) | 물 위 나무 상자 격자, 반투명 얼음 큐브, 매달린 참치, "수산시장" 간판, 배·크레인, 주황 차양 |
| 아래 가운데 | 찻잎 정원 결승 · FINAL | 마지막 1명이 남을 때까지 | 찻잔 회전 — 중앙 찻잔이 회전하며 플랫폼을 밀어냄 (약 6초) | 차밭이 무너짐 — 가장자리 차밭부터 (약 15초) | 동심원 계단식 차밭, 벚꽃, 거대 찻주전자 2개, 붉은 정자, 시냇물 |
| 아래 오른쪽 | 온천탕 인형뽑기 결승 · FINAL | 마지막 1명이 남을 때까지 | 온천수 상승 — 일정 시간마다 차올라 발판이 아래로 (약 10초) | 중앙 인형뽑기 작동 — 바닥을 흔듦 (약 12초) | 분홍 인형뽑기 기계 + 흰 고양이 인형, "온천" 간판, ♨ 네온, 나무 데크, 청록 온천물, 김 |

- 시트 머리글: "더 다양하고, 더 거대한 주방 속으로!", "작은 초밥, 거대한 주방!" — 아트 가이드 1절 세계 컨셉과 같다.
- 모든 칸에 "플레이어 크기 비교"(초밥 4개) — 스케일 1 stud ≈ 1 cm(아트 가이드 1절)를 유지하라는 뜻으로 읽는다.

## 1. 사례 표

| # | 게임 / 라운드 | 쓸 곳 | 핵심 | 근거 수준 |
|---|---|---|---|---|
| A | **Fall Guys — Dizzy Heights** (Race) | 설거지통 회전 접시 | 회전 원판 위를 달림. "한 원판은 오른쪽, 옆 원판은 왼쪽으로" 돌고, 몇 걸음마다 균형이 흔들림. 원판 사이를 점프하면 앞으로 더 나감 | [원문] Inverse 공략 |
| B | **Fall Guys — Block Party** (Survival) | 수산시장 얼음 블록 | 움직이는 벽을 피해 판 위에 남기, 떨어지면 탈락. 중간부터 낮은 벽(점프), 판이 좁아짐 | [검색] GameWith·Fandom (원문 404) |
| C | Roblox **BE CRUSHED BY A SPEEDING WALL** | 수산시장 얼음 블록 | "버튼을 누르고 빠르게 오는 벽에 깔려라" — 밀려오는 벽 자체가 로블록스 아이들에게 익숙한 장르. 총 방문 **707.8M**, 역대 최고 동접 372(2026-07) | [원문] RoWatcher |
| D | **Fall Guys — Jump Showdown** (Final) | 찻잎 정원 차별화 | 회전 막대 2개(낮은 것 점프), 시간이 지나면 발판이 떨어져 2개 남음 — 우리 `skewer-showdown`의 원형. 같은 손맛을 또 만들지 않는다 | [검색] Prima Games·TrueTrophies |
| E | **Stumble Guys — Laser Tracer Legendary** (Final, 패치 0.86) | 온천탕 충격파 | "레이저 고리가 위에서 떨어져 터지듯 켜지고 **가운데서 바깥으로 퍼진다**" — 가운데서 퍼지는 고리를 넘는 결승의 직접 사례 | [원문] stumbleguys.com update86 |
| F | Roblox **Natural Disaster Survival** — 지진 | 온천탕 충격파 | 지진 때 "평지에서 계속 점프하면 피해를 덜 받는다" — 로블록스 아이들이 "땅이 흔들리면 점프" 규칙을 이미 앎 | [검색] Sportskeeda(원문 405) |
| G | Roblox **The Floor Is LAVA!** / **Flood Escape 2** | 온천수 상승 | 차오르는 용암·물 — 이미 `REFERENCE-m5-maps.md` G·H. 우리 `tempura-pot`이 "올라가기"로 이미 씀 → 온천은 "올라가기"가 아니라 "높이 순서로 가라앉는 발판" | `REFERENCE-m5-maps.md` (2026-10-08 확인) |
| H | Roblox **Super Bomb Survival** | 운석·생선 낙하 | 하늘에서 떨어지는 폭탄, 단계별로 많아짐 — `REFERENCE-m5-maps.md` B, 우리 `ikura-bombs`의 원형 | `REFERENCE-m5-maps.md` |
| I | Roblox **OBBY BUT here is Space** | 우주 레일 저중력 | 설명 "Survive in low gravity obby!" — 우주 = 저중력이 로블록스 오비의 흔한 공식. 총 방문 3.0M | [원문] RoWatcher |
| J | Roblox DevForum — 저중력 구현 스레드 | 우주 레일 저중력 | Workspace 중력은 게임 전체에 영향 → 캐릭터 HumanoidRootPart에 **VectorForce(월드 기준)로 중력 일부를 상쇄**하는 방식이 표준. BodyForce는 폐기, VectorForce가 후속 | [검색] devforum t/1135572, t/2623378 |
| K | Roblox **Escape The Amazing Kitchen Obby** 등 주방 오비 | 세계관 | 주방 테마 오비(굴러오는 밀대·칼 피하기) 방문 약 11.9M — "거대한 주방 속 작은 나"가 로블록스에서 익숙한 무대 | [검색] Bloxodes |
| L | Fall Guys — Slime Climb·Roll Off / Hex-A-Gone | 공통 | 차오르는 액체, 경기장 축소가 결승 표준(`REFERENCE-m5-maps.md` A·E·F, `REFERENCE-final-overtime.md`) | 기존 문서 |

### 읽은 것
1. **회전 원판(A)** 은 "방향이 서로 반대인 원판을 건너뛰는 Race"로 이미 검증된 손맛이다. 우리 `rotating-belt`는 직선 벨트가 **늘 뒤로** 민다 — 원판은 **옆(접선)으로** 밀고 원판마다 방향이 반대라 다르다.
2. **밀려오는 벽(B·C)** 은 Survival에 맞다. 우리 `cat-cafe-shelves`의 공은 좁은 선반 하나를 왕복하지만, 얼음 블록은 **넓은 격자 줄을 통째로 쓸고 줄을 바꾼다**(Block Party에 가깝다).
3. **가운데서 퍼지는 고리(E)·지진 점프(F)** 는 "타이밍 점프"를 막대 회전(`skewer-showdown`)과 다른 모양으로 준다 — 원형 파동은 **모두에게 같은 순간이 아니라 거리 순서로** 도착한다.
4. **저중력(I·J)** 은 우주 테마를 가장 싸고 확실하게 차별화한다. 서버가 VectorForce를 달면 판정·이동 감시와 충돌하지 않는다(위로 오르는 속도는 점프와 같고 더 느리게 떨어질 뿐 — `MovementGuardLogic` 상한과 무관).
5. 낙하물(H)은 이미 `ikura-bombs`(결승)에 있다 → 운석은 **Race에서 떨어진 뒤 바위로 남아 길을 좁히는 것**, 생선은 **떨어진 뒤 누워서 한 번 팔딱이는 것**으로 다르게 한다.

## 2. 겹침 분석 (기존 15개와 새 6개끼리)

| 새 맵 | 겹칠 수 있는 기존 맵 | 겹침 정도 | 차별화 (스펙에 반영) |
|---|---|---|---|
| `dish-sink` 설거지통 | `rotating-belt`(밀림), `ramen-rapids`(원형 발판 회전 막대) | 중 | 접시는 **판 자체가 도는 회전판** — 접선 방향으로 밀고, 원판마다 방향 반대(Dizzy Heights). 막대가 없다. 스펀지는 좁은 칸막이 선반을 가로질러 왕복(밀려 물로) |
| `space-conveyor` 우주 회전초밥 | `rotating-belt`(컨베이어) | **높음** | 레일이 **6초마다 방향이 바뀐다**(앞으로 실어 줌 ↔ 뒤로 밂, 화살표 색으로 예고) + **저중력 소행성 구간** + 운석이 **바위로 남아** 길을 좁힘. 회전 벨트는 늘 뒤로·저중력 없음 |
| `rice-cooker` 초대형 밥솥 | `hot-plate`(바닥 위 생존), `chef-board`(줄 경고 + 넉백), `dessert-fridge`(송풍구 바람) | 중 | 바닥이 **사라지지 않는다**. 계단식 밥 언덕(가운데 높음), 끓어오름은 **위로 튕김**(옆이 아님), 증기는 **1.2초 순간 분사**(송풍구처럼 계속 미는 바람이 아님) 띠 3개 중 하나 — 줄을 읽고 피하기 |
| `fish-market` 수산시장 | `dessert-fridge`(얼음), `cat-cafe-shelves`(굴러오는 공), `claw-machine-prize`(구역 제거), `ikura-bombs`(낙하 넉백) | **높음** | 얼음은 **미끄러운 바닥이 아니다**(`Ice` 태그 금지 — 밀어내는 블록일 뿐). 블록은 넓은 격자 줄을 통째로 쓸고 줄을 바꿈. 생선은 **바닥을 없애지 않고** 떨어진 뒤 5초 누워 있다가 한 번 팔딱(두 번째 넉백). 칸 사이 물길(틈 5)이 탈락 지점 |
| `tea-garden` 찻잎 정원 | `skewer-showdown`(가운데서 도는 막대), `ikura-bombs`(고리 순서 붕괴) | **높음** | 막대 대신 **굴러가는 찻잔**이 한 단(고리)만 돈다 → 피하는 법은 **다른 단으로 올라가거나 내려가기**(점프 타이밍이 아님). 차밭이 **본 경기 중 15초마다** 바깥 단부터 무너짐(연어알은 연장전에서만 고리 순서). 단마다 높이가 달라(계단식) 위·아래 이동이 핵심 |
| `onsen-claw` 온천탕 인형뽑기 | `claw-machine-prize`(집게·인형뽑기), `tempura-pot`(차오르는 액체) | **높음** | 집게가 **바닥을 집지 않는다** — 가운데 탁상 인형뽑기가 "쿵" 하면 **바깥으로 퍼지는 충격파 고리**(점프로 넘음, Laser Tracer·지진). 물은 올라가기 경쟁이 아니라 **낮은 데크부터 순서대로 가라앉힘**(데크 높이 차 2씩, 위치를 옮기는 게임). 높은 데크는 물에 안전하지만 충격파 발원지에 가까워 더 세게 맞음(위험·보상) |

- 새 6개끼리: 회전(접시) · 방향 전환(레일) · 위로 튕김(밥) · 쓸어내는 블록(얼음) · 굴러가는 장애물(찻잔) · 퍼지는 고리(충격파). **같은 손맛 두 번 없음.** 낙하물은 운석(Race, 바위로 남음)과 생선(Survival, 누워서 팔딱) 두 개지만 종류·효과가 다르다.
- 색: 6개 맵 히어로 색이 서로·기존 15개와 겹치지 않게 골랐다(각 스펙 "아트" 절). 위험 경고 색(빨강·주황·자홍 + 흰 테두리)은 장식에 쓰지 않는다(아트 가이드 4절) — 벚꽃 분홍·인형뽑기 분홍은 채도를 낮추거나 경고와 다른 위치에.

## 3. 풀 균형 (배치 3 이후)

| 종류 | 지금 | 배치 3 | 합계 |
|---|---|---|---|
| Race | 6 | +2 (`dish-sink`, `space-conveyor`) | **8** |
| Survival | 5 | +2 (`rice-cooker`, `fish-market`) | **7** |
| Final | 4 | +2 (`tea-garden`, `onsen-claw`) | **6** |
| 합계 | 15 | +6 | **21** |

- 한 판 규칙(`Rules.buildRoundPlan`)은 그대로: 첫 라운드 Race, 마지막 Final, 중복 없음, 4라운드면 Survival ≥ 1. 21개면 결승이 같은 맵으로 연속 나올 확률이 1/4 → 1/6로 준다(독립 추첨 가정, 추정).
- 4라운드 판에서 가운데 두 라운드 후보 = Race 7(첫 라운드에 하나 썼음) + Survival 7 — 비율이 거의 반반이라 종류가 한쪽으로 쏠리지 않는다.

## 4. 수치 근거 메모 (공통)
- 점프: 점프력 50, g = 196.2 → 최고 높이 약 6.37, 체공 약 0.51초, 걷기 16이면 수평 약 8.2(기존 스펙들 같은 계산). 저중력 0.5배면 높이 약 12.7, 체공 약 1.02초, 수평 약 16.3.
- 넉백: 기존 넉백(꼬치 32·22, 칼 45, 와사비 80·30, 연어알)과 같은 범위(수평 26~38, 위 10~22)로 잡아 `MovementGuardLogic` 면제 상한(수평 130, 위 200)보다 충분히 작다.
- 경고 시간: 기존 1~2초(젓가락 1, 칼 1.2, 연어알 1.5, 셰프 손 2, 튀는 기름 1.2)와 같은 범위.

## 4-1. 길이 (사용자 요청 2026-10-14 "맵이 좀 짧다")
- 기존 Race 6개 코스 114~294 studs, 빠른 사람 약 12~32초(코드 상수 추정), 한 판 약 2.8~3.5분 — 자세한 표는 [`docs/specs/m5-40-map-length-pass.md`](specs/m5-40-map-length-pass.md) "측정".
- 그래서 새 Race 2개는 445·470 studs(빠른 사람 45~55초), 새 Survival 2개는 `timeLimit = 75`. 추정은 사례가 아니라 우리 걷기 속도 16·장애물 상수로 계산했다(실측은 각 스펙 Studio AC).

## 5. 출처 (확인일 2026-10-14)
- Inverse, Fall Guys Dizzy Heights path — https://www.inverse.com/gaming/fall-guys-dizzy-heights-tips-strategy-path (원문)
- GameWith, Fall Guys Block Party — https://gamewith.net/fallguys/article/show/20701 (404, 검색 요약), Fandom Wall Guys/Block Party 페이지 (검색 요약)
- RoWatcher, BE CRUSHED BY A SPEEDING WALL — https://rowatcher.com/games/185284807/be-crushed-by-a-speeding-wall (원문: 설명·707.8M·최고 동접 372)
- Rolimons, BE CRUSHED BY A SPEEDING WALL — https://www.rolimons.com/game/482742811 (검색 요약)
- Prima Games, All Fall Guys Survival Rounds — https://primagames.com/tips/all-fall-guys-survival-rounds-and-strategies-to-win-them (검색 요약), TrueTrophies Jump Showdown — https://www.truetrophies.com/n18452/fall-guys (검색 요약)
- Stumble Guys update 0.86 — https://www.stumbleguys.com/news/update86 (원문: Laser Tracer Legendary 고리가 가운데서 퍼짐)
- Sportskeeda, Disasters in Natural Disaster Survival — https://sportskeeda.com/roblox-news/disasters-roblox-natural-disaster-survival (405, 검색 요약: 지진 때 계속 점프)
- RoWatcher, OBBY BUT here is Space — https://rowatcher.com/games/5038409382/obby-but-here-is-space (원문: "Survive in low gravity obby!", 3.0M)
- Roblox DevForum, Help with low gravity — https://devforum.roblox.com/t/help-with-low-gravity/1135572, Disabling Gravity On Client — https://devforum.roblox.com/t/disabling-gravity-on-client/2623378 (검색 요약: HumanoidRootPart VectorForce로 중력 일부 상쇄)
- Bloxodes, Escape The Amazing Kitchen Obby — https://bloxodes.com/stats/games/escape-the-amazing-kitchen-obby-436414416 (검색 요약: 약 11.9M)

### 확인 못 함
- Block Party·Jump Showdown의 정확한 벽 속도·발판 낙하 시각(원문 접근 불가).
- 로블록스 인기 파티 게임 중 "가운데서 퍼지는 충격파를 점프로 넘는 결승" 사례 — Stumble Guys(로블록스 아님)만 확인.
- 로블록스 설거지·밥솥·수산시장·차밭·온천 테마 맵의 구체 사례 — 주방 오비(K) 외에는 못 찾음. 테마는 사용자 시트를 그대로 따른다.
- 수치(주기·속도·넉백)는 위 사례의 "구조"와 시트의 주기만 따르고 값은 우리 점프·맵 크기로 계산한 **기본값**이다. 플레이테스트 뒤 각 맵 Layout 상수만 바꾼다.
