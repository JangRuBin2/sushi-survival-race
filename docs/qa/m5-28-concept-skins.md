# QA — m5-28 콘셉트 몸 스킨 4종 (참치·새우·계란·연어알 군함, 무료 테스트)

- 스펙: `docs/specs/m5-28-concept-skins.md`
- 검증 커밋: `68283e1` (브랜치 `m5-28-concept-skins`, main `481eea0` 기준 diff — 실제 갈라진 점 `c01a38f`)
- 결과: **통과** (P0/P1 없음) → 스펙 `qa-passed`. Studio 확인 AC9~AC12는 사용자 확인 필요.

## 자동 검증 (2026-10-13, 클라우드 Linux)
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | OK |
| `stylua --check src tests tools` | OK |
| `selene src` | 0 errors / 0 warnings / 0 parse errors (std는 `~/.cache/selene/roblox.yml` 캐시) |
| `lune run tests` | **1806 passed, 0 failed** (개발 1800 + QA 6) |
| `luau-lsp analyze …` (새 검사기) | 끝 코드 0 |
| `lune run tools/render-character concept-shrimp --view turntable --light studio` | 정상 출력 (1.5초) |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 카탈로그 36종, 새 4종 Basic·experimental·가격 없음·"(테스트)"·order 33~36·대사 2줄, validate 통과 | 통과 | `m5-28-concept-skins` "카탈로그: 새 4종…", `skins.spec` AC1, `m5-03-foundation` AC5 |
| AC2 예외 목록 3곳 일치(5종), 목록 밖 experimental·가격·다른 등급은 validate가 잡음 | 통과 | "예외 목록…", "validate: 새 실험 스킨에 가격…", `m5-27` "예외는 콘셉트 몸 5종뿐" |
| AC3 새 프로필에서 장착·"입기", 코인·로벅스 `AlreadyOwned`, `ownedSkins`에 안 들어감, migrate 뒤 장착 유지 | 통과 | "보유: 새 프로필에서도…" + QA "새 4종은 코인·로벅스·이벤트 재화 어느 길로도…" |
| AC4 5종 × 4표정 파츠 ≤ 47, 발바닥 2.25, 이름표 −0.4 아래, 효과 0, z-fighting·떠 있음·이름 중복 0 | 통과 | "레이아웃: 표정마다 파츠 ≤ 47…" (최대 46 = 연어·새우·연어알 당황) + QA 새우 꼬리 실제 접촉 |
| AC5 밥·받침·팔·다리·얼굴이 연어와 크기·위치·색·재질·관절까지 같음, 토핑이 얼굴 앞으로 안 나옴 | 통과 | "공유 몸…", "토핑이 얼굴을 안 가려요…" |
| AC6 관절 8개, 깜빡임 숨김/보임, 발 위끝, 진짜 Instance build (Body만 고정, Motor6D 8/4, 충돌·쿼리·터치 없음, Massless) | 통과 | "관절…", "build: 진짜 Instance…" |
| AC7 concept-salmon·다른 31종 레이아웃 바이트 동일 | 통과 (QA가 따로 확인) | QA가 main `src/shared`와 브랜치 `src/shared`를 같은 스크립트로 JSON 직렬화 — 32종 × (표정 없음 + 4표정) SushiBody 레이아웃, `gameLayout` 4표정, 견본 8조합, 카탈로그 항목 32개, 204줄이 `cmp`로 **완전히 같음** |
| AC8 SushiBody require = SushiConceptSample 하나, 견본은 require 없음, 클라이언트·서버에 콘셉트 id 분기 없음 | 통과 | "SushiBody: 여전히…", "클라이언트: 인형 표정·팔 흔들기는…" + `git diff --stat`: `src/server`·`src/client` 변경 0 |
| AC9 탈의실 "전체" 탭 맨 끝 4장 "입기", 미리보기·내 캐릭터 바뀜 | 로직 통과, **사용자 확인 필요** | QA "탈의실 — 새 4종은 '전체' 탭 맨 끝에만" (등급 탭에는 안 보임) |
| AC10 달리기·숨쉬기·깜빡임·팔 흔들기·착지 찌그러짐이 연어와 같음, 발이 땅에 닿음 | 로직 통과, **사용자 확인 필요** | 팔·발 관절 이름·위치가 연어와 같음 (QA "팔은 5종 모두 같은 자리…") |
| AC11 탈락 인형(아픔), 우승·단상 인형(신남) | 로직 통과, **사용자 확인 필요** | 인형 컨트롤러가 id 없이 `"Hurt"`/`"Happy"`로 `SushiBody.build` (테스트로 고정) |
| AC12 휴대폰 뒤 카메라 구분 | 렌더로 대체로 확인, **사용자 확인 필요** | 아래 "렌더 확인" |

합계: 순수 로직 AC1~AC8 **8/8 통과**, Studio AC9~AC12 **4개 사용자 확인 필요**(로직 쪽 근거는 통과).

## 핵심 위험 점검
- **concept-salmon 그대로**: 위 AC7 — main과 바이트 단위 동일 (개발 쪽 주장을 QA가 따로 재현).
- **저장 없는 보유 남용 불가**
  - `Skins.isFree`는 `skin.experimental == true and EXPERIMENTAL_IDS[id]` 둘 다 볼 때만 true (`src/shared/Skins.luau:407-413`), validate는 목록 밖 `experimental`을 거절(`:479`)하고 실험 스킨은 Basic·가격 없음을 강제(`:487-498`).
  - 코인(`NotForCoins`/`AlreadyOwned`), 이벤트 재화(`NotForTokens`), 로벅스(`AlreadyOwned`, 가짜 결제 포함), 상품 id 역조회(`Skins.forProduct`) 모두 막힘 — QA 테스트 추가.
  - 특별 상품 묶음에 넣으면 `Offers.validate`가 거절 (`robux == nil` → "not a regular robux skin") — QA 테스트 추가. 지금 `Offers.LIST`에도 없음.
  - `ownedSkins`에 쓰는 곳(`ShopLogic.buyWithCoins`·`grantSkin`·`buyWithTokens`, `OfferLogic.applyGrant`)은 모두 위 검사를 먼저 거치거나 상품 목록에서만 와서 콘셉트 id가 들어갈 길이 없음.
- **나중에 id를 뺐을 때**: `EXPERIMENTAL_IDS`에서 빼면 `ProfileLogic.migrate`가 장착값을 `tamago`로 되돌리고(`src/shared/ProfileLogic.luau:170-175`), 카탈로그에서 아예 지우면 `AdminLogic.pickAppearance`가 nil → 기본, `SushiBody.layout`은 모르는 id면 계란초밥. `ownedSkins`에 흔적이 없으니 데이터 정리 불필요 — QA 테스트로 고정.
- **파츠 상한**: 5종 × 4표정 최대 46 ≤ 47.
- **z-fighting·떠 있음**: `LayoutCheck.floating`은 외곽 상자 겹침만 보아 회전한 쐐기(새우 꼬리)는 상자만 닿고 실제로는 떠 있을 수 있음 → QA가 쐐기 꼭짓점과 돔(원기둥 + 양 끝 공) 표면 거리를 직접 계산: 3장 모두 가장 가까운 꼭짓점이 표면 안쪽 0.02~0.04 (붙어 있음, 깊이 묻히지 않음). 테스트로 고정.
- **인형 표정·팔 흔들기**: 클라이언트는 `partJoint(model, "ArmLeft")` 등 이름으로 찾고, 새 토핑 파츠 이름(`Wall`, `Tail*` …)은 클라이언트·서버의 어떤 `FindFirstChild` 이름과도 겹치지 않음 (`VictoryProps`의 `Wall`/`Tail`은 다른 모델 안이라 무관).
- **공용 파일**: 변경 없음 (`Skins`·`SushiBody`·`SushiConceptSample`는 공용 목록 밖). **경제·DataStore 쓰기 변경 없음** (`src/server`, `src/client` diff 0줄).

## 렌더 확인 (커밋된 PNG를 읽음)
- `concept-shrimp-turntable.png`: 흰 돔 + 주황 줄 + 빨간 꼬리 부채, 앞·3/4·뒤·위 모두 또렷. 옆 모습에서 꼬리가 돔 위에 "꽂힌" 느낌 — 계산상 붙어 있음.
- `concept-ikura-turntable.png`: 검은 김 그릇 + 주황 알 2층 + 오이 포인트, 앞에서 얼굴이 가려지지 않음.
- `concept-tamago-expressions.png`: 4표정 모두 연어와 같은 자리, 김 띠·겹 줄 보임.
- `concept-shrimp-gameplay-back.png`: 뒤 카메라에서 새우(흰+빨간 V 꼬리)·연어(김 띠)·연어알(검은 상자)가 바로 구분.
- `concept-tuna-mobile-back.png` (480×270): 참치는 "빨간 돔"으로 읽히고 결은 희미 — 연어와는 김 띠 유무로 구분됨(P3-2 참고).

## 버그
P0·P1·P2 없음.

### [P3-1] 새우 꼬리가 넘어질 때 땅에 묻힐 수 있음 (Studio 확인)
- 재현: concept-shrimp 장착 → 젓가락·잡기로 넘어짐(누운 자세).
- 기대: 꼬리가 크게 땅을 뚫지 않음.
- 실제: 확인 못 함. 꼬리가 외곽을 뒤 1.82·위 2.69로 늘림(다른 콘셉트 ≤ 2.32). 충돌이 없어 판정 영향은 없음.
- 위치: `src/shared/SushiConceptSample.luau` `shrimpTopping` (꼬리 piece). 개발 메모 특이사항 4와 같음.

### [P3-2] 휴대폰 뒤 카메라에서 참치 결이 거의 안 보임
- 재현: `docs/renders/characters/concept-tuna-mobile-back.png`.
- 기대: 참치 = 빨강 + 결.
- 실제: 빨간 돔으로만 읽힘. 연어와는 김 띠 유무로 구분되므로 기능 문제는 아님 — 디자인 판단(스펙 열린 질문과 같이 사용자에게).
- 위치: `SushiConceptSample.luau` `TUNA_MARBLE_W`.

### [P3-3] 연어알 Glass 재질이 Future 조명에서 달라 보일 수 있음
- 렌더러는 Glass를 불투명으로 그림. Studio에서 너무 투명·검게 보이면 `SmoothPlastic` + Reflectance로 (개발 메모 특이사항 3).

### [P3-4] (테스트 도구 한계) `LayoutCheck.floating`은 외곽 상자만 봄
- 회전한 쐐기·원판이 상자만 닿고 실제로는 떠 있어도 못 잡음. 이번 스펙은 QA 테스트가 새우 꼬리를 따로 계산해 막음. 앞으로 회전 파츠를 쓰는 스킨이 늘면 도구 보강 고려 (`tools/render/LayoutCheck.luau:135`).

## 서버 판정 · 보안 체크
- [x] 클라이언트 리모트 인자 검증 — 이번 변경에 리모트 없음. 기존 `EquipSkin`은 `ShopLogic.canEquip`(카탈로그·보유/무료·잠금)으로 검증.
- [x] 판정이 서버에만 — 판정 코드 변경 없음, 스킨은 겉모습만(충돌·쿼리·터치 없음, Massless).
- [x] 맵 상태 `ctx` — 해당 없음.
- [x] Cleanup — 해당 없음 (새 연결·스레드 없음).
- [x] 경제: 가격·상품·코인 경로에서 콘셉트 스킨 획득 불가, 저장 기록 없음.

## 사용자 Studio 확인 체크리스트
1. Play → 로비 탈의실 → **"전체" 탭 맨 아래**: 콘셉트 연어 다음에 **콘셉트 참치초밥 · 새우초밥 · 계란초밥 · 연어알 군함 (테스트)** 4장이 모두 "입기"인지. 관리자 명령 `resetprofile`(Studio) 뒤에도 같은지. "일반"~"전설" 탭에는 안 보여야 함. (AC9)
2. 4장을 하나씩 눌러: 탈의실 미리보기 인형과 내 캐릭터가 그 토핑으로 바뀌는지. (AC9)
3. 혼자 방 만들어 출발(`minPlayersToStart = 1`) → 스킨마다 달리기: **팔이 앞뒤로 흔들리는지, 발이 땅에 닿는지**, 서 있으면 깜빡임·숨쉬기, 점프 착지 찌그러짐. 새우 꼬리가 몸과 같이 움직이는지. (AC10)
4. 젓가락·잡기로 넘어졌을 때 **새우 꼬리·연어알이 땅에 크게 묻히지 않는지**. (P3-1)
5. 떨어져 탈락 → **탈락 인형이 x x + 반창고**, 그 스킨 토핑으로 나오는지. 우승 → **우승 인형·로비 단상이 ^ ^**. (AC11)
6. 디바이스 에뮬레이터(iPhone 등) 뒤 카메라: 참치(빨강, 김 없음)·새우(흰+주황 줄+빨간 꼬리)·계란(노랑+김 띠)·연어알(검은 그릇+주황 알)·연어가 서로 구분되는지. (AC12, P3-2)
7. 연어알 Glass가 Future 조명에서 너무 투명·검게 보이지 않는지. (P3-3)

## 추가한 테스트
- `tests/m5-28-qa.spec.luau` (6개)
  - 새 4종은 코인·이벤트 재화·로벅스(가짜 결제 포함)로 못 사고, 상품 id 역조회로도 안 나옴
  - 특별 상품 묶음에 넣으면 `Offers.validate` 거절, 지금 목록에 없음
  - `EXPERIMENTAL_IDS`에서 빼면 migrate가 `tamago`로, 카탈로그에서 지우면 외형 nil·레이아웃 계란초밥, 저장 흔적 없음
  - 탈의실: "전체" 탭 마지막 4장, 등급 탭에는 없음
  - 새우 꼬리 쐐기 꼭짓점이 실제로 돔 표면에 닿음(−0.3 < 거리 ≤ 0.02), 4표정 모두
  - 5종 팔 관절·위치·크기가 연어와 같음

## 인계 메모
- 브랜치: `m5-28-concept-skins` (QA 커밋을 이 브랜치에 push, main에는 안 넣음)
- 끝난 것: 검증 5단계 통과(1806/0), AC1~AC8 통과, concept-salmon·31종 바이트 동일 재현, QA 테스트 6개, 리포트, 스펙 `qa-passed`.
- 남은 것: 사용자 Studio 확인(위 1~7), 스펙 열린 질문(가격·이름·다음 배치), m5-26 현지화 병합 뒤 새 4종 이름·대사 CSV 키, main 병합 뒤 검증 다시 돌리기.
- 다음 첫 단계: 메인 세션이 `m5-28-concept-skins`를 main에 병합 → 5단계 검증 재실행.
- 막힌 점: 없음.
