# QA — m5-04 두 번째 결승 맵: 연어알 폭탄 접시 (`ikura-bombs`)

- 스펙: `docs/specs/m5-04-map-ikura-bombs.md`
- 검증 커밋: `e76627a` (`origin/m5-04-ikura`, 게임플레이 + 아트 PHASE B) + `origin/main` `9be7767` 병합 (`1ee0f55`) + QA 테스트 추가
- 결과: **통과 (qa-passed)**. P0/P1/P2 없음. P3 5건(연출·문서·성능 메모). Studio 항목 AC10~AC16·AC18은 사용자 확인 필요.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 (QA 테스트 포함) |
| `selene src` | 통과 (0 errors, 0 warnings, 0 parse errors) |
| `lune run tests` | 통과 — **1642 passed, 0 failed** (이 스펙 개발 23 + QA 19) |
| `luau-lsp analyze ... src` (타입 검사) | 통과 (끝 코드 0) |
| `lune run tools/render-map ikura-bombs` (QA가 직접 실행) | decor 1182/1500, lights 10/24 (그림자 1/2), particles 7/16, anim 71/80, void 최대 5% (intro-02·eye·mobile), 예산 경고 없음 |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `map-ikura-bombs.spec` "AC1" 4개 + QA "build: 충돌 파츠는 전부 칸 Slab(17칸)…" |
| AC2 | 통과 | `map-ikura-bombs.spec` "AC2: tileAt — 경계 바로 안쪽 표본 20개…" |
| AC3 | 통과 | `map-ikura-bombs.spec` "AC3" + QA "bombWave 경계: 29.999/30, 59.999/60, overtimeAt = 15(디버그)·overtimeAt < 3" |
| AC4 | 통과 | `map-ikura-bombs.spec` "AC4" 4개 + QA "pickTargets 경계"(레이서 0명·칸 0개·count 0), "D4: 레이서 1명 + 3개 간격 위반 ≤ 1%, 레이서 위 폭탄은 묶음마다 1개", "레이서 2명 + 2개 → 두 사람을 각각 노림" (D4 확정 해석과 일치) |
| AC5 | 통과 | `map-ikura-bombs.spec` "AC5" + QA "knockback 경계"(반경 바로 밖 nil, 높이 차 6/6.01) + 실제 맵 "폭발" 2개(바깥 방향 50, 거리 5에서 50 × (1 − 0.4 × 5/7), 위 30, 돌린 origin에서도 월드 바깥 방향) |
| AC6 | 통과 | `map-ikura-bombs.spec` "AC6" 5개 + 실제 맵 QA "금 가기" 2개(같은 바깥 칸 두 번 → 1초 경고 → 충돌·쿼리·터치 없음 + 투명 / 원판은 35초 동안 계속 맞아도 그대로), "정해진 낙하"(40초 하나, 89초에 바깥 3·가운데 2·원판 1) |
| AC7 | 통과 | `map-ikura-bombs.spec` "AC7" + QA "overtimeRings 경계" + 실제 맵 QA "연장전" 3개 (아래 서버 판정 참고) |
| AC8 | 통과 | `map-ikura-bombs.spec` "AC8·AC17" 2개 (Extended 1500 기준, 시야 상자), `inPool` 줄 삭제 확인 |
| AC9 | 통과 | 위 자동 검증 5단계, `maps`·`round-logic` 통과. 다른 테스트 수정(m2-01-qa·m4-12·m4-foundation·m5-03-foundation·maps·m5-03-qa)은 아래 "기존 테스트 변경 검토" 참고 — 정당함 |
| AC10 | 사용자 확인 필요 | 체크리스트 2 |
| AC11 | 사용자 확인 필요 | 체크리스트 3 |
| AC12 | 사용자 확인 필요 | 체크리스트 4 |
| AC13 | 사용자 확인 필요 | 체크리스트 5 |
| AC14 | 사용자 확인 필요 | 체크리스트 6 (Final 풀이 4개라 이 맵 확률은 약 1/4 — 스펙의 "5판 중 두 맵"보다 판 수가 더 필요) |
| AC15 | 사용자 확인 필요 | 체크리스트 7 |
| AC16 | 사용자 확인 필요 | 친구 테스트 (`docs/playtest/`) |
| AC17 | 통과 (렌더 근사) | 개발 메모에 반복 기록·전/후 PNG(`docs/renders/ikura-bombs/`)·최종 PNG 경로 있음. QA가 렌더러를 직접 돌려 같은 stats 확인, 체크리스트 18개 아래 "아트 검토"에서 재확인 (P3 메모 2건). `checkBudget(…, "Extended")`·`lighting` validate 테스트 있음 |
| AC18 | 사용자 확인 필요 | 체크리스트 8 |

통과 9 / 실패 0 / 사용자 확인 필요 8 (AC10~AC16, AC18).

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 이 맵은 새 리모트가 없음.
- [x] 통과·탈락·순위 판정이 서버에만 있다 — 낙하 판정(`IkuraBombs.luau:553-566`, 칸 윗면 −30)·폭발 판정(`explode`)·금·정해진 낙하·연장전 붕괴 전부 서버 `start`/`overtime`. `ctx.pass` 없음. QA "낙하선: −30.1 탈락, −29.9 아직, 한 번만".
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — `roundStates[ctx]`(칸 상태·금·쿨다운·숟가락 목표·폭탄 폴더), `newState`가 `ctx.cleanup`에 지우기 등록. QA "여러 방: 한 방의 연장전 붕괴·넉백이 다른 방에 안 섞여요"(origin 2000/4000 두 방 동시).
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다 — Heartbeat 연결 1개, 폭탄 일정·정해진 낙하 `task.delay`·`runBomb`·`dropTile`·넉백 해제·LinearVelocity 삭제 스레드, `Bombs` 폴더·폭탄 Model·LinearVelocity가 전부 `ctx.cleanup`에. QA "정리"가 가짜 스케줄러로 만든 **모든** 스레드가 cleanup 목록에 있는지, 라운드가 끝나면 경고 중 폭탄이 터지지 않고 지워지고 연장전 붕괴도 멈추는지 확인.
- [x] 넉백: `LinearVelocity`(World, MaxForce 무한) 0.12초 + `AssemblyLinearVelocity` + `PlatformStand` 1초 + `MoveExempt.mark(character, 1.5)` — `SoySwampHazards` 와사비와 같은 방식. 0.5초 쿨다운(`lastHit`). 넘어진 사이 탈락하면 PlatformStand를 건드리지 않음(EliminationService 고정 유지, QA 테스트). 라운드가 끝날 때 넘어져 있던 사람은 `CharacterUtil.resetMovement`가 풀어 줌(꼬치 쇼다운·라멘과 같은 패턴).
- [x] 잡기 풀림: `GrabService.isDown`이 `humanoid.PlatformStand`를 보고(`GrabService.luau:60`) 잡은 쪽·잡힌 쪽이 넘어지면 풀림 — 폭발이 PlatformStand를 켜므로 스펙대로.
- [x] 연장전 계약(m5-01): `overtime`이 yield 없이 바로 돌아오고(QA), 일정은 `task.delay`를 `ctx.cleanup`에. 바깥 1초·가운데 10.5초·원판 20초에 고리째 사라지고 **20초 뒤 모델 안 충돌 파츠 0개**(QA "연장전: … 20초 뒤 충돌 파츠 0"). 연장전 중엔 금·정해진 낙하가 멈추고 폭탄은 1초마다 3개(QA). `start` 전에 불려도 바닥을 없앰(QA).
- [x] 설 곳: 판정 충돌 파츠는 칸 Slab 121개뿐(원판 1 + 6도 조각 120, 렌더러의 judgment 145 = 121 + 스폰 24)(QA build 테스트 — 스폰·숟가락·칸 경계선·금 줄 모두 충돌 없음). 장식(테두리·종지·군함 탑·숟가락·팔·부두·등 기둥)은 `MapKit.buildDecor` → `applyDecorRules`(CanCollide/CanQuery/CanTouch false)로 강제. 숟가락 Model은 `Decor` 폴더 안.
- [x] 배경 바닥(부두 −45, 바다 −62)은 낙하선 −30보다 10 이상 아래(개발 테스트).

## 기존 테스트 변경 검토
- `tests/m5-03-qa.spec.luau`: 껍데기 `IkuraBombs`(판 하나 `Plate`)의 build/start/overtime 확인 3곳을 뺌. 이 스펙이 껍데기를 실제 맵으로 덮어쓰라고 정했고(`Plate` 파츠가 더는 없음), 남은 껍데기 두 개(tempura-pot·dessert-fridge) 확인은 그대로 남음 → **정당**. 빠진 "overtime이 yield 없이 돌아오고 시간 뒤 바닥이 사라진다" 확인은 QA가 실제 맵으로 `tests/m5-04-qa.spec.luau`에 다시 넣음(더 엄격: 고리별 시각·충돌 파츠 0).
- `m5-03-foundation`(껍데기 목록에서 빼고 id·이름·문구는 계속 확인, infos 13), `maps`(13), `m4-foundation`(Final 4), `m2-01-qa`(결승 후보에 추가), `m4-12-hardening`(강제 플랜 추가): 전부 풀에 맵 하나가 들어간 데 따른 개수·목록 갱신이고 기대값을 느슨하게 만든 곳은 없음 → **정당**.

## 아트 검토 (렌더러 직접 실행, `build/renders/ikura-bombs/`)
체크리스트 11절 18개를 QA가 PNG로 다시 봄: 1 빈 공중 예(최대 5%) · 2 실루엣 예(군함 탑·셰프 팔·노점·등대) · 3 맨 상자 없음 예 · 4 히어로 색 예(군함 탑 위 연어알) · 5 shade 예(부두 판자 3톤) · 6 바닥 가독성 예(칸 캐러멜 + 크림 경계선) · 7 위험 색 대체로 예(P3 B3) · 8 가짜 바닥 대체로 예(P3 B2) · 9 보이는 광원 예(그림자 1) · 10 온도 대비 예(따뜻한 노점 등 / 차가운 바다) · 11 밀도 예 · 12 생동감 예 · 13 방향 예(가운데 원판) · 14 소개 구도 예(intro-03은 숟가락 그릇이 위를 크게 가림 — 의도라고 개발 메모에 있음) · 15 휴대폰 예 · 16 배경 바닥 예 · 17 예산 예 · 18 스케일 예.
- **경고 원 가독성**: 경고 원은 런타임에만 생겨 기본 렌더에 없어서, QA가 장식 목록에 빨간 원(232,24,36)+흰 테두리 2개와 떨어지는 연어알을 **임시로** 넣고 eye·mobile·overview를 렌더해 봄(확인 뒤 원래대로 되돌림, 커밋 안 함). 불투명 빨강 + 흰 테두리는 eye·mobile(480×270) 모두에서 캐러멜 칸·크림 경계선·노란 스폰 표시와 또렷이 구분됨. 깜빡임 색(255,92,92)도 구분됨. 실제 Roblox 조명·블룸은 다를 수 있어 AC18로 확인.

## 버그
### [P3] B1 경고 원 표현이 스펙 문구와 다름 (문서 정리)
- 재현: 스펙 "연어알 폭탄 — 경고"는 "빨간 원(반투명, 깜빡임)", 아트 디렉션은 "빨강 Neon + 흰 테두리".
- 기대: 스펙 문구와 구현이 같음.
- 실제: 구현은 **불투명 빨강 SmoothPlastic + 흰 테두리, 색 깜빡임**(개발 메모: 렌더에서 반투명 Neon이 블룸에 하얗게 날아가서 바꿈). QA 임시 렌더로는 이쪽이 더 잘 읽힘 — 동작 문제는 아님.
- 위치: `src/shared/maps/IkuraBombs.luau:443-463`, `IkuraBombsArt.luau` `COLORS.bombCircle/bombBlink/bombBorder`
- 할 일: planner가 스펙 문구를 구현에 맞춤(AC18 Studio 확인 뒤).

### [P3] B2 와사비·생강 종지가 접시 가장자리에 붙어 있어 디딤판처럼 보일 수 있음
- 재현: `lune run tools/render-map ikura-bombs --view top` → 왼쪽(−X, 각도 180, 반지름 31) 종지가 접시 테두리에 맞닿아 있음. eye·intro-01에서도 둥근 받침이 접시 옆 낮은 발판처럼 보임.
- 기대: 판정 바닥 옆에 서 있을 수 있어 보이는 충돌 없는 판이 없음(체크리스트 8).
- 실제: 종지 윗면은 칸 윗면보다 2.5 낮고 충돌이 없어서, 넉백으로 가장자리에 몰린 사람이 뛰어 올라가려 하면 그냥 떨어짐. 스펙이 "접시 가장자리에 고추냉이·생강 장식(밖, 충돌 없음)"을 요구하고 결승은 가장자리 밖 = 탈락이라 판정상 문제는 없음.
- 위치: `src/shared/maps/IkuraBombsArt.luau:1032-1033` (`condimentDish(list, 180, 31, true)`, `condimentDish(list, 270, 47, false)`)
- 제안(선택): 첫 종지를 반지름 34 이상으로 떼거나 윗면을 더 낮게(−5 이하). 친구 테스트에서 "종지에 서려다 떨어졌다"가 나오면 고침.

### [P3] B3 군함 탑 위 연어알 장식이 경고 빨강과 비슷한 톤
- 재현: eye·mobile 렌더(그리고 QA 임시 경고 원 렌더)에서 군함 탑 연어알 더미·흘러내린 줄기가 골든아워 조명 아래 붉은 주황으로 보임.
- 기대: 위험 색(빨강)은 위험물에만(체크리스트 7).
- 실제: 히어로 색 연어알 주황(255,96,40)이 스펙상 장식 히어로 색이라 의도된 것이고, 탑은 접시 밖 멀리·공 모양이라 바닥 위 원과 헷갈릴 가능성은 낮음. 다만 마지막 0.5초 떨어지는 연어알이 탑 앞을 지날 때 배경에 묻힘(임시 렌더 eye).
- 위치: `IkuraBombsArt.luau` `gunkanTower`, `IkuraBombs.luau:473-483`(떨어지는 연어알)
- 할 일: AC18 Studio 확인 때 같이 봄. 묻히면 떨어지는 연어알만 밝게(Transparency 0.25 → 0, 또는 흰 하이라이트).

### [P3] B4 폭발 알갱이 파티클 하나를 옮겨 쓰므로 같은 순간 여러 폭발이면 마지막 자리에만 보일 수 있음
- 재현: 30초 뒤(2개)·연장전(3개) 묶음은 같은 시각에 터짐 → `explode`가 같은 프레임에 holder를 차례로 옮기며 `Emit`.
- 기대: 폭발마다 그 자리에 알갱이.
- 실제: 서버 `Emit`의 복제 방식에 따라 앞 폭발 알갱이가 마지막 자리로 몰릴 수 있음(개발 메모 "알려진 한계"와 같음). 연출만, 판정 영향 없음.
- 위치: `src/shared/maps/IkuraBombs.luau:400-408`
- 할 일: Studio에서 연장전(3개 동시)에 확인. 몰리면 폭탄 Model 안에 emitter를 따로 두는 쪽으로(파티클 예산은 런타임 장식이라 상관없음).

### [P3] B5 숟가락 장식(약 40파츠)을 서버가 매 Heartbeat `PivotTo`
- 재현: `start`의 Heartbeat가 `spoonTarget`이 있는 동안 매 프레임 `spoon:PivotTo` — 폭탄이 1~2.5초마다 목표를 바꿔서 결승 내내 앵커 파츠 수십 개의 CFrame이 계속 복제됨.
- 기대: 연출용 이동은 가볍게.
- 실제: 방 하나당 결승 한 번이라 지금 규모에선 문제가 안 될 가능성이 높음(꼬치 쇼다운 손도 서버에서 움직임). 성능 메모.
- 위치: `src/shared/maps/IkuraBombs.luau:567-571`
- 할 일(선택): 목표와 거의 같으면(0.05 이하) PivotTo를 건너뜀, 또는 휴대폰 실측(`DEBUG.logArenaStats`)에서 문제 될 때 클라이언트 연출로.

## 사용자 Studio 확인 체크리스트
준비: `src/shared/Config.luau`의 `Config.DEBUG.forceMapPlan = { "rotating-belt", "hot-plate", "ikura-bombs" }`. 빠른 연장전은 `Config.DEBUG.overtimeAt = 15`. **확인 뒤 둘 다 `nil`로 되돌리기.**
1. 결승 소개: 바다 쪽 넓은 샷 → 숟가락 → 위에서 내려다보기 → 출발 자리 순으로 카메라가 움직이고, 화면이 로비 조명이 아니라 해 질 녘 색으로 바뀌는지.
2. (AC10) 출발 3초 뒤 빨간 원(흰 테두리)이 뜨고 숟가락이 그 위로 오며, 1.5초 뒤 위에서 주황 연어알이 떨어져 터지는지. 원 안이면 바깥으로 날아가 넘어지고(@_@) 1초 뒤 일어나는지, 원 밖이면 아무 일 없는지.
3. (AC11) 같은 바깥 칸에 두 번 맞으면 칸이 어두워졌다가(금 줄) 두 번째에 빨갛게 깜빡이며 흔들린 뒤 사라지는지. 가운데 원판에는 몇 번 맞아도 금이 안 가는지. 40초부터 바깥 칸이, 60초부터 가운데 고리 칸이 하나씩 깜빡이고 떨어지는지.
4. (AC12) Test → Clients and Servers 2명: 연장전 배너 → 바깥 고리 전체 깜빡임(1초) 뒤 사라짐 → 약 10초 뒤 가운데 고리 → 약 20초에 원판까지 사라져 설 곳이 없는지. 숟가락·셰프 팔·접시 테두리·종지·군함 탑·등 기둥에 올라가거나 매달릴 수 없는지(통과해 떨어지는지). 더 늦게 떨어진 사람이 우승하는지.
5. (AC13) Play Solo로 결승 → 연장전 붕괴로 끝나고, 탈락 연출이 셰프 손인지.
6. (AC14) `forceMapPlan = nil`, 4명 이상으로 랜덤 판 여러 번 → 결승에 이 맵과 다른 결승 맵들이 섞여 나오는지 (Final 4개 중 무작위라 이 맵은 약 4판에 1번 — 10판 정도 필요).
7. (AC15) 휴대폰 에뮬레이터: 빨간 원이 잘 보이는지. 폭발에 날아갈 때 Output에 이동 감시(`[MovementGuard]`) 로그가 없고 되돌려지지 않는지. 잡은 상태에서 폭발에 맞으면 잡기가 풀리는지.
8. (AC18) 접시 위 등(기둥에 매단 SpotLight) 아래로 숟가락 그림자가 접시에 떨어지는지. 휴대폰 화면에서 빨간 경고 원이 연어알 주황(군함 탑·떨어지는 알)과 헷갈리지 않는지(B3). 연장전에서 동시에 터진 3개 폭발의 주황 알갱이가 각자 자리에서 터지는지(B4). 셰프 팔 소매가 숟가락을 따라 움직일 때 카메라를 가리지 않는지.

## 추가한 테스트
`tests/m5-04-qa.spec.luau` 19개 — 실제 `IkuraBombs.luau`를 가짜 Roblox 환경 + 가짜 스케줄러(os.clock·task.wait/delay/spawn·Heartbeat:Wait를 시계 하나로)로 돌림:
- build: 충돌 파츠는 칸 Slab뿐(17칸), 스폰 24·숟가락은 Decor 폴더
- 폭발: 반경 안 넉백 방향·세기·위 30·PlatformStand 1초·MoveExempt 1.5·LinearVelocity 0.12초, 반경 밖·높이 차 밖 무사 / 돌린 origin / 넘어진 사이 탈락하면 PlatformStand 유지
- 금 가기: 두 번 → 1초 경고 → 충돌·쿼리·터치 없음 + 투명, 쿨다운 뒤 다시 맞음 / 원판 35초
- 정해진 낙하: 40초 하나, 바깥 3·가운데 2에서 멈춤
- 연장전: yield 없음, 1·10.5·20초 고리 붕괴, 20초 뒤 충돌 파츠 0 / 금·정해진 낙하 멈춤, 폭탄 1초 3개 / start 전 호출
- 낙하선 −30, 여러 방 동시, 정리(모든 스레드·연결이 ctx.cleanup)
- 순수 경계: bombWave, pickTargets(빈 입력·D4·레이서 2명), overtimeRings, knockback/inBlast

## 인계 메모 (2026-10-13, qa)
- 브랜치: QA worktree에서 `origin/main`(`9be7767`) + `origin/m5-04-ikura`(`e76627a`) 병합 후 검증, `origin/m5-04-ikura`에 push.
- 끝난 것: 검증 5단계, 렌더러 직접 실행·PNG 검토(임시 경고 원 렌더 포함), AC1~AC9·AC17 확인, QA 테스트 19개, 리포트, 스펙 상태 `qa-passed`.
- 남은 것: 사용자 Studio 확인(위 1~8 = AC10~AC15·AC18), AC16 친구 테스트. P3 B1(planner 문구), B2~B5(선택, Studio·플레이테스트 결과 보고).
- 다음 첫 단계: `m5-04-ikura`를 main에 병합 → 병합 뒤 검증 5단계 다시 → docs-writer 반영 → `done`.
- 막힌 점: 없음.
