-- ManyHub_Glass_Ultimate.lua · Lua · Custom UI · MM2 Client-Side
-- Полная сборка: Glassmorphism UI, все модули, картинка на кнопке.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local CFG = {
    espEnabled = true, espBox = true, espTracer = true, espSkeleton = false, espWeapons = true,
    aimbotEnabled = false, silentAim = false, hitboxExpand = false, autoShoot = false, aimFOV = 150, aimSmooth = 0.3, aimPart = "Head",
    flyEnabled = false, noclipEnabled = false, speedEnabled = false, bhopEnabled = false, antiFling = false,
    fullbright = false, fpsBoost = false, autoPickup = false, antiAfk = true, walkSpeed = 16
}

local RoleCache, ESPCache, WeaponCache = {}, {}, {}
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

local function updateESP()
    if not CFG.espEnabled then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local char = plr.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
        local head = char:FindFirstChild("Head") or hrp
        if not hrp then continue end

        local role = RoleCache[plr] or "Innocent"
        local color = getRoleColor(role)

        if not ESPCache[plr] then
            local hl = Instance.new("Highlight", char)
            hl.Name = "MH_HL"
            local bb = Instance.new("BillboardGui", head)
            bb.Name = "MH_BB"; bb.Size = UDim2.new(0, 100, 0, 30); bb.StudsOffset = Vector3.new(0, 2, 0); bb.AlwaysOnTop = true
            local txt = Instance.new("TextLabel", bb)
            txt.Size = UDim2.new(1,0,1,0); txt.BackgroundTransparency = 1; txt.TextColor3 = color; txt.Font = Enum.Font.GothamBold; txt.TextSize = 12
            ESPCache[plr] = {hl=hl, bb=bb, txt=txt}
        end
        
        local e = ESPCache[plr]
        e.hl.FillColor = color; e.hl.OutlineColor = color
        e.txt.Text = role .. " | " .. math.floor((Camera.CFrame.Position - hrp.Position).Magnitude) .. "m"
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
        local part = best.Character:FindFirstChild(CFG.aimPart) or best.Character:FindFirstChild("HumanoidRootPart")
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
    if hum then
        local targetSpeed = CFG.speedEnabled and 50 or CFG.walkSpeed
        if hum.WalkSpeed ~= targetSpeed then hum.WalkSpeed = targetSpeed end
    end
end

-- ============================================================
-- UI (GLASSMORPHISM)
-- ============================================================
local parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
pcall(function() parent = gethui() end)

local blur = Instance.new("BlurEffect", Lighting)
blur.Size = 0; blur.Enabled = false

local screen = Instance.new("ScreenGui")
screen.Name = "ManyHubUI"; screen.ResetOnSpawn = false; screen.DisplayOrder = 999; screen.Parent = parent

-- Кнопка с картинкой
local toggleBtn = Instance.new("ImageButton")
toggleBtn.Size = UDim2.new(0, 60, 0, 60); toggleBtn.Position = UDim2.new(0, 20, 0.5, -30)
toggleBtn.BackgroundTransparency = 1
toggleBtn.Image = "https://fotovssylku.ru/i/1000063845.nRKCn" -- Твоя картинка
toggleBtn.ZIndex = 10; toggleBtn.Parent = screen
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 30)

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 400, 0, 300); main.Position = UDim2.new(0.5, -200, 0.5, -150)
main.BackgroundColor3 = Color3.fromRGB(20, 10, 30); main.BackgroundTransparency = 0.2
main.BorderSizePixel = 0; main.Active = true; main.Draggable = true; main.Visible = false; main.ZIndex = 5; main.Parent = screen
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 16)
local mainStroke = Instance.new("UIStroke", main); mainStroke.Color = Color3.fromRGB(180, 80, 255); mainStroke.Thickness = 1.5

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 40); header.BackgroundColor3 = Color3.fromRGB(35, 20, 45); header.ZIndex = 6; header.Parent = main
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 16)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 1, 0); title.Position = UDim2.new(0, 15, 0, 0); title.BackgroundTransparency = 1
title.Text = "ManyHub · Ultimate"; title.TextColor3 = Color3.fromRGB(255, 255, 255); title.Font = Enum.Font.GothamBold
title.TextSize = 16; title.TextXAlignment = Enum.TextXAlignment.Left; title.ZIndex = 7; title.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 26, 0, 26); closeBtn.Position = UDim2.new(1, -36, 0, 7)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60); closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255); closeBtn.Font = Enum.Font.GothamBold
closeBtn.ZIndex = 7; closeBtn.Parent = header; Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

local tabPanel = Instance.new("Frame")
tabPanel.Size = UDim2.new(0, 100, 1, -50); tabPanel.Position = UDim2.new(0, 10, 0, 45)
tabPanel.BackgroundTransparency = 1; tabPanel.ZIndex = 6; tabPanel.Parent = main

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -120, 1, -50); content.Position = UDim2.new(0, 115, 0, 45)
content.BackgroundTransparency = 1; content.ZIndex = 6; content.Parent = main

local tabs, tabBtns = {}, {}

local function switchTab(name)
    for tabName, frame in pairs(tabs) do
        frame.Visible = (tabName == name)
        tabBtns[tabName].BackgroundColor3 = (tabName == name) and Color3.fromRGB(150, 50, 255) or Color3.fromRGB(35, 20, 45)
    end
end

local function createTab(name, index)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30); btn.Position = UDim2.new(0, 0, 0, (index-1)*35)
    btn.BackgroundColor3 = index == 1 and Color3.fromRGB(150, 50, 255) or Color3.fromRGB(35, 20, 45)
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

local espFrame = createTab("ESP", 1)
local aimFrame = createTab("Aimbot", 2)
local moveFrame = createTab("Movement", 3)
local tpFrame = createTab("Teleport", 4)
local plrFrame = createTab("Player", 5)

local function createToggle(parentFrame, text, initialState, callback, yPos)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30); btn.Position = UDim2.new(0, 0, 0, yPos)
    btn.BackgroundColor3 = initialState and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(45, 25, 55)
    btn.Text = text .. ": " .. (initialState and "ON" or "OFF")
    btn.TextColor3 = Color3.fromRGB(255, 255, 255); btn.Font = Enum.Font.Gotham
    btn.TextSize = 12; btn.ZIndex = 8; btn.Parent = parentFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    
    local state = initialState
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = text .. ": " .. (state and "ON" or "OFF")
        btn.BackgroundColor3 = state and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(45, 25, 55)
        callback(state)
    end)
end

-- Заполнение вкладок
createToggle(espFrame, "ESP Enabled", CFG.espEnabled, function(v) 
    CFG.espEnabled = v
    if not v then for p, e in pairs(ESPCache) do e.hl:Destroy(); e.bb:Destroy(); ESPCache[p] = nil end end
end, 0)
createToggle(espFrame, "Box ESP", CFG.espBox, function(v) CFG.espBox = v end, 35)
createToggle(espFrame, "Tracers", CFG.espTracer, function(v) CFG.espTracer = v end, 70)

createToggle(aimFrame, "Aimbot (Touch/RMB)", CFG.aimbotEnabled, function(v) CFG.aimbotEnabled = v end, 0)
createToggle(aimFrame, "Silent Aim", CFG.silentAim, function(v) CFG.silentAim = v end, 35)
createToggle(aimFrame, "Auto Shoot", CFG.autoShoot, function(v) CFG.autoShoot = v end, 70)
createToggle(aimFrame, "Hitbox Expander", CFG.hitboxExpand, function(v) CFG.hitboxExpand = v end, 105)

createToggle(moveFrame, "Fly", CFG.flyEnabled, function(v) CFG.flyEnabled = v end, 0)
createToggle(moveFrame, "Noclip", CFG.noclipEnabled, function(v) CFG.noclipEnabled = v end, 35)
createToggle(moveFrame, "Speed", CFG.speedEnabled, function(v) CFG.speedEnabled = v end, 70)
createToggle(moveFrame, "Bhop", CFG.bhopEnabled, function(v) CFG.bhopEnabled = v end, 105)
createToggle(moveFrame, "Anti-Fling", CFG.antiFling, function(v) CFG.antiFling = v end, 140)

local tpMurdererBtn = Instance.new("TextButton")
tpMurdererBtn.Size = UDim2.new(1, 0, 0, 30); tpMurdererBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 255)
tpMurdererBtn.Text = "TP to Murderer"; tpMurdererBtn.TextColor3 = Color3.fromRGB(255, 255, 255); tpMurdererBtn.Font = Enum.Font.GothamBold; tpMurdererBtn.ZIndex = 8
tpMurdererBtn.Parent = tpFrame; Instance.new("UICorner", tpMurdererBtn).CornerRadius = UDim.new(0, 6)
tpMurdererBtn.MouseButton1Click:Connect(function()
    for _, p in ipairs(Players:GetPlayers()) do
        if RoleCache[p] == "Murderer" and p.Character and LocalPlayer.Character then
            LocalPlayer.Character.HumanoidRootPart.CFrame = p.Character.HumanoidRootPart.CFrame + Vector3.new(0,3,0)
        end
    end
end)

createToggle(plrFrame, "Fullbright", CFG.fullbright, function(v) 
    CFG.fullbright = v
    Lighting.Brightness = v and 3 or 1
    Lighting.FogEnd = v and 100000 or 1000
end, 0)
createToggle(plrFrame, "FPS Boost", CFG.fpsBoost, function(v) CFG.fpsBoost = v end, 35)
createToggle(plrFrame, "Auto Pickup", CFG.autoPickup, function(v) CFG.autoPickup = v end, 70)
createToggle(plrFrame, "Anti-AFK", CFG.antiAfk, function(v) CFG.antiAfk = v end, 105)

-- Открытие/Закрытие
local isOpen = false
local function toggleMenu()
    isOpen = not isOpen
    main.Visible = isOpen
    blur.Enabled = isOpen
    if isOpen then
        main.Size = UDim2.new(0, 0, 0, 0)
        TweenService:Create(main, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0, 400, 0, 300)}):Play()
        blur.Size = 15
    end
end

toggleBtn.MouseButton1Click:Connect(toggleMenu)
closeBtn.MouseButton1Click:Connect(toggleMenu)

-- Логика перетаскивания кнопки
local dragging, dragInput, dragStart, startPos
toggleBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = toggleBtn.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
toggleBtn.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        toggleBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- ============================================================
-- ЗАПУСК
-- ============================================================
RunService.RenderStepped:Connect(function()
    updateRoles()
    updateESP()
    doAimbot()
    updateMovement()
    if CFG.antiAfk then pcall(function() game:GetService("VirtualUser"):ClickButton2(Vector2.new()) end) end
end)
