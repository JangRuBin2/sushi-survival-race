# m5-31 우승자 뽑기 티켓 — 기획 작업 기록

## 2026-10-14 (2차) — 등급별 확률·샘플 화면으로 스펙 개정
- 브랜치: main 체크아웃(문서만). developer는 다른 worktree(`m5-31-winner-ticket-draw`)에서 구현 중 — 같은 내용을 메인 세션이 먼저 전달함, 스펙을 그에 맞춤.
- 끝난 것
  - 사용자 샘플 `docs/귀여운 초밥 스킨 뽑기 UI.png` 직접 확인.
  - 스펙 개정: 꽝 없는 등급별(1/5/15/30/49), `drawGrade` 표, 중복 코인 20/40/80/150/300, 빈 등급 비율 나누기(m5-31 실제 5.05/15.15/30.30/49.49, 표시 5.0/15.2/30.3/49.5 최대 나머지), `DrawLogic` API(grades·roll·displayPercents·perSkinPercent·featured), `Types.DrawResult` kind Skin|Duplicate, validate "drawGrade + robux" 허용, UI 절(샘플 11항목), AC1~AC16 lune / AC17~AC24 Studio. 1차 결정은 취소선으로 남김.
  - REFERENCE §4(정책 재확인 [원문]: 퍼센트·합 100%·반올림 안내·"각 X%" 허용, 판매+랜덤 같이 있는 경우 문서 언급 없음), GDD 변경 이력·9.1·9.2·9.4·9.6·10, USER-TODO 열린 질문·C3·C4·답변 기록.
- 남은 것: developer 구현 → QA. 개발 메모에 실제 필드 이름(`drawGrade`, `isDrawOnly` 등)이 스펙과 다르면 결정 기록에 남기게.
- 다음 첫 단계: developer 브랜치의 구현이 스펙 AC4~AC6 숫자(5/99 등, 경계 0.0505/0.0506…)와 맞는지 QA가 확인.
- 막힌 점: 없음.
- 사용자 답을 기다리는 질문: 천장(영웅·전설 보장), 적은 인원 방 파밍, 성숙도 설문 답 확인.

## 2026-10-14 — 스펙 작성, `ready`, GDD v0.7
- 브랜치: main 체크아웃 (문서만, 커밋은 메인 세션이 — planner에는 Bash 없음)
- 끝난 것
  - `docs/specs/m5-31-winner-ticket-draw.md` (status ready): 사용자 결정 4건(티켓·10%/90%+20, 풀 = 콘셉트 9종 뽑기 전용, 이름 "○○ (특)", Studio 전부 입기) 결정 기록에 그대로. 기본값 `Config.Draw`(상한 99, 대체 +100, 간격 1초), 구조(`DrawLogic` 순수, `ShopService`에 `DrawTicket`, `RewardService` Won 지급, 프로필 v3), AC1~AC14 lune / AC15~AC20 Studio, 공용 파일(Config·Remotes·Types) 담당 = 이 스펙 developer, docs-writer 반영 목록(CLAUDE.md 규칙 문구 포함).
  - `docs/REFERENCE-winner-ticket-draw.md` 새로: Roblox 유료 랜덤·성숙도 문서 [원문] 확인(무료 행동 보상은 유료 랜덤 아님, 도박 정의), 비교 게임 MM2·TDS·Rivals·Blade Ball, 수치 추정.
  - `docs/REFERENCE-roblox-monetization.md` §5에 한 줄.
  - `docs/GDD.md` v0.7: 변경 이력, 9.1 무료 뽑기 규칙, 9.2 특 9종 줄, 9.4, 9.5, 새 9.6, 10, 11.5 v3, 11.7 `tickets`·Studio 전부 입기, 12, 13 리스크.
  - `docs/USER-TODO.md`: A1 열린 결정 2개 + 기본값, C4 성숙도 설문 "유료 랜덤 아이템" 답, 답변 기록 2026-10-14에 사용자 결정.
- 남은 것: m5-29 QA·병합, m5-30 병합 → developer가 그 main에서 `m5-31-winner-ticket-draw` 시작 → QA → docs-writer(CLAUDE.md·DEV-SETUP·CHANGELOG).
- 다음 첫 단계: developer가 스펙 "구조"대로 `Skins` 이름·`draw`·`isFree` 변경 + `DrawLogic`부터.
- 막힌 점: 없음. 주의 — m5-30이 `tests/m5-27~29-*.spec.luau`를 고치는 중이라 m5-31은 병합 뒤에 시작해야 함.
- 사용자 답을 기다리는 질문: 천장 여부, 적은 인원 방 티켓 파밍(둘 다 급하지 않음, 추천 = 일단 없음), 성숙도 설문 답 확인(퍼블리시 때).
