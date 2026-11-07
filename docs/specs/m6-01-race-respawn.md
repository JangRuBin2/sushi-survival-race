status: in-qa
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m6-01 — Race 부활 + 부활 카운트다운

- 마일스톤: M6 (플레이테스트 반영)
- GDD 근거: `docs/GDD.md` v0.8 — §4(라운드 진행 "Race 부활"), §4.1(결승 진출 2명 보장 메모), §7(탈락 연출 표), §10(UI "Race 부활 카운트다운")
- 요청: 사용자 2026-11-07 "정해진 인원이 통과하기 전까지는 다시 살아나서 도전할 수 있도록 개선해줘. 카운트 다운도 화면에 표시하고"
- 공용 파일 수정: `src/shared/Config.luau`(`Config.Race`), `src/shared/Attributes.luau`(`RespawnAt`). `Remotes.luau`·`Types.luau`·init 파일은 안 바꿈(리모트 개수 그대로).

## 결정 기록 (사용자 답변, 2026-11-07)
- Q1 부활 범위 → **Race만**. Survival은 "목표 인원만 남을 때까지 버티기"라 부활하면 안 끝나고, 결승은 1명이 남아야 끝나서 제외.
- Q2 카운트다운 → **부활까지 남은 시간**(라운드 남은 시간 "⏱ N초"는 이미 있음).
- Q3 부활 위치 → **출발점**(체크포인트 없음).

## 규칙
1. 결승이 아닌 Race 라운드(`RoundLogic.modeFor` = `"Race"`)에서 아직 레이서인 사람이 낙하(`ctx.eliminate`)·리셋·사망·캐릭터 교체를 하면 탈락하지 않고 **`Config.Race.RespawnDelay`(3초, 기본값) 뒤 처음 받은 스폰**에서 다시 달린다. 소개 중에도 같다(출발 전이면 잠긴 채 세움).
2. 낙하: 살아 있는 캐릭터를 바로 출발점에 세우고 고정(`Anchored`, 이동 0)했다가 시간이 되면 푼다. 리셋·사망: `RespawnTime`(1초) 뒤 로비에 생긴 새 캐릭터를 시간이 되면 출발점으로 옮긴다.
3. 기다리는 동안 Player 속성 `Attributes.RespawnAt`(서버 시각)을 단다 → 클라이언트 `RespawnCountdown`이 화면 가운데 "다시 출발까지" + 3 → 2 → 1 + "출발점에서 다시 달려요!". 다시 출발·통과·탈락·라운드 닫힘에 지운다. 속성은 화면 표시용이고 판정에 안 쓴다.
4. 기다리는 동안 맵 `ctx.getRacers()`·잡기(`activeRoomOf`)·이동 감시(`placedRoomOf`)에 레이서로 안 보이고, `ctx.eliminate`는 무시. 레이서 수(`RoundLogic`)에는 그대로 남는다.
5. 정원이 차는 순간 `RoundLogic.pass`가 라운드를 끝내고 남은 사람(부활 대기자 포함)을 진행도 순 탈락(`Timeout` 연출). 90초 시간 종료면 진행도 상위로 빈 자리를 채운다 — 부활 대기 중이면 출발점 진행도.
6. 방·게임을 나감, 캐릭터가 끝내 안 생김 → 부활 없이 바로 탈락(`queueFall(..., force = true)`).
7. `Config.Race.Respawn = false`면 예전처럼 탈락(`RoundLogic.respawns`가 false).

## 구현
- 순수: `RoundLogic.respawns(round, userId, enabled)`, `RespawnCountdownLogic.secondsLeft(respawnAt, now)`(지나도 1에서 멈춤, 숫자 아니면 nil).
- 서버: `RoundService` — `queueFall`의 부활 분기, `startRespawn`, 배치 공용 `standOn`, 감시 다시 달기(`unwatchOf`), `clearRespawn`.
- 클라이언트: `src/client/ui/RespawnCountdown.luau`(HudController.start에서 켬), 문구 `hud.respawn.title`·`hud.respawn.sub`(ko/en).
- 테스트: `tests/m6-01-race-respawn.spec.luau`, `camera-priority`(Attributes 20개)·`movement-guard`(배치 알림이 `standOn`에) 갱신.

## 수용 기준 (Studio 확인 — DEV-SETUP 3-16)
- AC1 Race에서 코스 밖으로 떨어지면 탈락 연출 없이 출발점에 멈춘 채 가운데에 3 → 2 → 1, 그 뒤 바로 달릴 수 있다.
- AC2 Race에서 리셋(Esc → R)해도 같은 카운트다운 뒤 출발점에서 다시 달린다.
- AC3 통과 정원이 차면 부활을 기다리던 사람을 포함해 남은 사람이 탈락하고 카운트다운이 사라진다.
- AC4 Survival·결승에서는 예전처럼 떨어지면 탈락이다.
- AC5 부활 직후 이동 감시 경고·되돌림이 없다(출력 창 `[MovementGuard]`).
- AC6 휴대폰 배치에서도 카운트다운 글씨가 잘리지 않는다.
