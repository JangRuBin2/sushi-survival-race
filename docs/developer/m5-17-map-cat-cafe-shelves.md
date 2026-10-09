# m5-17 map-cat-cafe-shelves — 개발 작업 기록

## 2026-10-09 — 구현 완료, in-qa (최신)
- **worktree**: `/Users/rubinjang/sushi/sushi-survival-race/.claude/worktrees/agent-a403f3f4c1e682250` (브랜치 `worktree-agent-a403f3f4c1e682250`). push는 안 함 — 메인 세션이 머지.
- **끝난 것**: 스펙 범위 전부 (순수 로직 + Roblox 빌드/스타트 + 아트 + cue 3개).
  - `src/shared/maps/CatCafeShelvesLayout.luau`: 3단 캣타워 치수(테두리 1·2단 + 꽉 찬 3단), `shelves()` 9개, `spawnOffsets()` 24개(1단 전용), `outerSideOf`/`topYOf`.
  - `src/shared/maps/CatCafeShelvesLogic.luau`: `climbGap`(1→2, 2→3 모두 4), `ballOffset`(사인파 왕복, 선반마다 위상 다름), `isHit`(2.2 이하 맞음), `outwardDirection`(중심→점 단위벡터, 중심 일치 시 고정 기본값), `pawInterval`(그레이스 8초 → 5 → 3.2 → 2초), `pickShelf`(occupant 가중 랜덤, Top 제외, 연속 금지, 후보 없으면 nil).
  - `src/shared/maps/CatCafeShelvesArt.luau`: 파스텔 카페 배경(벽·창문·햇살 조명 2·먼지 파티클 2), 장식 기둥 3, 발자국 8, 바구니·실뭉치 4쌍, 2단 쿠션 4, 3단 캣방석, 간판, `introCamera()` 4점. 파츠 ~39개(예산 600 이하), 조명 2(≤12), 파티클 2(≤8).
  - `src/shared/maps/CatCafeShelves.luau`: 선반·공(9개씩)·스폰(24개) 빌드, HotPlate 스타일 단일 레이캐스트로 "서 있는 선반" 판정 → 공 맞음(along 차)·고양이 발 occupant 집계를 같은 Heartbeat 틱에서 처리. 넉백은 `SoySwampHazards.launch`와 같은 LinearVelocity 홀드 방식을 이 파일 안에 재구현. `MoveExempt.mark`(공 1.2초/고양이 발 1.6초). `inPool = false` 줄 삭제.
  - `src/shared/SfxCues.luau`·`src/shared/SfxLibrary.luau`: `CatToyBounce`·`CatPawWarn`·`CatPawSwipe` 추가(무음, id는 사용자 몫).
  - `tests/map-cat-cafe-shelves.spec.luau`: AC1~AC10 전부 (12개 케이스).
  - `docs/USER-TODO.md` A2에 소리 3개 추가.
- **기존 테스트 수정 (맵 개수 하드코딩)**: cat-cafe-shelves가 껍데기(inPool=false)에서 실제 풀 맵으로 바뀌어 다음을 맞게 고침 — `tests/camera-priority.spec.luau`(SfxCues 목록), `tests/maps.spec.luau`(풀 6→7), `tests/m4-foundation.spec.luau`(Survival 2→3), `tests/m5-03-foundation.spec.luau`(SHELLS 목록에서 제거, infos() 6→7, 기대표에서 행 삭제), `tests/m4-12-hardening.spec.luau`(5판 강제 플랜 중 하나에 포함해 전체 맵 풀을 덮게 함). `docs/GDD.md`는 건드리지 않음.
- **검증**: `rojo build -o build.rbxl` OK, `stylua --check src tests` OK, `selene src` 0 errors/0 warnings, `lune run tests` 1164 passed / 0 failed, `luau-lsp analyze`(LuauSolverV2) 종료 코드 0.
- **남은 것**: Studio 확인 AC12~AC18 (사용자 — `docs/DEV-SETUP.md` 패턴, 스펙 "개발 메모"에 절차 적어 둠), 소리 3개 id 선택, QA.
- **다음에 할 첫 단계**: QA가 스펙 수용 기준대로 검증(특히 Studio AC12~AC18), 재미 체감(AC18)에 따라 `CatCafeShelvesLogic`의 `BALL_KNOCK_*`/`PAW_KNOCK_*` 상수만 조정.
- **막힌 점**: 없음. 스펙과 다르게 구현한 곳 없음 — "주황빛/고양이 발 그림자" 중 전자(선반 색 변경)만 구현했는데, 스펙 문구가 "/"(또는)라 수용 기준 범위 안이라고 판단함.
