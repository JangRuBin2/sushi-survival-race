# QA — m5-33 맵 3차 배치 기반 (껍데기 6개 + 등록 + 소리·파티클 + 풀 개수 테스트)

- 스펙: `docs/specs/m5-33-map-batch-3-foundation.md`
- 검증 커밋: `55e578c`(구현) · `0fa51c8`(문서), 브랜치 `main`
- 결과: **통과** (P0/P1 없음, P3 2건) → 스펙 `qa-passed`

## 자동 검증 (2026-10-15, Windows, QA 테스트 추가 뒤 다시 돌림)
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 성공 (끝 코드 0) |
| `stylua --check src tests tools` | 통과 (끝 코드 0) |
| `selene src` | 0 errors, 0 warnings |
| `lune run tests` | **2004 passed, 0 failed** (개발 1999 + QA 5), 끝 코드 0 |
| `luau-lsp analyze … src` | 끝 코드 0 |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `m5-33-batch3` AC1 — validate·id·kind·displayName·rule이 스펙 표·GDD §5.3(221~226줄)과 글자 그대로, Final 2개 `overtime` 함수 |
| AC2 | 통과 | `m5-33-batch3` AC2 — `allInfos` 21, `infos` 15(= 기대값 계산), 중복 id 없음, 껍데기 6개 `infos`에 없음 |
| AC3 | 통과 | `m5-33-batch3` AC3. 서버 경로도 확인: `MatchService.luau:201` `Rules.resolveForcedPlan(ids, Maps.allInfos())`, 실행은 `MatchService.luau:296` `Maps.get(mapInfo.id)`, 관리자 `plan`도 `AdminCommands.luau:111`에서 `allInfos` |
| AC4 | 통과 | `m5-33-batch3` AC4 — 1,000번, 랜덤 판은 `MatchService.luau:267` `Maps.infos()`라 `inPool = false`가 빠짐 |
| AC5 | 통과 | `m5-33-batch3` AC5 + QA "Race 결승"(결승선도 바닥 위, 충돌 없음) |
| AC6 | 통과 | `m5-33-batch3` AC6 + `camera-priority` AC3(확정 목록 = `SfxCues.all()` 전체 개수, 중복 없음). 볼륨 14개 스펙 표와 직접 대조 일치, `FishFlop`·`FishSplash`(m5-32) 그대로 |
| AC7 | 통과 | 단위: `m5-33-batch3` AC7. **QA가 직접 재현**: 저장소 복사본에서 6개 `inPool = false` 줄을 모두 지우고 `lune run tests` → 2003 passed, 1 failed — 실패 1개는 `m5-10-qa`의 "CodeList가 git에 안 올라감" 검사로, 복사본에 `.git`이 없어서 생긴 환경 문제(진짜 저장소에서는 통과). 풀 개수·목록 관련 실패 0 |
| AC8 | 통과 | 위 자동 검증 표 (QA가 직접 실행) |
| AC9 | 사용자 확인 필요 | 아래 체크리스트 1~2 |
| AC10 | 사용자 확인 필요 | 아래 체크리스트 3 (선택) |

### 결정 기록 확인
- **D5 (현지화 CSV 생략)**: 맞음. `main`에 `src/shared/Localization`이 없고 m5-26은 `origin/m5-26-i18n`·`m5-26-i18n-p2`와 worktree에만 있음. 스펙 범위 7은 "m5-26이 먼저 들어가 있으면"이라는 조건부라 할 일 없음. m5-26 병합 때 21개 맵 `name|rule` 수집이 필요하다는 점은 m5-26 쪽 일(병합 뒤 검증에서 걸림).
- **D6 (새 Race 껍데기 바닥 뒤로 10)**: 맞음. GDD·스펙은 껍데기 지오메트리 수치를 정하지 않고, AC5 "24개 모두 판정 바닥 위"(CLAUDE.md 맵 규칙)를 지키려는 변경. 바닥 z +20 ~ −170, 스폰 z 0~15, 결승선 z −160(바닥 위, QA 테스트로 확인). 기존 맵 파일 변경 없음.

### 요청 확인 항목
- **inPool = false**: 6개 모두 `inPool = false`, 랜덤 판(`Maps.infos()`)에 없음(AC2·AC4).
- **강제 플랜·Maps.get 흐름**: 위 AC3 근거. 껍데기의 `start`는 Heartbeat 연결 하나를 `ctx.cleanup`에 넣고 `ctx.isActive()`로 끝난 라운드에서는 판정하지 않음. 낙하선은 origin 로컬 Y(아레나 슬롯 높이 300에서도 맞음), Race 통과는 로컬 −Z ≥ 160이고 통과로 라운드가 끝나면 그 틱을 멈춤 — QA 테스트로 확인.
- **Final 연장전 훅**: `task.wait` 없음, `task.delay(collapseDuration)` 하나를 `ctx.cleanup`에 넣고 바로 반환, 시간이 되면 유일한 판정 충돌 파츠 `Plate`가 `CanCollide = false`·`Transparency = 1` → 판정 충돌 파츠 0개(매달릴 턱·높은 곳 없음, 스폰·결승선은 원래 충돌 없음, 장식은 빈 목록). 라운드가 이미 끝났으면 손대지 않고, 같은 맵을 도는 다른 방 모델은 그대로(`ctx.model`만 봄). QA 테스트로 확인.
- **목록 기준으로 바뀐 기존 테스트 8곳 — 약해졌나**: 원래 잡던 회귀는 그대로 잡음.
  - `maps.spec` / `m5-03` AC2: `15 + 풀에 든 배치 3`. 기존 15개 중 하나가 풀에서 빠지면 개수가 1 모자라 실패(그대로).
  - `m4-foundation` AC6: 기존 15개 종류별 목록은 정확히 고정한 채 배치 3 중 풀에 든 것만 더함. 배치 3 맵의 실제 `kind`가 `Batch3.KIND`와 다르면 목록이 어긋나 실패(오히려 하나 더 잡음).
  - `m2-01-qa`: 결승 후보에 풀에 든 배치 3 Final만 더함 — Race·Survival 맵이 결승에 오면 여전히 실패.
  - `m5-03` AC1·`m5-13-qa`: `allInfos` 21 고정, 배치 3 밖 맵은 여전히 "풀에 있음" 검사.
  - `camera-priority` AC3: 목록 추가뿐, 전체 개수·중복 검사 그대로.
  - 약해진 곳 2군데는 아래 P3-1·P3-2(설계상 의도된 trade-off, 반려 사유 아님).
- **SfxCues·SfxLibrary·MapFxPresets**: cue 14개 이름·볼륨이 스펙 표와 일치, 모두 `sfx(nil, …)` 무음, 이름 중복 없음(전체 cue에서 중복 0), `FishFlop`·`FishSplash` 보존. 프리셋 `SoapFoam`(흰→하늘, 투명도 0.4→1, 크기 0.6→1.6, 위로, Rate 3)·`Stardust`(흰→연보라, 0.15~0.4, Speed 0.2~0.6, Lifetime 3~5)·`TeaLeaves`(`Petals`와 움직임 값 전부 같고 색만 연두→초록) 모두 스펙대로, `MapFxPresets.validate`·`MapKitLogic.validate` 통과.

## 버그
P0/P1/P2 없음.

### [P3-1] 배치 3 맵이 풀에 들어간 뒤 다시 `inPool = false`로 돌아가도 잡는 테스트가 없음
- 재현: (배치 3이 모두 졸업한 뒤) 예컨대 `RiceCooker.luau`에 `inPool = false`를 실수로 다시 넣고 `lune run tests`.
- 기대: 랜덤 풀이 21개에서 20개로 줄어든 것을 어떤 테스트가 잡는다.
- 실제: 통과. 기대값이 모두 "지금 `inPool` 값"에서 계산되고(`tests/lib/Batch3.luau:51` `pooledIds`), `m5-03-foundation.spec.luau` AC1은 배치 3을 "풀에 있음" 검사에서 뺌, `m5-33-batch3.spec.luau` AC2도 지금 값으로 분기.
- 성격: 병렬 6개가 공용 테스트를 고치지 않게 하려는 의도된 trade-off(스펙 D3). 스펙도 "6개가 다 들어가면 메인 세션이 `#Maps.infos() == 21`을 확인"이라고 적음.
- 제안(개발·메인 세션, 반려 아님): 6개가 모두 병합되면 `tests/lib/Batch3.luau`에 "졸업 완료" 고정 단언(`#Maps.infos() == 21`, Race 8·Survival 7·Final 6)을 한 줄 넣어 다시 숫자로 묶는다.

### [P3-2] `m4-12-hardening` 연속 플랜 목록이 배치 3 맵을 영구히 제외
- 위치: `tests/m4-12-hardening.spec.luau:277~281`
- 내용: "연속 플랜이 풀의 맵을 모두 한 번 이상 씀" 검사에서 배치 3을 뺐다. 이 검사는 Studio 연속 플랜 목록(`FORCED_PLANS`)이 풀 전체를 덮는지를 보는데, 배치 3이 졸업해도 목록에 없어도 통과한다. 연속 5판 시뮬레이션은 순수 로직이라 실제 위험은 낮음.
- 제안: P3-1과 같은 때(6개 졸업 뒤) 배치 3 맵을 `FORCED_PLANS`에 넣고 제외 분기를 지운다.

### 참고 (버그 아님)
- 개발 테스트(`m5-33-batch3`)는 껍데기의 `start`·`overtime` 동작을 돌려 보지 않았다. QA가 복사본에서 돌연변이 4개(연장전 delay를 `ctx.cleanup`에 안 넣음, 낙하를 월드 Y로, 결승 `>=`→`>`, 연장전 뒤 `CanCollide = true`)를 넣어 보니 **기존 테스트는 4개 모두 통과**했고 이번에 추가한 `m5-33-qa`가 4개 모두 잡았다(2000 passed, 4 failed — 그중 1개는 위 `.git` 환경 실패).

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 이 스펙은 리모트를 추가·변경하지 않음(`Remotes.luau` 변경 없음)
- [x] 통과·탈락·순위 판정이 서버에만 있다 — 껍데기 판정은 `start`의 서버 Heartbeat에서 `ctx.pass`/`ctx.eliminate`만
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — 모듈 수준 local은 상수·require·함수뿐(QA 테스트로 고정), 연장전은 `ctx.model`만 봄
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다 — Heartbeat 연결 1개, 연장전 delay 1개 모두 `ctx.cleanup`

## 사용자 Studio 확인 체크리스트 (AC9·AC10)
1. `src/shared/Config.luau`에서 `DEBUG.forceMapPlan = { "dish-sink", "rice-cooker", "tea-garden" }`로 바꾸고 Play(혼자, `minPlayersToStart = 1`).
   - 1라운드 "깨끗하게! 설거지통": 회색 바닥을 앞으로 달려 노란 결승선을 지나면 통과.
   - 2라운드 "초대형 밥솥": 회색 접시에서 60초 버티면 통과(떨어지면 탈락).
   - 3라운드 "찻잎 정원"(결승): 90초에 "⚡ 연장전!" 배너·경적 → 20초 뒤 접시가 사라지고 떨어져 마무리(혼자면 우승 연출).
   - 라운드 소개에 이름·한 줄 규칙이 GDD 표대로 나오는지, 라운드마다 조명 분위기가 바뀌는지(오전 → 오후 → 해 질 녘).
   - Output 창에 빨간 에러가 없는지.
2. `forceMapPlan = { "space-conveyor", "fish-market", "onsen-claw" }`로 한 번 더(우주 = 밤 조명, 수산시장 = 아침, 온천 = 저녁). 같은 확인.
3. (선택, AC10) `forceMapPlan = nil`로 두고 몇 판 — 새 6개는 나오지 않고 기존 15개만 나와야 함.
4. **확인이 끝나면 `forceMapPlan = nil`로 되돌린다**(커밋 값 고정 테스트가 있음).

## 추가한 테스트
- `tests/m5-33-qa.spec.luau` (5개) — 실제 껍데기 소스를 가짜 Heartbeat·가짜 `task`로 불러 돌림. 맵 스펙이 파일을 덮어쓰면(머리 주석 "m5-33 껍데기"가 사라지면) 그 맵은 자동으로 빠지므로 m5-34~39가 이 파일을 고칠 필요 없음.
  1. 지금 `inPool = false`인 배치 3은 모두 껍데기
  2. 낙하선: 로컬 Y −24.9 무사 / −25.1 탈락(아레나 슬롯 origin), 끝난 라운드는 판정 없음, Heartbeat 연결 1개가 `ctx.cleanup`
  3. Race 결승: −Z 159.9 아님 / 160·165 통과, 통과로 라운드가 끝나면 그 틱 멈춤, 결승선이 바닥 위·충돌 없음
  4. Final 연장전: 바로 반환·`task.wait` 없음·delay 1개(20초)가 `ctx.cleanup`, 발동 뒤 판정 충돌 파츠 0개·접시 투명, 다른 방 모델 그대로, 끝난 라운드면 그대로
  5. Race·Survival은 `overtime` 없음, 모듈 수준 가변 상태 없음

## 인계 메모 (2026-10-15, qa)
- **브랜치**: `main`. QA 커밋 1개(push 안 함 — 메인 세션 지시).
- **끝난 것**: AC1~AC8 확인(검증 5단계 직접 실행, AC7 풀 진입 시뮬레이션 재현), D5·D6 확인, 테스트 5개 추가, 스펙 `qa-passed`.
- **남은 것**: 사용자 Studio AC9·AC10(위 체크리스트). P3-1·P3-2는 6개 맵이 모두 병합된 뒤 메인 세션/개발이 처리.
- **다음 첫 단계**: 메인 세션이 `main` push → m5-34~39 worktree 생성. docs-writer가 문서 반영 후 `done`.
- **막힌 점**: 없음.

## P3-1·P3-2 처리 기록 (2026-10-15, qa, 배치 3 6개 모두 main 병합 뒤)
- **P3-1**: 실제 풀 검사를 고정값으로 바꿈. `tests/lib/Batch3.luau`에 `POOL_COUNT = 21`·`POOL_BY_KIND`(Race 8·Survival 7·Final 6)·`idsOfKind` 추가. `m5-33-batch3` AC2는 `#Maps.infos() == 21`과 종류별 8/7/6을 숫자로 확인하고 배치 3 6개가 모두 `inPool ~= false`인지 봄. AC7은 실제 풀을 `POOL_COUNT`와 비교(가짜 목록 검사는 그대로). `m5-03-foundation` AC1의 배치 3 예외 분기를 지우고 AC2를 `21`로 고정. `m4-foundation`·`m2-01-qa`는 `pooledOfKind(Maps.get, …)` 대신 고정 목록 `idsOfKind`.
- **P3-2**: `m4-12-hardening` 연속 플랜에 `{ dish-sink, rice-cooker, tea-garden }`·`{ space-conveyor, fish-market, onsen-claw }`를 넣고(13개) 배치 3 제외 분기를 지움.
- **돌연변이 확인**: 복사본에서 `RiceCooker.luau`에 `inPool = false`를 넣으니 `m4-12-hardening`·`m4-foundation`·`m5-03-foundation`·`m5-33-batch3`·`m5-33-qa`·`map-rice-cooker`가 실패(전에는 통과).
- **검증 5단계**: rojo build 성공, stylua 통과, selene 0 errors / 0 warnings, `lune run tests` **2178 passed, 0 failed**, luau-lsp 끝 코드 0. `src/` 변경 없음.
