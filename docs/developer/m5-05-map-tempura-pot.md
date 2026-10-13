# m5-05 map-tempura-pot — 개발 작업 기록

## 2026-10-13 — PHASE B(아트) 끝, in-qa (최신)
- **브랜치**: 로컬 `worktree-agent-ae5010b600402689b` → 원격 `m5-05-tempura`. origin/main(kit fix e07e08d·591d84e) 머지함.
- **끝난 것**: `TempuraPotArt.luau` 전면 작성("밤의 주방, 불 위의 무쇠 튀김 냄비"), `TempuraPot.luau` 아트 부착(기름 따라 올라가는 짙은 기름 층·주황 빛 3·김 2·거품 2, 벽 반사, 층별 튀김옷 밝기, `lighting = Art.LIGHTING`). 판정 파츠 크기·위치·CanCollide·수치는 그대로.
- **테스트**: `map-tempura-pot.spec` AC8·AC16(Extended 예산, 배경 바닥 깊이, 발판 장식이 윗면보다 낮음, IntroCamera가 판정 경계 + 40 안). `m5-23-qa.spec`의 "모든 맵 Standard 조명·파티클" 검사를 맵의 예산 단계 기준으로 바꿈(tempura-pot = Extended) — QA 확인 부탁. `m5-03-qa.spec`의 껍데기 build/start 검사에서 tempura-pot을 뺌(실제 맵이 됨).
- **검증**: rojo build OK, stylua OK, selene 0/0, lune 1592 passed / 0 failed, luau-lsp exit 0.
- **최종 렌더**: `docs/renders/tempura-pot/after-{overview,eye,intro-01,intro-02,intro-04,top,mobile}.png`, 통계 `after-stats.txt` — decor 1479/1500, lights 14/24 (shadowed 1/2), particles 6/16, anim 53/80, void 0% (모든 뷰). 전: `before-*.png`.
- **남은 것**: Studio AC10~AC15·AC17 (사용자/QA). 렌더러는 근사 — 특히 후드 SpotLight·기름 빛 세기와 밤 조명 밝기는 Studio에서 확인.
- **다음에 할 첫 단계**: QA 리포트 받기. 밝기 조정은 `Art.LIGHTING`(Brightness·ExposureCompensation·Ambient)과 `HoodLamp` brightness만.
- **막힌 점**: 없음. (참고) 처음엔 렌더러 `CFrame.lookAt`이 뒤집혀 있어 로컬에서 고쳐 확인했고, 머지 전에 내 tools/ 수정은 버리고 main의 수정(e07e08d)을 받음.

### 반복 1 (첫 키트 적용)
- 렌더: 주방·레인지·후드·창문·카운터 다 들어감, void 0%(intro-01 16% → 카메라 위치 문제), 장식 1612 > 1500(예산 초과).
- 체크리스트: 1 아니오(intro-01 16%) · 2 예 · 3 예 · 4 아니오(발판 윗면이 칙칙한 올리브, 금빛이 안 읽힘) · 5 예 · 6 **아니오**(발판 윗면이 어둡고 바구니가 파란 물처럼 보임) · 7 아니오(새우 꼬리 빨간 쐐기가 경고처럼 보임) · 8 예 · 9 예 · 10 예 · 11 예 · 12 예 · 13 예 · 14 아니오(렌더러 lookAt 버그로 intro가 엉뚱한 방향 — 렌더러 쪽 문제) · 15 아니오(6과 같음) · 16 예 · 17 **아니오**(1612) · 18 예.
- 가장 나쁜 뷰 eye: ① 발판 윗면이 빛을 못 받아 어두운 갈색 덩어리 ② 바구니가 청회색이라 기름/물 같음 ③ 튀김옷 돌기가 진한 주황 점이라 구멍처럼 보임.
- 고침: 창틀·문틀·매트를 roundedBox → bevelBox, 고리 분할 줄임(1612 → 1464), intro-01을 판정 경계 안으로.

### 반복 2 (조명)
- 체크리스트 아니오: 4·6(윗면 여전히 어두움), 10(앰비언트가 보라·청색이라 전체가 라벤더).
- 고침: 후드를 y 80으로 내리고 램프 3개(가운데 그림자 Spot 80°, 양옆 110°, 밝기 7/5), Brightness 1.6·Exposure 0.45, 바구니 놋쇠빛, 돌기 색을 반죽 크림 계열로, 새우 꼬리 작게·코랄색, 고구마 껍질 자주를 덜 빨갛게, 창 SurfaceLight range 16(키트 경고).

### 반복 3 (발판 가독성)
- 체크리스트 아니오: 6(아래층 발판이 위층보다 어두워 "밟는 곳"이 약함), 9(카운터 쪽 빛 원인 부족).
- 고침: 발판 색 기준 밝게(층별 1.015~1.225 배, 높을수록 밝음), 무쇠 벽 Reflectance 0.15, 카운터 위 펜던트 등 2(보이는 전구+갓+줄, Sway), Exposure 0.65.

### 반복 4 (온도·마무리, 최종)
- 고침: 바닥을 따뜻한 나무 마루 2 shade로, 앰비언트를 덜 파랗게, 후드 경사면·뒤판을 어둡게(화면 위쪽을 차지하던 밝은 라벤더 면 줄임), 펜던트 갓 색을 빨강 → 무쇠(위험 색 금지).
- 체크리스트 (최종): 1 예(void 전부 0%) · 2 예(냄비·레인지 불꽃·후드·젓가락·튀김 접시) · 3 예(큰 장식은 roundedBox/bevelBox/ring/림) · 4 예(금빛 기름·튀김이 냄비 안에, 강조색은 작게) · 5 예 · 6 예(발판 윗면이 가장 밝은 황금 갈색, 높을수록 밝음) · 7 예(위험 = 기름 경고 원 주황 Neon만, 장식에 빨강 Neon 없음 — 불꽃은 파랑) · 8 예(발판 장식은 전부 윗면보다 낮음, 테스트) · 9 예(조명 14개 전부 Neon 원인 파츠/기름 표면, 그림자 1) · 10 예(주황 기름·후드 램프·펜던트 vs 파란 창빛·가스 불꽃) · 11 예(냄비·레인지 주변에 몰림, 소품 무리) · 12 예(파티클 3종 6개, anim 53) · 13 예(eye에서 나선 발판이 위로 이어짐) · 14 예(intro 4개 주제 하나씩: 불꽃+냄비 / 발판 나선 / 꼭대기에서 내려다보기 / 바구니) · 15 예(mobile에서 발판 층·가장자리 보임; 경고 원은 게임 중 생겨 렌더에 없음 — Studio AC17) · 16 예(주방 바닥 −108, 레인지 상판 −26) · 17 예(1479/1500 등) · 18 예(냄비 지름 76 = 업소용, 레인지 높이 82, 카운터 깊이 70, 창·찬장 비율).
- 남은 아쉬움 (렌더러 기준): overview가 밤 장면이라 전체적으로 어둡고, 냄비 바깥면이 거의 검정 — Studio Future 조명에서 반사가 살아나는지 확인 필요.

## 2026-10-13 — PHASE A(게임플레이) 끝, PHASE B(아트) 대기 (최신)
- **브랜치**: 로컬 `worktree-agent-ae5010b600402689b` → 원격 `m5-05-tempura` (`git push -u origin HEAD:m5-05-tempura`). worktree `C:\Users\inter\sushi-survival-race\.claude\worktrees\agent-ae5010b600402689b`.
- **끝난 것**: 스펙의 규칙·순수 로직·서버 맵 모듈·테스트 전부(아트 제외). `inPool = false` 삭제(랜덤 풀 합류). 자세한 파일 목록·해석(D4·D5)은 스펙 "개발 메모"·"결정 기록".
- **검증**: rojo build OK, stylua --check OK, selene 0/0, lune 1255 passed / 0 failed, luau-lsp(LuauSolverV2) exit 0.
- **남은 것 (PHASE B)**: m5-23 새 비주얼 키트(올린 예산, 선언형 조명·파티클·애니메이션, 맵별 조명 프리셋)가 main에 들어오면 `TempuraPotArt.luau`를 채움 — 무쇠 냄비 테두리·손잡이(벽 32조각 위), 기름 표면 거품 파티클 2·김 2, 발판 튀김옷 돌기·새우 꼬리·고구마 껍질 테두리·깻잎 잎맥(충돌 없음), 거대한 긴 젓가락, 주방 배경. 판정 파츠 크기·위치·CanCollide는 그대로.
- **다음에 할 첫 단계**: `git fetch origin && git merge origin/main`(m5-23 받기) → m5-23 스펙·키트 API 읽기 → `TempuraPotArt` 확장, 예산 테스트 갱신.
- **막힌 점**: 없음. `shared/maps/init.luau` 주석의 "(inPool = false)"는 공용 파일이라 그대로 둠.
