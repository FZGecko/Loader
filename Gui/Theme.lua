return function(import)
    local Theme = {
        --// Colors
        Background = Color3.fromRGB(24, 24, 36),    -- Darker background for contrast
        Surface = Color3.fromRGB(35, 39, 65),       -- Slightly lighter surface for panels
        Primary = Color3.fromRGB(54, 57, 86),       -- Primary color for buttons and active elements
        Accent = Color3.fromRGB(98, 114, 255),      -- A vibrant accent color
        Hover = Color3.fromRGB(70, 73, 100),        -- Hover state color
        Text = Color3.fromRGB(220, 221, 222),        -- Light text for readability
        TextMuted = Color3.fromRGB(153, 170, 181),   -- Muted text for less important labels

        --// Fonts
        Font = Enum.Font.SourceSansBold,         -- A cleaner, more modern font
        FontSize = 14,

        --// Sizing
        Rounding = 6,

        --// Spacing
        PaddingSmall = UDim.new(0, 4),          -- Small padding for tight elements
        PaddingLarge = UDim.new(0, 8),           -- Larger padding for more spacing
    }

    return Theme
end
