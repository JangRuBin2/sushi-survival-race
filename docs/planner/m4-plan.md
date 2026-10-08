# M4 기획 작업 기록 (planner)

## 2026-10-08 — M4 스펙 14개 작성 완료 (최신)

**브랜치**: `main` (커밋 0944110 위, 커밋 안 함 — planner는 Bash가 없음. 메인 세션이 아래 "커밋할 파일"을 커밋 + push)

### 끝난 것
- 읽은 것: CLAUDE.md, WORKFLOW, GDD v0.3 §12·§13, CHANGELOG M3(남은 P3·M4로 미룬 것), REFERENCE-map-production, REFERENCE-party-royale, proposals/robux-gameplay(참고만, 결정에 안 씀), m2-01·m3-01·m3-02 스펙 형식, 현재 `src/` 구조(Config·Remotes·Types·MatchService·AppearanceService·SushiBody·RoomService·init).
- M4 스펙 14개 작성, 모두 `status: ready`. 결정이 필요한 항목은 사용자 지시("일단 개발하고 나중에 수정")대로 **기본값으로 정하고** 각 스펙 결정 기록에 "기본값으로 진행, 사용자 수정 가능"으로 남김.
- **GDD는 고치지 않았다** — 기본값이 사용자 확정 전이라. 확정되면 v0.4로 반영(아래 "남은 것").

| 스펙 | 내용 | worktree / 포트 |
|---|---|---|
| m4-01 foundation | 공용 파일, MatchEvents 훅, DataService 메모리판, ProfileSchema/ProfileStore, PlaceRole, MapKit, 새 맵 stub 2개, 껍데기, P3(I1·m3-03 B2) | main |
| m4-02 art-race-maps | 회전 벨트·간장 늪 아트 + 벨트 태그 전환(M1 B10) | m4-art-race 34872 |
| m4-03 art-survival-final-maps | 철판·꼬치 쇼다운 아트 (+ m3-04 B2 끝점) | m4-art-arena 34873 |
| m4-04 map-ramen-rapids | 새 Race ③ 라멘 국물 급류 | m4-ramen 34874 |
| m4-05 map-chef-board | 새 Survival ④ 셰프의 도마 | m4-chef-board 34875 |
| m4-06 lobby-art-podium | 로비 건물·조명·우승자 단상 | m4-lobby 34876 |
| m4-07 data-persistence | DataStore 저장·세션 잠금·음소거 저장 | m4-data 34877 |
| m4-08 rewards-titles | 밥알 코인·승수·칭호·코인 UI | m4-rewards 34878 |
| m4-09 mobile-ui | 화면 배율·안전 영역·터치 버튼·관전 ←/→ 제거 | m4-mobile 34879 |
| m4-10 movement-guard | 서버 순간이동·속도 감시 (M1 B11) | m4-guard 34880 |
| m4-11 place-split | 로비/매치 플레이스, 텔레포트, 같은 방 복귀, 서버 간 방 목록 | main |
| m4-12 release-hardening | 타입 검사(I2), 남은 P3, 연속 매치 안정성, 출시 체크리스트 | main |
| m4-13 skins-closet | 스킨 16종·탈의실·코인 해금 (스킨은 마지막) | main |
| m4-14 robux-shop | 개발자 상품·ProcessReceipt·구매 기록 (맨 마지막) | main |

### 개발 순서와 병렬 묶음
```
단계 0 (순차, main)      m4-01 foundation  ← 공용 파일·init·훅·껍데기 전부
                               │ main 병합 + push 후 worktree 생성
단계 1 (병렬, worktree)  물결 A: m4-07 data · m4-08 rewards · m4-09 mobile · m4-04 ramen · m4-05 chef-board
                         물결 B: m4-02 art-race · m4-03 art-arena · m4-06 lobby · m4-10 guard
                               │ 전부 qa-passed → main 병합 (m4-10은 맵 스펙 m4-02~05 뒤에 병합)
단계 2 (순차, main)      m4-11 place-split → m4-12 release-hardening   → 사용자 비공개 테스트
단계 3 (순차, main, 마지막) m4-13 skins-closet → m4-14 robux-shop       → 공개 전환
```
- 단계 1의 9개는 **고치는 파일이 서로 겹치지 않는다** (각 스펙 머리의 "이 스펙이 고치는 파일"). 눈여겨볼 나눔: `CharacterFxController`(이름표 칭호) = m4-08만, `Sfx.luau`(음소거 저장) = m4-07만, 기존 UI 화면 파일 = m4-09만, 새 화면(코인 배지)은 m4-08의 자기 ScreenGui + `UiScaleController.attach`.
- 동시에 9개를 못 돌리면 물결 A(저장·보상·모바일 = 출시 필수, 새 맵 2개 = 맵 6개 채우기) → 물결 B(아트 패스·로비·감시).
- 병합 순서 권장: m4-07 → m4-08 → m4-09 → 맵(m4-04·05·02·03) → m4-06 → **m4-10 마지막**(맵이 `MoveExempt.mark`를 넣은 뒤라야 오탐이 없음).
- 공용 파일 담당: 단계 0 = m4-01, 단계 1 = 없음(고칠 일이 생기면 사용자에게 알림), 단계 2·3 = 그 순서의 스펙.

### 기본값으로 정한 주요 결정 (사용자 수정 가능)
- 맵 아트: 판정 지오메트리는 코드 그대로, 색·재질·코드 장식(`MapKit`, 충돌 없음)·IntroCamera는 에이전트가. 더 정교한 아트는 사용자가 Studio에서 만들어 `assets/map-art/<id>.rbxm` → `ServerStorage.MapArt`(장식 전용). Blender·메시는 사용자 선택. 장식 예산 맵당 파츠 600·파티클 8·조명 12.
- 새 맵: ③ 라멘 국물 급류(급류 밀기·가라앉는 차슈·회전 젓가락 막대, 약 300 studs), ④ 셰프의 도마(격자 61칸, 칼 줄 경고 → 넉백, 양 끝 칸 잘림, 가운데 3×3 보호, 10초마다 8도 기울기).
- 결승 같은 묶음 낙하 + 리셋(m2-07 I1): 리셋·퇴장이 더 나쁜 등수.
- 저장: 직접 구현한 세션 잠금(UpdateAsync + JobId, 30분 만료), 로드 실패 시 저장 안 하는 임시 프로필, Studio 기본 메모리(`persistDataInStudio = false`).
- 코인: 그때그때 지급, Victory 순위표 때 합계 표시, 하루 = UTC, 결승 진출 = 결승 출발 레이서 전원.
- 단상: 이 서버의 가장 최근 우승자 1명. 방 목록 3D 접시 UI는 M5.
- 모바일: 가로 고정, 짧은 변 720px 기준 UIScale 0.6~1.25, 관전 ←/→ 제거(Q/E만). 콘솔 UI는 M5.
- 이동 감시: 되돌리기 + 위반 2초 동안 통과 무시 + 로그, 킥 없음.
- 플레이스 분리: 신뢰 정보는 MemoryStore 매니페스트(키 PrivateServerId), 매치 서버는 도착하면 바로 시작(최대 20초, 2명 미만 취소), 끝나면 같이 로비로 → 같은 방 복원. 서버 간 방 목록 포함. Studio·id 없음 = 한 플레이스 모드.
- 출시 점검: luau-lsp 타입 검사 도입, m3-09 B3·m3-07 G1·G4 고침, B4 둠, 다이브 지름길 확인만. 비공개 테스트는 스킨 전에.
- 스킨: 시즌 제외 16종(GDD 9.2 가격 그대로) 코드 레이아웃, 코인 해금은 일반만, 라운드 중 장착 변경 금지. 로벅스: 스킨 개발자 상품 15개, VIP·연출 팩·번들은 M5.

### 포함하지 않은 M3 P3 / 보류
- m3-09 B4(결승 소개 중 리셋 연출 잘림) — 둠.
- m3-06 B2·B3(다이브 지름길) — m4-12에서 확인만.
- 잡기 감속 무시·noclip 감지 — M5 이후 필요하면(m4-10 제외 항목).
- 로블록스판 "Bro Falls"·랜덤 맵 변형·세그먼트 조합 — M5 후보(GDD 범위 밖).

### 남은 것
- 개발: m4-01부터 (developer, main).
- 사용자 작업 (스펙을 막지 않음, 코드는 없이도 Studio에서 돎):
  1. 게임 퍼블리시 + Studio API 접근 허용 (m4-07 저장 확인)
  2. Match 플레이스 생성·같은 빌드 퍼블리시·PlaceId 2개 알려 주기 (m4-11)
  3. (선택) 맵·로비 Studio 장식 `.rbxm`, 컨셉 이미지
  4. 실제 휴대폰 테스트 (m4-09 AC9)
  5. 출시 체크리스트: 이름·설명·아이콘·썸네일·경험 설문·기기·서버 인원·비공개 테스트 (m4-12 표)
  6. 개발자 상품 15개 생성·id 알려 주기 (m4-14)
  7. M3 이월: 배경음 4곡·효과음 8개 id 고르기, 친구 테스트
- 기획: 사용자가 기본값을 확인·수정하면 GDD v0.4에 반영 — §5.2 ③④ 세부 규칙, §8 단상 방식, §9.4 지급 시점·UTC, §9.3 M4 판매 범위(스킨만), §11.2 매니페스트 방식, §12 M4 세부, M3 기본값(우승 10초 등)도 함께.

### 다음에 할 첫 단계
- 메인 세션: 아래 파일 커밋 + push → `developer` 에이전트로 `docs/specs/m4-01-foundation.md` 구현 (main, 순차).

### 막힌 점
- 없음. 사용자 작업(퍼블리시·PlaceId·상품 id)이 없어도 모든 스펙이 Studio·lune에서 개발·확인되게 설계했다(메모리 저장, 한 플레이스 모드, `simulateMatchServer`, `fakeRobuxInStudio`). 실제 서버 확인 항목(m4-07 AC10, m4-11 AC9~13, m4-14 AC7)만 사용자 작업 뒤에 할 수 있다.

### 사용자 답을 기다리는 질문 (기본값으로 이미 진행 중, 답이 오면 스펙·GDD 수정)
- 새 맵 2개 규칙·수치가 괜찮은지 (특히 도마 "가운데 3×3 보호" — Survival이 끝까지 0명이 안 되게).
- 하루 첫 판 보너스 기준을 UTC(한국 오전 9시)로 해도 되는지.
- 이동 감시를 "킥 없음"으로 둘지.
- 매치 서버를 "도착하면 바로 시작, 2명 미만이면 취소"로 할지.
- M4 판매 범위를 스킨만(VIP·연출 팩·번들은 M5)으로 할지.

### 커밋할 파일
- `docs/specs/m4-01-foundation.md`, `m4-02-art-race-maps.md`, `m4-03-art-survival-final-maps.md`, `m4-04-map-ramen-rapids.md`, `m4-05-map-chef-board.md`
- `docs/specs/m4-06-lobby-art-podium.md`, `m4-07-data-persistence.md`, `m4-08-rewards-titles.md`, `m4-09-mobile-ui.md`, `m4-10-movement-guard.md`
- `docs/specs/m4-11-place-split.md`, `m4-12-release-hardening.md`, `m4-13-skins-closet.md`, `m4-14-robux-shop.md`
- `docs/planner/m4-plan.md`
