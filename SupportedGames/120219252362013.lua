
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

        -- SERVICES
        local Players = game:GetService("Players")
        local UserInputService = game:GetService("UserInputService")
        local VirtualInputManager = game:GetService("VirtualInputManager")

        -- BUTTON CREATOR
        local function createFarmButton(name, text, y, icon)
            local button = Instance.new("TextButton")
            button.Name = name
            button.Position = UDim2.fromOffset(10, y)
            button.Size = UDim2.new(1, -20, 0, 40)
            button.BackgroundColor3 = Color3.fromRGB(17, 21, 28)
            button.BorderSizePixel = 0
            button.Text = text
            button.TextColor3 = Color3.fromRGB(220, 225, 235)
            button.TextSize = 13
            button.Font = Enum.Font.GothamMedium
            button.TextXAlignment = Enum.TextXAlignment.Left
            button.AutoButtonColor = false
            button.Parent = page

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 8)
            corner.Parent = button

            local padding = Instance.new("UIPadding")
            padding.PaddingLeft = UDim.new(0, 12)
            padding.Parent = button

            if icon then
                local iconLabel = Instance.new("TextLabel")
                iconLabel.Name = "Icon"
                iconLabel.Size = UDim2.fromOffset(30, 30)
                iconLabel.Position = UDim2.new(1, -38, 0.5, -15)
                iconLabel.BackgroundTransparency = 1
                iconLabel.Text = icon
                iconLabel.TextSize = 19
                iconLabel.Parent = button
            end

            return button
        end

        -- CLICK BUTTON
        local clickButton = createFarmButton(
            "ClickButton",
            "Click",
            55,
            "🖱"
        )

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

        -- WALK BUTTON
        local walkButton = createFarmButton(
            "WalkButton",
            "Walk",
            105,
            "🚶"
        )

        walkButton.MouseButton1Click:Connect(function()
            local player = Players.LocalPlayer
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")

            if not humanoid then
                warn("[BZHUB] Humanoid not found!")
                return
            end

            humanoid:MoveTo(Vector3.new(0, 5.59802532, -45))
        end)

    end)

    if farmButton then
        farmButton.Text = "    FARM"
    end
end

return GameModule
