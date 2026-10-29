----------------------------------------------------
-- SECTION 1: SETTINGS
----------------------------------------------------
local GET_KEY_LINK = "https://work.ink/35c8/key-system"
local KEY_LIFETIME = 12 * 60 * 60
local LOGIC_URL = "https://raw.githubusercontent.com/Fries-dev/LizardWareRLBX/refs/heads/main/Logic.lua"

----------------------------------------------------
-- SECTION 2: TOOLS
----------------------------------------------------
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local guiParent = (gethui and gethui()) or CoreGui
local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request

-- Every place a GUI might end up
local function getContainers()
    local list = { CoreGui }
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h and h ~= CoreGui then table.insert(list, h) end
    end
    local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then table.insert(list, pg) end
    return list
end

----------------------------------------------------
-- SECTION 3: KEY FUNCTIONS
----------------------------------------------------
local expiresAt = 0 -- kept in memory while the script runs
local KEY_FILE = "LizardWare_key.json"

local function saveKey()
    if not writefile then return end
    pcall(function()
        writefile(KEY_FILE, HttpService:JSONEncode({
            expiresAt = expiresAt,
            userId = Players.LocalPlayer.UserId,
        }))
    end)
end

local function loadSavedKey()
    if not (isfile and readfile and isfile(KEY_FILE)) then return end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(KEY_FILE))
    end)
    if ok and type(data) == "table"
        and type(data.expiresAt) == "number"
        and data.userId == Players.LocalPlayer.UserId
        and data.expiresAt > os.time()
        and data.expiresAt <= os.time() + KEY_LIFETIME then
        expiresAt = data.expiresAt
    elseif delfile then
        pcall(delfile, KEY_FILE) -- expired or invalid, clean it up
    end
end
loadSavedKey()           -- <-- add this line
if os.time() >= expiresAt then
    promptForKey()
end
local function validateToken(token)
    if not httpRequest or token == "" then return false end
    local ok, res = pcall(function()
        return httpRequest({
            Url = "https://work.ink/_api/v2/token/isValid/" .. HttpService:UrlEncode(token) .. "?deleteToken=1",
            Method = "GET",
        })
    end)
    if not ok or not res or res.StatusCode ~= 200 then return false end
    local ok2, data = pcall(HttpService.JSONDecode, HttpService, res.Body)
    return ok2 and data.valid == true
end

----------------------------------------------------
-- SECTION 4: KEY WINDOW
----------------------------------------------------
local function promptForKey()
    local passed = false
    local gui = Instance.new("ScreenGui")
    gui.Name = "PepsiKeyGate"
    gui.Parent = guiParent

    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.fromOffset(320, 170)
    frame.Position = UDim2.new(0.5, -160, 0.5, -85)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    Instance.new("UICorner", frame)

    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundTransparency = 1
    title.Text = "Key System"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16

    local box = Instance.new("TextBox", frame)
    box.Size = UDim2.new(1, -20, 0, 32)
    box.Position = UDim2.fromOffset(10, 40)
    box.PlaceholderText = "Paste your key here"
    box.Text = ""
    box.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    box.TextColor3 = Color3.new(1, 1, 1)
    box.ClearTextOnFocus = false
    Instance.new("UICorner", box)

    local status = Instance.new("TextLabel", frame)
    status.Size = UDim2.new(1, -20, 0, 20)
    status.Position = UDim2.fromOffset(10, 76)
    status.BackgroundTransparency = 1
    status.Text = ""
    status.TextColor3 = Color3.fromRGB(255, 120, 120)
    status.TextSize = 13

    local function makeButton(text, x, cb)
        local b = Instance.new("TextButton", frame)
        b.Size = UDim2.new(0.5, -15, 0, 32)
        b.Position = UDim2.new(x, x == 0 and 10 or 5, 0, 110)
        b.Text = text
        b.BackgroundColor3 = Color3.fromRGB(60, 90, 200)
        b.TextColor3 = Color3.new(1, 1, 1)
        Instance.new("UICorner", b)
        b.MouseButton1Click:Connect(cb)
    end

    makeButton("Get Key", 0, function()
        if setclipboard then setclipboard(GET_KEY_LINK) end
        status.TextColor3 = Color3.fromRGB(120, 255, 120)
        status.Text = "Link copied! Paste it in your browser."
    end)

    makeButton("Check Key", 0.5, function()
        status.TextColor3 = Color3.fromRGB(255, 255, 120)
        status.Text = "Checking..."
        if validateToken(box.Text) then
            expiresAt = os.time() + KEY_LIFETIME
            saveKey()            -- <-- add this line
            passed = true
            gui:Destroy()
        else
            status.TextColor3 = Color3.fromRGB(255, 120, 120)
            status.Text = "Invalid or expired key."
        end
    end)

    repeat task.wait() until passed
end

----------------------------------------------------
-- SECTION 5: THE GATE (runs once, before anything loads)
----------------------------------------------------
if os.time() >= expiresAt then
    promptForKey()
end

if os.time() >= expiresAt then
    warn("[KeyGate] No valid key, stopping.")
    return
end

----------------------------------------------------
-- SECTION 6: SNAPSHOT WHAT'S ON SCREEN BEFORE YOUR UI LOADS
----------------------------------------------------
local before = {}
for _, container in ipairs(getContainers()) do
    for _, v in ipairs(container:GetChildren()) do
        before[v] = true
    end
end

----------------------------------------------------
-- SECTION 7: YOUR UI
----------------------------------------------------

local LOGIC_URL = "https://raw.githubusercontent.com/Fries-dev/LizardWareRLBX/refs/heads/main/Logic.lua"

local function loadLogic()
    -- Remote first; falls back to a local copy in your executor's workspace folder.
    local ok, source = pcall(function()
        return game:HttpGet(LOGIC_URL)
    end)
    if not ok or type(source) ~= "string" or #source == 0 then
        if readfile and isfile and isfile("Logic.lua") then
            source = readfile("Logic.lua")
        else
            error("Could not load Logic.lua (HttpGet failed and no local copy found)")
        end
    end

    local chunk, err = loadstring(source)
    if not chunk then
        error("Logic.lua failed to compile: " .. tostring(err))
    end
    return chunk()
end

local Logic = loadLogic()

local library = loadstring(game:GetObjects("rbxassetid://7657867786")[1].Source)()

----------
-- Window + tabs
----------
local PepsisWorld = library:CreateWindow({
    Name = "LizardWare",
    Themeable = {
        Info = ""
    },
    Theme = [[{"__Designer.Colors.topGradient":"000000","__Designer.Colors.section":"FFFFFF","__Designer.Colors.hoveredOptionBottom":"FFFFFF","__Designer.Background.ImageAssetID":"rbxassetid://4427304036","__Designer.Colors.selectedOption":"000000","__Designer.Colors.unselectedOption":"000000","__Designer.Files.WorkspaceFile":"LizardWare","__Designer.Colors.unhoveredOptionTop":"000000","__Designer.Colors.outerBorder":"FFFFFF","__Designer.Background.ImageColor":"000000","__Designer.Colors.tabText":"FFFFFF","__Designer.Colors.elementBorder":"383838","__Designer.Background.ImageTransparency":0,"__Designer.Colors.innerBorder":"000000","__Designer.Colors.sectionBackground":"000000","__Designer.Colors.bottomGradient":"000000","__Designer.Colors.background":"000000","__Designer.Colors.main":"FFFFFF","__Designer.Colors.otherElementText":"E6E6E6","__Designer.Colors.hoveredOptionTop":"FFFFFF","__Designer.Colors.elementText":"FFFFFF","__Designer.Colors.unhoveredOptionBottom":"000000","__Designer.Background.UseBackgroundImage":false}]]
})

local GeneralTab = PepsisWorld:CreateTab({ Name = "General" })
local WorldTab   = PepsisWorld:CreateTab({ Name = "World" })
local PlayersTab = PepsisWorld:CreateTab({ Name = "Players" })
local AimTab     = PepsisWorld:CreateTab({ Name = "Aim" })

local ScriptSection        = GeneralTab:CreateSection({ Name = "Script" })
local Boulder              = GeneralTab:CreateSection({ Name = "Holder" })
local WorldSection         = WorldTab:CreateSection({ Name = "World" })
local WorldSettingsSection = WorldTab:CreateSection({ Name = "Settings" })
local PlayerEspSection     = PlayersTab:CreateSection({ Name = "Player ESP" })
local AimSection           = AimTab:CreateSection({ Name = "Soldier Aim Lock" })
local PlayerAimSection     = AimTab:CreateSection({ Name = "Player Aim Lock" })
local PredictionSection    = AimTab:CreateSection({ Name = "Prediction" })
local WeaponSection        = AimTab:CreateSection({ Name = "Weapon" })


----------
-- General
----------
ScriptSection:AddButton({
    Name = "Disable Script",
    Callback = function()
        Logic.disableAll()
    end
})

Boulder:AddToggle({
    Name = "See Holder",
    Flag = "Boulder_Holder",
    Value = false,
    Callback = function(enabled)
        Logic.setTrackerEnabled(enabled)
    end
})

----------
-- World
----------
local worldToggles = {
    { "Show Nodes",              "Nodes_Toggle",         "Nodes" },
    { "Show Drops",              "Drops_Toggle",         "Drops" },
    { "Show Metal Crates",       "Metal_Crates_Toggle",  "Metal Crates" },
    { "Show Wooden Crates",      "Wooden_Crates_Toggle", "Wooden Crates" },
    { "Show Soldiers",           "Soldiers_Toggle",      "Soldiers" },
    { "Show Cloth",              "Cloth_Toggle",         "Cloth" },
}

for _, t in ipairs(worldToggles) do
    WorldSection:AddToggle({
        Name = t[1],
        Flag = t[2],
        Value = false,
        Callback = function(enabled)
            Logic.setWorldToggle(t[3], enabled)
        end
    })
end

WorldSection:AddToggle({
    Name = "Xray Base",
    Flag = "Xray_Base_Toggle",
    Value = false,
    Callback = function(enabled)
        Logic.setXray(enabled)
    end
})

WorldSettingsSection:AddToggle({
    Name = "Highlight World Items",
    Flag = "World_Highlight_Toggle",
    Value = false,
    Callback = function(enabled)
        Logic.setHighlightEnabled(enabled)
    end
})

local HighlightDropdown = WorldSettingsSection:AddDropdown({
    Name = "Highlight Which",
    Flag = "World_Highlight_Which",
    List = {"All", "Nodes", "Drops", "Metal Crates", "Wooden Crates", "Soldiers", "Cloth"},
    Multi = true,
    Callback = function(selected)
        Logic.setHighlightSelection(selected)
    end
})
HighlightDropdown:Set({"All"})

WorldSettingsSection:AddColorPicker({
    Name = "Highlight Color",
    Flag = "World_Highlight_Color",
    Value = Color3.fromRGB(0, 255, 200),
    Callback = function(color)
        Logic.setHighlightColor(color)
    end
})

WorldSettingsSection:AddSlider({
    Name = "Distance",
    Flag = "World_Distance",
    Value = 500,
    Min = 50,
    Max = 2000,
    Format = function(value)
        return "Distance: " .. tostring(value) .. " studs"
    end,
    Callback = function(value)
        Logic.setDistance(value)
    end
})

WorldSettingsSection:AddSlider({
    Name = "Xray Transparency",
    Flag = "Xray_Transparency",
    Value = 70,
    Min = 0,
    Max = 100,
    Format = function(value)
        return "Xray: " .. tostring(value) .. "%"
    end,
    Callback = function(value)
        Logic.setXrayTransparency(value / 100)
    end
})

----------
-- Aim: soldiers
----------
AimSection:AddToggle({
    Name = "Aim Lock Soldiers (Hold Right Click)",
    Flag = "Aim_Lock_Toggle",
    Value = false,
    Callback = function(enabled)
        Logic.setAimLock(enabled)
    end
})

AimSection:AddToggle({
    Name = "Show FOV Circle",
    Flag = "Fov_Circle_Toggle",
    Value = false,
    Callback = function(enabled)
        Logic.setFovCircle(enabled)
    end
})

AimSection:AddDropdown({
    Name = "Soldier Aim Part",
    Flag = "Aim_Part",
    List = {"Head", "Chest", "Waist"},
    Value = "Head",
    Multi = false,
    Callback = function(selected)
        Logic.setSoldierAimPart(selected)
    end
})

AimSection:AddSlider({
    Name = "FOV Radius",
    Flag = "Aim_Fov",
    Value = 150,
    Min = 20,
    Max = 600,
    Format = function(value)
        return "FOV: " .. tostring(value) .. " px"
    end,
    Callback = function(value)
        Logic.setFov(value)
    end
})

AimSection:AddSlider({
    Name = "Smoothness",
    Flag = "Aim_Smoothness",
    Value = 20,
    Min = 0,
    Max = 95,
    Format = function(value)
        return "Smoothness: " .. tostring(value)
    end,
    Callback = function(value)
        Logic.setSmoothness(value)
    end
})
----------
-- Camera: FOV + zoom
----------
AimSection:AddToggle({
    Name = "FOV Changer",
    Flag = "Fov_Changer_Toggle",
    Value = false,
    Callback = function(enabled)
        Logic.setFovChanger(enabled)
    end
})
----------
-- Movement
----------
PlayerEspSection:AddToggle({
    Name = "Walk Speed",
    Flag = "Speed_Toggle",
    Value = false,
    Callback = function(enabled)
        Logic.setSpeed(enabled)
    end
})

PlayerEspSection:AddSlider({
    Name = "Walk Speed Value",
    Flag = "Speed_Value",
    Value = 32,
    Min = 16,
    Max = 150,
    Format = function(value)
        return "Speed: " .. tostring(value)
    end,
    Callback = function(value)
        Logic.setWalkSpeed(value)
    end
})

PlayerEspSection:AddToggle({
    Name = "Infinite Jump",
    Flag = "Inf_Jump_Toggle",
    Value = false,
    Callback = function(enabled)
        Logic.setInfiniteJump(enabled)
    end
})

PlayerEspSection:AddToggle({
    Name = "Fly (WASD, Space up, Ctrl/Shift down)",
    Flag = "Fly_Toggle",
    Value = false,
    Callback = function(enabled)
        Logic.setFly(enabled)
    end
})

PlayerEspSection:AddSlider({
    Name = "Fly Speed",
    Flag = "Fly_Speed",
    Value = 60,
    Min = 10,
    Max = 300,
    Format = function(value)
        return "Fly: " .. tostring(value)
    end,
    Callback = function(value)
        Logic.setFlySpeed(value)
    end
})

----------
-- Visuals
----------
WorldSettingsSection:AddToggle({
    Name = "Fullbright (No Fog)",
    Flag = "Fullbright_Toggle",
    Value = false,
    Callback = function(enabled)
        Logic.setFullbright(enabled)
    end
})
PlayerEspSection:AddToggle({
    Name = "Noclip",
    Flag = "Noclip_Toggle",
    Value = false,
    Callback = function(enabled)
        Logic.setNoclip(enabled)
    end
})
AimSection:AddSlider({
    Name = "Camera FOV",
    Flag = "Camera_Fov",
    Value = 70,
    Min = 30,
    Max = 400,
    Format = function(value)
        return "FOV: " .. tostring(value)
    end,
    Callback = function(value)
        Logic.setCustomFov(value)
    end
})

AimSection:AddToggle({
    Name = "Zoom",
    Flag = "Zoom_Toggle",
    Value = false,
    Callback = function(enabled)
        Logic.setZoomEnabled(enabled)
    end
})

AimSection:AddDropdown({
    Name = "Zoom Mode",
    Flag = "Zoom_Mode",
    List = {"Hold", "Toggle"},
    Value = "Hold",
    Multi = false,
    Callback = function(selected)
        Logic.setZoomMode(selected)
    end
})

AimSection:AddDropdown({
    Name = "Zoom Key",
    Flag = "Zoom_Key",
    List = {"Z", "X", "C", "V", "B", "Q", "E", "F", "G", "LeftAlt"},
    Value = "Z",
    Multi = false,
    Callback = function(selected)
        Logic.setZoomKey(selected)
    end
})

AimSection:AddSlider({
    Name = "Zoom FOV",
    Flag = "Zoom_Fov",
    Value = 20,
    Min = -100,
    Max = 60,
    Format = function(value)
        return "Zoom FOV: " .. tostring(value)
    end,
    Callback = function(value)
        Logic.setZoomFov(value)
    end
})
----------
-- Aim: players
----------
PlayerAimSection:AddToggle({
    Name = "Aim Lock Players (Hold Right Click)",
    Flag = "Player_Aim_Lock_Toggle",
    Value = false,
    Callback = function(enabled)
        Logic.setPlayerAim(enabled)
    end
})

PlayerAimSection:AddDropdown({
    Name = "Player Aim Part",
    Flag = "Player_Aim_Part",
    List = {"Head", "Chest", "Waist"},
    Value = "Head",
    Multi = false,
    Callback = function(selected)
        Logic.setPlayerAimPart(selected)
    end
})

----------
-- Players ESP
----------
PlayerEspSection:AddToggle({
    Name = "Player Corner Box ESP",
    Flag = "Player_Esp_Toggle",
    Value = false,
    Callback = function(enabled)
        Logic.setPlayerBox(enabled)
    end
})

PlayerEspSection:AddToggle({
    Name = "Soldier Corner Box ESP",
    Flag = "Soldier_Esp_Toggle",
    Value = false,
    Callback = function(enabled)
        Logic.setSoldierBox(enabled)
    end
})

PlayerEspSection:AddSlider({
    Name = "Box Y Offset",
    Flag = "Box_Y_Offset",
    Value = 0,
    Min = -60,
    Max = 60,
    Format = function(value)
        return "Y Offset: " .. tostring(value) .. " px"
    end,
    Callback = function(value)
        Logic.setBoxYOffset(value)
    end
})
PlayerEspSection:AddToggle({
    Name = "Visibility Check (Green = Visible, Red = Hidden)",
    Flag = "Vis_Check_Toggle",
    Value = true,
    Callback = function(enabled)
        Logic.setVisibilityCheck(enabled)
    end
})

PlayerEspSection:AddColorPicker({
    Name = "Visible Color",
    Flag = "Vis_Color_Visible",
    Value = Color3.fromRGB(0, 255, 80),
    Callback = function(color)
        Logic.setVisibleColor(color)
    end
})

PlayerEspSection:AddColorPicker({
    Name = "Hidden Color",
    Flag = "Vis_Color_Hidden",
    Value = Color3.fromRGB(255, 40, 40),
    Callback = function(color)
        Logic.setHiddenColor(color)
    end
})
PlayerEspSection:AddToggle({
    Name = "Team Check (ESP + Aim)",
    Flag = "Team_Check_Toggle",
    Value = false,
    Callback = function(enabled)
        Logic.setTeamCheck(enabled)
    end
})

----------
-- Prediction
----------
PredictionSection:AddToggle({
    Name = "Prediction (Lead + Bullet Drop)",
    Flag = "Prediction_Toggle",
    Value = false,
    Callback = function(enabled)
        Logic.setPrediction(enabled)
    end
})

PredictionSection:AddSlider({
    Name = "Bullet Speed",
    Flag = "Bullet_Speed",
    Value = 1000,
    Min = 50,
    Max = 5000,
    Format = function(value)
        return "Speed: " .. tostring(value) .. " studs/s"
    end,
    Callback = function(value)
        Logic.setBulletSpeed(value)
    end
})

PredictionSection:AddSlider({
    Name = "Bullet Drop",
    Flag = "Bullet_Drop",
    Value = 0,
    Min = 0,
    Max = 400,
    Format = function(value)
        return "Drop: " .. tostring(value) .. " (0 = off)"
    end,
    Callback = function(value)
        Logic.setBulletDrop(value)
    end
})

----------------------------------------------------
-- SECTION 8: UNLOAD EVERYTHING WHEN THE KEY EXPIRES
----------------------------------------------------
local function unloadAll()
    -- Try the library's own unload methods first, if it has any
    for _, name in ipairs({ "Unload", "Destroy", "Close" }) do
        if type(library) == "table" and type(library[name]) == "function" then
            pcall(library[name], library)
        end
    end
    -- Then remove every GUI that appeared after the snapshot
    for _, container in ipairs(getContainers()) do
        for _, v in ipairs(container:GetChildren()) do
            if not before[v] then
                pcall(function() v:Destroy() end)
            end
        end
    end
    warn("[KeyGate] Key expired. UI unloaded. Re-run the script to get a new key.")
end
----------------------------------------------------
-- SECTION 8: NOTIFICATIONS + UNLOAD WHEN THE KEY EXPIRES
----------------------------------------------------
local TweenService = game:GetService("TweenService")

local function notify(titleText, bodyText, duration, color)
    duration = duration or 6
    color = color or Color3.fromRGB(255, 90, 90)

    local gui = Instance.new("ScreenGui")
    gui.Name = "LizardWareNotify"
    gui.ResetOnSpawn = false
    gui.Parent = guiParent

    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.fromOffset(300, 80)
    frame.Position = UDim2.new(1, 320, 1, -100)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    frame.BorderSizePixel = 0
    Instance.new("UICorner", frame)

    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = color
    stroke.Thickness = 1.5

    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, -20, 0, 28)
    title.Position = UDim2.fromOffset(10, 6)
    title.BackgroundTransparency = 1
    title.Text = titleText
    title.TextColor3 = color
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left

    local body = Instance.new("TextLabel", frame)
    body.Size = UDim2.new(1, -20, 0, 40)
    body.Position = UDim2.fromOffset(10, 34)
    body.BackgroundTransparency = 1
    body.Text = bodyText
    body.TextColor3 = Color3.new(1, 1, 1)
    body.Font = Enum.Font.Gotham
    body.TextSize = 13
    body.TextWrapped = true
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.TextYAlignment = Enum.TextYAlignment.Top

    TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(1, -320, 1, -100)
    }):Play()

    task.delay(duration, function()
        local out = TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(1, 320, 1, -100)
        })
        out:Play()
        out.Completed:Wait()
        gui:Destroy()
    end)
end

-- Turns seconds into text like "5 hours", "30 minutes" or "10 seconds"
local function formatTime(seconds)
    if seconds >= 3600 then
        return string.format("%.1f hours", seconds / 3600)
    elseif seconds >= 60 then
        return math.floor(seconds / 60) .. " minutes"
    end
    return math.floor(seconds) .. " seconds"
end

local function unloadAll()
    for _, name in ipairs({ "Unload", "Destroy", "Close" }) do
        if type(library) == "table" and type(library[name]) == "function" then
            pcall(library[name], library)
        end
    end
    for _, container in ipairs(getContainers()) do
        for _, v in ipairs(container:GetChildren()) do
            if not before[v] then
                pcall(function() v:Destroy() end)
            end
        end
    end
    -- Notification goes AFTER the cleanup so it isn't destroyed with the rest
    notify("Key Expired", "Your key has run out. Re-run the script to get a new one.", 8)
end

-- Halfway warning
task.spawn(function()
    local warnAt = expiresAt - (KEY_LIFETIME / 2)
    if warnAt > os.time() then
        while os.time() < warnAt do task.wait(1) end
        local left = expiresAt - os.time()
        notify("Key Expiring", "Your key expires in " .. formatTime(left) .. ".", 6, Color3.fromRGB(255, 200, 80))
    end
end)

-- Expiry
task.spawn(function()
    while os.time() < expiresAt do
        task.wait(1)
    end
    Logic.disableAll()
    unloadAll()
end)