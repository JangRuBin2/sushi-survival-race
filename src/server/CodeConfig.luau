--!strict
-- 코드 보상 목록 로더 (m5-03 틀, m5-10이 씀). 서버 전용 — ServerScriptService 아래라 클라이언트에 복제되지 않아요.
--
-- 저장소가 GitHub 공개라서 **실제 코드 목록은 커밋하지 않아요**. 목록은 이 폴더의 로컬 파일 `CodeList.luau`
-- (src/server/CodeList.luau, .gitignore에 있음)에 두고, Rojo가 ServerScriptService.Server.CodeList로 동기화해요.
-- 처음 만들 때는 `CodeList.example.luau`를 같은 폴더에 `CodeList.luau`로 복사해서 코드를 채워요.
-- 파일이 없으면 빈 목록 + 경고 한 줄 (코드 창은 "없는 코드예요"만 돌려줘요). 퍼블리시하는 PC에 파일이 있어야 해요.
--
--   CodeConfig.load() -> { CodeEntry }            서버 시작 때 한 번 (CodeService.init)
--   CodeConfig.resolve(found, value) -> ({ CodeEntry }, warning?)   순수: 불러온 값 → 목록 (테스트용)
-- 코드 하나하나의 형식·범위 검사(중복, 대문자·숫자, coins 0~300 …)는 m5-10의 CodeLogic.validateConfig가 해요.

-- 코드는 대문자·숫자만 (입력은 대소문자 무시). 시각은 UTC unix 초, nil이면 제한 없음.
export type CodeEntry = {
	code: string,
	coins: number, -- 0~300 정수 (GDD 9.3)
	tokens: number?, -- 이벤트 재화 1~30 (eventId 필수, 그 이벤트가 진행 중일 때만 지급)
	eventId: string?, -- Shared.Seasons 이벤트 id
	startsAt: number?,
	expiresAt: number?,
}

local CodeConfig = {}

CodeConfig.LIST_NAME = "CodeList" -- src/server/CodeList.luau (커밋 안 함)

-- found: CodeList 모듈이 있었는가, value: 그 모듈이 돌려준 값 (require 실패면 nil)
function CodeConfig.resolve(found: boolean, value: unknown): ({ CodeEntry }, string?)
	if not found then
		return {},
			"no src/server/CodeList.luau — redeem codes are off. Copy CodeList.example.luau to CodeList.luau (not committed)"
	end
	if type(value) ~= "table" or type((value :: any).Codes) ~= "table" then
		return {}, "CodeList.luau must return { Codes = { ... } } — redeem codes are off"
	end
	local list: { CodeEntry } = {}
	for _, entry in (value :: any).Codes do
		if type(entry) == "table" then
			table.insert(list, table.clone(entry) :: any)
		end
	end
	return list, nil
end

function CodeConfig.load(): { CodeEntry }
	local module = script.Parent:FindFirstChild(CodeConfig.LIST_NAME)
	local found = module ~= nil and module:IsA("ModuleScript")
	local value: unknown = nil
	if found then
		local ok, result = pcall(require, module :: ModuleScript)
		if ok then
			value = result
		else
			warn(`[CodeConfig] CodeList.luau failed to load: {result}`)
		end
	end
	local list, warning = CodeConfig.resolve(found, value)
	if warning then
		local isStudio = game:GetService("RunService"):IsStudio()
		warn(`[CodeConfig] {warning}{if isStudio then " (Studio)" else ""}`)
	end
	return list
end

return CodeConfig
