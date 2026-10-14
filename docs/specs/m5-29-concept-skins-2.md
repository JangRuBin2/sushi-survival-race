status: qa-passed
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m5-29 — 콘셉트 몸 스킨 2차 4종 (장어·성게 군함·문어·유부, 무료 테스트)

- 마일스톤: M5
- GDD 근거: `docs/GDD.md` §9.1 (겉모습만, Pay-to-Win 금지), §9.2 (스킨 목록 — 실험 스킨은 판매 목록이 아니라 표에 넣지 않음) · 바탕: m5-27 `concept-salmon`, m5-28 `docs/specs/m5-28-concept-skins.md`·`docs/developer/m5-28-concept-skins.md`
- 담당 개발 worktree: 브랜치 `m5-29-concept-skins-2` (`origin/main`에서)
- 공용 파일 수정 담당: 없음 (Config·Remotes·Types·Attributes·maps·default.project.json·init 스크립트·rokit.toml 안 건드림)

## 목표
m5-28과 같은 콘셉트 스타일(넓은 밥 + 도톰한 토핑 + 작은 눈·팔·다리)로 장어·성게 군함·문어·유부 4종을 더 만들어, 탈의실에서 콘셉트 스킨 9종을 바로 입어 보고 비교할 수 있게 한다. 콘셉트 5종과 기존 31종의 모양은 그대로 둔다. 모두 무료 테스트(가격·등급·판매 없음)다.

## 범위
- 포함
  - 새 실험 스킨 4종 (모두 무료, `Skins.EXPERIMENTAL_IDS`에 추가, m5-28과 같은 방식):
    | id | 이름 | order | 생김새 | 같은 음식 기존 스킨(비교 그림용) |
    |---|---|---|---|---|
    | `concept-unagi` | 콘셉트 장어초밥 (테스트) | 37 | 진한 갈색 윤기 소스 돔(타레 — 반짝이는 재질) + 위에 구운 자국(짙은 줄 여러 개, 돔을 가로지름) + 가운데 김 띠(위→앞, 위→등 아래, concept-salmon과 같은 문법) | `eel` |
    | `concept-uni` | 콘셉트 성게 군함 (테스트) | 38 | concept-ikura 군함 구조 재사용(김 벽 등·옆, 앞은 밥 속, 그릇 바닥) + 주황·겨자빛 성게 덩어리(길쭉한 혀 모양 조각이 나란히 누운 결, 둥근 알 아님) | `uni` |
    | `concept-tako` | 콘셉트 문어초밥 (테스트) | 39 | 흰 바탕 돔 + 보라/적갈 가장자리 + 위에 빨판 점(작은 원판 몇 개) + 가운데 김 띠 | `octopus` |
    | `concept-inari` | 콘셉트 유부초밥 (테스트) | 40 | 밥 위에 얹는 토핑이 아니라 **몸 전체를 덮는 갈색 유부 주머니**. 위가 열려 있어 밥(흰색)이 살짝 보이고, 주머니 위 테두리가 약간 접히거나 주름진다. 얼굴은 유부 앞면에 보인다 | `inari` |
  - 이름·대사 (대사 2줄씩, 탈락 말풍선):
    | id | 대사 1 | 대사 2 |
    |---|---|---|
    | `concept-unagi` | 소스가 너무 미끄러웠어! | 지글지글 구운 장어~ |
    | `concept-uni` | 성게가 흘러내려… | 김 그릇 꽉 잡아! |
    | `concept-tako` | 빨판으로 붙어 볼걸… | 쫄깃쫄깃 문어 출동! |
    | `concept-inari` | 주머니에서 밥이 샜어! | 달콤한 유부 속으로~ |
  - `SushiConceptSample`: 새 4종 토핑을 `TOPPINGS[skinId]`에 추가, `SKIN_IDS` 5 → 9. 기존 `dome`·`domeBand`·김 띠·군함 그릇 함수를 재사용한다(장어·문어 = 돔 문법, 성게 = 연어알 군함 그릇 문법). inari는 아래 "inari 예외"대로.
  - `SushiBody`: 바꿀 곳이 없어야 한다(`SKIN_IDS`에서 자동 연결). 필요하면 바꾸되 require는 여전히 `SushiConceptSample` 하나.
  - 렌더 도구 `--sample concept-<새 스킨>` 그대로 사용, 비교 그림(`compare`)은 위 표의 기존 스킨과. 렌더 비평 3회 이상, PNG 커밋.
  - 새 테스트 `tests/m5-29-concept-skins-2.spec.luau`, 카탈로그 개수 기존 테스트 갱신(36 → 40, Basic 6 → 10, 실험 5 → 9).
  - m5-26 현지화가 main에 있으면 CSV 키 추가 (AC9).
- 제외
  - 가격·등급·판매 (사용자 결정 2026-10-14: 콘셉트 스킨은 무료 테스트 유지)
  - 기존 31종·콘셉트 5종 모양 변경, 기준 몸 교체
  - 게임 중 내 캐릭터 표정 바꾸기 (m5-27·28과 같음, 인형만)
  - 공용 파일 변경

### inari 예외 (AC5 범위)
유부초밥은 밥을 유부가 감싸는 음식이라 "공유 밥 위에 토핑" 구조가 맞지 않는다. 그래서 inari만 아래처럼 예외를 둔다.
- **같아야 하는 것 (예외 없음)**: 얼굴(표정 4종 전부 — 눈·감은 눈·입·볼·땀·반창고 등)·팔·다리 파츠의 크기·위치·색·재질, 관절 8개(눈·감은 눈·발·팔)의 이름·위치·축, 깜빡임·걸음 때 움직임. 받침 파츠의 크기·위치.
- **달라도 되는 것**: 공유 밥 파츠의 **색·재질만**(유부 갈색, 예: 노릇한 갈색 계열, 재질 자유). 크기·위치·모양은 concept-salmon 밥과 같다 — 그래야 얼굴이 원래 자리(유부 앞면)에 그대로 보이고 깜빡일 때 눈이 몸 속으로 들어간다.
- **추가 파츠**: 주머니 위 테두리(접힌 입구·주름), 입구 안에 살짝 보이는 흰 밥(위쪽에만), 유부 겉면 결(선택). 추가 파츠는 얼굴 높이에서 밥 앞면보다 앞으로 나오지 않는다(다른 스킨의 토핑 규칙과 같음). 몸 외곽 폭은 콘셉트 공통 폭(4.76, 팔 포함)을 넘지 않는다.
- 받침 색은 그대로 둔다(받침이 유부와 같은 색이면 발과 몸이 붙어 보임 — 개발이 렌더 보고 바꾸고 싶으면 결정 기록에 남긴다).

## 수용 기준
### 순수 로직 (lune 테스트로 확인)
- [ ] AC1: 카탈로그 40종. 새 4종은 Basic·`experimental = true`·가격/얻는 길 없음, 이름은 위 표 그대로("(테스트)" 포함), order 37~40(탈의실 "전체" 맨 끝, concept-ikura 다음), 대사 2줄(위 표). `Skins.validate` 통과. 기본 등급 10종, 실험 스킨 9종.
- [ ] AC2: `Skins.EXPERIMENTAL_IDS` = `SushiBody.EXPERIMENTAL`의 id = `SushiConceptSample.SKIN_IDS` (9종, 정확한 목록 비교). 목록 밖 id에 `experimental`을 달거나 새 스킨에 가격·다른 등급을 붙이면 validate가 잡는다.
- [ ] AC3: 새 프로필에서도 새 4종 모두 장착 가능·카드 "입기", 코인·로벅스 구매 요청은 `AlreadyOwned`, 저장 `ownedSkins`에는 안 들어가고 장착값은 `migrate` 뒤에도 유지.
- [ ] AC4: 9종 × 표정 4종 모두 파츠 ≤ 47, 발바닥 = `GROUND_OFFSET`(2.25), 꼭대기 ≤ 이름표 − 0.4, 효과 0, z-fighting 0, 떠 있는 파츠 0, 이름 중복 0.
- [ ] AC5: concept-unagi·uni·tako의 밥·받침·팔·다리·얼굴(표정별) 파츠와 관절이 concept-salmon과 크기·위치·색·재질까지 같다. 토핑은 얼굴 높이에서 밥 앞면보다 앞으로 안 나온다. **concept-inari**는 위 "inari 예외"대로: 얼굴·팔·다리·받침·관절은 같고, 밥 파츠는 크기·위치가 같고 색·재질만 다르며(테스트가 "다른 것은 Color·Material뿐"을 확인), 추가 파츠는 얼굴 높이에서 밥 앞면보다 앞으로 안 나오고 외곽 폭 ≤ 4.76.
- [ ] AC6: 새 4종도 관절 8개(눈·감은 눈·발·팔), 깜빡이면 눈이 몸 속·감은 눈이 앞, 발 위끝은 걸음 때도 받침 위. 진짜 Instance build: Body만 고정, `PartJoint` Motor6D(기본·당황 8, 신남·아픔 4), 충돌·쿼리·터치 없음, Massless.
- [ ] AC7: 콘셉트 5종(게임 4표정·견본 8조합)과 다른 31종 레이아웃이 이 작업 전과 바이트 단위로 같다 (개발 중 JSON 스냅숏 비교). 기존 m5-27·m5-28 테스트는 개수 기대값(5 → 9) 말고는 약화 없이 통과.
- [ ] AC8: `SushiBody`의 require는 `SushiConceptSample` 하나, 견본 모듈은 아무것도 require하지 않는다. 클라이언트·서버 코드에 콘셉트 id 분기 없음(이름·관절로 동작).
- [ ] AC9 (현지화): 개발 시작 때 main에 m5-26(`src/shared/Localization/Strings.csv`)이 있으면, 새 4종의 `skin.<id>.name` 4행 + `skin.<id>.speech.1|2` 8행(총 12행, `Source` 한국어 = `displayName`/`speech`, `en` 아래 표)을 추가하고 m5-26 테스트(데이터 동기화 AC5 포함)가 통과한다. 그때 콘셉트 5종의 키가 아직 없으면 같이 넣는다. main에 m5-26이 없으면 이 기준은 "해당 없음"으로 적고 개발 메모에 남긴다.
  | id | en name | en speech 1 | en speech 2 |
  |---|---|---|---|
  | `concept-unagi` | Concept Eel Sushi (Test) | The sauce was too slippery! | Sizzling grilled eel~ |
  | `concept-uni` | Concept Sea Urchin Gunkan (Test) | My urchin is sliding off… | Hold the seaweed cup tight! |
  | `concept-tako` | Concept Octopus Sushi (Test) | Should've used my suckers… | Chewy octopus, go! |
  | `concept-inari` | Concept Inari Sushi (Test) | Rice leaked out of my pouch! | Into the sweet tofu pouch~ |
- [ ] AC10: 검증 5단계 통과(rojo build, stylua, selene, `lune run tests` "N passed, 0 failed", luau-lsp 끝 코드 0). 돌리지 못한 단계는 보고에 그대로 적는다.

### 렌더 (개발이 PNG로 남기고 QA가 그림으로 확인)
- [ ] AC11: 렌더 → 글로 비평 → 고침 → 다시 렌더를 **3회 이상** 하고 회차별 비평을 `docs/developer/m5-29-concept-skins-2.md`에 남긴다. `docs/renders/characters/`에 새 4종 각각 `turntable`·`expressions`·`gameplay-back`·`mobile-back`·`compare`(위 표의 기존 스킨과) PNG와 40종 줄 세우기(`concept-skins-lineup.png` 갱신) PNG를 커밋한다.
- [ ] AC12: 휴대폰 뒤 카메라(480×270) 그림에서 9종이 서로 구분된다 — 특히 장어(진갈색 + 김 띠) ↔ 연어(주황 + 김 띠), 성게(겨자·주황 덩어리, 둥근 알 없음) ↔ 연어알(빨간 주황 알 + 오이), 문어(흰 + 보라 가장자리 + 김 띠) ↔ 새우(흰 + 주황 줄 + 꼬리), 유부(몸 전체 갈색)는 다른 모두와. 구분이 약하면 비평에 적고 고친다.

### Studio 확인
- [ ] AC13: 탈의실 "전체" 탭 맨 끝(concept-ikura 다음)에 새 4종 카드가 새 계정(또는 `resetprofile`)에서도 처음부터 "입기", 누르면 미리보기·내 캐릭터가 바뀐다.
- [ ] AC14: 달리기·숨쉬기·깜빡임·팔 흔들기·착지 찌그러짐이 concept-salmon과 같다. 발이 땅에 닿는다. inari는 깜빡일 때 눈이 유부 속으로 들어가고 얼굴이 유부에 가려지지 않는다.
- [ ] AC15: 탈락 인형(아픔 x x + 반창고), 우승·단상 인형(신남 ^ ^)이 새 4종에서도 나온다.
- [ ] AC16: 장어 소스 돔의 윤기(반짝이는 재질)가 Future 조명에서 너무 검거나 하얗게 날아가지 않는다.

## 공용 파일 변경
- 없음.

## 결정 기록
<!-- 날짜 · 질문 · 결정 · 누가 -->
- 2026-10-14 · 콘셉트 스킨 5종 가격·등급 (m5-28 열린 질문 1) · **무료 테스트 그대로 유지** (가격·등급·판매 없음) · 사용자
- 2026-10-14 · 콘셉트 스타일 다음 배치를 만들지 (m5-28 열린 질문 3) · **더 만든다** · 사용자
- 2026-10-14 · 2차 배치 종류 · 장어·성게 군함·문어·유부 4종 (기존 판매 스킨에 같은 음식이 있어 비교 가능한 것) · 메인 세션
- 2026-10-14 · inari 모양 · 토핑을 얹지 않고 공유 밥 파츠를 유부 색으로 바꾸고(크기·위치 그대로) 입구·주름·보이는 밥만 추가 — 얼굴·팔·다리·관절 공유를 지키면서 "밥을 감싼 주머니"로 읽히게 · 메인 세션·기획
- 2026-10-14 · 이름 · 기존 패턴 "콘셉트 ○○ (테스트)". 정식 이름 나누기(m5-28 열린 질문 2)는 판매를 정할 때까지 미룸 · 기획
- 참고 조사: 이번 스펙은 가격·보상·난이도 수치를 정하지 않는다(무료 테스트, 모양은 m5-28 기준 그대로). 그래서 새 REFERENCE 문서는 만들지 않았다. 스킨 판매로 바꿀 때는 `docs/REFERENCE-roblox-monetization.md` 기준으로 따로 정한다.
- 2026-10-14 · 장어·성게 모양 · **사용자 캐릭터 시트(`docs/귀여운 우니와 장어 초밥 캐릭터 시트.png`)를 따름** — 둘 다 몸 위쪽을 김 띠가 한 바퀴 두름. 장어 = 진갈색 윤기 판 + 세로 김 띠(구운 자국 없음, 참깨는 파츠 상한으로 뺌), 성게 = 높은 김 그릇 + 주황 덩어리 4줄 + 초록 잎(시트에 있음) · 사용자 시트 → 개발
- 2026-10-14 · 유부 받침·입 덮개 색 · 받침도 유부 색(밥과 0.01 겹친 옆면 z-fighting, 다리는 흰색이라 발 구분 유지), 입 덮개(MouthCover)도 몸 색을 따라감(흰 네모로 보였음) · 개발
- **열린 질문 (사용자, 급하지 않음)**
  1. 콘셉트 스킨을 나중에 판매로 바꿀지, 기존 같은 음식 스킨(연어·참치·장어 등)과 이름을 어떻게 나눌지 (m5-28 열린 질문 2 그대로).

## 개발 메모
<!-- developer가 작성: 바뀐 파일, Studio 확인 방법, 남은 이슈 -->
- 파츠 예산 참고(m5-28 개발 메모): 공유 부분 = 밥·받침 8 + 팔·다리 4 + 얼굴(기본 13 / 신남 9 / 당황 15 / 아픔 9) → 당황 표정 기준 **토핑(또는 inari 추가 파츠)은 20개 이하**여야 상한 47을 지킨다.
- 성게는 concept-ikura 그릇 함수를 재사용하되, 알 대신 길쭉한 덩어리(capsule·roundedBox 조각)로. 오이 조각은 넣지 않는다(연어알과 구분).
- **2026-10-14 개발 끝 (`in-qa`)** — 자세한 내용·렌더 비평 5회·파츠 수·Studio 확인 방법은 `docs/developer/m5-29-concept-skins-2.md`.
  - 바뀐 파일: `src/shared/Skins.luau`(4종·예외 목록), `src/shared/SushiConceptSample.luau`(토핑 4개, `band`, `RICE_LOOK`, `maskWithRice`), `src/shared/SushiBody.luau`(주석), `tools/render-character.luau`(compare 짝 unagi↔eel, tako↔octopus), 테스트 새 파일 1 + 개수 갱신 6, 그림 21장.
  - 장어·성게는 시트를 따라 스펙 표와 모양이 다름(결정 기록). AC5의 "얼굴 파츠 색 같음"에서 유부 `MouthCover`만 예외(색만 몸 색).
  - AC7: 기존 36종 레이아웃 242개 스냅숏 바이트 단위 같음. AC9: m5-26 미병합 → 해당 없음.
  - 검증 5단계 모두 통과 (1852 passed, 0 failed).
- **2026-10-14 QA 통과 (`qa-passed`)** — `docs/qa/m5-29-concept-skins-2.md`. 검증 5단계 통과(1858 passed, 0 failed), AC1~AC8·AC10~AC12 통과, AC9 해당 없음, AC13~16 사용자 Studio 확인 필요. P0/P1 없음. P3: B1 당황 표정 눈썹이 장어·성게 김 띠에 가려짐(게임에서는 안 쓰는 표정), B2 장어 등 세로 김이 밥과 0.14 떠 있음, B3 유부 입 덮개 색 예외를 AC5 문구에 적기(planner).
