return function(import)
    local Kernel = import("Core/Kernel")
    local Janitor = import("Core/Janitor")
    local Theme = import("Gui/Theme")

    local Section = {}
    Section.__index = Section

    function Section.Create(properties)
        local sectionJanitor = Janitor.new()

        local sectionFrame = Kernel:Create("Frame", {
            Size = UDim2.new(1, 0, 0, 0), -- Auto-size in Y direction
            BackgroundColor3 = Theme.Surface,
            BorderSizePixel = 0,
            LayoutOrder = properties.LayoutOrder or 0, --Let sections have layoutorder too
        })
        sectionJanitor:Add(sectionFrame)
        sectionJanitor:Add(Kernel:Create("UICorner", { CornerRadius = UDim.new(0, Theme.Rounding), Parent = sectionFrame }))

        -- Add a UIListLayout to automatically arrange elements vertically
        local listLayout = Kernel:Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 2),
            Parent = sectionFrame
        })
        sectionJanitor:Add(listLayout)

        -- Give access to destroy for easy deletion
		sectionFrame.Destroy = function()
			sectionJanitor:Clean()
		end

        return sectionFrame
    end

    return Section
end

-- Properties:
--  LayoutOrder: (Optional) The order in which this section appears.
--  ZIndex (Optional) - The ZIndex of this Section
--  Visible (Optional) - If the Section is visible, this will require a Hook; Default is True and Visible

-- Methods:
-- Destroy() - Destroys the section and all its children.
