# m5-19 map-claw-machine-prize — 개발 작업 기록

## 2026-10-09 — 구현 완료, in-qa
- **워크트리**: `.claude/worktrees/agent-af6a09747d8f078ae`, 브랜치 `worktree-agent-af6a09747d8f078ae` (push 안 함 — 메인 세션이 머지)
- **끝난 것**: 스펙 범위 전부.
  - `ClawMachinePrize.luau` 껍데기(m5-13)를 실제 맵으로 덮어씀: 8×8=64칸 발판 격자(태그 `ClawMachineTile`, 속성 Row·Col·Index), 중앙 허브+세 갈래 발톱 집게 모델(태그 `ClawMachinePrizeClaw`, 연출 전용 충돌 없음), `PivotAnchor`로 origin에 피벗 고정(연장전 기울기용).
  - 새 `ClawMachinePrizeLayout.luau`(격자 좌표 순수 함수: tileIndex·tileHeight·tileLocalX/ZGrid·colOf/rowOf 역함수·spawnTiles 24개).
  - 새 `ClawMachinePrizeLogic.luau`(순수: clawWave 시간표, liftedTiles 격자 잘림, pickClawTarget 70/30 과녁 고르기+재시도, overtimeTilt 낮은 쪽부터 8줄 기울기 일정).
  - 새 `ClawMachinePrizeArt.luau`(유리벽 4면+천장 Transparency 0.9 Glass, 크레인 레일 교차, 오락실 네온 간판, 칸 위 저예산 인형 더미 2개 — 칸 파츠의 자식으로 넣어서 칸이 Destroy될 때 같이 사라짐).
  - 집게 과녁 선정 루프(`start`)는 `Logic.clawWave`로 주기·구역 크기·경고 시간을 읽어 `Logic.pickClawTarget`으로 과녁을 고르고, 경고(노란 깜빡임) → 바닥 비활성화(그 순간 자연 낙하) → 1.2초 들어 올리는 연출 → `Destroy`. 연장전(`overtime`)은 집게를 멈추고(이미 진행 중인 건 끝까지) 상자 전체를 `ctx.model:PivotTo(origin * CFrame.Angles(...))`로 0→35도 기울이며 `Logic.overtimeTilt`(낮은 쪽부터 8줄)로 줄 단위 경고 뒤 `CanCollide=false`(SkewerShowdown.collapseStrip과 같은 패턴). `task.wait`로 안 기다리고 `task.delay`/`task.spawn`을 `ctx.cleanup`에 넣음(m5-01 계약).
  - `inPool = false` 줄 삭제 — 랜덤 결승 풀 7개(skewer-showdown·claw-machine-prize + 아직 `done`이 아닌 맵은 이미 inPool 켜진 것만)로 늘어남.
  - 새 `tests/map-claw-machine-prize.spec.luau` AC1~AC7 (15개 케이스).
  - `SfxCues.luau`·`SfxLibrary.luau`에 `ClawLift` cue 추가(무음, USER-TODO 사용자 추가 제안 — 스펙 "사용자 작업" 참고, 공용 파일 아님).
- **맵 풀에 합류하면서 고친 기존 테스트** (공용 파일 아님, inPool 켜지며 깨진 하드코딩 가정들):
  - `tests/maps.spec.luau`: 풀 개수 6 → 7.
  - `tests/m4-foundation.spec.luau`: `byKind.Final`에 `claw-machine-prize` 추가.
  - `tests/m4-12-hardening.spec.luau`: 연속 5판 FORCED_PLANS 마지막 플랜의 결승을 skewer-showdown → claw-machine-prize로(풀의 맵을 전부 한 번씩 쓴다는 단언이 있어서).
  - `tests/m5-03-foundation.spec.luau`: SHELLS 목록·`expected` 표에서 claw-machine-prize 제거(더 이상 껍데기 아님), infos() 개수 6 → 7.
  - `tests/m2-01-qa.spec.luau`: "결승은 언제나 skewer-showdown" 단언을 "둘 중 하나"로 완화.
  - `tests/camera-priority.spec.luau`: SfxCues 확정 목록에 `ClawLift` 추가(정확한 개수 비교라 안 하면 깨짐).
- **검증**: `rojo build -o build.rbxl` OK, `stylua --check src tests` OK, `selene src` 0 errors/0 warnings, `lune run tests` 1163 passed / 0 failed, `luau-lsp analyze`(LuauSolverV2) 0 에러.
  - 타입 체크 중 `ClawMachinePrizeLogic.pickClawTarget`의 `lo, hi`가 중첩 클로저(`pickCrowded`/`pickRandom`) 안에서 `number?`로 좁혀지지 않는 문제가 있었음 → `local lo: number, hi: number`로 명시 타입 선언해서 해결.
- **남은 것**: Studio 확인 AC9~AC16 (QA·사용자).
- **다음에 할 첫 단계**: QA가 스펙 "Studio 확인" 절차대로 `forceMapPlan = { "rotating-belt", "hot-plate", "claw-machine-prize" }`로 확인.
- **막힌 점**: 없음. 결정 기록에 질문 추가하지 않음 — 스펙 그대로 구현 가능했음.

## 설계 메모 (결정 기록 외 구현 세부사항)
- **좌표계**: 격자 중심이 origin 기준 로컬 `(0, 0, CENTER_Z=-40)`. Row는 -Z→+Z, Col은 -X→+X, 0~7. `Layout.colOf`/`rowOf`는 `tileLocalX`/`tileLocalZGrid`의 역함수라서 캐릭터 월드 위치 → 칸(row,col) 변환에 그대로 재사용(레이서가 서 있는 칸 계산, `racerTiles`).
- **집게가 과녁을 고르는 창(window) 표현**: `liftedTiles(centerRow, centerCol, size, gridSize)`에서 size가 짝수(2)면 `centerRow/Col`이 창의 **낮은 쪽 모서리**(그래서 `pickClawTarget`이 앵커를 `0..grid-size`로만 고르면 2×2는 항상 안 잘림 — AC5 "2×2는 항상 4칸"), size가 홀수(3)면 `centerRow/Col`이 **가운데 칸**(앵커가 `0..7` 전체라서 가장자리에서 진짜로 잘림 — AC5 "3×3은 4~9칸"). 두 가지 의미가 섞여 있지만 함수 안에서만 쓰는 내부 규약이라 혼동 없이 동작.
- **집게 일정 루프**: 정확한 절대 시각표(SkewerShowdown의 `grabTimes`처럼)가 아니라 "현재 webTime의 wave를 읽고 picking → lift(비동기) → `task.wait(wave.interval)`" 방식. 들어 올리는 애니메이션은 `task.spawn`으로 분리해서(스케줄링 스레드를 막지 않음) 주기가 거의 표대로 유지됨. 플레이테스트로 체감이 다르면 `CLAW_LIFT_TIME`/`CLAW_HOVER_TIME`이나 `Logic.clawWave`의 상수만 조정하면 됨(AC16).
- **연장전 기울기 방향**(D4): `ctx.rng:NextInteger(1,4)`로 행/열 × 부호 4가지 중 하나. `overtimeTilt`가 주는 `step.row`(1..8, 낮은 쪽부터)를 실제 격자 row/col로 바꾸는 매핑은 `dir.sign`에 따라 `gridIndex = step.row-1`(sign=1) 또는 `GRID_SIZE-step.row`(sign=-1).
- **인형 더미 장식이 칸과 같이 사라짐**: `Art.tileDecor(row,col)`를 `MapKit.buildDecor(specs, tilePart.CFrame, tilePart)`로 칸 파츠 자식에 바로 넣음(디자인은 SkewerShowdown 조각 장식과 같은 패턴). 칸을 `part:Destroy()`하면 자식 장식도 한 번에 사라짐 — 집게·연장전 모두 같은 `collapseLine`/`liftWindow`가 그냥 `Destroy`만 부르면 됨.
- **이동 감시**: 낙하는 전부 "바닥이 사라져서 자연히 떨어짐"이라 `MoveExempt.mark`를 안 씀(SkewerShowdown의 `grabSlice`와 같은 전례). AC15는 Studio에서 Output에 이동 감시 로그가 없는지 확인.

## Studio 확인 방법 (스펙 AC9~AC16)
1. `src/shared/Config.luau`의 `DEBUG.forceMapPlan = { "rotating-belt", "hot-plate", "claw-machine-prize" }`로 설정 → Studio Play (확인 후 **반드시 nil로 되돌리기**).
2. 결승 시작 5초 뒤부터 노란 경고 → 2×2 들어 올림(AC9). 30초·60초 지나면 주기 빨라지고 3×3으로 커지는지, 사람 몰린 쪽을 쫓는 느낌인지(AC10).
3. 빠른 연장전 확인: `DEBUG.overtimeAt = 15` 추가로 설정(확인 후 nil로 되돌리기). 2명(Clients and Servers)으로 들어가 연장전 배너 → 집게 멈춤 → 유리 상자 기울기 → 20초 뒤 전원 낙하, 더 늦게 떨어진 사람 우승(AC11). 혼자(Play Solo)도 연장전으로 끝나는지, 탈락 연출은 셰프 손인지(AC12).
4. 유리벽·천장이 카메라 시야를 가리지 않는지 다른 결승 맵과 비교(AC13).
5. `forceMapPlan`을 지우고(nil) 4명 이상 랜덤 판을 8판 이상 돌려 결승 맵이 여러 개(꼬치 쇼다운·인형뽑기 등, `tug-of-war-platform`은 `m5-18` 상태 확인 후) 나오는지(AC14).
6. 휴대폰 에뮬레이터로 경고 빗금 가독성, Output에 이동 감시 로그 없는지(AC15).
7. 재미 체감(AC16, 사용자) — 수치를 바꾸고 싶으면 `ClawMachinePrizeLayout`·`ClawMachinePrizeLogic`의 상수만 고치면 됨.
