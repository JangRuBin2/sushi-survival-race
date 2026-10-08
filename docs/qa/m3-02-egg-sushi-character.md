# QA — m3-02 계란초밥 캐릭터 (`applyAppearance`) · 걷기/넘어짐 연출

- 스펙: `docs/specs/m3-02-egg-sushi-character.md`
- 검증 커밋: `4499710` (`m3-02-character`) + `origin/main` 병합(`08d49fd`, m3-01 QA) — 충돌 없음
- 결과: **통과 (P0/P1 없음, P2 2건, P3 3건)** → 스펙 상태 `qa-passed`. Studio 확인(AC5~AC10)은 사용자 확인 필요.

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 통과 (0 errors, 0 warnings) |
| `lune run tests` | 통과: 256 passed, 0 failed (병합 후 기존 242 + QA 추가 14) |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 | 통과 | `sushi-body.spec.luau` AC1 3개 (파츠 9개, 이름 중복 없음, 눈 앞면 좌우). QA `build: layout 파츠 전부…`로 실제 `build` 결과도 확인 |
| AC2 | 통과 | `sushi-body.spec.luau` AC2 (높이 4.7, 폭 2.8, 두께 2.3). QA `AC2: 초밥 발바닥이 휴머노이드 발바닥…` — 붙인 위치에서 발바닥이 휴머노이드 발바닥과 같고 꼭대기가 발바닥 위 4.7 |
| AC3 | 통과 | `sushi-body.spec.luau` AC3 + QA `build: 모르는 id도 tamago 파츠로…` |
| AC4 | 통과 | 위 자동 검증 |
| AC5 | 사용자 확인 필요 | 체크리스트 1. 코드상 숨김(몸·액세서리·decal 투명, 얼굴 decal 제거, 늦게 붙는 것도 숨김)은 QA 가짜 환경 테스트로 확인 |
| AC6 | 사용자 확인 필요 | 체크리스트 2. 코드상 두 번 불러도 한 벌·`AppearanceId = "tamago"`는 QA 테스트로 확인 |
| AC7 | 사용자 확인 필요 | 체크리스트 3. 이름표는 B2(위험) 참고 |
| AC8 | 사용자 확인 필요 | 체크리스트 4 |
| AC9 | 사용자 확인 필요 | 체크리스트 5 |
| AC10 | 사용자 확인 필요 | 체크리스트 6. 코드 리뷰상 회귀 위험 낮음 (아래 "M2 판정 회귀") |

요약: 순수 로직 AC1~AC4 통과(4/4), Studio AC5~AC10 사용자 확인 필요(6). 실패한 기준 없음.

## 확인한 것 (코드 리뷰)
- **파일 범위**: 바뀐 파일은 스펙이 지정한 `SushiBody.luau`, `AppearanceService.luau`, `CharacterFxController.luau`, `tests/sushi-body.spec.luau`와 문서(스펙, `docs/developer/`)뿐. 공용 파일(`Config`, `Remotes`, `Types`, `Attributes`, `maps/init`, `default.project.json`) 변경 없음.
- **단일 외형 지점**: 캐릭터에 초밥을 붙이고 아바타를 숨기고 `AppearanceId`를 다는 곳은 `AppearanceService.applyAppearance` 하나. 서버의 다른 파일은 `SushiBody`·`AppearanceId` 쓰기·`CanLoadCharacterAppearance`를 건드리지 않는다 (QA 테스트로 고정). `SushiBody.build`를 클라이언트 인형용으로 쓰는 것(m3-03, m3-05)은 스펙이 정한 용도라 외형 "적용"이 아니다.
- **M2 판정 회귀**: 초밥 파츠는 전부 `Massless`, `CanCollide/CanQuery/CanTouch = false` (QA 테스트로 실제 `build` 결과 확인). M2 맵은 `Touched`를 쓰지 않고 HRP 위치 기준으로 판정하며, 철판 레이캐스트는 `Include` 타일만 본다 (`HotPlate.luau:106-153`). 초밥은 HRP에 `Motor6D`로만 붙어서 휴머노이드 히트박스·`HipHeight`가 바뀌지 않는다. 회귀 위험 낮음.
- **개발이 스펙 밖에서 한 결정 (`LoadCharacterAppearance` / `CanLoadCharacterAppearance = false`)**: 문제 없음. m3-01이 이미 `default.project.json`에 `StarterPlayer.LoadCharacterAppearance = false`를 넣어 두었고(m3-01 결정 기록, GDD 6), 개발의 두 줄은 같은 값을 런타임에 한 번 더 거는 방어 코드다. 그래서 개발 메모의 "남은 이슈"(플레이 솔로에서 첫 캐릭터가 아바타 체형으로 나올 수 있음)는 프로젝트 설정 덕분에 실제로는 생기지 않을 가능성이 높다 — 체크리스트 3에서 같이 확인. 아바타 외형을 다시 켜려면 `default.project.json`까지 바꿔야 한다는 점만 스펙 결정 기록의 "이 두 줄만 빼면 됨"과 다르다 (P3 문서).
- **클라이언트 연출**: `Motor6D.Transform`만 로컬로 바꾸고 복제·판정과 무관. `Transform` 계산(누운 자세 = `(root.CFrame * C0):Inverse() * 목표`)은 `Part1 = Part0 * C0 * Transform * C1⁻¹`(C1 = 단위)과 맞다. 캐릭터가 사라지면 상태·"@_@"를 지운다.
- **서버 판정 원칙**: 이 스펙은 리모트를 추가하지 않는다. 판정 코드 변경 없음.

## 버그
### [P2] B1. 탈락할 때 넘어짐 연출(@_@, 누워 떨기, Knockdown 소리)이 나온다
- 재현: 아무 맵에서 낙하·리셋으로 탈락한다 (Clients and Servers 2명이면 다른 사람 화면도 같이 본다).
- 기대: 탈락은 넘어짐이 아니다. m3-03 머지 뒤에는 탈락 연출(인형)만 보이고 Knockdown 소리는 나지 않는다.
- 실제: `EliminationService`가 탈락자를 고정할 때 `PlatformStand = true`를 켠다(`src/server/EliminationService.luau:77-83`). `CharacterFxController`는 `PlatformStand and Health > 0`을 넘어짐으로 보고(`src/client/fx/CharacterFxController.luau:154-158`) 탈락 연출 3초 동안 공중/바닥에 누워 떨며 "@_@"와 Knockdown 소리를 낸다.
  - m3-03 전(지금): 모든 클라이언트에서 탈락자에게 넘어짐 연출 + 소리.
  - m3-03 뒤: 남의 캐릭터는 숨김을 존중해서 괜찮지만, **내 캐릭터는 숨겨져도 소리를 낸다**(1인칭 숨김과 m3-03 숨김을 구분하지 않음, `:129-131`, `:184-188` — 소리는 그 전 `:157`에서 이미 재생). 내가 먹힐 때마다 Knockdown이 탈락 효과음과 겹친다. m3-03 숨김과 `PlatformStand` 복제 순서에 따라 남의 캐릭터도 첫 프레임에 소리가 날 수 있다.
- 제안(개발 판단): 탈락 고정은 HRP를 `Anchored`로 만들므로 `knocked = PlatformStand and Health > 0 and not root.Anchored`처럼 고정된 캐릭터를 넘어짐에서 빼면 둘 다 해결된다. 또는 m3-09 통합에서 처리.
- 위치: `src/client/fx/CharacterFxController.luau:154`, 관련 `src/server/EliminationService.luau:80`

### [P2] B2. (위험, 사용자 확인 필요) Head를 투명하게 하면 이름표가 안 보일 수 있다
- 재현: 체크리스트 3 (2명, 서로 이름표 보기).
- 기대: AC7 — 이름표(DisplayName)가 머리 위에 보인다.
- 실제(코드): `hideOriginal`이 `Head`를 포함한 모든 몸 파츠를 `Transparency = 1`로 만든다(`src/server/AppearanceService.luau:41-50`). Roblox 기본 휴머노이드 이름표는 Head 기준으로 그려지는데, Head가 완전히 투명하면 이름표가 숨는 동작이 알려져 있어 AC7이 실패할 수 있다. 개발 메모도 "Studio에서 확인 필요"로 남겨 둠. QA는 Studio를 돌릴 수 없어 확정하지 못했다.
- 실패하면: `applyAppearance`에서 이름표용 `BillboardGui`를 직접 달거나(외형 적용 지점 안이라 원칙에 맞음) Head만 투명도를 1 미만으로 두는 방식 중 개발이 고른다. 실패가 확인되면 AC7 실패이므로 P1로 올려 반려한다.
- 위치: `src/server/AppearanceService.luau:30-58`

### [P3] B3. 캐릭터 아래에 나중에 붙는 BasePart는 전부 숨겨진다
- 실제: `DescendantAdded`로 초밥 Model 밖의 모든 BasePart·Decal을 투명하게 한다(`src/server/AppearanceService.luau:52-57`). 다이브(m3-06)·잡기(m3-07) 등이 캐릭터 아래에 보이는 파츠를 붙이면 서버에서 투명해진다.
- 제안: 다른 스펙이 캐릭터에 보이는 파츠를 붙일 때는 `SushiBody` Model 아래에 두거나 캐릭터 밖에 두도록 m3-06/07/09에 알린다.

### [P3] B4. 초밥 Model/관절 이름이 두 곳에 상수로 있다
- 개발이 결정 기록에 이미 적은 것(`AppearanceService.MODEL_NAME/JOINT_NAME`, `CharacterFxController` 상수). QA 테스트 `초밥 Model·관절 이름이 서버…와 클라이언트…에서 같아요`로 어긋나면 잡히게 했다. m3-09에서 공용 상수로 옮길지 결정.

### [P3] B5. 결정 기록 문구: 아바타를 다시 켜려면 두 줄만으로는 안 됨
- `default.project.json`의 `StarterPlayer.LoadCharacterAppearance = false`(m3-01)도 바꿔야 한다. 스펙 결정 기록(developer, "이 두 줄만 빼면 됨")을 고칠 것.

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자를 서버에서 검증한다 — 이 스펙은 리모트를 추가·변경하지 않음
- [x] 통과·탈락·순위 판정이 서버에만 있다 — 판정 코드 변경 없음, 클라이언트 연출은 `Motor6D.Transform`(로컬)만
- [x] 맵 상태가 모듈이 아니라 `ctx`에 있다 — 맵 변경 없음
- [x] 연결·인스턴스·스레드가 정리된다 — 숨김 연결은 재적용·`CharacterRemoving`·`PlayerRemoving`에서 끊음, 클라이언트 상태는 캐릭터가 사라지면 지움

## 사용자 Studio 확인 체크리스트
준비: `rojo serve` → Studio에서 Rojo 연결.

1. **AC5 로비 외형·1인칭** — 혼자 F5. 로비에서 내 캐릭터가 흰 밥 + 노란 계란 + 검은 김 띠 + 눈·입 + 짧은 발의 계란초밥이고, 아바타 몸·옷·모자·얼굴이 하나도 안 보인다. 마우스 휠로 끝까지 줌인해 1인칭이 됐을 때 초밥이 화면을 가리지 않는다(보통 1인칭에서는 내 몸이 사라진다). 다시 줌아웃하면 초밥이 보인다.
2. **AC6 리스폰** — Esc → Reset Character. 다시 계란초밥으로 나온다. Studio 상단 Client/Server 전환으로 **Server** 보기 → Explorer `Workspace/<내 이름>` 아래 `SushiBody` Model이 **하나**뿐이고, 그 안 `Body`에 `SushiJoint`(Motor6D)가 있다. `Workspace/<내 이름>` Properties → Attributes에 `AppearanceId = tamago`. 리셋을 3번 반복해도 한 벌이다.
3. **AC7 2명** — Test → Clients and Servers, 2명. 각 창에서 상대가 계란초밥이고 **머리 위에 상대 이름표가 보인다** (안 보이면 B2 확정 → QA에 알려 주세요). 서버 창 Command Bar:
   `for _,p in game.Players:GetPlayers() do print(p.Name, p.Character.HumanoidRootPart.Size, p.Character.Humanoid.HipHeight) end`
   → 두 줄의 Size·HipHeight가 같다. 첫 스폰(리셋 전)에서도 같은지 본다 (개발 메모 "남은 이슈" 확인).
4. **AC8 걷기** — 걸으면 초밥이 위아래로 통통 튀고 좌우로 살짝 기우뚱, 멈추면 가만히 선다. 점프·낙하 중에는 튀지 않는다. 2명 창에서 상대가 걸을 때도 튀는 게 보인다.
5. **AC9 넘어짐** — `Config.DEBUG.forceMapPlan = { "soy-swamp", "hot-plate", "rotating-belt", "skewer-showdown" }`(커밋 금지). 간장 늪에서 날치알 공에 맞으면 초밥이 옆으로 누워 바르르 떨고 머리 위에 "@_@"가 돌며, 약 1초 뒤 일어나면 원래대로 서고 "@_@"가 사라진다. 빨리 보려면 서버 Command Bar: `game.Players:GetPlayers()[1].Character.Humanoid.PlatformStand = true` → 몇 초 뒤 `false`. (Knockdown 소리는 m3-08 전에는 Sfx 껍데기라 안 들려도 정상.) 꼬치 쇼다운에서 꼬치에 맞았을 때도 같다.
   - 같이 볼 것(B1): 아무 맵에서 떨어져 탈락하면 지금은 탈락자가 누워 떨며 "@_@"가 뜬다 — B1의 현재 동작이다.
6. **AC10 회귀** — 위 forceMapPlan으로 4맵을 한 번씩: 회전 벨트 결승선 통과·젓가락 포획, 간장 늪 와사비 튕김·간장 감속, 철판 타일 밟기(뜨거운 타일에서 탈락), 꼬치 쇼다운 낙하 탈락·우승. M2와 똑같이 동작하고 초밥 때문에 막히거나 안 밟히는 곳이 없다. 끝나면 `forceMapPlan = nil`로 되돌린다.

## 추가한 테스트
`tests/m3-02-qa.spec.luau` (14개) — `SushiBody.luau`와 `AppearanceService.luau`를 가짜 Roblox 환경(Instance·Vector3·CFrame(이동만)·Enum·game)에서 실제로 불러 돌림.
- `build`: layout 파츠 전부, PrimaryPart = Body(Anchored), 나머지는 Body에 WeldConstraint / 모든 파츠 Massless·CanCollide·CanQuery·CanTouch false / 위치 = layout 오프셋 / 모르는 id도 tamago로 만들어짐.
- `applyAppearance`: AppearanceId 기본값, SushiBody 한 벌 + `SushiJoint`(HRP↔Body), Body 고정 해제 / 세 번 불러도 한 벌·옛것 삭제 / 원래 몸·액세서리·decal 투명, 얼굴 decal 제거, 초밥 파츠는 보임 / 늦게 붙는 액세서리 숨김, 초밥 Model 안은 안 숨김, 재적용 뒤에도 숨김 동작 / R15·R6 발바닥 맞춤과 C0 일치, 꼭대기 높이 / HRP 없으면 경고만 / `init()`이 `LoadCharacterAppearance = false`.
- 단일 지점·이름: 서버·클라이언트 초밥 Model/관절 이름 일치, 서버에서 `SushiBody`·`AppearanceId` 쓰기·`CanLoadCharacterAppearance`는 AppearanceService만.

## 인계 메모
- 지금 브랜치: `m3-02-qa` (`origin/m3-02-character` + `origin/main` 병합, QA 커밋 + push)
- 끝난 것: 자동 검증 4종 통과(256/0), AC1~AC4 통과, 코드 리뷰(파일 범위·단일 지점·M2 회귀·아바타 로딩 결정), 리포트, 스펙 상태 `qa-passed`.
- 남은 것: 사용자 Studio 확인 AC5~AC10 (위 체크리스트). 특히 AC7 이름표(B2) — 안 보이면 P1로 올려 반려. B1은 개발이 m3-02 후속 또는 m3-09에서 처리.
- 다음에 할 첫 단계: 메인 세션이 `m3-02-qa`를 main에 병합. 개발에 B1(탈락 고정 캐릭터를 넘어짐에서 빼기) 전달, m3-03/06/07 담당에 B3 공유.
- 막힌 점: 없음.
