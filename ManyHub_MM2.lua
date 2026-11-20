-- ManyHub_Green_Final.lua · Lua · MM2 Client-Side
-- Очищенная версия: без Silent Aim и Hitbox. Только рабочие функции.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local LANG = "RU"
local Locale = {
    RU = { title = "ManyHub", esp = "Визуал", aim = "Аимбот", move = "Движение", tp = "Телепорт", fling = "Флинг", settings = "Настройки",
        espEnable = "ESP", aimEnable = "Аимбот", fov = "FOV", fly = "Полет", noclip = "Noclip", speed = "Скорость",
        tpM = "ТП к Убийце", tpS = "ТП к Шерифу", autoPickup = "Авто-подбор", lang = "Язык (RU/EN)", flingBtn = "ШВЫРНУТЬ", autoShoot = "Авто-стрельба" },
    EN = { title = "ManyHub", esp = "Visuals", aim = "Aimbot", move = "Movement", tp = "Teleport", fling = "Fling", settings = "Settings",
        espEnable = "ESP", aimEnable = "Aimbot", fov = "FOV", fly = "Fly", noclip = "Noclip", speed = "Speed",
        tpM = "TP to Murderer", tpS = "TP to Sheriff", autoPickup = "Auto Pickup", lang = "Language (RU/EN)", flingBtn = "FLING", autoShoot = "Auto Shoot" }
}
local function T(key) return Locale[LANG][key] or key end

local CFG = {
    espEnabled = true, aimbotEnabled = false, aimFOV = 150, aimSmooth = 0.3, autoShoot = false,
    flyEnabled = false, noclipEnabled = false, speedValue = 16, autoPickup = false, antiAfk = true
}

local RoleCache, ESPCache = {}, {}
local flyBV, flyBG
local isPickingUp = false
local currentTab = "ESP"

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
    return Color3.fromRGB(0, 255, 0)
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
    e.hl.Enabled = CFG.espEnabled; e.bb.Enabled = CFG.espEnabled
    if CFG.espEnabled then
        local color = getRoleColor(role)
        e.hl.FillColor = color; e.hl.OutlineColor = color
        e.txt.Text = role .. " | " .. math.floor((Camera.CFrame.Position - head.Position).Magnitude) .. "m"
        e.txt.TextColor3 = color
    end
end

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
    hum.WalkSpeed = CFG.speedValue
end

local function doAimbot()
    if not CFG.aimbotEnabled then return end
    local isPressing = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) or UserInputService:IsMouseButtonPressed(Enum.UserInputType.Touch)
    if not isPressing then return end

    local mousePos = UserInputService:GetMouseLocation()
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local checkPos = mousePos.Magnitude > 0 and mousePos or center

    local best, bestDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        local head = plr.Character and plr.Character:FindFirstChild("Head")
        
        if hrp and head and RoleCache[plr] == "Murderer" then
            local sp, on = Camera:WorldToViewportPoint(head.Position)
            if on and sp.Z > 0 then
                local d = (Vector2.new(sp.X, sp.Y) - checkPos).Magnitude
                if d < CFG.aimFOV and d < bestDist then 
                    bestDist = d
                    best = plr 
                end
            end
        end
    end
    
    if best then
        local targetPart = best.Character:FindFirstChild("Head") or best.Character:FindFirstChild("HumanoidRootPart")
        if targetPart then
            local targetCFrame = CFrame.new(Camera.CFrame.Position, targetPart.Position)
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, CFG.aimSmooth)
            
            if CFG.autoShoot then
                local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                if tool and tool.Name == "Gun" then pcall(function() tool:Activate() end) end
            end
        end
    end
end

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
-- UI (GREEN NEON)
-- ============================================================
local parent = LocalPlayer:WaitForChild("PlayerGui")
pcall(function() parent = gethui() end)

local blur = Instance.new("BlurEffect", Lighting); blur.Size = 0; blur.Enabled = false
local screen = Instance.new("ScreenGui"); screen.Name = "ManyHubUI"; screen.ResetOnSpawn = false; screen.DisplayOrder = 999; screen.Parent = parent

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 120, 0, 40); toggleBtn.Position = UDim2.new(0, 20, 0.5, -20)
toggleBtn.BackgroundColor3 = Color3.fromRGB(10, 20, 10); toggleBtn.Text = "ManyHub"
toggleBtn.TextColor3 = Color3.fromRGB(0, 255, 0); toggleBtn.Font = Enum.Font.GothamBlack; toggleBtn.TextSize = 16
toggleBtn.ZIndex = 10; toggleBtn.Parent = screen
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)
local stroke = Instance.new("UIStroke", toggleBtn); stroke.Color = Color3.fromRGB(0, 255, 0); stroke.Thickness = 2

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

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 420, 0, 320); main.Position = UDim2.new(0.5, -210, 0.5, -160)
main.BackgroundColor3 = Color3.fromRGB(10, 15, 10); main.BackgroundTransparency = 0.1
main.BorderSizePixel = 0; main.Active = true; main.Draggable = true; main.Visible = false; main.ZIndex = 5; main.Parent = screen
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
local mainStroke = Instance.new("UIStroke", main); mainStroke.Color = Color3.fromRGB(0, 255, 0); mainStroke.Thickness = 1.5

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 40); header.BackgroundColor3 = Color3.fromRGB(15, 30, 15); header.ZIndex = 6; header.Parent = main
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -120, 1, 0); title.Position = UDim2.new(0, 15, 0, 0); title.BackgroundTransparency = 1
title.Text = "ManyHub"; title.TextColor3 = Color3.fromRGB(0, 255, 0); title.Font = Enum.Font.GothamBold
title.TextSize = 18; title.TextXAlignment = Enum.TextXAlignment.Left; title.ZIndex = 7; title.Parent = header

local setBtn = Instance.new("TextButton")
setBtn.Size = UDim2.new(0, 30, 0, 30); setBtn.Position = UDim2.new(1, -75, 0, 5)
setBtn.BackgroundColor3 = Color3.fromRGB(20, 50, 20); setBtn.Text = "⚙"
setBtn.TextColor3 = Color3.fromRGB(0, 255, 0); setBtn.Font = Enum.Font.GothamBold; setBtn.TextSize = 16
setBtn.ZIndex = 7; setBtn.Parent = header; Instance.new("UICorner", setBtn).CornerRadius = UDim.new(0, 6)

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
        tabBtns[tabName].BackgroundColor3 = (tabName == name) and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(15, 30, 15)
    end
end

local function createTab(name, index)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30); btn.Position = UDim2.new(0, 0, 0, (index-1)*35)
    btn.BackgroundColor3 = index == 1 and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(15, 30, 15)
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
    local flingFrame = createTab(T("fling"), 5)
    local setFrame = createTab(T("settings"), 6)

    -- ESP
    local espToggle = Instance.new("TextButton", espFrame)
    espToggle.Size = UDim2.new(1, 0, 0, 30); espToggle.Position = UDim2.new(0, 0, 0, 0)
    espToggle.BackgroundColor3 = CFG.espEnabled and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(20, 40, 20)
    espToggle.Text = T("espEnable") .. ": " .. (CFG.espEnabled and "ON" or "OFF"); espToggle.TextColor3 = Color3.fromRGB(255, 255, 255); espToggle.Font = Enum.Font.Gotham; espToggle.ZIndex = 8
    Instance.new("UICorner", espToggle).CornerRadius = UDim.new(0, 6)
    espToggle.MouseButton1Click:Connect(function() CFG.espEnabled = not CFG.espEnabled; espToggle.Text = T("espEnable") .. ": " .. (CFG.espEnabled and "ON" or "OFF"); espToggle.BackgroundColor3 = CFG.espEnabled and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(20, 40, 20) end)

    -- Aimbot
    local aimToggle = Instance.new("TextButton", aimFrame)
    aimToggle.Size = UDim2.new(1, 0, 0, 30); aimToggle.Position = UDim2.new(0, 0, 0, 0)
    aimToggle.BackgroundColor3 = CFG.aimbotEnabled and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(20, 40, 20)
    aimToggle.Text = T("aimEnable") .. ": " .. (CFG.aimbotEnabled and "ON" or "OFF"); aimToggle.TextColor3 = Color3.fromRGB(255, 255, 255); aimToggle.Font = Enum.Font.Gotham; aimToggle.ZIndex = 8
    Instance.new("UICorner", aimToggle).CornerRadius = UDim.new(0, 6)
    aimToggle.MouseButton1Click:Connect(function() CFG.aimbotEnabled = not CFG.aimbotEnabled; aimToggle.Text = T("aimEnable") .. ": " .. (CFG.aimbotEnabled and "ON" or "OFF"); aimToggle.BackgroundColor3 = CFG.aimbotEnabled and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(20, 40, 20) end)

    local autoShootBtn = Instance.new("TextButton", aimFrame)
    autoShootBtn.Size = UDim2.new(1, 0, 0, 30); autoShootBtn.Position = UDim2.new(0, 0, 0, 40)
    autoShootBtn.BackgroundColor3 = CFG.autoShoot and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(20, 40, 20)
    autoShootBtn.Text = T("autoShoot") .. ": " .. (CFG.autoShoot and "ON" or "OFF"); autoShootBtn.TextColor3 = Color3.fromRGB(255, 255, 255); autoShootBtn.Font = Enum.Font.Gotham; autoShootBtn.ZIndex = 8
    Instance.new("UICorner", autoShootBtn).CornerRadius = UDim.new(0, 6)
    autoShootBtn.MouseButton1Click:Connect(function() CFG.autoShoot = not CFG.autoShoot; autoShootBtn.Text = T("autoShoot") .. ": " .. (CFG.autoShoot and "ON" or "OFF"); autoShootBtn.BackgroundColor3 = CFG.autoShoot and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(20, 40, 20) end)

    -- Movement
    local function addMoveBtn(text, configKey, y)
        local b = Instance.new("TextButton", moveFrame)
        b.Size = UDim2.new(1, 0, 0, 30); b.Position = UDim2.new(0, 0, 0, y)
        b.BackgroundColor3 = CFG[configKey] and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(20, 40, 20)
        b.Text = text .. ": " .. (CFG[configKey] and "ON" or "OFF"); b.TextColor3 = Color3.fromRGB(255, 255, 255); b.Font = Enum.Font.Gotham; b.ZIndex = 8
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        b.MouseButton1Click:Connect(function() CFG[configKey] = not CFG[configKey]; b.Text = text .. ": " .. (CFG[configKey] and "ON" or "OFF"); b.BackgroundColor3 = CFG[configKey] and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(20, 40, 20) end)
    end
    addMoveBtn(T("fly"), "flyEnabled", 0)
    addMoveBtn(T("noclip"), "noclipEnabled", 35)

    local speedLabel = Instance.new("TextLabel", moveFrame)
    speedLabel.Size = UDim2.new(1, 0, 0, 20); speedLabel.Position = UDim2.new(0, 0, 0, 75)
    speedLabel.BackgroundTransparency = 1; speedLabel.Text = T("speed") .. ": " .. CFG.speedValue; speedLabel.TextColor3 = Color3.fromRGB(0, 255, 0); speedLabel.Font = Enum.Font.Gotham; speedLabel.TextSize = 12; speedLabel.ZIndex = 8

    local speedBar = Instance.new("Frame", moveFrame)
    speedBar.Size = UDim2.new(1, 0, 0, 10); speedBar.Position = UDim2.new(0, 0, 0, 100)
    speedBar.BackgroundColor3 = Color3.fromRGB(20, 40, 20); speedBar.ZIndex = 8; Instance.new("UICorner", speedBar).CornerRadius = UDim.new(0, 5)
    
    local speedFill = Instance.new("Frame", speedBar)
    speedFill.Size = UDim2.new((CFG.speedValue - 16) / 134, 0, 1, 0); speedFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0); speedFill.ZIndex = 9; Instance.new("UICorner", speedFill).CornerRadius = UDim.new(0, 5)
    
    local speedKnob = Instance.new("TextButton", speedBar)
    speedKnob.Size = UDim2.new(0, 20, 0, 20); speedKnob.Position = UDim2.new((CFG.speedValue - 16) / 134, -10, 0.5, -10)
    speedKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255); speedKnob.Text = ""; speedKnob.ZIndex = 10; speedKnob.Parent = speedBar
    Instance.new("UICorner", speedKnob).CornerRadius = UDim.new(0, 10)

    local draggingSpeed = false
    speedKnob.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then draggingSpeed = true end end)
    UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then draggingSpeed = false end end)
    UserInputService.InputChanged:Connect(function(input)
        if draggingSpeed and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local mouseX = input.Position.X; local barPos = speedBar.AbsolutePosition.X; local barSize = speedBar.AbsoluteSize.X
            local percent = math.clamp((mouseX - barPos) / barSize, 0, 1)
            CFG.speedValue = math.floor(16 + percent * 134)
            speedFill.Size = UDim2.new(percent, 0, 1, 0); speedKnob.Position = UDim2.new(percent, -10, 0.5, -10); speedLabel.Text = T("speed") .. ": " .. CFG.speedValue
        end
    end)

    -- TP
    local function addTpBtn(text, targetRole, y)
        local b = Instance.new("TextButton", tpFrame)
        b.Size = UDim2.new(1, 0, 0, 30); b.Position = UDim2.new(0, 0, 0, y)
        b.BackgroundColor3 = Color3.fromRGB(0, 180, 0); b.Text = text; b.TextColor3 = Color3.fromRGB(255, 255, 255); b.Font = Enum.Font.Gotham; b.ZIndex = 8
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        b.MouseButton1Click:Connect(function()
            for _, p in ipairs(Players:GetPlayers()) do
                if RoleCache[p] == targetRole and p.Character and LocalPlayer.Character then LocalPlayer.Character.HumanoidRootPart.CFrame = p.Character.HumanoidRootPart.CFrame + Vector3.new(0,3,0) end
            end
        end)
    end
    addTpBtn(T("tpM"), "Murderer", 0)
    addTpBtn(T("tpS"), "Sheriff", 35)

    -- FLING
    local yOffset = 0
    local playerBtns = {}
    local selectedPlr = nil

    local function refreshList()
        for _, b in ipairs(playerBtns) do b:Destroy() end; table.clear(playerBtns); yOffset = 0
        for _, p in ipairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            local b = Instance.new("TextButton", flingFrame)
            b.Size = UDim2.new(1, 0, 0, 25); b.Position = UDim2.new(0, 0, 0, yOffset)
            b.BackgroundColor3 = Color3.fromRGB(20, 40, 20); b.Text = p.Name; b.TextColor3 = Color3.fromRGB(255, 255, 255); b.Font = Enum.Font.Gotham; b.TextSize = 12; b.ZIndex = 8
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
            b.MouseButton1Click:Connect(function()
                selectedPlr = p
                for _, btn in ipairs(playerBtns) do btn.BackgroundColor3 = Color3.fromRGB(20, 40, 20) end
                b.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
            end)
            table.insert(playerBtns, b); yOffset = yOffset + 30
        end
    end
    refreshList()

    local flingBtn = Instance.new("TextButton", flingFrame)
    flingBtn.Size = UDim2.new(1, 0, 0, 30); flingBtn.Position = UDim2.new(0, 0, 0, yOffset + 10)
    flingBtn.BackgroundColor3 = Color3.fromRGB(0, 220, 0); flingBtn.Text = T("flingBtn"); flingBtn.TextColor3 = Color3.fromRGB(0, 0, 0); flingBtn.Font = Enum.Font.GothamBold; flingBtn.ZIndex = 8
    Instance.new("UICorner", flingBtn).CornerRadius = UDim.new(0, 6)
    flingBtn.MouseButton1Click:Connect(function()
        if selectedPlr and selectedPlr.Character and selectedPlr.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character then
            LocalPlayer.Character.HumanoidRootPart.CFrame = selectedPlr.Character.HumanoidRootPart.CFrame
            selectedPlr.Character.HumanoidRootPart.Velocity = Vector3.new(math.random(-500,500), 500, math.random(-500,500))
        end
    end)

    -- Settings
    local langBtn = Instance.new("TextButton", setFrame)
    langBtn.Size = UDim2.new(1, 0, 0, 30); langBtn.Position = UDim2.new(0, 0, 0, 0)
    langBtn.BackgroundColor3 = Color3.fromRGB(20, 40, 20); langBtn.Text = T("lang"); langBtn.TextColor3 = Color3.fromRGB(0, 255, 0); langBtn.Font = Enum.Font.Gotham; langBtn.ZIndex = 8
    Instance.new("UICorner", langBtn).CornerRadius = UDim.new(0, 6)
    langBtn.MouseButton1Click:Connect(function() LANG = LANG == "RU" and "EN" or "RU"; drawUI() end)

    local autoPickupBtn = Instance.new("TextButton", setFrame)
    autoPickupBtn.Size = UDim2.new(1, 0, 0, 30); autoPickupBtn.Position = UDim2.new(0, 0, 0, 40)
    autoPickupBtn.BackgroundColor3 = CFG.autoPickup and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(20, 40, 20)
    autoPickupBtn.Text = T("autoPickup") .. ": " .. (CFG.autoPickup and "ON" or "OFF"); autoPickupBtn.TextColor3 = Color3.fromRGB(255, 255, 255); autoPickupBtn.Font = Enum.Font.Gotham; autoPickupBtn.ZIndex = 8
    Instance.new("UICorner", autoPickupBtn).CornerRadius = UDim.new(0, 6)
    autoPickupBtn.MouseButton1Click:Connect(function() CFG.autoPickup = not CFG.autoPickup; autoPickupBtn.Text = T("autoPickup") .. ": " .. (CFG.autoPickup and "ON" or "OFF"); autoPickupBtn.BackgroundColor3 = CFG.autoPickup and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(20, 40, 20) end)

    switchTab(currentTab)
end

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
setBtn.MouseButton1Click:Connect(function() switchTab(T("settings")) end)

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
    if CFG.antiAfk then pcall(function() game:GetService("VirtualUser"):ClickButton2(Vector2.new()) end) end
end)
