# 🍣 Sushi Survival Race

먹히기 전에 탈출하라! 회전초밥집의 초밥이 되어 손님 젓가락을 피해 달리는 로블록스 라운드제 서바이벌 레이스.

- 방장이 인원(4~24명)을 정해서 방을 만들고, 3~4라운드 만에 단 1개의 초밥만 바다로 탈출
- 라운드마다 맵이 바뀌고, 맵마다 규칙이 달라요
- 기본 스킨은 계란초밥! 로벅스로 다른 초밥 스킨을 살 수 있어요 (출시 준비 단계에서 추가 예정)
- 탈락하면? 젓가락에 집혀 냠!

## 지금 상태
M2(한 판 MVP) 개발·QA 완료, Studio 확인 대기 — 방을 만들어 시작하면 3~4라운드 한 판이 우승까지 끝까지 돌아요.
맵 4개(Race "회전 벨트"·"간장 늪 & 와사비 산", Survival "뜨거운 철판", 생존형 결승 "회전 꼬치 쇼다운")가 회색 박스로 들어가 있고, 매 판 랜덤으로 구성돼요. 탈락하면 관전하고, 우승하면 순위표가 떠요.
다음은 M3(계란초밥 캐릭터, 탈락·우승 연출, 다이브/잡기, 사운드). 자세한 건 [변경 기록](docs/CHANGELOG.md).

## 문서
- [게임 기획서 (GDD)](docs/GDD.md)
- [개발 환경 세팅과 테스트 방법](docs/DEV-SETUP.md)
- [협업 워크플로 (기획·개발·QA·문서화 에이전트)](docs/WORKFLOW.md)
- [변경 기록](docs/CHANGELOG.md)

## 개발 환경
- Roblox Studio + [Rojo](https://rojo.space/), 도구 버전은 [Rokit](https://github.com/rojo-rbx/rokit)으로 고정 (`rokit.toml`)
- Luau, 순수 로직 테스트는 [Lune](https://lune-org.github.io/docs)
