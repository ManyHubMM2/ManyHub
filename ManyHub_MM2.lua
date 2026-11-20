-- ManyHub_Pulse.lua · Lua · Orion UI · MM2 Client-Side
-- Без ключей. Красивое меню с вкладками. ESP показывает всех.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ============================================================
-- ЗАГРУЗКА ORION (Красивый UI)
-- ============================================================
local OrionLib = loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Orion/main/source'))()

local Window = OrionLib:MakeWindow({
    Name = "ManyHub · Pulse Style", 
    HidePremium = false, 
    SaveConfig = false,
    ConfigFolder = "ManyHubConfig"
})

-- ============================================================
-- КОНФИГ И ПЕРЕМЕННЫЕ
-- ============================================================
local CFG = {
    espEnabled = true, -- Включено по умолчанию
    aimbotEnabled = false, aimFOV = 120, aimSmooth = 0.3,
    autoShootEnabled = false,
    bhopEnabled = false, flyEnabled = false, noclipEnabled = false, antiAfk = true
}

local RoleCache, ESPCache = {}, {}
local flyBV, flyBG, bhopConn

-- ============================================================
-- ЛОГИКА РОЛЕЙ
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

-- ============================================================
-- ESP (ПОКАЗЫВАЕТ ВСЕГДА, ДАЖЕ ВЫБЫВШИХ)
-- ============================================================
local function createESP(plr)
    if plr == LocalPlayer then return end
    local char = plr.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    -- Если ХРП или Головы нет, пробуем вешать на Torso (выбывшие)
    if not hrp then hrp = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") end
    if not head then head = hrp end
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
    if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
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
                if d < CFG.aimFOV and d < bestDist then bestDist = d; best = plr end
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
                    tool:Activate()
                    break
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
-- GUI (ВКЛАДКИ ORION)
-- ============================================================
-- Вкладка ESP
local EspTab = Window:MakeTab({Name = "ESP", Icon = "rbxassetid://4483345998", PremiumOnly = false})
EspTab:AddToggle({Name = "ESP Enabled", Default = true, Callback = function(v) 
    CFG.espEnabled = v
    if v then 
        for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then createESP(p) end end
    else
        for plr, e in pairs(ESPCache) do e.highlight:Destroy(); e.billboard:Destroy(); ESPCache[plr] = nil end
    end
end})

-- Вкладка Aimbot
local AimTab = Window:MakeTab({Name = "Aimbot", Icon = "rbxassetid://4483345998", PremiumOnly = false})
AimTab:AddToggle({Name = "Aimbot (RMB)", Default = false, Callback = function(v) CFG.aimbotEnabled = v end})
AimTab:AddSlider({Name = "FOV", Min = 10, Max = 360, Default = 120, Callback = function(v) CFG.aimFOV = v end})
AimTab:AddToggle({Name = "Auto Shoot (Sheriff)", Default = false, Callback = function(v) CFG.autoShootEnabled = v end})

-- Вкладка Movement
local MoveTab = Window:MakeTab({Name = "Movement", Icon = "rbxassetid://4483345998", PremiumOnly = false})
MoveTab:AddToggle({Name = "Fly", Default = false, Callback = function(v) CFG.flyEnabled = v end})
MoveTab:AddToggle({Name = "Noclip", Default = false, Callback = function(v) CFG.noclipEnabled = v end})
MoveTab:AddToggle({Name = "BHop", Default = false, Callback = function(v) 
    CFG.bhopEnabled = v
    if v then
        if bhopConn then bhopConn:Disconnect() end
        bhopConn = RunService.Heartbeat:Connect(function()
            if LocalPlayer.Character then
                local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum and (hum:GetState() == Enum.HumanoidStateType.Landed or hum:GetState() == Enum.HumanoidStateType.Running) then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end
        end)
    else
        if bhopConn then bhopConn:Disconnect(); bhopConn = nil end
    end
end})

-- Вкладка Player
local PlayerTab = Window:MakeTab({Name = "Player", Icon = "rbxassetid://4483345998", PremiumOnly = false})
PlayerTab:AddToggle({Name = "Anti-AFK", Default = true, Callback = function(v) CFG.antiAfk = v end})
PlayerTab:AddSlider({Name = "WalkSpeed", Min = 16, Max = 200, Default = 16, Callback = function(v) 
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = v end
end})

-- ============================================================
-- АВТО-ЗАПУСК И ОБНОВЛЕНИЕ
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

OrionLib:Init()
