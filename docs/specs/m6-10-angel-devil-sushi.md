status: qa-passed
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m6-10 — 전설 스킨 "천사 스시" · "악마 스시"

- 마일스톤: M6 · GDD 근거: §9.1(겉모습만), §9.2(전설 R$ 199), §9.6(뽑기 전설), §6(공격 — 스킨은 연출만)
- 사용자 요청 (2026-11-10): 그림 한 장(천사·악마 콘셉트 몸 초밥) + "천사스시 악마스시도 개발바람. 얘네는 고등어초밥과 같은 등급으로 설정해줘."
- "고등어초밥과 같은 등급" = 상점 등급 **전설(Legendary) R$ 199** + 🎫 뽑기 등급 **전설**(판매와 뽑기 둘 다, `drawGrade = "Legendary"`).
- 바탕: m6-08·m6-09 전설 콘셉트 몸 스킨(`LEGEND_RULES`). 담당: 스킨 developer(m6-09와 같은 worktree, 이어서) / 공격 연출·문서 메인 세션. 그림은 저장소에 넣지 않음(참고용).

## 카탈로그
| id | 이름 / en | order | 모양 | 효과(≤2) | 공격 연출 |
|---|---|---|---|---|---|
| `angel-sushi` | 천사 스시 / Angel Sushi | 47 | 금 별 왕관(분홍 보석) + 떠 있는 금빛 고리, 흰 깃털 날개, 금 별 지팡이(분홍 보석). 얼굴은 기본 귀여운 얼굴(그림의 검은 띠·빨간 눈은 넣지 않음) | Glow(고리) + Sparkles(금·흰) | `HolyHalo` 금빛 도는 고리 + 금·흰 조각 띠 |
| `devil-sushi` | 악마 스시 / Devil Sushi | 48 | 보라 뿔 투구(보라 보석) + 검은 바이저에 빨간 눈 두 줄, 보라 박쥐 날개, 보라 삼지창(보석) | Smoke(진보라) + Glow(빨간 눈·보석) | `DemonFlame` 보라 고리 + 보라 불꽃 띠(머리 빨강) |

- 둘 다 `tier = "Legendary"`, `robux = 199`, `drawGrade = "Legendary"`, `conceptBody = true`, `productId` 비움, 대사 2줄(ko/en).
- 합계(m6-09 포함): 스킨 **48종**, 전설 상점 등급 14, 뽑기·콘셉트 몸 17, 뽑기 전설 8종(등급 1% 그대로 → 스킨마다 0.125%).

## 수용 기준
- AC1 카탈로그·CSV·`CONCEPT_BODY_IDS`·`DRAW_IDS`·`LEGEND_RULES`, `Skins.validate` 통과. AC2 고정 수 테스트 갱신. AC3 표정 6개 레이아웃 검사. AC4 렌더 3회 이상 before/after `docs/renders/characters/<id>/`. AC5 `HolyHalo`·`DemonFlame` 연출 표(테스트 `m6-08-attack` AC4(m6-10)).
- Studio(사용자): 탈의실 전설 탭·뽑기 화면(전설 각 0.125%, 보유 n/17), 날개·고리·연기 밝기, 이름표, 공격 연출(DEV-SETUP 3-18).

## 개발 메모
- developer 기록 `docs/developer/m6-10-angel-devil-sushi.md`(천사 75/79·상한 80, 악마 54/58·상한 70, 들고 있는 지팡이·삼지창은 `ArmRight`에 붙어 팔과 함께 흔들림). 병합 뒤 2533 passed, 0 failed.

## 결정 기록
- 2026-11-10 사용자: 고등어와 같은 등급(전설 판매 + 뽑기 전설).
- 2026-11-10 메인: 천사의 검은 바이저·빨간 눈(그림)은 천사답지 않아 빼고 기본 얼굴. 악마만 바이저 + 빨간 눈.

## QA
- 2026-11-12 QA: 통과(P3 1건) — [`docs/qa/m6-10-angel-devil-sushi.md`](../qa/m6-10-angel-devil-sushi.md). Studio 확인은 사용자.
