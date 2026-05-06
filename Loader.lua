-- loadstring(game:HttpGet("https://raw.githubusercontent.com/FZGecko/Loader/refs/heads/main/Loader.lua"))()

--!optimize 2
--!strict
--[[
    ENGINE: FZUI (Foundation)
    PURPOSE: High-Performance, Stealth-Oriented Roblox GUI Library
    VERSION: 0.0.2
]]

-- [[ PROTOTYPES ]]
local Window = {}; Window.__index = Window
local Tab = {}; Tab.__index = Tab
local Section = {}; Section.__index = Section
local Feature = {}; Feature.__index = Feature
local DisplayWindow = {}; DisplayWindow.__index = DisplayWindow

local Janitor = {}; Janitor.__index = Janitor
function Janitor.new()
    return setmetatable({tasks = {}}, Janitor)
end
function Janitor:Add(obj, method)
    table.insert(self.tasks, {obj, method or "Disconnect"})
    return obj
end
function Janitor:Cleanup()
    for _, task in ipairs(self.tasks) do
        local obj, method = task[1], task[2]
        pcall(function()
            if typeof(obj) == "RBXScriptConnection" then
                obj:Disconnect()
            elseif obj[method] then
                obj[method](obj)
            end
        end)
    end
    table.clear(self.tasks)
end

local _sharedRenderSteppedHandlers = {}
local _handlerLookup = {}
local _activeTweens = setmetatable({}, {__mode = "k"})

local UI = {
    _janitor = Janitor.new(),
    _windows = {},
    _flags = {},
    _flatFlags = {},
    _objects = {},
    _binds = {},
    _flagSignals = {},
    _updaters = {},
    _tabs = {},
    _isBinding = false,
    _drag = { active = false },
    _active = true,
    Themes = {
        Default = {
            WindowBackground = Color3.fromRGB(240, 242, 245), -- Clean Off-White
            ContainerBackground = Color3.fromRGB(220, 225, 230), -- Soft Blue-Gray
            SectionBackground = Color3.fromRGB(255, 255, 255), -- Pure Elevated White
            ControlBackground = Color3.fromRGB(200, 205, 215), -- Medium Gray
            Accent = Color3.fromRGB(0, 160, 255), -- Electric Blue
            AccentSecondary = Color3.fromRGB(0, 110, 200), -- Deep Sea Blue
            Text = Color3.fromRGB(35, 40, 45), -- Deep Charcoal
            TextDark = Color3.fromRGB(90, 100, 110), -- Slate Secondary Text
            Outline = Color3.fromRGB(0, 160, 255), -- Cyan/Blue Outline
            Highlight = Color3.fromRGB(255, 255, 255), -- Stark Imperial White
            Font = Enum.Font.BuilderSansMedium,
            FontBold = Enum.Font.BuilderSansExtraBold
        }
    }
}

-- [[ UTILITIES ]]
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local CoreGui = game:GetService("CoreGui")

function UI:_track(conn)
    return self._janitor:Add(conn)
end

local function GetSafeContainer()
    if gethui then return gethui() end
    return nil
end

local TargetContainer = GetSafeContainer()

if not TargetContainer then
    error("[FZUI] INSECURE EXECUTION ENVIRONMENT DETECTED. ABORTING DEPLOYMENT.")
end

local Util = {}

function Util:Create(class, properties, children)
    local inst = Instance.new(class)
    for prop, val in pairs(properties) do
        inst[prop] = val
    end
    if children then
        for _, child in pairs(children) do
            child.Parent = inst
        end
    end
    
    return inst
end

function Util:Tween(obj, info, goal)
    if _activeTweens[obj] then
        _activeTweens[obj]:Cancel()
    end

    local tween = TweenService:Create(obj, TweenInfo.new(unpack(info)), goal)
    _activeTweens[obj] = tween
    tween:Play()

    if obj:IsA("Instance") then
        obj.Destroying:Connect(function()
            if _activeTweens[obj] == tween then
                tween:Cancel()
                _activeTweens[obj] = nil
            end
        end)
    end

    return tween
end

function Util:SafeCall(fn, ...)
    if not fn then return end
    local ok, err = pcall(fn, ...)
    if not ok then
        warn("[FZUI_CALLBACK_ERROR]:", err)
    end
end

-- [[ SIGNAL CLASS ]]
-- Avoids BindableEvent overhead; faster and cleaner for performance.
local Signal = {}
Signal.__index = Signal

function Signal.new()
    return setmetatable({_bindables = {}, _count = 0}, Signal)
end

function Signal:Connect(callback)
    self._count += 1
    local id = self._count
    self._bindables[id] = callback
    return {
        Disconnect = function()
            self._bindables[id] = nil
        end
    }
end

function Signal:Fire(...)
    for _, callback in next, self._bindables do
        Util:SafeCall(callback, ...)
    end
end

function UI:AddRenderHandler(key: string, instance: Instance?, fn: () -> ())
    if _handlerLookup[key] then _handlerLookup[key].dead = true end
    local handler = {key = key, fn = fn, dead = false, instance = instance}
    table.insert(_sharedRenderSteppedHandlers, handler)
    _handlerLookup[key] = handler
    if instance and instance:IsA("Instance") then
        self:_track(instance.Destroying:Connect(function() handler.dead = true end))
    end
end

function UI:_setFlag(flag: string, value: any)
    self._flags[flag] = value
    local serializedValue = value
    if typeof(value) == "Color3" then
        serializedValue = value:ToHex()
    elseif typeof(value) == "EnumItem" then
        serializedValue = value.Name
    end
    self._flatFlags[flag] = serializedValue
end

function UI:_setBind(flag: string, key: Enum.KeyCode | Enum.UserInputType)
    self._binds[flag] = self._binds[flag] or {}
    self._binds[flag].Key = key
    self._flatFlags["BIND_" .. flag] = key.Name
end

function UI:CreateWindow(title: string, transparency: number?)
    local self = setmetatable({}, Window)
    self._tabs, self._popups, self._janitor = {}, {}, Janitor.new()

    local Screen = Util:Create("ScreenGui", {Parent = TargetContainer, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
    self._screen = Screen

    local MainFrame = Util:Create("CanvasGroup", {
        Parent = Screen,
        Size = UDim2.new(0, 650, 0, 720),
        Position = UDim2.new(0.5, -325, 0.5, -360),
        BackgroundColor3 = UI.Themes.Default.WindowBackground,
        GroupTransparency = transparency or 0.1,
        BorderSizePixel = 0,
        ZIndex = 1
    }, {
        Util:Create("UICorner", {CornerRadius = UDim.new(0, 6)}),
        Util:Create("UIStroke", {Color = UI.Themes.Default.Outline, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}),
        Util:Create("UIStroke", {
            Color = UI.Themes.Default.Accent,
            Thickness = 2.5,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        }, {
            Util:Create("UIGradient", {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, UI.Themes.Default.AccentSecondary),
                    ColorSequenceKeypoint.new(0.3, UI.Themes.Default.Accent),
                    ColorSequenceKeypoint.new(0.5, UI.Themes.Default.Highlight),
                    ColorSequenceKeypoint.new(0.7, UI.Themes.Default.Accent),
                    ColorSequenceKeypoint.new(1, UI.Themes.Default.AccentSecondary)
                }),
                Rotation = 45
            })
        })
    })
    self._mainFrame = MainFrame

    local Overlay = Util:Create("Frame", {Parent = Screen, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ZIndex = 100})
    self._overlay = Overlay

    local Header = Util:Create("Frame", {Parent = MainFrame, Size = UDim2.new(1, 0, 0, 60), BackgroundTransparency = 1})

    local Title = Util:Create("TextLabel", {
        Parent = Header,
        Text = "FZ | " .. title:upper(),
        Size = UDim2.new(1, 0, 0, 30),
        Position = UDim2.new(0.5, 0, 0, 20),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 1,
        TextColor3 = UI.Themes.Default.Accent,
        Font = UI.Themes.Default.FontBold,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Center
    })

    Util:Create("Frame", {Parent = Header, Size = UDim2.new(0, 60, 0, 2), Position = UDim2.new(0.5, 0, 0, 12), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = UI.Themes.Default.Accent, BorderSizePixel = 0})
    Util:Create("Frame", {Parent = MainFrame, Size = UDim2.new(1, -60, 0, 1), Position = UDim2.new(0, 30, 0, 55), BackgroundColor3 = UI.Themes.Default.Outline, BackgroundTransparency = 0.5})

    local UnderlineTrack = Util:Create("Frame", {Parent = MainFrame, Size = UDim2.new(1, -40, 0, 2), Position = UDim2.new(0, 20, 0, 90), BackgroundTransparency = 1})
    self._underlineTrack = UnderlineTrack

    local TabUnderline = Util:Create("Frame", {Parent = UnderlineTrack, Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = UI.Themes.Default.Accent, BorderSizePixel = 0}, {Util:Create("UIGradient", {Color = ColorSequence.new(UI.Themes.Default.Accent, UI.Themes.Default.AccentSecondary)})})
    self._underline = TabUnderline

    local MainContainer = Util:Create("Frame", {Parent = MainFrame, Size = UDim2.new(1, -30, 1, -125), Position = UDim2.new(0, 15, 0, 110), BackgroundColor3 = UI.Themes.Default.ContainerBackground, BorderSizePixel = 0}, {Util:Create("UICorner", {CornerRadius = UDim.new(0, 4)})})
    self._container = MainContainer

    local TabBar = Util:Create("Frame", {Parent = MainFrame, Size = UDim2.new(1, -40, 0, 30), Position = UDim2.new(0, 20, 0, 60), BackgroundTransparency = 1}, {Util:Create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 20)})})
    self._tabBar = TabBar

    self:_ApplyDragging(Header)
    MainFrame.GroupTransparency = 1
    Util:Tween(MainFrame, {0.8, Enum.EasingStyle.Quart, Enum.EasingDirection.Out}, {GroupTransparency = transparency or 0.1, Position = UDim2.new(0.5, -325, 0.5, -360)})

    table.insert(UI._windows, self)
    return self
end

-- [[ WINDOW PROTOTYPE ]]
function Window:CreateTab(name: string)
    local tab = setmetatable({ _sections = {}, _window = self }, Tab)
    local TabButton = Util:Create("TextButton", { Parent = self._tabBar, Size = UDim2.new(0, 90, 1, 0), BackgroundTransparency = 1, Text = name, TextColor3 = #self._tabs == 0 and UI.Themes.Default.Accent or UI.Themes.Default.Text, Font = UI.Themes.Default.FontBold, TextSize = 13, AutoButtonColor = false })

    local Page = Util:Create("ScrollingFrame", { Parent = self._container, Size = UDim2.new(1, -10, 1, -10), Position = UDim2.new(0, 5, 0, 5), Visible = false, BackgroundTransparency = 1, ScrollBarThickness = 0, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y }, { Util:Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10) }) })
    local LeftCol = Util:Create("Frame", { Parent = Page, Size = UDim2.new(0.5, -5, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, { Util:Create("UIListLayout", {Padding = UDim.new(0, 10)}) })
    local RightCol = Util:Create("Frame", { Parent = Page, Size = UDim2.new(0.5, -5, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, { Util:Create("UIListLayout", {Padding = UDim.new(0, 10)}) })

    self._janitor:Add(TabButton.MouseButton1Click:Connect(function()
        for _, t in pairs(self._tabs) do 
            t.Page.Visible = false 
            Util:Tween(t.Button, {0.2}, {TextColor3 = UI.Themes.Default.TextDark})
        end
        Page.Visible = true
        Util:Tween(TabButton, {0.2}, {TextColor3 = UI.Themes.Default.Accent})
        self:_UpdateUnderline(TabButton)
    end))

    tab.Page = Page
    tab.Button = TabButton
    tab.Columns = {Left = LeftCol, Right = RightCol}
    table.insert(self._tabs, tab)

    if #self._tabs == 1 then 
        Page.Visible = true
        task.defer(function() self:_UpdateUnderline(TabButton) end)
    end

    return tab
end

function Window:CloseAllPopups()
    for _, obj in ipairs(self._popups) do
        if obj then pcall(function() obj:Destroy() end) end
    end
    table.clear(self._popups)
end

function Window:Destroy()
    self:CloseAllPopups()
    self._janitor:Cleanup()
    if self._screen then self._screen:Destroy() end
end

function Window:SetTransparency(val: number)
    if self._mainFrame then self._mainFrame.GroupTransparency = val end
end

function Window:_UpdateUnderline(TabButton)
    if not UI._active or TabButton.AbsoluteSize.X == 0 then return end
    local tw = TabButton.TextBounds.X + 20
    local tx = (TabButton.AbsolutePosition.X - self._underlineTrack.AbsolutePosition.X) + (TabButton.AbsoluteSize.X / 2) - (tw / 2)
    Util:Tween(self._underline, {0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out}, {Size = UDim2.new(0, tw, 0, 2), Position = UDim2.new(0, tx, 0, 0)}) 
end

function Window:_ApplyDragging(Header)
    local Dragging, DragStart, StartPos
    self._janitor:Add(Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and not UserInputService:GetFocusedTextBox() then
            Dragging, DragStart, StartPos = true, input.Position, self._mainFrame.Position
            local connection
            connection = self._janitor:Add(input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then Dragging = false; connection:Disconnect() end
            end))
        end
    end))
    self._janitor:Add(UserInputService.InputChanged:Connect(function(input)
        if Dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - DragStart
            local screenSize = self._screen.AbsoluteSize
            local uiSize = self._mainFrame.AbsoluteSize

            local centerX, centerY = screenSize.X * StartPos.X.Scale, screenSize.Y * StartPos.Y.Scale
            local newX = math.clamp(centerX + StartPos.X.Offset + delta.X, 0, screenSize.X - uiSize.X)
            local newY = math.clamp(centerY + StartPos.Y.Offset + delta.Y, 0, screenSize.Y - uiSize.Y)

            self._mainFrame.Position = UDim2.new(StartPos.X.Scale, newX - centerX, StartPos.Y.Scale, newY - centerY)
        end
    end))
end

-- [[ TAB PROTOTYPE ]]
function Tab:CreateSection(label: string, side: string)
    local section = setmetatable({ _nextOrder = 0, _window = self._window, _janitor = Janitor.new() }, Section)
    self._window._janitor:Add(section._janitor, "Cleanup")
    side = (side == "Left" or side == "Right") and side or "Left"
    
    local SectionFrame = Util:Create("Frame", {
        Parent = self.Columns[side],
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = UI.Themes.Default.SectionBackground,
        AutomaticSize = Enum.AutomaticSize.Y
    }, {
        Util:Create("UICorner", {CornerRadius = UDim.new(0, 4)}),
        Util:Create("UIStroke", { Color = UI.Themes.Default.Outline, Thickness = 1 }),
        Util:Create("UIListLayout", { Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
        Util:Create("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) })
    })
    section._instance = SectionFrame

    Util:Create("TextLabel", { Parent = SectionFrame, Text = label:upper(), Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, TextColor3 = UI.Themes.Default.Accent, Font = UI.Themes.Default.FontBold, TextSize = 15, LayoutOrder = -100 })
    return section
end

-- [[ SECTION PROTOTYPE ]]
function Section:AddSubTitle(text: string)
    self._nextOrder += 1
    return Util:Create("TextLabel", { Parent = self._instance, Text = text:upper(), Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, TextColor3 = UI.Themes.Default.Accent, Font = UI.Themes.Default.FontBold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = self._nextOrder })
end

function Section:AddFeature(name: string)
    self._nextOrder += 1
    local FeatureFrame = Util:Create("Frame", { Parent = self._instance, Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = self._nextOrder }, {
        Util:Create("TextLabel", { Text = name, Size = UDim2.new(0.4, 0, 1, 0), BackgroundTransparency = 1, TextColor3 = UI.Themes.Default.Text, Font = UI.Themes.Default.Font, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left })
    })
    local ControlContainer = Util:Create("Frame", { Parent = FeatureFrame, Size = UDim2.new(0.6, 0, 1, 0), Position = UDim2.new(0.4, 0, 0, 0), BackgroundTransparency = 1 }, {
        Util:Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) })
    })

    local feature = setmetatable({ _name = name, _container = ControlContainer, _window = self._window, _flag = nil, _janitor = Janitor.new() }, Feature)
    -- Hierarchy: Feature is owned by Section
    self._janitor:Add(feature._janitor, "Cleanup")
    return feature
end

-- [[ FEATURE PROTOTYPE ]]
function Feature:AddToggle(flag: string, default: boolean, callback: (boolean) -> ())
    self._flag = flag
    UI:_setFlag(flag, default)
    local Switch = Util:Create("TextButton", { Parent = self._container, Size = UDim2.new(0, 32, 0, 16), BackgroundColor3 = default and UI.Themes.Default.Accent or UI.Themes.Default.ControlBackground, Text = "", AutoButtonColor = false, LayoutOrder = 3 }, { Util:Create("UICorner", {CornerRadius = UDim.new(1, 0)}) })
    local Dot = Util:Create("Frame", { Parent = Switch, Size = UDim2.new(0, 12, 0, 12), Position = default and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6), BackgroundColor3 = UI.Themes.Default.Highlight }, { Util:Create("UICorner", {CornerRadius = UDim.new(1, 0)}) })
    UI._updaters[flag] = function(active) 
        UI._flags[flag] = active; 
        Util:Tween(Switch, {0.15}, {BackgroundColor3 = active and UI.Themes.Default.Accent or UI.Themes.Default.ControlBackground}); 
        Util:Tween(Dot, {0.15}, {Position = active and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)})
        Util:SafeCall(callback, active)
    end
    self._janitor:Add({Cleanup = function() UI._updaters[flag] = nil end}, "Cleanup")
    
    self._janitor:Add(Switch.MouseButton1Click:Connect(function() local active = not UI._flags[flag]; UI._updaters[flag](active) end))
    return self
end

function Feature:AddKeybind(flag: string, default: Enum.KeyCode, callback: (any) -> ())
    local Binding = false
    local function GetName(k) return k.Name:gsub("MouseButton", "MB"):gsub("Keyboard", "") end
    local Btn = Util:Create("TextButton", { Parent = self._container, Size = UDim2.new(0, 60, 0, 22), BackgroundColor3 = UI.Themes.Default.ControlBackground, Text = GetName(default), TextColor3 = UI.Themes.Default.Text, Font = UI.Themes.Default.Font, TextSize = 10, LayoutOrder = 1 }, { Util:Create("UIStroke", {Color = UI.Themes.Default.Outline}), Util:Create("UICorner", {CornerRadius = UDim.new(0, 3)}) })
    
    -- Simplified internalCallback: it just passes through to the user's callback
    local internalCallback = function(...)
        Util:SafeCall(callback, ...)
    end

    UI._binds[flag] = { Key = default, Callback = internalCallback, Mode = "Toggle", Name = self._name, Flag = flag } -- Store metadata for Keybind List
    UI:UpdateBindMap()
    self._janitor:Add({Cleanup = function() UI._binds[flag] = nil; UI:UpdateBindMap() end}, "Cleanup")

    self._janitor:Add(Btn.MouseButton1Click:Connect(function()
        if Binding then return end
        Binding = true; UI._isBinding = true; Btn.Text = "..."
        local tempConn
        tempConn = self._janitor:Add(UserInputService.InputBegan:Connect(function(input)
            local k = input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode or input.UserInputType
            if k == Enum.UserInputType.Focus then return end
            tempConn:Disconnect()
            if k == Enum.KeyCode.Escape then
                UI:_setBind(flag, Enum.KeyCode.Unknown); Btn.Text = "NONE"
            else
                UI:_setBind(flag, k); Btn.Text = GetName(k)
            end
            UI:UpdateBindMap(); Binding = false; task.wait(); UI._isBinding = false
        end))
    end))
    return self
end

function Feature:AddColorPicker(flag: string, default: Color3, callback: (Color3) -> ())
    local h, s, v = default:ToHSV()
    local cpState = { h = h, s = s, v = v }
    UI:_setFlag(flag, default)
    UI:_setFlag(flag .. "_Alpha", UI._flags[flag .. "_Alpha"] or 0)
    UI:_setFlag(flag .. "_Rainbow", UI._flags[flag .. "_Rainbow"] or false)
    UI:_setFlag(flag .. "_RainbowSpeed", UI._flags[flag .. "_RainbowSpeed"] or 0.5)
    self._janitor:Add({Cleanup = function() UI._updaters[flag] = nil end}, "Cleanup")

    local PickerBtn = Util:Create("TextButton", { Parent = self._container, Size = UDim2.new(0, 16, 0, 16), BackgroundColor3 = default, Text = "", AutoButtonColor = false, LayoutOrder = 2 }, { Util:Create("UICorner", {CornerRadius = UDim.new(0, 4)}), Util:Create("UIStroke", {Color = UI.Themes.Default.Outline, Thickness = 1}) })
    
    local pickerState = { IsOpen = false, ActivePickerInstance = nil, Janitor = nil }

    local function Close()
        if not pickerState.IsOpen then return end
        pickerState.IsOpen = false
        
        if pickerState.Janitor then
            pickerState.Janitor:Cleanup()
            pickerState.Janitor = nil
        end
        
        if pickerState.ActivePickerInstance then
            for i, popup in ipairs(self._window._popups) do
                if popup == pickerState.ActivePickerInstance then
                    table.remove(self._window._popups, i)
                    break
                end
            end
        end

        pickerState.ActivePickerInstance = nil

        if _handlerLookup[flag .. "_SVMap"] then _handlerLookup[flag .. "_SVMap"].dead = true end
        if _handlerLookup[flag .. "_Hue"] then _handlerLookup[flag .. "_Hue"].dead = true end
        if _handlerLookup[flag .. "_Alpha"] then _handlerLookup[flag .. "_Alpha"].dead = true end
        if _handlerLookup[flag .. "_Speed"] then _handlerLookup[flag .. "_Speed"].dead = true end
        if _handlerLookup[flag .. "_Rainbow"] then _handlerLookup[flag .. "_Rainbow"].dead = true end
    end
    
    local function Open()
        if pickerState.IsOpen then return end
        pickerState.Janitor = Janitor.new()
        self._window:CloseAllPopups()
        local PickerWindow = Util:Create("Frame", { Parent = self._window._overlay, Size = UDim2.new(0, 190, 0, 280), Position = UDim2.new(0, PickerBtn.AbsolutePosition.X - 195, 0, PickerBtn.AbsolutePosition.Y), BackgroundColor3 = UI.Themes.Default.SectionBackground, ZIndex = 110, Active = true }, { Util:Create("UICorner", {CornerRadius = UDim.new(0, 4)}), Util:Create("UIStroke", {Color = UI.Themes.Default.Accent, Thickness = 1.5}) })
        pickerState.Janitor:Add(PickerWindow, "Destroy"); pickerState.ActivePickerInstance = PickerWindow; pickerState.IsOpen = true
        table.insert(self._window._popups, PickerWindow)
        pickerState.Janitor:Add(PickerWindow.Destroying:Connect(Close))
        local HueSlider = Util:Create("Frame", { Parent = PickerWindow, Size = UDim2.new(0, 12, 0, 140), Position = UDim2.new(0, 10, 0, 10), BackgroundColor3 = UI.Themes.Default.Highlight }, { Util:Create("UICorner", {CornerRadius = UDim.new(0, 2)}), Util:Create("UIGradient", { Rotation = 90, Color = ColorSequence.new({ 
            ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)), ColorSequenceKeypoint.new(0.167, Color3.fromHSV(0.167, 1, 1)),
            ColorSequenceKeypoint.new(0.333, Color3.fromHSV(0.333, 1, 1)), ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
            ColorSequenceKeypoint.new(0.667, Color3.fromHSV(0.667, 1, 1)), ColorSequenceKeypoint.new(0.833, Color3.fromHSV(0.833, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1))
        }) }) })
        
        local HuePin = Util:Create("Frame", { Parent = HueSlider, Size = UDim2.new(1, 2, 0, 2), Position = UDim2.new(0, -2, cpState.h, 0), BackgroundColor3 = UI.Themes.Default.Highlight }, { Util:Create("UIStroke", {Thickness = 1}) })
        local SVMap = Util:Create("ImageLabel", { Parent = PickerWindow, Size = UDim2.new(0, 140, 0, 140), Position = UDim2.new(0, 32, 0, 10), Image = "rbxassetid://4155801252", BackgroundColor3 = Color3.fromHSV(cpState.h, 1, 1), ScaleType = Enum.ScaleType.Stretch })
        local SVPin = Util:Create("Frame", { Parent = SVMap, Size = UDim2.new(0, 4, 0, 4), Position = UDim2.new(cpState.s, -2, 1 - cpState.v, -2), BackgroundColor3 = UI.Themes.Default.Highlight }, { Util:Create("UIStroke", {Thickness = 1}) })
        local AlphaSlider = Util:Create("Frame", { Parent = PickerWindow, Size = UDim2.new(0, 170, 0, 12), Position = UDim2.new(0, 10, 0, 158), BackgroundColor3 = UI.Themes.Default.Highlight }, { Util:Create("UICorner", {CornerRadius = UDim.new(0, 2)}), Util:Create("UIGradient", { Color = ColorSequence.new(default, UI.Themes.Default.SectionBackground) }) })
        local AlphaPin = Util:Create("Frame", { Parent = AlphaSlider, Size = UDim2.new(0, 2, 1, 2), Position = UDim2.new(UI._flags[flag .. "_Alpha"], -1, 0, -1), BackgroundColor3 = UI.Themes.Default.Accent }, { Util:Create("UIStroke", {Thickness = 1}) })
        
        -- Unified Utility Row: Hex (Left) + Rainbow (Right)
        local UtilRow = Util:Create("Frame", { Parent = PickerWindow, Size = UDim2.new(1, -20, 0, 20), Position = UDim2.new(0, 10, 0, 178), BackgroundTransparency = 1 })
        local HexInput = Util:Create("TextBox", { Parent = UtilRow, Size = UDim2.new(0, 60, 1, 0), BackgroundColor3 = UI.Themes.Default.ControlBackground, Text = "#" .. UI._flags[flag]:ToHex():upper(), TextColor3 = UI.Themes.Default.Text, Font = UI.Themes.Default.Font, TextSize = 10, ClearTextOnFocus = false }, { Util:Create("UICorner", {CornerRadius = UDim.new(0, 4)}), Util:Create("UIStroke", {Color = UI.Themes.Default.Outline, Thickness = 0.8}) })
        local RainbowLabel = Util:Create("TextLabel", { Parent = UtilRow, Text = "RAINBOW", Size = UDim2.new(0, 50, 1, 0), Position = UDim2.new(1, -75, 0, 0), BackgroundTransparency = 1, TextColor3 = UI.Themes.Default.Text, Font = UI.Themes.Default.FontBold, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Right })
        local RainbowToggle = Util:Create("TextButton", { Parent = UtilRow, Size = UDim2.new(0, 22, 0, 10), Position = UDim2.new(1, -22, 0.5, -5), BackgroundColor3 = UI._flags[flag .. "_Rainbow"] and UI.Themes.Default.Accent or UI.Themes.Default.ControlBackground, Text = "", AutoButtonColor = false }, { Util:Create("UICorner", {CornerRadius = UDim.new(1, 0)}) })
        local RainbowDot = Util:Create("Frame", { Parent = RainbowToggle, Size = UDim2.new(0, 6, 0, 6), Position = UI._flags[flag .. "_Rainbow"] and UDim2.new(1, -8, 0.5, -3) or UDim2.new(0, 2, 0.5, -3), BackgroundColor3 = UI.Themes.Default.Highlight }, { Util:Create("UICorner", {CornerRadius = UDim.new(1, 0)}) })

        local SpeedRow = Util:Create("Frame", { Parent = PickerWindow, Size = UDim2.new(1, -20, 0, 32), Position = UDim2.new(0, 10, 0, 205), BackgroundTransparency = 1 }, { Util:Create("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, FillDirection = Enum.FillDirection.Vertical}) })
        local SpeedTop = Util:Create("Frame", { Parent = SpeedRow, Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, LayoutOrder = 1 }, { Util:Create("TextLabel", { Text = "CYCLE SPEED", Size = UDim2.new(0.6, 0, 1, 0), BackgroundTransparency = 1, TextColor3 = UI.Themes.Default.TextDark, Font = UI.Themes.Default.Font, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left }), Util:Create("TextBox", { Size = UDim2.new(0, 35, 1, 2), Position = UDim2.new(1, -35, 0, -1), BackgroundColor3 = UI.Themes.Default.ControlBackground, Text = tostring(math.floor((UI._flags[flag .. "_RainbowSpeed"] or 0.5) * 100)), TextColor3 = UI.Themes.Default.Text, Font = UI.Themes.Default.Font, TextSize = 9, ClearTextOnFocus = false }, { Util:Create("UICorner", {CornerRadius = UDim.new(0, 3)}), Util:Create("UIStroke", {Color = UI.Themes.Default.Outline, Thickness = 0.8}) }) })
        local SpeedInput = SpeedTop:FindFirstChildWhichIsA("TextBox") :: TextBox
        local SpeedBar = Util:Create("Frame", { Parent = SpeedRow, Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = UI.Themes.Default.ControlBackground, LayoutOrder = 2 }, { Util:Create("UICorner", {CornerRadius = UDim.new(1, 0)}) })
        local SpeedFill = Util:Create("Frame", { Parent = SpeedBar, Size = UDim2.new(UI._flags[flag .. "_RainbowSpeed"] or 0.5, 0, 1, 0), BackgroundColor3 = UI.Themes.Default.Accent }, { Util:Create("UICorner", {CornerRadius = UDim.new(1, 0)}), Util:Create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 8, 0, 8), BackgroundColor3 = UI.Themes.Default.Highlight }, { Util:Create("UICorner", {CornerRadius = UDim.new(1, 0)}), Util:Create("UIStroke", {Thickness = 1, Color = UI.Themes.Default.Accent}) }) })
        
        local AlphaGradient = AlphaSlider:FindFirstChildWhichIsA("UIGradient")
        
        local function UpdateColor()
            local newCol = Color3.fromHSV(cpState.h, cpState.s, cpState.v)
            UI:_setFlag(flag, newCol)
            PickerBtn.BackgroundColor3 = newCol
            PickerBtn.BackgroundTransparency = UI._flags[flag .. "_Alpha"]
            SVMap.BackgroundColor3 = Color3.fromHSV(cpState.h, 1, 1)
            if HexInput then HexInput.Text = "#" .. newCol:ToHex():upper() end
            if UI._flags[flag .. "_Rainbow"] then
                RainbowToggle.BackgroundColor3 = newCol
            end
            if AlphaGradient then
                AlphaGradient.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, newCol),
                    ColorSequenceKeypoint.new(1, UI.Themes.Default.SectionBackground)
                })
            end
            Util:SafeCall(callback, newCol)
        end

        HexInput.FocusLost:Connect(function()
            local text = HexInput.Text:gsub("#", "")
            if #text == 6 then
                local success, result = pcall(Color3.fromHex, text)
                if success then
                    cpState.h, cpState.s, cpState.v = result:ToHSV()
                    HuePin.Position = UDim2.new(0, -2, cpState.h, 0)
                    SVPin.Position = UDim2.new(cpState.s, -2, 1 - cpState.v, -2)
                    UpdateColor()
                else
                    HexInput.Text = "#" .. UI._flags[flag]:ToHex():upper()
                end
            else
                HexInput.Text = "#" .. UI._flags[flag]:ToHex():upper()
            end
        end)

        local function rainbowHandler()
            local speed = (UI._flags[flag .. "_RainbowSpeed"] or 0.5) * 0.5
            cpState.h = (os.clock() * speed) % 1
            HuePin.Position = UDim2.new(0, -2, cpState.h, 0)
            UpdateColor()
        end

        local function ToggleRainbow(active: boolean)
            if UI._flags[flag .. "_Rainbow"] then
                UI:AddRenderHandler(flag .. "_Rainbow", PickerWindow, rainbowHandler)
            else
                if _handlerLookup[flag .. "_Rainbow"] then _handlerLookup[flag .. "_Rainbow"].dead = true end
                RainbowToggle.BackgroundColor3 = UI.Themes.Default.ControlBackground

            end
        end

        ToggleRainbow(UI._flags[flag .. "_Rainbow"])

        pickerState.Janitor:Add(SVMap.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then 
            UI._drag = { active = true, type = "SVMap", instance = SVMap, pin = SVPin, state = cpState, update = UpdateColor }
        end end))
        pickerState.Janitor:Add(HueSlider.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then 
            UI._drag = { active = true, type = "Hue", instance = HueSlider, pin = HuePin, state = cpState, update = UpdateColor }
        end end))
        pickerState.Janitor:Add(AlphaSlider.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then 
            UI._drag = { active = true, type = "Alpha", flag = flag, instance = AlphaSlider, pin = AlphaPin, update = UpdateColor }
        end end))
        pickerState.Janitor:Add(SpeedBar.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then 
            UI._drag = { active = true, type = "Speed", flag = flag, instance = SpeedBar, fill = SpeedFill, input = SpeedInput }
        end end))
        
        if SpeedInput then pickerState.Janitor:Add(SpeedInput.FocusLost:Connect(function() local val = tonumber(SpeedInput.Text); if val then val = math.clamp(math.floor(val), 0, 100); UI:_setFlag(flag .. "_RainbowSpeed", val / 100); SpeedFill.Size = UDim2.new(val / 100, 0, 1, 0); SpeedInput.Text = tostring(val) else SpeedInput.Text = tostring(math.floor(UI._flags[flag .. "_RainbowSpeed"] * 100)) end end)) end
        pickerState.Janitor:Add(RainbowToggle.MouseButton1Click:Connect(function() UI:_setFlag(flag .. "_Rainbow", not UI._flags[flag .. "_Rainbow"]); Util:Tween(RainbowDot, {0.15}, {Position = UI._flags[flag .. "_Rainbow"] and UDim2.new(1, -10, 0.5, -4) or UDim2.new(0, 2, 0.5, -4)}); ToggleRainbow(UI._flags[flag .. "_Rainbow"]) end))
        
        task.defer(function() 
            pickerState.Janitor:Add(UserInputService.InputBegan:Connect(function(input)
                if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                local mPos = UserInputService:GetMouseLocation()
                local gInset = GuiService:GetGuiInset()
                local pPos, pSize = PickerWindow.AbsolutePosition + gInset, PickerWindow.AbsoluteSize
                local bPos, bSize = PickerBtn.AbsolutePosition + gInset, PickerBtn.AbsoluteSize
                if not (mPos.X >= pPos.X and mPos.X <= pPos.X + pSize.X and mPos.Y >= pPos.Y and mPos.Y <= pPos.Y + pSize.Y) and not (mPos.X >= bPos.X and mPos.X <= bPos.X + bSize.X and mPos.Y >= bPos.Y and mPos.Y <= bPos.Y + bSize.Y) then Close() end 
            end))
        end)
    end -- End of Open()
    
    self._janitor:Add(PickerBtn.MouseButton1Click:Connect(function() if pickerState.IsOpen then Close() else Open() end end))
    UI._updaters[flag] = function(val) local newCol = (typeof(val) == "string") and Color3.fromHex(val) or val; UI:_setFlag(flag, newCol); PickerBtn.BackgroundColor3 = newCol; cpState.h, cpState.s, cpState.v = newCol:ToHSV() end
    return self
end

function Section:AddButton(text: string, callback: () -> ())
    self._nextOrder += 1
    local Btn = Util:Create("TextButton", { Parent = self._instance, Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = UI.Themes.Default.ControlBackground, Text = text:upper(), TextColor3 = UI.Themes.Default.Text, Font = UI.Themes.Default.FontBold, TextSize = 13, AutoButtonColor = false, LayoutOrder = self._nextOrder }, { Util:Create("UIStroke", { Color = UI.Themes.Default.Outline, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }), Util:Create("UICorner", {CornerRadius = UDim.new(0, 4)}) }) -- Line break for readability
    self._janitor:Add(Btn.MouseButton1Click:Connect(function() Util:SafeCall(callback) end))
end

function Section:AddSlider(text: string, flag: string, min: number, max: number, default: number, callback: (number) -> ())
    self._nextOrder += 1; UI:_setFlag(flag, default)
    local SliderRow = Util:Create("Frame", { Parent = self._instance, Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, LayoutOrder = self._nextOrder }, { Util:Create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, FillDirection = Enum.FillDirection.Vertical}) })
    local TopRow = Util:Create("Frame", { Parent = SliderRow, Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, LayoutOrder = 1 }, { Util:Create("TextLabel", { Text = text, Size = UDim2.new(0.7, 0, 1, 0), BackgroundTransparency = 1, TextColor3 = UI.Themes.Default.Text, Font = UI.Themes.Default.Font, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left }), Util:Create("TextBox", { Size = UDim2.new(0, 40, 1, 2), Position = UDim2.new(1, -40, 0, -1), BackgroundColor3 = UI.Themes.Default.ControlBackground, Text = tostring(default), TextColor3 = UI.Themes.Default.Text, Font = UI.Themes.Default.Font, TextSize = 10, ClearTextOnFocus = false }, { Util:Create("UICorner", {CornerRadius = UDim.new(0, 3)}), Util:Create("UIStroke", {Color = UI.Themes.Default.Outline, Thickness = 0.8}) }) })
    local Bar = Util:Create("Frame", { Parent = SliderRow, Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = UI.Themes.Default.ControlBackground, LayoutOrder = 2 }, { Util:Create("UICorner", {CornerRadius = UDim.new(1, 0)}) })
    local Fill = Util:Create("Frame", { Parent = Bar, Size = UDim2.new(math.clamp((default - min) / (max - min), 0, 1), 0, 1, 0), BackgroundColor3 = UI.Themes.Default.Accent }, { Util:Create("UICorner", {CornerRadius = UDim.new(1, 0)}), Util:Create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 10, 0, 10), BackgroundColor3 = UI.Themes.Default.Highlight }, { Util:Create("UICorner", {CornerRadius = UDim.new(1, 0)}), Util:Create("UIStroke", {Thickness = 1.5, Color = UI.Themes.Default.Accent}) }) })
    
    local function UpdateUI(val)
        UI:_setFlag(flag, val); Fill.Size = UDim2.new(math.clamp((val - min) / (max - min), 0, 1), 0, 1, 0)
        local box = TopRow:FindFirstChildWhichIsA("TextBox"); if box then box.Text = tostring(val) end
    end
    UI._updaters[flag] = UpdateUI
    self._janitor:Add({Cleanup = function() UI._updaters[flag] = nil end}, "Cleanup")
    
    self._janitor:Add(Bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            UI._drag = {
                active = true, type = "Slider", instance = Bar, min = min, max = max, update = UpdateUI, callback = callback
            }
        end
    end))
end

function Section:AddDropdown(text: string, flag: string, options: {string}, default: string, callback: (string) -> ())
    self._nextOrder += 1; UI:_setFlag(flag, default)
    local Container = Util:Create("Frame", { Parent = self._instance, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = self._nextOrder }, { Util:Create("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}) })
    local Label = Util:Create("TextLabel", { Parent = Container, Text = text, Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, TextColor3 = UI.Themes.Default.TextDark, Font = UI.Themes.Default.Font, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1 })
    local DropBtn = Util:Create("TextButton", { Parent = Container, Size = UDim2.new(1, 0, 0, 25), BackgroundColor3 = UI.Themes.Default.ControlBackground, Text = "  " .. default, TextColor3 = UI.Themes.Default.Text, Font = UI.Themes.Default.Font, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2 }, { Util:Create("UIStroke", {Color = UI.Themes.Default.Outline}), Util:Create("UICorner", {CornerRadius = UDim.new(0, 4)}) })
    
    self._janitor:Add({Cleanup = function() UI._updaters[flag] = nil end}, "Cleanup")

    self._janitor:Add(DropBtn.MouseButton1Click:Connect(function()
        self._window:CloseAllPopups()
        local List = Util:Create("ScrollingFrame", { Parent = self._window._overlay, Size = UDim2.new(0, DropBtn.AbsoluteSize.X, 0, math.min(#options * 25, 150)), Position = UDim2.new(0, DropBtn.AbsolutePosition.X, 0, DropBtn.AbsolutePosition.Y + 30), BackgroundColor3 = UI.Themes.Default.SectionBackground, ScrollBarThickness = 2, CanvasSize = UDim2.new(0, 0, 0, #options * 25), ZIndex = 105 }, { Util:Create("UIListLayout", {}), Util:Create("UIStroke", {Color = UI.Themes.Default.Accent}), Util:Create("UICorner", {CornerRadius = UDim.new(0, 4)}) })
        table.insert(self._window._popups, List)

        task.defer(function()
            local clickConn
            clickConn = UserInputService.InputBegan:Connect(function(input)
                if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                local mPos = UserInputService:GetMouseLocation()
                local gInset = GuiService:GetGuiInset()
                local lPos, lSize = List.AbsolutePosition + gInset, List.AbsoluteSize
                local bPos, bSize = DropBtn.AbsolutePosition + gInset, DropBtn.AbsoluteSize

                if not (mPos.X >= lPos.X and mPos.X <= lPos.X + lSize.X and mPos.Y >= lPos.Y and mPos.Y <= lPos.Y + lSize.Y) and 
                   not (mPos.X >= bPos.X and mPos.X <= bPos.X + bSize.X and mPos.Y >= bPos.Y and mPos.Y <= bPos.Y + bSize.Y) then
                    self._window:CloseAllPopups()
                end
            end)
            List.Destroying:Connect(function() clickConn:Disconnect() end)
        end)

        for _, opt in ipairs(options) do
            local isSelected = (UI._flags[flag] == opt)
            local OptBtn = Util:Create("TextButton", { Parent = List, Size = UDim2.new(1, 0, 0, 25), BackgroundTransparency = 1, Text = "  " .. opt, TextColor3 = isSelected and UI.Themes.Default.Accent or UI.Themes.Default.Text, Font = isSelected and UI.Themes.Default.FontBold or UI.Themes.Default.Font, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left })
            self._janitor:Add(OptBtn.MouseButton1Click:Connect(function() UI:_setFlag(flag, opt); DropBtn.Text = "  " .. opt; Util:SafeCall(callback, opt); self._window:CloseAllPopups() end))
        end
    end))
end

function Window:CreateDisplayWindow(title: string, size: UDim2, transparency: number?)
    local display = setmetatable({ _janitor = Janitor.new() }, DisplayWindow)
    -- Hierarchy: DisplayWindow is owned by the Main Window
    self._janitor:Add(display._janitor, "Cleanup")

    local Frame = Util:Create("CanvasGroup", { Parent = self._screen, Size = size or UDim2.new(0, 200, 0, 250), Position = UDim2.new(1, -220, 0.5, -125), BackgroundColor3 = UI.Themes.Default.WindowBackground, GroupTransparency = transparency or 0.3, Active = true }, { Util:Create("UICorner", {CornerRadius = UDim.new(0, 4)}), Util:Create("UIStroke", {Color = UI.Themes.Default.Outline}), Util:Create("TextLabel", { Text = title:upper(), Size = UDim2.new(1, 0, 0, 25), TextColor3 = UI.Themes.Default.Accent, Font = UI.Themes.Default.FontBold, TextSize = 12, BackgroundTransparency = 1 }) })
    display._janitor:Add(Frame, "Destroy")
    display._frame = Frame
    display._container = Util:Create("Frame", { Parent = Frame, Size = UDim2.new(1, -10, 1, -35), Position = UDim2.new(0, 5, 0, 30), BackgroundTransparency = 1 }, { Util:Create("UIListLayout", {Padding = UDim.new(0, 5)}) })
    return display
end

function DisplayWindow:AddLabel(text: string)
    return Util:Create("TextLabel", { Parent = self._container, Text = text, Size = UDim2.new(1, 0, 0, 18), TextColor3 = UI.Themes.Default.Text, Font = UI.Themes.Default.Font, TextSize = 11, BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left })
end

function DisplayWindow:SetTransparency(val: number)
    if self._frame then self._frame.GroupTransparency = val end
end

function UI:CreateLoader(config: {Title: string, Subtitle: string?, Steps: {string}?, Duration: number?, Transparency: number?}, callback: () -> ())
    if not TargetContainer then return end
    local Screen = Util:Create("ScreenGui", {Parent = TargetContainer, ResetOnSpawn = false})
    local Loader = Util:Create("CanvasGroup", {
        Parent = Screen, Size = UDim2.new(0, 320, 0, 160), Position = UDim2.new(0.5, -160, 0.48, -80),
        BackgroundColor3 = self.Themes.Default.WindowBackground, GroupTransparency = 1
    }, {
        Util:Create("UICorner", {CornerRadius = UDim.new(0, 6)}),
        Util:Create("UIStroke", {Color = self.Themes.Default.Accent, Thickness = 2})
    })
    self._activeLoader = Loader

    Util:Create("TextLabel", {Parent = Loader, Text = config.Title:upper(), Size = UDim2.new(1, 0, 0, 40), TextColor3 = self.Themes.Default.Accent, Font = self.Themes.Default.FontBold, TextSize = 16, BackgroundTransparency = 1})
    local Status = Util:Create("TextLabel", {Parent = Loader, Text = config.Subtitle or "INITIALIZING...", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0, 50), TextColor3 = self.Themes.Default.TextDark, Font = self.Themes.Default.Font, TextSize = 11, BackgroundTransparency = 1})
    local Bar = Util:Create("Frame", {Parent = Loader, Size = UDim2.new(1, -60, 0, 4), Position = UDim2.new(0, 30, 0, 100), BackgroundColor3 = self.Themes.Default.ControlBackground}, {Util:Create("UICorner", {CornerRadius = UDim.new(1, 0)})})
    local Fill = Util:Create("Frame", {Parent = Bar, Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = self.Themes.Default.Accent}, {Util:Create("UICorner", {CornerRadius = UDim.new(1, 0)})})

    Util:Tween(Loader, {0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out}, {GroupTransparency = config.Transparency or 0.1, Position = UDim2.new(0.5, -160, 0.5, -80)})

    local totalDuration = config.Duration or 2
    local steps = config.Steps or {config.Subtitle or "LOADING..."}

    task.spawn(function()
        Util:Tween(Fill, {totalDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out}, {Size = UDim2.new(1, 0, 1, 0)})
        for i, stepText in ipairs(steps) do
            Status.Text = stepText:upper()
            task.wait(totalDuration / #steps)
        end
        Util:Tween(Loader, {0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In}, {GroupTransparency = 1, Position = UDim2.new(0.5, -160, 0.52, -80)})
        task.wait(0.5)
        self._activeLoader = nil
        Screen:Destroy(); Util:SafeCall(callback)
    end)
end

-- [[ PREMADE: KEY SYSTEM ]]
function UI:CreateKeySystem(config: {Title: string?, Key: string, Transparency: number?}, callback: () -> ())
    if not TargetContainer then return end
    local Screen = Util:Create("ScreenGui", {Parent = TargetContainer, ResetOnSpawn = false})
    local Main = Util:Create("CanvasGroup", {
        Parent = Screen, Size = UDim2.new(0, 300, 0, 180), Position = UDim2.new(0.5, -150, 0.48, -90), 
        BackgroundColor3 = self.Themes.Default.WindowBackground, GroupTransparency = 1
    }, {
        Util:Create("UICorner", {CornerRadius = UDim.new(0, 6)}),
        Util:Create("UIStroke", {Color = self.Themes.Default.Accent, Thickness = 2})
    })
    self._activeKeySystem = Main

    Util:Create("TextLabel", {Parent = Main, Text = (config.Title or "VILTRUM ACCESS"):upper(), Size = UDim2.new(1, 0, 0, 40), TextColor3 = self.Themes.Default.Accent, Font = self.Themes.Default.FontBold, TextSize = 16, BackgroundTransparency = 1})
    local Input = Util:Create("TextBox", {Parent = Main, Size = UDim2.new(1, -40, 0, 35), Position = UDim2.new(0, 20, 0, 60), BackgroundColor3 = self.Themes.Default.ControlBackground, PlaceholderText = "Enter Key...", Text = "", TextColor3 = self.Themes.Default.Text, Font = self.Themes.Default.Font, TextSize = 12}, {Util:Create("UICorner", {CornerRadius = UDim.new(0, 4)}), Util:Create("UIStroke", {Color = self.Themes.Default.Outline})})
    local Verify = Util:Create("TextButton", {Parent = Main, Size = UDim2.new(1, -40, 0, 35), Position = UDim2.new(0, 20, 0, 110), BackgroundColor3 = self.Themes.Default.Accent, Text = "VERIFY", TextColor3 = self.Themes.Default.Highlight, Font = self.Themes.Default.FontBold, TextSize = 14}, {Util:Create("UICorner", {CornerRadius = UDim.new(0, 4)})})

    Util:Tween(Main, {0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out}, {Position = UDim2.new(0.5, -150, 0.5, -90), GroupTransparency = config.Transparency or 0.1})

    UI:_track(Verify.MouseButton1Click:Connect(function()
        if Input.Text == config.Key then
            Util:Tween(Main, {0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In}, {Position = UDim2.new(0.5, -150, 0.52, -90), GroupTransparency = 1})
            task.wait(0.5)
            self._activeKeySystem = nil
            Screen:Destroy(); Util:SafeCall(callback)
        else
            Verify.Text = "INVALID KEY"; Verify.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
            task.wait(1); Verify.Text = "VERIFY"; Verify.BackgroundColor3 = UI.Themes.Default.Accent
        end
    end))
end

function UI:CreateWatermark(title: string, transparency: number?)
    local watermarkJanitor = Janitor.new()
    self._janitor:Add(watermarkJanitor, "Cleanup")
    UI._watermark = nil -- Reset reference

    local Screen = Util:Create("ScreenGui", {
        Parent = TargetContainer,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 999
    })
    watermarkJanitor:Add(Screen, "Destroy")

    local Stroke = Util:Create("UIStroke", {Color = self.Themes.Default.Outline, Thickness = 1})
    local AccentBar = Util:Create("Frame", {
        Size = UDim2.new(0, 1, 1, -8),
        BackgroundColor3 = self.Themes.Default.Accent,
        BorderSizePixel = 0
    }, {
        Util:Create("UICorner", {CornerRadius = UDim.new(0, 1)})
    })

    local Main = Util:Create("CanvasGroup", {
        Parent = Screen,
        Size = UDim2.new(0, 0, 0, 20),
        Position = UDim2.new(0, 20, 0, 20),
        BackgroundColor3 = self.Themes.Default.WindowBackground,
        GroupTransparency = transparency or 0.3,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.X
    }, {
        Util:Create("UICorner", {CornerRadius = UDim.new(0, 2)}),
        Stroke,
        AccentBar,
        Util:Create("UIPadding", {
            PaddingLeft = UDim.new(0, 6),
            PaddingRight = UDim.new(0, 6)
        }),
        Util:Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 6)
        })
    })

    local function CreateLabel(text: string, color: Color3)
        return Util:Create("TextLabel", {
            Parent = Main,
            Text = text,
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundTransparency = 1,
            TextColor3 = color,
            Font = self.Themes.Default.FontBold,
        })
    end

    local TitleLabel = CreateLabel(title:upper() .. " |", self.Themes.Default.Accent)
    local UserLabel = CreateLabel(game.Players.LocalPlayer.Name:lower(), self.Themes.Default.Text)
    local StatsLabel = CreateLabel("", self.Themes.Default.TextDark)

    local Dragging, DragStart, StartPos
    watermarkJanitor:Add(Main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Dragging, DragStart, StartPos = true, input.Position, Main.Position
        end
    end))

    watermarkJanitor:Add(UserInputService.InputChanged:Connect(function(input)
        if Dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - DragStart
            Main.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + delta.X, StartPos.Y.Scale, StartPos.Y.Offset + delta.Y)
        end
    end))

    watermarkJanitor:Add(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then Dragging = false end
    end))

    local lastUpdate = 0
    watermarkJanitor:Add(RunService.Heartbeat:Connect(function()
        if tick() - lastUpdate >= 0.5 then
            lastUpdate = tick()
            local fps = math.floor(1 / RunService.RenderStepped:Wait())
            local ping = math.floor(game.Players.LocalPlayer:GetNetworkPing() * 1000)
            local time = os.date("%X")
            local mem = math.floor(game:GetService("Stats"):GetTotalMemoryUsageMb())
            StatsLabel.Text = string.format("| %d FPS | %d MS | %s | %d MB", fps, ping, time, mem)
        end
    end))

    local api = {
        SetTitle = function(new: string) TitleLabel.Text = new:upper() .. " |" end,
        SetVisible = function(val: boolean) Screen.Enabled = val end,
        SetTransparency = function(val: number)
            Main.GroupTransparency = val
        end,
        Destroy = function() watermarkJanitor:Cleanup() end
    }
    UI._watermark = api
    return api
end

function UI:CreateKeybindList(transparency: number?)
    local listJanitor = Janitor.new()
    self._janitor:Add(listJanitor, "Cleanup")
    UI._keybindList = nil -- Reset reference

    local Screen = Util:Create("ScreenGui", { Parent = TargetContainer, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 998 })
    listJanitor:Add(Screen, "Destroy")

    local Main = Util:Create("CanvasGroup", {
        Parent = Screen, 
        Size = UDim2.new(0, 180, 0, 0), Position = UDim2.new(0, 20, 0.5, -100), BackgroundColor3 = self.Themes.Default.WindowBackground, GroupTransparency = transparency or 0.3,
        BorderSizePixel = 0, 
        AutomaticSize = Enum.AutomaticSize.Y
    }, {
        Util:Create("UICorner", {CornerRadius = UDim.new(0, 4)}),
        Util:Create("UIStroke", {Color = self.Themes.Default.Outline, Thickness = 1}),
        Util:Create("TextLabel", { Text = "KEYBINDS", Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, TextColor3 = self.Themes.Default.Accent, Font = self.Themes.Default.FontBold, TextSize = 12,
            LayoutOrder = 1 -- Force top
        }),
        Util:Create("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
        Util:Create("UIPadding", { PaddingBottom = UDim.new(0, 6) })
    })

    local Container = Util:Create("Frame", { Parent = Main, Size = UDim2.new(1, -20, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2 }, {
        Util:Create("UIListLayout", { Padding = UDim.new(0, 4) })
    })

        local activeLabels = {}
    local function GetBindName(k) return k.Name:gsub("MouseButton", "MB"):gsub("Keyboard", "") end

    self:AddRenderHandler("KeybindListUpdate", Main, function()
        for flag, label in pairs(activeLabels) do
            if not self._binds[flag] then
                label:Destroy()
                activeLabels[flag] = nil
            end
        end

        for flag, data in pairs(self._binds) do
            if data.Key == Enum.KeyCode.Unknown or data.Key == Enum.UserInputType.None then 
                if activeLabels[flag] then activeLabels[flag].Visible = false end
                continue 
            end

            local label = activeLabels[flag]
            if not label then
                label = Util:Create("TextLabel", {
                    Parent = Container, Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
                    Font = self.Themes.Default.Font, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left
                })
                activeLabels[flag] = label
            end

            local state = self._flags[data.Flag]
            label.Visible = true
            label.Text = string.format("%s [%s]", data.Name, GetBindName(data.Key))
            label.TextColor3 = state and self.Themes.Default.Accent or self.Themes.Default.TextDark
        end
    end)

    local Dragging, DragStart, StartPos
    listJanitor:Add(Main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then Dragging, DragStart, StartPos = true, input.Position, Main.Position end
    end))
    listJanitor:Add(UserInputService.InputChanged:Connect(function(input)
        if Dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - DragStart
            Main.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + delta.X, StartPos.Y.Scale, StartPos.Y.Offset + delta.Y)
        end
    end))
    listJanitor:Add(UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then Dragging = false end end))

    local api = { 
        SetVisible = function(val) Screen.Enabled = val end, 
        SetTransparency = function(val) Main.GroupTransparency = val end,
        Destroy = function() listJanitor:Cleanup() end 
    }
    UI._keybindList = api
    return api
end

-- [[ CONFIG SYSTEM ]]
function UI:SaveConfig(name: string)
    local success, str = pcall(HttpService.JSONEncode, HttpService, self._flatFlags)
    if success and writefile then
        writefile(name .. ".json", str)
    end
end

function UI:LoadConfig(name: string)
    if not isfile or not isfile(name .. ".json") then return end
    local str = readfile(name .. ".json")
    local success, data = pcall(HttpService.JSONDecode, HttpService, str)
    
    if success then
        for flag, value in pairs(data) do
            if flag:sub(1, 5) == "BIND_" then
                local realFlag = flag:sub(6)
                if self._binds[realFlag] then 
                    self._binds[realFlag].Key = Enum.KeyCode[value] or Enum.UserInputType[value]
                    self:_setBind(realFlag, self._binds[realFlag].Key)
                end
            else
                if self._updaters[flag] then
                    self._updaters[flag](value)
                end
            end
        end
        self:UpdateBindMap()
    end
end
-- Memory Leak Prevention: Global cleanup
function UI:Unload()
    self._active = false
    for _, win in ipairs(self._windows) do
        win:Destroy()
    end
    self._janitor:Cleanup()
    
    UI._watermark = nil
    UI._keybindList = nil

    table.clear(UI._flags); table.clear(UI._flatFlags); table.clear(UI._objects); table.clear(UI._updaters); table.clear(UI._windows); table.clear(_sharedRenderSteppedHandlers); table.clear(_handlerLookup)
    table.clear(UI._binds); table.clear(UI._bindMap)

    for _, tween in pairs(_activeTweens) do
        pcall(function()
            tween:Cancel()
        end)
    end
    table.clear(_activeTweens)
end

-- [[ SINGLETON INITIALIZATION ]]
UI._bindMap = {}

function UI:UpdateBindMap()
    table.clear(self._bindMap)
    for flag, data in pairs(self._binds) do
        local k = data.Key
        if k ~= Enum.KeyCode.Unknown and k ~= Enum.UserInputType.None then
            self._bindMap[k] = self._bindMap[k] or {}
            table.insert(self._bindMap[k], data)
        end
    end
end

function UI:HandleBinding(input: InputObject, isBegan: boolean)
    if self._isBinding or not self._active then return end
    local k = input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode or input.UserInputType
    local binds = self._bindMap[k]
    
    if binds then
        for _, bind in ipairs(binds) do
            if bind.Mode == "Toggle" then
                if isBegan then Util:SafeCall(bind.Callback, k) end
            else
                Util:SafeCall(bind.Callback, isBegan)
            end
        end
    end
end

-- Single shared RenderStepped connection for all continuous UI updates
local _sharedRenderSteppedConnection = UI:_track(RunService.RenderStepped:Connect(function()
    if UI._drag.active then
        local drag = UI._drag
        if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
            drag.active = false
        else
            local mPos = UserInputService:GetMouseLocation()
            local gInset = GuiService:GetGuiInset()
            if drag.type == "Slider" then
                local bPos, bWidth = drag.instance.AbsolutePosition.X, drag.instance.AbsoluteSize.X
                local val = math.floor(drag.min + (drag.max - drag.min) * math.clamp((mPos.X - bPos) / bWidth, 0, 1))
                drag.update(val); Util:SafeCall(drag.callback, val)
            elseif drag.type == "SVMap" then
                local rel = mPos - drag.instance.AbsolutePosition - gInset
                drag.state.s = math.clamp(rel.X / drag.instance.AbsoluteSize.X, 0, 1)
                drag.state.v = 1 - math.clamp(rel.Y / drag.instance.AbsoluteSize.Y, 0, 1)
                drag.pin.Position = UDim2.new(drag.state.s, -2, 1 - drag.state.v, -2)
                drag.update()
            elseif drag.type == "Hue" then
                local relY = math.clamp((mPos.Y - drag.instance.AbsolutePosition.Y - gInset.Y) / drag.instance.AbsoluteSize.Y, 0, 1)
                drag.state.h = relY
                drag.pin.Position = UDim2.new(0, -2, relY, 0)
                drag.update()
            elseif drag.type == "Alpha" then
                local a = math.clamp((mPos.X - drag.instance.AbsolutePosition.X) / drag.instance.AbsoluteSize.X, 0, 1)
                UI._flags[drag.flag .. "_Alpha"] = a
                drag.pin.Position = UDim2.new(a, -1, 0, -1)
                drag.update()
            elseif drag.type == "Speed" then
                local s = math.clamp((mPos.X - drag.instance.AbsolutePosition.X) / drag.instance.AbsoluteSize.X, 0, 1)
                UI._flags[drag.flag .. "_RainbowSpeed"] = s; drag.fill.Size = UDim2.new(s, 0, 1, 0)
                if drag.input then drag.input.Text = tostring(math.floor(s * 100)) end
            end
        end
    end
    for i = #_sharedRenderSteppedHandlers, 1, -1 do
        local h = _sharedRenderSteppedHandlers[i]

        if h.instance and not h.instance.Parent then
            h.dead = true
        end

        if h.dead then
            _handlerLookup[h.key] = nil
            table.remove(_sharedRenderSteppedHandlers, i)
            continue
        end

        local ok, err = pcall(h.fn)
        if not ok then
            warn("[FZUI_HANDLER_CRASH]:", h.key, err)
            _handlerLookup[h.key] = nil
            table.remove(_sharedRenderSteppedHandlers, i)
        end
    end
end))

UI:_track(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    UI:HandleBinding(input, true)
end))

UI:_track(UserInputService.InputEnded:Connect(function(input, gpe)
    if gpe then return end
    UI:HandleBinding(input, false)
end))

return UI
