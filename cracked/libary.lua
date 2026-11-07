--[[
    Slot UI Library
]]

local Env = (getgenv and getgenv()) or _G

if Env.Library and type(Env.Library.Unload) == "function" then
    pcall(function()
        Env.Library:Unload()
    end)
end

local cloneref = cloneref or function(Object) return Object end
local function GetService(Name) return cloneref(game:GetService(Name)) end

local UserInputService = GetService("UserInputService")
local HttpService = GetService("HttpService")
local TweenService = GetService("TweenService")
local CoreGui = GetService("CoreGui")

local Vector2New = Vector2.new
local UDim2New = UDim2.new
local UDimNew = UDim.new
local FromRGB = Color3.fromRGB

local SlotGradient = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.new(0.09, 0.27, 0.38)),
    ColorSequenceKeypoint.new(0.15, Color3.new(0.81, 0.84, 0.87)),
    ColorSequenceKeypoint.new(0.43, Color3.new(0.10, 0.33, 0.47)),
    ColorSequenceKeypoint.new(0.56, Color3.new(0.09, 0.41, 0.64)),
    ColorSequenceKeypoint.new(0.80, Color3.new(0.09, 0.27, 0.31)),
    ColorSequenceKeypoint.new(1, Color3.new(0.45, 0.76, 0.16)),
})

local Library = {
    Flags = {},
    Theme = {
        Background = FromRGB(40, 40, 40),
        Inline = FromRGB(28, 28, 28),
        Element = FromRGB(56, 56, 56),
        Text = FromRGB(171, 171, 171),
        TextActive = FromRGB(255, 255, 255),
        Close = FromRGB(200, 60, 60),
        Accent = FromRGB(24, 105, 164),
    },
    Font = Font.new("rbxasset://fonts/families/Inter.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
}

local function Create(Class, Props)
    local Item = Instance.new(Class)
    if Item:IsA("GuiObject") then Item.BorderSizePixel = 0 end
    if Item:IsA("TextLabel") or Item:IsA("TextButton") or Item:IsA("TextBox") then
        Item.FontFace = Library.Font
        Item.TextSize = 12
        Item.TextColor3 = Library.Theme.Text
        Item.BackgroundTransparency = 1
    end
    for Property, Value in pairs(Props) do
        if Property ~= "Parent" then Item[Property] = Value end
    end
    Item.Parent = Props.Parent
    return Item
end

local function GradientStroke(Parent, Thickness)
    local Stroke = Create("UIStroke", {
        Parent = Parent,
        Color = Color3.new(1, 1, 1),
        Thickness = Thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    })
    Create("UIGradient", {
        Parent = Stroke,
        Rotation = 37.84,
        Color = SlotGradient
    })
    return Stroke
end

local function MakeDraggable(Handle, Target)
    local Dragging = false
    local DragStart, StartPosition
    Handle.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
            Dragging = true
            DragStart = Input.Position
            StartPosition = Target.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(Input)
        if Dragging and (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch) then
            local Delta = Input.Position - DragStart
            Target.Position = UDim2New(StartPosition.X.Scale, StartPosition.X.Offset + Delta.X, StartPosition.Y.Scale, StartPosition.Y.Offset + Delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
            Dragging = false
        end
    end)
end

function Library:Unload()
    if self.Holder then self.Holder:Destroy() end
    Env.Library = nil
end

Library.Holder = Create("ScreenGui", {
    Name = HttpService:GenerateGUID(false),
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    Parent = (gethui and gethui()) or CoreGui
})

function Library:Window(Data)
    Data = Data or {}
    local WindowSize = Data.Size or UDim2New(0, 686, 0, 678)

    local WindowClass = { Pages = {} }

    local MainFrame = Create("Frame", {
        Name = "Window",
        Parent = self.Holder,
        AnchorPoint = Vector2New(0.5, 0.5),
        Position = UDim2New(0.5, 0, 0.5, 0),
        Size = WindowSize,
        BackgroundColor3 = Library.Theme.Background,
        Active = true
    })
    GradientStroke(MainFrame, 2)
    MakeDraggable(MainFrame, MainFrame)

    local Header = Create("Frame", {
        Name = "Header",
        Parent = MainFrame,
        Position = UDim2New(0, 12, 0, 12),
        Size = UDim2New(1, -24, 0, 48),
        BackgroundTransparency = 1
    })

    local LogoBox = Create("Frame", {
        Name = "LogoBox",
        Parent = Header,
        Size = UDim2New(0, 48, 0, 48),
        BackgroundColor3 = Library.Theme.Inline
    })
    GradientStroke(LogoBox, 1)

    local CloseButton = Create("TextButton", {
        Name = "CloseButton",
        Parent = Header,
        AnchorPoint = Vector2New(1, 0),
        Position = UDim2New(1, 0, 0, 0),
        Size = UDim2New(0, 48, 0, 48),
        BackgroundColor3 = Library.Theme.Inline,
        Text = ""
    })
    GradientStroke(CloseButton, 1)

    Create("TextLabel", {
        Parent = CloseButton,
        Size = UDim2New(1, 0, 1, 0),
        Text = "X",
        TextSize = 16,
        TextColor3 = Library.Theme.Close,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center
    })

    CloseButton.MouseButton1Click:Connect(function()
        Library:Unload()
    end)

    local TabsBar = Create("Frame", {
        Name = "TabsBar",
        Parent = Header,
        Position = UDim2New(0, 60, 0, 0),
        Size = UDim2New(1, -120, 1, 0),
        BackgroundColor3 = Library.Theme.Inline
    })
    GradientStroke(TabsBar, 1)

    Create("UIListLayout", {
        Parent = TabsBar,
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDimNew(0, 4),
        VerticalAlignment = Enum.VerticalAlignment.Center
    })

    Create("UIPadding", {
        Parent = TabsBar,
        PaddingLeft = UDimNew(0, 6)
    })

    local Body = Create("Frame", {
        Name = "Body",
        Parent = MainFrame,
        Position = UDim2New(0, 12, 0, 68),
        Size = UDim2New(1, -24, 1, -80),
        BackgroundTransparency = 1
    })

    local FirstPage = true
    function WindowClass:Page(PageData)
        PageData = PageData or {}
        local PageName = PageData.Name or "Page"
        local PageClass = {}

        local TabButton = Create("TextButton", {
            Parent = TabsBar,
            Size = UDim2New(0, 80, 0, 36),
            BackgroundColor3 = Library.Theme.Element,
            Text = PageName,
            TextColor3 = FirstPage and Library.Theme.TextActive or Library.Theme.Text
        })
        GradientStroke(TabButton, 1)

        local PageContainer = Create("Frame", {
            Name = PageName .. "_Page",
            Parent = Body,
            Size = UDim2New(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Visible = FirstPage
        })

        local LeftCol = Create("Frame", {
            Name = "LeftColumn",
            Parent = PageContainer,
            Position = UDim2New(0, 0, 0, 0),
            Size = UDim2New(0.49, 0, 1, 0),
            BackgroundTransparency = 1
        })
        Create("UIListLayout", { Parent = LeftCol, Padding = UDimNew(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })

        local RightCol = Create("Frame", {
            Name = "RightColumn",
            Parent = PageContainer,
            Position = UDim2New(0.51, 0, 0, 0),
            Size = UDim2New(0.49, 0, 1, 0),
            BackgroundTransparency = 1
        })
        Create("UIListLayout", { Parent = RightCol, Padding = UDimNew(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })

        if FirstPage then FirstPage = false end

        TabButton.MouseButton1Click:Connect(function()
            for _, p in pairs(WindowClass.Pages) do
                p.Container.Visible = false
                p.Button.TextColor3 = Library.Theme.Text
            end
            PageContainer.Visible = true
            TabButton.TextColor3 = Library.Theme.TextActive
        end)

        function PageClass:Section(SecData)
            SecData = SecData or {}
            local SecName = SecData.Name or "Section"
            local Column = (SecData.Side == 2 and RightCol) or LeftCol
            local SecClass = {}

            local SecFrame = Create("Frame", {
                Name = SecName .. "_Section",
                Parent = Column,
                Size = UDim2New(1, 0, 0, 240),
                BackgroundColor3 = Library.Theme.Inline
            })
            GradientStroke(SecFrame, 1)

            Create("TextLabel", {
                Parent = SecFrame,
                Position = UDim2New(0, 10, 0, 6),
                Size = UDim2New(1, -20, 0, 16),
                Text = SecName,
                TextColor3 = Library.Theme.TextActive,
                TextXAlignment = Enum.TextXAlignment.Left
            })

            local Container = Create("Frame", {
                Parent = SecFrame,
                Position = UDim2New(0, 10, 0, 28),
                Size = UDim2New(1, -20, 1, -34),
                BackgroundTransparency = 1
            })
            Create("UIListLayout", { Parent = Container, Padding = UDimNew(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })

            -- Add Toggle
            function SecClass:Toggle(TogData)
                TogData = TogData or {}
                local Row = Create("Frame", { Parent = Container, Size = UDim2New(1, 0, 0, 20), BackgroundTransparency = 1 })
                local Box = Create("Frame", { Parent = Row, Size = UDim2New(0, 14, 0, 14), Position = UDim2New(0, 0, 0, 3), BackgroundColor3 = Library.Theme.Element })
                GradientStroke(Box, 1)
                
                Create("TextLabel", { Parent = Row, Position = UDim2New(0, 22, 0, 0), Size = UDim2New(1, -22, 1, 0), Text = TogData.Name or "Toggle", TextXAlignment = Enum.TextXAlignment.Left })
                local Btn = Create("TextButton", { Parent = Row, Size = UDim2New(1, 0, 1, 0), BackgroundTransparency = 1, Text = "" })

                local State = TogData.Default or false
                Box.BackgroundColor3 = State and Library.Theme.Accent or Library.Theme.Element

                Btn.MouseButton1Click:Connect(function()
                    State = not State
                    Box.BackgroundColor3 = State and Library.Theme.Accent or Library.Theme.Element
                    if TogData.Callback then TogData.Callback(State) end
                end)
            end

            -- Add Button
            function SecClass:Button(BtnData)
                BtnData = BtnData or {}
                local BtnFrame = Create("Frame", { Parent = Container, Size = UDim2New(1, 0, 0, 24), BackgroundColor3 = Library.Theme.Element })
                GradientStroke(BtnFrame, 1)

                local Btn = Create("TextButton", { Parent = BtnFrame, Size = UDim2New(1, 0, 1, 0), Text = BtnData.Name or "Button", TextColor3 = Library.Theme.TextActive })

                Btn.MouseButton1Click:Connect(function()
                    if BtnData.Callback then BtnData.Callback() end
                end)
            end

            -- Add Label
            function SecClass:Label(Text)
                Create("TextLabel", { Parent = Container, Size = UDim2New(1, 0, 0, 18), Text = tostring(Text), TextXAlignment = Enum.TextXAlignment.Left })
            end

            return SecClass
        end

        PageClass.Container = PageContainer
        PageClass.Button = TabButton
        table.insert(WindowClass.Pages, PageClass)

        return PageClass
    end

    function WindowClass:SetOpen(Bool) MainFrame.Visible = Bool end
    return WindowClass
end

Env.Library = Library
return Library