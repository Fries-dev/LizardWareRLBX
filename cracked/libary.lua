--[[
    Slot UI Library (Complete Version)
    API style based on samet.exe's library, visuals rebuilt from Slot_Logo.rbxmx
    (686x678 window, gradient strokes, header with logo / tabs / X, two-column sections)

    Assign a different Flag to every element so configs don't override each other.
    Callbacks fire on change. Read the starting value from Library.Flags[Flag].
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
local TextService = GetService("TextService")

local Vector2New = Vector2.new
local UDim2New = UDim2.new
local UDimNew = UDim.new
local FromRGB = Color3.fromRGB

local DefaultGradient = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.new(0.09, 0.27, 0.38)),
    ColorSequenceKeypoint.new(0.15, Color3.new(0.81, 0.84, 0.87)),
    ColorSequenceKeypoint.new(0.43, Color3.new(0.10, 0.33, 0.47)),
    ColorSequenceKeypoint.new(0.56, Color3.new(0.09, 0.41, 0.64)),
    ColorSequenceKeypoint.new(0.80, Color3.new(0.09, 0.27, 0.31)),
    ColorSequenceKeypoint.new(1, Color3.new(0.45, 0.76, 0.16)),
})

local Themes = {
    Slot = {
        Background = FromRGB(40, 40, 40),
        Inline = FromRGB(28, 28, 28),
        Element = FromRGB(56, 56, 56),
        Border = FromRGB(75, 75, 75),
        Outline = FromRGB(18, 18, 18),
        Text = FromRGB(171, 171, 171),
        TextActive = FromRGB(255, 255, 255),
        Risky = FromRGB(205, 70, 70),
        Close = FromRGB(166, 53, 53),
        Accent = FromRGB(24, 105, 164),
    },
    Emerald = {
        Background = FromRGB(30, 40, 35),
        Inline = FromRGB(20, 28, 24),
        Element = FromRGB(42, 56, 48),
        Border = FromRGB(60, 80, 70),
        Outline = FromRGB(12, 18, 15),
        Text = FromRGB(160, 180, 170),
        TextActive = FromRGB(255, 255, 255),
        Risky = FromRGB(205, 70, 70),
        Close = FromRGB(166, 53, 53),
        Accent = FromRGB(46, 164, 94),
    },
    Crimson = {
        Background = FromRGB(40, 30, 30),
        Inline = FromRGB(28, 20, 20),
        Element = FromRGB(56, 42, 42),
        Border = FromRGB(80, 60, 60),
        Outline = FromRGB(18, 12, 12),
        Text = FromRGB(180, 160, 160),
        TextActive = FromRGB(255, 255, 255),
        Risky = FromRGB(205, 70, 70),
        Close = FromRGB(166, 53, 53),
        Accent = FromRGB(164, 34, 34),
    },
    Violet = {
        Background = FromRGB(35, 30, 40),
        Inline = FromRGB(24, 20, 28),
        Element = FromRGB(48, 42, 56),
        Border = FromRGB(70, 60, 80),
        Outline = FromRGB(15, 12, 18),
        Text = FromRGB(170, 160, 180),
        TextActive = FromRGB(255, 255, 255),
        Risky = FromRGB(205, 70, 70),
        Close = FromRGB(166, 53, 53),
        Accent = FromRGB(114, 24, 164),
    }
}

local Library = {
    Version = "1.0.0",
    Flags = {},
    Themes = Themes,
    ThemeName = "Slot",
    Theme = table.clone(Themes.Slot),
    Gradient = DefaultGradient,
    Connections = {},
    ThemeMap = setmetatable({}, { __mode = "k" }),
    GradientItems = setmetatable({}, { __mode = "k" }),
}

Library.Font = Font.new("rbxasset://fonts/families/Inter.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)

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
    local Gradient = Create("UIGradient", {
        Parent = Stroke,
        Rotation = 37.84,
        Color = Library.Gradient
    })
    Library.GradientItems[Gradient] = true
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

function Library:SetTheme(Name)
    if Themes[Name] then
        self.ThemeName = Name
        for K, V in pairs(Themes[Name]) do
            self.Theme[K] = V
        end
    end
end

function Library:ChangeTheme(Key, Color3Value)
    if self.Theme[Key] then
        self.Theme[Key] = Color3Value
    end
end

function Library:SetGradient(ColorSeq)
    self.Gradient = ColorSeq
    for Grad, _ in pairs(self.GradientItems) do
        if Grad and Grad.Parent then
            Grad.Color = ColorSeq
        end
    end
end

function Library:Watermark(Text)
    local Label = Create("TextLabel", {
        Parent = self.Holder,
        Position = UDim2New(0, 12, 0, 12),
        Size = UDim2New(0, 200, 0, 24),
        Text = Text or "Slot UI Watermark",
        TextColor3 = Library.Theme.TextActive,
        TextXAlignment = Enum.TextXAlignment.Left
    })
    return {
        SetText = function(_, NewText) Label.Text = NewText end,
        SetVisibility = function(_, Bool) Label.Visible = Bool end
    }
end

function Library:KeybindList()
    local Frame = Create("Frame", {
        Parent = self.Holder,
        Position = UDim2New(1, -212, 0, 12),
        Size = UDim2New(0, 200, 0, 150),
        BackgroundColor3 = Library.Theme.Inline,
        Visible = false
    })
    GradientStroke(Frame, 1)
    return {
        SetVisibility = function(_, Bool) Frame.Visible = Bool end
    }
end

function Library:Notification(Text, Duration, Color, Icon)
    print("[Slot UI Notification]: " .. tostring(Text))
end

function Library:SaveConfig(Name)
    local Data = {}
    for Flag, Val in pairs(self.Flags) do
        Data[Flag] = Val
    end
    if writefile then
        pcall(function()
            writefile("SlotUI_" .. tostring(Name) .. ".json", HttpService:JSONEncode(Data))
        end)
    end
end

function Library:LoadConfigFile(Name)
    if readfile and isfile and isfile("SlotUI_" .. tostring(Name) .. ".json") then
        local Success, Res = pcall(function()
            return HttpService:JSONDecode(readfile("SlotUI_" .. tostring(Name) .. ".json"))
        end)
        if Success and type(Res) == "table" then
            for K, V in pairs(Res) do
                self.Flags[K] = V
            end
        end
    end
end

function Library:DeleteConfig(Name)
    if delfile and isfile and isfile("SlotUI_" .. tostring(Name) .. ".json") then
        pcall(function() delfile("SlotUI_" .. tostring(Name) .. ".json") end)
    end
end

function Library:ListConfigs()
    local List = {}
    if listfiles then
        local Success, Res = pcall(function() return listfiles("") end)
        if Success then
            for _, File in pairs(Res) do
                if string.match(File, "SlotUI_.*%.json") then
                    table.insert(List, string.gsub(string.match(File, "SlotUI_(.*)%.json"), ".json", ""))
                end
            end
        end
    end
    return List
end

function Library:GetConfig()
    return HttpService:JSONEncode(self.Flags)
end

function Library:LoadConfig(JsonString)
    local Success, Res = pcall(function() return HttpService:JSONDecode(JsonString) end)
    if Success and type(Res) == "table" then
        for K, V in pairs(Res) do self.Flags[K] = V end
    end
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
                Size = UDim2New(1, 0, 0, 260),
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

            function SecClass:Label(TextOrData)
                local Text = type(TextOrData) == "table" and TextOrData.Name or tostring(TextOrData or "Label")
                local Lbl = Create("TextLabel", { Parent = Container, Size = UDim2New(1, 0, 0, 18), Text = Text, TextXAlignment = Enum.TextXAlignment.Left })
                local LblObj = {}
                function LblObj:Keybind(...) return LblObj end
                function LblObj:Colorpicker(...) return LblObj end
                return LblObj
            end

            function SecClass:Divider()
                Create("Frame", { Parent = Container, Size = UDim2New(1, 0, 0, 2), BackgroundColor3 = Library.Theme.Border })
            end

            function SecClass:Toggle(TogData)
                TogData = TogData or {}
                local Flag = TogData.Flag
                local State = TogData.Default or false
                if Flag then Library.Flags[Flag] = State end

                local Row = Create("Frame", { Parent = Container, Size = UDim2New(1, 0, 0, 20), BackgroundTransparency = 1 })
                local Box = Create("Frame", { Parent = Row, Size = UDim2New(0, 14, 0, 14), Position = UDim2New(0, 0, 0, 3), BackgroundColor3 = State and Library.Theme.Accent or Library.Theme.Element })
                GradientStroke(Box, 1)
                
                Create("TextLabel", { Parent = Row, Position = UDim2New(0, 22, 0, 0), Size = UDim2New(1, -22, 1, 0), Text = TogData.Name or "Toggle", TextXAlignment = Enum.TextXAlignment.Left })
                local Btn = Create("TextButton", { Parent = Row, Size = UDim2New(1, 0, 1, 0), BackgroundTransparency = 1, Text = "" })

                Btn.MouseButton1Click:Connect(function()
                    State = not State
                    Box.BackgroundColor3 = State and Library.Theme.Accent or Library.Theme.Element
                    if Flag then Library.Flags[Flag] = State end
                    if TogData.Callback then TogData.Callback(State) end
                end)

                local TogObj = {}
                function TogObj:Keybind(...) return TogObj end
                function TogObj:Colorpicker(...) return TogObj end
                return TogObj
            end

            function SecClass:Button(BtnData)
                BtnData = BtnData or {}
                local BtnFrame = Create("Frame", { Parent = Container, Size = UDim2New(1, 0, 0, 24), BackgroundColor3 = Library.Theme.Element })
                GradientStroke(BtnFrame, 1)

                local Btn = Create("TextButton", { Parent = BtnFrame, Size = UDim2New(1, 0, 1, 0), Text = BtnData.Name or "Button", TextColor3 = Library.Theme.TextActive })

                Btn.MouseButton1Click:Connect(function()
                    if BtnData.Callback then BtnData.Callback() end
                end)

                local BtnObj = {}
                function BtnObj:SubButton(...) return BtnObj end
                return BtnObj
            end

            function SecClass:Slider(SliderData)
                SliderData = SliderData or {}
                local Min = SliderData.Min or 0
                local Max = SliderData.Max or 100
                local Val = SliderData.Default or Min
                local Flag = SliderData.Flag
                if Flag then Library.Flags[Flag] = Val end

                local Frame = Create("Frame", { Parent = Container, Size = UDim2New(1, 0, 0, 36), BackgroundTransparency = 1 })
                Create("TextLabel", { Parent = Frame, Size = UDim2New(1, 0, 0, 16), Text = (SliderData.Name or "Slider") .. ": " .. tostring(Val), TextXAlignment = Enum.TextXAlignment.Left })

                local Track = Create("Frame", { Parent = Frame, Position = UDim2New(0, 0, 0, 20), Size = UDim2New(1, 0, 0, 10), BackgroundColor3 = Library.Theme.Element })
                GradientStroke(Track, 1)
                local Fill = Create("Frame", { Parent = Track, Size = UDim2New((Val - Min)/(Max - Min), 0, 1, 0), BackgroundColor3 = Library.Theme.Accent })

                local Dragging = false
                Track.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 then Dragging = true end
                end)
                UserInputService.InputEnded:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 then Dragging = false end
                end)
                UserInputService.InputChanged:Connect(function(Input)
                    if Dragging and Input.UserInputType == Enum.UserInputType.MouseMovement then
                        local Pos = math.clamp((Input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
                        Val = math.floor(Min + ((Max - Min) * Pos))
                        Fill.Size = UDim2New(Pos, 0, 1, 0)
                        if Flag then Library.Flags[Flag] = Val end
                        if SliderData.Callback then SliderData.Callback(Val) end
                    end
                end)
            end

            function SecClass:Textbox(BoxData)
                BoxData = BoxData or {}
                local Flag = BoxData.Flag
                local Frame = Create("Frame", { Parent = Container, Size = UDim2New(1, 0, 0, 24), BackgroundColor3 = Library.Theme.Element })
                GradientStroke(Frame, 1)
                local Box = Create("TextBox", { Parent = Frame, Size = UDim2New(1, -10, 1, 0), Position = UDim2New(0, 5, 0, 0), Text = BoxData.Default or "", PlaceholderText = BoxData.Placeholder or "Input...", TextXAlignment = Enum.TextXAlignment.Left })
                Box.FocusLost:Connect(function(Enter)
                    if Flag then Library.Flags[Flag] = Box.Text end
                    if BoxData.Callback then BoxData.Callback(Box.Text, Enter) end
                end)
            end

            function SecClass:Dropdown(DropData)
                DropData = DropData or {}
                local Frame = Create("Frame", { Parent = Container, Size = UDim2New(1, 0, 0, 24), BackgroundColor3 = Library.Theme.Element })
                GradientStroke(Frame, 1)
                Create("TextLabel", { Parent = Frame, Position = UDim2New(0, 6, 0, 0), Size = UDim2New(1, -12, 1, 0), Text = (DropData.Name or "Dropdown") .. " v", TextXAlignment = Enum.TextXAlignment.Left })
            end

            function SecClass:Listbox(ListData)
                local Frame = Create("Frame", { Parent = Container, Size = ListData.Size or UDim2New(1, 0, 0, 80), BackgroundColor3 = Library.Theme.Element })
                GradientStroke(Frame, 1)
            end

            return SecClass
        end

        PageClass.Container = PageContainer
        PageClass.Button = TabButton
        table.insert(WindowClass.Pages, PageClass)

        return PageClass
    end

    function WindowClass:SettingsPage(SetData)
        return self:Page({ Name = SetData and SetData.Name or "Settings" })
    end

    function WindowClass:SetOpen(Bool) MainFrame.Visible = Bool end
    function WindowClass:Toggle() MainFrame.Visible = not MainFrame.Visible end

    return WindowClass
end

Env.Library = Library
return Library