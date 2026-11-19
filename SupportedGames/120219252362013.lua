
local GameModule = {}

function GameModule.Register(api)
    local farmButton = api.AddCategory("Farm", "FARM", function(page)

        -- FARM TITLE
        local title = Instance.new("TextLabel")
        title.Name = "FarmTitle"
        title.Size = UDim2.new(1, -20, 0, 30)
        title.Position = UDim2.fromOffset(10, 10)
        title.BackgroundTransparency = 1
        title.Text = "Farm"
        title.TextSize = 18
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = page

        -- CLICK BUTTON
        local clickButton = Instance.new("TextButton")
        clickButton.Name = "ClickButton"
        clickButton.Position = UDim2.fromOffset(10, 55)
        clickButton.Size = UDim2.new(1, -20, 0, 40)
        clickButton.BackgroundColor3 = Color3.fromRGB(17, 21, 28)
        clickButton.BorderSizePixel = 0
        clickButton.Text = "Click"
        clickButton.TextColor3 = Color3.fromRGB(220, 225, 235)
        clickButton.TextSize = 13
        clickButton.Font = Enum.Font.GothamMedium
        clickButton.TextXAlignment = Enum.TextXAlignment.Left
        clickButton.AutoButtonColor = false
        clickButton.Parent = page

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = clickButton

        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 12)
        padding.Parent = clickButton

        -- MOUSE ICON
        local mouseIcon = Instance.new("TextLabel")
        mouseIcon.Name = "MouseIcon"
        mouseIcon.Size = UDim2.fromOffset(30, 30)
        mouseIcon.Position = UDim2.new(1, -38, 0.5, -15)
        mouseIcon.BackgroundTransparency = 1
        mouseIcon.Text = "🖱"
        mouseIcon.TextSize = 19
        mouseIcon.Parent = clickButton

        -- CLICK FUNCTION
        local UserInputService = game:GetService("UserInputService")
        local VirtualInputManager = game:GetService("VirtualInputManager")

        clickButton.MouseButton1Click:Connect(function()
            clickButton.TextColor3 = Color3.fromRGB(75, 225, 135)

            task.wait(1)

            if not page.Parent then return end

            local mouseLocation = UserInputService:GetMouseLocation()

            VirtualInputManager:SendMouseButtonEvent(
                mouseLocation.X,
                mouseLocation.Y,
                0,
                true,
                game,
                0
            )

            task.wait(0.05)

            VirtualInputManager:SendMouseButtonEvent(
                mouseLocation.X,
                mouseLocation.Y,
                0,
                false,
                game,
                0
            )

            clickButton.TextColor3 = Color3.fromRGB(220, 225, 235)
        end)
    end)

    if farmButton then
        farmButton.Text = "    FARM"
    end
end

return GameModule
