# m5-23 / m5-24 맵 비주얼 기획 작업 기록 (planner)

## 2026-10-13 — 비주얼 키트 스펙 + 아트 가이드 + 새 맵 3개 아트 절 + 기존 맵 12개 아트 패스 스펙 (최신)

**브랜치**: `main` (f88e327 위, 커밋 안 함 — planner는 Bash가 없음. 메인 세션이 아래 파일을 커밋 + push)

### 끝난 것
- 사용자 요청(2026-10-13): "맵 퀄리티가 다른 로블록스 맵들에 비해 많이 떨어진다 — 시각적으로 괜찮게 만드는 게 매우 중요", 이어서 "기존 맵에도 같은 방식으로 아트 작업 해줘".
- `docs/specs/m5-23-map-visual-kit.md` (`in-dev`, main, 공용 파일 담당) — Lune 렌더러(`tools/render-map`, void% 통계), DecorSpec 확장(CornerWedge·reflectance·castShadow·light·particle·anim), Extended 예산(1500/16/24, 그림자 2, 움직임 80 — 기존 상수 600/8/12는 그대로), 팔레트·shade·모양 헬퍼, 맵별 클라이언트 조명(`MapLighting`·`MapLightingController`, 카메라가 있는 아레나 기준), `Technology = Future`, 원래 6개 맵 조명 초안.
- `docs/REFERENCE-map-art-direction.md` — 필수 아트 가이드(1 stud ≈ 1 cm 주방 스케일, FG/MG/BG + 배경 바닥은 낙하선 10 아래, 맨 상자 금지, 히어로 색 60-30-10, 가독성 위계, 재질표, 보이는 광원·그림자 조명 ≤ 2, 파티클·로컬 움직임, 밀도, 체크리스트 18개, 렌더→비평→고침 3회 루프, 전/후 PNG는 `docs/renders/<mapId>/`). 조사 출처(Roblox 공식 Lighting·Atmosphere·조명 튜토리얼·성능 문서, Future is Bright 공지, Fall Guys 기사) + "확인 못 함" 표시.
- m5-04·05·06: "### 아트" 절만 교체(가이드·m5-23·Extended 예산·맵별 디렉션) + 수용 기준 끝에 "아트 품질" AC 2개 추가. 다른 절·개발 메모는 안 건드림.
- `docs/specs/m5-24-map-art-pass-v2.md` (`ready`, m5-23 머지 후) — 기존 맵 12개, worktree 4그룹(34882~34885), 판정 불변 규칙, 맵별 디렉션, 전/후 렌더·3회 반복·휴대폰 메모 AC.

### 남은 것 / 다음 첫 단계
- m5-23 개발 중 기획 질문이 오면 결정 기록에 답한다.
- m5-23 머지 뒤 m5-04~06 아트 패스, 이어서 m5-24 그룹 A~D worktree 생성(A·B·C는 m5-20 머지 후).
- GDD 반영(§11.4 예산 단계·`lighting` 필드, §5.3 아트 기준)은 m5-23 qa-passed 뒤.

### 사용자 답을 기다리는 질문
1. **m5-24 D2**: 기존 테스트가 "장식 600 이하"를 고정 — Extended(1500)로 올리려면 그 예산 단언(아트 수량만)을 바꿔야 함. 기본값은 "아트 수량 단언만 바꾸기 허용, 판정 테스트는 그대로". 600 유지를 원하면 알려 주기.
2. Future 조명 휴대폰 성능(m5-23 AC18) — 비공개 테스트 때 실제 휴대폰 확인.
3. (선택) 맵별 스카이박스 이미지 에셋.

### 막힌 점
- 인기 로블록스 게임(DOORS·Pet Sim 99·Tower of Hell)의 실제 아트·조명 설정 1차 자료는 못 찾음 — 가이드에 "확인 못 함"으로 표시, 수치는 Roblox 공식 문서 예제만 근거로 씀.
- `Lighting.Technology`는 스크립트로 못 바꿈(Studio 전용) — 프로젝트 파일로 넣고, Rojo live sync가 못 바꾸면 사용자가 Studio에서 한 번 설정.
