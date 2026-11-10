# m6-11 전설 스킨 "다이너마이트 스시" — 개발 작업 기록

## 2026-11-10 (2차) — 얼굴 없이 다이너마이트만 (사용자 결정)
- 브랜치: `claude/gracious-curie-tl82em-dynamite2` (worktree `/home/user/sushi-dynamite`, 1차 병합 뒤 브랜치 머리에서). push 안 함(요청). AttackFxLogic·공격/다이너마이트 라운드 코드·Config/Remotes/Types/Attributes·init·메인 문서는 손대지 않음.
- 요청(메인 세션 → 사용자): "얼굴 안보이고 다이너마이트로만 채워줘. 그게 더 귀여울듯" → 확인 질문에 "얼굴도 없이 다이너마이트만". 어느 각도에서도 눈·입·볼과 흰 밥이 안 보이고, 흰 팔·다리만 남은 걷는 다이너마이트 묶음.

### 바뀐 것
- `src/shared/ConceptDynamite.luau` 다시 짬: 막대 12개(앞 줄 5·뒤 줄 5·옆 2, 지름 0.86, 간격 0.81로 이웃이 살짝 겹쳐 틈 없음, 끝 마개 12) + 팔 위 짧은 막대 2(마개 없음, 아래끝 y 0 — 팔 위끝 −0.04보다 위라 팔은 다 보여요) + 위에서 보이는 안쪽 막대 끝 4 + 짙은 빨강 판 4(앞 z −1.64~−1.60·양옆 x ±1.80~1.84·위 y 1.0~1.06 — 밥과 받침을 통째로 감싸요. 뒤는 뒤 줄 막대가 밥 뒷면에서 거의 닿아 판 없이 덮어요) + 숯빛 띠 2줄 × 앞·뒤·양옆 4(막대 바깥면에 반쯤 묻힘, 모서리는 네모로 만남) + 심지(위 판 위 갈색 받침·꼰 마디 4·Neon 불꽃 공·빛살 3).
- 앞 판은 가장 앞으로 나온 얼굴 파츠(당황 땀방울 z −1.57)보다 앞이라, 앞 줄 막대 틈으로도 얼굴이 안 보여요. 공유 얼굴 파츠(깜빡임 관절 포함)는 그대로 있고 숨기만 해요 — 공유 몸 검사·관절 8개 그대로.
- 규칙 표 `SushiBody`: `ConceptBodyRule`에 선택 칸 `faceHidden: boolean?`, `LEGEND_RULES["dynamite-sushi"] = { partBudget = 80, faceHidden = true }`, `conceptBody`로 옮겨 담음. 게임 코드는 이 칸을 안 읽고(테스트가 `.faceHidden` 접근을 SushiBody 밖에서 막음) 테스트만 씀. 스킨 id 분기 없음.
- 파츠 상한 70 → **80**: 막대 12 + 마개 12 + 팔 위 2 + 안쪽 끝 4 + 판 4 + 띠 8 + 심지 9 = 토핑 51, 공유 몸 25~29 → 76/72~80 (최대 표정이 딱 80).
- `Skins.luau` 주석만 고침(카탈로그 값·문구 그대로).

### 수치 (표정 6종)
| 파츠 (기본/최소~최대) | 상한 | 효과 | 외곽 X × Y × Z (salmon 대비 X·Z) | 꼭대기 | 이름표 |
|---|---|---|---|---|---|
| 76 / 72~80 | 80 | Sparkles(불꽃 공) + Smoke(심지 끝 마디) | 4.76 × 4.99 × 3.67 (1.00 · 1.24) | 2.74 | 3.6 |
- Z는 한도 3.70에 가까워요(앞 줄 z −1.42·뒤 줄 1.31·띠). 발바닥 2.25, 겹침·떠 있음 0, 관절 8개, 토핑은 모두 Body 용접.

### 렌더 비평 (2차, `lune run tools/render-character dynamite-sushi --view closeup|turntable|expressions|gameplay [--light studio|lobby]`)
1. w1(앞 줄 5·뒤 줄 5·옆 2·안쪽 끝 5·판 5): 앞·뒤·위 모두 빨간 막대 묶음, 얼굴·흰 밥 안 보임. 옆에서 앞 모서리 막대와 옆 막대 사이(팔 자리)에 짙은 빨강 판이 넓게 보여 상자 같음. 팔은 앞에서 거의 안 보임(모서리 막대 바깥 2.15 vs 팔 끝 2.33). → 팔 위 짧은 막대 2개 추가, 파츠를 맞추려고 뒤 판을 빼고(뒤 줄을 z 1.31로 — 밥 뒷면에서 틈 0.004) 안쪽 끝 5 → 4(심지 받침이 그 자리).
2. w2: 옆이 막대로 차고 팔이 그 아래로 나와요. 팔이 앞에서는 여전히 실처럼 보임. → 줄 간격 0.86 → 0.81(이웃이 살짝 겹침), 옆 바깥 2.05라 팔 끝 0.28이 앞에서도 보여요.
3. w3: 앞에서 양옆으로 작은 흰 팔, 3/4에서 팔이 막대 묶음 옆에서 또렷, 위에서는 막대 끝 격자 + 심지. 테스트에서 판 아래끝을 받침까지 내리자 막대 아래끝과 같은 평면 → 막대 아래끝 −1.32로.
4. 최종: 앞·3/4·옆·뒤·위 어디서도 얼굴·흰 밥 없음, 표정 6종 그림이 모두 같아요(의도). 로비 조명에서도 빨강·숯빛·노란 불꽃 구분. 남은 차이: 팔 위 짧은 막대는 마개가 없어 위에서 보면 끝이 평평(파츠 80이 꽉 참).
- 렌더: `after-*.png` 6장 교체(`after-closeup`·`after-turntable`·`after-turntable-lobby`·`after-expressions`·`after-gameplay-back`·`after-mobile-back`), `before-*` 그대로, 1차 최종(얼굴 보이는 판)은 `prev-closeup.png`.

### 바뀐 테스트
- `m5-28-concept-skins` "토핑이 얼굴을 안 가려요"·`m5-29-qa` "게임에서 쓰는 모습 … 얼굴 파츠를 앞에서 안 가려요": 규칙 표에 `faceHidden`이 있는 스킨은 건너뜀. `m5-28-concept-skins`·`m5-30-qa` 상한 80 목록에 다이너마이트.
- `m6-11-dynamite-sushi`: 상한 80·`faceHidden`, 얼굴 안 가림 검사를 빼고 대신 (1) `faceHidden`은 다이너마이트 하나뿐 + 게임 코드는 안 읽음, (2) 표정 6종마다 모든 얼굴 파츠의 앞면 5 × 5 점과 얼굴 영역 격자(x ±1.4, y −0.8~0.76) 앞에 토핑(앞에서 본 판·세운 원기둥 앞면으로 계산), (3) 흰 밥 안 보임(앞·옆·위 판이 밥·받침 외곽을 덮음, 뒤는 x를 따라 뒤 줄 막대 뒷면이 밥 뒷면보다 뒤), 막대 묶음(앞·뒤 줄 5개 이상·간격 ≤ 지름·바닥까지·팔 위 막대는 팔보다 위·안쪽 끝), 띠(앞·뒤 막대 바깥) 고침. 19개.

### 검증 (2차)
- `lune run tests` **2563 passed, 0 failed** (이 브랜치 기준 2561 + m6-11 새 2개). `rojo build` 통과, `stylua --check src tests tools` 통과, `luau-lsp analyze` 끝 코드 0, selene 근사 std(Roblox API 검사 없음) 0 errors / 0 warnings.

### Studio에서 확인할 것 (2차)
1. 탈의실·인형·게임 캐릭터 모두 얼굴이 안 보이는지 — 앞·옆·위·뒤에서 흰 밥도 안 보이는지(특히 Future 조명에서 막대 사이 틈, 아래에서 올려다보는 카메라).
2. 걸을 때 팔이 팔 위 짧은 막대·옆 막대와 크게 겹쳐 보이지 않는지(팔 흔들림은 클라이언트 연출, 막대는 Body 용접).
3. 탈락·우승 연출에서 표정이 안 보여도 어색하지 않은지(표정 6종 그림이 모두 같아요 — 의도), 깜빡임 관절이 판 뒤라 안 보이는지.
4. 불꽃 Sparkles·Smoke 양, 이름표와 불꽃 간격(꼭대기 2.74, 이름표 3.6).

## 2026-11-10 — 구현·렌더 비평·테스트 (사용자 확인 대기)
- 브랜치: `claude/gracious-curie-tl82em-dynamite` (worktree `/home/user/sushi-dynamite`). push 안 함(요청). 스펙 문서·CLAUDE.md·GDD·GAME-GUIDE·CHANGELOG·USER-TODO·DEV-SETUP·README와 공격 연출(`AttackFxLogic` — 메인 세션이 main에서 `dynamite-sushi` 연출 추가)·공격 코드·Config/Remotes/Types/Attributes·init 스크립트는 손대지 않음.
- 요청(메인 세션 → 사용자 콘셉트 그림, 파일 없음): 콘셉트 몸 위 귀여운 다이너마이트 묶음. 빨간 막대 약 8개가 통처럼 두르고, 숯빛 띠 두 줄, 위에 갈색 받침 + 꼰 심지 + 노랑·주황 Neon 불꽃, 효과 2개(불꽃 Sparkles/Fire + 옅은 회색 Smoke). 전설 R$ 199, drawGrade Legendary, conceptBody, order 49, productId nil, 대사 2줄. 특정 작품 없음.

### 끝난 것
- 카탈로그 `src/shared/Skins.luau`: `dynamite-sushi`(다이너마이트 스시, order 49), `CONCEPT_BODY_IDS`·`DRAW_IDS`에 한 줄씩, 머리 주석.
- 모양: 새 순수 데이터 모듈 `src/shared/ConceptDynamite.luau`(`topping()`, PartMath만 require). 파츠 이름은 `Dynamite…`. `SushiConceptSample.SKIN_IDS`·`TOPPINGS`에 연결.
- 규칙 표 `SushiBody` `LEGEND_RULES`: `["dynamite-sushi"] = { partBudget = 70 }`(80 안 씀). 외곽 ±25%, 이름표 기본 3.6. 스킨 id 분기 없음.
- 현지화 `Strings.csv` 3행(이름·대사 ko/en).
- 테스트: 새 `tests/m6-11-dynamite-sushi.spec.luau`(17개) + 개수 고정 테스트 갱신(아래).
- 렌더: `docs/renders/characters/dynamite-sushi/` — `before-closeup.png`·`before-turntable.png`(v1), `after-closeup.png`·`after-turntable.png`·`after-turntable-lobby.png`·`after-expressions.png`·`after-gameplay-back.png`·`after-mobile-back.png`(최종). 천사와 같은 파일 묶음.

### 모양
- 막대 9개(빨강 원기둥, 위끝에 한 단 좁은 밝은 빨강 마개 = 깎인 끝): 뒤 5개(지름 0.8, 서로 닿아 뒤에서 통째로 막대 묶음), 옆 2개(지름 0.8, 팔 뒤 z 0.45), 앞 모서리 2개(지름 0.56, 둥근 밥 모서리에 반쯤 묻힘 — 팔이 앞에서도 반쯤 보여요). 위끝 높이 1.40~1.66으로 들쭉날쭉(밥 위 1.0 위로 삐죽).
- 띠 2줄(숯빛 {56,56,62}, Fabric): 위 y 0.78~1.12, 아래 y −1.08~−0.82. 앞(밥 앞면 위, 얼굴 위·아래로만)·뒤(뒤 막대 바깥)·양옆(옆 막대 바깥) 판 + 앞 모서리 막대를 감는 고리. 뒤 모서리는 네모로 만나요.
- 심지: 밥 위 가운데 짙은 갈색 받침(Wood) → 꼰 심지 4마디(밝은/어두운 황갈색 번갈아)가 +X쪽으로 휘어 올라감 → 끝에 노란 Neon 공(Sparkles) + 주황 Neon 빛살 3개(60°마다 별). 마지막 심지 마디에 옅은 회색 Smoke.
- 얼굴은 공유 콘셉트 얼굴 그대로(벌린 웃는 입 + 볼). 빨간 앞판(선택 사항)은 넣지 않음 — 얼굴 높이에서 밥 앞면 앞으로 나오면 m5-28 얼굴 검사에 걸리고, 밥 색을 바꾸면 공유 몸 검사가 깨져요.

### 수치 (표정 6종)
| 파츠 (기본/최소~최대) | 상한 | 효과 | 외곽 X × Y × Z (salmon 대비 X·Z) | 꼭대기 | 이름표 |
|---|---|---|---|---|---|
| 64 / 60~68 | 70 | Sparkles(불꽃 공) + Smoke(심지 끝 마디) | 4.76 × 4.87 × 3.30 (1.00 · 1.11) | 2.62 | 3.6 |
- 발바닥 2.25, 겹침·떠 있는 파츠 0, 관절 공유 8개(토핑은 모두 Body 용접, attach 없음), 얼굴 높이에서 밥 앞면보다 앞으로 나온 토핑 0. 폭은 팔(±2.33)이 정해요 — 막대 바깥 x 1.98·띠 2.02라 제트기와 달리 X 한도(5.95)에 여유.

### 렌더 비평 (`lune run tools/render-character dynamite-sushi --view closeup|turntable|expressions|gameplay [--light studio|lobby]`)
1. v1(막대 8개 지름 0.6, 띠 두께 0.2): 다이너마이트로 읽히지만 뒤에서 막대 사이로 흰 밥이 줄무늬처럼 보여 울타리·바코드 같음. 띠가 가늘어 얼굴 둘레 검은 액자 선 같음. 앞 모서리 막대(지름 0.6)가 팔을 거의 다 가림. 위에서 보면 막대가 띄엄띄엄. → 뒤 5개·옆 2개를 지름 0.8로 굵게 해 서로 닿게, 띠 두께 0.34/0.26, 앞 모서리 막대는 0.56으로 가늘게 바깥 x를 옆 막대와 맞춤(팔 보이게), 불꽃·심지 조금 크게.
2. v2: 뒤·게임 카메라에서 통통한 막대 묶음 + 띠 두 줄로 바로 읽힘, 팔도 보임. 불꽃이 게임 화면에서 작음, 앞 모서리 막대가 낮아 띠 위로 거의 안 나옴. → 심지를 더 높게 휘고(꼭대기 2.62) 불꽃 공 0.46·빛살 0.96, 앞 모서리 막대 위끝 +0.1.
3. v3: 불꽃이 또렷. 테스트에서 m5-28 "얼굴 높이에서 밥 앞면보다 앞으로 안 나옴"(x 제한 없음)에 앞 모서리 막대(z −1.58)가 걸림 → 앞 모서리 막대를 z −1.06으로 밥 둥근 모서리에 묻음.
4. v4(최종): 앞에서는 빨간 모서리 막대 + 띠 고리가 얼굴을 둥근 틀처럼 감싸고, 뒤·옆은 막대 묶음, 위에 휜 심지와 노란 불꽃. 로비 조명에서도 빨강·숯빛이 구분됨. 남은 차이: 앞 모서리 막대가 반쯤 묻혀 앞에서는 가는 빨간 기둥으로 보여요(얼굴 검사 한도 때문). 위에서 보면 밥 윗면이 흰 채로 넓어요(초밥 밥 — 의도).

### 바뀐 테스트 (기존 고정 값 갱신, +1)
- 개수: 스킨 48 → 49, 전설 14 → 15, 콘셉트 몸·뽑기·견본 17 → 18(`m5-03-foundation`·`m5-22-qa`·`m5-27-concept-skin`·`m5-28-concept-skins`·`m5-29-concept-skins-2`·`m5-31-draw-logic`·`m5-32-fresh-mackerel`·`m6-08-legend-skins`·`m6-09-magical-girl-sushi`·`m6-10-angel-devil-sushi`·`skins`), 효과 표 1행(`skins`).
- 순서: 끝에서 세던 위치 한 칸 앞(`m5-28-qa`·`m5-29-qa`·`m5-29-concept-skins-2`·`m5-32-fresh-mackerel`·`m6-08-legend-skins`·`m6-09-magical-girl-sushi`·`m6-10-angel-devil-sushi`), 맨 끝 = 다이너마이트(`m5-28-concept-skins`).
- 뽑기: 전설 등급 9종, 스킨마다 0.111% — 화면 표시(`DrawLogic.perSkinPercent`)는 **"0.11%"**. `SOLD_LEGENDS`(m5-31 때 카탈로그)에 추가, 고등어 레이아웃 스냅숏 제외 목록에 추가(`m5-32-fresh-mackerel` AC5).
- require: 견본 모듈이 토핑 모듈 6개(`sushi-body`·`m5-28-concept-skins`).

### 검증
- `lune run tests` **2552 passed, 0 failed** (이 브랜치 기준 2535 + 새 17). `rojo build` 통과, `stylua --check src tests tools` 통과, `luau-lsp analyze` 끝 코드 0, selene 근사 std(Roblox API 검사 없음) 0 errors / 0 warnings.

### Studio에서 확인할 것 (사용자)
1. 탈의실 전설 탭 맨 끝(악마 다음) 다이너마이트, 카드 "R$ 199 — 곧 열려요" + "🎫 뽑기 전설에서도 나와요".
2. 불꽃 Sparkles·심지 Smoke 양(렌더러는 Sparkles를 안 그려요), Neon 불꽃이 Future 조명에서 너무 밝지 않은지.
3. 걸을 때 팔이 앞 모서리·옆 막대 사이로 자연스럽게 흔들리는지(팔은 막대와 안 겹치게 배치했지만 흔들림 폭은 Studio에서).
4. 이름표가 불꽃과 겹치지 않는지(꼭대기 2.62, 이름표 3.6).
5. 뽑기 화면: 전설 줄 1.0%, ⓘ 스킨별 "각 0.11%" 9줄(실제 0.111%), 보유 n/18.
6. 대사·영어 문구, 개발자 상품(R$ 199) → `productId`. 공격 연출은 메인 세션 main 쪽(`AttackFxLogic`).

### 남은 것 / 막힌 점
- 남은 것: 사용자 Studio 확인, 상품 id, 문서 반영(메인 세션), 진짜 roblox std로 selene 한 번, main의 `AttackFxLogic` 연출과 병합 뒤 검증 다시.
- 막힌 점: 없음.
