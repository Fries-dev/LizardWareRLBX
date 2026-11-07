--[[
    Slot UI - Logic Module
    Handles backend features and binds them to UI library flags.
]]

local Logic = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

function Logic.Init(LibraryInstance)
    local Library = LibraryInstance or _G.Library
    if not Library then
        warn("[Logic]: Library instance not found!")
        return
    end

    -- Run-loop for real-time feature updates (like FOV)
    RunService.RenderStepped:Connect(function()
        -- FOV Logic Feature
        local TargetFOV = Library.Flags["Aim_FOV"]
        if TargetFOV and Camera then
            Camera.FieldOfView = TargetFOV
        end
        
        -- You can add more feature checks here later, e.g.:
        -- local speedVal = Library.Flags["Move_Speed"]
        -- if speedVal and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        --     LocalPlayer.Character.Humanoid.WalkSpeed = speedVal
        -- end
    end)

    print("[Logic Module]: Successfully initialized and bound to UI flags.")
end

return Logic