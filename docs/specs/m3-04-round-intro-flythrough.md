status: ready
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m3-04 — 라운드 소개 플라이스루 · "출발!"

- 마일스톤: M3
- GDD 근거: `docs/GDD.md` §4-2(라운드 소개: 맵 플라이스루 카메라 + 맵 이름·규칙 한 줄 3초), §4-3(소개 동안 스폰에 멈춰 있다가 동시에 출발), §11.3(CameraController: 소개 플라이스루)
- 참고: `docs/REFERENCE-party-royale.md` §2 (Fall Guys 코스 플라이오버 + 설명, 크고 두꺼운 카운트다운 글씨)
- 담당 개발 worktree: `m3-intro` (Rojo 포트 34874)
- 공용 파일 수정 담당: 없음
- 의존: **m3-01 머지 후 시작** (맵 Model 속성 `RoomId`/`RoundIndex`/`MapId`, `CameraDirector`)
- **이 스펙이 고치는 파일**: `src/client/fx/IntroController.luau`, 새 파일 `src/client/fx/IntroScreen.luau`("출발!" 글씨), 새 파일 `src/shared/IntroCameraLogic.luau`(순수), 새 파일 `tests/intro-camera.spec.luau`

## 목표
라운드가 바뀔 때마다 카메라가 새 맵 위를 한 번 훑어서 "이번엔 어떤 맵이지?"를 보여 주고, 내 초밥 뒤로 돌아와 큰 글씨 **"출발!"**과 함께 모두가 동시에 출발한다.

## 범위
- 포함:
  1. **누가 보나** — `MatchPhase` = `RoundIntro`를 받았을 때 **내가 `aliveUserIds`에 있으면**(이번 라운드를 뛰는 사람) 플라이스루를 본다. 이미 탈락한 관전자·"로비로"를 누른 사람은 보지 않는다(관전 화면 그대로).
  2. **맵 찾기** — Workspace에서 속성 `RoomId` = 내 방 id(`RoomUpdated`로 받은 것), `RoundIndex` = 이번 라운드 번호인 Model을 찾는다. 서버가 소개 방송 직후 맵을 지으므로 **최대 1초 기다리고**, 못 찾으면 이번 플라이스루는 건너뛴다(배너만, M2와 같음).
  3. **카메라 경로** — 맵 Model 안에 `IntroCamera` 폴더가 있으면 그 안의 파츠를 이름순으로 경유점 삼는다(M4 아트 맵용, 지금 맵들은 없음). 없으면 순수 함수 `IntroCameraLogic.autoPath(boundsCFrame, boundsSize, origin, kind)`로 자동 경로를 만든다:
     - Race: 코스 **끝(결승선 쪽, origin의 로컬 -Z 방향 먼 끝) 위 높은 곳**에서 시작 → 코스 가운데 위를 지나 → **스폰 뒤쪽 위에서 코스 방향을 바라보며** 끝난다.
     - Survival·Final: 맵 가운데를 바라보며 높은 곳에서 반 바퀴(약 180도) 돌고, 스폰 쪽 위에서 끝난다.
     - 경유점 사이는 부드럽게(가감속) 이어진다: `IntroCameraLogic.sample(path, t) -> CFrame` (t = 0~1).
  4. **시간 배분** (`Config.Match.IntroDuration` = 3초 기준): 처음 2.4초 경로 비행(`IntroWhoosh` 한 번) → 마지막 0.6초 동안 내 캐릭터 뒤 기본 카메라 위치로 부드럽게 붙는다 → `RoundActive`를 받으면 release. 카메라는 `CameraDirector.request("Intro", Priority.Intro, …)`. 소개가 중간에 취소되면(소개 중 이탈로 결승으로 건너뜀 → 새 `RoundIntro`) 새 라운드로 처음부터 다시.
  5. **"출발!"** — `RoundActive`를 받는 순간 화면 가운데 큰 글씨 "출발!"을 0.8초 띄우고(커졌다 사라짐) `Sfx.play("Go")`. 플라이스루를 안 본 관전자에게는 띄우지 않는다.
  6. 기존 HUD 소개 배너(라운드 n/N · 맵 이름 · 규칙)는 그대로 둔다 — 이 스펙은 HUD 파일을 고치지 않는다.
- 제외:
  - 맵별 손으로 짠 카메라 경로 (`IntroCamera` 폴더는 M4 맵 아트에서)
  - 소개 시간 늘리기·"3, 2, 1" 카운트다운 (기본값은 3초 그대로. 필요하면 m3-09 튜닝에서)
  - 서버 변경

## 수용 기준
### 순수 로직 (lune 테스트로 확인, `tests/intro-camera.spec.luau`)
- [ ] AC1: Race 맵 경계(origin 앞쪽 -Z로 200 studs 뻗은 상자)로 `autoPath`를 만들면 첫 경유점은 코스 끝 쪽(origin 로컬 Z가 가장 작은 쪽 절반)에 있고, 마지막 경유점은 스폰 쪽 절반에 있으며 바라보는 방향의 로컬 Z 성분이 음수(코스 방향)다.
- [ ] AC2: 모든 자동 경유점의 높이가 경계 상자 꼭대기보다 높다.
- [ ] AC3: Survival·Final 경계로 만든 경로의 모든 경유점이 경계 중심을 바라본다(바라보는 방향과 중심 방향의 내적 > 0.9). 단 마지막 점은 예외 없이 같은 조건.
- [ ] AC4: `sample(path, 0)` = 첫 경유점, `sample(path, 1)` = 마지막 경유점(위치 오차 0.01 이하), t가 커질수록 경로를 따라 앞으로만 간다(되돌아가지 않음).
- [ ] AC5: `lune run tests` 전체 통과.

### Studio 확인
- [ ] AC6: 혼자 F5, `forceMapPlan = { "rotating-belt", "hot-plate", "soy-swamp", "skewer-showdown" }` — 라운드마다 소개 3초 동안 카메라가 새 맵 위를 훑고, 끝날 무렵 내 초밥 뒤로 돌아온다. 맵 이름·규칙 배너가 같이 보인다.
- [ ] AC7: Race 맵(회전 벨트·간장 늪)에서는 결승선 쪽에서 출발 지점 쪽으로 날아오고, 철판·꼬치 쇼다운에서는 맵 가운데를 보며 돈다.
- [ ] AC8: 소개가 끝나는 순간 "출발!"이 크게 뜨고, 그때 카메라는 이미 내 캐릭터를 따라가며 바로 움직일 수 있다(카메라가 늦게 돌아와 출발이 늦어지지 않음).
- [ ] AC9: Clients and Servers 3명 — 1라운드에서 탈락해 관전 중인 사람은 2라운드 소개 때 관전 화면이 유지되고 플라이스루·"출발!"이 나오지 않는다. 달리는 두 사람은 플라이스루를 본다.
- [ ] AC10: 두 방이 동시에 같은 맵으로 라운드를 시작해도 각자 자기 방 맵을 훑는다 (Clients and Servers 4명, 방 2개 × 2명, `minPlayersToStart` 1).
- [ ] AC11: 플라이스루 도중 방을 나가면 카메라가 로비의 내 캐릭터로 돌아오고 에러가 없다.

## 공용 파일 변경
- 없음 (읽기만: `Config.Match.IntroDuration`, `Attributes.RoomId/RoundIndex/MapId`, `CameraDirector`, `SfxCues`)

## 결정 기록
- 2026-10-08 · 플라이스루 대상 · 이번 라운드를 뛰는 사람만. 관전자는 관전 화면 유지. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 소개 시간 · 3초 그대로(비행 2.4 + 복귀 0.6), 카운트다운 없이 "출발!"만. 한 판 길이(GDD 4~5분) 유지. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 순수 함수 자료형 · Lune 테스트 환경에는 `Vector3`/`CFrame`이 없다(`tests/lib/RobloxRequire.luau`는 `script`·`require`만 흉내). 그래서 `IntroCameraLogic`은 위치·방향을 숫자 표(`{ x, y, z }`)로 받고 돌려주며, `autoPath(bounds, origin, kind)`의 `bounds`는 `{ center, size }`(숫자 표), `origin`은 `{ position, forward }`(forward = origin LookVector)로 받는다. 경유점은 `{ position, lookAt }`. 컨트롤러가 `CFrame.lookAt`으로 바꾼다. 위 AC의 "CFrame"·"origin 로컬 Z"는 이 숫자 표 기준으로 읽는다 · planner
- 2026-10-08 · 경로 · 맵 파일을 고치지 않게 자동 경로(경계 상자 기준). 맵별 수동 경로는 `IntroCamera` 폴더로 M4에서 · planner

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
