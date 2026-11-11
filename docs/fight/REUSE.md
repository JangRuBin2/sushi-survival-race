# 스시 파이트 — 스시런에서 살릴 것 (재활용 표)

- 작성: 2026-11-11, 브랜치 `sushi-fight` (기준 커밋 `a85fd669`)
- 표기: **그대로** = 코드 수정 없이 씀 · **고쳐서** = 파이트용으로 바꾸거나 감쌈 · **새로** = 파이트 전용으로 새로 만듦
- 스시런 코드는 이 브랜치에서도 **지우거나 옮기지 않아요**. 파이트 코드는 `fight/` 하위 폴더에 따로 두고 스시런 모듈을 require해요. 그래야 `main`과 합칠 때 스시런이 깨지지 않아요.

## 1. 캐릭터 · 스킨

| 스시런 | 파이트에서 | 비고 |
|---|---|---|
| `shared/SushiBody`·`SushiConceptSample`·`ConceptMackerel`·`SushiPose`·`PartMath` | 그대로 | 몸·표정. 히트박스 하나 원칙 유지 |
| `shared/Skins` (41종) | 그대로 | 능력 없음, 겉모습만 |
| `server/AppearanceService` | 그대로 | 외형 입히기 출입구 하나 |
| `client/fx/CharacterFxController`·`FishRig`·`DollAnimator` | 그대로 | 숨쉬기·깜빡임·고등어 팔딱 |
| `shared/CharacterAnimLogic` | 고쳐서 | 맞음·경직 자세 추가(표정 Hurt·Angry 활용) |
| 간장 색 진하기 | 새로 | `FightLogic.soyTint` → 클라이언트가 파츠 색에 섞음 |

## 2. 조작

| 스시런 | 파이트에서 | 비고 |
|---|---|---|
| `shared/DiveLogic` + `client/input/Dive*` | 고쳐서 → 박치기 | 이동감·쿨다운은 그대로, 타격 판정은 서버 파이트 로직 |
| `shared/GrabLogic`·`GrabInputLogic` + `server/GrabService` | 고쳐서 → 잡고 던지기 | 대상 고르기(`pickTarget`)·쿨다운·면역 장부 재사용 |
| `shared/TouchLayoutLogic` + `client/input/TouchLayoutController`·`ui/TouchLayoutEditor` | 고쳐서 | 버튼 3 → 4개(때리기) |
| `shared/GamepadNavLogic` + `ui/GamepadNav` | 그대로 | 창 이동. 때리기 = B 버튼과 겹침 → 라운드 중 잠금 규칙 그대로 |
| `shared/MoveExempt`·`MovementGuardLogic` + `server/MovementGuardService` | 그대로 | 넉백 때 `MoveExempt.mark` |
| `client/input/IceController` | 그대로 | 간장 웅덩이 미끄러짐에 재사용 가능 |
| 때리기 | 새로 | 판정은 `FightLogic.hit` |

## 3. 맵 · 아레나

| 스시런 | 파이트에서 | 비고 |
|---|---|---|
| `shared/maps/MapTypes` (`build`·`overtime`) | 그대로 | `build`로 아레나 생성, `overtime`을 서든데스 붕괴로 |
| 결승 6종 `SkewerShowdown`·`IkuraBombs`·`TugOfWarPlatform`·`ClawMachinePrize`·`TeaGarden`·`OnsenClaw` | 그대로(build) | MVP는 꼬치·연어알·찻잎. `start`는 안 쓰고 파이트 서버가 판정 |
| Survival `ChefBoard`·`HotPlate`·`TempuraPot`·`CatCafeShelves`·`RotatingBelt` | 고쳐서 | 위험 요소 → 게이지 올리기(2차) |
| `LazySusan` (대형 Survival) | 고쳐서 | 대인원 난투(3차) |
| `MapKit`·`MapKitLogic`·`MapKitShapes`·`MapLighting`·`MapSfx`·`MapDecorAnimLogic` | 그대로 | 장식·조명·예산 |
| `tools/render-map.luau` | 그대로 | 아레나 렌더 확인 |
| `IkuraBombsLogic` | 고쳐서 | 연어알 아이템 폭발 반경·넉백 |

## 4. 매치 흐름 · 연출

| 스시런 | 파이트에서 | 비고 |
|---|---|---|
| `server/RoomService`·`RoomDirectory`·`shared/RoomLogic` | 그대로 | 방 만들기·인원·코드 |
| `server/PlaceService`·`shared/PlaceRole`·`PlacePayload` | 고쳐서 | `"Fight"` 역할 추가(F1-02, 결정 Q1) |
| `server/RoundService`·`shared/RoundLogic`·`Rules` | 참고만 | 라운드 구조가 달라서 `FightService`·`FightLogic`을 새로 |
| `server/EliminationService` + `client/fx/EliminationCutscene*` | 고쳐서 | 장외 KO = 젓가락 집기 연출 |
| `client/fx/Intro*`·`shared/IntroLayout`·`IntroCameraLogic` | 그대로 | 아레나 소개 플라이스루 |
| `client/fx/VictoryCutscene*`·`shared/VictoryCutsceneLogic`·`PodiumLogic` | 그대로 | 우승 연출 |
| `shared/SpectateLogic` + `client/ui/Spectate*` | 그대로 | 목숨 0 → 관전 |
| `shared/SfxCues`·`SfxLibrary` + `client/Sfx` | 고쳐서 | 때리기·박치기·장외 소리 추가 |

## 5. 경제 · 운영

| 스시런 | 파이트에서 | 비고 |
|---|---|---|
| `server/DataService`·`shared/ProfileSchema`(v3)·`ProfileLogic` | 그대로 | 같은 유니버스면 프로필 공유(결정 Q1) |
| `server/RewardService`·`shared/RewardLogic` | 고쳐서 | 파이트 보상 사유 추가(참가·KO·우승) |
| `ShopService`·`RobuxShopService`·`OfferService`·`DrawLogic`·`CodeService`·`Seasons` | 그대로 | 탈의실·상점·🎫 뽑기·코드·시즌 |
| `AdminService`·`AdminCommands`·`AdminLogic` | 고쳐서 | `fight` 명령(강제 시작·게이지 설정) 추가 |
| `shared/Localization/Strings.csv`·`LocalizeLogic`·`client/Loc`·`WorldText` | 그대로 | 파이트 문구는 `fight.*` 키로 추가 |
| `client/ui/UiScaleController`·콘솔 안전 여백 | 그대로 | |

## 6. 도구 · 문서 · 테스트

| 스시런 | 파이트에서 |
|---|---|
| `rokit.toml` 도구·검증 5단계 | 그대로 |
| `tests/lib/Test`·`RobloxRequire`·`LargeMapHarness` | 그대로 |
| `.claude/agents/` 4역할·`docs/WORKFLOW.md`·스펙 템플릿 | 그대로 (스펙 id는 `f<마일스톤>-<번호>`) |
| 레퍼런스 문서·콘셉트 시트 | [`references/`](references/README.md)로 복사 |
