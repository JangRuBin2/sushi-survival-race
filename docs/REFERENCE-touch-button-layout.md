# REFERENCE — 모바일 터치 버튼 위치 편집 (m5-41)

- 작성: planner, **2026-10-14** (확인 날짜 전부 2026-10-14)
- 표기: **[원문]** WebFetch로 확인, **[검색]** 검색 요약만, **확인 못 함**.
- 결정은 [`docs/specs/m5-41-touch-button-layout.md`](specs/m5-41-touch-button-layout.md) "결정 기록".

## 1. 사례
| # | 대상 | 내용 | 근거 |
|---|---|---|---|
| A | Fortnite 모바일 "HUD 레이아웃 도구" | 설정 메뉴에서 버튼마다 **위치·크기**를 바꿈, 모드별(전투/건축) 레이아웃을 따로 저장 — 모바일 액션 게임의 표준 기능 | [검색] Sportskeeda 등 3자 가이드, Epic 크리에이터 문서는 창작자용(별개) |
| B | Game Accessibility 패턴 "Personal Interface" | 플레이어가 화면 요소의 위치·크기를 자기 손·기기에 맞추게 하는 접근성 패턴 | [검색] accessible.games |
| C | Roblox DevForum "Mobile Button Customizer" (커뮤니티 모듈) | 플레이어가 모바일 버튼(JumpButton 포함)을 끌어 옮기고 **서버 쪽에 저장**. 버튼은 ImageButton이어야 함 | [원문] devforum t/3886832 (저장 형식·스케일 방식은 원문에 없음) |
| D | Roblox 공식 문서 "Cross-platform design" | 맞춤 터치 버튼은 **기본 점프 버튼 위치를 기준으로** 놓으라고 권장, 경로 `PlayerGui.TouchGui.TouchControlFrame.JumpButton`. TouchGui는 터치가 켜졌을 때만 있음 | [검색] create.roblox.com/docs/ui/cross-platform-design |
| E | Roblox 기기 저장소 | 경험(게임)에서 **기기에 저장하는 클라이언트 API는 없다** — 설정은 서버 DataStore에 저장하고 클라이언트는 요청만 보내는 방식이 표준(커뮤니티 `LocalStoreService`도 실은 서버 저장 + 쿨다운). 샌드박스 파일 저장은 기능 요청 상태 | [검색] devforum t/1545741, t/3962445, t/164384 |
| F | 기본 점프 버튼 옮기기 | 기본 버튼의 Position을 LocalScript로 바꾸면 기본 컨트롤 스크립트(PlayerModule TouchJump)가 **다시 덮어쓸 수 있다**는 주의 — 확인은 기기·에뮬레이터 실측 필요 | [검색] devforum t/3915124 등 (확정 근거 **확인 못 함**) |

## 2. 읽은 것
1. 위치·크기 편집은 모바일 액션 게임에서 흔하고(A), 접근성 패턴(B)이기도 하다 → 넣을 가치가 있다. 로블록스 안에서도 개발자가 직접 만드는 기능(C).
2. **저장은 프로필(서버 DataStore)** 이 유일한 영구 저장(E). 대신 "기기마다 화면이 다르다"는 문제는 **화면 비율로 정규화한 좌표 + 기기 종류 묶음(휴대폰/태블릿)별 저장**으로 푼다.
3. 기본 점프 버튼은 옮길 수는 있지만 PlayerModule이 되돌릴 수 있다(F) → **속성이 바뀔 때마다 다시 적용**하는 방식을 먼저 쓰고, Studio 실측으로 안 되면 자체 점프 버튼으로 바꾼다(스펙 D3).
4. 왼쪽 아래는 Roblox 이동 조이스틱(DynamicThumbstick) 자리라 버튼을 둘 수 없다 — 썸스틱을 오른쪽으로 옮기려면 PlayerModule을 통째로 고쳐야 한다(우리 범위 밖) → "왼손잡이 좌우 반전"은 진짜 반전이 안 된다(스펙 D4).

## 3. 출처
- Mobile Button Customizer — https://devforum.roblox.com/t/mobile-button-customizer-let-players-move-their-controls/3886832 (원문)
- Figuring out where the jump button placement — https://devforum.roblox.com/t/figuring-out-where-the-jump-button-placement/3915124 (검색)
- Roblox Creator Docs, Cross-platform design — https://create.roblox.com/docs/ui/cross-platform-design (검색)
- LocalStoreService — https://devforum.roblox.com/t/localstoreservice/1545741 (검색), Client storage improvements — https://devforum.roblox.com/t/client-storage-improvements/164384 (검색), sandboxed FileSystem 요청 — https://devforum.roblox.com/t/add-very-basic-and-sandboxed-filesystem-support/3962445 (검색)
- Sportskeeda, How to change controls in Fortnite Mobile — https://www.sportskeeda.com/esports/how-change-controls-fortnite-mobile (검색)
- Game Accessibility, Personal Interface — https://accessible.games/accessible-player-experiences/access-patterns/personal-interface/ (검색)

### 확인 못 함
- 인기 로블록스 게임(Rivals·Arsenal·BedWars 등)의 플레이어용 버튼 편집기 유무 — 검색으로 못 찾음.
- PlayerModule TouchJump가 화면 크기 변경 때 JumpButton Position·Size를 다시 쓰는지 정확한 조건(코드 원문 미확인) → Studio AC.
- DynamicThumbstick 영역의 정확한 크기(추정: 화면 왼쪽 약 40%, 아래 약 2/3) → 스펙에서 넉넉한 금지 구역으로 잡음.
