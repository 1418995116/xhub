--=====================================================================
--  XHub v4.1 · Fly / ESP / Aimbot / AC压制 / AC-Guard / ThreadCleaner
--  菜单键 RightShift/Insert/F2 · F 飞行 · Q 瞄准 · 右上角通知
--  v4.1: 检测层改为“只动 AC 自己的渲染/心跳回调”,不再全量挂钩,并带输入自动回滚
--=====================================================================
local VERSION = "v8.3"
local BUILD   = "2026-11-01 13:05"

local CONFIG = {
    MenuKeys = { Enum.KeyCode.RightShift, Enum.KeyCode.Insert, Enum.KeyCode.F2 },
    FlyKey   = Enum.KeyCode.F,
    AimKey   = Enum.KeyCode.Q,
    Accent   = Color3.fromRGB(0, 200, 255),
    Enemy    = Color3.fromRGB(255, 70, 70),
    Mate     = Color3.fromRGB(90, 255, 120),
    AC = { Patterns = { "BS_", "最强防御", "防御", "Antikick", "AntiCheat", "Anti_Kick", "AC_" },
           Marker = "BS_Script_Running_Marker" },
    ACG = { Keywords = { "AntiCheat", "Antikick", "AntiKick", "Anti_Kick", "BS_", "防御" },
            Known    = { "ReplicatedFirst.AntiCheat" },   -- 实测该服的反作弊脚本全名
            RemoteKw = { "AntiCheat", "Antikick", "ReportCheat", "BanPlayer" },
            Hashes   = {} },
    Safe = { "veh", "car", "drive", "input", "control", "sprint", "camera", "mouse",
             "key", "player", "character", "anim", "tool", "seat", "vehicle" },
}

local Players, RS = game:GetService("Players"), game:GetService("RunService")
local UIS, CoreGui = game:GetService("UserInputService"), game:GetService("CoreGui")
local RStorage, SC = game:GetService("ReplicatedStorage"), game:GetService("ScriptContext")
local Lighting, TweenService = game:GetService("Lighting"), game:GetService("TweenService")
local lp, cam = Players.LocalPlayer, workspace.CurrentCamera

local S = {
    fly = false, flySpeed = 55,
    esp = false, espBox = true, espName = true, espHp = true, espDist = true,
    espTeam = false, espOccluded = true, espRainbow = false,
    aim = false, aimSmooth = 12, aimFov = 140, bulletTrack = false, silentAim = false, silentTime = 0.09, aimNpc = false, espNpc = false, flyGov = true, btStandalone = false, remoteAim = true, remoteAimAll = false, remoteProbe = false,
    aimPart = "Head", aimTeam = false, aimWall = true, showFov = true,
    aimOnFire = true, vehicleSafe = true, antiFall = false,
    flyMode = "cframe", antiSnap = true,
    noclip = false, walkSpeed = 20, safeMode = false, autoTune = true, ghost = false,
    night = false, entityEsp = false, entNotify = true, hudNearest = true,
    itemEsp = false, pickup = false, pickupRadius = 25, pickupInterval = 0.12,
    autoPrompt = false, promptRadius = 20,
    autoDoor = false, doorRadius = 28, autoWalk = false, pulse = false,
    entColor = true, thirdPerson = false, autoHide = false, hideDist = 130,
    hideMode = "sky", skyHeight = 300, skyTime = 8, instantPrompt = true,
    hideOnlyRush = true, invertY = true, fastScan = true, scenery = false,
    tpMode = "zoom", doors = false, eyesAway = true, leverAuto = false, lever = false, hidePrefer = "sky", forceDoors = false, govEnabled = false, govMax = 12, govWindow = 0.6,
    dim = true, bgA = 0.5, blur = false,
}
local captureMode = false

local function mk(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end
local function hover(row, base)
    row.MouseEnter:Connect(function() row.BackgroundColor3 = Color3.fromRGB(34, 38, 48) end)
    row.MouseLeave:Connect(function() row.BackgroundColor3 = base end)
end
local function charOf(p) local c = p and p.Character; if c and c.Parent then return c end end
local function humOf(p) local c = charOf(p); return c and c:FindFirstChildOfClass("Humanoid") end
local function alive(p) local h = humOf(p); return h ~= nil and h.Health > 0 end
local function isMate(p) return lp.Team ~= nil and p.Team == lp.Team end
local function isSafeName(s)
    s = (s or ""):lower()
    if s == "" then return false end
    for _, k in ipairs(CONFIG.Safe) do
        if s:find(k, 1, true) then return true end
    end
    return false
end

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
    -- 连续射线: 跳过透明/无碰撞的挡板(很多游戏用隐形墙挡视线,会让自瞄永远找不到目标)
    local origin = cam.CFrame.Position
    local target = part.Position
    rp.FilterDescendantsInstances = { lp.Character, part.Parent }
    for _ = 1, 5 do
        local dir = target - origin
        if dir.Magnitude < 0.1 then return true end
        local hit = workspace:Raycast(origin, dir, rp)
        if not hit then return true end
        local inst = hit.Instance
        if inst:IsDescendantOf(part.Parent) then return true end
        local solid = true
        pcall(function()
            if inst.Transparency >= 0.95 or inst.CanCollide == false then solid = false end
        end)
        if solid then return false end
        origin = hit.Position + dir.Unit * 0.1
    end
    return true
end

--==================== 服务器档位: 按“特征”自动识别 ====================
local PROFILES = {
    doors = {
        label = "DOORS · 服务端权威",
        flySpeed = 18, flyCap = 20, flyMode = "cframe", walkSpeed = 20,
        antiSnap = true, noclip = true, vehicleSafe = false, banRisk = "低",
        tip = "按 0.6s 周期纠正位置，高速必被拉回；用 Noclip + 走速 20",
    },
    sanAurie = {
        label = "San Aurie · 会封号",
        flySpeed = 16, flyCap = 18, flyMode = "cframe", walkSpeed = 16,
        antiSnap = true, noclip = true, vehicleSafe = true, banRisk = "高",
        tip = "实测服务端会下发 600 封禁；速度已锁 18 以下，建议只开 ESP / Noclip",
    },
    ["default"] = {
        label = "通用 · 未识别",
        flySpeed = 40, flyCap = 60, flyMode = "cframe", walkSpeed = 16,
        antiSnap = true, noclip = false, vehicleSafe = true, banRisk = "未知",
        tip = "未匹配特征，按实测调速度（先 35，被拉就降 5 档）",
    },
}

local function detectProfile()
    local ok, res = pcall(function()
        if RStorage:FindFirstChild("RemotesFolder") and workspace:FindFirstChild("CurrentRooms") then
            return "doors"
        end
        if game:GetService("ReplicatedFirst"):FindFirstChild("AntiCheat")
           or RStorage:FindFirstChild("BS_Script_Running_Marker") then
            return "sanAurie"
        end
        return "default"
    end)
    return ok and res or "default"
end

local currentProfileKey = detectProfile()

local function applyProfile(key)
    local p = PROFILES[key] or PROFILES["default"]
    currentProfileKey = key
    S.flySpeed    = math.min(p.flySpeed or 40, p.flyCap or 60)
    S.flyMode     = p.flyMode
    S.walkSpeed   = p.walkSpeed
    S.antiSnap    = p.antiSnap
    S.noclip      = p.noclip
    S.vehicleSafe = p.vehicleSafe
    return p
end

local function flyCapNow()
    local p = PROFILES[currentProfileKey]
    return (p and p.flyCap) or 60
end

applyProfile(currentProfileKey)

-- 非 DOORS 服务器：默认关掉 DOORS 专属模块（可在杂项强制开启）
local function doorsAllowed()
    return currentProfileKey == "doors" or S.forceDoors
end
if not doorsAllowed() then
    S.doors, S.lever, S.leverAuto, S.eyesAway, S.autoHide, S.scenery = false, false, false, false, false, false
end

--==================== 界面骨架 ====================
local gui = mk("ScreenGui", { Name = "XHub", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999 })
if not pcall(function() gui.Parent = CoreGui end) then
    gui.Parent = lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui")
end

local backdrop = mk("Frame", { Name = "Backdrop", Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1 - S.bgA,
    BorderSizePixel = 0, Visible = S.dim, ZIndex = 0, Active = false }, gui)

local blurFx = Instance.new("BlurEffect")
blurFx.Size = 0; blurFx.Enabled = false; blurFx.Parent = Lighting

--==================== 右上角通知 ====================
local notifHolder = mk("Frame", { Name = "Notifs", Size = UDim2.fromOffset(290, 0),
    Position = UDim2.new(1, -14, 0, 14), AnchorPoint = Vector2.new(1, 0),
    BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y,
    ZIndex = 60, ClipsDescendants = false }, gui)
mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
    HorizontalAlignment = Enum.HorizontalAlignment.Right }, notifHolder)
local notifOrder = 0

local function notify(text, kind, life)
    notifOrder = notifOrder + 1
    local col = CONFIG.Accent
    if kind == "err" then col = Color3.fromRGB(255, 96, 96)
    elseif kind == "ok" then col = Color3.fromRGB(96, 232, 150)
    elseif kind == "warn" then col = Color3.fromRGB(255, 196, 92) end

    local card = mk("Frame", { Size = UDim2.fromOffset(290, 34),
        BackgroundColor3 = Color3.fromRGB(24, 27, 34), BackgroundTransparency = 0.08,
        BorderSizePixel = 0, LayoutOrder = notifOrder, ZIndex = 60 }, notifHolder)
    mk("UICorner", { CornerRadius = UDim.new(0, 8) }, card)
    mk("UIStroke", { Color = col, Thickness = 1, Transparency = 0.55 }, card)
    mk("Frame", { Size = UDim2.fromOffset(3, 20), Position = UDim2.new(0, 6, 0.5, -10),
        BackgroundColor3 = col, BorderSizePixel = 0, ZIndex = 61 }, card)
    mk("TextLabel", { Text = text, BackgroundTransparency = 1, Position = UDim2.new(0, 16, 0, 0),
        Size = UDim2.new(1, -24, 1, 0), Font = Enum.Font.GothamMedium, TextSize = 12,
        TextColor3 = Color3.fromRGB(234, 240, 250), TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 61 }, card)

    TweenService:Create(card, TweenInfo.new(0.18), { BackgroundTransparency = 0.08 }):Play()
    task.delay(life or 3.2, function()
        if not card.Parent then return end
        TweenService:Create(card, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
        task.delay(0.34, function() if card.Parent then card:Destroy() end end)
    end)
end

--==================== 主面板 ====================
local main = mk("Frame", { Name = "Main", Size = UDim2.fromOffset(570, 430),
    Position = UDim2.new(0.5, -285, 0.5, -215), BackgroundColor3 = Color3.fromRGB(20, 22, 28),
    BorderSizePixel = 0, Active = true, ClipsDescendants = true, ZIndex = 5 }, gui)
mk("UICorner", { CornerRadius = UDim.new(0, 12) }, main)
mk("UIStroke", { Color = Color3.fromRGB(58, 64, 78), Thickness = 1 }, main)
mk("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.35) }) }, main)

local bar = mk("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = Color3.fromRGB(27, 30, 39),
    BorderSizePixel = 0, ZIndex = 2 }, main)
mk("TextLabel", { Text = "XHub", BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
    Position = UDim2.new(0, 16, 0, 0), Size = UDim2.fromOffset(60, 42), Font = Enum.Font.GothamBold,
    TextSize = 15, TextColor3 = Color3.fromRGB(235, 241, 250) }, bar)
mk("TextLabel", { Text = VERSION .. "  universal", BackgroundTransparency = 1,
    TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 68, 0, 0),
    Size = UDim2.fromOffset(130, 42), Font = Enum.Font.Gotham, TextSize = 11,
    TextColor3 = Color3.fromRGB(120, 130, 148) }, bar)

local icon
local function setVisible(v, silent)
    main.Visible = v
    if v then
        pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.Default end)
        pcall(function() UIS.MouseIconEnabled = true end)
    end
    if backdrop then backdrop.Visible = v and S.dim end
    if blurFx then
        blurFx.Enabled = v and S.blur
        blurFx.Size = (v and S.blur) and 14 or 0
    end
    if icon then icon.BackgroundColor3 = v and CONFIG.Accent or Color3.fromRGB(30, 34, 44) end
    if not silent then notify(v and "菜单已打开" or "菜单已隐藏", "info", 1.1) end
end

do
    icon = mk("TextButton", { Name = "XHubIcon", Text = "X", Size = UDim2.fromOffset(36, 36),
        Position = UDim2.new(0, 10, 0.5, -20), BackgroundColor3 = CONFIG.Accent,
        TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 16,
        AutoButtonColor = false, ZIndex = 10 }, gui)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, icon)
    mk("UIStroke", { Color = CONFIG.Accent, Thickness = 1, Transparency = 0.4 }, icon)

    local keyBtn = mk("TextButton", { Name = "XHubKeyBtn", Text = "K", Size = UDim2.fromOffset(36, 30),
        Position = UDim2.new(0, 10, 0.5, 22), BackgroundColor3 = Color3.fromRGB(30, 34, 44),
        TextColor3 = Color3.fromRGB(200, 208, 220), Font = Enum.Font.GothamBold, TextSize = 14,
        AutoButtonColor = false, ZIndex = 10 }, gui)
    mk("UICorner", { CornerRadius = UDim.new(0, 8) }, keyBtn)

    icon.MouseButton1Click:Connect(function() setVisible(not main.Visible) end)
    keyBtn.MouseButton1Click:Connect(function()
        captureMode = true
        notify("按下新的菜单键（Esc 取消）", "warn", 4)
    end)
end

local closeBtn = mk("TextButton", { Text = "×", BackgroundTransparency = 1, TextSize = 20,
    Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(150, 155, 170),
    Size = UDim2.fromOffset(42, 42), Position = UDim2.new(1, -42, 0, 0) }, bar)
closeBtn.MouseButton1Click:Connect(function() setVisible(false) end)

do
    local dragging, ds, sp = false, nil, nil
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging, ds, sp = true, i.Position, main.Position end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - ds
            main.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
end

--==================== 页签 / 内容卡 ====================
local tabBar = mk("Frame", { Size = UDim2.new(0, 124, 1, -56), Position = UDim2.new(0, 12, 0, 50),
    BackgroundTransparency = 1, ZIndex = 3 }, main)
mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, tabBar)
local cardBg = mk("Frame", { Size = UDim2.new(1, -160, 1, -64), Position = UDim2.new(0, 148, 0, 50),
    BackgroundColor3 = Color3.fromRGB(15, 17, 22), BorderSizePixel = 0, ZIndex = 3 }, main)
mk("UICorner", { CornerRadius = UDim.new(0, 9) }, cardBg)
mk("UIStroke", { Color = Color3.fromRGB(44, 49, 60), Thickness = 1 }, cardBg)
local content = mk("Frame", { Size = UDim2.new(1, -170, 1, -74), Position = UDim2.new(0, 153, 0, 55),
    BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 4 }, main)

local pages, tabBtns, lastOrder = {}, {}, 0
local function addPage(name)
    lastOrder = lastOrder + 1
    local btn = mk("TextButton", { Text = name, BackgroundColor3 = Color3.fromRGB(26, 29, 37),
        BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 32), AutoButtonColor = false, TextSize = 13,
        Font = Enum.Font.GothamMedium, TextColor3 = Color3.fromRGB(165, 172, 186),
        LayoutOrder = lastOrder, ZIndex = 4 }, tabBar)
    mk("UICorner", { CornerRadius = UDim.new(0, 7) }, btn)
    local page = mk("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = Color3.fromRGB(70, 76, 90),
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false, ZIndex = 4 }, content)
    mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, page)
    mk("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
        PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8) }, page)
    pages[name], tabBtns[name] = page, btn
    btn.MouseButton1Click:Connect(function()
        for n, p in pairs(pages) do
            p.Visible = (n == name)
            tabBtns[n].BackgroundColor3 = (n == name) and Color3.fromRGB(38, 43, 54) or Color3.fromRGB(26, 29, 37)
            tabBtns[n].TextColor3 = (n == name) and Color3.fromRGB(238, 243, 252) or Color3.fromRGB(165, 172, 186)
        end
    end)
    return page
end

local rowOrder = 0
local function addSection(page, text)
    rowOrder = rowOrder + 1
    return mk("TextLabel", { Text = text, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18),
        TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold, TextSize = 10,
        TextColor3 = CONFIG.Accent, LayoutOrder = rowOrder }, page)
end
local function addToggle(page, text, default, cb)
    rowOrder = rowOrder + 1
    local base = Color3.fromRGB(24, 27, 34)
    local row = mk("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = base,
        BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = rowOrder }, page)
    mk("UICorner", { CornerRadius = UDim.new(0, 7) }, row)
    mk("TextLabel", { Text = text, BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -62, 1, 0),
        Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Color3.fromRGB(218, 224, 235) }, row)
    local pill = mk("Frame", { Size = UDim2.fromOffset(34, 18), Position = UDim2.new(1, -44, 0.5, -9),
        BackgroundColor3 = Color3.fromRGB(44, 49, 60), BorderSizePixel = 0 }, row)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, pill)
    local dot = mk("Frame", { Size = UDim2.fromOffset(14, 14), Position = UDim2.new(0, 2, 0.5, -7),
        BackgroundColor3 = Color3.fromRGB(148, 154, 168), BorderSizePixel = 0 }, pill)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
    local on = default
    local function paint()
        pill.BackgroundColor3 = on and CONFIG.Accent or Color3.fromRGB(44, 49, 60)
        dot.Position = on and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    end
    local function set(v) on = v; paint(); if cb then cb(v) end end
    row.MouseButton1Click:Connect(function() set(not on) end)
    hover(row, base); paint(); if cb then cb(on) end
    return set
end
local function addSlider(page, text, mn, mx, default, cb)
    rowOrder = rowOrder + 1
    local row = mk("Frame", { BackgroundColor3 = Color3.fromRGB(24, 27, 34), BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 46), LayoutOrder = rowOrder }, page)
    mk("UICorner", { CornerRadius = UDim.new(0, 7) }, row)
    mk("TextLabel", { Text = text, BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 10, 0, 4), Size = UDim2.new(1, -72, 0, 15),
        Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Color3.fromRGB(218, 224, 235) }, row)
    local valueLbl = mk("TextLabel", { Text = "", BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -62, 0, 4),
        Size = UDim2.fromOffset(52, 15), Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = CONFIG.Accent }, row)
    local track = mk("Frame", { Size = UDim2.new(1, -20, 0, 6), Position = UDim2.new(0, 10, 0, 28),
        BackgroundColor3 = Color3.fromRGB(44, 49, 60), BorderSizePixel = 0 }, row)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
    local fill = mk("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = CONFIG.Accent,
        BorderSizePixel = 0 }, track)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
    local knob = mk("Frame", { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0 }, track)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
    local drag = false
    local function set(v)
        v = math.clamp(v, mn, mx)
        local a = (v - mn) / (mx - mn)
        fill.Size = UDim2.new(a, 0, 1, 0)
        knob.Position = UDim2.new(a, 0, 0.5, 0)
        valueLbl.Text = tostring(math.floor(v * 10 + 0.5) / 10)
        if cb then cb(v) end
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
    local base = Color3.fromRGB(30, 34, 44)
    local btn = mk("TextButton", { Text = text, AutoButtonColor = false, BackgroundColor3 = base,
        BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = rowOrder,
        Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Color3.fromRGB(224, 230, 240) }, page)
    mk("UICorner", { CornerRadius = UDim.new(0, 7) }, btn)
    btn.MouseButton1Click:Connect(cb)
    hover(btn, base)
    return function(t) btn.Text = t end
end
local function addBox(page, placeholder, default)
    rowOrder = rowOrder + 1
    local box = mk("TextBox", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Color3.fromRGB(24, 27, 34),
        BorderSizePixel = 0, ClearTextOnFocus = false, PlaceholderText = placeholder, Text = default or "",
        PlaceholderColor3 = Color3.fromRGB(110, 118, 132), Font = Enum.Font.Gotham, TextSize = 12,
        TextColor3 = Color3.fromRGB(232, 238, 248), TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = rowOrder }, page)
    mk("UICorner", { CornerRadius = UDim.new(0, 7) }, box)
    mk("UIPadding", { PaddingLeft = UDim.new(0, 8) }, box)
    return box
end

--==================== 飞行 v2: 双模式 + 反拉回 ====================
local flyBV, flyPos, lastHrpPos
local flySnaps = 0

local function flyStop()
    S.fly = false
    if flyBV then flyBV:Destroy(); flyBV = nil end
    local h = humOf(lp)
    if h then pcall(function() h.PlatformStand = false end) end
    cam.CameraType = Enum.CameraType.Custom
    flyPos, lastHrpPos, flySnaps = nil, nil, 0
end

local function setFly(on)
    if on and S.safeMode then
        notify("安全模式开启：位移类功能已禁用（先关掉安全模式）", "err", 3)
        return
    end
    S.fly = on
    local c = charOf(lp); local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if on and hrp then
        flyPos = hrp.Position
        lastHrpPos = nil
        flySnaps = 0
        local h = humOf(lp)
        if S.flyMode == "cframe" and h then pcall(function() h.PlatformStand = true end) end
        if S.flyMode == "body" then
            if flyBV then flyBV:Destroy() end
            flyBV = mk("BodyVelocity", { Name = "XHubFly", MaxForce = Vector3.new(1e5, 1e5, 1e5),
                Velocity = Vector3.zero, P = 1250 }, hrp)
        end
        notify(("飞行已开启 · %s · 速度 %d"):format(S.flyMode == "body" and "物理" or "CFrame", S.flySpeed), "ok", 1.6)
    else
        flyStop()
        notify("飞行已关闭", "info", 1.2)
    end
end

local function flyDir()
    local cf = cam.CFrame
    local d = Vector3.zero
    if UIS:IsKeyDown(Enum.KeyCode.W) then d = d + cf.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.S) then d = d - cf.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.A) then d = d - cf.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.D) then d = d + cf.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.Space) then d = d + Vector3.yAxis end
    if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then d = d - Vector3.yAxis end
    return d
end

local tune = { n = 0, dSum = 0, pSum = 0, pN = 0, lastT = 0 }

local function onSnap(delta)
    flySnaps = flySnaps + 1
    local now = os.clock()
    tune.n = tune.n + 1
    tune.dSum = tune.dSum + (delta or 0)
    if tune.lastT > 0 then
        tune.pSum = tune.pSum + (now - tune.lastT)
        tune.pN = tune.pN + 1
    end
    tune.lastT = now

    if tune.n >= 3 then
        local period = (tune.pN > 0) and (tune.pSum / tune.pN) or 0.63
        local avgD = tune.dSum / tune.n
        local allowed = math.floor(S.flySpeed - avgD / period)
        local cap = flyCapNow()
        local target = math.max(10, math.min(cap, math.floor((S.flySpeed - avgD / period) * 0.9)))
        if S.autoTune and target < S.flySpeed then
            S.flySpeed = target
            notify(("自动调参: 每 %.2fs 被扣 %.1f studs → 该服上限≈%d → 已设为 %d")
                :format(period, avgD, math.max(allowed, 10), target), "warn", 4.5)
        end
        tune.n, tune.dSum, tune.pSum, tune.pN = 0, 0, 0, 0
        flySnaps = 0
    end
end

RS.RenderStepped:Connect(function(dt)
    if not S.fly then return end
    local cap = flyCapNow()
    if S.govEnabled and S.flyGov then
        local govCap = math.floor((S.govMax or 12) / (S.govWindow or 0.6))
        if govCap > 4 and cap > govCap then cap = govCap end
    end
    if S.flySpeed > cap then S.flySpeed = cap end
    local c = charOf(lp); local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local dir = flyDir()

    if S.flyMode == "body" then
        if not flyBV or flyBV.Parent ~= hrp then
            flyBV = mk("BodyVelocity", { Name = "XHubFly", MaxForce = Vector3.new(1e5, 1e5, 1e5),
                Velocity = Vector3.zero, P = 1250 }, hrp)
        end
        flyBV.Velocity = (dir.Magnitude > 0) and (dir.Unit * S.flySpeed) or Vector3.zero
        if S.antiSnap and lastHrpPos and dir.Magnitude > 0 then
            if (hrp.Position - lastHrpPos).Magnitude < 0.03 then onSnap() end
        end
        lastHrpPos = hrp.Position
        return
    end

    -- CFrame 模式: 直接写位置,被服务器拉回就顺势续飞(不硬抢)
    local cur = hrp.CFrame
    flyPos = flyPos or cur.Position
    local snapDelta = (cur.Position - flyPos).Magnitude
    if S.antiSnap and snapDelta > 6 then
        onSnap(snapDelta)
        flyPos = cur.Position
    end

    local moving = dir.Magnitude > 0
    if S.pulse and moving and (os.clock() % 0.6) >= 0.36 then moving = false end
    if S.ghost then
        local h2 = humOf(lp)
        if h2 then pcall(function() h2.WalkSpeed = 16 end) end
    end

    if not moving then
        -- 静止时绝不写 CFrame：否则每帧把角色钉住，穿墙/物理都会被我们挡住
        flyPos = cur.Position
        return
    end

    flyPos = flyPos + dir.Unit * S.flySpeed * dt
    local rot = cur - cur.Position
    hrp.CFrame = CFrame.new(flyPos) * rot
    pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
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
                OutlineTransparency = 0.1, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop }, c)
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
            StudsOffset = Vector3.new(0, 2.4, 0), AlwaysOnTop = true, Adornee = head, LightInfluence = 0 }, head)
        o.nameLbl = mk("TextLabel", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16),
            Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.new(1, 1, 1),
            TextStrokeTransparency = 0.4 }, o.tag)
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
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(280, 280),
        Visible = false, ZIndex = 3 }, gui)
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
    -- NPC / 怪物目标
    if S.aimNpc then
        pcall(function()
            local n = 0
            for _, m in ipairs(workspace:GetDescendants()) do
                n = n + 1
                if n > 3000 then break end
                if m:IsA("Model") and not Players:GetPlayerFromCharacter(m) then
                    local hum = m:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        local part = m:FindFirstChild("Head") or m:FindFirstChild("HumanoidRootPart", true)
                        if part then
                            local sp, onScreen = cam:WorldToViewportPoint(part.Position)
                            if onScreen then
                                local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                                if d < bestD and canSee(part) then best, bestD = part, d end
                            end
                        end
                    end
                end
            end
        end)
    end
    return best
end
local aimInfo
local aimWant, aimGoal = false, nil

local function aimTick(dt)
    aimWant = false
    if S.aim and not main.Visible then
        -- 只保留「左键开火自瞄」；Q 键已移除
        if UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
            aimWant = true
        elseif not S.aimOnFire then
            aimWant = true
        end
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

    if not aimWant then
        aimGoal = nil
        if aimInfo then aimInfo.Text = "自瞄: 待触发（按住左键开火）" end
        return
    end

    local okT, t = pcall(findTarget)
    if not okT then t = nil end
    if not t then
        aimGoal = nil
        if aimInfo then aimInfo.Text = "自瞄: FOV 内无目标" end
        return
    end

    if cam.CameraType ~= Enum.CameraType.Custom then cam.CameraType = Enum.CameraType.Custom end
    local cur = cam.CFrame
    local goal = CFrame.lookAt(cur.Position, t.Position)
    aimGoal = goal
    if S.bulletTrack then
        -- 子弹追踪：这一帧直接把相机对准目标（工具从相机方向发射时 = 命中）
        cam.CFrame = goal
    else
        local alpha = 1 - math.exp(-math.max(S.aimSmooth, 0.5) * dt)
        cam.CFrame = cur:Lerp(goal, math.clamp(alpha, 0.02, 1))
    end

    if aimInfo then
        local vp = cam.ViewportSize
        local sp = cam:WorldToViewportPoint(t.Position)
        local err = (Vector2.new(sp.X, sp.Y) - Vector2.new(vp.X / 2, vp.Y / 2)).Magnitude
        aimInfo.Text = ("自瞄: 目标 %.0fm · 残余误差 %.0fpx"):format(
            (t.Position - cam.CFrame.Position).Magnitude, err)
    end
end

pcall(function() RS:UnbindFromRenderStep("XHubAim") end)
RS:BindToRenderStep("XHubAim", Enum.RenderPriority.Camera.Value + 1, aimTick)

--==== 远程弹道改写（Remote Aim）：让静默/子弹追踪真正影响命中 ====
local WEAPON_REMOTE_KW = { "fire", "shoot", "hit", "damage", "bullet", "gun",
                           "attack", "click", "swing", "melee", "slash", "cast" }
local fireUntil = 0

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        fireUntil = os.clock() + 0.3
    end
end)

local function remoteAimPoint()
    if not (S.silentAim or S.btStandalone or S.bulletTrack) then return nil end
    if not S.remoteAim then return nil end
    local ok, t = pcall(findTarget)
    if ok and t then return t.Position end
    return nil
end

local remoteHooked = false

local function argSig(args)
    local parts = {}
    for i = 1, math.min(#args, 6) do
        local v = args[i]
        local tv = typeof(v)
        if tv == "Vector3" then
            parts[#parts + 1] = ("V3(%.1f,%.1f,%.1f)"):format(v.X, v.Y, v.Z)
        elseif tv == "CFrame" then
            parts[#parts + 1] = "CFrame"
        else
            parts[#parts + 1] = tv
        end
    end
    return table.concat(parts, ", ")
end

local function installRemoteAim()
    if remoteHooked then return end
    if not (hookmetamethod and getnamecallmethod and checkcaller) then
        notify("执行器不支持 hookmetamethod，远程改写不可用", "err", 3)
        return
    end
    local old
    old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local m = getnamecallmethod()
        local inWindow = os.clock() < fireUntil
        -- 注意：不能要求 checkcaller()，因为开火是游戏脚本发起的（caller 不是我们）
        if (m == "FireServer" or m == "InvokeServer") and inWindow then
            local okName, nm = pcall(function() return tostring(self.Name):lower() end)
            local args = { ... }

            -- 探针：把开火窗口内所有远程打出来
            if S.remoteProbe then
                print(("[probe] %s  %s  (%d args)"):format(tostring(self.Name), m, #args))
                print("[probe]   " .. argSig(args))
            end

            if S.remoteAim then
                local matched = S.remoteAimAll
                if not matched and okName and nm then
                    for _, k in ipairs(WEAPON_REMOTE_KW) do
                        if nm:find(k, 1, true) then matched = true break end
                    end
                end
                if matched then
                    local pt = remoteAimPoint()
                    if pt then
                        local c = charOf(lp)
                        local hrp = c and c:FindFirstChild("HumanoidRootPart")
                        local changed = false
                        for i, v in ipairs(args) do
                            local tv = typeof(v)
                            if tv == "Vector3" then
                                if v.Magnitude <= 3 and hrp then
                                    args[i] = (pt - hrp.Position).Unit
                                else
                                    args[i] = pt
                                end
                                changed = true
                            elseif tv == "CFrame" then
                                args[i] = CFrame.lookAt(v.Position, pt)
                                changed = true
                            end
                        end
                        if changed then
                            if S.remoteProbe then
                                print(("[probe]   >>> 已改写 %s 的方向参数"):format(tostring(self.Name)))
                            end
                            return old(self, table.unpack(args))
                        end
                    end
                end
            end
        end
        return old(self, ...)
    end))
    remoteHooked = true
    print("[XHub] remote hook installed")
end
pcall(installRemoteAim)
--==== 静默瞄准（Silent Aim）：视角不动，只在开火瞬间改写相机方向 1~6 帧 ====
local silent = { saved = nil, untilT = 0, pos = nil }

local function silentTarget()
    if not S.aim then return nil end
    return findTarget()
end

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    if main.Visible then return end
    if not (S.silentAim or S.btStandalone) then return end
    local wasAim = S.aim
    if not wasAim then S.aim = true end
    local t = nil
    pcall(function() t = findTarget() end)
    S.aim = wasAim
    if t then
        silent.saved = cam.CFrame
        silent.pos = t.Position
        if wasAim then
            silent.untilT = os.clock() + (S.silentTime or 0.09)
        else
            silent.untilT = os.clock() + 0.25   -- 独立子弹追踪：多留几帧确保命中的那一发被改写
        end
    end
end)

pcall(function() RS:UnbindFromRenderStep("XHubSilent") end)
RS:BindToRenderStep("XHubSilent", Enum.RenderPriority.Last.Value - 4, function()
    if not silent.saved then return end
    if os.clock() > silent.untilT then
        pcall(function() cam.CFrame = silent.saved end)
        silent.saved, silent.pos = nil, nil
        return
    end
    if silent.pos then
        pcall(function() cam.CFrame = CFrame.lookAt(silent.saved.Position, silent.pos) end)
    end
end)

-- 兼容：如果执行器支持 hookfunction，再挂一层 ScreenPointToRay（更隐蔽）
pcall(function()
    if not (hookfunction and newcclosure) then return end
    local c = workspace.CurrentCamera
    local spr = c and c.ScreenPointToRay
    if type(spr) ~= "function" then return end
    hookfunction(spr, newcclosure(function(self, x, y, ...)
        if S.silentAim and S.aim and not main.Visible then
            local t = silentTarget()
            if t then
                local ok, sp = pcall(function() return self:WorldToViewportPoint(t.Position) end)
                if ok and sp then return spr(self, sp.X, sp.Y, ...) end
            end
        end
        return spr(self, x, y, ...)
    end))
end)

-- 双保险: 有些游戏在 RenderStepped 里覆写相机,同帧再补一次
RS.RenderStepped:Connect(function()
    if not (S.aim and aimWant and aimGoal) then return end
    cam.CFrame = cam.CFrame:Lerp(aimGoal, 0.45)
end)

--==================== 可回滚记录 + 输入修复 ====================
local FIX = { conns = {}, hooks = {} }

local function repairInput(showNotif)
    local nC, nH = 0, 0
    for _, e in ipairs(FIX.hooks) do
        if pcall(hookfunction, e.f, e.old) then nH = nH + 1 end
    end
    FIX.hooks = {}
    for _, c in ipairs(FIX.conns) do
        if pcall(function() c:Enable() end) then nC = nC + 1 end
    end
    FIX.conns = {}
    pcall(function() UIS.ModalEnabled = false end)
    pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.Default end)
    pcall(function() UIS.MouseIconEnabled = true end)
    local h = humOf(lp)
    if h then
        pcall(function()
            h.PlatformStand = false
            h.Sit = false
            if h.WalkSpeed < 1 then h.WalkSpeed = 16 end
            if h.JumpPower < 1 then h.JumpPower = 50 end
        end)
    end
    local c = charOf(lp)
    if c then
        -- 只清我们自己的速度物体,别动游戏角色控制器在用的 LinearVelocity/AlignPosition
        for _, v in ipairs(c:GetDescendants()) do
            if v.Name == "XHubFly" then pcall(function() v:Destroy() end) end
        end
    end
    if showNotif ~= false then
        notify(("输入已修复 · 还原闭包 %d / 重连 %d"):format(nH, nC), "ok", 3)
    end
    return nH, nC
end

-- 只还原、不复位角色(给“车辆安全模式”用)
local function suspendACG()
    local nH, nC = 0, 0
    for _, e in ipairs(FIX.hooks) do
        if pcall(hookfunction, e.f, e.old) then nH = nH + 1 end
    end
    FIX.hooks = {}
    for _, c in ipairs(FIX.conns) do
        if pcall(function() c:Enable() end) then nC = nC + 1 end
    end
    FIX.conns = {}
    return nH, nC
end

-- 下车后角色“半身入土 / 站不起来 / 会倒”的复位
local function characterFix(silent)
    local c = charOf(lp); if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid")
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if h then
        pcall(function() h.Sit = false end)
        pcall(function() h.PlatformStand = false end)
        pcall(function() h:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        pcall(function() if h.WalkSpeed < 1 then h.WalkSpeed = 16 end end)
        pcall(function() if h.JumpPower < 1 then h.JumpPower = 50 end end)
        pcall(function() h.Jump = true end)
        pcall(function() if h.HipHeight < 0.2 then h.HipHeight = 2 end end)
    end
    if hrp then
        pcall(function() if hrp.Anchored then hrp.Anchored = false end end)
        for _, v in ipairs(c:GetDescendants()) do
            if v:IsA("Weld") or v:IsA("WeldConstraint") then
                local outside = false
                pcall(function()
                    outside = (v.Part1 ~= nil and not v.Part1:IsDescendantOf(c))
                           or (v.Part0 ~= nil and not v.Part0:IsDescendantOf(c))
                end)
                if outside then pcall(function() v:Destroy() end) end
            end
            if (v:IsA("BodyVelocity") or v:IsA("BodyGyro")) and v.Name ~= "XHubFly" then
                pcall(function() v:Destroy() end)
            end
        end
        if h and h.FloorMaterial == Enum.Material.Air then
            pcall(function() hrp.CFrame = hrp.CFrame + Vector3.new(0, 3, 0) end)
        end
    end
    if not silent then notify("角色状态已复位（起身 / 解焊 / 抬升）", "ok", 2.5) end
end

-- 车辆安全模式: 上车自动暂停绕过,下车自动复位角色
local function isSeated()
    local h = humOf(lp); if not h then return false end
    local s = false
    pcall(function() s = h.SeatPart ~= nil end)
    if s then return true end
    pcall(function() s = h:GetState() == Enum.HumanoidStateType.Seated end)
    if s then return true end
    local c = charOf(lp)
    if c then
        for _, v in ipairs(c:GetChildren()) do
            if v:IsA("Weld") and v.Name:lower():find("seat", 1, true) then return true end
        end
    end
    return false
end

-- 防遁地守护
local function groundYAt(pos)
    local params = RaycastParams.new()
    params.FilterType = rp.FilterType
    params.FilterDescendantsInstances = { lp.Character }
    local res = workspace:Raycast(pos + Vector3.new(0, 40, 0), Vector3.new(0, -400, 0), params)
    return res and res.Position.Y or nil
end

local __wasSeated = false
task.spawn(function()
    while true do
        task.wait(0.2)
        local seated = isSeated()
        if seated ~= __wasSeated then
            __wasSeated = seated
            if seated then
                if S.vehicleSafe then
                    local nH, nC = suspendACG()
                    notify(("车辆安全模式: 已暂停绕过（还原 %d 闭包 / %d 连接）"):format(nH, nC), "warn", 2.6)
                end
            else
                task.delay(0.7, function()
                    if S.vehicleSafe then characterFix(true) end
                    notify("已下车: 角色已复位（需要绕过请重开 ①②）", "info", 3)
                end)
            end
        end
    end
end)

task.spawn(function()
    local airT = 0
    while true do
        task.wait(0.3)
        local c, h = charOf(lp), humOf(lp)
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if c and h and hrp and S.antiFall and not S.fly and not isSeated() then
            if h.FloorMaterial == Enum.Material.Air then
                airT = airT + 0.3
                if airT >= 1.2 then
                    airT = 0
                    local gy = groundYAt(hrp.Position)
                    if gy and hrp.Position.Y < gy + 2 then
                        pcall(function()
                            hrp.AssemblyLinearVelocity = Vector3.zero
                            hrp.CFrame = CFrame.new(hrp.Position.X, gy + 3.2, hrp.Position.Z)
                        end)
                        -- 静默抬回，不再弹通知（避免和其他功能互相顶）
                    end
                end
            else
                airT = 0
            end
        else
            airT = 0
        end
    end
end)

--==================== 穿墙 / 移速 ====================
local noclipOrig = {}

local function setNoclip(on)
    S.noclip = on
    local c = charOf(lp)
    if not c then return end
    if on then
        for _, v in ipairs(c:GetDescendants()) do
            if v:IsA("BasePart") then
                noclipOrig[v] = v.CanCollide
                pcall(function() v.CanCollide = false end)
            end
        end
        notify("穿墙已开启（低速穿墙不会触发回弹）", "ok", 2)
    else
        for _, v in ipairs(c:GetDescendants()) do
            if v:IsA("BasePart") then
                pcall(function() v.CanCollide = noclipOrig[v] ~= false end)
            end
        end
        noclipOrig = {}
        notify("穿墙已关闭", "info", 1.2)
    end
end

task.spawn(function()
    while task.wait(0.25) do
        if S.noclip then
            local c = charOf(lp)
            if c then
                for _, v in ipairs(c:GetDescendants()) do
                    if v:IsA("BasePart") and v.CanCollide then
                        if noclipOrig[v] == nil then noclipOrig[v] = true end
                        pcall(function() v.CanCollide = false end)
                    end
                end
            end
        end
        if not S.fly and not isSeated() then
            local h = humOf(lp)
            if h and math.abs(h.WalkSpeed - S.walkSpeed) > 0.5 then
                pcall(function() h.WalkSpeed = S.walkSpeed end)
            end
        end
    end
end)

--==================== 基础压制 ====================
local AC = { marker = nil, guard = false }
local function acIs(s)
    if type(s) ~= "string" or s == "" then return false end
    for _, k in ipairs(CONFIG.AC.Patterns) do if s:find(k, 1, true) then return true end end
    return false
end
local function acRun()
    local t, c = 0, 0
    if getreg and coroutine and coroutine.close then
        for _, v in pairs(getreg()) do
            if type(v) == "thread" then
                local ok, src = pcall(function() return debug.info(v, "s") end)
                if ok and acIs(src) and not isSafeName(src) and (pcall(coroutine.close, v)) then
                    t = t + 1
                end
            end
        end
    end
    if getconnections then
        local sigs = {}
        for _, n in ipairs({ "Heartbeat", "RenderStepped", "PreRender", "Stepped" }) do
            local ok, sig = pcall(function() return RS[n] end)
            if ok and sig then sigs[#sigs + 1] = sig end
        end
        for _, sig in ipairs(sigs) do
            local ok, conns = pcall(getconnections, sig)
            if ok and conns then
                for _, k in ipairs(conns) do
                    local sn = ""
                    pcall(function() if k.Script then sn = k.Script.Name end end)
                    if acIs(sn) and not isSafeName(sn) then
                        FIX.conns[#FIX.conns + 1] = k
                        pcall(function() k:Disable() end)
                        pcall(function() k:Disconnect() end)
                        c = c + 1
                    end
                end
            end
        end
    end
    local mc = 0
    local marker = RStorage:FindFirstChild(CONFIG.AC.Marker)
    if marker then
        AC.marker = marker
        for _, sig in ipairs({ marker.Changed, marker:GetPropertyChangedSignal("Value") }) do
            local ok, conns = pcall(getconnections, sig)
            if ok and conns then
                for _, k in ipairs(conns) do
                    FIX.conns[#FIX.conns + 1] = k
                    pcall(function() k:Disable() end); pcall(function() k:Disconnect() end)
                    mc = mc + 1
                end
            end
        end
        pcall(function() marker.Value = false end)
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
    local msg = ("线程 %d / 连接 %d / marker %d"):format(t, c, mc)
    notify("基础压制: " .. msg, "ok", 3)
    print("[XHub-AC]", msg)
    return msg
end

--==================== AC Guard ====================
local G = { layer1 = false, layer2 = false, blockKick = true,
            hookedFns = 0, hookedRemotes = 0, killedThreads = 0, blocked = 0,
            targetScripts = {}, matches = {}, oldNamecall = nil, installed = false }

local function hash(s)
    s = tostring(s or "")
    local h = 5381
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end
    return h
end
local function isTarget(s)
    s = tostring(s or "")
    if s == "" or isSafeName(s) then return false end
    if CONFIG.ACG.Hashes[hash(s)] then return true end
    local low = s:lower()
    for _, k in ipairs(CONFIG.ACG.Known) do
        if low:find(k:lower(), 1, true) then return true end
    end
    for _, k in ipairs(CONFIG.ACG.Keywords) do
        if low:find(k:lower(), 1, true) then return true end
    end
    return false
end
local function collectScripts()
    local byName = {}
    if not getscripts then return byName end
    for _, s in ipairs(getscripts()) do
        local full, nm = "", ""
        pcall(function() full = s:GetFullName(); nm = s.Name end)
        local hit = isTarget(full) or isTarget(nm)
        if not hit and getscriptbytecode then
            local ok, bc = pcall(getscriptbytecode, s)
            if ok and type(bc) == "string" then
                for _, k in ipairs(CONFIG.ACG.Keywords) do
                    if bc:find(k, 1, true) then hit = true; break end
                end
            end
        end
        if hit then
            byName[nm:lower()] = true
            byName[full:lower()] = true
            G.matches[#G.matches + 1] = "script: " .. full
        end
    end
    return byName
end
local function killACGThreads(byName)
    if not (getreg and coroutine and coroutine.close) then return 0 end
    local n = 0
    for _, v in pairs(getreg()) do
        if type(v) == "thread" then
            local src = ""
            pcall(function() src = debug.info(v, "s") or "" end)
            local hit = isTarget(src)
            if not hit and src ~= "" and not isSafeName(src) then
                for nm in pairs(byName) do
                    if src:lower():find(nm, 1, true) then hit = true; break end
                end
            end
            if hit then
                local ok, res = pcall(coroutine.close, v)
                if ok and res then n = n + 1 end
            end
        end
    end
    G.killedThreads = G.killedThreads + n
    return n
end

-- v4.1 精准挂钩: 只处理 AC 自己挂在渲染/心跳上的回调,不扫全量闭包
local function hookConnFns()
    if not (getconnections and hookfunction) then return 0, 0 end
    local connN, hookN = 0, 0
    for _, sigName in ipairs({ "Heartbeat", "RenderStepped", "Stepped", "PreRender" }) do
        local ok, sig = pcall(function() return RS[sigName] end)
        if ok and sig then
            local okc, conns = pcall(getconnections, sig)
            if okc and conns then
                for _, c in ipairs(conns) do
                    local sn, src = "", ""
                    pcall(function() if c.Script then sn = c.Script:GetFullName() end end)
                    pcall(function() src = debug.info(c.Function, "s") or "" end)
                    if (isTarget(sn) or isTarget(src))
                       and not isSafeName(sn) and not isSafeName(src) then
                        FIX.conns[#FIX.conns + 1] = c
                        pcall(function() c:Disable() end)
                        if c.Function then
                            local okh, old = pcall(hookfunction, c.Function, function() end)
                            if okh and old then
                                FIX.hooks[#FIX.hooks + 1] = { f = c.Function, old = old }
                                hookN = hookN + 1
                            end
                        end
                        connN = connN + 1
                    end
                end
            end
        end
    end
    G.hookedFns = G.hookedFns + hookN
    return connN, hookN
end

local function countInputConns()
    if not getconnections then return -1 end
    local n = 0
    for _, sig in ipairs({ UIS.InputBegan, UIS.InputChanged, UIS.InputEnded }) do
        local ok, cs = pcall(getconnections, sig)
        if ok and cs then n = n + #cs end
    end
    return n
end

local function runLayer1()
    G.matches = {}
    local byName = collectScripts()
    local before = countInputConns()
    local t = killACGThreads(byName)
    local c, h = hookConnFns()
    local after = countInputConns()
    if before >= 0 and after >= 0 and after < before then
        repairInput(false)
        notify(("检测层动到了输入连接(%d→%d)，已自动还原"):format(before, after), "err", 4)
        return 0, 0, 0
    end
    return c, t, h
end

local function hookRemote(inst)
    if not (hookmetamethod and getnamecallmethod and checkcaller) then return false end
    local ok = pcall(function()
        local old
        old = hookmetamethod(inst, "__namecall", newcclosure(function(self, ...)
            local m = getnamecallmethod()
            if not checkcaller() and (m == "FireServer" or m == "InvokeServer") then
                G.blocked = G.blocked + 1
                return nil
            end
            return old(self, ...)
        end))
    end)
    if ok then G.hookedRemotes = G.hookedRemotes + 1 end
    return ok
end
local function scanRemotes()
    local n = 0
    local function walk(root)
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") then
                local nm = d.Name:lower()
                local hit = CONFIG.ACG.Hashes[hash(d.Name)] or false
                if not hit then
                    for _, k in ipairs(CONFIG.ACG.RemoteKw) do
                        if nm:find(k:lower(), 1, true) then hit = true; break end
                    end
                end
                if hit then
                    G.matches[#G.matches + 1] = "remote: " .. d:GetFullName()
                    if hookRemote(d) then n = n + 1 end
                end
            end
        end
    end
    pcall(walk, RStorage)
    pcall(walk, game:GetService("ReplicatedFirst"))
    pcall(walk, workspace)
    local ps = lp:FindFirstChild("PlayerScripts")
    if ps then pcall(walk, ps) end
    pcall(walk, CoreGui)
    return n
end
local function installGlobalHook()
    if G.installed then return true end
    if not (getrawmetatable and getnamecallmethod and checkcaller) then return false end
    local mt = getrawmetatable(game)
    if not mt or not mt.__namecall then return false end
    if setreadonly then pcall(setreadonly, mt, false) end
    local old = mt.__namecall
    G.oldNamecall = old
    mt.__namecall = newcclosure(function(self, ...)
        local m = getnamecallmethod()
        if not checkcaller() then
            if G.blockKick and m == "Kick" then
                G.blocked = G.blocked + 1
                return nil
            end
            -- 只切上行;不拦 Connect,避免掐死车辆/疾跑按键
            if m == "FireServer" or m == "InvokeServer" then
                local cs = getcallingscript and getcallingscript()
                local sn, short = "", ""
                if cs then pcall(function() sn = cs:GetFullName(); short = cs.Name end) end
                if not isSafeName(sn) and not isSafeName(short)
                   and (isTarget(sn) or isTarget(short) or G.targetScripts[(short or ""):lower()]) then
                    G.blocked = G.blocked + 1
                    return nil
                end
            end
        end
        return old(self, ...)
    end)
    if setreadonly then pcall(setreadonly, mt, true) end
    G.installed = true
    return true
end
local function runLayer2()
    G.matches = {}
    local byName = collectScripts()
    G.targetScripts = byName
    installGlobalHook()
    return scanRemotes()
end
local function hashSearch(q)
    if q and q ~= "" then CONFIG.ACG.Hashes[hash(q)] = true end
    G.matches = {}
    local byName = collectScripts()
    local c, h = hookConnFns()
    local t = killACGThreads(byName)
    local n = scanRemotes()
    return c, t, h, n
end
local function acgRestore()
    if G.oldNamecall and getrawmetatable then
        local mt = getrawmetatable(game)
        if mt then
            if setreadonly then pcall(setreadonly, mt, false) end
            mt.__namecall = G.oldNamecall
            if setreadonly then pcall(setreadonly, mt, true) end
            G.oldNamecall = nil
            G.installed = false
        end
    end
end

--==================== 按名字拦截远程(通用) ====================
local blockedRemotes = {}

local function blockRemoteSubstr(sub)
    sub = tostring(sub or ""):lower()
    if sub == "" then return 0 end
    if not (hookmetamethod and getnamecallmethod) then return 0 end
    local n = 0
    local function walk(root)
        for _, d in ipairs(root:GetDescendants()) do
            if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent"))
               and not blockedRemotes[d] then
                local full = d:GetFullName():lower()
                if full:find(sub, 1, true) then
                    local ok = pcall(function()
                        local old
                        old = hookmetamethod(d, "__namecall", newcclosure(function(self, ...)
                            local m = getnamecallmethod()
                            if m == "FireServer" or m == "InvokeServer" then
                                G.blocked = G.blocked + 1
                                return nil
                            end
                            return old(self, ...)
                        end))
                    end)
                    if ok then
                        blockedRemotes[d] = true
                        n = n + 1
                        G.matches[#G.matches + 1] = "blocked: " .. d:GetFullName()
                    end
                end
            end
        end
    end
    pcall(walk, RStorage)
    pcall(walk, game:GetService("ReplicatedFirst"))
    pcall(walk, workspace)
    return n
end

--==================== 线程清理面板 ====================
local TC = { all = {}, panel = nil, exact = false, cs = false, rowIdx = 0 }
local function tcCollect()
    local out, seen = {}, {}
    local function add(t)
        if type(t) ~= "thread" or seen[t] then return end
        seen[t] = true
        local src, line, scr = "", -1, nil
        pcall(function() src  = debug.info(t, "s") or "" end)
        pcall(function() line = debug.info(t, "l") or -1 end)
        if getscriptfromthread then pcall(function() scr = getscriptfromthread(t) end) end
        local n = src
        if scr then
            local ok, full = pcall(function() return scr:GetFullName() end)
            if ok and full then n = full end
        end
        local st = "?"
        pcall(function() st = coroutine.status(t) end)
        out[#out + 1] = { t = t, name = n, line = line, status = st }
    end
    if getreg then for _, v in pairs(getreg()) do add(v) end end
    if getrunningthreads then for _, t in ipairs(getrunningthreads()) do add(t) end end
    return out
end
local function tcMatch(e, q)
    if q == nil or q == "" then return true end
    local hay, needle = e.name, q
    if not TC.cs then hay, needle = string.lower(hay), string.lower(needle) end
    if TC.exact then return hay == needle end
    return string.find(hay, needle, 1, true) ~= nil
end
local function tcRender()
    if not TC.panel then return end
    for _, c in ipairs(TC.list:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    local q = TC.search.Text or ""
    local n = 0
    for _, e in ipairs(TC.all) do
        if tcMatch(e, q) then
            n = n + 1
            if n <= 250 then
                TC.rowIdx = TC.rowIdx + 1
                local row = mk("TextButton", {
                    Text = ("%4d  [%-9s]  %s:%d"):format(n, e.status,
                        (e.name ~= "" and e.name or "[无名线程]"):sub(1, 56), e.line),
                    Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = Color3.fromRGB(22, 25, 31),
                    BorderSizePixel = 0, Font = Enum.Font.Code, TextSize = 11,
                    TextColor3 = Color3.fromRGB(200, 208, 220), TextXAlignment = Enum.TextXAlignment.Left,
                    AutoButtonColor = true, LayoutOrder = TC.rowIdx }, TC.list)
                mk("UIPadding", { PaddingLeft = UDim.new(0, 6) }, row)
            end
        end
    end
    TC.status.Text = ("总线程 %d / 匹配 %d%s"):format(#TC.all, n, n > 250 and "（仅显示前 250）" or "")
end
local function tcRefresh() TC.all = tcCollect(); tcRender() end
local function tcKill(q)
    local killed, matched = 0, 0
    if not coroutine.close then return 0, 0 end
    for _, e in ipairs(TC.all) do
        if tcMatch(e, q) and not isSafeName(e.name) then
            matched = matched + 1
            local ok, res = pcall(coroutine.close, e.t)
            if ok and res then killed = killed + 1
            elseif task and task.cancel then pcall(task.cancel, e.t) end
        end
    end
    return killed, matched
end
local function tcDump()
    print(("===== thread dump (%d) ====="):format(#TC.all))
    for i, e in ipairs(TC.all) do print(("%4d [%s] %s:%d"):format(i, e.status, e.name, e.line)) end
end
local function tcBuild()
    if TC.panel then return end
    TC.all = tcCollect()
    local p = mk("Frame", { Name = "TCPanel", Size = UDim2.fromOffset(560, 450),
        Position = UDim2.new(0.5, -280, 0.5, -225), BackgroundColor3 = Color3.fromRGB(20, 22, 28),
        BorderSizePixel = 0, Active = true, Visible = false, ClipsDescendants = true, ZIndex = 70 }, gui)
    mk("UICorner", { CornerRadius = UDim.new(0, 12) }, p)
    mk("UIStroke", { Color = Color3.fromRGB(58, 64, 78), Thickness = 1 }, p)
    TC.panel = p

    local tb = mk("Frame", { Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = Color3.fromRGB(27, 30, 39),
        BorderSizePixel = 0, ZIndex = 71 }, p)
    mk("TextLabel", { Text = "Thread Cleaner", BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(1, -60, 1, 0), Font = Enum.Font.GothamBold, TextSize = 13,
        TextColor3 = Color3.fromRGB(230, 236, 246) }, tb)
    local x = mk("TextButton", { Text = "×", BackgroundTransparency = 1, TextSize = 18,
        Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(150, 155, 170),
        Size = UDim2.fromOffset(36, 36), Position = UDim2.new(1, -36, 0, 0) }, tb)
    x.MouseButton1Click:Connect(function() p.Visible = false end)

    local dragging, ds, sp = false, nil, nil
    tb.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging, ds, sp = true, i.Position, p.Position end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - ds
            p.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)

    TC.search = mk("TextBox", { Size = UDim2.new(1, -24, 0, 32), Position = UDim2.new(0, 12, 0, 46),
        BackgroundColor3 = Color3.fromRGB(26, 29, 37), BorderSizePixel = 0, ClearTextOnFocus = false,
        PlaceholderText = "搜索线程/脚本名", Text = "", PlaceholderColor3 = Color3.fromRGB(120, 128, 145),
        Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = Color3.fromRGB(235, 240, 250),
        TextXAlignment = Enum.TextXAlignment.Left }, p)
    mk("UICorner", { CornerRadius = UDim.new(0, 7) }, TC.search)
    mk("UIPadding", { PaddingLeft = UDim.new(0, 8) }, TC.search)

    local function chip(text, x2, w, cb)
        local b = mk("TextButton", { Text = text, Size = UDim2.fromOffset(w, 26),
            Position = UDim2.new(0, x2, 0, 84), BackgroundColor3 = Color3.fromRGB(30, 34, 44),
            BorderSizePixel = 0, Font = Enum.Font.GothamMedium, TextSize = 12,
            TextColor3 = Color3.fromRGB(210, 216, 226), AutoButtonColor = false }, p)
        mk("UICorner", { CornerRadius = UDim.new(0, 7) }, b)
        b.MouseButton1Click:Connect(cb)
        return b
    end
    local exactChip = chip("精确匹配: 关", 12, 110, function()
        TC.exact = not TC.exact
        exactChip.Text = "精确匹配: " .. (TC.exact and "开" or "关")
        exactChip.BackgroundColor3 = TC.exact and CONFIG.Accent or Color3.fromRGB(30, 34, 44)
        tcRender()
    end)
    local csChip = chip("区分大小写: 关", 130, 122, function()
        TC.cs = not TC.cs
        csChip.Text = "区分大小写: " .. (TC.cs and "开" or "关")
        csChip.BackgroundColor3 = TC.cs and CONFIG.Accent or Color3.fromRGB(30, 34, 44)
        tcRender()
    end)

    TC.list = mk("ScrollingFrame", { Size = UDim2.new(1, -24, 1, -180), Position = UDim2.new(0, 12, 0, 118),
        BackgroundColor3 = Color3.fromRGB(15, 17, 22), BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = Color3.fromRGB(70, 76, 90),
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y }, p)
    mk("UICorner", { CornerRadius = UDim.new(0, 7) }, TC.list)
    mk("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, TC.list)
    mk("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, TC.list)

    TC.status = mk("TextLabel", { Text = "未刷新", BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 1, -58), Size = UDim2.new(1, -24, 0, 18),
        Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Color3.fromRGB(160, 168, 182),
        TextXAlignment = Enum.TextXAlignment.Left }, p)

    local function btn(text, x2, w, cb)
        local b = mk("TextButton", { Text = text, Size = UDim2.fromOffset(w, 30),
            Position = UDim2.new(0, x2, 1, -32), BackgroundColor3 = CONFIG.Accent,
            BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 12,
            TextColor3 = Color3.fromRGB(10, 12, 16), AutoButtonColor = false }, p)
        mk("UICorner", { CornerRadius = UDim.new(0, 7) }, b)
        b.MouseButton1Click:Connect(cb)
        return b
    end
    TC.search:GetPropertyChangedSignal("Text"):Connect(tcRender)
    btn("刷新", 12, 80, function() tcRefresh() end)
    btn("列到 F9", 98, 80, function() tcDump() end)
    btn("填 BS_", 184, 80, function()
        TC.search.Text = "BS_"
        TC.status.Text = "已填 BS_（车辆/输入脚本已白名单，不会误杀）"
    end)
    btn("终止匹配", 270, 96, function()
        local k, m = tcKill(TC.search.Text or "")
        TC.status.Text = ("终止了 %d / %d（匹配 %d）"):format(k, #TC.all, m)
        task.delay(0.3, tcRefresh)
    end)
    btn("关闭", 372, 60, function() p.Visible = false end)
    tcRender()
end
local function tcShow()
    tcBuild(); TC.panel.Visible = true; tcRefresh()
end

--==================== 角色 / 服务器操作 ====================
local function suicide()
    local h = humOf(lp)
    if h then pcall(function() h.Health = 0 end) end
    local c = charOf(lp)
    if c then
        for _, v in ipairs(c:GetDescendants()) do
            if v:IsA("BasePart") then pcall(function() v:BreakJoints() end) end
        end
    end
    notify("已自杀，等待重生", "warn", 2.5)
end
local function rejoinHere()
    local TS = game:GetService("TeleportService")
    notify("正在重进本服…", "info", 2)
    task.wait(0.4)
    local ok = pcall(function() TS:TeleportToPlaceInstance(game.PlaceId, game.JobId, lp) end)
    if not ok then ok = pcall(function() TS:Teleport(game.PlaceId, lp) end) end
    if not ok then notify("重进失败（被游戏/AC 拦截，或该体验禁止传送）", "err", 4) end
end
local function newServer()
    local TS = game:GetService("TeleportService")
    local ok = pcall(function() TS:Teleport(game.PlaceId, lp) end)
    notify(ok and "正在切换到新服务器…" or "切服失败", ok and "info" or "err", 3)
end

-- (实体/物品的即时捕获移到文件后部，等 isEntityModel/ensureEnt 定义好再连; 见 "刷新即时捕获")

--==================== 夜视 ====================
local NV = { saved = nil, cc = nil }

local function setNight(on)
    S.night = on
    local L = Lighting
    if on then
        if not NV.saved then
            NV.saved = {
                Brightness = L.Brightness, Ambient = L.Ambient,
                OutdoorAmbient = L.OutdoorAmbient, ClockTime = L.ClockTime,
                FogEnd = L.FogEnd, GlobalShadows = L.GlobalShadows,
            }
        end
        pcall(function()
            L.Brightness = 3
            L.Ambient = Color3.fromRGB(150, 150, 165)
            L.OutdoorAmbient = Color3.fromRGB(140, 140, 160)
            L.ClockTime = 14
            L.FogEnd = 1000000
            L.GlobalShadows = false
        end)
        if not NV.cc then
            NV.cc = Instance.new("ColorCorrectionEffect")
            NV.cc.Brightness = 0.28
            NV.cc.Contrast = 0.12
            NV.cc.Saturation = 0.15
            NV.cc.Parent = Lighting
        end
        notify("夜视已开启（纯客户端,服务端看不到）", "ok", 2)
    else
        if NV.saved then
            pcall(function()
                L.Brightness = NV.saved.Brightness
                L.Ambient = NV.saved.Ambient
                L.OutdoorAmbient = NV.saved.OutdoorAmbient
                L.ClockTime = NV.saved.ClockTime
                L.FogEnd = NV.saved.FogEnd
                L.GlobalShadows = NV.saved.GlobalShadows
            end)
        end
        if NV.cc then NV.cc:Destroy(); NV.cc = nil end
        notify("夜视已关闭", "info", 1.2)
    end
end

--==================== 实体 / NPC / 怪物绘制 ====================
local ENT_KW = { "Rush", "Ambush", "Eyes", "Screech", "Figure", "Hide", "Seek", "Glitch",
                 "Timothy", "Jack", "Shadow", "Dupe", "Snare", "Guiding", "Monster",
                 "NPC", "Entity", "Bot", "Zombie", "Ghost" }
local entStore = {}

local ENT_IGNORE = { "baserig", "humanoidrig", "dummy", "template", "wall" }

-- 精确实体名表：只比对“模型自己的名字”，绝不扫子对象（否则门里的 FigureAttack 会误报）
local ENT_STRICT = { "rushmoving", "rush", "ambushmoving", "ambush", "seek", "figure",
                     "screech", "eyes", "glitch", "timothy", "jack", "dupe",
                     "snare", "halt", "void", "shadow" }

local function isEntityModel(m)
    if not m:IsA("Model") then return false end
    if Players:GetPlayerFromCharacter(m) then return false end
    local nm = m.Name:lower():gsub("%s+", "")
    for _, k in ipairs(ENT_IGNORE) do
        if nm:find(k, 1, true) then return false end
    end
    if m:FindFirstChildOfClass("Humanoid") then return true end
    if m:FindFirstChild("HumanoidRootPart", true) then return true end
    for _, k in ipairs(ENT_STRICT) do
        if nm:find(k, 1, true) then return true end
    end
    return false
end

local function scanAll(cap)
    local out, n = {}, 0
    cap = cap or 5000
    -- 先扫 CurrentRooms 子树(房间内实体/物品都在这里)
    local cr = workspace:FindFirstChild("CurrentRooms")
    if cr then
        for _, d in ipairs(cr:GetDescendants()) do
            n = n + 1
            if n > cap then break end
            out[#out + 1] = d
        end
    end
    -- 再扫 workspace 其它顶层子树(实体也可能挂在某个 Folder / Model 下)
    if n <= cap then
        for _, child in ipairs(workspace:GetChildren()) do
            if n > cap then break end
            if child ~= cr then
                n = n + 1
                out[#out + 1] = child
                if n <= cap then
                    for _, d in ipairs(child:GetDescendants()) do
                        n = n + 1
                        if n > cap then break end
                        out[#out + 1] = d
                    end
                end
            end
        end
    end
    return out
end

local function destroyEnt(o)
    for _, v in pairs(o) do if typeof(v) == "Instance" then v:Destroy() end end
end

local ENT_COLOR = {
    rush = Color3.fromRGB(255, 60, 60), ambush = Color3.fromRGB(255, 150, 40),
    eyes = Color3.fromRGB(230, 230, 120), screech = Color3.fromRGB(200, 120, 255),
    figure = Color3.fromRGB(160, 60, 255), hide = Color3.fromRGB(120, 200, 255),
    seek = Color3.fromRGB(255, 90, 200), glitch = Color3.fromRGB(120, 255, 180),
    timothy = Color3.fromRGB(255, 200, 90), jack = Color3.fromRGB(255, 120, 120),
    dupe = Color3.fromRGB(180, 180, 255), snare = Color3.fromRGB(255, 160, 160),
}

local function entColorFor(name)
    if not S.entColor then return Color3.fromRGB(255, 120, 40) end
    local low = (name or ""):lower()
    for k, col in pairs(ENT_COLOR) do
        if low:find(k, 1, true) then return col end
    end
    local h = 0
    for i = 1, #low do h = (h * 33 + low:byte(i)) % 360 end
    return Color3.fromHSV(h / 360, 0.75, 1)
end

local entHud
local entSeen = {}

local function firstPart(inst)
    if inst:IsA("BasePart") then return inst end
    local p
    pcall(function() p = inst.PrimaryPart end)
    if p then return p end
    p = inst:FindFirstChild("HumanoidRootPart", true)
    if p then return p end
    return inst:FindFirstChildWhichIsA("BasePart", true)
end

local function distTo(m)
    local c = charOf(lp)
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local p = firstPart(m)
    if p then return (p.Position - hrp.Position).Magnitude end
    local ok, cf = pcall(function() return m:GetBoundingBox() end)
    if ok and cf then return (cf.Position - hrp.Position).Magnitude end
    return nil
end

local function ensureEnt(m)
    local o = entStore[m]
    if not o then o = {}; entStore[m] = o end
    if not (o.hl and o.hl.Parent) then
        o.hl = mk("Highlight", { Name = "XHubEnt",
            FillColor = Color3.fromRGB(255, 120, 40), FillTransparency = 0.55,
            OutlineColor = Color3.fromRGB(255, 205, 130), OutlineTransparency = 0,
            DepthMode = Enum.HighlightDepthMode.AlwaysOnTop }, m)
    end
    o.hl.Parent = m
    o.hl.FillColor = entColorFor(m.Name)
    o.hl.OutlineColor = entColorFor(m.Name):Lerp(Color3.new(1, 1, 1), 0.55)
    local head
    pcall(function() head = m:FindFirstChild("Head") end)
    head = head or firstPart(m)
    if not head then return end
    if not (o.tag and o.tag.Parent) then
        o.tag = mk("BillboardGui", { Name = "XHubEntTag", Size = UDim2.fromOffset(190, 32),
            AlwaysOnTop = true, Adornee = head, StudsOffset = Vector3.new(0, 2.2, 0) }, head)
        o.lbl = mk("TextLabel", { Text = m.Name, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16), Font = Enum.Font.GothamBold, TextSize = 12,
            TextColor3 = Color3.fromRGB(255, 195, 125), TextStrokeTransparency = 0.35 }, o.tag)
        o.dlbl = mk("TextLabel", { Text = "", BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0, 14), Size = UDim2.new(1, 0, 0, 14),
            Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Color3.fromRGB(255, 230, 190),
            TextStrokeTransparency = 0.5 }, o.tag)
    end
    o.tag.Adornee = head
    o.tag.Parent = head
    local showName = m.Name
    if S.espNpc then
        local hum = m:FindFirstChildOfClass("Humanoid")
        if hum then showName = ("%s  [%d]"):format(m.Name, math.floor(hum.Health)) end
    end
    if o.lbl then o.lbl.Text = showName end
    local d = distTo(m)
    if o.dlbl then o.dlbl.Text = d and ("%.0f m"):format(d) or "" end

    if S.entNotify and not entSeen[m] then
        entSeen[m] = true
        if d and d < 400 then
            notify(("发现实体: %s · %.0f m"):format(m.Name, d), "warn", 3)
        end
    end
end

task.spawn(function()
    while true do
        task.wait(S.fastScan and 1.0 or 0.4)
        if S.entityEsp or S.espNpc then
            local n = 0
            for _, d in ipairs(scanAll(4000)) do
                n = n + 1
                if n > 4000 then break end
                if d:IsA("Model") and isEntityModel(d) then
                    pcall(ensureEnt, d)
                end
            end
            local dead = {}
            for m, o in pairs(entStore) do
                if not m.Parent then destroyEnt(o); dead[#dead + 1] = m end
            end
            for _, m in ipairs(dead) do entStore[m] = nil; entSeen[m] = nil end

            -- 最近实体 HUD
            if S.hudNearest then
                if not (entHud and entHud.Parent) then
                    entHud = mk("TextLabel", { Name = "XHubEntHud", Size = UDim2.fromOffset(320, 24),
                        Position = UDim2.new(0.5, -160, 0, 8), BackgroundTransparency = 0.35,
                        BackgroundColor3 = Color3.fromRGB(20, 22, 28), Text = "",
                        Font = Enum.Font.GothamBold, TextSize = 13,
                        TextColor3 = Color3.fromRGB(255, 190, 120), ZIndex = 25 }, gui)
                    mk("UICorner", { CornerRadius = UDim.new(0, 8) }, entHud)
                end
                local bestN, bestD = nil, math.huge
                for m in pairs(entStore) do
                    local d = distTo(m)
                    if d and d < bestD then bestD, bestN = d, m.Name end
                end
                local hh = humOf(lp)
                local dead = (hh == nil) or (hh.Health <= 0)
                if dead then
                    entHud.Text = "角色已死亡 · 房间已卸载，实体不可见（正常）"
                    entHud.TextColor3 = Color3.fromRGB(255, 150, 150)
                else
                    entHud.TextColor3 = Color3.fromRGB(255, 190, 120)
                    entHud.Text = bestN and ("最近实体: %s · %.0f m"):format(bestN, bestD) or "附近没有实体"
                end
            elseif entHud then
                entHud:Destroy(); entHud = nil
            end
        else
            for m, o in pairs(entStore) do destroyEnt(o) end
            entStore = {}
            entSeen = {}
            if entHud then entHud:Destroy(); entHud = nil end
        end
    end
end)

--==================== 物品绘制 / 拾取 / 自动交互 ====================
local ITEM_KW = { "key", "钥匙", "loot", "item", "coin", "chest", "drawer", "pickup",
                  "gem", "gold", "cash", "money", "bandage", "flashlight", "lighter",
                  "candle", "crucifix", "lockpick", "vitamin", "potion", "weapon", "barrel", "crate", "sack", "bag", "box", "桶", "箱", "袋" }
local itemStore = {}

local function nameHits(v, list)
    local nm = (v and v.Name or ""):lower()
    if nm == "" then return false end
    for _, k in ipairs(list) do
        if nm:find(k:lower(), 1, true) then return true end
    end
    return false
end

local ITEM_EXCLUDE = { "candle", "蜡烛", "drawer", "container", "wall", "stool", "chair", "seat", "bench", "table", "sofa", "lamp", "potted", "plant", "tree", "flower", "盆栽" }

local function isItemInst(v)
    local nm = (v and v.Name or ""):lower()
    for _, k in ipairs(ITEM_EXCLUDE) do
        if nm:find(k, 1, true) then return false end
    end
    if v:IsA("Tool") then return true end
    return nameHits(v, ITEM_KW)
end

local function ensureItem(v)
    local o = itemStore[v]
    if not o then o = {}; itemStore[v] = o end
    if not (o.hl and o.hl.Parent) then
        o.hl = mk("Highlight", { Name = "XHubItem",
            FillColor = Color3.fromRGB(140, 255, 60), FillTransparency = 0.35,
            OutlineColor = Color3.fromRGB(235, 255, 150), OutlineTransparency = 0,
            DepthMode = Enum.HighlightDepthMode.AlwaysOnTop }, v)
    end
    o.hl.Parent = v
    local part = firstPart(v)
    if not part then return end
    if not (o.tag and o.tag.Parent) then
        o.tag = mk("BillboardGui", { Name = "XHubItemTag", Size = UDim2.fromOffset(180, 30),
            AlwaysOnTop = true, Adornee = part, StudsOffset = Vector3.new(0, 1.8, 0) }, part)
        o.lbl = mk("TextLabel", { Text = v.Name, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 15), Font = Enum.Font.GothamBold, TextSize = 12,
            TextColor3 = Color3.fromRGB(215, 255, 120), TextStrokeTransparency = 0.25 }, o.tag)
        o.dlbl = mk("TextLabel", { Text = "", BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0, 13), Size = UDim2.new(1, 0, 0, 13),
            Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Color3.fromRGB(245, 255, 200),
            TextStrokeTransparency = 0.5 }, o.tag)
    end
    o.tag.Adornee = part
    o.tag.Parent = part
    if o.lbl then o.lbl.Text = v.Name end
    if o.dlbl then
        local c = charOf(lp)
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if hrp then o.dlbl.Text = ("%.0f m"):format((part.Position - hrp.Position).Magnitude) end
    end
end

local pickupParts = {}

local function rangePickup(radius)
    if not firetouchinterest then return 0 end
    local c = charOf(lp)
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return 0 end
    local n = 0
    for _, v in ipairs(pickupParts) do
        if v.Parent and (v.Position - hrp.Position).Magnitude <= radius then
            pcall(firetouchinterest, v, hrp, 0)
            pcall(firetouchinterest, v, hrp, 1)
            local cd = v:FindFirstChildOfClass("ClickDetector")
            if cd and fireclickdetector then pcall(fireclickdetector, cd) end
            n = n + 1
        end
    end
    return n
end

local promptCool = {}

local function autoPrompts(radius)
    local c = charOf(lp)
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return 0 end
    local now = os.clock()
    local n = 0
    for _, p in ipairs(workspace:GetDescendants()) do
        if p:IsA("ProximityPrompt") and p.Enabled then
            local pos
            local node = p.Parent
            for _ = 1, 4 do
                if not node then break end
                if node:IsA("BasePart") then pos = node.Position break end
                if node:IsA("Attachment") and node.Parent and node.Parent:IsA("BasePart") then
                    pos = node.Parent.Position break
                end
                node = node.Parent
            end
            local pn = (p.Parent and p.Parent.Name or ""):lower()
            local act = (p.ActionText or ""):lower()
            local blocked = pn:find("seat", 1, true) or pn:find("chair", 1, true)
                         or pn:find("sofa", 1, true) or pn:find("bench", 1, true)
                         or pn:find("坐", 1, true)
                         or act:find("sit", 1, true) or act:find("坐", 1, true)
            if pos and not blocked and (pos - hrp.Position).Magnitude <= radius
               and (now - (promptCool[p] or 0)) > 0.25 then
                promptCool[p] = now
                n = n + 1
                if S.instantPrompt then
                    pcall(function() p.HoldDuration = 0 end)
                end
                pcall(function() p.MaxActivationDistance = math.max(p.MaxActivationDistance, radius + 5) end)
                pcall(function() p:InputHoldBegin() end)
                if S.instantPrompt then
                    pcall(function() p:InputHoldEnd() end)
                else
                    task.delay(0.5, function() pcall(function() p:InputHoldEnd() end) end)
                end
            end
        end
    end
    return n
end

local doorState = {}

local function autoDoors(radius)
    local rooms = workspace:FindFirstChild("CurrentRooms")
    if not rooms then return 0 end
    local c = charOf(lp)
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return 0 end
    local now = os.clock()
    local n = 0
    for _, room in ipairs(rooms:GetChildren()) do
        local door = room:FindFirstChild("Door")
        if door then
            local part = door:FindFirstChildWhichIsA("BasePart", true)
            local re = door:FindFirstChild("ClientOpen", true)
            local st = doorState[door]
            if not st then
                st = { tries = 0, last = 0, pos = nil, banned = 0 }
                doorState[door] = st
            end
            if part and re and st.banned <= now
               and (part.Position - hrp.Position).Magnitude <= radius
               and (now - st.last) > 0.8 then
                -- 上次点完门没动 = 假门/锁门,连点两次就拉黑 45s
                if st.pos and (part.Position - st.pos).Magnitude < 0.05 then
                    st.tries = st.tries + 1
                    if st.tries >= 2 then
                        st.banned = now + 45
                        notify(("假门/锁门已跳过: %s"):format(door.Name), "warn", 2.2)
                    end
                end
                if st.banned <= now then
                    st.pos = part.Position
                    st.last = now
                    if re:IsA("RemoteEvent") then
                        pcall(function() re:FireServer() end)
                    elseif re:IsA("RemoteFunction") then
                        pcall(function() re:InvokeServer() end)
                    end
                    n = n + 1
                end
            end
        end
    end
    return n
end

--==================== 自动寻路 ====================
local PF = { running = false, gen = 0 }

local function stopWalk()
    PF.running = false
    PF.gen = PF.gen + 1
    local h = humOf(lp)
    if h then pcall(function() h:MoveTo(h.Parent.HumanoidRootPart.Position) end) end
end

local function walkTo(pos, timeoutSec)
    if PF.running then stopWalk() end
    PF.running = true
    PF.gen = PF.gen + 1
    local gen = PF.gen
    timeoutSec = timeoutSec or 25

    task.spawn(function()
        local t0 = os.clock()
        local c, h = charOf(lp), humOf(lp)
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if not (h and hrp) then PF.running = false; return end
        local path = game:GetService("PathfindingService"):CreatePath({
            AgentRadius = 2, AgentHeight = 5, AgentCanJump = true,
        })
        local ok = pcall(function() path:ComputeAsync(hrp.Position, pos) end)
        local wps
        if ok and path.Status == Enum.PathStatus.Success then
            wps = path:GetWaypoints()
        else
            wps = { { Position = pos } }
            notify("寻路服务不可用，改为直线前进（可开 Noclip 穿障碍）", "warn", 3)
        end
        for _, wp in ipairs(wps) do
            if not PF.running or PF.gen ~= gen or os.clock() - t0 > timeoutSec then break end
            h:MoveTo(wp.Position)
            local tw = os.clock()
            while (hrp.Position - wp.Position).Magnitude > 3.5 do
                if not PF.running or PF.gen ~= gen or os.clock() - t0 > timeoutSec then break end
                task.wait(0.08)
            end
        end
        PF.running = false
    end)
end

local function nearestDoorPos()
    local c = charOf(lp)
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local best, bestD = nil, math.huge
    local cr = workspace:FindFirstChild("CurrentRooms")
    local roots = {}
    if cr then roots[#roots + 1] = cr end
    roots[#roots + 1] = workspace
    for _, root in ipairs(roots) do
        for _, d in ipairs(root:GetDescendants()) do
            -- 名字里带 door 的模型/部件都算候选（Door / DoorFrame / Doorway …）
            local nm = d.Name:lower()
            local isModel = d:IsA("Model")
            local realDoor = isModel and isRealDoor(nm)
            local hasOpen = isModel and d:FindFirstChild("ClientOpen", true) ~= nil
            if realDoor or hasOpen then
                local part = d:IsA("BasePart") and d or d:FindFirstChildWhichIsA("BasePart", true)
                if part and part.Parent then
                    local dd = (part.Position - hrp.Position).Magnitude
                    -- 真门(带 ClientOpen)优先：距离打 8 折，避免选到门框
                    if hasOpen then dd = dd * 0.8 end
                    if dd < bestD then best, bestD = part, (part.Position - hrp.Position).Magnitude end
                end
            end
            if bestD < 6 then break end
        end
    end
    return best and best.Position or nil, bestD
end

task.spawn(function()
    while true do
        task.wait(S.fastScan and 1.5 or 0.35)
        if S.itemEsp then
            local n = 0
            for _, v in ipairs(scanAll(4000)) do
                n = n + 1
                if n > 3000 then break end
                if (v:IsA("Tool") or v:IsA("Model")) and isItemInst(v) then
                    pcall(ensureItem, v)
                end
            end
            local dead = {}
            for v, o in pairs(itemStore) do
                if not v:IsDescendantOf(workspace) then
                    destroyEnt(o); dead[#dead + 1] = v
                end
            end
            for _, v in ipairs(dead) do itemStore[v] = nil end
        elseif next(itemStore) ~= nil then
            for v, o in pairs(itemStore) do destroyEnt(o) end
            itemStore = {}
        end
        if S.pickup then
            local cache = {}
            for _, v in ipairs(scanAll(2500)) do
                if v:IsA("BasePart") and v.Parent and isItemInst(v.Parent) then
                    cache[#cache + 1] = v
                end
            end
            pickupParts = cache
        end
    end
end)

-- 拾取 / 交互 / 开门: 独立快速循环
task.spawn(function()
    while true do
        local iv = S.pickupInterval or 0.12
        if iv < 0.05 then iv = 0.05 end
        task.wait(iv)
        if S.pickup then
            pcall(rangePickup, S.pickupRadius)
            pcall(autoPrompts, S.pickupRadius)
        end
        if S.autoPrompt then pcall(autoPrompts, S.promptRadius) end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        if S.autoDoor then pcall(autoDoors, S.doorRadius) end
    end
end)

--==================== 第三人称 / 模拟移动 / 自动躲避 ====================
local camOrig = nil
local orbit = { yaw = 0, pitch = 0.25, dist = 14 }

local function setThirdPerson(on)
    S.thirdPerson = on
    local P = lp
    if not camOrig then
        camOrig = { max = P.CameraMaxZoomDistance, min = P.CameraMinZoomDistance }
    end
    if on then
        pcall(function() P.CameraMode = Enum.CameraMode.Classic end)
        pcall(function() P.CameraMaxZoomDistance = math.max(camOrig.max, 64) end)
        pcall(function() P.CameraMinZoomDistance = math.max(camOrig.min, 8) end)
        if S.tpMode == "orbit" then
            local cf = cam.CFrame
            orbit.yaw = math.atan2(-cf.LookVector.X, -cf.LookVector.Z)
            orbit.pitch = math.asin(math.clamp(cf.LookVector.Y, -1, 1))
            notify("第三人称: 脚本相机（鼠标自由旋转）", "ok", 2.5)
        else
            notify("第三人称: 变焦锁定（把相机拉到身后，兼容性最好）", "ok", 2.5)
        end
    else
        pcall(function() cam.CameraType = Enum.CameraType.Custom end)
        local h = humOf(lp)
        if h then pcall(function() cam.CameraSubject = h end) end
        pcall(function() P.CameraMaxZoomDistance = camOrig.max end)
        pcall(function() P.CameraMinZoomDistance = camOrig.min end)
        notify("已交还相机控制", "info", 1.6)
    end
end

pcall(function() RS:UnbindFromRenderStep("XHubCam") end)
RS:BindToRenderStep("XHubCam", Enum.RenderPriority.Last.Value, function()
    if not S.thirdPerson then return end
    local P = lp
    local c0 = charOf(lp)
    local hum0 = c0 and c0:FindFirstChildOfClass("Humanoid")
    if S.tpMode == "zoom" then
        -- 变焦锁定：每帧抢，游戏重置也压不住
        pcall(function() P.CameraMode = Enum.CameraMode.Classic end)
        pcall(function()
            if P.CameraMaxZoomDistance < 48 then P.CameraMaxZoomDistance = 48 end
        end)
        pcall(function()
            if P.CameraMinZoomDistance < 10 then P.CameraMinZoomDistance = 10 end
        end)
        pcall(function()
            if hum0 and cam.CameraSubject ~= hum0 then cam.CameraSubject = hum0 end
            if cam.CameraType ~= Enum.CameraType.Custom then
                cam.CameraType = Enum.CameraType.Custom
            end
        end)
        return
    end
    local d = UIS:GetMouseDelta()
    orbit.yaw = orbit.yaw - d.X * 0.0035
    local dy = S.invertY and -d.Y or d.Y
    orbit.pitch = math.clamp(orbit.pitch + dy * 0.0035, -1.2, 1.2)
    local c = charOf(lp)
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then
        -- 角色没了(死亡/加载中)：立刻交还相机，否则会黑屏
        pcall(function() cam.CameraType = Enum.CameraType.Custom end)
        return
    end
    local look = CFrame.fromEulerAnglesYXZ(orbit.pitch, orbit.yaw, 0)
    local eye = hrp.Position + Vector3.new(0, 1.6, 0)
    local pos = eye - look.LookVector * orbit.dist
    pcall(function() cam.CameraSubject = nil end)
    pcall(function() cam.CameraType = Enum.CameraType.Scriptable end)
    cam.CFrame = CFrame.lookAt(pos, eye)
end)

-- 变焦锁定模式：每帧把游戏的视角设置拉回来（不少游戏会锁第一人称）
task.spawn(function()
    while true do
        task.wait(0.15)
        if S.thirdPerson and S.tpMode == "zoom" then
            local P = lp
            pcall(function() P.CameraMode = Enum.CameraMode.Classic end)
            pcall(function()
                if P.CameraMaxZoomDistance < 48 then P.CameraMaxZoomDistance = 48 end
            end)
            pcall(function()
                if P.CameraMinZoomDistance < 10 then P.CameraMinZoomDistance = 10 end
            end)
        end
    end
end)

local function simWalk(pos, timeoutSec)
    stopWalk()
    PF.running = true
    PF.gen = PF.gen + 1
    local gen = PF.gen
    task.spawn(function()
        local t0 = os.clock()
        local c, h = charOf(lp), humOf(lp)
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if not (h and hrp) then
            PF.running = false
            notify("没有角色（可能已死亡/加载中）", "err", 3)
            return
        end
        if h.Health <= 0 then
            PF.running = false
            notify("角色已死亡，无法移动", "err", 3)
            return
        end
        if h.WalkSpeed < 1 then pcall(function() h.WalkSpeed = 16 end) end
        local lastPos, stuckT = hrp.Position, os.clock()
        while PF.running and PF.gen == gen and os.clock() - t0 < (timeoutSec or 20) do
            if not hrp.Parent then break end
            if (hrp.Position - pos).Magnitude < 3.5 then break end
            h:MoveTo(pos)
            if (hrp.Position - lastPos).Magnitude > 2 then
                lastPos, stuckT = hrp.Position, os.clock()
            elseif os.clock() - stuckT > 2.5 then
                -- 卡墙了：跳一下 + 侧移绕开
                pcall(function() h.Jump = true end)
                local dir = (pos - hrp.Position)
                if dir.Magnitude > 0.1 then
                    dir = dir.Unit
                    local right = Vector3.new(dir.Z, 0, -dir.X) * ((math.random() > 0.5) and 6 or -6)
                    h:MoveTo(hrp.Position + right + dir * 3)
                end
                task.wait(0.6)
                stuckT = os.clock()
            end
            task.wait(0.15)
        end
        pcall(function() h:MoveTo(hrp.Position) end)
        PF.running = false
    end)
end

local HIDE_KW = { "closet", "wardrobe", "bed", "locker", "hide", "柜", "床", "hiding" }

local HIDE_PROMPT_KW = { "hide", "closet", "wardrobe", "bed", "locker", "hiding", "柜", "床", "躲" }

local function promptPos(p)
    local node = p.Parent
    for _ = 1, 4 do
        if not node then return nil end
        if node:IsA("BasePart") then return node end
        if node:IsA("Attachment") and node.Parent and node.Parent:IsA("BasePart") then
            return node.Parent
        end
        node = node.Parent
    end
    return nil
end

local function findHidePrompt(maxDist)
    local c = charOf(lp)
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local best, bestD, bestPart
    bestD = maxDist or 120
    for _, p in ipairs(scanAll(4000)) do
        if p:IsA("ProximityPrompt") or p:IsA("ClickDetector") then
            local nm = ((p.Parent and p.Parent.Name or "") .. " "
                     .. ((p:IsA("ProximityPrompt") and (p.ActionText or "") or "")) .. " "
                     .. ((p:IsA("ProximityPrompt") and (p.ObjectText or "") or ""))):lower()
            local hit = false
            for _, k in ipairs(HIDE_PROMPT_KW) do
                if nm:find(k, 1, true) then hit = true; break end
            end
            if hit then
                local part = promptPos(p)
                if part then
                    local d = (part.Position - hrp.Position).Magnitude
                    if d < bestD then best, bestD, bestPart = p, d, part end
                end
            end
        end
    end
    return best, bestD, bestPart
end

--==== 智能躲避：优先“柜子/床的 E 提示”（服务端认可的状态），否则高空顶住 ====
local skyHold = nil

local function preferSky(name)
    if S.hidePrefer == "sky" then return true end
    if S.hidePrefer == "closet" then return false end
    local nm = (name or ""):lower()
    -- auto: Rush/Ambush 钻柜子(服务端认可)；Seek 等追猎型用高空
    if nm:find("rush", 1, true) or nm:find("ambush", 1, true) then return false end
    return true
end

local function skyHide(reason)
    local c = charOf(lp)
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then hiding = false; return end
    skyHold = { cf = hrp.CFrame + Vector3.new(0, S.skyHeight, 0), exp = os.clock() + S.skyTime }
    notify(("高空躲避(%s): %.0f studs / %d 秒")
        :format(reason or "?", S.skyHeight, S.skyTime), "warn", 3)
    task.delay(S.skyTime, function()
        skyHold = nil
        local c2 = charOf(lp)
        local h2 = c2 and c2:FindFirstChild("HumanoidRootPart")
        if h2 then pcall(function() h2.Anchored = false end) end
        hiding = false
    end)
end

local function hideSmart(name)
    if hiding then return end
    if os.clock() < (S.lastHide or 0) + 15 then return end
    S.lastHide = os.clock()
    hiding = true

    if preferSky(name) then
        skyHide(name)
        return
    end

    local prompt, d, part = findHidePrompt(150)
    if prompt and part then
        local pname = (part.Parent and part.Parent.Name) or part.Name
        notify(("躲进 %s（%.0f m）"):format(pname, d or 0), "warn", 2.4)
        local c = charOf(lp)
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if hrp and (d or 0) > 10 then
            local dir = hrp.Position - part.Position
            if dir.Magnitude < 0.1 then dir = Vector3.new(0, 0, 1) end
            pcall(function() hrp.CFrame = CFrame.new(part.Position + dir.Unit * 3) end)
            task.wait(0.12)
        end
        if prompt:IsA("ProximityPrompt") then
            pcall(function() prompt.HoldDuration = 0 end)
            pcall(function() prompt.MaxActivationDistance = 300 end)
            pcall(function() prompt:InputHoldBegin() end)
            task.delay(0.1, function() pcall(function() prompt:InputHoldEnd() end) end)
        elseif fireclickdetector then
            pcall(fireclickdetector, prompt)
        end
        task.delay(S.skyTime, function() hiding = false end)
        return
    end

    skyHide("无柜子")
end

pcall(function() RS:UnbindFromRenderStep("XHubSky") end)
RS:BindToRenderStep("XHubSky", Enum.RenderPriority.Last.Value - 2, function()
    if not skyHold then return end
    if os.clock() > skyHold.exp then skyHold = nil; return end
    local c = charOf(lp)
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = skyHold.cf
        pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
    end
end)

local function findHideSpot(maxDist)
    local c = charOf(lp)
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, nil end
    local best, bestD = nil, maxDist or 80
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("Model") or v:IsA("BasePart") then
            local nm = v.Name:lower()
            local hit = false
            for _, k in ipairs(HIDE_KW) do
                if nm:find(k, 1, true) then hit = true; break end
            end
            if hit then
                local part = v:IsA("BasePart") and v or v:FindFirstChildWhichIsA("BasePart", true)
                if part then
                    local d = (part.Position - hrp.Position).Magnitude
                    if d < bestD then best, bestD = part, d end
                end
            end
        end
    end
    return best, bestD
end

local hiding = false
local function hideNow()
    if hiding then return end
    hiding = true

    if S.hideMode == "sky" then
        -- 高空躲避: 抬到 Rush 够不到的高度,等它跑过去再落回
        local c = charOf(lp)
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if not hrp then hiding = false; return end
        local back = hrp.CFrame
        notify(("高空躲避: 抬升 %.0f studs，%d 秒后回落"):format(S.skyHeight, S.skyTime), "warn", 2.6)
        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.Anchored = true
            hrp.CFrame = back + Vector3.new(0, S.skyHeight, 0)
        end)
        task.delay(S.skyTime, function()
            local c2 = charOf(lp)
            local h2 = c2 and c2:FindFirstChild("HumanoidRootPart")
            if h2 then
                pcall(function()
                    h2.CFrame = back
                    h2.AssemblyLinearVelocity = Vector3.zero
                    h2.Anchored = false
                end)
            end
            notify("已落回原位", "info", 1.6)
            hiding = false
        end)
        return
    end

    -- 柜子模式
    local spot, d = findHideSpot(90)
    if not spot then
        notify("附近没找到柜子/床（可改用高空躲避）", "warn", 2.4)
        hiding = false
        return
    end
    notify(("自动躲避: 冲向 %s（%.0f m）"):format(spot.Parent and spot.Parent.Name or spot.Name, d or 0), "warn", 2.6)
    simWalk(spot.Position, 15)
    task.delay(1.0, function()
        pcall(autoPrompts, 9)
        task.delay(1.0, function()
            pcall(autoPrompts, 9)
            hiding = false
        end)
    end)
end

local HIDE_TRIGGER = { "rushmoving", "rush", "ambush", "seek", "glitch", "glitchcube", "cube", "dupe" }

task.spawn(function()
    local wasAlive = true
    while true do
        task.wait(0.5)
        local h = humOf(lp)
        local aliveNow = (h ~= nil) and (h.Health > 0)
        if wasAlive and not aliveNow then
            -- 刚死亡: 关飞行、交还相机、清 HUD 噪音
            if S.fly then setFly(false) end
            if S.thirdPerson then
                pcall(function() cam.CameraType = Enum.CameraType.Custom end)
            end
            notify("你已死亡：实体/物品不可见是正常的，复活后自动恢复", "warn", 4)
        elseif (not wasAlive) and aliveNow then
            if S.entityEsp then notify("已复活，实体绘制恢复", "ok", 2) end
        end
        wasAlive = aliveNow
    end
end)

local nearestTrigger

task.spawn(function()
    while true do
        task.wait(0.4)
        if S.autoHide then
            local name, d = nearestTrigger()
            if name and d <= S.hideDist then hideSmart(name) end
        end
    end
end)

--==================== 躲避触发扫描（不依赖 ESP，独立按名字找） ====================
local TRIGGER_STRICT = { "rushmoving", "rush", "ambush", "ambushmoving", "seekmovingnewclone", "seek", "glitch" }
local TRIGGER_ALL = { "rushmoving", "rush", "ambush", "ambushmoving",
                      "seek", "glitch", "glitchcube", "figure", "dupe" }

nearestTrigger = function()
    local c = charOf(lp)
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local list = S.hideOnlyRush and TRIGGER_STRICT or TRIGGER_ALL
    local bestD, bestN = math.huge, nil
    for _, m in ipairs(scanAll(3000)) do
        if m:IsA("Model") then
            local nm = m.Name:lower()
            local fake = nm:find("cube", 1, true) or nm:find("fake", 1, true) or nm:find("dupe", 1, true) or nm:find("clone", 1, true) and not nm:find("seek", 1, true)
            if not fake then
            for _, k in ipairs(list) do
                if nm:find(k, 1, true) then
                    local d = distTo(m)
                    if d and d < bestD then bestD, bestN = d, m.Name end
                    break
                end
            end
            end
        end
    end
    return bestN, bestD
end

--==================== A* 网格寻路（类似 Baritone 的思路） ====================
local NAV = { running = false, gen = 0, cell = 5, radius = 12 }
local navHud

local function navLog(txt)
    if not (navHud and navHud.Parent) then
        navHud = mk("TextLabel", { Name = "XHubNavLog", Size = UDim2.fromOffset(380, 84),
            Position = UDim2.new(0, 12, 0.5, 120), BackgroundTransparency = 0.25,
            BackgroundColor3 = Color3.fromRGB(14, 16, 22), Text = "", TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.Code, TextSize = 12,
            TextColor3 = Color3.fromRGB(170, 230, 255), ZIndex = 30 }, gui)
        local pad = mk("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 6) }, navHud)
    end
    navHud.Text = tostring(txt)
end

local function navParams()
    local p = RaycastParams.new()
    p.FilterType = Enum.RaycastFilterType.Exclude
    local list = { gui }
    local ch = charOf(lp)
    if ch then table.insert(list, ch) end
    p.FilterDescendantsInstances = list
    return p
end

local function sampleCell(x, z, yHint)
    local params = navParams()
    local hit = workspace:Raycast(Vector3.new(x, yHint + 8, z), Vector3.new(0, -26, 0), params)
    if not hit or hit.Normal.Y < 0.55 then return nil end
    local y = hit.Position.Y
    local up = workspace:Raycast(Vector3.new(x, y + 1.4, z), Vector3.new(0, 4.2, 0), params)
    if up then return nil end
    return y
end

local function navFindPath(startPos, goalPos)
    local cell, R = NAV.cell, NAV.radius
    local sx, sz = math.floor(startPos.X / cell), math.floor(startPos.Z / cell)
    local gx, gz = math.floor(goalPos.X / cell), math.floor(goalPos.Z / cell)
    local function kk(x, z) return x .. ":" .. z end
    local nodes, open, closed = {}, {}, {}
    local function node(x, z)
        local k = kk(x, z)
        if nodes[k] then return nodes[k] end
        local y = sampleCell(x * cell, z * cell, startPos.Y + 4)
        if not y then return nil end
        local n = { x = x, z = z, y = y, g = math.huge, f = math.huge, parent = nil }
        nodes[k] = n
        return n
    end
    local s = node(sx, sz)
    if not s then return nil end
    s.g = 0
    s.f = math.abs(sx - gx) + math.abs(sz - gz)
    open[1] = s
    local guard = 0
    while #open > 0 and guard < 3500 do
        guard = guard + 1
        local bi = 1
        for i = 2, #open do
            if open[i].f < open[bi].f then bi = i end
        end
        local cur = table.remove(open, bi)
        local ck = kk(cur.x, cur.z)
        if not closed[ck] then
            closed[ck] = true
            if cur.x == gx and cur.z == gz then
                local path, n = {}, cur
                while n do
                    table.insert(path, 1, Vector3.new(n.x * cell, n.y + 2.5, n.z * cell))
                    n = n.parent
                end
                return path
            end
            for dx = -1, 1 do
                for dz = -1, 1 do
                    if dx ~= 0 or dz ~= 0 then
                        local nx, nz = cur.x + dx, cur.z + dz
                        if math.abs(nx - sx) <= R and math.abs(nz - sz) <= R then
                            local nk = kk(nx, nz)
                            if not closed[nk] then
                                local n2 = node(nx, nz)
                                if n2 then
                                    local stepCost = (dx ~= 0 and dz ~= 0) and 1.414 or 1
                                    if math.abs(n2.y - cur.y) > 3 then stepCost = stepCost + 5 end
                                    local g = cur.g + stepCost
                                    if g < n2.g then
                                        n2.g = g
                                        n2.f = g + math.abs(nx - gx) + math.abs(nz - gz)
                                        n2.parent = cur
                                        open[#open + 1] = n2
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function navTo(pos)
    if NAV.running then
        NAV.gen = NAV.gen + 1
        NAV.running = false
    end
    local c, h = charOf(lp), humOf(lp)
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not (h and hrp) then
        notify("没有角色，无法寻路", "err", 3)
        return
    end
    navLog("A* 计算中…（射线采样网格）")
    notify("A* 计算中…", "info", 1.5)
    local path = navFindPath(hrp.Position, pos)
    if not path or #path == 0 then
        notify("A* 找不到路径 → 退回直线移动", "warn", 3)
        simWalk(pos, 25)
        return
    end
    NAV.running = true
    NAV.gen = NAV.gen + 1
    local gen = NAV.gen
    notify(("A* 成功: %d 个路点，开始移动"):format(#path), "ok", 2.5)
    navLog(("路点 %d 个，目标 (%.0f, %.0f)"):format(#path, pos.X, pos.Z))
    task.spawn(function()
        -- 不依赖 Humanoid:MoveTo（很多游戏每帧覆写移动），直接按合法速度 CFrame 推进
        local spd = math.max(12, math.min(S.walkSpeed or 16, 20))
        local i, t0 = 1, os.clock()
        while NAV.gen == gen and i <= #path and os.clock() - t0 < 90 do
            local c2, h2 = charOf(lp), humOf(lp)
            local hrp2 = c2 and c2:FindFirstChild("HumanoidRootPart")
            if not (hrp2 and h2) then break end
            local wp = path[i]
            local flat = Vector3.new(wp.X - hrp2.Position.X, 0, wp.Z - hrp2.Position.Z)
            if flat.Magnitude < 2.5 then
                i = i + 1
            else
                local mv = flat.Unit * math.min(spd * 0.03, flat.Magnitude)
                local np = hrp2.Position + mv
                local ny = math.max(np.Y, wp.Y - 2.5)
                pcall(function()
                    hrp2.CFrame = CFrame.new(Vector3.new(np.X, ny, np.Z))
                        * (hrp2.CFrame - hrp2.CFrame.Position)
                    hrp2.AssemblyLinearVelocity = Vector3.zero
                end)
                if os.clock() - t0 > 0.25 then
                    navLog(("路点 %d/%d · 距目标 %.0f · 剩余 %.0f studs")
                        :format(i, #path, (hrp2.Position - pos).Magnitude, flat.Magnitude))
                    t0 = os.clock()
                end
            end
            task.wait(0.03)
        end
        NAV.running = false
        navLog(("结束 · 剩余 %.0f studs"):format((pos - (charOf(lp) and charOf(lp):FindFirstChild("HumanoidRootPart").Position or pos)).Magnitude))
    end)
end

--==================== 场景物体绘制（柜子/床/抽屉，纯渲染，不计入实体） ====================
local SCENE_KW = { "closet", "wardrobe", "bed", "locker", "drawer", "dresser",
                   "crate", "柜", "床", "抽屉" }
local sceneStore = {}
local doorStore = {}
local leverStore = {}

local DOOR_BAD = { "frame", "blocked", "fake", "start", "end", "hidden", "lock", "doorway" }

local function isRealDoor(nm)
    if not (nm:find("door", 1, true) or nm:find("门", 1, true)) then return false end
    for _, k in ipairs(DOOR_BAD) do
        if nm:find(k, 1, true) then return false end
    end
    return true
end

local LEVER_KW = { "lever", "拉杆", "switch", "handle", "valve" }

local function isLever(nm)
    for _, k in ipairs(LEVER_KW) do
        if nm:find(k, 1, true) then return true end
    end
    return false
end

local function ensureLever(m)
    local o = leverStore[m]
    if not o then o = {}; leverStore[m] = o end
    if not (o.hl and o.hl.Parent) then
        o.hl = mk("Highlight", { Name = "XHubLever",
            FillColor = Color3.fromRGB(255, 60, 220), FillTransparency = 0.4,
            OutlineColor = Color3.fromRGB(255, 180, 245), OutlineTransparency = 0,
            DepthMode = Enum.HighlightDepthMode.AlwaysOnTop }, m)
    end
    o.hl.Parent = m
    local part = firstPart(m)
    if not part then return end
    if not (o.tag and o.tag.Parent) then
        o.tag = mk("BillboardGui", { Name = "XHubLeverTag", Size = UDim2.fromOffset(150, 26),
            AlwaysOnTop = true, Adornee = part, StudsOffset = Vector3.new(0, 1.6, 0) }, part)
        o.lbl = mk("TextLabel", { Text = "拉杆", BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 14), Font = Enum.Font.GothamBold, TextSize = 12,
            TextColor3 = Color3.fromRGB(255, 150, 240), TextStrokeTransparency = 0.3 }, o.tag)
        o.dlbl = mk("TextLabel", { Text = "", BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0, 12), Size = UDim2.new(1, 0, 0, 12),
            Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Color3.fromRGB(255, 220, 250),
            TextStrokeTransparency = 0.5 }, o.tag)
    end
    o.tag.Adornee = part
    o.tag.Parent = part
    local c = charOf(lp)
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if o.dlbl and hrp then
        o.dlbl.Text = ("%.0f m"):format((part.Position - hrp.Position).Magnitude)
    end
end

local function ensureScene(m)
    local o = sceneStore[m]
    if not o then o = {}; sceneStore[m] = o end
    if not (o.hl and o.hl.Parent) then
        o.hl = mk("Highlight", { Name = "XHubScene",
            FillColor = Color3.fromRGB(120, 255, 200), FillTransparency = 0.65,
            OutlineColor = Color3.fromRGB(190, 255, 230), OutlineTransparency = 0.2,
            DepthMode = Enum.HighlightDepthMode.AlwaysOnTop }, m)
    end
    o.hl.Parent = m
end

local function ensureDoor(m)
    local o = doorStore[m]
    if not o then o = {}; doorStore[m] = o end
    if not (o.hl and o.hl.Parent) then
        o.hl = mk("Highlight", { Name = "XHubDoor",
            FillColor = Color3.fromRGB(255, 205, 80), FillTransparency = 0.55,
            OutlineColor = Color3.fromRGB(255, 235, 160), OutlineTransparency = 0,
            DepthMode = Enum.HighlightDepthMode.AlwaysOnTop }, m)
    end
    o.hl.Parent = m
    local part = firstPart(m)
    if not part then return end
    if not o.cf0 then o.cf0 = part.CFrame end
    if not (o.tag and o.tag.Parent) then
        o.tag = mk("BillboardGui", { Name = "XHubDoorTag", Size = UDim2.fromOffset(160, 28),
            AlwaysOnTop = true, Adornee = part, StudsOffset = Vector3.new(0, 2, 0) }, part)
        o.lbl = mk("TextLabel", { Text = m.Name, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 14), Font = Enum.Font.GothamBold, TextSize = 12,
            TextColor3 = Color3.fromRGB(255, 220, 120), TextStrokeTransparency = 0.35 }, o.tag)
        o.dlbl = mk("TextLabel", { Text = "", BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0, 12), Size = UDim2.new(1, 0, 0, 12),
            Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Color3.fromRGB(255, 240, 200),
            TextStrokeTransparency = 0.5 }, o.tag)
    end
    o.tag.Adornee = part
    o.tag.Parent = part
    local c = charOf(lp)
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if o.dlbl and hrp then
        o.dlbl.Text = ("%.0f m"):format((part.Position - hrp.Position).Magnitude)
    end
end

task.spawn(function()
    while true do
        task.wait(S.fastScan and 1.2 or 0.5)
        if S.scenery or S.doors or S.lever then
            local c0 = charOf(lp)
            local hrp0 = c0 and c0:FindFirstChild("HumanoidRootPart")
            local n = 0
            for _, m in ipairs(scanAll(4000)) do
                if m:IsA("Model") then
                    n = n + 1
                    if n > 4000 then break end
                    local nm = m.Name:lower()
                    local d = hrp0 and distTo(m) or nil
                    if d and d > 90 then
                        -- 远处的不要，过会儿再处理
                    elseif S.doors and isRealDoor(nm) then
                        pcall(ensureDoor, m)
                    elseif S.lever and isLever(nm) then
                        pcall(ensureLever, m)
                        if S.leverAuto and d and d <= 14 then
                            local part = firstPart(m)
                            if part then
                                pcall(autoPrompts, 16)
                            end
                        end
                    elseif S.scenery then
                        for _, k in ipairs(SCENE_KW) do
                            if nm:find(k:lower(), 1, true) then
                                pcall(ensureScene, m)
                                break
                            end
                        end
                    end
                end
            end
            local dead = {}
            for m, o in pairs(sceneStore) do
                if not m.Parent then destroyEnt(o); dead[#dead + 1] = m end
            end
            for _, m in ipairs(dead) do sceneStore[m] = nil end
            local dead2 = {}
            for m, o in pairs(doorStore) do
                local p2 = m.Parent and firstPart(m)
                local opened = false
                if o.cf0 and p2 then
                    if p2.CFrame.LookVector:Dot(o.cf0.LookVector) < 0.94 then opened = true end
                    if (p2.Position - o.cf0.Position).Magnitude > 3 then opened = true end
                end
                if (not m.Parent) or opened then destroyEnt(o); dead2[#dead2 + 1] = m end
            end
            for _, m in ipairs(dead2) do doorStore[m] = nil end
            local dead3 = {}
            for m, o in pairs(leverStore) do
                if not m.Parent then destroyEnt(o); dead3[#dead3 + 1] = m end
            end
            for _, m in ipairs(dead3) do leverStore[m] = nil end
        end
        if not S.scenery and next(sceneStore) ~= nil then
            for _, o in pairs(sceneStore) do destroyEnt(o) end
            sceneStore = {}
        end
        if not S.doors and next(doorStore) ~= nil then
            for _, o in pairs(doorStore) do destroyEnt(o) end
            doorStore = {}
        end
        if not S.lever and next(leverStore) ~= nil then
            for _, o in pairs(leverStore) do destroyEnt(o) end
            leverStore = {}
        end
    end
end)

--==================== 刷新即时捕获 + 声音线索（放在所有定义之后） ====================
local SOUND_HINT = { "rush", "ambush", "seek", "figure", "screech" }

workspace.DescendantAdded:Connect(function(d)
    if d:IsA("Model") and S.entityEsp and isEntityModel(d) then
        task.defer(function() if d.Parent then pcall(ensureEnt, d) end end)
    end
    if (d:IsA("Tool") or d:IsA("Model")) and S.itemEsp and isItemInst(d) then
        task.defer(function() if d.Parent then pcall(ensureItem, d) end end)
    end
    if d:IsA("Model") then
        local nm2 = d.Name:lower()
        if S.doors and isRealDoor(nm2) then pcall(ensureDoor, d) end
        if S.lever and isLever(nm2) then pcall(ensureLever, d) end
        if S.scenery then
            for _, k in ipairs(SCENE_KW) do
                if nm2:find(k:lower(), 1, true) then pcall(ensureScene, d); break end
            end
        end
    end
    if d:IsA("Sound") then
        local sn = d.Name:lower()
        for _, k in ipairs(SOUND_HINT) do
            if sn:find(k, 1, true) then
                notify(("声音线索: %s"):format(d.Name), "warn", 3)
                if S.autoHide then pcall(hideSmart, d.Name) end
                break
            end
        end
    end
end)

--==== NPC / 怪物 ESP（独立模块：方框 + 名字 + 血量 + 距离） ====
local npcStore = {}

local function ensureNpcEsp(m)
    local o = npcStore[m]
    if not o then o = {}; npcStore[m] = o end
    if not (o.hl and o.hl.Parent) then
        o.hl = mk("Highlight", { Name = "XHubNpcEsp",
            FillColor = Color3.fromRGB(90, 255, 120), FillTransparency = 0.75,
            OutlineColor = Color3.fromRGB(190, 255, 200), OutlineTransparency = 0,
            DepthMode = Enum.HighlightDepthMode.AlwaysOnTop }, m)
    end
    o.hl.Parent = m
    local head = m:FindFirstChild("Head") or m:FindFirstChild("HumanoidRootPart", true)
                  or m:FindFirstChildWhichIsA("BasePart", true)
    if not head then return end
    if not (o.tag and o.tag.Parent) then
        o.tag = mk("BillboardGui", { Name = "XHubNpcEspTag", Size = UDim2.fromOffset(200, 54),
            AlwaysOnTop = true, Adornee = head, StudsOffset = Vector3.new(0, 2.6, 0) }, head)
        o.box = mk("Frame", { Size = UDim2.fromOffset(38, 58), Position = UDim2.new(0.5, -19, 0.5, -29),
            BackgroundTransparency = 1, BorderSizePixel = 2,
            BorderColor3 = Color3.fromRGB(140, 255, 150) }, o.tag)
        o.lbl = mk("TextLabel", { Text = m.Name, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 15), Font = Enum.Font.GothamBold, TextSize = 12,
            TextColor3 = Color3.fromRGB(160, 255, 180), TextStrokeTransparency = 0.3 }, o.tag)
        o.dlbl = mk("TextLabel", { Text = "", BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0, 13), Size = UDim2.new(1, 0, 0, 13),
            Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Color3.fromRGB(220, 255, 225),
            TextStrokeTransparency = 0.5 }, o.tag)
    end
    o.tag.Adornee = head
    o.tag.Parent = head
    local hum = m:FindFirstChildOfClass("Humanoid")
    local hp = hum and math.floor(hum.Health) or 0
    if o.lbl then o.lbl.Text = m.Name end
    if o.dlbl then
        local d = distTo(m)
        o.dlbl.Text = d and ("HP %d · %.0f m"):format(hp, d) or ("HP %d"):format(hp)
    end
end

task.spawn(function()
    while true do
        task.wait(S.fastScan and 0.8 or 0.4)
        if S.espNpc then
            local n = 0
            for _, m in ipairs(scanAll(4000)) do
                if m:IsA("Model") and not Players:GetPlayerFromCharacter(m) then
                    n = n + 1
                    if n > 4000 then break end
                    if m:FindFirstChildOfClass("Humanoid") then
                        pcall(ensureNpcEsp, m)
                    end
                end
            end
            local dead = {}
            for m, o in pairs(npcStore) do
                if not m.Parent then destroyEnt(o); dead[#dead + 1] = m end
            end
            for _, m in ipairs(dead) do npcStore[m] = nil end
        elseif next(npcStore) ~= nil then
            for _, o in pairs(npcStore) do destroyEnt(o) end
            npcStore = {}
        end
    end
end)
--==== 遇到 Eyes 自动背对（把角色朝向转成背对它） ====
task.spawn(function()
    local locked = false
    while true do
        task.wait(0.08)
        if S.eyesAway then
            local c, h = charOf(lp), humOf(lp)
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            local best, bestD = nil, 200
            if hrp then
                for _, m in ipairs(scanAll(2500)) do
                    if m:IsA("Model") and m.Name:lower():find("eyes", 1, true) then
                        local d = distTo(m)
                        if d and d < bestD then bestD, best = d, m end
                    end
                end
            end
            if best and hrp then
                if h and not locked then
                    pcall(function() h.AutoRotate = false end)
                    locked = true
                end
                local p = firstPart(best)
                if p then
                    local away = hrp.Position - p.Position
                    away = Vector3.new(away.X, 0, away.Z)
                    if away.Magnitude > 0.1 then
                        pcall(function()
                            hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + away.Unit)
                        end)
                    end
                end
            elseif locked then
                if h then pcall(function() h.AutoRotate = true end) end
                locked = false
            end
        elseif locked then
            local h = humOf(lp)
            if h then pcall(function() h.AutoRotate = true end) end
            locked = false
        end
    end
end)

--==================== 页面 ====================
local pMain, pVisual = addPage("主要"), addPage("视觉")
local pCombat, pAuto = addPage("战斗"), addPage("自动")
local pGuard = addPage("防护")
local pMisc = addPage("杂项")

addSection(pMain, "MOVEMENT")
addToggle(pMain, "飞行 (F)", false, function(v) setFly(v) end)
addSlider(pMain, "飞行速度", 10, 200, S.flySpeed, function(v) S.flySpeed = v end)
local setModeBtn
setModeBtn = addButton(pMain, "飞行模式: " .. (S.flyMode == "cframe" and "CFrame" or "物理"), function()
    S.flyMode = (S.flyMode == "cframe") and "body" or "cframe"
    setModeBtn("飞行模式: " .. (S.flyMode == "cframe" and "CFrame（防拉回更好）" or "物理 BodyVelocity"))
    if S.fly then setFly(false); setFly(true) end
    notify("飞行模式 = " .. S.flyMode, "info", 1.6)
end)
addToggle(pMain, "反拉回（被拉回自动降速）", true, function(v) S.antiSnap = v end)
addToggle(pMain, "安全模式（禁飞/禁加速，只留视觉）", false, function(v)
    S.safeMode = v
    if v and S.fly then setFly(false) end
    notify(v and "安全模式: 位移类功能已禁用" or "安全模式: 已关闭", v and "warn" or "info", 2.5)
end)
addToggle(pMain, "自动调参（实测该服速度上限）", true, function(v) S.autoTune = v end)
addToggle(pMain, "幽灵位移（伪装走速 + 脉冲前进）", false, function(v)
    S.ghost = v
    notify(v and "幽灵位移: 走速锁定 16,位移改为脉冲" or "幽灵位移: 已关闭", "info", 2.5)
end)
addToggle(pMain, "脉冲位移（每 0.6s 走 0.36s）", false, function(v) S.pulse = v end)
addSlider(pMain, "走路速度（服务端容忍≈16-22）", 16, 60, S.walkSpeed, function(v) S.walkSpeed = v end)
addToggle(pMain, "穿墙 Noclip（不改速度,不触发回弹）", false, function(v) setNoclip(v) end)
addSection(pMain, "菜单背景")
addToggle(pMain, "压暗游戏背景", true, function(v)
    S.dim = v
    if backdrop then backdrop.Visible = main.Visible and v end
end)
addSlider(pMain, "背景不透明度 %", 0, 90, 50, function(v)
    S.bgA = v / 100
    if backdrop then backdrop.BackgroundTransparency = 1 - S.bgA end
end)
addToggle(pMain, "背景模糊 (BlurEffect)", false, function(v)
    S.blur = v
    if blurFx then blurFx.Size = v and 14 or 0; blurFx.Enabled = v and main.Visible end
end)
addSection(pMain, "HUB")
local setKeyBtn = addButton(pMain, "菜单键: " .. CONFIG.MenuKeys[1].Name .. " (点我改键)", function()
    captureMode = true
    setKeyBtn("菜单键: 请按键…（Esc 取消）")
end)
addButton(pMain, "隐藏菜单", function() setVisible(false) end)

addSection(pVisual, "ESP")
addToggle(pVisual, "启用 ESP", false, function(v)
    S.esp = v
    notify("ESP " .. (v and "开" or "关"), v and "ok" or "info", 1.4)
end)
addToggle(pVisual, "方框高亮", true, function(v) S.espBox = v end)
addToggle(pVisual, "名字", true, function(v) S.espName = v end)
addToggle(pVisual, "血量条", true, function(v) S.espHp = v end)
addToggle(pVisual, "距离", true, function(v) S.espDist = v end)
addToggle(pVisual, "显示队友", false, function(v) S.espTeam = v end)
addToggle(pVisual, "NPC / 怪物 ESP", false, function(v)
    S.espNpc = v
    notify(v and "NPC ESP 已开启（方框+名字+血量+距离）" or "NPC ESP 已关闭", "info", 2.2)
end)
addToggle(pVisual, "穿墙可见", true, function(v) S.espOccluded = v end)
addToggle(pVisual, "彩虹上色", false, function(v) S.espRainbow = v end)
addSection(pVisual, "环境")
addToggle(pVisual, "夜视（提亮+去雾，纯客户端）", false, function(v) setNight(v) end)
if doorsAllowed() then
addToggle(pVisual, "场景物体绘制（柜子/床/抽屉，青色）", false, function(v)
    S.scenery = v
    notify(v and "场景绘制: 柜子/床/抽屉 会亮青色（纯渲染）" or "场景绘制已关闭", "info", 2.4)
end)
addToggle(pVisual, "门绘制（门/门框，金色 + 距离）", false, function(v)
    S.doors = v
    notify(v and "门绘制: 门会亮金色并显示名字/距离" or "门绘制已关闭", "info", 2.4)
end)
addToggle(pVisual, "拉杆绘制 + 距离（洋红）", false, function(v)
    S.lever = v
    notify(v and "拉杆绘制已开启（lever/switch/拉杆）" or "拉杆绘制已关闭", "info", 2.4)
end)
addToggle(pVisual, "自动拉杆（靠近自动点 E）", false, function(v)
    S.leverAuto = v
    notify(v and "自动拉杆: 14 studs 内会自动触发提示" or "自动拉杆已关闭", "info", 2.4)
end)
addToggle(pVisual, "遇到 Eyes 自动背对", true, function(v) S.eyesAway = v end)
end
addToggle(pVisual, "实体绘制（怪物/NPC/Entity）", false, function(v)
    S.entityEsp = v
    notify(v and "实体绘制已开启（关键词 + 非玩家 Humanoid）" or "实体绘制已关闭", "info", 2.5)
end)
addToggle(pVisual, "实体刷新提示（弹出名字+距离）", true, function(v) S.entNotify = v end)
addToggle(pVisual, "屏幕顶部显示最近实体距离", true, function(v)
    S.hudNearest = v
    if not v and entHud then entHud.Visible = false end
end)
addToggle(pVisual, "实体上色（按名字分配颜色）", true, function(v)
    S.entColor = v
    for m, o in pairs(entStore) do
        if o.hl then o.hl.FillColor = entColorFor(m.Name) end
    end
end)
addSection(pVisual, "视角")
addToggle(pVisual, "强制第三人称", false, function(v) setThirdPerson(v) end)
local setTpModeBtn
setTpModeBtn = addButton(pVisual, "第三人称模式: 变焦锁定", function()
    S.tpMode = (S.tpMode == "zoom") and "orbit" or "zoom"
    setTpModeBtn("第三人称模式: " .. (S.tpMode == "zoom" and "变焦锁定" or "脚本相机"))
    if S.thirdPerson then setThirdPerson(false); task.wait(0.1); setThirdPerson(true) end
    notify("模式 = " .. S.tpMode, "info", 1.6)
end)
addToggle(pVisual, "第三人称 Y 轴反转", true, function(v) S.invertY = v end)
addButton(pVisual, "恢复默认视角", function() setThirdPerson(false) end)
addSection(pVisual, "性能")
addToggle(pVisual, "优化模式（降低扫描频率）", true, function(v)
    S.fastScan = v
    notify(v and "优化模式: 实体 1.0s / 物品 1.5s 扫描" or "优化模式关闭: 扫描更频繁（更卡）", "info", 2.4)
end)
addButton(pVisual, "诊断扫描（F9 + 弹窗）", function()
    local wsKids = #workspace:GetChildren()
    local cr = workspace:FindFirstChild("CurrentRooms")
    local list = scanAll(6000)
    local mcount, hits = 0, 0
    print(("[dbg] workspace 子对象=%d  CurrentRooms=%s  扫描=%d")
        :format(wsKids, tostring(cr ~= nil), #list))
    local shown = 0
    for _, d in ipairs(list) do
        if d:IsA("Model") then
            mcount = mcount + 1
            if shown < 12 then
                shown = shown + 1
                print(("[dbg] model: %s"):format(d.Name))
            end
        end
        local nm = d.Name:lower()
        if nm:find("rush", 1, true) or nm:find("ambush", 1, true)
           or nm:find("seek", 1, true) or nm:find("figure", 1, true) then
            hits = hits + 1
            if hits <= 20 then
                print(("[dbg] 命中: %s  (%s)"):format(d:GetFullName(), d.ClassName))
            end
        end
    end
    print(("[dbg] Model=%d  名字命中=%d"):format(mcount, hits))
    notify(("ws=%d CR=%s 扫=%d M=%d 命中=%d")
        :format(wsKids, cr and "有" or "无", #list, mcount, hits), "info", 5)
end)

addToggle(pCombat, "远程改写：宽松模式（所有带方向的远程都改）", false, function(v)
    S.remoteAimAll = v
    notify(v and "宽松改写已开（可能影响交互类远程，谨慎）" or "宽松改写已关（只改武器类远程）", "warn", 3)
end)
addButton(pCombat, "开火探针（15 秒，输出到 F9）", function()
    S.remoteProbe = true
    notify("探针已开 15 秒：现在开一枪，把 F9 里的 [probe] 行发我", "ok", 4)
    task.delay(15, function()
        S.remoteProbe = false
        notify("探针已关闭", "info", 1.6)
    end)
end)
addToggle(pCombat, "远程弹道改写（静默/子弹追踪真正生效的关键）", true, function(v)
    S.remoteAim = v
    notify(v and "远程改写已开：开火时把方向类参数改成对准目标" or "远程改写已关（只有视角变化，命中不受影响）", v and "ok" or "warn", 3)
end)

addSection(pCombat, "子弹追踪（独立功能，不需要自瞄）")
addToggle(pCombat, "开火自动对准目标（250ms）", false, function(v)
    S.btStandalone = v
    notify(v and "子弹追踪已开：每次开火自动对准一次" or "子弹追踪已关闭", "info", 2.6)
end)

addSection(pCombat, "AIMBOT")
addToggle(pCombat, "启用自瞄", false, function(v)
    S.aim = v
    notify("自瞄 " .. (v and "开" or "关"), v and "ok" or "info", 1.4)
end)
addToggle(pCombat, "子弹追踪（开火瞬间对准头部）", false, function(v) S.bulletTrack = v end)
addToggle(pCombat, "静默瞄准（视角不动，只改开火方向）", false, function(v)
    S.silentAim = v
    notify(v and "静默瞄准已开：开火瞬间改写相机方向，随后立刻恢复" or "静默瞄准已关闭", "info", 2.6)
end)
addSlider(pCombat, "静默改写时长 ×0.01s（9 = 90ms）", 3, 20, 9, function(v) S.silentTime = v / 100 end)
addToggle(pCombat, "左键开火时自瞄", true, function(v) S.aimOnFire = v end)
addToggle(pCombat, "瞄准队友", false, function(v) S.aimTeam = v end)
addToggle(pCombat, "瞄准 NPC / 怪物", false, function(v)
    S.aimNpc = v
    notify(v and "自瞄已包含 NPC/怪物" or "自瞄只锁玩家", "info", 2.2)
end)
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

rowOrder = rowOrder + 1
aimInfo = mk("TextLabel", { Text = "自瞄: 待触发（按住左键 / Q）", BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 20), Font = Enum.Font.Code, TextSize = 11,
    TextColor3 = Color3.fromRGB(150, 210, 180), TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = rowOrder }, pCombat)

if doorsAllowed() then
addSection(pAuto, "物品")
addToggle(pAuto, "物品绘制（钥匙 / 道具 / 箱子）", false, function(v)
    S.itemEsp = v
    notify(v and "物品绘制已开启" or "物品绘制已关闭", "info", 2)
end)
addToggle(pAuto, "范围拾取（touch 模拟）", false, function(v) S.pickup = v end)
addSlider(pAuto, "拾取半径", 5, 60, S.pickupRadius, function(v) S.pickupRadius = v end)
addSlider(pAuto, "拾取间隔 ×0.01s（12 = 0.12s）", 5, 50, 12, function(v) S.pickupInterval = v / 100 end)

addSection(pAuto, "交互")
addToggle(pAuto, "自动交互（ProximityPrompt）", false, function(v) S.autoPrompt = v end)
addSlider(pAuto, "交互半径", 5, 40, S.promptRadius, function(v) S.promptRadius = v end)
addToggle(pAuto, "瞬间交互（去掉长按）", true, function(v) S.instantPrompt = v end)
addToggle(pAuto, "自动开门（Door.ClientOpen）", false, function(v) S.autoDoor = v end)
addSlider(pAuto, "开门半径", 5, 50, S.doorRadius, function(v) S.doorRadius = v end)

addSection(pAuto, "躲避")
addToggle(pAuto, "遇到实体自动躲", false, function(v)
    S.autoHide = v
    notify(v and "自动躲避已开启（按当前模式执行）" or "自动躲避已关闭", "info", 2.4)
end)
local setHideModeBtn
setHideModeBtn = addButton(pAuto, "躲避方式: 高空传送", function()
    S.hideMode = (S.hideMode == "sky") and "closet" or "sky"
    setHideModeBtn("躲避方式: " .. (S.hideMode == "sky" and "高空传送" or "柜子/床"))
    notify("躲避方式 = " .. S.hideMode, "info", 1.6)
end)
addSlider(pAuto, "触发距离", 30, 200, S.hideDist, function(v) S.hideDist = v end)
addToggle(pAuto, "只对 Rush/Ambush/Seek 触发", true, function(v) S.hideOnlyRush = v end)
addSlider(pAuto, "高空高度 studs", 50, 800, S.skyHeight, function(v) S.skyHeight = v end)
addSlider(pAuto, "高空停留 秒", 3, 20, S.skyTime, function(v) S.skyTime = v end)
local setPreferBtn
setPreferBtn = addButton(pAuto, "躲避策略: 自动(Rush钻柜/Seek升空)", function()
    if S.hidePrefer == "auto" then
        S.hidePrefer = "sky"
    elseif S.hidePrefer == "sky" then
        S.hidePrefer = "closet"
    else
        S.hidePrefer = "auto"
    end
    local txt = ({ auto = "自动(Rush钻柜/Seek升空)", sky = "全部高空", closet = "全部钻柜" })[S.hidePrefer]
    setPreferBtn("躲避策略: " .. txt)
    notify("躲避策略 = " .. S.hidePrefer, "info", 2)
end)

addButton(pAuto, "A* 寻路到最近的门", function()
    local pos, d = nearestDoorPos()
    if not pos then return notify("没找到名字含 door 的对象", "err", 3) end
    notify(("A* 目标: 最近的门的 (%.0f studs)"):format(d or 0), "info", 2)
    navTo(pos)
end)
end
addSection(pAuto, "寻路")
addButton(pAuto, "停止寻路", function()
    stopWalk()
    notify("已停止寻路", "info", 1.5)
end)

--==== 位移限速器：把 0.6 秒内的位移硬压在该服容忍值以内（服务端永远看不到异常速度） ====
local govHist = {}
task.spawn(function()
    while true do
        task.wait(0.08)
        if S.govEnabled and not isSeated() then
            local c = charOf(lp)
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            if hrp then
                local now, p = os.clock(), hrp.Position
                govHist[#govHist + 1] = { t = now, p = p }
                while #govHist > 0 and now - govHist[1].t > (S.govWindow or 0.6) do
                    table.remove(govHist, 1)
                end
                local first = govHist[1]
                if first then
                    local delta = p - first.p
                    local maxD = S.govMax or 12
                    if delta.Magnitude > maxD then
                        local target = first.p + delta.Unit * maxD
                        pcall(function()
                            hrp.CFrame = CFrame.new(target) * (hrp.CFrame - hrp.CFrame.Position)
                            hrp.AssemblyLinearVelocity = Vector3.zero
                        end)
                    end
                end
            end
        elseif #govHist > 0 then
            govHist = {}
        end
    end
end)

addSection(pGuard, "① 基础压制")
addButton(pGuard, "圣奥里安全预设（限速 + 关飞行 + 开①③）", function()
    S.safeMode = true
    S.fly = false
    S.walkSpeed = 16
    S.govEnabled = true
    S.govMax = 12
    S.govWindow = 0.6
    S.autoHide = false
    S.doors = false
    S.lever = false
    pcall(function() if S.fly then setFly(false) end end)
    pcall(function() h = humOf(lp); if h then h.WalkSpeed = 16 end end)
    notify("圣奥里预设: 位移限速 12 studs/0.6s · 飞行关 · 走速 16", "ok", 4)
    notify("AC: 只建议开①③；②会掐车辆/起身；飞行会被 600 封禁", "warn", 4)
end)
addToggle(pGuard, "位移限速器（0.6s 内最多走 12 studs）", false, function(v)
    S.govEnabled = v
    notify(v and "限速器开启：任何速度类功能都会被压在服务端容忍内" or "限速器已关闭（飞行/加速不再被限制）",
        v and "ok" or "warn", 3)
end)
addSlider(pGuard, "限速窗口内允许位移 studs", 6, 40, 12, function(v) S.govMax = v end)
addToggle(pGuard, "线程 + 连接 + marker", false, function(v) if v then acRun() end end)
addButton(pGuard, "重新执行基础压制", function() acRun() end)

addSection(pGuard, "② 检测层（只动 AC 的渲染/心跳回调）")
addToggle(pGuard, "挂钩 AC 回调 / 杀线程", false, function(v)
    G.layer1 = v
    if v then
        local c, t, h = runLayer1()
        notify(("检测层: 连接 %d / 线程 %d / 闭包 %d"):format(c, t, h), "ok", 3)
    end
end)

addSection(pGuard, "③ 通道层（只切上行，不动 Connect）")
addToggle(pGuard, "切断上报 + 拦本地踢人", false, function(v)
    G.layer2 = v; G.blockKick = v
    if v then
        local n = runLayer2()
        notify(("通道层: remote %d / blocked %d"):format(n, G.blocked), "ok", 3)
    end
end)

addSection(pGuard, "哈希搜索")
local hashBox = addBox(pGuard, "输入 AntiCheat / 混淆名", "AntiCheat")
addButton(pGuard, "哈希搜索 + 挂钩", function()
    local c, t, h, n = hashSearch(hashBox.Text)
    notify(("搜索 %s → 连接 %d / 线程 %d / 闭包 %d / remote %d")
        :format(hashBox.Text, c, t, h, n), "ok", 3)
end)
addButton(pGuard, "只加入哈希表", function()
    CONFIG.ACG.Hashes[hash(hashBox.Text)] = true
    notify(("hash(%s) = %d 已加入"):format(hashBox.Text, hash(hashBox.Text)), "ok", 2.5)
end)
addButton(pGuard, "列出匹配到 F9", function()
    print(("=== ACG matches (%d) ==="):format(#G.matches))
    for _, m in ipairs(G.matches) do print(m) end
    notify(("已打印 %d 条"):format(#G.matches), "info", 2)
end)

addSection(pGuard, "远程拦截（按名字）")
local remoteBox = addBox(pGuard, "例如 MotorReplication / Report / AntiCheat", "MotorReplication")
addButton(pGuard, "拦截匹配的 FireServer/InvokeServer", function()
    local n = blockRemoteSubstr(remoteBox.Text)
    notify(("已拦截 %d 个远程（匹配 %s）"):format(n, remoteBox.Text),
        n > 0 and "ok" or "warn", 3)
end)

addSection(pGuard, "THREAD CLEANER")
addButton(pGuard, "打开线程面板", function() tcShow() end)
addButton(pGuard, "快速杀 BS_", function()
    TC.all = tcCollect()
    local k, m = tcKill("BS_")
    notify(("BS_ 匹配 %d / 终止 %d"):format(m, k), k > 0 and "ok" or "warn", 3)
end)
addButton(pGuard, "列出全部线程到 F9", function()
    TC.all = tcCollect(); tcDump()
    notify(("已打印 %d 个线程"):format(#TC.all), "info", 2)
end)

addSection(pGuard, "输入急救")
addButton(pGuard, "修复车辆/疾跑按键", function() repairInput(true) end)
addButton(pGuard, "还原 ACG 钩子 + 输入", function()
    acgRestore()
    repairInput(true)
    notify("已还原 __namecall 与所有被改动的回调", "ok", 3)
end)

addSection(pGuard, "车辆 / 角色")
addToggle(pGuard, "车辆安全模式（上下车暂停/恢复绕过）", true, function(v)
    S.vehicleSafe = v
end)
addToggle(pGuard, "防遁地守护（陷地自动抬回）", false, function(v)
    S.antiFall = v
end)
addButton(pGuard, "角色复位（起身/解焊/抬升）", function() characterFix(false) end)
addButton(pGuard, "打印 AC 脚本全名到 F9", function()
    local by = collectScripts()
    local n = 0
    for k in pairs(by) do n = n + 1 end
    for _, m in ipairs(G.matches) do print(m) end
    notify(("匹配 %d 个标识 / %d 条记录（见 F9）"):format(n, #G.matches), "info", 3)
end)

addSection(pMisc, "服务器档位")
addButton(pMisc, "打印 PlaceId / 识别结果", function()
    print(("[profile] PlaceId=%d  JobId=%s  识别=%s")
        :format(game.PlaceId, tostring(game.JobId), currentProfileKey))
    notify(("PlaceId %d · 档位 %s"):format(game.PlaceId, PROFILES[currentProfileKey].label), "info", 4)
end)
addToggle(pMisc, "强制启用 DOORS 专属模块（门/拉杆/Eyes/躲避）", false, function(v)
    S.forceDoors = v
    notify(v and "已强制启用 DOORS 模块（任何服务器都会跑）" or "已恢复：非 DOORS 服务器关闭 DOORS 模块", v and "warn" or "info", 3)
end)
local setProfileBtn
setProfileBtn = addButton(pMisc, "当前档位: " .. PROFILES[currentProfileKey].label, function()
    local order = { "doors", "sanAurie", "default" }
    local i = 1
    for k, v in ipairs(order) do if v == currentProfileKey then i = k end end
    local p = applyProfile(order[(i % #order) + 1])
    setProfileBtn("当前档位: " .. p.label)
    notify(("已切换档位: %s"):format(p.label), "ok", 3)
    notify(p.tip, "info", 5)
end)

addSection(pMisc, "角色")
addButton(pMisc, "自杀 / 重生", function() suicide() end)
addSection(pMisc, "服务器")
addButton(pMisc, "重进本服 (同 JobId)", function() rejoinHere() end)
addButton(pMisc, "换一个新服务器", function() newServer() end)
addSection(pMisc, "其他")
addButton(pMisc, "卸载并恢复全部", function()
    setFly(false); S.esp = false; S.aim = false
    acgRestore(); repairInput(false)
    for _, o in pairs(espStore) do destroyESP(o) end
    espStore = {}
    pcall(function() RS:UnbindFromRenderStep("XHubAim") end)
    if blurFx then blurFx:Destroy() end
    if notifHolder then notifHolder:Destroy() end
    gui:Destroy()
end)
addSection(pMisc, "信息")
rowOrder = rowOrder + 1
mk("TextLabel", { Text = ("版本: %s (%s)   执行器: %s"):format(VERSION, BUILD,
    (identifyexecutor and identifyexecutor()) or "unknown"),
    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), Font = Enum.Font.Code,
    TextSize = 11, TextColor3 = Color3.fromRGB(160, 200, 180), LayoutOrder = rowOrder }, pMisc)
rowOrder = rowOrder + 1
mk("TextLabel", { Text = "白名单: 车辆/输入/疾跑/相机 永不触碰\n通道层只切 FireServer,不拦 Connect",
    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Font = Enum.Font.Gotham,
    TextSize = 10, TextColor3 = Color3.fromRGB(140, 148, 162), TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = rowOrder }, pMisc)

-- 菜单打开时每帧把鼠标交还出来（游戏通常在相机回调里锁回去，必须抢在它后面）
pcall(function() RS:UnbindFromRenderStep("XHubMouse") end)
RS:BindToRenderStep("XHubMouse", Enum.RenderPriority.Last.Value - 1, function()
    if not main.Visible then return end
    if UIS.MouseBehavior ~= Enum.MouseBehavior.Default then
        pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.Default end)
    end
    if not UIS.MouseIconEnabled then
        pcall(function() UIS.MouseIconEnabled = true end)
    end
end)

task.spawn(function()
    while true do
        task.wait(0.25)
        if main.Visible then
            if UIS.MouseBehavior ~= Enum.MouseBehavior.Default then
                pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.Default end)
            end
            if not UIS.MouseIconEnabled then
                pcall(function() UIS.MouseIconEnabled = true end)
            end
        end
    end
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
            notify("改键已取消", "warn", 2)
        else
            CONFIG.MenuKeys = { i.KeyCode }
            setKeyBtn("菜单键: " .. i.KeyCode.Name .. " (点我改键)")
            notify("菜单键 = " .. i.KeyCode.Name, "ok", 2)
        end
        return
    end
    if isMenuKey(i.KeyCode) then
        setVisible(not main.Visible)
    elseif i.KeyCode == CONFIG.FlyKey and not gp then
        setFly(not S.fly)
        if not S.fly then notify("飞行已关闭", "info", 1.2) end
    end
end)

setVisible(false, true)
task.delay(0.2, function() setVisible(true, true) end)
notify("XHub " .. VERSION .. " 已加载", "ok", 3)
task.delay(0.4, function()
    notify(("档位: %s"):format(PROFILES[currentProfileKey].label), "ok", 4)
    notify(PROFILES[currentProfileKey].tip, "info", 5)
end)
if S.noclip then
    task.delay(0.6, function() pcall(function() setNoclip(true) end) end)
end
print(("[XHub] %s (build %s) loaded · 6 页 · 菜单键 %s · 档位=%s (PlaceId=%d)"):format(
    VERSION, BUILD, CONFIG.MenuKeys[1].Name, currentProfileKey, game.PlaceId))
