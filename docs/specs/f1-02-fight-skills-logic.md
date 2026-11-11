status: in-qa
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# f1-02 — 스시 파이트 특수 스킬 (로직)

- 마일스톤: F1 (스시 파이트 MVP)
- GDD 근거: `docs/fight/GDD.md` v0.2 §5.1
- 담당 개발 worktree: `sushi-fight` 브랜치
- 공용 파일 수정 담당: 없음 (`src/shared/fight/`만)

## 목표
"엄청 좋은 캐릭터들은 특수스킬 넣어주자"(사용자, 2026-11-11)를 페이투윈 없이 넣는다. 사용자 선택: **스킬은 누구나 공짜, 에픽·전설 스킨은 연출만**. 이번 스펙은 서버가 쓸 순수 로직과 수치까지다.

## 범위
- 포함: 스킬 6종 카탈로그·수치, 스킬 게이지(충전·발동), 에픽·전설 14종 시그니처 표(겉모습 필드만), 스킬 선택 검증, 판정 도우미(폭발 대상, 방패 guard, 대시 도착점, 끈끈이 감속, 입가심 회복), `FightLogic.hit`의 `guard` 입력.
- 제외: 서버 실행·리모트(F1-03/F1-06), 버튼 길게 누르기 입력(F1-04), 스킬 효과·시그니처 연출 렌더(F1-06), 스킬 고르기 화면·문구 CSV(F1-06/F1-07), 고른 스킬 저장(F1-03 결정).

## 수용 기준
### 순수 로직 (`tests/fight-skills.spec.luau`)
- [x] AC1: 스킬 6종(`WasabiBurst`·`NoriShield`·`SoyDash`·`RiceSticky`·`SushiSpin`·`GingerCleanse`), 각자 `FightConfig.Skills`에 수치가 있다.
- [x] AC2: 시그니처는 `Skins.LIST`의 tier가 Epic·Legendary인 스킨 **전부이고 그것만**(지금 14종 — 시즌 2·VIP 1·고등어 포함). 스킨이 추가되면 테스트가 시그니처를 요구한다.
- [x] AC3: 시그니처 필드는 `skill`·`color`·`fx`뿐(수치 필드 금지), fx는 Fire·Sparkles·Smoke·Glow, 색은 RGB 정수.
- [x] AC4: 스킬마다 시그니처 스킨이 2개 이상.
- [x] AC5: 처음 고른 스킬 = 시그니처(없으면 와사비 폭발). 클라이언트가 보낸 선택은 6종이면 그대로, 아니면 스킨 기본값 — **어떤 스킨이든 6종 전부 고를 수 있다**.
- [x] AC6: 스킬 게이지 상한 100, 초당 +2, 맞히기 +6, 맞기 +4, KO +20. 다 차야 발동, 발동하면 0.
- [x] AC7: 와사비 폭발 대상 = 나를 뺀 수평 반경 9 이내(경계 포함).
- [x] AC8: 김 방패 2.5초 동안 `FightLogic.hit`이 게이지 증가 50%·넉백 35%만 준다.
- [x] AC9: 간장 대시 도착점 = 보는 방향 수평 18 studs, 방향 없으면 제자리.
- [x] AC10: 밥알 끈끈이 2.5초 이동 속도 절반.
- [x] AC11: 초생강 입가심 게이지 -25(0 아래로 안 내려감).
- [x] AC12: 스킬 타격(`Burst`·`DashHit`·`SpinTick`)이 `FightLogic.hit`으로 판정된다.

### Studio 확인
- 없음 (순수 로직만).

## 공용 파일 변경
- 없음.

## 결정 기록
- 2026-11-11 · 스킬 공정성 · 스킬은 누구나 6종 공짜, 에픽·전설 스킨은 시그니처 연출만(사용자 답 "스킬은 공짜, 스킨은 연출") · 사용자
- 2026-11-11 · 대상 · 전설 + 에픽(사용자 답). Skins의 tier 기준이라 시즌(호박 초밥·산타 새우)·VIP(금박 계란초밥)·고등어 [신선]도 포함 · 사용자 + 메인 세션
- 2026-11-11 · 발동 입력 · 스킬 게이지가 차 있을 때 때리기 0.5초 누르기(버튼 4개 상한 유지) — 기본값, GDD Q3 · 메인 세션
- 2026-11-11 · 출시 형태 · 스시런과 같은 유니버스의 플레이스, DataStore 공유(GDD Q1) · 사용자

## 개발 메모
- 새 파일: `src/shared/fight/FightSkills.luau`, `tests/fight-skills.spec.luau`(12 케이스). 수정: `FightConfig`(Skills 표 + 기술 `Burst`·`DashHit`·`SpinTick`), `FightLogic.hit`(`input.guard` — 게이지·넉백·경직 배율).
- 문구(스킬 이름·설명)는 src에 넣지 않았다(현지화 규칙). 스킬 고르기 화면 스펙(F1-06)에서 `fight.skill.<id>.name|desc` 키로 CSV에 넣는다.
- 검증(2026-11-11, 클라우드): stylua 통과, 새 spec 12/12 + fight-logic 19/19, luau-lsp 끝 코드 0, rojo build·전체 lune은 커밋 전 다시 돌림(아래 인계 메모). selene 전체는 클라우드에서 불가.
