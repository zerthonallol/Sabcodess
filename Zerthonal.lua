-- ============================================================
-- Zerthonal Hub - Code Catch
-- После ввода кода в TextBox жмёт ImageButton "Confirmation".
-- Без Enter, без CaptureFocus/ReleaseFocus, без VIM/SendKeyEvent.
-- ============================================================

local Players           = game:GetService("Players")
local UserInputService   = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local LP                 = Players.LocalPlayer
local PlayerGui          = LP:WaitForChild("PlayerGui")

local REQUIRED_KEY = "ZERTHONALEZZSAB"
local GUI_NAME     = "ZerthonalHubCodeCatchGui"
local HUB_NAME     = "Zerthonal Hub - Code Catch"
local CONFIRM_NAME = "Confirmation"

-- ============================================================
-- ВСПОМОГАТЕЛЬНЫЕ
-- ============================================================
local function isOurGui(instance)
    local p = instance
    for _ = 1, 10 do
        if not p then break end
        if p.Name == GUI_NAME or p.Name == (GUI_NAME .. "_Main") then return true end
        p = p.Parent
    end
    return false
end

local function isVisibleChain(inst)
    local cur = inst
    while cur do
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("ScreenGui") then return cur.Enabled end
        cur = cur.Parent
    end
    return true
end

local function writeCodeToBox(box, code)
    if not box then return false end
    local ok = pcall(function() box.Text = code end)
    return ok and box.Text == code
end

local function clickButton(btn)
    if not btn then return false end
    return (pcall(function() btn.MouseButton1Click:Fire() end))
end

-- ============================================================
-- ПОИСК ПАНЕЛИ КОДОВ
-- ============================================================
local function findCodePanel()
    local codesGui = PlayerGui:FindFirstChild("Codes")
    if codesGui then
        if codesGui:IsA("ScreenGui") then codesGui.Enabled = true end
        local codesFrame = codesGui:FindFirstChild("Codes") or codesGui
        if codesFrame and codesFrame:IsA("GuiObject") then
            codesFrame.Visible = true
            local cur = codesFrame
            while cur and cur ~= codesGui do
                if cur:IsA("GuiObject") then cur.Visible = true end
                cur = cur.Parent
            end
        end
        return codesFrame
    end

    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled and not isOurGui(gui) then
            for _, d in ipairs(gui:GetDescendants()) do
                if d:IsA("TextBox") and not isOurGui(d) and isVisibleChain(d) then
                    local n  = d.Name:lower()
                    local pn = (d.Parent and d.Parent.Name or ""):lower()
                    if n:find("code") or pn:find("code")
                        or n:find("redeem") or pn:find("redeem")
                        or n:find("input") or pn:find("input")
                        or n:find("enter") then
                        return d.Parent
                    end
                end
            end
        end
    end
    return nil
end

-- ============================================================
-- ПОИСК ImageButton "Confirmation" В ПАНЕЛИ КОДОВ
-- ============================================================
local function findConfirmationButton(root)
    if not root then return nil end

    -- 1) Точное совпадение имени
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("ImageButton") and not isOurGui(d) and d.Name == CONFIRM_NAME then
            return d
        end
    end

    -- 2) Без учёта регистра, если точное не нашли
    local lowerName = CONFIRM_NAME:lower()
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("ImageButton") and not isOurGui(d) and d.Name:lower() == lowerName then
            return d
        end
    end

    return nil
end

-- ============================================================
-- ВВОД КОДА + КЛИК ПО Confirmation
-- ============================================================
local redeemBusy = false

local function typeAndSubmitCode(code)
    if redeemBusy then return false, "busy" end
    redeemBusy = true

    local ok, result = pcall(function()
        local root = findCodePanel()
        if not root then return false, "no code panel" end

        -- Поле ввода
        local box
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("TextBox") and not isOurGui(d) then box = d; break end
        end
        if not box then return false, "no codebox" end

        -- Кнопка Confirmation
        local confirmBtn = findConfirmationButton(root)
        if not confirmBtn then
            task.wait(0.3)
            confirmBtn = findConfirmationButton(findCodePanel())
        end
        if not confirmBtn then return false, "Confirmation ImageButton not found" end

        -- Ввод кода
        writeCodeToBox(box, code)
        task.wait(0.1)

        -- Клик по Confirmation (ровно один раз)
        clickButton(confirmBtn)
        task.wait(0.2)

        -- Страховка: если поле не очистилось — один повторный клик
        local stillHasCode = false
        pcall(function() stillHasCode = (box.Text ~= "" and box.Text == code) end)
        if stillHasCode then
            clickButton(confirmBtn)
            task.wait(0.1)
        end

        return true, "wrote code + clicked Confirmation (" .. confirmBtn:GetFullName() .. ")"
    end)

    redeemBusy = false
    if not ok then return false, tostring(result) end
    return result
end

-- ============================================================
-- AI RIDDLES: локальный решатель
-- ============================================================
local function solveRiddle(question)
    if not question or question == "" then return nil end
    local q = question:lower():gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")

    if q:find("what year") or q:find("current year") or q:find("какой год") then
        return tostring(os.date("%Y"))
    end
    if q:find("what time") or q:find("current time") then
        return os.date("%H:%M")
    end
    if q:find("what month") or q:find("current month") then
        local months = {"january","february","march","april","may","june",
                        "july","august","september","october","november","december"}
        return months[tonumber(os.date("%m"))]
    end
    if q:find("what day") and not q:find("today") then
        return os.date("%A"):lower()
    end

    local a, op, b = q:match("what is (%d+)%s*([%+%-%*/])%s*(%d+)")
    if a and op and b then
        a, b = tonumber(a), tonumber(b)
        if op == "+" then return tostring(a + b) end
        if op == "-" then return tostring(a - b) end
        if op == "*" then return tostring(a * b) end
        if op == "/" and b ~= 0 then return tostring(a / b) end
    end
    return nil
end

-- ============================================================
-- NOTIFY REMOTE
-- ============================================================
local function findNotifyRemote()
    local Packages = ReplicatedStorage:FindFirstChild("Packages")
    if not Packages then return nil end
    local Net = Packages:FindFirstChild("Net")
    if not Net then return nil end
    for _, d in ipairs(Net:GetDescendants()) do
        if d:IsA("RemoteEvent") and (d.Name:lower():find("notif") or d.Name:lower():find("announce")) then
            return d
        end
    end
    return nil
end
local notifyRemote = findNotifyRemote()

-- ============================================================
-- ЭКРАН КЛЮЧА
-- ============================================================
if PlayerGui:FindFirstChild(GUI_NAME) then PlayerGui[GUI_NAME]:Destroy() end
if PlayerGui:FindFirstChild(GUI_NAME .. "_Main") then PlayerGui[GUI_NAME .. "_Main"]:Destroy() end

local keyGui = Instance.new("ScreenGui")
keyGui.Name = GUI_NAME
keyGui.ResetOnSpawn = false
keyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
keyGui.DisplayOrder = 999
keyGui.Parent = PlayerGui

local keyFrame = Instance.new("Frame")
keyFrame.Size = UDim2.new(0, 280, 0, 150)
keyFrame.Position = UDim2.new(0.5, -140, 0.5, -75)
keyFrame.BackgroundColor3 = Color3.fromRGB(245, 245, 248)
keyFrame.BackgroundTransparency = 0.1
keyFrame.BorderSizePixel = 0
keyFrame.Parent = keyGui
Instance.new("UICorner", keyFrame).CornerRadius = UDim.new(0, 16)
local kStroke = Instance.new("UIStroke", keyFrame)
kStroke.Color = Color3.fromRGB(255, 255, 255); kStroke.Thickness = 1.5

local keyTitle = Instance.new("TextLabel")
keyTitle.Size = UDim2.new(1, -24, 0, 24)
keyTitle.Position = UDim2.new(0, 12, 0, 12)
keyTitle.BackgroundTransparency = 1
keyTitle.Font = Enum.Font.GothamBold
keyTitle.Text = HUB_NAME
keyTitle.TextColor3 = Color3.fromRGB(80, 10, 15)
keyTitle.TextSize = 13
keyTitle.TextXAlignment = Enum.TextXAlignment.Left
keyTitle.Parent = keyFrame

local keyHint = Instance.new("TextLabel")
keyHint.Size = UDim2.new(1, -24, 0, 14)
keyHint.Position = UDim2.new(0, 12, 0, 36)
keyHint.BackgroundTransparency = 1
keyHint.Font = Enum.Font.Gotham
keyHint.Text = "Enter key to continue"
keyHint.TextColor3 = Color3.fromRGB(120, 30, 35)
keyHint.TextSize = 10
keyHint.TextXAlignment = Enum.TextXAlignment.Left
keyHint.Parent = keyFrame

local keyBox = Instance.new("TextBox")
keyBox.Size = UDim2.new(1, -24, 0, 32)
keyBox.Position = UDim2.new(0, 12, 0, 58)
keyBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
keyBox.BackgroundTransparency = 0.35
keyBox.BorderSizePixel = 0
keyBox.PlaceholderText = "KEY..."
keyBox.PlaceholderColor3 = Color3.fromRGB(130, 135, 145)
keyBox.Text = ""
keyBox.TextColor3 = Color3.fromRGB(40, 45, 55)
keyBox.ClearTextOnFocus = false
keyBox.Font = Enum.Font.GothamBold
keyBox.TextSize = 12
keyBox.TextXAlignment = Enum.TextXAlignment.Center
keyBox.Parent = keyFrame
Instance.new("UICorner", keyBox).CornerRadius = UDim.new(0, 10)
local kbStroke = Instance.new("UIStroke", keyBox)
kbStroke.Color = Color3.fromRGB(255, 255, 255); kbStroke.Thickness = 1

local keyStatus = Instance.new("TextLabel")
keyStatus.Size = UDim2.new(1, -24, 0, 14)
keyStatus.Position = UDim2.new(0, 12, 0, 94)
keyStatus.BackgroundTransparency = 1
keyStatus.Font = Enum.Font.GothamBold
keyStatus.Text = ""
keyStatus.TextColor3 = Color3.fromRGB(200, 40, 50)
keyStatus.TextSize = 10
keyStatus.TextXAlignment = Enum.TextXAlignment.Center
keyStatus.Parent = keyFrame

local keyBtn = Instance.new("TextButton")
keyBtn.Size = UDim2.new(1, -24, 0, 30)
keyBtn.Position = UDim2.new(0, 12, 0, 110)
keyBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
keyBtn.BorderSizePixel = 0
keyBtn.Font = Enum.Font.GothamBold
keyBtn.Text = "UNLOCK"
keyBtn.TextColor3 = Color3.fromRGB(90, 12, 18)
keyBtn.TextSize = 11
keyBtn.Parent = keyFrame
Instance.new("UICorner", keyBtn).CornerRadius = UDim.new(0, 10)
local keyBtnStroke = Instance.new("UIStroke", keyBtn)
keyBtnStroke.Color = Color3.fromRGB(255, 255, 255); keyBtnStroke.Thickness = 1

-- ============================================================
-- ОСНОВНОЙ UI
-- ============================================================
local function buildMainUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = GUI_NAME .. "_Main"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = PlayerGui

    local mainFrame = Instance.new("ImageLabel")
    mainFrame.Size = UDim2.new(0, 300, 0, 205)
    mainFrame.Position = UDim2.new(0.5, -150, 0.5, -102)
    mainFrame.BackgroundColor3 = Color3.fromRGB(245, 245, 248)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.Image = "rbxassetid://93857225029776"
    mainFrame.ImageTransparency = 0.85
    mainFrame.ScaleType = Enum.ScaleType.Crop
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = screenGui
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 16)
    local mainStroke = Instance.new("UIStroke", mainFrame)
    mainStroke.Color = Color3.fromRGB(255, 255, 255); mainStroke.Thickness = 1.5

    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 44)
    topBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    topBar.BackgroundTransparency = 0.4
    topBar.BorderSizePixel = 0
    topBar.Parent = mainFrame
    Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 16)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0, 220, 0, 14)
    titleLabel.Position = UDim2.new(0, 12, 0, 8)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = HUB_NAME
    titleLabel.TextColor3 = Color3.fromRGB(80, 10, 15)
    titleLabel.TextSize = 12
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = topBar

    local subLabel = Instance.new("TextLabel")
    subLabel.Size = UDim2.new(0, 220, 0, 12)
    subLabel.Position = UDim2.new(0, 12, 0, 25)
    subLabel.BackgroundTransparency = 1
    subLabel.Font = Enum.Font.Gotham
    subLabel.Text = "click 'Confirmation' after write"
    subLabel.TextColor3 = Color3.fromRGB(120, 30, 35)
    subLabel.TextSize = 10
    subLabel.TextXAlignment = Enum.TextXAlignment.Left
    subLabel.Parent = topBar

    local statusDot = Instance.new("TextButton")
    statusDot.Size = UDim2.new(0, 10, 0, 10)
    statusDot.Position = UDim2.new(1, -18, 0, 17)
    statusDot.BackgroundColor3 = Color3.fromRGB(220, 40, 50)
    statusDot.BorderSizePixel = 0
    statusDot.Text = ""
    statusDot.AutoButtonColor = false
    statusDot.Parent = topBar
    Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)

    local function makeButton(text, y, height)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -24, 0, height)
        b.Position = UDim2.new(0, 12, 0, y)
        b.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        b.BackgroundTransparency = 0.35
        b.BorderSizePixel = 0
        b.Font = Enum.Font.GothamBold
        b.Text = text
        b.TextColor3 = Color3.fromRGB(90, 12, 18)
        b.TextSize = 11
        b.AutoButtonColor = false
        b.Parent = mainFrame
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
        local s = Instance.new("UIStroke", b)
        s.Color = Color3.fromRGB(255, 255, 255); s.Thickness = 1
        return b
    end

    local scanButton = makeButton("START SCAN", 52, 30)
    local modeButton = makeButton("MODE: 3 GLOBAL MESSAGES", 88, 30)
    modeButton.TextSize = 9
    modeButton.TextColor3 = Color3.fromRGB(80, 85, 95)

    local previewBox = Instance.new("TextBox")
    previewBox.Size = UDim2.new(1, -102, 0, 30)
    previewBox.Position = UDim2.new(0, 12, 0, 126)
    previewBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    previewBox.BackgroundTransparency = 0.35
    previewBox.BorderSizePixel = 0
    previewBox.PlaceholderText = "Captured code..."
    previewBox.Text = ""
    previewBox.TextColor3 = Color3.fromRGB(40, 45, 55)
    previewBox.ClearTextOnFocus = false
    previewBox.Font = Enum.Font.GothamBold
    previewBox.TextSize = 11
    previewBox.TextXAlignment = Enum.TextXAlignment.Left
    previewBox.Parent = mainFrame
    Instance.new("UICorner", previewBox).CornerRadius = UDim.new(0, 10)
    local pstroke = Instance.new("UIStroke", previewBox)
    pstroke.Color = Color3.fromRGB(255, 255, 255); pstroke.Thickness = 1
    local pad = Instance.new("UIPadding", previewBox)
    pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8)

    local redeemButton = Instance.new("TextButton")
    redeemButton.Size = UDim2.new(0, 70, 0, 30)
    redeemButton.Position = UDim2.new(1, -82, 0, 126)
    redeemButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    redeemButton.BorderSizePixel = 0
    redeemButton.Text = "REDEEM"
    redeemButton.TextColor3 = Color3.fromRGB(90, 12, 18)
    redeemButton.Font = Enum.Font.GothamBold
    redeemButton.TextSize = 10
    redeemButton.Parent = mainFrame
    Instance.new("UICorner", redeemButton).CornerRadius = UDim.new(0, 10)
    local rstroke = Instance.new("UIStroke", redeemButton)
    rstroke.Color = Color3.fromRGB(255, 255, 255); rstroke.Thickness = 1

    local bottomRow = Instance.new("Frame")
    bottomRow.Size = UDim2.new(1, -24, 0, 30)
    bottomRow.Position = UDim2.new(0, 12, 0, 162)
    bottomRow.BackgroundTransparency = 1
    bottomRow.Parent = mainFrame

    local delayLabel = Instance.new("TextLabel")
    delayLabel.Size = UDim2.new(0, 48, 1, 0)
    delayLabel.Position = UDim2.new(0, 10, 0, 0)
    delayLabel.BackgroundTransparency = 1
    delayLabel.Font = Enum.Font.GothamBold
    delayLabel.Text = "Delay:"
    delayLabel.TextColor3 = Color3.fromRGB(90, 95, 105)
    delayLabel.TextSize = 11
    delayLabel.TextXAlignment = Enum.TextXAlignment.Left
    delayLabel.Parent = bottomRow

    local delayBox = Instance.new("TextBox")
    delayBox.Size = UDim2.new(0, 48, 1, 0)
    delayBox.Position = UDim2.new(0, 62, 0, 0)
    delayBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    delayBox.BackgroundTransparency = 0.35
    delayBox.BorderSizePixel = 0
    delayBox.Text = "0.5"
    delayBox.TextColor3 = Color3.fromRGB(40, 45, 55)
    delayBox.Font = Enum.Font.GothamBold
    delayBox.TextSize = 12
    delayBox.TextXAlignment = Enum.TextXAlignment.Center
    delayBox.ClearTextOnFocus = false
    delayBox.Parent = bottomRow
    Instance.new("UICorner", delayBox).CornerRadius = UDim.new(0, 10)
    local dstroke = Instance.new("UIStroke", delayBox)
    dstroke.Color = Color3.fromRGB(255, 255, 255); dstroke.Thickness = 1

    local setButton = Instance.new("TextButton")
    setButton.Size = UDim2.new(0, 70, 1, 0)
    setButton.Position = UDim2.new(1, -70, 0, 0)
    setButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    setButton.BorderSizePixel = 0
    setButton.Text = "SET"
    setButton.TextColor3 = Color3.fromRGB(90, 12, 18)
    setButton.Font = Enum.Font.GothamBold
    setButton.TextSize = 10
    setButton.Parent = bottomRow
    Instance.new("UICorner", setButton).CornerRadius = UDim.new(0, 10)
    local sstroke = Instance.new("UIStroke", setButton)
    sstroke.Color = Color3.fromRGB(255, 255, 255); sstroke.Thickness = 1

    local function hover(btn)
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundTransparency = 0.1}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundTransparency = 0.35}):Play()
        end)
    end
    hover(scanButton); hover(modeButton); hover(setButton); hover(redeemButton)

    statusDot.MouseButton1Click:Connect(function()
        keyGui:Destroy()
        screenGui:Destroy()
    end)

    local dragging, dragInput, dragStart, startPos
    local function update(input)
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
    mainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    mainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then update(input) end
    end)

    local scanning, buffer, mode, delay = false, {}, 3, 0.5

    local function updateDelay()
        local val = tonumber(delayBox.Text)
        if val and val >= 0.05 then
            delay = val
            print("[" .. HUB_NAME .. "] Delay set to:", delay)
        else
            delayBox.Text = tostring(delay)
        end
    end
    delayBox.FocusLost:Connect(function(enter) if enter then updateDelay() end end)
    delayBox:GetPropertyChangedSignal("Text"):Connect(function()
        local val = tonumber(delayBox.Text)
        if val and val >= 0.05 then delay = val end
    end)
    setButton.MouseButton1Click:Connect(updateDelay)

    local function isValidCode(msg) return msg:match("^[A-Za-z0-9]+$") ~= nil end

    local function updatePreview()
        if #buffer == 0 then previewBox.Text = ""; return end
        local count = math.min(#buffer, mode)
        previewBox.Text = table.concat(buffer, "", 1, count)
    end

    local function processBuffer()
        if not scanning then return end
        while #buffer >= mode do
            if redeemBusy then task.wait(0.05); continue end
            local combined = table.concat(buffer, "", 1, mode)
            buffer = {}
            updatePreview()
            local ok, info = typeAndSubmitCode(combined)
            print("[" .. HUB_NAME .. "] Auto '" .. combined .. "' -> " .. tostring(info))
            task.wait(delay)
        end
        updatePreview()
    end

    local function onAnnouncement(txt)
        if not scanning or not txt or txt == "" then return end
        local msg = txt:match("^%s*(.-)%s*$")

        local answer = solveRiddle(msg)
        if answer then
            print("[" .. HUB_NAME .. "] Riddle solved: '" .. msg .. "' -> '" .. answer .. "'")
            typeAndSubmitCode(answer)
            return
        end

        if isValidCode(msg) then
            table.insert(buffer, msg)
            updatePreview()
            if #buffer >= mode then task.spawn(processBuffer) end
            print("[" .. HUB_NAME .. "] Captured code: " .. msg .. " (buffer: " .. #buffer .. ")")
        else
            print("[" .. HUB_NAME .. "] Skipped (unknown riddle/non-code): " .. msg)
        end
    end

    local function toggleScan()
        scanning = not scanning
        if scanning then
            scanButton.Text = "SCANNING..."
            scanButton.BackgroundColor3 = Color3.fromRGB(120, 220, 140)
            scanButton.BackgroundTransparency = 0.2
            statusDot.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
            buffer = {}; updatePreview()
            print("[" .. HUB_NAME .. "] Scanning started.")
        else
            scanButton.Text = "START SCAN"
            scanButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            scanButton.BackgroundTransparency = 0.35
            statusDot.BackgroundColor3 = Color3.fromRGB(220, 40, 50)
            buffer = {}; updatePreview()
            print("[" .. HUB_NAME .. "] Scanning stopped.")
        end
    end
    scanButton.MouseButton1Click:Connect(toggleScan)

    modeButton.MouseButton1Click:Connect(function()
        mode = (mode % 4) + 1
        modeButton.Text = "MODE: " .. mode .. " GLOBAL MESSAGE" .. (mode > 1 and "S" or "")
        updatePreview()
        if scanning and #buffer >= mode then task.spawn(processBuffer) end
    end)

    local function manualRedeem()
        local code = previewBox.Text
        if code and code ~= "" then
            local ok, info = typeAndSubmitCode(code)
            print("[" .. HUB_NAME .. "] Manual '" .. code .. "' -> " .. tostring(info))
            buffer = {}; updatePreview()
        end
    end
    redeemButton.MouseButton1Click:Connect(manualRedeem)
    previewBox.FocusLost:Connect(function(enter) if enter then manualRedeem() end end)

    if notifyRemote then
        notifyRemote.OnClientEvent:Connect(function(txt, ...)
            onAnnouncement(txt)
        end)
        print("[" .. HUB_NAME .. "] Subscribed to:", notifyRemote:GetFullName())
    else
        warn("[" .. HUB_NAME .. "] Notify remote not found. Capture disabled.")
    end

    print("[" .. HUB_NAME .. "] Ready. Click 'START SCAN' to begin.")
end

-- ============================================================
-- Логика ключа
-- ============================================================
local function tryUnlock()
    local entered = keyBox.Text:gsub("%s", "")
    if entered == REQUIRED_KEY then
        keyStatus.Text = "ACCESS GRANTED"
        keyStatus.TextColor3 = Color3.fromRGB(50, 180, 80)
        task.wait(0.35)
        keyGui:Destroy()
        buildMainUI()
    else
        keyStatus.Text = "INVALID KEY"
        keyStatus.TextColor3 = Color3.fromRGB(200, 40, 50)
        keyBox.Text = ""
    end
end

keyBtn.MouseButton1Click:Connect(tryUnlock)
keyBox.FocusLost:Connect(function(enter) if enter then tryUnlock() end end)

keyBox:CaptureFocus()
print("[" .. HUB_NAME .. "] Awaiting key...")
