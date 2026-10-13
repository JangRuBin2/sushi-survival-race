# m5-27 캐릭터 콘셉트 견본 (연어초밥 1종, 렌더 확인용)

기준: 사용자 콘셉트 시트(2026-10-13). **범위 = 견본 하나** + (2차) 그 견본을 무료 실험 스킨 `concept-salmon`으로 게임에 넣기 (사용자 요청). 다른 31종 스킨 모양은 그대로예요. 스펙 파일 없음.

## 인계 메모 (최신이 위)

### 2026-10-13 — 무료 실험 스킨 `concept-salmon` (게임에서 써 보기)
사용자 요청: 견본을 게임에서 무료로 써 볼 수 있게. 스펙 파일 없음 (사용자 직접 요청, 범위 = 스킨 1종 추가).
- 브랜치: `m5-27-character-concept` (worktree `agent-a32c047dc60aee5a4`에서 `origin/main`을 병합한 뒤 작업, `HEAD:m5-27-character-concept`로 push)
- 끝난 것
  - **카탈로그** `Skins.luau`: `concept-salmon` "콘셉트 연어초밥 (테스트)", `tier = "Basic"`, `experimental = true`, 가격·얻는 길 없음, order 32 (탈의실 "전체" 탭 맨 끝). `Skins.EXPERIMENTAL_IDS`(이 id 하나)에 있는 id만 `experimental`을 달 수 있어요. `Skins.isFree(id)` = 계란초밥 또는 실험 스킨.
  - **보유 (저장 없이)**: 프로필 `ownedSkins`에 안 넣고 `Skins.isFree`로 판단 — `ShopLogic.canEquip`·`owns`(카드 "입기")·`canBuyWithCoins`(AlreadyOwned), `ReceiptLogic.canRequest`, `OfferLogic`, `ShopController`, `ShopService.equippedOf`(복사본에만 더함), `ProfileLogic.migrate`(장착값 유지). 실험 스킨을 나중에 빼면 장착값만 계란초밥으로 돌아가고 데이터는 안 남아요.
  - **validate 예외 (이 id만)**: 실험 스킨은 Basic + 무료여야 하고, 외곽 허용치(BOUNDS_TOLERANCE) 대신 `SushiBody.EXPERIMENTAL[id].partBudget`(47)만 봐요. 효과 예산(0)은 그대로.
  - **몸** `SushiBody`: `LAYOUTS["concept-salmon"] = SushiConceptSample.gameLayout("Default")`, `layout(id, expression?)`·`build(id, expression?)` — 표정은 이 스킨만 보고 나머지 스킨은 무시. `SushiBody.EXPERIMENTAL` 표. SushiBody의 **유일한 require = SushiConceptSample**(순수, 아무것도 require하지 않음 — 순환 없음). 그래서 견본은 SushiBody 타입을 쓰지 않고 같은 모양의 `PartSpec`을 따로 정의해요.
  - **게임 레이아웃** `SushiConceptSample.gameLayout(expression?)`: 발바닥 −2.25(= `SushiBody.GROUND_OFFSET`, `GAME_GROUND_OFFSET`로 assert) — 다리를 늘려 위끝을 밥 속 −0.8까지. 다리 이름 `FootLeft/Right`, 눈 깜빡임 관절(`EyeLeft/Right` joint + `EyeLow*`·`Shine*` attach + 감은 눈 `LidLeft/Right`), 팔 `ArmLeft/Right` joint, 앞 지방 줄 조각 3개 뺌. 파츠: 기본 44, 당황 46, 신남·아픔 40 (상한 47). 견본 렌더(`layout`/`build`)는 그대로.
  - **움직임**: m5-25 숨쉬기·깜빡임·점프 늘어남·착지 찌그러짐·발 걸음이 같은 관절 이름으로 그대로 동작. 팔 흔들기 새로 — `CharacterAnimLogic.pose().armSwing`(왼발이 앞이면 오른팔이 앞, 최대 35°×걷기), `CharacterFxController`가 `ArmLeft/Right` 관절이 있을 때만 어깨(파츠 위끝)를 축으로 돌려요. 없는 이름은 건너뛰어요(다른 스킨 영향 없음).
  - **표정 인형**: 탈락 연출 `build(id, "Hurt")`(x x + 반창고), 우승 연출·로비 단상 `build(id, "Happy")`(^ ^). 탈의실 미리보기는 기본 표정. 다른 스킨은 표정 인자를 무시해요.
  - **테스트**: 새 `tests/m5-27-concept-skin.spec.luau` 14개 (카탈로그·예외 범위, validate가 다른 id의 experimental·가격·등급을 잡음, 보유·카드·저장, 레이아웃 발바닥·파츠·z-fighting·떠 있음·이름표 아래, 표정, 관절·깜빡임 숨김, 진짜 Instance build, 팔 흔들기, 렌더 도구 경로, 클라이언트 연결). 기존 테스트는 **`skin.experimental`인 스킨만** 기준 몸·외곽·관절 6개·두께·뒷면 색 검사에서 빼고(이유 주석), 개수 31 → 32·Basic 1 → 2, SushiBody require 고정 테스트는 "SushiConceptSample 하나만"으로, 가짜 환경 로더(m3-02-qa·m5-25-qa)에 SushiConceptSample을 넣었어요.
  - **렌더**: `lune run tools/render-character concept-salmon --view turntable` (일반 스킨 경로), `all --view lineup`에 32번째로 나와요. `docs/renders/characters/concept-salmon-skin-turntable.png` (스튜디오 조명, 발이 땅에 닿음).
- 검증 5단계 (2026-10-13, Windows 로컬): rojo build OK · `stylua --check src tests tools` OK · selene 0/0/0 · `lune run tests` **1787 passed, 0 failed** · luau-lsp analyze 끝 코드 0.
- 남은 것 / 알려진 한계
  - 게임 중 통과·우승 순간 내 캐릭터 표정 바꾸기(신남)는 안 했어요 (인형만). 하려면 서버가 몸을 다시 만들거나 표정 파츠 보이기 전환이 필요.
  - 이름표 높이는 공용 3.6 그대로 — 이 몸은 꼭대기 1.97이라 이름표가 조금 높게 떠요.
  - 넘어짐 누운 높이(`LIE_HEIGHT` 1.8)는 기준 몸 기준 — 이 몸(폭 약 4.7, 팔 포함)은 누웠을 때 살짝 땅에 묻힐 수 있어요 (Studio 확인).
  - 입 덮개·혀 두께 0.03은 견본 그대로 (일반 스킨 최소 두께 0.06 규칙의 예외, z-fighting 0 확인).
  - **m5-26 현지화 브랜치가 main에 들어오면** 스킨 이름 CSV 테스트가 새 키를 요구할 거예요: `concept-salmon` 이름 "콘셉트 연어초밥 (테스트)"·대사 2줄 키를 CSV에 추가해야 해요 (여기서는 main에 없어서 안 넣음).
- 다음 첫 단계: 사용자 Studio 확인(아래) → 좋으면 planner가 "기준 몸 교체" 스펙.
- 막힌 점: 없음.

#### Studio 확인 방법 (concept-salmon)
1. Studio에서 Play → 로비의 탈의실 열기 → "전체" 탭 맨 끝 **콘셉트 연어초밥 (테스트)** 카드가 처음부터 "입기"인지 → 누르면 미리보기(돔 연어 + 김 띠 + 팔·다리)와 내 캐릭터가 바뀌는지.
2. 혼자 방을 만들어 출발 (`Config.DEBUG.minPlayersToStart = 1`) → 달리면서 **발이 땅에 닿는지**(뜨거나 묻히지 않음), 가만히 서면 숨쉬기·2~5초마다 깜빡임, 걸으면 발이 번갈아 들리고 **팔이 앞뒤로** 흔들리는지, 점프 착지 때 찌그러지는지.
3. 떨어져서 **탈락 연출 인형**이 x x 눈 + 반창고(아픔)인지, 우승하면 **우승 연출·로비 단상 인형**이 ^ ^ 눈(신남)인지.
4. 젓가락·잡기에 넘어졌을 때 옆으로 누운 몸이 땅에 너무 묻히지 않는지.
5. 휴대폰: Studio 기기 에뮬레이터(iPhone 등)로 같은 화면에서 뒤 카메라에 "연어초밥"이 읽히는지, 탈의실 카드·미리보기가 잘리지 않는지.
6. 다른 스킨(계란초밥·연어 등)으로 돌아가 움직임·인형이 예전과 같은지 (팔 관절이 없는 스킨은 변화 없음).

### 2026-10-13 — 견본·렌더 끝
- 브랜치: `m5-27-character-concept` (worktree `agent-aa45f31da65069b91`에서 `git push origin HEAD:m5-27-character-concept`)
- 끝난 것
  - `src/shared/SushiConceptSample.luau` (새) — `layout(expression?, pose?)`(순수), `build(...)`(Model, Body만 고정, 팔·다리 Motor6D, 나머지 용접), `EXPRESSIONS`(Default·Happy·Flustered·Hurt), `POSES`(Stand·Run), `GROUND_OFFSET` 2.0. 게임 코드 어디서도 안 불러요(테스트로 확인).
  - `tools/render-character.luau` — `--sample concept` 옵션: `<out>/<light>/concept/`에 turntable·turntable-run·expressions·gameplay-back/front·mobile-back/front·compare(지금 게임 연어 ↔ 견본). 배우 id `concept:<표정>:<자세>`. 기존 스킨 렌더 동작은 그대로.
  - `tests/m5-27-concept-sample.spec.luau` (새 6개) — 8조합 파츠 ≤ 48·이름·모양·z-fighting 0·떠 있는 파츠 0, 발바닥, 비율(토핑 30~42%), 진짜 Instance build 구조, 게임 코드가 견본을 안 씀.
  - 그림 `docs/renders/characters/concept-*.png` 8장 (아래 "최종 그림").
- 검증 5단계 (2026-10-13, Windows 로컬): rojo build OK · `stylua --check src tests tools` OK · selene 0/0/0 · `lune run tests` **1773 passed, 0 failed** · luau-lsp analyze 끝 코드 0.
- 남은 것: 사용자가 그림을 보고 방향 결정 → 좋으면 planner가 "기준 몸 교체 + 31종 재배치 + 표정 시스템 + 팔 흔들기" 스펙(파츠 예산 재검토 포함).
- 다음 첫 단계: 사용자 피드백.
- 막힌 점: 없음.

## 만들기 (`lune run tools/render-character --sample concept [--light studio|lobby|both] [--quality fast|high]`, 고품질 약 35초)

## 모양 요약 (메시 없이 Block·Ball·Cylinder만)
| 부위 | 구성 | 파츠 |
|---|---|---|
| 밥 | 세로 모서리 둥근 덩어리 3.6 × 2.0 × 2.7 (상자 2 + 세운 원기둥 4, Salt 재질 = 실제 Roblox에서 밥알 결) + 아래 좁은 받침(상자 2) | 8 |
| 연어 | 늘어진 가장자리 판(모든 모서리 둥근 "베개" 4.0 × 0.6 × 3.2: 상자 + 원기둥 4 + 공 4) + 돔 캡슐(축 X 원기둥 지름 2.7 + 양 끝 공) | 12 |
| 지방 줄 | 돔·앞 가장자리를 가로지르는 같은 축 얇은 원판 조각 × 3줄 | 6 |
| 김 띠 | 가운데 앞→돔→뒤 가장자리→등 아래 (원판 조각 3 + 등 판 1) | 4 |
| 얼굴 (기본) | 타원 눈(원판 2개 겹침) + 하이라이트 ×2, 입(진한 원판 + 밥 색 덮개 + 분홍 혀), 볼 2 | 11 |
| 팔·다리 | 네모 손 2(Motor6D), 짧은 네모 다리 2(Motor6D) | 4 |
- 파츠 수: 기본 **45**, 신남 43, 당황 47, 아픔 43 (게임 스킨 상한 40보다 5~7 많음 — 돔·늘어진 가장자리 12, 팔 2가 더 들어감. 게임에 넣으면 받침 2·지방 줄 앞 조각 3을 빼면 40 근처).
- 키 3.97 (발바닥 −2.0 ~ 돔 꼭대기 1.97), 밥 폭/키 0.91, 토핑(늘어진 아래끝 0.55부터) = 키의 36%.
- 표정: 신남 = `^ ^` 막대 + 큰 입, 당황 = 걱정 눈썹(안쪽이 올라감) + 작은 `o` 입 + 땀방울(공 + 마름모), 아픔 = `x x` + 일자 입 + 반창고(천 + 패드). 앞에서 봐서 오른쪽에 땀·반창고 (콘셉트와 같은 쪽).
- 자세: Run = 팔 앞뒤 35° 엇갈림, 왼발 앞으로 들림 (정지 그림용, 움직임 코드는 없음).

## 렌더 비평 (콘셉트 시트와 나란히 비교)
### 1회차 — 첫 모양 (얇은 베개 + 작은 등성이)
- 실루엣: 넓고 낮은 몸·밥보다 넓은 토핑은 콘셉트와 같음. 하지만 토핑이 얇고 평평해 "줄무늬 방석 + 혹" — 콘셉트의 도톰한 돔(키의 35~40%)과 다름.
- 지방 줄 4줄이 너무 규칙적이라 빵·방석처럼 보임. 팔은 뒤쪽에 얇은 판, 다리는 받침에 묻혀 거의 안 보임(콘셉트는 둘 다 또렷).
- 얼굴: 작은 타원 눈·하이라이트·작게 벌린 입·볼 — 콘셉트 느낌이 바로 남. 입 위에 작은 점 하나(원인 미상).
- 고침: 토핑 두께 0.9 → 1.1, 등성이 키움, 다리 0.75 → 1.0(발바닥 −2.0), 팔 크게·앞으로, 줄 3줄·폭 0.12, z-fighting 3건(김 띠 끝면) 정리.
### 2회차 — 두꺼운 베개 + 등성이
- 옆에서 보면 "두꺼운 테 + 위의 혹" 두 층, 3/4에서 등성이가 통나무처럼 따로 놂. 다리·팔은 보이기 시작.
- 고침: 등성이를 큰 캡슐로 바꿔 판 윗면을 거의 다 덮게(돔), 판은 가장자리로만.
### 3회차 — 큰 돔
- 돔은 생겼지만 판이 굵은 관(반지름 0.4)이라 "챙 달린 반구 헬멧"·버섯으로 읽힘. 게임 뒤 카메라에서는 테 안쪽이 오목한 쟁반처럼 보임.
- 고침(4~6회차): 돔 지름이 밥 깊이를 넘으면 밥 앞면을 뚫어서(타원 모양을 파츠로 못 만듦) 반지름 1.35로 묶고, 밥 깊이를 2.6 → 2.7로 늘려 돔이 밥 속에 숨게. 판을 얇게(0.6)·좁게(돔 밖으로 0.17만) 해서 챙이 아니라 **돔 아래로 살짝 삐져나온 늘어진 입술**로. 돔 중심을 내려 위를 조금 평평하게(꼭대기 1.97).
- 결과(6회차): 앞·3/4에서 "도톰한 연어가 밥을 덮고 가장자리가 늘어진" 모양. 게임 뒤 카메라에서도 쟁반 느낌이 거의 사라지고 "가운데 김 띠 두른 연어 초밥"이 한눈에.
### 7회차 — 얼굴 가까이 (얼굴 확대 렌더로 원인 찾기)
- 입 위 점 = 입 덮개 옆면(두께 0.085)이 선으로 보인 것, 그리고 위에서 볼 때 입 원판 윗변이 비침. → 입 원판을 밥에 거의 묻고(앞으로 0.03) 얇은 덮개(0.03)가 윗변보다 0.04 위까지 덮게. 다시 렌더해 깨끗한 반달 입 확인.
- 눈이 원 두 개 겹친 "8"자로 보임 → 원판 지름 0.36 → 0.4, 간격 0.1 → 0.07 (허리 홈 0.01, 타원 0.4 × 0.54).
- 당황 눈썹이 화난 V 모양 → 안쪽이 올라간 걱정 눈썹으로. 땀방울·반창고를 콘셉트처럼 앞에서 봐서 오른쪽으로, 땀방울 끝을 마름모로.
### 최종 (고품질, 스튜디오·로비 조명)
- 휴대폰 앞 화면(480×270, 12.5~16 studs): 세 명의 눈·입·`^ ^`·땀방울이 보임. 다만 눈이 지금 게임 몸(지름 0.98 큰 눈)보다 작아서 같은 거리에서 표정은 덜 커요 — 콘셉트 비율을 따른 대가.
- 휴대폰 뒤 화면: 연어 돔 + 가운데 김 띠 + 흰 밥 + 다리 두 개로 "연어초밥"이 바로 읽힘.

## 콘셉트와 아직 다른 점 (왜)
1. **돔 모양** — 콘셉트는 납작한 타원 돔이 가장자리까지 매끈하게 이어지는데, 파츠(공·원기둥)는 납작하게 못 늘려요. 돔(원기둥 반지름 ≤ 밥 깊이 절반)과 늘어진 판을 겹쳐서 흉내 냈고, 3/4에서 돔과 가장자리 사이에 얕은 골이 남아요. 매끈하게 하려면 메시(사용자 업로드)가 필요.
2. **지방 줄 방향** — 콘셉트는 대각선 줄인데, 휜 표면을 따라가려고 돔과 같은 축의 원판 조각을 써서 앞뒤 방향 곧은 줄이에요(돌리면 표면에서 떠요).
3. **김 띠 자리** — 콘셉트 정면 그림은 띠가 옆으로 치우쳐 있고 뒷모습은 가운데라 그림끼리 달라요. 뒷모습(게임에서 가장 많이 보는 화면)에 맞춰 가운데, 앞에서는 연어 위에서 끝나 얼굴을 안 가려요.
4. **밥알 결** — Salt 재질이라 실제 Roblox에서는 결이 보이지만 렌더러는 재질 무늬를 거의 안 그려요(Studio 확인 필요). 둥근 모서리는 세로 모서리만, 위·아래 모서리는 각져요(토핑·받침으로 가림).
5. **팔** — 콘셉트의 둥근 벙어리장갑 대신 네모 상자(살짝 기울임). 렌더에서 옆면이 평평하게 칠해져 3/4에서 판처럼 보일 때가 있어요.
6. **파츠 수** 45 (게임 상한 40). 표정은 모델을 새로 만드는 방식(견본용) — 게임에서는 파츠 보이기 전환이나 Decal 얼굴로 바꿔야 해요.

## 최종 그림 (`docs/renders/characters/`)
- `concept-salmon-turntable.png` 앞·3/4·옆·뒤·위 (스튜디오), `concept-salmon-turntable-run.png` 달리기 자세
- `concept-expressions.png` 기본·신남·당황·아픔
- `concept-gameplay-back.png` (게임 카메라 12.5 studs), `concept-gameplay-front-lobby.png`
- `concept-mobile-back.png`, `concept-mobile-front-lobby.png` (480×270)
- `concept-compare-salmon.png` 지금 게임 연어 ↔ 견본 (3/4·뒤, 칸마다 크기를 맞춰 그려서 실제 크기 비교는 아님)
