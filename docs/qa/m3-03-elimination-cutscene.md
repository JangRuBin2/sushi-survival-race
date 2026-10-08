# QA — m3-03 탈락 연출 ("먹혔다!")

- 스펙: `docs/specs/m3-03-elimination-cutscene.md`
- 검증 커밋: `3401317` (`m3-03-elimination`) + `origin/main` 병합 `9dbb4a3` (충돌 없음)
- 결과: **통과 (P0/P1 없음, P2 1건·P3 3건)** → 스펙 상태 `qa-passed`. Studio 확인(AC6~AC13)은 사용자 확인 필요.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 통과 (0 errors, 0 warnings) |
| `lune run tests` | 통과: 262 passed, 0 failed (병합 후 기존 246 + QA 추가 16) |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `elimination-cutscene.spec.luau` `AC1: 연출 종류` 외 2개 + QA `variantFor: 결승이면 …`, `variantFor: 결승이 아니면 Survival 낙하만 Mouth`, `isFinalRound: …` |
| AC2 | 통과 | `AC2: 낙하·리셋만 연출` + QA `shouldPlay: Fall·Reset 말고는 전부 false` |
| AC3 | 통과 | `AC3` 3개 + QA `linesFor` 3개, `pickLine: 목록의 모든 위치를 고를 수 있고 nil이 나오지 않아요`, `기본 스킨은 전용 대사가 있어요` |
| AC4 | 통과 | `AC4: 동시 월드 연출 한도 6` + QA `canStartWorld: 6개 재생 중 7번째는 막히고 …` |
| AC5 | 통과 | 위 자동 검증 |
| AC6 | 사용자 확인 필요 | 체크리스트 2. 코드상 본인은 `CameraDirector.request("Elimination", 40)` + 스탬프(`EliminationCutsceneController.luau:326-329, 397-408`), HUD 문구 생략(`HudController.luau:49`), 3초 뒤 release → SpectateController가 같은 3초 뒤 Spectate(10) 요청 |
| AC7 | 사용자 확인 필요 | 체크리스트 3. 다른 사람은 카메라 요청 없음(`isMe`일 때만), 캐릭터 로컬 숨김(`:225-254`) |
| AC8 | 사용자 확인 필요 | 체크리스트 4 |
| AC9 | 사용자 확인 필요 | 체크리스트 5 |
| AC10 | 사용자 확인 필요 | 체크리스트 6. **B1 참고** — 결승의 마지막 탈락자 연출은 Victory로 즉시 지워진다 |
| AC11 | 사용자 확인 필요 | 체크리스트 7. 코드상 `cause = "Left"` → `shouldPlay` false (`:426`) |
| AC12 | 사용자 확인 필요 | 체크리스트 8. 코드상 모든 인스턴스가 연출별 Cleanup에 있고 Victory·매치 종료에 `stopAll` (`:411-423`) |
| AC13 | 사용자 확인 필요 | 체크리스트 9. `TextScaled` + `UITextSizeConstraint`, 스탬프 `UISizeConstraint` 460×220 |

요약: 순수 로직 AC1~AC5 통과(5/5), Studio AC6~AC13 사용자 확인 필요(8). 실패한 기준 없음.

## 코드 리뷰

### 파일 범위
`git diff origin/main --name-only` = 스펙이 지정한 6개(`EliminationCutsceneController`, `EliminationCutsceneScreen`, `CutsceneProps`, `EliminationCutsceneLogic`, `tests/elimination-cutscene.spec.luau`, `HudController`) + 스펙·개발 기록 문서. 공용 파일(`Config`, `Remotes`, `Types`, `maps/init`, `default.project.json`)과 서버 코드는 바뀌지 않았다. `HudController`는 탈락 문구 1곳(`:48-51`)만 바뀌었다.

### 판정이 서버에 있는가
- 연출은 `PlayerResult`(서버 방송)와 `MatchPhase`·`RoomUpdated`만 읽는다. 연출 3파일에 `FireServer`/`InvokeServer`/`SetAttribute`/`Remotes.fn`이 없다 (QA 정적 테스트).
- 캐릭터 고정·로비 이동은 그대로 서버(`EliminationService.luau:73-92`). 클라이언트는 `LocalTransparencyModifier`만 바꾼다 → 다른 클라이언트·서버에 영향 없음.

### 카메라 (CameraDirector)
- 본인: `Elimination`(40)을 요청, 매 프레임 `isActive(OWNER)`일 때만 CFrame을 바꾼다. 끝(3초)·Victory·매치 종료에 release.
- SpectateController는 본인 탈락 때 `inCutscene = true`로 3초 기다렸다가 Spectate(10)를 요청한다. 순서가 어떻게 돼도 40 > 10이라 연출이 이기고, release 뒤 관전이 이어진다. Intro(30)는 결과 단계(3초) 뒤라 겹치지 않고, VictoryCutscene(50)은 더 높다. 문제 없음.
- 다른 사람이 탈락할 때는 카메라 요청이 없다 (AC7 "B·C 카메라 그대로").

### 정리
- 연출 하나당 `Cleanup` 하나: 숨김 복원 함수, 스탬프 제거, Model(인형·소품·방울·말풍선 BillboardGui 포함), RenderStepped 연결, 카메라 release. `stop()`은 한 번만 돈다(`stopped` 플래그).
- `stopAll`은 목록을 복사한 뒤 멈춰서 순회 중 삭제 문제가 없다. `Workspace.EliminationCutscenes` 폴더 자체는 남지만 비어 있다 (AC12 기준 "소품이 남지 않음"에는 맞음).
- 간장 방울은 Anchored=false·CanCollide=false라 떨어지다가 Model과 함께 지워진다.
- 한도 초과로 월드 연출 없이 숨김만 하는 경우에도 3초 뒤 복원된다.

### 숨김/복원
- 숨김은 매 프레임 다시 적용(기본 스크립트가 되돌려도 유지), 복원은 0으로 되돌리고 대상 참조를 버린다. 캐릭터가 사라졌으면 아무것도 안 한다.
- 탈락 위치에서 40스터드 안의 캐릭터만 숨긴다 (리셋 뒤 새 캐릭터 보호). 서버 고정 위치와 같으므로 낙하에서는 항상 숨겨진다.

### 동시 재생 한도
- 남의 월드 연출만 `worldCount`에 센다(`isWorld = world and not isMe`). 본인은 항상 재생. 7번째부터는 숨김만. 스펙 범위 6과 같다.

### cause nil (m3-09로 넘긴 것)의 영향
- 시간 종료·정원 마감 탈락은 연출·숨김·카메라 없음, HUD "탈락했어요 (n등)" 문구가 그대로 뜨고 3초 뒤 자동 관전 (SpectateController는 cause와 상관없이 3초 기다림). 동작에 빈틈은 없다. 다만 Race에서 가장 흔한 탈락 방식이라 "남이 먹히는 걸 보는 웃음"이 이 경우엔 없다 → 기획 결정 (B4).

## 버그
P0/P1 없음.

### [P2] B1 결승의 마지막 탈락자 연출이 Victory 방송에 바로 지워짐 (2명 결승이면 셰프 손 연출이 한 번도 안 보임)
- 재현: 결승(회전 꼬치 쇼다운)에 2명 진출. B가 떨어져 A가 우승.
- 기대: B가 떨어지면 셰프 손 연출(AC10)과 B 화면의 "먹혔다! 2등" 스탬프가 보인다 (최소한 B 본인에게 등수가 한 번은 보인다).
- 실제(코드상): 서버는 마지막 낙하 묶음을 처리한 직후 같은 흐름에서 `Won` → `MatchPhase Victory`를 방송한다 (`MatchService.luau:232-249`, 대기 없음). 클라이언트는 Victory를 받는 순간 `stopAll()`(`EliminationCutsceneController.luau:418-423`) → 연출·스탬프가 한 프레임 안에 사라진다. 또 HUD는 낙하·리셋 탈락 문구를 생략하므로(`HudController.luau:49`) B 본인은 개인 결과 문구도 못 본다 (Victory 화면 순위표만 남음). 3명 이상 결승이면 먼저 떨어진 사람의 연출은 정상.
- 원인: 스펙 범위 7("Victory가 시작되면 모두 지움")과 AC12 "연출 도중 우승이 결정돼도 남지 않는다"를 그대로 구현한 결과라 **구현 버그가 아니라 스펙 간 충돌**이다. 결승은 2명 진출이 흔하므로(결승 진출 2명 보장) AC10을 Studio에서 확인하려면 3명 이상이 결승에 가야 한다.
- 제안(기획 결정): (a) Victory 시작 때 지우되 서버가 마지막 탈락 뒤 `EliminationCutscene`만큼 기다렸다가 Victory로 가기 (m3-05 우승 연출·m3-09 통합과 같이), 또는 (b) Victory 때 월드 연출은 지우되 본인 스탬프는 남기기. 사용자/기획 확인 필요.
- 위치: `src/client/fx/EliminationCutsceneController.luau:418-433`, `src/client/ui/HudController.luau:49`, `src/server/MatchService.luau:232-249`

### [P3] B2 낙하 연출이 코스보다 20~40스터드 아래에서 재생됨
- 재현: 회전 벨트·간장 늪·꼬치 쇼다운에서 코스 밖으로 떨어짐.
- 실제(코드상): `position`은 서버가 낙하 판정한 순간의 루트 위치라 코스 아래 깊은 곳이다 (꼬치 쇼다운 `FALL_DEPTH = 20`, 간장 늪 40, 회전 벨트 `VOID_DROP`). 본인 카메라는 따라가므로 문제없지만, 달리는 B·C 화면에서는 시야 밖이라 거의 안 보일 수 있다 (AC7 "A가 보이는 곳이면"으로 스펙상 허용). 젓가락 소품은 X·Y 월드축 기준이라 벽에 묻힐 수 있다는 개발 메모와 같은 성격 — M4 아트 때 "코스 가장자리 높이로 올려서 재생" 같은 보정 검토.
- 위치: `src/client/fx/EliminationCutsceneController.luau:288, 335-353`

### [P3] B3 숨김이 BasePart·Decal만 대상 (이름표·BillboardGui·파티클은 남음)
- 지금 캐릭터는 회색 블록이라 영향 없음. m3-02 계란초밥 몸에 BillboardGui·ParticleEmitter·Beam이 생기면 연출 중 진짜 캐릭터의 일부가 보일 수 있다. m3-02 병합 뒤 Studio 체크리스트 3에서 같이 확인.
- 위치: `src/client/fx/EliminationCutsceneController.luau:238-242`

### [P3] B4 (질문, 버그 아님) 시간 종료·정원 마감 탈락(cause nil)은 연출 없음
- m3-01 QA B3과 같은 열린 질문. 원하면 m3-09에서 서버 cause(`"Timeout"` 등) + `shouldPlay` 추가.

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 이 스펙은 새 클라이언트→서버 리모트가 없다 (QA 정적 테스트로 확인).
- [x] 통과·탈락·순위 판정이 서버에만 있다 — 연출은 서버 방송만 읽고 로컬 표시만 바꾼다.
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — 해당 없음 (맵 수정 없음). 컨트롤러 상태는 `start()` 지역 변수.
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다 — 연출별 Cleanup, Victory·매치 종료·방 이탈에 `stopAll`. 스탬프는 `task.delay` 자동 제거도 있다(중복 호출 안전).

## 사용자 Studio 확인 체크리스트
준비: `src/shared/Config.luau`의 `DEBUG.forceMapPlan`을 로컬에서만 `{ "rotating-belt", "hot-plate", "skewer-showdown" }`로 바꾸고(커밋 금지) `rojo serve` → Test 탭 → Clients and Servers, 플레이어 3명(Player1=A, Player2=B, Player3=C). 한 명이 방을 만들고 나머지가 참가 → 시작.

1. 모든 클라이언트 Output에 빨간 에러가 없는지 계속 본다.
2. **AC6 (A 화면)** — 1라운드 회전 벨트에서 A를 코스 밖으로 떨어뜨린다. 확인: 카메라가 비스듬히 위에서 A의 인형(지금은 회색 박스)을 크게 잡는다 → 젓가락이 내려와 집음 → 들어 올려 버둥 → 간장 종지에 퐁당(갈색 방울) → 손님 입으로 "냠!" → 입 위 말풍선. 화면 가운데 빨간 "먹혔다!" 도장이 쾅 찍히고 아래 "n등". 기존 "🥢 탈락했어요…" 문구는 **안 뜬다**. 약 3초 뒤 자동 관전 화면으로 바뀐다.
3. **AC7 (B·C 화면)** — 같은 순간 B·C 창에서 A가 떨어진 자리(코스 아래쪽일 수 있음, B2)를 보면 같은 연출이 보이고, 그 동안 A의 진짜 캐릭터는 보이지 않는다. B·C의 카메라는 그대로다. 연출이 끝나면 A의 캐릭터가 다시 보인다(로비에서).
4. **AC8** — 다음 판에서 라운드 중 B가 Esc → Reset Character. 리셋한 자리에서 젓가락 연출이 나온다.
5. **AC9** — 2라운드 뜨거운 철판에서 맨 아래로 떨어진다. 아래쪽에서 위로 벌린 입으로 인형이 떨어지고 입이 닫힌 뒤 말풍선.
6. **AC10** — 결승(회전 꼬치 쇼다운)에 **3명이 올라가게** 한 뒤 1명이 떨어진다 → 셰프의 큰 손이 내려와 움켜쥐고 위로 사라짐, 말풍선(결승 대사 "오늘의 마지막 접시!" 등이 나올 수 있음). 참고: 마지막 1명이 떨어져 우승이 정해지는 순간의 연출은 바로 지워진다(B1, 기획 확인 필요).
7. **AC11** — 새 판에서 라운드 중 C가 방 나가기 버튼. A·B 화면에 연출이 나오지 않는다.
8. **AC12** — 각 클라이언트 창에서 Explorer의 `Workspace/EliminationCutscenes`를 펼쳐 둔다. 연출이 끝난 뒤 비어 있어야 한다. 결승에서 우승이 정해지는 순간(누군가 떨어지는 중)에도 Victory 화면이 뜨자마자 비어야 한다. 탈락했던 사람의 캐릭터가 우승 화면에서 투명하게 남아 있지 않은지도 본다.
9. **AC13** — Test 탭 → Device에서 휴대폰(예: iPhone SE, 가로)으로 바꾸고 2를 반복. "먹혔다!"·"n등"·말풍선 글씨가 잘리지 않는다.
10. (권장) 4명 이상(가능하면 8명)으로 1라운드에서 동시에 여러 명을 떨어뜨려 프레임 저하·에러가 없는지, 7명째부터는 캐릭터만 사라졌다 나타나는지 본다.

끝나면 `forceMapPlan = nil`로 되돌린다.

## 추가한 테스트
`tests/m3-03-qa.spec.luau` (16개)
- `variantFor`: 결승이면 맵 종류·원인과 무관하게 ChefHand, 결승 아닌 Final 맵(강제 플랜)·리셋·cause nil/Left는 Chopsticks.
- `isFinalRound`: 3·4라운드 결승, 1라운드 플랜, 결승 아님, nil.
- `shouldPlay`: Left·Timeout·대소문자 다른 값·빈 문자열은 false.
- `linesFor`: 원본 목록 불변, 공통 → 스킨 → 결승 순서, 스킨 nil/모름 처리, 스펙 기본 대사 9줄 그대로·중복 없음.
- `pickLine`: 목록의 모든 위치를 고를 수 있고 nil 없음. 기본 스킨(`Config.Appearance.Default`)에 전용 대사 있음.
- `canStartWorld`: 시작/종료 시뮬레이션 (6개까지, 하나 끝나면 다시 가능).
- `timeline`: 효과음 순서가 스펙 표와 같음, 젓가락 박자가 스펙 구간 안, 길이 nil = 3초, 매번 새 표.
- 정적: 연출 3파일에 서버로 보내는 코드 없음, 컨트롤러가 Victory·매치 종료에 `stopAll`·카메라 release·숨김 복원, HUD는 `shouldPlay`로 낙하·리셋 문구만 생략.

## 인계 메모
- 지금 브랜치: `m3-03-qa` (`origin/m3-03-elimination` + `origin/main` 병합, QA 커밋 + push)
- 끝난 것: 자동 검증 4종 통과(262/0), AC1~AC5 통과, 코드 리뷰(파일 범위·판정·카메라·정리·숨김·한도·cause nil), 리포트, 스펙 상태 `qa-passed`.
- 남은 것: 사용자 Studio 확인 AC6~AC13 (위 체크리스트). 기획 결정 2건 — B1(결승 마지막 탈락 연출이 Victory에 지워짐), B4(cause nil 연출). 메인 세션이 `m3-03-qa`를 main에 병합.
- 다음에 할 첫 단계: `m3-03-qa` 병합 → B1을 m3-05(우승 연출)/m3-09(통합) 스펙에서 정하도록 기획에 넘김. m3-02 병합 뒤 체크리스트 3에서 B3(숨김 범위) 확인.
- 막힌 점: 없음.
