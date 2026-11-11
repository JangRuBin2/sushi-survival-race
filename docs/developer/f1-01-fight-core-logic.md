# f1-01 스시 파이트 핵심 로직 — 개발 작업 기록

## 2026-11-11 (클라우드 세션)
- **지금 브랜치**: `sushi-fight` (스시런 `main` @ `a85fd669`에서 갈라짐)
- **끝난 것**
  - 기획서 `docs/fight/GDD.md` v0.1(draft), 재활용 표 `docs/fight/REUSE.md`
  - 레퍼런스 13개 + 콘셉트 이미지 5장을 `docs/fight/references/`로 복사(원본은 그대로), 인덱스 `references/README.md`
  - 순수 로직 `src/shared/fight/FightConfig.luau`·`FightLogic.luau` + `tests/fight-logic.spec.luau` 19개 → 스펙 `in-qa`
- **남은 것**
  - qa 에이전트로 f1-01 검증
  - 사용자 결정 `docs/fight/GDD.md` 11절 Q1(같은 유니버스 플레이스 vs 별도 게임)·Q2(순서)·Q3(4번째 버튼)
  - F1-03 기반 스펙(planner): `Fight` 플레이스 역할, `Config.Fight`, 리모트, `FightService`
- **다음에 할 첫 단계**: (2026-11-11 갱신) Q1 확정, 특수 스킬이 F1-02가 됨 → `docs/developer/f1-02-fight-skills-logic.md` 참고
- **막힌 점**: 클라우드에서 selene 전체 린트 불가(Roblox API 덤프 TLS 실패). 도구는 GitHub 릴리스 zip을 직접 받아 씀(rokit install은 API 오류).
