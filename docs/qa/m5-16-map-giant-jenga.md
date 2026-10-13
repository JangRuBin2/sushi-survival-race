# QA — m5-16 새 Survival 맵: 와르르 나무 블록 (`giant-jenga`)

- 스펙: `docs/specs/m5-16-map-giant-jenga.md`
- 검증 커밋: `4192744` (`main`, m5-16 병합 `8f4fb5d` 포함)
- 결과: **반려 (P1 있음)** → 스펙 상태 `in-dev`. 블록이 뽑힐 때 위가 아니라 맨 아래 블록이 사라져서, 가라앉은 칸이 위에서 보면 멀쩡한 칸과 똑같이 보인다(B1).

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 0 errors / 0 warnings |
| `lune run tests` | 1258 passed, 0 failed (QA 추가 전 1233) |
| `luau-lsp analyze` (타입 검사) | 끝 코드 0 |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | 개발 `AC1` 4개 |
| AC2 | 통과 | 개발 `AC2` (표의 9개 시각 전부) |
| AC3 | 통과 | 개발 `AC3`. QA `60초 동안 뽑는 총 개수는 테두리 16칸 × 3단(48)보다 적어요` |
| AC4 | 통과 | 개발 `AC4` 4개. QA `시드 1~300 한 판 내내 고른 칸은 바깥·레벨>0·중복 없음…` |
| AC5 | 통과 | 개발 `AC5` |
| AC6 | 통과 | 개발 `AC6` 4개. QA 같은 시뮬레이션에서 모든 칸 기울기 각도 ≤ 18도·낮은 쪽 단위 벡터·축 ⟂ 낮은 쪽·보호/뚫린 칸 nil. 회전축 부호는 Lune CFrame으로 "낮은 쪽이 내려감" 확인 |
| AC7 | 통과 | 개발 `AC7`. QA `가장 많이 가라앉은 칸도 낙하선보다 20 이상 위` |
| AC8 | 통과 | 개발 `AC8` 6개 |
| AC9 | 통과 | 5단계 + `maps`·`round-logic` 통과 |
| AC10~AC16 | 사용자 확인 필요 | 아래 체크리스트. **AC10·AC11은 B1 때문에 지금 그대로는 실패할 것으로 예상** |

## 버그
### [P1] B1 블록이 뽑히면 맨 아래 블록이 사라지고 맨 위 블록은 남는다 — 가라앉은 칸이 안 보인다
- 재현: 코드 — 바깥 칸 블록은 `Block1`이 맨 위(중심 y −2), `Block3`이 맨 아래(중심 y −10)다(`GiantJenga.luau:99-108`, `centerY = -(level - 1) * LEVEL_DROP - LEVEL_DROP / 2`). 뽑을 때는 `entry.blocks[newLevel + 1]`을 숨긴다(`:303`) → 레벨 3→2에서 `Block3`(맨 아래), 2→1에서 `Block2`가 사라진다. 블록은 충돌이 없고(`ghost`) 보이기만 하는 파츠라, 판정 타일(Top)은 y −4로 내려가도 그 위에 불투명한 `Block1`(y −3.9~−0.1)이 그대로 남는다. Studio: `forceMapPlan = { "rotating-belt", "giant-jenga", "soy-swamp", "skewer-showdown" }`로 6초 뒤 처음 삐걱인 칸을 위에서 본다.
- 기대: 스펙 범위 7 "블록 1단 뽑힐 때마다 그 블록 하나가 빠지는 것처럼", AC10 "살짝 가라앉는다", AC11 "그 주변만 기울어서… 다른 각도로 보인다" — 이 맵의 핵심은 "어디가 약해졌는지 눈으로 읽기".
- 실제: 위에서 보면 가라앉은 칸도 맨 위 블록 윗면(y ≈ 0)이 그대로라 멀쩡해 보인다. 가라앉은 타일과 그 기울기는 `Block1` 안에 숨고 테두리 0.5 studs만 삐져나온다. 그 칸에 올라서면 보이는 바닥을 뚫고 4~8 studs 빠지고, 몸이 나무 블록 속에 묻혀 보인다. 칸이 완전히 사라질 때(레벨 0)만 갑자기 구멍이 보인다. 판정 자체(Top 높이·기울기·낙하)는 맞다.
- 고치는 방향: 레벨 L → L−1일 때 위에서부터 숨긴다 — `entry.blocks[Layout.LEVEL_MAX - newLevel]`(3→2에서 `Block1`, 2→1에서 `Block2`). 블록 만들기는 `GiantJenga.luau` 안이라 m5-24 아트 패스가 고치지 않는다.
- 위치: `src/shared/maps/GiantJenga.luau:303` (블록 배치 `:99-108`)

### [P3] B2 rule 문구가 결정 기록 없이 바뀌었다
- m5-13(GDD §5.3 확정)은 "흔들리는 블록탑 위에서 안 떨어지게 버텨요."인데 지금은 "국소적으로 흔들리는 블록탑 위에서 안 떨어지게 버티세요!"(`GiantJenga.luau:373`). m5-13 결정 기록은 "문구를 바꾸려면 각 맵 스펙 결정 기록에 적고 GDD도 같이". 다른 맵의 "~요." 말투와도 다르고 "국소적으로"는 아이에게 어려운 말이다. 원래 문구로 되돌리거나 planner가 결정 기록에 남긴다.

### [P3] B3 혼자 가라앉은 테두리 칸은 탑 바깥(허공) 쪽으로 기운다 (설계 확인)
- `tiltFor`는 이웃 중 더 높은 칸의 반대쪽을 낮은 쪽으로 잡는다. 테두리 칸이 이웃보다 낮으면 "낮은 이웃"이 없으니 격자 밖(허공)을 향해 기울고 그쪽으로 민다(예: (2,0) 레벨 2, 이웃 전부 레벨 3 → 낮은 쪽 +X, 6도, 최고 2 studs/s). 결정 D3("격자 밖은 무시")은 "가장자리라서 처음부터 기울지 않게"였고 이 경우는 다루지 않았다. 바깥으로 떨어뜨리는 압박이 의도면 그대로, 아니면 planner가 결정 기록에. 수치·규칙은 `GiantJengaLogic.tiltFor`.
- 위치: `src/shared/maps/GiantJengaLogic.luau:175-205`

### [P3] B4 첫 프레임에 모든 타일이 0.2 위로 올라간다
- `build`는 타일 윗면을 y 0(중심 −0.2)에 두는데, `flatCFrame`은 중심을 `heightOf`(0)에 둔다(`:208-211`). 시작하자마자 25칸 윗면이 0.2 올라가고, 가라앉은 높이도 모두 0.2 위. 서 있는 사람은 살짝 들릴 뿐이라 영향 거의 없음. `- TOP_THICKNESS / 2`를 맞추면 된다.

### 아트 (간단히, m5-24가 다시 씀)
- 장식 예산·시야 상자·손님 얼굴 높이는 개발 테스트로 확인. B1은 장식이 아니라 상태 표시라 아트 패스와 따로 고쳐야 한다.

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자 검증 — 이 맵은 리모트를 쓰지 않음(QA 소스 테스트)
- [x] 통과·탈락·순위 판정이 서버에만 있다 — `ctx.eliminate` 1곳만(`ctx.pass` 없음), Survival 종료·점수는 RoundLogic
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — `board`·`columns`·`previousKeys`는 `start` 지역, 태그는 `taggedInModel(ctx.model, …)`, 랜덤은 `ctx.rng`만(QA 소스 테스트)
- [x] 연결·인스턴스·스레드가 Cleanup으로 정리된다 — Heartbeat 1개·일정 스레드 1개·칸 제거 스레드마다 `ctx.cleanup:add`
- [x] MoveExempt — 국소 기울기 밀기는 연속 밀기라 달지 않음(0곳). 걷기 16 + 밀기 6 = 22 < 감시 수평 상한 80. 가라앉기·사라지기는 서버가 캐릭터를 옮기지 않음(자연 낙하)

## 사용자 Studio 확인 체크리스트
준비: `Config.DEBUG.forceMapPlan = { "rotating-belt", "giant-jenga", "soy-swamp", "skewer-showdown" }`, 끝나면 **`nil`로 되돌린다**.
1. (AC10·B1) 6초쯤 바깥 칸 하나가 삐걱이며 흔들린 뒤 가라앉는지 위에서 본다. 지금은 위에서 보면 변화가 거의 없고 맨 아래 블록만 사라질 것(B1). 가운데 3×3은 끝까지 그대로인지.
2. (AC11) 블록이 빠진 칸 주변만 기울고 다른 곳은 평평한지(셰프의 도마와 다른 느낌인지). B1 수정 뒤 다시 확인.
3. (AC12) 기운 칸 위에서 낮은 쪽(구멍 쪽)으로 서서히 밀리는지. 칸이 완전히 사라지면 서 있던 사람이 떨어져 손님 입 연출이 나오는지.
4. (B3) 테두리 칸 하나만 가라앉았을 때 그 칸이 탑 바깥쪽으로 기울어 밀어내는지 — 의도와 맞는지 의견.
5. (AC13) 48초 이후 1.5초마다 2칸씩 빨라지는지.
6. (AC14) 목표 인원 이하가 되면 바로 끝나고, 60초를 버티면 살아 있는 전원 통과.
7. (AC15) 두 방 동시 진행(Clients and Servers) 시 자기 방 탑만 움직이는지.
8. (AC16) 4명 이상 체감(친구 테스트).

## 추가한 테스트
- `tests/m5-16-qa.spec.luau` (6개): 60초 제거 총량 < 48 / 시드 1~300 한 판 전체 고르기 규칙 + 시드 1~30 매 제거 뒤 25칸 기울기 범위·단위 벡터·축 수직·보호/뚫린 칸 nil, 보호 칸 레벨 불변 / 최저 높이 vs 낙하선 / 걷기+밀기 < 감시 상한 / 소스: `ctx.model` 필터·모듈 상태·MoveExempt·pass·리모트 없음 / 소스: 연결·스레드 cleanup 등록, `Random.new`·`math.random` 없음.

## 인계 메모
- 브랜치: `m5-qa-maps-a`
- 끝난 것: 5단계, AC1~AC9 확인, 서버 코드 리뷰, 회전축 부호 Lune CFrame 확인, QA 테스트 6개, 리포트, 스펙 `in-dev`로 반려.
- 남은 것: developer가 B1(필수, 한 줄)·B4(권장) 수정, B2는 되돌리거나 planner 결정, B3은 planner 판단 → 재QA. Studio AC10~AC16(사용자).
- 다음 첫 단계: developer가 `GiantJenga.luau:303`을 위에서부터 숨기게 바꾸고, 블록 순서를 고정하는 테스트(예: 소스에서 `LEVEL_MAX - newLevel` 확인 또는 블록 높이 계산을 Layout으로 빼서 순수 테스트)를 추가.
- 막힌 점: 없음.

---

## 재QA (2026-10-13, 브랜치 `m5-maps-fix-a`, 수정 커밋 `b036ad8`)
- 결과: **통과**. 스펙 `qa-passed`. B2(문구)는 결정 기록대로 유지하고, GDD §5.3 문구 맞추기는 planner 몫으로 남는다. B3은 메인 세션 결정(테두리 바깥 기울기 ≤ 0.5단위 = 3도)을 기준으로 확인했다.

### 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 0 errors / 0 warnings |
| `lune run tests` | 1587 passed, 0 failed (origin/main `591d84e` 병합 뒤, 재QA 테스트 10개 포함) |
| `luau-lsp analyze` (타입 검사) | 끝 코드 0 |

### 버그별 확인
| 버그 | 결과 | 근거 |
|---|---|---|
| B1 (P1) 맨 아래 블록부터 사라짐 | **고쳐짐** | `Logic.poppedBlockIndex(newLevel) = LEVEL_MAX - newLevel`(3→2 Block1, 2→1 Block2, 1→0 Block3)이고, build는 블록 높이에 `Logic.blockCenterY(n)`(Block1이 맨 위)을 쓴다. 재QA: build의 이름 `Block{level}`·높이 `blockCenterY(level)`과 start의 `FindFirstChild(`Block{level}`)`·`blocks[level]`이 같은 번호를 쓰고, 3단을 차례로 뽑으면 Block1→2→3이 한 번씩 숨겨지고, 남은 블록 윗면은 늘 그 칸 윗면(`heightOf`) 이하다(가라앉은 타일을 가리는 블록이 없다) |
| B2 (P3) rule 문구 | 결정으로 유지 | 결정 기록 2026-10-13. GDD 문구 동기화는 planner |
| B3 (P3) 테두리 칸 바깥 기울기 | **고쳐짐(결정 기준)** | `tiltFor`가 테두리 칸의 바깥 성분을 `EDGE_OUTWARD_MAX_UNITS` 0.5로 자른다. 재QA: 무작위 보드 500개(레벨 0~3, 뚫린 이웃 포함)의 모든 테두리 칸에서 바깥쪽 각도 성분이 3도 이하다. 테두리를 따라가는 기울기(6도)가 그대로인 것은 개발 테스트가 확인한다 |
| B4 (P3) 첫 프레임 0.2 들림 | **고쳐짐** | `flatCFrame`이 `heightOf - TOP_THICKNESS / 2`로 build와 같은 중심 높이를 쓴다(개발 소스 테스트). 밀기 범위(`columnY - 6 ~ + 8`)는 윗면 기준 그대로라 영향이 없다 |

- 변이 확인: 수정 7곳(출구 벽 제거, 수평 속도 지우기, 레이캐스트 3.5, `plankRoll` 부호, `isRiding` 무조건 true, 옛 `newLevel + 1`, 바깥 기울기 상한 제거)을 임시로 되돌리면 재QA 테스트가 모두 실패하는 것을 확인했고, 그 뒤 `src`는 원래대로 되돌렸다.

### 판정 회귀 확인
- 낙하 탈락(`FALL_DEPTH`)·밀기 범위·제거 일정은 바뀌지 않았다. 기울기 상한은 테두리 칸(`i` 또는 `j`가 `±GRID_HALF`)의 바깥 성분에만 걸리고 안쪽 칸은 그대로다. 블록은 충돌 없는 표시용이라 숨기는 순서를 바꿔도 판정에 영향이 없다.

### 추가한 테스트
- `tests/m5-14-16-reqa.spec.luau`의 m5-16 2개(build/start 번호 일치·위에서부터 숨김, 무작위 보드 바깥 기울기 상한).

### Studio 확인 (사용자 확인 필요)
- `forceMapPlan = { "rotating-belt", "giant-jenga", "soy-swamp", "skewer-showdown" }`로 시작해서 확인한다: 6초 뒤 처음 삐걱인 칸을 위에서 보면 맨 위 블록이 사라지고 칸이 4 내려가 보이는지, 혼자 가라앉은 테두리 칸이 바깥으로 거의 기울지 않는지, 시작할 때 칸들이 들썩이지 않는지. 끝나면 `nil`로 되돌린다.

## 인계 메모 (재QA)
- 브랜치: `m5-maps-fix-a`
- 끝난 것: B1·B3·B4 확인, 테스트 2개 추가, 스펙 `qa-passed`.
- 남은 것: Studio 확인(사용자), GDD §5.3 rule 문구 동기화(planner).
- 다음 첫 단계: 사용자 Studio 확인 → docs-writer.
- 막힌 점: 없음.
