status: in-qa
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m6-09 — 전설 스킨 "마법소녀 스시" (오리지널 마법소녀)

- 마일스톤: M6
- GDD 근거: `docs/GDD.md` §9.1 (겉모습만), §9.2 (전설 R$ 199), §9.6 (뽑기 전설), §6 (공격 — 스킨은 연출만, v0.10) · 바탕: m6-08 전설 4종(`ConceptDragon`·`ConceptJet`, `SushiBody.CONCEPT_BODY` `LEGEND_RULES`)
- 사용자 요청 (2026-11-10): 그림 한 장(분홍·보라 오로라 배경의 마법소녀 초밥, 지팡이·트윈테일) + "마법소녀 스시도 추가해".
- **그림은 저장소에 넣지 않는다**: 특정 작품(세일러문 — 금발 당고머리와 빨간 보석, 이마 티아라, 초승달 지팡이, 남색 세일러복 + 빨간 리본)의 특징이 그대로라 상표·저작권 위험. "마법소녀" 장르만 가져오고 아래 오리지널 디자인으로 만든다(m6-08 "메가트론" → 오리지널 제트기와 같은 원칙).
- 담당: 스킨 모델링 developer(별도 worktree) / 공격 연출·문서 메인 세션. 공용 파일 수정 없음.

## 카탈로그
| 칸 | 값 |
|---|---|
| id | `magical-girl-sushi` |
| displayName / en | 마법소녀 스시 / Magical Girl Sushi |
| tier · 가격 | Legendary · R$ 199 (`productId` 비움) |
| drawGrade | Legendary (뽑기 전설 — 전설 6종이 되어 스킨마다 약 0.17%) |
| conceptBody | true (넓은 밥 + 작은 눈·팔·다리) |
| order | 46 |
| 대사 | 2줄 (마법소녀 말투, 먹히는 상황) |

## 모양 (오리지널 — 피할 것 / 쓸 것)
| 피할 것 (특정 작품) | 쓸 것 |
|---|---|
| 금발 양쪽 당고 + 빨간 보석 | **분홍(딸기우유색) 트윈테일**, 묶은 자리에 **민트 리본**, 정수리에 작은 **별 핀** |
| 이마 티아라·초승달 | 티아라 없음 |
| 남색 세일러 칼라·주름치마 + 가슴 빨간 큰 리본 | **흰·민트 프릴 망토(케이프) 드레스**, 가슴에 **분홍 하트 브로치** |
| 초승달 지팡이 | **별 지팡이**(노랑 별 + 작은 흰 날개 + 분홍 손잡이) — 한 손에 |
| | 효과 2개 이하: Sparkles(분홍·별빛) + Glow(지팡이 별) 권장 |

## 공격 연출 (메인 세션)
- `AttackFxLogic.STYLE_BY_SKIN["magical-girl-sushi"] = "StarRibbon"`: 분홍 고리 + 민트·노랑 별 조각 띠가 1.5바퀴 감아 오름 + 분홍 별빛 조각. 공격 효과는 모두와 같다(§6).

## 수용 기준
- AC1 카탈로그·CSV(이름·대사 ko/en)·`CONCEPT_BODY_IDS`·`DRAW_IDS`·`LEGEND_RULES`(또는 같은 표)에 들어가고 `Skins.validate` 통과(효과·외곽·파츠 한도).
- AC2 스킨 45 → 46, 뽑기 풀 14 → 15, 전설 등급 1% 그대로.
- AC3 6개 표정 모두 레이아웃 검사(발바닥·겹침·떠 있는 파츠·얼굴 가림 없음).
- AC4 렌더 → 비평 → 고침 3회 이상, before/after `docs/renders/characters/magical-girl-sushi/`.
- AC5 특정 작품 이름·표식이 소스·문서·CSV에 없음(테스트).
- AC6 `StarRibbon` 연출이 표에 있고 공격 판정 코드에는 스킨 id 없음(기존 테스트).
- Studio(사용자): 탈의실 전설 탭·뽑기 화면, 지팡이·리본 효과 밝기, 이름표 위치, 공격 연출(DEV-SETUP 3-18).

## 개발 메모
- developer 기록 `docs/developer/m6-09-magical-girl-sushi.md`(파츠 76/80, Glow + Sparkles, 렌더 4회). 병합 뒤 5단계: 2533 passed, 0 failed · selene 근사 std · luau-lsp 0.

## 결정 기록
- 2026-11-10 메인: 그림이 세일러문 특징 그대로 → 장르만 쓰고 오리지널(위 표). 얻는 길은 m6-08 전설과 같게(사용자 m6-08 결정 따름).
