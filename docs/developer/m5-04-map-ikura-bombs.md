# m5-04 연어알 폭탄 접시: 개발 작업 기록

## 2026-10-13 — PHASE B 아트 끝, in-qa (최신)
- **브랜치**: `m5-04-ikura` (worktree `.claude/worktrees/agent-a31d32c4a597d9bba`). origin/main 591d84e(키트 수정 e07e08d 포함) 병합. 스펙 status `in-qa`.
- **끝난 것**: 아트 패스 전부, 렌더 3회 반복 + 렌더러 수정 뒤 재확인, 전/후 PNG `docs/renders/ikura-bombs/`, 테스트 23개. 검증 5단계 통과 (lune 1590/0).
- **다음 단계**: QA. Studio AC10~AC18.
- **주의**: 병합할 때 `tests/m5-03-qa.spec.luau` 머리 주석이 충돌했었음(main의 "껍데기 서비스" 줄 변경과 겹침).

### 반복 1 (첫 아트 렌더)
stats: decor 956, lights 10 (그림자 1), particles 7, anim 71, void intro 4~45%(렌더러 lookAt 버그 전) · overview 10% · eye 2%.
체크리스트: 1 빈 공중 예(eye) / 2 실루엣 예 / 3 맨 상자 아니오(섬이 반구 덩어리) / 4 히어로 색 예 / 5 shade 예 / 6 바닥 가독성 예 / 7 위험 색 아니오(노점 지붕 옻칠 빨강) / 8 가짜 바닥 예 / 9 광원 예 / 10 온도 대비 예(약함) / 11 밀도 위치 아니오(부두가 비어 있음) / 12 생동감 예 / 13 방향 예 / 14 소개 구도 아니오(엉뚱한 곳을 봄) / 15 휴대폰 미확인(폭탄은 런타임) / 16 배경 바닥 예 / 17 예산 예 / 18 스케일 예.
가장 나쁜 뷰 intro-01: 접시가 안 보이고 바다만 — 원인은 내 좌표가 아니라 Lune `CFrame.lookAt` 버그(LookVector가 목표를 안 봄)로 확인, 메인에 알림(이후 e07e08d에서 고쳐짐). eye 뷰 앞을 기둥 등 기둥이 가림(렌더러 eye가 판정 경계 중심을 보는데 숟가락 Model이 판정으로 잡혀 중심이 +Z로 밀림). 바다 위 얕은 판·노을 반사 띠가 직사각형 모서리로 보여 싸 보임.
고침: 숟가락 Model을 Decor 폴더로, 얕은 바다판·반사 띠 삭제, 섬을 몸통 + 봉우리 2개로, 안개 Density 0.3 → 0.27·Haze 1.4 → 1.0.

### 반복 2
stats: decor 1002, void 전부 ≤ 9%.
체크리스트: 3 예 / 7 아니오(노점 지붕) / 11 아니오(부두 소품 없음) / 14 예(경고 원 렌더 확인 필요) / 15 아니오 — 임시로 경고 원 2개를 넣어 렌더하니 반투명 Neon 빨강 + 흰 Neon 테두리가 빛 번짐으로 **하얗게** 보여 위험 색이 안 읽힘. 나머지 예.
가장 나쁜 뷰 mobile: 경고 원이 흰 빛 덩어리. 군함 탑의 흘러내린 연어알이 듬성듬성한 물방울 무늬처럼 보임.
고침: 경고 원 불투명 빨강 + 흰 SmoothPlastic 테두리, 깜빡임은 색으로. 흘러내린 알을 촘촘한 한 줄기로, 김 위 밥 띠. 노점 지붕을 남색 옻칠로. 칸 색을 덜 붉은 간장 캐러멜로(빨간 원과 대비).

### 반복 3 (최종, 렌더러 수정 후 다시 확인)
stats: decor 1182/1500, lights 10/24 (그림자 1/2), particles 7/16 (SeaSpray·Sparkle·Steam 3종), anim 71/80, void intro-01 2% · intro-02 5% · intro-03 0% · intro-04 4% · overview 3% · eye 5% · mobile 5%.
고침: 부두 소품 무리(술통·상자·생선 바구니, scatter 2무리), 접시 흰 테두리를 칸보다 1 넘게 낮게(테스트로 고정), 소개 카메라를 판정 경계 + 40 안으로(메인 알림), 소개 1을 접시 쪽으로 당김.
체크리스트 18개: 1 예 · 2 예(셰프 팔+숟가락, 군함 탑, 노점, 와사비 종지, 등대) · 3 예(큰 장식은 roundedBox·bevelBox·rimDisc·캡슐·테 — 판자·바다·길 같은 큰 판은 배경 바닥) · 4 예(연어알 주황은 탑·숟가락·흘린 알만) · 5 예 · 6 예(칸이 금빛 선으로 나뉘어 밝게) · 7 예(빨강은 경고 원만) · 8 예(top 뷰·테스트) · 9 예(초롱·창·등대·부표·기둥 등 모두 Neon 원인 파츠, 그림자 1) · 10 예(따뜻한 초롱·창 / 차가운 바다·하늘·유리 부표) · 11 예(출발 쪽 노점·접시 둘레·탑 주변) · 12 예 · 13 예(가운데 원판과 동심원) · 14 예 · 15 예(임시 렌더로 확인) · 16 예(−45/−62) · 17 예 · 18 예(접시 48, 간장병 15, 찻잔 8, 카운터 높이 약 90, 상자·통 10~15).
남은 것(속이지 않음): 렌더러 근사라 Bloom·SpotLight 그림자는 Studio에서 확인 필요(AC18).

## 2026-10-13 — PHASE A 게임플레이 끝
- **브랜치**: `m5-04-ikura` (worktree `.claude/worktrees/agent-a31d32c4a597d9bba`, 로컬 브랜치 `worktree-agent-a31d32c4a597d9bba`를 `origin/m5-04-ikura`로 push). origin/main f88e327 병합함. 스펙 status `in-dev`.
- **끝난 것**: Layout·Logic·Art(최소)·맵 모듈·테스트 18개, `inPool = false` 삭제, 스펙 밖 풀 개수 테스트 5개 최소 수정. 스펙 "개발 메모" PHASE A 참고.
- **설계에서 바뀐 점**: 상태는 속성 대신 claw-machine-prize처럼 `roundStates[ctx]`(칸 상태·쿨다운·숟가락 목표). 칸 Model 속성(`Cracks`·`Falling`·`Dropped`)은 Studio에서 보기용으로만 갱신. 정해진 낙하는 `scheduleMarks`의 각 시각에 `task.delay` → `scheduledDrops(mark, alive)`. 다시 뽑기는 이미 노린 레이서를 뺌(결정 기록 D4).
- **검증 상태**: 5단계 통과 (lune 1251/0, luau-lsp 0).
- **다음에 할 첫 단계 (PHASE B)**: main에 m5-23 비주얼 키트가 들어오면 origin/main을 병합 → `IkuraBombsArt.luau`를 새 키트(조명·파티클·애니메이션·조명 프리셋, 높아진 예산)로 채우고 `buildSpoon`의 자리 잡기 파츠를 아트로 교체. 칸 경계 선은 칸 Model 안(같이 사라지게). 미리보기 렌더러로 확인 → status `in-qa`.
- **막힌 점 / 주의**: 풀 개수 테스트(m5-03-foundation·maps·m4-foundation·m2-01-qa·m4-12-hardening)는 m5-05/06도 고치는 줄이라 병합 충돌 가능.

## 2026-10-08 — 설계만 함, 코드 없음
- **브랜치**: `m5-04-ikura` (origin/main c4ca608에서 분기). 스펙 status `in-dev`. `inPool = false`는 그대로 둠.
- **끝난 것**: 스펙과 참고 코드(SkewerShowdown/Logic/Art, MapKit/Logic, MoveExempt, SoySwampHazards launch, MapTypes 연장전 계약, RoundService overtime 호출)를 읽고 아래 설계를 정함. 코드와 테스트는 아직 없음.
- **검증 상태**: 코드를 바꾸지 않아 돌리지 않음 (main 상태 그대로).
- **다음에 할 첫 단계**: `src/shared/maps/IkuraBombsLayout.luau`(상수·칸 표·스폰) → `IkuraBombsLogic.luau` → `tests/map-ikura-bombs.spec.luau` → `IkuraBombsArt.luau` → `IkuraBombs.luau` 덮어쓰기.
- **막힌 점 / 주의**: `inPool = false`를 지우면 기존 테스트가 깨진다. 이 테스트들은 스펙의 파일 목록 밖이다.
  - `tests/m5-03-foundation.spec.luau`: AC1(ikura `inPool == false` 기대), AC2(`#Maps.infos() == 6`, SHELLS에 ikura 포함), buildRoundPlan 껍데기 표
  - `tests/m2-01-qa.spec.luau:62` "결승은 언제나 skewer-showdown", `tests/m4-foundation.spec.luau:321` "Final 1"
  - 최소한으로 고친다(ikura를 껍데기 목록에서 빼고 개수 +1, Final 1 → 2). 보고에 적을 것. m5-05/06도 같은 줄을 고치므로 병합 충돌이 날 수 있다.

## 설계 (정한 것, 스펙 기본값)
- **좌표**: 접시 중심 = origin, 칸 윗면 = origin 높이(y 0), 두께 1.5. 각도는 꼬치 쇼다운과 같은 `atan2(-z, x)` (CFrame.Angles(0, θ, 0) 기준).
- **칸 기하 (틈 0)**:
  - 원을 6°씩 60조각으로 나눈다. Ring 1·2 칸은 조각마다 직사각형 1개다. 폭 = 바깥 현 `2·rOut·sin3°`, 깊이 = `(rOut − rIn)·cos3°`, 조각 이등분선 위에 둔다.
  - 고리 경계(r 8·16)가 같은 현 위에 있어서 고리 사이 틈은 0이다. 조각끼리는 최대 0.42 겹친다.
  - Ring 0은 지름 16 Cylinder 1개.
  - 칸은 Model이다 (태그 `IkuraTile`, 속성 `Ring`·`Index`·`TileId`·`Cracks`).
  - Ring 1 = 6칸 × 10조각, Ring 2 = 10칸 × 6조각 → 충돌 파츠 121개.
- **상태는 모듈 표가 아니라 속성에 둔다**:
  - 칸 속성: `Cracks`, `Falling`(경고 시작), `Dropped`.
  - 맵 Model 속성: `StartedAt`(os.clock), `OvertimeAt`(출발 기준 초).
  - 그래서 모듈 상태가 없고, overtime은 ctx.model만 읽는다.
- **스폰**: r 13에 12개(30° 간격), r 19에 12개(15° 어긋남). 앞 번호부터 흩어지게 순서를 섞는다. 테스트로 고정할 것: 모두 `tileAt` 안, 접시 가장자리까지 4 이상, 서로 3 이상.
- **Logic API**:
  - `tileAt(x, z) -> id?`
  - `bombWave(elapsed, overtimeAt?) -> { interval, count, warn, radius }?`
  - `pickTargets(rng, racers { {x, z} }, aliveIds, count)`: rng는 NextNumber/NextInteger만 있는 최소 타입(테스트는 가짜 rng). 칸 밖 점은 극좌표에서 반지름과 각도를 남은 칸 범위(0.5 안쪽)로 클램프한다.
  - `knockback(dx, dz, radius, awayX?, awayZ?) -> { x, y, z }?`: 거리 0이면 접시 중심 반대 방향, 그것도 0이면 +X.
  - `inBlast(dx, dy, dz, radius)`: 높이 차 6 이하.
  - `crack(ring, cracks) -> (cracks, drop)`
  - `pickDrop(ring, alive, rng?)`
  - `scheduledDrops(elapsed, alive, rng?)`: 바깥은 40+6k초, 가운데는 60+6k초 정각. 바깥 3칸·가운데 2칸은 남긴다. 금 간 칸이 먼저.
  - `overtimeRings(D, warn)`: dropAt = warn + (D − warn)·k/2.
- **런타임**:
  - Heartbeat 하나: 낙하 판정(y < −30), 숟가락이 목표를 따라감.
  - 폭탄 루프는 task.spawn으로 bombWave 간격마다 돈다. 폭탄마다 task.delay 스레드를 쓰고 전부 ctx.cleanup에 넣는다.
  - 폭탄은 `Bombs` 폴더 아래 Model(태그 `IkuraBomb`). 빨간 원(Cylinder, 충돌 없음)이 깜빡이고, 마지막 0.5초에 지름 4 주황 구가 떨어진다.
  - 폭발: LinearVelocity 0.12초 + AssemblyLinearVelocity + PlatformStand 1초 + `MoveExempt.mark(char, 1.5)`. 같은 사람은 0.5초 쿨다운. `MapSfx.play(.., "IkuraPop")`, ParticleEmitter:Emit.
  - PlatformStand가 켜지면 잡기가 풀린다(GrabService 60행).
- **금 가기 (연장전 전에만)**: 1이면 색을 어둡게 하고 칸 Model 안에 검은 얇은 선 장식을 넣는다. 2가 되면 1초 흔들림·빨간 깜빡임 뒤 CanCollide/CanTouch/CanQuery false + 투명 + `TileVanish`.
- **연장전**: `OvertimeAt` 속성을 설정한다(정해진 낙하·금 낙하 중지). 폭탄은 `bombWave`가 연장전 값을 준다. 고리 2 → 1 → 0을 `overtimeRings`대로 task.delay(ctx.cleanup)로 붕괴시킨다. 장식은 전부 충돌 없음.
- **아트 (예산 600)**:
  - 칸 경계 얇은 선(칸 Model 안).
  - 남색 무늬 도자기 테두리 lip (r 24~25, y 1 이하 → 시야 상자 y 2~12 밖).
  - 접시 바닥·굽, 부두·바다·가게 앞. 무대 높이 가짜 바닥은 금지 — map-art-arena의 fakeFloors 규칙대로 무대보다 6 이상 낮게.
  - 높이 28에 셰프 손 + 은 숟가락 (별도 Model `Spoon`, 장식 규칙).
  - 고추냉이·생강, 등롱 PointLight 12개 이하, IntroCamera 4점.
