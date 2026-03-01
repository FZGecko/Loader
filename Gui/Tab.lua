return function(import)
    local Kernel = import("Core/Kernel")
    local Janitor = import("Core/Janitor")
    local Theme = import("Gui/Theme")
    local Section = import("Gui/Section")

    local Tab = {}
    Tab.__index = Tab

    function Tab.Create(tabName, window, tabContainer, contentContainer)
        local tabJanitor = Janitor.new()

        -- Create Tab Button
        local tabButton = Kernel:Create("TextButton", {
            Size = UDim2.new(0, 100, 1, 0),
            BackgroundColor3 = Theme.Primary,
            Font = Theme.Font,
            TextSize = Theme.FontSize,
            TextColor3 = Theme.Text,
            Text = tabName,
            TextXAlignment = Enum.TextXAlignment.Center,
            LayoutOrder = #tabContainer:GetChildren(),
            BorderSizePixel = 0
        })
        tabJanitor:Add(tabButton)
        tabJanitor:Add(Kernel:Create("UICorner", { CornerRadius = UDim.new(0, Theme.Rounding), Parent = tabButton }))

        -- Create Content Frame (Invisible by default)
        local contentFrame = Kernel:Create("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Theme.Background,
            BorderSizePixel = 0,
            Visible = false,
            ClipsDescendants = true,
            LayoutOrder = #contentContainer:GetChildren()
        })
        tabJanitor:Add(contentFrame)
        tabJanitor:Add(Kernel:Create("UICorner", { CornerRadius = UDim.new(0, Theme.Rounding), Parent = contentFrame }))

        -- Function to Show Tab Content
        local function ShowTab()
            -- Hide all other tabs
            for _, child in ipairs(contentContainer:GetChildren()) do
                child.Visible = false
            end
            contentFrame.Visible = true
        end

        -- Connect button to show tab
        tabJanitor:Add(Kernel:Connect(tabButton.MouseButton1Click, ShowTab))

        -- Add to containers
        tabButton.Parent = tabContainer
        contentFrame.Parent = contentContainer

        -- Give access to destroy for easy deletion
		contentFrame.Destroy = function()
			tabJanitor:Clean()
		end

        return contentFrame
    end

    return Tab
end

-- Properties:
--  LayoutOrder: (Optional) The order in which this tab appears.
--  ZIndex (Optional) - The ZIndex of this Tab
--  Visible (Optional) - If the Tab is visible, this will require a Hook; Default is True and Visible

-- Methods:
-- Destroy() - Destroys the tab and all its children.
-- ShowTab() - shows the tab.
