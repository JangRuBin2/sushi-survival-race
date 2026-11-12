# QA — m6-08 모두의 "공격" + 전설 스킨 4종 (드래곤·용·제트기·섀도 제트)

- 스펙: `docs/specs/m6-08-attack-and-legend-skins.md`
- 검증 커밋: `e3ed7f9` (브랜치 `claude/gracious-curie-tl82em`, main보다 30커밋 앞, m6-09~12 함께)
- 결과: **통과** (P0/P1/P2 없음, P3 5건) → 스펙 `qa-passed`

## 자동 검증 (클라우드 세션, 2026-11-12)
| 명령 | 결과 |
|---|---|
| `rojo build -o /tmp/qa-build.rbxl` | 통과 (QA 직접 실행) |
| `stylua --check src tests tools` | 통과 (QA 직접 실행, QA 테스트 추가 뒤) |
| `selene src` | **근사 std로만 통과**(`cd tools/cloud && selene --config selene.toml ../../src` → 0 errors / 0 warnings). 진짜 Roblox std 검사는 못 함(프록시 인증서, DEV-SETUP 6절) — 로컬에서 한 번 더 |
| `lune run tests` (전체) | **QA는 전체를 돌리지 않음**(메인 세션이 같은 시각 전체 실행 중 — 동시 실행 금지 지시). 개별 실행: `m6-08-attack` 24/0, `m6-08-legend-skins` 14/0, `m6-08-wardrobe-odds` 3/0, `touch-layout` 30/0, `m5-41-qa` 17/0, `localization` 20/0, `skins` 24/0, `m5-31-draw-logic` 25/0, `m5-31-qa` 20/0, **새 `m6-08-qa` 10/0**, **새 `m6-legend-skins-qa` 5/0** |
| `luau-lsp analyze …` | 끝 코드 0 (QA 직접 실행, 소스맵 `/tmp/qa-sourcemap.json`) |

## 수용 기준
| AC | 결과 | 근거 |
|---|---|---|
| AC1 `pickTargets` | 통과 | `m6-08-attack` AC1 3개 + `m6-08-qa` "반지름 딱 10은 맞고 10.001은 안 맞음 — 위·아래도 같은 구", "빈 후보·나만·모두 면역" |
| AC2 `knockFor` | 통과 | `m6-08-attack` AC2 2개 + `m6-08-qa` "튕김 세기는 거리와 무관"(수직 look → -Z 포함) |
| AC3 북(쿨다운·면역·나간 사람) | 통과 | `m6-08-attack` AC3 3개 + `m6-08-qa` "쿨다운 중 record는 false이고 면역도 안 바꿔요, 경계 시각은 풀림"(빈 공격도 쿨다운, 맞은 사람은 바로 반격 가능) |
| AC4 연출 표·미사일 | 통과 | `m6-08-attack` AC4 9개 + `m6-legend-skins-qa` "연출 표: 스킨별 연출은 새 전설 8종뿐" |
| AC5 터치 4버튼·예전 저장값 | 통과 (P3-1 참고) | `m6-08-attack` AC5 4개 + `m6-08-qa` "44px 이상·화면 안", "예전 large 저장값은 그대로". 예전 **compact** 저장값은 기본 배치로 돌아감(스펙이 허용한 동작, P3-1) |
| AC6 현지화 | 통과 | `localization` 20/0(한국어 리터럴·키 누락 없음), CSV `input.attack.btn`·`input.attack.cooldown`·스킨 4종 이름·대사 ko/en |
| 전설 4종 카탈로그·한도 | 통과 | `m6-08-legend-skins` 14/0, `m6-legend-skins-qa`(얻는 길·가격·확률·규칙 표·validate) |
| Studio 확인 (DEV-SETUP 3-18) | **사용자 확인 필요** | 아래 체크리스트 |

## 서버 판정 · 보안 체크
- [x] `AttackInput`: 인자가 하나라도 있으면 무시(`AttackService.luau:132`), 요청 간격 `InputMinInterval` 0.2초(:135-140), 쿨다운은 서버 북(:78), 공격자는 출발한 라운드의 레이서만(`RoundService.activeRoomOf` — 소개·부활 대기·관전·로비 제외, :81), 넘어짐·젓가락·고정·죽음이면 거절(:86).
- [x] 대상은 같은 방 레이서만(:93), 나간 사람 북·간격 기록 정리(:148-155). `AttackFx`는 같은 방 사람에게만, 서버는 `OnServerEvent`를 걸지 않음.
- [x] 넉백은 공용 `Knockback` 한 곳: `MoveExempt.mark`(1.5초 ≥ 넘어짐 1초) → `LinearVelocity` 0.12초 → `PlatformStand` 1초, 탈락 고정(Anchored)이면 일으키지 않음.
- [x] **스킨은 연출만**: `AttackLogic`·`AttackService`·`Knockback`·`DynamiteLogic`·`DynamiteService`에 스킨 id·`AppearanceId`·`Shared.Skins`·`Shared.AttackFxLogic` require 없음, `Config.Attack`은 스킨별 표 없는 숫자뿐(`m6-08-qa` 테스트로 고정).
- [x] 공용 파일(`Config`·`Remotes`·`Attributes`·`Types`·init 2개)은 스펙이 정한 메인 세션 변경. `Config.DEBUG` 커밋 값은 바뀌지 않음. 리모트 16 + 14 = 30.
- [x] 새 화면·창 없음(모바일 버튼·카드 구석 글씨뿐) → `GamepadNav` 등록 대상 없음. L2는 `GamepadNav`가 쓰지 않는 키.

## 버그
### [P3-1] m6-08 전에 저장한 "compact"(엄지 가까이) 배치가 기본 배치로 돌아가요
- 재현: m5-41 편집 화면에서 프리셋 "compact"로 저장(공격 칸 없는 v1) → 이 브랜치로 업데이트 → 모바일로 접속.
- 기대: 저장한 compact 배치(점프·다이브·잡기)가 유지되고 공격 버튼만 빈 자리에.
- 실제: 공격 기본 자리 `{ x = dive.x, y = grab.y }`가 compact의 잡기와 겹쳐 `fit`이 실패 → `resolve`가 nil → 화면은 기본 배치(QA 확인: 844×390·667×375·568×320·1024×768·1366×1024·2400×1080 모두). 잡기와 다이브를 같은 줄에 둔 custom 배치도 같음. "large"는 유지됨(테스트 고정).
- 판단: 스펙 §1이 "겹치면 `fit`이 줄이거나 기본 배치로"를 허용했고 아직 퍼블리시 전이라 P3. 퍼블리시 전에 고치려면 `toScreen`이 공격 후보 자리 몇 개(잡기 왼쪽·다이브 위·잡기 위)를 차례로 보고 겹치지 않는 첫 자리를 쓰면 됨.
- 위치: `src/shared/TouchLayoutLogic.luau:207-208`

### [P3-2] PC·게임패드에는 공격 쿨다운 표시가 없어요
- 남은 초는 모바일 버튼에만(`AttackController.luau:74-86`). 스펙 표 "버튼에 남은 초 표시"대로이지만 F·L2 사용자는 8초 동안 눌러도 아무 반응이 없어 보임. 플레이테스트 뒤 작은 HUD 표시를 검토.

### [P3-3] 공격 범위가 구라서 바닥·선반 너머(위아래 10 studs)도 맞아요
- 스펙대로("구, 방향 무관")지만 층이 있는 맵(팬트리 선반·캣타워·나무 블록)에서 아래층 사람을 바닥 너머로 넘어뜨릴 수 있음. 시야 확인 없음. 플레이테스트 확인 항목.

### [P3-4] 맵의 넘어짐 타이머와 공격 넘어짐이 서로 일찍 풀어요
- 맵(설거지통 수세미·셰프의 도마·찻잎 정원·도시락 뚜껑)이 `PlatformStand = true` 뒤 자기 `task.delay`로 false로 돌리고, 공격 `Knockback`도 자기 타이머로 false로 돌려서 겹치면 짧은 쪽이 먼저 일으킴(최대 1초 차이, 연출 차이뿐).

### [P3-5] 문서 숫자 일부가 m6-11 전 값
- `docs/DEV-SETUP.md:1019` "새 전설 3종 … 전설 각 0.125%, 보유 n/17" → 지금은 전설 9종 각 0.11%, 보유 n/18, 다이너마이트 스시(`Kaboom`) 연출 줄도 없음. `:1020` 예시 "0.13%". `CLAUDE.md:41` 콘셉트 몸 문단에서 `faceHidden` 문장 뒤에 고등어 예외(외곽·이름표 4.8)가 붙어 다이너마이트 예외처럼 읽힘.

## 사용자 Studio 확인 체크리스트 (DEV-SETUP 3-18, Test → Clients and Servers 2~3명)
1. 달리는 중 F / L2 / 모바일 💥 → 하얀 충격파. 로비·소개 카운트다운·관전·부활 대기(3·2·1) 중에는 아무 일도 없음.
2. 반지름 10 안 상대가 바깥으로 튕기고 약 1초 "@_@". 약 11 이상은 안 맞음. 출력 창에 `[MovementGuard]` 경고·되돌림 없음(맞은 쪽 클라이언트에서 특히).
3. 모바일 버튼 회색 "8초 → 1초", 그동안 F 무반응. 서로 공격하면 방금 맞은 사람은 2초 동안 안 맞음.
4. A가 B를 잡은 채 B가 공격 → 잡기 풀리고 A가 넘어짐. 넘어진 사람은 공격 불가.
5. 낭떠러지 옆에서 맞음 → Race는 3초 뒤 부활, Survival·결승은 탈락.
6. 스킨별 연출 5종(드래곤·용·제트기(전투 가면 + 쫓아가는 미사일)·섀도 제트·기본). 같은 방 다른 클라이언트에도 보이는지, 다른 방에는 안 보이는지.
7. 게임패드: L2가 잡기(R2)·다이브(X)와 안 섞이는지, 콘솔에서 L2가 `gameProcessed`로 먹히지 않는지.
8. ⚙ → 버튼 위치 편집에 "💥 공격"(4번째), 프리셋 3개가 겹치지 않음. 예전 compact 배치 계정은 기본 배치로 돌아가는지(P3-1) 확인.
9. 탈의실 전설 탭: 4종 카드 "R$ 199 — 곧 열려요" + 🎫 확률 "0.11%", 뽑기 화면 ⓘ 전설 9줄.

## 추가한 테스트
- `tests/m6-08-qa.spec.luau` (10): 기본값 고정, 반지름 경계(옆·위·아래), 빈 후보, 튕김 세기 일정·수직 look, 북 경계·거절된 공격은 면역 없음, 서버 검증 구조(인자 없음·간격·레이서·같은 방·넘어짐·나간 사람 정리·MoveExempt가 밀기보다 먼저), 판정 파일 5개에 스킨 없음, 터치 44px·화면 안, 예전 large 저장값 유지, 리모트 수 30.
- `tests/m6-legend-skins-qa.spec.luau` (5, m6-09~11 공용): "drawGrade + robux" = 전설 R$ 199 + 뽑기 전설 9종뿐, 등급 확률 그대로·전설 9종 균등(카드 확률 = 뽑기 화면), 번들·VIP에 새 전설 없음, 규칙 표·validate, 연출 표 ⊆ 콘셉트 몸·뽑기.

## 인계 메모
- 브랜치: `claude/gracious-curie-tl82em` (QA 커밋은 push하지 않음 — 메인 세션 지시).
- 끝난 것: AC1~AC6 코드·테스트 검증, 서버 판정 점검, QA 테스트 15개 추가.
- 남은 것: 사용자 Studio 확인(위 1~9), 진짜 Roblox std `selene src`(로컬), 전체 `lune run tests` 결과는 메인 세션 실행분으로 확인.
- 다음 첫 단계: (선택) P3-1 공격 후보 자리 고치기 → docs-writer가 P3-5 문서 숫자 정리.
- 막힌 점: 없음.
