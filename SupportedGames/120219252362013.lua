
local GameModule = {}

function GameModule.Register(api)
    api.AddCategory("Farm", "FARM", function(page)

        --==================================================
        -- SERVICES
        --==================================================

        local Players = game:GetService("Players")
        local UserInputService = game:GetService("UserInputService")
        local VirtualInputManager = game:GetService("VirtualInputManager")
        local PathfindingService = game:GetService("PathfindingService")

        local player = Players.LocalPlayer

        --==================================================
        -- CONFIGURATION
        --==================================================

        local MIN_DELAY = 1
        local MAX_DELAY = 20

        local CLICK_DELAYS = {
            [1] = 0.125,
            [2] = 0.250,
            [3] = 0.375,
            [4] = 0.500,
            [5] = 0.625,
            [6] = 0.750,
            [7] = 0.875,
            [8] = 1.000,
            [9] = 1.125,
            [10] = 1.250,
            [11] = 1.375,
            [12] = 1.500,
            [13] = 1.625,
            [14] = 1.750,
            [15] = 1.875,
            [16] = 2.000,
            [17] = 2.125,
            [18] = 2.250,
            [19] = 2.375,
            [20] = 2.500
        }

        local AFTER_CLICK_DELAY = 1
        local AFTER_RESPAWN_DELAY = 6

        -- Dynamic waypoint settings
        local WAYPOINT_REACH_DISTANCE = 6
        local WAYPOINT_TIMEOUT = 15
        local MAX_PATH_RETRIES = 3

        local selectedSpeed = 1
        local isEnabled = false
        local isDragging = false
        local actionId = 0

        --==================================================
        -- DEBUG
        --==================================================

        local function debugLog(message)
            print("[BZHUB FARM DEBUG] " .. tostring(message))
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
                "Click Delay: %d | %.3f seconds",
                selectedSpeed,
                CLICK_DELAYS[selectedSpeed]
            )
        end

        local function updateSliderFromInput(input)
            local trackWidth = sliderTrack.AbsoluteSize.X

            if trackWidth <= 0 then
                return
            end

            local relativeX =
                input.Position.X - sliderTrack.AbsolutePosition.X

            local percentage = math.clamp(
                relativeX / trackWidth,
                0,
                1
            )

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
        -- SESSION CHECK
        --==================================================

        local function stillRunning(currentId)
            return isEnabled and actionId == currentId
        end

        --==================================================
        -- CANCELLABLE WAIT
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

        local function performClick(currentId)
            if not stillRunning(currentId) then
                return false
            end

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

            return true
        end

        --==================================================
        -- GET STARTERAREA POSITION
        --==================================================

        local function getStarterAreaPosition()
            local starterArea = workspace:WaitForChild("StarterArea")

            if starterArea:IsA("BasePart") then
                return starterArea.Position
            end

            return starterArea:GetPivot().Position
        end

        --==================================================
        -- GET CHARACTER REFERENCES
        --==================================================

        local function getCharacterReferences()
            local character = player.Character

            if not character then
                return nil, nil, nil
            end

            local humanoid = character:FindFirstChildOfClass("Humanoid")
            local rootPart = character:FindFirstChild("HumanoidRootPart")

            return character, humanoid, rootPart
        end

        --==================================================
        -- DYNAMIC WAYPOINT DISTANCE
        --==================================================

        local function getWaypointDistance(rootPart, waypoint)
            if not rootPart or not waypoint then
                return math.huge
            end

            return (rootPart.Position - waypoint.Position).Magnitude
        end

        local function hasReachedWaypoint(rootPart, waypoint)
            local distance = getWaypointDistance(rootPart, waypoint)

            debugLog(string.format(
                "Waypoint distance: %.2f studs",
                distance
            ))

            return distance <= WAYPOINT_REACH_DISTANCE
        end

        --==================================================
        -- FOLLOW PATH
        --==================================================

        local function followPath(path, character, humanoid, currentId)
            local waypoints = path:GetWaypoints()

            debugLog("Route found. Waypoints: " .. #waypoints)

            for index, waypoint in ipairs(waypoints) do
                if not stillRunning(currentId) then
                    return false
                end

                if player.Character ~= character then
                    return false
                end

                local rootPart = character:FindFirstChild("HumanoidRootPart")

                if not rootPart then
                    return false
                end

                -- Skip waypoints that are already close enough.
                if hasReachedWaypoint(rootPart, waypoint) then
                    debugLog(
                        "Waypoint "
                        .. index
                        .. " already reached. Skipping."
                    )

                    continue
                end

                if waypoint.Action == Enum.PathWaypointAction.Jump then
                    humanoid.Jump = true
                    debugLog("Jumping over obstacle...")
                end

                debugLog(
                    "Moving to waypoint "
                    .. index
                    .. "/"
                    .. #waypoints
                )

                humanoid:MoveTo(waypoint.Position)

                local startTime = os.clock()
                local reached = false

                while stillRunning(currentId) do
                    if player.Character ~= character then
                        return false
                    end

                    rootPart = character:FindFirstChild("HumanoidRootPart")

                    if not rootPart then
                        return false
                    end

                    -- Calculate the real distance every iteration.
                    local distance =
                        getWaypointDistance(rootPart, waypoint)

                    if distance <= WAYPOINT_REACH_DISTANCE then
                        reached = true

                        debugLog(string.format(
                            "Waypoint %d reached at %.2f studs.",
                            index,
                            distance
                        ))

                        break
                    end

                    if os.clock() - startTime >= WAYPOINT_TIMEOUT then
                        break
                    end

                    task.wait(0.1)
                end

                if not stillRunning(currentId) then
                    return false
                end

                if not reached then
                    debugLog(
                        "Waypoint timeout at "
                        .. index
                        .. ". Recalculation required."
                    )

                    return false
                end
            end

            return true
        end

        --==================================================
        -- PATHFINDING MOVEMENT
        --==================================================

        local function moveToStarterArea(currentId)
            debugLog("Finding path to StarterArea...")

            local character, humanoid, rootPart =
                getCharacterReferences()

            if not character or not humanoid or not rootPart then
                error("Character references not found.")
            end

            local targetPosition = getStarterAreaPosition()

            if not stillRunning(currentId) then
                return false
            end

            for attempt = 1, MAX_PATH_RETRIES do
                if not stillRunning(currentId) then
                    return false
                end

                if player.Character ~= character then
                    return false
                end

                rootPart = character:FindFirstChild("HumanoidRootPart")

                if not rootPart then
                    return false
                end

                -- If already near StarterArea, do not move again.
                local targetDistance =
                    (rootPart.Position - targetPosition).Magnitude

                debugLog(string.format(
                    "StarterArea distance: %.2f studs",
                    targetDistance
                ))

                if targetDistance <= WAYPOINT_REACH_DISTANCE then
                    debugLog("Already near StarterArea. No extra movement.")
                    return true
                end

                local path = PathfindingService:CreatePath({
                    AgentRadius = 2,
                    AgentHeight = 5,
                    AgentCanJump = true,
                    AgentCanClimb = true,
                    WaypointSpacing = 4
                })

                debugLog(
                    "Calculating route. Attempt "
                    .. attempt
                    .. "/"
                    .. MAX_PATH_RETRIES
                )

                local computed, computeError = pcall(function()
                    path:ComputeAsync(
                        rootPart.Position,
                        targetPosition
                    )
                end)

                if not computed then
                    debugLog("Path calculation error: " .. tostring(computeError))
                    task.wait(0.5)
                    continue
                end

                if not stillRunning(currentId) then
                    return false
                end

                if path.Status ~= Enum.PathStatus.Success then
                    debugLog(
                        "Pathfinding status: "
                        .. tostring(path.Status)
                    )

                    task.wait(0.5)
                    continue
                end

                local success = followPath(
                    path,
                    character,
                    humanoid,
                    currentId
                )

                if success then
                    rootPart = character:FindFirstChild("HumanoidRootPart")

                    if rootPart then
                        local finalDistance =
                            (rootPart.Position - targetPosition).Magnitude

                        debugLog(string.format(
                            "Final StarterArea distance: %.2f studs",
                            finalDistance
                        ))

                        if finalDistance <= WAYPOINT_REACH_DISTANCE then
                            debugLog("StarterArea reached successfully!")
                            return true
                        end
                    end
                end

                if not stillRunning(currentId) then
                    return false
                end

                debugLog("Recalculating route...")
                task.wait(0.5)
            end

            error("Could not reach StarterArea after path retries.")
        end

        --==================================================
        -- RESET CHARACTER
        --==================================================

        local function resetCharacter(currentId)
            if not stillRunning(currentId) then
                return false
            end

            local oldCharacter = player.Character

            if not oldCharacter then
                error("Character not found before reset.")
            end

            local humanoid =
                oldCharacter:FindFirstChildOfClass("Humanoid")

            if not humanoid then
                error("Humanoid not found before reset.")
            end

            debugLog("Resetting character...")

            humanoid.Health = 0

            while stillRunning(currentId) do
                local newCharacter = player.Character

                if newCharacter and newCharacter ~= oldCharacter then
                    local newHumanoid =
                        newCharacter:FindFirstChildOfClass("Humanoid")

                    local newRoot =
                        newCharacter:FindFirstChild("HumanoidRootPart")

                    if newHumanoid and newRoot
                        and newHumanoid.Health > 0 then

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

                        -- 1. WALK TO STARTERAREA
                        if not moveToStarterArea(currentId) then
                            break
                        end

                        -- 2. SELECTED DELAY
                        local delay = CLICK_DELAYS[selectedSpeed]

                        debugLog(string.format(
                            "Waiting %.3f seconds before clicking.",
                            delay
                        ))

                        if not waitWhileEnabled(delay, currentId) then
                            break
                        end

                        -- 3. CLICK ONCE
                        if not performClick(currentId) then
                            break
                        end

                        -- 4. WAIT 1 SECOND
                        debugLog("Waiting 1 second before reset...")

                        if not waitWhileEnabled(
                            AFTER_CLICK_DELAY,
                            currentId
                        ) then
                            break
                        end

                        -- 5. RESET
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
