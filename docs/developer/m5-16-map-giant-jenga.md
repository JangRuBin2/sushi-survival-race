# m5-16 map-giant-jenga — 개발 작업 기록

## 2026-10-09 — 구현 완료, in-qa (최신)
- **worktree**: `/Users/rubinjang/sushi/sushi-survival-race/.claude/worktrees/agent-a3228e567e64d1418`, 브랜치 `worktree-agent-a3228e567e64d1418`. 메인 세션이 머지 (push는 안 함).
- **끝난 것**: 스펙 범위 1~8 전부.
  - `src/shared/maps/GiantJengaLayout.luau`: 격자 25칸(`i, j ∈ -2..2`), 보호 칸(가운데 3×3), 스폰 24곳, 이웃 찾기.
  - `src/shared/maps/GiantJengaLogic.luau`: 보드 상태(`newBoard`), 제거 일정(`removalWave`/`removalTimes`, 스펙 표 그대로 6→18→34→48→60), 고르기(가중 랜덤, `previousKeys` 회피)·적용(`pickColumns`/`applyRemoval`), 국소 기울기(`tiltFor`, 이웃별 "가라앉은 정도" 차이 벡터 합, 최대 18도), 높이(`heightOf`).
  - `src/shared/maps/GiantJengaArt.luau`: 블록 색·받침대 색, 공사장/목공소 배경(손님 얼굴 3개, 나무 상자·톱밥·줄자·작업등), IntroCamera 3점, 시야 상자.
  - `src/shared/maps/GiantJenga.luau`: `inPool = false` 삭제(랜덤 Survival 풀 합류). build에서 칸마다 Top 판정 타일(`GiantJengaColumn` 태그) + 바깥 칸은 블록 3단(`Block1~3`, 레벨 떨어질 때마다 하나씩 투명·충돌 끔), 보호 칸은 받침대 하나. start에서 매 프레임 `Logic.tiltFor`로 칸마다 **독립적으로** 기울이고(셰프의 도마처럼 전체가 같이 기우는 게 아니라 칸 단위), 그 칸 위 플레이어를 낮은 쪽으로 최고 6 studs/s 밂(연속 밀기, `MoveExempt` 없음). 블록 제거 연출: 0.8초 삐걱임(`BlockCreak`) → 레벨 -1 → 레벨 > 0이면 0.3초로 부드럽게 가라앉음 / 레벨 0이면 추가 0.5초 흔들린 뒤 `TileVanish`로 사라짐.
  - `src/shared/SfxCues.luau`·`src/shared/SfxLibrary.luau`: `BlockCreak` cue 추가(무음, 사용자가 id 고를 때까지).
  - `tests/map-giant-jenga.spec.luau` 22개 (AC1~AC8).
- **기존 테스트 업데이트** (giant-jenga가 "m5-13 껍데기"에서 "실제 랜덤 풀 맵 7번째"로 바뀌며 깨진 것들 — 9개 껍데기 중 내가 처음 졸업시킨 사례):
  - `tests/sfx-library.spec.luau`, `tests/camera-priority.spec.luau`: cue 개수(BlockCreak 추가분) 갱신.
  - `tests/m4-foundation.spec.luau`(AC6), `tests/maps.spec.luau`(m5-01 AC7): 맵 풀 개수 Survival 2→3, 전체 6→7로 갱신.
  - `tests/m5-03-foundation.spec.luau`: `SHELLS` 목록·`expected` 표에서 giant-jenga 제거, `infos()` 6→7개로 갱신.
  - `tests/m4-12-hardening.spec.luau`: 강제 플랜 하나에 `giant-jenga`를 넣어 "풀의 맵을 모두 한 번 이상 써요" 조건 유지.
- **검증**: `rojo build` OK, `stylua --check` OK, `selene` 0/0/0, `lune run tests` 1174 passed / 0 failed, `luau-lsp analyze` exit 0.
- **남은 것**: Studio 확인 AC10~AC16(특히 AC11 "셰프의 도마와 느낌이 다른지", AC16 재미·난이도)과 QA.
- **다음에 할 첫 단계**: QA가 스펙 수용 기준대로 검증(특히 Studio 확인 항목은 QA·사용자 몫으로 넘김). 난이도 조정이 오면 `GiantJengaLogic`의 제거 일정·기울기 상수만 바꾸면 됨.
- **막힌 점**: 없음. 스펙과 다르게 구현한 부분 없음(결정 기록에 적힌 D1~D4 기본값 그대로).
- **메모**:
  - m5-13이 만든 다른 8개 껍데기(ikura-bombs, tempura-pot, dessert-fridge, bouncy-castle-maze, lantern-bridge, cat-cafe-shelves, tug-of-war-platform, claw-machine-prize)는 여전히 `inPool = false`인 채로 남아 있어, 그 스펙(m5-04/05/06/14/15/17/18/19)이 끝날 때마다 이번에 고친 "foundation" 테스트들(`tests/m5-03-foundation.spec.luau`의 `SHELLS` 목록과 `expected` 표, `tests/maps.spec.luau`/`tests/m4-foundation.spec.luau`의 맵 풀 개수, `tests/m4-12-hardening.spec.luau`의 `FORCED_PLANS`)을 똑같은 방식으로 또 손봐야 함. 다음 개발자를 위해 패턴을 남겨 둠.
  - `tiltFor`는 칸 자신의 레벨(sunk)을 기준으로 이웃과의 차이를 벡터로 더하는 방식이고, 뚫린(레벨 0) 이웃은 `LEVEL_MAX + 1`로 쳐서 레벨 2 이웃보다 더 크게 기울게 함(AC6).
  - `TILT_PUSH_ACCEL = 18`은 스펙에 수치가 없어 `ChefBoardLogic`과 같은 값을 재사용.
