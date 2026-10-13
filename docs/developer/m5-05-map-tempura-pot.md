# m5-05 map-tempura-pot — 개발 작업 기록

## 2026-10-13 — PHASE A(게임플레이) 끝, PHASE B(아트) 대기 (최신)
- **브랜치**: 로컬 `worktree-agent-ae5010b600402689b` → 원격 `m5-05-tempura` (`git push -u origin HEAD:m5-05-tempura`). worktree `C:\Users\inter\sushi-survival-race\.claude\worktrees\agent-ae5010b600402689b`.
- **끝난 것**: 스펙의 규칙·순수 로직·서버 맵 모듈·테스트 전부(아트 제외). `inPool = false` 삭제(랜덤 풀 합류). 자세한 파일 목록·해석(D4·D5)은 스펙 "개발 메모"·"결정 기록".
- **검증**: rojo build OK, stylua --check OK, selene 0/0, lune 1255 passed / 0 failed, luau-lsp(LuauSolverV2) exit 0.
- **남은 것 (PHASE B)**: m5-23 새 비주얼 키트(올린 예산, 선언형 조명·파티클·애니메이션, 맵별 조명 프리셋)가 main에 들어오면 `TempuraPotArt.luau`를 채움 — 무쇠 냄비 테두리·손잡이(벽 32조각 위), 기름 표면 거품 파티클 2·김 2, 발판 튀김옷 돌기·새우 꼬리·고구마 껍질 테두리·깻잎 잎맥(충돌 없음), 거대한 긴 젓가락, 주방 배경. 판정 파츠 크기·위치·CanCollide는 그대로.
- **다음에 할 첫 단계**: `git fetch origin && git merge origin/main`(m5-23 받기) → m5-23 스펙·키트 API 읽기 → `TempuraPotArt` 확장, 예산 테스트 갱신.
- **막힌 점**: 없음. `shared/maps/init.luau` 주석의 "(inPool = false)"는 공용 파일이라 그대로 둠.
