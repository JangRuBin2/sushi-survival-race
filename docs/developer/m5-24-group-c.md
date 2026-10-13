# m5-24 그룹 C 작업 기록 (ramen-rapids · giant-jenga · claw-machine-prize)

## 2026-10-13 인계 (사용자 요청으로 중간 정리)
- 브랜치: `m5-24-art-c` (worktree `agent-a69742ebe88c113b3`), `origin/main` 591d84e까지 병합됨. Rojo 포트 34884.
- 스펙 상태: `ready` 그대로 (in-dev로 안 바꿈). **검증 미완료 — in-qa로 넘기지 말 것.**

### 끝난 것
- 세 맵 BEFORE 렌더 저장: `docs/renders/<mapId>/before-*.png` + `before-stats.txt` (렌더러 lookAt 버그 수정 전 렌더라 before-intro-* 는 방향이 틀림 — 다시 찍으려면 `git show` 이전 커밋의 Art로 재렌더).
- **ramen-rapids 반복 2회 진행** (`src/shared/maps/RamenRapidsArt.luau`, `RamenRapids.luau`의 `lighting = Art.LIGHTING` 한 줄):
  - 라멘집 환경: 카운터 상판(y -90, 판 8장), 가게 바닥(y -290), 벽 4면(흙벽+기둥+보), 뒤 벽 주방 창구(따뜻한 빛, 육수 냄비·국자·김), 노렌 5장(가운데 흰 원 표식, Sway), 메뉴 패 10개, 붉은 등롱 3개(Point, Sway), 오른쪽 격자창 3개(차가운 Surface 빛 range 16), 왼쪽 그릇 선반, 앞 벽 미닫이 문.
  - 그릇 스케일 소품: 찻잔(김), 양념 쟁반(오른쪽), 교자 접시, 젓가락 통, 옆 손님 그릇(김), 물수건·메뉴 세움판.
  - 히어로: 라이몬 띠(BowlPattern/BowlPatternKey), 그릇 아래 깎임·굽, 나루토 소용돌이 섬(소용돌이 22조각 + Spin 막대), 반숙 계란 반쪽 2개, 젓가락이 든 면 커튼(14가닥 Sway) + 그림자 스폿 등 1개, 테두리 김 판, 렌게.
  - 국물: BrothDepth(불투명), 기름 띠, Sparkle·Bubbles·SteamThick 앵커.
  - **m5-20 QA B2·B5 해결**: FogPanel 3장을 국물 수면 아래(그릇 안, 길이 230/200)로 내림 — 그릇 밖으로 안 나가고, 위에서 볼 때 항상 국물 뒤라 가릴 투명 물체가 없음. 이름·개수·재질·투명도는 m5-20 테스트대로 유지(D3).
  - Art.LIGHTING: 프리셋 복사 후 Density 0.2, Haze 1, Contrast 0.08, Saturation 0.08, SpecularScale 0.8.
  - IntroCamera 4점: ① (56,50,38)→그릇 전체+주방 벽 ② 차슈 클로즈업 ③ 결승 쪽 반전 ④ 출발 뒤 (0,12,14). 모두 판정 경계+40 안.
  - 마지막 렌더 stats: decor 966/1500, lights 7/24 (shadowed 1/2), particles 13/16 (+코드 Steam 3 포함 여부 확인 필요), anim 29/80, tris 43744, void 전 뷰 0%.
- 바꾼 테스트 단언 (D2):
  - `tests/map-ramen-rapids.spec.luau` 318·371줄: `count <= DECOR_PART_BUDGET` → `checkBudget(decor, "Extended") == nil`
  - `tests/m5-20-qa.spec.luau` 177줄: 같은 변경 (ramen budget)
  - `tests/m5-23-visual-kit.spec.luau` AC7: `lighting == preset` → `preset 또는 validate 통과한 자기 Art.LIGHTING` (D4 때문에 필요, 다른 그룹도 같은 줄을 고칠 것 — 병합 충돌 주의)

### 남은 것
- **검증 실패 2건 (main 병합 후 새로 생긴 m5-23-qa 테스트)**: `m5-23-qa.spec.luau` "QA lighting: … 기존 6개는 프리셋을 씀"(ramen이 Art.LIGHTING을 써서) · "QA budget: 렌더러 통계 = 기존 맵 lune 카운트". 둘 다 m5-24 D4/Extended와 충돌 — 그 단언을 AC7과 같은 방식으로 고치거나 m5-23 담당과 맞춰야 함. 나머지 1567 통과, stylua 통과. selene·rojo build·타입 검사는 이번 상태로 **안 돌림**.
- ramen-rapids: 반복 3 이상 + 체크리스트 18개 글 비평 기록, 계란 노른자 모양 확인(마지막 렌더 아직 안 봄), 오버뷰 안개 정도 확인, 양념 쟁반 이동 후 구도 확인, after PNG 저장, 휴대폰 성능 메모, `tests/m5-24-c.spec.luau`(Extended 예산·anim 금지 목록·소개 경로 충돌·FogPanel 그릇 안) 작성.
- giant-jenga: 손 안 댐 (BEFORE만). 블록 스택은 m5-maps-fix-a가 판정 수정 중 — **아트 코드만, 블록 만드는 부분은 같은 hunk 건드리지 말 것**. 소개 점 01(y=355)이 아레나 경계 밖.
- claw-machine-prize: 손 안 댐 (BEFORE만). m5-maps-fix-b가 판정 수정 중 — 칸·집게 스타일 hunk 금지, 칸·인형·집게에 anim 금지.
- 스펙 개발 메모(그룹 C 절) 미작성.

### 다음에 할 첫 단계
1. `git fetch origin && git merge origin/main` → `lune run tools/render-map ramen-rapids --view all` → `build/renders/ramen-rapids/*.png` 전부 보고 반복 3 비평을 이 파일에 적기.
2. m5-23-qa 실패 2건 처리 방법 결정(단언 수정은 D2 범위인지 메인 세션에 확인).

### 막힌 점 / 참고
- Lune `CFrame.lookAt` 버그로 렌더러 intro 뷰가 반대로 찍히던 문제 → main e07e08d에서 고쳐짐 (BEFORE intro 렌더는 그 전 것).
- SurfaceLight range ≤ 16 (kit가 거부함). Spin anim은 amount 0.
- 여러 파츠로 된 장식에 anim을 달면 파츠마다 위상이 달라(phaseOf 위치 기반) 따로 움직임 — 단일 파츠에만 anim.
