# m5-32 고등어 초밥 [신선] — 기획 작업 기록

## 2026-10-14 — 스펙 작성, `ready`
- 브랜치: main 체크아웃 (문서만, 커밋은 메인 세션)
- 끝난 것
  - 사용자 시트 `docs/고등어 초밥 캐릭터 시트.png` 직접 확인(정면 머리 = 보는 사람 왼쪽, 김 띠 뒤쪽 1/3 비스듬히, 물방울, 표정 5종).
  - `docs/specs/m5-32-fresh-mackerel.md` (ready): 카탈로그(Legendary 199, order 41), 콘셉트 몸 예외 이름 바꾸기(`experimental` → `conceptBody`/`CONCEPT_BODY`, 고등어만 전설 ±25% 외곽 검사), 관절 사슬(`joint` + `attach` → Part0), 관절 이름 계약(FishRoot·FishMid·FishTail·FishFin*·Splash*), 팔딱 움직임 상태표·한도(7 Hz, 40°, 0.45)·성능(관절 17 이하, 60 studs 밖 정지), `DollAnimator`, AC1~AC10 lune / AC11~AC13 렌더 / AC14~AC19 Studio.
  - `docs/REFERENCE-fresh-mackerel.md` 새로(가격은 A안 확정값, 움직임 Hz 근거 [검색], 신선함 요소).
  - GDD 변경 이력·9.2 전설 줄·12, USER-TODO(열린 결정, C3 상품 1개, 답변 기록).
- 남은 것: m5-30·m5-31 병합 → developer `m5-32-fresh-mackerel` → QA.
- 다음 첫 단계: developer가 시트를 보고 예외 이름 바꾸기 + 관절 사슬부터, 그다음 고등어 토핑 첫 렌더.
- 막힌 점: 없음. 순서 주의 — m5-31과 같은 파일(Skins.validate, SushiBody 예외 표, m5-27~29 테스트).
- 사용자 답을 기다리는 질문: 파츠 상한 80 허용 여부(필요해질 때), 화남·슬픔 표정, 효과음.
