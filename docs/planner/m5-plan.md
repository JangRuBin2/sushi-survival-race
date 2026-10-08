# M5 기획 작업 기록 (planner)

## 2026-10-08 — GDD v0.5 반영 (최신)

**브랜치**: `m5-01-qa-fixes` 작업 트리 (main f418857 기준, 커밋 안 함 — 메인 세션이 커밋 + push). docs-writer가 같은 때 CLAUDE.md·CHANGELOG·DEV-SETUP·README·USER-TODO를 고침 → planner는 GDD와 이 파일만.

### 끝난 것
- m5-01·m5-02 둘 다 qa-passed + 사용자 확정(위임 포함)을 받아 `docs/GDD.md`를 **v0.5**로 갱신:
  - §4 3번(결승은 시간 제한 대신 연장전), §5.1(연장전 한 줄), §5.2 Final 문단(연장전 일정 표 90/110/150초, 안전 상한 = 가장 높이 있는 1명, 결승에서만, 훅 없는 결승 맵은 시간 제한에 높이 순), ⑥(손 멈춤, 꼬치 190/150, 바깥 줄부터 약 2.7초 = 19/7초 간격 붕괴)
  - §10 HUD(연장전 표시, 관리자 "🛠" 패널 — 관리자에게만), §11.4(`overtime?` 훅·Final 필수·schedule/clockPhase), 새 §11.7 테스트 도구(관리자 판단, 비밀번호 방식을 안 쓰는 이유, 기록 안 함, MemoryStore 유지)
  - §12 M5 행(진행 중, 두 기능 개발 완료·사용자 확인 대기), §13 리스크 2줄, §14 다음 할 일, 변경 이력 v0.5
- 위 "사용자 결정" 1(150초 = 1안 높이 1명)·4(`LiveEnabled = true`)는 사용자 위임으로 확정. 3(목록 위치)은 서버 전용 `AdminConfig`로 GDD에 기록.

### 남은 것 / 다음에 할 첫 단계
- 메인 세션: GDD + 이 파일 커밋·push (docs-writer 파일과 함께).
- 두 스펙의 상태 `qa-passed` → `done`은 사용자 Studio 확인 뒤(WORKFLOW 규칙대로).
- 다음 M5 스펙 후보: 백로그(아래) 중 사용자가 고르는 것. 새 결승 맵은 `overtime` 훅 필수.

### 사용자 답을 기다리는 질문
- 연장전 수치(90/20/150초, 꼬치 190/150, 경고 1초) — 플레이테스트 뒤 조정.
- 공개 출시 때 관리자 기능 끌지(`LiveEnabled`).
- Survival 탈락 0명 허용(GDD 4.1 Q7) — 그대로.

### 막힌 점
- 없음.

### 커밋할 파일
- `docs/GDD.md`
- `docs/planner/m5-plan.md`

---

## 2026-10-08 — M5 첫 스펙 2개

**브랜치**: `main` (a96ea46 위, 커밋 안 함 — planner는 Bash가 없음. 메인 세션이 아래 "커밋할 파일"을 커밋 + push)

### 끝난 것
- 사용자 요청 2가지를 스펙으로. 둘 다 `status: ready`, 사용자 지시 "기본값으로 진행"대로 결정은 조사 근거로 기본값을 정하고 결정 기록에 "사용자 수정 가능".
- 조사: `docs/REFERENCE-final-overtime.md` — 결승·라스트맨스탠딩 시간 초과 처리 사례 12개(Fall Guys Hex-A-Gone·결승 전반·Jump Showdown·Royal Fumble·Thin Ice, Stumble Guys Laser Tracer Endless·Stumblewood, Super Bomberman, Roblox Circle Clash·MM2·NDS·Epic Minigames), 관리자 권한 관행(Roblox 커뮤니티 기준·Creator Docs·DevForum).
- GDD는 고치지 않음 (사용자 확정 전).

| 스펙 | 내용 | worktree / 포트 | 공용 파일 |
|---|---|---|---|
| m5-01 final-overtime | 결승 90초 → 연장전(꼬치 가속 + 접시가 바깥부터 20초 동안 무너짐) → 늦게 떨어진 사람 우승, 150초 안전 상한(높이 1명). RoundLogic.schedule/clockPhase, MapTypes `overtime` 훅(Final 맵 필수), HUD "⚡ 연장전", `Overtime` 효과음 | `m5-overtime` 34872 | Config, Types, MapTypes |
| m5-02 admin-skin-preview | Studio·UserId 허용 목록(11402290839)·게임 소유자만 스킨 무료 착용(미리보기, 저장 안 됨), 관리자에게만 "🛠" 패널, 서버 재검증, MemoryStore로 로비↔매치 유지 | `m5-admin` 34873 | Remotes, Attributes, init 2개 |

### 개발 순서
```
병렬:  m5-01 (m5-overtime)   ||   m5-02 (m5-admin)
       고치는 파일이 겹치지 않음 (m5-02의 ShopService 수정은 m5-01과 무관)
병합:  어느 쪽이 먼저여도 됨. 둘 다 qa-passed → main 병합
```

### 바뀔 GDD 절 (사용자 확정 뒤 v0.5로)
- §4 3번 "모든 라운드는 짧은 시간 제한" → "결승은 시간 제한 대신 연장전".
- §5.1 결승 설명 + §5.2 "Final 맵 — 최대 90초" 문단: 90초 연장전 → 20초 붕괴 → 늦게 떨어진 사람 우승, 150초 안전 상한(높이 1명). ⑥ 꼬치 쇼다운에 연장전(꼬치 190/150, 바깥 줄부터 2.5초마다).
- §10 HUD: 결승 연장전 표시("⚡ 연장전!", 빨간 "⚡ N초", "⚡ 버텨요!"), 관리자 "🛠" 패널.
- §11.4 맵 인터페이스: `overtime?(ctx, info)` (Final 필수).
- 새 §11.7 "테스트 도구": 관리자 판단(Studio·UserId 목록·개인 소유자), 미리보기 착용은 저장·결제와 분리, 서버 재검증, 비밀번호 방식 금지 이유.
- §13 리스크 표: "결승이 끝나지 않음(버티기)" → 연장전 붕괴 + 안전 상한. "관리자 기능 악용" → 서버 UserId 판단.
- §12 M5 행: 위 두 기능 추가.

### 사용자 결정·작업 (기본값으로 진행 중, 답이 오면 스펙·GDD 수정)
1. 150초 안전 상한 판정: **1안 높이 1명(기본값)** / 2안 공동 우승(Fall Guys식, 큰 변경) / 3안 무승부 — REFERENCE 3절.
2. 연장전 수치(90초 시작, 20초 붕괴, 꼬치 190/150) — 플레이테스트 뒤 조정.
3. 관리자 목록 위치: 서버 전용 `AdminConfig`(기본값, 클라이언트에 안 보임) / 메인 세션 원안 `Config.Admin`.
4. 실서버 관리자 기능 유지(`LiveEnabled = true`) — 공개 출시 때 끌지.
5. USER-TODO 추가 제안 (docs-writer 담당 파일):
   - A2 소리 고르기에 효과음 `Overtime`(연장전 경적) 추가.
   - "UserId 알려 주기" 항목은 **완료**로 기록 (2026-10-08, 11402290839).
   - B(Studio)에 m5-01 AC11~17, m5-02 AC6~11 확인, 디버그 `Config.DEBUG.overtimeAt`·`AdminConfig.StudioAllAdmins` 되돌리기 안내.

### M5 백로그 (이번에 스펙화하지 않음)
- 새 맵(GDD 5.3): 디저트 냉장고(Race), 튀김 기름 점프(Survival), 연어 왕관 쟁탈전(Final — 규칙 재검토, **m5-01 연장전 훅 필수**), 꼬치 다리 대탈출(Race 후보), 팀 라운드.
- 시즌 스킨(할로윈 호박·크리스마스 산타 새우 등, 에픽 가격대 제안), 용 롤 꼬리 애니메이션.
- 9.3 상품: 탈락·우승 연출 팩, VIP 패스, 스타터 번들(79) — 가격 재검토, 세트 할인, SNS 코드 보상, 지역 가격.
- 이벤트(기간 한정 맵·보상), 콘솔 UI, 3D 방 목록(접시).
- 관리자 명령 확장(강제 시작·맵 고르기·코인 지급 — 테스트 서버 전용), 그룹 랭크 권한.
- 남은 결정: Survival 탈락 0명 허용(GDD 4.1 Q7).

### 다음에 할 첫 단계
- 메인 세션: 아래 파일 커밋 + push → worktree 2개로 `developer` 에이전트에 m5-01, m5-02 병렬 구현.

### 막힌 점
- Fall Guys 위키(Fandom)·일부 기사(PC Gamer·GameSpot·Prima)는 403/402로 원문을 못 열어 검색 요약으로 남김(REFERENCE "확인 못 함"). 결정에 쓴 핵심(Hex-A-Gone 5분 공동 우승, Jump Showdown infinite hang 제거, Laser Tracer Endless, Bomberman Hurry Up·무승부)은 원문 확인.

### 커밋할 파일
- `docs/REFERENCE-final-overtime.md`
- `docs/specs/m5-01-final-overtime.md`
- `docs/specs/m5-02-admin-skin-preview.md`
- `docs/planner/m5-plan.md`
