-- ManyHub_MM2.lua · Lua · Custom UI · MM2 Client-Side
-- Финальная сборка (Mobile Fix): Custom UI + Key System + Admin Panel + Modules.

local MASTER_KEY = "AdminManyHub-HDFG6"
local SERVER = "https://manyhub-production.up.railway.app" -- Твой сервер Railway
local ADMIN_TOKEN = "CHANGE_ME_ADMIN_TOKEN_123"    -- Должен совпадать с keyserver.py
local HWID = tostring(game:GetService("Players").LocalPlayer.UserId)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local CFG = {
    espEnabled = false, espRole = true, espDistance = true,
    aimbotEnabled = false, aimKey = Enum.UserInputType.MouseButton2,
    aimFOV = 120, aimSmooth = 0.3, aimPart = "Head", aimWallCheck = true, aimTargetRole = "Murderer",
    autoShootEnabled = false, autoShootDelay = 0.1, autoShootRange = 200,
    bhopEnabled = false, bhopJumpPower = 60, flyEnabled = false, flySpeed = 50, noclipEnabled = false,
    walkSpeed = 16, antiAfk = true,
}

local RoleCache, ESPCache = {}, {}
local flyBV, flyBG, bhopConn
local isMaster = false

-- ============================================================
-- ЛОГИКА МОДУЛЕЙ
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
        highlight.Name = "ManyHub_ESP"; highlight.FillColor = color; highlight.FillTransparency = 0.6
        highlight.OutlineColor = color; highlight.Parent = char

        billboard = Instance.new("BillboardGui")
        billboard.Name = "ManyHub_BB"; billboard.Size = UDim2.new(0, 160, 0, 60)
        billboard.StudsOffset = Vector3.new(0, 3.5, 0); billboard.AlwaysOnTop = true; billboard.Parent = head

        local bg = Instance.new("Frame", billboard)
        bg.Size = UDim2.new(1, 0, 1, 0); bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        bg.BackgroundTransparency = 0.7; bg.BorderSizePixel = 0
        Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

        nameLbl = Instance.new("TextLabel", bg); nameLbl.Size = UDim2.new(1, -4, 0, 20)
        nameLbl.Position = UDim2.new(0, 2, 0, 2); nameLbl.BackgroundTransparency = 1
        nameLbl.Text = plr.Name; nameLbl.TextColor3 = color; nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 13

        roleLbl = Instance.new("TextLabel", bg); roleLbl.Size = UDim2.new(1, -4, 0, 16)
        roleLbl.Position = UDim2.new(0, 2, 0, 22); roleLbl.BackgroundTransparency = 1
        roleLbl.Text = role; roleLbl.TextColor3 = color; roleLbl.Font = Enum.Font.GothamBold; roleLbl.TextSize = 11

        distLbl = Instance.new("TextLabel", bg); distLbl.Size = UDim2.new(1, -4, 0, 14)
        distLbl.Position = UDim2.new(0, 2, 0, 38); distLbl.BackgroundTransparency = 1
        distLbl.Text = "dist: ?"; distLbl.TextColor3 = Color3.fromRGB(200, 220, 255)
        distLbl.Font = Enum.Font.Gotham; distLbl.TextSize = 10
    end
    ESPCache[plr] = {highlight=highlight, billboard=billboard, nameLbl=nameLbl, roleLbl=roleLbl, distLbl=distLbl}
end

local function updateESP()
    for plr, e in pairs(ESPCache) do
        if plr == LocalPlayer then continue end
        local char = plr.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then removeESP(plr); continue end
        local role = RoleCache[plr] or "Innocent"
        local color = getRoleColor(role)
        if CFG.espEnabled then
            if not e.highlight or not e.highlight.Parent then createESP(plr); continue end
            e.highlight.FillColor = color; e.highlight.OutlineColor = color
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

local function doAimbot()
    if not CFG.aimbotEnabled then return end
    if not UserInputService:IsMouseButtonPressed(CFG.aimKey) then return end
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
        if CFG.aimWallCheck then
            local ray = Ray.new(Camera.CFrame.Position, hrp.Position - Camera.CFrame.Position)
            local hit = Workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character}, false, true)
            if hit and not hit:IsDescendantOf(hrp.Parent) then continue end
        end
        if d < bestDist then bestDist = d; best = plr end
    end
    if best then
        local part = best.Character:FindFirstChild(CFG.aimPart) or best.Character:FindFirstChild("HumanoidRootPart")
        if part then
            local desired = CFrame.new(Camera.CFrame.Position, part.Position)
            Camera.CFrame = Camera.CFrame:Lerp(desired, CFG.aimSmooth)
        end
    end
end

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
        if (char.HumanoidRootPart.Position - thrp.Position).Magnitude > CFG.autoShootRange then continue end
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, thrp.Position)
        pcall(function() tool:Activate() end)
        break
    end
end

local function updateMovement()
    if CFG.flyEnabled then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            if not flyBV then
                flyBV = Instance.new("BodyVelocity", hrp); flyBV.MaxForce = Vector3.new(1e5,1e5,1e5); flyBV.Velocity = Vector3.zero
                flyBG = Instance.new("BodyGyro", hrp); flyBG.MaxTorque = Vector3.new(1e5,1e5,1e5); flyBG.P = 1e4
            end
            local move = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0,1,0) end
            if move.Magnitude > 0 then move = move.Unit * CFG.flySpeed end
            flyBV.Velocity = move; flyBG.CFrame = Camera.CFrame
        end
    else
        if flyBV then flyBV:Destroy(); flyBV = nil end
        if flyBG then flyBG:Destroy(); flyBG = nil end
    end

    if CFG.noclipEnabled then
        local char = LocalPlayer.Character
        if char then for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end
    end

    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum and hum.WalkSpeed ~= CFG.walkSpeed then hum.WalkSpeed = CFG.walkSpeed end
end

-- ============================================================
-- GUI (С ИСПРАВЛЕННЫМ PARENT)
-- ============================================================
local function initCustomGUI()
    -- Надежно ищем родителя
    local parent = LocalPlayer:WaitForChild("PlayerGui")
    pcall(function()
        if gethui then parent = gethui() end
    end)

    -- Создаем единый ScreenGui для всего
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ManyHub_UI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = parent

    -- Кнопка MH
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 70, 0, 40); toggleBtn.Position = UDim2.new(1, -90, 0.5, -20)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(35, 20, 45); toggleBtn.Text = "MH"
    toggleBtn.TextColor3 = Color3.fromRGB(180, 80, 255); toggleBtn.Font = Enum.Font.GothamBlack; toggleBtn.TextSize = 18
    toggleBtn.Parent = screenGui
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)
    local s1 = Instance.new("UIStroke", toggleBtn); s1.Color = Color3.fromRGB(180, 80, 255); s1.Thickness = 2

    -- Меню
    local menu = Instance.new("Frame")
    menu.Size = UDim2.new(0, 350, 0, 450)
    menu.Position = UDim2.new(0.5, -175, 0.5, -225)
    menu.BackgroundColor3 = Color3.fromRGB(20, 10, 30)
    menu.BorderSizePixel = 0; menu.Active = true; menu.Draggable = true; menu.Visible = false
    menu.Parent = screenGui
    Instance.new("UICorner", menu).CornerRadius = UDim.new(0, 10)
    local s2 = Instance.new("UIStroke", menu); s2.Color = Color3.fromRGB(180, 80, 255); s2.Thickness = 2

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40); title.BackgroundColor3 = Color3.fromRGB(35, 20, 45)
    title.Text = "ManyHub · MM2"; title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold; title.TextSize = 16; title.Parent = menu
    Instance.new("UICorner", title).CornerRadius = UDim.new(0, 10)

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30); closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50); closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255); closeBtn.Font = Enum.Font.GothamBold; closeBtn.Parent = title
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

    local uiOpen = false
    toggleBtn.MouseButton1Click:Connect(function() uiOpen = not uiOpen; menu.Visible = uiOpen end)
    closeBtn.MouseButton1Click:Connect(function() uiOpen = false; menu.Visible = false end)

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(1, -20, 1, -60); mainFrame.Position = UDim2.new(0, 10, 0, 50)
    mainFrame.BackgroundTransparency = 1; mainFrame.Parent = menu

    local yOffset = 0
    local function addToggle(text, initial, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 35); btn.Position = UDim2.new(0, 0, 0, yOffset)
        btn.BackgroundColor3 = Color3.fromRGB(40, 25, 55); btn.Text = text .. ": " .. (initial and "ON" or "OFF")
        btn.TextColor3 = Color3.fromRGB(255, 255, 255); btn.Font = Enum.Font.Gotham; btn.TextSize = 14; btn.Parent = mainFrame
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        local state = initial
        btn.MouseButton1Click:Connect(function()
            state = not state
            btn.Text = text .. ": " .. (state and "ON" or "OFF")
            btn.BackgroundColor3 = state and Color3.fromRGB(60, 30, 80) or Color3.fromRGB(40, 25, 55)
            callback(state)
        end)
        yOffset = yOffset + 45
    end

    addToggle("ESP Enabled", CFG.espEnabled, function(v) 
        CFG.espEnabled = v
        if v then for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then createESP(p) end end
        else for p in pairs(ESPCache) do removeESP(p) end end
    end)
    addToggle("Aimbot (RMB)", CFG.aimbotEnabled, function(v) CFG.aimbotEnabled = v end)
    addToggle("Fly", CFG.flyEnabled, function(v) CFG.flyEnabled = v end)
    addToggle("Noclip", CFG.noclipEnabled, function(v) CFG.noclipEnabled = v end)
    addToggle("BHop", CFG.bhopEnabled, function(v)
        CFG.bhopEnabled = v
        if v then
            if bhopConn then bhopConn:Disconnect() end
            bhopConn = RunService.Heartbeat:Connect(function()
                if CFG.bhopEnabled and LocalPlayer.Character then
                    local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                    if hum and (hum:GetState() == Enum.HumanoidStateType.Landed or hum:GetState() == Enum.HumanoidStateType.Running) then
                        hum:ChangeState(Enum.HumanoidStateType.Jumping)
                    end
                end
            end)
        else if bhopConn then bhopConn:Disconnect(); bhopConn = nil end end
    end)
    addToggle("Anti-AFK", CFG.antiAfk, function(v) CFG.antiAfk = v end)
    
    if isMaster then
        yOffset = yOffset + 10
        local adminLabel = Instance.new("TextLabel")
        adminLabel.Size = UDim2.new(1, 0, 0, 20); adminLabel.Position = UDim2.new(0, 0, 0, yOffset)
        adminLabel.BackgroundTransparency = 1; adminLabel.Text = "--- ADMIN PANEL ---"
        adminLabel.TextColor3 = Color3.fromRGB(255, 200, 0); adminLabel.Font = Enum.Font.GothamBold; adminLabel.TextSize = 12
        adminLabel.Parent = mainFrame
        yOffset = yOffset + 25

        local nameBox = Instance.new("TextBox")
        nameBox.Size = UDim2.new(1, 0, 0, 35); nameBox.Position = UDim2.new(0, 0, 0, yOffset)
        nameBox.BackgroundColor3 = Color3.fromRGB(40, 25, 55); nameBox.Text = ""; nameBox.PlaceholderText = "Имя ключа (напр. VIP)"
        nameBox.PlaceholderColor3 = Color3.fromRGB(120, 80, 150); nameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameBox.Font = Enum.Font.Gotham; nameBox.TextSize = 14; nameBox.Parent = mainFrame
        Instance.new("UICorner", nameBox).CornerRadius = UDim.new(0, 6)
        yOffset = yOffset + 45

        local genBtn = Instance.new("TextButton")
        genBtn.Size = UDim2.new(1, 0, 0, 35); genBtn.Position = UDim2.new(0, 0, 0, yOffset)
        genBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 200); genBtn.Text = "СОЗДАТЬ КЛЮЧ НА СЕРВЕРЕ"
        genBtn.TextColor3 = Color3.fromRGB(255, 255, 255); genBtn.Font = Enum.Font.GothamBold; genBtn.TextSize = 14
        genBtn.Parent = mainFrame; Instance.new("UICorner", genBtn).CornerRadius = UDim.new(0, 6)
        
        local resultLbl = Instance.new("TextLabel")
        resultLbl.Size = UDim2.new(1, 0, 0, 20); resultLbl.Position = UDim2.new(0, 0, 0, yOffset + 40)
        resultLbl.BackgroundTransparency = 1; resultLbl.Text = ""; resultLbl.TextColor3 = Color3.fromRGB(0, 255, 100)
        resultLbl.Font = Enum.Font.Gotham; resultLbl.TextSize = 12; resultLbl.Parent = mainFrame

        genBtn.MouseButton1Click:Connect(function()
            local name = nameBox.Text:gsub("%s+", "")
            if name == "" then name = "KEY" end
            
            genBtn.Text = "ГЕНЕРАЦИЯ..."
            task.spawn(function()
                local req = syn and syn.request or request or http_request
                if not req then
                    resultLbl.Text = "Нет HTTP запросов"
                    genBtn.Text = "СОЗДАТЬ КЛЮЧ НА СЕРВЕРЕ"
                    return
                end
                
                local ok, res = pcall(function()
                    return req({
                        Url = SERVER .. "/api/admin/create", 
                        Method = "POST",
                        Headers = {
                            ["Content-Type"] = "application/json",
                            ["X-Admin-Token"] = ADMIN_TOKEN
                        },
                        Body = HttpService:JSONEncode({name = name, days = 30, max_activations = 1}),
                    })
                end)
                
                if ok and res and res.StatusCode == 200 then
                    local data = HttpService:JSONDecode(res.Body)
                    if data.ok then
                        resultLbl.Text = "Ключ: " .. data.key
                        resultLbl.TextColor3 = Color3.fromRGB(0, 255, 100)
                    else
                        resultLbl.Text = "Ошибка: " .. (data.error or "unknown")
                        resultLbl.TextColor3 = Color3.fromRGB(255, 80, 80)
                    end
                else
                    resultLbl.Text = "Ошибка сети"
                    resultLbl.TextColor3 = Color3.fromRGB(255, 80, 80)
                end
                genBtn.Text = "СОЗДАТЬ КЛЮЧ НА СЕРВЕРЕ"
            end)
        end)
    end

    RunService.RenderStepped:Connect(function(dt)
        updateRoles()
        updateESP()
        doAimbot()
        doAutoShoot(dt)
        updateMovement()
        
        if CFG.antiAfk then
            pcall(function() game:GetService("VirtualUser"):CaptureController() end)
            pcall(function() game:GetService("VirtualUser"):ClickButton2(Vector2.new()) end)
        end
    end)
end

-- ============================================================
-- KEY SYSTEM UI
-- ============================================================
local function showKeyUI(onSuccess)
    local parent = LocalPlayer:WaitForChild("PlayerGui")
    pcall(function() if gethui then parent = gethui() end end)

    local screen = Instance.new("ScreenGui")
    screen.Name = "ManyHubKeyUI"; screen.ResetOnSpawn = false; screen.Parent = parent

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 320, 0, 220); frame.Position = UDim2.new(0.5, -160, 0.5, -110)
    frame.BackgroundColor3 = Color3.fromRGB(25, 15, 35); frame.BorderSizePixel = 0; frame.Active = true; frame.Draggable = true; frame.Parent = screen
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new("UIStroke", frame); stroke.Color = Color3.fromRGB(180, 80, 255); stroke.Thickness = 2

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40); title.BackgroundTransparency = 1
    title.Text = "ManyHub · Key System"; title.TextColor3 = Color3.fromRGB(180, 80, 255)
    title.Font = Enum.Font.GothamBold; title.TextSize = 18; title.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -40, 0, 45); box.Position = UDim2.new(0, 20, 0, 60)
    box.BackgroundColor3 = Color3.fromRGB(40, 25, 55); box.Text = ""; box.PlaceholderText = "KEY"
    box.PlaceholderColor3 = Color3.fromRGB(120, 80, 150); box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.Font = Enum.Font.Gotham; box.TextSize = 16; box.Parent = frame
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -40, 0, 45); btn.Position = UDim2.new(0, 20, 0, 120)
    btn.BackgroundColor3 = Color3.fromRGB(120, 40, 200); btn.Text = "АКТИВИРОВАТЬ"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255); btn.Font = Enum.Font.GothamBold; btn.TextSize = 16
    btn.Parent = frame; Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -40, 0, 30); status.Position = UDim2.new(0, 20, 0, 175)
    status.BackgroundTransparency = 1; status.Text = ""; status.TextColor3 = Color3.fromRGB(255, 200, 0)
    status.Font = Enum.Font.Gotham; status.TextSize = 14; status.Parent = frame

    btn.MouseButton1Click:Connect(function()
        local key = box.Text:gsub("%s+", "")
        if key == "" then status.Text = "Введи ключ"; return end
        
        if key == MASTER_KEY then
            isMaster = true
            status.Text = "MASTER KEY OK"; status.TextColor3 = Color3.fromRGB(0, 255, 100)
            task.wait(0.5); screen:Destroy(); onSuccess()
            return
        end

        status.Text = "Проверка..."
        task.spawn(function()
            local req = syn and syn.request or request or http_request
            if not req then status.Text = "Нет HTTP"; return end
            
            local ok, res = pcall(function()
                return req({
                    Url = SERVER .. "/api/activate", Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = HttpService:JSONEncode({key = key, hwid = HWID}),
                })
            end)
            
            if ok and res and res.StatusCode == 200 then
                local data = HttpService:JSONDecode(res.Body)
                if data.ok then
                    status.Text = "OK · " .. (data.name or "VIP")
                    status.TextColor3 = Color3.fromRGB(0, 255, 100)
                    task.wait(0.5); screen:Destroy(); onSuccess()
                else
                    status.Text = "Неверный ключ"
                    status.TextColor3 = Color3.fromRGB(255, 80, 80)
                end
            else
                -- Если сервер вернул 404 или 403, скрипт тоже считает это неверным ключом
                status.Text = "Неверный ключ или сервер лежит"
                status.TextColor3 = Color3.fromRGB(255, 80, 80)
            end
        end)
    end)
end

showKeyUI(function() initCustomGUI() end)
