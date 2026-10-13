# QA — m5-21 스킨 기반 v2 (Wedge · 효과 예산 · 박스 허용치 등급별 분기)

- 스펙: `docs/specs/m5-21-skin-foundation-v2.md`
- 검증 커밋: `4192744` (main, m5-21 병합 `4afea72` 포함) + QA 테스트 추가 커밋 (브랜치 `m5-qa-quality-skins`)
- 결과: **통과** (P0/P1 없음, P3 2건) → 스펙 상태 `qa-passed`

## 자동 검증
| 명령 | 결과 |
|---|---|
| `rojo build -o build.rbxl` | 통과 |
| `stylua --check src tests` | 통과 |
| `selene src` | 0 errors / 0 warnings |
| `lune run tests` | **1256 passed, 0 failed** (m5-21 QA 7개 추가) |
| `luau-lsp analyze ...` (타입 검사) | 종료 코드 0 |

## 겉모습 전용 규칙 확인 (CLAUDE.md "스킨 · 상점 규칙", GDD 9.1)
- `SushiBody.build`는 Wedge 포함 **모든 파츠**에 `Massless = true`, `CanCollide/CanQuery/CanTouch = false`, Body만 Anchored, 나머지는 Body에 WeldConstraint. 판정은 Humanoid라 스킨과 무관. 가짜 Instance로 build해 확인(`m4-13-qa` 31종 + `m5-21-qa` Wedge·Smoke·Glow).
- 이름표·단상·연출 높이는 `GROUND_OFFSET`(2.3 고정)·`NAME_TAG_HEIGHT`(고정)만 쓰고 `bounds()`를 안 본다. 31종 모두 발바닥 y = −2.3(토핑이 발 아래로 안 내려감) — `m5-21-qa`.
- 새 효과: `Smoke` = `ParticleEmitter`(Rate 10, Lifetime 0.6~1.0), `Glow` = `PointLight`(Range 8, Brightness 2, 애니메이션 없음). 이동·속도에 닿는 코드 없음.

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 Wedge bounds == Block | 통과 | `sushi-body.spec`(0°·90°) + `m5-21-qa`: 20°, (10,0,15), 45°, (30,60,90), −25° 등 임의 회전도 같음 |
| AC2 shape 허용 목록에 Wedge | 통과 | `skins.spec` "파츠 값이 올바르고" |
| AC3 예산·허용치 표, SushiBody에 require 없음 | 통과 | `sushi-body.spec`, `m5-21-qa` |
| AC4 효과 등급별 예산 | 통과 | `skins.spec` + `m5-21-qa`: **`Skins.validate` 자체**가 일반 1 통과·레어 2 실패·에픽 2 통과·전설 2 통과·전설 3 실패 ("effect budget exceeded") |
| AC5 박스 등급별 허용치 | 통과 | `skins.spec` + `m5-21-qa`: `Skins.validate`가 일반·레어 1.14 통과/1.16·1.20 실패, 에픽 1.20·1.24 통과/1.26 실패, 전설 1.24 통과/1.30 실패 ("outside tolerance") |
| AC6 validate(LIST) == true, 예산 초과 메시지 | 통과 | `skins.spec`, `m5-21-qa` (가짜 레이아웃을 주입한 새 Skins 인스턴스로 실제 카탈로그는 안 건드림) |
| AC7 가짜 id 테스트 그대로 | 통과 | `skins.spec` 기존 테스트 + `m5-21-qa`: 레이아웃 없는 id·모르는 등급은 기하 검사 건너뜀, 에러 없음 |
| AC8 기존 AC1·AC2·AC4 무수정 통과 | 통과 | 병합 diff 확인, 전체 테스트 통과 |
| AC9 Wedge 기울기 방향 | 사용자 확인 필요 | 체크리스트 1 (m5-22 고양이 귀·왕관·갈기로 같이 확인) |
| AC10 효과 2개 겹침 | 사용자 확인 필요 | 체크리스트 2 (m5-22 갤럭시 롤·크라운 참치·유니콘 롤) |
| AC11 다수 동시 착용 성능 | 사용자 확인 필요 (코드 리뷰 통과) | 캐릭터당 최악 에미터 2개 또는 에미터 1 + 라이트 1(Range 8). 24명 최악 48개. 체크리스트 3 |
| AC12 서버 시작 validate 에러 없음 | 사용자 확인 필요 (lune 통과) | `ShopService.luau:237` 호출, lune에서 `(true, {})`. 체크리스트 4 |

순수 로직 8개 통과 / 8개, Studio 4개는 사용자 확인 필요.

## 버그
### [P3] B1 CLAUDE.md 스킨 규칙이 아직 "효과 1개 이하"·"16종"
- 위치: `CLAUDE.md:25`("토핑·색·효과 1개 이하"), `CLAUDE.md:27`·`:107`("16종" — 지금 31종).
- 기대: GDD v0.6대로 "효과 등급별 예산(일반·레어 1, 에픽·전설 2), 외곽 상자 일반·레어 ±15%·에픽·전설 ±25%".
- 담당: docs-writer (코드 문제 아님).

### [P3] B2 `setEffectsEnabled`가 캐릭터 아래 모든 PointLight를 켜고 끈다
- 위치: `src/shared/SushiBody.luau:943-948`
- 내용: 탈락 연출이 진짜 캐릭터의 효과를 숨겼다가 다시 켤 때(`EliminationCutsceneController.luau:244`) 캐릭터 아래 **모든** `PointLight`(그리고 파티클)를 무조건 `Enabled = true`로 되돌린다. 지금은 캐릭터에 스킨 Glow 말고 다른 PointLight가 없어 문제없다. 나중에 VIP·연출 팩 등이 일부러 꺼 둔 빛을 캐릭터에 달면 켜져 버린다. 그때 `Name == "SkinEffect"`로 좁히면 됨.

## 서버 판정 · 보안 체크
- [x] 클라이언트 RemoteEvent 인자 검증 — 새 리모트 없음.
- [x] 판정이 서버에만 있다 — 스킨 파츠는 충돌·쿼리·터치 없음, Massless. 판정 코드 변경 없음.
- [x] 맵 상태가 `ctx`에 있다 — 해당 없음.
- [x] 정리 — 효과는 스킨 파츠 자식이라 모델과 함께 사라짐.
- [x] 카탈로그 검사 — `Skins.validate`가 서버 시작 때 등급별 예산·허용치를 잡는다(새 스킨이 규칙을 어기면 서버 Output에 문제가 뜸).

## 사용자 Studio 확인 체크리스트
(m5-22와 같이 하면 편하다 — 실제 Wedge·2효과 스킨이 m5-22에 있음)
1. **AC9 Wedge 방향**: 탈의실("🍣 스킨")에서 고양이 초밥·크라운 참치·유니콘 롤을 입혀 본다. 고양이 귀·왕관 뾰족이가 **위로 뾰족한 쐐기**로 보이는지, 경사면 방향이 이상하면(뒤집혀 보이면) 어느 쪽을 보는지 적어 둔다. (Roblox WedgePart 기본: 경사면이 위·앞(−Z)쪽을 향함)
2. **AC10 효과 2개**: 갤럭시 롤(반짝이 + 빛)·크라운 참치(왕관 반짝이 + 망토 빛)·유니콘 롤(뿔 반짝이 + 갈기 빛)을 입고 두 효과가 다 보이는지, 너무 산만하지 않은지 본다.
3. **AC11 성능**: Test → Clients and Servers로 가능한 만큼(4명 이상) 접속해 모두 2효과 스킨을 입고(관리자 "🛠" 미리보기 사용 가능) 한 판을 달려 본다. 프레임이 눈에 띄게 떨어지지 않는지(View → Stats 또는 Shift+F5).
4. **AC12**: 서버 시작 Output에 `Skins.validate`·`catalog` 관련 경고·에러가 없다.
5. 탈락 연출 때 진짜 캐릭터의 반짝이·빛이 같이 사라졌다가 연출이 끝나면 다시 켜지는지(2효과 스킨으로).

## 추가한 테스트
- `tests/m5-21-qa.spec.luau` (7개)
  - Wedge bounds == Block bounds (회전 없음 + 90도가 아닌 회전 5가지)
  - 예산·허용치 표 값, SushiBody에 require 없음
  - `Skins.validate` 박스 경계(등급별 통과/실패 9가지) — 가짜 레이아웃 주입
  - `Skins.validate` 효과 예산(등급별 통과/실패 5가지)
  - 모르는 등급·레이아웃 없는 id는 기하 검사 건너뜀
  - 가짜 Instance build: Wedge → WedgePart(.Shape 설정하면 에러 나게 한 가짜로 확인), 용접됨, Smoke → `SkinEffect` 에미터, Glow → Range ≤ 8·Brightness ≤ 2 PointLight, `setEffectsEnabled`가 PointLight도 끄고 켬, 모든 파츠 Massless·충돌·쿼리·터치 없음
  - 31종 발바닥 높이 같음, `GROUND_OFFSET` 고정

## 인계 메모 (2026-10-13)
- 브랜치: `m5-qa-quality-skins` (worktree `agent-ab46a7b4445ffb810`, main `4192744` 위)
- 끝난 것: 자동 검증 5단계, AC1~AC8 확인, 겉모습 전용 규칙 확인, QA 테스트 7개, 리포트, 스펙 상태 `qa-passed`.
- 남은 것: 사용자 Studio 확인(AC9~AC12). B1은 docs-writer가 CLAUDE.md 갱신.
- 다음에 할 첫 단계: docs-writer 반영 후 `done`.
- 막힌 점: 없음.
