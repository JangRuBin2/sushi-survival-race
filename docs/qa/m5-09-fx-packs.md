# QA — m5-09 연출 팩 비주얼: 고양이 손님(탈락)·불꽃놀이(우승)

- 스펙: `docs/specs/m5-09-fx-packs.md`
- 검증 커밋: `a6c9536` (브랜치 `m5-09-fx`, origin/main `1ddf47e` 병합 위)
- 결과: **통과** (P0/P1/P2 없음, P3 2건 + 참고 2건)
- 메인 세션 결정 반영: D4(불꽃을 "부두 위 하늘" 대신 인형 뒤 바다 위 낮은 곳 — 고정 카메라에서 더 잘 보임) 수용, D5(고양이 발이 젓가락을 쥠)·D6(ChefHand는 앞발 박자 뒤 CatMeow)·D7(하늘색 대신 산호색) 수용.

## 자동 검증 (2026-10-13, 로컬 Windows)
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 통과 (0 errors, 0 warnings) |
| `lune run tests` | 통과 — **1440 passed, 0 failed** (병합 결과 1428 + QA 12) |
| `luau-lsp analyze ... src` (타입 검사) | 통과 (끝 코드 0) |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 skinFor/extraFor | 통과 | `elimination-cutscene` "m5-09 AC1", `victory-cutscene` "m5-09 AC1". QA: 대소문자·공백 다른 값, 표·숫자·불린, 모든 FxCatalog 연출이 다른 slot에서 기본 (`m5-09-qa` "이상한 속성 값은 모두 기본", "자기 slot에서만 반응") |
| AC2 고양이 대사 | 통과 | `elimination-cutscene` "m5-09 AC2" 2개 (결승 ChefHand 포함, 원본 목록 보존). 기존 대사 테스트·`m3-03-qa` 그대로 통과 |
| AC3 고양이 박자 | 통과 | `elimination-cutscene` "m5-09 AC3". QA: 길이 0.5~9초에서도 CatMeow 한 번·오름차순·길이 안·모든 cue가 SfxCues에 있음 |
| AC4 fireworksTimeline(6) | 통과 | `victory-cutscene` "m5-09 AC4". QA: 설정 길이(6초)에서 같은 이미터 재사용 간격 1.296초 > 불티 수명 최대 1.2초(이미 날아간 불티 색이 바뀌지 않음), 마지막 섬광이 연출 안에서 끝, `Sfx` 같은 cue 제한 0.05초 < 0.432초 간격 |
| AC5 검증 5단계 | 통과 | 위 표 |
| AC6 세 변형 고양이 모습·대사 | 사용자 확인 필요 | 코드: `EliminationCutsceneController` 세 변형이 `cat`일 때만 소품·pose 교체, 흐름·`s()` 박자 그대로 |
| AC7 다른 사람 화면에도 고양이 | 사용자 확인 필요 | 코드: 모든 클라이언트가 **탈락한 사람**(`GetPlayerByUserId(result.userId)`)의 `EliminationFx`를 읽음 (`src/client/fx/EliminationCutsceneController.luau:326,335`). QA 정적 테스트로 고정 |
| AC8 불꽃 6번·같은 장면 | 사용자 확인 필요 | 코드: 우승자(`GetPlayerByUserId(winnerUserId)`)의 `VictoryFx` (`src/client/fx/VictoryCutsceneController.luau:81-84`), 박자는 순수 로직이라 모든 클라이언트 같음. 위치는 D4대로 바다 위 낮은 곳 |
| AC9 길이 그대로·소품 남지 않음 | 일부 확인 / 사용자 확인 필요 | 길이: `Config.Match` 값과 박자 로직을 팩이 바꾸지 않음(QA 테스트). 정리: 고양이 소품은 연출 Model(`cleanup:add`) 밑, 불꽃 소품은 `props.model` 밑이라 장면째 지워짐(QA Shims 테스트: `rig:IsDescendantOf(props.model)`). Explorer 확인은 Studio |
| AC10 동시 6개 프레임 | 사용자 확인 필요 | 한도 계산: 고양이 Chopsticks 소품 39파츠(기본 19) × 6 = 234파츠를 매 프레임 CFrame — 파티클·조명 없음(QA 테스트). 체감은 친구 테스트 |

## 버그
### [P3] B1 첫 불꽃이 다이빙 옆 카메라 때라 화면 밖에서 터짐
- 재현: 불꽃놀이를 입은 사람이 우승 → 풍덩 직후(+0.05초) 첫 불꽃.
- 기대: 6번 모두 터지는 순간이 보임.
- 실제: 첫 불꽃은 카메라가 아직 옆(다이빙)이라 터지는 순간이 안 보이고, 1초 넘게 남는 불티만 카메라가 돌아온 뒤 보임. 스펙 제약(풍덩부터, 간격 ≥ 0.4, 5.7초까지 6번) 안에서는 피하기 어려움(개발 메모에 적힘). 체감상 5번처럼 보일 수 있음.
- 위치: `src/shared/VictoryCutsceneLogic.luau` `FIREWORK_LEAD` / `fireworksTimeline`
- 제안: 사용자가 Studio에서 보고 신경 쓰이면 planner가 "박수 카메라 전환 뒤부터 6번"으로 스펙 문구를 바꾸는 쪽.

### [P3] B2 분리 모드 매치 서버에서 프로필이 늦게 오면 첫 탈락·우승이 기본 연출
- 재현: (m5-08 병합 뒤, 분리 플레이스) 매치 서버 도착 직후 프로필 로드가 늦은 상태에서 탈락/우승.
- 기대: 입은 연출.
- 실제: 속성은 m5-08 `OfferService`가 `DataService.onLoaded`에서 달아서(`origin/m5-08-offers:src/server/OfferService.luau:309-311`), 그 전에 재생된 연출은 기본. m4-13 N2(늦은 프로필로 외형이 바뀜)와 같은 종류. 첫 라운드 소개가 있어서 실제로는 드묾.
- 위치: 계약 지점 `src/client/fx/EliminationCutsceneController.luau:335`, `src/client/fx/VictoryCutsceneController.luau:83`
- 제안: 고칠 필요 없음(보류). 진행·판정 차이 없음.

### 참고 (버그 아님)
- N1: 고양이 Chopsticks 소품이 파츠 한도(기본 + 20)에 딱 맞음 — 고양이 얼굴에 파츠를 더하려면 다른 걸 빼야 함(개발 메모와 같음). QA 테스트 "파츠 수 = 기본 + 20 이하"가 지킴.
- N2: 스펙 문구 "같은 소리 0.4초 간격 제한은 Sfx 규칙 그대로" — 실제 `Sfx` 규칙은 0.05초(`src/client/Sfx.luau:33`). 불꽃 간격 0.432초라 어느 쪽이든 매번 울림. 스펙 문구만 다름(docs-writer/planner가 정리할 때 참고).

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 이 스펙은 리모트를 추가하지 않음. 클라이언트 연출 4파일에 `FireServer`/`InvokeServer`/Player 속성 쓰기 없음(QA 정적 테스트).
- [x] 통과·탈락·순위 판정이 서버에만 있다 — 서버 코드는 바뀌지 않음, 연출 로직(`EliminationCutsceneLogic`·`VictoryCutsceneLogic.extraFor`)을 서버가 쓰지 않음(QA 정적 테스트). 연출 길이 `Config.Match` 그대로.
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — 해당 없음(맵 변경 없음). 연출 상태는 연출마다 지역 변수(`fired`·`launched`·`cat`).
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다 — 새 연결·스레드 없음(기존 RenderStepped 하나 안에서 갱신). 고양이 소품은 연출 Model 밑(`cleanup:add`), 불꽃 소품(이미터 3·조명 2·로켓 2·섬광 1)은 장면 Model 밑. pose/burst를 여러 번 돌려도 인스턴스 수가 늘지 않음(QA Shims 테스트). 모르는 속성 값·나간 사람은 기본(nil 안전).
- [x] 겉모습만 (GDD 9.1) — 길이·흐름·카메라·순서 그대로. 소품은 Anchored·충돌·쿼리·터치 없음(QA 테스트).
- [x] 모바일 — 고양이 소품에 파티클·조명·소리 인스턴스 없음, 불꽃은 이미터 3·조명 2(그림자 꺼짐), 한 불꽃당 불티 108(큰 불꽃 175).

## 사용자 Studio 확인 체크리스트
준비: `Config.DEBUG.forceMapPlan = { "rotating-belt", "hot-plate", "skewer-showdown" }` (커밋하지 말 것). m5-08 병합 전이면 Test 시작 뒤 Command Bar를 **Server**로 바꾸고:
```lua
for _, p in game.Players:GetPlayers() do p:SetAttribute("EliminationFx", "cat-customer") p:SetAttribute("VictoryFx", "fireworks") end
```
(m5-08 병합 뒤에는 상점에서 가짜 결제로 사서 입어도 됨.)
1. AC6 (혼자 Play): 1라운드(회전 벨트)에서 일부러 떨어지기 → 젓가락 위쪽을 주황 고양이 발이 쥐고 집어 간장에 찍은 뒤, 고양이 얼굴(세모 귀·수염)이 "냠!" 하고 오물오물. 말풍선이 "냥~ 신선하다냥!"/"생선은 역시 최고냥"/"한 접시 더 달라냥!" 중 하나.
2. AC6: 강제 플랜을 `{ "hot-plate", ... }`처럼 바꿔 Survival에서 떨어지기 → 아래에서 고양이 입이 벌어져 받아먹음. 결승(꼬치)에서 떨어지기 → 줄무늬 고양이 앞발이 내려와 발톱을 내밀며 움켜쥐고 올라감.
3. AC7 (Test → Clients and Servers, 2명): Player1에만 `EliminationFx`를 달고 Player1이 떨어질 때 **Player2 화면**에도 고양이, Player2가 떨어질 때는 두 화면 모두 기존 젓가락·입·손.
4. AC8 (2명): `VictoryFx`를 단 사람이 우승 → 풍덩 뒤 인형 뒤 바다 위에서 불꽃이 좌우 번갈아(마지막은 가운데 큰 금색) 터지고, 로켓 꼬리·섬광·물빛이 보임. 두 화면이 같은지. 첫 불꽃이 다이빙 카메라 때라 안 보여도 B1(알려진 것). 안 단 사람 우승은 기존 그대로.
5. AC9: 탈락 3초 뒤 관전으로, 우승 단계 10초 그대로. 끝난 뒤 Explorer에서 `Workspace.EliminationCutscenes`가 비어 있고 `VictoryCutscene` 모델(안의 `Fireworks`)이 없는지. 매치를 2~3번 연달아 해도 남는 것 없는지.
6. AC10 (4명 이상, 모두 고양이): 한꺼번에 떨어지기 → 프레임 체감(가능하면 휴대폰 에뮬레이터로도).
7. 속성 값을 `"아무거나"`나 `"fireworks"`(탈락 쪽)로 달아 보기 → 기본 연출, 출력 창 에러 없음.
8. 소리: `CatMeow`·`Fireworks`는 지금 무음(USER-TODO A2). id를 넣으면 고양이는 "냠!" 직후 한 번, 불꽃은 터질 때마다.

## 추가한 테스트
`tests/m5-09-qa.spec.luau` (12개)
- 이상한 속성 값(대소문자·공백·표·숫자·불린) → 기본, FxCatalog 연출이 다른 slot에서 기본, 카탈로그 id·slot 계약
- 옛 호출(인자 생략·nil·"Default") = 기존 결과, 길이 nil = 3초
- 고양이 박자: 여러 길이에서 CatMeow 한 번·순서·cue 유효
- 불꽃: 간격 ≥ 0.4, 이미터 재사용 간격 > 불티 수명, 마지막 섬광이 길이 안, Sfx 같은 cue 제한보다 김
- `fireworks()`가 새 표를 돌려줌(자리 원본 보호)
- (Shims, `tools/render/Shims`로 실제 소품 생성) 고양이 소품 파츠 수 = 기본 + 20 이하, 모든 파츠 Anchored·충돌/쿼리/터치 없음, 파티클·조명·소리·스크립트 없음
- (Shims) 고양이 pose를 90프레임 돌려도 인스턴스 수 그대로, 범위 밖 값도 에러 없음
- (Shims) 불꽃 소품: 이미터 3·조명 2(그림자 꺼짐)·파츠 4 이하, 장면 Model 밑, 6번 터뜨려도 인스턴스 수 그대로, 끄면 조명 꺼지고 섬광 숨김
- 정적: 연출 클라이언트 4파일에 리모트 보내기·Player 속성 쓰기·판정/경제 모듈 없음, 속성을 탈락한 사람·우승자 Player에서 한 곳에서만 읽음, 서버가 연출 로직을 안 씀, 연출 길이 설정 그대로

## 인계 메모
- 브랜치: `m5-09-fx` (QA worktree에서 origin/main + origin/m5-09-fx 병합 후 커밋, `git push origin HEAD:m5-09-fx`)
- 끝난 것: 자동 검증 5단계 전부 통과, AC1~AC5 통과, 코드 리뷰(속성 읽기·정리·한도·판정 영향 없음), QA 테스트 12개, 스펙 상태 `qa-passed`.
- 남은 것: 사용자 Studio 확인 AC6~AC10(위 체크리스트), 소리 id(A2), D4 불꽃 위치 체감 확인. m5-08 병합 뒤 속성 달기 경로로 한 번 더 AC7·AC8.
- 다음에 할 첫 단계: 메인 세션이 `m5-09-fx`를 main에 병합하고 검증을 다시 돌림(m5-08과 같은 `Attributes` 줄을 공유 — 이미 main에 있어서 충돌 없을 것).
- 막힌 점: 없음.
