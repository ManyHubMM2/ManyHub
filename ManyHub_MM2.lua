-- ManyHub_Glass.lua · Lua · Custom UI · MM2 Client-Side
-- Красивое меню без сторонних библиотек. Все функции рабочие.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local CFG = {
    espEnabled = true, aimbotEnabled = false, aimFOV = 150, aimSmooth = 0.3,
    bhopEnabled = false, flyEnabled = false, noclipEnabled = false, antiAfk = true, walkSpeed = 16
}

local RoleCache, ESPCache = {}, {}
local flyBV, flyBG, bhopConn

-- ============================================================
-- ЛОГИКА
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

local function createESP(plr)
    if plr == LocalPlayer then return end
    local char = plr.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    local head = char:FindFirstChild("Head") or hrp
    if not hrp then return end

    local role = RoleCache[plr] or "Innocent"
    local color = getRoleColor(role)
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "ManyHub_ESP"; highlight.FillColor = color; highlight.FillTransparency = 0.6
    highlight.OutlineColor = color; highlight.Parent = char

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ManyHub_BB"; billboard.Size = UDim2.new(0, 160, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 3, 0); billboard.AlwaysOnTop = true; billboard.Parent = head

    local bg = Instance.new("Frame", billboard)
    bg.Size = UDim2.new(1, 0, 1, 0); bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bg.BackgroundTransparency = 0.5; bg.BorderSizePixel = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)

    local nameLbl = Instance.new("TextLabel", bg); nameLbl.Size = UDim2.new(1, -4, 0, 20)
    nameLbl.Position = UDim2.new(0, 2, 0, 0); nameLbl.BackgroundTransparency = 1
    nameLbl.Text = plr.Name; nameLbl.TextColor3 = color; nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 13

    local roleLbl = Instance.new("TextLabel", bg); roleLbl.Size = UDim2.new(1, -4, 0, 16)
    roleLbl.Position = UDim2.new(0, 2, 0, 20); roleLbl.BackgroundTransparency = 1
    roleLbl.Text = role; roleLbl.TextColor3 = color; roleLbl.Font = Enum.Font.Gotham; roleLbl.TextSize = 11

    ESPCache[plr] = {highlight=highlight, billboard=billboard, roleLbl=roleLbl}
end

local function updateESP()
    if not CFG.espEnabled then return end
    for plr, e in pairs(ESPCache) do
        if plr.Character then
            local role = RoleCache[plr] or "Innocent"
            local color = getRoleColor(role)
            if e.highlight then e.highlight.FillColor = color; e.highlight.OutlineColor = color end
            if e.roleLbl then e.roleLbl.Text = role; e.roleLbl.TextColor3 = color end
        end
    end
end

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
        local part = best.Character:FindFirstChild("Head") or best.Character:FindFirstChild("HumanoidRootPart")
        if part then Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, part.Position), CFG.aimSmooth) end
    end
end

local function updateMovement()
    if CFG.flyEnabled then
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            if not flyBV then
                flyBV = Instance.new("BodyVelocity", hrp); flyBV.MaxForce = Vector3.new(1e5,1e5,1e5)
                flyBG = Instance.new("BodyGyro", hrp); flyBG.MaxTorque = Vector3.new(1e5,1e5,1e5); flyBG.P = 1e4
            end
            local move = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0,1,0) end
            flyBV.Velocity = move.Magnitude > 0 and move.Unit * 50 or Vector3.zero; flyBG.CFrame = Camera.CFrame
        end
    else
        if flyBV then flyBV:Destroy(); flyBV = nil; flyBG:Destroy(); flyBG = nil end
    end

    if CFG.noclipEnabled then
        local char = LocalPlayer.Character
        if char then for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end
    end
    
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum and hum.WalkSpeed ~= CFG.walkSpeed then hum.WalkSpeed = CFG.walkSpeed end
end

-- ============================================================
-- КРАСИВЫЙ UI (GLASSMORPHISM)
-- ============================================================
local parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
pcall(function() parent = gethui() end)

-- Блюр фона (создается, но выключен)
local lighting = game:GetService("Lighting")
local blur = Instance.new("BlurEffect", lighting)
blur.Size = 0; blur.Enabled = false

local screen = Instance.new("ScreenGui")
screen.Name = "ManyHubGlass"; screen.ResetOnSpawn = false; screen.DisplayOrder = 999; screen.Parent = parent

-- Кнопка MH
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 60, 0, 60); toggleBtn.Position = UDim2.new(0, 20, 0.5, -30)
toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 15, 45); toggleBtn.Text = "MH"
toggleBtn.TextColor3 = Color3.fromRGB(180, 80, 255); toggleBtn.Font = Enum.Font.GothamBlack; toggleBtn.TextSize = 22
toggleBtn.ZIndex = 10; toggleBtn.Parent = screen
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 12)
local stroke = Instance.new("UIStroke", toggleBtn); stroke.Color = Color3.fromRGB(180, 80, 255); stroke.Thickness = 2

-- Главное окно
local main = Instance.new("Frame")
main.Size = UDim2.new(0, 380, 0, 260); main.Position = UDim2.new(0.5, -190, 0.5, -130)
main.BackgroundColor3 = Color3.fromRGB(20, 10, 30); main.BackgroundTransparency = 0.2
main.BorderSizePixel = 0; main.Active = true; main.Draggable = true; main.Visible = false; main.ZIndex = 5; main.Parent = screen
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 16)
local mainStroke = Instance.new("UIStroke", main); mainStroke.Color = Color3.fromRGB(180, 80, 255); mainStroke.Thickness = 1.5

-- Шапка окна
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 40); header.BackgroundColor3 = Color3.fromRGB(35, 20, 45); header.ZIndex = 6; header.Parent = main
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 16)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 1, 0); title.Position = UDim2.new(0, 15, 0, 0); title.BackgroundTransparency = 1
title.Text = "ManyHub · UI"; title.TextColor3 = Color3.fromRGB(255, 255, 255); title.Font = Enum.Font.GothamBold
title.TextSize = 16; title.TextXAlignment = Enum.TextXAlignment.Left; title.ZIndex = 7; title.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 26, 0, 26); closeBtn.Position = UDim2.new(1, -36, 0, 7)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60); closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255); closeBtn.Font = Enum.Font.GothamBold
closeBtn.ZIndex = 7; closeBtn.Parent = header; Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

-- Левая панель (вкладки)
local tabPanel = Instance.new("Frame")
tabPanel.Size = UDim2.new(0, 100, 1, -50); tabPanel.Position = UDim2.new(0, 10, 0, 45)
tabPanel.BackgroundTransparency = 1; tabPanel.ZIndex = 6; tabPanel.Parent = main

-- Правая панель (контент)
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -120, 1, -50); content.Position = UDim2.new(0, 115, 0, 45)
content.BackgroundTransparency = 1; content.ZIndex = 6; content.Parent = main

-- Логика вкладок
local tabs = {}
local tabBtns = {}

local function switchTab(name)
    for tabName, frame in pairs(tabs) do
        frame.Visible = (tabName == name)
        tabBtns[tabName].BackgroundColor3 = (tabName == name) and Color3.fromRGB(150, 50, 255) or Color3.fromRGB(35, 20, 45)
    end
end

local function createTab(name, index)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 35); btn.Position = UDim2.new(0, 0, 0, (index-1)*45)
    btn.BackgroundColor3 = index == 1 and Color3.fromRGB(150, 50, 255) or Color3.fromRGB(35, 20, 45)
    btn.Text = name; btn.TextColor3 = Color3.fromRGB(255, 255, 255); btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13; btn.ZIndex = 7; btn.Parent = tabPanel
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    tabBtns[name] = btn

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0); frame.BackgroundTransparency = 1
    frame.Visible = index == 1; frame.ZIndex = 7; frame.Parent = content
    tabs[name] = frame
    
    btn.MouseButton1Click:Connect(function() switchTab(name) end)
    return frame
end

local espFrame = createTab("ESP", 1)
local aimFrame = createTab("Aimbot", 2)
local moveFrame = createTab("Movement", 3)

-- Функция создания тумблера
local function createToggle(parentFrame, text, initialState, callback, yPos)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 35); btn.Position = UDim2.new(0, 0, 0, yPos)
    btn.BackgroundColor3 = initialState and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(45, 25, 55)
    btn.Text = text .. ": " .. (initialState and "ON" or "OFF")
    btn.TextColor3 = Color3.fromRGB(255, 255, 255); btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13; btn.ZIndex = 8; btn.Parent = parentFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    
    local state = initialState
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = text .. ": " .. (state and "ON" or "OFF")
        btn.BackgroundColor3 = state and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(45, 25, 55)
        callback(state)
    end)
end

-- Заполняем вкладки
createToggle(espFrame, "ESP Enabled", CFG.espEnabled, function(v)
    CFG.espEnabled = v
    if v then for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then createESP(p) end end
    else for p, e in pairs(ESPCache) do e.highlight:Destroy(); e.billboard:Destroy(); ESPCache[p] = nil end end
end, 0)

createToggle(aimFrame, "Aimbot", CFG.aimbotEnabled, function(v) CFG.aimbotEnabled = v end, 0)

createToggle(moveFrame, "Fly", CFG.flyEnabled, function(v) CFG.flyEnabled = v end, 0)
createToggle(moveFrame, "Noclip", CFG.noclipEnabled, function(v) CFG.noclipEnabled = v end, 45)
createToggle(moveFrame, "Speed 32", false, function(v) CFG.walkSpeed = v and 32 or 16 end, 90)

-- Открытие/Закрытие
local isOpen = false
local function toggleMenu()
    isOpen = not isOpen
    main.Visible = isOpen
    blur.Enabled = isOpen
    if isOpen then
        main.Size = UDim2.new(0, 0, 0, 0)
        TweenService:Create(main, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0, 380, 0, 260)}):Play()
        blur.Size = 15
    end
end

toggleBtn.MouseButton1Click:Connect(toggleMenu)
closeBtn.MouseButton1Click:Connect(toggleMenu)

-- ============================================================
-- ЗАПУСК
-- ============================================================
for _, plr in ipairs(Players:GetPlayers()) do createESP(plr) end
Players.PlayerAdded:Connect(function(plr) plr.CharacterAdded:Connect(function() task.wait(1); if CFG.espEnabled then createESP(plr) end end) end)

RunService.RenderStepped:Connect(function()
    updateRoles()
    updateESP()
    doAimbot()
    updateMovement()
    if CFG.antiAfk then pcall(function() game:GetService("VirtualUser"):ClickButton2(Vector2.new()) end) end
end)
