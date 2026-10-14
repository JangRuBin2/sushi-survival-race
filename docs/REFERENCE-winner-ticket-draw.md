# REFERENCE — 우승자 뽑기 티켓 (무료 랜덤 보상) 조사

- 조사일: 2026-10-14 (planner)
- 쓰는 곳: `docs/specs/m5-31-winner-ticket-draw.md` 결정 기록, `docs/GDD.md` §9.1·§9.6
- 표기: **[원문]** = WebFetch로 원문을 읽고 확인, **[검색]** = 검색 요약만(원문 미확인), **확인 못 함** = 찾지 못함, **추정** = 우리 계산

## 1. Roblox 정책 — 무료로 얻는 랜덤 보상은 "유료 랜덤 아이템"이 아니다

| 항목 | 내용 | 출처 |
|---|---|---|
| 유료 랜덤 아이템의 정의 | Robux로, 또는 Robux로 산 게임 재화로 **직접·간접으로** 얻는 랜덤 아이템. "유료 게임 재화로 산 랜덤 아이템도 포함" | [원문] [Paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items) |
| 무료·플레이 보상 | Robux나 게임 재화 지불이 없는 행동의 보상이면 **확률 공개 의무가 없다** | [원문] 같은 문서 |
| 유료일 때 의무 | 모든 결과와 실제 확률을 보여 주고, 확률 합이 정확히 100% | [원문] 같은 문서 |
| `PolicyService.ArePaidRandomItemsRestricted` | true인 사용자는 유료 랜덤을 쓸 수 없고, 대안으로 "무료로 얻을 수 있는 경로" 등을 줘야 함 | [원문] 같은 문서 |
| 성숙도 설문 | 유료 랜덤 아이템이 있으면 Maturity & Compliance 설문에 신고. "행동을 완료한 대가로 주는 아이템"은 신고 대상 아님 | [원문] [Content maturity](https://create.roblox.com/docs/production/promotion/content-maturity) |
| 도박 규칙 | 도박 = "현실 돈·Robux·**가치 있는 게임 아이템**을 걸고 하는 운 게임". 플레이 가능한 도박(모의 도박 포함)은 금지 | [원문] 같은 문서 |
| 규제 경향 | 한국 확률형 아이템 규제가 Roblox 전체 확률 공개를 밀었다는 보도(2026-06) | [검색] REFERENCE-roblox-monetization §5 |

**우리 설계에 주는 결론 (기획 판단)**
1. 티켓을 **우승으로만** 주고 Robux·코인·이벤트 재화·코드·상품으로는 절대 주지 않으면 "유료 랜덤 아이템"이 아니다(직접·간접 모두 없음). 코인도 Robux로 팔지 않으므로(GDD 9.1) 간접 경로도 없다.
2. 도박 정의의 "가치 있는 게임 아이템을 건다"를 피하려고: 티켓은 **뽑기 말고 쓸 곳이 없고**, 코인으로 사거나 코인으로 바꿀 수 없고, 거래도 없다. 뽑기는 늘 무언가(스킨 또는 코인)를 준다 — "잃는" 결과가 없다.
3. 의무는 아니지만 **확률은 뽑기 화면에 공개**한다(어린 이용층 신뢰, 한국 규제 경향, 나중에 유료로 바뀌는 일을 막는 장치).
4. 이 조건(티켓 = 무료 획득만)이 깨지면 바로 유료 랜덤 아이템 규칙(확률 공개, `ArePaidRandomItemsRestricted` 대응, 설문 신고)이 적용된다. 그래서 GDD에 "티켓을 파는 상품을 만들지 않는다"를 규칙으로 둔다.
5. 성숙도 설문: 유료 랜덤 아이템 "없음"으로 답하는 것이 문서와 맞다 — 사용자가 설문을 채울 때 확인(USER-TODO).

## 2. 비슷한 로블록스 게임 — 플레이 재화로 여는 랜덤 보상

| 게임 | 여는 데 쓰는 것 | 얻는 길 | 확률 공개 | 중복 처리 | 출처 |
|---|---|---|---|---|---|
| Murder Mystery 2 | 상자 1개 = 코인 1,000 / 다이아 100 / 미스터리 키 1 | 코인은 플레이로 무료 | 상자 등급별 70% / 15% / 10% / 5% (팬 위키 기준) | 확인 못 함 | [원문] [bloxodes MM2 Boxes](https://bloxodes.com/wiki/murder-mystery-2/boxes) |
| Tower Defense Simulator | 스킨 상자(코인), 골든 스킨 상자 50,000 코인 | 코인은 플레이로 무료 | 등급(일반·고급·레어·전설)마다 확률이 다름, 정확한 % 확인 못 함 | 골든 상자는 6종 중 하나, **겹치지 않음** | [검색] [TDS Wiki Crates](https://tds.fandom.com/wiki/Crates), [검색] [touchtapplay](https://www.touchtapplay.com/tower-defense-simulator-golden-perks-explained/) |
| Rivals | 키로 상자 열기 | 경기 승리·과제·코드로 키 획득(양은 출처마다 다름). 유료 상자도 있음 | 유료 상자는 확률 공개 | 확인 못 함 | [검색] [thespike.gg](https://thespike.gg/roblox/game-codes/roblox-rivals), REFERENCE-roblox-monetization §3 I |
| Blade Ball | 휠 스핀 | 접속 시간·코드로 무료 스핀, 코인 3,000 또는 Robux 묶음으로도 | 확인 못 함 | 확인 못 함 | [검색] [tryhardguides](https://tryhardguides.com/how-to-get-sci-fi-spins-in-blade-ball/), [검색] [ggrecon](https://www.ggrecon.com/guides/blade-ball-codes-free-coins-spins-tickets/) |

관찰
- 장르 인기작은 "플레이로 얻는 재화 → 랜덤 상자"가 흔하다(MM2·TDS·Rivals). 다만 이들 대부분은 같은 상자를 Robux 재화(다이아·Robux 묶음)로도 열 수 있다 — 우리는 **그 유료 경로를 두지 않는다**.
- "이미 가진 것은 다시 안 나옴"(TDS 골든 상자) 사례가 있다 → 우리도 가진 스킨은 뽑기 후보에서 뺀다.
- 승리로 키를 주는 사례(Rivals) → "우승 = 티켓 1장"과 같은 방향.
- 천장(몇 번 실패하면 보장) 사례: **확인 못 함**(위 4개 게임에서 찾지 못함).

## 3. 우리 수치 — 얼마나 어려운가 (추정)

| 항목 | 값 | 계산 (추정) |
|---|---|---|
| 티켓 | 우승 1번 = 1장 | 8명 방 평균 우승 확률 1/8 → 약 8판에 1장 |
| 스킨 당첨 | 10% (사용자 결정) | 스킨 1개 ≈ 티켓 10장 ≈ **약 80판**(한 판 4~5분 → 약 6시간) |
| 9종 모두 | — | 약 90장 ≈ 720판. 가진 것은 빠져서 끝까지 10% |
| 비교: 레어 코인 해금 | 900 코인 | 약 30판(REFERENCE-roblox-monetization 7.1) → 뽑기 스킨은 레어 해금보다 약 2.7배 어렵다 = "꽤 어려운 스킨" |
| 꽝 위로 | 🍚 +20 | 한 판 평균 30 코인보다 적게 — 뽑기를 코인 벌이 수단으로 만들지 않음 |
| 9종 다 가진 뒤 당첨 | 🍚 +100 | 우승 보상(+100)과 같은 크기, 일반 해금(300)의 1/3 |
| 티켓 상한 | 99장 | 화면 두 자리, 미리 모아 두기 상한. 1장/우승이라 거의 닿지 않음 |

- 근거 요약: 플레이 재화 상자(MM2·TDS), 승리 보상 키(Rivals), 중복 제외(TDS 골든), 무료 획득이면 확률 공개 의무 없음(Roblox 문서) — 그래도 공개한다.
