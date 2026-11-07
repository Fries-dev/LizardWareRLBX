-- [[ Dumped Decompiled Script Execution ]]
-- Chunk: loadstring_chunk
-- Timestamp: 2026-11-05 19:35:42
-- Size: 153780 bytes

local _dbg = {}
do
    local d = debug
    _dbg.tb   = function(...) return d.traceback(...) end
    _dbg.info = function(...) return d.info(...) end
    _dbg.gup  = function(...) return d.getupvalues(...) end
    _dbg.gc   = function(...) return d.getconstants(...) end
    _dbg.sc   = function(...) return d.setconstant(...) end
    _dbg.gs   = function(...) return d.getstack(...) end
    _dbg.ss   = function(...) return d.setstack(...) end
end

local _env = getgenv and getgenv() or {}
local _hook = (hookfunction and function(a,b) return hookfunction(a,b) end) or nil
local _conn = (getconnections and function(a) return getconnections(a) end) or nil
local _senv = (getsenv and function(a) return getsenv(a) end) or nil
local _shp  = (sethiddenproperty and function(a,b,c) return sethiddenproperty(a,b,c) end) or nil
local _sff  = (setfflag and function(a,b) return setfflag(a,b) end) or nil
local _sr   = (setreadonly and function(a,b) return setreadonly(a,b) end) or nil
local _ilv  = (isvalidlevel and function(a) return isvalidlevel(a) end) or nil
local _gs2  = (getstack and function(a) return getstack(a) end) or nil
local _ss2  = (setstack and function(a,b,c) return setstack(a,b,c) end) or nil

local CoreGuiRef    = cloneref and cloneref(game:GetService("CoreGui")) or game:GetService("CoreGui")
local gethuiFn      = gethui or function() return CoreGuiRef end
local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local Workspace     = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService  = game:GetService("SoundService")
local Debris        = game:GetService("Debris")
local TweenService  = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService   = game:GetService("HttpService")
local Camera        = Workspace.CurrentCamera
local Client        = Players.LocalPlayer
local SETTINGS
SETTINGS = {
    ArmorViewer  = {Enabled=false, ShowLocal=false, MaxDistance=500}
}
local function CreateUndetectedGui(name)
    local gui = Instance.new("ScreenGui")
    gui.Name = " "
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999999
    gui.Parent = gethuiFn()
    return gui
end
do
    local Modules = ReplicatedStorage:FindFirstChild('Modules') or ReplicatedStorage:WaitForChild('Modules', 10)
    local ItemsModule
    if Modules then
        local ok, m = pcall(require, Modules:WaitForChild('Items', 5))
        if ok then ItemsModule = m end
    end
    if not ItemsModule then return end

    local GunTable = {}
    for _, gun in next, ItemsModule do
        if typeof(gun.Image) == 'table' then
            GunTable[gun.Name] = gun.Image
        else
            GunTable[gun.Name] = {['Default'] = gun.Image}
        end
    end

    local function GetArmor(Character)
        local result, seen = {}, {}
        if not Character or type(Character) == 'string' then return result end
        for _, child in Character:GetChildren() do
            local armorNumber, skinName = child.Name:match('Armor_(%d+)/(.*)')
            if not armorNumber then continue end
            local key = tonumber(armorNumber)
            if not key then continue end
            local item = ItemsModule[key]
            if not item or item.Type ~= 'Armor' then continue end
            if table.find(seen, item.Name) then continue end
            local image = ''
            if type(item.Image) == 'table' then
                if skinName and item.Image[skinName] then
                    image = item.Image[skinName]
                elseif item.Image.Default then
                    image = item.Image.Default
                end
            elseif type(item.Image) == 'string' then
                image = item.Image
            end
            local id = string.match(image or '', '%d+')
            table.insert(seen, item.Name)
            table.insert(result, {
                Skin = skinName,
                Name = item.Name,
                Type = item.ArmorType,
                Image = id
            })
        end
        return result
    end

    -------------------------------------------------
    -- Resizable Armor Viewer (8-slot grid)
    -------------------------------------------------
    local ArmorGui = CreateUndetectedGui("ArmorViewer")

    -- Base sizes (the scale we start at)
    local BASE_WIDTH  = 568
    local BASE_HEIGHT = 245
    local BASE_SLOT_W = 130
    local BASE_SLOT_H = 114
    local BASE_GAP_X  = 16
    local BASE_GAP_Y  = 16
    local BASE_IMG_W  = 102
    local BASE_IMG_H  = 90
    local BASE_IMG_X  = 14
    local BASE_IMG_Y  = 12

    local frame32 = Instance.new("Frame")
    frame32.Name = "Frame 32"
    frame32.Size = UDim2.fromOffset(BASE_WIDTH, BASE_HEIGHT)
    frame32.Position = UDim2.new(0, 20, 0, 20)
    frame32.BackgroundTransparency = 1
    frame32.BorderSizePixel = 0
    frame32.Visible = false
    frame32.Parent = ArmorGui

    local function createSlot(name, basePos)
        local slot = Instance.new("Frame")
        slot.Name = name
        slot.Size = UDim2.fromOffset(BASE_SLOT_W, BASE_SLOT_H)
        slot.Position = basePos
        slot.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        slot.BackgroundTransparency = 0
        slot.BorderSizePixel = 0
        slot.Visible = true
        slot.Parent = frame32

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.new(1, 1, 1)
        stroke.Thickness = 4
        stroke.Transparency = 0
        stroke.LineJoinMode = Enum.LineJoinMode.Round
        stroke.Parent = slot

        local gradient = Instance.new("UIGradient")
        gradient.Rotation = 37.84
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,     Color3.fromRGB(23, 69, 97)),
            ColorSequenceKeypoint.new(0.149, Color3.fromRGB(207, 216, 223)),
            ColorSequenceKeypoint.new(0.279, Color3.fromRGB(188, 207, 218)),
            ColorSequenceKeypoint.new(0.438, Color3.fromRGB(27, 86, 120)),
            ColorSequenceKeypoint.new(0.567, Color3.fromRGB(24, 105, 164)),
            ColorSequenceKeypoint.new(0.683, Color3.fromRGB(20, 94, 145)),
            ColorSequenceKeypoint.new(0.803, Color3.fromRGB(23, 69, 80)),
            ColorSequenceKeypoint.new(0.880, Color3.fromRGB(16, 87, 138)),
            ColorSequenceKeypoint.new(0.976, Color3.fromRGB(117, 196, 42)),
            ColorSequenceKeypoint.new(1,     Color3.fromRGB(117, 196, 42))
        })
        gradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 0)
        })
        gradient.Parent = stroke

        -- Image that will show the armor piece
        local img = Instance.new("ImageLabel")
        img.Name = "ArmorImage"
        img.BackgroundTransparency = 1
        img.Size = UDim2.fromOffset(BASE_IMG_W, BASE_IMG_H)
        img.Position = UDim2.fromOffset(BASE_IMG_X, BASE_IMG_Y)
        img.Image = ""
        img.ScaleType = Enum.ScaleType.Fit
        img.Visible = true
        img.Parent = slot

        -- Optional name label under the image
        local nameLbl = Instance.new("TextLabel")
        nameLbl.Name = "ArmorName"
        nameLbl.BackgroundTransparency = 1
        nameLbl.Size = UDim2.new(1, -8, 0, 16)
        nameLbl.Position = UDim2.new(0, 4, 1, -18)
        nameLbl.Font = Enum.Font.Gotham
        nameLbl.TextSize = 11
        nameLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
        nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
        nameLbl.Text = ""
        nameLbl.Visible = false
        nameLbl.Parent = slot

        return slot
    end

    -- Create the 8 slots
    local slots = {}
    slots[1] = createSlot("Slot Logo", UDim2.fromOffset(0, 0))
    slots[2] = createSlot("Slot1",     UDim2.fromOffset(BASE_SLOT_W + BASE_GAP_X, 0))
    slots[3] = createSlot("Slot 2",    UDim2.fromOffset((BASE_SLOT_W + BASE_GAP_X) * 2, 0))
    slots[4] = createSlot("Slot 3",    UDim2.fromOffset((BASE_SLOT_W + BASE_GAP_X) * 3, 0))
    slots[5] = createSlot("Slot 4",    UDim2.fromOffset(0, BASE_SLOT_H + BASE_GAP_Y))
    slots[6] = createSlot("Slot 5",    UDim2.fromOffset(BASE_SLOT_W + BASE_GAP_X, BASE_SLOT_H + BASE_GAP_Y))
    slots[7] = createSlot("Slot 6",    UDim2.fromOffset((BASE_SLOT_W + BASE_GAP_X) * 2, BASE_SLOT_H + BASE_GAP_Y))
    slots[8] = createSlot("Slot 7",    UDim2.fromOffset((BASE_SLOT_W + BASE_GAP_X) * 3, BASE_SLOT_H + BASE_GAP_Y))

    -------------------------------------------------
    -- Resize handle (bottom-right corner)
    -------------------------------------------------
    local resizeHandle = Instance.new("Frame")
    resizeHandle.Name = "ResizeHandle"
    resizeHandle.Size = UDim2.fromOffset(18, 18)
    resizeHandle.Position = UDim2.new(1, -18, 1, -18)
    resizeHandle.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
    resizeHandle.BackgroundTransparency = 0.25
    resizeHandle.BorderSizePixel = 0
    resizeHandle.ZIndex = 20
    resizeHandle.Parent = frame32

    local cornerIndicator = Instance.new("Frame")
    cornerIndicator.Size = UDim2.fromOffset(10, 10)
    cornerIndicator.Position = UDim2.new(1, -12, 1, -12)
    cornerIndicator.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
    cornerIndicator.BorderSizePixel = 0
    cornerIndicator.ZIndex = 21
    cornerIndicator.Parent = resizeHandle

    -------------------------------------------------
    -- Resize + Drag logic
    -------------------------------------------------
    local MIN_SCALE = 0.45
    local MAX_SCALE = 2.2
    local currentScale = 1

    local function applyScale(scale)
        scale = math.clamp(scale, MIN_SCALE, MAX_SCALE)
        currentScale = scale

        local newW = math.floor(BASE_WIDTH  * scale)
        local newH = math.floor(BASE_HEIGHT * scale)
        frame32.Size = UDim2.fromOffset(newW, newH)

        local slotW = math.floor(BASE_SLOT_W * scale)
        local slotH = math.floor(BASE_SLOT_H * scale)
        local gapX  = math.floor(BASE_GAP_X  * scale)
        local gapY  = math.floor(BASE_GAP_Y  * scale)
        local imgW  = math.floor(BASE_IMG_W  * scale)
        local imgH  = math.floor(BASE_IMG_H  * scale)
        local imgX  = math.floor(BASE_IMG_X  * scale)
        local imgY  = math.floor(BASE_IMG_Y  * scale)

        local positions = {
            UDim2.fromOffset(0, 0),
            UDim2.fromOffset(slotW + gapX, 0),
            UDim2.fromOffset((slotW + gapX) * 2, 0),
            UDim2.fromOffset((slotW + gapX) * 3, 0),
            UDim2.fromOffset(0, slotH + gapY),
            UDim2.fromOffset(slotW + gapX, slotH + gapY),
            UDim2.fromOffset((slotW + gapX) * 2, slotH + gapY),
            UDim2.fromOffset((slotW + gapX) * 3, slotH + gapY),
        }

        for i, slot in ipairs(slots) do
            slot.Size = UDim2.fromOffset(slotW, slotH)
            slot.Position = positions[i]

            local stroke = slot:FindFirstChildOfClass("UIStroke")
            if stroke then
                stroke.Thickness = math.max(2, 4 * scale)
            end

            local img = slot:FindFirstChild("ArmorImage")
            if img then
                img.Size = UDim2.fromOffset(imgW, imgH)
                img.Position = UDim2.fromOffset(imgX, imgY)
            end

            local nameLbl = slot:FindFirstChild("ArmorName")
            if nameLbl then
                nameLbl.TextSize = math.max(9, math.floor(11 * scale))
                nameLbl.Position = UDim2.new(0, 4, 1, -math.floor(18 * scale))
            end
        end
    end

    -- Resize
    local isResizing = false
    local startMouse, startSize

    resizeHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isResizing = true
            startMouse = UserInputService:GetMouseLocation()
            startSize  = frame32.AbsoluteSize
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isResizing = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not isResizing then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end

        local currentMouse = UserInputService:GetMouseLocation()
        local delta = currentMouse - startMouse
        local scaleX = (startSize.X + delta.X) / BASE_WIDTH
        local scaleY = (startSize.Y + delta.Y) / BASE_HEIGHT
        applyScale(math.max(scaleX, scaleY))
    end)

    -- Drag whole panel
    local dragging = false
    local dragStart, frameStart

    frame32.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and not isResizing then
            dragging = true
            dragStart = Vector2.new(input.Position.X, input.Position.Y)
            frameStart = frame32.AbsolutePosition
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging or isResizing then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

        local pos = UserInputService:GetMouseLocation()
        local delta = pos - dragStart
        frame32.Position = UDim2.fromOffset(frameStart.X + delta.X, frameStart.Y + delta.Y)
    end)

    -------------------------------------------------
    -- Update slots with armor data
    -------------------------------------------------
    local function ClearSlots()
        for _, slot in ipairs(slots) do
            local img = slot:FindFirstChild("ArmorImage")
            local nameLbl = slot:FindFirstChild("ArmorName")
            if img then img.Image = "" end
            if nameLbl then
                nameLbl.Text = ""
                nameLbl.Visible = false
            end
        end
    end

    local function PopulateSlots(armorData)
        ClearSlots()
        for i, armor in ipairs(armorData) do
            if i > #slots then break end
            local slot = slots[i]
            local img = slot:FindFirstChild("ArmorImage")
            local nameLbl = slot:FindFirstChild("ArmorName")

            local imageUrl = ""
            if armor.Image and tonumber(armor.Image) then
                imageUrl = "rbxassetid://" .. tostring(armor.Image)
            elseif armor.Skin and GunTable[armor.Name] and GunTable[armor.Name][armor.Skin] then
                imageUrl = GunTable[armor.Name][armor.Skin]
            elseif GunTable[armor.Name] and GunTable[armor.Name]["Default"] then
                imageUrl = GunTable[armor.Name]["Default"]
            end

            if img then
                img.Image = imageUrl
            end
            if nameLbl then
                nameLbl.Text = armor.Name or ""
                nameLbl.Visible = (armor.Name ~= nil and armor.Name ~= "")
            end
        end
    end

    -------------------------------------------------
    -- Main update loop
    -------------------------------------------------
    local lastHash = ""
    RunService.RenderStepped:Connect(function()
        if not SETTINGS.ArmorViewer.Enabled then
            frame32.Visible = false
            return
        end

        local Targeting = _G.scorpionTargeting
        local target = Targeting and Targeting.TargetCharacter
        if not target or not target.Parent then
            frame32.Visible = false
            lastHash = ""
            return
        end

        local root = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("UpperTorso")
        if root then
            local dist = (Camera.CFrame.Position - root.Position).Magnitude
            if dist > SETTINGS.ArmorViewer.MaxDistance then
                frame32.Visible = false
                return
            end
        end

        local armorData = GetArmor(target)
        local hash = HttpService:JSONEncode(armorData) .. target.Name
        if hash ~= lastHash then
            lastHash = hash
            PopulateSlots(armorData)
        end

        frame32.Visible = true
    end)
end