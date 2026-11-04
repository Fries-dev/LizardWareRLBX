------------------
-- Player ESP (ScreenGui + skeleton drawings)
------------------
local workspace = (cloneref and cloneref(game:GetService("Workspace"))) or game:GetService("Workspace")
local run = (cloneref and cloneref(game:GetService("RunService"))) or game:GetService("RunService")
local http_service = (cloneref and cloneref(game:GetService("HttpService"))) or game:GetService("HttpService")
local players = (cloneref and cloneref(game:GetService("Players"))) or game:GetService("Players")

local vec2 = Vector2.new
local dim2 = UDim2.new
local dim_offset = UDim2.fromOffset
local rgb = Color3.fromRGB

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

-- These get overwritten by UI flags via Logic.refreshEspFlags()
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

        local Top, TopIsRendered = esp:get_screen_pos(ViewportTop)
        local Bottom, BottomIsRendered = esp:get_screen_pos(ViewportBottom)

        local Width = math.max(math.floor(math.abs(Top.X - Bottom.X)), 3)
        local Height = math.max(math.floor(math.max(math.abs(Bottom.Y - Top.Y), Width / 2)), 3)
        local BoxSize = Vector2.new(math.floor(math.max(Height / 1.5, Width)), Height)
        local BoxPosition = Vector2.new(
            math.floor(Top.X * 0.5 + Bottom.X * 0.5 - BoxSize.X * 0.5),
            math.floor(math.min(Top.Y, Bottom.Y))
        )

        return BoxSize, BoxPosition, TopIsRendered or BottomIsRendered, Distance
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

        -- Corner boxes
        objects["corners"] = esp:create("Frame", {
            Visible = true,
            Parent = esp.cache,
            BackgroundTransparency = 1,
            Position = dim2(0, -1, 0, 2),
            Name = "\0",
            Size = dim2(1, 0, 1, 0),
            BorderSizePixel = 0,
        })

        local function makeCorner(props, innerColor)
            local frame = esp:create("Frame", props)
            esp:create("Frame", {
                Parent = frame,
                Position = dim2(0, 1, 0, 1),
                Size = dim2(1, -2, 1, -2),
                BorderSizePixel = 0,
                BackgroundColor3 = innerColor or espFlags["Box_Color"].Color,
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
            BorderColor3 = rgb(0, 0, 0), Rotation = 180, Parent = objects["corners"], Name = "line",
            Position = dim2(0, 0, 1, -5), AnchorPoint = vec2(0, 1), Size = dim2(0, 3, 0.25, 0), BorderSizePixel = 0, BackgroundColor3 = rgb(0, 0, 0),
        })
        objects["7"] = makeCorner({
            AnchorPoint = vec2(1, 1), Parent = objects["corners"], Name = "line",
            Position = dim2(1, 0, 1, -2), Size = dim2(0.4, 0, 0, 3), BorderSizePixel = 0, BackgroundColor3 = rgb(0, 0, 0),
        })
        objects["8"] = makeCorner({
            BorderColor3 = rgb(0, 0, 0), Rotation = 180, Parent = objects["corners"], Name = "line",
            Position = dim2(1, 0, 1, -5), AnchorPoint = vec2(1, 1), Size = dim2(0, 3, 0.25, 0), BorderSizePixel = 0, BackgroundColor3 = rgb(0, 0, 0),
        })

        -- Healthbar
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

        -- Skeleton lines
        if Drawing then
            for _ = 1, #bones do
                local line = Drawing.new("Line")
                line.Color = espFlags["Skeletons_Color"].Color
                line.Thickness = 1
                line.Visible = false
                data.drawings[#data.drawings + 1] = line
            end
        end

        -- Data functions
        data.health_changed = function(value)
            if not espFlags["Healthbar"] or not data.info.humanoid then return end
            local humanoid = data.info.humanoid
            local multiplier = math.clamp(value / math.max(humanoid.MaxHealth, 1), 0, 1)
            local color = espFlags["Health_Low"].Color:Lerp(espFlags["Health_High"].Color, multiplier)
            objects["healthbar"].Size = UDim2.new(1, -2, multiplier, -2)
            objects["healthbar"].Position = UDim2.new(0, 1, 1 - multiplier, 1)
            objects["healthbar"].BackgroundColor3 = color
        end

        data.tool_added = function(item)
            if not item:IsA("Tool") then return end
            local exists = data.info.character and data.info.character:FindFirstChild(item.Name)
            objects["weapon"].Text = item.Name
            objects["weapon"].Parent = (espFlags["Weapon"] and exists and objects["holder"]) or esp.cache
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
        for _, v in ipairs(players:GetPlayers()) do
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

    esp.connection = run.RenderStepped:Connect(function()
        if not espFlags["Enabled"] then return end
        camera = workspace.CurrentCamera
        if not camera then return end

        for _, player in ipairs(players:GetPlayers()) do
            local data = esp[player.Name]
            if not data then continue end

            local character = data.info.character
            local humanoid = data.info.humanoid
            if not (character and humanoid and humanoid.Health > 0) then continue end

            -- team check
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

            -- Skeletons
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
        for _, player in ipairs(players:GetPlayers()) do
            esp:remove_object(player)
        end
        if esp.connection then esp.connection:Disconnect() end
        if esp.player_added then esp.player_added:Disconnect() end
        if esp.player_removed then esp.player_removed:Disconnect() end
        pcall(function() esp.cache:Destroy() end)
        pcall(function() esp.screengui:Destroy() end)
    end
end

-- Init existing players
for _, v in ipairs(players:GetPlayers()) do
    if v ~= localPlayer then
        esp:create_object(v)
    end
end

esp.player_added = players.PlayerAdded:Connect(function(v)
    esp:create_object(v)
end)
esp.player_removed = players.PlayerRemoving:Connect(function(v)
    esp:remove_object(v)
end)
