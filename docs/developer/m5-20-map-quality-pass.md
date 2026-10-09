# m5-20 map quality pass — 개발 작업 기록

## 2026-10-09 — 구현 완료, in-qa (최신)
- **worktree**: `/Users/rubinjang/sushi/sushi-survival-race/.claude/worktrees/agent-ad065ab6dab525157` (branch `worktree-agent-ad065ab6dab525157`). 이 세션에서는 push하지 않음(메인 세션이 머지).
- **끝난 것**: 스펙 범위 전부(`rotating-belt`·`soy-swamp`·`chef-board`·`ramen-rapids`·`hot-plate` 5개 맵 장식 보강), AC1~AC7(순수 로직). 판정 지오메트리·장애물 수치·시간 제한·스폰 배치는 전부 그대로.
  - 새 공유 모듈 `src/shared/maps/MapDecorTags.luau` (CollectionService 태그 상수 EyeBlink·Wobble).
  - 새 클라이언트 컨트롤러 `src/client/fx/MapDecorFxController.luau` (태그로 파츠를 찾아 로컬로만 눈 깜빡임·병 흔들림, 복제 없음, 거리 컬링). `src/client/init.client.luau`에 한 줄 등록(이 스펙 담당 공용 파일 변경).
  - `rotating-belt`: 등불(Lantern) `PointLight` 3개, 병목 맨 앞 간장 종지 위 `SoyGlint` 파티클 2개, 손님 눈(FaceEye) 6개에 EyeBlink 태그, 소개 카메라 반전 샷 1개 추가(5점).
  - `soy-swamp`: 와사비 산 꼭대기(HillRice) `PointLight` 2개, 웅덩이 보글거림(SoyBubble) 파티클 3개, 안개 패널 4개, 소개 카메라 반전 샷 1개 추가(5점).
  - `chef-board`: 머리 위 등(LampBulb) `PointLight` 3개(가운데 Range 30·양옆 18), 칼날에 한 번만 터지는 불꽃 파티클(상시 아님), 안개 패널 4개.
  - `ramen-rapids`: 급류 양옆 소품(다시마 12·통깨 20·젓가락 받침 6 = 38곳) 추가, 안개 패널 3개.
  - `hot-plate`: 선반 간장병 3개에 Wobble 태그만 추가(파티클·조명은 이미 있어서 안 건드림).
- **검증**: `rojo build` OK, `stylua --check` OK, `selene` 0/0/0, `lune run tests` 1144 passed / 0 failed(기존 1090여 개 전부 그대로 통과 + 이번에 추가한 테스트), `luau-lsp analyze` 에러 0.
- **남은 것**: QA, Studio AC8~AC14(스펙 "Studio 확인 방법" 참고).
- **다음에 할 첫 단계**: QA가 `forceMapPlan`으로 다섯 맵을 Studio에서 돌며 등불·파티클·안개·흔들림·반전 샷 체감 확인. 특히 `rotating-belt` 반전 샷 좌표(`(0,26,-62)`, 스펙 제안 `y≈32`보다 낮춤 — 등불 충돌 회피, 아래 메모 참고)가 충분히 "내려다보는" 느낌인지.
- **막힌 점**: 없음. Studio가 없어 화면·밝기·흔들림 체감은 확인 못 함.
- **메모**
  - **AC7(기존 테스트 그대로 통과) 때문에 구조가 제약됨**: `tests/map-art-race.spec.luau`의 소스-텍스트 기반 테스트가 `build()` 함수 본문에서 `MapKit.buildDecor(Art.decor(), origin, MapKit.decorFolder(model))` 리터럴을 직접 찾는다. 처음에 조명·파티클 부착을 별도 `buildArt()` 함수로 뽑아냈다가 이 테스트가 깨져서, `rotating-belt`·`soy-swamp` 둘 다 데코 루프를 `build()` 안에 인라인으로 되돌렸다(변수에 중간 저장 안 하고 `MapKit.buildDecor(...)`를 `for`에 직접 씀). 이 패턴을 넘는 맵을 또 고칠 일이 있으면 같은 함정에 주의.
  - **반전 샷과 기존 등불이 충돌**: 스펙 제안대로 `rotating-belt` 5번째 점을 `(0,32,-60)`으로 넣었더니, 다음 점(결승 노렌, z=-96)으로 내려가는 직선 경로가 z=-90 등불을 스쳐 지나가서 `tests/m4-02-qa.spec.luau`·`tests/m4-12-hardening.spec.luau`(경유점 **사이** 경로를 촘촘히 샘플링하는 기존 QA 테스트, AC7 보호 목록 밖이지만 수정 안 하고 좌표로 해결)가 깨졌다. `(0,26,-62)`로 낮추고 당겨서 등불 세 개 전부와 여유(1.6~3.1 studs)를 뒀다. 좌표를 또 조정할 일이 있으면 `lune run tests`로 이 두 파일이 통과하는지 꼭 확인.
  - **chef-board 파티클은 `Art.decor()` 밖**: 칼날(Blade)은 `ChefBoard.luau`가 직접 만드는 파츠라 `DecorSpec` 목록에 없다. 그래서 AC2의 "파티클 1"은 `countNamed`가 아니라 소스 텍스트 검사(파티클 존재·`Enabled=false`·`Rate=0`·`:Emit(` 호출)로 확인했다 — QA가 볼 때 `countNamed` 패턴을 기대하면 당황할 수 있어 미리 적어 둠.
  - `tests/m4-05-qa.spec.luau`(AC7 보호 목록 밖)의 "ChefBoard에 조명·파티클이 전혀 없어야 한다"는 m4-05 때 단언을 이번 스펙 취지에 맞게 "LampBulb 3개·불꽃 1개만 있고 예산 안"으로 바꿨다.
  - 안개 패널 3종 색: soy-swamp 갈색-호박색, ramen-rapids 국물 금빛, chef-board 청회색. 전부 `Glass` 재질 + `Transparency` 0.88~0.92, 각 맵 `courseVolume()`/`courseVolumes()` 바깥에 배치(겹침 테스트로 고정).
