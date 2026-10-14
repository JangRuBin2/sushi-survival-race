status: in-dev
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-32 — 전설 스킨 "고등어 초밥 [신선]" (팔딱거리는 통고등어)

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §9.1 (겉모습만), §9.2 (전설 R$ 199·코인 불가, 효과 예산 전설 2개·외곽 ±25%), §6 (캐릭터), §9.6 (뽑기 전설 등급) · 바탕: m5-25 캐릭터 움직임(`CharacterAnimLogic`), m5-27~m5-30 콘셉트 몸(`SushiConceptSample`, 파츠 상한 70 — m5-30), m5-31 특 스킨(뽑기)
- 사용자 시트: **`docs/고등어 초밥 캐릭터 시트.png`** (정면·3/4·후면, 표정 5종, 액션 "팔딱!"·"첨벙!") — 개발은 반드시 이 그림을 직접 보고 시작한다.
- 조사: [`docs/REFERENCE-fresh-mackerel.md`](../REFERENCE-fresh-mackerel.md) (가격 근거, 움직임 Hz·각도 근거, 신선함 요소)
- 담당 개발 worktree: 브랜치 `m5-32-fresh-mackerel`
  - **시작 조건 (필수)**: m5-30(콘셉트 토핑 퀄리티, `SushiConceptSample`·파츠 상한 70)과 **m5-31(우승자 뽑기 — `drawGrade`·`DrawLogic`·`Skins.DRAW_IDS`)이 main에 병합된 뒤** 그 main에서 시작한다. 고등어는 뽑기 전설 등급(`drawGrade = "Legendary"`)이라 m5-31의 `DrawLogic`·validate 규칙("`drawGrade` + `robux`" 스킨)이 있어야 한다(2026-10-14 2차 결정).
- 공용 파일 수정 담당: **없음** (Config·Remotes·Types·Attributes·maps·default.project.json·init 스크립트·rokit.toml 안 건드림). 상품 id 칸은 `Skins.luau`(공용 아님).

## 목표
콘셉트 몸(넓은 밥 + 작은 눈·팔·다리) 위에 **통고등어 한 마리**가 누운 전설 스킨을 R$ 199에 팔고, **우승자 뽑기(m5-31)의 전설 등급(1%)으로도** 나오게 한다. 뽑기로 얻든 사든 같은 보유다. 이 스킨의 값어치는 효과 개수가 아니라 **살아 있는 듯 팔딱거리는 움직임**과 **갓 잡은 듯 윤기 나는 고등어 비주얼**이다. 움직임은 클라이언트 로컬 연출뿐이고 판정·크기·속도는 다른 스킨과 같다.

## 범위
- 포함
  1. 새 스킨 `fresh-mackerel` (카탈로그, 콘셉트 몸, 고등어 토핑, 표정 4종은 콘셉트 몸 것 그대로).
  1-1. **뽑기 전설 등급**: `drawGrade = "Legendary"` — m5-31 `DrawLogic`이 자동으로 전설 1%(빈 등급 나누기 끝)로 바꾼다. 뽑기 화면의 전설 줄·대표 스킨·보유 목록(n/10)·스킨 상세 "R$ 199로 사기", 탈의실 전설 카드의 "🎫 뽑기 전설에서도 나와요" 안내.
  2. **콘셉트 몸 예외를 판매 스킨도 쓸 수 있게** 일반화(아래 "콘셉트 몸 예외").
  3. **관절 사슬**: `PartSpec.joint = true` + `attach = "<관절 파츠>"`이면 Motor6D의 Part0을 그 파츠로(지금은 항상 Body). 고등어 몸통→뒷몸→꼬리를 사슬로.
  4. **팔딱 움직임**: 순수 `CharacterAnimLogic.fishPose` + `CharacterFxController`(내 캐릭터·다른 플레이어) + 새 클라이언트 모듈 `client/fx/DollAnimator.luau`(탈락·우승 인형, 단상, 탈의실 미리보기). 모두 **파츠 이름**으로 찾는다.
  5. 렌더: 정지 렌더 + **포즈 렌더**(렌더 도구에 `--pose <이름>` 옵션 추가, `tools/` 수정), 시트 비교, 비평 3회 이상.
  6. 탈락 대사 2줄, 현지화 키(m5-26이 main에 있을 때만).
- 제외
  - 판정·히트박스·속도 변경 (GDD 9.1)
  - ~~시트의 "화남"·"슬픔" 표정~~ → **넣는다**(사용자 결정 2026-10-14 3차, 아래 "3차 결정")
  - 다른 스킨에 물고기 움직임 붙이기, 용 롤 꼬리 움직임(다른 스펙)
  - ~~소리 무음~~ → **팔딱·첨벙 효과음 넣는다**(사용자 결정 2026-10-14 3차, 아래 "3차 결정")
  - 특별 상품·세트에 넣기(전설 세트는 그대로)
  - ~~뽑기 풀(m5-31)에 넣기 — 넣지 않는다~~ → **2차 결정으로 넣는다**(위 1-1). 뽑기 확률·중복 코인 규칙 자체는 m5-31 몫(바꾸지 않음)
  - 탈의실 "🎫 특" 탭에 넣기 — 특 탭은 뽑기 전용 9종만(고등어는 전설 탭)

## 카탈로그
| 칸 | 값 |
|---|---|
| id | `fresh-mackerel` |
| displayName | **고등어 초밥 [신선]** |
| en (AC17) | Mackerel Sushi [Fresh] |
| tier | `Legendary` |
| robux | **199** (A안) |
| coins | 없음 (에픽·전설은 로벅스만) |
| productId | nil — 사용자가 개발자 상품을 만든 뒤 넣음 (USER-TODO C3) |
| order | 41 (전설 탭 맨 끝, "전체"에서도 맨 끝) |
| speech | "아직 팔딱팔딱 살아 있다고!" / "오늘 아침에 잡힌 몸이야~" |
| en speech | "Still flipping fresh!" / "Caught just this morning~" |
| 콘셉트 몸 | 예 (아래) |
| drawGrade | **`Legendary`** (뽑기 전설, 1%) — 판매(robux)와 같이 있는 유일한 뽑기 스킨. 뽑기 전용(`isDrawOnly`) 아님 |
| 중복 | 이미 가진 사람이 뽑기에서 고등어가 나오면 🍚 +300(`Config.Draw.DuplicateCoins.Legendary`, m5-31). 이미 가진 사람의 로벅스 구매는 기존 `AlreadyOwned`로 막음 |
| 효과 | **1개**: 꼬리지느러미에 연한 물빛 `Sparkles`(effectColor 예: {150, 210, 255}) — "물기·반짝". 전설 예산 2개 중 1개만 쓰고, 나머지 "첨벙"은 효과 대신 **물방울 파츠**(아래)로 만든다(효과는 늘 뿜어져 나와 팔딱 순간에 맞출 수 없어서). 개발이 렌더·Studio에서 2번째 효과(예: 은빛 `Glow`)가 낫다고 보면 결정 기록에 남기고 써도 된다(예산 2 이하). |

### 콘셉트 몸 예외 이름 바꾸기
지금 `experimental`은 원래 "무료 실험 스킨"이었지만 m5-31부터 특 스킨(뽑기)의 **몸 모양 예외**만 뜻한다. 이번에 판매 스킨도 쓰므로 뜻에 맞게 이름을 바꾼다.
- `Skin.experimental` → `Skin.conceptBody: boolean?`, `Skins.EXPERIMENTAL_IDS` → `Skins.CONCEPT_BODY_IDS`, `SushiBody.EXPERIMENTAL` → `SushiBody.CONCEPT_BODY`. (예전 이름은 남기지 않는다 — 테스트·주석·렌더 도구까지 같이 바꾼다.)
- `CONCEPT_BODY_IDS` = 특 9종 + `fresh-mackerel` (10). `SushiConceptSample.SKIN_IDS`도 10. m5-31의 `Skins.DRAW_IDS`도 `fresh-mackerel`이 들어가 **10**(지금은 `CONCEPT_BODY_IDS`와 같은 목록이지만 뜻이 다르므로 테스트는 "같다"가 아니라 각각 명시 목록으로 비교). 뽑기 전용 목록(`isDrawOnly`)은 9 그대로.
- 규칙 표 `SushiBody.CONCEPT_BODY[id] = { partBudget, expressions, boundsTolerance? }`. 특 9종은 지금처럼 외곽 비교 없음(`boundsTolerance = nil`), `fresh-mackerel`은 **`boundsTolerance = BOUNDS_TOLERANCE.Legendary`(0.25)를 concept-salmon 외곽 기준으로** 비교한다.
- validate: 콘셉트 몸 스킨은 등급이 무엇이든 될 수 있다(특 = Basic + `drawGrade`(뽑기 전용), 고등어 = Legendary + robux + `drawGrade = "Legendary"`). 가격·얻는 길 규칙은 m5-31의 tier·`drawGrade` 규칙을 그대로 따른다("`drawGrade` + `robux`"는 보통 판매 규칙 + 뽑기, 콘셉트 몸이라고 무료가 아님). 효과 예산은 등급 규칙(전설 2).

## 모양 (시트 기준 — 개발은 그림을 보고 렌더 비평으로 맞춘다)
- **공유 부분**(concept-salmon과 같음): 밥·받침·팔·다리·얼굴(표정 4종)·관절 8개. 밥 앞 얼굴이 시트처럼 고등어 아래에 그대로 보인다.
- **고등어** 한 마리가 밥 위에 **X축으로 가로** 누움. 시트 정면 그림 기준 **보는 사람 왼쪽(캐릭터의 오른쪽, +X)에 머리**, 오른쪽(−X)에 꼬리 — 개발이 정면 렌더로 시트와 방향을 맞춘다.
  - 머리: 둥근 머리 + 앞(−Z)·뒤(+Z) 양쪽 **큰 눈**(크림 테두리 + 검은 눈동자 + 흰 하이라이트, 시트처럼 크게), 살짝 **벌린 입**(어두운 분홍 안쪽), 아가미 선.
  - 몸통: 머리 쪽이 굵고 꼬리 쪽으로 가늘어짐. **등 청회색**(예 {95, 115, 150}) + **짙은 남색 물결 줄무늬**(예 {40, 52, 80}, 등에서 옆구리로 내려오는 얇은 비스듬한 줄 여러 개 — 앞·뒤 양면), **배 은백색**(예 {225, 228, 232}, 금속 느낌 재질 — `Foil` 또는 `SmoothPlastic` + 밝은 하이라이트 띠), 등과 배 사이 부드러운 경계(중간색 띠).
  - **윤기**: 등 위에 밝은 하이라이트 띠(얇은 흰·하늘색 파츠, 길게) — "젖은 막 잡은" 느낌. 재질은 렌더·Future 조명에서 정한다(AC16).
  - 지느러미: 가슴지느러미(머리 뒤 양쪽, 반투명 느낌 청회색 `transparency` ≤ 0.3), 등지느러미 1~2(작게), **V자로 갈라진 꼬리지느러미**(Wedge 2개 이상).
  - **김 띠**: 고등어 뒤쪽 1/3쯤을 **비스듬히**(시트처럼 약간 기울여) 위→앞·뒤로 감아 밥 옆까지 내려감. 김 띠는 **뒷몸(FishMid)** 에 붙어 같이 움직인다(띠가 고등어를 붙잡고 있는 모양 유지).
  - **물방울**: 작은 물빛 공(Ball, `Glass` 또는 `SmoothPlastic`, 반투명 ≤ 0.35) **3~4개**(`Splash1`~`Splash4`). 평소에는 고등어 몸 **속에 완전히 숨어** 있다가 팔딱 순간 관절 이동으로 튀어나왔다 돌아간다(파츠 크기·투명도를 프레임마다 바꾸지 않는다 — m5-25 원칙).
- **관절 (이름이 계약 — 클라이언트는 이 이름으로만 찾는다)**
  | 파츠 | 관절 부모 | 움직임 | 붙는 파츠(`attach`) |
  |---|---|---|---|
  | `FishRoot` | Body | 들썩(Y 이동)·몸 휨(Z축 회전 — 머리·꼬리가 위로 휘는 아치)·살짝 비틀림(X축) | 머리·눈·입·앞몸·가슴지느러미·등지느러미 앞 |
  | `FishMid` | `FishRoot` | 좌우 흔들기(Y축 회전)·위로 휨(Z축) | 뒷몸·줄무늬 뒤쪽·김 띠·등지느러미 뒤 |
  | `FishTail` | `FishMid` | 꼬리 파닥(Y축 회전 큰 각)·위로 휨 | 꼬리자루·꼬리지느러미(효과 Sparkles) |
  | `FishFinL`/`FishFinR` | `FishRoot` | 가슴지느러미 팔랑 (선택 — 파츠 상한 안에서) | — |
  | `Splash1`~`Splash4` | Body | 팔딱 때 바깥·위로 튀어나옴 | — |
  - 관절 수: 기존 8 + 고등어 최대 9 = **17 이하**.
- **숫자 한도** (모든 표정 × 모든 테스트 포즈에서)
  - 파츠 ≤ **80**(이 스킨만 — 사용자 결정 2026-10-14 3차. 다른 콘셉트 몸 9종은 70 그대로).
  - 발바닥 = `GROUND_OFFSET`(2.25), 효과 ≤ 2(이번엔 1), 충돌·쿼리·터치 없음, Massless, z-fighting 0, 떠 있는 파츠 0(붙는 파츠는 부모 파츠와 닿거나 겹침), 이름 중복 0.
  - **쉰 자세(움직임 0)** 꼭대기 ≤ 이름표 − 0.4 (`NAME_TAG_HEIGHT` 3.6 → 3.2). **가장 크게 팔딱한 자세**에서도 꼭대기 ≤ 3.6(이름표를 잠깐 스쳐도 되지만 넘지 않음).
  - 외곽: 쉰 자세와 모든 테스트 포즈에서 concept-salmon 외곽 대비 X·Z 각 +25% 이하(폭 약 4.76 → **약 5.95 이하**). 고등어가 밥 양옆으로 나오는 건 이 안에서 허용.
  - 얼굴 가리지 않기: 모든 포즈에서 고등어·김·물방울 파츠가 얼굴 높이(밥 앞면의 눈·입 영역)에서 밥 앞면보다 앞으로 안 나오고, 꼬리·머리는 밥 윗면 − 0.2 아래로 내려오지 않는다.
  - 물방울 숨김: 쉰 자세에서 `Splash*` 파츠는 고등어 파츠들의 합친 상자 안에 완전히 들어간다(밖으로 0).

## 팔딱 움직임 (핵심, 기본값 — 렌더·Studio 보고 조정, 바꾼 값은 결정 기록에)
판정 무관, 클라이언트 로컬, 복제 없음. `CharacterAnimLogic`에 순수 함수로 두고 lune으로 검사한다.

- `CharacterAnimLogic.FISH` 상수 표(아래 값)와
  - `fishPose(input: FishInput) -> FishPose` — `FishPose = { rootLift, rootArch, rootTwist, midYaw, midArch, tailYaw, tailArch, finFlap, splash }` (거리 studs·각도 rad·splash 0~1).
  - `FishInput = { time, walk, phase, riseSpeed, airborne, landTime?, landStrength, knocked, flopTime?, mode }`, `mode = "Character" | "Idle" | "Hurt" | "Victory" | "Preview"`.
  - `nextFlopDelay(r, mode) -> number` (r 0~1, 테스트에서 고정).
  - `flopCurve(t) -> (amount 0~1)` 한 번 팔딱의 모양(빠르게 튀고 감쇠).
- 상태와 값
  | 상태 | 움직임 | 값 (기본) |
  |---|---|---|
  | 서 있음 — 살랑 | 꼬리 좌우 살랑 + 뒷몸이 반 박자 늦게 따라감(물결) | 꼬리 ±8°, 뒷몸 ±3°, **1.2 Hz** |
  | 서 있음 — 가끔 팔딱 | `nextFlopDelay` 간격(**2.5~6초**, 캐릭터)마다 한 번 **0.6초** 팔딱: FishRoot 들썩 +0.35, 아치(머리·꼬리 위로) 12°, 꼬리 ±35° **6 Hz** 감쇠, 뒷몸 ±14°, 물방울 0→1→0 | 위 |
  | 달리기 (walk > 0.2) | 꼬리가 걸음 위상의 **2배**로 계속 좌우, 뒷몸은 0.8 rad 늦게. 가끔 팔딱은 멈춤 | 꼬리 ±22°×walk, 뒷몸 ±9°×walk (걸음 2배 ≈ 3~4 Hz) |
  | 점프 올라갈 때 | 아치: 꼬리·머리가 위로 휘어 C자(공중에서 "팔딱!") | 아치 최대 20°(FishMid 10° + FishTail 15° 합산이 보이게), `stretch`에 비례 |
  | 착지 (`landStrength` > 0) | 착지 0.08초 뒤 큰 팔딱 0.5초: 들썩 +0.45×세기, 꼬리 ±40° 두 번 탁탁, 물방울 1(첨벙!) | 위 |
  | 넘어짐 (`knocked`) | 물 밖 물고기처럼 빠르게 퍼덕 | 꼬리 ±30° **7 Hz**, 뒷몸 ±12°, 들썩 0 |
  | 탈락 인형 (`Hurt`) | 축 처짐: 꼬리 아래로 처짐(아치 −10°), **1.5~2.5초**마다 약한 경련 0.3초(꼬리 ±15°) | 위 |
  | 우승 인형·단상 (`Victory`) | 신나게: **1.0~1.6초**마다 팔딱(0.6초, 물방울 1) | 위 |
  | 탈락 연출·탈의실 미리보기 (`Preview`) | 살랑 + **1.5~3초**마다 팔딱(보여 주기용으로 자주) | 위 |
- 한도
  - 진동수 상한 **7 Hz**(휴대폰 30fps에서 떨림으로 안 보이게, REFERENCE §2), 꼬리 최대 각 40°, 아치 최대 20°, 들썩 최대 0.45.
  - 모든 값은 연속(한 프레임에 크게 튀지 않음): 상태가 바뀔 때 0.15초 안에 섞는다(테스트: 1/60초 간격으로 꼬리 각 변화 ≤ 0.12 rad — 팔딱 순간 포함).
- 성능
  - 캐릭터 한 명당 매 프레임 Transform 쓰기: 기존 최대 8 + 고등어 최대 9 = **17 이하**. 카메라에서 `DETAIL_DISTANCE`(60)보다 멀면 고등어 관절도 기본 자세(identity)로 두고 계산하지 않는다. 24명이 모두 고등어여도 프레임당 408번 이하.
  - 고등어 관절이 없는 스킨은 고등어 계산을 건너뛴다(관절을 찾을 때 한 번 확인, 프레임마다 FindFirstChild 금지 — 지금 `findJoints` 캐시와 같은 방식).
  - `DollAnimator`는 화면에 있는 인형만(탈의실이 열려 있을 때, 연출 중일 때, 단상은 카메라 60 안) 돌리고, 인형이 사라지면 연결을 끊는다(`Cleanup`).
- 스킨 id 분기 금지: `CharacterFxController`·`DollAnimator`·`CharacterAnimLogic` 어디에도 `"fresh-mackerel"` 문자열이 없다(테스트로 고정). 관절 이름(`FishRoot`·`FishMid`·`FishTail`·`FishFin*`·`Splash*`)으로만 동작.
- 인형의 깜빡임·숨쉬기: `DollAnimator`는 이번엔 고등어 관절만 움직인다(다른 스킨 인형 움직임은 지금처럼 정지 — 범위 밖).

## 수용 기준
### 순수 로직 (lune 테스트로 확인)
- [ ] AC1 (카탈로그): `fresh-mackerel`이 위 표대로(이름 "고등어 초밥 [신선]", Legendary, robux 199, coins nil, order 41, 대사 2줄, `conceptBody = true`, `drawGrade = "Legendary"`). 카탈로그 개수 테스트 +1. `Skins.validate` 통과. `Skins.isDraw` true, `Skins.isDrawOnly` false. 전설 탭 `ShopLogic` 카드 상태는 다른 전설과 같다(로벅스 버튼, productId nil이면 "곧 열려요") + 안내 "🎫 뽑기 전설에서도 나와요". "🎫 특" 탭에는 없다. 코인 해금 요청 → 거절.
- [ ] AC2 (예외 이름): 코드·테스트·도구에 `experimental`·`EXPERIMENTAL`(콘셉트 몸 뜻) 식별자가 남지 않는다. `Skins.CONCEPT_BODY_IDS` = `SushiBody.CONCEPT_BODY`의 id = `SushiConceptSample.SKIN_IDS`(10, 정확한 목록 비교). `Skins.DRAW_IDS` = 특 9종 + `fresh-mackerel`(10, 명시 목록 비교), 뽑기 전용 목록은 특 9종.
- [ ] AC2-1 (뽑기 연결 — m5-31 `DrawLogic`): 실제 카탈로그 `DrawLogic.grades()` → 전설 skinIds = `{ "fresh-mackerel" }`이고 chance 0.01, 영웅 0.05·희귀 0.15·고급 0.30·일반 0.49(각 ±1e-9, 빈 등급 나누기 없음). `displayPercents` → "1.0%"·"5.0%"·"15.0%"·"30.0%"·"49.0%"(전설 "준비 중" 아님). `DrawLogic`·`Config.Draw` 소스는 이 작업에서 바뀌지 않는다(카탈로그만으로 바뀜 — diff 확인). 가짜 rng `NextNumber` 0.0099 → 고등어, 0.01 → 영웅. 안 가진 사람 → kind `Skin`(`ownedSkins["fresh-mackerel"] = true`, 장착은 안 바꿈), 가진 사람 → kind `Duplicate` + 🍚 300. `featured(빈 보유)` = `fresh-mackerel`.
- [ ] AC2-2 (뽑기 보유 = 구매 보유): 뽑기로 `ownedSkins["fresh-mackerel"] = true`가 된 프로필에서 로벅스 구매 판단(`ShopLogic`/`ReceiptLogic`의 기존 보유 검사)이 `AlreadyOwned`로 거절하고, 장착은 된다. 반대로 로벅스로 산 프로필에서 뽑기 전설이 나오면 `Duplicate` 300. 두 경로 모두 같은 `ownedSkins` 키 하나만 쓴다(보유 표시 따로 없음).
- [ ] AC3 (validate가 잡음): 목록 밖 id에 `conceptBody`를 달거나, 고등어에 효과 3개·외곽 +25% 초과·파츠 71개 이상을 주면 validate가 잡는다(가짜 레이아웃 주입 테스트).
- [ ] AC4 (모양 한도): 고등어 × 표정 4종 × 테스트 포즈 전부(쉰 자세, 꼬리 최대 +40°/−40°, 아치 최대, 착지 팔딱 최고점, 넘어짐 최대, Hurt 처짐)에서 위 "숫자 한도"를 모두 지킨다 — 파츠 ≤ 80, 발바닥 2.25, 쉰 자세 꼭대기 ≤ 3.2·포즈 꼭대기 ≤ 3.6, 외곽 X·Z ≤ concept-salmon × 1.25, 얼굴 안 가림, 꼬리·머리 밥 윗면 − 0.2 위, 쉰 자세 물방울 숨김, z-fighting 0, 떠 있는 파츠 0. (포즈 적용은 테스트에서 레이아웃 좌표에 관절 회전을 순수 계산으로 적용 — 함수는 개발이 `SushiBody` 또는 테스트 lib에 둔다.)
- [ ] AC5 (공유 부분): 고등어의 밥·받침·팔·다리·얼굴(표정별) 파츠와 관절 8개가 concept-salmon과 크기·위치·색·재질까지 같다. 다른 콘셉트 9종과 다른 31종(판매·시즌·VIP·기본)의 레이아웃은 이 작업 전과 바이트 단위로 같다(JSON 스냅숏 비교).
- [ ] AC6 (관절 사슬): 진짜 Instance build — Body만 Anchored. `FishRoot`의 Motor6D Part0 = Body, `FishMid` Part0 = `FishRoot`, `FishTail` Part0 = `FishMid`, 이름은 모두 `PartJoint`. 사슬 관절의 C0은 부모 파츠 기준이라 Transform이 identity일 때 레이아웃 좌표와 위치가 같다(오차 0.001). `attach`로 붙인 파츠는 자기 관절 파츠를 따라 움직인다(부모를 돌리면 같이 돈다). 관절 17개 이하. 사슬 없는 다른 스킨의 build 결과는 그대로.
- [ ] AC7 (움직임 값): `fishPose`가 위 표의 각 상태에서 값 범위를 지킨다 — 서 있음 살랑 꼬리 |각| ≤ 8°, 팔딱 중 ≤ 35°, 달리기 ≤ 22°×walk, 착지 ≤ 40°, 넘어짐 ≤ 30°, 아치 ≤ 20°, 들썩 ≤ 0.45, splash 0~1. 쉰 상태에서 splash = 0. 진동수: 넘어짐 꼬리 각의 0 교차 간격으로 잰 주파수 ≤ 7 Hz(모든 상태). 1/60초 간격 연속성(꼬리 각 변화 ≤ 0.12 rad, 상태 전환 포함).
- [ ] AC8 (간격): `nextFlopDelay(r, mode)`가 r=0·1에서 각 모드 범위 끝값(캐릭터 2.5·6, Victory 1.0·1.6, Preview 1.5·3, Hurt 1.5·2.5)이고 그 사이 단조. 달리는 중(walk > 0.2)에는 새 팔딱이 시작되지 않는다.
- [ ] AC9 (id 분기 없음): `src/client/fx/CharacterFxController.luau`·`src/client/fx/DollAnimator.luau`·`src/shared/CharacterAnimLogic.luau` 소스에 `fresh-mackerel`·`mackerel` 문자열이 없다. 고등어 관절이 없는 Model에 `DollAnimator`를 붙여도 오류 없이 아무것도 안 한다(가짜 Roblox 테스트).
- [ ] AC10: 검증 5단계 통과(rojo build, stylua, selene, `lune run tests` "N passed, 0 failed", luau-lsp 끝 코드 0). 돌리지 못한 단계는 보고에 그대로 적는다.

### 렌더 (개발이 PNG로 남기고 QA가 그림으로 확인)
- [ ] AC11: 렌더 → 글로 비평 → 고침 → 다시 렌더를 **3회 이상**, 회차별 비평을 `docs/developer/m5-32-fresh-mackerel.md`에. 비평은 **시트와 나란히** 본 것으로 쓴다(정면·3/4·후면 각각 "시트와 다른 점"). 다음을 `docs/renders/characters/`에 커밋: `fresh-mackerel-turntable`, `-expressions`, `-gameplay-back`, `-mobile-back`, `-compare`(같은 전설 `golden-otoro`와, 그리고 concept-salmon과), `-sheet-compare`(시트 정면·3/4·후면과 같은 각도 렌더를 한 장에 — 도구가 시트를 못 붙이면 같은 각도 3장 + 비평에 시트 대비 설명), `-poses`(쉰 자세·꼬리 최대 좌·우·점프 아치·착지 팔딱 최고점·넘어짐·Hurt 처짐·물방울 나온 순간 8칸), `-flop-strip`(착지 팔딱 0~0.6초 6~8프레임).
- [ ] AC12 (가독성): 휴대폰 뒤 카메라(480×270)에서 고등어가 **고등어로** 읽힌다 — 청회색 등 + 줄무늬 + 은빛 배 + V자 꼬리가 보이고, 연어·장어(특)·판매 장어와 헷갈리지 않는다. 앞 카메라(소개·탈락 연출)에서 고등어 눈·벌린 입이 보이고 밥 얼굴은 가려지지 않는다.
- [ ] AC13 (신선함): 정면·3/4 렌더에서 등에 윤기 하이라이트 띠, 배에 은빛이 보인다(비평에 시트 대비 평가). 너무 검거나 하얗게 날아가지 않는다.

### Studio 확인
- [ ] AC14 (판매·입기): 탈의실 전설 탭 맨 끝에 "고등어 초밥 [신선]" 카드, "R$ 199"(상품 id 전엔 "곧 열려요"). `fakeRobuxInStudio = true`로 가짜 결제 → 보유·자동 장착. (`unlockAllSkinsInStudio = true`면 결제 없이 "입기 (Studio)"로도 확인.)
- [ ] AC14-1 (뽑기 전설): `unlockAllSkinsInStudio = false`, 관리자 `tickets 99` → 탈의실 "🎫 뽑기" 화면: 확률표 전설 줄이 "1.0%"(금색, 가장 강조), 영웅 5.0 / 희귀 15.0 / 고급 30.0 / 일반 49.0, 단상에 고등어가 서고 "고등어 초밥 [신선] 스킨 획득 가능!"(샘플과 같은 모습), 보유 목록 n/10. 고등어가 나올 때까지 뽑으면(평균 100장 — 오래 걸리면 개발이 Studio 전용 확인 방법을 개발 메모에 적음, 커밋 기본값은 끔) "스킨 획득!" 화면이 전설 빛으로 가장 화려하고, 그 뒤 전설 카드가 "입기", 로벅스 구매 버튼은 "가진 스킨"으로 막힌다. 가진 상태에서 다시 나오면 "🍚 +300".
- [ ] AC15 (움직임 — 내 캐릭터·다른 플레이어): 가만히 서 있으면 꼬리가 살랑이고 몇 초마다 "팔딱"(들썩 + 꼬리 파닥 + 물방울). 달리면 꼬리가 걸음에 맞춰 계속 흔들리고 걸음과 엇박이 아니다. 점프하면 공중에서 C자로 휘고 착지하면 크게 팔딱 + 물방울. 넘어지면 빠르게 퍼덕. **Clients and Servers 2명**에서 다른 사람 고등어도 똑같이 움직인다. 고등어가 밥에서 떨어져 보이거나 김 띠가 고등어에서 빠져 보이지 않는다.
- [ ] AC16 (조명): Future 조명(로비·맵 2~3개)에서 등 윤기·은빛 배가 살아 보이고, 꼬리 Sparkles가 물기처럼 보인다(너무 반짝거리지 않음).
- [ ] AC17 (인형): 탈락 인형(아픔 x x + 반창고)에서 고등어가 축 처졌다가 가끔 경련, 우승 연출·로비 단상에서 신나게 팔딱, 탈의실 3D 미리보기에서 살랑 + 자주 팔딱. 탈의실을 닫거나 연출이 끝나면 움직임이 멈추고 오류 로그 없음.
- [ ] AC18 (성능): `Test → Clients and Servers` 8명 모두 고등어(또는 관리자 미리보기)로 로비·Race 맵에서 달릴 때 프레임이 다른 전설 스킨 8명일 때와 눈에 띄게 다르지 않다(마이크로프로파일러 또는 F9 확인 — 숫자를 개발 메모·QA 리포트에). 60 studs 밖 고등어는 움직임이 멈춘다.
- [ ] AC19 (현지화 — 조건부): main에 m5-26(`src/shared/Localization/Strings.csv`)이 있으면 `skin.fresh-mackerel.name`·`speech.1|2` 3행(위 en) 추가, m5-26 테스트 통과. 없으면 "해당 없음"으로 개발 메모에.

## 공용 파일 변경
- 없음. (`Skins.luau`·`SushiBody.luau`·`SushiConceptSample.luau`·`CharacterAnimLogic.luau`·`CharacterFxController.luau`·새 `DollAnimator.luau`·탈락/우승 연출·`LobbyFxController`(단상)·`ShopScreen`(미리보기)·`tools/render*`·테스트는 공용 아님.)

## 사용자 작업 (USER-TODO에 추가함)
- 개발자 상품 1개 더 만들기: "고등어 초밥 [신선]" R$ 199 → id를 알려 주면 `Skins.luau`의 `productId`에 넣음 (C3).
- Studio에서 움직임 체감 확인(AC15~AC17) — "팔딱"이 너무 잦거나 정신없으면 간격·각도를 숫자로 알려 주기.

## 결정 기록
<!-- 날짜 · 질문 · 결정 · 누가 -->
- 2026-10-14 · 새 스킨 요청 (사용자 원문 요지) · 사용자 시트 `docs/고등어 초밥 캐릭터 시트.png`. **고등어 초밥 스킨을 전설(Legendary) 등급으로**. "퀄리티 굉장히 높아야 함", "초밥 위의 고등어가 굉장히 팔딱거리는 게 포인트 → 애니메이션 효과에 각별히 신경", "굉장히 신선한 고등어 비주얼", **이름 끝에 [신선]** (예: "고등어 초밥 [신선]") · 사용자
- 2026-10-14 · 시트 요약 · 콘셉트 몸(넓은 밥 + 작은 눈·팔·다리)에 고등어 한 마리가 통째로 가로(X축)로 누움. 머리(큰 눈·벌린 입) 한쪽, 반대쪽 갈라진 꼬리지느러미, 가슴·등지느러미, 등은 청회색에 짙은 물결 줄무늬, 배는 은백색, 윤기. 김 띠가 고등어+밥을 비스듬히 감음. 액션: "팔딱!" 점프·"첨벙!" 물방울 · 메인 세션(시트 확인), 기획이 그림 직접 확인
- 2026-10-14 · 가격 · 전설 A안 R$ 199, 코인 불가 — 근거: 사용자 확정 A안(GDD 9.2), 기존 전설 5종과 같음 (REFERENCE-fresh-mackerel §1) · 기획(확정값 적용)
- 2026-10-14 · 몸 · 콘셉트 몸 사용, 판매 스킨도 쓸 수 있게 예외를 `conceptBody`/`CONCEPT_BODY`로 이름을 바꿔 일반화. 고등어만 전설 외곽 ±25%를 concept-salmon 기준으로 검사. ~~뽑기 풀에는 넣지 않음~~(2차 결정으로 넣음, 위) · 메인 세션 제안 → 기획 확정
- **2026-10-14 (2차, 사용자 결정 — 메인 세션 전달)** · 뽑기 · 위 "뽑기 풀에는 넣지 않음"을 바꿈: **고등어 [신선]은 m5-31 뽑기의 전설(1%)로도 나오고 로벅스 199 판매도 한다.** 뽑기로 얻든 사든 같은 보유, 이미 가진 사람은 구매를 막음(기존 `AlreadyOwned`), 뽑기에서 다시 나오면 🍚 +300. 사용자 뽑기 화면 샘플(`docs/귀여운 초밥 스킨 뽑기 UI.png`)도 전설 = 고등어로 그려져 있음. 그래서 m5-31 병합 뒤 시작이 필수 · 사용자
- 2026-10-14 (2차) · 판매 + 뽑기가 정책상 괜찮은지 · 로벅스로는 "정해진 고등어 한 마리"를 사는 것이고, 뽑기는 우승으로만 받는 뽑기권으로만 한다 — **뽑기 자체를 돈으로 할 수 없으므로** 유료 랜덤 아이템이 아니다. 고등어를 사도 확률은 그대로(전설이 나오면 코인으로 바뀔 뿐) · 기획 — 근거: REFERENCE-winner-ticket-draw §1·§4
- 2026-10-14 · 파츠 상한 · 70 (m5-30 콘셉트 상한, 사용자 결정 2026-10-14와 같음). 더 필요하면 사용자에게 묻는다(열린 질문 1) · 기획
- 2026-10-14 · 효과 · Sparkles 1개(꼬리, 물빛). "첨벙" 물방울은 효과가 아니라 관절로 튀어나오는 파츠 — 효과는 늘 뿜어져 팔딱 순간에 맞출 수 없어서 · 기획
- 2026-10-14 · 움직임 수치 · 살랑 1.2 Hz·±8°, 팔딱 6 Hz·±35°·0.6초, 착지 ±40°, 넘어짐 7 Hz, 상한 7 Hz — 근거: 물고기 유영 1~4.5 Hz·버스트 약 10 Hz [검색], 휴대폰 30fps에서 8 Hz 넘으면 떨림, m5-27 팔 35° 기준 (REFERENCE-fresh-mackerel §2). 모두 기본값 · 기획
- 2026-10-14 · 인형 움직임 · 새 클라이언트 모듈 `DollAnimator`(고등어 관절만). 다른 스킨 인형 깜빡임 등은 범위 밖 · 기획
- 2026-10-14 · 표정 · 콘셉트 몸 4종(기본·신남·당황·아픔)만. 시트의 화남·슬픔은 뺌 · 기획 (열린 질문 2)
- 2026-10-14 · 이름·대사 · "고등어 초밥 [신선]" (사용자 예시 그대로), 대사 "아직 팔딱팔딱 살아 있다고!" / "오늘 아침에 잡힌 몸이야~" · 기획
- 2026-10-14 · **3차 결정 (사용자)** — 열린 질문 1~3 답:
  1. **파츠 상한: 고등어만 80** (`SushiBody` 콘셉트 몸 예외 표에서 `fresh-mackerel`의 partBudget = 80, 다른 9종 70 그대로, 테스트로 고정). 24명 모두 고등어여도 캐릭터 파츠 약 1,900개.
  2. **표정 "화남"(Angry)·"슬픔"(Sad)을 만든다**: 시트의 화남(찡그린 눈썹 + ><에 가까운 눈 + 작은 입, 💢)·슬픔(처진 눈 + 눈물 한 방울 + 작은 입)을 **콘셉트 몸 공용 얼굴**(`SushiConceptSample` face)에 추가해 콘셉트 몸 스킨 모두가 쓸 수 있게 한다(`EXPRESSIONS` 6종). 기존 4표정 레이아웃은 바이트 단위로 그대로. 쓰는 곳: 탈의실·뽑기 화면 스킨 상세의 표정 썸네일(m5-31 상세 패널)과 미리보기 인형. 게임 흐름(탈락 = 아픔, 우승 = 신남)은 그대로. 새 표정도 파츠 상한·얼굴 규칙·깜빡임 관절 규칙(감은 눈 표정이면 관절 없음 등)을 지킨다.
  3. **팔딱·첨벙 효과음 넣는다**: `SfxCues`에 `FishFlop`(팔딱 — 큰 팔딱·착지 팔딱 순간), `FishSplash`(첨벙 — 물방울이 튀는 순간) 2개. 소리 id는 사용자가 고르므로(USER-TODO A2) 처음엔 비어 있고, 비어 있으면 조용히 건너뛴다(기존 Sfx 규칙). 클라이언트 로컬 재생, 캐릭터 위치에서 3D 소리(가까울수록 크게, 최대 거리 약 60 studs — 움직임 정지 거리와 같음), 같은 캐릭터당 0.25초에 한 번 이하, 서 있을 때 살랑(작은 움직임)에는 소리 없음. 인형(탈의실·뽑기 미리보기·우승 단상)도 팔딱할 때 소리(탈의실·뽑기 화면에서는 UI 소리로, 볼륨 낮게). 판정·복제 없음.
- 2026-10-14 · 개발 · 들썩·아치 수치: 가끔 팔딱 들썩 0.3(기본 0.35)·아치 10°(12°), 착지 들썩 0.41×세기(0.45), 비틀림 5° — 꼬리 위 갈래가 팔딱 꼭대기 3.6(이름표)을 넘지 않게. 나머지는 기본값 · 개발 (렌더·테스트 근거, docs/developer/m5-32-fresh-mackerel.md)
- 2026-10-14 · 개발 · 김 띠: 고등어 띠·자락은 스펙대로 FishMid에 붙어 움직이고, 시트의 "밥까지 감은 김"은 Body에 용접된 **밥 김** `NoriWrap`(밥 윗면 가장자리 + 앞면 위 0.17 — 얼굴의 땀·💢·눈썹을 가리지 않게)·`NoriWrapBack`(뒷면 0.3까지)으로 만듦. 팔딱으로 고등어가 들리면 잠깐 띠와 밥 김 사이가 벌어짐("김에서 튀어 오름"). 이름이 `Fish`가 아니라 고등어 파츠 검사 대신 전용 테스트로 고정 · 개발
- 2026-10-14 · 개발 · 소리 간격: "캐릭터당 0.25초에 한 번"을 소리마다(FishFlop·FishSplash 각각)로 — 팔딱과 첨벙은 짝이라 같이 울림 (`CharacterAnimLogic.fishSoundFilter`) · 개발
- 2026-10-14 · 개발 · 파츠 수: 기본 75·신남 71·당황 77·아픔 71·화남 79·슬픔 79 (상한 80) · 개발
- **열린 질문 (사용자)**
  1. 파츠 상한: 콘셉트 상한 70 안에서 만든다. 렌더 비평에서 "줄무늬·지느러미 때문에 70으로는 시트 퀄리티가 안 나온다"고 판단되면 **이 스킨만 80**까지 올려도 될지(24명 모두 고등어면 캐릭터 파츠 약 1,900개 — 모두 충돌 없음·Massless). 추천: 70으로 먼저 해 보고, 개발이 렌더 근거를 붙여 요청하면 결정.
  2. 시트의 "화남"·"슬픔" 표정을 콘셉트 몸 전체 표정으로 추가할지 — 지금 게임에서 쓰는 곳(탈락 = 아픔, 우승 = 신남)이 없어서 이번엔 뺌. 추천: 나중에 감정 표현(이모트) 기능이 생기면.
  3. "팔딱"·"첨벙" 효과음을 넣을지(소리 id는 사용자가 고름, A2) — 넣으면 다른 스킨과 달리 "소리 나는 스킨"이 됨. 추천: 무음으로 먼저 보고 결정.

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
- 파츠 예산 참고: 공유 부분(밥·받침 8 + 팔·다리 4 + 얼굴 최대 15) ≈ 27 → 고등어(관절 파츠·물방울 포함)는 **약 43개 이하**.
- 렌더 도구 `--pose`는 `CharacterAnimLogic.fishPose`의 상태를 이름으로 골라 관절 회전을 레이아웃에 적용해 그린다(테스트 AC4와 같은 계산을 재사용).
- **2026-10-14 개발 완료 (`in-qa`)** — 자세한 기록·렌더 비평 4회·Studio 확인 순서는 `docs/developer/m5-32-fresh-mackerel.md`.
  - 바뀐 파일: `src/shared/`(ConceptMackerel·PartMath·SushiPose 새, SushiConceptSample·SushiBody·Skins·CharacterAnimLogic·SfxCues·SfxLibrary·ShopLogic·UiLayout), `src/client/`(fx/FishRig·fx/DollAnimator 새, CharacterFxController·탈락/우승 연출·LobbyFxController·Sfx·ui/DrawScreen·ShopScreen·ShopController), `tools/render-character.luau`·`tools/render/Png·Sheet`, `tests/m5-32-fresh-mackerel.spec.luau`·`tests/lib/LayoutSnapshot.luau`·`tests/fixtures/m5-32-layout-snapshot.txt` 외 이름 바꾼 테스트.
  - 렌더: `docs/renders/characters/fresh-mackerel-{turntable,turntable-lobby,expressions,gameplay-back,gameplay-front,mobile-back,mobile-front,compare,sheet-compare,poses,poses-lobby,flop-strip,closeup}.png`, 처음 상태 `-before-sheet-compare`·`-before-flop-strip`.
  - m5-31 재QA P3 R1(`detailPanel.Active = true`)·R2(이름·대사 칸 0.52, 휴대폰 큰 미리보기 0.44)도 이 브랜치에 있음.
  - AC19 현지화: main에 m5-26이 없어 해당 없음.
  - Studio 확인: 탈의실 전설 탭 카드·가짜 결제(AC14), `tickets 99` 뽑기 확률표·단상(AC14-1, 고등어 당첨은 평균 100장), 서기·달리기·점프·착지·넘어짐 움직임(AC15, Clients and Servers 2명), 인형(AC17), Future 조명(AC16), 8명 성능(AC18).
