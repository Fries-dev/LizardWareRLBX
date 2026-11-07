--[[
    Slot UI - Logic Module (logic.lua)
]]

local Logic = {}

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local TweenService      = game:GetService("TweenService")
local CoreGui           = game:GetService("CoreGui")

local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local connections = {}
local gui, frame, header, resizeHandle
local slots = {}

function Logic.Init(Library, SETTINGS)
    if not Library then
        warn("[Logic]: Library instance missing!")
        return
    end

    local armorSettings = SETTINGS and SETTINGS.ArmorViewer or {}

    -- Items module setup for ArmorViewer
    local ItemsModule
    do
        local Modules = ReplicatedStorage:WaitForChild("Modules", 10)
        local ItemsScript = Modules and Modules:WaitForChild("Items", 10)
        if ItemsScript then
            local ok, m = pcall(require, ItemsScript)
            if ok and type(m) == "table" then ItemsModule = m end
        end
        if not ItemsModule then
            warn("[ArmorViewer] Could not load ReplicatedStorage.Modules.Items")
        end
    end

    local GunTable, ItemByName = {}, {}
    if ItemsModule then
        for _, entry in next, ItemsModule do
            if type(entry) == "table" and entry.Name then
                ItemByName[entry.Name] = entry
                if type(entry.Image) == "table" then
                    GunTable[entry.Name] = entry.Image
                else
                    GunTable[entry.Name] = { Default = entry.Image }
                end
            end
        end
    end

    local function toImageUrl(img)
        if type(img) == "number" then return "rbxassetid://" .. img end
        if type(img) == "string" and img ~= "" then
            if img:find("rbxasset") or img:find("http") then return img end
            if tonumber(img) then return "rbxassetid://" .. img end
        end
        return ""
    end

    local function GetArmor(Character)
        local result, seen = {}, {}
        if not Character or type(Character) == "string" or not ItemsModule then return result end

        for _, child in ipairs(Character:GetChildren()) do
            local armorNumber, skinName = child.Name:match("Armor_(%d+)/(.*)")
            if armorNumber then
                local item = ItemsModule[tonumber(armorNumber)] or ItemsModule[armorNumber]
                if item and item.Type == "Armor" and not seen[item.Name] then
                    seen[item.Name] = true
                    local image = ""
                    if type(item.Image) == "table" then
                        image = (skinName and item.Image[skinName]) or item.Image.Default or ""
                    elseif type(item.Image) == "string" then
                        image = item.Image
                    end
                    table.insert(result, {
                        Skin  = skinName,
                        Name  = item.Name,
                        Type  = item.ArmorType,
                        Image = tostring(image):match("%d+"),
                    })
                end
            end
        end
        return result
    end

    local IGNORED_CLASSES = {
        Pants = true, Shirt = true, ShirtGraphic = true, Accessory = true,
        BodyColors = true, CharacterMesh = true, Humanoid = true, Animator = true,
        Decal = true, Highlight = true, ForceField = true,
    }
    local IGNORED_TYPES = {
        Armor = true, Pants = true, Shirt = true, Clothing = true, Skin = true,
        Cosmetic = true, Outfit = true, Accessory = true, Hat = true,
    }

    local function GetHeldWeapon(character)
        if character == LocalPlayer.Character then
            local vfx = Workspace:FindFirstChild("VFX")
            local vms = vfx and vfx:FindFirstChild("VMs")
            if vms then
                for _, vm in ipairs(vms:GetChildren()) do
                    if vm.Name ~= "IgnoreMe" then return vm.Name end
                end
            end
        end

        local tool = character:FindFirstChildOfClass("Tool")
        if tool then return tool.Name end

        for _, attr in ipairs({ "EquippedTool", "CurrentWeapon", "Weapon", "Equipped" }) do
            local v = character:GetAttribute(attr)
            if type(v) == "string" and v ~= "" then return v end
        end

        for _, child in ipairs(character:GetChildren()) do
            if not child.Name:match("^Armor_") and not IGNORED_CLASSES[child.ClassName] then
                local item = ItemByName[child.Name]
                if item then
                    local t = tostring(item.Type)
                    if not IGNORED_TYPES[t] then return child.Name end
                end
            end
        end
        return nil
    end

    local function GetWeaponIconUrl(weaponName)
        if not weaponName then return "" end
        local entry = GunTable[weaponName]
        if entry then
            return toImageUrl(entry.Default or select(2, next(entry)))
        end
        return ""
    end

    -- Construct ArmorViewer GUI
    gui = Instance.new("ScreenGui")
    gui.Name = "ArmorViewer"
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999999
    gui.Parent = (gethui and gethui()) or CoreGui

    local TOTAL_SLOTS = 8
    local BASE_SLOT_W, BASE_SLOT_H = 130, 114
    local BASE_GAP_X, BASE_GAP_Y = 16, 16
    local BASE_IMG_W, BASE_IMG_H = 102, 90
    local BASE_IMG_X, BASE_IMG_Y = 14, 12
    local BASE_HEADER_H, BASE_HEADER_GAP = 36, 8
    local SLOT_COLOR = Color3.fromRGB(40, 40, 40)
    local baseW, baseH = 568, 244

    frame = Instance.new("Frame")
    frame.Name = "ArmorPanel"
    frame.Size = UDim2.fromOffset(baseW, baseH)
    frame.Position = UDim2.fromOffset(20, 64)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.Active = true
    frame.Parent = gui

    header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.fromOffset(baseW, BASE_HEADER_H)
    header.Position = UDim2.fromOffset(0, -(BASE_HEADER_H + BASE_HEADER_GAP))
    header.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    header.BorderSizePixel = 0
    header.Parent = frame

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 6)
    headerCorner.Parent = header

    local function makeHeaderLabel(font, color, align, size, pos)
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1
        l.Size = size
        l.Position = pos
        l.Font = font
        l.TextSize = 14
        l.TextColor3 = color
        l.TextXAlignment = align
        l.TextTruncate = Enum.TextTruncate.AtEnd
        l.Text = ""
        l.Parent = header
        return l
    end

    local headerName = makeHeaderLabel(Enum.Font.GothamBold, Color3.fromRGB(240, 240, 240), Enum.TextXAlignment.Left, UDim2.new(0.5, -10, 1, -4), UDim2.fromOffset(10, 0))
    local headerInfo = makeHeaderLabel(Enum.Font.Gotham, Color3.fromRGB(190, 190, 190), Enum.TextXAlignment.Right, UDim2.new(0.5, -10, 1, -4), UDim2.new(0.5, 0, 0, 0))

    local healthBack = Instance.new("Frame")
    healthBack.Size = UDim2.new(1, 0, 0, 4)
    healthBack.Position = UDim2.new(0, 0, 1, -4)
    healthBack.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    healthBack.BorderSizePixel = 0
    healthBack.Parent = header

    local healthFill = Instance.new("Frame")
    healthFill.Size = UDim2.fromScale(1, 1)
    healthFill.BackgroundColor3 = Color3.fromRGB(80, 220, 90)
    healthFill.BorderSizePixel = 0
    healthFill.Parent = healthBack

    local function createSlot(name)
        local slot = Instance.new("Frame")
        slot.Name = name
        slot.Size = UDim2.fromOffset(BASE_SLOT_W, BASE_SLOT_H)
        slot.BackgroundColor3 = SLOT_COLOR
        slot.BorderSizePixel = 0
        slot.Parent = frame

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.new(1, 1, 1)
        stroke.Thickness = 4
        stroke.LineJoinMode = Enum.LineJoinMode.Round
        stroke.Parent = slot

        local img = Instance.new("ImageLabel")
        img.Name = "ArmorImage"
        img.BackgroundTransparency = 1
        img.Size = UDim2.fromOffset(BASE_IMG_W, BASE_IMG_H)
        img.Position = UDim2.fromOffset(BASE_IMG_X, BASE_IMG_Y)
        img.ScaleType = Enum.ScaleType.Fit
        img.Parent = slot

        local typeLbl = Instance.new("TextLabel")
        typeLbl.Name = "ArmorType"
        typeLbl.BackgroundTransparency = 1
        typeLbl.Size = UDim2.new(0.7, 0, 0, 12)
        typeLbl.Position = UDim2.fromOffset(6, 4)
        typeLbl.Font = Enum.Font.GothamMedium
        typeLbl.TextSize = 9
        typeLbl.TextColor3 = Color3.fromRGB(160, 200, 255)
        typeLbl.TextXAlignment = Enum.TextXAlignment.Left
        typeLbl.Text = ""
        typeLbl.Visible = false
        typeLbl.Parent = slot

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Name = "ArmorName"
        nameLbl.BackgroundTransparency = 1
        nameLbl.Size = UDim2.new(1, -8, 0, 16)
        nameLbl.Position = UDim2.new(0, 4, 1, -18)
        nameLbl.Font = Enum.Font.Gotham
        nameLbl.TextSize = 11
        nameLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
        nameLbl.Text = ""
        nameLbl.Visible = false
        nameLbl.Parent = slot

        return slot
    end

    for i = 1, TOTAL_SLOTS do slots[i] = createSlot("Slot" .. i) end

    resizeHandle = Instance.new("Frame")
    resizeHandle.Name = "ResizeHandle"
    resizeHandle.Size = UDim2.fromOffset(18, 18)
    resizeHandle.Position = UDim2.new(1, -18, 1, -18)
    resizeHandle.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
    resizeHandle.BackgroundTransparency = 0.25
    resizeHandle.BorderSizePixel = 0
    resizeHandle.ZIndex = 20
    resizeHandle.Parent = frame

    local MIN_SCALE, MAX_SCALE = 0.45, 2.2
    local REF_W, REF_H = 1920, 1080
    local userScale, curScale = 1, 1

    local function screenFactor()
        local vp = Camera.ViewportSize
        return math.min(vp.X / REF_W, vp.Y / REF_H)
    end

    local function layoutMetrics()
        local cols = math.clamp(math.floor(tonumber(armorSettings.Columns) or 4), 1, TOTAL_SLOTS)
        local rows = math.ceil(TOTAL_SLOTS / cols)
        local w = cols * BASE_SLOT_W + (cols - 1) * BASE_GAP_X
        local h = rows * BASE_SLOT_H + (rows - 1) * BASE_GAP_Y
        return cols, w, h
    end

    local function applyScale(us)
        userScale = math.clamp(us, MIN_SCALE, MAX_SCALE)
        local scale = userScale * screenFactor()
        curScale = scale

        local cols, w, h = layoutMetrics()
        baseW, baseH = w, h

        frame.Size = UDim2.fromOffset(math.floor(w * scale), math.floor(h * scale))

        local headerH = math.floor(BASE_HEADER_H * scale)
        header.Size = UDim2.fromOffset(math.floor(w * scale), headerH)
        header.Position = UDim2.fromOffset(0, -(headerH + math.floor(BASE_HEADER_GAP * scale)))
        local hText = math.max(4, math.floor(14 * scale + 0.5))
        headerName.TextSize = hText
        headerInfo.TextSize = hText
        local barH = math.max(2, math.floor(4 * scale))
        healthBack.Size = UDim2.new(1, 0, 0, barH)
        healthBack.Position = UDim2.new(0, 0, 1, -barH)

        local slotW, slotH = math.floor(BASE_SLOT_W * scale), math.floor(BASE_SLOT_H * scale)
        local gapX, gapY = math.floor(BASE_GAP_X * scale), math.floor(BASE_GAP_Y * scale)
        local imgW, imgH = math.floor(BASE_IMG_W * scale), math.floor(BASE_IMG_H * scale)
        local imgX, imgY = math.floor(BASE_IMG_X * scale), math.floor(BASE_IMG_Y * scale)

        for i, slot in ipairs(slots) do
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            slot.Size = UDim2.fromOffset(slotW, slotH)
            slot.Position = UDim2.fromOffset(col * (slotW + gapX), row * (slotH + gapY))

            slot.UIStroke.Thickness = math.max(2, 4 * scale)

            slot.ArmorImage.Size = UDim2.fromOffset(imgW, imgH)
            slot.ArmorImage.Position = UDim2.fromOffset(imgX, imgY)

            local lbl = slot.ArmorName
            lbl.TextSize = math.max(4, math.floor(11 * scale + 0.5))
            lbl.Size = UDim2.new(1, -math.floor(8 * scale), 0, math.floor(16 * scale))
            lbl.Position = UDim2.new(0, math.floor(4 * scale), 1, -math.floor(18 * scale))

            local tl = slot.ArmorType
            tl.TextSize = math.max(4, math.floor(9 * scale + 0.5))
            tl.Size = UDim2.new(0.7, 0, 0, math.floor(12 * scale))
            tl.Position = UDim2.fromOffset(math.floor(6 * scale), math.floor(4 * scale))
        end
    end

    local function clampToScreen()
        local vp = Camera.ViewportSize
        local w, h = math.floor(baseW * curScale), math.floor(baseH * curScale)
        local top = armorSettings.ShowHeader and math.floor((BASE_HEADER_H + BASE_HEADER_GAP) * curScale) or 0
        local x = math.clamp(frame.Position.X.Offset, 0, math.max(0, vp.X - w))
        local y = math.clamp(frame.Position.Y.Offset, top, math.max(top, vp.Y - h))
        frame.Position = UDim2.fromOffset(x, y)
    end

    applyScale(userScale)
    clampToScreen()

    -------------------------------------------------
    -- Input: drag, resize, toggle key, viewport changes
    -------------------------------------------------
    local function connect(signal, fn)
        local c = signal:Connect(fn)
        table.insert(connections, c)
        return c
    end

    local isResizing, resizeStartMouse, resizeStartSize = false, nil, nil
    local dragging, dragStartMouse, dragStartPos = false, nil, nil

    local function isPress(input)
        return input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
    end

    connect(resizeHandle.InputBegan, function(input)
        if isPress(input) and not armorSettings.LockPosition then
            isResizing = true
            dragging = false
            resizeStartMouse = UserInputService:GetMouseLocation()
            resizeStartSize = Vector2.new(baseW * curScale, baseH * curScale)
        end
    end)

    connect(frame.InputBegan, function(input)
        if isPress(input) and not isResizing and not armorSettings.LockPosition then
            dragging = true
            dragStartMouse = UserInputService:GetMouseLocation()
            dragStartPos = Vector2.new(frame.Position.X.Offset, frame.Position.Y.Offset)
        end
    end)

    connect(UserInputService.InputEnded, function(input)
        if isPress(input) then
            isResizing = false
            dragging = false
        end
    end)

    connect(UserInputService.InputChanged, function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then return end

        local mouse = UserInputService:GetMouseLocation()
        if isResizing then
            local delta = mouse - resizeStartMouse
            local f = screenFactor()
            local sx = (resizeStartSize.X + delta.X) / (baseW * f)
            local sy = (resizeStartSize.Y + delta.Y) / (baseH * f)
            applyScale(math.max(sx, sy))
            clampToScreen()
        elseif dragging then
            local delta = mouse - dragStartMouse
            frame.Position = UDim2.fromOffset(dragStartPos.X + delta.X, dragStartPos.Y + delta.Y)
            clampToScreen()
        end
    end)

    local function GetTarget()
        local t = rawget(_G, "scorpionTargeting")
        local char = t and t.TargetCharacter
        if char and char.Parent then return char end

        local best, bestDist = nil, armorSettings.MaxDistance or 500
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local root = plr.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    local d = (Camera.CFrame.Position - root.Position).Magnitude
                    if d < bestDist then best, bestDist = plr.Character, d end
                end
            end
        end
        return best
    end

    -- Real-time feature loop (FOV + ArmorViewer)
    local scanTimer = 0
    local healthShown = nil

    local renderConn = RunService.RenderStepped:Connect(function(dt)
        Camera = Workspace.CurrentCamera

        -- FOV Logic
        if SETTINGS and SETTINGS.Fov and SETTINGS.Fov.Enabled then
            local targetFOV = Library.Flags["Aim_FOV"] or SETTINGS.Fov.Value
            if Camera then
                Camera.FieldOfView = targetFOV
            end
        end

        -- ArmorViewer Logic
        if not armorSettings.Enabled then
            frame.Visible = false
            return
        end

        resizeHandle.Visible = not armorSettings.LockPosition
        header.Visible = armorSettings.ShowHeader
        for _, slot in ipairs(slots) do
            slot.BackgroundTransparency = armorSettings.SlotTransparency or 0
        end

        local target = GetTarget()
        local root = target and (target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("UpperTorso"))
        local dist = root and (Camera.CFrame.Position - root.Position).Magnitude
        if target and dist and dist > (armorSettings.MaxDistance or 500) then target = nil end

        if not target then
            frame.Visible = false
            return
        end

        if armorSettings.ShowHeader then
            local plr = Players:GetPlayerFromCharacter(target)
            headerName.Text = plr and plr.DisplayName or target.Name

            local hum = target:FindFirstChildOfClass("Humanoid")
            local parts = {}
            if hum and hum.MaxHealth > 0 then
                local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                healthShown = healthShown and (healthShown + (pct - healthShown) * math.min(1, dt * 12)) or pct
                healthFill.Size = UDim2.fromScale(healthShown, 1)
                if armorSettings.ShowHealthText then
                    table.insert(parts, math.floor(hum.Health + 0.5) .. " HP")
                end
            end
            if dist then table.insert(parts, math.floor(dist) .. " studs") end
            headerInfo.Text = table.concat(parts, "  |  ")
        end

        scanTimer = scanTimer + dt
        if scanTimer >= (armorSettings.UpdateInterval or 0.1) then
            scanTimer = 0
            local armorData = GetArmor(target)
            local weaponName = GetHeldWeapon(target)

            for _, slot in ipairs(slots) do
                slot.Visible = not armorSettings.HideEmptySlots
                slot.ArmorImage.Image = ""
                slot.ArmorName.Text = ""
                slot.ArmorType.Text = ""
            end

            if weaponName then
                local s = slots[1]
                s.Visible = true
                s.ArmorImage.Image = GetWeaponIconUrl(weaponName)
                s.ArmorName.Text = weaponName
                s.ArmorType.Text = "Weapon"
            end

            for i, armor in ipairs(armorData) do
                local slot = slots[i + 1]
                if not slot then break end
                slot.Visible = true
                slot.ArmorImage.Image = armor.Image and ("rbxassetid://" .. armor.Image) or ""
                slot.ArmorName.Text = armor.Name or ""
                slot.ArmorType.Text = armor.Type and tostring(armor.Type) or ""
            end

            for _, slot in ipairs(slots) do
                slot.ArmorName.Visible = armorSettings.ShowNames and slot.ArmorName.Text ~= ""
            end
        end

        frame.Visible = true
    end)

    table.insert(connections, renderConn)

    print("[Logic Module]: Initialized successfully.")
end

-- Function to turn off and reset all active features
function Logic.DisableAll(SETTINGS)
    if SETTINGS then
        -- Reset FOV
        if SETTINGS.Fov then
            SETTINGS.Fov.Enabled = false
            if Camera then
                Camera.FieldOfView = SETTINGS.Fov.Base
            end
        end
    end

    for _, c in ipairs(connections) do
        c:Disconnect()
    end
    table.clear(connections)

    if gui then
        gui:Destroy()
    end

    print("[Logic Module]: All features disabled and reset to default.")
end

return Logic