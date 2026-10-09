# m5-18 map-tug-of-war-platform — 개발 작업 기록

## 2026-10-09 — 구현 완료, in-qa
- **브랜치/worktree**: `.claude/worktrees/agent-af227ddbced4aa388` (브랜치 `worktree-agent-af227ddbced4aa388`). 메인 세션이 머지, push는 안 함.
- **끝난 것**: 스펙 범위 전부.
  - `TugOfWarPlatform.luau` m5-13 껍데기 덮어씀 (`inPool = false` 삭제): 발판 1개(태그 `TugOfWarPlatform`) + 기울 때 같이 움직이는 `PlatformGroup`(발판 파츠 + 무게추/접시 테두리/동아줄 장식), 스폰 24개(왼쪽 12·오른쪽 12). 매 Heartbeat `TugOfWarPlatformLogic.tilt`로 목표 기울기를 구하고 `approach`로 서서히 따라가다가, 연장전이 오면 `overtimeAngle`로 전환(무게 분포 더 안 봄). 넉백·순간이동 없이 발판 CFrame만 돌리고 실제 미끄러짐은 Roblox 물리(중력+마찰, Friction 0.35)에 맡김 — `MoveExempt.mark` 안 씀(결정 기록 D3).
  - 새 `TugOfWarPlatformLayout.luau`(치수: 길이 70·폭 22·두께 2·CENTER_Z -40·FALL_DEPTH 25·마찰 0.35·스폰 24개 격자, Roblox API 없음).
  - 새 `TugOfWarPlatformLogic.luau`(`tilt`·`approach`·`overtimeAngle`, 상수 MAX_ANGLE 30°·SATURATION_TORQUE 105·TILT_RATE 20°/s·LETHAL_ANGLE 90°, Roblox API 없음).
  - 새 `TugOfWarPlatformArt.luau`(`deckDecor()` 기울어지는 저울 접시 테두리·동아줄·무게추, `decor()` 고정 받침대·가게 마당 배경, `introCamera()` 4점).
  - 새 `tests/map-tug-of-war-platform.spec.luau` AC1~AC7 (24개 전부 통과).
  - 맵 풀이 6개→7개로 늘어난 영향으로 기존 테스트 갱신: `tests/maps.spec.luau`(Final 풀 개수), `tests/m4-foundation.spec.luau`(AC6 Final 목록), `tests/m4-12-hardening.spec.luau`(강제 플랜에 tug-of-war-platform 포함), `tests/m5-03-foundation.spec.luau`(SHELLS 목록·infos() 개수·rule 텍스트 — tug-of-war-platform이 더 이상 껍데기가 아님).
  - 공용 파일 수정 없음(`shared/maps/init.luau`은 m5-13이 이미 등록).
- **검증**: `rojo build -o build.rbxl` OK, `stylua --check src tests` OK, `selene src` 0 errors/0 warnings, `lune run tests` 1163 passed / 0 failed, `luau-lsp analyze` 종료 코드 0.
  - 타입 검사에서 2곳 고침: `CFrame:ToObjectSpace`가 가변 반환(`...CFrame`)이라 `table.insert` 마지막 인자로 바로 쓰면 인자 수가 흔들려서 괄호로 값 하나만 받게 함, `table.create(n)`은 요소 타입을 못 정해서 `:: { CFrame }` 캐스팅(SkewerShowdown과 동일 패턴).
- **남은 것**: Studio 확인 AC9~AC16 (사용자, `docs/specs/m5-18-map-tug-of-war-platform.md` "Studio 확인" 절). 특히 AC9 부호 확인 — 반대로 보이면 `TugOfWarPlatform.luau`의 `TILT_SIGN` 상수 하나만 뒤집으면 됨.
- **다음에 할 첫 단계**: QA가 `docs/specs/m5-18-map-tug-of-war-platform.md` "개발 메모"의 Studio 확인 방법대로 검증.
- **막힌 점**: 없음. 스펙과 다르게 구현한 부분 없음(결정 기록 D1~D4 모두 "기본값 유지"로 따름).
- **메모**:
  - 장식/발판 CFrame 갱신은 `SkewerShowdown.luau`의 `moveFood` 패턴 재사용: build 때 flatPivot(원점 기준 CENTER_Z, 기울지 않은 상태) 기준 오프셋을 한 번만 계산해 두고, 매 틱 `pivotCFrame * offset`을 `workspace:BulkMoveTo`로 적용.
  - ikura-bombs(m5-04)가 아직 `ready`라서 지금은 랜덤 결승 맵이 꼬치 쇼다운 + 줄다리기 발판 2개 중 무작위(AC14는 ikura-bombs가 `done`이 되면 3개로 다시 확인).
