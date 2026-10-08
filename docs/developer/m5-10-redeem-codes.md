# m5-10 redeem codes — 개발 작업 기록

## 2026-10-08 — 시작만 함, 세션 종료로 중단 (최신)
- **브랜치**: `m5-10-codes` (origin/main `c4ca608` 기반). 커밋: `wip: m5-10 ...` (스펙 status in-dev + 이 메모만).
- **끝난 것**: 스펙·m5-03 인계 읽기, 관련 코드 조사. 코드 변경은 아직 없음.
- **검증 상태**: 코드 변경이 없어 돌리지 않음.
- **남은 것**: 스펙 "이 스펙이 고치는 파일" 전부 — `src/shared/CodeLogic.luau`(새), `src/server/CodeService.luau`(껍데기 채우기),
  `src/client/ui/CodeScreen.luau`(새), `src/client/ui/CodeController.luau`(껍데기 채우기), `tests/code-logic.spec.luau`(새).
  스펙의 "새 CodeConfig.luau" 대신 m5-03 로더 `CodeConfig.load()`를 그대로 씀. **CodeList.luau는 만들지도 커밋하지도 않음.**
- **다음에 할 첫 단계**: `src/shared/CodeLogic.luau` 작성 + `tests/code-logic.spec.luau`(가짜 코드만, 예: `FAKE2026`).

### 조사해 둔 것 (설계 메모)
- 이미 있음(m5-03): `Config.Codes`(RequestCooldown 2, MaxFailures 8, FailureWindow 600, MaxLength 20), 리모트 `RedeemCode`(RemoteFunction),
  `Types.RewardGrant`(tokens?/tokenTotal?/eventId?), `RewardReason "Code"`, `RewardLogic.REASON_TEXT.Code = "코드 보상"`(코인 토스트는
  CoinController가 RewardGranted로 자동 표시), `SfxCues "CodeRedeemed"`(클라이언트 `Sfx.play("CodeRedeemed")`), 프로필
  `redeemedCodes`(최근 200개)·`eventTokens`, `Seasons.now(isStudio, Config.DEBUG.eventNow, os.time())`, `Seasons.isActive(id, now)`,
  `Seasons.get(id).token.icon`, init.server/init.client에 CodeService/CodeController 등록 끝.
- CodeLogic 계획: `normalize(raw)`(문자열 아니거나 너무 길면 nil → trim → upper → `^[A-Z0-9]+$`, 3~20자),
  `check(code?, entry?, now, redeemed, failures, failNow?) -> (ok, reason, countsAsFailure)` 순서 Locked → Invalid(+1) → Unknown(+1)
  → NotStarted → Expired(`now >= expiresAt`) → AlreadyRedeemed, `recordFailure(list, now, window)`(오래된 것 지우고 추가, 개수 반환),
  `isLocked(list, now, window, max)`(`now - t < window`인 개수 ≥ max), `rewardFor(entry, now, isActive?)`(기본 Seasons.isActive),
  `message(reason)`, `successMessage(reward)`("🍚 200 받았어요!" / "🍚 100 + 🍬 10 받았어요!"), `validateConfig(codes) -> (valid, problems)`.
- CodeService 계획: 플레이어별 `lastAt`(os.clock, 2초)·`failures`(os.time 목록, PlayerRemoving에서 지움). 코드 시각은 `Seasons.now`(AC10용),
  실패 시각은 실제 os.time. 프로필 nil → NoProfile, `not DataService.canPersist(player) and not RunService:IsStudio()` → NotSaved.
  지급은 `DataService.update` 한 번 안에서 `redeemedCodes[code]` 재확인 후 기록+코인+재화(원자적), 그 뒤 `task.spawn(DataService.saveNow, player)`,
  `RewardGranted` FireClient. 로그: 성공 `[Code] 이름(UserId) redeemed CODE +200`, 잠금 순간 `[Code] 이름(UserId) locked after 8 failures`
  (실패 로그에 코드 문자열 없음). init에서 `validateConfig`로 걸러 warn.
- UI 계획: ShopScreen/ShopController 패턴 그대로(RoomUiKit, 자기 ScreenGui `CodeGui`, `UiScaleController.attach`/`onChanged`).
  버튼 "🎟 코드" 위치 (12, 10 + 2 × (버튼 높이 + 6)) = 기본 y110, **로비·방 대기실에서만**(RoomUpdated 상태가 InMatch가 아니고 매치 서버가 아닐 때).
  창: 제목 "코드 넣기", TextBox(placeholder "코드를 넣어 주세요", 20자 자르기), "받기", 결과 한 줄(성공 Nori/실패 Error), 안내 문구, 보내는 동안 비활성.
- **막힌 점**: 없음.
