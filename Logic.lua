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
local highlightCategories = {}
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

-- Soldier box ESP only (players use the new ScreenGui ESP)
local soldierBoxEnabled = false
local boxEspBound = false
local boxEspObjects = {}
local boxEspFrame = 0
local soldierEspColor = Color3.fromRGB(255, 170, 0)
local cornerLength = 0.3
local boxYOffset = 0

local visibilityCheckEnabled = true
local visibleColor = Color3.fromRGB(0, 255, 80)
local hiddenColor = Color3.fromRGB(255, 40, 40)
local visCheckParts = { "Head", "UpperTorso", "Torso", "HumanoidRootPart" }
local visParams = RaycastParams.new()
visParams.FilterType = Enum.RaycastFilterType.Exclude
visParams.RespectCanCollide = true

local fovChangerEnabled = false
local customFov = 70
local zoomEnabled = false
local zoomFov = 20
local zoomMode = "Hold"
local zoomKey = Enum.KeyCode.Z
local zoomActive = false
local cameraFovBound = false
local originalFov = nil

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

local noclipEnabled = false
local noclipConnection = nil
local noclipChanged = {}

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
local function isModelVisible(model, camera)
    if not model or not camera then return false end

    local myChar = localPlayer.Character
    visParams.FilterDescendantsInstances = myChar and { myChar } or {}

    local origin = camera.CFrame.Position
    for _, name in ipairs(visCheckParts) do
        local part = model:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            local result = workspace:Raycast(origin, part.Position - origin, visParams)
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


local statusLabel = script.Parent:WaitForChild("StatusLabel") -- Change to your actual path/name
local function setTrackerEnabled(enabled)
    isTracking = enabled

    -- Safely update the status label only if it exists
    if statusLabel then
        if isTracking then
            statusLabel.Text = "Status: ENABLED"
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0) -- Green for active
        else
            statusLabel.Text = "Status: DISABLED"
            statusLabel.TextColor3 = Color3.fromRGB(255, 0, 0) -- Red for disabled
        end
    end

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

    if nodeEspEnabled then
        local nodes = workspace:FindFirstChild("Nodes", true)
        if nodes then
            for _, item in ipairs(nodes:GetChildren()) do
                createWorldElements(item, nil, "Nodes")
            end
        end
    end

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
-- Player ESP (ScreenGui + skeleton drawings)
------------------
local workspaceSvc = (cloneref and cloneref(game:GetService("Workspace"))) or game:GetService("Workspace")
local runSvc = (cloneref and cloneref(game:GetService("RunService"))) or game:GetService("RunService")
local http_service = (cloneref and cloneref(game:GetService("HttpService"))) or game:GetService("HttpService")
local playersSvc = (cloneref and cloneref(game:GetService("Players"))) or game:GetService("Players")

local vec2 = Vector2.new
local dim2 = UDim2.new
local dim_offset = UDim2.fromOffset
local rgb = Color3.fromRGB

local camera = workspaceSvc.CurrentCamera

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

local espFlags = {
    ["Enabled"] = true,
    ["Names"] = true,
    ["Name_Color"] = { Color = rgb(255, 255, 255) },
    ["Boxes"] = true,
    ["Box_Type"] = "Corner",
    ["Box_Color"] = { Color = rgb(255, 255, 255) },
    ["Healthbar"] = true,
    ["Health_High"] = { Color = rgb(0, 255, 80) },
    ["Health_Low"] = { Color = rgb(255, 40, 40) },
    ["Distance"] = true,
    ["Weapon"] = true,
    ["Skeletons"] = false,
    ["Skeletons_Color"] = { Color = rgb(255, 255, 255) },
    ["Distance_Color"] = { Color = rgb(255, 255, 255) },
    ["Weapon_Color"] = { Color = rgb(255, 255, 255) },
}

local fonts = {}
do
    local function Register_Font(Name, Weight, Style, Asset)
        if isfile and writefile and not isfile(Asset.Id) then
            writefile(Asset.Id, Asset.Font)
        end
        if isfile and delfile and isfile(Name .. ".font") then
            delfile(Name .. ".font")
        end
        local Data = {
            name = Name,
            faces = {{
                name = "Normal",
                weight = Weight,
                style = Style,
                assetId = getcustomasset and getcustomasset(Asset.Id) or "",
            }},
        }
        if writefile and http_service then
            writefile(Name .. ".font", http_service:JSONEncode(Data))
        end
        return getcustomasset and getcustomasset(Name .. ".font") or ""
    end

    local ok, ProggyTiny = pcall(function()
        return Register_Font("PepsiProggyTiny", 100, "Normal", {
            Id = "ProggyTinyyyy.ttf",
            Font = game:HttpGet("https://github.com/i77lhm/storage/raw/refs/heads/main/fonts/ProggyTiny.ttf"),
        })
    end)

    if ok and ProggyTiny ~= "" then
        fonts.main = Font.new(ProggyTiny, Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    else
        fonts.main = Font.fromEnum(Enum.Font.SourceSans)
    end
end

local esp = {
    players = {},
    screengui = Instance.new("ScreenGui"),
    cache = Instance.new("ScreenGui"),
    connections = {},
}

do
    local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
    esp.screengui.IgnoreGuiInset = true
    esp.screengui.Name = "\0"
    esp.screengui.Parent = parentGui
    esp.cache.Enabled = false
    esp.cache.Parent = parentGui

    function esp:get_screen_pos(world_position)
        local viewport_size = camera.ViewportSize
        local local_position = camera.CFrame:pointToObjectSpace(world_position)

        local aspect_ratio = viewport_size.X / viewport_size.Y
        local half_height = -local_position.Z * math.tan(math.rad(camera.FieldOfView / 2))
        local half_width = aspect_ratio * half_height

        local far_plane_corner = Vector3.new(-half_width, half_height, local_position.Z)
        local relative_position = local_position - far_plane_corner

        local screen_x = relative_position.X / (half_width * 2)
        local screen_y = -relative_position.Y / (half_height * 2)

        local is_on_screen = -local_position.Z > 0 and screen_x >= 0 and screen_x <= 1 and screen_y >= 0 and screen_y <= 1

        return Vector3.new(screen_x * viewport_size.X, screen_y * viewport_size.Y, -local_position.Z), is_on_screen
    end

    function esp:box_solve(torso)
        if not torso then return nil, nil, false, 0 end

        local ViewportTop = torso.Position + (torso.CFrame.UpVector * 1.8) + camera.CFrame.UpVector
        local ViewportBottom = torso.Position - (torso.CFrame.UpVector * 2.5) - camera.CFrame.UpVector
        local Distance = (torso.Position - camera.CFrame.Position).Magnitude

        local Top = esp:get_screen_pos(ViewportTop)
        local Bottom = esp:get_screen_pos(ViewportBottom)

        local Width = math.max(math.floor(math.abs(Top.X - Bottom.X)), 3)
        local Height = math.max(math.floor(math.max(math.abs(Bottom.Y - Top.Y), Width / 2)), 3)
        local BoxSize = Vector2.new(math.floor(math.max(Height / 1.5, Width)), Height)
        local BoxPosition = Vector2.new(
            math.floor(Top.X * 0.5 + Bottom.X * 0.5 - BoxSize.X * 0.5),
            math.floor(math.min(Top.Y, Bottom.Y))
        )

        local _, topOn = esp:get_screen_pos(ViewportTop)
        local _, botOn = esp:get_screen_pos(ViewportBottom)
        return BoxSize, BoxPosition, topOn or botOn, Distance
    end

    function esp:create(instance, options)
        local ins = Instance.new(instance)
        for prop, value in pairs(options) do
            ins[prop] = value
        end
        return ins
    end

    function esp:create_object(player)
        if player == localPlayer then return end

        esp[player.Name] = {
            objects = {},
            info = { character = nil, humanoid = nil, rootpart = nil },
            drawings = {},
        }
        local data = esp[player.Name]
        local objects = data.objects

        objects["holder"] = esp:create("Frame", {
            Parent = esp.screengui,
            Name = "\0",
            BackgroundTransparency = 1,
            Position = dim2(0, 0, 0, 0),
            BorderSizePixel = 0,
            Size = dim2(0, 0, 0, 0),
        })

        objects["box_outline"] = esp:create("UIStroke", {
            Parent = esp.cache,
            LineJoinMode = Enum.LineJoinMode.Miter,
        })

        objects["name"] = esp:create("TextLabel", {
            FontFace = fonts.main,
            Parent = objects["holder"],
            TextColor3 = espFlags["Name_Color"].Color,
            Text = string.format("%s (@%s)", player.DisplayName, player.Name),
            Name = "\0",
            TextStrokeTransparency = 0,
            AnchorPoint = vec2(0, 1),
            Size = dim2(1, 0, 0, 0),
            BackgroundTransparency = 1,
            Position = dim2(0, 0, 0, -5),
            BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.Y,
            TextSize = 9,
        })

        objects["box_handler"] = esp:create("Frame", {
            Parent = esp.cache,
            Name = "\0",
            BackgroundTransparency = 1,
            Position = dim2(0, 1, 0, 1),
            Size = dim2(1, -2, 1, -2),
            BorderSizePixel = 0,
        })

        objects["box_color"] = esp:create("UIStroke", {
            Color = rgb(255, 255, 255),
            LineJoinMode = Enum.LineJoinMode.Miter,
            Name = "\0",
            Parent = objects["box_handler"],
        })

        objects["outline"] = esp:create("Frame", {
            Parent = objects["box_handler"],
            Name = "\0",
            BackgroundTransparency = 1,
            Position = dim2(0, 1, 0, 1),
            Size = dim2(1, -2, 1, -2),
            BorderSizePixel = 0,
        })
        esp:create("UIStroke", {
            Parent = objects["outline"],
            LineJoinMode = Enum.LineJoinMode.Miter,
        })

        objects["corners"] = esp:create("Frame", {
            Visible = true,
            Parent = esp.cache,
            BackgroundTransparency = 1,
            Position = dim2(0, -1, 0, 2),
            Name = "\0",
            Size = dim2(1, 0, 1, 0),
            BorderSizePixel = 0,
        })

        local function makeCorner(props)
            local frame = esp:create("Frame", props)
            esp:create("Frame", {
                Parent = frame,
                Position = dim2(0, 1, 0, 1),
                Size = dim2(1, -2, 1, -2),
                BorderSizePixel = 0,
                BackgroundColor3 = espFlags["Box_Color"].Color,
            })
            return frame
        end

        objects["1"] = makeCorner({
            Parent = objects["corners"], Name = "line",
            Position = dim2(0, 0, 0, -2), Size = dim2(0.4, 0, 0, 3), BorderSizePixel = 0, BackgroundColor3 = rgb(0, 0, 0),
        })
        objects["2"] = makeCorner({
            Parent = objects["corners"], Name = "line",
            Position = dim2(0, 0, 0, 1), Size = dim2(0, 3, 0.25, 0), BorderSizePixel = 0, BackgroundColor3 = rgb(0, 0, 0),
        })
        objects["3"] = makeCorner({
            AnchorPoint = vec2(1, 0), Parent = objects["corners"], Name = "line",
            Position = dim2(1, 0, 0, -2), Size = dim2(0.4, 0, 0, 3), BorderSizePixel = 0, BackgroundColor3 = rgb(0, 0, 0),
        })
        objects["4"] = makeCorner({
            AnchorPoint = vec2(1, 0), Parent = objects["corners"], Name = "line",
            Position = dim2(1, 0, 0, 1), Size = dim2(0, 3, 0.25, 0), BorderSizePixel = 0, BackgroundColor3 = rgb(0, 0, 0),
        })
        objects["5"] = makeCorner({
            AnchorPoint = vec2(0, 1), Parent = objects["corners"], Name = "line",
            Position = dim2(0, 0, 1, -2), Size = dim2(0.4, 0, 0, 3), BorderSizePixel = 0, BackgroundColor3 = rgb(0, 0, 0),
        })
        objects["6"] = makeCorner({
            Rotation = 180, Parent = objects["corners"], Name = "line",
            Position = dim2(0, 0, 1, -5), AnchorPoint = vec2(0, 1), Size = dim2(0, 3, 0.25, 0), BorderSizePixel = 0, BackgroundColor3 = rgb(0, 0, 0),
        })
        objects["7"] = makeCorner({
            AnchorPoint = vec2(1, 1), Parent = objects["corners"], Name = "line",
            Position = dim2(1, 0, 1, -2), Size = dim2(0.4, 0, 0, 3), BorderSizePixel = 0, BackgroundColor3 = rgb(0, 0, 0),
        })
        objects["8"] = makeCorner({
            Rotation = 180, Parent = objects["corners"], Name = "line",
            Position = dim2(1, 0, 1, -5), AnchorPoint = vec2(1, 1), Size = dim2(0, 3, 0.25, 0), BorderSizePixel = 0, BackgroundColor3 = rgb(0, 0, 0),
        })

        objects["healthbar_holder"] = esp:create("Frame", {
            AnchorPoint = vec2(1, 0),
            Parent = esp.cache,
            Name = "\0",
            Position = dim2(0, -5, 0, -1),
            Size = dim2(0, 4, 1, 2),
            BorderSizePixel = 0,
            BackgroundColor3 = rgb(0, 0, 0),
        })
        objects["healthbar"] = esp:create("Frame", {
            Parent = objects["healthbar_holder"],
            Name = "\0",
            Position = dim2(0, 1, 0, 1),
            Size = dim2(1, -2, 1, -2),
            BorderSizePixel = 0,
            BackgroundColor3 = rgb(255, 255, 255),
        })

        objects["distance"] = esp:create("TextLabel", {
            FontFace = fonts.main,
            TextColor3 = espFlags["Distance_Color"].Color,
            Text = "0st",
            Parent = esp.cache,
            TextStrokeTransparency = 0,
            Name = "\0",
            Size = dim2(1, 0, 0, 0),
            BackgroundTransparency = 1,
            Position = dim2(0, 0, 1, 5),
            BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.Y,
            TextSize = 9,
        })

        objects["weapon"] = esp:create("TextLabel", {
            FontFace = fonts.main,
            TextColor3 = espFlags["Weapon_Color"].Color,
            Text = "",
            Parent = esp.cache,
            TextStrokeTransparency = 0,
            Name = "\0",
            Size = dim2(1, 0, 0, 0),
            BackgroundTransparency = 1,
            Position = dim2(0, 0, 1, 19),
            BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.Y,
            TextSize = 9,
        })

        if Drawing then
            for _ = 1, #bones do
                local line = Drawing.new("Line")
                line.Color = espFlags["Skeletons_Color"].Color
                line.Thickness = 1
                line.Visible = false
                data.drawings[#data.drawings + 1] = line
            end
        end

        data.health_changed = function(value)
            if not espFlags["Healthbar"] or not data.info.humanoid then return end
            local humanoid = data.info.humanoid
            local multiplier = math.clamp(value / math.max(humanoid.MaxHealth, 1), 0, 1)
            local color = espFlags["Health_Low"].Color:Lerp(espFlags["Health_High"].Color, multiplier)
            objects["healthbar"].Size = UDim2.new(1, -2, multiplier, -2)
            objects["healthbar"].Position = UDim2.new(0, 1, 1 - multiplier, 1)
            objects["healthbar"].BackgroundColor3 = color
        end

        -- Initialize the data table first so it's not nil
        local data = data or {}

        data.tool_added = function(item)
            if not item:IsA("Tool") then return end
            
            print("Tool detected for UI:", item.Name)
            
            -- Make sure both the weapon object and holder exist before setting properties
            if objects["weapon"] and objects["holder"] then
                objects["weapon"].Text = item.Name
                objects["weapon"].Parent = objects["holder"]
            else
                warn("objects['weapon'] or objects['holder'] is nil! Check your table definitions.")
            end
        end
        data.refresh_descendants = function()
            local character = player.Character
            if not character then return end
            local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 3)
            if not humanoid then return end

            data.info.character = character
            data.info.humanoid = humanoid
            data.info.rootpart = humanoid.RootPart or character:FindFirstChild("HumanoidRootPart")

            humanoid.HealthChanged:Connect(data.health_changed)
            character.ChildAdded:Connect(data.tool_added)
            character.ChildRemoved:Connect(function()
                local tool = character:FindFirstChildOfClass("Tool")
                if tool then
                    data.tool_added(tool)
                else
                    objects["weapon"].Text = ""
                    objects["weapon"].Parent = esp.cache
                end
            end)

            data.health_changed(humanoid.Health)

            local tool = character:FindFirstChildOfClass("Tool")
            if tool then data.tool_added(tool) end
        end

        data.refresh_descendants()
        player.CharacterAdded:Connect(data.refresh_descendants)
    end

    function esp:remove_object(player)
        local holder = esp[player.Name]
        if not holder then return end

        for _, line in ipairs(holder.drawings) do
            pcall(function() line:Remove() end)
        end
        if holder.objects["holder"] then
            holder.objects["holder"]:Destroy()
        end
        esp[player.Name] = nil
    end

    function esp.refresh_elements()
        for _, v in ipairs(playersSvc:GetPlayers()) do
            if v == localPlayer then continue end
            if not v.Character then continue end

            local path = esp[v.Name]
            local objects = path and path.objects
            if not objects then continue end

            objects.holder.Parent = espFlags["Enabled"] and esp.screengui or esp.cache

            objects["name"].Parent = espFlags["Names"] and objects["holder"] or esp.cache
            objects["name"].TextColor3 = espFlags["Name_Color"].Color

            local is_corner = espFlags["Box_Type"] == "Corner"

            if espFlags["Boxes"] then
                objects["corners"].Parent = is_corner and objects["holder"] or esp.cache
                objects["box_handler"].Parent = is_corner and esp.cache or objects["holder"]
                objects["box_outline"].Parent = is_corner and esp.cache or objects["holder"]
            else
                objects["corners"].Parent = esp.cache
                objects["box_handler"].Parent = esp.cache
                objects["box_outline"].Parent = esp.cache
            end

            objects["box_color"].Color = espFlags["Box_Color"].Color
            for _, corner in ipairs(objects["corners"]:GetChildren()) do
                local inner = corner:FindFirstChildOfClass("Frame")
                if inner then inner.BackgroundColor3 = espFlags["Box_Color"].Color end
            end

            for _, line in ipairs(path.drawings) do
                line.Color = espFlags["Skeletons_Color"].Color
            end

            objects["healthbar_holder"].Parent = espFlags["Healthbar"] and objects["holder"] or esp.cache
            objects["weapon"].TextColor3 = espFlags["Weapon_Color"].Color
            objects["weapon"].Parent = (espFlags["Weapon"] and v.Character:FindFirstChildOfClass("Tool") and objects["holder"]) or esp.cache
            objects["distance"].TextColor3 = espFlags["Distance_Color"].Color
            objects["distance"].Parent = espFlags["Distance"] and objects["holder"] or esp.cache
        end
    end

    esp.connection = runSvc.RenderStepped:Connect(function()
        if not espFlags["Enabled"] then return end
        camera = workspaceSvc.CurrentCamera
        if not camera then return end

        for _, player in ipairs(playersSvc:GetPlayers()) do
            local data = esp[player.Name]
            if not data then continue end

            local character = data.info.character
            local humanoid = data.info.humanoid
            if not (character and humanoid and humanoid.Health > 0) then continue end

            if teamCheckEnabled and player.Team and player.Team == localPlayer.Team then
                if data.objects["holder"].Visible then
                    data.objects["holder"].Visible = false
                end
                for _, line in ipairs(data.drawings) do line.Visible = false end
                continue
            end

            local root = data.info.rootpart or humanoid.RootPart
            if not root then continue end

            local objects = data.objects
            local box_size, box_pos, on_screen, distance = esp:box_solve(root)
            local holder = objects["holder"]

            if holder.Visible ~= on_screen then
                holder.Visible = on_screen
            end

            if espFlags["Skeletons"] and Drawing and character:FindFirstChild("UpperTorso") then
                for i = 1, #bones do
                    local path = data.drawings[i]
                    if not path then continue end
                    local origin_3d = character:FindFirstChild(bones[i][1])
                    local destination_3d = character:FindFirstChild(bones[i][2])
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
                    else
                        path.Visible = false
                    end
                end
            else
                for _, line in ipairs(data.drawings) do line.Visible = false end
            end

            if not on_screen then continue end

            holder.Position = dim_offset(box_pos.X, box_pos.Y)
            holder.Size = dim_offset(box_size.X, box_size.Y)

            local distText = tostring(math.round(distance)) .. "st"
            if objects["distance"].Text ~= distText then
                objects["distance"].Text = distText
            end
        end
    end)

    function esp:unload()
        for _, player in ipairs(playersSvc:GetPlayers()) do
            esp:remove_object(player)
        end
        if esp.connection then esp.connection:Disconnect() end
        if esp.player_added then esp.player_added:Disconnect() end
        if esp.player_removed then esp.player_removed:Disconnect() end
        pcall(function() esp.cache:Destroy() end)
        pcall(function() esp.screengui:Destroy() end)
    end
end

for _, v in ipairs(playersSvc:GetPlayers()) do
    if v ~= localPlayer then
        esp:create_object(v)
    end
end

esp.player_added = playersSvc.PlayerAdded:Connect(function(v)
    esp:create_object(v)
end)
esp.player_removed = playersSvc.PlayerRemoving:Connect(function(v)
    esp:remove_object(v)
end)

------------------
-- Soldier corner box ESP (Drawing – bots only)
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

local function projectPoint(cam, worldPos)
    local v = cam:WorldToViewportPoint(worldPos)
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

local function updateBoxEsp(key, char, color, name, cam, origin)
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

    if visibilityCheckEnabled then
        if os.clock() - obj.lastVisScan > 0.05 then
            obj.lastVisScan = os.clock()
            obj.visible = isModelVisible(char, cam)
        end
        setBoxEspColor(obj, obj.visible and visibleColor or hiddenColor)
    else
        setBoxEspColor(obj, color)
    end

    local cf, size = getBoxGeometry(char, root, hum)
    local half = size / 2

    local li = 0
    for _, s in ipairs(cornerSigns) do
        local corner = cf:PointToWorldSpace(half * s)
        local a, aFront = projectPoint(cam, corner)
        local neighbors = {
            Vector3.new(-s.X, s.Y, s.Z),
            Vector3.new(s.X, -s.Y, s.Z),
            Vector3.new(s.X, s.Y, -s.Z),
        }
        for _, n in ipairs(neighbors) do
            li += 1
            local line = obj.lines[li]
            local tip = corner:Lerp(cf:PointToWorldSpace(half * n), cornerLength)
            local b, bFront = projectPoint(cam, tip)
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

    local top, topFront = projectPoint(cam, cf:PointToWorldSpace(Vector3.new(0, half.Y, 0)))
    local bottom, bottomFront = projectPoint(cam, cf:PointToWorldSpace(Vector3.new(0, -half.Y, 0)))

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
    local cam = workspace.CurrentCamera
    if not cam then return end

    boxEspFrame += 1

    local myChar = localPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local origin = myRoot and myRoot.Position or cam.CFrame.Position

    if soldierBoxEnabled then
        if os.clock() - lastTargetScan > 1 then
            lastTargetScan = os.clock()
            scanSoldiers()
        end
        for _, hum in ipairs(soldierTargets) do
            local model = hum.Parent
            if model then
                updateBoxEsp(model, model, soldierEspColor, model.Name, cam, origin)
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
    local needed = soldierBoxEnabled

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
    local cam = workspace.CurrentCamera
    if not cam then return end

    local target
    if zoomEnabled and zoomActive then
        target = zoomFov
    elseif fovChangerEnabled then
        target = customFov
    else
        target = originalFov or 70
    end

    local current = cam.FieldOfView
    if math.abs(current - target) < 0.1 then
        cam.FieldOfView = target
    else
        cam.FieldOfView = current + (target - current) * 0.3
    end
end

local function updateCameraFovBinding()
    local needed = fovChangerEnabled or (zoomEnabled and zoomActive)

    if needed and not cameraFovBound then
        local cam = workspace.CurrentCamera
        if cam and not originalFov then
            originalFov = cam.FieldOfView
        end
        cameraFovBound = true
        RunService:BindToRenderStep("PepsiCameraFov", Enum.RenderPriority.Camera.Value + 3, cameraFovStep)
    elseif not needed and cameraFovBound then
        local cam = workspace.CurrentCamera
        if cam and originalFov and math.abs(cam.FieldOfView - originalFov) > 0.1 then
            return
        end
        cameraFovBound = false
        RunService:UnbindFromRenderStep("PepsiCameraFov")
        if cam and originalFov then
            cam.FieldOfView = originalFov
        end
        originalFov = nil
    end
end

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
-- Fly
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
        local cam = workspace.CurrentCamera
        if not (root and hum and cam) then return end

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
            local cf = cam.CFrame
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
        flyGyro.CFrame = cam.CFrame
    end)
end

------------------
-- Fullbright
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
    setSoldierBox(false)

    -- unload new player ESP
    if esp and esp.unload then
        esp:unload()
    end

    if inputBeganConn then inputBeganConn:Disconnect() inputBeganConn = nil end
    if inputEndedConn then inputEndedConn:Disconnect() inputEndedConn = nil end

    print("--- Pepsi's World: everything disabled ---")
end

------------------
-- Public API
------------------
local worldToggles = {
    Nodes = function(v) nodeEspEnabled = v end,
    Drops = function(v) dropsEspEnabled = v end,
    ["Metal Crates"] = function(v) metalCratesEspEnabled = v end,
    ["Wooden Crates"] = function(v) woodenCratesEspEnabled = v end,
    Soldiers = function(v) soldierEspEnabled = v end,
    Cloth = function(v) clothEspEnabled = v end,
}

Logic.setTrackerEnabled = setTrackerEnabled

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

Logic.setXray = setXray
Logic.setXrayTransparency = setXrayTransparency

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

function Logic.setPrediction(enabled) predictionEnabled = enabled end
function Logic.setBulletSpeed(value) bulletSpeed = value end
function Logic.setBulletDrop(value) bulletGravity = value end

-- Player ESP is driven by the full flag set; this is a simple on/off
function Logic.setPlayerBox(enabled)
    espFlags["Enabled"] = enabled
    espFlags["Boxes"] = enabled
    esp.refresh_elements()
end

Logic.setSoldierBox = setSoldierBox
function Logic.setBoxYOffset(value) boxYOffset = value end
function Logic.setTeamCheck(enabled) teamCheckEnabled = enabled end

function Logic.setVisibilityCheck(enabled)
    visibilityCheckEnabled = enabled
    updateHighlightColors()
end
function Logic.setVisibleColor(color) visibleColor = color end
function Logic.setHiddenColor(color) hiddenColor = color end

-- Push UI flags into the real player ESP
function Logic.refreshEspFlags(newFlags)
    if type(newFlags) ~= "table" then return end
    for k, v in pairs(newFlags) do
        espFlags[k] = v
    end
    esp.refresh_elements()
end

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

Logic.setNoclip = setNoclip
Logic.setSpeed = setSpeed
function Logic.setWalkSpeed(value) walkSpeedValue = value end
Logic.setInfiniteJump = setInfiniteJump
Logic.setFly = setFly
function Logic.setFlySpeed(value) flySpeed = value end
Logic.setFullbright = setFullbright

Logic.disableAll = disableAll

return Logic