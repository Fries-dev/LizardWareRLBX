--[[
    Slot UI - Logic Module (logic.lua)
]]

local Logic = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

function Logic.Init(Library, SETTINGS)
    if not Library then
        warn("[Logic]: Library instance missing!")
        return
    end

    -- Real-time feature loop
    RunService.RenderStepped:Connect(function()
        if SETTINGS and SETTINGS.Fov and SETTINGS.Fov.Enabled then
            local targetFOV = Library.Flags["Aim_FOV"] or SETTINGS.Fov.Value
            if Camera then
                Camera.FieldOfView = targetFOV
            end
        end
    end)

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
        
        -- Add future feature resets here (e.g., speed, ESP, etc.)
    end
    print("[Logic Module]: All features disabled and reset to default.")
end

return Logic