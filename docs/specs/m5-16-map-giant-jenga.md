status: in-qa
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-16 — 새 Survival 맵: 와르르 나무 블록 (`giant-jenga`)

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §5.3(v0.6 1차 확장 맵 6개 — `giant-jenga`), §5.2 Survival(목표 인원 이하가 되면 종료, 시간 종료면 버틴 사람 전원 통과, 최대 60초)
- 레퍼런스: `docs/proposals/map-expansion-and-quality.md` §3-7("기존 Survival의 '전체가 같이 기운다'와 달리 부분마다 다르게 흔들려서 무게중심을 계속 옮겨야 한다")
- 참고 코드: `ChefBoard.luau`+`ChefBoardLogic.luau`(격자 칸, 보호 칸, 기울기 계산·서버 밀기, `MoveExempt` 없는 연속 밀기 판례), `HotPlateLogic.luau`(타일이 사라지는 패턴), `RamenRapidsLayout.luau`/`RamenRapidsLogic.luau`(정적 치수 Layout ↔ 동적 계산 Logic 분리 선례)
- 담당 개발 worktree: `m5-jenga` (Rojo 포트 **34877**)
- 공용 파일 수정 담당: 없음 (`SfxCues.luau`에 cue 이름 한 줄만 추가 가능 — m5-04의 `IkuraPop`과 같은 방식, CLAUDE.md의 "공용 파일" 목록에는 포함되지 않음)
- 의존: **m5-13 머지 후 시작** (껍데기 `src/shared/maps/GiantJenga.luau`, `inPool = false`를 덮어씀)
- **이 스펙이 고치는 파일**: `src/shared/maps/GiantJenga.luau`(껍데기 덮어쓰기, 끝나면 `inPool = false` 줄 삭제), 새 파일 `src/shared/maps/GiantJengaLayout.luau`, `GiantJengaLogic.luau`, `GiantJengaArt.luau`, `tests/map-giant-jenga.spec.luau`

## 목표
공중에 뜬 5×5 나무 블록탑 위에서 버틴다. 가운데 3×3은 뽑히지 않는 안전지대고, 바깥 테두리 16칸 아래에서는 셰프가 주기적으로 나무 블록을 하나씩 뽑아 간다. 블록이 뽑힌 자리는 그 칸만(그리고 그 칸에 맞닿은 칸들만) 내려앉고 기울어서, 탑 전체가 아니라 **부분마다 다르게 흔들린다** — 셰프의 도마(`chef-board`, 전체가 같은 각도로 같이 기움)와 달리 "어디가 약해졌는지 계속 눈으로 읽고 무게중심을 옮겨야" 하는 맵. 시간이 갈수록 블록을 뽑는 속도가 빨라진다.

## 범위
- 포함 (수치는 전부 기본값, `GiantJengaLayout`·`GiantJengaLogic` 상수):
  1. **탑 구조(격자)**: 5×5 = **25개 기둥**(칸, `i, j ∈ -2..2`), 한 칸 10 studs. 각 기둥은 **3단 나무 블록**(`LEVEL_MAX = 3`) 위에 플레이어가 서는 윗면 타일이 얹힌 모양. 가운데 3×3(`|i| ≤ 1, |j| ≤ 1`, 9칸)은 **보호 기둥**(절대 안 뽑힘, 항상 평평) — 안전지대.
  2. **블록 뽑기(`GiantJengaBlock` 태그)**: 바깥 테두리 16칸(보호 칸 제외) 중에서만 고른다.
     - 일정(`Logic.removalWave(elapsed)`, `Config.TimeLimit.Survival` = 60초 기준):

       | 경과 | 간격 | 한 번에 |
       |---|---|---|
       | 0 ~ 6초 | 없음(출발 여유) | — |
       | 6 ~ 18초 | 5.0초 | 1칸 |
       | 18 ~ 34초 | 3.5초 | 1칸 |
       | 34 ~ 48초 | 2.5초 | 2칸 |
       | 48 ~ 60초 | 1.5초 | 2칸 |
     - 고르는 규칙: 아직 뽑을 블록이 남은(레벨 > 0) 바깥 칸 중 남은 레벨이 많은 칸을 우선(가중 랜덤), 바로 전 틱에서 뽑은 칸은 되도록 피한다, 한 틱에 여러 칸이면 서로 다른 칸(중복 없이, 부족하면 있는 만큼만).
     - 한 번 뽑히면: **0.8초 삐걱이는 경고**(그 기둥만 흔들림, 소리 `BlockCreak`) → 레벨 -1. 레벨이 아직 1 이상이면 그 기둥 윗면이 `LEVEL_DROP`(4 studs) 가라앉고(부드럽게 이동) 모양이 안정. 레벨이 0이 되면 추가로 0.5초 흔들린 뒤 사라져(투명해지고 충돌 꺼짐) 그 자리는 완전히 뚫린 구멍이 된다(`TileVanish` 재사용).
  3. **국소 기울기(핵심 기믹)**: 매 프레임, 평평하지 않은(이웃과 높이가 다른) 바깥 칸마다 **그 칸만** 기운다 — `Logic.tiltFor(board, i, j)`가 그 칸의 4방향(존재하는) 이웃의 "가라앉은 정도"(`sunk = LEVEL_MAX - level`, 뚫린 이웃은 더 큰 값으로 취급) 차이를 모아 "낮은 쪽" 방향과 각도를 계산한다(최대 `MAX_TILT_DEG` 18도). 보호 칸과 평평한 칸은 기울지 않는다(`nil`). 기운 칸 위 플레이어는 `ChefBoardLogic` 밀기와 같은 방식(서버 가속, 최고 6 studs/s, 연속 밀기라 `MoveExempt` 없음)으로 낮은 쪽으로 밀린다.
  4. **판정**: 윗면(또는 가라앉은 자리)보다 30 studs 아래로 떨어지면 `ctx.eliminate`. 결승선 없음, Survival 종료(목표 인원 이하 즉시 종료, 60초 종료 시 전원 통과)는 `RoundLogic`이 처리 — 맵은 `ctx.eliminate`만 부른다. 점수(높이)는 기존대로 HumanoidRootPart Y.
  5. **스폰**: 25칸 중 가운데 정중앙 `(0,0)`을 뺀 **24칸** 위(5×5 격자 자체가 넓게 퍼져 있어 시작부터 바깥 칸에 설 수도 있음 — 처음엔 전부 평평해서 안전).
  6. **소리**(기존 cue 재사용): 뽑히는 경고 `BlockCreak`(신규, `SfxCues.Effects`에 한 줄 추가), 완전히 사라질 때 `TileVanish`(재사용).
  7. **아트**: 각 바깥 기둥을 실제 나무 블록 3단이 쌓인 모양으로(블록 1단 뽑힐 때마다 그 블록 하나가 빠지는 것처럼 보이게, 남은 블록 색은 나무색 변형), 가운데 3×3은 더 두껍고 짙은 색의 "받침대"처럼 보이게 해 안전지대임을 시각적으로 구분. 탑 아래 30~60 studs에 입 벌린 손님 얼굴(철판·도마와 같은 표현, Survival 낙하 → `Mouth` 연출). 배경은 공사장/목공소 느낌(톱밥, 나무 상자, 줄자 장식). `IntroCamera` 최소 3점(탑 전체 → 바깥 테두리 한 칸 클로즈업 → 가운데 안전지대).
  8. **순수 로직**: `GiantJengaLayout`(정적 치수 — 칸 25개 좌표, 보호 칸 판정, 이웃 찾기, 스폰 24곳), `GiantJengaLogic`(동적 — 보드 상태, 제거 일정·고르기·적용, 국소 기울기 계산).
- 제외:
  - 진짜 물리 기반 블록 와르르 붕괴(불안정한 캐릭터 상호작용) — 셰프의 도마처럼 앵커 + 서버 밀기로 흉내
  - 플레이어가 블록을 직접 뽑거나 미는 상호작용 (셰프만 뽑음)
  - 기둥이 다시 복구되는 것 (한 번 뽑히면 그 라운드 안에서 돌아오지 않음)

## 수용 기준
### 순수 로직 (lune 테스트, `tests/map-giant-jenga.spec.luau`)
- [ ] AC1: `GiantJengaLayout.columns()`가 25개(`i, j ∈ -2..2`), `isProtected(i, j)`가 `|i| ≤ 1 and |j| ≤ 1`일 때만 참(9개), `spawnOffsets()`가 24개이고 `(0,0)`을 제외한 나머지 칸과 정확히 일치한다. `MapTypes.validate` 통과(kind `Survival`, `overtime` 없어도 통과).
- [ ] AC2: `Logic.removalWave(elapsed)`가 위 표대로: 3 → `nil`, 6 → `{5.0, 1}`, 17.9 → `{5.0, 1}`, 18 → `{3.5, 1}`, 33.9 → `{3.5, 1}`, 34 → `{2.5, 2}`, 47.9 → `{2.5, 2}`, 48 → `{1.5, 2}`, 59 → `{1.5, 2}`.
- [ ] AC3: `Logic.removalTimes(60)`이 6초부터 시작해 각 구간의 간격대로 증가하는 시각 목록을 돌려주고 마지막 값이 60 미만이다.
- [ ] AC4: `Logic.pickColumns(board, previousKeys, count, rng)`를 시드 1~200으로 돌리면 보호 칸(9개)과 레벨 0(이미 뽑힌) 칸은 한 번도 고르지 않고, 대안이 있을 때는 `previousKeys`를 피하며, 돌려주는 개수가 `count` 이하이고 중복이 없다.
- [ ] AC5: `Logic.applyRemoval(board, columns)`이 고른 칸의 레벨을 1씩 줄이고 0 밑으로 내려가지 않으며, 보호 칸에 적용을 시도하면 레벨이 그대로다(바뀌지 않음, 방어적 동작 확인).
- [ ] AC6: `Logic.tiltFor(board, i, j)`: 전부 레벨 3(평평)이면 모든 칸이 `nil`. 한 이웃만 레벨 2(한 단계 가라앉음)면 `nil`이 아니고 각도가 `DEG_PER_UNIT`(6도)에 가깝고 축이 그 이웃 방향을 "낮은 쪽"으로 둔다. 한 이웃이 레벨 0(뚫림)이면 그 이웃이 레벨 2일 때보다 각도가 더 크다(최대 `MAX_TILT_DEG` 18도에서 캡). 보호 칸은 이웃 상태와 무관하게 항상 `nil`.
- [ ] AC7: `Logic.heightOf(board, i, j)`가 레벨 3/2/1에서 각각 0 / `-LEVEL_DROP` / `-2·LEVEL_DROP`을 돌려준다.
- [ ] AC8: 장식이 `MapKitLogic.validate` 통과, 파츠 600개 이하·파티클 8개 이하·조명 12개 이하, 시야 상자와 안 겹침. `GiantJenga.luau`에 `inPool = false` 줄이 없다(랜덤 Survival 풀에 들어감).
- [ ] AC9: 검증 5단계 통과 + 기존 `maps`·`round-logic` 테스트 통과.

### Studio 확인 (`forceMapPlan = { "rotating-belt", "giant-jenga", "soy-swamp", "skewer-showdown" }`)
- [ ] AC10: 처음엔 탑이 완전히 평평하고, 6초쯤부터 바깥 테두리 칸 하나가 삐걱이며 흔들린 뒤 살짝 가라앉는다. 가운데 3×3은 라운드 내내 움직이지 않는다.
- [ ] AC11: 블록이 빠진 칸 근처는 **그 주변만** 기울어서, 같은 시각에도 탑의 다른 부분은 다른 각도로(또는 평평하게) 보인다 — 셰프의 도마(전체가 한 번에 같은 각도로 기움)와 비교했을 때 확실히 다른 느낌인지 확인.
- [ ] AC12: 기운 칸 위에 서 있으면 낮은 쪽(특히 뚫린 구멍 쪽)으로 서서히 밀린다. 기둥이 완전히 뽑혀 사라지면 그 자리에 서 있던 플레이어가 자연스럽게 아래로 떨어져 탈락(손님 입 연출)한다.
- [ ] AC13: 48초 이후 블록 뽑기 속도가 눈에 띄게 빨라진다(1.5초마다 2칸).
- [ ] AC14: 남은 인원이 목표 이하가 되면 바로 끝나고, 60초를 버티면 그 시점에 살아 있는 사람 전원 통과(탑이 다 안 뚫려도 상관없음).
- [ ] AC15: 2개 방 동시 진행(Test → Clients and Servers) 시 블록 뽑힘·기울기가 자기 방 탑에서만 움직인다.
- [ ] AC16: 재미·난이도 확인(사용자, 친구 테스트): 4명 이상에서 60초 안에 적당히 떨어지는지, "억울하게 밀렸다"보다 "눈치껏 옮겨 다닐 수 있었다"는 느낌인지. 바꿀 수치를 알려 주면 `GiantJengaLogic` 상수만 고친다.

## 공용 파일 변경
- 없음. (`SfxCues.luau`의 `Effects` 목록에 `"BlockCreak"` 한 줄 추가 — m5-04/05/06이 `IkuraPop`/`OilSplash`/`FanGust`를 추가한 것과 같은 방식이고, CLAUDE.md의 "공용 파일" 목록에는 `SfxCues.luau`가 없어 병렬 제약 대상이 아니다. 실제 소리 id는 `SfxLibrary`에 없으면 무음이라 사용자가 고르기 전까지도 안전하다.)

## 사용자 작업 (스펙을 막지 않음)
- AC16 체감, `BlockCreak` 소리 id(USER-TODO에 추가). (선택) `assets/map-art/giant-jenga.rbxm`.

## 결정 기록
<!-- 날짜 · 질문 · 결정 · 누가 -->
- 2026-10-09 · D1 "부분마다 다르게 흔들린다"를 코드로 어떻게 표현할지 · 전체를 한 강체로 돌리는 셰프의 도마 방식 대신, **칸마다 독립적으로 `tiltFor(board, i, j)`를 계산**해 이웃과의 높이 차이로 그 칸만 기울게 함. 보호 칸(가운데 3×3)은 뽑히지도 기울지도 않아 "탑이 점점 낮아지며 발판이 줄어든다"는 느낌과 "항상 설 곳은 있다"는 안전장치를 동시에 만족. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-09 · D2 격자 크기·레벨 수 · 5×5(25칸)·3단(`LEVEL_MAX`)으로 셰프의 도마(9×9, 61칸)보다 작고 단순하게 잡음 — 이 맵의 재미는 칸 수가 아니라 "국소 기울기"에 있어서 격자를 키울 필요가 적고, 테두리 16칸 × 3단 = 48번의 제거 여유가 60초 일정(약 27~32회 소모)에 넉넉함. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-09 · D3 기울기를 격자 바깥 경계에도 적용할지 · 적용하지 않음 — 처음에 바깥 테두리 칸이 "모서리라서" 이웃이 적다는 이유만으로 기울면 라운드 시작부터 탑이 흔들려 보여 어색함. `tiltFor`는 **실제로 존재하는 이웃**끼리의 높이 차이만 보고, 격자 밖은 그냥 무시한다. **기본값으로 진행, 사용자 수정 가능** · planner
- 2026-10-09 · D4 뽑힌 자리에 경고를 둘지 · 셰프의 도마는 빨간 줄로 미리 경고하지만, 이 맵은 "셰프가 보이지 않는 곳에서 뽑는다"는 컨셉이라 사전 경고 없이 일정표대로 진행하되, **뽑히는 순간 0.8초 삐걱임**으로 "방금 그 칸이 흔들렸다"는 사후 신호만 준다(완전 무경고는 억울함만 남고, 사전 경고는 긴장감을 없앰). **기본값, 플레이테스트 후 조정** · planner

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
- **바뀐 파일**
  - `src/shared/maps/GiantJengaLayout.luau` (새 파일): 격자 치수 — `columns()`(25칸), `isProtected`, `spawnOffsets()`(24곳), `neighborsOf`, `key`. `LEVEL_MAX`(3)·`LEVEL_DROP`(4)·`FALL_DEPTH`(30)·`CELL_SIZE`(10).
  - `src/shared/maps/GiantJengaLogic.luau` (새 파일): 보드 상태(`newBoard`), 제거 일정(`removalWave`/`removalTimes`, 스펙 표 그대로), 고르기·적용(`pickColumns`/`applyRemoval`), 국소 기울기(`tiltFor`, `DEG_PER_UNIT` 6도·`MAX_TILT_DEG` 18도), 높이(`heightOf`).
  - `src/shared/maps/GiantJengaArt.luau` (새 파일): 블록 색(`blockColor`)·받침대 색, 공사장/목공소 배경 장식(손님 얼굴 3개, 상자·톱밥·줄자·작업등), `introCamera`(3점: 탑 전체 → 바깥 테두리 → 가운데), `courseVolume`.
  - `src/shared/maps/GiantJenga.luau` (덮어씀): `inPool = false` 줄 삭제(랜덤 Survival 풀에 들어감). 칸마다 Top 판정 타일(`GiantJengaColumn` 태그) + 바깥 칸은 블록 3단(`Block1~3`, 하나씩 투명해져 빠짐), 보호 칸은 받침대 하나. 매 프레임 `Logic.tiltFor`로 칸마다 독립적으로 기울이고, 그 칸 위 플레이어를 낮은 쪽으로 최고 6 studs/s로 밂(연속 밀기라 `MoveExempt` 없음). 블록 제거: 0.8초 삐걱임(`BlockCreak`) → 레벨 -1 → 레벨 > 0이면 0.3초로 부드럽게 가라앉고, 레벨 0이면 추가 0.5초 흔들린 뒤 `TileVanish`로 사라짐.
  - `src/shared/SfxCues.luau`: `Effects`에 `"BlockCreak"` 한 줄 추가.
  - `src/shared/SfxLibrary.luau`: `BlockCreak` 항목 추가 (id는 사용자가 고를 때까지 무음 — `docs/USER-TODO.md`에 추가 필요, docs-writer 단계에서 반영 요청).
  - `tests/map-giant-jenga.spec.luau` (새 파일): AC1~AC8 전부 커버 (22개 테스트).
  - **기존 테스트 업데이트** (giant-jenga가 "m5-13 껍데기"에서 "실제 랜덤 풀 맵"으로 바뀌며 깨진 것들 — 내가 처음으로 m5-13 껍데기 하나를 졸업시켰어요):
    - `tests/sfx-library.spec.luau`, `tests/camera-priority.spec.luau`: cue 개수 갱신 (BlockCreak 추가).
    - `tests/m4-foundation.spec.luau` (AC6), `tests/maps.spec.luau` (m5-01 AC7): 맵 풀 개수/목록이 Survival 2→3, 전체 6→7로 늘어난 것 반영.
    - `tests/m5-03-foundation.spec.luau`: `SHELLS` 목록·`expected` 표에서 giant-jenga 제거(더는 껍데기 아님), `infos()` 6→7개로 갱신.
    - `tests/m4-12-hardening.spec.luau`: 강제 플랜 하나에 `giant-jenga`를 넣어서 "풀의 맵을 모두 한 번 이상 써요" 조건을 다시 만족시킴.
- **결정/설계 메모** (스펙에 수치가 명시 안 된 부분, 스펙 "기본값, 사용자 수정 가능" 방침을 따름):
  - `tiltFor`의 "가라앉은 정도" 차이 계산은 칸 자신의 레벨(sunk)을 기준으로 이웃과의 차이를 벡터로 더하는 방식 (뚫린 이웃은 `LEVEL_MAX + 1`로 쳐서 레벨 2 이웃보다 더 크게 기울게 함). AC6 그대로 테스트로 확인.
  - 기울기 밀기 가속도(`TILT_PUSH_ACCEL = 18`)는 수치 명시가 없어 `ChefBoardLogic`과 같은 값을 재사용.
  - 블록 3단은 바깥 칸마다 실제 Part 3개(`Block1~3`)로 만들고, 레벨이 줄 때마다 위에서부터 하나씩 투명해지고 충돌을 끔 — "블록 하나가 빠지는 것처럼" 보이게 함. 보호 칸은 블록 구분 없이 두껍고 짙은 받침대 하나.
  - 판정은 ChefBoard와 같은 패턴으로 origin 기준 Y만 봄 (칸마다 다른 "가라앉은 자리" 기준으로 따로 30을 빼지 않음) — 가장 많이 가라앉아도 -8이라 30 studs 여유 안에서 결과가 같음.
- **Studio 확인 방법** (`docs/DEV-SETUP.md` 패턴): `Config.DEBUG.forceMapPlan = { "rotating-belt", "giant-jenga", "soy-swamp", "skewer-showdown" }`로 설정하고 Studio Test 실행. AC10~AC16은 사용자 확인 필요 (코드 쪽에서는 손 댈 게 없음) — 특히 AC11(국소 기울기가 셰프의 도마와 다르게 느껴지는지)·AC16(재미·난이도)은 반드시 플레이테스트로.
- **검증**: `rojo build`·`stylua --check`·`selene`·`lune run tests`(1174 passed, 0 failed)·`luau-lsp analyze`(exit 0) 전부 통과.
- **남은 이슈**: 없음 (코드 레벨). Studio 확인(AC10~16)은 QA·사용자 몫.
- **worktree**: `/Users/rubinjang/sushi/sushi-survival-race/.claude/worktrees/agent-a3228e567e64d1418`, 브랜치 `worktree-agent-a3228e567e64d1418`. 메인 세션이 머지.
