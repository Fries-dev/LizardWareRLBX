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

-- Noclip
local noclipEnabled = false
local noclipConnection = nil
local noclipChanged = {} -- parts we turned CanCollide off on

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
-- Disable everything
------------------
local function disableAll()
    setNoclip(false)
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

-- Shutdown
Logic.disableAll = disableAll

return Logic