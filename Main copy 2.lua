-- Logic.lua
-- All state + functions for Pepsi's World. Returns a table of setters that Main.lua calls from the UI.

local Logic = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local localPlayer = Players.LocalPlayer


local nodeEspEnabled = false
local worldHighlightEnabled = false
local highlightSelection = { All = true }
local worldMaxDistance = 500
local worldHighlightColor = Color3.fromRGB(0, 255, 200)
local activeWorldGuis = {}
local activeWorldHighlights = {}
local worldRenderConnection = nil

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

        for _, hl in ipairs(activeWorldHighlights) do
            if hl and hl.Parent and hl.Adornee then
                local pos = getObjectPosition(hl.Adornee)
                if pos then
                    local dist = (rootPos - pos).Magnitude
                    hl.Enabled = (dist <= worldMaxDistance)
                end
            end
        end
    end
end

local function updateHighlightColors()
    for _, hl in ipairs(activeWorldHighlights) do
        if hl and hl.Parent then
            hl.FillColor = worldHighlightColor
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
        end
    end
end

local function refreshWorldEsp()
    removeWorldEsp()

    if not nodeEspEnabled
        then
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
    updateDistanceCheck()
    worldRenderConnection = RunService.RenderStepped:Connect(updateDistanceCheck)
end


------------------
-- Disable everything
------------------
local function disableAll()

    nodeEspEnabled = false
    worldHighlightEnabled = false
    refreshWorldEsp()

    if inputBeganConn then inputBeganConn:Disconnect() inputBeganConn = nil end
    if inputEndedConn then inputEndedConn:Disconnect() inputEndedConn = nil end
end




------------------
-- Public API (called from Main.lua)
------------------
local worldToggles = {
    Nodes = function(v) nodeEspEnabled = v end
}

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

Logic.disableAll = disableAll

return Logic