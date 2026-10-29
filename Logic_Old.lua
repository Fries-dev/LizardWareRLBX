

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
-- Visuals (corner box ESP + visibility check)
------------------------------------------------------------
do
    local column = Visuals:column()
    local box = column:section({name = "Corner Box ESP", toggle = false})

    box:toggle({name = "Player Boxes", flag = "player_box", callback = Logic.setPlayerBox})
    box:toggle({name = "Soldier Boxes", flag = "soldier_box", callback = Logic.setSoldierBox})
    box:slider({name = "Box Y Offset", flag = "box_y_offset", min = -50, max = 50, default = 0, interval = 1, suffix = "px", callback = Logic.setBoxYOffset})

    local vis = column:section({name = "Visibility Check", toggle = false})
    vis:toggle({name = "Enabled", flag = "vis_check", default = true, tooltip = "Green = visible, red = behind a wall", callback = Logic.setVisibilityCheck})
    vis:toggle({name = "Visible Color", flag = "vis_color_toggle"})
        :colorpicker({name = "Visible", flag = "visible_color", color = Color3.fromRGB(0, 255, 80), callback = Logic.setVisibleColor})
    vis:toggle({name = "Hidden Color", flag = "hid_color_toggle"})
        :colorpicker({name = "Hidden", flag = "hidden_color", color = Color3.fromRGB(255, 40, 40), callback = Logic.setHiddenColor})

    local column2 = Visuals:column()
    local preview
    local function refresh()
        if preview then preview.refresh_elements() end
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

    local pv = column2:section({name = "ESP Preview", toggle = false})

    pv:toggle({name = "Show Preview", flag = "Enabled", enabled = true, default = true, callback = refresh})
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

-- Logic.lua
-- All state + functions for Pepsi's World. Returns a table of setters that Main.lua calls from the UI.







































































































local Logic = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local localPlayer = Players.LocalPlayer

------------------
-- Vars
------------------
local xrayEnabled = false
local xrayTransparency = 0.7
local xrayParts = {}
local xrayConnection = nil
local xrayModelsOnly = false
local isTracking = false
local connections = {}
local lastPrintedState = {}

local nodeEspEnabled = false
local dropsEspEnabled = false
local metalCratesEspEnabled = false
local woodenCratesEspEnabled = false
local soldierEspEnabled = false
local clothEspEnabled = false
local worldHighlightEnabled = false
local highlightSelection = { All = true }
local worldMaxDistance = 500
local worldHighlightColor = Color3.fromRGB(0, 255, 200)
local activeWorldGuis = {}
local activeWorldHighlights = {}
local highlightCategories = {} -- [Highlight] = category name
local worldRenderConnection = nil
local worldDropScannerThread = nil
local worldCratesScannerThread = nil
local worldMilitaryScannerThread = nil
local worldSoldierScannerThread = nil
local worldClothScannerThread = nil

local aimLockEnabled = false
local fovCircleEnabled = false
local aimFov = 150
local aimSmoothness = 20
local aimHolding = false
local aimPartChoice = "Head"
local playerAimPartChoice = "Head"
local playerAimEnabled = false
local teamCheckEnabled = false
local aimBound = false
local fovCircle = nil
local soldierTargets = {}
local lastTargetScan = 0
local predictionEnabled = false
local bulletSpeed = 1000
local bulletGravity = 0

local playerBoxEnabled = false
local soldierBoxEnabled = false
local boxEspBound = false
local boxEspObjects = {}
local boxEspFrame = 0
local playerEspColor = Color3.fromRGB(255, 60, 60)
local soldierEspColor = Color3.fromRGB(255, 170, 0)
local cornerLength = 0.3
local boxYOffset = 0

-- Visibility check (green = visible, red = blocked)
local visibilityCheckEnabled = true
local visibleColor = Color3.fromRGB(0, 255, 80)
local hiddenColor = Color3.fromRGB(255, 40, 40)
local visCheckParts = { "Head", "UpperTorso", "Torso", "HumanoidRootPart" }
local visParams = RaycastParams.new()
visParams.FilterType = Enum.RaycastFilterType.Exclude
visParams.RespectCanCollide = true

-- Camera FOV changer + zoom
local fovChangerEnabled = false
local customFov = 70
local zoomEnabled = false
local zoomFov = 20
local zoomMode = "Hold" -- "Hold" or "Toggle"
local zoomKey = Enum.KeyCode.Z
local zoomActive = false
local cameraFovBound = false
local originalFov = nil

-- Movement + visuals extras
local Lighting = game:GetService("Lighting")

local speedEnabled = false
local walkSpeedValue = 32
local originalWalkSpeed = nil
local speedConnection = nil

local infJumpEnabled = false
local infJumpConnection = nil

local flyEnabled = false
local flySpeed = 60
local flyConnection = nil
local flyVelocity = nil
local flyGyro = nil

local fullbrightEnabled = false
local fullbrightConnection = nil
local lightingBackup = nil

-- Noclip
local noclipEnabled = false
local noclipConnection = nil
local noclipChanged = {} -- parts we turned CanCollide off on
local workspace = cloneref(game:GetService("Workspace"))
local run = cloneref(game:GetService("RunService"))
local http_service = cloneref(game:GetService("HttpService"))
local players = cloneref(game:GetService("Players"))

local vec2 = Vector2.new
local vec3 = Vector3.new
local dim2 = UDim2.new
local dim = UDim.new 
local rect = Rect.new
local cfr = CFrame.new
local empty_cfr = cfr()
local point_object_space = empty_cfr.PointToObjectSpace
local angle = CFrame.Angles
local dim_offset = UDim2.fromOffset

local color = Color3.new
local rgb = Color3.fromRGB
local hex = Color3.fromHex
local hsv = Color3.fromHSV
local rgbseq = ColorSequence.new
local rgbkey = ColorSequenceKeypoint.new
local numseq = NumberSequence.new
local numkey = NumberSequenceKeypoint.new

local camera = workspace.CurrentCamera

local bones = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"UpperTorso", "RightUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LowerTorso", "RightUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
}

local flags = { -- basically a substitute for ur ui flags (flags["wahdiuawdhwa"])
    ["Enabled"] = true;
    ["Names"] = true; 
    ["Name_Color"] = { Color = rgb(0, 255, 255) };
    ["Boxes"] = true;
    ["Box_Type"] = "Corner";
    ["Box_Color"] = { Color = rgb(0, 255, 0) };
    ["Healthbar"] = true; 
    ["Health_High"] = { Color = rgb(0, 255, 0) };
    ["Health_Low"] = { Color = rgb(255, 0, 0) };
    ["Distance"] = true;
    ["Weapon"] = true;
    ["Skeletons"] = true;
    ["Skeletons_Color"] = { Color = rgb(16, 0, 247) };
    ["Distance_Color"] = { Color = rgb(0, 255, 0) };
    ["Weapon_Color"] = { Color = rgb(0, 255, 255) }
}

local fonts = {}; do
    function Register_Font(Name, Weight, Style, Asset)
        if not isfile(Asset.Id) then
            writefile(Asset.Id, Asset.Font)
        end

        if isfile(Name .. ".font") then
            delfile(Name .. ".font")
        end

        local Data = {
            name = Name,
            faces = {
                {
                    name = "Normal",
                    weight = Weight,
                    style = Style,
                    assetId = getcustomasset(Asset.Id),
                },
            },
        }
        writefile(Name .. ".font", http_service:JSONEncode(Data))

        return getcustomasset(Name .. ".font");
    end
    
    local ProggyTiny = Register_Font("adwdawdwadadwadawdawdawdawd!", 100, "Normal", {
        Id = "ProggyTinyyyy.ttf",
        Font = game:HttpGet("https://github.com/i77lhm/storage/raw/refs/heads/main/fonts/ProggyTiny.ttf"),
    })

    fonts = {
        main = Font.new(ProggyTiny, Enum.FontWeight.Regular, Enum.FontStyle.Normal);
    }
end

local esp = { players = {}, screengui = Instance.new("ScreenGui", gethui()), cache = Instance.new("ScreenGui", gethui()), connections = {}}; do 
    esp.screengui.IgnoreGuiInset = true
    esp.screengui.Name = "\0"

    esp.cache.Enabled = false

    -- Functions 
        function esp:get_screen_pos(world_position)
            local viewport_size = camera.ViewportSize
            local local_position = camera.CFrame:pointToObjectSpace(world_position) 
            
            local aspect_ratio = viewport_size.x / viewport_size.y
            local half_height = -local_position.z * math.tan(math.rad(camera.FieldOfView / 2))
            local half_width = aspect_ratio * half_height
            
            local far_plane_corner = Vector3.new(-half_width, half_height, local_position.z)
            local relative_position = local_position - far_plane_corner
        
            local screen_x = relative_position.x / (half_width * 2)
            local screen_y = -relative_position.y / (half_height * 2)
        
            local is_on_screen = -local_position.z > 0 and screen_x >= 0 and screen_x <= 1 and screen_y >= 0 and screen_y <= 1
            
            -- returns in pixels as opposed to scale
            return Vector3.new(screen_x * viewport_size.x, screen_y * viewport_size.y, -local_position.z), is_on_screen
        end

        function esp:box_solve(torso)
            if not torso then
                return nil, nil, nil
            end
            
            local ViewportTop = torso.Position + (torso.CFrame.UpVector * 1.8) + camera.CFrame.UpVector
            local ViewportBottom = torso.Position - (torso.CFrame.UpVector * 2.5) - camera.CFrame.UpVector
            local Distance = (torso.Position - camera.CFrame.p).Magnitude

            local Top, TopIsRendered = esp:get_screen_pos(ViewportTop)
            local Bottom, BottomIsRendered = esp:get_screen_pos(ViewportBottom)

            local Width = math.max(math.floor(math.abs(Top.X - Bottom.X)), 3)
            local Height = math.max(math.floor(math.max(math.abs(Bottom.Y - Top.Y), Width / 2)), 3)
            local BoxSize = Vector2.new(math.floor(math.max(Height / 1.5, Width)), Height)
            local BoxPosition = Vector2.new(math.floor(Top.X * 0.5 + Bottom.X * 0.5 - BoxSize.X * 0.5), math.floor(math.min(Top.Y, Bottom.Y)))
            
            return BoxSize, BoxPosition, TopIsRendered, Distance
            
        end

        function esp:create(instance, options)
            local ins = Instance.new(instance) 
            
            for prop, value in options do 
                ins[prop] = value
            end
            
            return ins 
        end

        function esp:create_object( player )
            esp[ player.Name ] = { objects = { }, info = {character = character; humanoid = humanoid}; drawings = { }} 
            local data = esp[ player.Name ] 

            local objects = data.objects; do
                objects[ "holder" ] = esp:create( "Frame" , {
                    Parent = esp.screengui;
                    Name = "\0";
                    BackgroundTransparency = 1;
                    Position = dim2(0, 0, 0, 0);
                    BorderColor3 = rgb(0, 0, 0);
                    Size = dim2(0, 0, 0, 0);
                    BorderSizePixel = 0;
                    BackgroundColor3 = rgb(255, 255, 255)
                });
                
                objects[ "box_outline" ] = esp:create( "UIStroke" , {
                    Parent = (flags["Boxes"] and flags["Box_Type"] ~= "Corner" and objects["holder"]) or esp.cache;
                    LineJoinMode = Enum.LineJoinMode.Miter
                });
                
                objects[ "name" ] = esp:create( "TextLabel" , {
                    FontFace = fonts.main;
                    Parent = objects[ "holder" ];
                    TextColor3 = flags["Name_Color"].Color;
                    BorderColor3 = rgb(0, 0, 0);
                    Text = string.format("%s (@%s)", player.DisplayName, player.Name);
                    Name = "\0";
                    TextStrokeTransparency = 0;
                    AnchorPoint = vec2(0, 1);
                    Size = dim2(1, 0, 0, 0);
                    BackgroundTransparency = 1;
                    Position = dim2(0, 0, 0, -5);
                    BorderSizePixel = 0;
                    AutomaticSize = Enum.AutomaticSize.Y;
                    TextSize = 9;
                });
                
                objects[ "box_handler" ] = esp:create( "Frame" , {
                    Parent = (flags["Boxes"] and flags["Box_Type"] ~= "Corner" and objects["holder"]) or esp.cache;
                    Name = "\0";
                    BackgroundTransparency = 1;
                    Position = dim2(0, 1, 0, 1);
                    BorderColor3 = rgb(0, 0, 0);
                    Size = dim2(1, -2, 1, -2);
                    BorderSizePixel = 0;
                    BackgroundColor3 = rgb(255, 255, 255)
                });
                
                objects[ "box_color" ] = esp:create( "UIStroke" , {
                    Color = rgb(255, 255, 255);
                    LineJoinMode = Enum.LineJoinMode.Miter;
                    Name = "\0";
                    Parent = objects[ "box_handler" ]
                });
                
                objects[ "outline" ] = esp:create( "Frame" , {
                    Parent = objects[ "box_handler" ];
                    Name = "\0";
                    BackgroundTransparency = 1;
                    Position = dim2(0, 1, 0, 1);
                    BorderColor3 = rgb(0, 0, 0);
                    Size = dim2(1, -2, 1, -2);
                    BorderSizePixel = 0;
                    BackgroundColor3 = rgb(255, 255, 255)
                });
                
                esp:create( "UIStroke" , {
                    Parent = objects[ "outline" ];
                    LineJoinMode = Enum.LineJoinMode.Miter
                });  
                
                -- Corner Boxes
                    objects[ "corners" ] = esp:create( "Frame" , {
                        Visible = true;
                        BorderColor3 = rgb(0, 0, 0);
                        Parent = flags["Boxes"] and flags["Box_Type"] == "Corner" and objects["holder"] or esp.cache;
                        BackgroundTransparency = 1;
                        Position = dim2(0, -1, 0, 2);
                        Name = "\0";
                        Size = dim2(1, 0, 1, 0);
                        BorderSizePixel = 0;
                        BackgroundColor3 = rgb(255, 255, 255)
                    });

                    objects[ "1" ] = esp:create( "Frame" , {
                        Parent = objects[ "corners" ];
                        Name = "line";
                        Position = dim2(0, 0, 0, -2);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(0.4, 0, 0, 3);
                        BorderSizePixel = 0;
                        BackgroundColor3 = rgb(0, 0, 0)
                    });
                    
                    esp:create( "Frame" , {
                        Parent = objects[ "1" ];
                        Position = dim2(0, 1, 0, 1);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(1, -2, 1, -2);
                        BorderSizePixel = 0;
                        BackgroundColor3 = flags["Box_Color"].Color
                    });
                    
                    objects[ "2" ] = esp:create( "Frame" , {
                        Parent = objects[ "corners" ];
                        Name = "line";
                        Position = dim2(0, 0, 0, 1);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(0, 3, 0.25, 0);
                        BorderSizePixel = 0;
                        BackgroundColor3 = rgb(0, 0, 0)
                    });
                    
                    esp:create( "Frame" , {
                        Parent = objects[ "2" ];
                        Position = dim2(0, 1, 0, -2);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(1, -2, 1, 1);
                        BorderSizePixel = 0;
                        BackgroundColor3 = flags["Box_Color"].Color
                    });
                    
                    objects[ "3" ] = esp:create( "Frame" , {
                        AnchorPoint = vec2(1, 0);
                        Parent = objects[ "corners" ];
                        Name = "line";
                        Position = dim2(1, 0, 0, -2);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(0.4, 0, 0, 3);
                        BorderSizePixel = 0;
                        BackgroundColor3 = rgb(0, 0, 0)
                    });
                    
                    esp:create( "Frame" , {
                        Parent = objects[ "3" ];
                        Position = dim2(0, 1, 0, 1);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(1, -2, 1, -2);
                        BorderSizePixel = 0;
                        BackgroundColor3 = flags["Box_Color"].Color
                    });
                    
                    objects[ "4" ] = esp:create( "Frame" , {
                        AnchorPoint = vec2(1, 0);
                        Parent = objects[ "corners" ];
                        Name = "line";
                        Position = dim2(1, 0, 0, 1);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(0, 3, 0.25, 0);
                        BorderSizePixel = 0;
                        BackgroundColor3 = rgb(0, 0, 0)
                    });
                    
                    esp:create( "Frame" , {
                        Parent = objects[ "4" ];
                        Position = dim2(0, 1, 0, -2);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(1, -2, 1, 1);
                        BorderSizePixel = 0;
                        BackgroundColor3 = flags["Box_Color"].Color
                    });
                    
                    objects[ "5" ] = esp:create( "Frame" , {
                        AnchorPoint = vec2(0, 1);
                        Parent = objects[ "corners" ];
                        Name = "line";
                        Position = dim2(0, 0, 1, -2);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(0.4, 0, 0, 3);
                        BorderSizePixel = 0;
                        BackgroundColor3 = rgb(0, 0, 0)
                    });
                    
                    esp:create( "Frame" , {
                        Parent = objects[ "5" ];
                        Position = dim2(0, 1, 0, 1);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(1, -2, 1, -2);
                        BorderSizePixel = 0;
                        BackgroundColor3 = flags["Box_Color"].Color
                    });
                    
                    objects[ "6" ] = esp:create( "Frame" , {
                        BorderColor3 = rgb(0, 0, 0);
                        Rotation = 180;
                        Parent = objects[ "corners" ];
                        Name = "line";
                        Position = dim2(0, 0, 1, -5);
                        AnchorPoint = vec2(0, 1);
                        Size = dim2(0, 3, 0.25, 0);
                        BorderSizePixel = 0;
                        BackgroundColor3 = rgb(0, 0, 0)
                    });
                    
                    esp:create( "Frame" , {
                        Parent = objects[ "6" ];
                        Position = dim2(0, 1, 0, -2);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(1, -2, 1, 1);
                        BorderSizePixel = 0;
                        BackgroundColor3 = flags["Box_Color"].Color
                    });
                    
                    objects[ "7" ] = esp:create( "Frame" , {
                        AnchorPoint = vec2(1, 1);
                        Parent = objects[ "corners" ];
                        Name = "line";
                        Position = dim2(1, 0, 1, -2);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(0.4, 0, 0, 3);
                        BorderSizePixel = 0;
                        BackgroundColor3 = rgb(0, 0, 0)
                    });
                    
                    esp:create( "Frame" , {
                        Parent = objects[ "7" ];
                        Position = dim2(0, 1, 0, 1);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(1, -2, 1, -2);
                        BorderSizePixel = 0;
                        BackgroundColor3 = flags["Box_Color"].Color
                    });
                    
                    objects[ "7" ] = esp:create( "Frame" , {
                        BorderColor3 = rgb(0, 0, 0);
                        Rotation = 180;
                        Parent = objects[ "corners" ];
                        Name = "line";
                        Position = dim2(1, 0, 1, -5);
                        AnchorPoint = vec2(1, 1);
                        Size = dim2(0, 3, 0.25, 0);
                        BorderSizePixel = 0;
                        BackgroundColor3 = rgb(0, 0, 0)
                    });
                    
                    esp:create( "Frame" , {
                        Parent = objects[ "7" ];
                        Position = dim2(0, 1, 0, -2);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(1, -2, 1, 1);
                        BorderSizePixel = 0;
                        BackgroundColor3 = flags["Box_Color"].Color
                    });
                -- 
                
                -- Healthbar
                    objects[ "healthbar_holder" ] = esp:create( "Frame" , {
                        AnchorPoint = vec2(1, 0);
                        Parent = flags["Healthbar"] and objects[ "holder" ] or esp.cache;
                        Name = "\0";
                        Position = dim2(0, -5, 0, -1);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(0, 4, 1, 2);
                        BorderSizePixel = 0;
                        BackgroundColor3 = rgb(0, 0, 0)
                    });
                    
                    objects[ "healthbar" ] = esp:create( "Frame" , {
                        Parent = objects[ "healthbar_holder" ];
                        Name = "\0";
                        Position = dim2(0, 1, 0, 1);
                        BorderColor3 = rgb(0, 0, 0);
                        Size = dim2(1, -2, 1, -2);
                        BorderSizePixel = 0;
                        BackgroundColor3 = rgb(255, 255, 255)
                    });
                -- 

                -- Distance esp
                    objects[ "distance" ] = esp:create( "TextLabel" , {
                        FontFace = fonts.main;
                        TextColor3 = flags["Distance_Color"].Color;
                        BorderColor3 = rgb(0, 0, 0);
                        Text = "127st";
                        Parent = flags[ "Distance" ] and objects[ "holder" ] or esp.cache;
                        TextStrokeTransparency = 0;
                        Name = "\0";
                        Size = dim2(1, 0, 0, 0);
                        BackgroundTransparency = 1;
                        Position = dim2(0, 0, 1, 5);
                        BorderSizePixel = 0;
                        AutomaticSize = Enum.AutomaticSize.Y;
                        TextSize = 9;
                    });                
                -- 

                -- Weapon esp
                    objects[ "weapon" ] = esp:create( "TextLabel" , {
                        FontFace = fonts.main;
                        TextColor3 = flags["Weapon_Color"].Color;
                        BorderColor3 = rgb(0, 0, 0);
                        Text = "[ak-47]";
                        Parent = esp.cache;
                        TextStrokeTransparency = 0;
                        Name = "\0";
                        Size = dim2(1, 0, 0, 0);
                        BackgroundTransparency = 1;
                        Position = dim2(0, 0, 1, 19);
                        BorderSizePixel = 0;
                        AutomaticSize = Enum.AutomaticSize.Y;
                        TextSize = 9;
                    });
                -- 
                
                -- Skeleton Lines
                    
                    for _, bone in bones do
                        local line = Drawing.new("Line")
                        line.Color = flags["Skeletons_Color"].Color;
                        line.Thickness = 1;
                        line.Visible = false;

                        data.drawings[#data.drawings + 1] = line;
                    end
                -- 
            end
            
            do --[[ data functions ]]
                data.health_changed = function( value )
                    if not flags[ "Healthbar" ] then 
                        return 
                    end

                    local selected_layout = objects[ player.Name ]
                    local humanoid = data.info.humanoid
                    
                    local multiplier = value / humanoid.MaxHealth
                    local color = flags[ "Health_Low" ].Color:Lerp( flags["Health_High"].Color, multiplier )
                    
                    objects[ "healthbar" ].Size = UDim2.new(1, -2, multiplier, -2)
                    objects[ "healthbar" ].Position = UDim2.new(0, 1, 1 - multiplier, 1)
                    objects[ "healthbar" ].BackgroundColor3 = color
                end

                data.tool_added = function( item )
                    if not item:IsA("Tool") then 
                        return 
                    end 

                    local exists = data.info.character:FindFirstChild(item.Name) 
                    print(exists, item.Name)
                    objects[ "weapon" ].Text = item.Name
                    objects[ "weapon" ].Parent = exists and objects[ "holder" ] or esp.cache
                end

                data.refresh_offsets = function()
                    local offset = 5; 

                    if objects["distance"].Parent == objects[ "holder" ] then 
                        offset += 5
                        objects[ "weapon" ].Position = dim2(0, 0, 1, offset)
                    end 

                    if objects[ "weapon" ].Parent == objects[ "holder" ] then 
                        offset += 5
                        objects[ "weapon" ].Position = dim2(0, 0, 1, offset)
                    end 
                end 

                data.refresh_descendants = function() 
                    local character = player.Character or player.CharacterAdded:Wait()
                    local humanoid = character:WaitForChild( "Humanoid" )
                    
                    data.info.character = character
                    data.info.humanoid = humanoid
                    data.info.rootpart = rootpart

                    humanoid.HealthChanged:Connect( data.health_changed )

                    character.ChildAdded:Connect( data.tool_added )
                    character.ChildRemoved:Connect( data.tool_added )

                    data.health_changed( data.info.humanoid.Health )
                end
            end 
            
            do --[[ init / connections ]]  
                data.refresh_descendants()

                data.health_changed( data.info.humanoid.Health )

                player.CharacterAdded:Connect( data.refresh_descendants )

                local tool = player.Character:FindFirstChildOfClass("Tool")

                if tool then
                    data.tool_added( tool )
                end 
            end 
        end

        function esp:remove_object(player)
            local holder = esp[player.Name]

            if not holder then return end 

            local objects = holder.objects
 
            for _, line in holder.drawings do 
                line:Remove()
            end
            
            objects[ "holder" ]:Destroy() 
            esp[player.Name] = nil
        end
        
        function esp.refresh_elements( )
            for _,v in players:GetPlayers() do 
                if v == players.LocalPlayer then 
                    continue
                end
                print("1")
                
                if not v.Character then 
                    continue 
                end 
                print("2")

                local path = esp[v.Name]
                local objects = path and path.objects
                
                if not objects then 
                    continue 
                end
                print("3")
                objects.holder.Parent = flags["Enabled"] and esp.screengui or esp.cache

                objects[ "name" ].Parent = flags["Names"] and objects["holder"] or esp.cache
                objects[ "name" ].TextColor3 = flags["Name_Color"].Color
                
                local is_corner = flags[ "Box_Type" ] == "Corner"

                if flags["Boxes"] then 
                    objects[ "corners" ].Parent = (is_corner and objects["holder"]) or esp.cache
                    objects[ "box_handler" ].Parent = (is_corner and esp.cache or objects[ "holder" ])
                    objects[ "box_outline" ].Parent = (is_corner and esp.cache or objects[ "holder" ]) 
                else
                    objects[ "corners" ].Parent =  esp.cache
                    objects[ "box_handler" ].Parent = esp.cache
                    objects[ "box_outline" ].Parent = esp.cache
                end 
                print("4")
                objects[ "box_color" ].Color = flags["Box_Color"].Color 

                for _, corner in objects[ "corners" ]:GetChildren() do
                    corner.Frame.BackgroundColor3 = flags["Box_Color"].Color
                end
                print("5")

                for _, line in path.drawings do
                    line.Color = flags["Skeletons_Color"].Color
                    line.Visible = flags["Skeletons"]
                end

                objects[ "healthbar_holder" ].Parent = flags[ "Healthbar" ] and objects[ "holder" ] or esp.cache
                print("6")
                objects[ "weapon" ].TextColor3 = flags["Weapon_Color"].Color
                objects[ "weapon" ].Parent = flags["Weapon"] and v.Character:FindFirstChildOfClass("Tool") and objects[ "holder" ] or esp.cache

                objects[ "distance" ].TextColor3 = flags["Distance_Color"].Color
                objects[ "distance" ].Parent = flags["Distance"] and objects[ "holder" ] or esp.cache
            end
        end

        esp.connection = run.RenderStepped:Connect(function()
            if not flags["Enabled"] then 
                return
            end

            for _, player in players:GetPlayers() do 
                local data = esp[player.Name]

                if not data then 
                    continue 
                end 

                local character = data.info.character
                local humanoid = data.info.humanoid 
                
                if not (character or humanoid) then 
                    continue 
                end 

                local objects = data and data.objects 

                if not objects then 
                    continue 
                end 

                local box_size, box_pos, on_screen, distance = esp:box_solve(humanoid.RootPart)
                local holder = objects[ "holder" ]

                if holder.Visible ~= on_screen then 
                    holder.Visible = on_screen
                end 

                -- Skeletons 
                    if flags["Skeletons"] and character:FindFirstChild("UpperTorso") then 
                        for i = 1, #bones do
                            local origin, destination = bones[i][1], bones[i][2]

                            if not data.drawings[i] then 
                                continue  
                            end 

                            local path = data.drawings[i]

                            local origin_3d = character:FindFirstChild(origin) 
                            local destination_3d = character:FindFirstChild(destination) 

                            if origin_3d and destination_3d then 
                                local origin_2d, on_screen_start = esp:get_screen_pos(origin_3d.Position)
                                local destination_2d, on_screen_end = esp:get_screen_pos(destination_3d.Position)
                                
                                if on_screen_start and on_screen_end then 
                                    path.Visible = true
                                    path.From = Vector2.new(origin_2d.X, origin_2d.Y)
                                    path.To = Vector2.new(destination_2d.X, destination_2d.Y)
                                else
                                    path.Visible = false
                                end 
                            end
                        end 
                    end 
                -- 

                if not on_screen then
                    continue
                end 
                
                local pos = dim_offset(box_pos.X, box_pos.Y) -- silly sanity check
                if pos ~= holder.Position then 
                    holder.Position = dim_offset(box_pos.X, box_pos.Y)
                end 

                local size = dim_offset(box_size.X, box_size.Y) -- more silly sanity checks
                if size ~= holder.Size then 
                    holder.Size = size
                end 

                local distance_label = objects[ "distance" ]
                if distance_label.Text ~= tostring( math.round(distance) )  .. "st" then 
                    distance_label.Text = tostring( math.round(distance) ) .. "st"
                end 

            end
        end)

        function esp:unload() 
            for _, player in players:GetPlayers() do 
                esp:remove_object(player)
            end 

            esp.connection:Disconnect() 
            esp.player_added:Disconnect() 
            esp.player_removed:Disconnect() 

            esp.cache:Destroy() 
            esp.screengui:Destroy()

            esp = nil
        end 
    -- 
end

for _,v in players:GetPlayers() do 
    if v ~= players.LocalPlayer then 
        esp:create_object(v)
    end 
end 

esp.player_added = players.PlayerAdded:Connect(function(v)
    esp:create_object(v)
end)

esp.player_removed = players.PlayerRemoving:Connect(function(v)
    esp:remove_object(v)
end)

flags = { -- basically a substitute for ur ui flags (flags["wahdiuawdhwa"])
    ["Enabled"] = true;
    ["Names"] = true; 
    ["Name_Color"] = { Color = rgb(255, 255, 255) };
    ["Boxes"] = true;
    ["Box_Type"] = "Normal";
    ["Box_Color"] = { Color = rgb(255, 255, 255) };
    ["Healthbar"] = true; 
    ["Health_High"] = { Color = rgb(0, 255, 0) };
    ["Health_Low"] = { Color = rgb(255, 0, 0) };
    ["Distance"] = true;
    ["Weapon"] = true;
    ["Skeletons"] = true;
    ["Skeletons_Color"] = { Color = rgb(255, 255, 255) };
    ["Distance_Color"] = { Color = rgb(255, 255, 255) };
    ["Weapon_Color"] = { Color = rgb(255, 255, 255) }
}; 
task.wait()
esp.refresh_elements()
local aimPartNames = {
    ["Head"] = {"Head"},
    ["Chest"] = {"UpperTorso", "Torso"},
    ["Waist"] = {"LowerTorso", "HumanoidRootPart"},
}

local cornerSigns = {}
for x = -1, 1, 2 do
    for y = -1, 1, 2 do
        for z = -1, 1, 2 do
            table.insert(cornerSigns, Vector3.new(x, y, z))
        end
    end
end

------------------
-- Input (hold right click to aim)
------------------
local inputBeganConn = UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        aimHolding = true
    end
end)
local inputEndedConn = UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        aimHolding = false
    end
end)

------------------
-- Visibility check
------------------
-- Returns true if a clear line of sight exists from the camera to any key body part of the model
local function isModelVisible(model, camera)
    if not model or not camera then return false end

    local myChar = localPlayer.Character
    visParams.FilterDescendantsInstances = myChar and { myChar } or {}

    local origin = camera.CFrame.Position
    for _, name in ipairs(visCheckParts) do
        local part = model:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            local result = workspace:Raycast(origin, part.Position - origin, visParams)
            -- Nothing in the way, or the first thing hit is the target itself
            if not result or result.Instance:IsDescendantOf(model) then
                return true
            end
        end
    end
    return false
end

------------------
-- Xray
------------------
local function getBase()
    local bases = workspace:FindFirstChild("Bases")
    return bases and bases:FindFirstChild("Base")
end

local function applyXray(obj)
    if obj:IsA("BasePart") then
        if xrayModelsOnly and not obj:FindFirstAncestorOfClass("Model") then
            return
        end
        xrayParts[obj] = true
        obj.LocalTransparencyModifier = xrayTransparency
    end
end

local function setXray(enabled)
    xrayEnabled = enabled

    if xrayConnection then
        xrayConnection:Disconnect()
        xrayConnection = nil
    end
    for part in pairs(xrayParts) do
        if part and part.Parent then
            part.LocalTransparencyModifier = 0
        end
    end
    xrayParts = {}

    if not enabled then return end

    local base = getBase()
    if not base then
        warn("Base not found at Workspace.Bases.Base")
        return
    end

    for _, obj in ipairs(base:GetDescendants()) do
        applyXray(obj)
    end

    xrayConnection = base.DescendantAdded:Connect(function(obj)
        if xrayEnabled then
            applyXray(obj)
        end
    end)
end

local function setXrayTransparency(value)
    xrayTransparency = value
    for part in pairs(xrayParts) do
        if part and part.Parent then
            part.LocalTransparencyModifier = xrayTransparency
        end
    end
end

------------------
-- Holder tracker
------------------
local function getHandledItems(character)
    local itemsFound = {}

    for _, descendant in ipairs(character:GetDescendants()) do
        local isUI = descendant:IsA("GuiObject") or descendant:IsA("LayerCollector") or descendant:IsA("GuiBase")

        if not isUI and (descendant:IsA("Tool") or descendant:IsA("Model") or descendant:IsA("Accoutrement")) then
            local handle = descendant:FindFirstChild("Handle", true) or descendant:FindFirstChild("handle", true)
            if handle and handle:IsA("BasePart") then
                table.insert(itemsFound, descendant.Name)
            end
        end
    end

    table.sort(itemsFound)
    return itemsFound
end

local function checkAndPrint(player, character)
    if not character or not character.Parent then return end

    local items = getHandledItems(character)
    local currentText = #items > 0 and table.concat(items, ", ") or "No handled items"

    if lastPrintedState[player] ~= currentText then
        lastPrintedState[player] = currentText
        print(string.format("[%s]: %s", player.Name, currentText))
    end
end

local function setupCharacterTracker(player, character)
    lastPrintedState[player] = nil

    local updateScheduled = false
    local function queueUpdate()
        if not updateScheduled and isTracking then
            updateScheduled = true
            task.defer(function()
                updateScheduled = false
                if isTracking then
                    checkAndPrint(player, character)
                end
            end)
        end
    end

    queueUpdate()

    table.insert(connections, character.DescendantAdded:Connect(queueUpdate))
    table.insert(connections, character.DescendantRemoving:Connect(queueUpdate))
end

local function setTrackerEnabled(enabled)
    isTracking = enabled

    if isTracking then
        print("--- See Holder: ENABLED ---")
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character then
                setupCharacterTracker(player, player.Character)
            end
            table.insert(connections, player.CharacterAdded:Connect(function(character)
                if isTracking then
                    setupCharacterTracker(player, character)
                end
            end))
        end

        table.insert(connections, Players.PlayerAdded:Connect(function(player)
            table.insert(connections, player.CharacterAdded:Connect(function(character)
                if isTracking then
                    setupCharacterTracker(player, character)
                end
            end))
        end))
    else
        print("--- See Holder: DISABLED ---")
        for _, conn in ipairs(connections) do
            conn:Disconnect()
        end
        connections = {}
        lastPrintedState = {}
    end
end

------------------
-- World ESP
------------------
local function getObjectPosition(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then
        return obj.Position
    elseif obj:IsA("Model") then
        if obj.PrimaryPart then
            return obj.PrimaryPart.Position
        else
            local part = obj:FindFirstChildWhichIsA("BasePart", true)
            if part then
                return part.Position
            end
        end
    end
    return nil
end

local function updateDistanceCheck()
    local char = localPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")

    if root then
        local rootPos = root.Position

        for _, gui in ipairs(activeWorldGuis) do
            if gui and gui.Parent and gui.Adornee then
                local pos = gui.Adornee.Position
                local dist = (rootPos - pos).Magnitude
                gui.Enabled = (dist <= worldMaxDistance)
            end
        end

        local camera = workspace.CurrentCamera

        for _, hl in ipairs(activeWorldHighlights) do
            if hl and hl.Parent and hl.Adornee then
                local pos = getObjectPosition(hl.Adornee)
                if pos then
                    local dist = (rootPos - pos).Magnitude
                    local inRange = dist <= worldMaxDistance
                    hl.Enabled = inRange

                    -- Soldier highlights turn green/red based on line of sight
                    if inRange and visibilityCheckEnabled and camera and highlightCategories[hl] == "Soldiers" then
                        hl.FillColor = isModelVisible(hl.Adornee, camera) and visibleColor or hiddenColor
                    end
                end
            end
        end
    end
end

local function cancelThread(thread)
    if thread then
        task.cancel(thread)
    end
    return nil
end

local function removeWorldEsp()
    for _, gui in ipairs(activeWorldGuis) do
        if gui and gui.Parent then
            gui:Destroy()
        end
    end
    activeWorldGuis = {}

    for _, hl in ipairs(activeWorldHighlights) do
        if hl and hl.Parent then
            hl:Destroy()
        end
    end
    activeWorldHighlights = {}
    highlightCategories = {}

    if worldRenderConnection then
        worldRenderConnection:Disconnect()
        worldRenderConnection = nil
    end

    worldDropScannerThread = cancelThread(worldDropScannerThread)
    worldCratesScannerThread = cancelThread(worldCratesScannerThread)
    worldMilitaryScannerThread = cancelThread(worldMilitaryScannerThread)
    worldSoldierScannerThread = cancelThread(worldSoldierScannerThread)
    worldClothScannerThread = cancelThread(worldClothScannerThread)
end

local function updateHighlightColors()
    for _, hl in ipairs(activeWorldHighlights) do
        if hl and hl.Parent then
            -- Soldier highlights are colored by the visibility check when it's on
            if not (visibilityCheckEnabled and highlightCategories[hl] == "Soldiers") then
                hl.FillColor = worldHighlightColor
            end
        end
    end
end

local function normalizeSelection(selected)
    local result = {}
    if type(selected) == "string" then
        result[selected] = true
    elseif type(selected) == "table" then
        for k, v in pairs(selected) do
            if type(k) == "number" and type(v) == "string" then
                result[v] = true
            elseif type(k) == "string" and v then
                result[k] = true
            end
        end
    end
    return result
end

local function shouldHighlight(category)
    if not worldHighlightEnabled then return false end
    if highlightSelection["All"] then return true end
    return category ~= nil and highlightSelection[category] == true
end

local function createWorldElements(item, customName, category)
    local primaryPart = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart", true)

    if primaryPart then
        if not item:FindFirstChild("WorldTextGui") then
            local billboard = Instance.new("BillboardGui")
            billboard.Name = "WorldTextGui"
            billboard.Size = UDim2.new(0, 150, 0, 40)
            billboard.StudsOffset = Vector3.new(0, 3, 0)
            billboard.AlwaysOnTop = true
            billboard.Adornee = primaryPart
            billboard.Parent = item

            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.Text = string.gsub(customName or item.Name, "_", " ")
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
            label.TextStrokeTransparency = 0
            label.TextSize = 15
            label.Font = Enum.Font.SourceSansBold
            label.Parent = billboard

            table.insert(activeWorldGuis, billboard)
        end

        if shouldHighlight(category) and not item:FindFirstChild("WorldHighlight") then
            local highlight = Instance.new("Highlight")
            highlight.Name = "WorldHighlight"
            highlight.Adornee = item
            highlight.FillColor = worldHighlightColor
            highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
            highlight.FillTransparency = 0.5
            highlight.OutlineTransparency = 0
            highlight.Parent = item

            table.insert(activeWorldHighlights, highlight)
            highlightCategories[highlight] = category
        end
    end
end

local function refreshWorldEsp()
    removeWorldEsp()

    if not nodeEspEnabled and not dropsEspEnabled and not metalCratesEspEnabled
        and not woodenCratesEspEnabled
        and not soldierEspEnabled and not clothEspEnabled then
        return
    end

    -- 1. Nodes
    if nodeEspEnabled then
        local nodes = workspace:FindFirstChild("Nodes", true)
        if nodes then
            for _, item in ipairs(nodes:GetChildren()) do
                createWorldElements(item, nil, "Nodes")
            end
        end
    end

    -- 2. Drops
    if dropsEspEnabled then
        worldDropScannerThread = task.spawn(function()
            while dropsEspEnabled do
                local dropsContainer = workspace:FindFirstChild("Drops", true)
                if dropsContainer then
                    for _, item in ipairs(dropsContainer:GetChildren()) do
                        createWorldElements(item, nil, "Drops")
                    end
                end
                task.wait(1)
            end
        end)
    end

    -- 3. Crates
    if metalCratesEspEnabled or woodenCratesEspEnabled then
        worldCratesScannerThread = task.spawn(function()
            while metalCratesEspEnabled or woodenCratesEspEnabled do
                for _, item in ipairs(workspace:GetDescendants()) do
                    if item:IsA("Model") or item:IsA("BasePart") then
                        local nameLower = string.lower(item.Name)
                        if metalCratesEspEnabled and string.find(nameLower, "metal") and string.find(nameLower, "crate") then
                            createWorldElements(item, nil, "Metal Crates")
                        end
                        if woodenCratesEspEnabled and (string.find(nameLower, "wood") or string.find(nameLower, "wooden")) and string.find(nameLower, "crate") then
                            createWorldElements(item, nil, "Wooden Crates")
                        end
                    end
                end
                task.wait(2)
            end
        end)
    end



    -- 5. Soldiers
    if soldierEspEnabled then
        worldSoldierScannerThread = task.spawn(function()
            while soldierEspEnabled do
                for _, item in ipairs(workspace:GetDescendants()) do
                    if item:IsA("Humanoid") then
                        local parentModel = item.Parent
                        if parentModel and string.find(string.lower(parentModel.Name), "soldier") then
                            createWorldElements(parentModel, nil, "Soldiers")
                        end
                    end
                end
                task.wait(1.5)
            end
        end)
    end

    -- 6. Cloth (inside Plants)
    if clothEspEnabled then
        worldClothScannerThread = task.spawn(function()
            while clothEspEnabled do
                local plants = workspace:FindFirstChild("Plants", true)
                if plants then
                    for _, item in ipairs(plants:GetDescendants()) do
                        if item:IsA("Model") or item:IsA("BasePart") then
                            if string.find(string.lower(item.Name), "cloth") then
                                createWorldElements(item, "Cloth", "Cloth")
                            end
                        end
                    end
                end
                task.wait(1.5)
            end
        end)
    end

    updateDistanceCheck()
    worldRenderConnection = RunService.RenderStepped:Connect(updateDistanceCheck)
end

------------------
-- Aim system
------------------
local function getFovCircle()
    if not fovCircle and Drawing then
        fovCircle = Drawing.new("Circle")
        fovCircle.Thickness = 1.5
        fovCircle.NumSides = 64
        fovCircle.Filled = false
        fovCircle.Color = Color3.fromRGB(255, 255, 255)
        fovCircle.Transparency = 1
        fovCircle.Visible = false
    end
    return fovCircle
end

local function scanSoldiers()
    soldierTargets = {}
    for _, item in ipairs(workspace:GetDescendants()) do
        if item:IsA("Humanoid") then
            local model = item.Parent
            if model and string.find(string.lower(model.Name), "soldier") then
                table.insert(soldierTargets, item)
            end
        end
    end
end

local function getAimPart(model, choice)
    local names = aimPartNames[choice] or aimPartNames["Head"]
    for _, name in ipairs(names) do
        local part = model:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            return part
        end
    end
    return model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart", true)
end

local function getClosestSoldier(center, camera)
    local bestPart = nil
    local bestDist = aimFov

    for _, hum in ipairs(soldierTargets) do
        local model = hum.Parent
        if model and hum.Health > 0 then
            local part = getAimPart(model, aimPartChoice)
            if part then
                local pos, onScreen = camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    if dist < bestDist then
                        bestPart = part
                        bestDist = dist
                    end
                end
            end
        end
    end

    return bestPart, bestDist
end

local function isEnemy(player)
    if teamCheckEnabled and player.Team ~= nil and player.Team == localPlayer.Team then
        return false
    end
    return true
end

local function getClosestPlayer(center, camera)
    local bestPart = nil
    local bestDist = aimFov

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and isEnemy(player) then
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local part = getAimPart(char, playerAimPartChoice)
                if part then
                    local pos, onScreen = camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                        if dist < bestDist then
                            bestPart = part
                            bestDist = dist
                        end
                    end
                end
            end
        end
    end

    return bestPart, bestDist
end

local function getTargetVelocity(part)
    local model = part.Parent
    local root = model and model:FindFirstChild("HumanoidRootPart")
    return (root or part).AssemblyLinearVelocity
end

-- Leads the target by its velocity and raises the aim point to cancel bullet drop
local function getAimPosition(part, origin)
    local pos = part.Position
    if not predictionEnabled then
        return pos
    end

    local velocity = getTargetVelocity(part)
    local speed = math.max(bulletSpeed, 1)
    local t = (pos - origin).Magnitude / speed
    local aimPoint = pos

    for _ = 1, 4 do
        aimPoint = pos + velocity * t + Vector3.new(0, 0.5 * bulletGravity * t * t, 0)
        t = (aimPoint - origin).Magnitude / speed
    end

    return aimPoint
end

local function aimStep()
    local camera = workspace.CurrentCamera
    if not camera then return end

    local center = camera.ViewportSize / 2

    if fovCircleEnabled then
        local circle = getFovCircle()
        if circle then
            circle.Position = center
            circle.Radius = aimFov
            circle.Visible = true
        end
    end

    if (aimLockEnabled or playerAimEnabled) and aimHolding then
        local target, targetDist = nil, math.huge

        if aimLockEnabled then
            if os.clock() - lastTargetScan > 1 then
                lastTargetScan = os.clock()
                scanSoldiers()
            end
            local part, dist = getClosestSoldier(center, camera)
            if part then
                target, targetDist = part, dist
            end
        end

        if playerAimEnabled then
            local part, dist = getClosestPlayer(center, camera)
            if part and dist < targetDist then
                target, targetDist = part, dist
            end
        end

        if target then
            local alpha = math.clamp(1 - (aimSmoothness / 100), 0.02, 1)
            local goal = CFrame.new(camera.CFrame.Position, getAimPosition(target, camera.CFrame.Position))
            camera.CFrame = camera.CFrame:Lerp(goal, alpha)
        end
    end
end

local function updateAimSystem()
    local needed = aimLockEnabled or playerAimEnabled or fovCircleEnabled

    if needed and not aimBound then
        aimBound = true
        RunService:BindToRenderStep("PepsiAimLock", Enum.RenderPriority.Camera.Value + 1, aimStep)
    elseif not needed and aimBound then
        aimBound = false
        RunService:UnbindFromRenderStep("PepsiAimLock")
    end

    if not fovCircleEnabled and fovCircle then
        fovCircle.Visible = false
    end
end

------------------
-- Corner box ESP
------------------
local function makeEspText()
    local text = Drawing.new("Text")
    text.Size = 14
    text.Center = true
    text.Outline = true
    text.Color = Color3.fromRGB(255, 255, 255)
    text.Transparency = 1
    text.Visible = false
    return text
end

local function createBoxEspObject(color)
    local obj = {
        lines = {},
        nameText = makeEspText(),
        heldText = makeEspText(),
        lastHeldScan = 0,
        heldString = "Nothing",
        frame = 0,
        color = color,
        lastVisScan = 0,
        visible = true,
    }
    for i = 1, 24 do
        local line = Drawing.new("Line")
        line.Thickness = 1.5
        line.Color = color
        line.Transparency = 1
        line.Visible = false
        obj.lines[i] = line
    end
    return obj
end

local function setBoxEspColor(obj, color)
    if obj.color == color then return end
    obj.color = color
    for _, line in ipairs(obj.lines) do
        line.Color = color
    end
end

local function hideBoxEsp(obj)
    for _, line in ipairs(obj.lines) do
        line.Visible = false
    end
    obj.nameText.Visible = false
    obj.heldText.Visible = false
end

local function removeBoxEsp(key)
    local obj = boxEspObjects[key]
    if not obj then return end
    for _, line in ipairs(obj.lines) do
        line:Remove()
    end
    obj.nameText:Remove()
    obj.heldText:Remove()
    boxEspObjects[key] = nil
end

local function getHeldString(character)
    local names = {}
    for _, d in ipairs(character:GetDescendants()) do
        if (d:IsA("Tool") or d:IsA("Model")) and not d:FindFirstAncestorWhichIsA("Accoutrement") then
            if not (d:IsA("Model") and d:FindFirstAncestorWhichIsA("Tool")) then
                local handle = d:FindFirstChild("Handle", true) or d:FindFirstChild("handle", true)
                if handle and handle:IsA("BasePart") then
                    table.insert(names, d.Name)
                end
            end
        end
    end
    table.sort(names)
    return #names > 0 and table.concat(names, ", ") or "Nothing"
end

local function projectPoint(camera, worldPos)
    local v = camera:WorldToViewportPoint(worldPos)
    return Vector2.new(v.X, v.Y + boxYOffset), v.Z > 0
end

local function getBoxGeometry(char, root, hum)
    local rootPos = root.Position
    local bottomY, topY

    if hum.RigType == Enum.HumanoidRigType.R6 then
        bottomY = rootPos.Y - 3
        topY = rootPos.Y + 2
    elseif hum.HipHeight > 0.1 then
        bottomY = rootPos.Y - (root.Size.Y / 2 + hum.HipHeight)
        topY = bottomY + hum.HipHeight * 2.6
    else
        local bbCF, bbSize = char:GetBoundingBox()
        bottomY = bbCF.Position.Y - bbSize.Y / 2
        topY = bbCF.Position.Y + bbSize.Y / 2
    end

    local height = topY - bottomY

    local look = root.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 0.01 then
        flat = Vector3.new(0, 0, -1)
    end

    local center = Vector3.new(rootPos.X, (topY + bottomY) / 2, rootPos.Z)
    local cf = CFrame.new(center, center + flat)
    local size = Vector3.new(height * 0.7, height, height * 0.45)

    return cf, size
end

local function updateBoxEsp(key, char, color, name, camera, origin)
    local obj = boxEspObjects[key]
    if obj then
        obj.frame = boxEspFrame
    end

    local root = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if not (root and hum and hum.Health > 0) then
        if obj then hideBoxEsp(obj) end
        return
    end

    local dist = (root.Position - origin).Magnitude
    if dist > worldMaxDistance then
        if obj then hideBoxEsp(obj) end
        return
    end

    if not obj then
        obj = createBoxEspObject(color)
        obj.frame = boxEspFrame
        boxEspObjects[key] = obj
    end

    -- Color: green if visible, red if blocked (re-checked ~every 0.05s to keep it cheap)
    if visibilityCheckEnabled then
        if os.clock() - obj.lastVisScan > 0.05 then
            obj.lastVisScan = os.clock()
            obj.visible = isModelVisible(char, camera)
        end
        setBoxEspColor(obj, obj.visible and visibleColor or hiddenColor)
    else
        setBoxEspColor(obj, color)
    end

    local cf, size = getBoxGeometry(char, root, hum)
    local half = size / 2

    -- 3D corner box (8 corners x 3 edges = 24 line segments)
    local li = 0
    for _, s in ipairs(cornerSigns) do
        local corner = cf:PointToWorldSpace(half * s)
        local a, aFront = projectPoint(camera, corner)
        local neighbors = {
            Vector3.new(-s.X, s.Y, s.Z),
            Vector3.new(s.X, -s.Y, s.Z),
            Vector3.new(s.X, s.Y, -s.Z),
        }
        for _, n in ipairs(neighbors) do
            li += 1
            local line = obj.lines[li]
            local tip = corner:Lerp(cf:PointToWorldSpace(half * n), cornerLength)
            local b, bFront = projectPoint(camera, tip)
            if aFront and bFront then
                line.From = a
                line.To = b
                line.Visible = true
            else
                line.Visible = false
            end
        end
    end

    if os.clock() - obj.lastHeldScan > 0.5 then
        obj.lastHeldScan = os.clock()
        obj.heldString = getHeldString(char)
    end

    local top, topFront = projectPoint(camera, cf:PointToWorldSpace(Vector3.new(0, half.Y, 0)))
    local bottom, bottomFront = projectPoint(camera, cf:PointToWorldSpace(Vector3.new(0, -half.Y, 0)))

    if topFront then
        obj.nameText.Text = string.format("%s [%d studs]", string.gsub(name, "_", " "), math.floor(dist))
        obj.nameText.Position = top - Vector2.new(0, 18)
        obj.nameText.Visible = true
    else
        obj.nameText.Visible = false
    end

    if bottomFront then
        obj.heldText.Text = "Holding: " .. obj.heldString
        obj.heldText.Position = bottom + Vector2.new(0, 2)
        obj.heldText.Visible = true
    else
        obj.heldText.Visible = false
    end
end

local function boxEspStep()
    local camera = workspace.CurrentCamera
    if not camera then return end

    boxEspFrame += 1

    local myChar = localPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local origin = myRoot and myRoot.Position or camera.CFrame.Position

    if playerBoxEnabled then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= localPlayer and isEnemy(player) then
                updateBoxEsp(player, player.Character, playerEspColor, player.Name, camera, origin)
            end
        end
    end

    if soldierBoxEnabled then
        if os.clock() - lastTargetScan > 1 then
            lastTargetScan = os.clock()
            scanSoldiers()
        end
        for _, hum in ipairs(soldierTargets) do
            local model = hum.Parent
            if model then
                updateBoxEsp(model, model, soldierEspColor, model.Name, camera, origin)
            end
        end
    end

    for key, obj in pairs(boxEspObjects) do
        if obj.frame ~= boxEspFrame then
            removeBoxEsp(key)
        end
    end
end

local function updateBoxEspBinding()
    local needed = playerBoxEnabled or soldierBoxEnabled

    if needed and not boxEspBound then
        boxEspBound = true
        RunService:BindToRenderStep("PepsiBoxEsp", Enum.RenderPriority.Camera.Value + 2, boxEspStep)
    elseif not needed and boxEspBound then
        boxEspBound = false
        RunService:UnbindFromRenderStep("PepsiBoxEsp")
        for key in pairs(boxEspObjects) do
            removeBoxEsp(key)
        end
    end
end

local function setPlayerBox(enabled)
    if enabled and not Drawing then
        warn("Corner box ESP needs the Drawing library, which this executor doesn't support")
        return
    end
    playerBoxEnabled = enabled
    updateBoxEspBinding()
end

local function setSoldierBox(enabled)
    if enabled and not Drawing then
        warn("Corner box ESP needs the Drawing library, which this executor doesn't support")
        return
    end
    soldierBoxEnabled = enabled
    updateBoxEspBinding()
end


------------------
-- FOV changer + zoom
------------------
local function cameraFovStep()
    local camera = workspace.CurrentCamera
    if not camera then return end

    local target
    if zoomEnabled and zoomActive then
        target = zoomFov
    elseif fovChangerEnabled then
        target = customFov
    else
        target = originalFov or 70
    end

    -- Smooth transition so zoom in/out doesn't snap
    local current = camera.FieldOfView
    if math.abs(current - target) < 0.1 then
        camera.FieldOfView = target
    else
        camera.FieldOfView = current + (target - current) * 0.3
    end
end

local function updateCameraFovBinding()
    local needed = fovChangerEnabled or (zoomEnabled and zoomActive)

    if needed and not cameraFovBound then
        local camera = workspace.CurrentCamera
        if camera and not originalFov then
            originalFov = camera.FieldOfView
        end
        cameraFovBound = true
        RunService:BindToRenderStep("PepsiCameraFov", Enum.RenderPriority.Camera.Value + 3, cameraFovStep)
    elseif not needed and cameraFovBound then
        -- Keep the step running until FOV has eased back to the original value
        local camera = workspace.CurrentCamera
        if camera and originalFov and math.abs(camera.FieldOfView - originalFov) > 0.1 then
            return
        end
        cameraFovBound = false
        RunService:UnbindFromRenderStep("PepsiCameraFov")
        if camera and originalFov then
            camera.FieldOfView = originalFov
        end
        originalFov = nil
    end
end

-- Zoom key input (hold or toggle)
local zoomBeganConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or not zoomEnabled then return end
    if input.KeyCode == zoomKey then
        if zoomMode == "Toggle" then
            zoomActive = not zoomActive
        else
            zoomActive = true
        end
        updateCameraFovBinding()
    end
end)
local zoomEndedConn = UserInputService.InputEnded:Connect(function(input)
    if zoomMode == "Hold" and input.KeyCode == zoomKey then
        zoomActive = false
    end
end)

-- While unzoomed with the changer off, let the step finish easing back, then unbind
RunService.Heartbeat:Connect(function()
    if cameraFovBound and not (fovChangerEnabled or (zoomEnabled and zoomActive)) then
        updateCameraFovBinding()
    end
end)

------------------
-- Noclip
------------------
local function setNoclip(enabled)
    noclipEnabled = enabled

    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end

    if enabled then
        -- Stepped runs before physics each frame, so collisions stay off even if the game re-enables them
        noclipConnection = RunService.Stepped:Connect(function()
            local char = localPlayer.Character
            if not char then return end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    noclipChanged[part] = true
                    part.CanCollide = false
                end
            end
        end)
    else
        -- Restore collisions on the parts we changed
        for part in pairs(noclipChanged) do
            if part and part.Parent then
                part.CanCollide = true
            end
        end
        noclipChanged = {}
    end
end

------------------
-- Walk speed
------------------
local function getHumanoid()
    local char = localPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function setSpeed(enabled)
    speedEnabled = enabled

    if speedConnection then
        speedConnection:Disconnect()
        speedConnection = nil
    end

    local hum = getHumanoid()
    if enabled then
        if hum and not originalWalkSpeed then
            originalWalkSpeed = hum.WalkSpeed
        end
        -- Heartbeat so the value sticks even if the game keeps resetting it
        speedConnection = RunService.Heartbeat:Connect(function()
            local h = getHumanoid()
            if h then
                if not originalWalkSpeed then
                    originalWalkSpeed = h.WalkSpeed
                end
                h.WalkSpeed = walkSpeedValue
            end
        end)
    else
        if hum then
            hum.WalkSpeed = originalWalkSpeed or 16
        end
        originalWalkSpeed = nil
    end
end

------------------
-- Infinite jump
------------------
local function setInfiniteJump(enabled)
    infJumpEnabled = enabled

    if infJumpConnection then
        infJumpConnection:Disconnect()
        infJumpConnection = nil
    end

    if enabled then
        infJumpConnection = UserInputService.JumpRequest:Connect(function()
            local hum = getHumanoid()
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    end
end

------------------
-- Fly (WASD + Space up, Left Ctrl/Shift down, moves toward where the camera looks)
------------------
local function stopFly()
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    if flyVelocity then
        flyVelocity:Destroy()
        flyVelocity = nil
    end
    if flyGyro then
        flyGyro:Destroy()
        flyGyro = nil
    end
    local hum = getHumanoid()
    if hum then
        hum.PlatformStand = false
    end
end

local function setFly(enabled)
    flyEnabled = enabled
    stopFly()
    if not enabled then return end

    flyConnection = RunService.RenderStepped:Connect(function()
        local char = localPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local camera = workspace.CurrentCamera
        if not (root and hum and camera) then return end

        -- Recreate the movers after respawn
        if not flyVelocity or flyVelocity.Parent ~= root then
            if flyVelocity then flyVelocity:Destroy() end
            flyVelocity = Instance.new("BodyVelocity")
            flyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            flyVelocity.Velocity = Vector3.zero
            flyVelocity.Parent = root
        end
        if not flyGyro or flyGyro.Parent ~= root then
            if flyGyro then flyGyro:Destroy() end
            flyGyro = Instance.new("BodyGyro")
            flyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
            flyGyro.P = 9e4
            flyGyro.Parent = root
        end

        hum.PlatformStand = true

        local dir = Vector3.zero
        if not UserInputService:GetFocusedTextBox() then
            local cf = camera.CFrame
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cf.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cf.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cf.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cf.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
                or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                dir -= Vector3.yAxis
            end
        end

        flyVelocity.Velocity = dir.Magnitude > 0 and dir.Unit * flySpeed or Vector3.zero
        flyGyro.CFrame = camera.CFrame
    end)
end

------------------
-- Fullbright / no fog
------------------
local function applyFullbright()
    Lighting.Brightness = 2
    Lighting.ClockTime = 14
    Lighting.FogEnd = 1e6
    Lighting.GlobalShadows = false
    Lighting.Ambient = Color3.fromRGB(178, 178, 178)
    Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
end

local function setFullbright(enabled)
    fullbrightEnabled = enabled

    if fullbrightConnection then
        fullbrightConnection:Disconnect()
        fullbrightConnection = nil
    end

    if enabled then
        if not lightingBackup then
            lightingBackup = {
                Brightness = Lighting.Brightness,
                ClockTime = Lighting.ClockTime,
                FogEnd = Lighting.FogEnd,
                GlobalShadows = Lighting.GlobalShadows,
                Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
            }
        end
        -- Re-applied every frame because many games change lighting on a day/night cycle
        fullbrightConnection = RunService.RenderStepped:Connect(applyFullbright)
    elseif lightingBackup then
        for prop, value in pairs(lightingBackup) do
            Lighting[prop] = value
        end
        lightingBackup = nil
    end
end

------------------
-- Disable everything
------------------
local function disableAll()
    setNoclip(false)
    setSpeed(false)
    setInfiniteJump(false)
    setFly(false)
    setFullbright(false)
    fovChangerEnabled = false
    zoomEnabled = false
    zoomActive = false
    updateCameraFovBinding()
    if zoomBeganConn then zoomBeganConn:Disconnect() zoomBeganConn = nil end
    if zoomEndedConn then zoomEndedConn:Disconnect() zoomEndedConn = nil end

    setTrackerEnabled(false)
    setXray(false)

    nodeEspEnabled = false
    dropsEspEnabled = false
    metalCratesEspEnabled = false
    woodenCratesEspEnabled = false
    soldierEspEnabled = false
    clothEspEnabled = false
    worldHighlightEnabled = false
    refreshWorldEsp()

    aimLockEnabled = false
    playerAimEnabled = false
    fovCircleEnabled = false
    predictionEnabled = false
    aimHolding = false
    updateAimSystem()
    if fovCircle then
        fovCircle:Remove()
        fovCircle = nil
    end

    teamCheckEnabled = false
    setPlayerBox(false)
    setSoldierBox(false)

    if inputBeganConn then inputBeganConn:Disconnect() inputBeganConn = nil end
    if inputEndedConn then inputEndedConn:Disconnect() inputEndedConn = nil end

    print("--- Pepsi's World: everything disabled ---")
end

------------------
-- Public API (called from Main.lua)
------------------
local worldToggles = {
    Nodes = function(v) nodeEspEnabled = v end,
    Drops = function(v) dropsEspEnabled = v end,
    ["Metal Crates"] = function(v) metalCratesEspEnabled = v end,
    ["Wooden Crates"] = function(v) woodenCratesEspEnabled = v end,
    Soldiers = function(v) soldierEspEnabled = v end,
    Cloth = function(v) clothEspEnabled = v end,
}

-- Holder
Logic.setTrackerEnabled = setTrackerEnabled

-- World ESP
function Logic.setWorldToggle(category, enabled)
    local setter = worldToggles[category]
    if setter then
        setter(enabled)
        refreshWorldEsp()
    end
end

function Logic.setHighlightEnabled(enabled)
    worldHighlightEnabled = enabled
    refreshWorldEsp()
end

function Logic.setHighlightSelection(selected)
    highlightSelection = normalizeSelection(selected)
    refreshWorldEsp()
end

function Logic.setHighlightColor(color)
    worldHighlightColor = color
    updateHighlightColors()
end

function Logic.setDistance(value)
    worldMaxDistance = value
    updateDistanceCheck()
end

-- Xray
Logic.setXray = setXray
Logic.setXrayTransparency = setXrayTransparency

-- Aim
function Logic.setAimLock(enabled)
    aimLockEnabled = enabled
    updateAimSystem()
end

function Logic.setFovCircle(enabled)
    fovCircleEnabled = enabled
    updateAimSystem()
end

local function pickPart(selected)
    if type(selected) == "table" then
        selected = selected[1] or next(selected)
    end
    if type(selected) == "string" and aimPartNames[selected] then
        return selected
    end
    return nil
end

function Logic.setSoldierAimPart(selected)
    aimPartChoice = pickPart(selected) or aimPartChoice
end

function Logic.setPlayerAimPart(selected)
    playerAimPartChoice = pickPart(selected) or playerAimPartChoice
end

function Logic.setFov(value) aimFov = value end
function Logic.setSmoothness(value) aimSmoothness = value end

function Logic.setPlayerAim(enabled)
    playerAimEnabled = enabled
    updateAimSystem()
end

-- Prediction
function Logic.setPrediction(enabled) predictionEnabled = enabled end
function Logic.setBulletSpeed(value) bulletSpeed = value end
function Logic.setBulletDrop(value) bulletGravity = value end

-- Box ESP
Logic.setPlayerBox = setPlayerBox
Logic.setSoldierBox = setSoldierBox
function Logic.setBoxYOffset(value) boxYOffset = value end
function Logic.setTeamCheck(enabled) teamCheckEnabled = enabled end

-- Visibility check (green = visible, red = hidden)
function Logic.setVisibilityCheck(enabled)
    visibilityCheckEnabled = enabled
    updateHighlightColors()
end
function Logic.setVisibleColor(color) visibleColor = color end
function Logic.setHiddenColor(color) hiddenColor = color end


-- FOV changer + zoom
function Logic.setFovChanger(enabled)
    fovChangerEnabled = enabled
    updateCameraFovBinding()
end

function Logic.setCustomFov(value)
    customFov = value
end

function Logic.setZoomEnabled(enabled)
    zoomEnabled = enabled
    if not enabled then zoomActive = false end
    updateCameraFovBinding()
end

function Logic.setZoomFov(value)
    zoomFov = value
end

function Logic.setZoomMode(selected)
    if type(selected) == "table" then
        selected = selected[1] or next(selected)
    end
    if selected == "Hold" or selected == "Toggle" then
        zoomMode = selected
        zoomActive = false
        updateCameraFovBinding()
    end
end

function Logic.setZoomKey(selected)
    if type(selected) == "table" then
        selected = selected[1] or next(selected)
    end
    if typeof(selected) == "EnumItem" then
        zoomKey = selected
    elseif type(selected) == "string" then
        local key = Enum.KeyCode[selected]
        if key then zoomKey = key end
    end
end

-- Noclip
Logic.setNoclip = setNoclip

-- Speed / jump / fly / fullbright
Logic.setSpeed = setSpeed
function Logic.setWalkSpeed(value) walkSpeedValue = value end
Logic.setInfiniteJump = setInfiniteJump
Logic.setFly = setFly
function Logic.setFlySpeed(value) flySpeed = value end
Logic.setFullbright = setFullbright

-- Shutdown
Logic.disableAll = disableAll

return Logic