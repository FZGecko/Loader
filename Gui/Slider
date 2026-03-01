return function(import)
    local Kernel = import("Core/Kernel")
    local Janitor = import("Core/Janitor")
    local Theme = import("Gui/Theme")
    local Services = import("Core/Services")
    local UserInputService = Services.Get("UserInputService")

    local Slider = {}
    Slider.__index = Slider

    function Slider.Create(properties)
        local elementJanitor = Janitor.new()

        local sliderFrame = Kernel:Create("Frame", {
            Size = UDim2.new(1, 0, 0, 20),
            BackgroundColor3 = Theme.Primary,
            BorderSizePixel = 0,
            LayoutOrder = properties.LayoutOrder
        })
        elementJanitor:Add(sliderFrame)
        elementJanitor:Add(Kernel:Create("UICorner", { CornerRadius = UDim.new(0, Theme.Rounding), Parent = sliderFrame }))

        local sliderBar = Kernel:Create("Frame", {
            Size = UDim2.new(0.5, 0, 1, 0),
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
            Parent = sliderFrame,
        })
        elementJanitor:Add(Kernel:Create("UICorner", { CornerRadius = UDim2.new(1, Theme.Rounding, 1, Theme.Rounding), Parent = sliderBar }))

        local thumb = Kernel:Create("Frame", {
            Size = UDim2.fromOffset(16, 20),
            Position = UDim2.new(1,0,0,0),
            BackgroundColor3 = Theme.Text,
            BorderSizePixel = 0,
            Parent = sliderBar
        })
        elementJanitor:Add(Kernel:Create("UICorner", { CornerRadius = UDim2.new(1, Theme.Rounding, 1, Theme.Rounding), Parent = thumb }))
        
        local dragging = false
        local dragStart
        local sliderStart

        elementJanitor:Add(Kernel:Connect(thumb.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = UserInputService:GetMouseLocation()
                sliderStart = sliderBar.Size
            end
        end))

        elementJanitor:Add(Kernel:Connect(thumb.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end))

        LoopManager:Bind("SliderDrag", "Render", function()
            if dragging then
                local delta = (UserInputService:GetMouseLocation().X - dragStart.X)
                local newSizeX = math.clamp(sliderStart.X.Offset + delta, 0, sliderFrame.AbsoluteSize.X)
                sliderBar.Size = UDim2.new(0, newSizeX, 1, 0)
                properties.Callback(newSizeX/sliderFrame.AbsoluteSize.X)
            end
        end)

        -- Give access to destroy for easy deletion
		sliderFrame.Destroy = function()
			elementJanitor:Clean()
		end

        return sliderFrame
    end

    return Slider
end

-- Properties : Callback, LayoutOrder

-- Callback returns a number between 0 and 1 representing the slider value.

-- TODO: Add a Value property and setter to programatically change the slider's position.
--       Add MouseEnter/Leave highlights.
--       Add Keyboard support.
--       Consider making the thumb a separate image.
