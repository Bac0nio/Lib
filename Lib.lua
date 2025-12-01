local Library = {}
Library.__index = Library

local DrawingObjects = {}
local Services = {
    Mouse = game:GetService("MouseService"),
    Run = game:GetService("RunService"),
    Players = game:GetService("Players")
}

local Player = Services.Players.LocalPlayer

local CONFIG = {
    TOGGLE_KEY = "P",
    TOGGLE_COOLDOWN = 0.25,
    
    GUI = {
        X = 200, Y = 120,
        WIDTH = 770, HEIGHT = 520,
        LEFT_WIDTH = 195
    },
    
    COLORS = {
        LEFT_PANEL = Color3.fromRGB(5, 5, 5),
        RIGHT_PANEL = Color3.fromRGB(0, 0, 0),
        NICK_BLOCK = Color3.fromRGB(30, 30, 30),
        NICK_CIRCLE = Color3.fromRGB(70, 70, 70),
        BLOCK_BG = Color3.fromRGB(25, 25, 25),
        TOGGLE_OFF = Color3.fromRGB(60, 60, 60),
        TOGGLE_ON = Color3.fromRGB(100, 150, 255),
        SLIDER_BG = Color3.fromRGB(40, 40, 40),
        SLIDER_FILL = Color3.fromRGB(100, 150, 255),
        ACTIVE_TAB = Color3.fromRGB(100, 150, 255),
        TEXT_DEFAULT = Color3.new(1, 1, 1),
        TEXT_INACTIVE = Color3.fromRGB(150, 150, 150),
        HEADER = Color3.fromRGB(180, 180, 180),
        SCROLLBAR_BG = Color3.fromRGB(30, 30, 30),
        SCROLLBAR_THUMB = Color3.fromRGB(100, 150, 255),
        BUTTON_BG = Color3.fromRGB(50, 50, 50),
        DROPDOWN_BG = Color3.fromRGB(20, 20, 20),
        CHECKBOX_OFF = Color3.fromRGB(60, 60, 60),
        CHECKBOX_ON = Color3.fromRGB(100, 150, 255)
    },
    
    OPACITY = {
        LEFT = 0.6,
        RIGHT = 0.92,
        NICK_BLOCK = 0.92,
        BLOCK = 0.85,
        SCROLLBAR = 0.95,
        DROPDOWN = 0.98
    },
    
    LAYOUT = {
        LINE_SPACING = 40,
        TEXT_OFFSET_X = 50,
        NICK_HEIGHT = 50,
        AVATAR_SIZE = 30,
        BLOCK_PADDING = 15,
        BLOCK_SPACING = 15,
        OPTION_HEIGHT = 30,
        OPTION_SPACING = 8,
        TOGGLE_WIDTH = 40,
        TOGGLE_HEIGHT = 20,
        TOGGLE_CIRCLE_RADIUS = 8,
        SLIDER_HEIGHT = 6,
        SLIDER_CIRCLE_RADIUS = 10,
        SCROLLBAR_WIDTH = 10,
        BUTTON_HEIGHT = 25,
        DROPDOWN_ITEM_HEIGHT = 25
    },
    
    TEXT_SIZE = {
        TITLE = 27,
        HEADER = 13,
        BUTTON = 16,
        BLOCK_TITLE = 16,
        OPTION = 12,
        NICK = 18
    },
    
    ZINDEX = {
        BASE = 100,
        PANEL = 100,
        BLOCK = 200,
        COMPONENT = 300,
        SCROLLBAR = 400,
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

local function PointInCircle(px, py, cx, cy, radius)
    local dx, dy = px - cx, py - cy
    return (dx * dx + dy * dy) <= (radius * radius)
end

local function Clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function Lerp(a, b, t)
    return a + (b - a) * t
end

local function LoadAvatar()
    local avatarUrl
    local fileName = "avatar_" .. Player.UserId .. ".txt"
    
    if isfile and readfile and isfile(fileName) then
        local content = readfile(fileName)
        if content and content ~= "" then
            avatarUrl = content
        end
    end
    
    if not avatarUrl then
        local apiUrl = "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds="..Player.UserId.."&size=100x100&format=Png"
        local success, response = pcall(game.HttpGet, game, apiUrl)
        if success and response then
            avatarUrl = response:match("(https://tr%.rbxcdn%.com/.-noFilter)")
            if avatarUrl and writefile then
                pcall(writefile, fileName, avatarUrl)
            end
        end
    end
    
    if avatarUrl then
        local resizedUrl = avatarUrl:gsub("/100/100/", "/"..CONFIG.LAYOUT.AVATAR_SIZE.."/"..CONFIG.LAYOUT.AVATAR_SIZE.."/")
        local avatarImage = CreateDrawing("Image", {
            Url = resizedUrl,
            Size = Vector2.new(CONFIG.LAYOUT.AVATAR_SIZE, CONFIG.LAYOUT.AVATAR_SIZE),
            ZIndex = CONFIG.ZINDEX.PANEL + 3,
            Rounding = 15
        })
        return avatarImage
    end
    
    return nil
end

local ScrollManager = {
    offset = 0,
    maxOffset = 0,
    draggingThumb = false,
    dragStartY = 0,
    dragStartOffset = 0
}

function ScrollManager:Init()
    self.scrollbarBg = CreateDrawing("Square", {
        Filled = true,
        Color = CONFIG.COLORS.SCROLLBAR_BG,
        Transparency = CONFIG.OPACITY.SCROLLBAR,
        Rounding = 5,
        ZIndex = CONFIG.ZINDEX.SCROLLBAR
    })
    
    self.scrollbarThumb = CreateDrawing("Square", {
        Filled = true,
        Color = CONFIG.COLORS.SCROLLBAR_THUMB,
        Transparency = CONFIG.OPACITY.SCROLLBAR,
        Rounding = 5,
        ZIndex = CONFIG.ZINDEX.SCROLLBAR + 1
    })
end

function ScrollManager:UpdateMaxOffset(contentHeight, viewHeight)
    self.maxOffset = math.max(0, contentHeight - viewHeight)
    self.offset = Clamp(self.offset, 0, self.maxOffset)
end

function ScrollManager:Update()
    local rightX = Panel.x + CONFIG.GUI.LEFT_WIDTH
    local rightY = Panel.y
    local rightWidth = CONFIG.GUI.WIDTH - CONFIG.GUI.LEFT_WIDTH
    local rightHeight = CONFIG.GUI.HEIGHT
    
    if self.maxOffset > 10 then
        self.scrollbarBg.Position = Vector2.new(rightX + rightWidth - CONFIG.LAYOUT.SCROLLBAR_WIDTH - 8, rightY + 8)
        self.scrollbarBg.Size = Vector2.new(CONFIG.LAYOUT.SCROLLBAR_WIDTH, rightHeight - 16)
        self.scrollbarBg.Visible = GUI_Visible and GUI_Initialized
        
        local thumbHeight = math.max(40, (rightHeight - 16) * (rightHeight / (rightHeight + self.maxOffset)))
        local scrollableHeight = rightHeight - 16 - thumbHeight
        local thumbY = rightY + 8 + (scrollableHeight * (self.offset / self.maxOffset))
        
        self.scrollbarThumb.Position = Vector2.new(rightX + rightWidth - CONFIG.LAYOUT.SCROLLBAR_WIDTH - 8, thumbY)
        self.scrollbarThumb.Size = Vector2.new(CONFIG.LAYOUT.SCROLLBAR_WIDTH, thumbHeight)
        self.scrollbarThumb.Visible = GUI_Visible and GUI_Initialized
    else
        self.scrollbarBg.Visible = false
        self.scrollbarThumb.Visible = false
    end
end

function ScrollManager:HandleThumbDrag(mx, my)
    if self.draggingThumb then
        local rightY = Panel.y
        local rightHeight = CONFIG.GUI.HEIGHT
        local thumbHeight = math.max(40, (rightHeight - 16) * (rightHeight / (rightHeight + self.maxOffset)))
        
        local deltaY = my - self.dragStartY
        local scrollRange = rightHeight - 16 - thumbHeight
        if scrollRange > 0 then
            local scrollDelta = (deltaY / scrollRange) * self.maxOffset
            self.offset = Clamp(self.dragStartOffset + scrollDelta, 0, self.maxOffset)
        end
        return true
    end
    return false
end

function ScrollManager:StartThumbDrag(mx, my)
    if self.maxOffset <= 10 then return false end
    
    local pos = self.scrollbarThumb.Position
    local size = self.scrollbarThumb.Size
    
    if PointInRect(mx, my, pos.X, pos.Y, size.X, size.Y) then
        self.draggingThumb = true
        self.dragStartY = my
        self.dragStartOffset = self.offset
        return true
    end
    return false
end

function ScrollManager:StopThumbDrag()
    self.draggingThumb = false
end

local Toggle = {}
Toggle.__index = Toggle

function Toggle.new(option, accentColor)
    local self = setmetatable({}, Toggle)
    self.option = option
    self.accentColor = accentColor or CONFIG.COLORS.TOGGLE_ON
    
    self.bg = CreateDrawing("Square", {
        Filled = true,
        Color = CONFIG.COLORS.TOGGLE_OFF,
        Transparency = 0.8,
        Rounding = 10,
        ZIndex = CONFIG.ZINDEX.COMPONENT
    })
    
    self.circle = CreateDrawing("Circle", {
        Filled = true,
        Color = Color3.new(1, 1, 1),
        Radius = CONFIG.LAYOUT.TOGGLE_CIRCLE_RADIUS,
        ZIndex = CONFIG.ZINDEX.COMPONENT + 1
    })
    
    self.label = CreateDrawing("Text", {
        Text = option.Name,
        Size = CONFIG.TEXT_SIZE.OPTION,
        Center = false,
        Color = CONFIG.COLORS.TEXT_INACTIVE,
        ZIndex = CONFIG.ZINDEX.COMPONENT
    })
    
    return self
end

function Toggle:Update(x, y)
    self.label.Position = Vector2.new(x, y)
    
    local toggleX = x + 175
    self.bg.Position = Vector2.new(toggleX, y - 2)
    self.bg.Size = Vector2.new(CONFIG.LAYOUT.TOGGLE_WIDTH, CONFIG.LAYOUT.TOGGLE_HEIGHT)
    
    local circleX = self.option.Value and 
        (toggleX + CONFIG.LAYOUT.TOGGLE_WIDTH - CONFIG.LAYOUT.TOGGLE_CIRCLE_RADIUS - 2) or 
        (toggleX + CONFIG.LAYOUT.TOGGLE_CIRCLE_RADIUS + 2)
    
    self.circle.Position = Vector2.new(circleX, y + CONFIG.LAYOUT.TOGGLE_HEIGHT / 2 - 2)
    self.bg.Color = self.option.Value and self.accentColor or CONFIG.COLORS.TOGGLE_OFF
    self.label.Color = self.option.Value and CONFIG.COLORS.TEXT_DEFAULT or CONFIG.COLORS.TEXT_INACTIVE
end

function Toggle:HandleClick(mx, my)
    if not self.bg.Visible then return false end
    local pos = self.bg.Position
    local size = self.bg.Size
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
    self.bg.Visible = visible and GUI_Visible and GUI_Initialized
    self.circle.Visible = visible and GUI_Visible and GUI_Initialized
    self.label.Visible = visible and GUI_Visible and GUI_Initialized
end

local Slider = {}
Slider.__index = Slider

function Slider.new(option, accentColor)
    local self = setmetatable({}, Slider)
    self.option = option
    self.dragging = false
    self.accentColor = accentColor or CONFIG.COLORS.SLIDER_FILL
    
    self.bg = CreateDrawing("Square", {
        Filled = true,
        Color = CONFIG.COLORS.SLIDER_BG,
        Transparency = 0.8,
        Rounding = 3,
        ZIndex = CONFIG.ZINDEX.COMPONENT
    })
    
    self.fill = CreateDrawing("Square", {
        Filled = true,
        Color = self.accentColor,
        Transparency = 0.8,
        Rounding = 3,
        ZIndex = CONFIG.ZINDEX.COMPONENT + 1
    })
    
    self.circle = CreateDrawing("Circle", {
        Filled = true,
        Color = Color3.new(1, 1, 1),
        Radius = CONFIG.LAYOUT.SLIDER_CIRCLE_RADIUS,
        ZIndex = CONFIG.ZINDEX.COMPONENT + 2
    })
    
    self.label = CreateDrawing("Text", {
        Text = option.Name,
        Size = CONFIG.TEXT_SIZE.OPTION,
        Center = false,
        Color = CONFIG.COLORS.TEXT_DEFAULT,
        ZIndex = CONFIG.ZINDEX.COMPONENT
    })
    
    self.valueText = CreateDrawing("Text", {
        Text = tostring(option.Value),
        Size = CONFIG.TEXT_SIZE.OPTION,
        Center = false,
        Color = CONFIG.COLORS.TEXT_DEFAULT,
        ZIndex = CONFIG.ZINDEX.COMPONENT
    })
    
    return self
end

function Slider:Update(x, y)
    self.label.Position = Vector2.new(x, y)
    
    local sliderX = x + 75
    local sliderWidth = 100
    self.bg.Position = Vector2.new(sliderX, y + 5)
    self.bg.Size = Vector2.new(sliderWidth, CONFIG.LAYOUT.SLIDER_HEIGHT)
    
    local percent = (self.option.Value - self.option.Min) / (self.option.Max - self.option.Min)
    local fillWidth = sliderWidth * percent
    
    self.fill.Position = Vector2.new(sliderX, y + 5)
    self.fill.Size = Vector2.new(fillWidth, CONFIG.LAYOUT.SLIDER_HEIGHT)
    
    local circleX = sliderX + fillWidth
    self.circle.Position = Vector2.new(circleX, y + 8)
    
    self.valueText.Text = tostring(math.floor(self.option.Value))
    self.valueText.Position = Vector2.new(sliderX + sliderWidth + 10, y)
end

function Slider:HandleDrag(mx, my)
    if self.dragging then
        local pos = self.bg.Position
        local size = self.bg.Size
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
    if not self.bg.Visible then return false end
    local pos = self.bg.Position
    local size = self.bg.Size
    if PointInRect(mx, my, pos.X, pos.Y - 5, size.X, size.Y + 10) or
       PointInCircle(mx, my, self.circle.Position.X, self.circle.Position.Y, CONFIG.LAYOUT.SLIDER_CIRCLE_RADIUS) then
        self.dragging = true
        return true
    end
    return false
end

function Slider:StopDrag()
    self.dragging = false
end

function Slider:SetVisible(visible)
    self.bg.Visible = visible and GUI_Visible and GUI_Initialized
    self.fill.Visible = visible and GUI_Visible and GUI_Initialized
    self.circle.Visible = visible and GUI_Visible and GUI_Initialized
    self.label.Visible = visible and GUI_Visible and GUI_Initialized
    self.valueText.Visible = visible and GUI_Visible and GUI_Initialized
end

local MultiSelect = {}
MultiSelect.__index = MultiSelect

function MultiSelect.new(option, accentColor)
    local self = setmetatable({}, MultiSelect)
    self.option = option
    self.accentColor = accentColor or CONFIG.COLORS.CHECKBOX_ON
    self.isOpen = false
    self.dropdownElements = {}
    
    self.label = CreateDrawing("Text", {
        Text = option.Name,
        Size = CONFIG.TEXT_SIZE.OPTION,
        Center = false,
        Color = CONFIG.COLORS.TEXT_DEFAULT,
        ZIndex = CONFIG.ZINDEX.COMPONENT
    })
    
    self.button = CreateDrawing("Square", {
        Filled = true,
        Color = CONFIG.COLORS.BUTTON_BG,
        Transparency = 0.8,
        Rounding = 3,
        ZIndex = CONFIG.ZINDEX.COMPONENT
    })
    
    self.buttonText = CreateDrawing("Text", {
        Text = "Select...",
        Size = CONFIG.TEXT_SIZE.OPTION,
        Center = false,
        Color = CONFIG.COLORS.TEXT_DEFAULT,
        ZIndex = CONFIG.ZINDEX.COMPONENT + 1
    })
    
    self.dropdownBg = CreateDrawing("Square", {
        Filled = true,
        Color = CONFIG.COLORS.DROPDOWN_BG,
        Transparency = CONFIG.OPACITY.DROPDOWN,
        Rounding = 3,
        ZIndex = CONFIG.ZINDEX.DROPDOWN
    })
    
    for _, itemName in ipairs(option.Options) do
        local checkbox = CreateDrawing("Square", {
            Filled = true,
            Color = CONFIG.COLORS.CHECKBOX_OFF,
            Transparency = 0.8,
            Rounding = 2,
            ZIndex = CONFIG.ZINDEX.DROPDOWN + 1
        })
        
        local checkmark = CreateDrawing("Text", {
            Text = "✓",
            Size = 14,
            Center = false,
            Color = Color3.new(1, 1, 1),
            ZIndex = CONFIG.ZINDEX.DROPDOWN + 2
        })
        
        local itemText = CreateDrawing("Text", {
            Text = itemName,
            Size = CONFIG.TEXT_SIZE.OPTION,
            Center = false,
            Color = CONFIG.COLORS.TEXT_DEFAULT,
            ZIndex = CONFIG.ZINDEX.DROPDOWN + 1
        })
        
        table.insert(self.dropdownElements, {
            name = itemName,
            checkbox = checkbox,
            checkmark = checkmark,
            text = itemText,
            selected = false
        })
    end
    
    return self
end

function MultiSelect:Update(x, y)
    self.label.Position = Vector2.new(x, y)
    
    local buttonX = x + 100
    local buttonWidth = 115
    self.button.Position = Vector2.new(buttonX, y - 2)
    self.button.Size = Vector2.new(buttonWidth, CONFIG.LAYOUT.BUTTON_HEIGHT)
    
    local selectedCount = 0
    for _, elem in ipairs(self.dropdownElements) do
        if elem.selected then selectedCount = selectedCount + 1 end
    end
    
    self.buttonText.Text = selectedCount > 0 and ("Selected: " .. selectedCount) or "Select..."
    self.buttonText.Position = Vector2.new(buttonX + 5, y + 3)
    
    if self.isOpen then
        local dropdownHeight = #self.dropdownElements * CONFIG.LAYOUT.DROPDOWN_ITEM_HEIGHT + 10
        self.dropdownBg.Position = Vector2.new(buttonX, y + CONFIG.LAYOUT.BUTTON_HEIGHT + 2)
        self.dropdownBg.Size = Vector2.new(buttonWidth, dropdownHeight)
        self.dropdownBg.Visible = GUI_Visible and GUI_Initialized
        
        for i, elem in ipairs(self.dropdownElements) do
            local itemY = y + CONFIG.LAYOUT.BUTTON_HEIGHT + 5 + (i - 1) * CONFIG.LAYOUT.DROPDOWN_ITEM_HEIGHT
            
            elem.checkbox.Position = Vector2.new(buttonX + 5, itemY + 3)
            elem.checkbox.Size = Vector2.new(16, 16)
            elem.checkbox.Color = elem.selected and self.accentColor or CONFIG.COLORS.CHECKBOX_OFF
            elem.checkbox.Visible = GUI_Visible and GUI_Initialized
            
            elem.checkmark.Position = Vector2.new(buttonX + 7, itemY + 2)
            elem.checkmark.Visible = GUI_Visible and GUI_Initialized and elem.selected
            
            elem.text.Position = Vector2.new(buttonX + 28, itemY + 5)
            elem.text.Visible = GUI_Visible and GUI_Initialized
        end
    else
        self.dropdownBg.Visible = false
        for _, elem in ipairs(self.dropdownElements) do
            elem.checkbox.Visible = false
            elem.checkmark.Visible = false
            elem.text.Visible = false
        end
    end
end

function MultiSelect:HandleClick(mx, my)
    if not self.button.Visible then return false end
    
    local pos = self.button.Position
    local size = self.button.Size
    
    if PointInRect(mx, my, pos.X, pos.Y, size.X, size.Y) then
        self.isOpen = not self.isOpen
        if self.isOpen and ActiveDropdown and ActiveDropdown ~= self then
            ActiveDropdown.isOpen = false
        end
        ActiveDropdown = self.isOpen and self or nil
        return true
    end
    
    if self.isOpen then
        local dropdownPos = self.dropdownBg.Position
        local dropdownSize = self.dropdownBg.Size
        
        if PointInRect(mx, my, dropdownPos.X, dropdownPos.Y, dropdownSize.X, dropdownSize.Y) then
            for i, elem in ipairs(self.dropdownElements) do
                local itemY = dropdownPos.Y + 5 + (i - 1) * CONFIG.LAYOUT.DROPDOWN_ITEM_HEIGHT
                if PointInRect(mx, my, dropdownPos.X, itemY, dropdownSize.X, CONFIG.LAYOUT.DROPDOWN_ITEM_HEIGHT) then
                    elem.selected = not elem.selected
                    
                    if not self.option.Values then
                        self.option.Values = {}
                    end
                    
                    if elem.selected then
                        table.insert(self.option.Values, elem.name)
                    else
                        for j, v in ipairs(self.option.Values) do
                            if v == elem.name then
                                table.remove(self.option.Values, j)
                                break
                            end
                        end
                    end
                    
                    if self.option.Callback then
                        self.option.Callback(self.option.Values)
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
    self.button.Visible = visible and GUI_Visible and GUI_Initialized
    self.buttonText.Visible = visible and GUI_Visible and GUI_Initialized
    if not visible then
        self.dropdownBg.Visible = false
        for _, elem in ipairs(self.dropdownElements) do
            elem.checkbox.Visible = false
            elem.checkmark.Visible = false
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
    
    self.title = CreateDrawing("Text", {
        Text = data.Name,
        Size = CONFIG.TEXT_SIZE.BLOCK_TITLE,
        Center = false,
        Color = CONFIG.COLORS.TEXT_DEFAULT,
        ZIndex = CONFIG.ZINDEX.BLOCK + 1
    })
    
    self.bg = CreateDrawing("Square", {
        Filled = true,
        Color = CONFIG.COLORS.BLOCK_BG,
        Transparency = CONFIG.OPACITY.BLOCK,
        Rounding = 5,
        ZIndex = CONFIG.ZINDEX.BLOCK
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
        Values = {},
        Callback = options.Callback
    }
    
    local multiselect = MultiSelect.new(option, self.accentColor)
    table.insert(self.components, multiselect)
    
    return {
        GetSelected = function()
            return option.Values
        end,
        SetSelected = function(values)
            option.Values = values or {}
            for _, elem in ipairs(multiselect.dropdownElements) do
                elem.selected = false
                for _, v in ipairs(option.Values) do
                    if elem.name == v then
                        elem.selected = true
                        break
                    end
                end
            end
            if option.Callback then
                option.Callback(option.Values)
            end
        end
    }
end

function Section:CalculateHeight()
    local height = CONFIG.LAYOUT.BLOCK_PADDING * 2 + CONFIG.TEXT_SIZE.BLOCK_TITLE + 10
    for _, component in ipairs(self.components) do
        height = height + CONFIG.LAYOUT.OPTION_HEIGHT + CONFIG.LAYOUT.OPTION_SPACING
    end
    return height
end

function Section:UpdateBlock(x, y, width)
    self.bg.Position = Vector2.new(x, y)
    local height = self:CalculateHeight()
    self.bg.Size = Vector2.new(width, height)
    
    self.title.Position = Vector2.new(x + CONFIG.LAYOUT.BLOCK_PADDING, y + CONFIG.LAYOUT.BLOCK_PADDING)
    
    local optionY = y + CONFIG.LAYOUT.BLOCK_PADDING + CONFIG.TEXT_SIZE.BLOCK_TITLE + 15
    for _, component in ipairs(self.components) do
        component:Update(x + CONFIG.LAYOUT.BLOCK_PADDING, optionY)
        optionY = optionY + CONFIG.LAYOUT.OPTION_HEIGHT + CONFIG.LAYOUT.OPTION_SPACING
    end
    
    return height
end

function Section:SetVisible(visible, clipY, clipHeight)
    if not visible or not GUI_Initialized then
        self.bg.Visible = false
        self.title.Visible = false
        for _, component in ipairs(self.components) do
            component:SetVisible(false)
        end
        return
    end
    
    local blockY = self.bg.Position.Y
    local blockHeight = self.bg.Size.Y
    local blockBottom = blockY + blockHeight
    local clipBottom = clipY + clipHeight
    
    if blockBottom < clipY or blockY > clipBottom then
        self.bg.Visible = false
        self.title.Visible = false
        for _, component in ipairs(self.components) do
            component:SetVisible(false)
        end
        return
    end
    
    self.bg.Visible = GUI_Visible and GUI_Initialized
    
    local visibleTop = math.max(blockY, clipY)
    local visibleBottom = math.min(blockBottom, clipBottom)
    local visibleHeight = visibleBottom - visibleTop
    
    if visibleHeight > 0 then
        self.bg.Position = Vector2.new(self.bg.Position.X, visibleTop)
        self.bg.Size = Vector2.new(self.bg.Size.X, visibleHeight)
    end
    
    local titleY = self.title.Position.Y
    self.title.Visible = (titleY >= clipY and titleY <= clipBottom) and GUI_Visible and GUI_Initialized
    
    for _, component in ipairs(self.components) do
        local compY = component.label.Position.Y
        local compVisible = compY >= clipY and (compY + CONFIG.LAYOUT.OPTION_HEIGHT) <= clipBottom
        component:SetVisible(compVisible)
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
    self.AccentColor = options.AccentColor or CONFIG.COLORS.TOGGLE_ON
    self.ToggleKey = options.ToggleKey or CONFIG.TOGGLE_KEY
    
    CONFIG.COLORS.TOGGLE_ON = self.AccentColor
    CONFIG.COLORS.SLIDER_FILL = self.AccentColor
    CONFIG.COLORS.ACTIVE_TAB = self.AccentColor
    CONFIG.COLORS.SCROLLBAR_THUMB = self.AccentColor
    CONFIG.COLORS.CHECKBOX_ON = self.AccentColor
    CONFIG.TOGGLE_KEY = self.ToggleKey
    
    self.tabs = {}
    self.tabButtons = {}
    self.activeTab = nil
    
    self.leftPanel = CreateDrawing("Square", {
        Filled = true,
        Color = CONFIG.COLORS.LEFT_PANEL,
        Transparency = CONFIG.OPACITY.LEFT,
        ZIndex = CONFIG.ZINDEX.PANEL
    })
    
    self.rightPanel = CreateDrawing("Square", {
        Filled = true,
        Color = CONFIG.COLORS.RIGHT_PANEL,
        Transparency = CONFIG.OPACITY.RIGHT,
        ZIndex = CONFIG.ZINDEX.PANEL
    })
    
    self.nickBlock = CreateDrawing("Square", {
        Filled = true,
        Color = CONFIG.COLORS.NICK_BLOCK,
        Transparency = CONFIG.OPACITY.NICK_BLOCK,
        ZIndex = CONFIG.ZINDEX.PANEL + 1
    })
    
    self.nickCircle = CreateDrawing("Circle", {
        Filled = true,
        Color = CONFIG.COLORS.NICK_CIRCLE,
        Radius = CONFIG.LAYOUT.AVATAR_SIZE / 2,
        ZIndex = CONFIG.ZINDEX.PANEL + 2
    })
    
    self.avatarImage = LoadAvatar()
    
    self.nickText = CreateDrawing("Text", {
        Text = Player.DisplayName,
        Size = CONFIG.TEXT_SIZE.NICK,
        Font = 1,
        Color = CONFIG.COLORS.TEXT_DEFAULT,
        Center = false,
        ZIndex = CONFIG.ZINDEX.PANEL + 2
    })
    
    self.title = CreateDrawing("Text", {
        Text = self.Name,
        Size = CONFIG.TEXT_SIZE.TITLE,
        Font = 2,
        Center = true,
        Color = CONFIG.COLORS.TEXT_DEFAULT,
        ZIndex = CONFIG.ZINDEX.PANEL + 2
    })
    
    self.dragging = false
    self.dragOffset = {x = 0, y = 0}
    self.wasLeftPressed = false
    self.lastToggle = 0
    
    ScrollManager:Init()
    
    self:StartLoop()
    
    return self
end

function Library:Tab(options)
    local tab = Tab.new(options.Name or "Tab", self.AccentColor)
    
    local tabButton = {
        name = tab.name,
        tab = tab,
        text = CreateDrawing("Text", {
            Text = tab.name,
            Size = CONFIG.TEXT_SIZE.BUTTON,
            Center = false,
            Color = CONFIG.COLORS.TEXT_DEFAULT,
            ZIndex = CONFIG.ZINDEX.PANEL + 2
        }),
        box = CreateDrawing("Square", {
            Filled = true,
            Color = Color3.fromRGB(0, 0, 0),
            Transparency = 0,
            ZIndex = CONFIG.ZINDEX.PANEL + 1
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
    ScrollManager.offset = 0
end

function Library:UpdateUI()
    self.leftPanel.Position = Vector2.new(Panel.x, Panel.y)
    self.leftPanel.Size = Vector2.new(CONFIG.GUI.LEFT_WIDTH, CONFIG.GUI.HEIGHT)
    self.leftPanel.Visible = GUI_Visible and GUI_Initialized
    
    self.rightPanel.Position = Vector2.new(Panel.x + CONFIG.GUI.LEFT_WIDTH, Panel.y)
    self.rightPanel.Size = Vector2.new(CONFIG.GUI.WIDTH - CONFIG.GUI.LEFT_WIDTH, CONFIG.GUI.HEIGHT)
    self.rightPanel.Visible = GUI_Visible and GUI_Initialized
    
    self.nickBlock.Position = Vector2.new(Panel.x, Panel.y + CONFIG.GUI.HEIGHT - CONFIG.LAYOUT.NICK_HEIGHT)
    self.nickBlock.Size = Vector2.new(CONFIG.GUI.LEFT_WIDTH, CONFIG.LAYOUT.NICK_HEIGHT)
    self.nickBlock.Visible = GUI_Visible and GUI_Initialized
    
    local circleX = Panel.x + 10 + CONFIG.LAYOUT.AVATAR_SIZE / 2
    local circleY = Panel.y + CONFIG.GUI.HEIGHT - CONFIG.LAYOUT.NICK_HEIGHT / 2
    
    self.nickCircle.Position = Vector2.new(circleX, circleY)
    self.nickCircle.Visible = GUI_Visible and GUI_Initialized
    
    if self.avatarImage then
        self.avatarImage.Position = Vector2.new(
            circleX - CONFIG.LAYOUT.AVATAR_SIZE / 2,
            circleY - CONFIG.LAYOUT.AVATAR_SIZE / 2
        )
        self.avatarImage.Visible = GUI_Visible and GUI_Initialized
    end
    
    self.nickText.Position = Vector2.new(
        Panel.x + 10 + CONFIG.LAYOUT.AVATAR_SIZE + 10,
        Panel.y + CONFIG.GUI.HEIGHT - CONFIG.LAYOUT.NICK_HEIGHT / 2 - 8
    )
    self.nickText.Visible = GUI_Visible and GUI_Initialized
    
    self.title.Position = Vector2.new(
        Panel.x + CONFIG.GUI.LEFT_WIDTH / 2,
        Panel.y + 20
    )
    self.title.Visible = GUI_Visible and GUI_Initialized
    
    for i, tabButton in ipairs(self.tabButtons) do
        local textY = Panel.y + 60 + (i - 1) * CONFIG.LAYOUT.LINE_SPACING
        tabButton.text.Position = Vector2.new(Panel.x + CONFIG.LAYOUT.TEXT_OFFSET_X - 20, textY)
        tabButton.text.Visible = GUI_Visible and GUI_Initialized
        tabButton.box.Position = Vector2.new(Panel.x + 10, textY - 5)
        tabButton.box.Size = Vector2.new(CONFIG.GUI.LEFT_WIDTH - 20, CONFIG.LAYOUT.LINE_SPACING - 10)
        tabButton.box.Visible = GUI_Visible and GUI_Initialized
        tabButton.text.Color = tabButton.tab.isActive and self.AccentColor or CONFIG.COLORS.TEXT_DEFAULT
    end
end

function Library:UpdateBlocks()
    if not GUI_Initialized then return end
    
    local rightX = Panel.x + CONFIG.GUI.LEFT_WIDTH
    local rightY = Panel.y
    local rightWidth = CONFIG.GUI.WIDTH - CONFIG.GUI.LEFT_WIDTH
    local rightHeight = CONFIG.GUI.HEIGHT
    local blockWidth = (rightWidth - CONFIG.LAYOUT.BLOCK_SPACING * 3 - CONFIG.LAYOUT.SCROLLBAR_WIDTH - 10) / 2
    
    for _, tab in ipairs(self.tabs) do
        if tab.isActive then
            local col1Y = rightY + CONFIG.LAYOUT.BLOCK_SPACING - ScrollManager.offset
            local col2Y = rightY + CONFIG.LAYOUT.BLOCK_SPACING - ScrollManager.offset
            local maxHeight = 0
            
            for i, section in ipairs(tab.sections) do
                local col = ((i - 1) % 2) + 1
                local x = col == 1 and (rightX + CONFIG.LAYOUT.BLOCK_SPACING) or (rightX + blockWidth + CONFIG.LAYOUT.BLOCK_SPACING * 2)
                local y = col == 1 and col1Y or col2Y
                
                local height = section:UpdateBlock(x, y, blockWidth)
                section:SetVisible(GUI_Visible, rightY, rightHeight)
                
                if col == 1 then
                    col1Y = col1Y + height + CONFIG.LAYOUT.BLOCK_SPACING
                    maxHeight = math.max(maxHeight, col1Y - rightY + ScrollManager.offset)
                else
                    col2Y = col2Y + height + CONFIG.LAYOUT.BLOCK_SPACING
                    maxHeight = math.max(maxHeight, col2Y - rightY + ScrollManager.offset)
                end
            end
            
            ScrollManager:UpdateMaxOffset(maxHeight, rightHeight)
        else
            for _, section in ipairs(tab.sections) do
                section:SetVisible(false, 0, 0)
            end
        end
    end
    
    ScrollManager:Update()
end

function Library:HandleClick(mx, my)
    if ScrollManager:StartThumbDrag(mx, my) then return end
    
    for _, tabButton in ipairs(self.tabButtons) do
        local pos = tabButton.box.Position
        local size = tabButton.box.Size
        if PointInRect(mx, my, pos.X, pos.Y, size.X, size.Y) then
            self:SwitchTab(tabButton.tab)
            return
        end
    end
    
    if self.activeTab then
        for _, section in ipairs(self.activeTab.sections) do
            if not section.bg.Visible then continue end
            
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
    
    if PointInRect(mx, my, Panel.x, Panel.y, CONFIG.GUI.WIDTH, CONFIG.GUI.HEIGHT) then
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
        ScrollManager:StopThumbDrag()
        return
    end
    
    local mp = Services.Mouse:GetMouseLocation()
    local mx, my = mp.X, mp.Y
    local leftPressed = isleftpressed()
    
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
        
        ScrollManager:HandleThumbDrag(mx, my)
        
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
            ScrollManager:StopThumbDrag()
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
    if not getpressedkeys then return end
    for _, k in ipairs(getpressedkeys()) do
        if k == CONFIG.TOGGLE_KEY then
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
    Services.Run.Render:Connect(function()
        self:HandleToggle()
        if not GUI_Visible then return end
        
        self:HandleInput()
        self:UpdateUI()
        self:UpdateBlocks()
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
