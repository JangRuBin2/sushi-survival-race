--!strict
-- 클라이언트 부트스트랩. 클라이언트는 입력·UI·연출만 담당하고 판정은 하지 않아요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 서버가 리모트를 만들 때까지 기다려요
require(ReplicatedStorage.Shared.Remotes)

local gui = require(script.ui.LobbyController).start()
require(script.ui.HudController).start(gui)
