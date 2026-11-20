-- ManyHub_Custom.lua · Lua · Pure Roblox UI · MM2 Client-Side
-- Красивое меню с вкладками без сторонних библиотек.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local CFG = {
    espEnabled = true, aimbotEnabled = false, aimFOV = 150, aimSmooth = 0.3,
    autoShootEnabled = false, bhopEnabled = false, flyEnabled = false, noclipEnabled = false, antiAfk = true
}

local RoleCache, ESPCache = {}, {}
local flyBV, flyBG, bhopConn
local currentTab = "ESP"

-- ============================================================
-- РОЛИ И ESP
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
    billboard.Name = "ManyHub_BB"; billboard.Size = UDim2.new(0, 160, 0, 60)
    billboard.StudsOffset = Vector3.new(0, 3.5, 0); billboard.AlwaysOnTop = true; billboard.Parent = head

    local bg = Instance.new("Frame", billboard)
    bg.Size = UDim2.new(1, 0, 1, 0); bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bg.BackgroundTransparency = 0.7; bg.BorderSizePixel = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

    local nameLbl = Instance.new("TextLabel", bg); nameLbl.Size = UDim2.new(1, -4, 0, 20)
    nameLbl.Position = UDim2.new(0, 2, 0, 2); nameLbl.BackgroundTransparency = 1
    nameLbl.Text = plr.Name; nameLbl.TextColor3 = color; nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 13

    local roleLbl = Instance.new("TextLabel", bg); roleLbl.Size = UDim2.new(1, -4, 0, 16)
    roleLbl.Position = UDim2.new(0, 2, 0, 22); roleLbl.BackgroundTransparency = 1
    roleLbl.Text = role; roleLbl.TextColor3 = color; roleLbl.Font = Enum.Font.GothamBold; roleLbl.TextSize = 11

    ESPCache[plr] = {highlight=highlight, billboard=billboard, nameLbl=nameLbl, roleLbl=roleLbl}
end

local function updateESP()
    if not CFG.espEnabled then return end
    for plr, e in pairs(ESPCache) do
        local char = plr.Character
        if char then
            local role = RoleCache[plr] or "Innocent"
            local color = getRoleColor(role)
            if e.highlight then e.highlight.FillColor = color; e.highlight.OutlineColor = color end
            if e.roleLbl then e.roleLbl.Text = role; e.roleLbl.TextColor3 = color end
        end
    end
end

-- ============================================================
-- АИМБОТ / АВТОСТРЕЛЬБА / ДВИЖЕНИЕ
-- ============================================================
local function doAimbot()
    if not CFG.aimbotEnabled then return end
    local isPressing = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) 
                     or UserInputService:IsMouseButtonPressed(Enum.UserInputType.Touch)
    if not isPressing then return end

    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local best, bestDist = nil, math.huge
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
        
        if hrp and hum and hum.Health > 0 and RoleCache[plr] == "Murderer" then
            local sp, on = Camera:WorldToViewportPoint(hrp.Position)
            if on and sp.Z > 0 then
                local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                if d < CFG.aimFOV and d < bestDist then 
                    bestDist = d; best = plr 
                end
            end
        end
    end
    
    if best then
        local part = best.Character:FindFirstChild("Head") or best.Character:FindFirstChild("HumanoidRootPart")
        if part then Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, part.Position), CFG.aimSmooth) end
    end
end

local function doAutoShoot()
    if not CFG.autoShootEnabled then return end
    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool and tool.Name == "Gun" then
        for _, plr in ipairs(Players:GetPlayers()) do
            if RoleCache[plr] == "Murderer" and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                if (char.HumanoidRootPart.Position - plr.Character.HumanoidRootPart.Position).Magnitude < 200 then
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, plr.Character.HumanoidRootPart.Position)
                    tool:Activate(); break
                end
            end
        end
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
end

-- ============================================================
-- КРАСИВОЕ КАСТОМНОЕ МЕНЮ
-- ============================================================
local parent = game:GetService("CoreGui")
pcall(function() parent = gethui() end)

local screen = Instance.new("ScreenGui")
screen.Name = "ManyHubCustomUI"; screen.ResetOnSpawn = false; screen.Parent = parent

-- Кнопка открытия
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 70, 0, 40); toggleBtn.Position = UDim2.new(1, -90, 0.5, -20)
toggleBtn.BackgroundColor3 = Color3.fromRGB(35, 20, 45); toggleBtn.Text = "MH"
toggleBtn.TextColor3 = Color3.fromRGB(180, 80, 255); toggleBtn.Font = Enum.Font.GothamBlack; toggleBtn.TextSize = 18
toggleBtn.Parent = screen
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)
local s1 = Instance.new("UIStroke", toggleBtn); s1.Color = Color3.fromRGB(180, 80, 255); s1.Thickness = 2

-- Главное окно
local mainWin = Instance.new("Frame")
mainWin.Size = UDim2.new(0, 400, 0, 300); mainWin.Position = UDim2.new(0.5, -200, 0.5, -150)
mainWin.BackgroundColor3 = Color3.fromRGB(20, 10, 30); mainWin.BorderSizePixel = 0
mainWin.Active = true; mainWin.Draggable = true; mainWin.Visible = false; mainWin.Parent = screen
Instance.new("UICorner", mainWin).CornerRadius = UDim.new(0, 12)
local s2 = Instance.new("UIStroke", mainWin); s2.Color = Color3.fromRGB(180, 80, 255); s2.Thickness = 2

-- Заголовок
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 40); titleBar.BackgroundColor3 = Color3.fromRGB(30, 15, 45)
titleBar.Parent = mainWin; Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 12)

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -40, 1, 0); titleText.Position = UDim2.new(0, 15, 0, 0)
titleText.BackgroundTransparency = 1; titleText.Text = "ManyHub · Custom"
titleText.TextColor3 = Color3.fromRGB(180, 80, 255); titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 16; titleText.TextXAlignment = Enum.TextXAlignment.Left; titleText.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30); closeBtn.Position = UDim2.new(1, -35, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50); closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255); closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = titleBar; Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

-- Левая панель (вкладки)
local sideBar = Instance.new("Frame")
sideBar.Size = UDim2.new(0, 100, 1, -50); sideBar.Position = UDim2.new(0, 10, 0, 45)
sideBar.BackgroundTransparency = 1; sideBar.Parent = mainWin

local tabs = {"ESP", "Aimbot", "Movement"}
local tabButtons = {}

local function switchTab(tabName)
    currentTab = tabName
    for name, btn in pairs(tabButtons) do
        if name == tabName then
            btn.BackgroundColor3 = Color3.fromRGB(180, 80, 255)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            btn.BackgroundColor3 = Color3.fromRGB(40, 25, 55)
            btn.TextColor3 = Color3.fromRGB(150, 150, 150)
        end
    end
    -- Здесь можно добавить логику переключения контента
end

for i, tabName in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 35); btn.Position = UDim2.new(0, 0, 0, (i-1)*45)
    btn.BackgroundColor3 = Color3.fromRGB(40, 25, 55); btn.Text = tabName
    btn.TextColor3 = Color3.fromRGB(150, 150, 150); btn.Font = Enum.Font.GothamBold; btn.TextSize = 14
    btn.Parent = sideBar; Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    tabButtons[tabName] = btn
    btn.MouseButton1Click:Connect(function() switchTab(tabName) end)
end

-- Правая панель (контент)
local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -120, 1, -50); contentArea.Position = UDim2.new(0, 115, 0, 45)
contentArea.BackgroundTransparency = 1; contentArea.Parent = mainWin

-- Пример тумблера (ESP)
local espToggle = Instance.new("TextButton")
espToggle.Size = UDim2.new(1, 0, 0, 40); espToggle.BackgroundColor3 = Color3.fromRGB(40, 25, 55)
espToggle.Text = "ESP: ON"; espToggle.TextColor3 = Color3.fromRGB(0, 255, 100)
espToggle.Font = Enum.Font.GothamBold; espToggle.Parent = contentArea
Instance.new("UICorner", espToggle).CornerRadius = UDim.new(0, 6)

espToggle.MouseButton1Click:Connect(function()
    CFG.espEnabled = not CFG.espEnabled
    espToggle.Text = "ESP: " .. (CFG.espEnabled and "ON" or "OFF")
    espToggle.TextColor3 = CFG.espEnabled and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 80, 80)
    if not CFG.espEnabled then
        for plr, e in pairs(ESPCache) do e.highlight:Destroy(); e.billboard:Destroy(); ESPCache[plr] = nil end
    else
        for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then createESP(p) end end
    end
end)

-- Открытие/закрытие
local isOpen = false
toggleBtn.MouseButton1Click:Connect(function()
    isOpen = not isOpen
    mainWin.Visible = isOpen
end)
closeBtn.MouseButton1Click:Connect(function()
    isOpen = false; mainWin.Visible = false
end)

switchTab("ESP") -- Вкладка по умолчанию

-- ============================================================
-- ЗАПУСК
-- ============================================================
for _, plr in ipairs(Players:GetPlayers()) do createESP(plr) end
Players.PlayerAdded:Connect(function(plr) plr.CharacterAdded:Connect(function() task.wait(1); if CFG.espEnabled then createESP(plr) end end) end)
LocalPlayer.CharacterAdded:Connect(function() task.wait(1); if CFG.espEnabled then for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then createESP(p) end end end end)

RunService.RenderStepped:Connect(function()
    updateRoles()
    updateESP()
    doAimbot()
    doAutoShoot()
    updateMovement()
    if CFG.antiAfk then pcall(function() game:GetService("VirtualUser"):ClickButton2(Vector2.new()) end) end
end)
