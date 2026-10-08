--!strict
-- 내 프로필 보관 (m4-01). 서버 DataService가 보내는 ProfileUpdated를 받아 최신 ProfileView를 들고 있어요.
--   ProfileStore.get() -> ProfileView?        아직 못 받았으면 nil
--   ProfileStore.changed(fn(view)) -> 연결    받을 때마다 불러요. :Disconnect()로 해제
--   ProfileStore.start(gui)                   init.client.luau가 컨트롤러 중 가장 먼저 불러요 (Sfx보다 먼저)
-- 코인 배지(m4-08), 음소거 복원(m4-07), 상점(m4-13)이 여기서 읽어요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

export type Connection = { Connected: boolean, Disconnect: (self: Connection) -> () }

local ProfileStore = {}

local current: Types.ProfileView? = nil
local listeners: { (view: Types.ProfileView) -> () } = {}
local started = false

function ProfileStore.get(): Types.ProfileView?
	return current
end

function ProfileStore.changed(fn: (view: Types.ProfileView) -> ()): Connection
	table.insert(listeners, fn)
	local connection: Connection
	connection = {
		Connected = true,
		Disconnect = function(self: Connection)
			self.Connected = false
			local index = table.find(listeners, fn)
			if index then
				table.remove(listeners, index)
			end
		end,
	}
	return connection
end

local function onProfileUpdated(view: unknown)
	if type(view) ~= "table" then
		return
	end
	local profile = view :: Types.ProfileView
	current = profile
	for _, fn in table.clone(listeners) do
		task.spawn(fn, profile)
	end
end

function ProfileStore.start(_gui: Instance)
	if started then
		return
	end
	started = true
	Remotes.event("ProfileUpdated").OnClientEvent:Connect(onProfileUpdated)
end

return ProfileStore
