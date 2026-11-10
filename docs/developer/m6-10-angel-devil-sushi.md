# m6-10 전설 스킨 2종 "천사 스시"·"악마 스시" — 개발 작업 기록

## 2026-11-10 — 구현·렌더 비평·테스트 (사용자 확인 대기)
- 브랜치: `claude/gracious-curie-tl82em-magical` (worktree `/home/user/sushi-magical`, m6-09 마법소녀 커밋 다음). push 안 함(요청). 스펙·CLAUDE.md·GDD·GAME-GUIDE·CHANGELOG·USER-TODO·DEV-SETUP과 공격 연출(`AttackFxLogic` — 메인 세션이 `HolyHalo`·`DemonFlame` 추가)은 손대지 않음.
- 요청(메인 세션 → 사용자 요청): 참고 그림(분위기만)의 천사·악마를 일반 디자인으로. 둘 다 Legendary, R$ 199, drawGrade Legendary, conceptBody, productId nil, 대사 2줄. 천사 order 47, 악마 order 48. 천사에는 그림의 검은 바이저·빨간 눈을 넣지 않음(보통 귀여운 얼굴).

### 끝난 것
- 카탈로그 `src/shared/Skins.luau`: `angel-sushi`(천사 스시)·`devil-sushi`(악마 스시), `CONCEPT_BODY_IDS`·`DRAW_IDS`에 두 줄씩.
- 모양: 새 순수 데이터 모듈 `src/shared/ConceptAngelDevil.luau`(`angel()`·`devil()`, PartMath만 require). 파츠 이름은 `Angel…`·`Devil…`. `SushiConceptSample.SKIN_IDS`·`TOPPINGS`에 연결.
- 규칙 표 `SushiBody.CONCEPT_BODY` `LEGEND_RULES`: 천사 80(별 두 개 + 고리 8 + 날개), 악마 70. 외곽 ±25%, 이름표 기본 3.6. 스킨 id 분기 없음.
- 천사 별 홀 14파츠·악마 삼지창 10파츠는 `attach = "ArmRight"`(오른팔 Motor6D에 용접, 관절 수 그대로).
- 현지화 `Strings.csv` 6행(이름·대사 ko/en).
- 테스트: 새 `tests/m6-10-angel-devil-sushi.spec.luau`(15개) + 개수 고정 테스트 갱신(아래).

### 모양
- 천사: 밥 위 모서리를 두른 금빛 왕관 띠(앞·뒤·옆, 아래끝 y 0.96) + 앞 위 금빛 별(분홍 보석) + 별 양옆 작은 뾰족 장식 둘, 머리 위에 떠 있는 얇은 금빛 고리(원기둥 8개 팔각, Neon), 등 양옆 흰 날개(둥근 원판 둘 + 깃털 끝 쐐기 둘), 오른손 금빛 별 홀(분홍 보석·아래 손잡이 공).
- 악마: 짙은 보라 투구(테두리 판 둘 + 윗단) + 윗단 앞 보라 보석(Neon) + 바깥으로 기운 뾰족한 삼각 뿔 둘(쐐기 두 장씩), 얼굴 위 검은 바이저 띠(y 0.77~0.97)에 빨간 Neon 눈 두 줄(안쪽이 내려간 장난꾸러기 눈), 등 양옆 보라 박쥐 날개(뼈대 + 톱니 막 셋), 오른손 짙은 보라 삼지창(가로대·갈래 셋·빛나는 끝·보석).

### 수치 (표정 6종)
| 스킨 | 파츠 (기본/최대) | 상한 | 효과 | 외곽 X × Y × Z (salmon 대비 X·Z) | 꼭대기 | 이름표 |
|---|---|---|---|---|---|---|
| angel-sushi | 75 / 79 | 80 | Glow(고리, 따뜻한 금빛) + Sparkles(홀 별, 금·흰) | 5.81 × 4.80 × 2.91 (1.22 · 0.98) | 2.55 | 3.6 |
| devil-sushi | 54 / 58 | 70 | Glow(바이저, 빨강) + Smoke(삼지창 가운데 끝, 짙은 보라) | 5.72 × 4.84 × 2.90 (1.20 · 0.98) | 2.59 | 3.6 |
- 모두 발바닥 2.25, 겹침·떠 있는 파츠 0(고리는 서로 닿은 8마디라 "떠 있음" 검사 통과 — 보이기에는 머리 위에 떠요), 관절 공유 8개, 얼굴 영역에서 밥 앞면보다 앞으로 나온 토핑 0. 꼭대기는 미리보기 카메라 한도(약 3.06) 안.

### 렌더 비평 (`lune run tools/render-character <id> --view closeup|turntable|expressions|gameplay`)
**천사**
1. v1: 왕관 띠·별·고리·홀은 바로 읽힘. 왕관 띠가 둥근 모서리에서 끊겨 울타리 같음. 날개가 얇은 회색 가시 부채라 앞·뒤에서 거의 안 보이고 "얼음 조각" 같음. → 띠를 모서리까지 늘려 네모 테로, 깃털을 크게·두껍게.
2. v2: 깃털이 뾰족한 흰 가시로 읽혀 천사 날개답지 않음 → 둥근 원판 셋(폭신) 시험.
3. v3: 원판만은 풍선·구름 방울 같음 → 위쪽 원판 둘 + 아래 깃털 끝 쐐기 둘(톱니)로 섞음, 날개 젖힘 22° → 12°, 0.26 위로.
4. v4(최종): 뒤에서 둥근 윗변 + 깃털 끝으로 작은 날개가 읽히고, 앞에서도 왕관 옆으로 날개 끝이 보임. 남은 차이: 날개가 흰 밥과 같은 흰색이라 해 반대쪽(뒤)에서는 회색으로 그려짐(조명 탓).
**악마**
1. v1: 바이저·빨간 눈·보석·삼지창은 그림 인상. 뿔이 가는 막대(안테나), 박쥐 날개 막이 줄에 단 삼각 깃발(만국기)처럼 띄엄띄엄, 외곽 X 6.10(한도 넘음), 투구 두 판이 같은 앞면(깜빡임). → 날개 막을 뼈대 마디 사이 직각삼각형(한 변 = 뼈대)으로 이어 붙여 톱니 가장자리, 투구 윗단 앞뒤 줄임.
2. v2: 박쥐 날개로 또렷. 뿔이 관절 공 때문에 굽은 관(잠망경)처럼 보임 → 곧은 두 마디.
3. v3: 곧은 두 마디는 굵기 단차로 망원경처럼 보임 → 쐐기 두 장 삼각 뿔(앞을 봐요)로 바꿈.
4. v4(최종): 뾰족한 악마 뿔 + 바이저 빨간 눈 + 보라 박쥐 날개 + 삼지창 연기. 투구 윗단이 조금 모자처럼 네모남(그림의 각진 투구 인상과는 맞음). 숨어 있던 뿔 뿌리 빛 공 2개는 뺌.
- 처음·마지막 렌더: `docs/renders/characters/<id>/before-closeup.png`·`before-turntable.png`, `after-closeup.png`·`after-turntable.png`·`after-turntable-lobby.png`·`after-expressions.png`·`after-gameplay-back.png`·`after-mobile-back.png`.

### 바뀐 테스트 (기존 고정 값 갱신, m6-09 위에 +2)
- 개수: 스킨 46 → 48, 전설 12 → 14, 콘셉트 몸·뽑기 15 → 17(`m5-03-foundation`·`m5-22-qa`·`m5-27-concept-skin`·`m5-28-concept-skins`·`m5-29-concept-skins-2`·`m5-31-draw-logic`·`m5-32-fresh-mackerel`·`m6-08-legend-skins`·`m6-09-magical-girl-sushi`·`skins`), 상한 80 목록에 천사(`m5-28-concept-skins`·`m5-30-qa`), 효과 표 2행(`skins`).
- 순서: 끝에서 세던 위치 두 칸 앞(`m5-28-qa`·`m5-29-qa`·`m5-29-concept-skins-2`·`m5-32-fresh-mackerel`·`m6-08-legend-skins`·`m6-09-magical-girl-sushi`), 맨 끝 = 악마(`m5-28-concept-skins`).
- 뽑기: 전설 등급 8종, 스킨마다 0.125% — 화면 표시(`DrawLogic.perSkinPercent`, 소수 둘째 자리 반올림)는 **"0.13%"**. `SOLD_LEGENDS`(m5-31 때 카탈로그)에 2종 추가.
- require: 견본 모듈이 토핑 모듈 5개(`sushi-body`·`m5-28-concept-skins`).

### 검증
- `lune run tests` **2528 passed, 0 failed** (m6-09 뒤 2513 + 새 15). `rojo build` 통과, `stylua --check src tests tools` 통과, `luau-lsp analyze` 끝 코드 0(경고 없음), selene 근사 std(Roblox API 검사 없음) 0 errors / 0 warnings.

### Studio에서 확인할 것 (사용자)
1. 탈의실 전설 탭 맨 끝(마법소녀 다음) 천사 → 악마, 카드 "R$ 199 — 곧 열려요" + "🎫 뽑기 전설에서도 나와요".
2. 천사: 고리 Glow(Neon 고리 + 빛)가 너무 밝지 않은지, 고리가 이름표·👑와 겹치지 않는지(고리 꼭대기 2.55, 이름표 3.6), 흰 날개가 Future 조명에서 보이는지.
3. 악마: 바이저 빨간 Glow가 얼굴을 너무 붉게 물들이지 않는지, 삼지창 연기 양.
4. 두 스킨 모두 걸을 때 홀·삼지창이 오른팔과 같이 흔들리는지.
5. 뽑기 화면: 전설 줄 1.0%, ⓘ 스킨별 "각 0.13%" 8줄(실제 0.125%), 보유 n/17.
6. 대사·영어 문구, 개발자 상품 2개(R$ 199) → `productId`.

### 남은 것 / 막힌 점
- 남은 것: 사용자 Studio 확인, 상품 id, 문서 반영(메인 세션), 진짜 roblox std로 selene 한 번.
- 막힌 점: 없음.
