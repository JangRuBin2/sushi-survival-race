# REFERENCE — M5 새 맵 3개 (두 번째 결승·Survival·Race) 사례 조사

- 작성: planner, **2026-10-08** (모든 출처 확인 날짜 = 2026-10-08)
- 목적: M5 새 맵(`docs/specs/m5-04-map-ikura-bombs.md`, `m5-05-map-tempura-pot.md`, `m5-06-map-dessert-fridge.md`)의 규칙·수치를 감이 아니라 사례로 정하기 위한 근거.
- 표기: **[원문]** = WebFetch로 원문을 직접 확인, **[검색]** = 검색 결과 요약만 확인(원문 403·402 등), **확인 못 함** = 못 찾음. 추정은 "추정"이라고 쓴다.
- 이 문서는 **참고 자료**다. 규칙·수치 결정은 스펙 결정 기록에 있고, 사용자 확정 뒤 GDD 5.2에 들어간다.

---

## 0. 지금 맵 풀과 빈자리

| 종류 | 지금 맵 | 손맛 |
|---|---|---|
| Race | 회전 벨트(거슬러 달리기), 간장 늪(느려짐·와사비 튕김), 라멘 급류(앞으로 휩쓸림·가라앉는 발판·회전 막대) | 달리기 |
| Survival | 뜨거운 철판(계속 움직이기, 밟은 타일 사라짐), 셰프의 도마(칼 줄 읽고 피하기·도마 축소·기울기) | 바닥 위에서 버티기 |
| Final | 회전 꼬치 쇼다운(점프 타이밍, 조각 제거, 연장전 붕괴) | 점프 타이밍 |

- **결승 맵이 1개뿐**이라 결승이 매번 같다. 마지막 라운드가 항상 같은 경험이면 한 판의 클라이맥스가 금방 질린다 (Fall Guys도 결승 풀을 여러 개 돌림 — 아래 A·E·F).
- 빈자리: ① 결승에 **"위에서 떨어지는 것을 피하기 + 넉백"**(꼬치는 "옆에서 오는 막대를 넘기") ② Survival에 **"위로 올라가기"**(지금 둘 다 평평한 바닥) ③ Race에 **"미끄러짐"**(관성).

## 1. 사례 표

| # | 게임 / 라운드 | 종류 | 핵심 규칙 | 끝나게 하는 장치 | 근거 수준 |
|---|---|---|---|---|---|
| A | **Fall Guys — Blast Ball** | 결승 | 원형 경기장(바깥 48조각 = 3줄 × 16, 가운데 주황 고리 1개, 안쪽 8조각 + 가운데 구멍). 스포너 6곳에서 **폭탄 공**이 나오고, 집으면 약 5초 깜빡인 뒤 터져 주변을 날려 보냄. 떨어지면 슬라임 = 탈락, 마지막 1명 우승 | **시간이 갈수록 경기장 조각이 떨어짐**. 시간 제한 4:30이지만 "그 전에 경기장이 다 떨어져서 시간 초과는 사실상 불가능" | [검색] Fall Guys Wiki(Fandom 402로 원문 못 엶) |
| B | Roblox **Super Bomb Survival** | 라운드 생존 | 경기장에 **폭탄이 하늘에서 무작위로 떨어짐**, 폭발 반경이 폭탄마다 다름. 최대한 오래 살아남기 | **Intensity 1.0~5.0**: 높을수록 폭탄이 많고 빨리 오고 위험한 종류가 나옴 | [검색] earnaldo 가이드, Fandom 위키 / 게임 패스 가격은 [원문] (`REFERENCE-roblox-monetization.md` 3절 F) |
| C | Super Bomberman (배틀) | 결승형 대전 | 폭발 범위 피하기 | 1:30 "Hurry Up" → 바깥부터 벽이 떨어져 경기장 축소 | [원문] (`REFERENCE-final-overtime.md` 2절 H) |
| D | **Fall Guys — Slime Climb** | Race | 오르막 장애물 코스, **아래에서 슬라임이 차오름**, 슬라임에 닿으면 즉시 탈락. 망치·움직이는 블록·철구, 노란 범퍼 지름길 | 슬라임이 계속 올라옴 | [검색] Push Square, Kotaku |
| E | **Fall Guys — Roll Off** (시즌 3) | 결승 | "Roll Out의 결승판에 **차오르는 슬라임**을 더함" | 슬라임 상승 | [원문] TheSixthAxis 시즌 3 패치 노트 |
| F | **Fall Guys — Thin Ice** (시즌 3) | 결승 | "Hex-a-gone의 후계: 깨지는 얼음 여러 층, 마지막 1명 우승" | 얼음이 깨짐 | [원문] TheSixthAxis 시즌 3 |
| G | Roblox **The Floor Is LAVA!** | 라운드 생존 | "차오르는 용암을 피해 플랫폼 오비를 올라가 살아남기", 여러 맵 | 용암 상승 | [원문] Rowatcher(방문 **32억**, 2017년 5월 출시, 최고 동접 2.7만 2025-08) |
| H | Roblox **Flood Escape 2** | 협동 오비 | 물이 계속 차올라서 빨리 올라가야 함, 맵 50개 이상 | 물 상승 | [검색] (검색 결과 대부분 품질 낮은 사이트 — 원문 못 봄) |
| I | **Fall Guys — 시즌 3 겨울 라운드** | Race | Tundra Run("눈덩이·펀처·플리퍼를 피해 달리기"), Freezy Peak("**블리자드 팬**과 플리퍼로 정상까지"), Ski Fall("거대한 **얼음 미끄럼틀**을 내려가며 링 통과") | — | [원문] TheSixthAxis 시즌 3 |
| J | **Stumble Guys — Icy Heights** | Race | "미끄러운 바닥이라 **멈추거나 방향을 바꾸기 어려움**, 속도와 조절 사이 균형, 미리 계획" | — | [검색] |
| K | Roblox **Easy Obby but Everything Is Ice** | 오비 | 모든 발판이 얼음 — 로블록스에도 "얼음 오비"가 하나의 장르 | — | [검색] Rowatcher 게임 페이지 제목 |
| L | Roblox DevForum "Ice-walking effect for player" | 기술 | **Humanoid는 바닥 마찰을 거의 무시**해서 재질·마찰값만 바꿔서는 안 미끄러짐. 해결: **클라이언트가 속도 값을 따로 들고, 이동 방향으로 조금씩 가속하고 매 프레임 감쇠**(예: ×0.996) — 다른 사람 물리에 영향 없음 | — | [원문] devforum.roblox.com/t/3131105 |

### 읽은 것
1. **결승은 "경기장이 줄어드는 것"이 표준**이다(A·C·E·F). Blast Ball은 거기에 **넉백 폭발**을 더해 "가장자리에 몰리면 위험"을 만든다. 우리 꼬치 쇼다운과 겹치지 않는 결승 손맛 = **위에서 떨어지는 폭탄을 피하고, 폭발에 밀리고, 바닥이 줄어든다**.
2. 로블록스 아이들에게 **"폭탄이 하늘에서 떨어지는 생존"(B)과 "차오르는 용암·물(G·H)"은 이미 익숙한 장르**다. 처음 보는 사람도 규칙을 설명 없이 안다 → 라운드 소개 3초에 한 줄이면 충분.
3. 폭탄 생존(B)은 **난이도를 단계로 올린다**(개수·속도·종류). 우리 결승도 시간 단계로 폭탄 간격·개수·반경을 올린다(꼬치 쇼다운의 10초 가속·60초 서든데스와 같은 구조).
4. **차오르는 액체**는 Race(D)·결승(E)·생존(G·H) 어디에나 쓰인다. 우리는 Survival로 쓴다: 우리 Survival 판정이 "높이"라서(GDD 5.2 점수) 올라간 사람이 유리한 규칙과 딱 맞는다.
5. 얼음 Race(I·J·K)의 재미는 **"멈추기·꺾기가 어렵다"**. 바람(Freezy Peak 블리자드 팬)이 얼음 위에서 특히 무섭다. 로블록스는 Humanoid가 마찰을 무시하므로(L) **클라이언트 관성 이동**으로 만든다 — 우리 게임은 이동이 원래 클라이언트 물리이고 판정(결승선·낙하)만 서버라서(GDD 11.4) 구조가 맞는다.

## 2. 우리 맵으로 옮기기 (스펙 기본값 요약, 사용자 수정 가능)

### 2.1 Final — 연어알 폭탄 접시 (`ikura-bombs`) → `m5-04`
| 항목 | 기본값 | 근거 |
|---|---|---|
| 무대 | 지름 48 간장 접시(꼬치 쇼다운 44와 비슷), 가운데 원판 1 + 가운데 고리 6조각 + 바깥 고리 10조각 = 17칸 | A(고리·조각 구조), 결승 인원 2~5명 |
| 폭탄 | 셰프 숟가락에서 거대한 연어알이 떨어짐. 빨간 원 경고 1.5초(60초부터 1.2초) → 터지면 반경 7(60초부터 9) 안을 바깥으로 날림 + 1초 넘어짐 | B(하늘에서 떨어지는 폭탄), A(넉백), 우리 젓가락 경고 1초·셰프 손 경고 2초 사이 |
| 간격 | 3~30초 2.5초마다 1개, 30~60초 2초마다 2개, 60~90초 1.5초마다 2개, 연장전 1초마다 3개 | B(Intensity 단계), 꼬치 쇼다운 단계와 같은 시각(10/60초 리듬) |
| 노리는 곳 | 60%는 살아 있는 사람 발밑(± 3), 40%는 남은 칸 아무 데나 | 추정: 결승 인원이 적어 무작위만으로는 긴장이 약함 |
| 바닥 줄이기 | 폭발이 같은 칸을 **두 번** 맞히면 그 칸이 떨어짐(가운데 원판 제외). 40초부터 6초마다 바깥 조각 1개(3개 남을 때까지), 60초부터 가운데 조각 1개(2개 남을 때까지) | A(조각이 떨어짐), C(축소) |
| 연장전 | 남은 칸이 바깥 고리 → 가운데 고리 → 가운데 원판 순서로 1초 경고 뒤 떨어짐, 마지막이 20초 | `REFERENCE-final-overtime.md` 3절, m5-01 계약 |

### 2.2 Survival — 튀김 냄비 탈출 (`tempura-pot`) → `m5-05`
| 항목 | 기본값 | 근거 |
|---|---|---|
| 무대 | 지름 72 냄비 속, 튀김 조각(새우튀김·고구마·깻잎) 발판이 4 studs 높이 간격(7~31)으로 탑처럼 쌓임, 맨 위 세 층(23·27·31)은 기름이 닿지 않음 | G·H(올라가서 버티기), 점프 높이 약 6.4(점프력 50) |
| 기름 | 6초까지 그대로, 그 뒤 0.4 studs/s로 차올라 22에서 멈춤(60초에 21.6) | D·E·G(차오르는 액체) |
| 탈락 | 발이 기름 표면 아래로 들어가면 "튀겨짐" 탈락 | D("닿으면 즉시 탈락") |
| 튀는 기름 | 10초부터 3초마다(30초부터 2초, 45초부터 1.5초) 한 사람 발밑에 주황 원 1.2초 경고 → 기름이 튀어 반경 5 안을 밀어냄 + 넘어짐 | B(경고 뒤 폭발), 맨 위가 "안전한 자리"로 굳지 않게 |
| 맨 위 넓이 | 약 8~10명이 설 수 있는 크기 | Survival은 시간이 끝나면 버틴 사람 전원 통과(GDD 5.2) — 맨 위가 너무 넓으면 아무도 안 떨어짐 |

### 2.3 Race — 디저트 냉장고 (`dessert-fridge`) → `m5-06`
| 항목 | 기본값 | 근거 |
|---|---|---|
| 코스 | 약 260 studs: 출발 → 얼음 쟁반(얼음 바닥, 구멍 2개·얼음 큐브 슬라롬) → 젤리 계단(밟으면 튕겨 위 선반으로) → 찬바람 선반(얼음 + 옆으로 미는 송풍구 2개) → 냉장고 문 결승 | I(얼음 미끄럼틀·블리자드 팬), J(멈추기 어려움), 간장 늪 와사비(튕김 재사용) |
| 얼음 | 클라이언트 관성: 얼음 위에서는 실제 속도에서 출발해 입력 방향 목표 속도 쪽으로 천천히 다가감(가속 계수 2.5/s → 약 0.9초에 90%), 손을 떼면 감쇠 1.0/s(걷기 속도에서 약 16 studs 미끄러짐). 반대로 누르면 0.3초 안에 멈춤. 최고 속도는 걷기 속도 그대로 | L(속도 누적 + 감쇠), 최고 속도를 안 올려 이동 감시(80 studs/s)와 무관 |
| 송풍구 | 2초 불고 2초 쉼(불기 0.5초 전 서리 입자 경고), 옆으로 14 studs/s까지 밂 | I(블리자드 팬), 라멘 급류 소용돌이 옆 밀기 10과 비슷하게 |

## 3. 출처 (확인일 2026-10-08)
- Fall Guys Wiki, Blast Ball — https://fallguysultimateknockout.fandom.com/wiki/Blast_Ball (402, 검색 요약: 조각 구조·폭탄 5초·4:30·"시간 초과 사실상 불가")
- Pro Game Guides, How to play Blast Ball — https://progameguides.com/fall-guys/how-to-play-blast-ball-in-fall-guys/ (403, 확인 못 함)
- earnaldo, Super Bomb Survival 가이드 — https://earnaldo.com/blog/super-bomb-survival-free-robux-guide (검색 요약: 하늘에서 폭탄, Intensity 1.0~5.0)
- Super Bomb Survival 위키 Bombs — https://roblox-super-bomb-survival.fandom.com/wiki/Bombs (검색 요약)
- Push Square, Fall Guys 라운드 가이드 — https://www.pushsquare.com/guides/fall-guys-all-rounds-and-how-to-win-every-game-type (검색 요약: Slime Climb)
- Kotaku, "Slime Climb should never be the first Fall Guys round" — https://kotaku.com/slime-climb-should-never-be-the-first-fall-guys-round-1844675472 (검색 요약)
- TheSixthAxis, Fall Guys Season 3 patch notes (2020-12-14) — https://www.thesixthaxis.com/2020/12/14/fall-guys-season-3-patch-notes-update-changelog-pc-ps4-ps5/ (원문: Tundra Run·Freezy Peak·Ski Fall·Thin Ice·Roll Off 설명)
- Rowatcher, The Floor Is LAVA! — https://rowatcher.com/games/341654025/the-floor-is-lava (원문: 설명·방문 32억·출시·최고 동접)
- Flood Escape 2 — 검색 결과만 (원문 신뢰할 페이지 못 찾음)
- Stumble Guys Icy Heights — 검색 요약 (원문 출처 특정 못 함)
- Rowatcher, Easy Obby but Everything Is Ice — https://rowatcher.com/games/5943673771/easy-obby-but-everything-is-ice (검색 결과 제목)
- Roblox DevForum, "Ice-walking effect for player" — https://devforum.roblox.com/t/ice-walking-effect-for-player/3131105 (원문)
- Roblox DevForum, "Making a specific default character slide on ice" — https://devforum.roblox.com/t/making-a-specific-default-character-slide-on-ice/1896896 (검색 요약: 마찰은 양쪽 표면 상호작용, 캐릭터 쪽만 바꾸면 안 됨)

### 확인 못 함
- Blast Ball의 정확한 조각 낙하 간격·폭발 반경 수치 (위키 원문 접근 불가).
- 로블록스 인기 "Fall Guys류" 게임 중 폭탄 결승을 쓰는 사례 — 찾지 못함 (Super Bomb Survival은 라운드 생존 전체가 폭탄).
- 우리 숫자(간격·반경·상승 속도)는 위 사례의 "구조"만 따르고 값은 우리 맵 크기·점프 높이로 계산한 **기본값**이다. 플레이테스트 뒤 Layout 상수만 바꿔 조정한다.
