--=====================================================================
--  XHub · 单文件整合版  Fly / AC-Bypass / ESP / Aimbot / 热键
--  用法: 整段 Execute。菜单键默认 RightShift / Insert / F2,点 ⌨ 可改
--=====================================================================
local CONFIG = {
    MenuKeys = { Enum.KeyCode.RightShift, Enum.KeyCode.Insert, Enum.KeyCode.F2 },
    FlyKey   = Enum.KeyCode.F,
    AimKey   = Enum.KeyCode.Q,
    Accent   = Color3.fromRGB(0, 200, 255),
    Enemy    = Color3.fromRGB(255, 70, 70),
    Mate     = Color3.fromRGB(90, 255, 120),
    AC = { Patterns = { "BS_", "最强防御", "Antikick", "AntiCheat", "Anti_Kick", "AC_" },
           Marker = "BS_Script_Running_Marker" },
}

local Players, RS = game:GetService("Players"), game:GetService("RunService")
local UIS, CoreGui = game:GetService("UserInputService"), game:GetService("CoreGui")
local RStorage, SC = game:GetService("ReplicatedStorage"), game:GetService("ScriptContext")
local lp, cam = Players.LocalPlayer, workspace.CurrentCamera

local S = {
    fly = false, flySpeed = 60,
    esp = false, espBox = true, espName = true, espHp = true, espDist = true,
    espTeam = false, espOccluded = true, espRainbow = false,
    aim = false, aimHold = true, aimSmooth = 10, aimFov = 140,
    aimPart = "Head", aimTeam = false, aimWall = true, showFov = true,
    ac = false,
}
local captureMode = false

local function mk(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end
local function charOf(p) local c = p and p.Character; if c and c.Parent then return c end end
local function humOf(p) local c = charOf(p); return c and c:FindFirstChildOfClass("Humanoid") end
local function alive(p) local h = humOf(p); return h ~= nil and h.Health > 0 end
local function isMate(p) return lp.Team ~= nil and p.Team == lp.Team end

local APARTS = { Head = {"Head"}, Root = {"HumanoidRootPart"}, Torso = {"UpperTorso","Torso","HumanoidRootPart"} }
local function aimPartOf(p)
    local c = charOf(p); if not c then return nil end
    for _, n in ipairs(APARTS[S.aimPart] or {"Head"}) do
        local v = c:FindFirstChild(n)
        if v and v:IsA("BasePart") then return v end
    end
end

local rp = RaycastParams.new()
pcall(function() rp.FilterType = Enum.RaycastFilterType.Exclude end)
if rp.FilterType ~= Enum.RaycastFilterType.Exclude then
    pcall(function() rp.FilterType = Enum.RaycastFilterType.Blacklist end)
end
rp.IgnoreWater = true
local function canSee(part)
    if not S.aimWall then return true end
    local o = cam.CFrame.Position
    rp.FilterDescendantsInstances = { lp.Character, part.Parent }
    local hit = workspace:Raycast(o, part.Position - o, rp)
    return hit == nil or hit.Instance:IsDescendantOf(part.Parent)
end

--==================== GUI 骨架 ====================
local gui = mk("ScreenGui", { Name = "XHub", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999 })
if not pcall(function() gui.Parent = CoreGui end) then
    gui.Parent = lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui")
end

local main = mk("Frame", { Name = "Main", Size = UDim2.fromOffset(540, 400),
    Position = UDim2.new(0.5, -270, 0.5, -200), BackgroundColor3 = Color3.fromRGB(20, 22, 28),
    BorderSizePixel = 0, Active = true }, gui)
mk("UICorner", { CornerRadius = UDim.new(0, 10) }, main)
mk("UIStroke", { Color = Color3.fromRGB(60, 66, 80), Thickness = 1 }, main)

local bar = mk("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Color3.fromRGB(26, 29, 37),
    BorderSizePixel = 0 }, main)
mk("UICorner", { CornerRadius = UDim.new(0, 10) }, bar)
mk("TextLabel", { Text = "XHub   universal", BackgroundTransparency = 1,
    TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 14, 0, 0),
    Size = UDim2.new(1, -60, 1, 0), Font = Enum.Font.GothamBold, TextSize = 14,
    TextColor3 = Color3.fromRGB(230, 236, 246) }, bar)
if pcall(function() return UIS.MouseIconEnabled end) then
    mk("TextLabel", { Text = CONFIG.MenuKeys[1].Name .. " 开关菜单", BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -50, 0, 0),
        Size = UDim2.new(0, 150, 1, 0), Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = Color3.fromRGB(120, 128, 145) }, bar)
end

--==================== 显示切换 + 悬浮按钮 + Toast ====================
local toast
local icon
local function setVisible(v)
    main.Visible = v
    if icon then
        icon.BackgroundColor3 = v and CONFIG.Accent or Color3.fromRGB(30, 34, 44)
    end
    if toast then
        toast.Text = v and "XHub · 已打开" or "XHub · 已关闭"
        toast.Visible = true
        task.delay(1.2, function() if toast then toast.Visible = false end end)
    end
end

do
    icon = mk("TextButton", { Name = "XHubIcon", Text = "X", Size = UDim2.fromOffset(36, 36),
        Position = UDim2.new(0, 10, 0.5, -20), BackgroundColor3 = CONFIG.Accent,
        TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 16,
        AutoButtonColor = false, ZIndex = 10 }, gui)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, icon)
    mk("UIStroke", { Color = CONFIG.Accent, Thickness = 1, Transparency = 0.4 }, icon)

    local keyBtn = mk("TextButton", { Name = "XHubKeyBtn", Text = "⌨", Size = UDim2.fromOffset(36, 30),
        Position = UDim2.new(0, 10, 0.5, 22), BackgroundColor3 = Color3.fromRGB(30, 34, 44),
        TextColor3 = Color3.fromRGB(200, 208, 220), Font = Enum.Font.GothamBold, TextSize = 16,
        AutoButtonColor = false, ZIndex = 10 }, gui)
    mk("UICorner", { CornerRadius = UDim.new(0, 8) }, keyBtn)

    toast = mk("TextLabel", { Name = "XHubToast", Text = "", Size = UDim2.fromOffset(220, 28),
        Position = UDim2.new(0.5, -110, 0, 52), BackgroundColor3 = Color3.fromRGB(20, 22, 28),
        BackgroundTransparency = 0.15, TextColor3 = Color3.fromRGB(230, 236, 246),
        Font = Enum.Font.GothamBold, TextSize = 13, Visible = false, ZIndex = 20 }, gui)
    mk("UICorner", { CornerRadius = UDim.new(0, 8) }, toast)

    icon.MouseButton1Click:Connect(function() setVisible(not main.Visible) end)
    keyBtn.MouseButton1Click:Connect(function()
        captureMode = true
        toast.Text = "按下新的菜单键（Esc 取消）"
        toast.Visible = true
    end)
end

local closeBtn = mk("TextButton", { Text = "×", BackgroundTransparency = 1, TextSize = 20,
    Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(150, 155, 170),
    Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -40, 0, 0) }, bar)
closeBtn.MouseButton1Click:Connect(function() setVisible(false) end)

do -- 拖动
    local dragging, dragStart, startPos = false, nil, nil
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging, dragStart, startPos = true, i.Position, main.Position
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                      startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
end

--==================== 页签 / 控件 ====================
local tabBar = mk("Frame", { Size = UDim2.new(0, 120, 1, -50), Position = UDim2.new(0, 10, 0, 46),
    BackgroundTransparency = 1 }, main)
mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, tabBar)
local content = mk("Frame", { Size = UDim2.new(1, -145, 1, -60), Position = UDim2.new(0, 135, 0, 46),
    BackgroundTransparency = 1, ClipsDescendants = true }, main)

local pages, tabBtns, lastOrder = {}, {}, 0
local function addPage(name)
    lastOrder = lastOrder + 1
    local btn = mk("TextButton", { Text = name, BackgroundColor3 = Color3.fromRGB(26, 29, 37),
        BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 34), AutoButtonColor = false, TextSize = 13,
        Font = Enum.Font.GothamMedium, TextColor3 = Color3.fromRGB(170, 176, 190),
        LayoutOrder = lastOrder }, tabBar)
    mk("UICorner", { CornerRadius = UDim.new(0, 7) }, btn)

    local page = mk("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = Color3.fromRGB(70, 76, 90),
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false }, content)
    mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, page)
    mk("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2) }, page)

    pages[name], tabBtns[name] = page, btn
    btn.MouseButton1Click:Connect(function()
        for n, p in pairs(pages) do
            p.Visible = (n == name)
            tabBtns[n].BackgroundColor3 = (n == name) and Color3.fromRGB(36, 40, 50) or Color3.fromRGB(26, 29, 37)
            tabBtns[n].TextColor3 = (n == name) and Color3.fromRGB(235, 240, 250) or Color3.fromRGB(170, 176, 190)
        end
    end)
    return page
end

local rowOrder = 0
local function addSection(page, text)
    rowOrder = rowOrder + 1
    return mk("TextLabel", { Text = text, BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 20),
        TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold, TextSize = 11,
        TextColor3 = CONFIG.Accent, LayoutOrder = rowOrder }, page)
end
local function addToggle(page, text, default, cb)
    rowOrder = rowOrder + 1
    local row = mk("TextButton", { Text = "", AutoButtonColor = false,
        BackgroundColor3 = Color3.fromRGB(26, 29, 37), BorderSizePixel = 0,
        Size = UDim2.new(1, -8, 0, 34), LayoutOrder = rowOrder }, page)
    mk("UICorner", { CornerRadius = UDim.new(0, 7) }, row)
    mk("TextLabel", { Text = text, BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -60, 1, 0),
        Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Color3.fromRGB(220, 226, 236) }, row)
    local pill = mk("Frame", { Size = UDim2.fromOffset(34, 18), Position = UDim2.new(1, -44, 0.5, -9),
        BackgroundColor3 = Color3.fromRGB(45, 50, 62), BorderSizePixel = 0 }, row)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, pill)
    local dot = mk("Frame", { Size = UDim2.fromOffset(14, 14), Position = UDim2.new(0, 2, 0.5, -7),
        BackgroundColor3 = Color3.fromRGB(150, 155, 170), BorderSizePixel = 0 }, pill)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
    local on = default
    local function paint()
        pill.BackgroundColor3 = on and CONFIG.Accent or Color3.fromRGB(45, 50, 62)
        dot.Position = on and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    end
    local function set(v) on = v; paint(); if cb then cb(v) end end
    row.MouseButton1Click:Connect(function() set(not on) end)
    paint(); if cb then cb(on) end
    return set
end
local function addSlider(page, text, mn, mx, default, cb)
    rowOrder = rowOrder + 1
    local row = mk("Frame", { BackgroundColor3 = Color3.fromRGB(26, 29, 37), BorderSizePixel = 0,
        Size = UDim2.new(1, -8, 0, 48), LayoutOrder = rowOrder }, page)
    mk("UICorner", { CornerRadius = UDim.new(0, 7) }, row)
    mk("TextLabel", { Text = text, BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 10, 0, 4), Size = UDim2.new(1, -70, 0, 16),
        Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Color3.fromRGB(220, 226, 236) }, row)
    local valueLbl = mk("TextLabel", { Text = "", BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -62, 0, 4),
        Size = UDim2.fromOffset(52, 16), Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = CONFIG.Accent }, row)
    local track = mk("Frame", { Size = UDim2.new(1, -20, 0, 6), Position = UDim2.new(0, 10, 0, 30),
        BackgroundColor3 = Color3.fromRGB(45, 50, 62), BorderSizePixel = 0 }, row)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
    local fill = mk("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = CONFIG.Accent,
        BorderSizePixel = 0 }, track)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
    local knob = mk("Frame", { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0 }, track)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
    local val, drag = default, false
    local function set(v)
        val = math.clamp(v, mn, mx)
        local a = (val - mn) / (mx - mn)
        fill.Size = UDim2.new(a, 0, 1, 0)
        knob.Position = UDim2.new(a, 0, 0.5, 0)
        valueLbl.Text = tostring(math.floor(val * 10 + 0.5) / 10)
        if cb then cb(val) end
    end
    local function fromX(x)
        set(mn + (mx - mn) * math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1))
    end
    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true; fromX(i.Position.X) end
    end)
    UIS.InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then fromX(i.Position.X) end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
    end)
    set(default)
    return set
end
local function addButton(page, text, cb)
    rowOrder = rowOrder + 1
    local btn = mk("TextButton", { Text = text, AutoButtonColor = false,
        BackgroundColor3 = Color3.fromRGB(30, 34, 44), BorderSizePixel = 0,
        Size = UDim2.new(1, -8, 0, 32), LayoutOrder = rowOrder, Font = Enum.Font.GothamMedium,
        TextSize = 13, TextColor3 = Color3.fromRGB(225, 231, 241) }, page)
    mk("UICorner", { CornerRadius = UDim.new(0, 7) }, btn)
    btn.MouseButton1Click:Connect(cb)
    return function(t) btn.Text = t end
end

--==================== 飞行 ====================
local flyBV
local function setFly(on)
    S.fly = on
    local c = charOf(lp); local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if on and hrp then
        if flyBV then flyBV:Destroy() end
        flyBV = mk("BodyVelocity", { Name = "XHubFly", MaxForce = Vector3.new(1e5, 1e5, 1e5),
            Velocity = Vector3.zero, P = 1250 }, hrp)
    else
        if flyBV then flyBV:Destroy(); flyBV = nil end
        local h = humOf(lp); if h then h.PlatformStand = false end
        cam.CameraType = Enum.CameraType.Custom
    end
end
RS.Heartbeat:Connect(function()
    if not S.fly then return end
    local c = charOf(lp); local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if not flyBV or flyBV.Parent ~= hrp then
        flyBV = mk("BodyVelocity", { Name = "XHubFly", MaxForce = Vector3.new(1e5, 1e5, 1e5),
            Velocity = Vector3.zero, P = 1250 }, hrp)
    end
    local cf = cam.CFrame; local dir = Vector3.zero
    if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.yAxis end
    if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.yAxis end
    flyBV.Velocity = (dir.Magnitude > 0) and (dir.Unit * S.flySpeed) or Vector3.zero
end)
lp.CharacterAdded:Connect(function() if S.fly then setFly(true) end end)

--==================== ESP ====================
local espStore = {}
local function hueColor() return Color3.fromHSV((tick() * 0.2) % 1, 0.85, 1) end
local function espColor(p)
    if S.espRainbow then return hueColor() end
    if lp.Team ~= nil and p.Team == lp.Team then return CONFIG.Mate end
    return CONFIG.Enemy
end
local function destroyESP(o)
    for _, v in pairs(o) do if typeof(v) == "Instance" then v:Destroy() end end
end
local function ensureESP(p)
    local c = charOf(p); if not c then return end
    local o = espStore[p]; if not o then o = {}; espStore[p] = o end
    if S.espBox then
        if not (o.hl and o.hl.Parent) then
            o.hl = mk("Highlight", { Name = "XHubHL", FillTransparency = 0.65,
                OutlineTransparency = 0.1, DepthMode = S.espOccluded and Enum.HighlightDepthMode.AlwaysOnTop
                or Enum.HighlightDepthMode.Occluded }, c)
        end
        o.hl.Parent = c
        o.hl.FillColor = espColor(p)
        o.hl.OutlineColor = Color3.new(1, 1, 1)
        o.hl.DepthMode = S.espOccluded and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
    elseif o.hl then
        o.hl:Destroy(); o.hl = nil
    end
    local head = c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart")
    if not head then return end
    if not (o.tag and o.tag.Parent) then
        o.tag = mk("BillboardGui", { Name = "XHubTag", Size = UDim2.fromOffset(190, 46),
            StudsOffset = Vector3.new(0, 2.4, 0), AlwaysOnTop = true, Adornee = head,
            LightInfluence = 0 }, head)
        o.nameLbl = mk("TextLabel", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16),
            Position = UDim2.new(0, 0, 0, 0), Font = Enum.Font.GothamBold, TextSize = 13,
            TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.4 }, o.tag)
        o.distLbl = mk("TextLabel", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14),
            Position = UDim2.new(0, 0, 0, 15), Font = Enum.Font.Gotham, TextSize = 11,
            TextColor3 = Color3.fromRGB(210, 215, 225), TextStrokeTransparency = 0.5 }, o.tag)
        o.hpBg = mk("Frame", { Size = UDim2.fromOffset(60, 4), Position = UDim2.new(0.5, -30, 1, -10),
            BackgroundColor3 = Color3.fromRGB(20, 20, 20), BorderSizePixel = 0 }, o.tag)
        o.hpFill = mk("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(80, 220, 120),
            BorderSizePixel = 0 }, o.hpBg)
    end
    o.tag.Adornee = head; o.tag.Parent = head
    local h = humOf(p)
    o.nameLbl.Text = p.Name
    o.nameLbl.TextColor3 = S.espName and espColor(p) or Color3.new(1, 1, 1)
    o.nameLbl.Visible = S.espName
    o.distLbl.Visible = S.espDist
    if S.espDist then
        local myC = charOf(lp); local myHrp = myC and myC:FindFirstChild("HumanoidRootPart")
        if myHrp then o.distLbl.Text = math.floor((head.Position - myHrp.Position).Magnitude) .. " m" end
    end
    o.hpBg.Visible = S.espHp
    if h then
        local r = math.clamp(h.Health / math.max(h.MaxHealth, 1), 0, 1)
        o.hpFill.Size = UDim2.new(r, 0, 1, 0)
        o.hpFill.BackgroundColor3 = Color3.fromRGB(math.floor(255 * (1 - r)), math.floor(220 * r), 60)
    end
end
task.spawn(function()
    while true do
        task.wait(0.1)
        if S.esp then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= lp and alive(p) and (S.espTeam or not isMate(p)) then ensureESP(p) end
            end
            local dead = {}
            for p, o in pairs(espStore) do
                if not alive(p) or (isMate(p) and not S.espTeam) or p.Parent == nil then
                    destroyESP(o); dead[#dead + 1] = p
                end
            end
            for _, p in ipairs(dead) do espStore[p] = nil end
        else
            for _, o in pairs(espStore) do destroyESP(o) end
            espStore = {}
        end
    end
end)
Players.PlayerRemoving:Connect(function(p)
    if espStore[p] then destroyESP(espStore[p]); espStore[p] = nil end
end)

--==================== 自瞄 ====================
local fovGui
if Drawing then
    local ok, c = pcall(function()
        local o = Drawing.new("Circle")
        o.Thickness, o.NumSides, o.Filled, o.Color = 1.5, 64, false, CONFIG.Accent
        return o
    end)
    if ok then fovGui = c end
end
if not fovGui then
    fovGui = mk("Frame", { Name = "XHubFov", BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(280, 280), Visible = false }, gui)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, fovGui)
    mk("UIStroke", { Color = CONFIG.Accent, Thickness = 1, Transparency = 0.3 }, fovGui)
end
local function findTarget()
    local vp = cam.ViewportSize
    local center = Vector2.new(vp.X / 2, vp.Y / 2)
    local best, bestD = nil, S.aimFov
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp and alive(p) and (S.aimTeam or not isMate(p)) then
            local part = aimPartOf(p)
            if part then
                local sp, onScreen = cam:WorldToViewportPoint(part.Position)
                if onScreen then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if d < bestD and canSee(part) then best, bestD = part, d end
                end
            end
        end
    end
    return best
end
pcall(function() RS:UnbindFromRenderStep("XHubAim") end)
RS:BindToRenderStep("XHubAim", Enum.RenderPriority.Camera.Value + 1, function(dt)
    local want = false
    if S.aim then
        if S.aimHold then want = UIS:IsKeyDown(CONFIG.AimKey) else want = true end
    end
    if fovGui then
        fovGui.Visible = (S.aim and S.showFov)
        if fovGui.Visible then
            local vp = cam.ViewportSize
            if Drawing then
                fovGui.Position = Vector2.new(vp.X / 2, vp.Y / 2)
                fovGui.Radius = S.aimFov
            else
                fovGui.Position = UDim2.fromOffset(vp.X / 2, vp.Y / 2)
                fovGui.Size = UDim2.fromOffset(S.aimFov * 2, S.aimFov * 2)
            end
        end
    end
    if not want then return end
    local t = findTarget(); if not t then return end
    if cam.CameraType ~= Enum.CameraType.Custom then cam.CameraType = Enum.CameraType.Custom end
    local cur = cam.CFrame
    local goal = CFrame.lookAt(cur.Position, t.Position)
    local alpha = 1 - math.exp(-math.max(S.aimSmooth, 0.5) * dt)
    cam.CFrame = cur:Lerp(goal, math.clamp(alpha, 0.02, 1))
end)

--==================== 反作弊压制 ====================
local AC = { origNamecall = nil, marker = nil, guard = false }
local function acIs(s)
    if type(s) ~= "string" or s == "" then return false end
    for _, k in ipairs(CONFIG.AC.Patterns) do if s:find(k, 1, true) then return true end end
    return false
end
local function nm(inst) local ok, v = pcall(function() return inst.Name end); return ok and v or "" end
local function acSrc(fn) local ok, v = pcall(function() return debug.info(fn, "s") end); return ok and v or "" end
local function acCaller()
    local cs = getcallingscript and getcallingscript()
    if cs ~= nil then return nm(cs) end
    local ok, v = pcall(function() return debug.info(2, "s") end); return ok and v or ""
end
local function acRun()
    local t, c, f = 0, 0, false
    if getreg and coroutine and coroutine.close then
        for _, v in pairs(getreg()) do
            if type(v) == "thread" then
                local ok, src = pcall(function() return debug.info(v, "s") end)
                if ok and acIs(src) and pcall(coroutine.close, v) then t = t + 1 end
            end
        end
    end
    if getconnections then
        local sigs = {}
        for _, n in ipairs({ "Heartbeat", "RenderStepped", "PreRender", "Stepped",
                             "PreSimulation", "PostSimulation" }) do
            local ok, sig = pcall(function() return RS[n] end)
            if ok and sig then sigs[#sigs + 1] = sig end
        end
        sigs[#sigs + 1] = SC.Error
        for _, sig in ipairs(sigs) do
            local ok, conns = pcall(getconnections, sig)
            if ok and conns then
                for _, k in ipairs(conns) do
                    local sn = nm((function() local o, v = pcall(function() return k.Script end)
                        return o and v or nil end)())
                    if acIs(sn) or acIs(acSrc(k.Function)) then
                        pcall(function() k:Disable() end)
                        pcall(function() k:Disconnect() end)
                        c = c + 1
                    end
                end
            end
        end
    end
    if getrawmetatable and getnamecallmethod and checkcaller and not AC.origNamecall then
        local mt = getrawmetatable(game)
        if mt and mt.__namecall then
            if setreadonly then pcall(setreadonly, mt, false) end
            AC.origNamecall = mt.__namecall
            local wrap = newcclosure or function(x) return x end
            mt.__namecall = wrap(function(self, ...)
                local m = getnamecallmethod()
                if not checkcaller() and acIs(acCaller()) then
                    if m == "Connect" or m == "ConnectParallel" or m == "Once" then
                        return AC.origNamecall(self, function() end)
                    elseif m == "FireServer" or m == "InvokeServer" or m == "Fire" then
                        return nil
                    end
                end
                return AC.origNamecall(self, ...)
            end)
            if setreadonly then pcall(setreadonly, mt, true) end
            f = true
        end
    end
    local mcount = 0
    local mk2 = RStorage:FindFirstChild(CONFIG.AC.Marker)
    if mk2 then
        AC.marker = mk2
        for _, sig in ipairs({ mk2.Changed, mk2:GetPropertyChangedSignal("Value") }) do
            local ok, conns = pcall(getconnections, sig)
            if ok and conns then
                for _, k in ipairs(conns) do
                    pcall(function() k:Disable() end); pcall(function() k:Disconnect() end)
                    mcount = mcount + 1
                end
            end
        end
        pcall(function() mk2.Value = false end)
        if not AC.guard then
            AC.guard = true
            task.spawn(function()
                while AC.marker and AC.marker.Parent do
                    if AC.marker.Value ~= false then pcall(function() AC.marker.Value = false end) end
                    task.wait(0.5)
                end
            end)
        end
    end
    local msg = ("线程 %d / 连接 %d / 防火墙 %s / marker %d")
        :format(t, c, f and "on" or "off", mcount)
    print("[XHub-AC]", msg)
    return msg
end

--==================== 页面内容 ====================
local pMain, pVisual   = addPage("主要"), addPage("视觉")
local pCombat, pBypass = addPage("战斗"), addPage("绕过")

addSection(pMain, "MOVEMENT")
addToggle(pMain, "飞行 (F)", false, function(v) setFly(v) end)
addSlider(pMain, "飞行速度", 10, 300, S.flySpeed, function(v) S.flySpeed = v end)
addSection(pMain, "HUB")
local setKeyBtn = addButton(pMain, "菜单键: " .. CONFIG.MenuKeys[1].Name .. " (点我改键)", function()
    captureMode = true
    setKeyBtn("菜单键: 请按键…（Esc 取消）")
end)
addButton(pMain, "隐藏菜单", function() setVisible(false) end)

addSection(pVisual, "ESP")
addToggle(pVisual, "启用 ESP", false, function(v) S.esp = v end)
addToggle(pVisual, "方框高亮", true, function(v) S.espBox = v end)
addToggle(pVisual, "名字", true, function(v) S.espName = v end)
addToggle(pVisual, "血量条", true, function(v) S.espHp = v end)
addToggle(pVisual, "距离", true, function(v) S.espDist = v end)
addToggle(pVisual, "显示队友", false, function(v) S.espTeam = v end)
addToggle(pVisual, "穿墙可见", true, function(v) S.espOccluded = v end)
addToggle(pVisual, "彩虹上色", false, function(v) S.espRainbow = v end)

addSection(pCombat, "AIMBOT")
addToggle(pCombat, "启用自瞄", false, function(v) S.aim = v end)
addToggle(pCombat, "按住 Q 瞄准 (关=常开)", true, function(v) S.aimHold = v end)
addToggle(pCombat, "瞄准队友", false, function(v) S.aimTeam = v end)
addToggle(pCombat, "隔墙忽略", true, function(v) S.aimWall = v end)
addToggle(pCombat, "显示 FOV", true, function(v) S.showFov = v end)
addSlider(pCombat, "平滑", 1, 30, S.aimSmooth, function(v) S.aimSmooth = v end)
addSlider(pCombat, "FOV 像素", 20, 400, S.aimFov, function(v) S.aimFov = v end)
local setPartBtn = addButton(pCombat, "部位: Head", function()
    local list = { "Head", "Root", "Torso" }
    local i = 1
    for k, v in ipairs(list) do if v == S.aimPart then i = k end end
    S.aimPart = list[(i % #list) + 1]
    setPartBtn("部位: " .. S.aimPart)
end)

addSection(pBypass, "ANTI-CHEAT")
addToggle(pBypass, "启用压制 (先开这个)", false, function(v)
    S.ac = v
    if v then acRun() end
    if not v and AC.origNamecall and getrawmetatable then
        local mt = getrawmetatable(game)
        if mt then
            if setreadonly then pcall(setreadonly, mt, false) end
            mt.__namecall = AC.origNamecall
            if setreadonly then pcall(setreadonly, mt, true) end
            AC.origNamecall = nil
        end
    end
end)
addButton(pBypass, "重新压制", function() acRun() end)
addButton(pBypass, "卸载并恢复", function()
    setFly(false); S.esp = false; S.aim = false
    if AC.origNamecall and getrawmetatable then
        local mt = getrawmetatable(game)
        if mt then mt.__namecall = AC.origNamecall; AC.origNamecall = nil end
    end
    for _, o in pairs(espStore) do destroyESP(o) end
    espStore = {}
    gui:Destroy()
end)

pcall(function() tabBtns["主要"]:Fire("MouseButton1Click") end)

--==================== 热键 ====================
local function isMenuKey(code)
    for _, k in ipairs(CONFIG.MenuKeys) do if k == code then return true end end
    return false
end
UIS.InputBegan:Connect(function(i, gp)
    if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if UIS:GetFocusedTextBox() then captureMode = false; return end

    if captureMode then
        captureMode = false
        if i.KeyCode == Enum.KeyCode.Escape then
            toast.Text = "改键已取消"
        else
            CONFIG.MenuKeys = { i.KeyCode }
            toast.Text = "菜单键 = " .. i.KeyCode.Name
            setKeyBtn("菜单键: " .. i.KeyCode.Name .. " (点我改键)")
            print("[XHub] menu key -> " .. i.KeyCode.Name)
        end
        toast.Visible = true
        task.delay(1.2, function() if toast then toast.Visible = false end end)
        return
    end

    if isMenuKey(i.KeyCode) then
        setVisible(not main.Visible)
    elseif i.KeyCode == CONFIG.FlyKey and not gp then
        setFly(not S.fly)
        toast.Text = "飞行: " .. (S.fly and "开" or "关")
        toast.Visible = true
        task.delay(1.0, function() if toast then toast.Visible = false end end)
    end
end)

toast.Text = "XHub 就绪 · " .. CONFIG.MenuKeys[1].Name .. " 开关菜单"
toast.Visible = true
task.delay(2, function() if toast then toast.Visible = false end end)
print("[XHub] loaded · 菜单键 " .. CONFIG.MenuKeys[1].Name .. " / F 飞行 / Q 瞄准")
