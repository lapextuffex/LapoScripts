local LIBRARY_URL = "https://raw.githubusercontent.com/LapoLapoNaldo/Lapo-X2/refs/heads/main/Library.lua"
local HUB_FOLDER = "LapoFruitHub"
local HUB_VERSION = "1.9.0"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local Backpack = LocalPlayer:WaitForChild("Backpack")
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
assert(Remotes, "[Lapo Fruit Hub] Remotes folder not found.")
local CommF_ = Remotes:WaitForChild("CommF_", 15)
assert(CommF_, "[Lapo Fruit Hub] CommF_ remote not found.")

local Environment = (getgenv and getgenv()) or _G
if Environment.LapoFruitHub and Environment.LapoFruitHub.Destroy then
    pcall(Environment.LapoFruitHub.Destroy)
end
local ScriptArguments = ...
local ExternalConfig = type(ScriptArguments) == "table" and ScriptArguments
    or (type(Environment.LapoFruitConfig) == "table" and Environment.LapoFruitConfig or {})
local ScriptUrl = "https://raw.githubusercontent.com/lapextuffex/LapoScripts/refs/heads/main/Blox%20Fruits/BF-Fruits.luau"
local HasExternalConfig = next(ExternalConfig) ~= nil

local loaded, Library = pcall(function()
    return loadstring(game:HttpGet(LIBRARY_URL))()
end)
assert(loaded and Library, "[Lapo Fruit Hub] Failed to load Lapo X2: " .. tostring(Library))

local Window = Library:New({ Id = "lapo-fruit-hub" })
local Connections = {}
local Runtime = {
    Running = true,
    BusyCollecting = false,
    BusyStoring = false,
    CurrentTween = nil,
    CurrentTarget = nil,
    LastSniperCheck = 0,
    LastRandomBuy = 0,
    LastWebhook = 0,
    NoFruitSince = os.clock(),
    Hopping = false,
    LastHopAttempt = 0,
    HopAttempt = 0,
    HopManual = false,
    ActiveHopId = nil,
    RetryScheduled = false,
    TeamReady = false,
    TeamJoining = false,
    LastTeamAttempt = 0,
    StorageWorkers = 0,
    CharacterGeneration = 0,
    MovementGuard = nil,
    EventBusy = false,
    EventType = nil,
    EventTarget = nil,
    EventTween = nil,
    EventTool = nil,
    EmptyScanCount = 0,
}

local State = {
    AutoCollect = true,
    AutoStore = true,
    EspFruit = false,
    FilterMode = "all",
    SelectedFruits = {},
    MinimumValue = 0,
    Priority = "value",
    Movement = "tween",
    TweenSpeed = 450,
    ScanInterval = 0.2,
    PickupTimeout = 12,
    StoreDelay = 0.35,
    AntiIdle = true,
    AutoSniper = false,
    SniperTargets = {},
    SniperInterval = 15,
    AutoRandomFruit = false,
    AutoServerHop = true,
    HopAfter = 10,
    HopPages = 3,
    HopRetries = 8,
    AutoRaidFactory = false,
    WebhookEnabled = false,
    WebhookUrl = "",
    WebhookStored = true,
    WebhookMinimumValue = 0,
    WebhookMention = "none",
    WebhookUserId = "",
    WebhookIncludeServer = true,
    WebhookInterval = 1.5,
    ProfileName = "default",
}

local function externalValue(config, keys, fallback, expected)
    for _, key in ipairs(keys) do
        local value = config[key]
        if type(value) == expected then return value end
    end
    return fallback
end

local function copyStringArray(value)
    if type(value) ~= "table" then return nil end
    local result = {}
    for _, item in ipairs(value) do
        if type(item) == "string" and item ~= "" then table.insert(result, item) end
    end
    return result
end

local function applyExternalConfig(config)
    if type(config) ~= "table" then return end
    State.AutoCollect = externalValue(config, { "collectFruit", "autoCollect" }, State.AutoCollect, "boolean")
    State.AutoStore = externalValue(config, { "storeFruit", "autoStore" }, State.AutoStore, "boolean")
    State.AutoServerHop = externalValue(config, { "autoServerHop" }, State.AutoServerHop, "boolean")
    State.EspFruit = externalValue(config, { "espFruit" }, State.EspFruit, "boolean")
    local filterMode = externalValue(config, { "filterMode" }, State.FilterMode, "string")
    State.FilterMode = (filterMode == "selected" or filterMode == "all") and filterMode or State.FilterMode
    State.MinimumValue = externalValue(config, { "minimumValue", "minFruitValue" }, State.MinimumValue, "number")
    local priority = externalValue(config, { "priority" }, State.Priority, "string")
    State.Priority = (priority == "nearest" or priority == "value") and priority or State.Priority
    local movement = externalValue(config, { "movement", "movementMethod" }, State.Movement, "string")
    State.Movement = (movement == "instant" or movement == "tween") and movement or State.Movement
    State.TweenSpeed = externalValue(config, { "tweenSpeed" }, State.TweenSpeed, "number")
    State.ScanInterval = externalValue(config, { "scanInterval" }, State.ScanInterval, "number")
    State.PickupTimeout = externalValue(config, { "pickupTimeout" }, State.PickupTimeout, "number")
    State.StoreDelay = externalValue(config, { "storeDelay" }, State.StoreDelay, "number")
    State.AntiIdle = externalValue(config, { "antiIdle" }, State.AntiIdle, "boolean")
    State.AutoSniper = externalValue(config, { "autoSniper" }, State.AutoSniper, "boolean")
    State.SniperInterval = externalValue(config, { "sniperInterval" }, State.SniperInterval, "number")
    State.AutoRandomFruit = externalValue(config, { "autoRandomFruit", "randomFruit" }, State.AutoRandomFruit, "boolean")
    State.HopAfter = externalValue(config, { "hopAfter" }, State.HopAfter, "number")
    State.HopPages = externalValue(config, { "hopPages" }, State.HopPages, "number")
    State.HopRetries = externalValue(config, { "hopRetries" }, State.HopRetries, "number")
    State.AutoRaidFactory = externalValue(config, { "autoRaidFactory", "autoPirateRaid", "autoFactory", "autoPirateRaidFactory" }, State.AutoRaidFactory, "boolean")
    State.WebhookUrl = externalValue(config, { "webhookUrl", "webhookURL", "webhookurl", "webookurl" }, State.WebhookUrl, "string")
    State.WebhookEnabled = externalValue(config, { "webhookEnabled", "sendWebhookOnCollect", "sendWebhookOnStore" }, State.WebhookEnabled, "boolean")
    State.WebhookMinimumValue = externalValue(config, { "webhookMinimumValue" }, State.WebhookMinimumValue, "number")
    local mention = externalValue(config, { "webhookMention" }, State.WebhookMention, "string")
    State.WebhookMention = (mention == "none" or mention == "user" or mention == "everyone") and mention or State.WebhookMention
    State.WebhookUserId = externalValue(config, { "webhookUserId" }, State.WebhookUserId, "string")
    State.WebhookIncludeServer = externalValue(config, { "webhookIncludeServer" }, State.WebhookIncludeServer, "boolean")
    State.WebhookInterval = externalValue(config, { "webhookInterval" }, State.WebhookInterval, "number")
    local selected = copyStringArray(config.selectedFruits)
    if selected then State.SelectedFruits = selected end
    local sniper = copyStringArray(config.sniperTargets)
    if sniper then State.SniperTargets = sniper end
    if type(config.webhookEnabled) == "boolean"
        or type(config.sendWebhookOnCollect) == "boolean"
        or type(config.sendWebhookOnStore) == "boolean" then
        State.WebhookStored = true
    end
end

applyExternalConfig(ExternalConfig)

local function configSnapshot()
    local selected = copyStringArray(State.SelectedFruits) or {}
    local sniper = copyStringArray(State.SniperTargets) or {}
    return {
        collectFruit = State.AutoCollect,
        storeFruit = State.AutoStore,
        autoServerHop = State.AutoServerHop,
        espFruit = State.EspFruit,
        filterMode = State.FilterMode,
        selectedFruits = selected,
        minimumValue = State.MinimumValue,
        priority = State.Priority,
        movement = State.Movement,
        tweenSpeed = State.TweenSpeed,
        scanInterval = State.ScanInterval,
        pickupTimeout = State.PickupTimeout,
        storeDelay = State.StoreDelay,
        antiIdle = State.AntiIdle,
        autoSniper = State.AutoSniper,
        sniperTargets = sniper,
        sniperInterval = State.SniperInterval,
        autoRandomFruit = State.AutoRandomFruit,
        hopAfter = State.HopAfter,
        hopPages = State.HopPages,
        hopRetries = State.HopRetries,
        autoRaidFactory = State.AutoRaidFactory,
        webhookUrl = State.WebhookUrl,
        webhookEnabled = State.WebhookEnabled,
        sendWebhookOnCollect = State.WebhookEnabled,
        sendWebhookOnStore = State.WebhookEnabled,
        webhookMinimumValue = State.WebhookMinimumValue,
        webhookMention = State.WebhookMention,
        webhookUserId = State.WebhookUserId,
        webhookIncludeServer = State.WebhookIncludeServer,
        webhookInterval = State.WebhookInterval,
    }
end

local function luaArray(value)
    local output = { "{" }
    for _, item in ipairs(value or {}) do
        table.insert(output, string.format("%q", tostring(item)) .. ",")
    end
    table.insert(output, "}")
    return table.concat(output, " ")
end

local function buildConfigLoader()
    local config = configSnapshot()
    local lines = { "local LapoFruitConfig = {" }
    local order = {
        "collectFruit", "storeFruit", "autoServerHop", "espFruit", "filterMode", "selectedFruits",
        "minimumValue", "priority", "movement", "tweenSpeed", "scanInterval", "pickupTimeout",
        "storeDelay", "antiIdle", "autoSniper", "sniperTargets", "sniperInterval", "autoRandomFruit", "hopAfter",
        "hopPages", "hopRetries", "autoRaidFactory", "webhookUrl", "webhookEnabled", "sendWebhookOnCollect",
        "sendWebhookOnStore", "webhookMinimumValue", "webhookMention", "webhookUserId",
        "webhookIncludeServer", "webhookInterval",
    }
    for _, key in ipairs(order) do
        local value = config[key]
        local encoded
        if type(value) == "table" then
            encoded = luaArray(value)
        elseif type(value) == "string" then
            encoded = string.format("%q", value)
        elseif type(value) == "boolean" then
            encoded = tostring(value)
        else
            encoded = tostring(tonumber(value) or 0)
        end
        table.insert(lines, "    " .. key .. " = " .. encoded .. ",")
    end
    table.insert(lines, "}")
    table.insert(lines, "local LapoFruitEnvironment = (getgenv and getgenv()) or _G")
    table.insert(lines, "LapoFruitEnvironment.LapoFruitConfig = LapoFruitConfig")
    table.insert(lines, "loadstring(game:HttpGet(" .. string.format("%q", ScriptUrl) .. "))(LapoFruitConfig)")
    return table.concat(lines, "\n")
end

local Catalog = {}
local CatalogByAlias = {}
local TrackedWorldFruits = setmetatable({}, { __mode = "k" })
local PendingWorldFruits = setmetatable({}, { __mode = "k" })
local PickupNotified = setmetatable({}, { __mode = "k" })
local AcquiredByUs = setmetatable({}, { __mode = "k" })
local StoreStatus = setmetatable({}, { __mode = "k" })
local EspObjects = setmetatable({}, { __mode = "k" })
local FailedUntil = setmetatable({}, { __mode = "k" })
local FailureCount = setmetatable({}, { __mode = "k" })
local IgnoredWorldFruits = setmetatable({}, { __mode = "k" })
local WebhookQueue = {}
local VisitedServers = type(Environment.LapoFruitVisitedServers) == "table"
    and Environment.LapoFruitVisitedServers or {}
Environment.LapoFruitVisitedServers = VisitedServers
local Controls = {}
local syncStateFromControls
local safeCollectFruit
local serverHop
local pivotCharacterTo
local stopEventAutomation

local function entropySeed()
    local source = table.concat({
        HttpService:GenerateGUID(false),
        tostring(LocalPlayer.UserId),
        tostring(game.JobId),
        tostring(os.clock()),
        tostring(DateTime.now().UnixTimestampMillis),
    }, ":")
    local hash = 5381
    for index = 1, #source do
        hash = (hash * 33 + source:byte(index)) % 2147483647
    end
    return math.max(1, hash)
end

local HopRandom = Random.new(entropySeed())

local FALLBACK_FRUITS = {
    "Rocket-Rocket", "Spin-Spin", "Blade-Blade", "Spring-Spring", "Bomb-Bomb", "Smoke-Smoke",
    "Spike-Spike", "Flame-Flame", "Ice-Ice", "Sand-Sand", "Dark-Dark", "Eagle-Eagle",
    "Diamond-Diamond", "Light-Light", "Rubber-Rubber", "Ghost-Ghost", "Magma-Magma",
    "Quake-Quake", "Buddha-Buddha", "Love-Love", "Creation-Creation", "Spider-Spider",
    "Sound-Sound", "Phoenix-Phoenix", "Portal-Portal", "Rumble-Rumble", "Pain-Pain",
    "Blizzard-Blizzard", "Gravity-Gravity", "Mammoth-Mammoth", "T-Rex-T-Rex",
    "Dough-Dough", "Shadow-Shadow", "Venom-Venom", "Control-Control", "Gas-Gas",
    "Spirit-Spirit", "Leopard-Leopard", "Tiger-Tiger", "Yeti-Yeti", "Magnet-Magnet",
    "Kitsune-Kitsune", "Dragon-Dragon"
}

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(Connections, connection)
    return connection
end

local function invoke(...)
    local args = table.pack(...)
    local ok, result = pcall(function()
        return CommF_:InvokeServer(table.unpack(args, 1, args.n))
    end)
    return ok, result
end

local function comma(number)
    local value = tostring(math.floor(tonumber(number) or 0))
    while true do
        local changed
        value, changed = value:gsub("^(-?%d+)(%d%d%d)", "%1.%2")
        if changed == 0 then break end
    end
    return value
end

local function normalize(text)
    return tostring(text or ""):lower():gsub("fruit", ""):gsub("[^%w]", "")
end

local function prettyFruitName(storageName)
    local name = tostring(storageName or "Fruit")
    name = name:gsub(" Fruit$", "")
    if #name % 2 == 1 then
        local middle = (#name + 1) / 2
        local first, second = name:sub(1, middle - 1), name:sub(middle + 1)
        if name:sub(middle, middle) == "-" and normalize(first) == normalize(second) then
            name = first
        end
    end
    return name .. " Fruit"
end

local function fruitStorageName(tool)
    if not tool then return nil end
    local attribute = tool:GetAttribute("OriginalName") or tool:GetAttribute("FruitName")
    if attribute then return attribute end
    local entry = CatalogByAlias[normalize(tool.Name)]
    return entry and entry.Name or tool.Name
end

local function isFruit(instance)
    if not instance or not instance:IsA("Tool") then return false end
    local name = instance.Name:lower()
    return instance:GetAttribute("OriginalName") ~= nil
        or instance:GetAttribute("FruitName") ~= nil
        or name:find("fruit", 1, true) ~= nil
        or name == "unknown"
end

local function fruitHandle(tool)
    if not tool then return nil end
    return tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart")
end

local function catalogEntry(name)
    return CatalogByAlias[normalize(name)]
end

local function fruitValue(name)
    local entry = catalogEntry(name)
    return entry and entry.Price or 0
end

local function selectedContains(list, name)
    local wanted = normalize(name)
    for _, selected in ipairs(list) do
        if normalize(selected) == wanted then return true end
        local entry = catalogEntry(selected)
        if entry and normalize(entry.DisplayName) == wanted then return true end
    end
    return false
end

local function characterRoot()
    local character = LocalPlayer.Character
    if not character then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or humanoid.Health <= 0 or not root then return nil end
    return root, humanoid
end

local function isMarineTeam()
    local team = LocalPlayer.Team
    return team ~= nil and team.Name:lower():find("marine", 1, true) ~= nil
end

local function findMarineButton()
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return nil end
    for _, object in ipairs(playerGui:GetDescendants()) do
        if object:IsA("GuiButton") then
            local label = object:IsA("TextButton") and object.Text or ""
            local route = (object:GetFullName() .. " " .. object.Name .. " " .. label):lower()
            if route:find("marine", 1, true) then return object end
        end
    end
end

local function activateMarineButton()
    local button = findMarineButton()
    if not button then return false end
    if type(firesignal) == "function" then
        local ok = pcall(firesignal, button.Activated)
        if ok then return true end
    end
    if type(getconnections) == "function" then
        local ok = pcall(function()
            for _, connection in ipairs(getconnections(button.Activated)) do
                if type(connection.Function) == "function" then connection.Function() end
            end
        end)
        if ok then return true end
    end
    return pcall(function() button:Activate() end)
end

local function ensureMarineTeam()
    if isMarineTeam() then
        Runtime.TeamReady = true
        Runtime.TeamJoining = false
        return true
    end
    Runtime.TeamReady = false
    Runtime.NoFruitSince = os.clock()
    if Runtime.TeamJoining or os.clock() - Runtime.LastTeamAttempt < 0.8 then return false end
    Runtime.TeamJoining = true
    Runtime.LastTeamAttempt = os.clock()
    invoke("SetTeam", "Marines")
    if not isMarineTeam() then activateMarineButton() end
    task.wait(0.25)
    Runtime.TeamJoining = false
    if isMarineTeam() then
        Runtime.TeamReady = true
        Runtime.NoFruitSince = os.clock()
        return true
    end
    return false
end

local function isOwned(tool)
    local character = LocalPlayer.Character
    return tool and (tool.Parent == Backpack or (character and tool.Parent == character))
end

local function worldContains(tool)
    return isFruit(tool) and tool.Parent == Workspace
end

local function fruitIdentityKnown(tool)
    local attribute = tool and (tool:GetAttribute("OriginalName") or tool:GetAttribute("FruitName"))
    if attribute and tostring(attribute):lower() ~= "unknown" then return true end
    local rawName = tostring(fruitStorageName(tool) or ""):lower()
    local toolName = tostring(tool and tool.Name or ""):lower()
    if rawName == "unknown" or toolName == "unknown" then return false end
    return catalogEntry(rawName) ~= nil
end

local function fruitAllowed(tool)
    if State.AutoServerHop then return true end
    if not fruitIdentityKnown(tool) then return true end
    local storageName = fruitStorageName(tool)
    local value = fruitValue(storageName)
    if value < State.MinimumValue then return false end
    if State.FilterMode == "selected" and not selectedContains(State.SelectedFruits, storageName) then
        return false
    end
    return true
end

local function colorForValue(value)
    if value >= 5000000 then return Color3.fromRGB(255, 85, 127) end
    if value >= 2000000 then return Color3.fromRGB(190, 110, 255) end
    if value >= 1000000 then return Color3.fromRGB(255, 190, 70) end
    return Color3.fromRGB(95, 215, 155)
end

local function removeEsp(tool)
    local gui = EspObjects[tool]
    if gui then pcall(function() gui:Destroy() end) end
    EspObjects[tool] = nil
end

local function addEsp(tool)
    if not State.EspFruit or not worldContains(tool) or EspObjects[tool] then return end
    local handle = fruitHandle(tool)
    if not handle then return end

    local value = fruitValue(fruitStorageName(tool))
    local gui = Instance.new("BillboardGui")
    gui.Name = "LapoFruitESP"
    gui.AlwaysOnTop = true
    gui.Size = UDim2.fromOffset(180, 42)
    gui.StudsOffset = Vector3.new(0, 2.7, 0)
    gui.MaxDistance = 5000
    gui.Adornee = handle
    gui.Parent = handle

    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Size = UDim2.fromScale(1, 1)
    text.Font = Enum.Font.GothamBold
    text.TextSize = 13
    text.TextStrokeTransparency = 0.25
    text.TextColor3 = colorForValue(value)
    text.Text = string.format("%s\n$%s", prettyFruitName(fruitStorageName(tool)), comma(value))
    text.Parent = gui
    EspObjects[tool] = gui
end

local function refreshAllEsp()
    for tool in pairs(EspObjects) do removeEsp(tool) end
    if not State.EspFruit then return end
    for tool in pairs(TrackedWorldFruits) do addEsp(tool) end
end

local function registerWorldFruit(tool)
    if not worldContains(tool) or TrackedWorldFruits[tool] then return end
    if not fruitHandle(tool) then
        if PendingWorldFruits[tool] then return end
        PendingWorldFruits[tool] = true
        task.spawn(function()
            local deadline = os.clock() + 3
            repeat
                task.wait(0.05)
            until not Runtime.Running or not worldContains(tool) or fruitHandle(tool) or os.clock() >= deadline
            PendingWorldFruits[tool] = nil
            if Runtime.Running and worldContains(tool) and fruitHandle(tool) then
                registerWorldFruit(tool)
            end
        end)
        return
    end
    TrackedWorldFruits[tool] = true
    addEsp(tool)
    local allowed = fruitAllowed(tool)
    if allowed then
        Runtime.NoFruitSince = os.clock()
    end
    if Runtime.TeamReady and not Runtime.EventBusy and (State.AutoCollect or State.AutoServerHop) and allowed
        and not Runtime.BusyCollecting and safeCollectFruit then
        task.spawn(safeCollectFruit, tool)
    end
end

local function scanEntireWorld()
    for _, instance in ipairs(Workspace:GetChildren()) do
        if isFruit(instance) then registerWorldFruit(instance) end
    end
end

local function unregisterWorldFruit(tool)
    removeEsp(tool)
    TrackedWorldFruits[tool] = nil
    PendingWorldFruits[tool] = nil
    IgnoredWorldFruits[tool] = nil
    FailedUntil[tool] = nil
    FailureCount[tool] = nil
end

local function refreshCatalog()
    local ok, result = invoke("GetFruits")
    if not ok or type(result) ~= "table" then
        return false, tostring(result)
    end

    local nextCatalog = {}
    for _, raw in pairs(result) do
        if type(raw) == "table" then
            local storageName = raw.Name or raw.name or raw.StorageName
            if storageName then
                local entry = {
                    Name = tostring(storageName),
                    DisplayName = prettyFruitName(storageName),
                    Price = tonumber(raw.Price or raw.price or raw.Cost) or 0,
                    OnSale = raw.OnSale == true or raw.InStock == true,
                }
                table.insert(nextCatalog, entry)
            end
        end
    end
    if #nextCatalog == 0 then return false, "empty catalog" end

    table.sort(nextCatalog, function(a, b)
        if a.Price == b.Price then return a.DisplayName < b.DisplayName end
        return a.Price > b.Price
    end)
    Catalog = nextCatalog
    table.clear(CatalogByAlias)
    local options = {}
    local stock = 0
    for _, entry in ipairs(Catalog) do
        CatalogByAlias[normalize(entry.Name)] = entry
        CatalogByAlias[normalize(entry.DisplayName)] = entry
        CatalogByAlias[normalize(prettyFruitName(entry.Name))] = entry
        if entry.OnSale then stock = stock + 1 end
        table.insert(options, {
            value = entry.Name,
            label = string.format("%s - $%s%s", entry.DisplayName, comma(entry.Price), entry.OnSale and " [STOCK]" or ""),
        })
    end
    if Controls.SelectedFruits then Controls.SelectedFruits:SetOptions(options, { silent = true }) end
    if Controls.SniperTargets then Controls.SniperTargets:SetOptions(options, { silent = true }) end
    if Controls.SelectedFruits then State.SelectedFruits = Controls.SelectedFruits:Get() end
    if Controls.SniperTargets then State.SniperTargets = Controls.SniperTargets:Get() end
    refreshAllEsp()
    return true
end

for _, name in ipairs(FALLBACK_FRUITS) do
    local entry = { Name = name, DisplayName = prettyFruitName(name), Price = 0, OnSale = false }
    table.insert(Catalog, entry)
    CatalogByAlias[normalize(name)] = entry
    CatalogByAlias[normalize(entry.DisplayName)] = entry
end

local function fallbackOptions()
    local options = {}
    for _, entry in ipairs(Catalog) do
        table.insert(options, { value = entry.Name, label = entry.DisplayName })
    end
    return options
end

local function requestFunction()
    if type(request) == "function" then return request end
    if type(http_request) == "function" then return http_request end
    if type(syn) == "table" and type(syn.request) == "function" then return syn.request end
    if type(http) == "table" and type(http.request) == "function" then return http.request end
    if type(fluxus) == "table" and type(fluxus.request) == "function" then return fluxus.request end
end

local function validWebhook(url)
    if type(url) ~= "string" then return false end
    return url:match("^https://discord%.com/api/webhooks/%d+/.+")
        or url:match("^https://canary%.discord%.com/api/webhooks/%d+/.+")
        or url:match("^https://ptb%.discord%.com/api/webhooks/%d+/.+")
        or url:match("^https://discordapp%.com/api/webhooks/%d+/.+")
end

local function seaName()
    local map = {
        [2753915549] = "First Sea", [85211729168715] = "First Sea",
        [4442272183] = "Second Sea", [79091703265657] = "Second Sea",
        [7449423635] = "Third Sea", [100117331123089] = "Third Sea",
    }
    return map[game.PlaceId] or ("Place " .. tostring(game.PlaceId))
end

local function queueWebhook(eventName, fruitName, value, detail, force)
    if not force then
        if eventName ~= "Stored" or not State.WebhookEnabled or not State.WebhookStored then return end
        if value < State.WebhookMinimumValue then return end
    end
    table.insert(WebhookQueue, {
        Event = eventName,
        Fruit = fruitName,
        Value = value,
        Detail = detail or "-",
        Force = force == true,
    })
end

local function sendWebhook(entry)
    local url = State.WebhookUrl:gsub("%s+", "")
    if not validWebhook(url) then return false, "Invalid Discord webhook URL" end
    local send = requestFunction()
    if not send then return false, "executor missing request function" end

    local mention = ""
    local allowedMentions = { parse = {} }
    if State.WebhookMention == "everyone" then
        mention = "@everyone"
        allowedMentions.parse = { "everyone" }
    elseif State.WebhookMention == "user" then
        local id = State.WebhookUserId:match("%d+")
        if id then
            mention = "<@" .. id .. ">"
            allowedMentions.users = { id }
        end
    end

    local fields = {
        { name = "Fruit", value = prettyFruitName(entry.Fruit), inline = true },
        { name = "Value", value = "$" .. comma(entry.Value), inline = true },
        { name = "Event", value = entry.Event, inline = true },
        { name = "Player", value = LocalPlayer.Name .. " (" .. LocalPlayer.DisplayName .. ")", inline = true },
        { name = "Sea", value = seaName(), inline = true },
        { name = "Detail", value = tostring(entry.Detail):sub(1, 900), inline = false },
    }
    if State.WebhookIncludeServer then
        table.insert(fields, { name = "Server", value = "`" .. tostring(game.JobId) .. "`", inline = false })
    end

    local body = HttpService:JSONEncode({
        username = "Lapo Fruit Hub",
        content = mention,
        allowed_mentions = allowedMentions,
        embeds = {{
            title = "Fruit " .. entry.Event,
            color = entry.Event == "Stored" and 5763719 or (entry.Event == "Purchased" and 16763904 or 8317335),
            fields = fields,
            footer = { text = "Lapo Fruit Hub v" .. HUB_VERSION },
            timestamp = DateTime.now():ToIsoDate(),
        }},
    })

    local ok, response = pcall(send, {
        Url = url,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = body,
    })
    if not ok then return false, tostring(response) end
    local code = tonumber(response and (response.StatusCode or response.Status or response.status_code)) or 0
    if code >= 200 and code < 300 then return true end
    return false, "HTTP " .. tostring(code)
end

local function shouldAutoStore()
    return State.AutoStore or State.AutoServerHop
end

local function storeFruitInner(tool, forceRetry)
    if not Runtime.Running or not isFruit(tool) or not isOwned(tool) then return false end
    local previous = StoreStatus[tool]
    if previous == "stored" then return true end
    if previous == "failed" and not forceRetry then return false end
    if previous == "working" then
        repeat task.wait(0.05) until not Runtime.Running or StoreStatus[tool] ~= "working"
        return StoreStatus[tool] == "stored"
    end

    StoreStatus[tool] = "pending"
    local waitGuard = os.clock() + 10
    while Runtime.BusyStoring and Runtime.Running and os.clock() < waitGuard do task.wait(0.1) end
    if not Runtime.Running or not isOwned(tool) then return false end
    Runtime.BusyStoring = true
    Runtime.StorageWorkers = Runtime.StorageWorkers + 1
    StoreStatus[tool] = "working"
    task.wait(State.StoreDelay)
    if not Runtime.Running or not isOwned(tool) then
        StoreStatus[tool] = AcquiredByUs[tool] and "stored" or "failed"
        Runtime.StorageWorkers = math.max(0, Runtime.StorageWorkers - 1)
        Runtime.BusyStoring = false
        return StoreStatus[tool] == "stored"
    end

    local identityDeadline = os.clock() + 2
    local storageName = fruitStorageName(tool)
    while isOwned(tool) and not fruitIdentityKnown(tool) and os.clock() < identityDeadline do
        task.wait(0.05)
        storageName = fruitStorageName(tool)
    end
    local ok = invoke("StoreFruit", storageName, tool)
    local waitUntil = os.clock() + 3
    while ok and isOwned(tool) and os.clock() < waitUntil do task.wait(0.1) end
    local stored = ok and tool.Parent == nil
    StoreStatus[tool] = stored and "stored" or "failed"
    Runtime.StorageWorkers = math.max(0, Runtime.StorageWorkers - 1)
    Runtime.BusyStoring = false
    if stored then
        queueWebhook("Stored", storageName, fruitValue(storageName), "Stored automatically")
        return true
    end
    return false
end

local function storeFruit(tool, forceRetry)
    local ok, result = pcall(storeFruitInner, tool, forceRetry)
    if not ok then
        warn("[Lapo Fruit Hub] storeFruit error: " .. tostring(result))
        Runtime.StorageWorkers = math.max(0, (Runtime.StorageWorkers or 1) - 1)
        Runtime.BusyStoring = false
        if StoreStatus[tool] == "working" then StoreStatus[tool] = "failed" end
        return false
    end
    return result
end

local function onOwnedFruit(tool)
    if not isFruit(tool) or PickupNotified[tool] then
        if shouldAutoStore() and isFruit(tool) then task.spawn(storeFruit, tool) end
        return
    end
    PickupNotified[tool] = true
    AcquiredByUs[tool] = true
    if StoreStatus[tool] == nil then StoreStatus[tool] = "pending" end
    if shouldAutoStore() then task.spawn(storeFruit, tool) end
end

local function chooseFruit()
    scanEntireWorld()
    local root = characterRoot()
    if not root then return nil end
    local candidates = {}
    local now = os.clock()
    for tool in pairs(TrackedWorldFruits) do
        local handle = fruitHandle(tool)
        if worldContains(tool) and handle and fruitAllowed(tool) and not IgnoredWorldFruits[tool]
            and (not FailedUntil[tool] or FailedUntil[tool] <= now) then
            table.insert(candidates, {
                Tool = tool,
                Distance = (root.Position - handle.Position).Magnitude,
                Value = fruitValue(fruitStorageName(tool)),
            })
        end
    end
    table.sort(candidates, function(a, b)
        if State.Priority == "nearest" then return a.Distance < b.Distance end
        if a.Value == b.Value then return a.Distance < b.Distance end
        return a.Value > b.Value
    end)
    return candidates[1] and candidates[1].Tool or nil
end

local function hasWorldFruitToProcess()
    local now = os.clock()
    for tool in pairs(TrackedWorldFruits) do
        if worldContains(tool) and fruitAllowed(tool) and not IgnoredWorldFruits[tool]
            and (not FailedUntil[tool] or FailedUntil[tool] <= now) then
            return true
        end
    end
    for tool in pairs(PendingWorldFruits) do
        if worldContains(tool) then return true end
    end
    return false
end

local function hasPendingStorage()
    if Runtime.BusyStoring or Runtime.StorageWorkers > 0 then return true end
    if not shouldAutoStore() then return false end
    for _, container in ipairs({ Backpack, LocalPlayer.Character }) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if isFruit(item) then
                    local status = StoreStatus[item]
                    if status == nil or status == "pending" or status == "working" then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function touchFruit(tool, root, handle)
    local touch = firetouchinterest
    if touch then
        pcall(touch, root, handle, 0)
        task.wait()
        pcall(touch, root, handle, 1)
    end
end

local function disableCharacterCollision(character)
    local previous = {}
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            previous[part] = part.CanCollide
            part.CanCollide = false
        end
    end
    return previous
end

local function restoreCharacterCollision(previous)
    for part, canCollide in pairs(previous) do
        if part.Parent then part.CanCollide = canCollide end
    end
end

local function stopMovementGuard()
    local guard = Runtime.MovementGuard
    Runtime.MovementGuard = nil
    if guard then
        if guard.DriverConnection then pcall(function() guard.DriverConnection:Disconnect() end) end
        if guard.Driver then pcall(function() guard.Driver:Destroy() end) end
        if guard.Connection then pcall(function() guard.Connection:Disconnect() end) end
        if guard.Velocity then pcall(function() guard.Velocity:Destroy() end) end
        if guard.Collision then restoreCharacterCollision(guard.Collision) end
    end
end

local function startMovementGuard(character, root, humanoid)
    stopMovementGuard()
    local collision = disableCharacterCollision(character)
    local velocity = Instance.new("BodyVelocity")
    velocity.Name = "LapoFruitMovement"
    velocity.MaxForce = Vector3.new(100000, 100000, 100000)
    velocity.P = 10000
    velocity.Velocity = Vector3.zero
    velocity.Parent = root

    local guard
    local connection = RunService.Stepped:Connect(function()
        if not Runtime.Running or LocalPlayer.Character ~= character or humanoid.Parent ~= character
            or root.Parent ~= character or humanoid.Health <= 0 then return end
        humanoid.Sit = false
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                if collision[part] == nil then collision[part] = part.CanCollide end
                part.CanCollide = false
            end
        end
        root.AssemblyAngularVelocity = Vector3.zero
        if guard and guard.HoldPosition then
            pivotCharacterTo(character, guard.HoldPosition)
        end
    end)
    guard = {
        Character = character,
        Humanoid = humanoid,
        Collision = collision,
        Velocity = velocity,
        Connection = connection,
    }
    Runtime.MovementGuard = guard
    return guard
end

local function movementEnabled(manual)
    return Runtime.Running and (State.AutoCollect or State.AutoServerHop or manual)
end

local function movementCharacterValid(character, humanoid, generation)
    return LocalPlayer.Character == character
        and Runtime.CharacterGeneration == generation
        and humanoid.Parent == character
        and humanoid.Health > 0
end

pivotCharacterTo = function(character, position)
    local currentPivot = character:GetPivot()
    character:PivotTo(CFrame.new(position) * (currentPivot - currentPivot.Position))
end

local function tweenSegment(root, humanoid, character, generation, tool, position, manual)
    if not movementEnabled(manual) or not movementCharacterValid(character, humanoid, generation)
        or not worldContains(tool) then return false, "interrupted" end
    local distance = (root.Position - position).Magnitude
    if distance <= 4 then
        pivotCharacterTo(character, position)
        return true
    end

    local duration = math.max(0.05, distance / math.max(State.TweenSpeed, 1))
    local driver = Instance.new("CFrameValue")
    driver.Name = "LapoFruitTweenDriver"
    local currentPivot = character:GetPivot()
    local orientation = currentPivot - currentPivot.Position
    driver.Value = currentPivot
    local tween = TweenService:Create(
        driver,
        TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
        { Value = CFrame.new(position) * orientation }
    )
    local guard = Runtime.MovementGuard
    local driverConnection = RunService.Heartbeat:Connect(function()
        if movementEnabled(manual) and movementCharacterValid(character, humanoid, generation)
            and worldContains(tool) then
            character:PivotTo(driver.Value)
        end
    end)
    if guard then
        guard.Driver = driver
        guard.DriverConnection = driverConnection
    end
    Runtime.CurrentTween = tween
    tween:Play()
    local deadline = os.clock() + duration + 2
    while movementEnabled(manual) and movementCharacterValid(character, humanoid, generation)
        and worldContains(tool) and os.clock() < deadline do
        if (root.Position - position).Magnitude <= 5 then break end
        task.wait(0.03)
    end
    pcall(function() tween:Cancel() end)
    pcall(function() driverConnection:Disconnect() end)
    pcall(function() driver:Destroy() end)
    if guard and guard.Driver == driver then
        guard.Driver = nil
        guard.DriverConnection = nil
    end
    if Runtime.CurrentTween == tween then Runtime.CurrentTween = nil end
    if not movementCharacterValid(character, humanoid, generation) then return false, "respawn" end
    if not movementEnabled(manual) or not worldContains(tool) then return false, "interrupted" end
    return (root.Position - position).Magnitude <= 20, "position correction"
end

local function moveToFruit(tool, root, humanoid, character, generation, manual)
    local handle = fruitHandle(tool)
    if not handle then return false, "fruit without Handle" end
    local start = root.Position
    local destination = handle.Position + Vector3.new(0, 3, 0)
    local horizontalDistance = (Vector3.new(start.X, 0, start.Z) - Vector3.new(destination.X, 0, destination.Z)).Magnitude
    local route = {}

    if horizontalDistance > 180 then
        local cruiseY = math.max(220, start.Y + 80, destination.Y + 100)
        table.insert(route, Vector3.new(start.X, cruiseY, start.Z))
        table.insert(route, Vector3.new(destination.X, cruiseY, destination.Z))
    end
    table.insert(route, destination)

    for _, waypoint in ipairs(route) do
        local reached, reason = tweenSegment(root, humanoid, character, generation, tool, waypoint, manual)
        if not reached and waypoint == destination and reason == "position correction" then
            reached, reason = tweenSegment(root, humanoid, character, generation, tool, waypoint, manual)
        end
        if not reached then return false, reason end
    end
    return true
end

local function collectFruit(tool, manual)
    if Runtime.BusyCollecting or not fruitAllowed(tool) then return false end
    local root, humanoid = characterRoot()
    local handle = fruitHandle(tool)
    if not root or not handle or not worldContains(tool) then return false end

    local character = root.Parent
    local generation = Runtime.CharacterGeneration
    local finalPosition = handle.Position + Vector3.new(0, 1.5, 0)
    Runtime.BusyCollecting = true
    Runtime.CurrentTarget = tool
    local oldAutoRotate = humanoid.AutoRotate
    humanoid.AutoRotate = false
    startMovementGuard(character, root, humanoid)

    local reached
    if State.Movement == "instant" then
        pivotCharacterTo(character, handle.Position + Vector3.new(0, 3, 0))
        reached = true
    else
        reached = moveToFruit(tool, root, humanoid, character, generation, manual)
    end

    local characterChanged = not movementCharacterValid(character, humanoid, generation)
    if reached and movementEnabled(manual) and not characterChanged and worldContains(tool) and handle.Parent then
        local pickupDeadline = os.clock() + State.PickupTimeout
        repeat
            if not worldContains(tool) or not handle.Parent or not movementCharacterValid(character, humanoid, generation) then break end
            if AcquiredByUs[tool] or isOwned(tool) then break end
            finalPosition = handle.Position + Vector3.new(0, 1.5, 0)
            pivotCharacterTo(character, finalPosition)
            touchFruit(tool, root, handle)
            task.wait(0.12)
        until os.clock() >= pickupDeadline
    end

    local success = AcquiredByUs[tool] == true or isOwned(tool) or StoreStatus[tool] == "stored"
    if not success and worldContains(tool) and not characterChanged then
        FailureCount[tool] = (FailureCount[tool] or 0) + 1
        FailedUntil[tool] = os.clock() + 2
        if FailureCount[tool] >= 3 then IgnoredWorldFruits[tool] = true end
    elseif success then
        FailureCount[tool] = nil
        FailedUntil[tool] = nil
    end
    Runtime.CurrentTarget = nil
    if success and shouldAutoStore() and isOwned(tool) then
        if Runtime.MovementGuard then Runtime.MovementGuard.HoldPosition = finalPosition end
        storeFruit(tool)
    end
    if success and not characterChanged and Runtime.MovementGuard then
        Runtime.MovementGuard.HoldPosition = finalPosition
        local settleDeadline = os.clock() + 0.75
        while movementCharacterValid(character, humanoid, generation) and os.clock() < settleDeadline do
            task.wait(0.03)
        end
    end
    stopMovementGuard()
    if humanoid.Parent then humanoid.AutoRotate = oldAutoRotate end
    Runtime.BusyCollecting = false
    if success then
        Runtime.NoFruitSince = os.clock()
        Runtime.EmptyScanCount = 0
    end
    return success
end

local PIRATE_RAID_CENTER = Vector3.new(-5543.532, 313.8, -2964.258)
local PIRATE_RAID_RADIUS = 1600
local PIRATE_RAID_NAMES = {}
for _, name in ipairs({
    "Galley Pirate", "Galley Captain", "Raider", "Mercenary", "Vampire", "Zombie",
    "Snow Trooper", "Winter Warrior", "Lab Subordinate", "Horned Warrior", "Magma Ninja",
    "Lava Pirate", "Ship Deckhand", "Ship Engineer", "Ship Steward", "Ship Officer",
    "Arctic Warrior", "Snow Lurker", "Sea Soldier", "Water Fighter",
}) do
    PIRATE_RAID_NAMES[normalize(name)] = true
end

local function eventPart(target)
    if not target then return nil end
    if target:IsA("BasePart") then return target end
    return target:FindFirstChild("HumanoidRootPart", true)
        or target.PrimaryPart
        or target:FindFirstChildWhichIsA("BasePart", true)
end

local function eventTargetAlive(target)
    local part = eventPart(target)
    if not part or not part.Parent then return false end
    local humanoid = target:IsA("Model") and target:FindFirstChildOfClass("Humanoid") or nil
    if humanoid and (not humanoid.Parent or humanoid.Health <= 0) then return false end
    local health = target:GetAttribute("Health")
    if type(health) == "number" and health <= 0 then return false end
    return true
end

local function factoryCoreTarget()
    if seaName() ~= "Second Sea" then return nil end
    local enemies = Workspace:FindFirstChild("Enemies")
    if enemies then
        for _, target in ipairs(enemies:GetChildren()) do
            local key = normalize(target.Name)
            if (key == "core" or key:find("factorycore", 1, true)) and eventTargetAlive(target) then
                return target
            end
        end
    end
    for _, target in ipairs(Workspace:GetChildren()) do
        if normalize(target.Name) == "core" and eventTargetAlive(target) then
            return target
        end
    end
end

local function pirateRaidTargets()
    if seaName() ~= "Third Sea" then return {} end
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return {} end
    local targets = {}
    for _, target in ipairs(enemies:GetChildren()) do
        if target:IsA("Model") and eventTargetAlive(target) then
            local key = normalize(target.Name)
            local part = eventPart(target)
            local isRaidName = PIRATE_RAID_NAMES[key] or key:find("tanky", 1, true) ~= nil
            if isRaidName and part and (part.Position - PIRATE_RAID_CENTER).Magnitude <= PIRATE_RAID_RADIUS then
                table.insert(targets, target)
            end
        end
    end
    table.sort(targets, function(a, b)
        local aTank = normalize(a.Name):find("tanky", 1, true) ~= nil
        local bTank = normalize(b.Name):find("tanky", 1, true) ~= nil
        if aTank ~= bTank then return aTank end
        local root = characterRoot()
        local aPart, bPart = eventPart(a), eventPart(b)
        if not root or not aPart or not bPart then return a.Name < b.Name end
        return (root.Position - aPart.Position).Magnitude < (root.Position - bPart.Position).Magnitude
    end)
    return targets
end

local function findActiveRaidFactory()
    local core = factoryCoreTarget()
    if core then return "Factory", { core } end
    local pirates = pirateRaidTargets()
    if #pirates > 0 then return "Pirate Raid", pirates end
end

local function isPhysicalFruitTool(tool)
    if not tool or not tool:IsA("Tool") then return true end
    return isFruit(tool) or CatalogByAlias[normalize(tool.Name)] ~= nil
end

local function combatToolScore(tool)
    local tooltip = ""
    pcall(function() tooltip = tostring(tool.ToolTip or ""):lower() end)
    local name = tostring(tool.Name or ""):lower()
    if tooltip:find("sword", 1, true) or name:find("sword", 1, true) then return 1 end
    if tooltip:find("melee", 1, true) or name:find("godhuman", 1, true)
        or name:find("karate", 1, true) or name:find("claw", 1, true) then return 2 end
    if tooltip:find("gun", 1, true) then return 3 end
    if tooltip:find("blox fruit", 1, true) then return 4 end
    return 5
end

local function findCombatTool()
    local candidates = {}
    for _, container in ipairs({ LocalPlayer.Character, Backpack }) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") and not isPhysicalFruitTool(tool) then
                    table.insert(candidates, tool)
                end
            end
        end
    end
    table.sort(candidates, function(a, b)
        local aScore, bScore = combatToolScore(a), combatToolScore(b)
        if aScore == bScore then return a.Name < b.Name end
        return aScore < bScore
    end)
    return candidates[1]
end

local function attackEventTarget()
    local root, humanoid = characterRoot()
    if not root or not humanoid then return false end
    local tool = Runtime.EventTool
    if not tool or not tool.Parent or isPhysicalFruitTool(tool) then
        tool = findCombatTool()
        Runtime.EventTool = tool
    end
    if tool then
        if tool.Parent == Backpack then
            pcall(function() humanoid:EquipTool(tool) end)
            task.wait(0.05)
        end
        pcall(function() tool:Activate() end)
        if type(mouse1click) == "function" then pcall(mouse1click) end
        return true
    end
    if type(mouse1click) == "function" then
        pcall(mouse1click)
        return true
    end
    local clicked = pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:Button1Down(Vector2.new(0, 0))
        VirtualUser:Button1Up(Vector2.new(0, 0))
    end)
    return clicked
end

local function eventCharacterValid(character, humanoid, generation)
    return Runtime.Running and Runtime.EventBusy and LocalPlayer.Character == character
        and Runtime.CharacterGeneration == generation and humanoid.Parent == character and humanoid.Health > 0
end

local function eventMoveTo(target)
    local root, humanoid = characterRoot()
    local part = eventPart(target)
    if not root or not humanoid or not part then return false end
    local character = root.Parent
    local generation = Runtime.CharacterGeneration
    local guard = Runtime.MovementGuard
    if not guard or guard.Character ~= character then
        guard = startMovementGuard(character, root, humanoid)
    end
    local position = part.Position + Vector3.new(0, 20, 0)
    local distance = (root.Position - position).Magnitude
    if distance <= 7 then
        guard.HoldPosition = position
        return true
    end

    local driver = Instance.new("CFrameValue")
    driver.Name = "LapoEventTweenDriver"
    local currentPivot = character:GetPivot()
    local orientation = currentPivot - currentPivot.Position
    driver.Value = currentPivot
    local tween = TweenService:Create(
        driver,
        TweenInfo.new(math.max(0.05, distance / math.max(State.TweenSpeed, 1)), Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
        { Value = CFrame.new(position) * orientation }
    )
    local driverConnection = RunService.Heartbeat:Connect(function()
        if eventCharacterValid(character, humanoid, generation) then character:PivotTo(driver.Value) end
    end)
    guard.Driver = driver
    guard.DriverConnection = driverConnection
    Runtime.CurrentTween = tween
    Runtime.EventTween = tween
    tween:Play()
    local deadline = os.clock() + math.max(0.05, distance / math.max(State.TweenSpeed, 1)) + 2
    while eventCharacterValid(character, humanoid, generation) and eventTargetAlive(target) and os.clock() < deadline do
        if (root.Position - position).Magnitude <= 8 then break end
        task.wait(0.03)
    end
    pcall(function() tween:Cancel() end)
    pcall(function() driverConnection:Disconnect() end)
    pcall(function() driver:Destroy() end)
    if guard.Driver == driver then
        guard.Driver = nil
        guard.DriverConnection = nil
    end
    if Runtime.CurrentTween == tween then Runtime.CurrentTween = nil end
    if Runtime.EventTween == tween then Runtime.EventTween = nil end
    if not eventCharacterValid(character, humanoid, generation) then return false end
    guard.HoldPosition = position
    return (root.Position - position).Magnitude <= 20
end

local function runAutoRaidFactory()
    if Runtime.EventBusy or not State.AutoRaidFactory or not Runtime.Running then return end
    Runtime.EventBusy = true
    Runtime.EventType = nil
    Runtime.EventTarget = nil
    Runtime.EventTool = nil
    while Runtime.Running and State.AutoRaidFactory and Runtime.BusyCollecting do task.wait(0.1) end
    if not Runtime.Running or not State.AutoRaidFactory then
        stopEventAutomation()
        return
    end
    while Runtime.Running and State.AutoRaidFactory do
        local eventType, targets = findActiveRaidFactory()
        if not eventType or #targets == 0 then break end
        Runtime.EventType = eventType
        local target = targets[1]
        Runtime.EventTarget = target
        local part = eventPart(target)
        if part and eventTargetAlive(target) then
            if eventMoveTo(target) then
                local attackDeadline = os.clock() + 40
                while Runtime.Running and State.AutoRaidFactory and eventTargetAlive(target)
                    and os.clock() < attackDeadline do
                    local currentPart = eventPart(target)
                    local guard = Runtime.MovementGuard
                    if currentPart and guard then
                        guard.HoldPosition = currentPart.Position + Vector3.new(0, 20, 0)
                    end
                    attackEventTarget()
                    task.wait(0.08)
                end
            else
                task.wait(0.4)
            end
        else
            task.wait(0.2)
        end
    end
    stopEventAutomation()
    if Runtime.Running and shouldAutoStore() then task.spawn(storeInventory) end
end

stopEventAutomation = function()
    if Runtime.EventTween then pcall(function() Runtime.EventTween:Cancel() end) end
    Runtime.EventTween = nil
    if Runtime.EventBusy then stopMovementGuard() end
    Runtime.EventBusy = false
    Runtime.EventType = nil
    Runtime.EventTarget = nil
    Runtime.EventTool = nil
    Runtime.NoFruitSince = os.clock()
end

safeCollectFruit = function(tool, manual)
    if Runtime.EventBusy then return false end
    local ok, result = pcall(collectFruit, tool, manual)
    if not ok then
        if Runtime.CurrentTween then pcall(function() Runtime.CurrentTween:Cancel() end) end
        Runtime.CurrentTween = nil
        Runtime.CurrentTarget = nil
        Runtime.BusyCollecting = false
        local _, humanoid = characterRoot()
        if humanoid then humanoid.AutoRotate = true end
        stopMovementGuard()
        return false
    end
    return result
end

local function storeInventory(forceRetry)
    for _, container in ipairs({ Backpack, LocalPlayer.Character }) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if isFruit(item) then
                    storeFruit(item, forceRetry == true)
                end
            end
        end
    end
end

local function purchaseFruit(storageName)
    if not storageName then return false end
    local ok = invoke("PurchaseRawFruit", storageName)
    if not ok then
        return false
    end
    return true
end

local function buyRandomFruit()
    if not State.AutoRandomFruit or os.clock() - Runtime.LastRandomBuy < 10 then return false end
    Runtime.LastRandomBuy = os.clock()
    local ok = invoke("Cousin", "Buy")
    if ok then task.delay(0.5, function() if Runtime.Running and shouldAutoStore() then storeInventory() end end) end
    return ok
end

local function runSniper()
    if not State.AutoSniper or #State.SniperTargets == 0 then return end
    local refreshed = refreshCatalog()
    if not refreshed then return end
    for _, entry in ipairs(Catalog) do
        if entry.OnSale and selectedContains(State.SniperTargets, entry.Name) then
            local key = "Sniper_" .. normalize(entry.Name)
            local last = Runtime[key] or 0
            if os.clock() - last >= 60 then
                Runtime[key] = os.clock()
                purchaseFruit(entry.Name)
                break
            end
        end
    end
end

local function getJson(url)
    local body = nil
    local lastErr = nil
    local send = requestFunction()
    if send then
        local requested, response = pcall(send, { Url = url, Method = "GET" })
        if requested and type(response) == "table" then
            local code = tonumber(response.StatusCode or response.Status or response.status_code) or 0
            if code == 429 then
                return false, "HTTP 429 rate-limit"
            elseif code >= 200 and code < 300 then
                body = response.Body or response.body
            else
                lastErr = "HTTP " .. tostring(code)
            end
        else
            lastErr = tostring(response)
        end
    end
    if type(body) ~= "string" or body == "" then
        local ok, result = pcall(function() return game:HttpGet(url) end)
        if ok and type(result) == "string" and result ~= "" then
            body = result
        else
            return false, tostring(lastErr or result or "http failed")
        end
    end
    local decoded, data = pcall(HttpService.JSONDecode, HttpService, body)
    if not decoded or type(data) ~= "table" then return false, "invalid server response" end
    return true, data
end

local function queueHopScript()
    local loader = buildConfigLoader()
    local queue = (queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport))
    if type(queue) == "function" then
        pcall(queue, loader)
    elseif type(getgenv) == "function" then
        pcall(function()
            local env = getgenv()
            env.LapoFruitConfig = configSnapshot()
        end)
    end
end

local function findServer(skipVisited)
    local cursor = nil
    local candidates = {}
    local sortOrder = HopRandom:NextInteger(0, 1) == 0 and "Asc" or "Desc"
    local pages = math.clamp(math.floor(tonumber(State.HopPages) or 3), 1, 10)
    for _ = 1, pages do
        local url = string.format(
            "https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=%s&excludeFullGames=true&limit=100",
            tostring(game.PlaceId), sortOrder
        )
        if cursor and cursor ~= "" then url = url .. "&cursor=" .. HttpService:UrlEncode(cursor) end
        local ok, page = getJson(url)
        if not ok then
            if #candidates > 0 then break end
            return nil, page
        end
        for _, server in ipairs(page.data or {}) do
            local id = tostring(server.id or "")
            local playing = tonumber(server.playing) or math.huge
            local maximum = tonumber(server.maxPlayers) or 0
            if id ~= "" and id ~= game.JobId and maximum > 0 and playing < maximum
                and (not skipVisited or not VisitedServers[id]) then
                table.insert(candidates, { Id = id, Playing = playing })
            end
        end
        cursor = page.nextPageCursor
        if not cursor or cursor == "" then break end
        task.wait(0.1)
    end
    if #candidates == 0 then return nil, "no servers available" end
    return candidates[HopRandom:NextInteger(1, #candidates)]
end

local function scheduleHopRetry()
    if Runtime.RetryScheduled then return end
    local attempt = Runtime.HopAttempt or 0
    local mayRetry = Runtime.HopManual or State.AutoServerHop
    Runtime.Hopping = false
    Runtime.ActiveHopId = nil
    if not Runtime.Running then
        Runtime.RetryScheduled = false
        return
    end
    if not mayRetry then
        Runtime.HopAttempt = 0
        Runtime.HopManual = false
        Runtime.NoFruitSince = os.clock()
        return
    end
    local refreshAfter = math.max(1, math.floor(tonumber(State.HopRetries) or 8))
    if attempt >= refreshAfter then
        table.clear(VisitedServers)
        VisitedServers[game.JobId] = true
        attempt = 0
        Runtime.HopAttempt = 0
    end

    Runtime.RetryScheduled = true
    local delaySeconds = HopRandom:NextNumber(0.7, 2.4)
    task.delay(delaySeconds, function()
        Runtime.RetryScheduled = false
        if not Runtime.Running then return end
        if not (Runtime.HopManual or State.AutoServerHop) then return end
        local ok, err = pcall(serverHop, Runtime.HopManual, attempt + 1)
        if not ok then
            warn("[Lapo Fruit Hub] Hop failed: " .. tostring(err))
            scheduleHopRetry()
        end
    end)
end

serverHop = function(manual, attempt)
    if Runtime.Hopping or Runtime.RetryScheduled or not Runtime.Running then return false end
    if not manual and not State.AutoServerHop then return false end
    if not manual and not attempt and os.clock() - Runtime.LastHopAttempt < 8 then return false end
    if not manual then
        scanEntireWorld()
        if Runtime.BusyCollecting or hasWorldFruitToProcess() or hasPendingStorage() then
            Runtime.NoFruitSince = os.clock()
            Runtime.EmptyScanCount = 0
            return false
        end
    end
    attempt = attempt or 1
    Runtime.Hopping = true
    Runtime.LastHopAttempt = os.clock()
    Runtime.HopAttempt = attempt
    if attempt == 1 then Runtime.HopManual = manual == true end
    VisitedServers[game.JobId] = true
    local server = findServer(true)
    if not server then
        table.clear(VisitedServers)
        VisitedServers[game.JobId] = true
        server = findServer(false)
    end
    if not server then
        scheduleHopRetry()
        return false
    end
    if not manual then
        task.wait(0.35)
        scanEntireWorld()
    end
    if not manual and (Runtime.BusyCollecting or hasWorldFruitToProcess() or hasPendingStorage()) then
        Runtime.Hopping = false
        Runtime.HopAttempt = 0
        Runtime.HopManual = false
        Runtime.NoFruitSince = os.clock()
        Runtime.EmptyScanCount = 0
        return false
    end

    VisitedServers[server.Id] = true
    pcall(function() Window:SaveProfile("default") end)
    pcall(queueHopScript)
    if Runtime.CurrentTween then pcall(function() Runtime.CurrentTween:Cancel() end) end
    Runtime.CurrentTween = nil
    Runtime.ActiveHopId = server.Id
    local activeId = server.Id
    task.delay(10, function()
        if Runtime.Running and Runtime.Hopping and Runtime.ActiveHopId == activeId and game.JobId ~= activeId then
            scheduleHopRetry()
        end
    end)

    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, server.Id, LocalPlayer)
    end)
    if not ok then
        warn("[Lapo Fruit Hub] Teleport failed: " .. tostring(err))
        scheduleHopRetry()
        return false
    end
    return true
end

local FarmTab = Window:Tab({ name = "Farm", icon = "F" })
local ShopTab = Window:Tab({ name = "Shop", icon = "S" })
local HopTab = Window:Tab({ name = "Hop", icon = "H" })
local EventsTab = Window:Tab({ name = "Events", icon = "E" })
local SettingsTab = Window:Tab({ name = "Settings", icon = "C" })
local WebhookTab = Window:Tab({ name = "Webhook", icon = "W" })

FarmTab:Section({ id = "collection", text = "Collection", expanded = true, persist = false })
Controls.AutoCollect = FarmTab:Toggle({
    id = "auto-collect",
    section = "collection",
    text = "Auto Collect",
    default = State.AutoCollect,
    callback = function(value)
        State.AutoCollect = value
        if not value and not State.AutoServerHop and Runtime.CurrentTween then
            Runtime.CurrentTween:Cancel()
        end
    end,
})
Controls.AutoStore = FarmTab:Toggle({
    id = "auto-store",
    section = "collection",
    text = "Auto Store",
    default = State.AutoStore,
    callback = function(value)
        State.AutoStore = value
        if value then
            task.spawn(storeInventory)
        end
    end,
})
Controls.EspFruit = FarmTab:Toggle({
    id = "esp-fruit",
    section = "collection",
    text = "Fruit ESP",
    default = State.EspFruit,
    callback = function(value)
        State.EspFruit = value
        refreshAllEsp()
    end,
})

FarmTab:Section({ id = "filters", text = "Filters", expanded = true, persist = false })
Controls.FilterMode = FarmTab:Dropdown({
    id = "filter-mode",
    section = "filters",
    text = "Collect Filter",
    options = {
        { value = "all", label = "All" },
        { value = "selected", label = "Selected Only" },
    },
    default = State.FilterMode,
    valueDefault = true,
    callback = function(_, value)
        State.FilterMode = value
    end,
})
Controls.SelectedFruits = FarmTab:Dropdown({
    id = "selected-fruits",
    section = "filters",
    text = "Selected Fruits",
    options = fallbackOptions(),
    multiple = true,
    default = copyStringArray(State.SelectedFruits) or {},
    dependsOn = { id = "filter-mode", equals = "selected" },
    callback = function(value)
        State.SelectedFruits = value
    end,
})
Controls.MinimumValue = FarmTab:NumberInput({
    id = "minimum-value",
    section = "filters",
    text = "Minimum Value",
    min = 0,
    max = 100000000,
    step = 50000,
    default = State.MinimumValue,
    callback = function(value)
        State.MinimumValue = value
    end,
})
Controls.Priority = FarmTab:Dropdown({
    id = "priority",
    section = "filters",
    text = "Priority",
    options = {
        { value = "value", label = "Highest Value" },
        { value = "nearest", label = "Nearest" },
    },
    default = State.Priority,
    valueDefault = true,
    callback = function(_, value)
        State.Priority = value
    end,
})

FarmTab:Section({ id = "actions", text = "Actions", expanded = false, persist = false })
FarmTab:Button({
    section = "actions",
    text = "Collect One Now",
    callback = function()
        local target = chooseFruit()
        if target then
            task.spawn(safeCollectFruit, target, true)
        end
    end,
})
FarmTab:Button({
    section = "actions",
    text = "Store Inventory",
    callback = function()
        task.spawn(storeInventory)
    end,
})

EventsTab:Section({ id = "events", text = "Raid / Factory", expanded = true, persist = false })
Controls.AutoRaidFactory = EventsTab:Toggle({
    id = "auto-raid-factory",
    section = "events",
    text = "Auto Pirate Raid / Factory",
    default = State.AutoRaidFactory,
    callback = function(value)
        State.AutoRaidFactory = value
        if not value and stopEventAutomation then
            stopEventAutomation()
        end
    end,
})

ShopTab:Section({ id = "stock", text = "Stock", expanded = true, persist = false })
ShopTab:Button({
    section = "stock",
    text = "Refresh Catalog",
    callback = function()
        task.spawn(refreshCatalog)
    end,
})

ShopTab:Section({ id = "sniper", text = "Sniper", expanded = true, persist = false })
Controls.SniperTargets = ShopTab:Dropdown({
    id = "sniper-targets",
    section = "sniper",
    text = "Sniper Targets",
    options = fallbackOptions(),
    multiple = true,
    default = copyStringArray(State.SniperTargets) or {},
    callback = function(value)
        State.SniperTargets = value
    end,
})
Controls.AutoSniper = ShopTab:Toggle({
    id = "auto-sniper",
    section = "sniper",
    text = "Auto Buy On Stock",
    default = State.AutoSniper,
    callback = function(value)
        State.AutoSniper = value
    end,
})
Controls.SniperInterval = ShopTab:Slider({
    id = "sniper-interval",
    section = "sniper",
    text = "Sniper Interval (s)",
    min = 10,
    max = 120,
    step = 5,
    default = State.SniperInterval,
    callback = function(value)
        State.SniperInterval = value
    end,
})

ShopTab:Section({ id = "random-fruit", text = "Random", expanded = false, persist = false })
Controls.AutoRandomFruit = ShopTab:Toggle({
    id = "auto-random-fruit",
    section = "random-fruit",
    text = "Auto Random Fruit",
    default = State.AutoRandomFruit,
    callback = function(value)
        State.AutoRandomFruit = value
    end,
})

HopTab:Section({ id = "server-hop", text = "Server Hop", expanded = true, persist = false })
Controls.AutoServerHop = HopTab:Toggle({
    id = "auto-server-hop",
    section = "server-hop",
    text = "Auto Server Hop",
    default = State.AutoServerHop,
    callback = function(value)
        State.AutoServerHop = value
        Runtime.NoFruitSince = os.clock()
        if value then
            task.spawn(storeInventory)
        end
    end,
})
Controls.HopAfter = HopTab:Slider({
    id = "hop-after",
    section = "server-hop",
    text = "Hop After No Fruit (s)",
    min = 5,
    max = 120,
    step = 5,
    default = State.HopAfter,
    callback = function(value)
        State.HopAfter = value
        Runtime.NoFruitSince = os.clock()
    end,
})
Controls.HopPages = HopTab:Slider({
    id = "hop-pages",
    section = "server-hop",
    text = "Server Pages",
    min = 1,
    max = 10,
    step = 1,
    default = State.HopPages,
    callback = function(value)
        State.HopPages = value
    end,
})
Controls.HopRetries = HopTab:Slider({
    id = "hop-retries",
    section = "server-hop",
    text = "Retries Before Reset",
    min = 2,
    max = 20,
    step = 1,
    default = State.HopRetries,
    callback = function(value)
        State.HopRetries = value
    end,
})
HopTab:Button({
    section = "server-hop",
    text = "Hop Now",
    callback = function()
        task.spawn(serverHop, true)
    end,
})

SettingsTab:Section({ id = "movement", text = "Movement", expanded = true, persist = false })
Controls.Movement = SettingsTab:Dropdown({
    id = "movement-method",
    section = "movement",
    text = "Movement Method",
    options = {
        { value = "tween", label = "Tween (Recommended)" },
        { value = "instant", label = "Instant" },
    },
    default = State.Movement,
    valueDefault = true,
    callback = function(_, value)
        State.Movement = value
    end,
})
Controls.TweenSpeed = SettingsTab:Slider({
    id = "tween-speed",
    section = "movement",
    text = "Tween Speed",
    min = 200,
    max = 1000,
    step = 50,
    default = State.TweenSpeed,
    dependsOn = { id = "movement-method", equals = "tween" },
    callback = function(value)
        State.TweenSpeed = value
    end,
})

SettingsTab:Section({ id = "performance", text = "Performance", expanded = false, persist = false })
Controls.ScanInterval = SettingsTab:Slider({
    id = "scan-interval",
    section = "performance",
    text = "Scan Interval (s)",
    min = 0.1,
    max = 1,
    step = 0.1,
    default = State.ScanInterval,
    callback = function(value)
        State.ScanInterval = value
    end,
})
Controls.PickupTimeout = SettingsTab:Slider({
    id = "pickup-timeout",
    section = "performance",
    text = "Pickup Timeout (s)",
    min = 5,
    max = 30,
    step = 1,
    default = State.PickupTimeout,
    callback = function(value)
        State.PickupTimeout = value
    end,
})
Controls.StoreDelay = SettingsTab:Slider({
    id = "store-delay",
    section = "performance",
    text = "Store Delay (s)",
    min = 0.1,
    max = 3,
    step = 0.05,
    default = State.StoreDelay,
    callback = function(value)
        State.StoreDelay = value
    end,
})
Controls.AntiIdle = SettingsTab:Toggle({
    id = "anti-idle",
    section = "performance",
    text = "Anti-AFK",
    default = State.AntiIdle,
    callback = function(value)
        State.AntiIdle = value
    end,
})

SettingsTab:Section({ id = "profiles", text = "Profiles", expanded = false, persist = false })
Controls.ProfileName = SettingsTab:TextBox({
    id = "profile-name",
    section = "profiles",
    text = "Profile Name",
    default = "default",
    persist = false,
    placeholder = "default",
    callback = function(value)
        State.ProfileName = value ~= "" and value or "default"
    end,
})
SettingsTab:Button({
    section = "profiles",
    text = "Save Profile",
    callback = function()
        Window:SaveProfile(State.ProfileName)
    end,
})
SettingsTab:Button({
    section = "profiles",
    text = "Load Profile",
    callback = function()
        local ok = Window:LoadProfile(State.ProfileName)
        if ok and syncStateFromControls then
            syncStateFromControls()
            if HasExternalConfig then
                applyExternalConfig(ExternalConfig)
            end
        end
    end,
})
SettingsTab:Button({
    section = "profiles",
    text = "Copy Config JSON",
    callback = function()
        local ok, data = pcall(function()
            return HttpService:JSONEncode(Window:ExportProfile())
        end)
        if not ok then
            return
        end
        Window:Copy(data)
    end,
})
SettingsTab:Button({
    section = "profiles",
    text = "Export Loadstring",
    callback = function()
        Window:Copy(buildConfigLoader())
    end,
})
SettingsTab:Button({
    section = "profiles",
    text = "Unload Hub",
    callback = function()
        if Environment.LapoFruitHub then
            Environment.LapoFruitHub.Destroy()
        end
    end,
})

WebhookTab:Section({ id = "webhook-main", text = "Webhook", expanded = true, persist = false })
Controls.WebhookUrl = WebhookTab:TextBox({
    id = "webhook-url",
    section = "webhook-main",
    text = "Discord Webhook URL",
    placeholder = "https://discord.com/api/webhooks/...",
    default = State.WebhookUrl,
    validate = function(value)
        if value == "" or validWebhook(value:gsub("%s+", "")) then
            return true
        end
        return false, "Use an official discord.com/api/webhooks URL"
    end,
    callback = function(value)
        State.WebhookUrl = value
    end,
})
Controls.WebhookEnabled = WebhookTab:Toggle({
    id = "webhook-enabled",
    section = "webhook-main",
    text = "Enable Webhook",
    default = State.WebhookEnabled,
    callback = function(value)
        State.WebhookEnabled = value
    end,
})
Controls.WebhookStored = WebhookTab:Toggle({
    id = "webhook-stored",
    section = "webhook-main",
    text = "Notify Stored Only",
    default = true,
    callback = function(value)
        State.WebhookStored = value
    end,
})
Controls.WebhookMinimumValue = WebhookTab:NumberInput({
    id = "webhook-minimum",
    section = "webhook-main",
    text = "Minimum Value",
    min = 0,
    max = 100000000,
    step = 50000,
    default = State.WebhookMinimumValue,
    callback = function(value)
        State.WebhookMinimumValue = value
    end,
})
Controls.WebhookIncludeServer = WebhookTab:Toggle({
    id = "webhook-server",
    section = "webhook-main",
    text = "Include Server JobId",
    default = State.WebhookIncludeServer,
    callback = function(value)
        State.WebhookIncludeServer = value
    end,
})
Controls.WebhookMention = WebhookTab:Dropdown({
    id = "webhook-mention",
    section = "webhook-main",
    text = "Mention",
    options = {
        { value = "none", label = "None" },
        { value = "user", label = "User By ID" },
        { value = "everyone", label = "@everyone" },
    },
    default = State.WebhookMention,
    valueDefault = true,
    callback = function(_, value)
        State.WebhookMention = value
    end,
})
Controls.WebhookUserId = WebhookTab:TextBox({
    id = "webhook-user-id",
    section = "webhook-main",
    text = "Discord User ID",
    default = State.WebhookUserId,
    placeholder = "123456789...",
    dependsOn = { id = "webhook-mention", equals = "user" },
    validate = function(value)
        return value == "" or value:match("^%d+$") ~= nil, "Digits only"
    end,
    callback = function(value)
        State.WebhookUserId = value
    end,
})
Controls.WebhookInterval = WebhookTab:Slider({
    id = "webhook-interval",
    section = "webhook-main",
    text = "Send Interval (s)",
    min = 1,
    max = 10,
    step = 0.5,
    default = State.WebhookInterval,
    callback = function(value)
        State.WebhookInterval = value
    end,
})
WebhookTab:Button({
    section = "webhook-main",
    text = "Test Webhook",
    callback = function()
        if State.WebhookUrl == "" then
            return
        end
        queueWebhook("Test", "Rocket-Rocket", 5000, "Webhook configured successfully", true)
    end,
})

syncStateFromControls = function()
    local wasAutoStore = State.AutoStore
    State.AutoCollect = Controls.AutoCollect:Get()
    State.AutoStore = Controls.AutoStore:Get()
    State.EspFruit = Controls.EspFruit:Get()
    State.FilterMode = Controls.FilterMode:Get()
    State.SelectedFruits = Controls.SelectedFruits:Get()
    State.MinimumValue = Controls.MinimumValue:Get()
    State.Priority = Controls.Priority:Get()
    State.Movement = Controls.Movement:Get()
    State.TweenSpeed = Controls.TweenSpeed:Get()
    State.ScanInterval = Controls.ScanInterval:Get()
    State.PickupTimeout = Controls.PickupTimeout:Get()
    State.StoreDelay = Controls.StoreDelay:Get()
    State.AntiIdle = Controls.AntiIdle:Get()
    State.AutoSniper = Controls.AutoSniper:Get()
    State.SniperTargets = Controls.SniperTargets:Get()
    State.SniperInterval = Controls.SniperInterval:Get()
    State.AutoRandomFruit = Controls.AutoRandomFruit:Get()
    State.AutoServerHop = Controls.AutoServerHop:Get()
    State.HopAfter = Controls.HopAfter:Get()
    State.HopPages = Controls.HopPages:Get()
    State.HopRetries = Controls.HopRetries:Get()
    State.AutoRaidFactory = Controls.AutoRaidFactory:Get()
    State.WebhookEnabled = Controls.WebhookEnabled:Get()
    State.WebhookUrl = Controls.WebhookUrl:Get()
    State.WebhookStored = Controls.WebhookStored:Get()
    State.WebhookMinimumValue = Controls.WebhookMinimumValue:Get()
    State.WebhookMention = Controls.WebhookMention:Get()
    State.WebhookUserId = Controls.WebhookUserId:Get()
    State.WebhookIncludeServer = Controls.WebhookIncludeServer:Get()
    State.WebhookInterval = Controls.WebhookInterval:Get()
    if not State.AutoCollect and not State.AutoServerHop and Runtime.CurrentTween then Runtime.CurrentTween:Cancel() end
    if State.AutoStore and not wasAutoStore then task.spawn(storeInventory) end
    refreshAllEsp()
end

Window:SetUser(LocalPlayer.DisplayName, "v " .. HUB_VERSION)
Window:Init({
    Title = "Lapo Fruit Hub",
    Width = 450,
    Height = 400,
    ToggleKey = "End",
    Renderer = "Auto",
    ProfileFolder = HUB_FOLDER,
    Profile = "default",
    AutoSave = true,
    AutoLoad = not HasExternalConfig,
})
syncStateFromControls()
applyExternalConfig(ExternalConfig)

local Hub = {}
function Hub.ExportConfig()
    return configSnapshot()
end
function Hub.ExportLoadstring()
    return buildConfigLoader()
end
function Hub.Destroy()
    if not Runtime.Running then return end
    Runtime.Running = false
    State.AutoCollect = false
    State.AutoSniper = false
    State.AutoRandomFruit = false
    State.AutoServerHop = false
    State.AutoRaidFactory = false
    if Runtime.CurrentTween then pcall(function() Runtime.CurrentTween:Cancel() end) end
    stopEventAutomation()
    stopMovementGuard()
    for _, connection in ipairs(Connections) do pcall(function() connection:Disconnect() end) end
    for tool in pairs(EspObjects) do removeEsp(tool) end
    pcall(function() Window:Destroy() end)
    if Environment.LapoFruitHub == Hub then Environment.LapoFruitHub = nil end
end
Environment.LapoFruitHub = Hub

connect(Workspace.ChildAdded, registerWorldFruit)
connect(Workspace.ChildRemoved, function(instance)
    if TrackedWorldFruits[instance] then unregisterWorldFruit(instance) end
end)
connect(Backpack.ChildAdded, onOwnedFruit)

local function invalidateCharacterMovement()
    Runtime.CharacterGeneration = Runtime.CharacterGeneration + 1
    if Runtime.CurrentTween then pcall(function() Runtime.CurrentTween:Cancel() end) end
    Runtime.CurrentTween = nil
    Runtime.EventTween = nil
    Runtime.EventTool = nil
    Runtime.CurrentTarget = nil
    Runtime.BusyCollecting = false
    Runtime.BusyStoring = false
    Runtime.StorageWorkers = 0
    for tool, status in pairs(StoreStatus) do
        if status == "working" then StoreStatus[tool] = "pending" end
    end
    stopMovementGuard()
    Runtime.NoFruitSince = os.clock()
end

local function bindCharacter(character)
    invalidateCharacterMovement()
    connect(character.ChildAdded, onOwnedFruit)
    task.spawn(function()
        local humanoid = character:WaitForChild("Humanoid", 10)
        if humanoid and humanoid:IsA("Humanoid") then
            connect(humanoid.Died, function()
                if LocalPlayer.Character == character then
                    invalidateCharacterMovement()
                end
            end)
        end
    end)
end

connect(LocalPlayer.CharacterAdded, bindCharacter)
if LocalPlayer.Character then bindCharacter(LocalPlayer.Character) end
scanEntireWorld()
if shouldAutoStore() then task.spawn(storeInventory) end
connect(LocalPlayer.Idled, function()
    if State.AntiIdle then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end
end)
connect(TeleportService.TeleportInitFailed, function(player, result)
    if player ~= LocalPlayer then return end
    warn("[Lapo Fruit Hub] TeleportInitFailed: " .. tostring(result))
    if Runtime.Hopping or Runtime.HopManual or State.AutoServerHop then
        scheduleHopRetry()
    end
end)
connect(LocalPlayer:GetPropertyChangedSignal("Team"), function()
    Runtime.TeamReady = isMarineTeam()
    Runtime.NoFruitSince = os.clock()
end)

task.spawn(function()
    while Runtime.Running do
        if not Runtime.TeamReady or not isMarineTeam() then
            ensureMarineTeam()
        end
        task.wait(Runtime.TeamReady and 1 or 0.2)
    end
end)

task.spawn(function()
    while Runtime.Running do
        local ok, err = pcall(function()
            if State.AutoRaidFactory and Runtime.TeamReady and not Runtime.EventBusy
                and not Runtime.BusyCollecting and not Runtime.Hopping then
                local eventType = findActiveRaidFactory()
                if eventType then
                    local rok, rerr = pcall(runAutoRaidFactory)
                    if not rok then
                        warn("[Lapo Fruit Hub] Raid/Factory error: " .. tostring(rerr))
                        pcall(stopEventAutomation)
                    end
                end
            end
        end)
        if not ok then
            warn("[Lapo Fruit Hub] Raid loop error: " .. tostring(err))
            pcall(stopEventAutomation)
        end
        task.wait(State.AutoRaidFactory and 0.25 or 0.75)
    end
end)

task.spawn(function()
    task.spawn(refreshCatalog)
    while Runtime.Running do
        local ok, err = pcall(function()
            if Runtime.TeamReady and not Runtime.EventBusy and (State.AutoCollect or State.AutoServerHop) and not Runtime.BusyCollecting then
                local target = chooseFruit()
                if target then
                    safeCollectFruit(target)
                else
                    task.wait(State.ScanInterval)
                end
            else
                task.wait(0.25)
            end
        end)
        if not ok then
            warn("[Lapo Fruit Hub] Collect loop error: " .. tostring(err))
            Runtime.BusyCollecting = false
            task.wait(0.5)
        end
    end
end)

task.spawn(function()
    while Runtime.Running do
        if State.AutoSniper and os.clock() - Runtime.LastSniperCheck >= State.SniperInterval then
            Runtime.LastSniperCheck = os.clock()
            runSniper()
        end
        task.wait(0.5)
    end
end)

task.spawn(function()
    while Runtime.Running do
        if State.AutoRandomFruit then buyRandomFruit() end
        task.wait(1)
    end
end)

task.spawn(function()
    while Runtime.Running do
        local ok, err = pcall(function()
            if State.AutoServerHop and not Runtime.Hopping and not Runtime.RetryScheduled and not Runtime.EventBusy then
                scanEntireWorld()
                local root = characterRoot()
                if not root or Runtime.BusyCollecting
                    or hasWorldFruitToProcess() or hasPendingStorage() then
                    Runtime.NoFruitSince = os.clock()
                    Runtime.EmptyScanCount = 0
                else
                    Runtime.EmptyScanCount = Runtime.EmptyScanCount + 1
                end
                if Runtime.EmptyScanCount >= 3 and os.clock() - Runtime.NoFruitSince >= State.HopAfter then
                    serverHop(false)
                end
            end
        end)
        if not ok then
            warn("[Lapo Fruit Hub] Hop loop error: " .. tostring(err))
            Runtime.Hopping = false
        end
        task.wait(0.5)
    end
end)

task.spawn(function()
    while Runtime.Running do
        local entry = table.remove(WebhookQueue, 1)
        if entry then
            local elapsed = os.clock() - Runtime.LastWebhook
            if elapsed < State.WebhookInterval then task.wait(State.WebhookInterval - elapsed) end
            if not Runtime.Running then break end
            sendWebhook(entry)
            Runtime.LastWebhook = os.clock()
        else
            task.wait(0.25)
        end
    end
end)
