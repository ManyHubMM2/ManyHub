-- ManyHub_Full.lua · Lua · Roblox Executor (Delta/Synapse/Wave) · MM2 client-side
-- GUI: Rayfield. Вкладки: Key, ESP, Aimbot, AutoShoot, Movement.
-- Key-system: server-side validation + HWID. Master key = AdminManyHub-HDFG6.

-- ============================================================
-- КОНФИГ СЕРВЕРА
-- ============================================================
local SERVER = "https://ТВОЙ_СЕРВЕР.onrender.com"  -- ← замени
local MASTER_KEY = "AdminManyHub-HDFG6"

-- ============================================================
-- ЗАГРУЗКА RAYFIELD
-- ============================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ============================================================
-- СЕРВИСЫ
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ============================================================
-- КОНФИГ МОДУЛЕЙ
-- ============================================================
local CFG = {
    espEnabled = false, espRole = true, espDistance = true,
    aimbotEnabled = false, aimKey = Enum.UserInputType.MouseButton2,
    aimFOV = 120, aimSmooth = 0.3, aimPart = "Head",
    aimWallCheck = true, aimTargetRole = "Murderer",
    autoShootEnabled = false, autoShootDelay = 0.1, autoShootRange = 200,
    bhopEnabled = false, bhopJumpPower = 60,
    flyEnabled = false, flySpeed = 50,
    noclipEnabled = false,
}

-- ============================================================
-- KEY-SYSTEM: HWID + СЕТЬ
-- ============================================================
local function getHWID()
    local hwid = ""
    pcall(function() if gethwid then hwid = gethwid() end end)
    if hwid == "" then
        pcall(function() hwid = game:GetService("RbxAnalyticsService"):GetClientId() end)
    end
    if hwid == "" then hwid = tostring(LocalPlayer.UserId) end
    return hwid
end

local HWID = getHWID()

local function post(path, body)
    local req = syn and syn.request or request or http_request
    if not req then return {ok = false, error = "no http lib"} end
    local ok, res = pcall(function()
        return req({
            Url = SERVER .. path,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(body or {}),
        })
    end)
    if not ok or not res then return {ok = false, error = "request failed"} end
    local decoded
    pcall(function() decoded = HttpService:JSONDecode(res.Body) end)
    return decoded or {ok = false, error = "bad json"}
end

-- ============================================================
-- СЕССИЯ
-- ============================================================
_G.ManyHubSession = nil  -- nil = не активирован

local function isSessionValid()
    local s = _G.ManyHubSession
    if not s or not s.ok then return false end
    if s.full then return true end
    if s.expires_at and s.expires_at > 0 then
        return os.time() < s.expires_at
    end
    return true
end

-- ============================================================
-- РОЛИ MM2
-- ============================================================
local RoleCache = {}
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
-- ESP
-- ============================================================
local ESPCache = {}

local function removeESP(plr)
    local e = ESPCache[plr]
    if not e then return end
    pcall(function() if e.highlight then e.highlight:Destroy() end end)
    pcall(function() if e.billboard then e.billboard:Destroy() end end)
    ESPCache[plr] = nil
end

local function createESP(plr)
    if plr == LocalPlayer then return end
    removeESP(plr)
    local char = plr.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not hrp or not head then return end

    local role = RoleCache[plr] or "Innocent"
    local color = getRoleColor(role)
    local highlight, billboard, nameLbl, roleLbl, distLbl

    if CFG.espEnabled then
        highlight = Instance.new("Highlight")
        highlight.Name = "ManyHub_ESP"
        highlight.FillColor = color
        highlight.FillTransparency = 0.6
        highlight.OutlineColor = color
        highlight.Parent = char

        billboard = Instance.new("BillboardGui")
        billboard.Name = "ManyHub_BB"
        billboard.Size = UDim2.new(0, 160, 0, 60)
        billboard.StudsOffset = Vector3.new(0, 3.5, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = head

        local bg = Instance.new("Frame", billboard)
        bg.Size = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        bg.BackgroundTransparency = 0.7
        bg.BorderSizePixel = 0
        Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

        nameLbl = Instance.new("TextLabel", bg)
        nameLbl.Size = UDim2.new(1, -4, 0, 20)
        nameLbl.Position = UDim2.new(0, 2, 0, 2)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = plr.Name
        nameLbl.TextColor3 = color
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 13

        roleLbl = Instance.new("TextLabel", bg)
        roleLbl.Size = UDim2.new(1, -4, 0, 16)
        roleLbl.Position = UDim2.new(0, 2, 0, 22)
        roleLbl.BackgroundTransparency = 1
        roleLbl.Text = role
        roleLbl.TextColor3 = color
        roleLbl.Font = Enum.Font.GothamBold
        roleLbl.TextSize = 11

        distLbl = Instance.new("TextLabel", bg)
        distLbl.Size = UDim2.new(1, -4, 0, 14)
        distLbl.Position = UDim2.new(0, 2, 0, 38)
        distLbl.BackgroundTransparency = 1
        distLbl.Text = "dist: ?"
        distLbl.TextColor3 = Color3.fromRGB(200, 220, 255)
        distLbl.Font = Enum.Font.Gotham
        distLbl.TextSize = 10
    end

    ESPCache[plr] = {highlight=highlight, billboard=billboard, nameLbl=nameLbl, roleLbl=roleLbl, distLbl=distLbl}
end

local function updateESP()
    for plr, e in pairs(ESPCache) do
        if plr == LocalPlayer then continue end
        local char = plr.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            removeESP(plr); continue
        end
        local role = RoleCache[plr] or "Innocent"
        local color = getRoleColor(role)
        if CFG.espEnabled then
            if not e.highlight or not e.highlight.Parent then createESP(plr); continue end
            e.highlight.FillColor = color
            e.highlight.OutlineColor = color
            if e.nameLbl then e.nameLbl.TextColor3 = color end
            if e.roleLbl then e.roleLbl.Text = role; e.roleLbl.TextColor3 = color end
            if e.distLbl and CFG.espDistance then
                local dist = (Camera.CFrame.Position - char.HumanoidRootPart.Position).Magnitude
                e.distLbl.Text = string.format("dist: %d", math.floor(dist))
            end
        else
            if e.highlight then e.highlight:Destroy() end
            if e.billboard then e.billboard:Destroy() end
            ESPCache[plr] = {}
        end
    end
end

-- ============================================================
-- AIMBOT
-- ============================================================
local function isVisible(hrp)
    if not CFG.aimWallCheck then return true end
    local origin = Camera.CFrame.Position
    local ray = Ray.new(origin, hrp.Position - origin)
    local hit = Workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character}, false, true)
    return hit == nil or hit:IsDescendantOf(hrp.Parent)
end

local function getAimbotTarget()
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local best, bestDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local char = plr.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then continue end
        local role = RoleCache[plr] or "Innocent"
        if CFG.aimTargetRole ~= "All" and role ~= CFG.aimTargetRole then continue end
        local sp, on = Camera:WorldToViewportPoint(hrp.Position)
        if not on or sp.Z <= 0 then continue end
        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if d > CFG.aimFOV then continue end
        if not isVisible(hrp) then continue end
        if d < bestDist then bestDist = d; best = plr end
    end
    return best
end

local function doAimbot()
    if not CFG.aimbotEnabled then return end
    if not UserInputService:IsMouseButtonPressed(CFG.aimKey) then return end
    local target = getAimbotTarget()
    if not target then return end
    local char = target.Character
    local part = char and (char:FindFirstChild(CFG.aimPart) or char:FindFirstChild("HumanoidRootPart"))
    if not part then return end
    local desired = CFrame.new(Camera.CFrame.Position, part.Position)
    Camera.CFrame = Camera.CFrame:Lerp(desired, CFG.aimSmooth)
end

-- ============================================================
-- AUTO SHOOT
-- ============================================================
local autoShootTimer = 0
local function doAutoShoot(dt)
    if not CFG.autoShootEnabled then return end
    autoShootTimer = autoShootTimer + dt
    if autoShootTimer < CFG.autoShootDelay then return end
    autoShootTimer = 0
    local char = LocalPlayer.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool or tool.Name ~= "Gun" then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local role = RoleCache[plr] or "Innocent"
        if role ~= "Murderer" then continue end
        local tchar = plr.Character
        local thrp = tchar and tchar:FindFirstChild("HumanoidRootPart")
        if not thrp then continue end
        local dist = (char.HumanoidRootPart.Position - thrp.Position).Magnitude
        if dist > CFG.autoShootRange then continue end
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, thrp.Position)
        pcall(function() tool:Activate() end)
        break
    end
end

-- ============================================================
-- MOVEMENT
-- ============================================================
local bhopConn
local function startBHop()
    if bhopConn then bhopConn:Disconnect() end
    bhopConn = RunService.Heartbeat:Connect(function()
        if not CFG.bhopEnabled then return end
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local st = hum:GetState()
        if st == Enum.HumanoidStateType.Landed or st == Enum.HumanoidStateType.Running then
            hum.JumpPower = CFG.bhopJumpPower
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
end
local function stopBHop()
    if bhopConn then bhopConn:Disconnect(); bhopConn = nil end
end

local flyBV, flyBG
local function setFly(on)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if on then
        flyBV = Instance.new("BodyVelocity")
        flyBV.Name = "ManyHub_FlyBV"
        flyBV.MaxForce = Vector3.new(1e5,1e5,1e5)
        flyBV.Velocity = Vector3.zero
        flyBV.Parent = hrp
        flyBG = Instance.new("BodyGyro")
        flyBG.Name = "ManyHub_FlyBG"
        flyBG.MaxTorque = Vector3.new(1e5,1e5,1e5)
        flyBG.P = 1e4
        flyBG.Parent = hrp
    else
        if flyBV then flyBV:Destroy() end
        if flyBG then flyBG:Destroy() end
        flyBV, flyBG = nil, nil
    end
end

local function updateFly()
    if not CFG.flyEnabled or not flyBV or not flyBG then return end
    local move = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0,1,0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.new(0,1,0) end
    if move.Magnitude > 0 then move = move.Unit * CFG.flySpeed end
    flyBV.Velocity = move
    flyBG.CFrame = Camera.CFrame
end

local function updateNoclip()
    if not CFG.noclipEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
end

-- ============================================================
-- ГЛАВНЫЙ ЦИКЛ (с проверкой сессии)
-- ============================================================
RunService.RenderStepped:Connect(function(dt)
    if not isSessionValid() then return end
    updateRoles()
    updateESP()
    doAimbot()
    doAutoShoot(dt)
    updateFly()
    updateNoclip()
end)

-- ============================================================
-- РЕСПАВН
-- ============================================================
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    if not isSessionValid() then return end
    if CFG.noclipEnabled then updateNoclip() end
    if CFG.flyEnabled then setFly(true) end
end)

-- ============================================================
-- ESP НА НОВЫХ ИГРОКОВ
-- ============================================================
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function()
        task.wait(1)
        if CFG.espEnabled and isSessionValid() then createESP(plr) end
    end)
end)

for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then createESP(plr) end
end

-- ============================================================
-- GUI
-- ============================================================
local Window = Rayfield:CreateWindow({
    Name = "ManyHub · MM2",
    LoadingTitle = "ManyHub",
    LoadingSubtitle = "by pepa",
    Theme = "Default",
    DisableRayfieldPrompts = true,
    ConfigurationSaving = {Enabled = false},
    KeySystem = false,
})

-- ============================================================
-- ВКЛАДКА 1: KEY
-- ============================================================
local KeyTab = Window:CreateTab("Key", 4483362458)

local statusLabel = "Не активирован"

KeyTab:CreateParagraph({
    Title = "Статус ключа",
    Content = "Введи ключ и нажми АКТИВИРОВАТЬ",
})

local keyInput = KeyTab:CreateInput({
    Name = "Ключ",
    PlaceholderText = "AdminManyHub-HDFG6",
    RemoveTextAfterFocusLost = false,
    Flag = "keyInput",
    Callback = function(txt) end,
})

local statusDisplay = KeyTab:CreateLabel("Статус: не активирован")

KeyTab:CreateButton({
    Name = "АКТИВИРОВАТЬ",
    Callback = function()
        local key = (keyInput and keyInput:gsub("%s+", "")) or ""
        if key == "" then
            statusDisplay:Set("Статус: введи ключ")
            return
        end
        statusDisplay:Set("Статус: проверка...")

        task.spawn(function()
            local res = post("/api/activate", {key = key, hwid = HWID})
            task.wait(0.3)
            if res.ok then
                _G.ManyHubSession = res
                local tag = res.full and "FULL" or (res.name or "key")
                local exp = ""
                if res.expires_at and res.expires_at > 0 then
                    local days = math.floor((res.expires_at - os.time()) / 86400)
                    exp = string.format(" · %d дн.", days)
                end
                statusDisplay:Set("Статус: OK · " .. tag .. exp)
                Rayfield:Notify({
                    Title = "ManyHub",
                    Content = "Ключ принят: " .. tag,
                    Duration = 3,
                })
                -- включаем ESP если был выключен
                if not CFG.espEnabled then
                    CFG.espEnabled = true
                end
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer then createESP(plr) end
                end
            else
                _G.ManyHubSession = nil
                statusDisplay:Set("Статус: ошибка · " .. (res.error or "unknown"))
                Rayfield:Notify({
                    Title = "ManyHub",
                    Content = "Ключ отклонён: " .. (res.error or "unknown"),
                    Duration = 3,
                })
            end
        end)
    end,
})

KeyTab:CreateButton({
    Name = "Показать HWID",
    Callback = function()
        Rayfield:Notify({Title = "HWID", Content = HWID, Duration = 4})
    end,
})

-- ============================================================
-- ВКЛАДКА 2: ESP
-- ============================================================
local ESPTab = Window:CreateTab("ESP", 4483362458)

ESPTab:CreateToggle({
    Name = "ESP Enabled",
    CurrentValue = false,
    Flag = "espEnabled",
    Callback = function(v)
        CFG.espEnabled = v
        if v and isSessionValid() then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then createESP(plr) end
            end
        elseif not v then
            for plr in pairs(ESPCache) do removeESP(plr) end
        end
    end,
})

ESPTab:CreateToggle({
    Name = "Show Role",
    CurrentValue = true,
    Flag = "espRole",
    Callback = function(v) CFG.espRole = v end,
})

ESPTab:CreateToggle({
    Name = "Show Distance",
    CurrentValue = true,
    Flag = "espDistance",
    Callback = function(v) CFG.espDistance = v end,
})

-- ============================================================
-- ВКЛАДКА 3: AIMBOT
-- ============================================================
local AimTab = Window:CreateTab("Aimbot", 4483362458)

AimTab:CreateToggle({
    Name = "Aimbot Enabled",
    CurrentValue = false,
    Flag = "aimbotEnabled",
    Callback = function(v) CFG.aimbotEnabled = v end,
})

AimTab:CreateSlider({
    Name = "FOV", Range = {10, 360}, Increment = 5, Suffix = "°",
    CurrentValue = 120, Flag = "aimFOV",
    Callback = function(v) CFG.aimFOV = v end,
})

AimTab:CreateSlider({
    Name = "Smooth", Range = {0.05, 1.0}, Increment = 0.05, Suffix = "x",
    CurrentValue = 0.3, Flag = "aimSmooth",
    Callback = function(v) CFG.aimSmooth = v end,
})

AimTab:CreateDropdown({
    Name = "Target Part",
    Options = {"Head", "HumanoidRootPart", "UpperTorso"},
    CurrentOption = "Head", Flag = "aimPart",
    Callback = function(opt) CFG.aimPart = opt end,
})

AimTab:CreateDropdown({
    Name = "Target Role",
    Options = {"Murderer", "Sheriff", "All"},
    CurrentOption = "Murderer", Flag = "aimTargetRole",
    Callback = function(opt) CFG.aimTargetRole = opt end,
})

AimTab:CreateToggle({
    Name = "Wall Check",
    CurrentValue = true, Flag = "aimWallCheck",
    Callback = function(v) CFG.aimWallCheck = v end,
})

-- ============================================================
-- ВКЛАДКА 4: AUTO SHOOT
-- ============================================================
local ShootTab = Window:CreateTab("AutoShoot", 4483362458)

ShootTab:CreateToggle({
    Name = "Auto Shoot (Sheriff)",
    CurrentValue = false, Flag = "autoShootEnabled",
    Callback = function(v) CFG.autoShootEnabled = v end,
})

ShootTab:CreateSlider({
    Name = "Delay", Range = {0.05, 1.0}, Increment = 0.05, Suffix = "s",
    CurrentValue = 0.1, Flag = "autoShootDelay",
    Callback = function(v) CFG.autoShootDelay = v end,
})

ShootTab:CreateSlider({
    Name = "Range", Range = {50, 500}, Increment = 10, Suffix = " studs",
    CurrentValue = 200, Flag = "autoShootRange",
    Callback = function(v) CFG.autoShootRange = v end,
})

-- ============================================================
-- ВКЛАДКА 5: MOVEMENT
-- ============================================================
local MoveTab = Window:CreateTab("Movement", 4483362458)

MoveTab:CreateToggle({
    Name = "BHop", CurrentValue = false, Flag = "bhopEnabled",
    Callback = function(v)
        CFG.bhopEnabled = v
        if v then startBHop() else stopBHop() end
    end,
})

MoveTab:CreateSlider({
    Name = "Jump Power", Range = {30, 150}, Increment = 5,
    CurrentValue = 60, Flag = "bhopJumpPower",
    Callback = function(v) CFG.bhopJumpPower = v end,
})

MoveTab:CreateToggle({
    Name = "Fly", CurrentValue = false, Flag = "flyEnabled",
    Callback = function(v)
        CFG.flyEnabled = v
        setFly(v)
    end,
})

MoveTab:CreateSlider({
    Name = "Fly Speed", Range = {10, 200}, Increment = 5,
    CurrentValue = 50, Flag = "flySpeed",
    Callback = function(v) CFG.flySpeed = v end,
})

MoveTab:CreateToggle({
    Name = "Noclip", CurrentValue = false, Flag = "noclipEnabled",
    Callback = function(v) CFG.noclipEnabled = v end,
})

-- ============================================================
-- АВТО-ПРОВЕРКА МАСТЕР-КЛЮЧА (опционально)
-- ============================================================
-- Если хочешь, чтобы мастер-ключ активировался автоматом при запуске:
-- раскомментируй блок ниже и вставь свой мастер-ключ в MASTER_KEY.
--[[
task.spawn(function()
    local res = post("/api/activate", {key = MASTER_KEY, hwid = HWID})
    if res.ok then
        _G.ManyHubSession = res
        statusDisplay:Set("Статус: MASTER · full")
    end
end)
--]]

Rayfield:LoadConfiguration()
print("[ManyHub] Loaded. GUI ready. Session:", isSessionValid() and "valid" or "none")