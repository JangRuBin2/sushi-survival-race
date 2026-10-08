--!strict
-- 플레이스 역할과 텔레포트 (GDD 11.2, m4-11).
-- m4-01: 역할 질의만 있어요. Studio이거나 Config.Places id가 비어 있으면 항상 "Single"(한 플레이스 모드 = 지금과 같음).
-- 텔레포트·매니페스트·같은 방 복귀는 m4-11이 이 파일에 채워요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local PlaceRole = require(ReplicatedStorage.Shared.PlaceRole)

local PlaceService = {}

function PlaceService.role(): PlaceRole.Role
	return PlaceRole.resolve(game.PlaceId, Config.Places, RunService:IsStudio())
end

function PlaceService.init() end

function PlaceService.start() end

return PlaceService
