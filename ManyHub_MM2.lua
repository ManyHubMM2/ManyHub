-- ManyHub_White.lua · Lua · MM2 Client-Side
-- Светлый UI, перетаскиваемая кнопка, настройки, ввод FOV, фикс ESP.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ============================================================
-- ЛОКАЛИЗАЦИЯ
-- ============================================================
local LANG = "RU"
local Locale = {
    RU = { title = "ManyHub", esp = "Визуал", aim = "Аимбот", move = "Движение", tp = "Телепорт", fling = "Флинг", settings = "Настройки",
        espEnable = "Включить ESP", espRoles = "Показывать: Всех",
        aimEnable = "Аимбот: ВЫКЛ", aimPart = "Часть: Голова", aimFov = "FOV (введи):", aimSmooth = "Плавность:",
        fly = "Полет", noclip = "Noclip", speed = "Скорость", flingMode = "Флинг: ВЫКЛ",
        tpMurder = "ТП к Убийце", tpSheriff = "ТП к Шерифу",
        fullbright = "Fullbright", autoPickup = "Авто-подбор", antiAfk = "Anti-AFK", lang = "Язык (RU/EN)"
    },
    EN = { title = "ManyHub", esp = "Visuals", aim = "Aimbot", move = "Movement", tp = "Teleport", fling = "Fling", settings = "Settings",
        espEnable = "Enable ESP", espRoles = "Show: All",
        aimEnable = "Aimbot: OFF", aimPart = "Part: Head", aimFov = "FOV (input):", aimSmooth = "Smooth:",
        fly = "Fly", noclip = "Noclip", speed = "Speed", flingMode = "Fling: OFF",
        tpMurder = "TP to Murderer", tpSheriff = "TP to Sheriff",
        fullbright = "Fullbright", autoPickup = "Auto Pickup", antiAfk = "Anti-AFK", lang = "Language (RU/EN)"
    }
}
local function T(key) return Locale[LANG][key] or key end

-- ============================================================
-- КОНФИГ
-- ============================================================
local CFG = {
    espEnabled = true, espShowAll = true, aimbotEnabled = false, aimFOV = 150, aimSmooth = 0.3, aimPart = "Head",
    flyEnabled = false, noclipEnabled = false, speedEnabled = false, speedValue = 20, flingEnabled = false,
    fullbright = false, autoPickup = false, antiAfk = true
}

local RoleCache, ESPCache = {}, {}
local flyBV, flyBG
local currentTab = "ESP"
local isPickingUp = false
local flingTarget = "All"

-- ============================================================
-- ESP (ПОЧИНЕН)
-- ============================================================
local function updateRoles()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local char = plr.Character
        if not char then RoleCache[plr] = "Innocent"; continue end
        local bp = plr:FindFirstChild("Backpack")
        local hasKnife = (bp and bp:FindFirstChild("Knife")) or char:FindFirstChild("Knife")
        local hasGun = (bp and bp:FindFirstChild("Gun")) or char:FindFirstChild("Gun")
        if hasKnife then RoleCache[plr] = "Murderer"
        elseif hasGun then RoleCache[plr] = "Sheriff"
        else RoleCache[plr] = "Innocent" end
    end
end

local function getRoleColor(role)
    if role == "Murderer" then return Color3.fromRGB(255, 50, 50) end
    if role == "Sheriff" then return Color3.fromRGB(50, 150, 255) end
    return Color3.fromRGB(50, 255, 100)
end

local function manageESP(plr)
    if plr == LocalPlayer then return end
    local char = plr.Character
    if not char then return end
    local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    if not head then return end

    if not ESPCache[plr] then
        local hl = Instance.new("Highlight", char); hl.Name = "MH_HL"
        local bb = Instance.new("BillboardGui", head); bb.Name = "MH_BB"; bb.Size = UDim2.new(0, 160, 0, 40); bb.StudsOffset = Vector3.new(0, 2.5, 0); bb.AlwaysOnTop = true
        local txt = Instance.new("TextLabel", bb); txt.Size = UDim2.new(1,0,1,0); txt.BackgroundTransparency = 1; txt.Font = Enum.Font.GothamBold; txt.TextSize = 12
        ESPCache[plr] = {hl=hl, bb=bb, txt=txt}
    end

    local e = ESPCache[plr]
    local role = RoleCache[plr] or "Innocent"
    local show = CFG.espEnabled and (CFG.espShowAll or (role == "Murderer" and not CFG.espShowAll))
    
    e.hl.Enabled = show
    e.bb.Enabled = show
    
    if show then
        local color = getRoleColor(role)
        e.hl.FillColor = color; e.hl.OutlineColor = color
        local dist = math.floor((Camera.CFrame.Position - head.Position).Magnitude)
        e.txt.Text = role .. " | " .. dist .. "m"
        e.txt.TextColor3 = color
    end
end

-- ============================================================
-- ДВИЖЕНИЕ
-- ============================================================
local function doMovement()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    if CFG.flyEnabled then
        if not flyBV then
            flyBV = Instance.new("BodyVelocity", hrp); flyBV.MaxForce = Vector3.new(1e5,1e5,1e5)
            flyBG = Instance.new("BodyGyro", hrp); flyBG.MaxTorque = Vector3.new(1e5,1e5,1e5); flyBG.P = 1e4
        end
        flyBV.Velocity = Camera.CFrame.LookVector * 50; flyBG.CFrame = Camera.CFrame
    else
        if flyBV then flyBV:Destroy(); flyBV = nil; flyBG:Destroy(); flyBG = nil end
    end

    for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = not CFG.noclipEnabled end end
    hum.WalkSpeed = CFG.speedEnabled and CFG.speedValue or 16
end

-- ============================================================
-- AIMBOT
-- ============================================================
local function doAimbot()
    if not CFG.aimbotEnabled then return end
    local isPressing = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) or UserInputService:IsMouseButtonPressed(Enum.UserInputType.Touch)
    if not isPressing then return end

    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local best, bestDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        if hrp and RoleCache[plr] == "Murderer" then
            local sp, on = Camera:WorldToViewportPoint(hrp.Position)
            if on and sp.Z > 0 then
                local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                if d < CFG.aimFOV and d < bestDist then bestDist = d; best = plr end
            end
        end
    end
    if best then
        local part = best.Character:FindFirstChild(CFG.aimPart) or best.Character:FindFirstChild("HumanoidRootPart")
        if part then Camera.CFrame = Camera.CFrame:Lerp(CFG.aimPart == "Head" and CFrame.new(Camera.CFrame.Position, part.Position) or CFrame.lookAt(Camera.CFrame.Position, part.Position), CFG.aimSmooth) end
    end
end

-- ============================================================
-- АВТО-ПОДБОР
-- ============================================================
local function doAutoPickup()
    if not CFG.autoPickup or isPickingUp then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Tool") and (obj.Name == "Gun" or obj.Name == "Knife") then
            local handle = obj:FindFirstChild("Handle")
            if handle and (hrp.Position - handle.Position).Magnitude < 150 then
                isPickingUp = true; local originalPos = hrp.CFrame
                hrp.CFrame = handle.CFrame; task.wait(0.15)
                if char and char:FindFirstChild("HumanoidRootPart") then char.HumanoidRootPart.CFrame = originalPos end
                isPickingUp = false; break 
            end
        end
    end
end

-- ============================================================
-- FLING (ВЫБОР ИГРОКА)
-- ============================================================
local function doFling()
    if not CFG.flingEnabled then return end
    if UserInputService:IsKeyDown(Enum.KeyCode.F) or UserInputService:IsMouseButtonPressed(Enum.UserInputType.Touch) then
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            if flingTarget == "All" then
                char.HumanoidRootPart.Velocity = Vector3.new(math.random(-100,100), 100, math.random(-100,100))
            else
                local target = Players:FindFirstChild(flingTarget)
                if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                    char.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame
                    target.Character.HumanoidRootPart.Velocity = Vector3.new(math.random(-500,500), 500, math.random(-500,500))
                end
            end
        end
    end
end

-- ============================================================
-- БЕЛОЕ МЕНЮ С НАСТРОЙКАМИ
-- ============================================================
local parent = LocalPlayer:WaitForChild("PlayerGui")
pcall(function() parent = gethui() end)

local blur = Instance.new("BlurEffect", Lighting); blur.Size = 0; blur.Enabled = false
local screen = Instance.new("ScreenGui"); screen.Name = "ManyHubUI"; screen.ResetOnSpawn = false; screen.DisplayOrder = 999; screen.Parent = parent

-- Кнопка
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 60, 0, 60); toggleBtn.Position = UDim2.new(0, 20, 0.5, -30)
toggleBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255); toggleBtn.Text = "MH"
toggleBtn.TextColor3 = Color3.fromRGB(0, 0, 0); toggleBtn.Font = Enum.Font.GothamBlack; toggleBtn.TextSize = 20
toggleBtn.ZIndex = 10; toggleBtn.Parent = screen
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 30)
local stroke = Instance.new("UIStroke", toggleBtn); stroke.Color = Color3.fromRGB(0, 0, 0); stroke.Thickness = 2

-- Логика перетаскивания кнопки
local dragging, dragInput, dragStart, startPos
toggleBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = toggleBtn.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end)
toggleBtn.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        toggleBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Главное окно (Белое)
local main = Instance.new("Frame")
main.Size = UDim2.new(0, 420, 0, 320); main.Position = UDim2.new(0.5, -210, 0.5, -160)
main.BackgroundColor3 = Color3.fromRGB(255, 255, 255); main.BorderSizePixel = 0; main.Active = true; main.Draggable = true; main.Visible = false; main.ZIndex = 5; main.Parent = screen
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 16)
local mainStroke = Instance.new("UIStroke", main); mainStroke.Color = Color3.fromRGB(0, 0, 0); mainStroke.Thickness = 1

-- Шапка
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 40); header.BackgroundColor3 = Color3.fromRGB(245, 245, 245); header.ZIndex = 6; header.Parent = main
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 16)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -120, 1, 0); title.Position = UDim2.new(0, 15, 0, 0); title.BackgroundTransparency = 1
title.Text = "ManyHub"; title.TextColor3 = Color3.fromRGB(0, 0, 0); title.Font = Enum.Font.GothamBold
title.TextSize = 18; title.TextXAlignment = Enum.TextXAlignment.Left; title.ZIndex = 7; title.Parent = header

-- Шестеренка (Настройки)
local settingsBtn = Instance.new("TextButton")
settingsBtn.Size = UDim2.new(0, 30, 0, 30); settingsBtn.Position = UDim2.new(1, -75, 0, 5)
settingsBtn.BackgroundColor3 = Color3.fromRGB(200, 200, 200); settingsBtn.Text = "⚙"
settingsBtn.TextColor3 = Color3.fromRGB(0, 0, 0); settingsBtn.Font = Enum.Font.GothamBold; settingsBtn.TextSize = 18
settingsBtn.ZIndex = 7; settingsBtn.Parent = header; Instance.new("UICorner", settingsBtn).CornerRadius = UDim.new(0, 6)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30); closeBtn.Position = UDim2.new(1, -40, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60); closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255); closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 14
closeBtn.ZIndex = 7; closeBtn.Parent = header; Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

local tabPanel = Instance.new("Frame")
tabPanel.Size = UDim2.new(0, 100, 1, -50); tabPanel.Position = UDim2.new(0, 10, 0, 45)
tabPanel.BackgroundTransparency = 1; tabPanel.ZIndex = 6; tabPanel.Parent = main

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -120, 1, -50); content.Position = UDim2.new(0, 115, 0, 45)
content.BackgroundTransparency = 1; content.ZIndex = 6; content.Parent = main

local tabs, tabBtns = {}, {}
local function switchTab(name)
    currentTab = name
    for tabName, frame in pairs(tabs) do
        frame.Visible = (tabName == name)
        tabBtns[tabName].BackgroundColor3 = (tabName == name) and Color3.fromRGB(200, 200, 255) or Color3.fromRGB(240, 240, 240)
    end
end

local function createTab(name, index)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30); btn.Position = UDim2.new(0, 0, 0, (index-1)*35)
    btn.BackgroundColor3 = index == 1 and Color3.fromRGB(200, 200, 255) or Color3.fromRGB(240, 240, 240)
    btn.Text = name; btn.TextColor3 = Color3.fromRGB(0, 0, 0); btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12; btn.ZIndex = 7; btn.Parent = tabPanel
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    tabBtns[name] = btn

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0); frame.BackgroundTransparency = 1
    frame.Visible = index == 1; frame.ZIndex = 7; frame.Parent = content
    tabs[name] = frame
    
    btn.MouseButton1Click:Connect(function() switchTab(name) end)
    return frame
end

-- Отрисовка
local function drawUI()
    for _, child in ipairs(content:GetChildren()) do if child:IsA("Frame") then child:ClearAllChildren() end end
    for _, child in ipairs(tabPanel:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end

    local espFrame = createTab("ESP", 1)
    local aimFrame = createTab("Aimbot", 2)
    local moveFrame = createTab("Movement", 3)
    local tpFrame = createTab("Teleport", 4)
    local flingFrame = createTab("Fling", 5)
    local setFrame = createTab("Settings", 6)

    -- ESP
    local espToggle = Instance.new("TextButton", espFrame)
    espToggle.Size = UDim2.new(1, 0, 0, 30); espToggle.Position = UDim2.new(0, 0, 0, 0)
    espToggle.BackgroundColor3 = CFG.espEnabled and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(220, 220, 220)
    espToggle.Text = T("espEnable") .. ": " .. (CFG.espEnabled and "ON" or "OFF"); espToggle.TextColor3 = Color3.fromRGB(0, 0, 0); espToggle.Font = Enum.Font.Gotham; espToggle.ZIndex = 8
    Instance.new("UICorner", espToggle).CornerRadius = UDim.new(0, 6)
    espToggle.MouseButton1Click:Connect(function() CFG.espEnabled = not CFG.espEnabled; espToggle.Text = T("espEnable") .. ": " .. (CFG.espEnabled and "ON" or "OFF"); espToggle.BackgroundColor3 = CFG.espEnabled and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(220, 220, 220) end)

    -- Aimbot (Ввод FOV)
    local aimToggle = Instance.new("TextButton", aimFrame)
    aimToggle.Size = UDim2.new(1, 0, 0, 30); aimToggle.Position = UDim2.new(0, 0, 0, 0)
    aimToggle.BackgroundColor3 = CFG.aimbotEnabled and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(220, 220, 220)
    aimToggle.Text = T("aimEnable") .. ": " .. (CFG.aimbotEnabled and "ON" or "OFF"); aimToggle.TextColor3 = Color3.fromRGB(0, 0, 0); aimToggle.Font = Enum.Font.Gotham; aimToggle.ZIndex = 8
    Instance.new("UICorner", aimToggle).CornerRadius = UDim.new(0, 6)
    aimToggle.MouseButton1Click:Connect(function() CFG.aimbotEnabled = not CFG.aimbotEnabled; aimToggle.Text = T("aimEnable") .. ": " .. (CFG.aimbotEnabled and "ON" or "OFF"); aimToggle.BackgroundColor3 = CFG.aimbotEnabled and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(220, 220, 220) end)

    local fovBox = Instance.new("TextBox", aimFrame)
    fovBox.Size = UDim2.new(1, 0, 0, 30); fovBox.Position = UDim2.new(0, 0, 0, 40)
    fovBox.BackgroundColor3 = Color3.fromRGB(240, 240, 240); fovBox.Text = "FOV: " .. CFG.aimFOV; fovBox.TextColor3 = Color3.fromRGB(0, 0, 0); fovBox.Font = Enum.Font.Gotham; fovBox.ZIndex = 8
    Instance.new("UICorner", fovBox).CornerRadius = UDim.new(0, 6)
    fovBox.FocusLost:Connect(function() local num = tonumber(fovBox.Text:match("%d+")) if num then CFG.aimFOV = num fovBox.Text = "FOV: " .. num end end)

    -- Movement (Слайдер скорости)
    local speedLabel = Instance.new("TextLabel", moveFrame)
    speedLabel.Size = UDim2.new(1, 0, 0, 20); speedLabel.Position = UDim2.new(0, 0, 0, 0)
    speedLabel.BackgroundTransparency = 1; speedLabel.Text = "Speed: " .. CFG.speedValue; speedLabel.TextColor3 = Color3.fromRGB(0, 0, 0); speedLabel.Font = Enum.Font.Gotham; speedLabel.TextSize = 12; speedLabel.ZIndex = 8
    
    local speedBar = Instance.new("Frame", moveFrame)
    speedBar.Size = UDim2.new(1, 0, 0, 10); speedBar.Position = UDim2.new(0, 0, 0, 25)
    speedBar.BackgroundColor3 = Color3.fromRGB(220, 220, 220); speedBar.ZIndex = 8; Instance.new("UICorner", speedBar).CornerRadius = UDim.new(0, 5)
    
    local speedFill = Instance.new("Frame", speedBar)
    speedFill.Size = UDim2.new((CFG.speedValue - 20) / 130, 0, 1, 0); speedFill.BackgroundColor3 = Color3.fromRGB(100, 200, 100); speedFill.ZIndex = 9; Instance.new("UICorner", speedFill).CornerRadius = UDim.new(0, 5)
    
    local speedKnob = Instance.new("TextButton", speedBar)
    speedKnob.Size = UDim2.new(0, 20, 0, 20); speedKnob.Position = UDim2.new((CFG.speedValue - 20) / 130, -10, 0.5, -10)
    speedKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255); speedKnob.Text = ""; speedKnob.ZIndex = 10; speedKnob.Parent = speedBar
    Instance.new("UICorner", speedKnob).CornerRadius = UDim.new(0, 10)

    local draggingSpeed = false
    speedKnob.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then draggingSpeed = true end end)
    UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then draggingSpeed = false end end)
    UserInputService.InputChanged:Connect(function(input)
        if draggingSpeed and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local mouseX = input.Position.X
            local barPos = speedBar.AbsolutePosition.X
            local barSize = speedBar.AbsoluteSize.X
            local percent = math.clamp((mouseX - barPos) / barSize, 0, 1)
            CFG.speedValue = math.floor(20 + percent * 130)
            speedFill.Size = UDim2.new(percent, 0, 1, 0)
            speedKnob.Position = UDim2.new(percent, -10, 0.5, -10)
            speedLabel.Text = "Speed: " .. CFG.speedValue
            CFG.speedEnabled = true
        end
    end)

    -- Fling (Выбор игрока)
    local flingToggle = Instance.new("TextButton", flingFrame)
    flingToggle.Size = UDim2.new(1, 0, 0, 30); flingToggle.Position = UDim2.new(0, 0, 0, 0)
    flingToggle.BackgroundColor3 = CFG.flingEnabled and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(220, 220, 220)
    flingToggle.Text = T("flingMode") .. ": " .. (CFG.flingEnabled and "ON" or "OFF"); flingToggle.TextColor3 = Color3.fromRGB(0, 0, 0); flingToggle.Font = Enum.Font.Gotham; flingToggle.ZIndex = 8
    Instance.new("UICorner", flingToggle).CornerRadius = UDim.new(0, 6)
    flingToggle.MouseButton1Click:Connect(function() CFG.flingEnabled = not CFG.flingEnabled; flingToggle.Text = T("flingMode") .. ": " .. (CFG.flingEnabled and "ON" or "OFF"); flingToggle.BackgroundColor3 = CFG.flingEnabled and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(220, 220, 220) end)

    local flingBox = Instance.new("TextBox", flingFrame)
    flingBox.Size = UDim2.new(1, 0, 0, 30); flingBox.Position = UDim2.new(0, 0, 0, 40)
    flingBox.BackgroundColor3 = Color3.fromRGB(240, 240, 240); flingBox.Text = "Target: All"; flingBox.TextColor3 = Color3.fromRGB(0, 0, 0); flingBox.Font = Enum.Font.Gotham; flingBox.ZIndex = 8
    Instance.new("UICorner", flingBox).CornerRadius = UDim.new(0, 6)
    flingBox.FocusLost:Connect(function() flingTarget = flingBox.Text:gsub("Target: ", "") end)

    -- Настройки (Языки)
    local langBtn = Instance.new("TextButton", setFrame)
    langBtn.Size = UDim2.new(1, 0, 0, 30); langBtn.Position = UDim2.new(0, 0, 0, 0)
    langBtn.BackgroundColor3 = Color3.fromRGB(220, 220, 220); langBtn.Text = T("lang"); langBtn.TextColor3 = Color3.fromRGB(0, 0, 0); langBtn.Font = Enum.Font.Gotham; langBtn.ZIndex = 8
    Instance.new("UICorner", langBtn).CornerRadius = UDim.new(0, 6)
    langBtn.MouseButton1Click:Connect(function() LANG = LANG == "RU" and "EN" or "RU"; drawUI() end)

    switchTab(currentTab)
end

-- Открытие/Закрытие
local isOpen = false
local function toggleMenu()
    isOpen = not isOpen; main.Visible = isOpen; blur.Enabled = isOpen
    if isOpen then
        main.Size = UDim2.new(0, 0, 0, 0)
        TweenService:Create(main, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0, 420, 0, 320)}):Play()
        blur.Size = 15
    end
end
toggleBtn.MouseButton1Click:Connect(toggleMenu)
closeBtn.MouseButton1Click:Connect(toggleMenu)
settingsBtn.MouseButton1Click:Connect(function() switchTab("Settings") end)

-- ============================================================
-- ЗАПУСК
-- ============================================================
drawUI()
Players.PlayerAdded:Connect(function(plr) plr.CharacterAdded:Connect(function() task.wait(1); manageESP(plr) end) end)
for _, plr in ipairs(Players:GetPlayers()) do if plr ~= LocalPlayer then manageESP(plr); plr.CharacterAdded:Connect(function() task.wait(1); manageESP(plr) end) end end

RunService.RenderStepped:Connect(function()
    updateRoles()
    for plr, _ in pairs(ESPCache) do manageESP(plr) end
    doAimbot()
    doMovement()
    doAutoPickup()
    doFling()
    if CFG.antiAfk then pcall(function() game:GetService("VirtualUser"):ClickButton2(Vector2.new()) end) end
end)
