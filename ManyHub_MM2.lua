-- ManyHub_MM2.lua · Lua · MM2 Client-Side
-- Финальная сборка: все функции рабочие, добавлен слайдер скорости.

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
    RU = {
        title = "ManyHub · MM2", esp = "Визуал (ESP)", aim = "Аимбот", move = "Движение", tp = "Телепорт", plr = "Игрок",
        espEnable = "Включить ESP", espRoles = "Показывать:", espAll = "Всех", espMurder = "Убийц",
        aimEnable = "Аимбот (Палец/ПКМ)", aimPart = "Целиться в:", aimFov = "Радиус (FOV):", aimSmooth = "Плавность:",
        fly = "Полет", noclip = "Noclip", speed = "Скорость", fling = "Fling", bhop = "Bhop",
        tpMurder = "ТП к Убийце", tpSheriff = "ТП к Шерифу", tpGun = "ТП к Оружию",
        fullbright = "Fullbright", autoPickup = "Авто-подбор", antiAfk = "Anti-AFK", lang = "Язык (RU/EN)"
    },
    EN = {
        title = "ManyHub · MM2", esp = "Visuals (ESP)", aim = "Aimbot", move = "Movement", tp = "Teleport", plr = "Player",
        espEnable = "Enable ESP", espRoles = "Show:", espAll = "All", espMurder = "Murderers",
        aimEnable = "Aimbot (Touch/RMB)", aimPart = "Target Part:", aimFov = "FOV Radius:", aimSmooth = "Smoothness:",
        fly = "Fly", noclip = "Noclip", speed = "Speed", fling = "Fling", bhop = "Bhop",
        tpMurder = "TP to Murderer", tpSheriff = "TP to Sheriff", tpGun = "TP to Gun",
        fullbright = "Fullbright", autoPickup = "Auto Pickup", antiAfk = "Anti-AFK", lang = "Language (RU/EN)"
    }
}
local function T(key) return Locale[LANG][key] or key end

-- ============================================================
-- КОНФИГ
-- ============================================================
local CFG = {
    espEnabled = true, espShowAll = true, aimbotEnabled = false, aimFOV = 150, aimSmooth = 0.3, aimPart = "Head",
    flyEnabled = false, noclipEnabled = false, speedEnabled = false, speedValue = 50, flingEnabled = false, bhopEnabled = false,
    fullbright = false, autoPickup = false, antiAfk = true, walkSpeed = 16
}

local RoleCache, ESPCache = {}, {}
local flyBV, flyBG, bhopConn
local currentTab = "ESP"
local isPickingUp = false

-- ============================================================
-- ESP ЛОГИКА
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
    
    e.hl.Enabled = show; e.bb.Enabled = show
    if show then
        local color = getRoleColor(role)
        e.hl.FillColor = color; e.hl.OutlineColor = color
        e.txt.Text = role .. " | " .. math.floor((Camera.CFrame.Position - head.Position).Magnitude) .. "m"
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
    hum.WalkSpeed = CFG.speedEnabled and CFG.speedValue or CFG.walkSpeed

    if CFG.flingEnabled and (UserInputService:IsKeyDown(Enum.KeyCode.F) or UserInputService:IsMouseButtonPressed(Enum.UserInputType.Touch)) then
        hrp.Velocity = Vector3.new(math.random(-100,100), 100, math.random(-100,100))
    end
end

-- ============================================================
-- АИМБОТ
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
        if part then Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, part.Position), CFG.aimSmooth) end
    end
end

-- ============================================================
-- ТП К ОРУЖИЮ (AUTO PICKUP)
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
            if handle then
                local dist = (hrp.Position - handle.Position).Magnitude
                if dist < 150 then -- Если оружие в радиусе 150 стадов
                    isPickingUp = true
                    local originalPos = hrp.CFrame
                    
                    -- ТП к оружию
                    hrp.CFrame = handle.CFrame
                    task.wait(0.15) -- Ждем, чтобы сервер выдал оружие
                    
                    -- ТП обратно
                    if char and char:FindFirstChild("HumanoidRootPart") then
                        char.HumanoidRootPart.CFrame = originalPos
                    end
                    isPickingUp = false
                    break 
                end
            end
        end
    end
end

-- ============================================================
-- КРАСИВОЕ МЕНЮ
-- ============================================================
local parent = LocalPlayer:WaitForChild("PlayerGui")
pcall(function() parent = gethui() end)

local blur = Instance.new("BlurEffect", Lighting)
blur.Size = 0; blur.Enabled = false

local screen = Instance.new("ScreenGui")
screen.Name = "ManyHubUI"; screen.ResetOnSpawn = false; screen.DisplayOrder = 999; screen.Parent = parent

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 60, 0, 60); toggleBtn.Position = UDim2.new(0, 20, 0.5, -30)
toggleBtn.BackgroundColor3 = Color3.fromRGB(180, 80, 255); toggleBtn.Text = "MH"
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255); toggleBtn.Font = Enum.Font.GothamBlack; toggleBtn.TextSize = 20
toggleBtn.ZIndex = 10; toggleBtn.Parent = screen
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 30)
local stroke = Instance.new("UIStroke", toggleBtn); stroke.Color = Color3.fromRGB(255, 255, 255); stroke.Thickness = 2

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 400, 0, 320); main.Position = UDim2.new(0.5, -200, 0.5, -160)
main.BackgroundColor3 = Color3.fromRGB(20, 10, 30); main.BackgroundTransparency = 0.1
main.BorderSizePixel = 0; main.Active = true; main.Draggable = true; main.Visible = false; main.ZIndex = 5; main.Parent = screen
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 16)
local mainStroke = Instance.new("UIStroke", main); mainStroke.Color = Color3.fromRGB(180, 80, 255); mainStroke.Thickness = 1.5

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 40); header.BackgroundColor3 = Color3.fromRGB(35, 20, 45); header.ZIndex = 6; header.Parent = main
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 16)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -100, 1, 0); title.Position = UDim2.new(0, 15, 0, 0); title.BackgroundTransparency = 1
title.Text = T("title"); title.TextColor3 = Color3.fromRGB(255, 255, 255); title.Font = Enum.Font.GothamBold
title.TextSize = 16; title.TextXAlignment = Enum.TextXAlignment.Left; title.ZIndex = 7; title.Parent = header

local langBtn = Instance.new("TextButton")
langBtn.Size = UDim2.new(0, 40, 0, 24); langBtn.Position = UDim2.new(1, -75, 0, 8)
langBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 255); langBtn.Text = "RU"
langBtn.TextColor3 = Color3.fromRGB(255, 255, 255); langBtn.Font = Enum.Font.GothamBold; langBtn.TextSize = 12
langBtn.ZIndex = 7; langBtn.Parent = header; Instance.new("UICorner", langBtn).CornerRadius = UDim.new(0, 6)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 24, 0, 24); closeBtn.Position = UDim2.new(1, -30, 0, 8)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60); closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255); closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 12
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
        tabBtns[tabName].BackgroundColor3 = (tabName == name) and Color3.fromRGB(180, 80, 255) or Color3.fromRGB(35, 20, 45)
    end
end

local function createTab(name, index)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30); btn.Position = UDim2.new(0, 0, 0, (index-1)*35)
    btn.BackgroundColor3 = index == 1 and Color3.fromRGB(180, 80, 255) or Color3.fromRGB(35, 20, 45)
    btn.Text = name; btn.TextColor3 = Color3.fromRGB(255, 255, 255); btn.Font = Enum.Font.GothamBold
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

local function drawUI()
    for _, child in ipairs(content:GetChildren()) do if child:IsA("Frame") then child:ClearAllChildren() end end
    for _, child in ipairs(tabPanel:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end

    local espFrame = createTab(T("esp"), 1)
    local aimFrame = createTab(T("aim"), 2)
    local moveFrame = createTab(T("move"), 3)
    local tpFrame = createTab(T("tp"), 4)
    local plrFrame = createTab(T("plr"), 5)

    -- ESP
    local espToggle = Instance.new("TextButton", espFrame)
    espToggle.Size = UDim2.new(1, 0, 0, 30); espToggle.Position = UDim2.new(0, 0, 0, 0)
    espToggle.BackgroundColor3 = CFG.espEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(45, 25, 55)
    espToggle.Text = T("espEnable") .. ": " .. (CFG.espEnabled and "ON" or "OFF"); espToggle.TextColor3 = Color3.fromRGB(255, 255, 255); espToggle.Font = Enum.Font.Gotham; espToggle.ZIndex = 8
    Instance.new("UICorner", espToggle).CornerRadius = UDim.new(0, 6)
    espToggle.MouseButton1Click:Connect(function() CFG.espEnabled = not CFG.espEnabled; espToggle.Text = T("espEnable") .. ": " .. (CFG.espEnabled and "ON" or "OFF"); espToggle.BackgroundColor3 = CFG.espEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(45, 25, 55) end)

    local roleToggle = Instance.new("TextButton", espFrame)
    roleToggle.Size = UDim2.new(1, 0, 0, 30); roleToggle.Position = UDim2.new(0, 0, 0, 40)
    roleToggle.BackgroundColor3 = Color3.fromRGB(45, 25, 55); roleToggle.Text = T("espRoles") .. " " .. (CFG.espShowAll and T("espAll") or T("espMurder")); roleToggle.TextColor3 = Color3.fromRGB(255, 255, 255); roleToggle.Font = Enum.Font.Gotham; roleToggle.ZIndex = 8
    Instance.new("UICorner", roleToggle).CornerRadius = UDim.new(0, 6)
    roleToggle.MouseButton1Click:Connect(function() CFG.espShowAll = not CFG.espShowAll; roleToggle.Text = T("espRoles") .. " " .. (CFG.espShowAll and T("espAll") or T("espMurder")) end)

    -- Aimbot
    local aimToggle = Instance.new("TextButton", aimFrame)
    aimToggle.Size = UDim2.new(1, 0, 0, 30); aimToggle.Position = UDim2.new(0, 0, 0, 0)
    aimToggle.BackgroundColor3 = CFG.aimbotEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(45, 25, 55)
    aimToggle.Text = T("aimEnable") .. ": " .. (CFG.aimbotEnabled and "ON" or "OFF"); aimToggle.TextColor3 = Color3.fromRGB(255, 255, 255); aimToggle.Font = Enum.Font.Gotham; aimToggle.ZIndex = 8
    Instance.new("UICorner", aimToggle).CornerRadius = UDim.new(0, 6)
    aimToggle.MouseButton1Click:Connect(function() CFG.aimbotEnabled = not CFG.aimbotEnabled; aimToggle.Text = T("aimEnable") .. ": " .. (CFG.aimbotEnabled and "ON" or "OFF"); aimToggle.BackgroundColor3 = CFG.aimbotEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(45, 25, 55) end)

    local partToggle = Instance.new("TextButton", aimFrame)
    partToggle.Size = UDim2.new(1, 0, 0, 30); partToggle.Position = UDim2.new(0, 0, 0, 40)
    partToggle.BackgroundColor3 = Color3.fromRGB(45, 25, 55); partToggle.Text = T("aimPart") .. " " .. CFG.aimPart; partToggle.TextColor3 = Color3.fromRGB(255, 255, 255); partToggle.Font = Enum.Font.Gotham; partToggle.ZIndex = 8
    Instance.new("UICorner", partToggle).CornerRadius = UDim.new(0, 6)
    partToggle.MouseButton1Click:Connect(function() CFG.aimPart = CFG.aimPart == "Head" and "HumanoidRootPart" or "Head"; partToggle.Text = T("aimPart") .. " " .. CFG.aimPart end)

    -- Movement (слайдер скорости)
    local function addMoveBtn(text, configKey, y)
        local b = Instance.new("TextButton", moveFrame)
        b.Size = UDim2.new(1, 0, 0, 30); b.Position = UDim2.new(0, 0, 0, y)
        b.BackgroundColor3 = CFG[configKey] and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(45, 25, 55)
        b.Text = text .. ": " .. (CFG[configKey] and "ON" or "OFF"); b.TextColor3 = Color3.fromRGB(255, 255, 255); b.Font = Enum.Font.Gotham; b.ZIndex = 8
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        b.MouseButton1Click:Connect(function() CFG[configKey] = not CFG[configKey]; b.Text = text .. ": " .. (CFG[configKey] and "ON" or "OFF"); b.BackgroundColor3 = CFG[configKey] and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(45, 25, 55) end)
    end
    addMoveBtn(T("fly"), "flyEnabled", 0)
    addMoveBtn(T("noclip"), "noclipEnabled", 35)
    addMoveBtn(T("speed"), "speedEnabled", 70)
    addMoveBtn(T("fling"), "flingEnabled", 105)

    -- Слайдер скорости
    local speedLabel = Instance.new("TextLabel", moveFrame)
    speedLabel.Size = UDim2.new(1, 0, 0, 20); speedLabel.Position = UDim2.new(0, 0, 0, 145)
    speedLabel.BackgroundTransparency = 1; speedLabel.Text = "Speed Value: " .. CFG.speedValue; speedLabel.TextColor3 = Color3.fromRGB(200,200,200); speedLabel.Font = Enum.Font.Gotham; speedLabel.TextSize = 12; speedLabel.ZIndex = 8
    
    local speedSlider = Instance.new("TextButton", moveFrame)
    speedSlider.Size = UDim2.new(1, 0, 0, 30); speedSlider.Position = UDim2.new(0, 0, 0, 165)
    speedSlider.BackgroundColor3 = Color3.fromRGB(45, 25, 55); speedSlider.Text = "+ Speed (10)"; speedSlider.TextColor3 = Color3.fromRGB(255, 255, 255); speedSlider.Font = Enum.Font.Gotham; speedSlider.ZIndex = 8
    Instance.new("UICorner", speedSlider).CornerRadius = UDim.new(0, 6)
    speedSlider.MouseButton1Click:Connect(function()
        CFG.speedValue = CFG.speedValue + 10
        if CFG.speedValue > 200 then CFG.speedValue = 16 end
        speedLabel.Text = "Speed Value: " .. CFG.speedValue
        speedSlider.Text = "+ Speed (" .. CFG.speedValue .. ")"
    end)

    -- TP
    local function addTpBtn(text, targetRole, y)
        local b = Instance.new("TextButton", tpFrame)
        b.Size = UDim2.new(1, 0, 0, 30); b.Position = UDim2.new(0, 0, 0, y)
        b.BackgroundColor3 = Color3.fromRGB(150, 50, 255); b.Text = text; b.TextColor3 = Color3.fromRGB(255, 255, 255); b.Font = Enum.Font.Gotham; b.ZIndex = 8
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        b.MouseButton1Click:Connect(function()
            for _, p in ipairs(Players:GetPlayers()) do
                if RoleCache[p] == targetRole and p.Character and LocalPlayer.Character then
                    LocalPlayer.Character.HumanoidRootPart.CFrame = p.Character.HumanoidRootPart.CFrame + Vector3.new(0,3,0)
                end
            end
        end)
    end
    addTpBtn(T("tpMurder"), "Murderer", 0)
    addTpBtn(T("tpSheriff"), "Sheriff", 35)

    -- Player
    local function addPlrBtn(text, configKey, y, isFunc)
        local b = Instance.new("TextButton", plrFrame)
        b.Size = UDim2.new(1, 0, 0, 30); b.Position = UDim2.new(0, 0, 0, y)
        b.BackgroundColor3 = CFG[configKey] and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(45, 25, 55)
        b.Text = text .. ": " .. (CFG[configKey] and "ON" or "OFF"); b.TextColor3 = Color3.fromRGB(255, 255, 255); b.Font = Enum.Font.Gotham; b.ZIndex = 8
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        b.MouseButton1Click:Connect(function()
            CFG[configKey] = not CFG[configKey]
            b.Text = text .. ": " .. (CFG[configKey] and "ON" or "OFF"); b.BackgroundColor3 = CFG[configKey] and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(45, 25, 55)
            if isFunc and CFG[configKey] then isFunc() end
        end)
    end
    addPlrBtn(T("fullbright"), "fullbright", 0, function() Lighting.Brightness = 3; Lighting.FogEnd = 100000 end)
    addPlrBtn(T("autoPickup"), "autoPickup", 35)
    addPlrBtn(T("antiAfk"), "antiAfk", 70)

    switchTab(currentTab)
end

local isOpen = false
local function toggleMenu()
    isOpen = not isOpen; main.Visible = isOpen; blur.Enabled = isOpen
    if isOpen then
        main.Size = UDim2.new(0, 0, 0, 0)
        TweenService:Create(main, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0, 400, 0, 320)}):Play()
        blur.Size = 15
    end
end
toggleBtn.MouseButton1Click:Connect(toggleMenu)
closeBtn.MouseButton1Click:Connect(toggleMenu)
langBtn.MouseButton1Click:Connect(function()
    LANG = LANG == "RU" and "EN" or "RU"; langBtn.Text = LANG; title.Text = T("title"); drawUI()
end)

-- ============================================================
-- ЗАПУСК
-- ============================================================
drawUI()

Players.PlayerAdded:Connect(function(plr) 
    plr.CharacterAdded:Connect(function() task.wait(1); manageESP(plr) end)
end)
for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then
        manageESP(plr)
        plr.CharacterAdded:Connect(function() task.wait(1); manageESP(plr) end)
    end
end

RunService.RenderStepped:Connect(function()
    updateRoles()
    for plr, _ in pairs(ESPCache) do manageESP(plr) end
    doAimbot()
    doMovement()
    doAutoPickup()
    if CFG.antiAfk then pcall(function() game:GetService("VirtualUser"):ClickButton2(Vector2.new()) end) end
end)
