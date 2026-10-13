# m5-07 season events — 개발 작업 기록

## 2026-10-08 — 착수만 함, 코드 변경 없음 (최신)
- **브랜치**: `m5-07-season` (origin/main c4ca608에서). 스펙 status `in-dev`.
- **끝난 것**: 스펙·m5-03 인계 메모·관련 코드 읽기와 설계. `src/` 변경은 아직 없음.
- **남은 것**: 스펙 범위 전부 (AC1~AC7 구현·테스트, 검증 5단계, 커밋, in-qa).
- **검증 상태**: 코드 변경이 없어 돌리지 않음.
- **막힌 점**: 없음. 세션 종료 지시로 중단.

### 다음에 할 첫 단계
`src/shared/RewardLogic.luau`부터: Grant에 `tokens?`/`eventId?`, `onRoundStart`/`onResult`에 마지막 인자 `now: number?`
(nil이면 재화 없음 — 기존 테스트 유지), `tokensFor(reason, now)`(Seasons.current + Config.Events.Tokens),
매치 끝 `matchEndPayout(lastDay, today, now)` → DailyFirstMatch(코인 50 + 재화 1+3) / MatchPlayed(0 + 1) / nil.

### 설계 메모 (조사 결과)
- **RewardService**: `grantWith`의 mutate가 `{ reason, amount, tokens?, eventId? }`를 돌려주게 바꿔 코인·재화를 한 update에서
  반영, 코인>0 또는 재화>0일 때만 RewardGranted(`tokens`·`tokenTotal`·`eventId`). 지금 시각 = `Seasons.now(RunService:IsStudio(), Config.DEBUG.eventNow, os.time())`.
  매치 끝 이유(DailyFirstMatch/MatchPlayed)는 update 안에서 정함.
- **ShopLogic**: Reason에 `EventEnded`·`NeedTokens`·`NotForTokens`. `canBuyWithTokens(skinId, wallet, now, canSave, locked?)` 순서:
  카탈로그(tokens) → 이벤트 진행 중 → 미보유 → 잠금 → 저장 가능 → 재화 ≥ 가격. `buyWithTokens`는 차감+보유+장착(update 안).
  Wallet/ViewLike에 `eventTokens?`. `cardState(skin, view, robux?, now?)`에 kind `Tokens`/`NeedTokens`/`Vip`/`OffSale` 추가
  (now nil이면 기간 확인 안 함 — ReceiptLogic과 같은 의미). `visibleSkins(view, tab, now)`(기간 끝+미보유 한정은 숨김),
  `tabs(now)`(이벤트 탭 라벨 "🎃 할로윈"/"🎄 크리스마스"는 ShopLogic에 — Seasons는 숫자만 고침),
  `eventHeader(event, now, tokens?)` 마지막 날 = endsAt−1 UTC 날짜(os.date 없이 일수→날짜 계산), `isLimited(skin)`.
- **ShopService**: `bind("BuyWithTokens", onBuyWithTokens)` — 기존 allowRequest 쿨다운 공유, canPersist or Studio, 성공 시
  clearPreview + AppearanceService.refresh + saveNow.
- **SushiBody**: 새 Effect `"Light"`(PointLight 약하게, ghost-tamago). setEffectsEnabled에 PointLight 포함.
  tree-maki·vip-gold-tamago는 Sparkles. 외곽 ±15% 확인.
- **테스트 영향 (내 목록 밖이지만 바꿔야 함 — 결정 기록에 적을 것)**: `tests/skins.spec.luau`의 `withEffect` 표에 새 스킨 효과 추가,
  `tests/m5-03-foundation.spec.luau` "AC5 탈의실 카드 Soon" 테스트를 새 카드 상태로 갱신.
- **클라이언트**: CoinScreen 배지에 재화 라벨(이벤트 없으면 숨김), 토스트 "+10 🍚 +1 🍬 라운드 통과", 재화 받으면
  `Sfx.play("TokenGet")`(Sfx 모듈 위치 확인 필요), 정산 줄에 이번 판 재화 합계. ShopScreen 탭을 데이터 기반으로
  (이벤트 탭 맨 앞, 열 때 먼저 선택), 머리줄 + 안내 문구, 카드 "한정" 표시, 가격은 `PriceCache.product`.
- **LobbyService**: 시작 때와 10분마다 Seasons.current로 장식 폴더 켜고 끄기 (CanCollide/CanQuery/CanTouch false, 40파츠 이하).
