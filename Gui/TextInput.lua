return function(import)
    local Kernel = import("Core/Kernel")
    local Janitor = import("Core/Janitor")
    local Theme = import("Gui/Theme")
    local Services = import("Core/Services")
    local UserInputService = Services.Get("UserInputService")

    local TextInput = {}
    TextInput.__index = TextInput

    function TextInput.Create(properties)
        local elementJanitor = Janitor.new()

        local textBox = Kernel:Create("TextBox", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = Theme.Primary,
            Font = Theme.Font,
            TextSize = Theme.Font_Size,
            TextColor3 = Theme.Text,
            PlaceholderText = properties.PlaceholderText or "Enter text here",
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = properties.LayoutOrder,
            BorderSizePixel = 0
        })
        elementJanitor:Add(textBox)
        elementJanitor:Add(Kernel:Create("UICorner", { CornerRadius = UDim.new(0, Theme.Rounding), Parent = textBox }))

        elementJanitor:Add(Kernel:Connect(textBox.FocusLost, function(enterPressed)
            if properties.Callback then
                properties.Callback(textBox.Text, enterPressed)
            end
        end))

        -- Set initial text if provided
        if properties.Text then
            textBox.Text = properties.Text
        end

        -- Give access to destroy for easy deletion
		textBox.Destroy = function()
			elementJanitor:Clean()
		end

        return textBox
    end

    return TextInput
end

-- Properties : Text, PlaceholderText, Callback, LayoutOrder
-- Callback is triggered when the textbox loses focus (enter is pressed or focus is lost).
-- Callback returns the text and a boolean for if enter was pressed.

-- TODO: Add scrolling if text is too long.
-- Add character limits.
-- Add different validation modes (number, email, etc.)

-- function TextInput.SetValue(textBox, text) -- example code, that would require further development.
-- textBox.Text = text -- example
-- end
