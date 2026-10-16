local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local GET_KEY_LINK = "https://work.ink/YOUR_ID/YOUR_LINK" -- your Work.ink link
local KEY_LIFETIME = 12 * 60 * 60                         -- 12 hours
local KEY_FILE = "PepsisWorld_key.json"

local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request

-- Ask Work.ink whether the token is real.
-- Check the exact endpoint/response in your Work.ink dashboard docs; this is the usual shape.
local function validateToken(token)
    local ok, res = pcall(function()
        return httpRequest({
            Url = "https://work.ink/_api/v2/token/isValid/" .. HttpService:UrlEncode(token) .. "?deleteToken=1",
            Method = "GET",
        })
    end)
    if not ok or not res or res.StatusCode ~= 200 then return false end
    local ok2, data = pcall(HttpService.JSONDecode, HttpService, res.Body)
    return ok2 and data.valid == true
end

local function savedKeyStillValid()
    if not (isfile and isfile(KEY_FILE)) then return false end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(KEY_FILE))
    end)
    return ok and data.expires and os.time() < data.expires
end

local function saveKey()
    writefile(KEY_FILE, HttpService:JSONEncode({ expires = os.time() + KEY_LIFETIME }))
end

local function promptForKey()
    local passed = false
    local gui = Instance.new("ScreenGui")
    gui.Name = "PepsiKeyGate"
    gui.Parent = (gethui and gethui()) or CoreGui

    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.fromOffset(320, 170)
    frame.Position = UDim2.new(0.5, -160, 0.5, -85)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    Instance.new("UICorner", frame)

    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundTransparency = 1
    title.Text = "Key System"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16

    local box = Instance.new("TextBox", frame)
    box.Size = UDim2.new(1, -20, 0, 32)
    box.Position = UDim2.fromOffset(10, 40)
    box.PlaceholderText = "Paste your key here"
    box.Text = ""
    box.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    box.TextColor3 = Color3.new(1, 1, 1)
    box.ClearTextOnFocus = false
    Instance.new("UICorner", box)

    local status = Instance.new("TextLabel", frame)
    status.Size = UDim2.new(1, -20, 0, 20)
    status.Position = UDim2.fromOffset(10, 76)
    status.BackgroundTransparency = 1
    status.Text = ""
    status.TextColor3 = Color3.fromRGB(255, 120, 120)
    status.TextSize = 13

    local function makeButton(text, x, cb)
        local b = Instance.new("TextButton", frame)
        b.Size = UDim2.new(0.5, -15, 0, 32)
        b.Position = UDim2.new(x, x == 0 and 10 or 5, 0, 110)
        b.Text = text
        b.BackgroundColor3 = Color3.fromRGB(60, 90, 200)
        b.TextColor3 = Color3.new(1, 1, 1)
        Instance.new("UICorner", b)
        b.MouseButton1Click:Connect(cb)
    end

    makeButton("Get Key", 0, function()
        if setclipboard then setclipboard(GET_KEY_LINK) end
        status.TextColor3 = Color3.fromRGB(120, 255, 120)
        status.Text = "Link copied to clipboard!"
    end)

    makeButton("Check Key", 0.5, function()
        status.TextColor3 = Color3.fromRGB(255, 255, 120)
        status.Text = "Checking..."
        if validateToken(box.Text) then
            saveKey()
            passed = true
            gui:Destroy()
        else
            status.TextColor3 = Color3.fromRGB(255, 120, 120)
            status.Text = "Invalid or expired key."
        end
    end)

    repeat task.wait() until passed
end

if not savedKeyStillValid() then
    promptForKey()
end
