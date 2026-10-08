--!strict
-- 코드 보상 목록 예시 (m5-10). 이 파일은 커밋되는 **예시**예요 — 진짜 코드는 넣지 마세요 (저장소가 공개).
-- 쓰는 법: 이 파일을 같은 폴더에 `CodeList.luau`로 복사해서 Codes에 코드를 넣어요.
--   src/server/CodeList.luau 는 .gitignore에 있어서 커밋되지 않고, Rojo가 ServerScriptService.Server.CodeList로 동기화해요.
--   퍼블리시하는 PC에 CodeList.luau가 있어야 실서버에서도 코드가 돼요.
--
-- 형식 (CodeConfig.CodeEntry):
--   code      대문자·숫자 3~20자 (플레이어 입력은 대소문자·앞뒤 공백 무시)
--   coins     0~300 정수
--   tokens    (선택) 이벤트 재화 1~30 — eventId가 있어야 하고, 그 이벤트 기간에만 지급
--   eventId   (선택) "halloween-2026" | "christmas-2026" (Shared.Seasons)
--   startsAt  (선택) 이 시각(UTC unix 초)부터
--   expiresAt (선택) 이 시각(UTC unix 초)부터 만료 — https://www.unixtimestamp.com 등에서 변환
--
-- 예 (진짜 코드로 바꿔서 CodeList.luau에):
--   { code = "EXAMPLE2026", coins = 200, expiresAt = 1798761600 }, -- 2027-01-01 00:00 UTC 만료
--   { code = "EXAMPLESPOOKY", coins = 100, tokens = 10, eventId = "halloween-2026",
--     startsAt = 1792108800, expiresAt = 1793923200 }, -- 할로윈 기간만
return {
	Codes = {},
}
