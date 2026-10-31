--=====================================================================
--  XHub · 合并版 (Fly / ESP / Aimbot / AC压制 / AC-Guard v2 / 线程清理)
--  菜单键 RightShift/Insert/F2 · F 飞行 · Q 瞄准
--=====================================================================
local CONFIG = {
    MenuKeys = { Enum.KeyCode.RightShift, Enum.KeyCode.Insert, Enum.KeyCode.F2 },
    FlyKey   = Enum.KeyCode.F,
    AimKey   = Enum.KeyCode.Q,
    Accent   = Color3.fromRGB(0, 200, 255),
    Enemy    = Color3.fromRGB(255, 70, 70),
    Mate     = Color3.fromRGB(90, 255, 120),
    AC = { Patterns = { "BS_", "最强防御", "防御", "Antikick", "AntiCheat", "Anti_Kick", "AC_" },
           Marker = "BS_Script_Running_Marker" },
    ACG = { Keywords = { "AntiCheat", "Antikick", "AntiKick", "Anti_Kick", "BS_", "防御", "AC_" },
            RemoteKw = { "Anti", "Cheat", "Kick", "Ban", "Report", "AC", "BS", "Guard" },
            Hashes   = {} },
}

local Players, RS = game:GetService("Players"), game:GetService("RunService")
local UIS, CoreGui = game:GetService("UserInputService"), game:GetService("CoreGui")
local RStorage, SC = game:GetService("ReplicatedStorage"), game:GetService("ScriptContext")
local Lighting = game:GetService("Lighting")
local lp, cam = Players.LocalPlayer, workspace.CurrentCamera

local S = {
    fly = false, flySpeed = 60,
    esp = false, espBox = true, espName = true, espHp = true, espDist = true,
    espTeam = false, espOccluded = true, espRainbow = false,
    aim = false, aimHold = true, aimSmooth = 10, aimFov = 140,
    aimPart = "Head", aimTeam = false, aimWall = true, showFov = true,
    dim = true, bgA = 0.55, blur = false,
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

--==================== 背景层 ====================
local gui = mk("ScreenGui", { Name = "XHub", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999 })
if not pcall(function() gui.Parent = CoreGui end) then
    gui.Parent = lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui")
end

local backdrop = mk("Frame", { Name = "Backdrop", Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1 - S.bgA,
    BorderSizePixel = 0, Visible = S.dim, ZIndex = 0, Active = false }, gui)

local blurFx = Instance.new("BlurEffect")
blurFx.Size = 0
blurFx.Enabled = false
blurFx.Parent = Lighting

--==================== 主面板 ====================
local main = mk("Frame", { Name = "Main", Size = UDim2.fromOffset(560, 420),
    Position = UDim2.new(0.5, -280, 0.5, -210), BackgroundColor3 = Color3.fromRGB(20, 22, 28),
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
mk("TextLabel", { Text = "universal", BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
    Position = UDim2.new(0, 68, 0, 0), Size = UDim2.fromOffset(100, 42), Font = Enum.Font.Gotham,
    TextSize = 11, TextColor3 = Color3.fromRGB(120, 130, 148) }, bar)

local toast
local icon
local function setVisible(v)
    main.Visible = v
    if backdrop then backdrop.Visible = v and S.dim end
    if blurFx then
        blurFx.Enabled = v and S.blur
        blurFx.Size = (v and S.blur) and 14 or 0
    end
    if icon then icon.BackgroundColor3 = v and CONFIG.Accent or Color3.fromRGB(30, 34, 44) end
    if toast then
        toast.Text = v and "XHub · 已打开" or "XHub · 已关闭"
        toast.Visible = true
        task.delay(1.1, function() if toast then toast.Visible = false end end)
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

    toast = mk("TextLabel", { Name = "XHubToast", Text = "", Size = UDim2.fromOffset(250, 28),
        Position = UDim2.new(0.5, -125, 0, 54), BackgroundColor3 = Color3.fromRGB(20, 22, 28),
        BackgroundTransparency = 0.12, TextColor3 = Color3.fromRGB(230, 236, 246),
        Font = Enum.Font.GothamBold, TextSize = 13, Visible = false, ZIndex = 20 }, gui)
    mk("UICorner", { CornerRadius = UDim.new(0, 8) }, toast)
    mk("UIStroke", { Color = Color3.fromRGB(58, 64, 78), Thickness = 1 }, toast)

    icon.MouseButton1Click:Connect(function() setVisible(not main.Visible) end)
    keyBtn.MouseButton1Click:Connect(function()
        captureMode = true
        toast.Text = "按下新的菜单键（Esc 取消）"
        toast.Visible = true
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
    hover(row, base)
    paint(); if cb then cb(on) end
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

--==================== 基础压制(线程+连接+marker) ====================
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
                if ok and acIs(src) and (pcall(coroutine.close, v)) then t = t + 1 end
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
                    local sn = ""
                    pcall(function() if k.Script then sn = k.Script.Name end end)
                    if acIs(sn) then
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
    print("[XHub-AC]", msg)
    return msg
end

--==================== AC Guard v2 ====================
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
    if s == "" then return false end
    if CONFIG.ACG.Hashes[hash(s)] then return true end
    local low = s:lower()
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
local function noop() end
local function hookClosures(byName)
    if not (getgc and hookfunction) then return 0 end
    local n = 0
    for _, v in ipairs(getgc()) do
        if type(v) == "function" then
            if islclosure == nil or islclosure(v) then
                local src = ""
                pcall(function() src = debug.info(v, "s") or "" end)
                if src ~= "" then
                    local hit = isTarget(src)
                    if not hit then
                        local low = src:lower()
                        for nm in pairs(byName) do
                            if low:find(nm, 1, true) then hit = true; break end
                        end
                    end
                    if hit and pcall(hookfunction, v, noop) then n = n + 1 end
                end
            end
        end
    end
    G.hookedFns = G.hookedFns + n
    return n
end
local function killACGThreads(byName)
    if not (getreg and coroutine and coroutine.close) then return 0 end
    local n = 0
    for _, v in pairs(getreg()) do
        if type(v) == "thread" then
            local src = ""
            pcall(function() src = debug.info(v, "s") or "" end)
            local hit = isTarget(src)
            if not hit and src ~= "" then
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
local function disableACGConns(byName)
    if not getconnections then return 0 end
    local n = 0
    local sigs = {}
    for _, nm in ipairs({ "Heartbeat", "RenderStepped", "PreRender", "Stepped",
                         "PreSimulation", "PostSimulation" }) do
        local ok, sig = pcall(function() return RS[nm] end)
        if ok and sig then sigs[#sigs + 1] = sig end
    end
    sigs[#sigs + 1] = SC.Error
    for _, sig in ipairs(sigs) do
        local ok, conns = pcall(getconnections, sig)
        if ok and conns then
            for _, c in ipairs(conns) do
                local sn, src = "", ""
                pcall(function() if c.Script then sn = c.Script:GetFullName() end end)
                pcall(function() src = debug.info(c.Function, "s") or "" end)
                if isTarget(sn) or isTarget(src) then
                    pcall(function() c:Disable() end)
                    pcall(function() c:Disconnect() end)
                    n = n + 1
                end
            end
        end
    end
    return n
end
local function runLayer1()
    G.matches = {}
    local byName = collectScripts()
    local f = hookClosures(byName)
    local t = killACGThreads(byName)
    local c = disableACGConns(byName)
    return f, t, c
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
    pcall(walk, workspace)
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
            if m == "FireServer" or m == "InvokeServer" then
                local cs = getcallingscript and getcallingscript()
                local sn, short = "", ""
                if cs then pcall(function() sn = cs:GetFullName(); short = cs.Name end) end
                if isTarget(sn) or isTarget(short) or G.targetScripts[(short or ""):lower()] then
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
    local f = hookClosures(byName)
    local t = killACGThreads(byName)
    local n = scanRemotes()
    return f, t, n
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
        if tcMatch(e, q) then
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
    for i, e in ipairs(TC.all) do
        print(("%4d [%s] %s:%d"):format(i, e.status, e.name, e.line))
    end
end
local function tcBuild()
    if TC.panel then return end
    TC.all = tcCollect()
    local p = mk("Frame", { Name = "TCPanel", Size = UDim2.fromOffset(560, 450),
        Position = UDim2.new(0.5, -280, 0.5, -225), BackgroundColor3 = Color3.fromRGB(20, 22, 28),
        BorderSizePixel = 0, Active = true, Visible = false, ClipsDescendants = true, ZIndex = 30 }, gui)
    mk("UICorner", { CornerRadius = UDim.new(0, 12) }, p)
    mk("UIStroke", { Color = Color3.fromRGB(58, 64, 78), Thickness = 1 }, p)
    TC.panel = p

    local tb = mk("Frame", { Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = Color3.fromRGB(27, 30, 39),
        BorderSizePixel = 0, ZIndex = 31 }, p)
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
        PlaceholderText = "搜索线程/脚本名,例如 BS_ 或 Antikick", Text = "",
        PlaceholderColor3 = Color3.fromRGB(120, 128, 145), Font = Enum.Font.Gotham, TextSize = 13,
        TextColor3 = Color3.fromRGB(235, 240, 250), TextXAlignment = Enum.TextXAlignment.Left }, p)
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
    btn("自动填 BS_", 184, 96, function()
        TC.search.Text = "BS_"
        TC.status.Text = "已填 BS_ —— 不行再试 防御 / Antikick / AntiCheat"
    end)
    btn("终止匹配", 286, 100, function()
        local k, m = tcKill(TC.search.Text or "")
        TC.status.Text = ("终止了 %d / %d（匹配 %d）"):format(k, #TC.all, m)
        task.delay(0.3, tcRefresh)
    end)
    btn("关闭", 392, 60, function() p.Visible = false end)

    tcRender()
end
local function tcShow()
    tcBuild()
    TC.panel.Visible = true
    tcRefresh()
end

--==================== 页面 ====================
local pMain, pVisual = addPage("主要"), addPage("视觉")
local pCombat, pGuard = addPage("战斗"), addPage("防护")
local pMisc = addPage("杂项")

addSection(pMain, "MOVEMENT")
addToggle(pMain, "飞行 (F)", false, function(v) setFly(v) end)
addSlider(pMain, "飞行速度", 10, 300, S.flySpeed, function(v) S.flySpeed = v end)
addSection(pMain, "菜单背景")
addToggle(pMain, "压暗游戏背景", true, function(v)
    S.dim = v
    if backdrop then backdrop.Visible = main.Visible and v end
end)
addSlider(pMain, "背景不透明度 %", 0, 90, 55, function(v)
    S.bgA = v / 100
    if backdrop then backdrop.BackgroundTransparency = 1 - S.bgA end
end)
addToggle(pMain, "背景模糊 (BlurEffect)", false, function(v)
    S.blur = v
    if blurFx then
        blurFx.Size = v and 14 or 0
        blurFx.Enabled = v and main.Visible
    end
end)
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

addSection(pGuard, "① 基础压制")
local guardStatus
addToggle(pGuard, "线程 + 连接 + marker", false, function(v)
    if v then
        local msg = acRun()
        if guardStatus then guardStatus(msg) end
    end
end)
addButton(pGuard, "重新执行基础压制", function()
    local msg = acRun()
    if guardStatus then guardStatus(msg) end
end)

addSection(pGuard, "② AC GUARD — 检测层")
addToggle(pGuard, "挂钩本地检测函数", false, function(v)
    G.layer1 = v
    if v then
        local f, t, c = runLayer1()
        if guardStatus then guardStatus(("检测层: 闭包 %d / 线程 %d / 连接 %d"):format(f, t, c)) end
    end
end)

addSection(pGuard, "③ AC GUARD — 通道层")
addToggle(pGuard, "切断上行 + 拦本地踢人", false, function(v)
    G.layer2 = v
    G.blockKick = v
    if v then
        local n = runLayer2()
        if guardStatus then guardStatus(("通道层: remote %d / blocked %d"):format(n, G.blocked)) end
    end
end)

addSection(pGuard, "哈希搜索")
local hashBox = addBox(pGuard, "输入 AntiCheat / 混淆名 / 脚本名", "AntiCheat")
addButton(pGuard, "哈希搜索 + 挂钩", function()
    local f, t, n = hashSearch(hashBox.Text)
    if guardStatus then guardStatus(("搜索 %s → 闭包 %d / 线程 %d / remote %d"):format(hashBox.Text, f, t, n)) end
end)
addButton(pGuard, "只把关键词加进哈希表", function()
    CONFIG.ACG.Hashes[hash(hashBox.Text)] = true
    if guardStatus then guardStatus(("hash(%s) = %d 已加入"):format(hashBox.Text, hash(hashBox.Text))) end
end)
addButton(pGuard, "列出匹配到 F9 + 恢复钩子", function()
    print(("=== ACG matches (%d) ==="):format(#G.matches))
    for _, m in ipairs(G.matches) do print(m) end
    acgRestore()
    if guardStatus then guardStatus(("已打印 %d 条,__namecall 已恢复"):format(#G.matches)) end
end)

addSection(pGuard, "THREAD CLEANER")
addButton(pGuard, "打开线程面板", function() tcShow() end)
addButton(pGuard, "快速杀 BS_", function()
    TC.all = tcCollect()
    local k, m = tcKill("BS_")
    if guardStatus then guardStatus(("BS_ 匹配 %d / 终止 %d"):format(m, k)) end
end)
addButton(pGuard, "列出全部线程到 F9", function()
    TC.all = tcCollect(); tcDump()
    if guardStatus then guardStatus(("已打印 %d 个线程"):format(#TC.all)) end
end)

rowOrder = rowOrder + 1
guardStatus = addButton(pGuard, "状态: 就绪", function() end)
rowOrder = rowOrder + 1
mk("TextLabel", { Text = "先 ③ 通道层,再 ② 检测层,最后 ① 基础压制。267 是引擎层,这里管不到。",
    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), Font = Enum.Font.Gotham,
    TextSize = 11, TextColor3 = Color3.fromRGB(140, 148, 162), TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = rowOrder }, pGuard)

addSection(pMisc, "清理")
addButton(pMisc, "卸载并恢复", function()
    setFly(false); S.esp = false; S.aim = false
    acgRestore()
    for _, o in pairs(espStore) do destroyESP(o) end
    espStore = {}
    pcall(function() RS:UnbindFromRenderStep("XHubAim") end)
    if blurFx then blurFx:Destroy() end
    gui:Destroy()
end)
addSection(pMisc, "信息")
rowOrder = rowOrder + 1
mk("TextLabel", { Text = ("执行器: %s\nhash() 可用 · ACG 关键词 %d 个"):format(
    (identifyexecutor and identifyexecutor()) or "unknown", #CONFIG.ACG.Keywords),
    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Font = Enum.Font.Code,
    TextSize = 11, TextColor3 = Color3.fromRGB(160, 200, 180), TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = rowOrder }, pMisc)

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

setVisible(true)
toast.Text = "XHub 就绪 · " .. CONFIG.MenuKeys[1].Name .. " 开关菜单"
toast.Visible = true
task.delay(2, function() if toast then toast.Visible = false end end)
print("[XHub] loaded · 菜单键 " .. CONFIG.MenuKeys[1].Name .. " / 5 页 / ACG v2 已并入")
