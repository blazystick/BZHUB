
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
        local RunService = game:GetService("RunService")

        local player = Players.LocalPlayer
        local playerGui = player:WaitForChild("PlayerGui")

        --==================================================
        -- CONFIGURATION
        --==================================================

        local MIN_POWER = 1
        local MAX_POWER = 20

        -- Measured Marker Y reference values
        local POWER_1_Y = 0.995735705
        local POWER_10_Y = 0.555865407
        local POWER_20_Y = 0.00212187553

        local MARKER_TOLERANCE = 0.008
        local DIRECTION_EPSILON = 0.00005
        local MARKER_TIMEOUT = 15

        local AFTER_CLICK_DELAY = 1
        local AFTER_RESPAWN_DELAY = 6

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
                MIN_POWER,
                MAX_POWER
            )

            local percentage =
                (selectedSpeed - MIN_POWER) / (MAX_POWER - MIN_POWER)

            sliderFill.Size = UDim2.new(percentage, 0, 1, 0)
            sliderKnob.Position = UDim2.new(percentage, 0, 0.5, 0)

            sliderLabel.Text = string.format(
                "Power Level: %d",
                selectedSpeed
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

            local value =
                MIN_POWER + percentage * (MAX_POWER - MIN_POWER)

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

                task.wait(0.01)
            end

            return stillRunning(currentId)
        end

        --==================================================
        -- POWER TARGET CALCULATION
        --==================================================

        local function getTargetY(power)
            power = math.clamp(
                math.floor(power + 0.5),
                MIN_POWER,
                MAX_POWER
            )

            if power <= 10 then
                local alpha = (power - 1) / 9

                return POWER_1_Y
                    + (POWER_10_Y - POWER_1_Y) * alpha
            end

            local alpha = (power - 10) / 10

            return POWER_10_Y
                + (POWER_20_Y - POWER_10_Y) * alpha
        end

        --==================================================
        -- FIND THROW MARKER
        --==================================================

        local function getThrowMarker()
            local sequence = playerGui:FindFirstChild("ThrowSequence")

            if not sequence then
                return nil
            end

            local meter = sequence:FindFirstChild("Meter")
            if not meter then
                return nil
            end

            local bar = meter:FindFirstChild("Bar")
            if not bar then
                return nil
            end

            return bar:FindFirstChild("Marker")
        end

        --==================================================
        -- WAIT FOR THROW MARKER
        --==================================================

        local function waitForMarker(currentId)
            debugLog("Waiting for ThrowSequence Marker...")

            local startTime = os.clock()

            while stillRunning(currentId) do
                local marker = getThrowMarker()

                if marker and marker:IsA("GuiObject") then
                    debugLog("ThrowSequence Marker found!")
                    return marker
                end

                if os.clock() - startTime >= MARKER_TIMEOUT then
                    error("ThrowSequence Marker not found. Timed out.")
                end

                task.wait(0.03)
            end

            return nil
        end

        --==================================================
        -- REAL MARKER POWER DETECTION
        --==================================================

        local function waitForSelectedPower(power, currentId)
            local targetY = getTargetY(power)

            debugLog(string.format(
                "Power target: %d | Target Y: %.6f",
                power,
                targetY
            ))

            local marker = waitForMarker(currentId)

            if not marker then
                return false
            end

            local previousY = nil

            local sawDescending = false
            local sawAscending = false

            local startTime = os.clock()

            if power >= 10 then
                debugLog(
                    "Detection mode: FIRST PASS (Y decreasing)."
                )
            else
                debugLog(
                    "Detection mode: SECOND PASS (Y increasing)."
                )
            end

            while stillRunning(currentId) do
                if not marker.Parent then
                    marker = getThrowMarker()

                    if not marker then
                        error("ThrowSequence Marker disappeared.")
                    end
                end

                local currentY = marker.Position.Y.Scale

                if previousY ~= nil then
                    local difference = currentY - previousY

                    -- Detect downward movement.
                    if difference < -DIRECTION_EPSILON then
                        sawDescending = true
                    end

                    -- Detect reversal after reaching the upper end.
                    if sawDescending
                        and difference > DIRECTION_EPSILON then

                        if not sawAscending then
                            sawAscending = true

                            debugLog(
                                "Marker reversed direction. Second pass started."
                            )
                        end
                    end

                    -- POWER 10-20:
                    -- Catch target while Y decreases.
                    if power >= 10 and sawDescending then
                        if currentY <= targetY + MARKER_TOLERANCE then
                            debugLog(string.format(
                                "POWER %d CAUGHT! Y: %.6f",
                                power,
                                currentY
                            ))

                            return true
                        end
                    end

                    -- POWER 1-9:
                    -- Wait for reversal, then catch while Y increases.
                    if power < 10 and sawAscending then
                        if currentY >= targetY - MARKER_TOLERANCE then
                            debugLog(string.format(
                                "POWER %d CAUGHT! Y: %.6f",
                                power,
                                currentY
                            ))

                            return true
                        end
                    end
                end

                previousY = currentY

                if os.clock() - startTime >= MARKER_TIMEOUT then
                    error(string.format(
                        "Power %d detection timed out. Last Y: %.6f | Target Y: %.6f",
                        power,
                        currentY,
                        targetY
                    ))
                end

                RunService.RenderStepped:Wait()
            end

            return false
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

            debugLog("MB1 click completed.")

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

            local humanoid =
                character:FindFirstChildOfClass("Humanoid")

            local rootPart =
                character:FindFirstChild("HumanoidRootPart")

            return character, humanoid, rootPart
        end

        --==================================================
        -- WAYPOINT DISTANCE
        --==================================================

        local function getWaypointDistance(rootPart, waypoint)
            if not rootPart or not waypoint then
                return math.huge
            end

            return (rootPart.Position - waypoint.Position).Magnitude
        end

        local function hasReachedWaypoint(rootPart, waypoint)
            local distance =
                getWaypointDistance(rootPart, waypoint)

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

                local rootPart =
                    character:FindFirstChild("HumanoidRootPart")

                if not rootPart then
                    return false
                end

                if hasReachedWaypoint(rootPart, waypoint) then
                    debugLog(
                        "Waypoint " .. index .. " already reached. Skipping."
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

                    rootPart =
                        character:FindFirstChild("HumanoidRootPart")

                    if not rootPart then
                        return false
                    end

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

                rootPart =
                    character:FindFirstChild("HumanoidRootPart")

                if not rootPart then
                    return false
                end

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
                    debugLog(
                        "Path calculation error: "
                        .. tostring(computeError)
                    )

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
                    rootPart =
                        character:FindFirstChild("HumanoidRootPart")

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

                        -- Capture selected power for this cycle.
                        local targetPower = selectedSpeed

                        debugLog(
                            "Reached StarterArea. Selected power: "
                            .. targetPower
                        )

                        -- 2. WAIT FOR REAL MARKER POSITION
                        if not waitForSelectedPower(
                            targetPower,
                            currentId
                        ) then
                            break
                        end

                        -- 3. CLICK AT SELECTED POWER
                        if not performClick(currentId) then
                            break
                        end

                        -- 4. WAIT BEFORE RESET
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

                        -- 7. WAIT AFTER RESPAWN
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
