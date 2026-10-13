# QA — m5-25 캐릭터 퀄리티 개선 (2단계)

- 스펙: `docs/specs/m5-25-character-quality.md`
- 검증 커밋: `cd6368a` (+ 이 리포트와 함께 커밋한 QA 테스트 `tests/m5-25-qa.spec.luau`)
- 결과: **통과** (P0·P1 없음, P2 0, P3 5) → 스펙 상태 `qa-passed`

## 자동 검증 (2026-10-13, Windows 로컬, rokit 도구)
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | OK |
| `stylua --check src tests tools` | OK |
| `selene src` | 0 errors / 0 warnings / 0 parse errors |
| `lune run tests` | **1767 passed, 0 failed** (QA 테스트 8개 포함) |
| `luau-lsp analyze ... src` | 끝 코드 0 |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 실루엣 | 통과 | `m5-25-character-quality` "AC1: 밥 몸은 알약…", `sushi-body` "넓고 낮은 몸" — 계란초밥 3.80 × 4.32 × 2.97, 폭/높이 0.88, 토핑−밥 폭 0.2 |
| AC2 얼굴 | 통과 | "AC2: 눈은 테두리·흰자·눈동자·하이라이트 4겹…", "AC2: 입은 0.2 이상…" (얼굴 비율 약 27%). 렌더 `after-face.png`, `after-mobile-front.png`(480×270에서 눈·입 보임) 직접 확인 |
| AC3 흰 면·뒷면 | 통과 | "AC3: …뒤에서 보이는 색 집합이 31종 모두 달라요". 개발 중 이 테스트가 슬라이더 버거의 빈 등을 잡아 고쳐짐. `after-gameplay.png`·`after-mobile-back.png`에서 계란초밥 뒷모습(김 끈·띠) 확인 |
| AC4 움직임 로직 | 통과 | `m5-25-character-quality` AC4 6개 + QA "곡선이 끊기지 않아요", "깜빡임 간격…단조 증가" |
| AC5 관절 | 통과 | "AC5: 움직이는 파츠 6개…감은 눈은 평소 숨고…" + QA "build: 31종 모두 Motor6D 정확히 6개…"(진짜 소스를 가짜 환경에서 실행, 용접 대상·C0·CastShadow까지) |
| AC6 색 겹침 | 통과 | "AC6: 토핑 대표색이 비슷한 스킨 쌍은 구별 신호가 2개 이상" |
| AC7 디테일·결함 | 통과 | "AC7: 31종 z-fighting 0·떠 있는 파츠 0…", "Glow는 범위 4·밝기 1.2 이하". QA "LayoutCheck: 원기둥 마개도…같은 겉모습은 빼요"로 검사기 자체도 확인 |
| AC8 공정성 | 통과 | `skins` "기준 파츠 22개…", 등급별 박스·효과 예산 테스트, `m4-13-qa` 31종 build Massless·충돌 없음, QA "히트박스 쪽 코드는 GROUND_OFFSET 하나로…". 판정·속도 코드 변경 없음(diff: `src/server` 변경 0) |
| AC9 성능 | 통과 | "AC9: 파츠 수 — 스킨 하나 ≤ 40, 31종 평균 ≤ 36" (28~40, 평균 34.6). Motor6D 6 |
| AC10 외형 적용 지점 | 통과 | `m3-02-qa` applyAppearance R15·R6 발바닥, `skins` "외형은 AppearanceService 한 곳" |
| AC11 렌더 산출물 | 통과 | `docs/renders/characters/after-*.png` 8장, `docs/developer/m5-25-character-quality.md` 렌더 비평 6회 |
| AC12 검증 5단계 | 통과 | 위 표 |
| AC13~AC18 | **사용자 확인 필요** | 아래 체크리스트 |

추가 확인: 이름표(QA "꼭대기가 이름표 높이보다 0.4 이상 아래") — 가장 높은 소프트아이스크림·유니콘도 여유 0.52. 탈의실 미리보기 카메라(QA "탈의실: …31종 높이가 다 들어와요"). 클라이언트 연출이 Transform만 바꾸는지(QA "연출: …Transform만") — 파츠 크기·CFrame·C0 쓰기 없음, 숨김 경로 2곳에서 관절 초기화.

## 버그
### [P3] 카메라를 아주 가까이 당기면 몸 속 파츠가 비칠 수 있음
- 재현: Studio Play, 마우스 휠로 내 캐릭터에 바짝 줌 → Roblox 기본 카메라가 캐릭터를 반투명(LocalTransparencyModifier)으로 만들 때.
- 기대: 반투명 밥 너머로 이상한 게 안 보임.
- 실제(추정, 렌더러로 못 봄): 평소 밥 속에 숨어 있는 감은 눈 선(Lid)·자락 안쪽·알약 이음이 비칠 수 있어요. 예전 몸도 겹친 파츠가 있었지만 감은 눈 선은 새로 생긴 숨은 파츠.
- 위치: `src/shared/SushiBody.luau` `eye()` Lid. 1인칭 숨김(완전 투명)일 때는 문제없음.

### [P3] 탈락 연출 젓가락이 넓어진 인형 몸을 뚫고 집음
- 재현: 탈락 연출 Chopsticks.
- 실제: 닫힌 젓가락 끝 간격 ±0.45가 인형(폭 3.8) 안쪽. 예전(폭 2.8)에도 안쪽이었지만 몸이 넓어져 더 깊이 박혀 보일 수 있어요.
- 위치: `src/client/fx/CutsceneProps.luau:71` `spread = 0.45 + open * 1.6`. Studio 확인 후 필요하면 닫힘 간격을 몸 폭 절반(약 1.9) 근처로.

### [P3] 잡기 "팔" Beam 시작점이 몸 속
- `src/client/input/GrabController.luau:147` 시작 Attachment가 루트 앞 1 stud — 새 몸 앞면은 −1.2라 0.2 studs는 밥 속에서 시작해요. 보이는 데 지장은 거의 없음.

### [P3] 우승 연출 기본값 상수가 옛 값
- `src/client/fx/VictoryCutsceneController.luau:32` `DEFAULT_GROUND_OFFSET = 2.3` — `SushiBody.GROUND_OFFSET`(2.25)이 없을 때만 쓰는 대비값이라 지금은 안 쓰여요. 정리 대상.

### [P3] 문서가 옛 모습을 설명
- `docs/DEV-SETUP.md` 2-2는 before 그림만, CLAUDE.md·GDD §6 "밥 블록 + 김 띠" 문장은 옛 몸 — docs-writer·planner 몫(스펙 "GDD 변경 제안").

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자 — 새 리모트 없음 (`shared/Remotes.luau` 변경 없음)
- [x] 통과·탈락·순위 판정이 서버에만 있다 — 판정 코드 변경 없음. 모양은 보이기만 하는 파츠(Massless·충돌/쿼리/터치 없음)
- [x] 맵 상태 — 해당 없음
- [x] 정리 — 캐릭터 상태는 기존 `states` 표(캐릭터가 사라지면 지움)에 들어가고, 새 연결·스레드 없음

## 사용자 Studio 확인 체크리스트 (스펙 AC13~AC18)
1. Play(F5) → 로비에서 5초 가만히: 몸이 천천히 오르내리고(발은 바닥에 그대로) 2~5초마다 눈을 깜빡여요(눈이 사라지고 검은 선).
2. WASD로 걷기: 두 발이 번갈아 들리고 앞뒤로 움직여요. Space 점프: 올라갈 때 발이 아래로 늘어지고, 착지 순간 몸이 살짝 내려앉았다 돌아와요.
3. Test → Clients and Servers 2명: 다른 사람 캐릭터도 같은 움직임, 서로 이름표가 머리(왕관·뿔·모자) 위에.
4. `Config.DEBUG.forceMapPlan`으로 날치알·꼬치 맵 → 넘어지면 눈 감고 옆으로 누워 떨고 "@_@". 누운 몸이 바닥에 파묻히거나 뜨지 않아요(누운 높이 1.8).
5. 🍣 스킨 탈의실에서 31종을 넘겨 보며 미리보기가 잘리지 않는지, 관리자 "🛠" 미리보기로 몇 종 입어 보기(스킨 바꾸면 움직임이 이어지는지).
6. 탈락 연출 3종·우승 연출·로비 단상 인형이 땅에 서 있는지(뜨거나 묻히지 않음), 단상 인형 머리가 이름 줄 아래인지. 젓가락이 몸을 너무 깊이 뚫는지(P3).
7. 로보·유령·갤럭시·크라운·유니콘: 빛이 몸 주변만 은은하고 바닥을 크게 물들이지 않는지. 반짝이(Sparkles) 위치(갤럭시 행성, 크라운 보석, 유니콘 뿔 끝, 다이아 성게 큰 다이아, 트리 별, 황금 참치, VIP 금박).
8. 카메라를 내 캐릭터에 바짝 줌(P3): 반투명해질 때 몸 속이 지저분하게 비치는지.
9. Test → Device → 가로 휴대폰: 다른 사람 눈·입이 보이는지, 내 뒷모습으로 스킨이 구별되는지. 사람이 많은 방에서 프레임.

## 추가한 테스트
- `tests/m5-25-qa.spec.luau` 8개: build 구조(31종, 가짜 환경에서 진짜 소스), 이름표 여유, 탈의실 카메라 여유, 연출은 Transform만, 움직임 곡선 연속성, 깜빡임 간격 범위·단조, LayoutCheck 원기둥 마개·같은 겉모습, 발바닥 하나로 맞춤.

## 인계 메모
- 브랜치: `m5-25-character`
- 끝난 것: 자동 검증 5단계, AC1~AC12 통과, QA 테스트 8개, 이 리포트. 스펙 `qa-passed`.
- 남은 것: 사용자 Studio 확인(위 1~9), docs-writer 반영(DEV-SETUP 2-2 after 그림·3-x 확인 목록, CHANGELOG, CLAUDE.md 캐릭터 문단), planner GDD v0.7, 메인 세션 main 병합(병합 뒤 검증 다시).
- 다음 첫 단계: 메인 세션이 병합 여부 결정 → docs-writer.
- 막힌 점: 없음.
