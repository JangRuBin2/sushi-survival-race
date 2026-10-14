# Sushi Survival Race

로블록스용 라운드제 레이스 게임. 플레이어는 회전초밥집의 초밥이 되어 손님 젓가락을 피해 달린다. 4~24명이 한 방에서 3~4라운드를 돌고, 결승에서 마지막까지 남은 한 명이 우승한다. 한 판은 4~5분.

아직 공개 전이다. 게임 코드는 출시할 수 있는 상태이고, Studio 확인·퍼블리시·비공개 테스트가 남았다. 남은 일은 [docs/USER-TODO.md](docs/USER-TODO.md)에 있다.

## 게임 규칙

라운드마다 맵이 바뀌고, 정해진 인원만 다음 라운드로 간다. 첫 라운드는 항상 Race, 마지막은 항상 Final이다.

| 시작 인원 | 라운드 수 | 남는 인원 예시 |
|---|---|---|
| 4~8명 | 3 | 8 → 5 → 3 → 1 |
| 9~24명 | 4 | 24 → 16 → 9 → 5 → 1 |

- Race: 결승선에 목표 인원이 들어오면 끝 (최대 90초)
- Survival: 목표 인원만 남거나 60초가 지나면 끝. 시간이 끝나면 버틴 사람은 모두 통과
- Final: 한 명이 남으면 우승. 90초가 지나면 연장전으로 20초 안에 발판이 모두 무너지고, 가장 늦게 떨어진 사람이 우승

떨어지면 젓가락에 집혀 먹히는 연출이 나오고, 이후 남은 사람을 관전한다.

### 맵 (15개)

| 종류 | 맵 |
|---|---|
| Race | 회전 벨트, 간장 늪 & 와사비 산, 라멘 국물 급류, 디저트 냉장고, 방방 미로, 등불 다리 |
| Survival | 뜨거운 철판, 셰프의 도마, 튀김 냄비 탈출, 와르르 나무 블록, 고양이 카페 캣타워 |
| Final | 회전 꼬치 쇼다운, 연어알 폭탄 접시, 줄다리기 발판, 인형뽑기 기계 속 |

맵별 규칙과 수치는 [GDD](docs/GDD.md) 5절과 `docs/specs/`의 맵 스펙에 있다.

### 조작

| 동작 | PC | 게임패드 | 모바일 |
|---|---|---|---|
| 이동 | WASD | 왼쪽 스틱 | 조이스틱 |
| 점프 | Space | A | 점프 버튼 |
| 다이브 | Shift 또는 E | X | 다이브 버튼 |
| 잡기 (누르고 있기) | 마우스 왼쪽 | R2 | 잡기 버튼 |
| 관전 대상 바꾸기 | Q / E | | 화면 좌우 버튼 |

모바일은 위쪽 바의 ⚙ → "버튼 위치 편집"으로 점프·다이브·잡기 버튼을 옮기고 크기를 바꿀 수 있다(프로필에 저장).

### 진행·상점

- 라운드 통과, 결승 진출, 우승, 하루 첫 판에 밥알 코인을 준다. 승수에 따라 칭호가 붙는다.
- 스킨 41종. 스킨은 겉모습만 바꾸고 크기·판정·속도는 같다. 일반·레어 스킨은 코인으로도 열 수 있고, 나머지는 로벅스(29~199)로 산다. 능력치 판매는 없다.
- 우승하면 🎫 뽑기권 1장을 받아 무료로 뽑는다. 꽝은 없고 등급 확률(전설 1% ~ 일반 49%)은 뽑기 화면에 공개한다. 뽑기권은 우승으로만 얻고 로벅스나 재화로 팔지 않는다(유료 뽑기 없음). 특 스킨 9종은 뽑기로만 나오고, 전설 고등어 초밥 [신선]은 뽑기와 판매 둘 다 된다.
- 그 밖에 시즌 이벤트(이벤트 재화로 한정 스킨 교환), 스킨 묶음과 탈락·우승 연출 팩, VIP 패스(겉모습 혜택만), 보상 코드가 있다.

## 개발

Roblox Studio + [Rojo](https://rojo.space/), 언어는 Luau(`--!strict`). 도구 버전은 `rokit.toml`에 고정돼 있다(Rojo, StyLua, Selene, Lune, luau-lsp).

```bash
rokit install      # 처음 한 번. Windows는 ~/.rokit/bin을 PATH에 추가
rojo serve         # Studio의 Rojo 플러그인에서 Connect 후 Play
```

판정(결승선, 탈락, 순위, 코인, 구매, 이동 감시)은 모두 서버에서 한다. 맵은 판정 지오메트리와 장식을 모두 코드로 만들기 때문에 Studio 에셋 없이 테스트할 수 있다. Studio에서 만든 장식은 `assets/map-art/<맵 id>.rbxm`에 넣으면 붙는다.

### 검증

커밋 전에 다섯 단계를 모두 통과해야 한다.

```bash
rojo build -o build.rbxl
stylua --check src tests tools
selene src
lune run tests     # 1992개(134개 파일, 2026-10-14). 실패가 있으면 종료 코드 1. 마지막 줄 "0 failed"도 확인할 것
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --platform roblox --sourcemap sourcemap.json --definitions "@roblox=types/globalTypes.None.d.luau" --flag:LuauSolverV2=true src
```

Studio 없이 맵을 PNG로 확인하려면 `lune run tools/render-map <맵 id>`, 캐릭터·스킨은 `lune run tools/render-character <스킨 id>`를 쓴다. 혼자 테스트하는 법, 디버그 설정, Studio 확인 목록은 [docs/DEV-SETUP.md](docs/DEV-SETUP.md)에 있다.

보상 코드 목록은 저장소가 공개라서 커밋하지 않는다. `src/server/CodeList.example.luau`를 `CodeList.luau`로 복사해 쓰면 된다(`.gitignore`에 있음).

### 폴더

```
src/server/   서버 서비스: 방, 매치, 라운드, 판정, 저장, 보상, 상점, 이동 감시
src/client/   UI, 카메라, 효과음, 연출, 입력
src/shared/   설정, 리모트, Roblox API를 쓰지 않는 순수 로직
  maps/       맵 모듈 15개와 장식 키트
tests/        Lune 테스트
tools/        맵·캐릭터 미리보기 렌더러
docs/         기획서, 스펙, QA 리포트, 변경 기록
```

### 문서

- [GDD](docs/GDD.md): 기획 기준
- [DEV-SETUP](docs/DEV-SETUP.md): 개발 환경과 Studio 확인 방법
- [WORKFLOW](docs/WORKFLOW.md): 기획 → 개발 → QA → 문서 작업 흐름
- [CHANGELOG](docs/CHANGELOG.md): 마일스톤별 변경 내역
- [USER-TODO](docs/USER-TODO.md): 퍼블리시, 상품 등록, 테스트 등 직접 할 일
