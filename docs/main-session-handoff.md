# 메인 세션 인계 메모

최신 내용을 맨 위에 둔다.

## 2026-10-13 밤 — m5-24·m5-28 QA 통과, main 병합

- `m5-24-merge`(4그룹 통합, QA 65a8fbc)와 `m5-28-concept-skins`(QA 12d293b)를 main에 병합. 병합 뒤 5단계: rojo OK · stylua OK · selene 0/0/0 · `lune run tests` **1842 passed, 0 failed** · luau-lsp 끝 코드 0. 두 스펙 `qa-passed`.
- QA 리포트: `docs/qa/m5-24-map-art-pass-v2.md`, `docs/qa/m5-28-concept-skins.md`.

### 특이사항 (남은 것)
- **P2 B1 giant-jenga 소개 카메라가 탑 앞줄 블록을 뚫음** (`GiantJengaArt.luau` 경유점 2→3). `tests/m5-24-qa.spec.luau`에 "알려진 버그"로 고정 — 고치면 그 항목 삭제. developer 몫.
- **P2 B2 claw-machine-prize 연장전 때 오락실 장식 554개가 상자와 같이 35° 기욺** (판정 영향 없음, 카펫이 낙하선 위로, 매 프레임 옮기는 파츠 ~900). 받아들일지 planner 결정.
- **planner Q1**: 예전 m5-20 안개 패널 처리 — soy·chef는 방 밖으로(D5), ramen은 국물 아래로 옮김(결정 기록 없음). 규칙("안개 패널 안 씀")과 맞는지 정하기.
- P3: 새우 꼬리 넘어질 때 묻힘 가능, 휴대폰 뒤 카메라에서 참치 결 안 보임(김 띠 없음으로만 연어와 구분), 연어알 Glass 재질 Future 조명 확인, 렌더러 "떠 있는 파츠" 검사가 외곽 상자 기준(회전 파츠 늘면 보강), bouncy 플레이어 시점 렌더 불가, hot-plate 플레이어 시점 왼쪽 큰 어두운 판(예전부터).
- 예산 빠듯: lantern-bridge 조명 23/24·움직임 73/80, bouncy-castle-maze 장식 1468/1500.
- 그룹 B·C·D 병합 커밋 일부에 Co-Authored-By 줄 빠짐(이미 push, 히스토리 안 고침).
- docs-writer 할 일: CLAUDE.md 현재 상태(m5-24 done, m5-28 콘셉트 스킨 4종·스킨 36종, 테스트 수), CHANGELOG. 앞 절의 m5-26 관련 문서 수정과 함께.
- **사용자 차례**: Studio 확인 — 맵은 QA 리포트 체크리스트(`forceMapPlans` 5판, 결승 `overtimeAt = 5`, 끝나면 nil), 스킨은 m5-28 QA 리포트 7개. 결정: 콘셉트 스킨 가격·등급·이름, 다음 묶음.

## 2026-10-13 저녁 (클라우드 세션 — m5-24 4그룹 + m5-28 콘셉트 스킨)

모두 각 브랜치에 push, **main에는 아직 병합 안 함**(QA 전). 클라우드 검증 5단계는 전부 통과.

| 작업 | 브랜치 · 커밋 | 테스트 | 다음 첫 단계 |
|---|---|---|---|
| m5-24 그룹 A (rotating-belt·hot-plate·skewer-showdown) | `m5-24-art-a` d5d2781 | 1795/0 | QA → main 병합 |
| m5-24 그룹 B (soy-swamp·chef-board·tug-of-war-platform) | `m5-24-art-b` 81f7bf3 | 1794/0 | QA → 병합 |
| m5-24 그룹 C (ramen-rapids·giant-jenga·claw-machine-prize) | `m5-24-art-c` 79a7807 | 1793/0 | QA → 병합 |
| m5-24 그룹 D (bouncy-castle-maze·lantern-bridge·cat-cafe-shelves) | `m5-24-art-d` 33b749f | 1794/0 | QA → 병합 |
| m5-28 콘셉트 스킨 4종(참치·새우·계란·연어알 군함, 무료 실험 스킨) | `m5-28-concept-skins` 68283e1 | 1800/0 | 스펙 `in-qa` → QA → 병합 |

### 특이사항
- **병합 충돌 예상: `tests/m5-23-qa.spec.luau`.** A·B·C가 같은 단언("기존 6개는 프리셋을 씀"·조명/파티클 고정 수)을 각자 다르게 고침. **A의 `artModule(id)` 방식(Art 모듈을 직접 읽음)을 기준으로** 합치고 B의 soy-swamp 수치 줄만 확인. 4그룹 다 병합한 뒤 검증 5단계 다시.
- 스펙 `m5-24-map-art-pass-v2.md` `status:` 줄은 그룹마다 ready/in-dev로 제각각 — 병합 담당이 한 번에 정리. 개발 메모 그룹 B·C·D 절은 스펙에 추가됨, A는 `docs/developer/m5-24-group-a.md`가 원본.
- **planner 확인 필요 (B, D5 제안)**: m5-20 안개 패널을 지우지 않고 방 벽 밖으로 옮김(soy ±680, chef ±312). 새 맵 규칙("안개 패널 안 씀")과 맞는지 결정.
- B: `TugOfWarPlatform.luau` 아트 부착부의 `p.CastShadow = false` 한 줄 삭제(장식 그림자 기본 규칙 적용). chef-board 방 반경 300으로 키움.
- C: claw-machine-prize는 연장전에 상자가 기울어 Spin/Sway 장식이 어긋나서 **Pulse만** 씀 → 스펙의 "미러볼 회전" 빠짐. 젠가 블록 모서리 장식은 판정 코드라 안 함, 망치 흔들림 → 앞치마 흔들림.
- D: lantern-bridge 입구 도리이 기둥이 m5-15부터 원기둥 축이 뒤집혀 원판이었음 → 고침(장식만). lantern 조명 23/24로 여유 1. 소개 카메라 점 좌표 변경(lantern ③, cat ②·③).
- A: hot-plate 후드 램프 PointLight 2 → SpotLight 2(왼쪽만 그림자). skewer 셰프를 화로 뒤(+Z 72)로, 장식이 반경 640까지 퍼짐(아레나 간격 2000 안). 렌더러 Neon 번짐이 Studio보다 셀 수 있음 — skewer 거리 창 밝기 Studio 확인.
- 렌더러 한계: bouncy 플레이어 시점은 렌더러 카메라가 출발 벽 뒤라 벽만 보임, cat-cafe overview는 천장이 없어 하늘이 보임(게임 카메라는 방 안).
- m5-28: concept-salmon은 리팩터 전후 레이아웃·렌더가 바이트 단위로 같음. m5-27 테스트 기대값 "실험 스킨 1종" → "정확히 5종", 카탈로그 32 → 36. 렌더 도구에 `--sample concept-<name>` 추가. Studio에서 연어알 Glass 재질(Future 조명)·새우 꼬리(꼭대기 2.69)가 넘어질 때 묻히는지 볼 것.
- **사용자 결정 대기 (m5-28)**: 콘셉트 스킨 5종 가격·등급(무료 테스트 유지 vs 판매 — 판매면 콘셉트 몸 검사 규칙 스펙 필요), "(테스트)" 이름 정리·기존 같은 초밥 스킨과 이름 구분, 다음 묶음(장어·성게·문어 등).
- **m5-26 현지화 병합 시**: 콘셉트 스킨 5종 이름·대사 CSV 키 추가 필요(새 4종은 이름 4 + 대사 8줄).
- **클라우드 환경 메모**: rokit 설치 스크립트가 403이라 5개 도구를 GitHub 릴리스 zip으로 직접 받아 `/root/.local/bin`에 둠. selene은 프록시 인증서 때문에 Roblox 표준 라이브러리를 못 받아 curl로 받은 `~/.cache/selene/roblox.yml` 캐시로 돌림(0.32.0 그대로). Windows 로컬은 해당 없음.
- Studio 확인(각 맵 AC12~15, 스킨 확인 순서)은 전부 아직 — 순서는 각 브랜치 `docs/developer/m5-24-group-<a~d>.md`, `docs/developer/m5-28-concept-skins.md`. `forceMapPlan(s)`는 확인 뒤 nil로.

## 2026-10-13 (사용량 한도로 중단)

main은 깨끗하고 push돼 있다(3ed86cb). 진행 중이던 일은 각자 브랜치에 wip로 push했다.

| 작업 | 브랜치 | 상태 | 다음 첫 단계 |
|---|---|---|---|
| m5-26 다국어 1·2단계 + 1단계 QA 수정 | `m5-26-i18n-p2` | 재QA 대부분 끝(e415e99): P0/P1 없음(잠정), 새 P3 B6. 회귀 테스트 추가만 남음 | QA 리포트 "재QA" 인계대로 `tests/m5-26-reqa.spec.luau` 추가 → 5단계 → `qa-passed` → main 머지(사용자 지시: QA 통과 시 머지) |
| m5-27 콘셉트 시트 캐릭터 샘플 (연어초밥 1개, 게임 코드는 안 바꿈) | `m5-27-character-concept` | 견본 완료(255abcb, aa09924), 사용자 검토 대기 | 사용자가 방향을 정하면 planner가 다음 스펙(기준 몸 교체, 31종, 표정 시스템, 팔). 이미지는 원할 때만 보여 줌 |
| m5-24 기존 맵 12개 아트 v2 | `m5-24-art-a`~`d` | 보류(사용자 지시: 맵 보류) | 각 브랜치 `docs/developer/m5-24-group-<a~d>.md` |
| m5-12 콘솔 UI | — | 시작 전 | 스펙 `ready` |

알아 둘 것:
- 사용자 콘셉트 이미지가 `docs/`에 추적 안 되는 파일로 있다. **커밋하지 말 것**(사용자가 작업 뒤 지움).
- 사용자 선호: 결과 페이지(아티팩트)는 사용자가 보고 싶다고 할 때만 띄운다. 맵 세부 판단은 메인 세션이 정하고 결정 기록에 남긴다.
- 출시 계획: 먼저 16세 이상 공개(비용 없음), 모든 연령은 나중(`docs/USER-TODO.md` 답변 기록).
- `tests/init.luau`는 실패가 있으면 끝 코드 1을 낸다. 일부 문서에 "실패가 있어도 0"이라고 적힌 곳은 틀린 설명이라 고쳐야 한다(CLAUDE.md 검증 절, DEV-SETUP 2절, README).
- m5-26 머지 뒤 docs-writer 할 일: CLAUDE.md 다국어 규칙(숫자 + 단위는 키 하나, 월드 글씨는 `WorldText.mark`, `Attributes.Title`은 숫자), DEV-SETUP(Player Emulator 언어), USER-TODO(번역 CSV 업로드, 자동 수집·자동 번역 켜기).
