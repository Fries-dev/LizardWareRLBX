-- Main.lua
-- Atlanta UI for Pepsi's World. All behaviour lives in Logic.lua; this file only builds the menu.

local library, themes = loadstring(game:HttpGet("https://raw.githubusercontent.com/i77lhm/Libraries/refs/heads/main/Atlanta/Library.lua"))()

-- Load Logic.lua: from the executor workspace folder if present, otherwise from your own URL
local LOGIC_URL = "https://raw.githubusercontent.com/Fries-dev/LizardWareRLBX/refs/heads/main/Logic.lua"
local Logic
if isfile and readfile and isfile("Logic.lua") then
    Logic = loadstring(readfile("Logic.lua"))()
elseif LOGIC_URL ~= "" then
    Logic = loadstring(game:HttpGet(LOGIC_URL))()
else
    error("Logic.lua not found. Put it in your executor's workspace folder or set LOGIC_URL.")
end

local dim2 = UDim2.new
local hex = Color3.fromHex

-- Window setup with optimized dimensions to prevent vertical overflow
local window = library:window({name = "Pepsi's World", size = dim2(0, 750, 0, 550)})

local Aiming   = window:tab({name = "Aiming"})
local Visuals  = window:tab({name = "Visuals"})
local World    = window:tab({name = "World"})
local Movement = window:tab({name = "Movement"})
local Misc     = window:tab({name = "Misc"})

------------------------------------------------------------
-- Aiming
------------------------------------------------------------
do
    local column = Aiming:column()
    local soldier, player = column:multi_section({names = {"Soldier Aim", "Player Aim"}})

    soldier:toggle({name = "Enabled", flag = "soldier_aim", callback = Logic.setAimLock})
    soldier:dropdown({name = "Aim Part", flag = "soldier_aim_part", items = {"Head", "Chest", "Waist"}, default = "Head", callback = Logic.setSoldierAimPart})

    player:toggle({name = "Enabled", flag = "player_aim", callback = Logic.setPlayerAim})
    player:dropdown({name = "Aim Part", flag = "player_aim_part", items = {"Head", "Chest", "Waist"}, default = "Head", callback = Logic.setPlayerAimPart})
    player:toggle({name = "Team Check", flag = "team_check", callback = Logic.setTeamCheck})

    local column2 = Aiming:column()
    local settings, prediction = column2:multi_section({names = {"Settings", "Prediction"}})

    settings:toggle({name = "Show FOV Circle", flag = "fov_circle", tooltip = "Hold right click to aim", callback = Logic.setFovCircle})
    settings:slider({name = "FOV", flag = "aim_fov", min = 10, max = 800, default = 150, interval = 1, callback = Logic.setFov})
    settings:slider({name = "Smoothness", flag = "aim_smooth", min = 0, max = 99, default = 20, interval = 1, suffix = "%", callback = Logic.setSmoothness})

    prediction:toggle({name = "Enabled", flag = "prediction", callback = Logic.setPrediction})
    prediction:slider({name = "Bullet Speed", flag = "bullet_speed", min = 50, max = 5000, default = 1000, interval = 10, callback = Logic.setBulletSpeed})
    prediction:slider({name = "Bullet Drop", flag = "bullet_drop", min = 0, max = 200, default = 0, interval = 1, callback = Logic.setBulletDrop})
end

------------------------------------------------------------
-- Visuals (player ScreenGui ESP + soldier Drawing boxes + preview)
------------------------------------------------------------
do
    local column = Visuals:column()

    -- Soldier boxes still use the old Drawing corner system
    local box = column:section({name = "Soldier Box ESP", toggle = false})
    box:toggle({name = "Soldier Boxes", flag = "soldier_box", callback = Logic.setSoldierBox})
    box:slider({name = "Box Y Offset", flag = "box_y_offset", min = -50, max = 50, default = 0, interval = 1, suffix = "px", callback = Logic.setBoxYOffset})

    local vis = column:section({name = "Visibility Check", toggle = false})
    vis:toggle({name = "Enabled", flag = "vis_check", default = true, tooltip = "Green = visible, red = behind a wall (soldiers)", callback = Logic.setVisibilityCheck})
    vis:toggle({name = "Visible Color", flag = "vis_color_toggle"})
        :colorpicker({name = "Visible", flag = "visible_color", color = Color3.fromRGB(0, 255, 80), callback = Logic.setVisibleColor})
    vis:toggle({name = "Hidden Color", flag = "hid_color_toggle"})
        :colorpicker({name = "Hidden", flag = "hidden_color", color = Color3.fromRGB(255, 40, 40), callback = Logic.setHiddenColor})

    local column2 = Visuals:column()
    local preview

    -- Push Atlanta flags into the real player ESP + refresh preview
    local function refresh()
        if preview then
            pcall(function() preview.refresh_elements() end)
        end

        if Logic.refreshEspFlags then
            local flags = library.flags or {}
            local function col(flag, fallback)
                local v = flags[flag]
                if typeof(v) == "Color3" then return v end
                if type(v) == "table" and typeof(v.Color) == "Color3" then return v.Color end
                return fallback
            end

            Logic.refreshEspFlags({
                Enabled         = flags["Enabled"] ~= false, -- master on/off from "Show Preview" / Enabled
                Names           = flags["Names"] ~= false,
                Name_Color      = { Color = col("Name_Color", Color3.fromRGB(255, 255, 255)) },
                Boxes           = flags["Boxes"] ~= false,
                Box_Type        = (flags["Box_Type"] == "Box" and "Normal") or (flags["Box_Type"] or "Corner"),
                Box_Color       = { Color = col("Box_Color", Color3.fromRGB(255, 255, 255)) },
                Healthbar       = flags["Healthbar"] ~= false,
                Health_High     = { Color = col("Health_High", Color3.fromRGB(0, 255, 80)) },
                Health_Low      = { Color = col("Health_Low", Color3.fromRGB(255, 40, 40)) },
                Distance        = flags["Distance"] ~= false,
                Distance_Color  = { Color = col("Distance_Color", Color3.fromRGB(255, 255, 255)) },
                Weapon          = flags["Weapon"] ~= false,
                Weapon_Color    = { Color = col("Weapon_Color", Color3.fromRGB(255, 255, 255)) },
                Skeletons       = flags["Skeletons"] == true,
                Skeletons_Color = { Color = col("Skeletons_Color", Color3.fromRGB(255, 255, 255)) },
            })
        end
    end

    local player = game.Players.LocalPlayer
    local function ensureAnimate(char)
        if char and not char:FindFirstChild("Animate") then
            local dummy = Instance.new("LocalScript")
            dummy.Name = "Animate"
            dummy.Parent = char
        end
    end
    if player.Character then
        ensureAnimate(player.Character)
    end
    player.CharacterAdded:Connect(ensureAnimate)

    local pv = column2:section({name = "Player ESP", toggle = false})

    -- These flags drive BOTH the library preview AND the live ScreenGui ESP
    pv:toggle({name = "Enabled", flag = "Enabled", enabled = true, default = true, callback = refresh})
    pv:toggle({name = "Boxes", flag = "Boxes", enabled = true, default = true, callback = refresh})
        :colorpicker({name = "Box", flag = "Box_Color", color = Color3.fromRGB(255, 255, 255), callback = refresh})
    pv:dropdown({name = "Box Type", flag = "Box_Type", items = {"Corner", "Box"}, default = "Corner", callback = refresh})
    pv:toggle({name = "Names", flag = "Names", enabled = true, default = true, callback = refresh})
        :colorpicker({name = "Name", flag = "Name_Color", color = Color3.fromRGB(255, 255, 255), callback = refresh})
    pv:toggle({name = "Healthbar", flag = "Healthbar", enabled = true, default = true, callback = refresh})
    pv:label({name = "Health Low"})
        :colorpicker({name = "Low", flag = "Health_Low", color = Color3.fromRGB(255, 40, 40), callback = refresh})
    pv:label({name = "Health High"})
        :colorpicker({name = "High", flag = "Health_High", color = Color3.fromRGB(0, 255, 80), callback = refresh})
    pv:toggle({name = "Distance", flag = "Distance", enabled = true, default = true, callback = refresh})
        :colorpicker({name = "Distance", flag = "Distance_Color", color = Color3.fromRGB(255, 255, 255), callback = refresh})
    pv:toggle({name = "Weapon", flag = "Weapon", enabled = true, default = true, callback = refresh})
        :colorpicker({name = "Weapon", flag = "Weapon_Color", color = Color3.fromRGB(255, 255, 255), callback = refresh})
    pv:toggle({name = "Skeletons", flag = "Skeletons", enabled = true, default = false, callback = refresh})
        :colorpicker({name = "Skeleton", flag = "Skeletons_Color", color = Color3.fromRGB(255, 255, 255), callback = refresh})

    local ok, result = pcall(function()
        return window.esp_section:esp_preview({})
    end)

    if ok and result then
        preview = result
        preview.items.viewportframe.Ambient = Color3.fromRGB(190, 190, 190)
        preview.items.viewportframe.LightColor = Color3.fromRGB(255, 255, 255)
        preview.refresh_elements()
    else
        warn("[Pepsi's World] ESP preview failed: " .. tostring(result))
    end

    -- Push defaults once UI is built
    task.defer(refresh)
end

------------------------------------------------------------
-- World ESP
------------------------------------------------------------
do
    local column = World:column()
    local esp = column:section({name = "World ESP", toggle = false})

    esp:toggle({name = "Nodes", flag = "esp_nodes", callback = function(v) Logic.setWorldToggle("Nodes", v) end})
    esp:toggle({name = "Drops", flag = "esp_drops", callback = function(v) Logic.setWorldToggle("Drops", v) end})
    esp:toggle({name = "Metal Crates", flag = "esp_metal", callback = function(v) Logic.setWorldToggle("Metal Crates", v) end})
    esp:toggle({name = "Wooden Crates", flag = "esp_wood", callback = function(v) Logic.setWorldToggle("Wooden Crates", v) end})
    esp:toggle({name = "Soldiers", flag = "esp_soldiers", callback = function(v) Logic.setWorldToggle("Soldiers", v) end})
    esp:toggle({name = "Cloth", flag = "esp_cloth", callback = function(v) Logic.setWorldToggle("Cloth", v) end})
    esp:slider({name = "Max Distance", flag = "world_distance", min = 50, max = 3000, default = 500, interval = 10, suffix = " studs", callback = Logic.setDistance})

    local column2 = World:column()
    local hl = column2:section({name = "Highlights", toggle = false})

    hl:toggle({name = "Enabled", flag = "hl_enabled", callback = Logic.setHighlightEnabled})
        :colorpicker({name = "Highlight Color", flag = "hl_color", color = Color3.fromRGB(0, 255, 200), callback = Logic.setHighlightColor})
    hl:dropdown({
        name = "Categories", flag = "hl_selection", multi = true, default = {"All"},
        items = {"All", "Nodes", "Drops", "Metal Crates", "Wooden Crates", "Soldiers", "Cloth"},
        callback = Logic.setHighlightSelection,
    })

    local xray = column2:section({name = "Base Xray", toggle = false})
    xray:toggle({name = "Enabled", flag = "xray", callback = Logic.setXray})
    xray:slider({name = "Transparency", flag = "xray_transparency", min = 0, max = 1, default = 0.7, interval = 0.05, callback = Logic.setXrayTransparency})
end

------------------------------------------------------------
-- Movement
------------------------------------------------------------
do
    local column = Movement:column()
    local move = column:section({name = "Movement", toggle = false})

    move:toggle({name = "Speed", flag = "speed", callback = Logic.setSpeed})
    move:slider({name = "Walk Speed", flag = "walk_speed", min = 16, max = 200, default = 32, interval = 1, callback = Logic.setWalkSpeed})
    move:toggle({name = "Infinite Jump", flag = "inf_jump", callback = Logic.setInfiniteJump})
    move:toggle({name = "Noclip", flag = "noclip", callback = Logic.setNoclip})
    move:toggle({name = "Fly", flag = "fly", tooltip = "WASD + Space up, Ctrl/Shift down", callback = Logic.setFly})
    move:slider({name = "Fly Speed", flag = "fly_speed", min = 10, max = 300, default = 60, interval = 1, callback = Logic.setFlySpeed})

    local column2 = Movement:column()
    local cam = column2:section({name = "Camera", toggle = false})

    cam:toggle({name = "FOV Changer", flag = "fov_changer", callback = Logic.setFovChanger})
    cam:slider({name = "Field Of View", flag = "custom_fov", min = -500, max = 320, default = 70, interval = 1, callback = Logic.setCustomFov})
    cam:toggle({name = "Zoom", flag = "zoom", callback = Logic.setZoomEnabled})
    cam:slider({name = "Zoom FOV", flag = "zoom_fov", min = -500, max = 320, default = 20, interval = 1, callback = Logic.setZoomFov})
    cam:dropdown({name = "Zoom Mode", flag = "zoom_mode", items = {"Hold", "Toggle"}, default = "Hold", callback = Logic.setZoomMode})
    cam:dropdown({name = "Zoom Key", flag = "zoom_key", items = {"Z", "X", "C", "V", "B", "Q", "E", "F"}, default = "Z", callback = Logic.setZoomKey})
end

------------------------------------------------------------
-- Misc
------------------------------------------------------------
do
    local column = Misc:column()
    local misc = column:section({name = "Misc", toggle = false})

    misc:toggle({name = "See Holder (prints to console)", flag = "see_holder", callback = Logic.setTrackerEnabled})
    misc:toggle({name = "Fullbright", flag = "fullbright", callback = Logic.setFullbright})
    misc:button({name = "Disable Script", callback = function()
        Logic.disableAll()
        if library.unload then
            library:unload()
        end
    end})
end

Aiming.open_tab()

------------------------------------------------------------
-- Initialisation
------------------------------------------------------------
library:config_list_update()

for index, value in themes.preset do
    pcall(function()
        library:update_theme(index, value)
    end)
end

task.wait()

library.old_config = library:get_config()