--=====================================================================
--  XHub v4.1 · Fly / ESP / Aimbot / AC压制 / AC-Guard / ThreadCleaner
--  菜单键 RightShift/Insert/F2 · F 飞行 · Q 瞄准 · 右上角通知
--  v4.1: 检测层改为“只动 AC 自己的渲染/心跳回调”,不再全量挂钩,并带输入自动回滚
--=====================================================================
local VERSION = "v13.4"
local BUILD   = "2026-11-02 19:40"

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

local M = {}                  -- namespace (keeps register count under Luau limit)
local UIKEYS = {}             -- UI refs used outside the protected page build
local RUNNING = true          -- shutdown flag
local shutdownXHub            -- forward decl (UI button references it)
_G.XHubKill = function() end   -- 占位，稍后赋值
pcall(function()
    if _G.XHubKill then pcall(_G.XHubKill) end
    -- ① 让旧实例自己优雅退出
    if _G.XHub and type(_G.XHub) == "table" and _G.XHub.shutdown then
        _G.XHub.shutdown()
        task.wait(0.2)
    end

    -- ② 兜底：清掉旧实例可能残留的 GUI（即使 shutdown 没跑成功）
    local targets = {}
    pcall(function() table.insert(targets, game:GetService("CoreGui")) end)
    pcall(function() table.insert(targets, Players.LocalPlayer:FindFirstChild("PlayerGui")) end)
    for _, cont in ipairs(targets) do
        if cont then
            for _, g in ipairs(cont:GetChildren()) do
                if g:IsA("ScreenGui") and tostring(g.Name):find("XHub") then
                    pcall(function() g:Destroy() end)
                end
            end
        end
    end

    -- ③ 兜底：清掉残留的 Highlight / Billboard
    local n = 0
    for _, d in ipairs(workspace:GetDescendants()) do
        n = n + 1
        if n > 6000 then break end
        if (d:IsA("Highlight") or d:IsA("BillboardGui") or d:IsA("TextLabel") and d.Parent == nil) then
            local nm = tostring(d.Name)
            if nm:find("XHub") then pcall(function() d:Destroy() end) end
        end
    end
end)
local Players, RS = game:GetService("Players"), game:GetService("RunService")
local UIS, CoreGui = game:GetService("UserInputService"), game:GetService("CoreGui")
local RStorage, SC = game:GetService("ReplicatedStorage"), game:GetService("ScriptContext")
local Lighting, TweenService = game:GetService("Lighting"), game:GetService("TweenService")
local lp, cam = Players.LocalPlayer, workspace.CurrentCamera

local S = {
    fly = false, flySpeed = 55,
    esp = false, espBox = true, espName = true, espHp = true, espDist = true,
    espTeam = false, espOccluded = true, espRainbow = false,
    aim = false, aimSmooth = 12, aimFov = 140, bulletTrack = false, silentAim = false, silentTime = 0.09, aimNpc = false, espNpc = false, flyGov = true, btStandalone = false, remoteAim = false, remoteAimSafe = true, remoteAimAll = false, remoteProbe = false, silentMaxAngle = 25, leadEnabled = false, leadSpeed = 600, leadScale = 1,
    aimPart = "Head", aimTeam = false, aimWall = true, showFov = true,
    aimOnFire = true, vehicleSafe = true, antiFall = false,
    flyMode = "cframe", antiSnap = true,
    noclip = false, walkSpeed = 20, safeMode = false, autoTune = true, ghost = false,
    night = false, entityEsp = false, entNotify = true, hudNearest = true,
    itemEsp = false, pickup = false, pickupRadius = 25, pickupInterval = 0.12,
    autoPrompt = false, promptRadius = 20,
    autoDoor = false, doorRadius = 28, autoWalk = false, autoAdvance = false, pulse = false,
    entColor = true, thirdPerson = false, autoHide = false, hideDist = 130,
    hideMode = "sky", skyHeight = 300, skyTime = 8, instantPrompt = true,
    hideOnlyRush = true, invertY = true, fastScan = true, scenery = false,
    tpMode = "orbit", tpDebug = false, doors = false, eyesAway = true, leverAuto = false, lever = false, hidePrefer = "sky", hideTier2 = false, hideSound = false, hideDebug = false, spin = false, spinSpeed = 180, npcAim = false, npcAimDist = 200, npcAimOnFire = true, npcLead = true, killAura = false, auraRemote = true, auraRing = false, instantKill = false, killDamage = 1000000, auraReach = 6, auraFireInt = 0.35, auraKey = Enum.KeyCode.G, auraMulti = false, auraMax = 5, dmgMult = 2, baseDamage = 20, dmgRepeat = 2, meleeRange = 12, auraRanged = true, healthLock = false, lowHPFlee = false, fleePct = 0.35, npcNoCollide = false, useLearned = true, replaySwap = true, replayScale = 1, replayFilter = true,  lockMax = true, lockHP = 100, lockKeep = 20, auraDebug = false, npcEspDist = 300, npcEspMax = 40, auraRadius = 20, auraDmg = 20, auraInt = 0.2, auraNpc = true, auraPlayer = false, forceDoors = false, govEnabled = false, govMax = 12, govWindow = 0.6,
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
function M.charOf(p) local c = p and p.Character; if c and c.Parent then return c end end
function M.humOf(p) local c = M.charOf(p); return c and c:FindFirstChildOfClass("Humanoid") end
local function alive(p) local h = M.humOf(p); return h ~= nil and h.Health > 0 end
function M.isMate(p) return lp.Team ~= nil and p.Team == lp.Team end
function M.isSafeName(s)
    s = (s or ""):lower()
    if s == "" then return false end
    for _, k in ipairs(CONFIG.Safe) do
        if s:find(k, 1, true) then return true end
    end
    return false
end

local APARTS = { Head = {"Head"}, Root = {"HumanoidRootPart"}, Torso = {"UpperTorso","Torso","HumanoidRootPart"} }
function M.aimPartOf(p)
    local c = M.charOf(p); if not c then return nil end
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
function M.canSee(part)
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

function M.detectProfile()
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

local currentProfileKey = M.detectProfile()

function M.applyProfile(key)
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

function M.flyCapNow()
    local p = PROFILES[currentProfileKey]
    return (p and p.flyCap) or 60
end

M.applyProfile(currentProfileKey)

-- 非 DOORS 服务器：默认关掉 DOORS 专属模块（可在杂项强制开启）
function M.doorsAllowed()
    return currentProfileKey == "doors" or S.forceDoors
end
if not M.doorsAllowed() then
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

--==== 窗口可拉伸（右边缘 / 下边缘 / 右下角）====
local MINW, MINH, MAXW, MAXH = 380, 300, 1100, 860
do
    local function makeHandle(size, pos, applyX, applyY)
        local h = mk("Frame", { Size = size, Position = pos, BackgroundTransparency = 1,
            Active = true, ZIndex = 60 }, main)
        local dragging, startSize, startPos = false, nil, nil
        h.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging, startSize, startPos = true, main.Size, inp.Position
            end
        end)
        UIS.InputChanged:Connect(function(inp)
            if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
                local d = inp.Position - startPos
                local w = startSize.X.Offset + (applyX and d.X or 0)
                local hh = startSize.Y.Offset + (applyY and d.Y or 0)
                w = math.clamp(w, MINW, MAXW)
                hh = math.clamp(hh, MINH, MAXH)
                main.Size = UDim2.fromOffset(w, hh)
                S.menuSize = { w = w, h = hh }
            end
        end)
        UIS.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)
    end
    makeHandle(UDim2.fromOffset(8, 0), UDim2.new(1, -8, 0, 0), true, false)   -- 右边缘
    makeHandle(UDim2.new(1, 0, 0, 8), UDim2.new(0, 0, 1, -8), false, true)   -- 下边缘
    makeHandle(UDim2.fromOffset(16, 16), UDim2.new(1, -16, 1, -16), true, true) -- 右下角
    if S.menuSize and S.menuSize.w then
        main.Size = UDim2.fromOffset(math.clamp(S.menuSize.w, MINW, MAXW), math.clamp(S.menuSize.h, MINH, MAXH))
    end
end


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
    UIS.InputChanged:Connect(function(i) if not RUNNING then return end
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - ds
            main.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i) if not RUNNING then return end
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
function M.addPage(name)
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
function M.addSection(page, text)
    rowOrder = rowOrder + 1
    return mk("TextLabel", { Text = text, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18),
        TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold, TextSize = 10,
        TextColor3 = CONFIG.Accent, LayoutOrder = rowOrder }, page)
end
function M.addToggle(page, text, default, cb)
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
function M.addSlider(page, text, mn, mx, default, cb)
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
    UIS.InputChanged:Connect(function(i) if not RUNNING then return end
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then fromX(i.Position.X) end
    end)
    UIS.InputEnded:Connect(function(i) if not RUNNING then return end
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
    end)
    set(default)
    return set
end
function M.addButton(page, text, cb)
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
function M.addBox(page, placeholder, default)
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

function M.flyStop()
    S.fly = false
    if flyBV then flyBV:Destroy(); flyBV = nil end
    local h = M.humOf(lp)
    if h then pcall(function() h.PlatformStand = false end) end
    cam.CameraType = Enum.CameraType.Custom
    flyPos, lastHrpPos, flySnaps = nil, nil, 0
end

function M.setFly(on)
    if on and S.safeMode then
        notify("安全模式开启：位移类功能已禁用（先关掉安全模式）", "err", 3)
        return
    end
    S.fly = on
    local c = M.charOf(lp); local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if on and hrp then
        flyPos = hrp.Position
        lastHrpPos = nil
        flySnaps = 0
        local h = M.humOf(lp)
        if S.flyMode == "cframe" and h then pcall(function() h.PlatformStand = true end) end
        if S.flyMode == "body" then
            if flyBV then flyBV:Destroy() end
            flyBV = mk("BodyVelocity", { Name = "XHubFly", MaxForce = Vector3.new(1e5, 1e5, 1e5),
                Velocity = Vector3.zero, P = 1250 }, hrp)
        end
        notify(("飞行已开启 · %s · 速度 %d"):format(S.flyMode == "body" and "物理" or "CFrame", S.flySpeed), "ok", 1.6)
    else
        M.flyStop()
        notify("飞行已关闭", "info", 1.2)
    end
end

function M.flyDir()
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

function M.onSnap(delta)
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
        local cap = M.flyCapNow()
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
    local cap = M.flyCapNow()
    if S.govEnabled and S.flyGov then
        local govCap = math.floor((S.govMax or 12) / (S.govWindow or 0.6))
        if govCap > 4 and cap > govCap then cap = govCap end
    end
    if S.flySpeed > cap then S.flySpeed = cap end
    local c = M.charOf(lp); local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local dir = M.flyDir()

    if S.flyMode == "body" then
        if not flyBV or flyBV.Parent ~= hrp then
            flyBV = mk("BodyVelocity", { Name = "XHubFly", MaxForce = Vector3.new(1e5, 1e5, 1e5),
                Velocity = Vector3.zero, P = 1250 }, hrp)
        end
        flyBV.Velocity = (dir.Magnitude > 0) and (dir.Unit * S.flySpeed) or Vector3.zero
        if S.antiSnap and lastHrpPos and dir.Magnitude > 0 then
            if (hrp.Position - lastHrpPos).Magnitude < 0.03 then M.onSnap() end
        end
        lastHrpPos = hrp.Position
        return
    end

    -- CFrame 模式: 直接写位置,被服务器拉回就顺势续飞(不硬抢)
    local cur = hrp.CFrame
    flyPos = flyPos or cur.Position
    local snapDelta = (cur.Position - flyPos).Magnitude
    if S.antiSnap and snapDelta > 6 then
        M.onSnap(snapDelta)
        flyPos = cur.Position
    end

    local moving = dir.Magnitude > 0
    if S.pulse and moving and (os.clock() % 0.6) >= 0.36 then moving = false end
    if S.ghost then
        local h2 = M.humOf(lp)
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

lp.CharacterAdded:Connect(function() if S.fly then M.setFly(true) end end)

--==================== ESP ====================
local espStore = {}
function M.hueColor() return Color3.fromHSV((tick() * 0.2) % 1, 0.85, 1) end
function M.espColor(p)
    if S.espRainbow then return M.hueColor() end
    if lp.Team ~= nil and p.Team == lp.Team then return CONFIG.Mate end
    return CONFIG.Enemy
end
function M.destroyESP(o)
    for _, v in pairs(o) do if typeof(v) == "Instance" then v:Destroy() end end
end
function M.ensureESP(p)
    local c = M.charOf(p); if not c then return end
    local o = espStore[p]; if not o then o = {}; espStore[p] = o end
    if S.espBox then
        if not (o.hl and o.hl.Parent) then
            o.hl = mk("Highlight", { Name = "XHubHL", FillTransparency = 0.65,
                OutlineTransparency = 0.1, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop }, c)
        end
        o.hl.Parent = c
        o.hl.FillColor = M.espColor(p)
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
    local h = M.humOf(p)
    o.nameLbl.Text = p.Name
    o.nameLbl.TextColor3 = S.espName and M.espColor(p) or Color3.new(1, 1, 1)
    o.nameLbl.Visible = S.espName
    o.distLbl.Visible = S.espDist
    if S.espDist then
        local myC = M.charOf(lp); local myHrp = myC and myC:FindFirstChild("HumanoidRootPart")
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
    while RUNNING do
        task.wait(0.1)
        if S.esp then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= lp and alive(p) and (S.espTeam or not M.isMate(p)) then M.ensureESP(p) end
            end
            local dead = {}
            for p, o in pairs(espStore) do
                if not alive(p) or (M.isMate(p) and not S.espTeam) or p.Parent == nil then
                    M.destroyESP(o); dead[#dead + 1] = p
                end
            end
            for _, p in ipairs(dead) do espStore[p] = nil end
        else
            for _, o in pairs(espStore) do M.destroyESP(o) end
            espStore = {}
        end
    end
end)
Players.PlayerRemoving:Connect(function(p)
    if espStore[p] then M.destroyESP(espStore[p]); espStore[p] = nil end
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
function M.findTarget()
    local vp = cam.ViewportSize
    local center = Vector2.new(vp.X / 2, vp.Y / 2)
    local best, bestD = nil, S.aimFov
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp and alive(p) and (S.aimTeam or not M.isMate(p)) then
            local part = M.aimPartOf(p)
            if part then
                local sp, onScreen = cam:WorldToViewportPoint(part.Position)
                if onScreen then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if d < bestD and M.canSee(part) then best, bestD = part, d end
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
                                if d < bestD and M.canSee(part) then best, bestD = part, d end
                            end
                        end
                    end
                end
            end
        end)
    end
    return best
end
function M.leadPoint(part)
    if not part then return nil end
    if not S.leadEnabled then return part.Position end
    local spd = math.max(S.leadSpeed or 600, 50)
    local vel = part.AssemblyLinearVelocity
    local dist = (part.Position - cam.CFrame.Position).Magnitude
    local tt = dist / spd
    return part.Position + vel * tt * (S.leadScale or 1)
end

local aimInfo
local aimWant, aimGoal = false, nil
local npcStore = {}          -- forward decl (NPC ESP 会往里塞)
local lastNpcTarget = nil
local hitTrack = { part = nil, hp = nil, last = 0 }

-- NPC 专用目标查找（独立自瞄 / 杀戮光环共用）
function M.findNpcTarget(maxDist)
    local c = M.charOf(lp)
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    maxDist = maxDist or (S.npcAimDist or 200)
    local bestD, bestP, bestM = math.huge, nil, nil
    local function consider(m)
        if not m or not m.Parent or m == c then return end
        if lp.Character and m == lp.Character then return end
        local hum = m:FindFirstChildOfClass("Humanoid")
        local p = m:FindFirstChild("HumanoidRootPart") or M.firstPart(m)
        if not (hum and p) then return end
        if hum.Health <= 0 then return end
        local d = (p.Position - hrp.Position).Magnitude
        if d > maxDist or d >= bestD then return end
        bestD, bestP, bestM = d, p, m
    end
    for m in pairs(npcStore) do consider(m) end
    for _, mm in ipairs(M.scanTargets()) do consider(mm) end
    for m in pairs(entStore) do
        local nm = m.Name:lower()
        if nm:find("rig", 1, true) or nm:find("dummy", 1, true) or nm:find("npc", 1, true)
           or nm:find("monster", 1, true) or nm:find("enemy", 1, true) then
            consider(m)
        end
    end
    return bestP, bestM, bestD
end
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

    -- 独立 NPC 自瞄：与玩家自瞄互不影响
    if S.npcAim and not main.Visible then
        local np, nm2 = M.findNpcTarget(S.npcAimDist)
        if np then
            local wantFire = (not S.npcAimOnFire) or UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
            if wantFire then
                local goal = np.Position
                if S.npcLead then
                    local v = np.AssemblyLinearVelocity
                    local dd = (np.Position - cam.CFrame.Position).Magnitude
                    goal = np.Position + v * (dd / math.max(50, S.leadSpeed)) * (S.leadScale or 1)
                end
                pcall(function() cam.CFrame = CFrame.lookAt(cam.CFrame.Position, goal) end)
                if aimInfo then aimInfo.Text = ("NPC自瞄: %s  %.0fm"):format(nm2.Name, (np.Position - cam.CFrame.Position).Magnitude) end
                lastNpcTarget = nm2
            end
        else
            if aimInfo and not S.aim then aimInfo.Text = "NPC自瞄: 无目标" end
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

    local okT, t = pcall(M.findTarget)
    if not okT then t = nil end
    if not t then
        aimGoal = nil
        if aimInfo then aimInfo.Text = "自瞄: FOV 内无目标" end
        return
    end

    -- 命中反馈：锁定目标的血量下降 => 打中
    do
        local hp = nil
        local par = t.Parent
        local hum = par and par:FindFirstChildOfClass("Humanoid")
        if hum then hp = hum.Health end
        if hitTrack.part == t and hitTrack.hp and hp and hp < hitTrack.hp - 0.5 then
            if os.clock() - hitTrack.last > 0.35 then
                notify(("命中 %s  -%d HP"):format(par.Name, math.floor(hitTrack.hp - hp)), "ok", 1.2)
                hitTrack.last = os.clock()
            end
        end
        hitTrack.part, hitTrack.hp = t, hp
    end

    if cam.CameraType ~= Enum.CameraType.Custom then cam.CameraType = Enum.CameraType.Custom end
    local cur = cam.CFrame
    local goal = CFrame.lookAt(cur.Position, M.leadPoint(t) or t.Position)
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
local auraPart = nil            -- forward decl (kill aura target)
local fireUntil = 0

UIS.InputBegan:Connect(function(input, gp) if not RUNNING then return end
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        fireUntil = os.clock() + 0.3
    end
end)

function M.remoteAimPoint()
    -- 杀戮光环：优先朝光环目标打
    if S.killAura and auraPart and auraPart.Parent and S.remoteAim then
        return auraPart.Position
    end
    if not (S.silentAim or S.btStandalone or S.bulletTrack) then return nil end
    if not S.remoteAim then return nil end
    local ok, t = pcall(M.findTarget)
    if ok and t then return M.leadPoint(t) or t.Position end
    return nil
end

local remoteHooked = false

function M.argSig(args, n)
    local parts = {}
    n = n or #args
    for i = 1, math.min(n, 6) do
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

function M.installRemoteAim()
    if remoteHooked then return end
    if not (hookmetamethod and getnamecallmethod and checkcaller) then
        notify("执行器不支持 hookmetamethod，远程改写不可用", "err", 3)
        return
    end
    local old
    old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        if not RUNNING then return old(self, ...) end
        local m = getnamecallmethod()
        local inWindow = os.clock() < fireUntil
        if (m == "FireServer" or m == "InvokeServer") and S.learnActive then
            local nL = select("#", ...)
            local aL = { ... }
            local nmL = tostring(self.Name):lower()
            local atk = false
            for _, k in ipairs({ "fire", "shoot", "hit", "damage", "attack", "slash", "swing",
                                 "melee", "punch", "knock", "grab", "kill", "hurt", "stab", "strike", "take" }) do
                if nmL:find(k, 1, true) then atk = true break end
            end
            if not atk then
                for i = 1, nL do
                    local v0 = aL[i]
                    if typeof(v0) == "Instance" then
                        local okc, isc = pcall(M.isCharLike, v0)
                        if okc and isc then atk = true break end
                    end
                end
            end
            if atk then
                S.learnCall = { remote = self, args = aL, n = nL, name = tostring(self.Name) }
                S.learnActive = false
                S.learned = { S.learnCall }
                pcall(M.saveLearned)
                pcall(function() auraLog(("已学会攻击: %s (%d 参)  %s"):format(tostring(self.Name), nL, M.argSig(aL, nL)), Color3.fromRGB(140, 255, 160)) end)
            end
        end

        if (m == "FireServer" or m == "InvokeServer") and S.dmgRecord then
            local n0 = select("#", ...)
            local a0 = { ... }
            S.dmgLast = { remote = self, args = a0, n = n0, name = tostring(self.Name), at = os.clock() }
            S.dmgRecord = false
            pcall(function() print(("[dmgcap] %s (%d args)  %s"):format(tostring(self.Name), n0, M.argSig(a0, n0))) end)
            pcall(function() auraLog(("捕获调用: %s (%d 参)"):format(tostring(self.Name), n0), Color3.fromRGB(140, 200, 255)) end)
        end

        if (m == "FireServer" or m == "InvokeServer") and inWindow and (S.remoteAim or S.remoteProbe) then
            local n = select("#", ...)          -- 关键：保留 nil 参数，不能被 # 截断
            local args = { ... }
            local okName, nm = pcall(function() return tostring(self.Name):lower() end)

            if S.remoteProbe then
                print(("[probe] %s  %s  (%d args)"):format(tostring(self.Name), m, n))
                print("[probe]   " .. M.argSig(args, n))
            end

            if S.remoteAim then
                local matched = S.remoteAimAll
                if not matched and okName and nm then
                    for _, k in ipairs(WEAPON_REMOTE_KW) do
                        if nm:find(k, 1, true) then matched = true break end
                    end
                end
                if matched then
                    local pt = M.remoteAimPoint()
                    if pt then
                        local c = M.charOf(lp)
                        local hrp = c and c:FindFirstChild("HumanoidRootPart")
                        local changed = false
                        for i = 1, n do
                            local v = args[i]
                            local tv = typeof(v)
                            if tv == "Vector3" then
                                local dir
                                if v.Magnitude <= 3 and hrp then
                                    dir = (pt - hrp.Position)
                                else
                                    dir = pt - v
                                end
                                if dir.Magnitude > 0.01 then
                                    dir = dir.Unit
                                    -- 限制偏转角：默认 25 度，避免服务器判定“这是外挂方向”
                                    local orig
                                    if tv == "Vector3" and v.Magnitude <= 3 then
                                        orig = v.Unit
                                    else
                                        orig = Vector3.zero
                                    end
                                    if orig.Magnitude < 0.1 then
                                        args[i] = (v.Magnitude <= 3) and dir or (v + dir * dir.Magnitude)
                                    else
                                        local ang = math.deg(math.acos(math.clamp(orig:Dot(dir), -1, 1)))
                                        if ang <= (S.silentMaxAngle or 25) then
                                            args[i] = dir
                                        end
                                    end
                                    changed = true
                                end
                            elseif tv == "CFrame" then
                                local want = CFrame.lookAt(v.Position, v.Position + (pt - v.Position).Unit, v.UpVector)
                                local ang = math.deg(math.acos(math.clamp(v.LookVector:Dot(want.LookVector), -1, 1)))
                                local lim = S.remoteAimSafe and 8 or (S.silentMaxAngle or 25)
                                if ang <= lim then
                                    args[i] = want
                                    changed = true
                                end
                            end
                        end
                        if changed then
                            if S.remoteProbe then
                                print(("[probe]   >>> 已改写 %s 的方向参数（偏转受限）"):format(tostring(self.Name)))
                            end
                            return old(self, table.unpack(args, 1, n))
                        end
                    end
                end
            end
            return old(self, table.unpack(args, 1, n))
        end
        return old(self, ...)
    end))    remoteHooked = true
    print("[XHub] remote hook installed")
end
pcall(M.installRemoteAim)
--==== 静默瞄准（Silent Aim）：视角不动，只在开火瞬间改写相机方向 1~6 帧 ====
local silent = { saved = nil, untilT = 0, pos = nil }

function M.silentTarget()
    if not S.aim then return nil end
    return M.findTarget()
end

UIS.InputBegan:Connect(function(input, gp) if not RUNNING then return end
    if gp then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    if main.Visible then return end
    if not (S.silentAim or S.btStandalone) then return end
    if S.silentAim and S.remoteAim then return end   -- 远程改写已生效时，相机一律不动（真静默）
    local wasAim = S.aim
    if not wasAim then S.aim = true end
    local t = nil
    pcall(function() t = M.findTarget() end)
    S.aim = wasAim
    if t then
        silent.saved = cam.CFrame
        silent.pos = M.leadPoint(t) or t.Position
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
            local t = M.silentTarget()
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

function M.repairInput(showNotif)
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
    local h = M.humOf(lp)
    if h then
        pcall(function()
            h.PlatformStand = false
            h.Sit = false
            if h.WalkSpeed < 1 then h.WalkSpeed = 16 end
            if h.JumpPower < 1 then h.JumpPower = 50 end
        end)
    end
    local c = M.charOf(lp)
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
function M.suspendACG()
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
function M.characterFix(silent)
    local c = M.charOf(lp); if not c then return end
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
function M.isSeated()
    local h = M.humOf(lp); if not h then return false end
    local s = false
    pcall(function() s = h.SeatPart ~= nil end)
    if s then return true end
    pcall(function() s = h:GetState() == Enum.HumanoidStateType.Seated end)
    if s then return true end
    local c = M.charOf(lp)
    if c then
        for _, v in ipairs(c:GetChildren()) do
            if v:IsA("Weld") and v.Name:lower():find("seat", 1, true) then return true end
        end
    end
    return false
end

-- 防遁地守护
function M.groundYAt(pos)
    local params = RaycastParams.new()
    params.FilterType = rp.FilterType
    params.FilterDescendantsInstances = { lp.Character }
    local res = workspace:Raycast(pos + Vector3.new(0, 40, 0), Vector3.new(0, -400, 0), params)
    return res and res.Position.Y or nil
end

local __wasSeated = false
task.spawn(function()
    while RUNNING do
        task.wait(0.2)
        local seated = M.isSeated()
        if seated ~= __wasSeated then
            __wasSeated = seated
            if seated then
                if S.vehicleSafe then
                    local nH, nC = M.suspendACG()
                    notify(("车辆安全模式: 已暂停绕过（还原 %d 闭包 / %d 连接）"):format(nH, nC), "warn", 2.6)
                end
            else
                task.delay(0.7, function()
                    if S.vehicleSafe then M.characterFix(true) end
                    notify("已下车: 角色已复位（需要绕过请重开 ①②）", "info", 3)
                end)
            end
        end
    end
end)

task.spawn(function()
    local airT = 0
    while RUNNING do
        task.wait(0.3)
        local c, h = M.charOf(lp), M.humOf(lp)
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if c and h and hrp and S.antiFall and not S.fly and not M.isSeated() then
            if h.FloorMaterial == Enum.Material.Air then
                airT = airT + 0.3
                if airT >= 1.2 then
                    airT = 0
                    local gy = M.groundYAt(hrp.Position)
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

function M.setNoclip(on)
    S.noclip = on
    local c = M.charOf(lp)
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
            local c = M.charOf(lp)
            if c then
                for _, v in ipairs(c:GetDescendants()) do
                    if v:IsA("BasePart") and v.CanCollide then
                        if noclipOrig[v] == nil then noclipOrig[v] = true end
                        pcall(function() v.CanCollide = false end)
                    end
                end
            end
        end
        if not S.fly and not M.isSeated() then
            local h = M.humOf(lp)
            if h and math.abs(h.WalkSpeed - S.walkSpeed) > 0.5 then
                pcall(function() h.WalkSpeed = S.walkSpeed end)
            end
        end
    end
end)

--==================== 基础压制 ====================
local AC = { marker = nil, guard = false }
function M.acIs(s)
    if type(s) ~= "string" or s == "" then return false end
    for _, k in ipairs(CONFIG.AC.Patterns) do if s:find(k, 1, true) then return true end end
    return false
end
function M.acRun()
    local t, c = 0, 0
    if getreg and coroutine and coroutine.close then
        for _, v in pairs(getreg()) do
            if type(v) == "thread" then
                local ok, src = pcall(function() return debug.info(v, "s") end)
                if ok and M.acIs(src) and not M.isSafeName(src) and (pcall(coroutine.close, v)) then
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
                    if M.acIs(sn) and not M.isSafeName(sn) then
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
    if s == "" or M.isSafeName(s) then return false end
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
function M.collectScripts()
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
function M.killACGThreads(byName)
    if not (getreg and coroutine and coroutine.close) then return 0 end
    local n = 0
    for _, v in pairs(getreg()) do
        if type(v) == "thread" then
            local src = ""
            pcall(function() src = debug.info(v, "s") or "" end)
            local hit = isTarget(src)
            if not hit and src ~= "" and not M.isSafeName(src) then
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
function M.hookConnFns()
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
                       and not M.isSafeName(sn) and not M.isSafeName(src) then
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

function M.countInputConns()
    if not getconnections then return -1 end
    local n = 0
    for _, sig in ipairs({ UIS.InputBegan, UIS.InputChanged, UIS.InputEnded }) do
        local ok, cs = pcall(getconnections, sig)
        if ok and cs then n = n + #cs end
    end
    return n
end

function M.runLayer1()
    G.matches = {}
    local byName = M.collectScripts()
    local before = M.countInputConns()
    local t = M.killACGThreads(byName)
    local c, h = M.hookConnFns()
    local after = M.countInputConns()
    if before >= 0 and after >= 0 and after < before then
        M.repairInput(false)
        notify(("检测层动到了输入连接(%d→%d)，已自动还原"):format(before, after), "err", 4)
        return 0, 0, 0
    end
    return c, t, h
end

function M.hookRemote(inst)
    if not (hookmetamethod and getnamecallmethod and checkcaller) then return false end
    local ok = pcall(function()
        local old
        old = hookmetamethod(inst, "__namecall", newcclosure(function(self, ...)
        if not RUNNING then return old(self, ...) end
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
function M.scanRemotes()
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
                    if M.hookRemote(d) then n = n + 1 end
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
function M.installGlobalHook()
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
                if not M.isSafeName(sn) and not M.isSafeName(short)
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
function M.runLayer2()
    G.matches = {}
    local byName = M.collectScripts()
    G.targetScripts = byName
    M.installGlobalHook()
    return M.scanRemotes()
end
function M.hashSearch(q)
    if q and q ~= "" then CONFIG.ACG.Hashes[hash(q)] = true end
    G.matches = {}
    local byName = M.collectScripts()
    local c, h = M.hookConnFns()
    local t = M.killACGThreads(byName)
    local n = M.scanRemotes()
    return c, t, h, n
end
function M.acgRestore()
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

function M.blockRemoteSubstr(sub)
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
        if not RUNNING then return old(self, ...) end
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
function M.tcCollect()
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
function M.tcMatch(e, q)
    if q == nil or q == "" then return true end
    local hay, needle = e.name, q
    if not TC.cs then hay, needle = string.lower(hay), string.lower(needle) end
    if TC.exact then return hay == needle end
    return string.find(hay, needle, 1, true) ~= nil
end
function M.tcRender()
    if not TC.panel then return end
    for _, c in ipairs(TC.list:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    local q = TC.search.Text or ""
    local n = 0
    for _, e in ipairs(TC.all) do
        if M.tcMatch(e, q) then
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
local function tcRefresh() TC.all = M.tcCollect(); M.tcRender() end
function M.tcKill(q)
    local killed, matched = 0, 0
    if not coroutine.close then return 0, 0 end
    for _, e in ipairs(TC.all) do
        if M.tcMatch(e, q) and not M.isSafeName(e.name) then
            matched = matched + 1
            local ok, res = pcall(coroutine.close, e.t)
            if ok and res then killed = killed + 1
            elseif task and task.cancel then pcall(task.cancel, e.t) end
        end
    end
    return killed, matched
end
function M.tcDump()
    print(("===== thread dump (%d) ====="):format(#TC.all))
    for i, e in ipairs(TC.all) do print(("%4d [%s] %s:%d"):format(i, e.status, e.name, e.line)) end
end
function M.tcBuild()
    if TC.panel then return end
    TC.all = M.tcCollect()
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
    UIS.InputChanged:Connect(function(i) if not RUNNING then return end
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - ds
            p.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i) if not RUNNING then return end
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
        M.tcRender()
    end)
    local csChip = chip("区分大小写: 关", 130, 122, function()
        TC.cs = not TC.cs
        csChip.Text = "区分大小写: " .. (TC.cs and "开" or "关")
        csChip.BackgroundColor3 = TC.cs and CONFIG.Accent or Color3.fromRGB(30, 34, 44)
        M.tcRender()
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
    TC.search:GetPropertyChangedSignal("Text"):Connect(M.tcRender)
    btn("刷新", 12, 80, function() tcRefresh() end)
    btn("列到 F9", 98, 80, function() M.tcDump() end)
    btn("填 BS_", 184, 80, function()
        TC.search.Text = "BS_"
        TC.status.Text = "已填 BS_（车辆/输入脚本已白名单，不会误杀）"
    end)
    btn("终止匹配", 270, 96, function()
        local k, m = M.tcKill(TC.search.Text or "")
        TC.status.Text = ("终止了 %d / %d（匹配 %d）"):format(k, #TC.all, m)
        task.delay(0.3, tcRefresh)
    end)
    btn("关闭", 372, 60, function() p.Visible = false end)
    M.tcRender()
end
function M.tcShow()
    M.tcBuild(); TC.panel.Visible = true; tcRefresh()
end

--==================== 角色 / 服务器操作 ====================
function M.suicide()
    local h = M.humOf(lp)
    if h then pcall(function() h.Health = 0 end) end
    local c = M.charOf(lp)
    if c then
        for _, v in ipairs(c:GetDescendants()) do
            if v:IsA("BasePart") then pcall(function() v:BreakJoints() end) end
        end
    end
    notify("已自杀，等待重生", "warn", 2.5)
end
function M.rejoinHere()
    local TS = game:GetService("TeleportService")
    notify("正在重进本服…", "info", 2)
    task.wait(0.4)
    local ok = pcall(function() TS:TeleportToPlaceInstance(game.PlaceId, game.JobId, lp) end)
    if not ok then ok = pcall(function() TS:Teleport(game.PlaceId, lp) end) end
    if not ok then notify("重进失败（被游戏/AC 拦截，或该体验禁止传送）", "err", 4) end
end
function M.newServer()
    local TS = game:GetService("TeleportService")
    local ok = pcall(function() TS:Teleport(game.PlaceId, lp) end)
    notify(ok and "正在切换到新服务器…" or "切服失败", ok and "info" or "err", 3)
end

-- (实体/物品的即时捕获移到文件后部，等 isEntityModel/ensureEnt 定义好再连; 见 "刷新即时捕获")

--==================== 夜视 ====================
local NV = { saved = nil, cc = nil }

function M.setNight(on)
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

function M.isEntityModel(m)
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

-- 目标扫描：专门找"带 Humanoid 的 Model"（不受 scanAll 数量上限影响）
-- 目标扫描：回到"直接全量找 Humanoid"（这是之前能正常绘制/锁定的实现），0.6 秒缓存
local _tgT, _tgList = 0, nil

function M.scanTargets()
    local now = os.clock()
    if _tgList and (now - _tgT) < 0.6 then return _tgList end
    _tgT = now
    local out, seen, n = {}, {}, 0
    pcall(function()
        for _, d in ipairs(workspace:GetDescendants()) do
            n = n + 1
            if n > 60000 then break end
            if d:IsA("Humanoid") then
                local m = d.Parent
                if m and m:IsA("Model") and not seen[m] then
                    seen[m] = true
                    out[#out + 1] = m
                end
            end
        end
    end)
    for _, pl in ipairs(Players:GetPlayers()) do
        local ch = pl.Character
        if ch and not seen[ch] then
            seen[ch] = true
            out[#out + 1] = ch
        end
    end
    _tgList = out
    return out
end
function M.scanAll(cap)
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

function M.destroyEnt(o)
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

function M.entColorFor(name)
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

function M.firstPart(inst)
    if inst:IsA("BasePart") then return inst end
    local p
    pcall(function() p = inst.PrimaryPart end)
    if p then return p end
    p = inst:FindFirstChild("HumanoidRootPart", true)
    if p then return p end
    return inst:FindFirstChildWhichIsA("BasePart", true)
end

function M.distTo(m)
    local c = M.charOf(lp)
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local p = M.firstPart(m)
    if p then return (p.Position - hrp.Position).Magnitude end
    local ok, cf = pcall(function() return m:GetBoundingBox() end)
    if ok and cf then return (cf.Position - hrp.Position).Magnitude end
    return nil
end

function M.ensureEnt(m)
    local o = entStore[m]
    if not o then o = {}; entStore[m] = o end
    if not (o.hl and o.hl.Parent) then
        o.hl = mk("Highlight", { Name = "XHubEnt",
            FillColor = Color3.fromRGB(255, 120, 40), FillTransparency = 0.55,
            OutlineColor = Color3.fromRGB(255, 205, 130), OutlineTransparency = 0,
            DepthMode = Enum.HighlightDepthMode.AlwaysOnTop }, m)
    end
    o.hl.Parent = m
    o.hl.FillColor = M.entColorFor(m.Name)
    o.hl.OutlineColor = M.entColorFor(m.Name):Lerp(Color3.new(1, 1, 1), 0.55)
    local head
    pcall(function() head = m:FindFirstChild("Head") end)
    head = head or M.firstPart(m)
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
    local d = M.distTo(m)
    if o.dlbl then o.dlbl.Text = d and ("%.0f m"):format(d) or "" end

    if S.entNotify and not entSeen[m] then
        entSeen[m] = true
        if d and d < 400 then
            notify(("发现实体: %s · %.0f m"):format(m.Name, d), "warn", 3)
        end
    end
end

task.spawn(function()
    while RUNNING do
        task.wait(S.fastScan and 1.0 or 0.4)
        if S.entityEsp or S.espNpc then
            local n = 0
            for _, d in ipairs(M.scanAll(4000)) do
                n = n + 1
                if n > 4000 then break end
                if d:IsA("Model") and M.isEntityModel(d) then
                    pcall(M.ensureEnt, d)
                end
            end
            local dead = {}
            for m, o in pairs(entStore) do
                if not m.Parent then M.destroyEnt(o); dead[#dead + 1] = m end
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
                    local d = M.distTo(m)
                    if d and d < bestD then bestD, bestN = d, m.Name end
                end
                local hh = M.humOf(lp)
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
            for m, o in pairs(entStore) do M.destroyEnt(o) end
            entStore = {}
            entSeen = {}
            if entHud then entHud:Destroy(); entHud = nil end
        end
    end
end)

--==================== 物品绘制 / 拾取 / 自动交互 ====================
local ITEM_KW = { "key", "钥匙", "loot", "item", "coin", "chest", "drawer", "pickup",
                  "gem", "gold", "cash", "money", "bandage", "flashlight", "lighter",
                  "candle", "crucifix", "lockpick", "vitamin", "potion", "weapon", "sack", "bag", "box", "箱", "袋" }
local itemStore = {}

function M.nameHits(v, list)
    local nm = (v and v.Name or ""):lower()
    if nm == "" then return false end
    for _, k in ipairs(list) do
        if nm:find(k:lower(), 1, true) then return true end
    end
    return false
end

local ITEM_EXCLUDE = { "candle", "蜡烛", "drawer", "container", "wall", "stool", "chair", "seat", "bench", "table", "sofa", "lamp", "potted", "plant", "tree", "flower", "盆栽", "barrel", "cellar", "stack", "crate", "wooden" }

function M.isItemInst(v)
    local nm = (v and v.Name or ""):lower()
    for _, k in ipairs(ITEM_EXCLUDE) do
        if nm:find(k, 1, true) then return false end
    end
    if v:IsA("Tool") then return true end
    return M.nameHits(v, ITEM_KW)
end

function M.ensureItem(v)
    local o = itemStore[v]
    if not o then o = {}; itemStore[v] = o end
    if not (o.hl and o.hl.Parent) then
        o.hl = mk("Highlight", { Name = "XHubItem",
            FillColor = Color3.fromRGB(140, 255, 60), FillTransparency = 0.35,
            OutlineColor = Color3.fromRGB(235, 255, 150), OutlineTransparency = 0,
            DepthMode = Enum.HighlightDepthMode.AlwaysOnTop }, v)
    end
    o.hl.Parent = v
    local part = M.firstPart(v)
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
        local c = M.charOf(lp)
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if hrp then o.dlbl.Text = ("%.0f m"):format((part.Position - hrp.Position).Magnitude) end
    end
end

local pickupParts = {}

function M.rangePickup(radius)
    if not firetouchinterest then return 0 end
    local c = M.charOf(lp)
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

function M.autoPrompts(radius)
    local c = M.charOf(lp)
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
                S.itemPoke = now
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

local navTo   -- forward decl (defined later)
local doorState = {}

function M.autoDoors(radius)
    local rooms = workspace:FindFirstChild("CurrentRooms")
    if not rooms then return 0 end
    local c = M.charOf(lp)
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
                        if S.autoAdvance and part then
                            local target = part.Position
                            task.delay(0.9, function()
                                if S.autoAdvance and target then navTo(target) end
                            end)
                        end
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

function M.stopWalk()
    PF.running = false
    PF.gen = PF.gen + 1
    local h = M.humOf(lp)
    if h then pcall(function() h:MoveTo(h.Parent.HumanoidRootPart.Position) end) end
end

function M.walkTo(pos, timeoutSec)
    if PF.running then M.stopWalk() end
    PF.running = true
    PF.gen = PF.gen + 1
    local gen = PF.gen
    timeoutSec = timeoutSec or 25

    task.spawn(function()
        local t0 = os.clock()
        local c, h = M.charOf(lp), M.humOf(lp)
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

local isRealDoor   -- forward decl (defined later with the door layer)
function M.nearestDoorPos()
    local c = M.charOf(lp)
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
    while RUNNING do
        local boost = (os.clock() - (S.itemPoke or 0)) < 3
        task.wait(S.fastScan and (boost and 0.4 or 1.5) or 0.35)
        if S.itemEsp then
            local n = 0
            for _, v in ipairs(M.scanAll(4000)) do
                n = n + 1
                if n > 3000 then break end
                if (v:IsA("Tool") or v:IsA("Model")) and M.isItemInst(v) then
                    pcall(M.ensureItem, v)
                end
            end
            local dead = {}
            for v, o in pairs(itemStore) do
                if not v:IsDescendantOf(workspace) then
                    M.destroyEnt(o); dead[#dead + 1] = v
                end
            end
            for _, v in ipairs(dead) do itemStore[v] = nil end
        elseif next(itemStore) ~= nil then
            for v, o in pairs(itemStore) do M.destroyEnt(o) end
            itemStore = {}
        end
        if S.pickup then
            local cache = {}
            for _, v in ipairs(M.scanAll(2500)) do
                if v:IsA("BasePart") and v.Parent and M.isItemInst(v.Parent) then
                    cache[#cache + 1] = v
                end
            end
            pickupParts = cache
        end
    end
end)

-- 拾取 / 交互 / 开门: 独立快速循环
task.spawn(function()
    while RUNNING do
        local iv = S.pickupInterval or 0.12
        if iv < 0.05 then iv = 0.05 end
        task.wait(iv)
        if S.pickup then
            pcall(M.rangePickup, S.pickupRadius)
            pcall(M.autoPrompts, S.pickupRadius)
        end
        if S.autoPrompt then pcall(M.autoPrompts, S.promptRadius) end
    end
end)

task.spawn(function()
    while RUNNING do
        task.wait(0.5)
        if S.autoDoor then pcall(M.autoDoors, S.doorRadius) end
    end
end)

--==================== 第三人称 / 模拟移动 / 自动躲避 ====================
local camOrig = nil
local camDbg = nil
local orbit = { yaw = 0, pitch = 0.25, dist = 14 }

function M.setThirdPerson(on)
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
        local h = M.humOf(lp)
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
    local c0 = M.charOf(lp)
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
        -- 兜底：如果相机离人太近（<6 studs），直接推镜头到身后
        local hz = hum0 and hum0.Parent and hum0.Parent:FindFirstChild("HumanoidRootPart")
        if hz then
            local dd = (cam.CFrame.Position - hz.Position).Magnitude
            if dd < 6 then
                local back = hz.CFrame.LookVector * -14 + Vector3.new(0, 4, 0)
                pcall(function() cam.CFrame = CFrame.lookAt(hz.Position + back, hz.Position) end)
            end
        end
        return
    end
    local d = UIS:GetMouseDelta()
    orbit.yaw = orbit.yaw - d.X * 0.0035
    local dy = S.invertY and -d.Y or d.Y
    orbit.pitch = math.clamp(orbit.pitch + dy * 0.0035, -1.2, 1.2)
    local c = M.charOf(lp)
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
    if S.tpDebug then
        if not (camDbg and camDbg.Parent) then
            camDbg = mk("TextLabel", { Name = "XHubCamDbg", Size = UDim2.fromOffset(420, 22),
                Position = UDim2.new(0, 12, 0, 40), BackgroundTransparency = 0.3,
                BackgroundColor3 = Color3.fromRGB(12, 16, 22), Text = "",
                Font = Enum.Font.Code, TextSize = 12, TextColor3 = Color3.fromRGB(160, 230, 255),
                ZIndex = 40 }, gui)
        end
        camDbg.Text = ("tp=%s  type=%s  mode=%s  距离=%.1f  yaw=%.2f pitch=%.2f")
            :format(tostring(S.tpMode), tostring(cam.CameraType), tostring(lp.CameraMode),
                    (cam.CFrame.Position - hrp.Position).Magnitude, orbit.yaw, orbit.pitch)
    end
end)

-- 变焦锁定模式：每帧把游戏的视角设置拉回来（不少游戏会锁第一人称）
task.spawn(function()
    while RUNNING do
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

function M.simWalk(pos, timeoutSec)
    M.stopWalk()
    PF.running = true
    PF.gen = PF.gen + 1
    local gen = PF.gen
    task.spawn(function()
        local t0 = os.clock()
        local c, h = M.charOf(lp), M.humOf(lp)
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

function M.promptPos(p)
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

function M.findHidePrompt(maxDist)
    local c = M.charOf(lp)
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local best, bestD, bestPart
    bestD = maxDist or 120
    for _, p in ipairs(M.scanAll(4000)) do
        if p:IsA("ProximityPrompt") or p:IsA("ClickDetector") then
            local nm = ((p.Parent and p.Parent.Name or "") .. " "
                     .. ((p:IsA("ProximityPrompt") and (p.ActionText or "") or "")) .. " "
                     .. ((p:IsA("ProximityPrompt") and (p.ObjectText or "") or ""))):lower()
            local hit = false
            for _, k in ipairs(HIDE_PROMPT_KW) do
                if nm:find(k, 1, true) then hit = true; break end
            end
            if hit then
                local part = M.promptPos(p)
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

function M.preferSky(name)
    if S.hidePrefer == "sky" then return true end
    if S.hidePrefer == "closet" then return false end
    local nm = (name or ""):lower()
    -- auto: Rush/Ambush 钻柜子(服务端认可)；Seek 等追猎型用高空
    if nm:find("rush", 1, true) or nm:find("ambush", 1, true) then return false end
    return true
end

function M.skyHide(reason)
    local c = M.charOf(lp)
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then hiding = false; return end
    skyHold = { cf = hrp.CFrame + Vector3.new(0, S.skyHeight, 0), exp = os.clock() + S.skyTime }
    notify(("高空躲避(%s): %.0f studs / %d 秒")
        :format(reason or "?", S.skyHeight, S.skyTime), "warn", 3)
    task.delay(S.skyTime, function()
        skyHold = nil
        local c2 = M.charOf(lp)
        local h2 = c2 and c2:FindFirstChild("HumanoidRootPart")
        if h2 then pcall(function() h2.Anchored = false end) end
        hiding = false
    end)
end

function M.hideSmart(name)
    if hiding then return end
    hiding = true

    if M.preferSky(name) then
        M.skyHide(name)
        return
    end

    local prompt, d, part = M.findHidePrompt(150)
    if prompt and part then
        local pname = (part.Parent and part.Parent.Name) or part.Name
        notify(("躲进 %s（%.0f m）"):format(pname, d or 0), "warn", 2.4)
        local c = M.charOf(lp)
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

    M.skyHide("无柜子")
end

pcall(function() RS:UnbindFromRenderStep("XHubSky") end)
RS:BindToRenderStep("XHubSky", Enum.RenderPriority.Last.Value - 2, function()
    if not skyHold then return end
    if os.clock() > skyHold.exp then skyHold = nil; return end
    local c = M.charOf(lp)
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = skyHold.cf
        pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
    end
end)

function M.findHideSpot(maxDist)
    local c = M.charOf(lp)
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
function M.hideNow()
    if hiding then return end
    hiding = true

    if S.hideMode == "sky" then
        -- 高空躲避: 抬到 Rush 够不到的高度,等它跑过去再落回
        local c = M.charOf(lp)
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
            local c2 = M.charOf(lp)
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
    local spot, d = M.findHideSpot(90)
    if not spot then
        notify("附近没找到柜子/床（可改用高空躲避）", "warn", 2.4)
        hiding = false
        return
    end
    notify(("自动躲避: 冲向 %s（%.0f m）"):format(spot.Parent and spot.Parent.Name or spot.Name, d or 0), "warn", 2.6)
    M.simWalk(spot.Position, 15)
    task.delay(1.0, function()
        pcall(M.autoPrompts, 9)
        task.delay(1.0, function()
            pcall(M.autoPrompts, 9)
            hiding = false
        end)
    end)
end

local HIDE_TRIGGER = { "rushmoving", "rush", "ambush", "seek", "glitch", "glitchcube", "cube", "dupe" }

task.spawn(function()
    local wasAlive = true
    while RUNNING do
        task.wait(0.5)
        local h = M.humOf(lp)
        local aliveNow = (h ~= nil) and (h.Health > 0)
        if wasAlive and not aliveNow then
            -- 刚死亡: 关飞行、交还相机、清 HUD 噪音
            if S.fly then M.setFly(false) end
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
    local warned = 0
    while RUNNING do
        task.wait(0.4)
        local ok, err = pcall(function()
            local name, d = nearestTrigger()
            if not name then return end
            if d <= S.hideDist then
                if S.autoHide then
                    M.hideSmart(name)
                else
                    if os.clock() - warned > 20 then
                        warned = os.clock()
                        notify(("检测到 %s %.0fm，但【自动躲避未开启】"):format(name, d), "warn", 4)
                    end
                end
            end
        end)
        if not ok then
            notify("躲避循环异常: " .. tostring(err), "err", 4)
            task.wait(2)
        end
    end
end)

--==================== 躲避触发扫描（不依赖 ESP，独立按名字找） ====================
--==== 杀戮光环（Kill Aura）====
auraTarget = nil

-- 独立扫描（不依赖 ESP 开关，NPC/玩家都能找到）
-- NPC ESP 事件快路径：新怪一出现立即上框（每 0.4 秒补一次）
task.spawn(function()
    while RUNNING do
        task.wait(0.4)
        if S.espNpc then
            local shown = 0
            for _ in pairs(npcStore) do shown = shown + 1 end
            local maxN = S.npcEspMax or 40
            if shown < maxN then
                for _, m in ipairs(M.scanTargets()) do
                    if shown >= maxN then break end
                    if not Players:GetPlayerFromCharacter(m) and not npcStore[m] then
                        pcall(M.ensureNpcEsp, m)
                        shown = shown + 1
                    end
                end
            end
        end
    end
end)

--==== 光环范围：白色圆环（纯描边，用 Drawing 画 48 段折线）====
local auraDraw = { lines = {}, ok = false }
local function ensureAuraDraw()
    if auraDraw.ok then return true end
    if not Drawing then
        if not S.auraNoDrawing then
            S.auraNoDrawing = true
            pcall(function() print("[aura] 本执行器没有 Drawing，范围圈不可用") end)
        end
        return false
    end
    for i = 1, 12 do
        local ln = Drawing.new("Line")
        ln.Thickness = 2
        ln.Color = Color3.fromRGB(255, 255, 255)
        ln.Transparency = 0.9
        ln.Visible = false
        auraDraw.lines[i] = ln
    end
    auraDraw.ok = true
    return true
end
local function hideAuraDraw()
    for _, ln in ipairs(auraDraw.lines) do pcall(function() ln.Visible = false end) end
end

--==== NPC 碰撞箱放大（本地探针）====
-- 说明：给每个 NPC 套一个放大的不可见部件，只有"客户端射线/鼠标目标"类判定会用到它，
-- 服务器自己的命中判定仍按原尺寸（这点无法从客户端改变）。
local hitProbes = {}

task.spawn(function()
    while RUNNING do
        task.wait(0.6)
        if S.npcHitbox then
            local mult = S.hitboxMult or 1.6
            for _, m in ipairs(M.scanTargets()) do
                if not Players:GetPlayerFromCharacter(m) then
                    local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
                    if root then
                        local probe = hitProbes[m]
                        if not (probe and probe.Parent) then
                            probe = Instance.new("Part")
                            probe.Name = "XHubHitProbe"
                            probe.Shape = Enum.PartType.Ball
                            probe.Transparency = 1
                            probe.CanCollide = false
                            probe.CanQuery = true
                            probe.CanTouch = true
                            probe.Massless = true
                            probe.Anchored = false
                            probe.Parent = m
                            local weld = Instance.new("WeldConstraint")
                            weld.Part0 = probe
                            weld.Part1 = root
                            weld.Parent = probe
                            hitProbes[m] = probe
                        end
                        local sz = root.Size
                        probe.Size = Vector3.new(sz.X * mult, sz.Y * mult * 1.6, sz.Z * mult)
                        probe.CFrame = root.CFrame
                    end
                end
            end
        else
            for m, p in pairs(hitProbes) do
                if p then pcall(function() p:Destroy() end) end
                hitProbes[m] = nil
            end
        end
    end
end)
--==== NPC 碰撞（本地）====
-- Roblox 的 NPC 是服务器拥有，碰撞判定在服务端；
-- 但客户端把 NPC 部件的 CanCollide 关掉后，你的角色能直接穿过它们（本地物理）
task.spawn(function()
    while RUNNING do
        task.wait(0.5)
        if S.npcNoCollide then
            for _, m in ipairs(M.scanTargets()) do
                if not Players:GetPlayerFromCharacter(m) then
                    for _, d in ipairs(m:GetDescendants()) do
                        if d:IsA("BasePart") and d.CanCollide then
                            pcall(function() d.CanCollide = false end)
                        end
                    end
                end
            end
        end
    end
end)
--==== 低血自动脱离（真实可行的"保命"手段）====
task.spawn(function()
    while RUNNING do
        task.wait(0.15)
        if S.lowHPFlee then
            local c = M.charOf(lp)
            local hum = c and c:FindFirstChildOfClass("Humanoid")
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 then
                local pct = hum.Health / math.max(1, hum.MaxHealth)
                if pct <= (S.fleePct or 0.35) and os.clock() - (S._lastFlee or 0) > 2 then
                    S._lastFlee = os.clock()
                    pcall(function() M.setNoclip(true) end)
                    pcall(function()
                        hrp.CFrame = hrp.CFrame * CFrame.new(0, 35, -25)
                        hrp.AssemblyLinearVelocity = Vector3.zero
                    end)
                    pcall(function()
                        auraLog(("血量 %.0f%% → 自动脱离（升空后退）"):format(pct * 100), Color3.fromRGB(255, 190, 120))
                    end)
                    task.delay(2.5, function()
                        if S.healthLock then return end
                        local c2 = M.charOf(lp)
                        local h2 = c2 and c2:FindFirstChildOfClass("Humanoid")
                        if h2 and h2.Health / math.max(1, h2.MaxHealth) > 0.5 then
                            pcall(function() M.setNoclip(false) end)
                        end
                    end)
                end
            end
        end
    end
end)
--==== 锁血 / 无敌（客户端侧）====
task.spawn(function()
    while RUNNING do
        task.wait(0.1)
        if S.healthLock then
            local c = M.charOf(lp)
            local hum = c and c:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                pcall(function()
                    if S.lockMax and hum.MaxHealth > 0 then hum.Health = hum.MaxHealth
                    else hum.Health = math.max(hum.Health, S.lockHP or 100) end
                end)
            end
        end
    end
end)

-- 死亡拦截：血量归零的瞬间立刻拉回（仅客户端）
task.spawn(function()
    while RUNNING do
        task.wait(0.2)
        if S.healthLock then
            local c = M.charOf(lp)
            local hum = c and c:FindFirstChildOfClass("Humanoid")
            if hum then
                pcall(function()
                    if not (S._hpConn and S._hpConnHum == hum) then
                        if S._hpConn then pcall(function() S._hpConn:Disconnect() end) end
                        S._hpConn = hum.HealthChanged:Connect(function(hp)
                            if S.healthLock and hp <= (S.lockKeep or 20) then
                                pcall(function() hum.Health = hum.MaxHealth end)
                            end
                        end)
                        S._hpConnHum = hum
                    end
                end)
            end
        end
    end
end)
--==== 秒杀 NPC（多策略尝试 + 生效校验）====
local DMG_REMOTE_KW = { "hit", "damage", "attack", "slash", "kill", "hurt", "swing", "melee", "shoot", "fire", "take" }
local dmgRemotesCache = nil

local function collectDamageRemotes()
    if dmgRemotesCache then return dmgRemotesCache end
    local list = {}
    local roots = { game:GetService("ReplicatedStorage"), workspace }
    for _, root in ipairs(roots) do
        local n = 0
        for _, d in ipairs(root:GetDescendants()) do
            n = n + 1
            if n > 8000 then break end
            if d:IsA("RemoteEvent") or d:IsA("UnreliableRemoteEvent") or d:IsA("RemoteFunction") then
                local nm = d.Name:lower()
                for _, k in ipairs(DMG_REMOTE_KW) do
                    if nm:find(k, 1, true) then list[#list + 1] = d break end
                end
            end
        end
    end
    dmgRemotesCache = list
    return list
end

-- 伤害/击杀统计：血量掉血 + 死亡事件 + 刀数计量
local dmgTrack = {}

function M.measureSwing(model)
    if not model or not model.Parent then return end
    local hum = model:FindFirstChildOfClass("Humanoid")
    local rec = dmgTrack[model]
    if not rec then
        rec = { n = 0, t0 = os.clock(), hp0 = hum and hum.Health or 0, hpDrop = 0 }
        dmgTrack[model] = rec
        if hum then
            pcall(function()
                hum.Died:Connect(function()
                    local dt = os.clock() - rec.t0
                    if rec.hpDrop > 0 then
                        auraLog(("击杀 %s：%d 刀 / %.1f 秒 · 累计掉血 %d HP"):format(model.Name, rec.n, dt, math.floor(rec.hpDrop)),
                            Color3.fromRGB(140, 255, 160))
                        S.measuredDmg = math.floor(rec.hpDrop / math.max(1, rec.n))
                        if S.measureDmg then
                            S.measureDmg = false
                            S.baseDamage = S.measuredDmg
                            pcall(function() if UIKEYS and UIKEYS.measureBtn then UIKEYS.measureBtn(("武器伤害: %d（实测）"):format(S.measuredDmg)) end end)
                        end
                    else
                        auraLog(("击杀 %s：%d 刀 / %.1f 秒 · 血量不可见（该游戏不暴露 Humanoid 血量）"):format(model.Name, rec.n, dt),
                            Color3.fromRGB(255, 200, 120))
                        if S.measureDmg then
                            S.measureDmg = false
                            pcall(function() if UIKEYS and UIKEYS.measureBtn then UIKEYS.measureBtn(("武器伤害: 不可测（%d 刀击杀）"):format(rec.n)) end end)
                        end
                    end
                    dmgTrack[model] = nil
                end)
            end)
        end
    end
    rec.n = rec.n + 1
    if hum then rec.hp0 = rec.hp0 or hum.Health end

    task.spawn(function()
        local minHp = hum and hum.Health or rec.hp0
        for _ = 1, 8 do
            task.wait(0.1)
            if not (hum and hum.Parent) then break end
            if hum.Health < minHp then minHp = hum.Health end
        end
        local drop = (rec.hp0 or minHp) - minHp
        if drop > 0.5 then
            rec.hpDrop = (rec.hpDrop or 0) + drop
            S.measuredDmg = math.floor(drop)
            auraLog(("本次命中 -%d HP（累计 %d）"):format(math.floor(drop), math.floor(rec.hpDrop)), Color3.fromRGB(170, 220, 170))
            if S.measureDmg then
                S.measureDmg = false
                S.baseDamage = S.measuredDmg
                auraLog(("实测武器伤害 = %d（已写入基础伤害）"):format(S.measuredDmg), Color3.fromRGB(140, 255, 160))
                pcall(function() if UIKEYS and UIKEYS.measureBtn then UIKEYS.measureBtn(("武器伤害: %d（实测）"):format(S.measuredDmg)) end end)
            end
            rec.hp0 = minHp
        else
            if S.measureDmg and rec.n >= 3 and os.clock() - (S._measNoHit or 0) > 3 then
                S._measNoHit = os.clock()
                auraLog(("已挥 %d 刀但血量不变 → 该游戏可能不暴露血量，继续砍到死会给出刀数"):format(rec.n),
                    Color3.fromRGB(255, 170, 120))
            end
        end
    end)
end
-- 判断某个参数是不是"角色类实例"（Humanoid / 带 Humanoid 的 Model / 角色部件）
function M.isCharLike(v)
    local ok, res = pcall(function()
        if v:IsA("Humanoid") then return true end
        if v:IsA("Model") then return v:FindFirstChildOfClass("Humanoid") ~= nil end
        if v:IsA("BasePart") then
            local anc = v.Parent
            while anc and anc ~= workspace do
                if anc:IsA("Model") and anc:FindFirstChildOfClass("Humanoid") then return true end
                anc = anc.Parent
            end
        end
        return false
    end)
    return ok and res
end

-- 重放"学习到的一次攻击"，把角色类参数换成当前光环目标（只换角色，不换武器）
function M.replayLearned(model, part)
    local list = S.learned
    if not list or #list == 0 then
        auraLog("还没有学到调用：先点「学习攻击」再手动砍一刀", Color3.fromRGB(255, 160, 120))
        return 0
    end
    local hum = model and model:FindFirstChildOfClass("Humanoid")
    local fired = 0
    local ATK_KW = { "fire", "shoot", "hit", "damage", "attack", "slash", "swing", "melee", "punch", "knock", "grab", "kill", "hurt", "stab", "strike" }
    local function isAttackCall(rec)
        if not S.replayFilter then return true end
        local nm = tostring(rec.remote.Name):lower()
        for _, k in ipairs(ATK_KW) do if nm:find(k, 1, true) then return true end end
        for i = 1, rec.n do if M.isCharLike(rec.args[i]) then return true end end
        return false
    end
    for _, rec in ipairs(list) do
        if rec.remote and rec.remote.Parent and isAttackCall(rec) then
            local out = {}
            for i = 1, rec.n do
                local v = rec.args[i]
                local tv = typeof(v)
                if tv == "Instance" then
                    if S.replaySwap and M.isCharLike(v) then
                        if v:IsA("Humanoid") then out[i] = hum or v
                        elseif v:IsA("Model") then out[i] = model or v
                        else out[i] = part or v end
                    else
                        out[i] = v
                    end
                elseif tv == "CFrame" then
                    out[i] = (S.replaySwap and part) and CFrame.new(part.Position) or v
                elseif tv == "Vector3" then
                    out[i] = (S.replaySwap and part) and part.Position or v
                elseif tv == "number" then
                    out[i] = v * (S.replayScale or 1)
                else
                    out[i] = v
                end
            end
            local ok = pcall(function()
                if rec.remote:IsA("RemoteEvent") or rec.remote:IsA("UnreliableRemoteEvent") then
                    rec.remote:FireServer(table.unpack(out, 1, rec.n))
                else
                    rec.remote:InvokeServer(table.unpack(out, 1, rec.n))
                end
            end)
            if ok then fired = fired + 1 end
        end
    end
    if S.auraDebug or fired == 0 then
        auraLog(("重放：%d/%d 个调用 → %s"):format(fired, #list, model and model.Name or "?"),
            fired > 0 and Color3.fromRGB(150, 220, 150) or Color3.fromRGB(255, 150, 120))
    end
    return fired
end
--==== 学习记录持久化（跨服务器/重注入）====
local LEARN_FILE = "xhub_learned.txt"

local function hasFS()
    return (type(writefile) == "function" and type(readfile) == "function")
end

local function argToTag(v)
    local tv = typeof(v)
    if tv == "Instance" then return "inst" end
    if tv == "number" then return "num:" .. tostring(v) end
    if tv == "boolean" then return "bool:" .. tostring(v) end
    if tv == "string" then return "str:" .. v:gsub("\n", " ") end
    if tv == "Vector3" then return "vec3" end
    if tv == "CFrame" then return "cf" end
    if tv == "nil" then return "nil" end
    return "skip"
end

function M.saveLearned()
    if not hasFS() then return false end
    local lines = {}
    for _, r in ipairs({ S.learnCall or (S.learned or {})[1] }) do
        if r.remote and r.remote.Parent then
            local tags = {}
            for i = 1, r.n do tags[i] = argToTag(r.args[i]) end
            lines[#lines + 1] = r.remote:GetFullName() .. "|" .. table.concat(tags, ",")
        end
    end
    local ok = pcall(function() writefile(LEARN_FILE, table.concat(lines, "\n")) end)
    return ok, #lines
end

local function resolvePath(path)
    local cur = game
    for part in string.gmatch(path, "[^%.]+") do
        local nxt = cur:FindFirstChild(part)
        if not nxt then return nil end
        cur = nxt
    end
    return cur
end

function M.loadLearned()
    if not hasFS() then return 0 end
    local ok, data = pcall(function() return readfile(LEARN_FILE) end)
    if not ok or not data or data == "" then return 0 end
    local out = {}
    for line in string.gmatch(data, "[^\n]+") do
        local path, tagstr = line:match("^(.-)|(.+)$")
        if path and tagstr then
            local r = resolvePath(path)
            if r then
                local tags = {}
                for t in string.gmatch(tagstr .. ",", "([^,]*),") do tags[#tags + 1] = t end
                local args, n = {}, 0
                for i, t in ipairs(tags) do
                    n = i
                    if t == "inst" then args[i] = nil
                    elseif t:sub(1, 4) == "num:" then args[i] = tonumber(t:sub(5)) or 0
                    elseif t:sub(1, 5) == "bool:" then args[i] = (t:sub(6) == "true")
                    elseif t:sub(1, 4) == "str:" then args[i] = t:sub(5)
                    elseif t == "vec3" then args[i] = Vector3.zero
                    elseif t == "cf" then args[i] = CFrame.new()
                    else args[i] = nil end
                end
                out[#out + 1] = { remote = r, args = args, n = n, name = r.Name, tpl = true }
            end
        end
    end
    S.learned = out
    S.learnCall = out[1]
    return #out
end
function M.tryKill(model, part)
    if not (model and model.Parent) then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    local hp0 = hum.Health
    local big = math.floor((S.killDamage or 1000000) * (S.dmgMult or 1))

    -- ① 客户端直伤（仅客户端拥有的 NPC 有效）
    pcall(function() hum:TakeDamage(big) end)

    -- ② 手持工具自带的远程（带伤害数值的各种组合）
    local c = M.charOf(lp)
    local tool = c and c:FindFirstChildOfClass("Tool")
    if tool then
        for _, d in ipairs(tool:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                local call = function(...)
                    local args = { ... }
                    if d:IsA("RemoteEvent") then
                        pcall(function() d:FireServer(table.unpack(args)) end)
                    else
                        pcall(function() d:InvokeServer(table.unpack(args)) end)
                    end
                end
                call(model)
                call(hum)
                call(part)
                call(part, big)
                call(model, big)
                call(hum, big)
                call(part.Position, big)
            end
        end
    end

    -- ③ 游戏内名字像"伤害"的远程
    for _, d in ipairs(collectDamageRemotes()) do
        if d:IsA("RemoteEvent") or d:IsA("UnreliableRemoteEvent") then
            pcall(function() d:FireServer(model) end)
            pcall(function() d:FireServer(hum) end)
            pcall(function() d:FireServer(part, big) end)
            pcall(function() d:FireServer(model, big) end)
            pcall(function() d:FireServer(part.Position, big) end)
        else
            pcall(function() d:InvokeServer(model, big) end)
        end
    end

    -- ④ 校验：0.35 秒后看血有没有掉
    task.delay(0.35, function()
        if hum.Parent then
            local hp1 = hum.Health
            if hp0 > 0 and hp1 < hp0 then
                auraLog(("秒杀生效: %s  -%d HP（%.0f→%.0f）"):format(model.Name, math.floor(hp0 - hp1), hp0, hp1),
                    Color3.fromRGB(140, 255, 140))
            else
                auraLog(("秒杀无效: %s（HP 未变，服务端判定）"):format(model.Name),
                    Color3.fromRGB(255, 140, 140))
            end
        end
    end)
    return true
end
--==== 光环日志面板（右侧，关闭即停光环）====
local auraPanel, auraLogFrame, auraLogRows = nil, nil, {}

local function ensureAuraPanel()
    if auraPanel and auraPanel.Parent then return auraPanel end
    auraPanel = mk("Frame", { Name = "XHubAuraPanel", Size = UDim2.fromOffset(330, 240),
        Position = UDim2.new(1, -346, 0, 120), BackgroundColor3 = Color3.fromRGB(14, 16, 22),
        BorderSizePixel = 0, ZIndex = 30 }, gui)
    mk("UICorner", { CornerRadius = UDim.new(0, 8) }, auraPanel)
    mk("UIStroke", { Color = Color3.fromRGB(120, 40, 40), Thickness = 1 }, auraPanel)

    local head = mk("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = Color3.fromRGB(28, 16, 16),
        BorderSizePixel = 0, ZIndex = 31 }, auraPanel)
    mk("TextLabel", { Text = "杀戮光环", BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -60, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.fromRGB(255, 170, 170), ZIndex = 32 }, head)
    local closeBtn = mk("TextButton", { Text = "×", BackgroundTransparency = 1, Position = UDim2.new(1, -28, 0, 0),
        Size = UDim2.fromOffset(28, 28), Font = Enum.Font.GothamBold, TextSize = 16,
        TextColor3 = Color3.fromRGB(255, 120, 120), ZIndex = 32 }, head)
    closeBtn.MouseButton1Click:Connect(function()
        S.killAura = false
        auraPanel.Visible = false
        hideAuraDraw()
        notify("杀戮光环已关闭（日志窗口）", "info", 2)
    end)

    auraLogFrame = mk("ScrollingFrame", { Size = UDim2.new(1, -12, 1, -38), Position = UDim2.new(0, 6, 0, 32),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 31 }, auraPanel)
    mk("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, auraLogFrame)
    mk("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 2) }, auraLogFrame)

    return auraPanel
end

local auraLogOrder = 0
--==== 日志 Hub（专属大窗口）====
local hub, hubList, hubRows, hubOrder, hubPaused = nil, nil, {}, 0, false
local hubBuf = {}

local function hubPush(text, color)
    if not (hub and hub.Parent) then return end
    if hubPaused then
        hubBuf[#hubBuf + 1] = { text = text, color = color }
        if #hubBuf > 200 then table.remove(hubBuf, 1) end
        return
    end
    hubOrder = hubOrder + 1
    local row = mk("TextLabel", { Text = os.date("%H:%M:%S ") .. text, BackgroundTransparency = 1,
        Size = UDim2.new(1, -8, 0, 16), TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.Code, TextSize = 11, TextColor3 = color or Color3.fromRGB(210, 214, 224),
        LayoutOrder = hubOrder, ZIndex = 52 }, hubList)
    hubRows[#hubRows + 1] = row
    if #hubRows > 200 then
        local old = table.remove(hubRows, 1)
        if old then old:Destroy() end
    end
    pcall(function() hubList.CanvasPosition = Vector2.new(0, math.max(0, hubList.AbsoluteCanvasSize.Y)) end)
end

local function ensureHub()
    if hub and hub.Parent then return hub end
    hub = mk("Frame", { Name = "XHubLogHub", Size = UDim2.fromOffset(520, 400),
        Position = UDim2.new(0.5, -260, 0.5, -200), BackgroundColor3 = Color3.fromRGB(12, 14, 19),
        BorderSizePixel = 0, ZIndex = 50 }, gui)
    mk("UICorner", { CornerRadius = UDim.new(0, 10) }, hub)
    mk("UIStroke", { Color = Color3.fromRGB(70, 90, 120), Thickness = 1 }, hub)

    local head = mk("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Color3.fromRGB(22, 26, 34),
        BorderSizePixel = 0, ZIndex = 51 }, hub)
    local title = mk("TextLabel", { Text = "XHub 日志 Hub", BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -220, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold, TextSize = 13,
        TextColor3 = Color3.fromRGB(140, 200, 255), ZIndex = 52 }, head)

    local function miniBtn(text, x, w, cb, col)
        local b = mk("TextButton", { Text = text, BackgroundTransparency = 1,
            Position = UDim2.new(1, x, 0, 4), Size = UDim2.fromOffset(w, 22),
            Font = Enum.Font.Gotham, TextSize = 11,
            TextColor3 = col or Color3.fromRGB(180, 200, 230), ZIndex = 52 }, head)
        b.MouseButton1Click:Connect(cb)
        return b
    end

    miniBtn("清空", -196, 40, function()
        for _, r in ipairs(hubRows) do pcall(function() r:Destroy() end) end
        hubRows = {}
    end)
    miniBtn("复制", -154, 40, function()
        local lines = {}
        for _, r in ipairs(hubRows) do lines[#lines + 1] = r.Text end
        local txtAll = table.concat(lines, "\n")
        local ok = pcall(function()
            if setclipboard then setclipboard(txtAll) elseif toclipboard then toclipboard(txtAll) end
        end)
        hubPush(ok and "已复制全部日志" or "本执行器不支持剪贴板", Color3.fromRGB(160, 220, 160))
    end)
    miniBtn("暂停", -112, 40, function()
        hubPaused = not hubPaused
        hubPush(hubPaused and "日志已暂停" or "日志已恢复", Color3.fromRGB(255, 200, 120))
        if not hubPaused then
            local pending = hubBuf
            hubBuf = {}
            for _, e in ipairs(pending) do hubPush(e.text, e.color) end
        end
    end)
    miniBtn("×", -30, 22, function() hub.Visible = false end, Color3.fromRGB(255, 120, 120))

    hubList = mk("ScrollingFrame", { Size = UDim2.new(1, -16, 1, -40), Position = UDim2.new(0, 8, 0, 34),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 51 }, hub)
    mk("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder }, hubList)
    mk("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 2) }, hubList)

    -- 拖动
    local dragging, dragStart, startPos = false, nil, nil
    head.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging, dragStart, startPos = true, i.Position, hub.Position
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - dragStart
            hub.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)

    return hub
end
local function auraLog(text, color)
    pcall(hubPush, text, color)
    local panel = ensureAuraPanel()
    panel.Visible = true
    auraLogOrder = auraLogOrder + 1
    local row = mk("TextLabel", { Text = os.date("%H:%M:%S ") .. text, BackgroundTransparency = 1,
        Size = UDim2.new(1, -6, 0, 16), TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.Code, TextSize = 11,
        TextColor3 = color or Color3.fromRGB(210, 210, 220), LayoutOrder = auraLogOrder, ZIndex = 32 }, auraLogFrame)
    table.insert(auraLogRows, row)
    if #auraLogRows > 40 then
        local old = table.remove(auraLogRows, 1)
        if old then old:Destroy() end
    end
end

task.spawn(function()
    while RUNNING do
        local dt = task.wait()
        S._ringFrame = ((S._ringFrame or 0) + 1) % 3
        if S.killAura and (S.auraRing ~= false) then
            if S._ringFrame == 0 then
            if ensureAuraDraw() then
                local c = M.charOf(lp)
                local hrp = c and c:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local r = S.auraRadius or 20
                    local center = hrp.Position - Vector3.new(0, 2.6, 0)
                    local n = 12
                    for i = 1, n do
                        local a1 = (i - 1) / n * math.pi * 2
                        local a2 = i / n * math.pi * 2
                        local p1 = center + Vector3.new(math.cos(a1) * r, 0, math.sin(a1) * r)
                        local p2 = center + Vector3.new(math.cos(a2) * r, 0, math.sin(a2) * r)
                        local s1, on1 = cam:WorldToViewportPoint(p1)
                        local s2, on2 = cam:WorldToViewportPoint(p2)
                        local ln = auraDraw.lines[i]
                        if on1 and on2 and s1.Z > 0 and s2.Z > 0 then
                            ln.From = Vector2.new(s1.X, s1.Y)
                            ln.To = Vector2.new(s2.X, s2.Y)
                            ln.Visible = true
                        else
                            ln.Visible = false
                        end
                    end
                else
                    hideAuraDraw()
                end
            end
        else
            hideAuraDraw()
        end
    end
    end
end)
-- 多目标查找：范围内按距离排序（一刀多砍用）
local function auraFindTargets(maxN)
    maxN = maxN or 5
    local c = M.charOf(lp)
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return {} end
    local list = {}
    for _, m in ipairs(M.scanTargets()) do
        if m ~= c then
            local hum = m:FindFirstChildOfClass("Humanoid")
            local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
            if hum and root and hum.Health > 0 then
                local isP = Players:GetPlayerFromCharacter(m) ~= nil
                local allowed = (isP and S.auraPlayer) or ((not isP) and S.auraNpc)
                if allowed then
                    local d = (root.Position - hrp.Position).Magnitude
                    if d <= S.auraRadius then
                        list[#list + 1] = { m = m, p = root, d = d }
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.d < b.d end)
    while #list > maxN do table.remove(list) end
    return list
end
local function auraFindTarget()
    local c = M.charOf(lp)
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local bestM, bestP, bestD = nil, nil, math.huge
    for _, m in ipairs(M.scanTargets()) do
        if m ~= c then
            local hum = m:FindFirstChildOfClass("Humanoid")
            local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
            if hum and root and hum.Health > 0 then
                local isP = Players:GetPlayerFromCharacter(m) ~= nil
                local allowed = (isP and S.auraPlayer) or ((not isP) and S.auraNpc)
                if allowed then
                    local d = (root.Position - hrp.Position).Magnitude
                    if d <= S.auraRadius and d < bestD then
                        bestM, bestP, bestD = m, root, d
                    end
                end
            end
        end
    end
    return bestP, bestM, bestD
end

task.spawn(function()
    while RUNNING do
        task.wait(S.auraInt or 0.15)
        if S.killAura then
            pcall(function()
                local targets = auraFindTargets(S.auraMulti and (S.auraMax or 5) or 1)
                local p, m, d = nil, nil, nil
                if targets[1] then p, m, d = targets[1].p, targets[1].m, targets[1].d end
                if not p then
                    auraPart = nil
                    auraTarget = nil
                    if os.clock() - (S.auraLogT or 0) > 4 then
                        S.auraLogT = os.clock()
                        auraLog(("半径 %d 内无目标"):format(S.auraRadius or 20), Color3.fromRGB(150, 150, 160))
                    end
                    return
                end
                auraPart = p
                if S.auraLastTarget ~= m then
                    S.auraLastTarget = m
                    auraLog(("锁定 %s  %.0f m"):format(m.Name, d), Color3.fromRGB(255, 190, 120))
                end
                auraTarget = ("%s  %.0fm"):format(m.Name, d)

                -- ① 先把武器远程的改写窗口打开，把射击方向改成目标
                if S.auraRemote then fireUntil = os.clock() + 0.3 end


                -- 面向目标（只转身，不移动）
                pcall(function()
                    local c1 = M.charOf(lp)
                    local h1 = c1 and c1:FindFirstChild("HumanoidRootPart")
                    if h1 then
                        h1.CFrame = CFrame.lookAt(h1.Position, Vector3.new(p.Position.X, h1.Position.Y, p.Position.Z))
                    end
                end)

                -- ③ 真正走游戏判定的攻击：激活手里工具
                local c = M.charOf(lp)
                local tool = c and c:FindFirstChildOfClass("Tool")
                if not tool and os.clock() - (S.auraNoTool or 0) > 5 then
                    S.auraNoTool = os.clock()
                    auraLog("没有手持工具 → 光环无法造成伤害", Color3.fromRGB(255, 120, 120))
                end
                if S.killAura and S.instantKill and os.clock() - (S.lastKillTry or 0) > 1.2 then
                    S.lastKillTry = os.clock()
                    pcall(M.tryKill, m, p)
                end

                local meleeOK = S.auraRanged or (d and d <= (S.meleeRange or 8))
                if not meleeOK and os.clock() - (S.nearWarn or 0) > 4 then
                    S.nearWarn = os.clock()
                    auraLog(("目标 %.0f m，超出近战距离 %d m（走近或开远程武器模式）"):format(d or 0, S.meleeRange or 8), Color3.fromRGB(255, 190, 120))
                end
                local nowT = os.clock()
                local fireGap = S.auraFireInt or 0.25
                if tool and meleeOK and nowT - (S.lastAuraSwing or 0) >= fireGap then
                    S.lastAuraSwing = nowT
                    pcall(M.measureSwing, m)
                    pcall(function()
                        local cc = M.charOf(lp)
                        local hh = cc and cc:FindFirstChildOfClass("Humanoid")
                        if hh and tool.Parent ~= cc then hh:EquipTool(tool) end
                    end)
                    if S.learnCall and S.learnCall.remote and S.learnCall.remote.Parent then
                        -- 已学会：只重放这一条真实攻击
                        local okN = M.replayLearned(m, p) or 0
                        if okN == 0 then pcall(function() tool:Activate() end) end
                    else
                        -- 还没学会：第一次开光环自动进入学习
                        if not S.learnActive then
                            S.learnActive = true
                            pcall(function() auraLog("未学习：现在手动砍目标一刀即可（只记这一次）", Color3.fromRGB(255, 220, 120)) end)
                        end
                        pcall(function() tool:Activate() end)
                    end
                    -- 工具内远程只打一次不带参调用（缓存，避免每帧遍历）
                    if not (S._toolCache and S._toolCacheTool == tool) then
                        local list = {}
                        for _, dd in ipairs(tool:GetDescendants()) do
                            if dd:IsA("RemoteEvent") or dd:IsA("RemoteFunction") then list[#list + 1] = dd end
                        end
                        S._toolCache, S._toolCacheTool = list, tool
                    end
                    local hitList = S.auraMulti and targets or { { m = m, p = p, d = d } }
                    local dmg = math.floor((S.baseDamage or 20) * (S.dmgMult or 1))
                    local reps = math.max(1, S.dmgRepeat or 1)
                    for _rep = 1, reps do
                      for _, tgt in ipairs(hitList) do
                        if tgt.p and tgt.p.Parent then
                            for _, dd in ipairs(S._toolCache or {}) do
                                if dd:IsA("RemoteEvent") then
                                    pcall(function() dd:FireServer() end)
                                    pcall(function() dd:FireServer(tgt.m) end)
                                    pcall(function() dd:FireServer(tgt.p) end)
                                    pcall(function() dd:FireServer(tgt.p.Position) end)
                                    pcall(function() dd:FireServer(tgt.p, dmg) end)
                                    pcall(function() dd:FireServer(tgt.m, dmg) end)
                                    pcall(function() dd:FireServer(tgt.p.Position, dmg) end)
                                else
                                    pcall(function() dd:InvokeServer(tgt.m, dmg) end)
                                end
                            end
                        end
                      end
                    end
                    if S.auraMulti then auraLog(("一刀多砍: %d 个目标"):format(#hitList), Color3.fromRGB(255, 220, 140)) end
                end
                if S.auraLastTarget and os.clock() - (S.auraFireLog or 0) > 2 then
                    S.auraFireLog = os.clock()
                    auraLog(("开火: %s"):format(tool and tool.Name or "无工具"), Color3.fromRGB(190, 230, 190))
                end
                if S.auraDebug then
                    print(("[aura] target=%s d=%.0f tool=%s remoteAim=%s")
                        :format(m.Name, d, tool and tool.Name or "none", tostring(S.remoteAim)))
                end
                if not (auraHud and auraHud.Parent) then
                    auraHud = mk("TextLabel", { Name = "XHubAura", Size = UDim2.fromOffset(300, 22),
                        Position = UDim2.new(0.5, -150, 0, 62), BackgroundTransparency = 0.3,
                        BackgroundColor3 = Color3.fromRGB(30, 18, 18), Text = "",
                        Font = Enum.Font.GothamBold, TextSize = 12,
                        TextColor3 = Color3.fromRGB(255, 140, 140), ZIndex = 41 }, gui)
                end
            end)
        else
            auraPart = nil
            auraTarget = nil
        end
    end
end)
--==== 玩家旋转（Spin）：RenderStepped 最高优先级 + 关掉 AutoRotate 才不会被打回 ====
local spinYaw = 0
local spinLocked = false
pcall(function() RS:UnbindFromRenderStep("XHubSpin") end)
RS:BindToRenderStep("XHubSpin", Enum.RenderPriority.Last.Value - 5, function(dt)
    local c = M.charOf(lp)
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    if not S.spin or not hrp or M.isSeated() then
        if spinLocked and hum then
            pcall(function() hum.AutoRotate = true end)
            spinLocked = false
        end
        return
    end
    if hum and not spinLocked then
        pcall(function() hum.AutoRotate = false end)
        spinLocked = true
    end
    spinYaw = (spinYaw + math.rad(S.spinSpeed) * dt) % (math.pi * 2)
    pcall(function()
        hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, spinYaw, 0)
    end)
end)
local auraTarget = nil        -- forward decl (kill aura fills it)
local auraHud = nil
-- HUD: shows which mob triggered the hide (and why)
local hideHud, hideHudUntil = nil, 0
function M.showHideSource(text)
    if not (hideHud and hideHud.Parent) then
        hideHud = mk("TextLabel", { Name = "XHubHideSrc", Size = UDim2.fromOffset(420, 24),
            Position = UDim2.new(0.5, -210, 0, 36), BackgroundTransparency = 0.25,
            BackgroundColor3 = Color3.fromRGB(20, 24, 30), Text = "",
            Font = Enum.Font.GothamBold, TextSize = 13,
            TextColor3 = Color3.fromRGB(255, 200, 120), ZIndex = 41 }, gui)
    end
    hideHud.Text = text
    hideHudUntil = os.clock() + 12
end

task.spawn(function()
    while RUNNING do
        task.wait(0.5)
        if hideHud and hideHud.Parent then
            if os.clock() > hideHudUntil then hideHud.Text = "" end
        end
        if auraHud and auraHud.Parent then
            if S.killAura and auraTarget then
                auraHud.Text = "光环目标: " .. auraTarget
            else
                auraHud.Text = ""
            end
        end
    end
end)
-- TIER1: deadly mobs (always win, own 8s cooldown)
local TIER1 = { "rushmoving", "rush", "ambushmoving", "ambush" }
-- TIER2: chasers / noise (opt-in, 15s cooldown)
local TIER2 = { "seekmovingnewclone", "seek", "figure", "glitch" }

nearestTrigger = function()
    local c = M.charOf(lp)
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local t1D, t1N = math.huge, nil
    local t2D, t2N = math.huge, nil

    local function consider(m)
        if not m or not m.Parent then return end
        local nm = m.Name:lower()
        if nm:find("fake", 1, true) or nm:find("dupe", 1, true)
           or nm:find("cube", 1, true) or nm:find("sideroom", 1, true) then return end
        local m1, m2 = false, false
        for _, k in ipairs(TIER1) do
            if nm:find(k, 1, true) then m1 = true break end
        end
        if not m1 and S.hideTier2 then
            for _, k in ipairs(TIER2) do
                if nm:find(k, 1, true) then m2 = true break end
            end
        end
        if not (m1 or m2) then return end
        local d = M.distTo(m)
        if not d then return end
        if m1 and d < t1D then t1D, t1N = d, m.Name end
        if m2 and d < t2D then t2D, t2N = d, m.Name end
    end

    -- ① ESP 已经追踪到的实体（最可靠：标签上能看到就说明它在这里）
    for m in pairs(entStore) do consider(m) end

    -- ② 再扫全场兜底
    for _, m in ipairs(M.scanAll(4000)) do
        if m:IsA("Model") then
            local nm = m.Name:lower()
            if not nm:find("fake", 1, true) then
                local m1, m2 = false, false
                for _, k in ipairs(TIER1) do
                    if nm:find(k, 1, true) then m1 = true break end
                end
                if not m1 and S.hideTier2 then
                    for _, k in ipairs(TIER2) do
                        if nm:find(k, 1, true) then m2 = true break end
                    end
                end
                if m1 or m2 then
                    local d = M.distTo(m)
                    if d then
                        if m1 and d < t1D then t1D, t1N = d, m.Name end
                        if m2 and d < t2D then t2D, t2N = d, m.Name end
                    end
                end
            end
        end
    end

    if t1N then return t1N, t1D, 1 end
    if t2N then return t2N, t2D, 2 end
    return nil
end

task.spawn(function()
    local warned = 0
    local dbgT = 0
    while RUNNING do
        task.wait(0.35)
        if S.hideDebug and os.clock() - dbgT > 2 then
            dbgT = os.clock()
            local n, dd, tr = nearestTrigger()
            local entCount, rushCount = 0, 0
            for mm in pairs(entStore) do
                entCount = entCount + 1
                local mn = mm.Name:lower()
                if mn:find("rush", 1, true) or mn:find("ambush", 1, true) then rushCount = rushCount + 1 end
            end
            print(("[hide] auto=%s tier2=%s dist=%s | 最近=%s %.0fm T%s | hiding=%s cd1=%.0fs | entStore=%d rush=%d")
                :format(tostring(S.autoHide), tostring(S.hideTier2), tostring(S.hideDist),
                        tostring(n), dd or -1, tostring(tr),
                        tostring(hiding), os.clock() - (S.lastHideT1 or 0), entCount, rushCount))
        end
        local ok, err = pcall(function()
            local name, d, tier = nearestTrigger()
            if not name then return end
            if d > S.hideDist then return end

            if not S.autoHide then
                if os.clock() - warned > 15 then
                    warned = os.clock()
                    notify(("检测到 %s %.0fm（未开启自动躲避）"):format(name, d), "warn", 3.5)
                    M.showHideSource(("未躲避（开关关）: %s  ·  %.0f m  ·  T%d"):format(name, d, tier))
                end
                return
            end

            local cd = (tier == 1) and 8 or 15
            local last = (tier == 1) and (S.lastHideT1 or 0) or (S.lastHideT2 or 0)
            if os.clock() - last < cd then
                if os.clock() - (S.cdWarn or 0) > 12 then
                    S.cdWarn = os.clock()
                    notify(("%s %.0fm：冷却中（剩 %.0fs）"):format(name, d, cd - (os.clock() - last)), "info", 2.5)
                end
                return
            end

            if tier == 1 and hiding then
                -- 已经在空中：不落地，直接把停留时间往后延
                if skyHold then
                    skyHold.exp = math.max(skyHold.exp, os.clock()) + 2.5
                    if os.clock() - (S.extendWarn or 0) > 2 then
                        S.extendWarn = os.clock()
                        notify(("T1 到来，延长升空 +2.5s（%s %.0fm）"):format(name, d), "warn", 2)
                    end
                end
                S.lastHideT1 = os.clock()
            end
            if tier == 1 then S.lastHideT1 = os.clock() else S.lastHideT2 = os.clock() end
            notify(("触发躲避[T%d]: %s %.0fm"):format(tier, name, d), "ok", 2)
            M.showHideSource(("躲避源: %s  ·  %.0f m  ·  T%d    触发于 %s")
                :format(name, d, tier, os.date("%H:%M:%S")))
            M.hideSmart(name)
        end)
        if not ok then
            notify("躲避循环异常: " .. tostring(err), "err", 4)
            task.wait(2)
        end
    end
end)
--==================== A* 网格寻路（类似 Baritone 的思路） ====================
local NAV = { running = false, gen = 0, cell = 3, radius = 16 }
local navHud

function M.navLog(txt)
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

function M.navParams()
    local p = RaycastParams.new()
    p.FilterType = Enum.RaycastFilterType.Exclude
    local list = { gui }
    local ch = M.charOf(lp)
    if ch then table.insert(list, ch) end
    p.FilterDescendantsInstances = list
    return p
end

function M.sampleCell(x, z, yHint)
    local params = M.navParams()
    local hit = workspace:Raycast(Vector3.new(x, yHint + 8, z), Vector3.new(0, -26, 0), params)
    if not hit or hit.Normal.Y < 0.55 then return nil end
    local y = hit.Position.Y
    local up = workspace:Raycast(Vector3.new(x, y + 1.4, z), Vector3.new(0, 4.2, 0), params)
    if up then return nil end
    return y
end

function M.navFindPath(startPos, goalPos)
    local cell, R = NAV.cell, NAV.radius
    local sx, sz = math.floor(startPos.X / cell), math.floor(startPos.Z / cell)
    local gx, gz = math.floor(goalPos.X / cell), math.floor(goalPos.Z / cell)
    local function kk(x, z) return x .. ":" .. z end
    local nodes, open, closed = {}, {}, {}
    local function node(x, z)
        local k = kk(x, z)
        if nodes[k] then return nodes[k] end
        local y = M.sampleCell(x * cell, z * cell, startPos.Y + 4)
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

navTo = function(pos)
    if NAV.running then
        NAV.gen = NAV.gen + 1
        NAV.running = false
    end
    local c, h = M.charOf(lp), M.humOf(lp)
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not (h and hrp) then
        notify("没有角色，无法寻路", "err", 3)
        return
    end
    M.navLog("A* 计算中…（射线采样网格）")
    notify("A* 计算中…", "info", 1.5)
    local path = M.navFindPath(hrp.Position, pos)
    if not path or #path == 0 then
        notify("A* 找不到路径 → 退回直线移动", "warn", 3)
        M.simWalk(pos, 25)
        return
    end
    NAV.running = true
    NAV.gen = NAV.gen + 1
    local gen = NAV.gen
    notify(("A* 成功: %d 个路点，开始移动"):format(#path), "ok", 2.5)
    M.navLog(("路点 %d 个，目标 (%.0f, %.0f)"):format(#path, pos.X, pos.Z))
    task.spawn(function()
        -- 不依赖 Humanoid:MoveTo（很多游戏每帧覆写移动），直接按合法速度 CFrame 推进
        local spd = math.max(12, math.min(S.walkSpeed or 16, 20))
        local i, t0 = 1, os.clock()
        while NAV.gen == gen and i <= #path and os.clock() - t0 < 90 do
            local c2, h2 = M.charOf(lp), M.humOf(lp)
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
                    M.navLog(("路点 %d/%d · 距目标 %.0f · 剩余 %.0f studs")
                        :format(i, #path, (hrp2.Position - pos).Magnitude, flat.Magnitude))
                    t0 = os.clock()
                end
            end
            task.wait(0.03)
        end
        NAV.running = false
        M.navLog(("结束 · 剩余 %.0f studs"):format((pos - (M.charOf(lp) and M.charOf(lp):FindFirstChild("HumanoidRootPart").Position or pos)).Magnitude))
    end)
end

--==================== 场景物体绘制（柜子/床/抽屉，纯渲染，不计入实体） ====================
local SCENE_KW = { "closet", "wardrobe", "bed", "locker", "drawer", "dresser",
                   "crate", "柜", "床", "抽屉" }
local sceneStore = {}
local doorStore = {}
local leverStore = {}

local DOOR_BAD = { "frame", "blocked", "fake", "start", "end", "hidden", "lock", "doorway" }

isRealDoor = function(nm)
    if not (nm:find("door", 1, true) or nm:find("门", 1, true)) then return false end
    for _, k in ipairs(DOOR_BAD) do
        if nm:find(k, 1, true) then return false end
    end
    return true
end

local LEVER_KW = { "lever", "拉杆", "switch", "handle", "valve" }

function M.isLever(nm)
    for _, k in ipairs(LEVER_KW) do
        if nm:find(k, 1, true) then return true end
    end
    return false
end

function M.ensureLever(m)
    local o = leverStore[m]
    if not o then o = {}; leverStore[m] = o end
    if not (o.hl and o.hl.Parent) then
        o.hl = mk("Highlight", { Name = "XHubLever",
            FillColor = Color3.fromRGB(255, 60, 220), FillTransparency = 0.4,
            OutlineColor = Color3.fromRGB(255, 180, 245), OutlineTransparency = 0,
            DepthMode = Enum.HighlightDepthMode.AlwaysOnTop }, m)
    end
    o.hl.Parent = m
    local part = M.firstPart(m)
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
    local c = M.charOf(lp)
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if o.dlbl and hrp then
        o.dlbl.Text = ("%.0f m"):format((part.Position - hrp.Position).Magnitude)
    end
end

function M.ensureScene(m)
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

function M.ensureDoor(m)
    local o = doorStore[m]
    if not o then o = {}; doorStore[m] = o end
    if not (o.hl and o.hl.Parent) then
        o.hl = mk("Highlight", { Name = "XHubDoor",
            FillColor = Color3.fromRGB(255, 205, 80), FillTransparency = 0.55,
            OutlineColor = Color3.fromRGB(255, 235, 160), OutlineTransparency = 0,
            DepthMode = Enum.HighlightDepthMode.AlwaysOnTop }, m)
    end
    o.hl.Parent = m
    local part = M.firstPart(m)
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
    local c = M.charOf(lp)
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if o.dlbl and hrp then
        o.dlbl.Text = ("%.0f m"):format((part.Position - hrp.Position).Magnitude)
    end
end

task.spawn(function()
    while RUNNING do
        task.wait(S.fastScan and 1.2 or 0.5)
        if S.scenery or S.doors or S.lever then
            local c0 = M.charOf(lp)
            local hrp0 = c0 and c0:FindFirstChild("HumanoidRootPart")
            local n = 0
            for _, m in ipairs(M.scanAll(2500)) do
                if m:IsA("Model") then
                    n = n + 1
                    if n > 2500 then break end
                    local known = sceneStore[m] or doorStore[m] or leverStore[m]
                    local nm = m.Name:lower()
                    local d = hrp0 and M.distTo(m) or nil
                    if known then
                        -- already drawn: just refresh distance cheaply, skip rework
                    elseif d and d > 150 then
                        -- 远处的不要，过会儿再处理
                    elseif S.doors and isRealDoor(nm) then
                        pcall(M.ensureDoor, m)
                    elseif S.lever and M.isLever(nm) then
                        pcall(M.ensureLever, m)
                        if S.leverAuto and d and d <= 14 then
                            local part = M.firstPart(m)
                            if part then
                                pcall(M.autoPrompts, 16)
                            end
                        end
                    elseif S.scenery then
                        for _, k in ipairs(SCENE_KW) do
                            if nm:find(k:lower(), 1, true) then
                                pcall(M.ensureScene, m)
                                break
                            end
                        end
                    end
                end
            end
            local dead = {}
            for m, o in pairs(sceneStore) do
                if not m.Parent then M.destroyEnt(o); dead[#dead + 1] = m end
            end
            for _, m in ipairs(dead) do sceneStore[m] = nil end
            local dead2 = {}
            for m, o in pairs(doorStore) do
                local p2 = m.Parent and M.firstPart(m)
                local opened = false
                if o.cf0 and p2 then
                    if p2.CFrame.LookVector:Dot(o.cf0.LookVector) < 0.94 then opened = true end
                    if (p2.Position - o.cf0.Position).Magnitude > 3 then opened = true end
                end
                if (not m.Parent) or opened then M.destroyEnt(o); dead2[#dead2 + 1] = m end
            end
            for _, m in ipairs(dead2) do doorStore[m] = nil end
            local dead3 = {}
            for m, o in pairs(leverStore) do
                if not m.Parent then M.destroyEnt(o); dead3[#dead3 + 1] = m end
            end
            for _, m in ipairs(dead3) do leverStore[m] = nil end
        end
        if not S.scenery and next(sceneStore) ~= nil then
            for _, o in pairs(sceneStore) do M.destroyEnt(o) end
            sceneStore = {}
        end
        if not S.doors and next(doorStore) ~= nil then
            for _, o in pairs(doorStore) do M.destroyEnt(o) end
            doorStore = {}
        end
        if not S.lever and next(leverStore) ~= nil then
            for _, o in pairs(leverStore) do M.destroyEnt(o) end
            leverStore = {}
        end
    end
end)

--==================== 刷新即时捕获 + 声音线索（放在所有定义之后） ====================
local SOUND_HINT = { "rush", "ambush", "seek", "figure", "screech" }

workspace.DescendantAdded:Connect(function(d)
    if d:IsA("Model") and S.entityEsp and M.isEntityModel(d) then
        task.defer(function() if d.Parent then pcall(M.ensureEnt, d) end end)
    end
    if (d:IsA("Tool") or d:IsA("Model")) and S.itemEsp and M.isItemInst(d) then
        task.defer(function() if d.Parent then pcall(M.ensureItem, d) end end)
    end
    if d:IsA("Model") then
        local nm2 = d.Name:lower()
        if S.doors and isRealDoor(nm2) then pcall(M.ensureDoor, d) end
        if S.lever and M.isLever(nm2) then pcall(M.ensureLever, d) end
        if S.scenery then
            for _, k in ipairs(SCENE_KW) do
                if nm2:find(k:lower(), 1, true) then pcall(M.ensureScene, d); break end
            end
        end
    end
    if d:IsA("Sound") then
        local sn = d.Name:lower()
        local isFake = sn:find("fake", 1, true) ~= nil
        for _, k in ipairs(SOUND_HINT) do
            if sn:find(k, 1, true) then
                notify(("声音线索: %s%s"):format(d.Name, isFake and "（假事件，忽略）" or ""), "info", 3)
                if S.hideSound and S.autoHide and not isFake then
                    pcall(M.hideSmart, d.Name)
                end
                break
            end
        end
    end
end)

--==== NPC / 怪物 ESP（独立模块：方框 + 名字 + 血量 + 距离） ====
npcStore = {}

function M.ensureNpcEsp(m)
    local dNow = M.distTo(m)
    local maxD = S.npcEspDist or 300
    local tooFar = dNow and dNow > maxD
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
    if o.tag then o.tag.Enabled = not tooFar end
    if o.hl then o.hl.Enabled = not tooFar end
    local hum = m:FindFirstChildOfClass("Humanoid")
    local hp = hum and math.floor(hum.Health) or 0
    if o.lbl then o.lbl.Text = m.Name end
    if o.dlbl then
        local d = M.distTo(m)
        o.dlbl.Text = d and ("HP %d · %.0f m"):format(hp, d) or ("HP %d"):format(hp)
    end
end

task.spawn(function()
    while RUNNING do
        task.wait(S.fastScan and 0.8 or 0.4)
        if S.espNpc then
            local n = 0
            npcTick = (npcTick or 0) + 1
            local refresh = (npcTick % 3 == 0)
            local known = 0
            for mm in pairs(npcStore) do known = known + 1 end
            for _, m in ipairs(M.scanTargets()) do
                if not Players:GetPlayerFromCharacter(m) then
                    n = n + 1
                    if n > 3000 then break end
                    local o = npcStore[m]
                    if o and o.tag and o.tag.Parent and not refresh then
                        -- 已绘制过，跳过（下一拍再刷新距离）
                    elseif (not o) and known >= (S.npcEspMax or 40) then
                        -- 超过上限，不再新增
                    elseif m:FindFirstChildOfClass("Humanoid") then
                        pcall(M.ensureNpcEsp, m)
                    end
                end
            end
            local dead = {}
            for m, o in pairs(npcStore) do
                if not m.Parent then M.destroyEnt(o); dead[#dead + 1] = m end
            end
            for _, m in ipairs(dead) do npcStore[m] = nil end
        elseif next(npcStore) ~= nil then
            for _, o in pairs(npcStore) do M.destroyEnt(o) end
            npcStore = {}
        end
    end
end)
--==== 遇到 Eyes 自动背对（把角色朝向转成背对它） ====
task.spawn(function()
    local locked = false
    while RUNNING do
        task.wait(0.08)
        if S.eyesAway then
            local c, h = M.charOf(lp), M.humOf(lp)
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            local best, bestD = nil, 200
            if hrp then
                for _, m in ipairs(M.scanAll(2500)) do
                    if m:IsA("Model") and m.Name:lower():find("eyes", 1, true) then
                        local d = M.distTo(m)
                        if d and d < bestD then bestD, best = d, m end
                    end
                end
            end
            if best and hrp then
                if h and not locked then
                    pcall(function() h.AutoRotate = false end)
                    locked = true
                end
                local p = M.firstPart(best)
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
            local h = M.humOf(lp)
            if h then pcall(function() h.AutoRotate = true end) end
            locked = false
        end
    end
end)

--==================== 页面 ====================
local BUILD_UI_ERROR = nil
local function BUILD_UI()
    local _ok, _err = pcall(function()
--[[ protected page build start ]]
local pMain, pVisual = M.addPage("主要"), M.addPage("视觉")
local pCombat, pAuto = M.addPage("战斗"), M.addPage("自动")
local pGuard = M.addPage("防护")
local pMisc = M.addPage("杂项")

print("[XHub][ui] build pMain")
M.addSection(pMain, "MOVEMENT")
M.addToggle(pMain, "飞行 (F)", false, function(v) M.setFly(v) end)
M.addSlider(pMain, "飞行速度", 10, 200, S.flySpeed, function(v) S.flySpeed = v end)
local setModeBtn
setModeBtn = M.addButton(pMain, "飞行模式: " .. (S.flyMode == "cframe" and "CFrame" or "物理"), function()
    S.flyMode = (S.flyMode == "cframe") and "body" or "cframe"
    setModeBtn("飞行模式: " .. (S.flyMode == "cframe" and "CFrame（防拉回更好）" or "物理 BodyVelocity"))
    if S.fly then M.setFly(false); M.setFly(true) end
    notify("飞行模式 = " .. S.flyMode, "info", 1.6)
end)
M.addToggle(pMain, "反拉回（被拉回自动降速）", true, function(v) S.antiSnap = v end)
M.addToggle(pMain, "安全模式（禁飞/禁加速，只留视觉）", false, function(v)
    S.safeMode = v
    if v and S.fly then M.setFly(false) end
    notify(v and "安全模式: 位移类功能已禁用" or "安全模式: 已关闭", v and "warn" or "info", 2.5)
end)
M.addToggle(pMain, "自动调参（实测该服速度上限）", true, function(v) S.autoTune = v end)
M.addToggle(pMain, "幽灵位移（伪装走速 + 脉冲前进）", false, function(v)
    S.ghost = v
    notify(v and "幽灵位移: 走速锁定 16,位移改为脉冲" or "幽灵位移: 已关闭", "info", 2.5)
end)
M.addToggle(pMain, "脉冲位移（每 0.6s 走 0.36s）", false, function(v) S.pulse = v end)
M.addSlider(pMain, "走路速度（服务端容忍≈16-22）", 16, 60, S.walkSpeed, function(v) S.walkSpeed = v end)
M.addToggle(pMain, "穿墙 Noclip（不改速度,不触发回弹）", false, function(v) M.setNoclip(v) end)
M.addToggle(pMain, "玩家旋转（原地转圈）", false, function(v)
    S.spin = v
    notify(v and "旋转已开" or "旋转已关闭", "info", 1.8)
end)
M.addSlider(pMain, "旋转速度 度/秒", 30, 720, 180, function(v) S.spinSpeed = v end)
M.addSection(pMain, "菜单背景")
M.addToggle(pMain, "压暗游戏背景", true, function(v)
    S.dim = v
    if backdrop then backdrop.Visible = main.Visible and v end
end)
M.addSlider(pMain, "背景不透明度 %", 0, 90, 50, function(v)
    S.bgA = v / 100
    if backdrop then backdrop.BackgroundTransparency = 1 - S.bgA end
end)
M.addToggle(pMain, "背景模糊 (BlurEffect)", false, function(v)
    S.blur = v
    if blurFx then blurFx.Size = v and 14 or 0; blurFx.Enabled = v and main.Visible end
end)
M.addSection(pMain, "HUB")
UIKEYS.setKeyBtn = M.addButton(pMain, "菜单键: " .. CONFIG.MenuKeys[1].Name .. " (点我改键)", function()
    captureMode = true
    UIKEYS.setKeyBtn("菜单键: 请按键…（Esc 取消）")
end)
M.addButton(pMain, "隐藏菜单", function() setVisible(false) end)

print("[XHub][ui] build pVisual")
M.addSection(pVisual, "ESP")
M.addToggle(pVisual, "启用 ESP", false, function(v)
    S.esp = v
    notify("ESP " .. (v and "开" or "关"), v and "ok" or "info", 1.4)
end)
M.addToggle(pVisual, "方框高亮", true, function(v) S.espBox = v end)
M.addToggle(pVisual, "名字", true, function(v) S.espName = v end)
M.addToggle(pVisual, "血量条", true, function(v) S.espHp = v end)
M.addToggle(pVisual, "距离", true, function(v) S.espDist = v end)
M.addToggle(pVisual, "显示队友", false, function(v) S.espTeam = v end)
M.addToggle(pVisual, "NPC / 怪物 ESP", false, function(v)
    S.espNpc = v
    notify(v and "NPC ESP 已开启（方框+名字+血量+距离）" or "NPC ESP 已关闭", "info", 2.2)
end)
M.addSlider(pVisual, "NPC 绘制距离（studs）", 30, 400, 300, function(v) S.npcEspDist = v end)
M.addSlider(pVisual, "NPC 最多显示数量", 5, 80, 40, function(v) S.npcEspMax = v end)
M.addToggle(pVisual, "穿墙可见", true, function(v) S.espOccluded = v end)
M.addToggle(pVisual, "彩虹上色", false, function(v) S.espRainbow = v end)
M.addSection(pVisual, "环境")
M.addToggle(pVisual, "夜视（提亮+去雾，纯客户端）", false, function(v) M.setNight(v) end)
if M.doorsAllowed() then
M.addToggle(pVisual, "场景物体绘制（柜子/床/抽屉，青色）", false, function(v)
    S.scenery = v
    notify(v and "场景绘制: 柜子/床/抽屉 会亮青色（纯渲染）" or "场景绘制已关闭", "info", 2.4)
end)
M.addToggle(pVisual, "门绘制（门/门框，金色 + 距离）", false, function(v)
    S.doors = v
    notify(v and "门绘制: 门会亮金色并显示名字/距离" or "门绘制已关闭", "info", 2.4)
end)
M.addToggle(pVisual, "拉杆绘制 + 距离（洋红）", false, function(v)
    S.lever = v
    notify(v and "拉杆绘制已开启（lever/switch/拉杆）" or "拉杆绘制已关闭", "info", 2.4)
end)
M.addToggle(pVisual, "自动拉杆（靠近自动点 E）", false, function(v)
    S.leverAuto = v
    notify(v and "自动拉杆: 14 studs 内会自动触发提示" or "自动拉杆已关闭", "info", 2.4)
end)
M.addToggle(pVisual, "遇到 Eyes 自动背对", true, function(v) S.eyesAway = v end)
end
M.addToggle(pVisual, "实体绘制（怪物/NPC/Entity）", false, function(v)
    S.entityEsp = v
    notify(v and "实体绘制已开启（关键词 + 非玩家 Humanoid）" or "实体绘制已关闭", "info", 2.5)
end)
M.addToggle(pVisual, "实体刷新提示（弹出名字+距离）", true, function(v) S.entNotify = v end)
M.addToggle(pVisual, "屏幕顶部显示最近实体距离", true, function(v)
    S.hudNearest = v
    if not v and entHud then entHud.Visible = false end
end)
M.addToggle(pVisual, "实体上色（按名字分配颜色）", true, function(v)
    S.entColor = v
    for m, o in pairs(entStore) do
        if o.hl then o.hl.FillColor = M.entColorFor(m.Name) end
    end
end)
M.addSection(pVisual, "视角")
M.addToggle(pVisual, "强制第三人称", false, function(v) M.setThirdPerson(v) end)
local setTpModeBtn
setTpModeBtn = M.addButton(pVisual, "第三人称模式: 变焦锁定", function()
    S.tpMode = (S.tpMode == "zoom") and "orbit" or "zoom"
    setTpModeBtn("第三人称模式: " .. (S.tpMode == "zoom" and "变焦锁定" or "脚本相机"))
    if S.thirdPerson then M.setThirdPerson(false); task.wait(0.1); M.setThirdPerson(true) end
    notify("模式 = " .. S.tpMode, "info", 1.6)
end)
M.addToggle(pVisual, "第三人称 Y 轴反转", true, function(v) S.invertY = v end)
M.addToggle(pVisual, "第三人称调试信息（排查用）", false, function(v)
    S.tpDebug = v
    if not v and camDbg then camDbg:Destroy(); camDbg = nil end
    notify(v and "已显示相机调试信息（左上角）" or "调试信息已关闭", "info", 2.2)
end)
M.addSlider(pVisual, "第三人称镜头距离 studs", 6, 40, 14, function(v) orbit.dist = v end)
M.addButton(pVisual, "恢复默认视角", function() M.setThirdPerson(false) end)
M.addSection(pVisual, "性能")
M.addToggle(pVisual, "优化模式（降低扫描频率）", true, function(v)
    S.fastScan = v
    notify(v and "优化模式: 实体 1.0s / 物品 1.5s 扫描" or "优化模式关闭: 扫描更频繁（更卡）", "info", 2.4)
end)
M.addButton(pVisual, "诊断扫描（F9 + 弹窗）", function()
    local wsKids = #workspace:GetChildren()
    local cr = workspace:FindFirstChild("CurrentRooms")
    local list = M.scanAll(6000)
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

print("[XHub][ui] build pCombat")
M.addToggle(pCombat, "远程改写：宽松模式（所有带方向的远程都改）", false, function(v)
    S.remoteAimAll = v
    notify(v and "宽松改写已开（可能影响交互类远程，谨慎）" or "宽松改写已关（只改武器类远程）", "warn", 3)
end)
M.addButton(pCombat, "开火探针（15 秒，输出到 F9）", function()
    S.remoteProbe = true
    notify("探针已开 15 秒：现在开一枪，把 F9 里的 [probe] 行发我", "ok", 4)
    task.delay(15, function()
        S.remoteProbe = false
        notify("探针已关闭", "info", 1.6)
    end)
end)
local setRwBtn
setRwBtn = M.addButton(pCombat, "远程改写: 关（默认，最不影响开火）", function()
    if not S.remoteAim then
        S.remoteAim, S.remoteAimSafe = true, true
        setRwBtn("远程改写: 安全（偏转≤8°，保留枪口）")
    elseif S.remoteAimSafe then
        S.remoteAim, S.remoteAimSafe = true, false
        setRwBtn("远程改写: 全量（偏转≤设定角）")
    else
        S.remoteAim = false
        setRwBtn("远程改写: 关（默认，最不影响开火）")
    end
    notify("远程改写 = " .. (not S.remoteAim and "关" or (S.remoteAimSafe and "安全" or "全量")), "info", 2.4)
end)

M.addSection(pCombat, "子弹追踪（独立功能，不需要自瞄）")
M.addToggle(pCombat, "开火自动对准目标（250ms）", false, function(v)
    S.btStandalone = v
    notify(v and "子弹追踪已开：每次开火自动对准一次" or "子弹追踪已关闭", "info", 2.6)
end)

M.addSection(pCombat, "AIMBOT")
M.addToggle(pCombat, "启用自瞄", false, function(v)
    S.aim = v
    notify("自瞄 " .. (v and "开" or "关"), v and "ok" or "info", 1.4)
end)
M.addToggle(pCombat, "子弹追踪（开火瞬间对准头部）", false, function(v) S.bulletTrack = v end)
M.addToggle(pCombat, "静默瞄准（视角不动，只改开火方向）", false, function(v)
    S.silentAim = v
    notify(v and "静默瞄准已开：开火瞬间改写相机方向，随后立刻恢复" or "静默瞄准已关闭", "info", 2.6)
end)
M.addSlider(pCombat, "静默改写时长 ×0.01s（9 = 90ms）", 3, 20, 9, function(v) S.silentTime = v / 100 end)
M.addSlider(pCombat, "远程改写最大偏转角 度（防判）", 5, 90, 25, function(v) S.silentMaxAngle = v end)
M.addToggle(pCombat, "左键开火时自瞄", true, function(v) S.aimOnFire = v end)
M.addToggle(pCombat, "瞄准队友", false, function(v) S.aimTeam = v end)
M.addToggle(pCombat, "预判瞄准（Lead Target，打移动目标）", false, function(v)
    S.leadEnabled = v
    notify(v and "预判已开：按目标速度 + 弹速算提前量" or "预判已关（直接锁当前位置）", "info", 2.6)
end)
M.addSlider(pCombat, "子弹速度 studs/s（预判用）", 100, 2000, 600, function(v) S.leadSpeed = v end)
M.addSlider(pCombat, "提前量倍率 ×0.1（10 = 1.0x）", 1, 25, 10, function(v) S.leadScale = v / 10 end)
M.addSection(pCombat, "NPC 自瞄（独立于玩家自瞄）")
M.addToggle(pCombat, "开启 NPC 自瞄", false, function(v)
    S.npcAim = v
    notify(v and "NPC 自瞄已开（只锁 NPC/怪物）" or "NPC 自瞄已关", "info", 2.2)
end)
M.addToggle(pCombat, "NPC 自瞄：只在按住左键时锁", true, function(v) S.npcAimOnFire = v end)
M.addToggle(pCombat, "NPC 自瞄：预判移动", true, function(v) S.npcLead = v end)
M.addSlider(pCombat, "NPC 自瞄距离", 20, 400, 200, function(v) S.npcAimDist = v end)

M.addSection(pCombat, "杀戮光环（学习一次真实攻击后自动重放）")
M.addToggle(pCombat, "开启杀戮光环（未学习时自动进入学习）", false, function(v)
    S.killAura = v
    if v then
        pcall(ensureAuraPanel)
        if auraPanel then auraPanel.Visible = true end
        if not (S.learnCall and S.learnCall.remote and S.learnCall.remote.Parent) then
            S.learnActive = true
            auraLog("未学习：现在手动砍目标一刀即可（只记这一次）", Color3.fromRGB(255, 220, 120))
        else
            auraLog("光环启动 · 已学会: " .. tostring(S.learnCall.name), Color3.fromRGB(255, 170, 170))
        end
    else
        if auraPanel then auraPanel.Visible = false end
    end
    notify(v and "杀戮光环: 开" or "杀戮光环: 关", v and "ok" or "info", 1.8)
end)
M.addButton(pCombat, "重新学习（清除已学攻击）", function()
    S.learnCall = nil
    S.learned = nil
    S.learnActive = true
    pcall(function() if hasFS and writefile then writefile(LEARN_FILE, "") end end)
    auraLog("已清除旧记录：手动砍一刀重新学习", Color3.fromRGB(255, 220, 120))
end)
UIKEYS.setAuraKeyBtn = M.addButton(pCombat, "光环快捷键: " .. S.auraKey.Name .. "（点我改键）", function()
    S.keyCapture = "aura"
    notify("按一个新键作为光环开关（Esc 取消）", "warn", 4)
end)
M.addSlider(pCombat, "光环半径 studs", 5, 60, 20, function(v) S.auraRadius = v end)

M.addToggle(pCombat, "瞄准 NPC / 怪物", false, function(v)
    S.aimNpc = v
    notify(v and "自瞄已包含 NPC/怪物" or "自瞄只锁玩家", "info", 2.2)
end)
M.addToggle(pCombat, "隔墙忽略", true, function(v) S.aimWall = v end)
M.addSlider(pCombat, "FOV 像素", 20, 400, S.aimFov, function(v) S.aimFov = v end)
local setPartBtn = M.addButton(pCombat, "部位: Head", function()
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

if M.doorsAllowed() then
print("[XHub][ui] build pAuto")
M.addSection(pAuto, "物品")
M.addToggle(pAuto, "物品绘制（钥匙 / 道具 / 箱子）", false, function(v)
    S.itemEsp = v
    notify(v and "物品绘制已开启" or "物品绘制已关闭", "info", 2)
end)
M.addToggle(pAuto, "范围拾取（touch 模拟）", false, function(v) S.pickup = v end)
M.addSlider(pAuto, "拾取半径", 5, 60, S.pickupRadius, function(v) S.pickupRadius = v end)
M.addSlider(pAuto, "拾取间隔 ×0.01s（12 = 0.12s）", 5, 50, 12, function(v) S.pickupInterval = v / 100 end)

M.addSection(pAuto, "交互")
M.addToggle(pAuto, "自动交互（ProximityPrompt）", false, function(v) S.autoPrompt = v end)
M.addSlider(pAuto, "交互半径", 5, 40, S.promptRadius, function(v) S.promptRadius = v end)
M.addToggle(pAuto, "瞬间交互（去掉长按）", true, function(v) S.instantPrompt = v end)
M.addToggle(pAuto, "自动开门（Door.ClientOpen）", false, function(v) S.autoDoor = v end)
M.addSlider(pAuto, "开门半径", 5, 50, S.doorRadius, function(v) S.doorRadius = v end)
M.addToggle(pAuto, "开门后自动走向该门（推进）", false, function(v)
    S.autoAdvance = v
    notify(v and "自动推进已开：开门 0.9 秒后自动 A* 走过去" or "自动推进已关闭", "info", 2.6)
end)

M.addSection(pAuto, "躲避")
M.addToggle(pAuto, "遇到实体自动躲", false, function(v)
    S.autoHide = v
    notify(v and "自动躲避已开启（按当前模式执行）" or "自动躲避已关闭", "info", 2.4)
end)
local setHideModeBtn
setHideModeBtn = M.addButton(pAuto, "躲避方式: 高空传送", function()
    S.hideMode = (S.hideMode == "sky") and "closet" or "sky"
    setHideModeBtn("躲避方式: " .. (S.hideMode == "sky" and "高空传送" or "柜子/床"))
    notify("躲避方式 = " .. S.hideMode, "info", 1.6)
end)
M.addSlider(pAuto, "触发距离", 30, 200, S.hideDist, function(v) S.hideDist = v end)
M.addButton(pAuto, "测试躲避（立刻执行一次）", function()
    notify("测试躲避: 立即执行", "info", 2)
    M.hideSmart("TEST")
end)
M.addToggle(pAuto, "躲避调试信息（F9，每 2 秒一行）", false, function(v)
    S.hideDebug = v
    if v then
        local n, d2, tr = nearestTrigger()
        print(("[hide] 当前最近触发源 = %s  %.0fm  T%s ; autoHide=%s hideDist=%s")
            :format(tostring(n), d2 or -1, tostring(tr), tostring(S.autoHide), tostring(S.hideDist)))
    end
    notify(v and "调试已开：F9 每 2 秒打印躲避判定" or "调试已关", "info", 2.5)
end)
M.addToggle(pAuto, "声音也触发躲避（默认关，防假 Rush）", false, function(v)
    S.hideSound = v
    notify(v and "声音触发已开（FakeoutRush 这类假事件仍会被过滤）" or "声音不再触发躲避（只按实体名字判断）", "info", 3)
end)
M.addToggle(pAuto, "额外躲避 Seek/Glitch 等（二级威胁）", false, function(v)
    S.hideTier2 = v
    notify(v and "二级威胁（Seek/Glitch/Figure/Dupe）也会触发躲避" or "只有 Rush/Ambush 会触发躲避", "info", 3)
end)
M.addSlider(pAuto, "高空高度 studs", 50, 800, S.skyHeight, function(v) S.skyHeight = v end)
M.addSlider(pAuto, "高空停留 秒", 3, 20, S.skyTime, function(v) S.skyTime = v end)
local setPreferBtn
setPreferBtn = M.addButton(pAuto, "躲避策略: 自动(Rush钻柜/Seek升空)", function()
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

M.addButton(pAuto, "A* 寻路到最近的门", function()
    local pos, d = M.nearestDoorPos()
    if not pos then return notify("没找到名字含 door 的对象", "err", 3) end
    notify(("A* 目标: 最近的门的 (%.0f studs)"):format(d or 0), "info", 2)
    navTo(pos)
end)
end
M.addSection(pAuto, "寻路")
M.addButton(pAuto, "停止寻路", function()
    M.stopWalk()
    notify("已停止寻路", "info", 1.5)
end)

--==== 位移限速器：把 0.6 秒内的位移硬压在该服容忍值以内（服务端永远看不到异常速度） ====
local govHist = {}
task.spawn(function()
    while RUNNING do
        task.wait(0.08)
        if S.govEnabled and not M.isSeated() then
            local c = M.charOf(lp)
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

print("[XHub][ui] build pGuard")
M.addSection(pGuard, "① 基础压制")
M.addButton(pGuard, "圣奥里安全预设（限速 + 关飞行 + 开①③）", function()
    S.safeMode = true
    S.fly = false
    S.walkSpeed = 16
    S.govEnabled = true
    S.govMax = 12
    S.govWindow = 0.6
    S.autoHide = false
    S.doors = false
    S.lever = false
    pcall(function() if S.fly then M.setFly(false) end end)
    pcall(function() h = M.humOf(lp); if h then h.WalkSpeed = 16 end end)
    notify("圣奥里预设: 位移限速 12 studs/0.6s · 飞行关 · 走速 16", "ok", 4)
    notify("AC: 只建议开①③；②会掐车辆/起身；飞行会被 600 封禁", "warn", 4)
end)
M.addButton(pGuard, "标定该服位移上限（自动设限速器）", function()
    local c = M.charOf(lp)
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return notify("没有角色", "err", 2) end
    notify("标定中：缓慢前移 6 秒，观察服务端是否拉回…", "info", 3)
    S.govEnabled = false          -- 标定期间不限制，才能测到边界
    local startPos = hrp.Position
    local snaps = 0
    local last = startPos
    local t0 = os.clock()
    local wasFly = S.fly
    if not S.fly then M.setFly(true) end
    S.flySpeed = 40
    task.spawn(function()
        while os.clock() - t0 < 6 do
            task.wait(0.1)
            if (hrp.Position - last).Magnitude < 0.05 then snaps = snaps + 1 end
            last = hrp.Position
        end
        if wasFly == false then M.setFly(false) end
        local moved = (hrp.Position - startPos).Magnitude
        local speed = moved / 6
        local allowed = snaps > 0 and math.max(8, math.floor(speed * 0.55)) or math.max(12, math.floor(speed * 0.8))
        S.govMax = allowed
        S.govWindow = 0.6
        S.govEnabled = true
        notify(("标定完成：6 秒位移 %.0f studs（%.1f/s），被拉回 %d 次 → 限速器设为 %d studs/0.6s")
            :format(moved, speed, snaps, allowed), "ok", 6)
    end)
end)
M.addToggle(pGuard, "锁血 / 无敌（客户端，每 0.1 秒回满）", false, function(v)
    S.healthLock = v
    if not v and S._hpConn then pcall(function() S._hpConn:Disconnect() end); S._hpConn = nil end
    notify(v and "锁血已开：客户端血量锁满（服务器判死仍可能生效）" or "锁血已关", v and "warn" or "info", 3.5)
end)
M.addSlider(pGuard, "锁血低于多少立刻拉满", 1, 100, 20, function(v) S.lockKeep = v end)
M.addToggle(pGuard, "低血自动脱离（升空后退 + 穿墙）", false, function(v)
    S.lowHPFlee = v
    notify(v and "低血脱离已开：血量低于阈值会自动升空后退" or "低血脱离已关", "info", 3)
end)
M.addSlider(pGuard, "自动脱离触发血量 %", 5, 90, 35, function(v) S.fleePct = v / 100 end)
M.addToggle(pGuard, "NPC 碰撞箱放大（本地探针，方便命中）", false, function(v)
    S.npcHitbox = v
    notify(v and "碰撞箱已放大：客户端射线/鼠标判定更容易命中" or "碰撞箱已恢复", "info", 3.2)
end)
M.addToggle(pGuard, "NPC 碰撞关闭（可穿过 NPC / 部分障碍）", false, function(v)
    S.npcNoCollide = v
    notify(v and "已关闭 NPC 碰撞：本地可穿过它们" or "NPC 碰撞已恢复", "info", 3)
end)
M.addToggle(pGuard, "位移限速器（0.6s 内最多走 12 studs）", false, function(v)
    S.govEnabled = v
    notify(v and "限速器开启：任何速度类功能都会被压在服务端容忍内" or "限速器已关闭（飞行/加速不再被限制）",
        v and "ok" or "warn", 3)
end)
M.addSlider(pGuard, "限速窗口内允许位移 studs", 6, 40, 12, function(v) S.govMax = v end)
M.addToggle(pGuard, "线程 + 连接 + marker", false, function(v) if v then M.acRun() end end)
M.addButton(pGuard, "重新执行基础压制", function() M.acRun() end)

M.addSection(pGuard, "② 检测层（只动 AC 的渲染/心跳回调）")
M.addToggle(pGuard, "挂钩 AC 回调 / 杀线程", false, function(v)
    G.layer1 = v
    if v then
        local c, t, h = M.runLayer1()
        notify(("检测层: 连接 %d / 线程 %d / 闭包 %d"):format(c, t, h), "ok", 3)
    end
end)

M.addSection(pGuard, "③ 通道层（只切上行，不动 Connect）")
M.addToggle(pGuard, "切断上报 + 拦本地踢人", false, function(v)
    G.layer2 = v; G.blockKick = v
    if v then
        local n = M.runLayer2()
        notify(("通道层: remote %d / blocked %d"):format(n, G.blocked), "ok", 3)
    end
end)

M.addSection(pGuard, "哈希搜索")
local hashBox = M.addBox(pGuard, "输入 AntiCheat / 混淆名", "AntiCheat")
M.addButton(pGuard, "哈希搜索 + 挂钩", function()
    local c, t, h, n = M.hashSearch(hashBox.Text)
    notify(("搜索 %s → 连接 %d / 线程 %d / 闭包 %d / remote %d")
        :format(hashBox.Text, c, t, h, n), "ok", 3)
end)
M.addButton(pGuard, "只加入哈希表", function()
    CONFIG.ACG.Hashes[hash(hashBox.Text)] = true
    notify(("hash(%s) = %d 已加入"):format(hashBox.Text, hash(hashBox.Text)), "ok", 2.5)
end)
M.addButton(pGuard, "列出匹配到 F9", function()
    print(("=== ACG matches (%d) ==="):format(#G.matches))
    for _, m in ipairs(G.matches) do print(m) end
    notify(("已打印 %d 条"):format(#G.matches), "info", 2)
end)

M.addSection(pGuard, "远程拦截（按名字）")
local remoteBox = M.addBox(pGuard, "例如 MotorReplication / Report / AntiCheat", "MotorReplication")
M.addButton(pGuard, "拦截匹配的 FireServer/InvokeServer", function()
    local n = M.blockRemoteSubstr(remoteBox.Text)
    notify(("已拦截 %d 个远程（匹配 %s）"):format(n, remoteBox.Text),
        n > 0 and "ok" or "warn", 3)
end)

M.addSection(pGuard, "THREAD CLEANER")
M.addButton(pGuard, "打开线程面板", function() M.tcShow() end)
M.addButton(pGuard, "快速杀 BS_", function()
    TC.all = M.tcCollect()
    local k, m = M.tcKill("BS_")
    notify(("BS_ 匹配 %d / 终止 %d"):format(m, k), k > 0 and "ok" or "warn", 3)
end)
M.addButton(pGuard, "列出全部线程到 F9", function()
    TC.all = M.tcCollect(); M.tcDump()
    notify(("已打印 %d 个线程"):format(#TC.all), "info", 2)
end)

M.addSection(pGuard, "输入急救")
M.addButton(pGuard, "修复车辆/疾跑按键", function() M.repairInput(true) end)
M.addButton(pGuard, "还原 ACG 钩子 + 输入", function()
    M.acgRestore()
    M.repairInput(true)
    notify("已还原 __namecall 与所有被改动的回调", "ok", 3)
end)

M.addSection(pGuard, "车辆 / 角色")
M.addToggle(pGuard, "车辆安全模式（上下车暂停/恢复绕过）", true, function(v)
    S.vehicleSafe = v
end)
M.addToggle(pGuard, "防遁地守护（陷地自动抬回）", false, function(v)
    S.antiFall = v
end)
M.addButton(pGuard, "角色复位（起身/解焊/抬升）", function() M.characterFix(false) end)
M.addButton(pGuard, "打印 AC 脚本全名到 F9", function()
    local by = M.collectScripts()
    local n = 0
    for k in pairs(by) do n = n + 1 end
    for _, m in ipairs(G.matches) do print(m) end
    notify(("匹配 %d 个标识 / %d 条记录（见 F9）"):format(n, #G.matches), "info", 3)
end)

print("[XHub][ui] build pMisc")
M.addSection(pMisc, "服务器档位")
M.addButton(pMisc, "打印 PlaceId / 识别结果", function()
    print(("[profile] PlaceId=%d  JobId=%s  识别=%s")
        :format(game.PlaceId, tostring(game.JobId), currentProfileKey))
    notify(("PlaceId %d · 档位 %s"):format(game.PlaceId, PROFILES[currentProfileKey].label), "info", 4)
end)
M.addToggle(pMisc, "强制启用 DOORS 专属模块（门/拉杆/Eyes/躲避）", false, function(v)
    S.forceDoors = v
    notify(v and "已强制启用 DOORS 模块（任何服务器都会跑）" or "已恢复：非 DOORS 服务器关闭 DOORS 模块", v and "warn" or "info", 3)
end)
local setProfileBtn
setProfileBtn = M.addButton(pMisc, "当前档位: " .. PROFILES[currentProfileKey].label, function()
    local order = { "doors", "sanAurie", "default" }
    local i = 1
    for k, v in ipairs(order) do if v == currentProfileKey then i = k end end
    local p = M.applyProfile(order[(i % #order) + 1])
    setProfileBtn("当前档位: " .. p.label)
    notify(("已切换档位: %s"):format(p.label), "ok", 3)
    notify(p.tip, "info", 5)
end)

M.addSection(pMisc, "角色")
M.addButton(pMisc, "自杀 / 重生", function() M.suicide() end)
M.addSection(pMisc, "服务器")
M.addButton(pMisc, "重进本服 (同 JobId)", function() M.rejoinHere() end)
M.addButton(pMisc, "换一个新服务器", function() M.newServer() end)
M.addSection(pMisc, "其他")
M.addButton(pMisc, "打开 / 关闭 日志 Hub（可拖动/复制）", function()
    local h = ensureHub()
    h.Visible = not h.Visible
    if h.Visible then
        hubPush("日志 Hub 已打开", Color3.fromRGB(140, 200, 255))
    end
end)
M.addButton(pMisc, "关闭脚本（完全卸载，可在同服换版本）", function()
    if _G.XHubShuttingDown then return end
    notify("正在卸载 XHub…", "warn", 2)
    task.delay(0.3, function() shutdownXHub() end)
end)
M.addSection(pMisc, "信息")
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
    while RUNNING do
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

    end)
    if not _ok then
        BUILD_UI_ERROR = tostring(_err)
        print("[XHub][ui] 页面构建失败: " .. tostring(_err))
    end
end
pcall(BUILD_UI)

--==================== 热键 ====================
local function isMenuKey(code)
    for _, k in ipairs(CONFIG.MenuKeys) do if k == code then return true end end
    return false
end
if BUILD_UI_ERROR then
    pcall(function()
        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(0, 520, 0, 60)
        t.Position = UDim2.new(0.5, -260, 0, 90)
        t.BackgroundColor3 = Color3.fromRGB(60, 18, 18)
        t.BackgroundTransparency = 0.15
        t.TextColor3 = Color3.fromRGB(255, 190, 190)
        t.Font = Enum.Font.Code
        t.TextSize = 12
        t.TextWrapped = true
        t.ZIndex = 9999
        t.Text = "UI 构建失败（把这段发给我）: " .. BUILD_UI_ERROR
        t.Parent = gui
    end)
end
UIS.InputBegan:Connect(function(i, gp) if not RUNNING then return end
    if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if UIS:GetFocusedTextBox() then captureMode = false; return end
    if S.keyCapture == "aura" then
        S.keyCapture = nil
        if i.KeyCode == Enum.KeyCode.Escape then
            notify("光环改键已取消", "warn", 2)
        else
            S.auraKey = i.KeyCode
            if UIKEYS.setAuraKeyBtn then UIKEYS.setAuraKeyBtn("光环快捷键: " .. i.KeyCode.Name .. " (点我改键)") end
            notify("光环快捷键 = " .. i.KeyCode.Name, "ok", 2)
        end
        return
    end
    if captureMode then
        captureMode = false
        if i.KeyCode == Enum.KeyCode.Escape then
            notify("改键已取消", "warn", 2)
        else
            CONFIG.MenuKeys = { i.KeyCode }
            if UIKEYS.setKeyBtn then UIKEYS.setKeyBtn("菜单键: " .. i.KeyCode.Name .. " (点我改键)") end
            notify("菜单键 = " .. i.KeyCode.Name, "ok", 2)
        end
        return
    end
    if S.auraKey and i.KeyCode == S.auraKey and not gp then
        S.killAura = not S.killAura
        pcall(function() if S.killAura then ensureAuraPanel() end end)
        pcall(function() if auraPanel then auraPanel.Visible = S.killAura end end)
        if S.killAura then pcall(function() auraLog("光环启动 · 快捷键", Color3.fromRGB(255, 170, 170)) end) end
        notify(S.killAura and "杀戮光环: 开" or "杀戮光环: 关", S.killAura and "ok" or "info", 1.6)
        return
    end
    if isMenuKey(i.KeyCode) then
        setVisible(not main.Visible)
    elseif i.KeyCode == CONFIG.FlyKey and not gp then
        M.setFly(not S.fly)
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
--==== 关闭脚本（完全卸载，可在同一服务器内换版本重新注入）====
shutdownXHub = function()
    if _G.XHubShuttingDown then return end
    _G.XHubShuttingDown = true
    RUNNING = false

    -- 1) 解绑全部渲染回调
    for _, name in ipairs({ "XHubAim", "XHubSilent", "XHubCam", "XHubSky", "XHubSpin", "XHubMouse" }) do
        pcall(function() RS:UnbindFromRenderStep(name) end)
    end

    -- 2) 还原角色/相机状态
    pcall(function() M.setNoclip(false) end)
    pcall(function() M.setFly(false) end)
    pcall(function()
        skyHold = nil
        local c = M.charOf(lp)
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = 16
            hum.AutoRotate = true
            pcall(function() hum.JumpPower = 50 end)
        end
        if cam then
            cam.CameraType = Enum.CameraType.Custom
            if hum then cam.CameraSubject = hum end
        end
    end)

    -- 3) 清掉所有 ESP 绘制对象
    for _, store in ipairs({ espStore, entStore, npcStore, sceneStore, doorStore, leverStore, itemStore }) do
        pcall(function()
            for k, v in pairs(store) do
                if type(v) == "table" then
                    for _, f in pairs(v) do
                        if typeof(f) == "Instance" then pcall(function() f:Destroy() end) end
                    end
                end
            end
            for k in pairs(store) do store[k] = nil end
        end)
    end

    -- 4) 销毁 GUI
    pcall(function() if gui then gui:Destroy() end end)
    pcall(function() if camDbg then camDbg:Destroy() end end)
    pcall(function() if navHud then navHud:Destroy() end end)
    pcall(function() if hideHud then hideHud:Destroy() end end)
    pcall(function() if auraHud then auraHud:Destroy() end end)

    -- 5) 摘掉全局注册
    _G.XHub = nil
    _G.XHubShuttingDown = false
    print("[XHub] 已卸载。可以在同一服务器内注入其它版本。")
end

_G.XHubKill = function() RUNNING = false end
_G.XHub = { version = VERSION, build = BUILD, shutdown = shutdownXHub, running = function() return RUNNING end }

-- 自动载入上次学习到的攻击调用
task.delay(1.0, function()
    local okL, cntL = pcall(M.loadLearned)
    if okL and cntL and cntL > 0 then
        pcall(function() auraLog(("已载入历史学习记录 %d 个调用"):format(cntL), Color3.fromRGB(150, 210, 255)) end)
    end
end)
if S.noclip then
    task.delay(0.6, function() pcall(function() M.setNoclip(true) end) end)
end
print(("[XHub] %s (build %s) loaded · 6 页 · 菜单键 %s · 档位=%s (PlaceId=%d)"):format(
    VERSION, BUILD, CONFIG.MenuKeys[1].Name, currentProfileKey, game.PlaceId))