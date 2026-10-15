-- Main.lua
-- Players execute THIS file. It builds the UI and pulls everything else from Logic.lua.

-- Where Logic.lua is hosted (raw link, e.g. GitHub raw / pastebin raw). Edit this.
local LOGIC_URL = "https://raw.githubusercontent.com/YOURNAME/YOURREPO/main/Logic.lua"

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
    Name = "Pepsi's World",
    Themeable = {
        Info = "Discord Server: VzYTJ7Y"
    }
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
    { "Show Military Monuments", "Military_Toggle",      "Military Monuments" },
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
    List = {"All", "Nodes", "Drops", "Metal Crates", "Wooden Crates", "Military Monuments", "Soldiers", "Cloth"},
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