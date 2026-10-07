--!strict
-- 라운드/화면처럼 수명이 있는 것들의 정리 목록.
-- 연결, 인스턴스, 스레드, 함수를 add 해두면 run() 한 번에 역순으로 정리해요.

export type Task = RBXScriptConnection | Instance | thread | () -> ()

local Cleanup = {}
Cleanup.__index = Cleanup

export type Cleanup = typeof(setmetatable({} :: { _tasks: { Task } }, Cleanup))

function Cleanup.new(): Cleanup
	return setmetatable({ _tasks = {} }, Cleanup)
end

function Cleanup.add<T>(self: Cleanup, item: T): T
	table.insert(self._tasks, item :: any)
	return item
end

function Cleanup.run(self: Cleanup)
	local tasks = self._tasks
	self._tasks = {}
	for i = #tasks, 1, -1 do
		local item = tasks[i]
		if typeof(item) == "RBXScriptConnection" then
			item:Disconnect()
		elseif typeof(item) == "Instance" then
			item:Destroy()
		elseif type(item) == "thread" then
			if coroutine.status(item) ~= "dead" and item ~= coroutine.running() then
				task.cancel(item)
			end
		elseif type(item) == "function" then
			item()
		end
	end
end

return Cleanup
