status: ready
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-21 — 스킨 기반 v2 (Wedge · 효과 예산 · 박스 허용치 등급별 분기)

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §6("캐릭터 몸"·"모든 스킨은 히트박스·속도가 똑같아요" 문단), §9.1("스킨이 반드시 초밥일 필요는 없어요"), §9.2("효과 예산"·"1차 확장" 문단) — v0.6
- 담당 개발 worktree: `m5-skinfoundation` (Rojo 포트 34882)
- 공용 파일 수정 담당: 없음 (`SushiBody.luau`·`Skins.luau`는 CLAUDE.md "공용 파일" 보호 목록에 없음. `Config.luau`·`Types.luau` 등 보호 목록 파일은 이 스펙에서 건드리지 않는다 — 예산·허용치 상수는 `SushiBody.luau` 안에 둔다)

## 목표
스킨 제작 도구를 넓힌다: 몸체 파츠에 쐐기(Wedge) 모양을 쓸 수 있게 하고, 에픽·전설 등급은 효과(이펙트) 2개·외곽 상자 ±25%까지 허용해, 등급이 높을수록 "진짜 다르게 생긴" 스킨을 만들 수 있게 한다. 신규 스킨 콘텐츠(겉모습)는 이 스펙이 아니라 `m5-22`가 만든다 — 여기서는 그 스펙이 쓸 도구와 검증 로직만 준비한다.

## 범위
- 포함:
  - `SushiBody.Shape`에 `"Wedge"` 추가, `build()`에 `Instance.new("WedgePart")` 분기.
  - `SushiBody.Effect`에 `"Smoke"`·`"Glow"` 추가, `addEffect()`에 두 종류 구현.
  - 등급별 효과 예산 테이블(`SushiBody.EFFECT_BUDGET`, 일반·레어 1 / 에픽·전설 2)과 등급별 박스 허용치 테이블(`SushiBody.BOUNDS_TOLERANCE`, 일반·레어 ±15% / 에픽·전설 ±25%)을 `SushiBody.luau`에 추가.
  - `Skins.validate`를 확장해 카탈로그 전체(기존 21종 + 앞으로 `m5-22`가 추가할 스킨)가 이 두 예산을 지키는지 서버 시작 때마다 자동으로 잡아낸다.
  - `tests/skins.spec.luau`·`tests/sushi-body.spec.luau`를 새 규칙에 맞게 고친다(아래 "영향받는 기존 테스트" 참고).
  - §2(제안서)의 "바로 가능한 개선" 중 **코드 규칙을 하나도 바꾸지 않는 것**(군함류 알 배치 차별화, 옆·뒤 파츠 추가, 재질·색 대비)은 선택 사항 — 넣어도 되지만 기존 21종의 `hasLayout`/대사/가격 테스트(AC1, AC4)를 깨면 안 된다. **이 스펙의 완료 기준은 아니다.**
  - Studio에서 Wedge 파츠가 실제로 올바르게 보이는지(기울기 방향, 회전 조합), 에픽·전설 2이펙트 스킨을 24명이 동시에 입었을 때 체감 성능이 괜찮은지 확인.
- 제외:
  - 신규 스킨 10종의 실제 디자인(이름·색·모양 데이터) — `m5-22`.
  - 탈의실 UI·미리보기 각도 변경(`ui/Shop*`) — 별도 스펙 대상(제안서 §2-5).
  - 이름표·단상 높이 계산 변경 — GDD v0.6에서 이미 "등급과 무관하게 고정값 유지"로 확정됐고, 코드 확인 결과 `CharacterFxController`의 `NAME_TAG_HEIGHT`(3.6, 고정 상수)와 `SushiBody.GROUND_OFFSET`(스킨마다 같은 고정값, `bounds()` 결과가 아니라 TAMAGO 레이아웃에서 나온 상수)는 스킨별 `bounds()` 값을 전혀 참조하지 않는다. 즉 ±25% 허용치를 넓혀도 이름표·단상·우승 연출 높이는 자동으로 안 바뀐다 — **코드 변경 불필요**, 그대로 둔다.
  - GDD 9.1 "비초밥 테마 허용" 문장은 이미 v0.6에 반영됐다(결정 D 완료) — 이 스펙은 추가로 손대지 않는다.

## 설계 메모 (developer가 그대로 따르거나, 근거를 보고 다르게 판단해도 됨)

### 1. Wedge
- `export type Shape = "Block" | "Ball" | "Cylinder" | "Wedge"`.
- `build()`에서 `spec.shape == "Wedge"`면 `Instance.new("Part")` 대신 `Instance.new("WedgePart")`를 만든다(`WedgePart`는 `Enum.PartType`의 `Shape` 속성이 아니라 별도 클래스라, 기존 `elseif spec.shape == "Cylinder" then part.Shape = ...` 분기와 나란히 둘 수 없다 — 분기 순서를 "어떤 클래스를 Instance.new할지"로 먼저 나누고, 그다음 Ball/Cylinder만 `Shape` 속성을 설정해야 한다).
- **`bounds()`는 그대로 둬도 된다(설계상 확인됨, 구현 전 Studio에서 재확인 권장)**: `WedgePart`의 회전 전 외곽 상자는 `Size`와 똑같은 직육면체다(쐐기 경사면이 한쪽 모서리에서 바닥 전체로 깎여 나가도, 바닥면 전체(최소 Y)와 뒤쪽 모서리(최대 Y)가 Size의 모든 축 극값에 그대로 닿는다 — Block의 외곽 상자와 동일). 지금 `bounds()`가 Ball·Cylinder에도 똑같은 "Size + 회전 행렬" 공식을 쓰는 이유도 이 때문(세 모양 다 회전 전 외곽 상자가 Size 박스와 같다). 그러니 Wedge 전용 근사 로직을 새로 만들 필요가 없다 — 다만 실제로 그런지 lune 테스트 하나(회전시킨 Wedge 스펙의 `bounds()`가 같은 회전의 Block 스펙 `bounds()`와 같은 값이 나오는지)로 확인해 넣는다(AC1).
- Wedge의 "경사면이 어느 축을 향하는지"(Roblox 기본값)는 `rotation` 필드로 이미 조정 가능하니 새 필드는 필요 없다. 실제 방향은 Studio에서 확인(AC3).
- 등급 제한 없음 — Wedge는 모든 등급(일반 포함)에서 쓸 수 있다. 등급별 차등은 효과 개수·박스 허용치뿐이다.

### 2. 효과 예산
- `export type Effect = "Fire" | "Sparkles" | "Smoke" | "Glow"`.
- `SushiBody.EFFECT_BUDGET: { [string]: number }` — 문자열 키(등급 이름)로 둬서 `SushiBody`가 `Skins.Tier` 타입을 몰라도 되게 한다(제안서 §4-B 방향). 값: `{ Basic = 0, Common = 1, Rare = 1, Epic = 2, Legendary = 2 }`.
- `SushiBody.effectCount(layout)`은 지금처럼 그냥 개수(정수)만 센다 — 상한을 그 자리에서 강제하지 않는다. 상한 확인은 "개수 vs 예산 테이블"을 비교하는 쪽(테스트, `Skins.validate`)의 책임으로 분리한다.
- `addEffect()`에 두 분기 추가:
  - `Smoke`: `Fire`와 같은 이유(네이티브 `Smoke` 오브젝트의 최소 크기가 큼)로 `ParticleEmitter` + 연기 텍스처로 구현.
  - `Glow`: 매 프레임 애니메이션(펄스)은 넣지 않는다 — `PointLight`(작은 `Range`·`Brightness`, 예: Range ≤ 8, Brightness ≤ 2)만 붙여 "은은한 빛"을 표현한다. 펄스 같은 움직임이 필요하면 그건 클라이언트 연출(캐릭터당 스크립트 루프 추가) 영역이라 이 인프라 스펙 밖 — 필요해지면 다음 스펙(m5-22 또는 별도)에서 다룬다.
  - 두 효과 다 기존 Fire/Sparkles처럼 `Massless`·충돌 없음 패턴을 따르는 파츠 위에만 붙는다(이미 `build()`가 모든 파츠에 `CanCollide=false` 등을 일괄 적용하니 추가 작업 없음).
- 모바일 파티클 부담: 한 캐릭터당 최대 2개(에픽·전설), 한 방 최대 24명 → 최악의 경우 48개 파티클 에미터가 동시에 존재할 수 있다. `MapKit`의 "맵당 파티클 8개" 예산과 비슷한 개념으로, Studio 확인 AC에 넣는다(아래 AC4). 수치로 더 강하게 제한하고 싶으면(예: 에미터 `Rate`를 낮춘다) developer 재량.

### 3. 박스 허용치 등급별 분기
- `SushiBody.BOUNDS_TOLERANCE: { [string]: number }` — `{ Common = 0.15, Rare = 0.15, Epic = 0.25, Legendary = 0.25 }` (`Basic`은 계란초밥 자신이 기준이라 비율이 항상 1이므로 테이블에 안 넣어도 되고, 넣어도 무해함 — developer 재량).
- `SushiBody.bounds(layout)` 자체(반환 타입 `Bounds`)는 바꾸지 않는다 — "허용치 적용"은 `bounds()` 결과(extents)와 `BOUNDS_TOLERANCE[tier]`를 비교하는 별도 로직(테스트, `Skins.validate`)의 몫이다. 이렇게 하면 `bounds()`를 쓰는 다른 코드(`AppearanceService`는 `GROUND_OFFSET`만 쓰고 `bounds()` 자체는 안 씀 — 확인됨)에 영향이 없다.

### 4. `Skins.validate` 확장 (서버 시작 때마다 자동 검증)
- `Skins.luau`가 `SushiBody`를 `require`한다(`SushiBody`는 아무것도 `require`하지 않으므로 순환 의존 없음 — 확인됨).
- `Skins.validate(list)` 안, 각 스킨에 대해 `SushiBody.hasLayout(skin.id)`가 참일 때만(가짜 id로 테스트하는 기존 "validate가 잘못된 카탈로그를 잡아요" 테스트가 실제 레이아웃이 없는 id를 쓰므로, 이 가드가 있어야 그 테스트들이 지금처럼 "unknown tier" 같은 다른 문제만 잡고 계란초밥으로 대체된 레이아웃 때문에 통과해버리는 걸 막는다 — 또는 통과해도 상관없게 둘지는 developer 판단, 아래 AC2 참고):
  - `SushiBody.effectCount(SushiBody.layout(skin.id))`가 `SushiBody.EFFECT_BUDGET[skin.tier]`(테이블에 없는 tier면 건너뜀 — "unknown tier"는 이미 다른 검사가 잡음)보다 크면 문제로 기록.
  - 외곽 상자 각 축 비율이 `SushiBody.BOUNDS_TOLERANCE[skin.tier]`를 벗어나면 문제로 기록(비교 대상 base는 `SushiBody.layout(Skins.DEFAULT_ID)`의 extents).
- 함수 시그니처(`(boolean, {string})`)는 그대로 — 호출부(`src/server/ShopService.luau:237`)는 수정 불필요.

## 수용 기준
<!-- QA가 그대로 체크할 수 있게 관찰 가능한 문장으로 -->
### 순수 로직 (lune 테스트로 확인)
- [ ] AC1: `SushiBody.layout`에 `shape = "Wedge"`인 파츠가 있어도 `SushiBody.bounds()`가 에러 없이 값을 내고, 같은 `size`·`offset`·`rotation`을 가진 `Block` 스펙과 `bounds()` 결과가 같다(회전된 경우 포함 — 회전 안 한 경우 + 90도 돌린 경우 둘 다 테스트).
- [ ] AC2: `tests/sushi-body.spec.luau`의 "파츠 값이 올바르고" 류 검사(현재 `tests/skins.spec.luau`에 있음)에서 `spec.shape`가 `nil | "Block" | "Ball" | "Cylinder" | "Wedge"` 중 하나인지 확인하도록 고쳐졌다(`Wedge`가 허용 목록에 들어감).
- [ ] AC3: `SushiBody.EFFECT_BUDGET`이 `{ Common = 1, Rare = 1, Epic = 2, Legendary = 2 }`(+`Basic = 0`, 선택)이고, `SushiBody.BOUNDS_TOLERANCE`가 `{ Common = 0.15, Rare = 0.15, Epic = 0.25, Legendary = 0.25 }`이다. 두 테이블 다 `SushiBody.luau`에서 export되고 `Skins`나 다른 모듈을 require하지 않는다(코드로 확인 — `SushiBody.luau` 맨 위에 `require` 줄이 없음).
- [ ] AC4: `tests/skins.spec.luau`의 "효과는 스킨당 1개 이하" 테스트가 "효과는 등급별 예산 이하"로 바뀌었다 — 기존 21종(`aburi-salmon`=Epic 1개, `golden-otoro`=Legendary 1개, `diamond-uni`=Legendary 1개, 나머지 0개)은 전부 그대로 통과하고, 추가로 **에픽·전설 2개짜리 가짜 레이아웃은 통과, 일반·레어 2개짜리 가짜 레이아웃은 실패**하는 걸 보여주는 테스트 케이스가 있다(실제 카탈로그를 안 건드리고 `SushiBody.EFFECT_BUDGET`·임의 레이아웃으로 검증).
- [ ] AC5: `tests/skins.spec.luau`의 "외곽 상자가 ±15% 안" 테스트가 등급별 허용치를 쓰도록 바뀌었다 — 기존 21종은 전부 그대로 통과(지금 다 ±15% 안이므로 더 넓은 에픽·전설 허용치에서도 당연히 통과)하고, 추가로 **에픽·전설 등급으로 ±20%(즉 ±15% 밖, ±25% 안)인 가짜 레이아웃은 통과, 일반·레어 등급으로 같은 ±20%인 가짜 레이아웃은 실패**하는 테스트 케이스가 있다.
- [ ] AC6: `Skins.validate(Skins.LIST)`가 여전히 `(true, {})`를 돌려준다(기존 21종은 전부 새 budget·tolerance를 지키므로). `Skins.validate`에 효과 예산을 초과하는 가짜 스킨(실제 레이아웃이 있는 id를 재사용하되 tier만 낮춰 예산을 넘기게 만들거나, 테스트 전용으로 `SushiBody.LAYOUTS`에 없는 id를 쓰는 대신 실제 존재하는 id로 tier를 바꿔치기하는 방식 등 — 구현 방법은 developer 재량)를 넣으면 문제 목록에 효과 예산 초과 메시지가 들어간다.
- [ ] AC7: 기존 "validate가 잘못된 카탈로그를 잡아요" 테스트(가짜 id `x`, `z` 등, 실제 레이아웃 없음)가 여전히 통과한다 — geometry 검사가 추가돼도 레이아웃이 없는(`hasLayout(id) == false`) 가짜 스킨 때문에 새로 생긴 에러 메시지가 섞여 들어가 이 테스트의 문자열 비교(`t.ok(string.find(...))`)가 깨지지 않는다.
- [ ] AC8: 기존 AC1(카탈로그 21종 표)·AC2(히트박스 기준 동일)·AC4(대사) 테스트는 손대지 않아도 그대로 통과한다(이 스펙은 레이아웃 데이터 자체를 바꾸지 않으므로).

### Studio 확인
- [ ] AC9: Studio에서 `Shape = "Wedge"`를 쓰는 테스트용 파츠(또는 미리보기 패널로) 하나를 만들어 봤을 때, `rotation`을 안 줬을 때 경사면이 어느 방향을 보는지 확인하고, 90도 단위로 돌려서 원하는 방향(귀·스파이크 등 위를 향하는 뾰족함)을 만들 수 있는지 확인한다.
- [ ] AC10: 관리자 미리보기 패널(🛠, m5-02)이나 임시 테스트 스킨으로 효과 2개(예: Fire + Sparkles, 또는 Smoke + Glow)를 가진 레이아웃을 만들어 Studio에서 입혀 보고, 겹쳤을 때 과하게 산만하지 않은지(둘 다 뚜렷이 보이는지) 확인한다.
- [ ] AC11: Studio Test에서(가능하면 여러 클라이언트 또는 `simulateMatchServer`로 다수 캐릭터를 흉내 내서) 효과 2개짜리 에픽/전설 스킨을 **여러 명**(이상적으로는 10명 이상, 24명 테스트가 어려우면 가능한 선에서)이 동시에 입었을 때 눈에 띄는 프레임 드랍이 없는지 확인한다. 어렵다면 최소한 효과 개수가 2배로 늘어난 것치고 한 캐릭터당 비용이 과하지 않은지(에미터 `Rate`·`PointLight.Range` 등 수치) 코드 리뷰로 확인하고 결과를 개발 메모에 남긴다.
- [ ] AC12: 서버 시작 로그에 `Skins.validate` 실패가 없는지(콘솔에 에러 없음) 확인한다.

## 공용 파일 변경
- `shared/Config.luau`: 없음
- `shared/Remotes.luau`: 없음

## 결정 기록
<!-- 날짜 · 질문 · 결정 · 누가 -->
- 2026-10-09 · "Wedge 추가·효과 예산 등급별·박스 허용치 등급별·비초밥 허용, 넷 다 할지" · 승인(위임) · 사용자 (근거: `docs/proposals/skin-quality-and-variety.md` §4, 반영 결과 `docs/GDD.md` v0.6 §6·§9.1·§9.2)
- 2026-10-09 · "이름표·연출 높이 계산도 등급별로 바꿀지" · 아니오, 등급과 무관하게 고정값 유지 · 사용자 (GDD v0.6 §6에 명시, 코드 확인 결과 이미 `bounds()`와 무관한 고정 상수라 변경 자체가 필요 없음)

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
