# QA — m5-20 기존 맵 장식 품질 패스 (판정 불변)

- 스펙: `docs/specs/m5-20-map-quality-pass.md`
- 검증 커밋: `4192744` (main, m5-20 병합 `99ea0f3` 포함) + QA 테스트 추가 커밋 (브랜치 `m5-qa-quality-skins`)
- 결과: **통과** (P0/P1 없음, P3 5건) → 스펙 상태 `qa-passed`

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 0 errors / 0 warnings |
| `lune run tests` | **1256 passed, 0 failed** (QA 추가 전 1233, m5-20 QA 8개 추가) |
| `luau-lsp analyze ...` (타입 검사) | 종료 코드 0 |

## 판정 불변 확인 (병합 diff)
`git diff 4afea72 99ea0f3 -- src/` 를 한 줄씩 읽었다.
- 바뀐 판정 쪽 파일은 `RotatingBelt.luau`·`SoySwamp.luau`·`ChefBoard.luau`·`HotPlate.luau`의 **장식 부착 부분뿐**: `MapKit.buildDecor` 결과를 돌며 장식 파츠에 `PointLight`·`ParticleEmitter`·태그를 붙인다. 판정 파츠의 크기·위치·CanCollide·태그, 장애물 수치, 시간 제한, 스폰은 그대로.
- `ChefBoard.luau`: `buildKnife`가 `Blade`를 지역 변수로 받아 자식으로 불꽃 에미터를 붙이고(`Blade` 속성은 그대로), `strike`가 칼이 닿은 직후 `spark:Emit(...)` 한 번. 칼 움직임·판정 타이밍 변화 없음.
- `*Layout.luau`·`*Logic.luau`(SoySwampLayout, RamenRapidsLayout/Logic, ChefBoardLogic, HotPlateLogic)는 **diff 없음**. `RamenRapids.luau`·`SkewerShowdown*`도 변경 없음.
- AC7 보호 대상 테스트(`map-art-race`·`map-art-arena`·`map-chef-board`·`map-ramen-rapids`·`round-logic*`)는 기존 블록 수정 없이 추가만 됨(diff에서 `-` 줄 없음 확인). 예외로 `tests/m4-05-qa.spec.luau`의 "조명·파티클 없음" 단언이 "있음·예산 안"으로 바뀌었는데, 이 스펙이 의도적으로 조명을 넣는 것이라 정당하다(QA 동의).

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 장식 validate·600 이하 | 통과 | 기존 `map-art-race`/`map-chef-board`/`map-ramen-rapids` 예산 테스트, `m5-20-qa` "라멘 고명 38개…" |
| AC2 조명·파티클 수·예산 | 통과 | `map-art-race` m5-20 AC2 2건, `map-chef-board` m5-20, `m4-05-qa`, `m5-20-qa` "새 조명·파티클 수치는 은은하게" |
| AC3 라멘 고명 38 | 통과 | `map-ramen-rapids` m5-20 AC3 + `m5-20-qa`: 38개 모두 \|x\|≥30, 국물 수면 바로 위(BROTH_Y~+1), 그릇 안, 시야 상자와 안 겹침 |
| AC4 안개 패널 vs 시야 상자 | 통과 | 맵별 m5-20 AC4 테스트 3건 |
| AC5 반전 샷 5점, 기존 4점 유지 | 통과 | `map-art-race` m5-20 AC5 + `m5-20-qa`: 새 점이 정확히 2·3번째 사이(순서 유지) |
| AC6 MapDecorTags | 통과 | `map-decor-tags.spec`, `m5-20-qa` (접두사 `MapDecor`, 판정 Logic·RoundService는 태그를 모름) |
| AC7 검증 5단계·기존 테스트 무수정 통과 | 통과 | 위 표, diff 확인 |
| AC8 등·파티클·칼 불꽃 Studio | 사용자 확인 필요 | 아래 체크리스트 1~3 |
| AC9 라멘 양옆 밀도 | 사용자 확인 필요 | 체크리스트 4 |
| AC10 안개 패널 분위기·시야 | 사용자 확인 필요 (코드 부분 통과) | `m5-20-qa`: 소개 카메라 직선 경로가 안개 패널을 뚫지 않음(선분-상자 교차), Glass 0.88~0.92, 세 맵 색 다름. 체크리스트 5 |
| AC11 눈 깜빡임·병 흔들림, 복제 없음 | 사용자 확인 필요 (코드 부분 통과) | `m5-20-qa`: 컨트롤러에 리모트·Size·Destroy·CanCollide 없음, 원래 값 기준 오프셋, 제거 추적·거리 컬링, init 등록. 체크리스트 6~7 |
| AC12 반전 샷 자연스러움, 3초 | 사용자 확인 필요 (코드 부분 통과) | `m5-20-qa`: 반전 샷 앞뒤 구간에서 수평 방향이 계속 앞(-Z) — 뒤로 휙 돌지 않음. 길이는 `IntroCameraLogic.sample`이 점 수와 무관한 비율이라 3초 유지. 체크리스트 8 |
| AC13 예산 경고 없음 | 사용자 확인 필요 | 체크리스트 9 (lune 예산 테스트는 통과) |
| AC14 플레이 감각 회귀 없음 | 사용자 확인 필요 | 체크리스트 10 (코드상 판정 diff 없음) |

순수 로직 7개 통과 / 7개, Studio 7개는 사용자 확인 필요.

## 버그
모두 P3(겉모습·다듬기). 개발 반려 사유 아님.

### [P3] B1 손님 눈이 깜빡일 때 눈 반짝임(FaceEyeShine)은 그대로 떠 있다
- 재현: rotating-belt에서 카운터 너머 손님 얼굴을 본다 → 눈이 깜빡이는 0.15초 동안.
- 기대: 눈 전체(검은 눈 + 흰 반짝임)가 같이 감긴다.
- 실제: `FaceEye`만 `Transparency = 1`이 되고, 바로 앞의 흰 공 `FaceEyeShine`(0.8)은 태그가 없어 그대로 보인다 → 빈 피부 위에 흰 점이 잠깐 떠 있다.
- 위치: `src/shared/maps/RotatingBeltArt.luau:255-263`(FaceEyeShine, 태그 없음), `src/client/fx/MapDecorFxController.luau:110`
- 제안: FaceEyeShine에도 같은 태그를 달거나(같은 위상을 쓰려면 눈과 짝지어 처리), Studio에서 눈에 띄지 않으면 그대로 둠.

### [P3] B2 라멘 양옆 안개 패널이 그릇 밖으로 삐져나온다
- 재현: ramen-rapids 소개 플라이스루나 높은 곳에서 그릇 양옆을 본다.
- 기대: 안개 패널이 그릇 안쪽(또는 완전히 바깥)에 있다.
- 실제: 패널이 x=±130, z −310~+10(길이 320), y −60~140. 그릇 벽(반지름 178, 중심 z −150)은 x=±130에서 z≈−28/−272이라, 패널 양 끝 약 38 studs가 그릇 벽을 뚫고 밖으로 나가고, 테두리(y 16) 위로 124 studs 솟는다. 위에서 보면 그릇 윤곽 밖으로 유리판 모서리가 보일 수 있다.
- 위치: `src/shared/maps/RamenRapidsArt.luau:235-251` (`addFogPanels`, 패널 248-249줄)
- 제안: 패널 z 길이를 약 240 이하로 줄이거나(벽 안쪽), Studio에서 거슬리지 않으면 둠. (도마 맵도 z=+150 패널은 주방 벽(z=110, 꼭대기 y=60) 뒤라 위쪽 띠만 보인다 — 같이 확인.)

### [P3] B3 간장 늪 반전 샷이 정확히 수직 아래를 본다
- 재현: soy-swamp 소개 플라이스루의 세 번째 경유점.
- 기대: 부드럽게 내려다본다.
- 실제: 경유점 `pos (0,36,-88)`, `lookAt (0,12,-88)` — 방향이 정확히 (0,−1,0)이라 `CFrame.lookAt`의 위쪽 벡터와 평행한 순간이 생긴다. 앞뒤 구간의 수평 방향은 계속 앞(-Z)이라(테스트로 확인) 큰 회전은 없겠지만, 그 한 프레임에 화면이 굴러(roll) 보일 수 있다.
- 위치: `src/shared/maps/SoySwampArt.luau:325`
- 제안: lookAt z를 −90 정도로 조금 앞으로(수평 성분을 남김). Studio AC12에서 튐이 보이면 고침.

### [P3] B4 깜빡이는 중에 카메라가 멀어지면 눈이 감긴 채로 남는다
- 재현: 눈이 감긴 0.15초 사이 카메라가 250 studs 밖으로 나간다(관전 전환·리스폰 등).
- 실제: `stepEyes`가 먼 파츠를 복원 전에 `continue`로 건너뛴다 → 다시 가까이 올 때까지 눈이 사라진 상태. 가까이 오면 바로 복원되므로 플레이어가 보는 일은 거의 없다.
- 위치: `src/client/fx/MapDecorFxController.luau:99-101`

### [P3] B5 안개 패널(Glass 재질) 뒤의 투명 물체·파티클이 안 보일 수 있다
- Roblox의 Glass 재질은 그 뒤에 있는 반투명 파츠·파티클을 그리지 않는다. 라멘 국물 수면(Glass, 투명 0.2)·김·파티클이 패널 너머(x>130)에 있으면 패널을 통해 볼 때 빠져 보일 수 있다. Studio AC10에서 확인, 문제면 재질을 `SmoothPlastic` + 같은 투명도로.
- 위치: 세 맵 `addFogPanels`의 `material = "Glass"`

### 참고 (버그 아님)
- `ChefBoard.luau:500` 불꽃 개수에 `ctx.rng`를 써서, 같은 시드일 때 다음 칼 줄 선택(`Logic.pickLine(…, ctx.rng)`)의 난수 순서가 m5-20 전과 달라진다. 무작위성·공정성에는 영향 없고 그 순서에 기대는 테스트도 없다. 깔끔하게 하려면 불꽃은 `math.random`/별도 `Random`.
- `SoyGlint`·`SoyBubble` 앵커는 개발 메모의 "투명 앵커"와 달리 불투명(간장색, 0.4 크기)이다. 크기가 작아 거의 안 보임.

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자 검증 — 새 리모트 없음. 클라이언트 컨트롤러는 리모트를 쓰지 않음(테스트로 확인).
- [x] 통과·탈락·순위 판정이 서버에만 있다 — 판정 코드 변경 없음. 클라이언트 애니메이션은 장식(충돌·쿼리·터치 없음)의 로컬 Transparency/CFrame만 바꾸고 복제되지 않음.
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — 새 상태 없음(불꽃 에미터는 칼 파츠 자식, `start` 지역 `blade`에서 찾음).
- [x] 정리 — 조명·파티클은 맵 모델 자식이라 모델과 함께 사라짐. 클라이언트 표는 `GetInstanceRemovedSignal`과 `Parent == nil` 검사로 지움. 컨트롤러 연결은 클라이언트 수명 동안 하나라 정리 불필요.

## 사용자 Studio 확인 체크리스트
준비: `src/shared/Config.luau`의 `DEBUG.forceMapPlan = { "rotating-belt", "soy-swamp", "chef-board", "ramen-rapids", "hot-plate" }` → Play Solo. (커밋 전에 `nil`로 되돌리기)
1. **회전 벨트(AC8)**: 머리 위 종이 등 3개 아래 바닥에 주황 빛이 번진다. 병목 맨 앞 간장 종지(좌우)에서 작은 반짝임이 천천히 올라온다.
2. **간장 늪(AC8)**: 와사비 산 꼭대기 흰 밥알 2곳이 연두빛으로 주변을 물들인다. 간장 웅덩이 3곳에서 갈색 보글거림이 천천히 올라온다.
3. **셰프의 도마(AC8)**: 머리 위 등 3개가 빛나고 가운데가 가장 넓게 비춘다. 칼이 도마를 내려찍는 순간 불꽃이 **한 번만** 튄다(계속 나오지 않음).
4. **라멘 급류(AC9)**: 급류 양옆에 짙은 녹색 다시마·검은 통깨·흰 젓가락 받침이 떠 있고 코스는 가리지 않는다.
5. **안개(AC10, B2·B5)**: 간장 늪(갈색)·라멘(금빛)·도마(청회색) 바깥 멀리 옅은 색판이 보이고 세 맵 분위기가 다르다. 확인할 것: 라멘 그릇 윤곽 밖으로 유리판 모서리가 삐져나와 보이는지(B2), 패널 너머 국물·파티클이 사라져 보이는지(B5), 도마 맵 주방 벽 위로 패널 띠가 어색한지.
6. **눈 깜빡임(AC11, B1)**: 회전 벨트 카운터 너머 손님 얼굴 3개의 눈이 2~4초마다 따로따로 깜빡인다. 깜빡일 때 흰 반짝임 점만 남아 떠 보이는지(B1) 본다.
7. **간장병(AC11)**: 철판 맵 선반 위 병 3개가 천천히 좌우로 흔들린다. Test → Clients and Servers(2명)로 서버 Output에 경고가 없는지, 서버 화면(서버 뷰)에서는 병이 움직이지 않는지(로컬 전용) 본다.
8. **반전 샷(AC12, B3)**: 회전 벨트·간장 늪 소개에서 병목/와사비 산 위 내려다보는 샷이 끼어든다. 카메라가 등·벽을 뚫거나, 간장 늪 샷에서 화면이 순간 굴러(roll) 보이는지(B3) 본다. 소개 전체 길이는 그대로 약 3초.
9. **예산 경고(AC13)**: Output에 `[MapKit] decor has` 또는 `[MapKit] decor skipped` 경고가 없다.
10. **판정 회귀(AC14)**: 다섯 맵 모두 낙하 탈락·결승선 통과·시간 종료가 전과 같다.

## 추가한 테스트
- `tests/m5-20-qa.spec.luau` (8개)
  - 반전 샷이 2·3번째 점 사이에 들어감(순서 유지), 더 높고 내려다봄
  - 반전 샷 앞뒤 구간에서 카메라 수평 방향이 계속 앞(-Z) — 휙 돌지 않음
  - 소개 카메라 직선 경로가 안개 패널을 뚫지 않음 (간장 늪·라멘·도마, 선분-상자 교차)
  - 안개 패널 Glass·투명도 0.88~0.92·세 맵 색 다름
  - 라멘 고명 38개 위치(양옆·수면·그릇 안·시야 상자 밖)와 예산
  - 애니메이션 대상 수(눈 6·병 3), 태그 접두사, 판정 Logic·RoundService가 태그를 모름
  - `MapDecorFxController` 로컬 전용(리모트·Size·Destroy·CanCollide 없음, 원래 값 기준, 제거 추적·거리 컬링, 등록)
  - 조명·파티클 수치(스펙 기본값, 칼 불꽃 상시 아님)

## 인계 메모 (2026-10-13)
- 브랜치: `m5-qa-quality-skins` (worktree `agent-ab46a7b4445ffb810`, main `4192744` 위)
- 끝난 것: 자동 검증 5단계, 순수 AC1~AC7 확인, 병합 diff로 판정 불변 확인, QA 테스트 8개 추가, 리포트, 스펙 상태 `qa-passed`.
- 남은 것: 사용자 Studio 확인(AC8~AC14, 위 체크리스트). P3 B1~B5는 Studio에서 거슬리면 developer가 수정.
- 다음에 할 첫 단계: docs-writer가 CHANGELOG·DEV-SETUP(Studio 확인 항목)에 반영하고 `done`.
- 막힌 점: 없음.
