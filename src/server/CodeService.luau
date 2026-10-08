--!strict
-- 코드 보상 서비스 (m5-10). m5-03 껍데기: 리모트 핸들러는 "준비 중이에요", 코드 목록은 CodeConfig.load()로 읽기만 해요
-- (목록이 없으면 Studio에서 경고 한 줄). 검증·지급·남용 방지는 m5-10이 채워요.
--   RedeemCode(code)  코드 보상 받기

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CodeConfig = require(script.Parent.CodeConfig)

local CodeService = {}

local codes: { CodeConfig.CodeEntry } = {}

function CodeService.init()
	codes = CodeConfig.load()
	Remotes.fn("RedeemCode").OnServerInvoke = function(): (boolean, string?)
		return false, "준비 중이에요"
	end
end

function CodeService.start() end

-- (m5-10 전까지) 읽은 코드 수 — 디버그용
function CodeService.count(): number
	return #codes
end

return CodeService
