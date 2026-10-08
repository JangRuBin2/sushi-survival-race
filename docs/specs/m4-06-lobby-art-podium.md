status: ready
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m4-06 — 로비 아트 · 조명 · 우승자 단상

- 마일스톤: M4
- GDD 근거: `docs/GDD.md` §3.1(회전초밥집 카운터 모양 로비, 벨트 위 접시), §8(로비로 돌아가면 단상에 우승자 초밥 전시, 우승 칭호), §12(M4)
- 참고: `docs/REFERENCE-map-production.md` §5, `docs/specs/m4-02-art-race-maps.md` "공통 규칙"(장식 규칙)
- 담당 개발 worktree: `m4-lobby` (Rojo 포트 34876)
- 공용 파일 수정 담당: 없음
- 의존: **m4-01 머지 후 시작** (`LobbyService`·`LobbyFxController` 껍데기, `MatchEvents.onWinnerShowcase`, `DataService`, `MapKit`)
- **이 스펙이 고치는 파일**: `src/server/LobbyService.luau`, `src/client/fx/LobbyFxController.luau`, 새 파일 `src/shared/LobbyLayout.luau`, `tests/lobby-layout.spec.luau`

## 목표
게임에 들어오면 기본 판자 바닥이 아니라 **회전초밥집 안**에 서 있다. 가운데 카운터를 접시 실은 레일이 돌고, 한쪽에 우승자 단상이 있어 방금 이긴 초밥이 칭호와 함께 서 있다. 게임 전체 조명이 따뜻한 가게 분위기로 바뀐다.

## 범위
- 포함:
  1. **로비 건물** (`LobbyService.start`에서 코드로 생성, `Workspace.Lobby` Model, 장식은 `MapKit.buildDecor` 규칙):
     - 바닥: 기존 `Baseplate`(256×256)를 그대로 쓰되 런타임에 색·재질을 나무 바닥으로 바꾼다(`default.project.json`은 안 고침). 바깥 가장자리에 낮은 벽(높이 14)과 기둥, 위쪽 들보.
     - **카운터 + 회전 레일**: `LobbySpawn`에서 앞쪽(-Z) 약 40 studs에 타원형 카운터(긴 쪽 60, 짧은 쪽 24, 높이 3.5)와 그 위 레일. 레일 위 접시 16개(빨강·파랑·금색 접시 + 연어·참치·계란·새우 니기리 소품)가 돈다 — **회전은 클라이언트 `LobbyFxController`가 로컬로**(서버 부하·복제 없음, 모든 클라이언트가 같은 시각 기준 `workspace:GetServerTimeNow()`로 위치 계산 → 대체로 같아 보임).
     - 카운터 안쪽에 셰프(블록 인형, 흰 모자), 벽에 메뉴판·노렌·등(PointLight ≤ 8), 입구 쪽 수조(파란 반투명 + 물고기 장식).
     - 레일·카운터·벽은 충돌 있음(밟고 올라갈 수 있는 정도는 상관없음), 소품은 장식 규칙(충돌 없음).
     - **스폰 주변 반지름 10 studs와 스폰 → 카운터 사이 통로**는 비운다. 로비 전체는 원점 반지름 128 안, 높이 60 아래 (아레나 슬롯 x ≥ 2000, 높이 300과 안 겹침).
  2. **우승자 단상**: 스폰 오른쪽(+X) 약 30 studs, 3단 시상대 모양(가운데가 가장 높음, 금색 테두리). 가운데 단 위에:
     - `MatchEvents.onWinnerShowcase(info)`를 받으면 그 우승자의 초밥 인형(`SushiBody.build(info.appearanceId)`, 크기 1.5배, 앵커·충돌 없음)을 세우고, 위에 BillboardGui로 "🏆 {이름}"과 칭호(`DataService.get` → `ProfileSchema.titleFor(wins)`, 없으면 생략)·"{wins}승"을 띄운다. 플레이어가 나가도 인형은 남는다(이름은 그대로).
     - 새 우승자가 나오면 바꾼다(가장 최근 1명). 아무도 없으면 빈 단상에 "다음 우승자는 누구?" 표시.
     - 양옆 낮은 단 두 개는 장식(M4에서는 비워 둠).
  3. **조명 프리셋**(서버 `LobbyService.init`에서 한 번, 한 플레이스 모드라 아레나에도 같이 적용): `Lighting.ClockTime = 14`, `Brightness`, 따뜻한 `Ambient`/`OutdoorAmbient`, `Atmosphere`(옅게, 먼 아레나가 너무 뿌옇지 않게 Density ≤ 0.3), `ColorCorrectionEffect`(약간 따뜻하게, Saturation +0.05), `BloomEffect` 약하게, `Technology`는 건드리지 않는다(Studio 설정). 값은 `LobbyLayout.LIGHTING` 표(순수 데이터).
  4. **순수 데이터** `LobbyLayout.luau`: 건물·장식 `DecorSpec` 목록, 레일 경로(타원 둘레 길이, `plateAt(index, t) -> {x,y,z, yaw}`), 단상 위치, 조명 표, 비워 둘 영역(스폰·통로) 상자.
  5. 플레이스 분리(m4-11) 대비: 로비는 `PlaceService.role()`이 `"Match"`이면 짓지 않는다(매치 플레이스에는 로비가 없음, 조명만 적용). 지금은 항상 `"Single"`.
- 제외:
  - 방 목록을 벨트 위 접시로 보여 주고 접시를 눌러 참가하는 3D UI (GDD 3.1 표현) — 방 목록은 지금 화면 UI 그대로. M5 이후 후보
  - 탈의실·상점 건물(m4-13·m4-14가 필요하면 로비 위치만 받아 감)
  - 우승 기록 저장(승수는 m4-08이 저장, 여기서는 읽기만)

## 수용 기준
### 순수 로직 (lune 테스트로 확인, `tests/lobby-layout.spec.luau`)
- [ ] AC1: 로비 장식이 `MapKitLogic.validate`를 통과하고 파츠 수가 800 이하다.
- [ ] AC2: 모든 로비 파츠 외곽이 원점 반지름 128·높이 60 안이고, 스폰 반지름 10·스폰→카운터 통로 상자와 겹치지 않는다.
- [ ] AC3: `plateAt(i, t)`가 레일 경로 위에 있고, 같은 t에서 접시 16개 사이 간격이 일정하며, t가 늘면 한 방향으로 돈다(주기 = 둘레 / 속도).
- [ ] AC4: 조명 표의 `Atmosphere.Density`가 0.3 이하이고 필요한 키가 다 있다.
- [ ] AC5: 검증 명령 4개 통과.

### Studio 확인
- [ ] AC6: F5로 들어가면 회전초밥집 로비(카운터, 접시가 도는 레일, 셰프, 노렌, 수조, 단상)가 보이고 조명이 따뜻하다 (스크린샷).
- [ ] AC7: 스폰에서 바로 움직일 수 있고 통로가 막히지 않는다. 로비 UI(방 목록)가 건물에 가려지지 않는다.
- [ ] AC8: 혼자(`forceMapPlan`) 한 판을 이기고 로비로 돌아오면 단상 가운데에 내 계란초밥 인형과 "🏆 내 이름", "탈출 초밥"(1승 이상일 때, m4-08 머지 전에는 승수가 0이라 칭호 없이 이름만) 표시가 있다.
- [ ] AC9: Clients and Servers 2명: 두 클라이언트에서 레일 접시 위치가 거의 같고(1초 이내 차이), 서버 Explorer에는 접시가 움직이지 않는다(로컬 회전 확인).
- [ ] AC10: 매치 아레나도 같은 따뜻한 조명이고, 먼 아레나를 보는 관전 화면이 안개로 뿌옇지 않다.
- [ ] AC11: 프레임이 M3 로비보다 눈에 띄게 떨어지지 않는다 (사용자 확인, 휴대폰 에뮬레이터 포함).

## 공용 파일 변경
- 없음 (`Baseplate`는 런타임에 색만 바꿈)

## 사용자 작업 (스펙을 막지 않음)
- AC6·AC11 확인. (선택) 더 꾸민 로비를 Studio에서 만들면 `assets/map-art/lobby.rbxm`(m4-01의 MapArt 규칙과 같게 `MapKit.attachStudioArt(lobbyModel, "lobby", CFrame.new())`를 이 스펙이 부름).

## 결정 기록
- 2026-10-08 · 단상 = 이 서버의 가장 최근 우승자 1명 · GDD 8 "방 안 단상"은 방이 3D 공간이 아니라서 로비 중앙 단상으로 대신. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-08 · 레일 접시는 클라이언트 로컬 회전 · 서버 부하·복제 없음 · planner
- 2026-10-08 · 방 목록 3D 접시 UI는 M5 이후 · 화면 UI가 모바일에서 더 쓰기 쉬움 · **기본값으로 진행, 사용자 수정 가능** · planner

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
