-- FOV Management Logic Script
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local FOVLogic = {}

-- Function to apply FOV changes safely
function FOVLogic.Init(LibraryInstance)
    -- Default fallback if library isn't passed
    local Library = LibraryInstance or _G.Library
    if not Library then return end

    -- Connection to update FOV dynamically when slider/flag changes
    RunService.RenderStepped:Connect(function()
        -- Read the FOV value from the library flags (defaults to 70 if not set)
        local TargetFOV = Library.Flags["Aim_FOV"] or 70
        
        if Camera then
            -- Apply the FOV value to the active game camera
            Camera.FieldOfView = TargetFOV
        end
    end)
    
    print("[FOV Logic]: Initialized and bound to Camera.")
end

return FOVLogic