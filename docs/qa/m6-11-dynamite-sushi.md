# QA — m6-11 전설 스킨 "다이너마이트 스시" (얼굴 없는 판)

- 스펙: **없음** — `docs/specs/m6-11-*.md` 파일이 없어요. 기준은 개발 기록 `docs/developer/m6-11-dynamite-sushi.md`(1차·2차) + CLAUDE.md "스킨 · 상점 규칙" + m6-08~10 전설 스펙의 공통 조건 + m6-12 스펙의 `Kaboom` 한 줄.
- 검증 커밋: `e3ed7f9` (브랜치 `claude/gracious-curie-tl82em`)
- 결과: **코드 통과**(P0/P1/P2 없음, P3 4건). 바꿀 스펙 상태가 없으므로 **planner가 스펙을 만들어 `qa-passed`로 기록할 것**(P3-1).

## 자동 검증 (클라우드 세션, 2026-11-12)
| 명령 | 결과 |
|---|---|
| `rojo build` | 통과 (QA 직접, `/tmp`) |
| `stylua --check src tests tools` | 통과 (QA 직접) |
| `selene src` | 근사 std로만 통과(0/0) — Roblox API 검사 없음 |
| `lune run tests` (전체) | QA 미실행(메인 세션 전체 실행 중). 개별: `m6-11-dynamite-sushi` 19/0, `skins` 24/0, `m5-31-draw-logic` 25/0, `m5-31-qa` 20/0, `localization` 20/0, **새 `m6-legend-skins-qa` 5/0** |
| `luau-lsp analyze` | 끝 코드 0 (QA 직접) |

## 확인한 조건 (스펙 대신 개발 기록·CLAUDE.md 기준)
| 조건 | 결과 | 근거 |
|---|---|---|
| 카탈로그: 전설·R$ 199·drawGrade 전설·conceptBody·order 49·productId 비움·대사 2줄 | 통과 | `m6-11-dynamite-sushi` 카탈로그, `m6-legend-skins-qa` "얻는 길" |
| CSV 이름·대사 ko/en, src 한국어 리터럴 없음 | 통과 | `m6-11-dynamite-sushi` 현지화, `localization` 20/0 |
| `CONCEPT_BODY_IDS`·`DRAW_IDS`·`SushiConceptSample`·`LEGEND_RULES` | 통과 | `m6-legend-skins-qa` "규칙 표"(CONCEPT_BODY 키 = CONCEPT_BODY_IDS) |
| 한도: 효과 2(Sparkles + Smoke), 파츠 72~80 ≤ 80, 외곽 X 1.00·Z 1.24 ≤ 1.25(±25%), 발바닥·겹침·떠 있음 0, 관절 8 | 통과 (Z 여유 0.01) | `m6-11-dynamite-sushi` 표정 6종 검사, `Skins.validate` 통과 |
| 얼굴 없음(`faceHidden`): 이 스킨 하나뿐, 게임 코드는 안 읽음, 얼굴 파츠가 앞에서 정말 가려짐, 흰 밥 안 보임 | 통과 | `m6-11-dynamite-sushi` faceHidden·얼굴 격자·밥 덮음 테스트, QA grep(`faceHidden`은 `SushiBody`·`ConceptDynamite` 주석·테스트에만). 렌더 `after-closeup.png` 앞·3/4·뒤 모두 막대 묶음 |
| 뽑기: 등급 1% 그대로, 전설 9종 균등(0.111% → 화면 0.11%), 유료 뽑기 없음 | 통과 | `m6-legend-skins-qa` "뽑기 확률", `m5-31-*` |
| 공격 연출 `Kaboom`(연출 표에만), 다이너마이트 라운드 폭발이 더 화려(클라이언트만), 판정 코드에 스킨 없음 | 통과 | `m6-08-qa` "판정 파일에 스킨 없음"(`DynamiteService`·`DynamiteLogic` 포함), `DynamiteFxController.luau:133-136` |
| 렌더 비평 3회 이상·before/after | 통과 | 1차 4회 + 2차 4회, `docs/renders/characters/dynamite-sushi/` before 2 + after 6 + prev 1 |
| 문서 수(스킨 49·뽑기 18·전설 9) | 통과 | CLAUDE.md·GDD 9.2/9.6·CHANGELOG·GAME-GUIDE 일치 (DEV-SETUP 3-18만 옛 값 — m6-08 리포트 P3-5) |
| Studio | **사용자 확인 필요** | 아래 |

## 버그
### [P3-1] 스펙 파일이 없어요 (절차)
- WORKFLOW는 "스펙 → 구현 → QA" 순서인데 m6-11은 개발 기록만 있음. 사용자 결정 두 개(얼굴 없이 다이너마이트만 — `faceHidden` 규칙 표 예외 추가 / 파츠 상한 80)와 공격 연출 `Kaboom`(m6-08 스펙 표에 없는 스타일)이 스펙·결정 기록 없이 들어감. 공유 규칙(얼굴 가림 검사)의 예외를 새로 만든 변경이라 기록이 필요.
- 할 일: planner가 `docs/specs/m6-11-dynamite-sushi.md`(카탈로그 표, 모양, `faceHidden` 결정, `Kaboom`, 수용 기준 = 위 표)를 만들고 상태를 `qa-passed`로, 이 리포트를 링크.

### [P3-2] `SushiBody` 주석 숫자가 2차 모양과 달라요
- `src/shared/SushiBody.luau:1022` "막대 12 + 안쪽 끝 5·밥을 덮는 판 5" → 개발 기록 2차는 안쪽 끝 4·판 4(파츠 수 계산도 4 기준).

### [P3-3] `CLAUDE.md:41` 문장이 섞였어요
- `faceHidden` 설명 뒤에 고등어 예외("외곽은 concept-salmon 기준 ±25%·이름표 높이 4.8")가 붙어 다이너마이트에도 4.8이 적용되는 것처럼 읽힘(실제는 3.6 — `m6-legend-skins-qa`가 고정). docs-writer가 문장 순서 정리.

### [P3-4] 다이너마이트 라운드에서 이 스킨이 바닥 아이템과 헷갈릴 수 있어요 (확인 요청)
- 바닥 다이너마이트(빨간 막대 셋 + 검은 띠 + 불빛)와 이 스킨이 멀리서 비슷함. 이 스킨은 팔·다리·이름표가 있어 구분은 되지만 플레이테스트에서 확인.

## 사용자 Studio 확인 체크리스트
1. 탈의실 전설 탭 맨 끝(악마 다음), 카드 R$ 199 + "🎫 뽑기 전설에서도 나와요" + 🎫 0.11%. 뽑기 화면 보유 n/18.
2. 앞·옆·위·뒤·아래에서 올려다보는 카메라 모두 얼굴·흰 밥이 안 보이는지(Future 조명에서 막대 사이 틈).
3. 걸을 때 팔이 팔 위 짧은 막대·옆 막대와 크게 겹쳐 보이지 않는지.
4. 탈락·우승 연출에서 표정이 안 보여도 어색하지 않은지.
5. 불꽃 Sparkles·Smoke 양, 이름표(3.6)와 불꽃(꼭대기 2.74) 간격.
6. 공격 연출 `Kaboom`(노랑·주황 고리 + 불티 띠), 다이너마이트 라운드에서 이 스킨으로 터뜨리면 불덩이가 더 크고 고리 둘(능력 같음).

## 추가한 테스트
- `tests/m6-legend-skins-qa.spec.luau` (m6-08~11 공용, 5개) — faceHidden은 다이너마이트만, 이름표 예외 없음, 연출 표 포함.

## 인계 메모
- 브랜치 `claude/gracious-curie-tl82em` (push 안 함 — 지시).
- 남은 것: planner 스펙 작성(P3-1), docs-writer 문서 정리(P3-2·P3-3), 사용자 Studio 확인, 상품 id.
- 막힌 점 없음.
