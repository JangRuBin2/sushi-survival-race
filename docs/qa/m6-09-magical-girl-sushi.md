# QA — m6-09 전설 스킨 "마법소녀 스시"

- 스펙: `docs/specs/m6-09-magical-girl-sushi.md`
- 검증 커밋: `e3ed7f9` (브랜치 `claude/gracious-curie-tl82em`)
- 결과: **통과** (P0/P1/P2 없음, P3 2건) → 스펙 `qa-passed`

## 자동 검증 (클라우드 세션, 2026-11-12)
| 명령 | 결과 |
|---|---|
| `rojo build` | 통과 (QA 직접, `/tmp`) |
| `stylua --check src tests tools` | 통과 (QA 직접) |
| `selene src` | 근사 std로만 통과(0/0) — Roblox API 검사 없음 |
| `lune run tests` (전체) | QA 미실행(메인 세션 전체 실행 중). 개별: `m6-09-magical-girl-sushi` 14/0, `m6-08-attack` 24/0, `skins` 24/0, `m5-31-draw-logic` 25/0, `localization` 20/0, **새 `m6-legend-skins-qa` 5/0** |
| `luau-lsp analyze` | 끝 코드 0 (QA 직접) |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 카탈로그·CSV·목록·규칙 표·validate | 통과 | `m6-09-magical-girl-sushi` 카탈로그·현지화·규칙 표·"validate가 잡아요", `m6-legend-skins-qa` "규칙 표"(상한 80·±25%·이름표 기본·faceHidden 없음) |
| AC2 개수·확률 | 통과 (숫자 갱신) | 스펙의 "46·15·전설 6종 약 0.17%"는 그 시점 값. 지금 m6-10·m6-11 뒤 **스킨 49, 뽑기 18, 전설 9종 각 0.11%, 전설 등급 1% 그대로** — `m6-legend-skins-qa` "뽑기 확률"이 고정 |
| AC3 표정 6개 레이아웃 | 통과 | `m6-09-magical-girl-sushi` 표정별 검사(발바닥·겹침·떠 있음·얼굴 가림) |
| AC4 렌더 3회 이상·before/after | 통과 | `docs/renders/characters/magical-girl-sushi/` before 2 + after 6, 작업 기록 렌더 4회. 근사 렌더러라 최종은 Studio |
| AC5 특정 작품 이름 없음 | 통과 (P3-1) | 테스트가 토핑 모듈·`Skins.luau`·CSV와 파츠 이름을 검사. 설계 문서에는 "피할 것"으로 작품 이름이 남음 |
| AC6 `StarRibbon` 표·판정에 스킨 없음 | 통과 | `m6-08-attack` AC4(m6-09), `m6-08-qa` "판정 파일에 스킨 없음" |
| Studio | **사용자 확인 필요** | 아래 |

## 규칙 점검
- 겉모습만: 크기·히트박스·속도 같음(공유 발바닥 `GROUND_OFFSET`, 공격 수치 공통). 효과 Glow + Sparkles = 2(전설 한도 2).
- 얻는 길: 전설 R$ 199(`productId` 비움) + 🎫 뽑기 전설. 코인·재화·번들·VIP 없음, 유료 뽑기 없음(`m6-legend-skins-qa`).
- 공용 파일 수정 없음(스펙대로). 새 UI 없음.

## 버그
### [P3-1] AC5 문구("소스·문서·CSV에 없음")와 실제 범위가 달라요
- `docs/GDD.md:9`, `docs/USER-TODO.md:227`, 스펙 자체, `CLAUDE.md`, `docs/main-session-handoff.md`에 "피할 작품"으로 작품 이름이 적혀 있음. 플레이어가 보는 것(소스·카탈로그·CSV·파츠 이름)에는 없고 테스트가 고정. 저장소가 공개라 신경 쓰이면 문서에서도 "특정 작품"으로만 쓰고 스펙 AC5를 "플레이어에게 보이는 것"으로 고치기(planner/docs-writer).

### [P3-2] 스펙·CHANGELOG·GDD 머리말의 확률 숫자가 그때 값
- "전설 6종 → 스킨마다 약 0.17%"(스펙·`GDD.md:9`·`CHANGELOG.md:15`) — 기록으로는 맞지만 지금 화면은 0.11%. 혼동되면 "(당시)"를 붙이기.

## 사용자 Studio 확인 체크리스트
1. 탈의실 전설 탭 순서(드래곤 … 마법소녀 → 천사 → 악마 → 다이너마이트), 카드 "R$ 199 — 곧 열려요" + "🎫 뽑기 전설에서도 나와요" + 구석 "🎫 0.11%".
2. 지팡이 별 Glow·분홍 Sparkles 밝기(Future 조명), 이름표(3.6)와 트윈테일·별 핀이 안 겹치는지.
3. 걸을 때 지팡이(팔)·망토가 몸을 뚫어 보이지 않는지.
4. 공격(F) → 분홍 고리 + 분홍·노랑 별이 번갈아 감아 오르는 리본(DEV-SETUP 3-18 6번).
5. 탈락 연출 대사 2줄 ko/en.

## 추가한 테스트
- `tests/m6-legend-skins-qa.spec.luau` (m6-08~11 공용, 5개) — m6-08 리포트 참고.

## 인계 메모
- 브랜치 `claude/gracious-curie-tl82em` (push 안 함 — 지시). 남은 것: 사용자 Studio 확인, 상품 id. 막힌 점 없음.
