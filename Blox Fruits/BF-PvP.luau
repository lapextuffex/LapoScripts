pcall(function()
	local c = getgenv()._LAPO_CLEANUP
	if type(c) == "function" then c() end
end)

local function loadLapo()
	local urls = {
		"https://raw.githubusercontent.com/LapoLapoNaldo/Lapo-X2/refs/heads/main/Library.lua",
		"https://raw.githubusercontent.com/LapoLapoNaldo/Lapo-X2/main/Library.lua",
		"https://raw.githubusercontent.com/LapoLapoNaldo/Lapo-X/main/Library.lua",
	}
	for _, url in ipairs(urls) do
		local ok, res = pcall(function() return game:HttpGet(url) end)
		if not ok or type(res) ~= "string" or #res < 500 then
			local req = request or http_request
			if type(req) == "function" then
				local ok2, response = pcall(req, { Url = url, Method = "GET" })
				if ok2 and type(response) == "table"
					and type(response.Body) == "string"
					and #response.Body > 500
				then
					ok, res = true, response.Body
				end
			end
		end
		if ok and type(res) == "string" and #res > 500 then
			local fn = loadstring(res)
			if fn then
				local ok2, lib = pcall(fn)
				if ok2 and type(lib) == "table" then return lib end
			end
		end
	end
	error("Failed to load Lapo-X from GitHub")
end

local LapoLib = loadLapo()

getgenv().LapoHub = getgenv().LapoHub or {
	Mode = "Cursor", TargetName = "All",
	AimOn = true, SilentAim = true, MouseHook = true,
	CamLock = false, CamSmooth = 0.2, TargetLock = false,
	FOV = 160, ShowFOV = true, FOVColor = "#FF3E5B",
	AimPart = "HumanoidRootPart",
	Predict = 0.12, PingCompensation = true,
	OnlyNoKen = false, WallCheck = false, TeamCheck = true,
	MaxDist = 1800,
	AutoBuso = true, AutoKen = false, AutoRaceV3 = false,
	SpeedOn = false, Speed = 120,
	JumpOn = false, Jump = 140,
	FlyOn = false, FlySpeed = 160,
	NoclipOn = false, InfJumpOn = false,
	PanicY = false, PanicHP = 25, PanicDY = 650,
	ESPOn = true, ESPHP = true, ESPDist = true,
	ESPKen = true, Chams = false,
}
local S = getgenv().LapoHub

local Players = game:GetService("Players")
local RS      = game:GetService("RunService")
local UIS     = game:GetService("UserInputService")
local VIM     = game:GetService("VirtualInputManager")
local Stats   = game:GetService("Stats")
local LP      = Players.LocalPlayer
local Cam     = workspace.CurrentCamera

local CommF_ = nil
pcall(function()
	local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 2)
	if R then CommF_ = R:WaitForChild("CommF_", 2) end
end)
local function CommF(...)
	if CommF_ then return CommF_:InvokeServer(...) end
end

local AimCF, AimPos, CurTarget
local PanicCD, LastBusoCheck, LastKenCheck, LastV3Check = 0, 0, 0, 0
local cachedMousePosition = Vector2.new(0, 0)
local cachedPing = 0
local TARGET_UPDATE_RATE = 1 / 30
local targetAccumulator = 0

local function updateMousePosition()
	cachedMousePosition = UIS:GetMouseLocation()
	return cachedMousePosition
end
local function updatePing()
	if not S.PingCompensation then cachedPing = 0; return 0 end
	local ping = 0
	pcall(function()
		ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
	end)
	cachedPing = math.clamp(ping, 0, 0.4)
	return cachedPing
end

local function myChar() return LP.Character end
local function myHRP()
	local c = myChar(); return c and c:FindFirstChild("HumanoidRootPart")
end
local function myHum()
	local c = myChar(); return c and c:FindFirstChildOfClass("Humanoid")
end
local function alive(char)
	local h = char and char:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0
end
local function hasKen(plr)
	local c = plr and plr.Character
	if not c then return false end
	return c:FindFirstChildOfClass("ForceField") ~= nil
		or c:FindFirstChild("KenHaki") ~= nil
end
local function sameTeam(plr)
	if plr == LP then return true end
	if S.TeamCheck and LP.Team and plr.Team then
		return LP.Team == plr.Team
	end
	return false
end
local function partOf(plr)
	local c = plr and plr.Character
	if not c then return nil end
	local p = c:FindFirstChild(S.AimPart)
	if p and p:IsA("BasePart") then return p end
	p = c:FindFirstChild("HumanoidRootPart")
	if p and p:IsA("BasePart") then return p end
	p = c:FindFirstChild("Head")
	if p and p:IsA("BasePart") then return p end
	return nil
end

local function wallBlocked(targetPart)
	if not S.WallCheck then return false end
	local myRoot = myHRP()
	if not myRoot then return true end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { myChar(), Cam }
	params.IgnoreWater = true
	local origin = Cam.CFrame.Position
	local dir = targetPart.Position - origin
	local result = workspace:Raycast(origin, dir, params)
	if result and result.Instance then
		local m1 = result.Instance:FindFirstAncestorOfClass("Model")
		local m2 = targetPart:FindFirstAncestorOfClass("Model")
		if m1 ~= m2 then return true end
	end
	return false
end

local function validTarget(plr, checkFOV, mousePos, fov)
	if plr == LP then return false end
	local char = plr.Character
	if not alive(char) then return false end
	if S.TeamCheck and sameTeam(plr) then return false end
	if S.OnlyNoKen and hasKen(plr) then return false end
	local part = partOf(plr)
	if not part then return false end
	local myRoot = myHRP()
	if myRoot and (myRoot.Position - part.Position).Magnitude > S.MaxDist then return false end
	if wallBlocked(part) then return false end
	if checkFOV then
		local pos, onScreen = Cam:WorldToViewportPoint(part.Position)
		if not onScreen or pos.Z <= 0 then return false end
		local d = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
		if d > fov then return false end
	end
	return true
end

local function resolveTarget()
	if S.TargetLock and CurTarget and validTarget(CurTarget, false, nil, nil) then
		return CurTarget
	end
	if S.Mode == "Specific" and S.TargetName ~= "All" then
		local p = Players:FindFirstChild(S.TargetName)
		if p and validTarget(p, true, cachedMousePosition, S.FOV) then return p end
		return nil
	end
	local mouse = cachedMousePosition
	local best, bestMetric = nil, math.huge
	local myRoot = myHRP()
	local myPos = myRoot and myRoot.Position
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LP and validTarget(player, S.Mode ~= "Close", mouse, S.FOV) then
			local tp = partOf(player)
			if tp then
				if S.Mode == "LowHP" then
					local h = player.Character:FindFirstChildOfClass("Humanoid")
					local hp = h and h.Health or math.huge
					if hp < bestMetric then bestMetric, best = hp, player end
				elseif S.Mode == "Close" then
					if myPos then
						local d = (myPos - tp.Position).Magnitude
						if d < bestMetric then bestMetric, best = d, player end
					end
				else
					local sp = Cam:WorldToViewportPoint(tp.Position)
					local d = (Vector2.new(sp.X, sp.Y) - mouse).Magnitude
					if d < bestMetric then bestMetric, best = d, player end
				end
			end
		end
	end
	return best
end

local function isIgnoredScript(scr)
	if not scr then return true end
	local n = tostring(scr.Name):lower()
	if n:find("camera") or n:find("control") or n:find("popper")
		or n:find("transparency") or n:find("mouselock")
		or n:find("mouse lock") or n:find("bubble")
		or n:find("player") or n:find("input")
		or n:find("controller") or n:find("character")
		or n:find("humanoid")
	then
		return true
	end
	local p = scr.Parent
	while p and p ~= game do
		local pn = tostring(p.Name):lower()
		if pn == "playerscripts" or pn == "playermodule"
			or pn == "camera" or pn == "coregui"
			or pn:find("camera") or pn:find("control")
		then
			return true
		end
		p = p.Parent
	end
	return false
end

pcall(function()
	local hm = hookmetamethod
	if type(hm) ~= "function" then return end

	local oldNamecall
	oldNamecall = hm(game, "__namecall", newcclosure(function(self, ...)

		if not AimCF or not S.AimOn or not S.SilentAim then
			return oldNamecall(self, ...)
		end

		local method = getnamecallmethod()
		if method ~= "FireServer" and method ~= "InvokeServer" then
			return oldNamecall(self, ...)
		end

		if typeof(self) ~= "Instance" then
			return oldNamecall(self, ...)
		end

		local n = select("#", ...)
		if n ~= 1 then
			return oldNamecall(self, ...)
		end

		local arg = ...
		local t = typeof(arg)
		if t ~= "Vector3" and t ~= "CFrame" then
			return oldNamecall(self, ...)
		end

		local lower = tostring(self.Name):lower()
		local isHit = lower == "remoteevent"
			or lower == "registerhit"
			or lower == "registerattack"
			or lower == "re/registerhit"
			or lower == "re/registerattack"
			or lower:find("registerhit", 1, true) ~= nil
			or lower:find("registerattack", 1, true) ~= nil
			or lower:find("hitbox", 1, true) ~= nil

		if not isHit then
			return oldNamecall(self, ...)
		end

		if t == "Vector3" then
			if not AimPos then
				return oldNamecall(self, ...)
			end
			local x, y, z = AimPos.X, AimPos.Y, AimPos.Z
			if x ~= x or y ~= y or z ~= z then
				return oldNamecall(self, ...)
			end
			return oldNamecall(self, AimPos)

		else
			if not AimCF then
				return oldNamecall(self, ...)
			end
			local p = AimCF.Position
			local _ = p.X + p.Y + p.Z
			return oldNamecall(self, AimCF)
		end
	end))
end)

local localMouse = nil
pcall(function() localMouse = LP:GetMouse() end)

pcall(function()
	if not S.MouseHook then return end
	local mt = getrawmetatable(game)
	if not mt then return end
	local oldIndex = mt.__index
	setreadonly(mt, false)
	mt.__index = newcclosure(function(self, key)
		if self ~= localMouse then return oldIndex(self, key) end
		if key ~= "Hit" and key ~= "Target" then return oldIndex(self, key) end
		if checkcaller() or not S.AimOn or not S.SilentAim
			or not S.MouseHook or not AimCF or not CurTarget
		then
			return oldIndex(self, key)
		end
		local char = CurTarget.Character
		if not char then return oldIndex(self, key) end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then return oldIndex(self, key) end
		local caller = nil
		pcall(function()
			if type(getcallingscript) == "function" then
				caller = getcallingscript()
			end
		end)
		if not caller or isIgnoredScript(caller) then return oldIndex(self, key) end
		if key == "Hit" then return AimCF end
		local tp = partOf(CurTarget)
		if tp then return tp end
		return oldIndex(self, key)
	end)
	setreadonly(mt, true)
end)

local fovCircle, fovGuiCircle
pcall(function()
	if Drawing and type(Drawing.new) == "function" then
		fovCircle = Drawing.new("Circle")
		fovCircle.Thickness = 1.5
		fovCircle.Filled = false
		fovCircle.Transparency = 1
		fovCircle.NumSides = 64
	end
end)
if not fovCircle then
	pcall(function()
		local gui = Instance.new("ScreenGui")
		gui.Name = "LapoFOVGui"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		pcall(function() gui.Parent = game:GetService("CoreGui") end)
		if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
		local circle = Instance.new("Frame")
		circle.Name = "FOVCircle"
		circle.BackgroundTransparency = 1
		circle.Visible = S.ShowFOV
		circle.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 62, 91)
		stroke.Thickness = 1.5
		stroke.Parent = circle
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = circle
		fovGuiCircle = circle
	end)
end

local espCache = {}
local function destroyESPEntry(e)
	if not e then return end
	if e.gui then pcall(function() e.gui:Destroy() end) end
	if e.hl then pcall(function() e.hl:Destroy() end) end
end
local function clearESP()
	for _, item in pairs(espCache) do destroyESPEntry(item) end
	table.clear(espCache)
end
local function makeHighlight(parent, adornee)
	local h = Instance.new("Highlight")
	h.Name = "LapoHL"
	h.FillColor = Color3.fromRGB(255, 62, 91)
	h.OutlineColor = Color3.fromRGB(255, 255, 255)
	h.FillTransparency = 0.5
	h.OutlineTransparency = 0.2
	h.Adornee = adornee
	h.Parent = parent
	return h
end
local function makeBillboard(root)
	local gui = Instance.new("BillboardGui")
	gui.Name = "LapoESP"
	gui.Size = UDim2.fromOffset(130, 36)
	gui.StudsOffset = Vector3.new(0, 2.8, 0)
	gui.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Name = "Tag"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	gui.Parent = root
	return gui, label
end
local function refreshESP()
	if not S.ESPOn then clearESP(); return end
	local root0 = myHRP()
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if player ~= LP and alive(char) then
			local root = char:FindFirstChild("HumanoidRootPart")
			local hum  = char:FindFirstChildOfClass("Humanoid")
			if root and hum then
				local entry = espCache[player]
				if not entry or not entry.gui or entry.gui.Parent ~= root then
					destroyESPEntry(entry)
					local gui, label = makeBillboard(root)
					local hl = S.Chams and makeHighlight(root, char) or nil
					entry = { gui = gui, label = label, hl = hl }
					espCache[player] = entry
				end
				local dist = root0 and math.floor((root0.Position - root.Position).Magnitude) or 0
				local text = player.Name
				if S.ESPHP then text = text .. " [" .. math.floor(hum.Health) .. "hp]" end
				if S.ESPDist then text = text .. " " .. dist .. "m" end
				if S.ESPKen and hasKen(player) then text = text .. " [KEN]" end
				entry.label.Text = text
				entry.label.TextColor3 = hasKen(player)
					and Color3.fromRGB(130, 190, 255)
					or Color3.fromRGB(255, 255, 255)
				if S.Chams then
					if not entry.hl then
						entry.hl = makeHighlight(root, char)
					else
						entry.hl.Adornee = char
					end
				elseif entry.hl then
					pcall(function() entry.hl:Destroy() end)
					entry.hl = nil
				end
			end
		else
			local entry = espCache[player]
			if entry then destroyESPEntry(entry); espCache[player] = nil end
		end
	end
end
Players.PlayerRemoving:Connect(function(player)
	local e = espCache[player]
	if e then destroyESPEntry(e); espCache[player] = nil end
	if CurTarget == player then CurTarget, AimCF, AimPos = nil, nil, nil end
end)

local function updateAim()
	updateMousePosition()
	if not S.AimOn then
		CurTarget, AimCF, AimPos = nil, nil, nil
		return
	end
	local target = resolveTarget()
	CurTarget = target
	AimCF, AimPos = nil, nil
	if not target then return end
	local tp = partOf(target)
	if not tp then return end
	local pos = tp.Position
	local ping = updatePing()
	if S.Predict > 0 then
		local lead = S.Predict + ping
		pcall(function()
			pos = pos + (tp.AssemblyLinearVelocity * lead)
		end)
	end
	AimPos = pos
	local camPos = Cam.CFrame.Position
	local offset = pos - camPos
	if offset.Magnitude <= 0.001 then return end
	AimCF = CFrame.lookAt(pos, pos + offset.Unit)
end

local function updateCameraLock()
	if not S.CamLock or not AimPos or not CurTarget
		or not alive(CurTarget.Character) then return end
	local current = Cam.CFrame
	local target = CFrame.lookAt(current.Position, AimPos)
	Cam.CFrame = current:Lerp(target, math.clamp(S.CamSmooth or 0.2, 0.01, 1))
end

local espTimer = 0
RS.RenderStepped:Connect(function(dt)
	dt = math.min(dt or 0.016, 0.1)

	pcall(function()
		local mouse = updateMousePosition()
		local color = Color3.fromRGB(255, 62, 91)
		if type(S.FOVColor) == "string" and S.FOVColor:sub(1, 1) == "#" then
			color = Color3.fromRGB(
				tonumber(S.FOVColor:sub(2, 3), 16) or 255,
				tonumber(S.FOVColor:sub(4, 5), 16) or 62,
				tonumber(S.FOVColor:sub(6, 7), 16) or 91
			)
		end
		if fovCircle then
			fovCircle.Visible = S.ShowFOV
			if S.ShowFOV then
				fovCircle.Position = mouse
				fovCircle.Radius = S.FOV
				fovCircle.Color = color
			end
		elseif fovGuiCircle then
			fovGuiCircle.Visible = S.ShowFOV
			if S.ShowFOV then
				fovGuiCircle.Position = UDim2.fromOffset(mouse.X - S.FOV, mouse.Y - S.FOV)
				fovGuiCircle.Size = UDim2.fromOffset(S.FOV * 2, S.FOV * 2)
				local stroke = fovGuiCircle:FindFirstChildOfClass("UIStroke")
				if stroke then stroke.Color = color end
			end
		end
	end)

	targetAccumulator += dt
	if targetAccumulator >= TARGET_UPDATE_RATE then
		targetAccumulator = 0
		pcall(updateAim)
	end

	if S.CamLock then pcall(updateCameraLock) end

	espTimer += dt
	if espTimer >= 0.4 then
		espTimer = 0
		pcall(refreshESP)
	end
end)

RS.Heartbeat:Connect(function(dt)
	dt = math.min(dt or 0.016, 0.1)
	pcall(function()
		local char = myChar()
		local hum  = myHum()
		local root = myHRP()
		if not (hum and root and char) then return end

		if S.SpeedOn and hum.WalkSpeed ~= S.Speed then hum.WalkSpeed = S.Speed end

		if S.JumpOn then
			hum.UseJumpPower = true
			if hum.JumpPower ~= S.Jump then hum.JumpPower = S.Jump end
		end

		if S.FlyOn then
			if not hum.PlatformStand then hum.PlatformStand = true end
			hum.AutoRotate = false
			local dir = Vector3.new(0, 0, 0)
			local cf = Cam.CFrame
			if UIS:IsKeyDown(Enum.KeyCode.W) then dir += cf.LookVector end
			if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= cf.LookVector end
			if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= cf.RightVector end
			if UIS:IsKeyDown(Enum.KeyCode.D) then dir += cf.RightVector end
			if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
			if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.new(0, 1, 0) end
			if dir.Magnitude > 0 then
				root.CFrame = root.CFrame + (dir.Unit * S.FlySpeed * dt)
			end
			root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		else
			if hum.PlatformStand then hum.PlatformStand = false end
			if not hum.AutoRotate then hum.AutoRotate = true end
		end

		if S.NoclipOn or S.FlyOn then
			for _, p in ipairs(char:GetChildren()) do
				if p:IsA("BasePart") then p.CanCollide = false end
			end
		end

		if S.PanicY and hum.MaxHealth > 0 and os.clock() > PanicCD then
			local hpPct = (hum.Health / hum.MaxHealth) * 100
			if hpPct <= S.PanicHP then
				PanicCD = os.clock() + 3.5
				root.CFrame = root.CFrame + Vector3.new(0, S.PanicDY, 0)
				root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			end
		end

		local now = os.clock()
		if S.AutoBuso and now - LastBusoCheck > 2 then
			LastBusoCheck = now
			if not char:FindFirstChild("HasBuso") then
				pcall(function() CommF("Buso") end)
			end
		end
		if S.AutoKen and now - LastKenCheck > 3 then
			LastKenCheck = now
			if not hasKen(LP) then
				pcall(function() CommF("Ken", true) end)
			end
		end
		if S.AutoRaceV3 and now - LastV3Check > 1 then
			LastV3Check = now
			if CurTarget and hum.MaxHealth > 0
				and (hum.Health / hum.MaxHealth) * 100 < 60 then
				pcall(function() CommF("ActivateAbility") end)
			end
		end
	end)
end)

local jumpConnection = UIS.JumpRequest:Connect(function()
	if S.InfJumpOn and myHum() then
		pcall(function() myHum():ChangeState(Enum.HumanoidStateType.Jumping) end)
	end
end)

pcall(function()
	LP.Idled:Connect(function()
		pcall(function() game:GetService("VirtualUser"):ClickButton2(Vector2.new()) end)
	end)
end)

local Window = LapoLib:New({ Id = "lapo-pvp", Width = 520, Height = 400 })

local function listPlayerNames()
	local list = { "All" }
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP then list[#list + 1] = p.Name end
	end
	return list
end

local CombatTab = Window:Tab({ id = "combat", name = "Aim & PvP" })
local SkillsTab = Window:Tab({ id = "skills", name = "Buffs" })
local MovTab    = Window:Tab({ id = "mov",    name = "Movement" })
local VisualTab = Window:Tab({ id = "vis",    name = "Visuals & ESP" })
local MiscTab   = Window:Tab({ id = "misc",   name = "Teleports & Utility" })

CombatTab:Section({ id = "sec_aim", text = "Aim Settings", expanded = true })
CombatTab:Toggle({ id = "aim_on", text = "Aimbot Enabled", default = S.AimOn, section = "sec_aim",
	callback = function(v) S.AimOn = v; if not v then CurTarget, AimCF, AimPos = nil, nil, nil end end })
CombatTab:Toggle({ id = "aim_silent", text = "Silent Aim (Redirect Skills)", default = S.SilentAim, section = "sec_aim",
	callback = function(v) S.SilentAim = v; if not v then AimCF, AimPos = nil, nil end end })
CombatTab:Toggle({ id = "aim_hook", text = "Mouse.Hit Safe Hook", default = S.MouseHook, section = "sec_aim",
	callback = function(v) S.MouseHook = v end })
CombatTab:Toggle({ id = "aim_camlock", text = "Camera Lock", default = S.CamLock, section = "sec_aim",
	callback = function(v) S.CamLock = v end })
CombatTab:Slider({ id = "aim_camsmooth", text = "Camera Smoothness", min = 0.05, max = 1, step = 0.05, default = S.CamSmooth, section = "sec_aim",
	callback = function(v) S.CamSmooth = v end })
CombatTab:Toggle({ id = "aim_lock", text = "Target Lock", default = S.TargetLock, section = "sec_aim",
	callback = function(v) S.TargetLock = v end })
CombatTab:Dropdown({ id = "aim_mode", text = "Selection Mode",
	options = { "Cursor", "Close", "LowHP", "Specific" }, default = S.Mode, section = "sec_aim",
	callback = function(value)
		local sel = type(value) == "table" and (value[2] or value[1]) or value
		if sel then S.Mode = sel end
	end })
CombatTab:Dropdown({ id = "aim_part", text = "Body Part",
	options = { "HumanoidRootPart", "Head", "UpperTorso", "LowerTorso" }, default = S.AimPart, section = "sec_aim",
	callback = function(value)
		local sel = type(value) == "table" and (value[2] or value[1]) or value
		if sel then S.AimPart = sel end
	end })
local targetDrop = CombatTab:Dropdown({ id = "aim_target", text = "Specific Target",
	options = listPlayerNames(), default = S.TargetName, section = "sec_aim",
	callback = function(value)
		local sel = type(value) == "table" and (value[2] or value[1]) or value
		if sel then S.TargetName = sel; if sel ~= "All" then S.Mode = "Specific" end end
	end })
CombatTab:Button({ text = "Refresh Player List",
	callback = function()
		pcall(function() targetDrop:SetOptions(listPlayerNames()) end)
		Window:Notify({ title = "Targets", content = "List updated!" })
	end })
CombatTab:TextBox({ id = "aim_target_txt", text = "Type Name Manually",
	placeholder = "Exact player name", section = "sec_aim",
	callback = function(v)
		v = tostring(v or ""):gsub("%s+", "")
		if v == "" then S.TargetName = "All"
		else S.TargetName = v; S.Mode = "Specific" end
	end })

CombatTab:Section({ id = "sec_fov", text = "FOV & Precision", expanded = true })
CombatTab:Slider({ id = "fov_radius", text = "FOV Radius", min = 30, max = 800, step = 5, default = S.FOV, section = "sec_fov",
	callback = function(v) S.FOV = v end })
CombatTab:Toggle({ id = "fov_show", text = "Show FOV Circle", default = S.ShowFOV, section = "sec_fov",
	callback = function(v) S.ShowFOV = v end })
CombatTab:ColorPicker({ id = "fov_color", text = "FOV Circle Color", default = S.FOVColor, section = "sec_fov",
	callback = function(hex) S.FOVColor = hex end })
CombatTab:Slider({ id = "aim_predict", text = "Prediction", min = 0, max = 0.35, step = 0.01, default = S.Predict, section = "sec_fov",
	callback = function(v) S.Predict = v end })
CombatTab:Toggle({ id = "aim_ping_comp", text = "Ping Compensation", default = S.PingCompensation, section = "sec_fov",
	callback = function(v) S.PingCompensation = v end })
CombatTab:Toggle({ id = "aim_noken", text = "Ignore Ken Haki", default = S.OnlyNoKen, section = "sec_fov",
	callback = function(v) S.OnlyNoKen = v end })
CombatTab:Toggle({ id = "aim_wall", text = "WallCheck", default = S.WallCheck, section = "sec_fov",
	callback = function(v) S.WallCheck = v end })
CombatTab:Toggle({ id = "aim_team", text = "Ignore Team", default = S.TeamCheck, section = "sec_fov",
	callback = function(v) S.TeamCheck = v end })
CombatTab:Slider({ id = "aim_maxdist", text = "Max Distance", min = 200, max = 4000, step = 50, default = S.MaxDist, section = "sec_fov",
	callback = function(v) S.MaxDist = v end })

SkillsTab:Section({ id = "sec_buffs", text = "Auto Buffs", expanded = true })
SkillsTab:Toggle({ id = "buff_buso", text = "Auto Buso Haki", default = S.AutoBuso, section = "sec_buffs",
	callback = function(v) S.AutoBuso = v end })
SkillsTab:Toggle({ id = "buff_ken", text = "Auto Ken Haki", default = S.AutoKen, section = "sec_buffs",
	callback = function(v) S.AutoKen = v end })
SkillsTab:Toggle({ id = "buff_race_v3", text = "Auto Race V3 (<60% HP)", default = S.AutoRaceV3, section = "sec_buffs",
	callback = function(v) S.AutoRaceV3 = v end })

MovTab:Section({ id = "sec_speed", text = "Speed & Jump", expanded = true })
MovTab:Toggle({ id = "speed_on", text = "Enable Speed", default = S.SpeedOn, section = "sec_speed",
	callback = function(v) S.SpeedOn = v end })
MovTab:Slider({ id = "speed_val", text = "WalkSpeed", min = 16, max = 500, step = 5, default = S.Speed, section = "sec_speed",
	callback = function(v) S.Speed = v end })
MovTab:Toggle({ id = "jump_on", text = "Super Jump", default = S.JumpOn, section = "sec_speed",
	callback = function(v) S.JumpOn = v end })
MovTab:Slider({ id = "jump_val", text = "JumpPower", min = 50, max = 500, step = 5, default = S.Jump, section = "sec_speed",
	callback = function(v) S.Jump = v end })
MovTab:Toggle({ id = "inf_jump", text = "Infinite Jump", default = S.InfJumpOn, section = "sec_speed",
	callback = function(v) S.InfJumpOn = v end })
MovTab:Section({ id = "sec_fly", text = "Fly & Noclip", expanded = true })
MovTab:Toggle({ id = "fly_on", text = "Fly", default = S.FlyOn, section = "sec_fly",
	callback = function(v) S.FlyOn = v end })
MovTab:Slider({ id = "fly_speed", text = "Fly Speed", min = 20, max = 400, step = 5, default = S.FlySpeed, section = "sec_fly",
	callback = function(v) S.FlySpeed = v end })
MovTab:Keybind({ id = "fly_key", text = "Fly Key", default = "F", section = "sec_fly",
	onPressed = function()
		S.FlyOn = not S.FlyOn
		Window:Notify({ title = "Fly", content = S.FlyOn and "Fly ON" or "Fly OFF", duration = 1.5 })
	end })
MovTab:Toggle({ id = "noclip_on", text = "Noclip", default = S.NoclipOn, section = "sec_fly",
	callback = function(v) S.NoclipOn = v end })
MovTab:Section({ id = "sec_panic", text = "Anti-Death", expanded = false })
MovTab:Toggle({ id = "panic_on", text = "Teleport on Low HP", default = S.PanicY, section = "sec_panic",
	callback = function(v) S.PanicY = v end })
MovTab:Slider({ id = "panic_hp", text = "Min Health (% HP)", min = 5, max = 70, step = 1, default = S.PanicHP, section = "sec_panic",
	callback = function(v) S.PanicHP = v end })
MovTab:Slider({ id = "panic_dy", text = "Escape Height", min = 100, max = 2000, step = 25, default = S.PanicDY, section = "sec_panic",
	callback = function(v) S.PanicDY = v end })

VisualTab:Section({ id = "sec_esp", text = "ESP", expanded = true })
VisualTab:Toggle({ id = "esp_on", text = "Enable ESP", default = S.ESPOn, section = "sec_esp",
	callback = function(v) S.ESPOn = v; if not v then clearESP() end end })
VisualTab:Toggle({ id = "esp_hp", text = "Show HP", default = S.ESPHP, section = "sec_esp",
	callback = function(v) S.ESPHP = v end })
VisualTab:Toggle({ id = "esp_dist", text = "Show Distance", default = S.ESPDist, section = "sec_esp",
	callback = function(v) S.ESPDist = v end })
VisualTab:Toggle({ id = "esp_ken", text = "Show Ken Haki", default = S.ESPKen, section = "sec_esp",
	callback = function(v) S.ESPKen = v end })
VisualTab:Toggle({ id = "esp_chams", text = "Chams / Highlights", default = S.Chams, section = "sec_esp",
	callback = function(v) S.Chams = v; clearESP() end })

MiscTab:Section({ id = "sec_tp", text = "Quick Teleports", expanded = true })
MiscTab:Button({ text = "Teleport Behind Target", variant = "primary",
	callback = function()
		local target = CurTarget or resolveTarget()
		local myRoot = myHRP()
		local targetRoot = target and target.Character
			and target.Character:FindFirstChild("HumanoidRootPart")
		if myRoot and targetRoot then
			myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 4)
			myRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			Window:Notify({ title = "Teleport", content = "Teleported to: " .. target.Name })
		else
			Window:Notify({ title = "Error", content = "No target." })
		end
	end })
MiscTab:Button({ text = "Teleport to Mouse",
	callback = function()
		local myRoot = myHRP()
		if myRoot and Cam then
			local mouse = updateMousePosition()
			local ray = Cam:ViewportPointToRay(mouse.X, mouse.Y)
			myRoot.CFrame = CFrame.new(ray.Origin + ray.Direction * 40)
			myRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			Window:Notify({ title = "Teleport", content = "Teleported." })
		end
	end })
MiscTab:Section({ id = "sec_sys", text = "System", expanded = true })
MiscTab:Keybind({ id = "toggle_key", text = "Menu Key", default = "End", section = "sec_sys",
	onPressed = function() Window:ToggleVisibility() end })
MiscTab:Button({ text = "Rejoin",
	callback = function() game:GetService("TeleportService"):Teleport(game.PlaceId, LP) end })

Window:Init({ Title = "Lapo Hub X - PvP BF", ToggleKey = "End", Width = 520, Height = 400 })
Window:Notify({ title = "Lapo Hub X - PvP BF", content = "Press End to open.", duration = 4 })

getgenv()._LAPO_CLEANUP = function()
	S.AimOn = false; S.CamLock = false; S.FlyOn = false
	CurTarget, AimCF, AimPos = nil, nil, nil
	pcall(function() jumpConnection:Disconnect() end)
	pcall(function() Window:Destroy() end)
	pcall(clearESP)
	if fovCircle then pcall(function() fovCircle:Remove() end); fovCircle = nil end
	if fovGuiCircle then
		pcall(function()
			local p = fovGuiCircle.Parent
			if p then p:Destroy() end
		end)
		fovGuiCircle = nil
	end
end

print("[Lapo Hub X - PvP BF] loaded.")
