local LIBRARY_URL = "https://raw.githubusercontent.com/LapoLapoNaldo/Lapo-X2/refs/heads/main/Library.lua"
local HUB_FOLDER = "LapoFruitHub"
local HUB_VERSION = "1.8.0"

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
assert(Remotes, "[Lapo Fruit Hub] Pasta Remotes nao encontrada.")
local CommF_ = Remotes:WaitForChild("CommF_", 15)
assert(CommF_, "[Lapo Fruit Hub] Remote CommF_ nao encontrado.")

local Environment = (getgenv and getgenv()) or _G
if Environment.LapoFruitHub and Environment.LapoFruitHub.Destroy then
    pcall(Environment.LapoFruitHub.Destroy)
end
local ScriptArguments = ...
local ExternalConfig = type(ScriptArguments) == "table" and ScriptArguments
    or (type(Environment.LapoFruitConfig) == "table" and Environment.LapoFruitConfig or {})
local ScriptUrl = type(Environment.LapoFruitScriptUrl) == "string" and Environment.LapoFruitScriptUrl or "URL_DO_SEU_HUB"
local HasExternalConfig = next(ExternalConfig) ~= nil

local loaded, Library = pcall(function()
    return loadstring(game:HttpGet(LIBRARY_URL))()
end)
assert(loaded and Library, "[Lapo Fruit Hub] Falha ao carregar a Lapo X2: " .. tostring(Library))

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
    AutoServerHop = true,
    HopAfter = 10,
    HopPages = 3,
    HopRetries = 8,
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
    State.HopAfter = externalValue(config, { "hopAfter" }, State.HopAfter, "number")
    State.HopPages = externalValue(config, { "hopPages" }, State.HopPages, "number")
    State.HopRetries = externalValue(config, { "hopRetries" }, State.HopRetries, "number")
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
        hopAfter = State.HopAfter,
        hopPages = State.HopPages,
        hopRetries = State.HopRetries,
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
        "storeDelay", "antiIdle", "autoSniper", "sniperTargets", "sniperInterval", "hopAfter",
        "hopPages", "hopRetries", "webhookUrl", "webhookEnabled", "sendWebhookOnCollect",
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
    "Spirit-Spirit", "Leopard-Leopard", "Tiger-Tiger", "Yeti-Yeti", "Kitsune-Kitsune", "Dragon-Dragon",
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
    local name = tostring(storageName or "Fruta")
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
    if Runtime.TeamReady and (State.AutoCollect or State.AutoServerHop) and allowed
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
    if #nextCatalog == 0 then return false, "catalogo vazio" end

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
        if eventName ~= "Guardada" or not State.WebhookEnabled or not State.WebhookStored then return end
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
    if not validWebhook(url) then return false, "URL de webhook do Discord invalida" end
    local send = requestFunction()
    if not send then return false, "executor sem funcao request" end

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
        { name = "Fruta", value = prettyFruitName(entry.Fruit), inline = true },
        { name = "Valor", value = "$" .. comma(entry.Value), inline = true },
        { name = "Evento", value = entry.Event, inline = true },
        { name = "Jogador", value = LocalPlayer.Name .. " (" .. LocalPlayer.DisplayName .. ")", inline = true },
        { name = "Mar", value = seaName(), inline = true },
        { name = "Detalhe", value = tostring(entry.Detail):sub(1, 900), inline = false },
    }
    if State.WebhookIncludeServer then
        table.insert(fields, { name = "Servidor", value = "`" .. tostring(game.JobId) .. "`", inline = false })
    end

    local body = HttpService:JSONEncode({
        username = "Lapo Fruit Hub",
        content = mention,
        allowed_mentions = allowedMentions,
        embeds = {{
            title = "Fruit " .. entry.Event,
            color = entry.Event == "Guardada" and 5763719 or (entry.Event == "Comprada" and 16763904 or 8317335),
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

local function storeFruit(tool, forceRetry)
    if not Runtime.Running or not isFruit(tool) or not isOwned(tool) then return false end
    local previous = StoreStatus[tool]
    if previous == "stored" then return true end
    if previous == "failed" and not forceRetry then return false end
    if previous == "working" then
        repeat task.wait(0.05) until not Runtime.Running or StoreStatus[tool] ~= "working"
        return StoreStatus[tool] == "stored"
    end

    StoreStatus[tool] = "pending"
    while Runtime.BusyStoring and Runtime.Running do task.wait(0.1) end
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
        queueWebhook("Guardada", storageName, fruitValue(storageName), "Armazenada automaticamente")
        return true
    end
    return false
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
    for tool in pairs(TrackedWorldFruits) do
        if worldContains(tool) and fruitAllowed(tool) and not IgnoredWorldFruits[tool] then return true end
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
        or not worldContains(tool) then return false, "interrompido" end
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
    if not movementEnabled(manual) or not worldContains(tool) then return false, "interrompido" end
    return (root.Position - position).Magnitude <= 20, "correcao de posicao"
end

local function moveToFruit(tool, root, humanoid, character, generation, manual)
    local handle = fruitHandle(tool)
    if not handle then return false, "fruta sem Handle" end
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
        if not reached then
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
    Runtime.NoFruitSince = os.clock()
    return success
end

safeCollectFruit = function(tool, manual)
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
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if not ok then
        local send = requestFunction()
        if not send then return false, tostring(body) end
        local requested, response = pcall(send, { Url = url, Method = "GET" })
        if not requested or type(response) ~= "table" then return false, tostring(response) end
        local code = tonumber(response.StatusCode or response.Status or response.status_code) or 0
        if code < 200 or code >= 300 then return false, "HTTP " .. tostring(code) end
        body = response.Body or response.body
    end
    local decoded, data = pcall(HttpService.JSONDecode, HttpService, body)
    if not decoded or type(data) ~= "table" then return false, "resposta de servidores invalida" end
    return true, data
end

local function findServer(skipVisited)
    local cursor = nil
    local candidates = {}
    local sortOrder = HopRandom:NextInteger(0, 1) == 0 and "Asc" or "Desc"
    for _ = 1, State.HopPages do
        local url = string.format(
            "https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=%s&excludeFullGames=true&limit=100",
            tostring(game.PlaceId), sortOrder
        )
        if cursor and cursor ~= "" then url = url .. "&cursor=" .. HttpService:UrlEncode(cursor) end
        local ok, page = getJson(url)
        if not ok then return nil, page end
        for _, server in ipairs(page.data or {}) do
            local id = tostring(server.id or "")
            local playing = tonumber(server.playing) or math.huge
            local maximum = tonumber(server.maxPlayers) or 0
            if id ~= "" and id ~= game.JobId and playing < maximum and (not skipVisited or not VisitedServers[id]) then
                table.insert(candidates, { Id = id, Playing = playing })
            end
        end
        cursor = page.nextPageCursor
        if not cursor or cursor == "" then break end
    end
    if #candidates == 0 then return nil, "nenhum servidor disponivel" end
    return candidates[HopRandom:NextInteger(1, #candidates)]
end

local function scheduleHopRetry()
    if Runtime.RetryScheduled or not Runtime.Running then return end
    local attempt = Runtime.HopAttempt
    local mayRetry = Runtime.HopManual or State.AutoServerHop
    Runtime.Hopping = false
    Runtime.ActiveHopId = nil
    if not mayRetry or attempt >= State.HopRetries then
        Runtime.HopAttempt = 0
        Runtime.HopManual = false
        Runtime.NoFruitSince = os.clock()
        return
    end

    Runtime.RetryScheduled = true
    local delaySeconds = HopRandom:NextNumber(0.7, 2.4)
    task.delay(delaySeconds, function()
        if not Runtime.Running then return end
        Runtime.RetryScheduled = false
        serverHop(Runtime.HopManual, attempt + 1)
    end)
end

serverHop = function(manual, attempt)
    if Runtime.Hopping or Runtime.RetryScheduled or not Runtime.Running then return false end
    if not manual and not State.AutoServerHop then return false end
    if not manual and not Runtime.TeamReady then return false end
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
    Runtime.ActiveHopId = server.Id
    local activeId = server.Id
    task.delay(HopRandom:NextNumber(8, 11), function()
        if Runtime.Running and Runtime.Hopping and Runtime.ActiveHopId == activeId then
            scheduleHopRetry()
        end
    end)

    local browser = ReplicatedStorage:FindFirstChild("__ServerBrowser")
        or ReplicatedStorage:WaitForChild("__ServerBrowser", 5)
    if not browser or not browser:IsA("RemoteFunction") then
        scheduleHopRetry()
        return false
    end
    local ok, result = pcall(function()
        return browser:InvokeServer("teleport", server.Id)
    end)
    if not ok or result == false then
        scheduleHopRetry()
        return false
    end
    return true
end

local FruitTab = Window:Tab({ name = "Fruit", icon = "F" })
local ConfigTab = Window:Tab({ name = "Config", icon = "C" })
local WebhookTab = Window:Tab({ name = "Webhook", icon = "W" })

FruitTab:Section({ id = "collection", text = "Coleta", expanded = true, persist = false })
Controls.AutoCollect = FruitTab:Toggle({
    id = "auto-collect", section = "collection", text = "Auto coletar frutas",
    default = State.AutoCollect,
    callback = function(value)
        State.AutoCollect = value
        if not value and not State.AutoServerHop and Runtime.CurrentTween then Runtime.CurrentTween:Cancel() end
    end,
})
Controls.AutoStore = FruitTab:Toggle({
    id = "auto-store", section = "collection", text = "Auto guardar frutas",
    default = State.AutoStore,
    callback = function(value)
        State.AutoStore = value
        if value then task.spawn(storeInventory) end
    end,
})
Controls.EspFruit = FruitTab:Toggle({
    id = "esp-fruit", section = "collection", text = "ESP de frutas", default = State.EspFruit,
    callback = function(value) State.EspFruit = value; refreshAllEsp() end,
})
Controls.FilterMode = FruitTab:Dropdown({
    id = "filter-mode", section = "collection", text = "Filtro de coleta",
    options = {{ value = "all", label = "Todas" }, { value = "selected", label = "Somente selecionadas" }},
    default = State.FilterMode, valueDefault = true,
    callback = function(_, value) State.FilterMode = value end,
})
Controls.SelectedFruits = FruitTab:Dropdown({
    id = "selected-fruits", section = "collection", text = "Frutas selecionadas",
    options = fallbackOptions(), multiple = true, default = copyStringArray(State.SelectedFruits) or {},
    dependsOn = { id = "filter-mode", equals = "selected" },
    callback = function(value) State.SelectedFruits = value end,
})
Controls.MinimumValue = FruitTab:NumberInput({
    id = "minimum-value", section = "collection", text = "Valor minimo para coletar",
    min = 0, max = 100000000, step = 50000, default = State.MinimumValue,
    callback = function(value) State.MinimumValue = value end,
})
Controls.Priority = FruitTab:Dropdown({
    id = "priority", section = "collection", text = "Prioridade",
    options = {{ value = "value", label = "Maior valor" }, { value = "nearest", label = "Mais proxima" }},
    default = State.Priority, valueDefault = true,
    callback = function(_, value) State.Priority = value end,
})
FruitTab:Button({
    section = "collection", text = "Coletar uma fruta agora",
    callback = function()
        local target = chooseFruit()
        if target then task.spawn(safeCollectFruit, target, true) end
    end,
})
FruitTab:Button({ section = "collection", text = "Guardar frutas do inventario", callback = function() task.spawn(storeInventory) end })

FruitTab:Section({ id = "server-hop", text = "Server Hop", expanded = true, persist = false })
Controls.AutoServerHop = FruitTab:Toggle({
    id = "auto-server-hop", section = "server-hop", text = "Auto Server Hop",
    default = State.AutoServerHop,
    callback = function(value)
        State.AutoServerHop = value
        Runtime.NoFruitSince = os.clock()
        if value then task.spawn(storeInventory) end
    end,
})
Controls.HopAfter = FruitTab:Slider({
    id = "hop-after", section = "server-hop", text = "Trocar apos ficar sem fruta (segundos)",
    min = 5, max = 120, step = 5, default = State.HopAfter,
    callback = function(value) State.HopAfter = value; Runtime.NoFruitSince = os.clock() end,
})
Controls.HopPages = FruitTab:Slider({
    id = "hop-pages", section = "server-hop", text = "Paginas de servidores",
    min = 1, max = 10, step = 1, default = State.HopPages,
    callback = function(value) State.HopPages = value end,
})
Controls.HopRetries = FruitTab:Slider({
    id = "hop-retries", section = "server-hop", text = "Tentativas com servidores diferentes",
    min = 2, max = 20, step = 1, default = State.HopRetries,
    callback = function(value) State.HopRetries = value end,
})
FruitTab:Button({
    section = "server-hop", text = "Server Hop agora",
    callback = function() task.spawn(serverHop, true) end,
})

FruitTab:Section({ id = "shop", text = "Loja e Gacha", expanded = true, persist = false })
FruitTab:Button({
    section = "shop", text = "Atualizar catalogo/estoque",
    callback = function()
        task.spawn(function()
            refreshCatalog()
        end)
    end,
})
Controls.SniperTargets = FruitTab:Dropdown({
    id = "sniper-targets", section = "shop", text = "Alvos do sniper",
    options = fallbackOptions(), multiple = true, default = copyStringArray(State.SniperTargets) or {},
    callback = function(value) State.SniperTargets = value end,
})
Controls.AutoSniper = FruitTab:Toggle({
    id = "auto-sniper", section = "shop", text = "Auto comprar quando houver estoque",
    default = State.AutoSniper, callback = function(value) State.AutoSniper = value end,
})
Controls.SniperInterval = FruitTab:Slider({
    id = "sniper-interval", section = "shop", text = "Intervalo do sniper (segundos)",
    min = 10, max = 120, step = 5, default = State.SniperInterval,
    callback = function(value) State.SniperInterval = value end,
})
FruitTab:Button({
    section = "shop", text = "Comprar fruta aleatoria (Gacha)",
    callback = function()
        if os.clock() - Runtime.LastRandomBuy < 5 then return end
        Runtime.LastRandomBuy = os.clock()
        invoke("Cousin", "Buy")
    end,
})

ConfigTab:Section({ id = "movement", text = "Movimento e desempenho", expanded = true, persist = false })
Controls.Movement = ConfigTab:Dropdown({
    id = "movement-method", section = "movement", text = "Metodo de movimento",
    options = {{ value = "tween", label = "Tween (recomendado)" }, { value = "instant", label = "Instantaneo" }},
    default = State.Movement, valueDefault = true,
    callback = function(_, value) State.Movement = value end,
})
Controls.TweenSpeed = ConfigTab:Slider({
    id = "tween-speed", section = "movement", text = "Velocidade do Tween",
    min = 200, max = 1000, step = 50, default = State.TweenSpeed,
    dependsOn = { id = "movement-method", equals = "tween" },
    callback = function(value) State.TweenSpeed = value end,
})
Controls.ScanInterval = ConfigTab:Slider({
    id = "scan-interval", section = "movement", text = "Intervalo de busca (segundos)",
    min = 0.1, max = 1, step = 0.1, default = State.ScanInterval,
    callback = function(value) State.ScanInterval = value end,
})
Controls.PickupTimeout = ConfigTab:Slider({
    id = "pickup-timeout", section = "movement", text = "Timeout de coleta (segundos)",
    min = 5, max = 30, step = 1, default = State.PickupTimeout,
    callback = function(value) State.PickupTimeout = value end,
})
Controls.StoreDelay = ConfigTab:Slider({
    id = "store-delay", section = "movement", text = "Espera antes de guardar",
    min = 0.1, max = 3, step = 0.05, default = State.StoreDelay,
    callback = function(value) State.StoreDelay = value end,
})
Controls.AntiIdle = ConfigTab:Toggle({
    id = "anti-idle", section = "movement", text = "Anti-AFK",
    default = State.AntiIdle, callback = function(value) State.AntiIdle = value end,
})

ConfigTab:Section({ id = "profiles", text = "Perfil", expanded = true, persist = false })
Controls.ProfileName = ConfigTab:TextBox({
    id = "profile-name", section = "profiles", text = "Nome do perfil", default = "default", persist = false,
    placeholder = "default", callback = function(value) State.ProfileName = value ~= "" and value or "default" end,
})
Controls.ScriptUrl = ConfigTab:TextBox({
    id = "script-url", section = "profiles", text = "URL do hub para exportar", default = ScriptUrl, persist = false,
    placeholder = "https://.../new.luau", callback = function(value)
        if value and value ~= "" then ScriptUrl = value end
    end,
})
ConfigTab:Button({
    section = "profiles", text = "Salvar perfil agora",
    callback = function()
        Window:SaveProfile(State.ProfileName)
    end,
})
ConfigTab:Button({
    section = "profiles", text = "Carregar perfil",
    callback = function()
        local ok = Window:LoadProfile(State.ProfileName)
        if ok and syncStateFromControls then
            syncStateFromControls()
            if HasExternalConfig then applyExternalConfig(ExternalConfig) end
        end
    end,
})
ConfigTab:Button({
    section = "profiles", text = "Copiar config JSON",
    callback = function()
        local ok, data = pcall(function() return HttpService:JSONEncode(Window:ExportProfile()) end)
        if not ok then return end
        Window:Copy(data)
    end,
})
ConfigTab:Button({
    section = "profiles", text = "Exportar config para loadstring",
    callback = function()
        Window:Copy(buildConfigLoader())
    end,
})
ConfigTab:Button({
    section = "profiles", text = "Descarregar hub",
    callback = function()
        if Environment.LapoFruitHub then Environment.LapoFruitHub.Destroy() end
    end,
})

WebhookTab:Section({ id = "webhook-main", text = "Webhook", expanded = true, persist = false })
Controls.WebhookUrl = WebhookTab:TextBox({
    id = "webhook-url", section = "webhook-main", text = "URL do Discord Webhook",
    placeholder = "https://discord.com/api/webhooks/...", default = State.WebhookUrl,
    validate = function(value)
        if value == "" or validWebhook(value:gsub("%s+", "")) then return true end
        return false, "Use uma URL oficial discord.com/api/webhooks"
    end,
    callback = function(value) State.WebhookUrl = value end,
})
Controls.WebhookEnabled = WebhookTab:Toggle({
    id = "webhook-enabled", section = "webhook-main", text = "Ativar webhook",
    default = State.WebhookEnabled, callback = function(value) State.WebhookEnabled = value end,
})
Controls.WebhookStored = WebhookTab:Toggle({
    id = "webhook-stored", section = "webhook-main", text = "Avisar somente fruta guardada",
    default = true, callback = function(value) State.WebhookStored = value end,
})
Controls.WebhookMinimumValue = WebhookTab:NumberInput({
    id = "webhook-minimum", section = "webhook-main", text = "Valor minimo para avisar",
    min = 0, max = 100000000, step = 50000, default = State.WebhookMinimumValue,
    callback = function(value) State.WebhookMinimumValue = value end,
})
Controls.WebhookIncludeServer = WebhookTab:Toggle({
    id = "webhook-server", section = "webhook-main", text = "Incluir JobId do servidor",
    default = State.WebhookIncludeServer, callback = function(value) State.WebhookIncludeServer = value end,
})
Controls.WebhookMention = WebhookTab:Dropdown({
    id = "webhook-mention", section = "webhook-main", text = "Mencao",
    options = {
        { value = "none", label = "Nenhuma" },
        { value = "user", label = "Usuario por ID" },
        { value = "everyone", label = "@everyone" },
    },
    default = State.WebhookMention, valueDefault = true,
    callback = function(_, value) State.WebhookMention = value end,
})
Controls.WebhookUserId = WebhookTab:TextBox({
    id = "webhook-user-id", section = "webhook-main", text = "Discord User ID",
    default = State.WebhookUserId, placeholder = "123456789...",
    dependsOn = { id = "webhook-mention", equals = "user" },
    validate = function(value) return value == "" or value:match("^%d+$") ~= nil, "Use somente numeros" end,
    callback = function(value) State.WebhookUserId = value end,
})
Controls.WebhookInterval = WebhookTab:Slider({
    id = "webhook-interval", section = "webhook-main", text = "Intervalo entre envios",
    min = 1, max = 10, step = 0.5, default = State.WebhookInterval,
    callback = function(value) State.WebhookInterval = value end,
})
WebhookTab:Button({
    section = "webhook-main", text = "Testar webhook",
    callback = function()
        if State.WebhookUrl == "" then return end
        queueWebhook("Teste", "Rocket-Rocket", 5000, "Webhook configurado corretamente", true)
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
    State.AutoServerHop = Controls.AutoServerHop:Get()
    State.HopAfter = Controls.HopAfter:Get()
    State.HopPages = Controls.HopPages:Get()
    State.HopRetries = Controls.HopRetries:Get()
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
    State.AutoServerHop = false
    if Runtime.CurrentTween then pcall(function() Runtime.CurrentTween:Cancel() end) end
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
    Runtime.CurrentTarget = nil
    Runtime.BusyCollecting = false
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
connect(TeleportService.TeleportInitFailed, function(player)
    if player ~= LocalPlayer then return end
    if Runtime.Hopping then
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
    task.spawn(refreshCatalog)
    while Runtime.Running do
        if Runtime.TeamReady and (State.AutoCollect or State.AutoServerHop) and not Runtime.BusyCollecting then
            local target = chooseFruit()
            if target then
                safeCollectFruit(target)
            else
                task.wait(State.ScanInterval)
            end
        else
            task.wait(0.25)
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
        if State.AutoServerHop and not Runtime.Hopping then
            scanEntireWorld()
            local root = characterRoot()
            if not Runtime.TeamReady or not root or Runtime.BusyCollecting
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
