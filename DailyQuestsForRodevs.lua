-- Main Server Player Classes Handler that does all of the Player Related Systems including Daily 

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local PhysicsService = game:GetService("PhysicsService")
local MarketPlaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local ReplicatedModules = ReplicatedStorage:WaitForChild("Modules")
local ReplicatedRemotes = ReplicatedStorage:WaitForChild("Remotes")

local ServerModules = ServerStorage:WaitForChild("Modules")
local Overheads = ServerStorage:WaitForChild("Overheads")

local InstancesHandler = require(ReplicatedModules.Instances)
local CharactersHandler = require(ReplicatedModules.Characters)
local Types = require(ReplicatedModules.Types)
local GameRanks = require(ReplicatedModules.GameRanks)
local GamePasses = require(ReplicatedModules.GamePasses)

local QuestsHandler = require(ServerModules.Quests)
local ProfileService = require(ServerModules:WaitForChild("Imports").ProfileStore)
local WebhooksHandler = require(ServerModules.Imports.WebhooksSufi)

local PlayersCollisionGroup = PhysicsService:RegisterCollisionGroup("Players")
PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)

local LogsWebhook = WebhooksHandler.new("ACBans", "AnticheatLogs")

local PlayersDataStore = ProfileService.New("PlayersStore", require(script.DataTemplate))

local PlayersHandler: Types.PlayerClass = {} do
	PlayersHandler.__index = PlayersHandler
	local Cache = setmetatable({}, {__mode = "k"})

	function PlayersHandler.new(plr: Player)
		if Cache[plr] then
			return Cache[plr]
		else
			local self = setmetatable({}, PlayersHandler)
			self.Player = plr
			self.Data = nil
			self.Threads = {} :: {thread}
			self.Connections = {} :: {RBXScriptConnection}
			self.Sizes = {HRP = Vector3.zero}
			self.IsInGroup = false
			self.Vip = false
			self.ExtraHealth = false
			self.Afk = false
			self.Role = ""
			self.RankId = ""

			local status = self:__init()
			if not status then
				return plr:Kick("Failed to load your data. If this error persists please contact a developer.")

			end
			self:BeginAcLoop()
			Cache[plr] = self
			return self
		end
	end
	---
	function PlayersHandler:__init(): boolean
		self.IsInGroup = self.Player:IsInGroupAsync(game.CreatorId)
		self.RankId = self.Player:GetRankInGroupAsync(game.CreatorId)
		self.Role = self.Player:GetRoleInGroupAsync(game.CreatorId)
		---
		if GameRanks[self.RankId] then
			self.Player:SetAttribute(GameRanks[self.RankId].Text, true)
			self.Player:SetAttribute(self.RankId, true)
		end
		---
		local leaderstats = InstancesHandler:Create("Folder", {
			Name = "leaderstats",
			Parent = self.Player
		})

		local Kills = InstancesHandler:Create("IntValue", {
			Name = "Gems",
			Parent = leaderstats,
			Value = 0
		})

		local profile
			
		for i = 1, 3 do
			profile = PlayersDataStore:StartSessionAsync(tostring(self.Player.UserId), {
				Cancel = function()
					return self.Player.Parent ~= Players
				end,
			})
			if profile then break end
			task.wait(2)
		end
		
		if not profile then
			warn("[-] Failed to get data Profile.")
			return false
		end

		profile:AddUserId(self.Player.UserId)
		profile:Reconcile()

		profile.OnSessionEnd:Connect(function()
			self:Drop()
		end)
		
		if self.Player.Parent ~= Players then
			profile:EndSession()
		end
				
		self.Data = profile
		
		if self.Data.Data.CurrentDay ~= self:GetYearDay() then
			local Quests = {}
			local Indexes = {} do
				while #Indexes < 3 do
					local r = math.random(1, #QuestsHandler)
					if not table.find(Indexes, r) then
						table.insert(Indexes, r)
					end
				end
			end
			---
			for i,v in next, Indexes do
				table.insert(Quests, QuestsHandler[v])
			end
			---
			self.Data.Data.CurrentDay = self:GetYearDay()
			self.Data.Data.DailyQuests = Quests
		end
		
		for i,v in next, self.Data.Data.DailyQuests do
			local QuestData = string.split(v.Id, "_")
			if QuestData[1] == "PLAY" then
				table.insert(self.Threads, task.spawn(function()
					local Target = tonumber(QuestData[2]) * 60
					while task.wait(1) do
						local Cancel = false
						v.Proggress += 1
						if v.Proggress >= Target then
							v.Completed = true
							Cancel = true
						end
						---
						ReplicatedRemotes.GetDailyQuestsSafe:FireClient(self.Player, v)
						if Cancel then
							break
						end
					end
				end))
			end
		end

		Kills.Value = self.Data.Data.Kills
		---
		for i,v in next, GamePasses do
			local OwnsGamePass = MarketPlaceService:UserOwnsGamePassAsync(self.Player.UserId, v.GamePassId)
			if OwnsGamePass or RunService:IsStudio() then
				self[v.GamePassName] = true
			end
		end
		---
		if self.Vip then
			self.Player:SetAttribute("Vip", true)
		end
		---
		if self.Afk then
			table.insert(self.Threads, task.spawn(function()
				while task.wait(300) do
					if math.random() <= 40 / 100 then
						self.Data.Data.Kills += math.random(1, 3)
						self.Player.leaderstats.Gems.Value = self.Data.Data.Kills
					end
				end
			end))
		end
		---
		self.Player:SetAttribute("DataLoaded", true)
		return true
	end
	---
	function PlayersHandler:Drop()
		if self.Data then
			self.Data:EndSession()
			self.Data = nil
		end

		for _, thread in next, self.Threads do
			task.cancel(thread)
		end

		for _, conn in next, self.Connections do
			conn:Disconnect()
		end
	end
	---
	function PlayersHandler:AddQuestGems(Gems: number)
		self.Data.Data.Kills += Gems
		self.Player.leaderstats.Gems.Value = self.Data.Data.Kills
	end
	---
	function PlayersHandler:RemoveKills(Kills: number)
		self.Data.Data.Kills -= Kills
		self.Player.leaderstats.Gems.Value = self.Data.Data.Kills
	end
	---
	function PlayersHandler:AddKills(Kills: number, AddsAsQuest: boolean)
		if self.IsInGroup and math.random() <= 10 / 100 then
			if AddsAsQuest then
				Kills += math.random(1, 2)
			end
		end
		---
		if self.Vip and math.random() <= 50 / 100 then
			Kills += math.random(2, 3)
		end
		---
		self.Data.Data.Kills += Kills
		self.Player.leaderstats.Gems.Value = self.Data.Data.Kills
		if not AddsAsQuest then return end
		for i,v in next, self.Data.Data.DailyQuests do
			local QuestData = string.split(v.Id, "_")
			if QuestData[1] == "KILL" then
				if v.Completed then continue end
				v.Proggress += 1
				if v.Proggress >= v.Goal then
					v.Completed = true
				end
				ReplicatedRemotes.GetDailyQuestsSafe:FireClient(self.Player, v)
			end
		end
	end
	---
	function PlayersHandler:BeginAcLoop()
		local Character = CharactersHandler:IsAlive(self.Player) and CharactersHandler:GetCharacter(self.Player) or self.Player.CharacterAdded:Wait()
		local HRP = Character:FindFirstChild("HumanoidRootPart") or Character:WaitForChild("HumanoidRootPart")
		local Humanoid = Character:WaitForChild("Humanoid")
		if HRP then
			self.Sizes.HRP = HRP.Size
		end
		---
		local Head = Character:WaitForChild("Head")
		
		Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		local OverheadClone = Overheads.Rank:Clone()
		OverheadClone.Frame.Name1.Text = self.Player.DisplayName
		OverheadClone.Frame.Rank.Text = self.Role
		OverheadClone.Parent = Head
		---
		if self.ExtraHealth then
			Humanoid.MaxHealth = 150
			Humanoid.Health = Humanoid.MaxHealth
		end
		---
		for i,v in next, Character:GetDescendants() do
			if v:IsA("BasePart") then
				v.CollisionGroup = "Players"
			end
		end
		---
		Character.DescendantAdded:Connect(function(descendant: BasePart)
			if descendant:IsA("BasePart") then
				descendant.CollisionGroup = "Players"
			end
		end)
		---
		table.insert(self.Connections, self.Player.CharacterAdded:Connect(function(newChar: Model)
			local HRP = newChar:WaitForChild("HumanoidRootPart")
			local Head = newChar:WaitForChild("Head")
			local Humanoid = newChar:WaitForChild("Humanoid")
			
			Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			local OverheadClone = Overheads.Rank:Clone()
			OverheadClone.Frame.Name1.Text = self.Player.DisplayName
			OverheadClone.Frame.Rank.Text = self.Role
			OverheadClone.Parent = Head
			
			if self.ExtraHealth then
				Humanoid.MaxHealth = 150
				Humanoid.Health = Humanoid.MaxHealth
			end

			self.Sizes.HRP = HRP.Size
			for i,v in next, newChar:GetDescendants() do
				if v:IsA("BasePart") then
					v.CollisionGroup = "Players"
				end
			end
			---
			newChar.DescendantAdded:Connect(function(descendant: BasePart)
				if descendant:IsA("BasePart") then
					descendant.CollisionGroup = "Players"
				end
			end)
		end))
	end
	---
	function PlayersHandler:GetYearDay(): number
		return tonumber(os.date("!*t").yday)
	end
	---
	function PlayersHandler:Ban(PublicReason: string, PrivateReason: string, Lenght: number): boolean
		local succ, err = pcall(function()
			return Players:BanAsync({
				UserIds = {self.Player.UserId};
				Duration = Lenght,
				DisplayReason = PublicReason,
				PrivateReason = PrivateReason,
				ExcludeAltAccounts = false,
				ApplyToUniverse = true
			})
		end)
		---
		local message = string.format(
			"**Username**: %s\n" ..
				"**Reason**: `%s`\n" ..
				"**User ID**: `%d`\n" ..
				"**Timestamp**: <t:%d:f>",
			self.Player.Name,
			PrivateReason,
			self.Player.UserId,
			os.time()
		)
		local Title = succ and "🚫 BAN ISSUED BY ANTICHEAT 🚫" or "Failed to ban. Roblox API error."
		LogsWebhook:post("Red", Title, message)
	end
end

return PlayersHandler


-- DailyQuests Data

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ReplicatedModules = ReplicatedStorage:WaitForChild("Modules")
local ServerModules = ServerStorage:WaitForChild("Modules")

local Types = require(ReplicatedModules.Types)

local Quests: {Types.Quest} = {
	{
		Id = "KILL_10",
		Description = "Defeat 10 enemies.",
		Completed = false,
		Claimed = false,
		Goal = 10,
		Proggress = 0,
		Reward = 2.5 * 10
	},
	{
		Id = "KILL_20",
		Description = "Defeat 20 enemies.",
		Completed = false,
		Claimed = false,
		Goal = 20,
		Proggress = 0,
		Reward = 2.5 * 20
	},
	{
		Id = "KILL_30",
		Description = "Defeat 30 enemies.",
		Completed = false,
		Claimed = false,
		Goal = 30,
		Proggress = 0,
		Reward = 2.5 * 30
	},
	{
		Id = "KILL_50",
		Description = "Defeat 50 enemies.",
		Completed = false,
		Claimed = false,
		Goal = 50,
		Proggress = 0,
		Reward = 2.5 * 50
	},
	{
		Id = "PLAY_10",
		Description = "Play for 10 minutes.",
		Completed = false,
		Claimed = false,
		Goal = 10,
		Proggress = 0,
		Reward = 2.5 * 10
	},
	{
		Id = "PLAY_15",
		Description = "Play for 15 minutes.",
		Completed = false,
		Claimed = false,
		Goal = 15,
		Proggress = 0,
		Reward = 2.5 * 15
	},
	{
		Id = "PLAY_30",
		Description = "Play for 30 minutes.",
		Completed = false,
		Claimed = false,
		Goal = 30,
		Proggress = 0,
		Reward = 2.5 * 30
	}
}

return Quests

-- DailyQuests Client Logic

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local ReplicatedModules = ReplicatedStorage:WaitForChild("Modules")
local ReplicatedRemotes = ReplicatedStorage:WaitForChild("Remotes")

local Types = require(ReplicatedModules.Types)
local LocalPlayer = Players.LocalPlayer

repeat
	task.wait()
until LocalPlayer:GetAttribute("DataLoaded")

local DailyQuests: {Types.Quest} = ReplicatedRemotes.GetDailyQuests:InvokeServer()
local DailyList = {}
for i,v in next, script.Parent.Quests:GetChildren() do
	if v:IsA("ImageLabel") then
		table.insert(DailyList, v)
	end
end
---
local function TweenBar(Bar: Frame, Proggress: number, Goal: number)
	local Percent = math.clamp(Proggress / Goal, 0, 1)
	TweenService:Create(Bar, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.fromScale(Percent, 1)}):Play()
end
---
local function CheckClaimedQuest(Bar: Frame, Quest: Types.Quest)
	if Quest.Claimed then
		Bar.Frame.Size = UDim2.fromScale(1, 1)
		Bar.Frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		Bar.Number.Text = "CLAIMED"
	end
end
---
for i,v in next, DailyList do
	v.Name = DailyQuests[i].Id
	v.Title.Text = DailyQuests[i].Description
	local QuestType = string.split(DailyQuests[i].Id, "_")
	if QuestType[1] == "PLAY" then
		v.Bar.Number.Text = `{math.floor(DailyQuests[i].Proggress / 60)}/{DailyQuests[i].Goal}`
		TweenBar(v.Bar.Frame, math.floor(DailyQuests[i].Proggress / 60), DailyQuests[i].Goal)
	else
		v.Bar.Number.Text = `{DailyQuests[i].Proggress}/{DailyQuests[i].Goal}`
		TweenBar(v.Bar.Frame, DailyQuests[i].Proggress, DailyQuests[i].Goal)
	end
	---
	v.Rectangle.Title.Text = `{DailyQuests[i].Reward} Gems`
end
---

---
for i,v in next, DailyQuests do
	local Bar = script.Parent.Quests:FindFirstChild(v.Id).Bar
	if not Bar then continue end
	---
	CheckClaimedQuest(Bar, v)
end
---
for i,v in next, script.Parent.Quests:GetChildren() do
	if v:IsA("ImageLabel") then
		v.Rectangle.Claim.Activated:Connect(function()
			local Response: Types.RemoteFunctionAnswer = ReplicatedRemotes.ClaimDailyQuest:InvokeServer(v.Name)
			if Response.status == 1 then
				v.Bar.Number.Text = "CLAIMED"
				v.Bar.Frame.Size = UDim2.fromScale(1, 1)
				v.Bar.Frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			else
				if RunService:IsStudio() then
					warn(`Could not claim quest: {Response.status}({Response.message})`)
				end
			end
		end)
	end
end
---
ReplicatedRemotes.GetDailyQuestsSafe.OnClientEvent:Connect(function(Quest: Types.Quest)
	local QuestFrame = script.Parent.Quests:FindFirstChild(Quest.Id)
	if QuestFrame then
		local QuestType = string.split(Quest.Id, "_")
		if QuestType[1] == "PLAY" then
			QuestFrame.Bar.Number.Text = `{math.floor(Quest.Proggress / 60)}/{Quest.Goal}`
			TweenBar(QuestFrame.Bar.Frame, math.floor(Quest.Proggress / 60), Quest.Goal)
		else
			QuestFrame.Bar.Number.Text = `{Quest.Proggress}/{Quest.Goal}`
			TweenBar(QuestFrame.Bar.Frame, Quest.Proggress, Quest.Goal)
		end
		---
		CheckClaimedQuest(QuestFrame.Bar, Quest)
	end
end)

script.Parent.X.Activated:Connect(function()
	script.Parent.Parent.Visible = false
end)
