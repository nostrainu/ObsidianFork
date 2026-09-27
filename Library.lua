if getgenv().uiUpd then 
    pcall(getgenv().uiUpd.Unload, getgenv().uiUpd) 
end

do
    local loaded = false
    if isfile and readfile then
        for _, path in ipairs({"Main/Karinderya/KarinderyaFunc.lua", "KarinderyaFunc.lua", "BobCat/Games/Karinderya/KarinderyaFunc.lua"}) do
            if isfile(path) then
                local ok, content = pcall(readfile, path)
                if ok and content then
                    local func, err = loadstring(content)
                    if func then
                        local success, execErr = pcall(func)
                        if success then
                            loaded = true
                            break
                        end
                    end
                end
            end
        end
    end
    if not loaded then
        local repo = "https://raw.githubusercontent.com/nostrainu/ObsidianFork/main/Karinderya/"
        local ok, content = pcall(game.HttpGet, game, repo .. "KarinderyaFunc.lua")
        if ok and content then
            local func, err = loadstring(content)
            if func then
                pcall(func)
            end
        end
    end
end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local isWorker = getgenv().Automation == true or getgenv().Automitation == true

if not isWorker and (not getgenv().Host or getgenv().Host == "") then
    getgenv().Host = LocalPlayer.Name
end

local function getProfilePath(profileName)
    return getgenv().getProfilePath(profileName)
end

local function getProfileData(altName)
    return getgenv().getProfileData(altName)
end

local function writeProfileData(altName, data)
    getgenv().writeProfileData(altName, data)
end

local function saveActiveProfile()
    getgenv().saveActiveProfile()
end

local function save()
    getgenv().saveProfile()
end

local function registerSetting(name, defaultValue)
    return getgenv().registerSetting(name, defaultValue)
end

local function startupDiscoverAlts()
    getgenv().startupDiscoverAlts()
end

if isWorker then
    pcall(getgenv().runWorker)
    return
end

local repo = "https://raw.githubusercontent.com/nostrainu/ObsidianFork/main/"
local libSrc = game:HttpGet(repo .. "Library.lua?t=" .. os.time())
local func, libErr = loadstring(libSrc)
assert(func, "[Karinderya] Failed to compile Library.lua: " .. tostring(libErr))
local Library = func()

local path = getProfilePath and getProfilePath("Main") or "BobCat/Games/Karinderya/config.json"
local config = {}
if isfile(path) then
    local readSuccess, fileContent = pcall(readfile, path)
    if readSuccess and fileContent then
        local decSuccess, parsed = pcall(HttpService.JSONDecode, HttpService, fileContent)
        if decSuccess and type(parsed) == "table" then
            config = parsed
        end
    end
end
getgenv().KarinderyaConfig = config

local activeProfile = "Main"
getgenv().activeProfile = activeProfile

local activeConfigTable = config
getgenv().activeConfigTable = activeConfigTable

config.HostActive = true
save()

pcall(startupDiscoverAlts)

local selectedAlts = {}

local isSyncingUI = false

local savePending = false
local function debouncedSave()
    if savePending then return end
    savePending = true
    task.delay(0.5, function()
        savePending = false
        saveActiveProfile()
    end)
end

local function setConfig(name, val)
    if isSyncingUI then
        if activeProfile == "Main" then
            getgenv()[name] = val
            if getgenv().AccountControl and getgenv().AccountControl[name] ~= nil then
                getgenv().AccountControl[name] = val
            end
        end
        return
    end

    activeConfigTable[name] = val
    debouncedSave()
    
    if activeProfile == "Main" then
        getgenv()[name] = val
        if getgenv().AccountControl and getgenv().AccountControl[name] ~= nil then
            getgenv().AccountControl[name] = val
        end
    end
    
    for altName, isSelected in pairs(selectedAlts) do
        if isSelected then
            local altData = getProfileData(altName) or {}
            altData[name] = val
            local host = getgenv().Host
            if host and host ~= "" then
                altData.Host = host
            end
            writeProfileData(altName, altData)
        end
    end
end

local defaultSettings = getgenv().KarinderyaDefaultSettings or {}

for name, defaultValue in pairs(defaultSettings) do
    registerSetting(name, defaultValue)
end

local function syncGlobalConfig()
    if getgenv().AccountControl then
        for k in pairs(getgenv().AccountControl) do
            if getgenv()[k] ~= nil then
                getgenv().AccountControl[k] = getgenv()[k]
            end
        end
    end
end
syncGlobalConfig()

local function toHex(color)
    local r = math.clamp(math.round(color.R * 255), 0, 255)
    local g = math.clamp(math.round(color.G * 255), 0, 255)
    local b = math.clamp(math.round(color.B * 255), 0, 255)
    return string.format("%02x%02x%02x", r, g, b)
end

local function fromHex(hex)
    if type(hex) ~= "string" then return Color3.new(1, 1, 1) end
    hex = hex:gsub("#", "")
    if #hex < 6 then return Color3.new(1, 1, 1) end
    local r = tonumber(hex:sub(1, 2), 16) or 255
    local g = tonumber(hex:sub(3, 4), 16) or 255
    local b = tonumber(hex:sub(5, 6), 16) or 255
    return Color3.fromRGB(r, g, b)
end

local function SyncUI()
    local defaults = getgenv().KarinderyaDefaultSettings or {}
    for key, defaultValue in pairs(defaults) do
        local opt = Library.Toggles[key] or Library.Options[key]
        if opt then
            local value = activeConfigTable[key]
            if value == nil then
                value = defaultValue
            end
            pcall(function()
                if opt.Type == "ColorPicker" and type(value) == "string" then
                    opt:SetValue(fromHex(value))
                else
                    opt:SetValue(value)
                end
            end)
        end
    end
end

local function loadProfile(profileName)
    activeProfile = profileName
    getgenv().activeProfile = profileName
    local profilePath = getProfilePath(profileName)
    
    if profileName == "Main" then
        activeConfigTable = config
        getgenv().activeConfigTable = config
    elseif isfile(profilePath) then
        local data = getProfileData(profileName)
        if data then
            activeConfigTable = data
            getgenv().activeConfigTable = data
        else
            activeConfigTable = {}
            getgenv().activeConfigTable = {}
        end
    else
        activeConfigTable = {}
        getgenv().activeConfigTable = {}
        saveActiveProfile()
    end
    
    isSyncingUI = true
    SyncUI()
    isSyncingUI = false
end
getgenv().Karinderya_LoadProfile = loadProfile

local function keysToArray(tbl)
    local arr = {}
    if type(tbl) == "table" then
        for k, v in pairs(tbl) do
            if v then
                table.insert(arr, k)
            end
        end
    end
    return arr
end

getgenv().uiActive = true
getgenv().Library = Library
getgenv().uiUpd = Library

local Window = Library:CreateWindow({
    Title = "Bobcat",
    Footer = "Karinderya",
    MobileButtonsSide = "Left",
    ShowMobileButtons = true,
    NotifySide = "Right",
    Center = true,
    SideBarText = false,
    ScrollLongText = true,
    Size = Library.IsMobile and UDim2.fromOffset(470, 380) or UDim2.fromOffset(570, 450),
    DisableFloatingMenu = registerSetting("DisableFloatingMenu", false)
})

Window:AddTabSection("Main Features")
local Tabs = {
    Main = Window:AddTab("Main", "layers-2"),
    Shop = Window:AddTab("Shop", "shopping-cart"),
    Misc = Window:AddTab("Misc", "box"),
}

local ServiceLeft = Tabs.Main:AddLeftGroupbox({
    Name = "Restaurant Service",
    Center = true,
    Collapsible = true,
    DefaultCollapsed = false
})

local KitchenRight = Tabs.Main:AddRightGroupbox({
    Name = "Kitchen & Cleaning",
    Center = true,
    Collapsible = true,
    DefaultCollapsed = false
})

local SecurityGroup = Tabs.Main:AddMiddleGroupbox({
    Name = "Security & Staff",
    Center = true,
    Collapsible = true,
    DefaultCollapsed = false
})

ServiceLeft:AddToggle("AutoCounter", {
    Text = "Auto Counter & Assign",
    Default = getgenv().AutoCounter,
    Callback = function(val) setConfig("AutoCounter", val) end
})

ServiceLeft:AddToggle("AutoCollectFood", {
    Text = "Auto Collect Food",
    Default = getgenv().AutoCollectFood,
    Callback = function(val) setConfig("AutoCollectFood", val) end
})

ServiceLeft:AddToggle("AutoServe", {
    Text = "Auto Serve & Softdrinks",
    Default = getgenv().AutoServe,
    Callback = function(val) setConfig("AutoServe", val) end
})

KitchenRight:AddToggle("AutoDish", {
    Text = "Auto Wash Dishes",
    Default = getgenv().AutoDish,
    Callback = function(val) setConfig("AutoDish", val) end
})

SecurityGroup:AddToggle("AutoCatch", {
    Text = "Auto Catch Runaways & Wake Staff",
    Default = getgenv().AutoCatch,
    Callback = function(val) setConfig("AutoCatch", val) end
})

local IngredientShopGroup = Tabs.Shop:AddLeftGroupbox({
    Name = "Ingredients Shop",
    Center = true,
    Collapsible = true,
    DefaultCollapsed = false
})

local PaintShopGroup = Tabs.Shop:AddRightGroupbox({
    Name = "Furniture & Paints",
    Center = true,
    Collapsible = true,
    DefaultCollapsed = false
})

IngredientShopGroup:AddToggle("AutoBuy", {
    Text = "Auto Buy Ingredients",
    Default = getgenv().AutoBuy,
    Callback = function(val) setConfig("AutoBuy", val) end
})

PaintShopGroup:AddToggle("AutoBuyPaints", {
    Text = "Auto Buy Paints",
    Default = getgenv().AutoBuyPaints,
    Callback = function(val) setConfig("AutoBuyPaints", val) end
})

local WebhookGroup = Tabs.Misc:AddLeftGroupbox({
    Name = "Webhook Settings",
    Center = true,
    Collapsible = true,
    DefaultCollapsed = false
})

WebhookGroup:AddInput("WebhookURL", {
    Text = "Webhook URL",
    Default = getgenv().WebhookURL or "",
    Finished = true,
    Callback = function(val) setConfig("WebhookURL", val) end
})

WebhookGroup:AddInput("WebhookUserID", {
    Text = "Discord User ID (optional)",
    Default = getgenv().WebhookUserID or "",
    Finished = true,
    Callback = function(val) setConfig("WebhookUserID", val) end
})

WebhookGroup:AddToggle("WebhookEnabled", {
    Text = "Enable Webhook",
    Default = getgenv().WebhookEnabled,
    Callback = function(val) setConfig("WebhookEnabled", val) end
})

WebhookGroup:AddButton("Test Webhook", function()
    local sendWebhook = getgenv().sendWebhook
    if sendWebhook then
        local contentStr = ""
        local userId = getgenv().WebhookUserID
        if userId and userId ~= "" then
            contentStr = "<@" .. tostring(userId) .. ">"
        end
        
        sendWebhook(getgenv().WebhookURL, {
            content = contentStr,
            embeds = {
                {
                    title = "🔔 Karinderya Webhook Test",
                    description = "Your webhook configuration is working successfully!",
                    color = 10711287,
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                    footer = {
                        text = "Bob-Cat",
                        icon_url = "https://raw.githubusercontent.com/nostrainu/Dump/main/Assets/pop_cat_smirk_closed.png"
                    }
                }
            }
        })
    end
end)

local SettingsTab = Window:AddTab({ Name = "Settings", Icon = "settings", Side = "Header", Visible = false })
local InfoTab = Window:AddTab({ Name = "Info", Icon = "info", Side = "SidebarBottom" })

local SettingsGroup = SettingsTab:AddLeftGroupbox("Controls")
SettingsGroup:AddLabel("Toggle UI Bind"):AddKeyPicker("MenuKeybind", { 
    Default = "LeftControl", 
    NoUI = true, 
    Text = "Menu Keybind" 
})
Library.ToggleKeybind = Library.Options.MenuKeybind

SettingsGroup:AddButton("Unload UI", function()
    Library:Unload()
end)

SettingsGroup:AddDivider()

SettingsGroup:AddToggle("DisableFloatingMenu", {
    Text = "Disable Floating",
    Default = registerSetting("DisableFloatingMenu", false),
    Callback = function(val)
        setConfig("DisableFloatingMenu", val)
        if activeProfile == "Main" then
            Library.DisableFloatingMenu = val
        end
    end
})

SettingsGroup:AddToggle("AutoExecute", {
    Text = "Auto Execute",
    Default = registerSetting("AutoExecute", false),
    Callback = function(val)
        setConfig("AutoExecute", val)
    end
})

local ProfileGroup = InfoTab:AddMiddleGroupbox({
    Name = "Profile",
    Center = true
})

local ProfileCard = ProfileGroup:AddProfileCard({
    Role = "Premium",
    KeyType = "Lifetime"
})

local DiscordTab = ProfileCard:AddTab({
    Name = "Discord",
    Icon = "message-square"
})
DiscordTab:AddLabel("Join our Discord community for support!")
DiscordTab:AddButton("Copy Invite Link", function()
    pcall(function() setclipboard("https://discord.gg/6sdWsCy9e") end)
end)

local ShopTab = ProfileCard:AddTab({
    Name = "Shop",
    Icon = "shopping-cart"
})
ShopTab:AddLabel("Purchase lifetime access & features!")
ShopTab:AddButton("Copy Shop URL", function()
    pcall(function() setclipboard("https://bobcat-hub.mysellix.io") end)
end)

local GameTab = ProfileCard:AddTab({
    Name = "Game",
    Icon = "gamepad-2"
})

GameTab:AddGameInfo()

local AccountsTab = ProfileCard:AddTab({
    Name = "Accounts",
    Icon = "users"
})
if type(config.Accounts) ~= "table" then
    config.Accounts = {}
    save()
end

AccountsTab:AddLabel("Account Control")

local altList = AccountsTab:AddAltList("AltAccountsList", {
    Accounts = config.Accounts,
    SelectedAlts = selectedAlts,
    Searchable = true,
    StatusOrder = { "Online", "Farming", "Waiting", "Paused", "No Script" },
    StatusColors = {
        Farming = Color3.fromRGB(240, 200, 0),
        Waiting = Color3.fromRGB(0, 180, 240),
        Paused = Color3.fromRGB(150, 150, 150),
        Idle = Color3.fromRGB(150, 150, 150),
        Online = Color3.fromRGB(0, 200, 100),
        Offline = Color3.fromRGB(240, 70, 70),
        ["No Script"] = Color3.fromRGB(240, 70, 70)
    },
    OnToggle = function(alt, isSelected)
        if isSelected then
            selectedAlts[alt.Name] = true
            if not getgenv().Karinderya_BulkSelectActive then
                loadProfile(alt.Name)
            end
        else
            selectedAlts[alt.Name] = nil
            if not getgenv().Karinderya_BulkSelectActive then
                if activeProfile == alt.Name then
                    local nextActive = "Main"
                    for otherAltName, otherIsSelected in pairs(selectedAlts) do
                        if otherIsSelected and otherAltName ~= alt.Name then
                            nextActive = otherAltName
                            break
                        end
                    end
                    loadProfile(nextActive)
                end
            end
        end
    end,
    OnCopyID = function(alt)
        pcall(function() setclipboard(tostring(alt.Id)) end)
    end,
    OnDelete = function(alt, confirmDelete)
        local dialog = Window:AddDialog("ConfirmRemove", {
            Title = "Remove Alt Account",
            Description = "Are you sure you want to remove " .. alt.Name .. "?",
            AutoDismiss = true,
            OutsideClickDismiss = true,
            FooterButtons = {
                {
                    Id = "Confirm",
                    Title = "Yes",
                    Variant = "Destructive",
                    Callback = function()
                        for i, a in ipairs(config.Accounts) do
                            if a.Name == alt.Name then
                                table.remove(config.Accounts, i)
                                break
                            end
                        end
                        save()
                        
                        local altPath = getProfilePath(alt.Name)
                        pcall(delfile, altPath)
                        
                        if activeProfile == alt.Name then
                            loadProfile("Main")
                        end
                        
                        if confirmDelete then
                            confirmDelete()
                        end
                    end
                },
                {
                    Id = "Cancel",
                    Title = "No",
                    Variant = "Secondary",
                    Callback = function()
                    end
                }
            }
        })
        return dialog
    end,
    OnPause = function(alt, explicitState)
        local parsed = getProfileData(alt.Name)
        if parsed then
            if explicitState ~= nil then
                if explicitState then
                    parsed.Status = "Paused"
                else
                    local isFarming = parsed.AutoCounter or parsed.AutoCollectFood or parsed.AutoServe or parsed.AutoDish or parsed.AutoCatch or parsed.AutoBuy or parsed.AutoBuyPaints
                    parsed.Status = isFarming and "Farming" or "Waiting"
                end
            else
                if parsed.Status == "Paused" then
                    local isFarming = parsed.AutoCounter or parsed.AutoCollectFood or parsed.AutoServe or parsed.AutoDish or parsed.AutoCatch or parsed.AutoBuy or parsed.AutoBuyPaints
                    parsed.Status = isFarming and "Farming" or "Waiting"
                else
                    parsed.Status = "Paused"
                end
            end
            writeProfileData(alt.Name, parsed)
        end
    end,
    OnOpenStats = function(alt)
        local altData = {
            AutoCounter = false,
            AutoCollectFood = false,
            AutoServe = false,
            AutoDish = false,
            AutoCatch = false,
            AutoBuy = false,
            AutoBuyPaints = false,
            Status = "Waiting",
            Coins = 0,
            Cash = 0,
            LastActive = 0
        }
        local isMain = false
        pcall(function()
            local lp = Players.LocalPlayer
            if lp and alt.Name == lp.Name then
                isMain = true
            end
        end)
        local parsed = getProfileData(alt.Name)
        if parsed then
            for k, v in pairs(parsed) do
                altData[k] = v
            end
        end
        local dialog = Window:AddDialog("AltStats_" .. alt.Name, {
            Title = "Statistics: " .. alt.Name,
            Description = "View real-time account details and status.",
            AutoDismiss = true,
            OutsideClickDismiss = true,
            FooterButtons = {
                {
                    Id = "Close",
                    Title = "Close",
                    Variant = "Primary"
                }
            }
        })
        local function formatCoins(val)
            val = tonumber(val) or 0
            if val >= 1000000 then
                return string.format("%.2fM", val / 1000000)
            elseif val >= 1000 then
                return string.format("%.2fK", val / 1000)
            else
                return tostring(val)
            end
        end
        local activeStatus = "Offline"
        if isMain then
            activeStatus = "Online"
        else
            local playerInGame = Players:FindFirstChild(alt.Name)
            local isOnline = playerInGame ~= nil
            if isOnline then
                activeStatus = "Online"
            end
            if altData.LastActive and os.time() - altData.LastActive < 15 then
                activeStatus = altData.Status or "Farming"
            elseif isOnline then
                activeStatus = "No Script"
            end
        end
        local lastActiveStr = "Unknown"
        if isMain then
            lastActiveStr = "Active now"
        elseif altData.LastActive and altData.LastActive > 0 then
            local diff = os.time() - altData.LastActive
            if diff < 15 then
                lastActiveStr = "Active now"
            elseif diff < 60 then
                lastActiveStr = tostring(diff) .. "s ago"
            elseif diff < 3600 then
                lastActiveStr = tostring(math.floor(diff / 60)) .. "m ago"
            else
                lastActiveStr = tostring(math.floor(diff / 3600)) .. "h ago"
            end
        end
        dialog:AddLabel("Status: " .. activeStatus)
        dialog:AddLabel("Last Active: " .. lastActiveStr)
        dialog:AddLabel("Cash: " .. formatCoins(altData.Cash or altData.Coins))
        return dialog
    end,
    OnOfflineAlert = function(alt, status)
        Window:AddDialog("AltOffline_" .. alt.Name, {
            Title = "Account Inactive",
            Description = alt.Name .. " is currently " .. status .. ". Please start the script on this account to control it.",
            AutoDismiss = true,
            OutsideClickDismiss = true,
            FooterButtons = {
                {
                    Id = "Ok",
                    Title = "OK",
                    Variant = "Primary"
                }
            }
        })
    end,
    GetFarmingStatus = function(alt, isOnline)
        local parsed = getProfileData(alt.Name)
        if parsed then
            local lastActive = parsed.LastActive or 0
            if os.time() - lastActive < 15 then
                return parsed.Status or "Farming", parsed.Status == "Paused"
            end
        end
        return isOnline and "No Script" or "Offline", false
    end,
    GetAccountDetails = function(alt, isMain)
        return ""
    end
})

getgenv().Karinderya_AltList = altList

altList:AddAccount({
    Name = LocalPlayer.Name,
    Id = LocalPlayer.UserId,
}, {
    IsMain = true,
    AllowDelete = false,
    AllowPause = false,
    AllowCopyID = true,
    AllowStats = true
})

AccountsTab:AddToggle("HideIdentity", {
    Text = "Hide Avatar & Name",
    Default = false,
    Callback = function(val)
        if altList and altList.SetHideIdentity then
            altList:SetHideIdentity(val)
        end
    end
})

local function autoDiscoverAlts()
    local mainSuccess, mainErr = pcall(function()
        local host = getgenv().Host
        if not host or host == "" then return end
        
        local folder = "BobCat/Games/Karinderya/alts"
        if not isfolder(folder) then return end
        
        local successFiles, files = pcall(listfiles, folder)
        if not successFiles or type(files) ~= "table" then return end
        
        local changed = false
        for _, filePath in ipairs(files) do
            local fileName = string.gsub(filePath, "\\", "/")
            fileName = string.match(fileName, "([^/]+)$") or fileName
            local altName = string.match(fileName, "^" .. host .. "_(.-)%.json$")
            if altName and altName ~= host then
                local exists = false
                for _, alt in ipairs(config.Accounts or {}) do
                    if alt.Name == altName then
                        exists = true
                        break
                    end
                end
                
                if not exists then
                    local userId = "0"
                    pcall(function()
                        if isfile(filePath) then
                            local content = readfile(filePath)
                            local parsed = HttpService:JSONDecode(content)
                            if type(parsed) == "table" and parsed.UserId then
                                userId = tostring(parsed.UserId)
                            end
                        end
                    end)
                    
                    table.insert(config.Accounts, { Name = altName, Id = userId })
                    changed = true
                    if altList and altList.AddAccount then
                        altList:AddAccount({ Name = altName, Id = userId })
                    end
                end
            end
        end
        
        if changed then
            save()
        end
    end)
end

pcall(autoDiscoverAlts)

task.spawn(function()
    while true do
        pcall(autoDiscoverAlts)
        task.wait(3)
    end
end)

SyncUI()

Library:OnUnload(function()
    if getgenv().Karinderya_Stop then
        pcall(getgenv().Karinderya_Stop)
        getgenv().Karinderya_Stop = nil
    end
end)
