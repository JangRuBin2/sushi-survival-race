status: ready
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-22 — 스킨 1차 배치 10종

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §6, §9.1, §9.2 (v0.6)
- 담당 개발 worktree: `m5-skinpack1` (Rojo 포트 34883)
- 공용 파일 수정 담당: 없음
- 의존: **m5-21(`m5-21-skin-foundation-v2.md`) 머지 후 시작**. 아래 "m5-21 의존 가정"을 반드시 머지된 실제 구현과 맞춰 본다.

## 목표
탈의실에 새 스킨 10종이 추가돼, 플레이어가 기존 21종과 실루엣·색이 뚜렷이 다른 토핑(쐐기 모양 귀·왕관·뿔, 2중 효과, 넓은 박스 허용치)을 입고 달릴 수 있다. `docs/proposals/skin-quality-and-variety.md` §3에서 사용자가 위임으로 고른 1차 10종을 실제 `Skins.luau`/`SushiBody.luau` 데이터로 만든다.

## 범위
- 포함: 아래 10종의 `Skins.LIST` 항목, `SushiBody.LAYOUTS` 조립 함수(새 색상 상수 포함), `tests/skins.spec.luau` 갱신 가이드(기대값 표·등급별 박스/효과 테스트).
- 제외: 제안서 §3의 나머지 10종(불새 롤·디스코볼 롤·딸기 다이후쿠·가지말이·달걀말이 자매품·번개 롤·닌자 롤·메카 드래곤 롤·고스트 캡틴 롤·체리블라썸 롤 — 다음 배치 후보로 제안서에 남김). 탈의실 UI·미리보기 각도 변경(제안서 §2-5). m5-21의 인프라 자체(Wedge 분기, 등급별 예산 구현) — 이 스펙은 그 인프라를 **쓰기만** 한다.

## m5-21 의존 가정 (머지 전 작성 — 실제 구현과 다르면 "결정 기록"에 질문을 남기고 맞춘다)
이 스펙 작성 시점에 m5-21 스펙 파일이 아직 없어 제안서 §4-A·B·C 기준으로 아래를 가정한다.
1. **Wedge**: `SushiBody.Shape`에 `"Wedge"`가 추가되고, `build()`가 `spec.shape == "Wedge"`일 때 `Instance.new("WedgePart")`를 만든다(일반 Part의 `Shape` 속성이 아니라 별도 ClassName). `piece()` 헬퍼는 이미 `shape` 필드를 그대로 통과시키므로 추가 변경이 필요 없다.
2. **bounds() 무변경**: `SushiBody.bounds`는 `spec.size`(회전 반영)만 보고 `spec.shape`를 보지 않는다. WedgePart의 축 정렬 외곽 상자는 같은 Size의 Block과 **정확히 같다**(쐐기가 상자를 깎아낼 뿐 상자 자체는 그대로) — 따라서 이 스펙의 모든 Wedge 파츠는 **Block처럼 size/offset/rotation으로 계산**하면 된다. m5-21이 이 전제를 깨고 `bounds()`에 쐐기 전용 보정을 넣었다면, 아래 수치(특히 여유가 빠듯한 고양이 초밥·소프트아이스크림 롤·유니콘 롤)를 다시 확인해야 한다.
3. **효과 예산**: `effectCount` 류 검사가 스킨의 `tier`를 받아 일반·레어는 ≤1, 에픽·전설은 ≤2로 분기한다고 가정(GDD 9.2). 효과 종류는 Fire·Sparkles·Smoke·Glow 4종.
4. **박스 허용치**: `tests/skins.spec.luau`의 `TOLERANCE`가 등급별로 분기해 일반·레어는 ±15%, 에픽·전설은 ±25%라고 가정(GDD 6).
5. 위 네 가지가 실제 m5-21과 다르면(예: 함수 시그니처, 상수 이름) developer가 이 스펙의 "개발 메모"에 불일치를 적고 수치만 그대로 재사용한다 — 디자인 의도(비율·위치)는 안 바뀐다.

## 공통 설계 원칙 (수치 검증 전략)
- 모든 신규 스킨은 기존 21종처럼 `withBase(...)`로 Body·눈·입·발을 그대로 가져온다(AC2 히트박스 테스트가 강제).
- 계란초밥(`tamago`) 전체 외곽은 X(폭) 2.8 · Y(높이) 4.7 · Z(두께) 2.25 — 바닥(발바닥)은 모든 스킨에서 항상 y = −2.3으로 고정(발 파츠가 같으므로). 즉 "박스 예산"은 사실상 **맨 위 꼭짓점이 얼마나 높이 올라갈 수 있는가**로 환산된다.
  - 일반·레어(±15%): 높이 상한 4.7×1.15 = 5.405 → 바닥 −2.3 고정이므로 **꼭대기 y ≤ 약 3.10**까지 여유.
  - 에픽·전설(±25%): 높이 상한 4.7×1.25 = 5.875 → **꼭대기 y ≤ 약 3.58**까지 여유.
- 폭(X)·두께(Z)는 기존 `slab()`(토핑 {2.8,0.8,2.2} offset {0,2.0,0.2}) + `ToppingBack`({2.6,1.6,0.3} offset {0,0.9,1.05}) 짝을 "앵커"로 그대로 재사용하면 폭·두께가 자동으로 허용치 안에 들어온다(기존 16종이 이미 이 조합으로 통과했음). 아래 10종 전부 이 앵커를 토대로 토핑 모양·색만 바꾸고, 돌출 장식(귀·안테나·왕관·뿔·갈기·소프트아이스크림 탑)만 높이 예산을 직접 계산해 배치했다.
- **여유가 빠듯한 3종**(고양이 초밥, 소프트아이스크림 롤, 유니콘 롤)은 아래 표에 계산한 꼭대기 y·높이 비율을 적어뒀다. `lune run tests`(AC2 박스 테스트)가 실패하면 **그 스킨의 가장 높은 파츠 offset.y만 0.05~0.15 낮춰서** 다시 맞춘다 — 모양·색은 그대로 두고 수치만 조정.

---

## 10종 상세

### 1. 타코야키 (일반, 29 R$ / 300 코인)
울퉁불퉁한 동그란 덩어리(작은 Ball 4개 뭉침) + 뒤쪽 받침판 + 초록 가다랑어포 물결 띠 + 흰 마요 지그재그.

색: `TAKOYAKI_BROWN = {196,140,92}`, `TAKOYAKI_DARK = {150,100,60}`, `BONITO_GREEN = {140,170,90}`, `MAYO_WHITE = {255,250,235}`.

| 파츠 | shape | size | color | offset | rotation | material |
|---|---|---|---|---|---|---|
| DomeBack (앵커) | Block | {2.6, 1.4, 0.3} | TAKOYAKI_DARK | {0, 0.9, 1.0} | — | SmoothPlastic |
| Dome1 | Ball | {1.1,1.1,1.1} | TAKOYAKI_BROWN | {-0.55, 2.05, -0.25} | — | SmoothPlastic |
| Dome2 | Ball | {1.1,1.1,1.1} | TAKOYAKI_BROWN | {0.55, 2.05, -0.25} | — | SmoothPlastic |
| Dome3 | Ball | {1.15,1.15,1.15} | TAKOYAKI_BROWN | {0, 2.1, 0.35} | — | SmoothPlastic |
| BonitoWave1 | Block | {1.6,0.05,0.35} | BONITO_GREEN | {-0.3, 2.62, 0.0} | {0,15,0} | SmoothPlastic |
| BonitoWave2 | Block | {1.5,0.05,0.35} | BONITO_GREEN | {0.35, 2.58, 0.2} | {0,-10,0} | SmoothPlastic |
| MayoZig1 | Block | {0.9,0.05,0.18} | MAYO_WHITE | {-0.4, 2.65, -0.4} | {0,25,0} | SmoothPlastic |
| MayoZig2 | Block | {0.9,0.05,0.18} | MAYO_WHITE | {0.3, 2.6, 0.1} | {0,-20,0} | SmoothPlastic |
| MayoZig3 | Block | {0.9,0.05,0.18} | MAYO_WHITE | {-0.1, 2.63, 0.55} | {0,15,0} | SmoothPlastic |

검산: 꼭대기 ≈ y 2.68(MayoZig1), 폭 X −1.3~1.3(DomeBack), 두께 Z −0.8~1.15. 전부 일반 등급 허용치 안. 효과 없음.

### 2. 에그토스트 ★ (일반, 29 R$ / 300 코인)
식빵색 토핑 + 테두리 크러스트 + **의도적으로 한쪽에 치우친** 노른자(좌우 비대칭 — 기존 21종은 전부 대칭).

색: `EGGTOAST_BREAD = {235,205,150}`, `EGGTOAST_CRUST = {200,150,90}`, `YOLK_YELLOW = {255,200,60}`, `YOLK_SHADE = {235,170,40}`.

| 파츠 | shape | size | color | offset | material |
|---|---|---|---|---|---|
| Topping | Block | {2.8,0.8,2.2} | EGGTOAST_BREAD | {0, 2.0, 0.2} | SmoothPlastic |
| ToppingBack (앵커) | Block | {2.6,1.6,0.3} | EGGTOAST_BREAD | {0, 0.9, 1.05} | SmoothPlastic |
| CrustEdge | Block | {2.82,0.15,2.22} | EGGTOAST_CRUST | {0, 2.42, 0.2} | SmoothPlastic |
| Yolk | Ball | {0.8,0.8,0.8} | YOLK_YELLOW | {0.55, 2.5, 0.35} | SmoothPlastic |
| YolkShade | Ball | {0.3,0.3,0.3} | YOLK_SHADE | {0.7, 2.65, 0.5} | SmoothPlastic |

검산: 꼭대기 ≈ y 2.9(Yolk), 노른자가 오른쪽·앞쪽에만 있어 왼쪽은 빈 크러스트 — 비대칭 실루엣 확보. 효과 없음.

### 3. 슬라이더 버거 ★ (일반, 29 R$ / 300 코인)
번 색 돔 + 패티 띠 + 양상추 지그재그 가장자리(앞·뒤) + 참깨 점.

색: `SLIDER_BUN = {210,150,90}`, `PATTY_BROWN = {110,70,45}`, `LETTUCE_GREEN = {95,165,70}`, `SESAME_WHITE = {250,245,230}`.

| 파츠 | shape | size | color | offset | rotation |
|---|---|---|---|---|---|
| Topping | Block | {2.8,0.8,2.2} | SLIDER_BUN | {0, 2.0, 0.2} | — |
| ToppingBack (앵커) | Block | {2.6,1.6,0.3} | SLIDER_BUN | {0, 0.9, 1.05} | — |
| PattyBand | Block | {2.82,0.18,2.22} | PATTY_BROWN | {0, 2.38, 0.2} | — |
| LettuceZig1 | Block | {2.84,0.08,0.4} | LETTUCE_GREEN | {0, 2.47, -0.75} | {0,0,8} |
| LettuceZig2 | Block | {2.84,0.08,0.4} | LETTUCE_GREEN | {0, 2.44, 1.05} | {0,0,-8} |
| Sesame1 | Ball | {0.12,0.12,0.12} | SESAME_WHITE | {-0.6, 2.47, -0.1} | — |
| Sesame2 | Ball | {0.12,0.12,0.12} | SESAME_WHITE | {0.5, 2.46, 0.3} | — |
| Sesame3 | Ball | {0.12,0.12,0.12} | SESAME_WHITE | {-0.2, 2.48, 0.6} | — |
| Sesame4 | Ball | {0.12,0.12,0.12} | SESAME_WHITE | {0.3, 2.45, -0.5} | — |

검산: 꼭대기 ≈ y 2.54, 갈색·초록·흰색 블로킹이 또렷. 효과 없음.

### 4. 돈가스 (레어, 59 R$ / 900 코인)
황금 튀김옷 + 사선 리지(기존 `stripes()` 재사용) + 뒤쪽 양배추채 컬(Cylinder) + 소스 줄.

색: `TONKATSU_GOLD = {215,165,70}`, `TONKATSU_RIDGE = {180,130,50}`, `CABBAGE_GREEN = {150,210,120}`, `SAUCE_BROWN = {90,55,30}`.

| 파츠 | shape | size | color | offset | rotation |
|---|---|---|---|---|---|
| Topping | Block | {2.8,0.8,2.2} | TONKATSU_GOLD | {0, 2.0, 0.2} | — |
| ToppingBack (앵커) | Block | {2.6,1.6,0.3} | TONKATSU_GOLD | {0, 0.9, 1.05} | — |
| Ridge0/1/2 | Block | `stripes(TONKATSU_RIDGE, 20)` 그대로 재사용(기존 헬퍼, x=-0.8/0/0.8, y 2.42, z 0.2) | — | {0,20,0} |
| CabbageCurl1 | Cylinder | {0.12,0.5,0.5} | CABBAGE_GREEN | {-0.5, 0.98, 1.15} | DISC `{0,0,90}` |
| CabbageCurl2 | Cylinder | {0.12,0.5,0.5} | CABBAGE_GREEN | {0, 1.0, 1.2} | DISC |
| CabbageCurl3 | Cylinder | {0.12,0.5,0.5} | CABBAGE_GREEN | {0.5, 0.98, 1.15} | DISC |
| SauceDrip | Block | {2.4,0.05,0.3} | SAUCE_BROWN | {0, 2.43, -0.9} | — |

검산: 꼭대기 ≈ y 2.43(Ridge/SauceDrip, `stripes()` offset y는 2.42), 두께 Z는 CabbageCurl이 1.45까지 살짝 넓혀 폭·두께 모두 레어 ±15% 안. 효과 없음.

### 5. 고양이 초밥 ★ (레어, 59 R$ / 900 코인) — **여유 빠듯, 우선 검증**
크림색 토핑 + Wedge 귀 2개(머리 위로 솟는 첫 실루엣) + 분홍 코 + 수염(Cylinder).

색: `CAT_CREAM = {250,240,225}`, `CAT_EAR_PINK = {255,160,190}`, `CAT_EAR_INNER = {255,200,215}`, `CAT_NOSE = {255,120,160}`, `WHISKER_WHITE = {255,255,255}`.

| 파츠 | shape | size | color | offset | rotation |
|---|---|---|---|---|---|
| Topping | Block | {2.8,0.8,2.2} | CAT_CREAM | {0, 2.0, 0.2} | — |
| ToppingBack (앵커) | Block | {2.6,1.6,0.3} | CAT_CREAM | {0, 0.9, 1.05} | — |
| EarLeft | **Wedge** | {0.5,0.7,0.35} | CAT_EAR_PINK | {-0.65, 2.68, -0.45} | {0,0,20} |
| EarRight | **Wedge** | {0.5,0.7,0.35} | CAT_EAR_PINK | {0.65, 2.68, -0.45} | {0,0,-20} |
| EarInnerLeft | **Wedge** | {0.25,0.4,0.15} | CAT_EAR_INNER | {-0.65, 2.65, -0.5} | {0,0,20} |
| EarInnerRight | **Wedge** | {0.25,0.4,0.15} | CAT_EAR_INNER | {0.65, 2.65, -0.5} | {0,0,-20} |
| Nose | Ball | {0.25,0.25,0.25} | CAT_NOSE | {0, 0.8, -0.95} | — |
| WhiskerLeft1 | Cylinder | {0.03,0.03,0.9} | WHISKER_WHITE | {-1.0, 0.75, -0.85} | {0,10,0} |
| WhiskerRight1 | Cylinder | {0.03,0.03,0.9} | WHISKER_WHITE | {1.0, 0.75, -0.85} | {0,-10,0} |

검산(중요): EarLeft/Right는 Z축 20도 회전만 받아 수직 반폭 = |cos20°|·0.35 + |sin20°|·0.25 ≈ 0.414 → **꼭대기 y ≈ 2.68 + 0.414 = 3.094**, 레어 예산(≈3.10) 안이지만 여유가 0.01 studs뿐이다. **AC2가 실패하면 EarLeft/EarRight·EarInner의 offset.y를 0.05~0.1 낮춘다** (예: 2.68 → 2.6). 폭(X)·두께(Z)는 ToppingBack 앵커가 지배해 문제없음. 효과 없음(코드 느낌을 밋밋하지 않게 하려면 추후 배치에서 추가 검토).

### 6. 로보 롤 ★ (레어, 59 R$ / 900 코인)
크롬 그레이 토핑 + 눈 위에 겹치는 네온 바이저 띠 + 뒤쪽 안테나(Cylinder+Ball, 끝에 Glow).

색: `ROBO_GRAY = {150,155,165}`, `ROBO_DARK = {90,95,105}`, `VISOR_NEON = {60,220,255}`, `ANTENNA_TIP = {255,60,90}`.

| 파츠 | shape | size | color | offset | rotation | effect |
|---|---|---|---|---|---|---|
| Topping | Block | {2.8,0.8,2.2} | ROBO_GRAY | {0, 2.0, 0.2} | — | — |
| ToppingBack (앵커) | Block | {2.6,1.6,0.3} | ROBO_DARK | {0, 0.9, 1.05} | — | — |
| VisorBand | Block | {2.84,0.22,0.12} | VISOR_NEON | {0, 1.05, -0.97} | — | — (Neon 재질, 기존 눈 위에 겹쳐 얹음) |
| AntennaRod | Cylinder | {0.6,0.08,0.08} | ROBO_DARK | {0, 2.65, 1.0} | {0,0,90} | — |
| AntennaTip | Ball | {0.22,0.22,0.22} | ANTENNA_TIP | {0, 2.95, 1.0} | — | **Glow**, effectColor {255,60,90} |

VisorBand material = `"Neon"`. 검산: 꼭대기 ≈ y 3.06(AntennaTip), 레어 예산(≈3.10) 안으로 여유 0.04 — 역시 빠듯한 편, AC2 실패 시 AntennaRod offset.y를 2.55~2.6으로 낮춘다. 효과 1개(Glow, 레어 상한 1개 그대로 사용).

### 7. 갤럭시 롤 ★ (에픽, 99 R$)
짙은 남색 토핑 + 흰·청록 별 점(Ball) 흩뿌림 + Sparkles + Glow(2효과, 에픽 상한 활용).

색: `GALAXY_NAVY = {30,25,70}`, `GALAXY_STAR_WHITE = {245,245,255}`, `GALAXY_STAR_TEAL = {90,220,210}`.

| 파츠 | shape | size | color | offset | effect |
|---|---|---|---|---|---|
| Topping | Block | {2.8,0.8,2.2} | GALAXY_NAVY | {0, 2.0, 0.2} | — |
| ToppingBack (앵커) | Block | {2.6,1.6,0.3} | GALAXY_NAVY | {0, 0.9, 1.05} | — |
| Star1 | Ball | {0.12,0.12,0.12} | GALAXY_STAR_WHITE | {-0.8, 2.46, -0.3} | — |
| Star2 | Ball | {0.12,0.12,0.12} | GALAXY_STAR_WHITE | {0.6, 2.47, 0.1} | — |
| Star3 | Ball | {0.12,0.12,0.12} | GALAXY_STAR_WHITE | {-0.3, 2.45, 0.6} | — |
| Star4 | Ball | {0.12,0.12,0.12} | GALAXY_STAR_WHITE | {0.4, 2.48, -0.7} | — |
| Star5 | Ball | {0.12,0.12,0.12} | GALAXY_STAR_TEAL | {-0.5, 2.47, 0.9} | — |
| SparkleCore | Ball | {0.15,0.15,0.15} | GALAXY_STAR_TEAL | {0, 2.5, 0.2} | **Sparkles**, {120,230,220} |
| GlowCore | Ball | {0.2,0.2,0.2} | GALAXY_STAR_WHITE | {0, 0.9, 1.15} | **Glow**, {200,200,255} |

검산: 꼭대기 ≈ y 2.65, 에픽 예산(≈3.58)에 한참 못 미쳐 여유 충분. 효과 2개(Sparkles + Glow).

### 8. 소프트아이스크림 롤 ★ (에픽, 99 R$) — **여유 빠듯, 우선 검증**
짧은 원판 Cylinder를 지름이 점점 줄며 쌓아 소용돌이를 흉내(수직 구조는 21종 중 처음) + 체리 Ball + 콘색 받침.

색: `SOFTSERVE_CREAM = {255,248,235}`, `SOFTSERVE_SHADE = {240,225,200}`, `CHERRY_RED = {200,30,40}`, `CONE_TAN = {210,160,90}`.

| 파츠 | shape | size | color | offset | rotation |
|---|---|---|---|---|---|
| ConeBand (앵커) | Block | {2.6,1.0,0.3} | CONE_TAN | {0, 1.0, 1.05} | — |
| Swirl1 | Cylinder | {0.45,2.6,2.6} | SOFTSERVE_CREAM | {0, 1.95, 0.2} | DISC `{0,0,90}` |
| Swirl2 | Cylinder | {0.4,2.0,2.0} | SOFTSERVE_SHADE | {0, 2.3, 0.2} | DISC |
| Swirl3 | Cylinder | {0.35,1.4,1.4} | SOFTSERVE_CREAM | {0, 2.65, 0.2} | DISC |
| SwirlTip | Ball | {0.5,0.5,0.5} | SOFTSERVE_SHADE | {0, 2.95, 0.2} | — |
| Cherry | Ball | {0.3,0.3,0.3} | CHERRY_RED | {0, 3.35, 0.2} | — |

주의: 이 스킨은 `Topping`/`ToppingBack` 대신 `ConeBand`만 앵커로 쓰고 egg 자리의 토핑을 전부 Cylinder 더미로 대체한다(수직 구조 강조). 검산: 꼭대기 ≈ y 3.5(Cherry), 전체 높이 = 3.5 − (−2.3) = 5.8, 비율 5.8/4.7 ≈ 1.234 — 에픽 허용치(1.25) **안이지만 여유 0.016뿐**. 두께(Z)는 Swirl1 지름 2.6으로 ±1.3~1.5 범위, 비율 약 1.16으로 안전. **AC2 실패 시 Cherry·SwirlTip의 offset.y를 0.1~0.2 낮춘다**(모양 비율은 그대로, 전체를 살짝 눌러 넣기). 효과 없음(제안서 원안에 효과 언급 없음 — 추후 배치에서 추가 검토 가능).

### 9. 크라운 참치 (전설, 199 R$)
짙은 빨강 참치 베이스 + 금색 Wedge 스파이크 5개(왕관, 가운데가 가장 높은 아치형) + 벨벳 망토 Wedge 2장(Sparkles + Glow, 전설 2효과 활용).

색: `CROWN_TUNA_RED = {150,25,40}`, `CROWN_GOLD = {255,205,70}`, `CAPE_VELVET = {90,20,60}`.

| 파츠 | shape | size | color | offset | rotation | effect |
|---|---|---|---|---|---|---|
| Topping | Block | {2.8,0.8,2.2} | CROWN_TUNA_RED | {0, 2.0, 0.2} | — | — |
| ToppingBack (앵커) | Block | {2.6,1.6,0.3} | CROWN_TUNA_RED | {0, 0.9, 1.05} | — | — |
| CrownBase | Block | {2.2,0.3,1.8} | CROWN_GOLD | {0, 2.55, 0.2} | — | — |
| CrownSpike1 | **Wedge** | {0.3,0.5,0.3} | CROWN_GOLD | {-0.8, 2.95, 0.2} | — | — |
| CrownSpike2 | **Wedge** | {0.3,0.5,0.3} | CROWN_GOLD | {-0.4, 3.0, 0.2} | — | — |
| CrownSpike3 | **Wedge** | {0.3,0.5,0.3} | CROWN_GOLD | {0, 3.05, 0.2} | — | **Sparkles**, {255,225,140} |
| CrownSpike4 | **Wedge** | {0.3,0.5,0.3} | CROWN_GOLD | {0.4, 3.0, 0.2} | — | — |
| CrownSpike5 | **Wedge** | {0.3,0.5,0.3} | CROWN_GOLD | {0.8, 2.95, 0.2} | — | — |
| CapeLeft | **Wedge** | {1.0,1.8,0.1} | CAPE_VELVET | {-0.7, 0.6, 1.25} | {10,0,15} | **Glow**, {160,60,120} |
| CapeRight | **Wedge** | {1.0,1.8,0.1} | CAPE_VELVET | {0.7, 0.6, 1.25} | {10,0,-15} | — |

검산: 꼭대기 ≈ y 3.3(CrownSpike3), 전체 높이 5.6, 비율 1.191 — 전설 허용치(1.25) 안 여유 충분. 두께 Z는 Cape 쪽이 약 1.46까지 넓혀 비율 ≈1.05, 안전. 효과 2개(Sparkles + Glow) — `golden-otoro`(에픽 수준 효과 1개뿐)보다 확실히 화려해지도록 설계.

### 10. 유니콘 롤 ★ (전설, 199 R$) — **여유 빠듯, 우선 검증**
흰 토핑 + 지름이 점점 줄어드는 Cylinder 3단 나선 뿔(Sparkles) + 한쪽으로만 늘어지는 비대칭 리본형 Wedge 갈기 3장(Glow).

색: `UNICORN_WHITE = {255,250,250}`, `MANE_PINK = {255,170,210}`, `MANE_LILAC = {200,170,255}`, `MANE_MINT = {160,230,210}`, `HORN_GOLD = {255,215,120}`, `HORN_GOLD_LIGHT = {255,235,180}`.

| 파츠 | shape | size | color | offset | rotation | effect |
|---|---|---|---|---|---|---|
| Topping | Block | {2.8,0.8,2.2} | UNICORN_WHITE | {0, 2.0, 0.2} | — | — |
| ToppingBack (앵커) | Block | {2.6,1.6,0.3} | UNICORN_WHITE | {0, 0.9, 1.05} | — | — |
| HornBase | Cylinder | {0.5,0.35,0.35} | HORN_GOLD | {0, 2.65, -0.3} | {0,0,90} | — |
| HornMid | Cylinder | {0.4,0.22,0.22} | HORN_GOLD | {0, 3.05, -0.35} | {0,0,90} | — |
| HornTip | Cylinder | {0.3,0.1,0.1} | HORN_GOLD_LIGHT | {0, 3.35, -0.4} | {0,0,90} | **Sparkles**, {255,210,245} |
| Mane1 | **Wedge** | {0.25,1.0,0.6} | MANE_PINK | {-1.1, 1.6, 0.6} | {0,0,25} | **Glow**, {200,170,255} |
| Mane2 | **Wedge** | {0.22,0.9,0.55} | MANE_LILAC | {-1.15, 1.0, 0.9} | {0,0,30} | — |
| Mane3 | **Wedge** | {0.2,0.8,0.5} | MANE_MINT | {-1.1, 0.4, 1.1} | {0,0,20} | — |

검산: 꼭대기 ≈ y 3.5(HornTip), 전체 높이 5.8, 비율 ≈1.234 — 전설 허용치(1.25) 안이지만 여유 0.016뿐(소프트아이스크림 롤과 같은 수준). 갈기는 왼쪽에만 있어(비대칭) 폭(X)이 왼쪽으로 −1.45까지 넓어지지만 비율 0.982로 안전. **AC2 실패 시 HornMid·HornTip의 offset.y를 0.1 안팎 낮춘다.** 효과 2개(Sparkles + Glow).

---

## 가격·등급·speech 정리 (Skins.luau 추가분, order 22~31)

| order | id | displayName | tier | robux | coins | productId | speech |
|---|---|---|---|---|---|---|---|
| 22 | `takoyaki` | 타코야키 | Common | 29 | 300 | nil | "동글동글 타코야키~" / "소스 범벅이 최고야!" |
| 23 | `egg-toast` | 에그토스트 | Common | 29 | 300 | nil | "폭신폭신 식빵 위에 반숙 노른자!" / "한 입 베어 물면 사르르~" |
| 24 | `slider-burger` | 슬라이더 버거 | Common | 29 | 300 | nil | "작아도 한 입 가득 든든해!" / "패티 육즙이 살아있어~" |
| 25 | `tonkatsu` | 돈가스 | Rare | 59 | 900 | nil | "바삭한 튀김옷이 일품!" / "소스 듬뿍 찍어 먹자~" |
| 26 | `cat-sushi` | 고양이 초밥 | Rare | 59 | 900 | nil | "야옹~ 잡아봐!" / "수염도 쫑긋, 귀도 쫑긋!" |
| 27 | `robo-roll` | 로보 롤 | Rare | 59 | 900 | nil | "삐빅, 시스템 가동 완료!" / "레이더에 간장이 감지됨!" |
| 28 | `galaxy-roll` | 갤럭시 롤 | Epic | 99 | nil | nil | "우주의 맛이 느껴져?" / "별빛처럼 반짝반짝~" |
| 29 | `softserve-roll` | 소프트아이스크림 롤 | Epic | 99 | nil | nil | "살살 녹는 소프트콘!" / "체리 하나로 완성!" |
| 30 | `crown-tuna` | 크라운 참치 | Legendary | 199 | nil | nil | "오늘의 왕은 나야!" / "참치 중의 참치, 왕관을 쓰다" |
| 31 | `unicorn-roll` | 유니콘 롤 | Legendary | 199 | nil | nil | "마법 같은 맛이지?" / "무지갯빛 꿈을 싣고 달려!" |

`Skins.validate`의 기존 규칙 그대로: Common·Rare는 `robux`+`coins` 둘 다, Epic·Legendary는 `robux`만(coins는 nil). `season`·`tokens`·`vipOnly`는 전부 nil(시즌·VIP 스킨 아님).

## 탈락 대사 톤 재확인 (GDD 9.1, v0.6) — 요구사항 4
다음 7종(★, 비초밥 테마)은 "맛"을 언급하지 않는 대사로 바꿔 톤을 맞췄다 — `EliminationCutsceneLogic.linesFor`가 `Chopsticks`/`Mouth`/`ChefHand` 세 변형에 그대로 섞어 쓰므로, 맛 표현이 없어도 감탄사·캐릭터성만으로 자연스럽게 읽히는지가 기준이다.
- **에그토스트**: "폭신폭신 식빵 위에 반숙 노른자!" — 식감 묘사로 "맛있다" 대신 질감을 강조.
- **슬라이더 버거**: "패티 육즙이 살아있어~" — 음식이라 기존 톤과 크게 다르지 않음, 비교군으로 유지.
- **고양이 초밥**: "야옹~ 잡아봐!" — 음식 맛이 아니라 캐릭터(고양이) 반응으로 완전히 새 톤.
- **로보 롤**: "삐빅, 시스템 가동 완료!" — 기계음 의성어, 맛 표현 없음.
- **갤럭시 롤**: "우주의 맛이 느껴져?" — 음식 어휘를 테마에 맞게 변주(맛+우주).
- **소프트아이스크림 롤**: "살살 녹는 소프트콘!" — 여전히 음식이라 톤 유지, 비교군.
- **유니콘 롤**: "마법 같은 맛이지?" — 음식 어휘를 테마에 맞게 변주(맛+마법).
developer는 이 7종 중 "고양이 초밥"·"로보 롤"처럼 맛 표현이 전혀 없는 대사가 `Chopsticks`(젓가락 → 간장 → 냠!) 변형에서 어색하지 않은지 Studio에서 들어보고, 어색하면 이 스펙의 후보 문장을 그대로 바꿔도 된다(디자인 의도는 "맛 대신 캐릭터성"이므로 문장 교체는 자유, 자리 비우지 않기만 하면 됨).

## 수용 기준

### 순수 로직 (lune 테스트로 확인)
- [ ] AC1: `tests/skins.spec.luau`의 `EXPECTED` 표가 31개 항목(기존 21 + 이 스펙 10)으로 갱신되고, `Skins.LIST`·`Skins.validate`가 전부 통과한다(id·order 중복 없음, 가격 규칙 — Common/Rare는 robux+coins, Epic/Legendary는 robux만).
- [ ] AC1: `byTier` 개수가 Basic 1 / Common 8 / Rare 9 / Epic 7 / Legendary 6 (총 31)로 갱신된다.
- [ ] AC2: 10종 전부 `SushiBody.hasLayout(id)`가 true, `layout(id)`의 Body·EyeLeft·EyeRight·Mouth·FootLeft·FootRight가 계란초밥과 완전히 같다(크기·위치·회전 없음).
- [ ] AC2: 10종 전부 외곽 상자가 **등급별 허용치** 안 — Common·Rare는 계란초밥 ±15%, Epic·Legendary는 ±25%(m5-21이 분기한 TOLERANCE 사용). 위 "여유 빠듯" 3종(고양이 초밥, 소프트아이스크림 롤, 유니콘 롤)을 먼저 확인한다.
- [ ] AC2: 10종 전부 효과 개수가 등급별 예산 안 — Common·Rare ≤1(돈가스·타코야키·에그토스트·슬라이더 버거·고양이 초밥은 0개, 로보 롤은 1개), Epic·Legendary ≤2(갤럭시 롤·크라운 참치·유니콘 롤은 2개, 소프트아이스크림 롤은 0개). 효과 종류가 이 스펙에 적은 Fire/Sparkles/Smoke/Glow 중 하나와 일치한다.
- [ ] AC2: Wedge를 쓰는 7개 파츠(고양이 초밥 EarLeft/Right/Inner×2, 크라운 참치 CrownSpike×5·Cape×2, 유니콘 롤 Mane×3)가 `shape == "Wedge"`로 저장되고 size 각 축이 모두 양수.
- [ ] AC4: 10종 전부 `speech`가 1~2줄, `Cutscene.linesFor(id, variant)`에 세 변형(`Chopsticks`/`Mouth`/`ChefHand`) 모두 그 대사가 섞여 나온다. `Cutscene.SKIN_LINES.tamago`는 그대로.

### Studio 확인
- [ ] AC5: 탈의실("🍣 스킨")에서 10종 모두 카드가 보이고, 입으면 캐릭터가 실제로 다른 모양(울퉁불퉁 덩어리/비대칭 노른자/고양이 귀/안테나/왕관/뿔 등)으로 보인다 — 기존 21종과 실루엣이 겹치지 않는지 육안 확인.
- [ ] AC5: 가격 표시가 맞다 — 일반 29 R$/300코인, 레어 59 R$/900코인, 에픽·전설은 로벅스만(코인 버튼 없음). 로벅스 버튼은 상품 id가 없어 "곧 열려요"로 보인다.
- [ ] AC5: Wedge 파츠(고양이 귀, 왕관 스파이크, 갈기)가 Studio에서 실제로 쐐기 모양으로 렌더링된다(일반 Part 각진 모양이 아님).
- [ ] AC5: 효과 2개를 쓰는 스킨(갤럭시 롤, 크라운 참치, 유니콘 롤)이 실제로 효과 2개가 동시에 보인다(파티클 성능 문제 없는지 — 여러 명이 동시에 입어도 랙 없는지는 m5-21의 효과 예산 성능 확인과 같이 본다).
- [ ] AC5: "여유 빠듯" 3종(고양이 초밥, 소프트아이스크림 롤, 유니콘 롤)이 다른 스킨 대비 과하게 커 보이거나 이름표 높이가 어긋나 보이지 않는다(±25%/±15% 안이라도 체감상 위화감이 있으면 developer가 수치를 낮춘다).
- [ ] AC5: 비초밥 7종의 탈락 연출 대사가 `Chopsticks`/`Mouth`/`ChefHand` 세 변형 모두에서 어색하지 않게 들린다.

## 공용 파일 변경
없음.

## 결정 기록
- 2026-10-09 · "m5-21이 머지 전인데 Wedge API를 가정해도 되는가" · planner가 제안서 §4-A 기준 가정(WedgePart 분기, bounds() 무변경)으로 작성 — developer가 머지 후 실제 시그니처와 다르면 여기 적고 수치만 재사용.
- 2026-10-09 · "소프트아이스크림 롤·유니콘 롤이 둘 다 비율 1.234로 전설/에픽 허용치(1.25)에 거의 붙어 있는데 괜찮은가" · planner 판단: 설계 의도(박스를 최대한 활용해 수직·비대칭 실루엣을 만드는 것 자체가 이번 배치의 핵심 가치)상 의도적으로 상한에 가깝게 뒀다. developer가 AC2 테스트에서 실패하면 가장 높은 파츠 1~2개의 offset.y만 낮추고 그 외 수치는 그대로 유지할 것.

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
