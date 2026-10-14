# m5-32 고등어 초밥 [신선] — 개발 작업 기록

## 2026-10-14 (3번째 세션) — 아트 패스·소리 간격·정리, `in-qa`
- 브랜치: `m5-32-fresh-mackerel` (worktree `.claude/worktrees/agent-a10906f098e1dcf01`), main 8f700a4에서 시작. main 병합 안 함.
- 끝난 것
  - 앞 세션 두 번(사용 한도·중단)이 남긴 것 확인: 카탈로그·`conceptBody` 이름 바꾸기·관절 사슬·`fishPose`/`FishRig`/`DollAnimator`·화남/슬픔 표정·`FishFlop`/`FishSplash`·뽑기 전설 연결·m5-31 재QA R1(`detailPanel.Active = true`)·R2(이름·대사 칸 0.52, 휴대폰 큰 미리보기 0.44)가 이미 되어 있었고 테스트 1932개가 통과하던 상태.
  - 렌더 → 비평 → 고침 4회 (아래 "렌더 비평"). 고등어 모양·움직임 수치·밥 김(`NoriWrap`/`NoriWrapBack`) 추가.
  - 소리 간격을 "같은 소리마다 캐릭터당 0.25초에 한 번"으로 고침(`CharacterAnimLogic.fishSoundFilter`) — 전에는 첨벙(FishSplash)이 간격 검사를 아예 건너뛰어서, 팔딱이 막힌 프레임에도 첨벙만 울릴 수 있었음.
  - 렌더 도구에 `closeup` 뷰(앞·3/4·뒤 큰 칸), `flop-strip`을 3/4 각도로(꼬리 좌우 파닥이 보이게).
  - 임시 탐색 파일 `tests/_probe.luau`(git rm)·`tests/_one.luau`·`tests/_dump.luau` 지움. `_probe2.luau`·`tools/_probe3.luau`는 앞 세션 커밋에서 이미 지워져 있었음.
  - CRLF: `git ls-files --eol`로 src·tests·tools·docs 전부 `w/lf` 확인(`.gitattributes`가 `eol=lf`). stylua 통과.
- 남은 것: QA, 사용자 Studio 확인(AC14~AC18), 상품 id(USER-TODO C3), 소리 id(A2).
- 다음 첫 단계(QA): `docs/specs/m5-32-fresh-mackerel.md` AC1~AC13 대조, `docs/renders/characters/fresh-mackerel-*.png`를 시트와 나란히.
- 막힌 점: 없음.

### 바뀐 파일 (main 8f700a4 대비, 이번 세션 포함 전체)
- 몸·모양: `src/shared/ConceptMackerel.luau`(새), `PartMath.luau`(새), `SushiPose.luau`(새), `SushiConceptSample.luau`(화남·슬픔, 고등어 토핑), `SushiBody.luau`(`CONCEPT_BODY`, 관절 사슬 build, 파츠 상한 80), `Skins.luau`(`fresh-mackerel`, `conceptBody`, `CONCEPT_BODY_IDS`).
- 움직임·소리: `CharacterAnimLogic.luau`(`FISH`·`fishPose`·`fishBlend`·`fishMotion`·`fishCues`·`fishSoundFilter`·`nextFlopDelay`), `client/fx/FishRig.luau`(새), `client/fx/DollAnimator.luau`(새), `CharacterFxController.luau`, `Elimination/VictoryCutsceneController.luau`·`LobbyFxController.luau`(인형에 DollAnimator), `SfxCues.luau`·`SfxLibrary.luau`(FishFlop·FishSplash, 무음·3D 60), `client/Sfx.luau`(항목별 maxDistance).
- 화면: `ShopLogic.luau`(뽑기 안내), `ShopScreen.luau`·`ShopController.luau`(미리보기 팔딱), `DrawScreen.luau`(표정 6칸, 로벅스 사기 버튼, R1·R2), `UiLayout.luau`(`previewDistance`).
- 도구: `tools/render-character.luau`(콘셉트 몸 게임 스킨, `--pose`, `--sheet`, poses·flop-strip·sheet-compare·closeup), `tools/render/Png.luau`(PNG 읽기), `tools/render/Sheet.luau`(자르기·줄이기).
- 테스트: `tests/m5-32-fresh-mackerel.spec.luau`(새, 21개), `tests/lib/LayoutSnapshot.luau`·`tests/fixtures/m5-32-layout-snapshot.txt`(main 8f700a4 레이아웃 40종 + 콘셉트 9종 × 4표정 바이트 스냅숏), 예전 `experimental` 이름을 쓰던 테스트들.

### 렌더 비평 (시트 `docs/고등어 초밥 캐릭터 시트.png`와 나란히 — `--view sheet`의 sheet-compare, `closeup`)
**1회차** (앞 세션 마지막 상태, `fresh-mackerel-before-sheet-compare.png`·`-before-flop-strip.png`)
- 정면: 시트는 머리가 통통하고 몸이 머리 뒤에서 바로 가늘어지는 물방울 모양인데, 렌더는 굵기가 거의 같은 관(캡슐)이라 "고등어"보다 "파란 소시지". 입이 안 보임(입 공이 머리 속에 묻힘). 줄무늬가 짙은 남색 고리로 대비가 너무 세서 사다리처럼 보임. 등 색이 보라빛이 돌 만큼 채도가 높음(시트는 회청색). 가슴지느러미가 배 은색과 비슷한 밝은 색이라 거의 안 보임.
- 3/4: 김 띠가 좁고(0.8) 밥 윗면 위에서 끝나서 고등어만 묶은 고무줄처럼 보임 — 시트는 김이 고등어와 밥을 같이 감아 밥 옆까지 내려옴. 꼬리지느러미가 밝은 파랑이라 몸과 따로 놂.
- 후면: 시트는 김이 밥 뒷면을 따라 길게 내려가는 게 가장 눈에 띄는데 렌더엔 없음. 꼬리 V는 시트와 비슷.
- 팔딱(flop-strip): 0.17초 프레임에서 아치로 머리가 들릴 때 앞몸 뒤끝과 뒷몸 사이에 턱(단면 차)이 보임.
**고침**: 고등어를 0.07 낮춰 밥에 더 묻히고(배 아래끝 0.84), 머리 공을 몸보다 크게(HEAD 단면 rd 0.86·rb 0.9), 앞몸 뒤끝에 둥근 공(등·배) — 이음매 턱 없앰, 입을 주둥이를 Z로 꿰뚫는 짙은 분홍 원판 + 분홍 혀로(옆에서 보임), 줄무늬 폭 −25%·색을 등과 가깝게, 등·꼬리·가슴지느러미 색 조정, 김 띠 폭 1.0 + **밥 김**(`NoriWrap` 밥 윗면 가장자리 + 앞면 위 0.17, `NoriWrapBack` 뒷면 0.3까지), 아가미 배 쪽 선 빼기(은빛 배에서 안 보임, 파츠 예산).

**2회차** (`closeup`)
- 정면: 머리가 둥글게 커져 시트 실루엣에 가까워짐. 입은 보이지만 밝은 빨강이라 "빨간 코"처럼 읽힘. 가슴지느러미가 몸 가운데 회청색 삼각으로 보이기 시작.
- 3/4: 김이 고등어 → 밥 윗면 → 밥 앞 가장자리로 이어져 시트처럼 "같이 감은" 모양. 윤기 띠(흰 판)가 회색 막대로 보여 젖은 느낌이 약함.
- 후면: 김 자락이 밥 뒷면을 따라 내려와 시트 후면과 같은 인상. 앞몸 배 원기둥 끝에 세로 턱이 보임.
**고침**: 입 색을 더 짙게(92,28,44)·위치를 주둥이 끝에서 조금 뒤·아래로, 윤기 띠를 반투명 Neon(빛나는 띠)으로, 배 색을 살짝 은회색(214,219,228)으로(하얗게 날아가지 않게), 줄무늬 기울기 +5°(더 비스듬히).

**3회차**
- 정면·3/4: 윤기 띠가 등 위 밝은 줄로 보여 "막 잡은 젖은" 느낌이 남(AC13). 배는 은빛, 등은 회청색 + 비스듬한 줄 — 시트보다 줄무늬가 곧고 규칙적(고리 원판 방식의 한계, 물결 모양은 못 냄). 입은 벌린 입("ㅇ")으로 읽힘.
- 후면: 앞몸 배 끝 턱이 아직 보임.
**고침**: 앞몸 배 끝에도 둥근 공(`FishRootEndBelly`) — 대신 김 띠 속에 완전히 숨어 있던 뒷몸 앞마디 끝 공 둘(`FishMidEnd*`)을 뺌(파츠 수 같음). 물방울 지름 +25%·더 진한 물빛·투명 0.2(팔딱 순간 잘 보이게).

**4회차 (최종, `fresh-mackerel-*.png`)**
- 정면(시트 정면 대비): 머리 = 보는 사람 왼쪽, 큰 크림 눈 + 검은 눈동자 + 흰 반짝, 벌린 입, 은빛 배·회청색 등·줄무늬·윤기 띠, 가슴지느러미, 김이 뒤쪽 1/3을 비스듬히 감고 밥 앞 가장자리까지. 시트와 다른 점: 고등어가 시트보다 낮고 길쭉함(이름표 한도 — 쉰 꼭대기 3.2·팔딱 3.6 때문에 몸 높이 약 2.0이 한계), 줄무늬가 물결이 아닌 곧은 사선, 밥 김은 앞면에서 얼굴(땀·💢·눈썹)을 가리지 않게 짧음.
- 3/4: 시트와 같은 인상(머리·눈·입이 앞, 김 띠, V자 꼬리). 다른 점: 꼬리가 시트보다 작음(팔딱 꼭대기 3.6 한도).
- 후면: 김 자락이 밥 뒷면을 따라 길게 — 시트 후면과 가장 비슷. 꼬리 V 또렷.
- 휴대폰 뒤 카메라(480×270): 청회색 등 + 흰 배 + 눈 + 검은 김 + V꼬리로 고등어로 읽힘. 옆의 장어(특)·판매 장어(갈색·주황)와 색이 달라 헷갈리지 않음(AC12).
- 팔딱(poses·flop-strip): 착지 팔딱 0.17~0.33초에 고등어가 들리며 머리가 위로, 꼬리가 좌우로 파닥, 물방울 4개가 튐. 고등어가 들리면 밥 김(움직이지 않음)과 고등어 띠 사이가 잠깐 벌어짐 — "김에서 튀어 오르는" 모양으로 의도함(아래 결정).
- 로비 조명(`-turntable-lobby`·`-poses-lobby`): 따뜻한 색에서도 등이 회청색으로 남고 배가 은빛.

### 결정·수치 (스펙 결정 기록에도 적음)
- 들썩: 가끔 팔딱 `FLOP_LIFT` 0.3(스펙 기본 0.35), 착지 `LAND_LIFT` 0.41(스펙 0.45×세기), 아치 `FLOP_ROOT_ARCH` 10°(12°) — 꼬리 위 갈래가 팔딱 꼭대기 3.6(이름표)을 넘지 않게. 비틀림 4° → 5°. 다른 값은 스펙 기본값.
- 밥 김 `NoriWrap`·`NoriWrapBack`은 Body에 용접(움직이지 않음). 고등어 띠·자락은 스펙대로 FishMid에 붙어 같이 움직임. 이름이 `Fish`로 시작하지 않아 고등어 파츠 검사(밥 윗면 −0.2 아래 금지)에서 빠지고, 대신 전용 테스트(얼굴 위끝 + 0.1 위, 밥 앞면 평평한 곳, 관절 아님, 띠 자락이 그 위에)로 고정.
- 파츠: 기본 75 · 신남 71 · 당황 77 · 아픔 71 · 화남 79 · 슬픔 79 (상한 80).
- 소리: 같은 소리(FishFlop·FishSplash 각각)는 캐릭터당 0.25초에 한 번 이하. 팔딱과 첨벙은 짝이라 서로 막지 않음.

### Studio 확인 방법 (사용자·QA)
1. **판매·입기(AC14)**: `Config.DEBUG.fakeRobuxInStudio = true`(커밋 전 되돌리기) → Play → 탈의실 전설 탭 맨 끝 "고등어 초밥 [신선]" 카드, "🎫 뽑기 전설에서도 나와요" 안내, 상품 id가 없으면 "곧 열려요". 가짜 결제 → 보유·자동 장착.
2. **뽑기(AC14-1)**: 관리자 패널 `tickets 99` → 탈의실 🎫 뽑기: 확률표 전설 1.0%(금색)·영웅 5.0·희귀 15.0·고급 30.0·일반 49.0, 단상에 고등어가 팔딱거리며 "고등어 초밥 [신선] 획득 가능!", 보유 n/10. 상세에서 "R$ 199로 사기"(상품 id 전엔 "R$ 199 — 곧 열려요"). 1%라 고등어 당첨 화면은 평균 100장 — `tickets`를 여러 번 주고 계속 뽑아야 함(Studio 전용 강제 설정은 공용 파일 `Config`라 만들지 않음).
3. **움직임(AC15)**: 고등어를 입고 가만히 → 꼬리 살랑, 2.5~6초마다 팔딱(들썩 + 꼬리 파닥 + 물방울). 달리기 → 꼬리가 걸음 2배로 계속. 점프 → 공중에서 C자, 착지 → 큰 팔딱 + 물방울. 넘어짐(잡기·다이브) → 빠른 퍼덕. `Test → Clients and Servers` 2명에서 상대 고등어도 같은지.
4. **인형(AC17)**: 탈락 연출(축 처짐 + 가끔 경련), 우승 연출·로비 단상(1.0~1.6초마다 팔딱), 탈의실·뽑기 상세 미리보기(살랑 + 1.5~3초마다 팔딱). 닫으면 멈추고 출력 창에 오류 없음.
5. **조명(AC16)**: Future 조명 로비·맵 2~3개에서 등 윤기 띠(Neon 반투명)가 너무 밝지 않은지, 꼬리 Sparkles가 물기처럼.
6. **성능(AC18)**: 8명 모두 고등어(관리자 미리보기)로 F9 → 마이크로프로파일러에서 다른 전설 8명과 비교. 60 studs 밖 고등어는 멈춤.
7. **소리**: 소리 id가 비어 있어 지금은 무음(USER-TODO A2). id를 넣으면 팔딱·착지에서만 3D로(60 studs), 살랑·경련엔 없음.
- AC19(현지화): main에 m5-26(`src/shared/Localization/Strings.csv`)이 없어서 **해당 없음**.

## 이전 세션 (2026-10-14, 끊김 2번)
- 1차: 레이아웃 스냅숏(5ef5bfa), 고등어 몸·움직임·뽑기 연결 진행 중 사용 한도로 중단(63385d8 wip).
- 2차: 단면 재설계·김 띠·눈·가슴지느러미(2d3b03b wip), 팔딱 애니메이션·관절 사슬 build·뽑기/상점 연결·테스트(cbef152). 개발 메모 없이 중단.
