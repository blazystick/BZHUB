
local GameModule = {}

function GameModule.Register(api)
    api.AddCategory("Farm", "FARM", function(page)

        --==================================================
        -- SERVICES
        --==================================================

        local Players = game:GetService("Players")
        local UserInputService = game:GetService("UserInputService")
        local VirtualInputManager = game:GetService("VirtualInputManager")

        local player = Players.LocalPlayer

        --==================================================
        -- CONFIGURATION
        --==================================================

        local MIN_DELAY = 1
        local MAX_DELAY = 20

        -- HER SEVİYENİN BEKLEME SÜRESİ
        local CLICK_DELAYS = {
            [1] = 0.10,
            [2] = 0.15,
            [3] = 0.25,
            [4] = 0.35,
            [5] = 0.50,
            [6] = 0.65,
            [7] = 0.80,
            [8] = 1.00,
            [9] = 1.20,
            [10] = 1.40,
            [11] = 1.60,
            [12] = 1.80,
            [13] = 2.00,
            [14] = 2.20,
            [15] = 2.50,
            [16] = 2.80,
            [17] = 3.00,
            [18] = 3.50,
            [19] = 4.00,
            [20] = 5.00
        }

        local AFTER_CLICK_DELAY = 1
        local AFTER_RESPAWN_DELAY = 6

        local selectedSpeed = 1
        local isEnabled = false
        local isDragging = false
        local actionId = 0

        --==================================================
        -- DEBUG
        --==================================================

        local function debugLog(message)
            print("[BZHUB FARM DEBUG] " .. message)
        end

        --==================================================
        -- TITLE
        --==================================================

        local title = Instance.new("TextLabel")
        title.Name = "FarmTitle"
        title.Size = UDim2.new(1, -20, 0, 30)
        title.Position = UDim2.fromOffset(10, 10)
        title.BackgroundTransparency = 1
        title.Text = "Farm"
        title.TextSize = 18
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextColor3 = Color3.fromRGB(235, 235, 235)
        title.Font = Enum.Font.GothamMedium
        title.Parent = page

        --==================================================
        -- TOGGLE BUTTON
        --==================================================

        local toggleButton = Instance.new("TextButton")
        toggleButton.Name = "FarmToggle"
        toggleButton.Position = UDim2.fromOffset(10, 55)
        toggleButton.Size = UDim2.new(1, -20, 0, 40)
        toggleButton.BackgroundColor3 = Color3.fromRGB(17, 21, 28)
        toggleButton.BorderSizePixel = 0
        toggleButton.Text = "Farm: OFF"
        toggleButton.TextColor3 = Color3.fromRGB(220, 225, 235)
        toggleButton.TextSize = 13
        toggleButton.Font = Enum.Font.GothamMedium
        toggleButton.AutoButtonColor = false
        toggleButton.Parent = page

        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 8)
        buttonCorner.Parent = toggleButton

        --==================================================
        -- SLIDER CONTAINER
        --==================================================

        local sliderContainer = Instance.new("Frame")
        sliderContainer.Name = "ClickSpeedSlider"
        sliderContainer.Position = UDim2.fromOffset(10, 105)
        sliderContainer.Size = UDim2.new(1, -20, 0, 75)
        sliderContainer.BackgroundColor3 = Color3.fromRGB(17, 21, 28)
        sliderContainer.BorderSizePixel = 0
        sliderContainer.Visible = true
        sliderContainer.Parent = page

        local sliderCorner = Instance.new("UICorner")
        sliderCorner.CornerRadius = UDim.new(0, 8)
        sliderCorner.Parent = sliderContainer

        --==================================================
        -- SLIDER LABEL
        --==================================================

        local sliderLabel = Instance.new("TextLabel")
        sliderLabel.Size = UDim2.new(1, -20, 0, 25)
        sliderLabel.Position = UDim2.fromOffset(10, 5)
        sliderLabel.BackgroundTransparency = 1
        sliderLabel.TextColor3 = Color3.fromRGB(220, 225, 235)
        sliderLabel.TextSize = 12
        sliderLabel.Font = Enum.Font.GothamMedium
        sliderLabel.TextXAlignment = Enum.TextXAlignment.Left
        sliderLabel.Parent = sliderContainer

        --==================================================
        -- SLIDER TRACK
        --==================================================

        local sliderTrack = Instance.new("Frame")
        sliderTrack.Name = "Track"
        sliderTrack.Position = UDim2.new(0, 12, 0, 43)
        sliderTrack.Size = UDim2.new(1, -24, 0, 5)
        sliderTrack.BackgroundColor3 = Color3.fromRGB(45, 52, 65)
        sliderTrack.BorderSizePixel = 0
        sliderTrack.Parent = sliderContainer

        local trackCorner = Instance.new("UICorner")
        trackCorner.CornerRadius = UDim.new(1, 0)
        trackCorner.Parent = sliderTrack

        --==================================================
        -- SLIDER FILL
        --==================================================

        local sliderFill = Instance.new("Frame")
        sliderFill.Size = UDim2.new(0, 0, 1, 0)
        sliderFill.BackgroundColor3 = Color3.fromRGB(65, 190, 130)
        sliderFill.BorderSizePixel = 0
        sliderFill.Parent = sliderTrack

        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(1, 0)
        fillCorner.Parent = sliderFill

        --==================================================
        -- SLIDER KNOB
        --==================================================

        local sliderKnob = Instance.new("TextButton")
        sliderKnob.Name = "Knob"
        sliderKnob.Size = UDim2.fromOffset(15, 15)
        sliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
        sliderKnob.Position = UDim2.new(0, 0, 0.5, 0)
        sliderKnob.BackgroundColor3 = Color3.fromRGB(235, 240, 245)
        sliderKnob.BorderSizePixel = 0
        sliderKnob.Text = ""
        sliderKnob.AutoButtonColor = false
        sliderKnob.Parent = sliderTrack

        local knobCorner = Instance.new("UICorner")
        knobCorner.CornerRadius = UDim.new(1, 0)
        knobCorner.Parent = sliderKnob

        --==================================================
        -- SLIDER UPDATE
        --==================================================

        local function updateSlider(value)
            selectedSpeed = math.clamp(
                math.floor(value + 0.5),
                MIN_DELAY,
                MAX_DELAY
            )

            local percentage = (selectedSpeed - MIN_DELAY)
                / math.max(1, MAX_DELAY - MIN_DELAY)

            sliderFill.Size = UDim2.new(percentage, 0, 1, 0)
            sliderKnob.Position = UDim2.new(percentage, 0, 0.5, 0)

            sliderLabel.Text = string.format(
                "Click Delay: %d | %.2f seconds",
                selectedSpeed,
                CLICK_DELAYS[selectedSpeed]
            )
        end

        local function updateSliderFromInput(input)
            local trackWidth = sliderTrack.AbsoluteSize.X
            local relativeX = input.Position.X - sliderTrack.AbsolutePosition.X

            local percentage = math.clamp(relativeX / trackWidth, 0, 1)

            local value = MIN_DELAY
                + percentage * (MAX_DELAY - MIN_DELAY)

            updateSlider(value)
        end

        sliderTrack.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then

                isDragging = true
                updateSliderFromInput(input)
            end
        end)

        sliderKnob.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then

                isDragging = true
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if not isDragging then
                return
            end

            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then

                updateSliderFromInput(input)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then

                isDragging = false
            end
        end)

        updateSlider(selectedSpeed)

        --==================================================
        -- CHECK ACTIVE SESSION
        --==================================================

        local function stillRunning(currentId)
            return isEnabled and actionId == currentId
        end

        --==================================================
        -- WAIT WITH CANCELLATION
        --==================================================

        local function waitWhileEnabled(seconds, currentId)
            local startTime = os.clock()

            while os.clock() - startTime < seconds do
                if not stillRunning(currentId) then
                    return false
                end

                task.wait(0.05)
            end

            return stillRunning(currentId)
        end

        --==================================================
        -- MOUSE CLICK
        --==================================================

        local function performClick()
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

            debugLog("One click completed.")
        end

        --==================================================
        -- MOVE TO STARTERAREA
        --==================================================

        local function moveToStarterArea(currentId)
            debugLog("Looking for StarterArea...")

            local starterArea = workspace:WaitForChild("StarterArea")

            if not stillRunning(currentId) then
                return false
            end

            local targetPosition

            if starterArea:IsA("BasePart") then
                targetPosition = starterArea.Position
            else
                targetPosition = starterArea:GetPivot().Position
            end

            local character = player.Character

            if not character then
                error("Character not found.")
            end

            local humanoid = character:FindFirstChildOfClass("Humanoid")
            local rootPart = character:FindFirstChild("HumanoidRootPart")

            if not humanoid or not rootPart then
                error("Humanoid or HumanoidRootPart not found.")
            end

            debugLog("Walking to StarterArea...")

            humanoid:MoveTo(targetPosition)

            local startTime = os.clock()

            while stillRunning(currentId) do
                local distance = (rootPart.Position - targetPosition).Magnitude

                if distance <= 5 then
                    debugLog("StarterArea reached!")
                    return true
                end

                if os.clock() - startTime >= 10 then
                    error("Movement timed out.")
                end

                task.wait(0.1)
            end

            return false
        end

        --==================================================
        -- RESET CHARACTER
        --==================================================

        local function resetCharacter(currentId)
            if not stillRunning(currentId) then
                return false
            end

            local character = player.Character

            if not character then
                error("Character not found before reset.")
            end

            local humanoid = character:FindFirstChildOfClass("Humanoid")

            if not humanoid then
                error("Humanoid not found before reset.")
            end

            debugLog("Resetting character...")

            -- Gerçek karakter ölümü
            humanoid.Health = 0

            -- Yeni karakterin yüklenmesini bekle
            while stillRunning(currentId) do
                local newCharacter = player.Character

                if newCharacter and newCharacter ~= character then
                    local newHumanoid =
                        newCharacter:FindFirstChildOfClass("Humanoid")

                    local newRoot =
                        newCharacter:FindFirstChild("HumanoidRootPart")

                    if newHumanoid and newRoot and newHumanoid.Health > 0 then
                        debugLog("Character respawned!")
                        return true
                    end
                end

                task.wait(0.1)
            end

            return false
        end

        --==================================================
        -- MAIN FARM LOOP
        --==================================================

        local function startFarm()
            actionId += 1

            local currentId = actionId

            task.spawn(function()
                local success, err = pcall(function()

                    debugLog("Farm started.")

                    while stillRunning(currentId) do

                        -- 1. WALK
                        if not moveToStarterArea(currentId) then
                            break
                        end

                        -- 2. SELECTED DELAY
                        local delay = CLICK_DELAYS[selectedSpeed]

                        debugLog(string.format(
                            "Waiting %.2f seconds before click.",
                            delay
                        ))

                        if not waitWhileEnabled(delay, currentId) then
                            break
                        end

                        -- 3. CLICK ONCE
                        debugLog("Performing one click...")
                        performClick()

                        -- 4. WAIT 1 SECOND
                        debugLog("Waiting 1 second before reset...")

                        if not waitWhileEnabled(
                            AFTER_CLICK_DELAY,
                            currentId
                        ) then
                            break
                        end

                        -- 5. RESET CHARACTER
                        if not resetCharacter(currentId) then
                            break
                        end

                        -- 6. WALK AGAIN
                        if not moveToStarterArea(currentId) then
                            break
                        end

                        -- 7. WAIT 6 SECONDS
                        debugLog("Waiting 6 seconds...")

                        if not waitWhileEnabled(
                            AFTER_RESPAWN_DELAY,
                            currentId
                        ) then
                            break
                        end

                        debugLog("Cycle completed. Restarting...")
                    end

                end)

                if not success then
                    warn("[BZHUB FARM ERROR] " .. tostring(err))

                    if currentId == actionId then
                        isEnabled = false

                        sliderContainer.Visible = true
                        toggleButton.Text = "Farm: OFF"
                        toggleButton.TextColor3 =
                            Color3.fromRGB(220, 225, 235)
                    end
                end

                debugLog("Farm loop stopped.")
            end)
        end

        --==================================================
        -- TOGGLE
        --==================================================

        toggleButton.MouseButton1Click:Connect(function()

            isEnabled = not isEnabled

            if isEnabled then
                toggleButton.Text = "Farm: ON"
                toggleButton.TextColor3 =
                    Color3.fromRGB(75, 225, 135)

                sliderContainer.Visible = false

                debugLog("Farm enabled.")
                startFarm()

            else
                actionId += 1

                toggleButton.Text = "Farm: OFF"
                toggleButton.TextColor3 =
                    Color3.fromRGB(220, 225, 235)

                sliderContainer.Visible = true

                debugLog("Farm disabled.")
            end
        end)

        debugLog("Farm module loaded.")

    end)
end

return GameModule
