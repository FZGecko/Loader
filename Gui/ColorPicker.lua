return function(import)
    local Kernel = import("Core/Kernel")
    local Janitor = import("Core/Janitor")
    local ThemeApplier = import("Gui/ThemeApplier")
    local Theme = import("Gui/Theme")
    local Slider = import("Gui/Slider")
    local Services = import("Core/Services")
    local UserInputService = Services.Get("UserInputService")

    local ColorPicker = {}
    ColorPicker.__index = ColorPicker

    --// HSV to RGB Conversion (Helper Function)
    local function HSVToRGB(h, s, v)
        local C = v * s
        local X = C * (1 - math.abs((h / 60) % 2 - 1))
        local m = v - C
        local r, g, b
        if h < 60 then
            r, g, b = C, X, 0
        elseif h < 120 then
            r, g, b = X, C, 0
        elseif h < 180 then
            r, g, b = 0, C, X
        elseif h < 240 then r, g, b = 0, X, C
        elseif h < 300 then r, g, b = X, 0, C
        else
            r, g, b = C, 0, X
        end
        return Color3.new(r + m, g + m, b + m)
    end

    --// RGB to HSV Conversion (Helper Function)
    local function RGBToHSV(color)
        local r, g, b = color.R, color.G, color.B
        local max = math.max(r, g, b)
        local min = math.min(r, g, b)
        local C = max - min

        if C == 0 then return 0, 0, max end

        local h
        if max == r then h = ((g - b) / C) % 6
        elseif max == g then h = (b - r) / C + 2
        else h = (r - g) / C + 4
        end
        h = h * 60
        if h < 0 then h = h + 360 end

        local s = C / max
        return h, s, max
    end

    function ColorPicker.Create(properties)
        local elementJanitor = Janitor.new()

        --// Main Color Picker Frame
        local colorPickerFrame = Kernel:Create("Frame", {
            Size = UDim2.new(1, 0, 0, 180),
            BackgroundColor3 = Theme.Primary,
            BorderSizePixel = 0,
            LayoutOrder = properties.LayoutOrder
        })
        elementJanitor:Add(colorPickerFrame)
        elementJanitor:Add(Kernel:Create("UICorner", { CornerRadius = UDim.new(0, Theme.Rounding), Parent = colorPickerFrame }))
        ThemeApplier:Apply(colorPickerFrame)

        --// Color Swatch (Displays the Selected Color)
        local swatch = Kernel:Create("Frame", {
            Size = UDim2.new(1, 0, 0, 20),
			Parent = colorPickerFrame,
            BackgroundColor3 = Color3.new(1, 1, 1), -- Default White
            Position = UDim2.new(0, 0, 0, 0),
            LayoutOrder = 1
        })
        elementJanitor:Add(swatch)
        elementJanitor:Add(Kernel:Create("UICorner", { CornerRadius = UDim.new(0, Theme.Rounding), Parent = swatch }))

        --// Transparency Slider
        local transparencySlider = Slider.Create({
			LayoutOrder = 4,
            Callback = function(transparency)
                local currentColor = swatch.BackgroundColor3
                local h, s, v = RGBToHSV(currentColor)
                local newColor = HSVToRGB(h, s, v)
                swatch.BackgroundColor3 = newColor:ToHSV()
                properties.Callback(newColor:ToHSV())
            end
        })
        local hue = 0
	transparencySlider.Parent = colorPickerFrame
	elementJanitor:Add(transparencySlider)


		-- Hue Slider
        -- Hue Slider
		local hueSlider = Slider.Create({
            LayoutOrder = 2,
            Callback = function(h)
                hue = h * 360
                local currentColor = HSVToRGB(hue, 1, 1)
                swatch.BackgroundColor3 = currentColor
                properties.Callback(currentColor)
            end
        })
        hueSlider.Parent = colorPickerFrame
        elementJanitor:Add(hueSlider)
        local saturation = 0

        --// Saturation Slider
        local saturationSlider = Slider.Create({
            LayoutOrder = 3,
            Callback = function(s)
                saturation = s
                local currentColor = HSVToRGB(hue, saturation, 1)
                swatch.BackgroundColor3 = currentColor
                properties.Callback(currentColor)
            end
        })
        saturationSlider.Parent = colorPickerFrame
        elementJanitor:Add(saturationSlider)


        --// Initialize with Starting Color if Provided
        if properties.StartingColor then
            local h, s, v = RGBToHSV(properties.StartingColor)
            hue = h
            saturation = s
            swatch.BackgroundColor3 = properties.StartingColor

            -- TODO: Set initial slider positions based on HSV values (requires Slider.SetValue function)
            -- Slider.SetValue(hueSlider, hue / 360)
            -- Slider.SetValue(saturationSlider, saturation)
            -- Slider.SetValue(transparencySlider, v)
        end

        -- Give access to destroy for easy deletion
        colorPickerFrame.Destroy = function()
            elementJanitor:Clean()
        end

        return colorPickerFrame
    end

    -- Properties : Callback, LayoutOrder, StartingColor
    -- Call back will pass a color3 when the color changes

    -- TODO: Add value input boxes.
    -- Add HSV/RGB mode toggle.
    -- Make slider more resilient and smooth

    -- This code requires helper functions for RGB to HSV conversion for programmatic value setting.
    -- RGBToHSV implementation (This is just an example, and I omitted it)
    -- local function RGBToHSV(color)
    -- end

    -- function Slider.SetValue(sliderFrame, color) -- incomplete
    -- local h,s,v = RGBToHSV(color)
    -- end

    return ColorPicker
end
            end
        end)

        -- Function to set color programmatically will require an RGBToHSV function that is beyond the scope of this code, but can be implemented and called here.


        -- Give access to destroy for easy deletion
		colorPickerFrame.Destroy = function()
			elementJanitor:Clean()
		end

        return colorPickerFrame
    end

    return ColorPicker
end

-- Properties : Callback, LayoutOrder, StartingColor
-- Call back will pass a color3 when the color changes

-- TODO: Add value input boxes.
-- Add HSV/RGB mode toggle.
-- Make slider more resiliant and smooth

-- This code requires helper functions for RGB to HSV conversion for programatic value setting.
-- RGBToHSV implementation (This is just an example, and I ommitted it)
-- local function RGBToHSV(color)
-- end


-- function Slider.SetValue(sliderFrame, color) -- incomplete
-- local h,s,v = RGBToHSV(color)
-- end
