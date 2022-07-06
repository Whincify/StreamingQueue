--[[

	$$\      $$\$$\   $$\$$$$$$\$$\   $$\ $$$$$$\ $$$$$$\$$$$$$$$\$$\     $$\ 
	$$ | $\  $$ $$ |  $$ \_$$  _$$$\  $$ $$  __$$\\_$$  _$$  _____\$$\   $$  |
	$$ |$$$\ $$ $$ |  $$ | $$ | $$$$\ $$ $$ /  \__| $$ | $$ |      \$$\ $$  / 
	$$ $$ $$\$$ $$$$$$$$ | $$ | $$ $$\$$ $$ |       $$ | $$$$$\     \$$$$  /  
	$$$$  _$$$$ $$  __$$ | $$ | $$ \$$$$ $$ |       $$ | $$  __|     \$$  /   
	$$$  / \$$$ $$ |  $$ | $$ | $$ |\$$$ $$ |  $$\  $$ | $$ |         $$ |    
	$$  /   \$$ $$ |  $$ $$$$$$\$$ | \$$ \$$$$$$  $$$$$$\$$ |         $$ |    
	\__/     \__\__|  \__\______\__|  \__|\______/\______\__|         \__|                                                                      
       
	StreamingYield waits for an instance to exist on the client before applying changes to it.
	This is necessary when streaming parts as they may not exist when the server wants to make changes.
	
	Created by Whincify with contributions from boatbomber, CloneTrooper1019's WindShake module.
	
	v1.0.0
       
]]-- 

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local StreamingFunction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Server"):WaitForChild("StreamingFunction")

-----------------------------------------------------------------------------------------------------------------

local StreamingYield = {
	Connections = {};
	PlayerYields = {};
	LastUpdate = os.clock();
}

function StreamingYield:Connect(funcName: string, event: RBXScriptSignal): RBXScriptConnection
	local callback = self[funcName]
	assert(typeof(callback) == "function", "Unknown function: " .. funcName)

	return event:Connect(function(...)
		return callback(self, ...)
	end)
end

function StreamingYield:Add(player: Instance, object: Instance, property: String, value)
	local yields = self.PlayerYields[player]["Yields"]
	local entry = nil

	for i, v in yields do
		if (v.Instance == object and v.Property == property) then
			entry = v
			break
		end
	end

	if (entry) then
		entry.Value = value
	else
		table.insert(yields,{
			Instance = object;
			Property = property;
			Value = value;
		})
	end
end

function StreamingYield:Update()
	local now = os.clock()
	local dt = (now - self.LastUpdate)

	if (dt < self.RefreshRate) then
		return
	end

	self.LastUpdate = now

	if self.Updating then
		return
	end

	self.Updating = true

	for i, v in self.PlayerYields do
		if (not v.Character) then
			return
		end

		local charPos = v.Character.PrimaryPart.Position

		if (not charPos) then
			return
		end

		for a, b in pairs(v.Yields) do
			local objPos

			if b.Instance:IsA("BasePart") then
				objPos = b.Instance.Position
			else
				objPos = b.Instance:FindFirstAncestorWhichIsA("BasePart").Position
			end

			if (charPos - objPos).Magnitude < self.Radius then
				local response = StreamingFunction:InvokeClient(v.Player,b.Instance,b.Property,b.Value)

				if (response == "success") then
					table.remove(v.Yields,a)
				end
			end
		end
	end
	
	self.Updating = false
end

function StreamingYield:PlayerAdded(player)
	if self.PlayerYields[player] then
		return
	end

	self.PlayerYields[player] = {
		Player = player;
		Character = player.Character;
		Yields = {};
	}

	player.CharacterAdded:Connect(function(character)
		self.PlayerYields[player].Character = character
	end)
end

function StreamingYield:PlayerRemoving(player)
	if self.PlayerYields[player] then
		self.PlayerYields[player] = nil
	end
end

function StreamingYield:Init(radius: number, refreshRate: number)
	if (not self.Initialized) then
		self.Initialized = true
		self.Radius = radius or 100
		self.RefreshRate = refreshRate or 10

		self.Connections["Update"] = StreamingYield:Connect("Update",RunService.Heartbeat)
		self.Connections["Join"] = StreamingYield:Connect("PlayerAdded",Players.PlayerAdded)
		self.Connections["Leave"] = StreamingYield:Connect("PlayerRemoving",Players.PlayerRemoving)
	end
end

return StreamingYield
