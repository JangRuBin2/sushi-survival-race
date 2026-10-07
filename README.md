# 🍣 Sushi Survival Race

먹히기 전에 탈출하라! 회전초밥집의 초밥이 되어 손님 젓가락을 피해 달리는 로블록스 라운드제 서바이벌 레이스.

- 방장이 인원(4~24명)을 정해서 방을 만들고, 3~4라운드 만에 단 1개의 초밥만 바다로 탈출
- 라운드마다 맵이 바뀌고, 맵마다 규칙이 달라요
- 기본 스킨은 계란초밥! 로벅스로 다른 초밥 스킨을 살 수 있어요 (출시 준비 단계에서 추가 예정)
- 탈락하면? 젓가락에 집혀 냠!

## 지금 상태
M1 완료 — 방 만들기·참가, 3~4라운드 매치 흐름, 회전 벨트 Race 맵(회색 박스), 매치 HUD까지 돌아가요.
다음은 M2(Survival·Final 맵, 관전·우승 처리). 자세한 건 [변경 기록](docs/CHANGELOG.md).

## 문서
- [게임 기획서 (GDD)](docs/GDD.md)
- [개발 환경 세팅과 테스트 방법](docs/DEV-SETUP.md)
- [협업 워크플로 (기획·개발·QA·문서화 에이전트)](docs/WORKFLOW.md)
- [변경 기록](docs/CHANGELOG.md)

## 개발 환경
- Roblox Studio + [Rojo](https://rojo.space/), 도구 버전은 [Rokit](https://github.com/rojo-rbx/rokit)으로 고정 (`rokit.toml`)
- Luau, 순수 로직 테스트는 [Lune](https://lune-org.github.io/docs)
