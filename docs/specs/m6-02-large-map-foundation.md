status: qa-passed
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m6-02 — 대형 맵 기반 (방 32·40명, 인원 맞춤 판 계획)

- 마일스톤: M6
- GDD 근거: v0.9 — 3.2(방 인원), 3.3(라운드 수), 4.1(통과 비율), 5.1(맵이 받는 인원), 11.2(서버 최대 인원)
- 제안서: `docs/proposals/large-maps.md`, 근거 자료 `docs/REFERENCE-large-maps.md`
- 공용 파일: `Config.luau`(`Room.MaxPlayerOptions`·`Rules.LargeMinPlayers`·`Rules.LargePassRatios`·`Maps`), `maps/MapTypes.luau`(`capacity`·`minPlayers`), `maps/init.luau`(풀 정보). **이 스펙만** 수정 — 맵 스펙(m6-03~07)은 `maps/init.luau`에 자기 줄 하나만 더해요.

## 결정 기록 (2026-11-08)
사용자가 "개발 진행해"로 승인하고 제안서 Q1~Q5에는 따로 답하지 않아 **권장안을 채택**했어요(바꾸려면 말해 주면 Config만 고치면 돼요).
- Q1 방 인원 → 32·40 추가 (4/8/12/16/24/32/40, 기본 12)
- Q2 25~40명 → 4라운드, 통과 0.60 · 0.45 · 0.40
- Q3 플레이스 최대 인원 → Match 40, Lobby 50 (`docs/USER-TODO.md` C2)
- Q4 맵 → 5개 전부 (m6-03 카운터, m6-04 도시락, m6-05 팬트리, m6-06 회전 원판, m6-07 연회상)
- Q5 24명 이하 방에서도 대형 맵 → 나옴(예상 인원 12명 이상인 라운드)

## 구현
1. `Rules.passRatios(roundCount, startCount?)`, `Rules.qualifyCount(..., startCount?)` — 4라운드 + 시작 25명 이상이면 `LargePassRatios`. startCount 없이 부르면 예전과 같아요.
2. `Rules.capacityOf`, `Rules.fitsCount(map, upper, expected)`, `Rules.roundCounts(start, kinds)` — expected = 목표대로 줄어든 인원, upper = Race는 목표, Survival은 시간 종료 전원 통과라 그대로.
3. `Rules.buildRoundPlan(roundCount, pool, rng, startCount?)` — 라운드마다 ① 인원·최소 인원이 맞는 맵 → ② 스폰만 맞는 맵 → ③ 예전 규칙. `MatchService`가 `startCount`를 넘겨요.
4. `MapTypes`: `capacity`·`minPlayers`(양의 정수, minPlayers ≤ capacity), `Maps.infos()`에 실어요.
5. 기존 맵 8개의 `MAX_PLAYERS`를 `Config.Maps.StandardCapacity`(24)로 — 방 최대 인원이 40이 돼도 스폰 24개 그대로.
6. `PlacePayload.MAX_MEMBERS` 40, `MapKitLogic.BUDGETS.Large` (파츠 2200·파티클 20·조명 32·그림자 2·움직임 120, 기본값), `MapKit` 런타임 경고는 Large 기준.
7. UI: 로비 인원 버튼은 `UiLayout.gridRows`로 이미 줄바꿈(7개 → 화면 폭에 따라 2줄), 대기실·순위표·관전 목록은 스크롤 목록이라 40줄 OK — Studio 확인 항목.

## 수용 기준
- AC1 방 만들기 창에 32·40 버튼이 보이고 휴대폰에서도 잘리지 않음 (Studio)
- AC2 40명 시작 → 1라운드는 대형 Race, 40 → 24 → 11 → 4 (테스트 `m6-02-large-foundation`)
- AC3 11명 이하 예상 라운드에는 대형 맵이 안 나옴, 24명 방 1·2라운드에는 나올 수 있음 (테스트)
- AC4 기존 맵 21개 스폰 24개 그대로 (기존 테스트)
- AC5 40명 텔레포트 매니페스트 통과 (`PlacePayload.MAX_MEMBERS`)

## QA
- 2026-11-12 QA 통과(`docs/qa/m6-02-large-map-foundation.md`): P0~P2 없음, P3 2개(강제 플랜이 맵 인원을 안 봄, 다이너마이트 방 상한 튜닝 메모). AC2~AC5 테스트 통과(`tests/m6-02-qa.spec.luau` 7개 — 실제 풀 판 계획 4~40명, 26개 맵 build 스폰 수 = capacity), AC1 Studio 사용자 확인 필요.
