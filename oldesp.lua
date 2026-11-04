
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

