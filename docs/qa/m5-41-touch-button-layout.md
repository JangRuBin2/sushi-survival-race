# QA — m5-41 모바일 터치 버튼 위치·크기 편집

- 스펙: `docs/specs/m5-41-touch-button-layout.md`
- 검증 커밋: 브랜치 `m5-41-touch-button-layout` — 개발 b1a31b3 + `origin/main`(1218c5b, m5-32 고등어 병합·B3 수정) 병합 95c7ad4 + 이 QA 커밋
- 결과: **통과** (P0~P2 없음, P3 2건). 스펙 상태 `qa-passed`. Studio 확인 AC11~AC17은 사용자 확인 필요.

## 자동 검증 (main 병합 뒤)
| 명령 | 결과 |
|---|---|
| `git merge origin/main` | 충돌 없음 (95c7ad4) |
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests tools` | 통과 |
| `selene src` | 0 errors, 0 warnings |
| `lune run tests` | **1992 passed, 0 failed** (개발 1942 + main 병합분 + QA 17) |
| `luau-lsp analyze ... src` | 끝 코드 0 |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 기본 프리셋 = `touchButtons` 픽셀까지 | 통과 | `touch-layout` "AC1: preset default = …화면 4종" |
| AC2 비율↔픽셀 왕복, 다른 휴대폰 | 통과 | `touch-layout` AC2 3개 (D9: 반올림 전 1px, 반올림 뒤 휴대폰 2px) |
| AC3 클램프 (44px~35%, 0.7~1.6배, 왼쪽 40%, 위쪽 띠, 노치, 간격 8) | 통과 | `touch-layout` AC3 + QA "끌기·크기 조절을 아무리 반복해도…"(400번 무작위, 노치 47·위쪽 바 58) |
| AC4 겹침 problem, 작은 화면 fit → default | 통과 | `touch-layout` AC4 2개 + QA "아주 작은 화면·세로 화면" |
| AC5 large·compact 규칙 | 통과 | `touch-layout` AC5 + QA "왼쪽 노치(47)·위쪽 바(58)·아래 홈 바(21)" (개발 테스트는 오른쪽 노치만 — 왼쪽 노치·위 안전 영역 추가) |
| AC6 `sanitizeSettings` 부분 저장 검증 | 통과 | `touch-layout` AC6 + QA "sanitizeChange 경계"(reset+layout, 숫자 키, 키 1만 개 표, 버전·preset 타입·대소문자, 끝값 0/1/0.04/0.4 통과, 원본과 별개 표) |
| AC7 병합·칸별 간격 | 통과 | `touch-layout` AC7 + QA: 진짜 DataService(메모리)로 "틀린 요청은 간격을 쓰지 않아요 (D11)", "부분 수락" |
| AC8 불러오기 복구 | 통과 | `touch-layout` AC8 + QA "묶음 안 버튼 하나만 망가져도…"(NaN, 모르는 묶음, 경제 필드 유지, 다시 불러와도 같음) |
| AC9 관전 화살표 | 통과 | `touch-layout` AC9 + QA "버튼이 위쪽 띠 바로 아래·오른쪽 끝" |
| AC10 리모트 수·설명·5단계 | 통과 | 리모트 27개 그대로(D7 — 스펙의 26은 m5-31 전 기준), 5단계 위 표 |
| AC11 편집 안 하면 같음, 다이브 옮겨 저장 | 사용자 확인 필요 | 코드: 기본 배치면 `current() == nil` → 다이브·잡기는 예전 계산 그대로, 점프는 손대지 않음 |
| AC12 점프 버튼이 되돌아가지 않음 | 사용자 확인 필요 | 코드 리뷰 통과(아래 "클라이언트 리뷰"). **실측 전** — 되돌아가면 D3 대안 |
| AC13 금지 구역·겹침 빨간 테두리·44px | 사용자 확인 필요 | 순수 규칙은 AC3·AC4 테스트로 확인 |
| AC14 편집 중 입력 안 나감, 취소·기본값·프리셋 | 사용자 확인 필요 | QA "편집 중 입력 막기"(소스) |
| AC15 라운드 중 잠금·자동 닫힘 | 사용자 확인 필요 | QA "편집 잠금 — 실제 이벤트 순서"(가짜 환경). 소개·라운드 중 잠금, 통과·탈락·결과에서 풀림 확인. Starting은 B1 |
| AC16 리셋·로비 복귀 유지, iPad 따로 | 사용자 확인 필요 | 순수: 묶음 경계 500/501 QA |
| AC17 관전 화살표, PC에서 ⚙ 없음 | 사용자 확인 필요 | QA "PC·게임패드"(소스 + 가짜 환경 `current() == nil`) |

순수 로직 AC1~AC10: **10/10 통과**. Studio AC11~AC17: 7개 사용자 확인 필요.

## 버그
### [P3] B1 "Starting" 단계 편집 잠금이 실제로는 걸리지 않아요 (D10) — **고침 (2026-10-16, main)**
- 수정: `RoomUpdated`는 InMatch가 **아닐 때만** phase·alive·passed를 지워요(InMatch로 바뀔 때 먼저 온 Starting을 지우지 않음). `tests/m5-41-qa.spec.luau` 기대값 `startingLocked == true`.
- 재현: 방에서 시작 → 카운트다운(Starting) 동안 ⚙ 메뉴를 연다.
- 기대(D10): Starting부터 "라운드 중에는 편집할 수 없어요".
- 실제: 서버 `RoomService.beginMatch`가 `RoomUpdated`를 `task.defer`로 미루고(`src/server/RoomService.luau:196-197`, flush 155-160), 그사이 `MatchService`가 `MatchPhase Starting`을 먼저 보냄(`src/server/MatchService.luau:247`). 클라이언트는 Starting을 받은 뒤 `RoomUpdated InMatch`에서 `was == false`라 `phase = nil`로 지움 → RoundIntro가 올 때까지 안 잠김. RoundIntro에서는 잠기고 열린 편집 화면도 닫히므로 AC15("소개 포함", "열어 둔 채 시작하면 닫힘")는 지켜짐 — 결과는 "카운트다운 중에 열었다가 소개에서 닫힘"(D10이 막으려던 일).
- 위치: `src/client/input/TouchLayoutController.luau:443-452` (`if not inMatch or not was then phase = nil`). 고칠 방향 예: InMatch로 바뀔 때는 phase를 지우지 않고, InMatch가 **아닐 때만** 지움.
- 테스트: `tests/m5-41-qa.spec.luau` "편집 잠금 — 실제 이벤트 순서"가 지금 동작(`startingLocked == false`)을 기록. 고치면 기대값을 true로.

### [P3] B2 점프를 옮긴 상태에서 "기본"/"기본값으로" 미리보기가 실제 기본 자리와 조금 다를 수 있어요
- 재현: 점프를 옮겨 저장 → 다시 편집 → "기본값으로". 노치가 있는 기기(TouchGui가 안전 영역 인셋을 쓰는 경우).
- 기대: 미리보기 = 저장 뒤 실제로 돌아갈 Roblox 기본 점프 자리.
- 실제: 점프가 옮겨져 있으면(`state.moved`) `defaultButtons()`가 실제 점프 위치 대신 `UiLayout.touchButtons(w, h)`(전체 화면 기준 상수)를 써서, 안전 영역 인셋만큼 미리보기가 어긋날 수 있음. 저장하면 점프는 `native` 값으로 정확히 돌아가므로 겉모습(미리보기)만의 문제.
- 위치: `src/client/input/TouchLayoutController.luau:155-169`, `src/client/ui/TouchLayoutEditor.luau:403-408`. 고칠 방향 예: `state.native.position/size`를 부모 기준으로 계산해 쓰기. Studio AC14에서 눈에 띄면 고침.

## 서버 판정 · 보안 체크
- [x] `SaveSettings` 인자 검증: 표 타입, `muteLevel` 정수 1~3, `touchLayout` = `bucket`(phone/tablet), `layout`(키 5개 이하·문자열 키만, `v == 1`, preset 4종·16자, 버튼 셋 각각 키 3개 `x`/`y` 0~1·`s` 0.04~0.4, NaN·±inf 거절) 또는 `reset == true`(둘 다·둘 다 없음 거절). 하나라도 틀리면 요청 전체 무시. 큰 표는 `onlyKeys`가 max+1번째에서 멈춤.
- [x] 맨 위 모르는 칸(D8): 읽지 않고 버림 — 진짜 DataService로 `coins`·`wins`·`ownedSkins`·`equippedSkin`·`version`·중첩 `settings`를 같이 보내도 경제 필드가 그대로(QA 테스트). `applySettings`는 `profile.settings`만 받음 → 구조상 경제 필드에 닿지 않음. 기존 m4-01·m4-07 테스트(`{ muteLevel = 2, coins = 999 }` → `{ muteLevel = 2 }`) 그대로 통과.
- [x] 칸별 간격(D11): 검증 → 간격 순서(`DataService.luau` `onSaveSettings`), 틀린 요청 바로 뒤 맞는 요청을 받음, 같은 칸 0.5초 안은 버림, 다른 칸은 받음. 퇴장 때 `lastSettingsAt[player] = nil`(DataService.luau:368).
- [x] 변경은 `DataService.update` 안에서만 (`ProfileSchema.applySettings`).
- [x] 불러오기: `touchLayout`만 틀리면 그 묶음만 버리고 메모, 버전 3 유지, `muteLevel`이 틀리면 예전처럼 설정 전체 기본.
- [x] 배치는 겉모습뿐 — 판정·경제와 무관. 서버 → 클라이언트 신호를 서버가 듣지 않음(새 리모트 없음).
- 판정·맵 상태·Cleanup(맵): 해당 없음.

## 개발 판단 D7~D12 검토
- D7 리모트 27: main 실제 값 기준, 새 리모트 없음 — 스펙 취지(리모트 추가 없음)와 맞음.
- D8 맨 위 모르는 칸은 버림: 기존 테스트 고정값과 맞고 경제 필드를 못 바꿈(확인). "알 수 없는 키 거절"을 `touchLayout` 안에 적용한 해석이 타당.
- D9 반올림 위치: 2400px에서 셋째 자리 한계 수학이 맞음(0.0005 × 2400 = 1.2px). 타당.
- D10 Starting 잠금: 취지는 맞지만 실제 이벤트 순서에서 안 걸림 → B1(P3).
- D11 검증 통과한 칸만 간격: 서버가 받는 일이 늘지 않음(검증이 키 수 상한으로 작게 끝남) — 타당. 진짜 DataService로 확인.
- D12 기본 점프 버튼 옮기기 먼저: 스펙 D3 순서 그대로, AC12 실측에 맡김 — 타당.

## 클라이언트 리뷰
- 편집 중 입력: 다이브 `InputBegan`이 `isEditing()`이면 `onPress` 안 부름 + gui 끔, 잡기는 무시 + 잡고 있던 것 놓음(`release`), 점프는 숨김, 덮개 Frame `Active = true`(DisplayOrder 60)가 아래 터치를 막음. 편집 화면은 잠금이 걸리면 저장 없이 닫힘, 터치 컨트롤이 꺼지면(키보드로 바뀜) 취소.
- 점프 다시 적용: 신호 핸들러는 `applying` 중이면 무시, 지연 신호(Deferred)로 늦게 온 우리 값은 `desired`와 비교해 `native`에 기록하지 않음, 값이 같으면 쓰지 않음, `task.defer` 한 번(`queued`) → 우리 쓰기가 다시 쓰기를 부르지 않아 **무한 루프 없음**. 매 프레임 루프 없음. PlayerModule이 점프 버튼을 새로 만들면 `DescendantAdded`·1초 확인으로 다시 붙음. 깜빡임 여부는 AC12 실측.
- 연결 정리: 편집 화면 세션은 `connections`·`stops`를 닫을 때 끊음. 컨트롤러·⚙·관전 화면·다이브·잡기는 한 번만 만드는 단일 객체(다이브·잡기는 destroy에서 `changed` 해제).
- PC·게임패드: `TouchEnabled`가 아니면 ⚙·기준 gui를 만들지 않고 `current()`가 nil → 아무것도 안 바뀜. 터치 + 키보드는 `TouchGui.Enabled`를 따라 ⚙ 보임/숨김.
- 기존 테스트: 브랜치 diff에서 `tests/`는 새 파일 `touch-layout.spec.luau`뿐 — 기존 테스트 수정·삭제 없음(`git diff d37a1c4 b1a31b3 --stat -- tests/`).

## 사용자 Studio 확인 체크리스트
준비: Studio → Test 탭 → Device(기기 에뮬레이터)에서 휴대폰 가로를 고르고 Play. `minPlayersToStart = 1`(커밋 값)이라 혼자 방을 시작할 수 있어요.

1. **AC11 (편집 안 함)**: iPhone(작은 화면) 가로로 Play. 점프·다이브·잡기 버튼 자리가 이 브랜치 전과 같은지(다이브는 점프 왼쪽, 잡기는 점프 위). 위쪽 바 음소거 버튼 왼쪽에 ⚙가 있는지.
2. **AC11 (다이브 옮기기)**: ⚙ → "✋ 버튼 위치 편집". 다이브를 끌어 옮기고, 눌러서 고른 뒤 "크게 +"를 두 번 → "저장". 바로 그 자리·크기로 보이고, 눌렀을 때 다이브가 되는지.
3. **AC12 (가장 중요)**: 다시 편집 → 점프를 왼쪽 위쪽(허용되는 곳)으로 옮겨 "저장". 그다음
   - 점프 버튼이 그 자리에서 실제로 점프가 되는지.
   - 캐릭터 리셋(Esc → Reset Character) 뒤에도 그 자리인지.
   - 방을 만들어 시작 → 소개 → 라운드 시작 뒤에도 그 자리인지.
   - 에뮬레이터 기기를 다른 휴대폰으로 바꾼 뒤에도(화면 크기 바뀜) 비율대로 그 근처인지.
   - 위 어느 때든 **원래 자리로 돌아가거나 깜빡이면** 알려 주세요(자체 점프 버튼으로 바꿔요).
4. **AC13**: 편집 중 버튼을 화면 왼쪽(빨간 "이동 조이스틱 자리"), 위쪽 띠, 화면 밖으로 끌어 보기 → 못 들어가야 해요. 두 버튼을 붙이면 빨간 테두리 + 안내 "버튼이 겹쳐요" + "저장"이 회색. "작게 −"를 계속 눌러도 일정 크기 아래로 안 작아지는지.
5. **AC14**: 편집 중에 버튼 복사본을 눌러도 캐릭터가 다이브·잡기·점프를 하지 않는지, 화면을 끌어도 카메라·이동이 안 되는지. "취소"는 바꾼 걸 버리는지. "기본값으로" → "저장"하면 처음 배치로 돌아가는지(이때 미리보기와 저장 뒤 자리가 조금 다르면 B2 — 알려 주세요). "크게"·"엄지 가까이" 프리셋이 바로 보이는지.
6. **AC15**: 방 시작 → 소개·라운드 중 ⚙ 메뉴 항목이 회색 "라운드 중에는 편집할 수 없어요"인지. 카운트다운(Starting)부터 메뉴 항목이 회색인지(B1 고침), 카운트다운 직전에 편집을 열어 둔 채 시작하면 편집이 닫히고 버튼이 정상인지. 탈락 뒤 관전 중·결승선 통과 뒤 대기석에서는 열리는지.
7. **AC16**: 리셋·로비 복귀 뒤에도 배치가 남는지. 에뮬레이터를 iPad로 바꾸면 휴대폰 배치와 따로(처음엔 기본) 쓰이는지, iPad에서 편집·저장 뒤 휴대폰으로 돌아오면 휴대폰 배치가 그대로인지.
8. **AC17**: 탈락해 관전할 때 ◀ ▶가 옮긴 버튼과 겹치지 않는지. 에뮬레이터를 끄고 PC 화면으로 Play하면 ⚙가 없고 아무것도 달라지지 않는지(게임패드가 있으면 그것도).

## 추가한 테스트
- `tests/m5-41-qa.spec.luau` (17개): 진짜 DataService(메모리, m4-01-qa 가짜 환경)로 경제 칸 무시·D11 간격·부분 수락·reset, `sanitizeChange` 경계(타입·키·큰 표·끝값·별개 표), `applySettings`가 update 안·검증 뒤 간격(소스), 불러오기 복구·멱등, 노치·위쪽 바 화면의 프리셋·fit, 아주 작은·세로 화면, 묶음 경계 500/501, 끌기·크기 400번 무작위, 관전 화살표 경계, 편집 잠금 실제 이벤트 순서(가짜 클라이언트 — B1 기록), 편집 중 입력 막기·점프 다시 적용 가드·PC 가드(소스).

## 인계 메모
- **브랜치**: `m5-41-touch-button-layout` (main 1218c5b 병합, push됨). main 병합 안 함.
- **끝난 것**: QA — 병합 뒤 5단계 통과(1992 passed, 0 failed), AC1~AC10 통과, 보안·D7~D12·클라이언트 리뷰, QA 테스트 17개. 스펙 `qa-passed`.
- **남은 것**: 사용자 Studio 확인 AC11~AC17(특히 AC12). P3 B1·B2는 막지 않음 — 개발이 다음에 손댈 때 고치면 됨(B1을 고치면 `m5-41-qa` "편집 잠금" 테스트의 `startingLocked` 기대값을 true로).
- **다음에 할 첫 단계**: 메인 세션이 main 병합 → 병합 뒤 검증 다시 → 사용자에게 위 체크리스트 전달. AC12가 실패하면 developer가 D3 대안(`TouchLayoutController.applyJump`/`attachJump`).
- **막힌 점**: 없음.
