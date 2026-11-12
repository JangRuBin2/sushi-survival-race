# QA — m6-10 전설 스킨 "천사 스시" · "악마 스시"

- 스펙: `docs/specs/m6-10-angel-devil-sushi.md`
- 검증 커밋: `e3ed7f9` (브랜치 `claude/gracious-curie-tl82em`)
- 결과: **통과** (P0/P1/P2 없음, P3 1건) → 스펙 `qa-passed`

## 자동 검증 (클라우드 세션, 2026-11-12)
| 명령 | 결과 |
|---|---|
| `rojo build` | 통과 (QA 직접, `/tmp`) |
| `stylua --check src tests tools` | 통과 (QA 직접) |
| `selene src` | 근사 std로만 통과(0/0) — Roblox API 검사 없음 |
| `lune run tests` (전체) | QA 미실행(메인 세션 전체 실행 중). 개별: `m6-10-angel-devil-sushi` 15/0, `m6-08-attack` 24/0, `skins` 24/0, `m5-31-draw-logic` 25/0, `m5-31-qa` 20/0, `localization` 20/0, **새 `m6-legend-skins-qa` 5/0** |
| `luau-lsp analyze` | 끝 코드 0 (QA 직접) |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 카탈로그·CSV·목록·규칙 표·validate | 통과 | `m6-10-angel-devil-sushi`(카탈로그 order 47·48, 현지화, 규칙 표 천사 80·악마 70), `m6-legend-skins-qa` |
| AC2 고정 수 테스트 갱신 | 통과 | 스펙의 "48·17·전설 8종 0.125%"는 그 시점. m6-11 뒤 49·18·전설 9종 0.11%로 다시 갱신됐고 `m6-legend-skins-qa`가 등급 1% 그대로·균등을 고정 |
| AC3 표정 6개 레이아웃 | 통과 | `m6-10-angel-devil-sushi` 두 스킨 × 표정 6 |
| AC4 렌더 3회 이상 | 통과 | `docs/renders/characters/angel-sushi/`·`devil-sushi/` before 2 + after 6씩 |
| AC5 `HolyHalo`·`DemonFlame` | 통과 | `m6-08-attack` AC4(m6-10) |
| "고등어와 같은 등급" | 통과 | 둘 다 tier Legendary·R$ 199·drawGrade Legendary·conceptBody, 코인·재화·번들 없음(`m6-legend-skins-qa` "얻는 길") |
| Studio | **사용자 확인 필요** | 아래 |

## 규칙 점검
- 효과: 천사 Glow + Sparkles, 악마 Smoke + Glow — 전설 한도 2 안. 외곽 ±25%, 이름표 기본 3.6.
- 들고 있는 지팡이·삼지창은 `ArmRight`에 붙은 겉모습(클라이언트 흔들림), 판정 없음. 스킨 id 분기 없음(규칙 표만).
- 공용 파일 수정 없음.

## 버그
### [P3-1] DEV-SETUP 3-18의 뽑기 확인 숫자가 m6-11 전 값
- `docs/DEV-SETUP.md:1019` "새 전설 3종 … 전설 각 0.125%, 보유 n/17" → 지금 전설 9종 각 0.11%, 보유 n/18(m6-08 리포트 P3-5와 같은 줄).

## 사용자 Studio 확인 체크리스트
1. 탈의실 전설 탭에 천사(47)·악마(48), 카드 R$ 199 + 🎫 확률 0.11%. 뽑기 화면 전설 줄 1.0%, ⓘ 9줄.
2. 천사 고리 Glow·금 Sparkles, 악마 진보라 Smoke·빨간 눈 Glow가 Future 조명에서 너무 밝거나 어둡지 않은지. 악마 Smoke가 이름표를 가리지 않는지.
3. 날개(흰 깃털·박쥐)가 걸을 때 다른 파츠를 뚫지 않는지, 지팡이·삼지창이 팔과 같이 흔들리는지.
4. 공격 연출: 천사 = 도는 금빛 고리 + 금·흰 조각, 악마 = 보라 고리 + 보라 불꽃 띠(머리 빨강).
5. 탈락 대사 ko/en.

## 추가한 테스트
- `tests/m6-legend-skins-qa.spec.luau` (m6-08~11 공용) — m6-08 리포트 참고.

## 인계 메모
- 브랜치 `claude/gracious-curie-tl82em` (push 안 함 — 지시). 남은 것: 사용자 Studio 확인, 상품 id 2개. 막힌 점 없음.
