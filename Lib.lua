local Library = {}
Library.__index = Library

local DrawingObjects = {}
local Services = {
    Mouse = game:GetService("MouseService"),
    Run = game:GetService("RunService"),
    Players = game:GetService("Players")
}

local Player = Services.Players.LocalPlayer

-- X11-inspired configuration
local CONFIG = {
    TOGGLE_KEY = "P",
    TOGGLE_COOLDOWN = 0.25,
    
    GUI = {
        X = 20, Y = 60,
        WIDTH = 300, HEIGHT = 400,
        TAB_HEIGHT = 20,
        TITLE_HEIGHT = 25
    },
    
    COLORS = {
        SURFACE = Color3.fromRGB(38, 38, 38),
        BORDER = Color3.fromRGB(25, 25, 25),
        CRUST = Color3.fromRGB(0, 0, 0),
        OVERLAY = Color3.fromRGB(76, 76, 76),
        ACCENT = Color3.fromRGB(255, 127, 0),
        TEXT = Color3.fromRGB(255, 255, 255),
        SHADOW = Color3.fromRGB(0, 0, 0)
    },
    
    OPACITY = {
        BASE = 1.0,
        SHADOW = 0.3
    },
    
    LAYOUT = {
        PADDING = 6,
        SECTION_SPACING = 8,
        ITEM_HEIGHT = 14,
        ITEM_SPACING = 8,
        SLIDER_HEIGHT = 20,
        CHOICE_HEIGHT = 20
    },
    
    TEXT_SIZE = 13,
    
    ZINDEX = {
        BASE = 100,
        PANEL = 100,
        SECTION = 200,
        COMPONENT = 300,
        DROPDOWN = 500
    }
}

local Panel = {x = CONFIG.GUI.X, y = CONFIG.GUI.Y}
local GUI_Visible = false
local GUI_Initialized = false
local ActiveDropdown = nil

local function CreateDrawing(type, properties)
    local obj = Drawing.new(type)
    for k, v in pairs(properties or {}) do
        obj[k] = v
    end
    obj.Visible = false
    table.insert(DrawingObjects, obj)
    return obj
end

local function PointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and py >= ry and px <= rx + rw and py <= ry + rh
end

local function Clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function Lerp(a, b, t)
    return a + (b - a) * t
end

local function GetTextBounds(str)
    return #str * CONFIG.TEXT_SIZE, CONFIG.TEXT_SIZE
end

local Toggle = {}
Toggle.__index = Toggle

function Toggle.new(option, accentColor)
    local self = setmetatable({}, Toggle)
    self.option = option
    self.accentColor = accentColor or CONFIG.COLORS.ACCENT
    
    self.outline = CreateDrawing("Square", {
        Filled = false,
        Thickness = 1,
        Color = CONFIG.COLORS.CRUST,
        ZIndex = CONFIG.ZINDEX.COMPONENT
    })
    
    self.check = CreateDrawing("Square", {
        Filled = true,
        Color = self.accentColor,
        ZIndex = CONFIG.ZINDEX.COMPONENT + 1
    })
    
    self.checkShadow = CreateDrawing("Square", {
        Filled = true,
        Color = CONFIG.COLORS.SHADOW,
        ZIndex = CONFIG.ZINDEX.COMPONENT
    })
    
    self.label = CreateDrawing("Text", {
        Text = option.Name,
        Size = CONFIG.TEXT_SIZE,
        Center = false,
        Outline = true,
        Color = CONFIG.COLORS.TEXT,
        ZIndex = CONFIG.ZINDEX.COMPONENT
    })
    
    return self
end

function Toggle:Update(x, y)
    local boxSize = Vector2.new(CONFIG.LAYOUT.ITEM_HEIGHT, CONFIG.LAYOUT.ITEM_HEIGHT)
    
    self.outline.Position = Vector2.new(x, y)
    self.outline.Size = boxSize
    
    self.check.Position = Vector2.new(x + 1, y + 1)
    self.check.Size = Vector2.new(boxSize.X - 2, boxSize.Y - 2)
    self.check.Visible = self.option.Value and GUI_Visible and GUI_Initialized
    
    self.checkShadow.Position = Vector2.new(x + 1, y + boxSize.Y - 2)
    self.checkShadow.Size = Vector2.new(boxSize.X - 2, 1)
    self.checkShadow.Transparency = CONFIG.OPACITY.SHADOW
    self.checkShadow.Visible = self.option.Value and GUI_Visible and GUI_Initialized
    
    self.label.Position = Vector2.new(x + boxSize.X + 8, y)
end

function Toggle:HandleClick(mx, my)
    if not self.outline.Visible then return false end
    local pos = self.outline.Position
    local size = self.outline.Size
    if PointInRect(mx, my, pos.X, pos.Y, size.X, size.Y) then
        self.option.Value = not self.option.Value
        if self.option.Callback then
            self.option.Callback(self.option.Value)
        end
        return true
    end
    return false
end

function Toggle:SetVisible(visible)
    self.outline.Visible = visible and GUI_Visible and GUI_Initialized
    self.check.Visible = visible and self.option.Value and GUI_Visible and GUI_Initialized
    self.checkShadow.Visible = visible and self.option.Value and GUI_Visible and GUI_Initialized
    self.label.Visible = visible and GUI_Visible and GUI_Initialized
end

local Slider = {}
Slider.__index = Slider

function Slider.new(option, accentColor)
    local self = setmetatable({}, Slider)
    self.option = option
    self.dragging = false
    self.accentColor = accentColor or CONFIG.COLORS.ACCENT
    
    self.outline = CreateDrawing("Square", {
        Filled = true,
        Color = CONFIG.COLORS.CRUST,
        ZIndex = CONFIG.ZINDEX.COMPONENT
    })
    
    self.fill = CreateDrawing("Square", {
        Filled = true,
        Color = self.accentColor,
        ZIndex = CONFIG.ZINDEX.COMPONENT + 1
    })
    
    self.fillShadow = CreateDrawing("Square", {
        Filled = true,
        Color = CONFIG.COLORS.SHADOW,
        ZIndex = CONFIG.ZINDEX.COMPONENT
    })
    
    self.label = CreateDrawing("Text", {
        Text = option.Name,
        Size = CONFIG.TEXT_SIZE,
        Center = false,
        Outline = true,
        Color = CONFIG.COLORS.TEXT,
        ZIndex = CONFIG.ZINDEX.COMPONENT
    })
    
    self.valueText = CreateDrawing("Text", {
        Text = tostring(option.Value),
        Size = CONFIG.TEXT_SIZE,
        Center = false,
        Outline = true,
        Color = CONFIG.COLORS.TEXT,
        ZIndex = CONFIG.ZINDEX.COMPONENT
    })
    
    return self
end

function Slider:Update(x, y, width)
    local labelW, labelH = GetTextBounds(self.option.Name)
    self.label.Position = Vector2.new(x, y)
    
    local sliderY = y + labelH + 10
    local sliderH = CONFIG.LAYOUT.SLIDER_HEIGHT
    
    self.outline.Position = Vector2.new(x, sliderY)
    self.outline.Size = Vector2.new(width, sliderH)
    
    local percent = (self.option.Value - self.option.Min) / (self.option.Max - self.option.Min)
    local fillWidth = math.max((width - 2) * percent, 0)
    
    self.fill.Position = Vector2.new(x + 1, sliderY + 1)
    self.fill.Size = Vector2.new(fillWidth, sliderH - 2)
    self.fill.Visible = self.option.Value ~= self.option.Min and GUI_Visible and GUI_Initialized
    
    self.fillShadow.Position = Vector2.new(x + 1, sliderY + sliderH - 3)
    self.fillShadow.Size = Vector2.new(fillWidth, 2)
    self.fillShadow.Transparency = 0.15
    self.fillShadow.Visible = self.option.Value ~= self.option.Min and GUI_Visible and GUI_Initialized
    
    local displayValue = tostring(math.floor(self.option.Value))
    local valueW = GetTextBounds(displayValue)
    self.valueText.Text = displayValue
    self.valueText.Position = Vector2.new(x + width - valueW - 6, sliderY + 4)
end

function Slider:HandleDrag(mx, my)
    if self.dragging then
        local pos = self.outline.Position
        local size = self.outline.Size
        local percent = Clamp((mx - pos.X) / size.X, 0, 1)
        self.option.Value = Lerp(self.option.Min, self.option.Max, percent)
        if self.option.Callback then
            self.option.Callback(self.option.Value)
        end
        return true
    end
    return false
end

function Slider:StartDrag(mx, my)
    if not self.outline.Visible then return false end
    local pos = self.outline.Position
    local size = self.outline.Size
    if PointInRect(mx, my, pos.X, pos.Y, size.X, size.Y) then
        self.dragging = true
        return true
    end
    return false
end

function Slider:StopDrag()
    self.dragging = false
end

function Slider:SetVisible(visible)
    self.outline.Visible = visible and GUI_Visible and GUI_Initialized
    self.fill.Visible = visible and self.option.Value ~= self.option.Min and GUI_Visible and GUI_Initialized
    self.fillShadow.Visible = visible and self.option.Value ~= self.option.Min and GUI_Visible and GUI_Initialized
    self.label.Visible = visible and GUI_Visible and GUI_Initialized
    self.valueText.Visible = visible and GUI_Visible and GUI_Initialized
end

local MultiSelect = {}
MultiSelect.__index = MultiSelect

function MultiSelect.new(option, accentColor)
    local self = setmetatable({}, MultiSelect)
    self.option = option
    self.accentColor = accentColor or CONFIG.COLORS.ACCENT
    self.isOpen = false
    self.dropdownElements = {}
    
    self.label = CreateDrawing("Text", {
        Text = option.Name,
        Size = CONFIG.TEXT_SIZE,
        Center = false,
        Outline = true,
        Color = CONFIG.COLORS.TEXT,
        ZIndex = CONFIG.ZINDEX.COMPONENT
    })
    
    self.outline = CreateDrawing("Square", {
        Filled = false,
        Thickness = 1,
        Color = CONFIG.COLORS.CRUST,
        ZIndex = CONFIG.ZINDEX.COMPONENT
    })
    
    self.fill = CreateDrawing("Square", {
        Filled = true,
        Color = CONFIG.COLORS.CRUST,
        ZIndex = CONFIG.ZINDEX.COMPONENT
    })
    
    self.valueText = CreateDrawing("Text", {
        Text = "...",
        Size = CONFIG.TEXT_SIZE,
        Center = false,
        Outline = true,
        Color = CONFIG.COLORS.TEXT,
        ZIndex = CONFIG.ZINDEX.COMPONENT + 1
    })
    
    self.expandText = CreateDrawing("Text", {
        Text = "<",
        Size = CONFIG.TEXT_SIZE,
        Center = false,
        Outline = true,
        Color = CONFIG.COLORS.TEXT,
        ZIndex = CONFIG.ZINDEX.COMPONENT + 1
    })
    
    -- Dropdown background
    self.dropdownBase = CreateDrawing("Square", {
        Filled = true,
        Color = CONFIG.COLORS.SURFACE,
        ZIndex = CONFIG.ZINDEX.DROPDOWN
    })
    
    self.dropdownCrust = CreateDrawing("Square", {
        Filled = false,
        Thickness = 1,
        Color = CONFIG.COLORS.CRUST,
        ZIndex = CONFIG.ZINDEX.DROPDOWN
    })
    
    self.dropdownBorder = CreateDrawing("Square", {
        Filled = false,
        Thickness = 1,
        Color = CONFIG.COLORS.BORDER,
        ZIndex = CONFIG.ZINDEX.DROPDOWN
    })
    
    for _, itemName in ipairs(option.Options) do
        local itemText = CreateDrawing("Text", {
            Text = itemName,
            Size = CONFIG.TEXT_SIZE,
            Center = false,
            Outline = true,
            Color = CONFIG.COLORS.TEXT,
            ZIndex = CONFIG.ZINDEX.DROPDOWN + 1
        })
        
        table.insert(self.dropdownElements, {
            name = itemName,
            text = itemText,
            selected = false
        })
    end
    
    return self
end

function MultiSelect:Update(x, y, width)
    local labelW, labelH = GetTextBounds(self.option.Name)
    self.label.Position = Vector2.new(x, y)
    
    local boxY = y + labelH + 10
    local boxH = CONFIG.LAYOUT.CHOICE_HEIGHT
    
    self.outline.Position = Vector2.new(x, boxY)
    self.outline.Size = Vector2.new(width, boxH)
    
    self.fill.Position = Vector2.new(x + 2, boxY + 2)
    self.fill.Size = Vector2.new(width - 4, boxH - 4)
    
    local selectedCount = 0
    for _, elem in ipairs(self.dropdownElements) do
        if elem.selected then selectedCount = selectedCount + 1 end
    end
    
    local valueStr = selectedCount > 0 and table.concat(self:GetSelectedNames(), ", ") or "..."
    local valueW = GetTextBounds(valueStr)
    if valueW > width - 32 then
        valueStr = "..."
    end
    self.valueText.Text = valueStr
    self.valueText.Position = Vector2.new(x + 4, boxY + 4)
    
    local expandW = GetTextBounds("<")
    self.expandText.Position = Vector2.new(x + width - expandW - 4, boxY + 4)
    
    if self.isOpen then
        local dropdownY = boxY + boxH
        local itemCount = #self.dropdownElements
        local dropdownH = itemCount * (CONFIG.TEXT_SIZE * 2 + CONFIG.LAYOUT.PADDING) + CONFIG.LAYOUT.PADDING
        
        self.dropdownBase.Position = Vector2.new(x, dropdownY)
        self.dropdownBase.Size = Vector2.new(width, dropdownH)
        self.dropdownBase.Visible = GUI_Visible and GUI_Initialized
        
        self.dropdownCrust.Position = Vector2.new(x, dropdownY)
        self.dropdownCrust.Size = Vector2.new(width, dropdownH)
        self.dropdownCrust.Visible = GUI_Visible and GUI_Initialized
        
        self.dropdownBorder.Position = Vector2.new(x + 1, dropdownY + 1)
        self.dropdownBorder.Size = Vector2.new(width - 2, dropdownH - 2)
        self.dropdownBorder.Visible = GUI_Visible and GUI_Initialized
        
        for i, elem in ipairs(self.dropdownElements) do
            local itemY = dropdownY + CONFIG.LAYOUT.PADDING + (i - 1) * (CONFIG.TEXT_SIZE * 2 + CONFIG.LAYOUT.PADDING)
            elem.text.Position = Vector2.new(x + CONFIG.LAYOUT.PADDING, itemY)
            elem.text.Color = elem.selected and self.accentColor or CONFIG.COLORS.TEXT
            elem.text.Visible = GUI_Visible and GUI_Initialized
        end
    else
        self.dropdownBase.Visible = false
        self.dropdownCrust.Visible = false
        self.dropdownBorder.Visible = false
        for _, elem in ipairs(self.dropdownElements) do
            elem.text.Visible = false
        end
    end
end

function MultiSelect:GetSelectedNames()
    local selected = {}
    for _, elem in ipairs(self.dropdownElements) do
        if elem.selected then
            table.insert(selected, elem.name)
        end
    end
    return selected
end

function MultiSelect:HandleClick(mx, my)
    if not self.outline.Visible then return false end
    
    local pos = self.outline.Position
    local size = self.outline.Size
    
    if PointInRect(mx, my, pos.X, pos.Y, size.X, size.Y) then
        self.isOpen = not self.isOpen
        if self.isOpen and ActiveDropdown and ActiveDropdown ~= self then
            ActiveDropdown.isOpen = false
        end
        ActiveDropdown = self.isOpen and self or nil
        return true
    end
    
    if self.isOpen then
        local dropdownPos = self.dropdownBase.Position
        local dropdownSize = self.dropdownBase.Size
        
        if PointInRect(mx, my, dropdownPos.X, dropdownPos.Y, dropdownSize.X, dropdownSize.Y) then
            for i, elem in ipairs(self.dropdownElements) do
                local itemY = dropdownPos.Y + CONFIG.LAYOUT.PADDING + (i - 1) * (CONFIG.TEXT_SIZE * 2 + CONFIG.LAYOUT.PADDING)
                local itemH = CONFIG.TEXT_SIZE * 2 + CONFIG.LAYOUT.PADDING
                if PointInRect(mx, my, dropdownPos.X, itemY, dropdownSize.X, itemH) then
                    elem.selected = not elem.selected
                    
                    if self.option.Callback then
                        self.option.Callback(self:GetSelectedNames())
                    end
                    return true
                end
            end
        else
            self.isOpen = false
            ActiveDropdown = nil
        end
    end
    
    return false
end

function MultiSelect:SetVisible(visible)
    self.label.Visible = visible and GUI_Visible and GUI_Initialized
    self.outline.Visible = visible and GUI_Visible and GUI_Initialized
    self.fill.Visible = visible and GUI_Visible and GUI_Initialized
    self.valueText.Visible = visible and GUI_Visible and GUI_Initialized
    self.expandText.Visible = visible and GUI_Visible and GUI_Initialized
    if not visible then
        self.dropdownBase.Visible = false
        self.dropdownCrust.Visible = false
        self.dropdownBorder.Visible = false
        for _, elem in ipairs(self.dropdownElements) do
            elem.text.Visible = false
        end
    end
end

local Section = {}
Section.__index = Section

function Section.new(data, accentColor)
    local self = setmetatable({}, Section)
    self.data = data
    self.accentColor = accentColor
    
    self.base = CreateDrawing("Square", {
        Filled = true,
        Color = CONFIG.COLORS.SURFACE,
        ZIndex = CONFIG.ZINDEX.SECTION
    })
    
    self.crust = CreateDrawing("Square", {
        Filled = false,
        Thickness = 1,
        Color = CONFIG.COLORS.CRUST,
        ZIndex = CONFIG.ZINDEX.SECTION
    })
    
    self.border = CreateDrawing("Square", {
        Filled = false,
        Thickness = 1,
        Color = CONFIG.COLORS.OVERLAY,
        ZIndex = CONFIG.ZINDEX.SECTION
    })
    
    self.title = CreateDrawing("Text", {
        Text = data.Name,
        Size = CONFIG.TEXT_SIZE,
        Center = false,
        Outline = true,
        Color = CONFIG.COLORS.TEXT,
        ZIndex = CONFIG.ZINDEX.SECTION + 1
    })
    
    self.components = {}
    
    return self
end

function Section:Toggle(options)
    local option = {
        Name = options.Name or "Toggle",
        Value = options.Default or false,
        Callback = options.Callback
    }
    
    local toggle = Toggle.new(option, self.accentColor)
    table.insert(self.components, toggle)
    
    return {
        SetValue = function(value)
            option.Value = value
            if option.Callback then
                option.Callback(value)
            end
        end,
        GetValue = function()
            return option.Value
        end
    }
end

function Section:Slider(options)
    local option = {
        Name = options.Name or "Slider",
        Min = options.Min or 0,
        Max = options.Max or 100,
        Value = options.Default or 50,
        Callback = options.Callback
    }
    
    local slider = Slider.new(option, self.accentColor)
    table.insert(self.components, slider)
    
    return {
        SetValue = function(value)
            option.Value = Clamp(value, option.Min, option.Max)
            if option.Callback then
                option.Callback(option.Value)
            end
        end,
        GetValue = function()
            return option.Value
        end
    }
end

function Section:MultiSelect(options)
    local option = {
        Name = options.Name or "Multi Select",
        Options = options.Options or {},
        Callback = options.Callback
    }
    
    local multiselect = MultiSelect.new(option, self.accentColor)
    table.insert(self.components, multiselect)
    
    return {
        GetSelected = function()
            return multiselect:GetSelectedNames()
        end
    }
end

function Section:CalculateHeight(width)
    local height = CONFIG.LAYOUT.PADDING * 2 + CONFIG.TEXT_SIZE
    for _, component in ipairs(self.components) do
        if component.option.Name then
            local _, labelH = GetTextBounds(component.option.Name)
            height = height + labelH + 10
        end
        if component.outline then
            height = height + component.outline.Size.Y
        end
        height = height + CONFIG.LAYOUT.ITEM_SPACING
    end
    return height
end

function Section:UpdateSection(x, y, width)
    local itemY = y + CONFIG.LAYOUT.PADDING + CONFIG.TEXT_SIZE + 5
    local contentWidth = width - CONFIG.LAYOUT.PADDING * 2
    
    for _, component in ipairs(self.components) do
        component:Update(x + CONFIG.LAYOUT.PADDING, itemY, contentWidth)
        
        if component.option.Name then
            local _, labelH = GetTextBounds(component.option.Name)
            itemY = itemY + labelH + 10
        end
        if component.outline then
            itemY = itemY + component.outline.Size.Y
        end
        itemY = itemY + CONFIG.LAYOUT.ITEM_SPACING
    end
    
    local height = self:CalculateHeight(width)
    
    self.base.Position = Vector2.new(x, y)
    self.base.Size = Vector2.new(width, height)
    
    self.crust.Position = Vector2.new(x, y)
    self.crust.Size = Vector2.new(width, height)
    
    self.border.Position = Vector2.new(x + 1, y + 1)
    self.border.Size = Vector2.new(width - 2, height - 2)
    
    local titleW, titleH = GetTextBounds(self.data.Name)
    self.title.Position = Vector2.new(x + 10, y - titleH / 2)
    
    return height
end

function Section:SetVisible(visible)
    self.base.Visible = visible and GUI_Visible and GUI_Initialized
    self.crust.Visible = visible and GUI_Visible and GUI_Initialized
    self.border.Visible = visible and GUI_Visible and GUI_Initialized
    self.title.Visible = visible and GUI_Visible and GUI_Initialized
    
    for _, component in ipairs(self.components) do
        component:SetVisible(visible)
    end
end

local Tab = {}
Tab.__index = Tab

function Tab.new(name, accentColor)
    local self = setmetatable({}, Tab)
    self.name = name
    self.accentColor = accentColor
    self.sections = {}
    self.isActive = false
    
    return self
end

function Tab:Section(options)
    local section = Section.new(options, self.accentColor)
    table.insert(self.sections, section)
    return section
end

function Library:Create(options)
    local self = setmetatable({}, Library)
    
    self.Name = options.Name or "UI Library"
    self.AccentColor = options.AccentColor or CONFIG.COLORS.ACCENT
    self.ToggleKey = options.ToggleKey or CONFIG.TOGGLE_KEY
    
    CONFIG.COLORS.ACCENT = self.AccentColor
    CONFIG.TOGGLE_KEY = self.ToggleKey
    
    self.tabs = {}
    self.tabButtons = {}
    self.activeTab = nil
    
    -- Main UI elements
    self.base = CreateDrawing("Square", {
        Filled = true,
        Color = CONFIG.COLORS.SURFACE,
        ZIndex = CONFIG.ZINDEX.BASE
    })
    
    self.crust = CreateDrawing("Square", {
        Filled = false,
        Thickness = 1,
        Color = CONFIG.COLORS.CRUST,
        ZIndex = CONFIG.ZINDEX.BASE
    })
    
    self.border = CreateDrawing("Square", {
        Filled = false,
        Thickness = 1,
        Color = CONFIG.COLORS.BORDER,
        ZIndex = CONFIG.ZINDEX.BASE
    })
    
    self.navbar = CreateDrawing("Square", {
        Filled = true,
        Color = CONFIG.COLORS.BORDER,
        ZIndex = CONFIG.ZINDEX.BASE + 1
    })
    
    self.title = CreateDrawing("Text", {
        Text = self.Name,
        Size = CONFIG.TEXT_SIZE,
        Center = false,
        Outline = true,
        Color = CONFIG.COLORS.TEXT,
        ZIndex = CONFIG.ZINDEX.BASE + 2
    })
    
    self.dragging = false
    self.dragOffset = {x = 0, y = 0}
    self.wasLeftPressed = false
    self.lastToggle = 0
    
    self:StartLoop()
    
    return self
end

function Library:Tab(options)
    local tab = Tab.new(options.Name or "Tab", self.AccentColor)
    
    local tabButton = {
        name = tab.name,
        tab = tab,
        backdrop = CreateDrawing("Square", {
            Filled = true,
            Color = CONFIG.COLORS.BORDER,
            ZIndex = CONFIG.ZINDEX.PANEL + 1
        }),
        shadow = CreateDrawing("Square", {
            Filled = true,
            Color = CONFIG.COLORS.SHADOW,
            ZIndex = CONFIG.ZINDEX.PANEL
        }),
        cursor = CreateDrawing("Square", {
            Filled = true,
            Color = self.AccentColor,
            ZIndex = CONFIG.ZINDEX.PANEL + 2
        }),
        text = CreateDrawing("Text", {
            Text = tab.name,
            Size = CONFIG.TEXT_SIZE,
            Center = false,
            Outline = true,
            Color = CONFIG.COLORS.TEXT,
            ZIndex = CONFIG.ZINDEX.PANEL + 2
        })
    }
    
    table.insert(self.tabButtons, tabButton)
    table.insert(self.tabs, tab)
    
    if not self.activeTab then
        self:SwitchTab(tab)
    end
    
    return tab
end

function Library:SwitchTab(targetTab)
    for _, tab in ipairs(self.tabs) do
        tab.isActive = false
    end
    targetTab.isActive = true
    self.activeTab = targetTab
end

function Library:UpdateUI()
    self.base.Position = Vector2.new(Panel.x, Panel.y)
    self.base.Size = Vector2.new(CONFIG.GUI.WIDTH, CONFIG.GUI.HEIGHT)
    self.base.Visible = GUI_Visible and GUI_Initialized
    
    self.crust.Position = Vector2.new(Panel.x, Panel.y)
    self.crust.Size = Vector2.new(CONFIG.GUI.WIDTH, CONFIG.GUI.HEIGHT)
    self.crust.Visible = GUI_Visible and GUI_Initialized
    
    self.border.Position = Vector2.new(Panel.x + 1, Panel.y + 1)
    self.border.Size = Vector2.new(CONFIG.GUI.WIDTH - 2, CONFIG.GUI.HEIGHT - 2)
    self.border.Visible = GUI_Visible and GUI_Initialized
    
    self.navbar.Position = Vector2.new(Panel.x + 2, Panel.y + 2)
    self.navbar.Size = Vector2.new(CONFIG.GUI.WIDTH - 4, CONFIG.GUI.TITLE_HEIGHT - 4)
    self.navbar.Visible = GUI_Visible and GUI_Initialized
    
    self.title.Position = Vector2.new(Panel.x + 7, Panel.y + 6)
    self.title.Visible = GUI_Visible and GUI_Initialized
    
    -- Update tabs
    local numTabs = #self.tabButtons
    local tabWidth = (CONFIG.GUI.WIDTH - CONFIG.LAYOUT.PADDING * 2 - (numTabs - 1) * 2) / numTabs
    
    for i, tabButton in ipairs(self.tabButtons) do
        local tabX = Panel.x + CONFIG.LAYOUT.PADDING + (i - 1) * (tabWidth + 2)
        local tabY = Panel.y + CONFIG.GUI.TITLE_HEIGHT + CONFIG.LAYOUT.PADDING
        
        tabButton.backdrop.Position = Vector2.new(tabX, tabY)
        tabButton.backdrop.Size = Vector2.new(tabWidth, CONFIG.GUI.TAB_HEIGHT)
        tabButton.backdrop.Visible = GUI_Visible and GUI_Initialized
        
        tabButton.shadow.Position = Vector2.new(tabX, tabY + CONFIG.GUI.TAB_HEIGHT)
        local tabW = (CONFIG.GUI.WIDTH - CONFIG.LAYOUT.PADDING * 2 - (numTabs - 1) * 2) / numTabs
        
        tabButton.shadow.Position = Vector2.new(tabX, tabY + CONFIG.GUI.TAB_HEIGHT - 8)
        tabButton.shadow.Size = Vector2.new(tabWidth, 8)
        tabButton.shadow.Transparency = 0.05
        tabButton.shadow.Visible = GUI_Visible and GUI_Initialized
        
        tabButton.cursor.Position = Vector2.new(tabX, tabY)
        tabButton.cursor.Size = Vector2.new(tabWidth, 1)
        tabButton.cursor.Visible = tabButton.tab.isActive and GUI_Visible and GUI_Initialized
        tabButton.cursor.Color = self.AccentColor
        
        local textW, textH = GetTextBounds(tabButton.name)
        tabButton.text.Position = Vector2.new(tabX + 4, tabY + CONFIG.GUI.TAB_HEIGHT / 2 - textH / 2)
        tabButton.text.Visible = GUI_Visible and GUI_Initialized
        
        -- Handle tab click
        if clickFrame and PointInRect(mx, my, tabX, tabY, tabWidth, CONFIG.GUI.TAB_HEIGHT) then
            self:SwitchTab(tabButton.tab)
        end
    end
    
    -- Update sections for active tab
    if self.activeTab then
        local contentY = Panel.y + CONFIG.GUI.TITLE_HEIGHT + CONFIG.GUI.TAB_HEIGHT + CONFIG.LAYOUT.PADDING * 2
        local contentHeight = CONFIG.GUI.HEIGHT - CONFIG.GUI.TITLE_HEIGHT - CONFIG.GUI.TAB_HEIGHT - CONFIG.LAYOUT.PADDING * 3
        local sectionWidth = CONFIG.GUI.WIDTH - CONFIG.LAYOUT.PADDING * 2
        
        for _, section in ipairs(self.activeTab.sections) do
            if section.base.Visible then
                local sectionHeight = section:UpdateSection(Panel.x + CONFIG.LAYOUT.PADDING, contentY, sectionWidth)
                contentY = contentY + sectionHeight + CONFIG.LAYOUT.SECTION_SPACING
            end
        end
    end
end

function Library:HandleClick(mx, my)
    -- Handle tab clicks
    for _, tabButton in ipairs(self.tabButtons) do
        local pos = tabButton.backdrop.Position
        local size = tabButton.backdrop.Size
        if PointInRect(mx, my, pos.X, pos.Y, size.X, size.Y) then
            self:SwitchTab(tabButton.tab)
            return
        end
    end
    
    -- Handle component clicks
    if self.activeTab then
        for _, section in ipairs(self.activeTab.sections) do
            for _, component in ipairs(section.components) do
                if component.HandleClick and component:HandleClick(mx, my) then
                    return
                end
                if component.StartDrag and component:StartDrag(mx, my) then
                    return
                end
            end
        end
    end
    
    -- Handle dragging
    if PointInRect(mx, my, Panel.x, Panel.y, CONFIG.GUI.WIDTH, CONFIG.GUI.TITLE_HEIGHT) then
        self.dragging = true
        self.dragOffset.x = mx - Panel.x
        self.dragOffset.y = my - Panel.y
    end
end

function Library:HandleInput()
    if not GUI_Visible or not GUI_Initialized then
        self.dragging = false
        self.wasLeftPressed = false
        for _, tab in ipairs(self.tabs) do
            for _, section in ipairs(tab.sections) do
                for _, component in ipairs(section.components) do
                    if component.StopDrag then
                        component:StopDrag()
                    end
                end
            end
        end
        return
    end
    
    local mouse = Services.Mouse
    local mouseLocation = mouse:GetMouseLocation()
    local mx, my = mouseLocation.X, mouseLocation.Y
    local leftPressed = mouse:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    
    if leftPressed then
        if self.activeTab then
            for _, section in ipairs(self.activeTab.sections) do
                for _, component in ipairs(section.components) do
                    if component.HandleDrag then
                        component:HandleDrag(mx, my)
                    end
                end
            end
        end
        
        if not self.wasLeftPressed then
            self:HandleClick(mx, my)
        end
    else
        if self.wasLeftPressed then
            if self.activeTab then
                for _, section in ipairs(self.activeTab.sections) do
                    for _, component in ipairs(section.components) do
                        if component.StopDrag then
                            component:StopDrag()
                        end
                    end
                end
            end
        end
        self.dragging = false
    end
    
    if self.dragging then
        Panel.x = mx - self.dragOffset.x
        Panel.y = my - self.dragOffset.y
    end
    
    self.wasLeftPressed = leftPressed
end

function Library:HandleToggle()
    local inputService = Services.Mouse
    local keysPressed = inputService:GetKeysPressed()
    
    for _, key in ipairs(keysPressed) do
        if key.KeyCode.Name == CONFIG.TOGGLE_KEY then
            local now = tick()
            if now - self.lastToggle > CONFIG.TOGGLE_COOLDOWN then
                GUI_Visible = not GUI_Visible
                
                if not GUI_Initialized and GUI_Visible then
                    GUI_Initialized = true
                end
                
                if not GUI_Visible then
                    for _, obj in ipairs(DrawingObjects) do
                        obj.Visible = false
                    end
                end
                
                self.lastToggle = now
            end
            break
        end
    end
end

function Library:StartLoop()
    Services.Run.RenderStepped:Connect(function()
        self:HandleToggle()
        if not GUI_Visible then return end
        
        self:HandleInput()
        self:UpdateUI()
    end)
end

function Library:Unload()
    for _, obj in ipairs(DrawingObjects) do
        obj:Remove()
    end
    DrawingObjects = {}
    GUI_Visible = false
    GUI_Initialized = false
    print("[UI Library] Unloaded")
end

return Library
