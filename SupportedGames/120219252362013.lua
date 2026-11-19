
local GameModule = {}

function GameModule.Register(api)
    local farmButton = api.AddCategory("Farm", "FARM", function(page)

        -- SERVICES
        local Players = game:GetService("Players")
        local UserInputService = game:GetService("UserInputService")
        local VirtualInputManager = game:GetService("VirtualInputManager")

        local player = Players.LocalPlayer
        local TARGET_POSITION = Vector3.new(0, 5.59802532, -45)

        local isRunning = false

        local function debugLog(message)
            print("[BZHUB FARM DEBUG] " .. message)
        end

        debugLog("Farm module loaded.")

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

        -- ACTION BUTTON
        local actionButton = Instance.new("TextButton")
        actionButton.Name = "FarmActionButton"
        actionButton.Position = UDim2.fromOffset(10, 55)
        actionButton.Size = UDim2.new(1, -20, 0, 40)
        actionButton.BackgroundColor3 = Color3.fromRGB(17, 21, 28)
        actionButton.BorderSizePixel = 0
        actionButton.Text = "Walk + Click"
        actionButton.TextColor3 = Color3.fromRGB(220, 225, 235)
        actionButton.TextSize = 13
        actionButton.Font = Enum.Font.GothamMedium
        actionButton.TextXAlignment = Enum.TextXAlignment.Left
        actionButton.AutoButtonColor = false
        actionButton.Parent = page

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = actionButton

        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 12)
        padding.Parent = actionButton

        local icon = Instance.new("TextLabel")
        icon.Name = "MouseIcon"
        icon.Size = UDim2.fromOffset(30, 30)
        icon.Position = UDim2.new(1, -38, 0.5, -15)
        icon.BackgroundTransparency = 1
        icon.Text = "🖱"
        icon.TextSize = 19
        icon.Parent = actionButton

        -- ACTION SYSTEM
        actionButton.MouseButton1Click:Connect(function()

            if isRunning then
                debugLog("Action already running. Ignored.")
                return
            end

            isRunning = true
            debugLog("Action started.")

            actionButton.Text = "Walking..."
            actionButton.TextColor3 = Color3.fromRGB(75, 225, 135)

            task.spawn(function()
                local success, err = pcall(function()

                    -- CHARACTER CHECK
                    debugLog("Checking character...")

                    local character = player.Character
                    if not character then
                        error("Character not found.")
                    end

                    local humanoid = character:FindFirstChildOfClass("Humanoid")
                    local rootPart = character:FindFirstChild("HumanoidRootPart")

                    if not humanoid or not rootPart then
                        error("Humanoid or HumanoidRootPart not found.")
                    end

                    debugLog("Character found.")
                    debugLog("Target: " .. tostring(TARGET_POSITION))

                    -- WALK
                    debugLog("Starting movement...")

                    humanoid:MoveTo(TARGET_POSITION)

                    local reached = humanoid.MoveToFinished:Wait()
                    local distance = (rootPart.Position - TARGET_POSITION).Magnitude

                    if not reached and distance > 5 then
                        error("Movement failed. Distance: " .. tostring(distance))
                    end

                    debugLog("Movement completed! Distance: " .. tostring(distance))

                    -- WAIT
                    actionButton.Text = "Waiting..."
                    debugLog("Waiting 1 second before clicking...")

                    task.wait(1)

                    -- CLICK
                    debugLog("Preparing mouse click...")

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

                    debugLog("MouseButton1 click sent!")
                    debugLog("Action completed successfully.")

                end)

                if not success then
                    warn("[BZHUB FARM ERROR] " .. tostring(err))
                end

                isRunning = false

                if actionButton.Parent then
                    actionButton.Text = "Walk + Click"
                    actionButton.TextColor3 = Color3.fromRGB(220, 225, 235)
                end

                debugLog("Action stopped.")
            end)
        end)

    end)

    if farmButton then
        farmButton.Text = "    FARM"
    end
end

return GameModule
