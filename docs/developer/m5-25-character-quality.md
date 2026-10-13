# m5-25 캐릭터 퀄리티 — 2단계 개발 기록 (새 기준 몸·얼굴·31종·작은 움직임)

스펙: `docs/specs/m5-25-character-quality.md` · 1단계 진단: `docs/developer/m5-25-character-diagnosis.md`

## 인계 메모 (최신이 위)

### 2026-10-13 — 구현 끝, QA로
- 브랜치: `m5-25-character` (이 세션은 worktree `agent-adfe249991c8a0c8c`에서 `git push origin HEAD:m5-25-character` — 1단계 worktree가 같은 브랜치를 잡고 있어서)
- 끝난 것
  - `src/shared/SushiBody.luau` — 새 기준 몸(알약 밥 + 받침, 큰 파츠 눈 4겹, 웃는 입, 볼, 둥근 발), 가족 문법 도우미(`top`·`back`·`belt`·`strap`·`noriWall`·`pill`·`disc`·`triangle`·`onBack`), 31종 재배치, `BASE_NAMES`(22)·`PART_BUDGET`(40)·`NAME_TAG_HEIGHT`·`PART_JOINT_NAME`·`GLOW_RANGE/BRIGHTNESS`, `build`가 joint 파츠는 Motor6D·attach 파츠는 그 파츠에 용접, 얼굴 안쪽 파츠 그림자 끔.
  - `src/shared/CharacterAnimLogic.luau` (새, 순수) — 깜빡임·숨쉬기·늘어남·찌그러짐·걸음 자세 계산.
  - `src/client/fx/CharacterFxController.luau` — 위 로직으로 SushiJoint + 파츠 Motor6D Transform. 60 studs 밖·숨김은 기본 자세. 몸 통통 0.45 → 0.3, 누운 높이 1.4 → 1.8, 이름표 높이는 `SushiBody.NAME_TAG_HEIGHT`.
  - `tools/render/LayoutCheck.luau` — z-fighting 검사에 Cylinder 마개 포함, 색·재질·투명도가 같은 쌍은 제외(안 보임). `tools/render-character.luau` — 이름표 높이·얼굴 카메라 높이를 새 몸에 맞춤.
  - 테스트: `tests/m5-25-character-quality.spec.luau`(새 15개: AC1~AC7·AC9, 움직임 로직). 기준값 이동(사용자 확정 결정 1): `skins.spec`(기준 파츠 22개 비교, Wedge 이름), `sushi-body.spec`(높이 4.0~4.6·폭 3.6~4.0·폭/높이 ≥ 0.8, 시즌 스킨 파츠 이름), `m3-02-qa`(가짜 환경에 PartType·Angles, joint/attach 구조, 키 하한 4.0), `m5-21-qa`(GROUND_OFFSET 2.25), `m5-22-qa`(효과·Wedge 파츠 이름 표).
  - after 렌더 `docs/renders/characters/after-*.png` 8장 (아래 "렌더 비평" 마지막 회차).
- 검증 5단계: 아래 "검증" 줄.
- 남은 것: QA(`docs/qa/m5-25-character-quality.md`), Studio 확인(스펙 AC13~AC18), docs-writer(DEV-SETUP 2-2 after 그림·3-10 확인 목록, CHANGELOG, CLAUDE.md 캐릭터 문단), planner GDD v0.7.
- 다음 첫 단계: qa가 스펙 AC1~AC12 확인.
- 막힌 점: 없음. 렌더러가 Sparkles를 못 그려 반짝이 위치는 Studio 확인(AC17).

## 렌더 비평 (진단 체크리스트 기준, 게임 카메라 12.5 studs·휴대폰 480×270에서 읽히는지)
`lune run tools/render-character all --view all --light both --quality high` (약 4분). fast 품질로 중간 확인.

### 1회차 — 새 기준 몸 첫 모양 (tamago turntable)
- 얼굴(진단 2): 큰 4겹 눈·볼·웃는 입이 앞면 1/4 이상 — 크게 좋아짐. 하지만 옆에서 눈이 고글처럼 튀어나옴.
- 실루엣(진단 1·4): 위에서 보면 알약이라 3/4에서 둥근 음영이 생겼지만, 위·아래 모서리가 곧아서 "통조림 캔"으로 읽힘.
- 토핑과 등 자락이 같은 세로 벽 두 개라 옆에서 계단(진단 4 "책가방"과 비슷). 발은 밥 속에 묻혀 거의 안 보임(진단 6).
- 고침: 밥 높이 3.0 → 2.4 + 아래 좁은 받침, 발을 아래로 꺼냄, 자락을 기울여 두건처럼(→ 2회차에서 실패).

### 2회차 — 기울인 자락·둥근 등성이
- 기울인 자락의 앞쪽이 얼굴 옆을 뚫고 나와 눈 옆에 노란 톱니(렌더에서 바로 보임) + 뒤 아래에 홈. 등성이(한 단 좁은 알약)는 "2단 모자"로 읽힘.
- 고침: 기울기 없앰, 자락 뒷면을 토핑 뒷면에 맞춤(뒤로 0.2 밀린 알약), 등성이를 얇게.

### 3회차 — 깔끔한 두건 + 폭 넓힘
- 옆·뒤에서 자락이 머리카락/두건처럼 붙어 보임 — 진단 4 "판이 매달림" 해결. 발이 보임.
- 아직 조금 "키 큰 캔" → 밥 폭 3.4 → 3.6, 토핑 3.8 (폭/높이 0.88).

### 4회차 — 31종 전부 + 게임 거리 (lineup·gameplay·mobile)
- 휴대폰 앞 화면(480×270)에서 세 명의 눈·입이 다 보임 — 진단 2의 "입 1~2px, 눈 점 두 개"가 해결(눈 지름 약 15px).
- 문제: (a) 고양이·크라운 뒤 위에 토핑과 자락이 같은 평면에서 깜빡이는 홈(z-fighting, 색이 달라 보임), (b) 등성이는 여전히 층으로 읽히고 파츠만 3개 더, (c) 내 화면(뒤)의 계란초밥은 "노란 벽 + 검은 띠" — 진단 5 그대로, (d) 새우는 흰 토핑이라 앞에서 그냥 밥, 꼬리가 작음, (e) 고양이 꼬리는 막대기.
- 고침: 자락 뒷면 0.02 안쪽, 등성이 삭제(토핑 판을 0.9로 두껍게), 계란초밥에 **위·등을 세로로 감는 김 끈**(진짜 계란초밥 모양), 새우 연산호색 + 굵은 줄 + 큰 꼬리, 고양이 등 줄무늬 + 위로 휜 꼬리 + 공 끝. LayoutCheck가 원기둥 마개도 보게 고쳐 z-fighting 0·떠 있는 파츠 0 확인.
- 결과: 뒤 카메라에서 계란초밥이 한눈에 "김 끈 두른 계란초밥". 모바일 뒤 화면에서도 끈·띠가 보임.

### 5회차 — 테스트가 찾은 것 + 높이 상한
- 새 AC3 테스트가 슬라이더 버거의 등이 그냥 흰 밥인 걸 잡음 → 번 색 등 자락(아래 번)으로, 등성이 대신.
- 산타 새우 모자가 시즌 스킨 ±15% 상한(m5-07 AC6)을 넘음 → 모자를 낮게, 끝이 옆으로 접히고 방울이 달랑.

### 6회차 — 고품질·로비 조명·얼굴 가까이
- 로비 조명(따뜻한 베이지)에서도 흰 밥과 얼굴이 바닥과 섞이지 않고, 앞 3명 거리에서 표정이 읽힘.
- 얼굴 가까이: 입 덮개와 볼의 두께 모서리가 보이고, 하이라이트가 0.24 튀어나와 옆에서 고글처럼. → 흰자·눈동자·하이라이트를 테두리에 묻고(가장 앞 −1.40), 입 덮개 두께 0.04, 볼 0.04로. 다시 렌더해 입 덮개가 거의 안 보이고 옆 모습이 납작해진 것 확인.
- 남은 아쉬움(다음 단계 후보): 토핑 앞면이 곧은 띠라 살짝 "머리띠"처럼 보임(메시 단계에서 둥글게), 유니콘 뿔은 나선이 아니라 쌓은 원기둥, 렌더러 원기둥 면 분할이 보이지만 실제 Roblox 원기둥은 매끈함.

### 최종 그림 (커밋)
- `after-lineup.png`(studio) · `after-lineup-lobby.png` · `after-tamago-turntable.png` · `after-face.png` · `after-gameplay.png`(뒤 12.5 studs) · `after-gameplay-front-lobby.png` · `after-mobile-back.png` · `after-mobile-front.png`
- 비교: `before-lineup.png` ↔ `after-lineup.png`, `before-gameplay.png` ↔ `after-gameplay.png`.

## 수치 (stats.txt 요약)
- 계란초밥 외곽 3.80 × 4.32 × 2.97 (예전 2.8 × 4.7 × 2.25), 발바닥 −2.25.
- 파츠: 28(오이마키) ~ 40(유령·고양이), 평균 약 35. 기준 22개. z-fighting 0, 떠 있는 파츠 0 (31종).
