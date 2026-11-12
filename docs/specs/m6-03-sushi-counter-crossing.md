status: qa-passed
<!-- draft | ready | in-dev | in-qa | qa-passed | done -->

# m6-03 — 대형 Race "초밥집 카운터 대횡단" (`sushi-counter-crossing`)

- 마일스톤: M6 · 기반 m6-02 · 제안서 `docs/proposals/large-maps.md` ① (배치도 `docs/proposals/large-maps/01-sushi-counter-crossing.png`)
- 종류 Race · `capacity = 40` · `minPlayers = 12` · 시간 제한 `Config.TimeLimit.Race`(90) · Race 부활(m6-01) 그대로
- 이름 "초밥집 카운터 대횡단" / 규칙 "세 갈래 길 중 하나를 골라 젓가락을 피해 계산대까지 달려요!" (CSV `map.sushi-counter-crossing.*`, en "Sushi Counter Crossing")
- 파일: `SushiCounterCrossing{,Layout,Logic,Art}.luau`, 테스트 `tests/map-sushi-counter-crossing.spec.luau`, 공용 하네스 `tests/lib/LargeMapHarness.luau`

## 코스 (모든 수치 기본값)
| 구간 | z | 바닥 | 내용 |
|---|---|---|---|
| A 출발 광장 | 0 ~ -40 | 0 | 폭 72, 스폰 40 (8 × 5, 간격 8 × 7) |
| B 갈림길 | -40 ~ -200 | 0 | 폭 18 × 3줄, 틈 9. 왼 **회전 레일**(40씩 4구간, 이웃 반대, 5초마다 뒤바뀜, 목표 속도 10, 색 청록=앞/연어=뒤, 0.4초 전 `RailSwitch`) · 가운데 **접시 징검다리** 13개(지름 10, 틈 약 4.4) · 오른 **간장병**(2.5초 간격, 속도 14, 길이 10 × 지름 4 — 옆 8로 피하거나 점프) |
| C 합류 광장 | -200 ~ -240 | 0 | 폭 72 |
| D 젓가락 들판 | -240 ~ -380 | 0 | 폭 72 + 양옆 낮은 벽 4. 0.9초마다 빨간 원(반지름 7) → 1.5초 뒤 젓가락 쿡: 원 안 사람을 바깥으로 넉백 34 + 위 16 (`ChopstickWarn`·`ChopstickClack`) |
| E 계산대 오르막 | -380 ~ -500 | 0 → 12 | 폭 14 × 4줄, 틈 4. 바깥 두 줄 **영수증**이 뒤로 5 밂(느리지만 안전) / 안쪽 두 줄 **동전 더미**가 2.2초마다 굴러옴(빠르지만 위험) |
| F 결승 | -500 ~ -524 | 12 | FinishLine z -510 |

- 맞음(간장병·동전): 판정 상자 + 1, 발 높이 3.5 미만이면 뒤로 26 + 위 12 넥백, 면제 1초, 쿨다운 0.8초. 소리는 기존 cue `Knockdown`.
- 연속 밀기(레일·영수증)는 `MoveExempt` 없음, 넉백만 `MoveExempt.mark`(서버 모듈에 한 곳).
- 낙하선 = 바닥 − 12 → Race 부활(정원 전) / 탈락(정원 뒤).
- 빠른 사람 추정 `Logic.estimateClearTime()` ≈ 50초(걷기 16 + 구간 지연 18).

## 아트
- "저녁 초밥집 카운터 — 작은 초밥이 거대한 히노키 카운터를 가로질러요". 코스는 공중에 뜬 밝은 판, 요리사 쪽 뒷선반(+18)·손님 의자(-22)는 높이가 달라 걸을 수 있는 바닥으로 오해하지 않게.
- 요리사 쪽: 재료 진열장(연어·참치·계란), 도마·칼, 미닫이 캐비닛 / 뒤 벽: 술병 선반 2단·노렌(흔들림)·메뉴 나무패 / 천장 등불 줄(PointLight 반쯤) / 손님 쪽: 빨간 의자·찻잔(김)·생강·와사비·창호지 벽(SurfaceLight 4) / 결승 너머 큰 계산대(초록 화면)·손 흔드는 복고양이·꽃가루.
- Large 예산 안: 장식 1457 · 조명 16(그림자 1) · 파티클 5 · 움직임 47. 렌더 3회(① 등불 띠가 접시처럼 보임·시야 가림 → ② 손님 쪽 비어 보임·소개 ④ 막힘·계산대 얼굴이 뒤쪽 → ③). 첫 렌더는 보관하지 못했고 마지막 렌더는 `docs/renders/sushi-counter-crossing/after-*.png`.

## Studio 확인 (DEV-SETUP 3-17)
- 40명 출발이 한 줄로 막히지 않는지(Clients and Servers 여러 명), 레일 색이 바뀌는 게 보이는지, 간장병·동전 맞음이 억울하지 않은지(점프로 넘기), 젓가락 원이 휴대폰에서도 잘 보이는지, 완주 시간 실측(목표 50~60초).

## QA
- 2026-11-12 QA 통과(`docs/qa/m6-03-sushi-counter-crossing.md`): P1/P2 없음, P3 4개(before 렌더 없음, 들판 끝 넉백이 오르막 틈으로, 다이너마이트 갈림길 허공 약 31%, 간장병·동전은 마주 달려야 점프로 넘음). Studio 확인 대기.
