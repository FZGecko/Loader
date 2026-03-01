return function(import)
    local Kernel = import("Core/Kernel")
    local Theme = import("Gui/Theme")

    local ThemeApplier = {}

    local function ApplyTheme(instance)
        if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
            Kernel:SetProperty(instance, "Font", Theme.Font)
            Kernel:SetProperty(instance, "TextSize", Theme.FontSize)
            Kernel:SetProperty(instance, "TextColor3", Theme.Text)

            if instance:IsA("TextLabel") or instance:IsA("TextBox") then
                Kernel:SetProperty(instance, "BackgroundColor3", Theme.Background)
            end

        elseif instance:IsA("Frame") or instance:IsA("TextButton") or instance:IsA("TextBox") then
            Kernel:SetProperty(instance, "BackgroundColor3", Theme.Primary)
        end

        if instance:IsA("Frame") then
            Kernel:SetProperty(instance, "BorderSizePixel", 0)
        end
    end

    function ThemeApplier:Apply(root)
        ApplyTheme(root) -- Apply to the root instance first
        for _, descendant in ipairs(root:GetDescendants()) do
            if descendant:IsA("GuiObject") then
                ApplyTheme(descendant)
            end
        end
    end

    return ThemeApplier
end

-- Usage:
-- local ThemeApplier = import("Gui/ThemeApplier")
-- local mySection = Section.Create() -- Or any GuiObject
-- ThemeApplier:Apply(mySection)

-- Properties: N/A

-- Methods:
-- Apply(root) - Applies the theme to the specified GuiObject and all its descendants.

-- TODO:
-- Add support for ImageLabels and ImageButtons.
-- Add a more flexible system for defining theme properties (e.g., a table of properties to apply based on class name).
-- Add support for custom themes.
-- This is not finished and should be used with caution.
