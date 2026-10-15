status: done
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-28 — 콘셉트 몸 스킨 4종 추가 (참치·새우·계란·연어알 군함, 무료 테스트)

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §9.1 (겉모습만, Pay-to-Win 금지), §9.2 (스킨 목록) · 바탕: m5-27 콘셉트 견본·실험 스킨 `concept-salmon` (`docs/developer/m5-27-character-concept.md`)
- 담당 개발 worktree: 브랜치 `m5-28-concept-skins` (`origin/main`에서)
- 공용 파일 수정 담당: 없음 (Config·Remotes·Types·Attributes·maps·default.project.json·init 스크립트·rokit.toml 안 건드림)

## 목표
사용자 콘셉트 시트 스타일(넓은 밥 + 도톰한 토핑 + 작은 눈·팔·다리)의 스킨을 연어 1종에서 5종으로 늘려, 플레이어가 탈의실에서 바로 입어 보고 "새 스타일로 여러 초밥"이 어떤지 판단할 수 있게 한다. 기존 31종 모양은 그대로 둔다.

## 범위
- 포함
  - 새 실험 스킨 4종 (모두 무료, `Skins.EXPERIMENTAL_IDS`에 추가, concept-salmon과 같은 방식):
    | id | 이름 | 토핑 |
    |---|---|---|
    | `concept-tuna` | 콘셉트 참치초밥 (테스트) | 진한 빨강 돔 + 가늘고 간격이 고르지 않은 밝은 결 4줄 (김 띠 없음) |
    | `concept-shrimp` | 콘셉트 새우초밥 (테스트) | 흰 돔 + 굵은 주황 줄 4개 + 주황빛 가장자리 + 등 뒤로 솟은 빨간 꼬리 부채 3장 |
    | `concept-tamago` | 콘셉트 계란초밥 (테스트) | 모서리 둥근 두툼한 노란 계란말이 + 앞·뒤 갈색 겹 줄 + 가운데 김 띠 (위→앞, 위→등 아래) |
    | `concept-ikura` | 콘셉트 연어알 군함 (테스트) | 김 벽(등·옆, 앞은 밥 속)이 밥 위로 솟은 그릇 + 주황 바닥 + 큰 연어알 11알(2층) + 오이 조각 |
  - `SushiConceptSample` 정리: 밥·받침·얼굴(표정 4종)·팔·다리·깜빡임 관절은 공유, 토핑만 스킨별 (`SKIN_IDS`, `layout/gameLayout/build`에 `skinId?`). concept-salmon은 파츠 하나하나 그대로.
  - `SushiBody`: 콘셉트 id 목록을 `SushiConceptSample.SKIN_IDS`에서 받아 `LAYOUTS`·`EXPERIMENTAL`(상한 47)·표정 경로를 모두 같은 방식으로.
  - 렌더 도구 `--sample <콘셉트 스킨 id>`, 렌더 비평 3회 이상, PNG 커밋.
  - 새 테스트 `tests/m5-28-concept-skins.spec.luau`, 카탈로그 개수(32 → 36, 기본 등급 2 → 6) 기존 테스트 갱신.
- 제외
  - 가격·등급·판매 (나중에 사용자 결정 — 아래 질문)
  - 기존 31종 모양 변경, 기준 몸 교체
  - m5-26 현지화 CSV 키 (main에 아직 없음 — 병합 뒤 추가)
  - 게임 중 내 캐릭터 표정 바꾸기 (m5-27과 같음, 인형만)

## 수용 기준
### 순수 로직 (lune 테스트로 확인)
- [x] AC1: 카탈로그 36종, 새 4종은 Basic·`experimental = true`·가격/얻는 길 없음, 이름에 "(테스트)", order 33~36(탈의실 "전체" 맨 끝), 대사 2줄. `Skins.validate` 통과.
- [x] AC2: `Skins.EXPERIMENTAL_IDS` = `SushiBody.EXPERIMENTAL` = `SushiConceptSample.SKIN_IDS` (5종). 목록 밖 id에 `experimental`을 달거나, 새 스킨에 가격·다른 등급을 붙이면 validate가 잡는다.
- [x] AC3: 새 프로필에서도 4종 모두 장착 가능·카드 "입기", 코인·로벅스는 `AlreadyOwned`, 저장 `ownedSkins`에는 안 들어가고 장착값은 `migrate` 뒤에도 유지.
- [x] AC4: 5종 × 표정 4종 모두 파츠 ≤ 47, 발바닥 = `GROUND_OFFSET`(2.25), 꼭대기 ≤ 이름표 − 0.4, 효과 0, z-fighting 0, 떠 있는 파츠 0, 이름 중복 0.
- [x] AC5: 새 4종의 밥·받침·팔·다리·얼굴(표정별) 파츠가 concept-salmon과 크기·위치·색·재질·관절까지 같다. 토핑은 얼굴 높이에서 밥 앞면보다 앞으로 안 나온다.
- [x] AC6: 관절 8개(눈·감은 눈·발·팔), 깜빡이면 눈이 밥 속·감은 눈이 앞, 발 위끝은 걸음 때도 받침 위. 진짜 Instance build: Body만 고정, `PartJoint` Motor6D(기본·당황 8, 신남·아픔 4), 충돌·쿼리·터치 없음, Massless.
- [x] AC7: concept-salmon 레이아웃(게임 4표정·견본 8조합)과 다른 31종 레이아웃이 리팩터 전과 바이트 단위로 같다 (개발 중 JSON 스냅숏 비교, 기존 m5-27 테스트는 약화 없이 통과).
- [x] AC8: `SushiBody`의 require는 `SushiConceptSample` 하나, 견본 모듈은 아무것도 require하지 않는다. 클라이언트·서버 코드에 콘셉트 id 분기 없음(이름·관절로 동작).

### Studio 확인
- [ ] AC9: 탈의실 "전체" 탭 맨 끝에 새 4종 카드가 처음부터 "입기", 미리보기·내 캐릭터가 바뀐다.
- [ ] AC10: 달리기·숨쉬기·깜빡임·팔 흔들기·착지 찌그러짐이 concept-salmon과 같다. 발이 땅에 닿는다.
- [ ] AC11: 탈락 인형(아픔 x x + 반창고), 우승·단상 인형(신남 ^ ^)이 새 4종에서도 나온다.
- [ ] AC12: 휴대폰 뒤 카메라에서 4종이 서로·연어와 구분된다 (참치 = 빨강, 새우 = 흰+주황 줄+꼬리, 계란 = 노랑+김 띠, 연어알 = 검은 그릇+주황 알).

## 공용 파일 변경
- 없음.

## 결정 기록
<!-- 날짜 · 질문 · 결정 · 누가 -->
- 2026-10-13 · 기존 31종을 콘셉트 스타일로 바꿀지 · **그대로 두고 콘셉트 스타일 새 스킨을 추가** · 사용자
- 2026-10-13 · 첫 배치 범위 · 참치·새우·계란·연어알 군함 4종, 모두 무료 실험 스킨(concept-salmon과 같은 방식) · 메인 세션
- 2026-10-13 · 연어알 파츠 상한 · 알을 크게(지름 0.68) 11알만 — 게임 레이아웃 기본 44, 당황 46 (상한 47) · developer
- 2026-10-13 · 참치에 김 띠 · **없음** — 연어(김 띠)와 뒤 카메라에서 바로 구분되게. 대신 결 4줄을 연어 지방 줄보다 굵기·간격을 불규칙하게 · developer
- 2026-10-14 · 열린 질문 1 (가격·등급) · **무료 테스트 그대로 유지** (가격·등급·판매 없음) · 사용자
- 2026-10-14 · 열린 질문 3 (다음 배치) · **더 만든다** — 장어·성게 군함·문어·유부 → `docs/specs/m5-29-concept-skins-2.md` · 사용자(종류는 메인 세션)
- **열린 질문 (사용자, 급하지 않음)**
  2. 이름 "(테스트)"를 정식 출시 때 뺄지, 기존 같은 음식 스킨(참치·새우·계란초밥·연어알 군함)과 이름을 어떻게 나눌지 (예: "말랑 참치"). 판매를 정할 때까지 미룸.

## 개발 메모
- 바뀐 파일: `src/shared/SushiConceptSample.luau`(공유 몸 + 스킨별 토핑, `SKIN_IDS`), `src/shared/SushiBody.luau`(콘셉트 id 목록 연결), `src/shared/Skins.luau`(4종·EXPERIMENTAL_IDS), `tools/render-character.luau`(`--sample <콘셉트 스킨 id>`), 테스트 `tests/m5-28-concept-skins.spec.luau`(새), `tests/skins.spec.luau`·`tests/m5-03-foundation.spec.luau`·`tests/m5-22-qa.spec.luau`(개수), `tests/m5-27-concept-skin.spec.luau`(예외 목록 1 → 5종, 정확한 목록 비교는 그대로).
- 파츠 수 (기본 / 신남 / 당황 / 아픔): 연어 44/40/46/40 · 참치 41/37/43/37 · 새우 44/40/46/40 · 계란 40/36/42/36 · 연어알 44/40/46/40.
- Studio 확인 방법·렌더 비평·특이사항: `docs/developer/m5-28-concept-skins.md`.
- m5-26 현지화가 main에 들어오면 새 4종 이름·대사(각 2줄) CSV 키를 추가해야 해요 (concept-salmon과 같이).
