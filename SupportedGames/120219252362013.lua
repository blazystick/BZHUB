--
local GameModule = {}

function GameModule.Register(api)
    local sessionStartedAt = os.clock()
    api.TotalThrows = 0
    api.AddCategory("Automation", "AUTOMATION", function(page)
        -- Store helper functions on one table to stay below Luau's 200-local register limit.
        local helpers = {}

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

        local MIN_POWER = 0
        local MAX_POWER = 20

        local POWER_0_Y = 1.0
        local POWER_10_Y = 0.555865407
        local POWER_20_Y = 0.00212187553

        local MARKER_TOLERANCE = 0.008
        local DIRECTION_EPSILON = 0.00005
        local MARKER_TIMEOUT = 15

        local AFTER_CLICK_DELAY = 1
        local INITIAL_STARTER_WAIT = 6

        local WAYPOINT_REACH_DISTANCE = 6
        local WAYPOINT_TIMEOUT = 15
        local MAX_PATH_RETRIES = 3

        local selectedSpeed = 1
        local isEnabled = false
        local trainEnabled = false
        local autoEquipBestEnabled = false
        local autoEquipBestWorkerId = 0
        local isDragging = false
        local actionId = 0
        local trainActionId = 0
        local activeHudMode = "throw"
        local startTrain
        local stopTrain

        --  lk ba lang  ta 6 saniye bekle.
        -- Sonraki d ng lerde ThrowReadyAt beklenecek.
        local firstCycle = true

        -- AFK FARM orchestration
        local autoFarmRunning = false
        local autoFarmWorkerId = 0
        local autoFarmThrowCount = 0
        local autoFarmThrowDone = false
        local autoFarmThrowTarget = 3
        local autoFarmTrainingSeconds = 60
        local autoFarmFirstCycle = true

        --==================================================
        -- DEBUG
        --==================================================

        helpers.debugLog = function(message)
            print("[BZHUB FARM DEBUG] " .. tostring(message))
        end

        --==================================================
        -- AUTO THROW UI
        --==================================================

        local TweenService = game:GetService("TweenService")
        local LocalizationService = game:GetService("LocalizationService")

        local ACCENT = Color3.fromRGB(45, 155, 255)
        local ACCENT_BRIGHT = Color3.fromRGB(85, 190, 255)
        local PANEL = Color3.fromRGB(15, 20, 29)
        local CARD = Color3.fromRGB(17, 23, 33)
        local TEXT = Color3.fromRGB(225, 233, 245)
        local MUTED = Color3.fromRGB(145, 160, 180)

        local translations = {
            English = {
                title = "AUTO FARM",
                power = "Power Level",
                info = "i",
                infoTitle = "AUTO THROW - IMPORTANT NOTES",
                infoHint = "  The 6-second starting wait is normal.\n  Do not move or click while the automation is waiting.\n  Cooldown delays are part of the game.\n  Keep the game open until the throw is complete.",
                idle = "Auto Throw is currently disabled.",
                starting = "Starting the automation...",
                moving = "Moving to the throw area. Please do not interfere.",
                initialWait = "Waiting 6 seconds at the starting area. Please leave it untouched.",
                cooldown = "Waiting for the throw cooldown / protection. Do not touch anything; movement will resume when the timer ends.",
                marker = "Waiting for the selected power level in the throw meter.",
                throwing = "Power reached. Sending the throw input...",
                resetting = "Throw completed. Resetting the character...",
                stopped = "Auto Throw has been stopped.",
                error = "An error occurred: ",
                enabled = "ENABLED",
                disabled = "DISABLED",
                close = "CLOSE"
            },
            Turkish = {
                title = "AUTO FARM",
                power = "G   Seviyesi",
                info = "i",
                infoTitle = "AUTO THROW - IMPORTANT NOTES",
                infoHint = "  The 6-second starting wait is normal.\n  Do not move or click while the automation is waiting.\n  Cooldown delays are part of the game.\n  Keep the game open until the throw is complete.",
                idle = "Auto Throw  u anda kapal .",
                starting = "Otomasyon ba lat l yor...",
                moving = "At   alan na y r n yor. L tfen m dahale etmeyin.",
                initialWait = "Ba lang   alan nda 6 saniye bekleniyor. L tfen dokunmay n.",
                cooldown = "At   bekleme s resi / koruma bitene kadar bekleniyor. Hi bir  eye dokunmay n; s re bitince hareket ba layacak.",
                marker = "At   g stergesinde se ilen g   seviyesi bekleniyor.",
                throwing = "Se ilen g   yakaland . At   girdisi g nderiliyor...",
                resetting = "At   tamamland . Karakter s f rlan yor...",
                stopped = "Auto Throw durduruldu.",
                error = "Bir hata olu tu: ",
                enabled = "A IK",
                disabled = "KAPALI",
                close = "KAPAT"
            },
            Russian = {
                title = "???? ??????",
                power = "??????? ????",
                info = "i",
                infoTitle = "AUTO THROW - IMPORTANT NOTES",
                infoHint = "  The 6-second starting wait is normal.\n  Do not move or click while the automation is waiting.\n  Cooldown delays are part of the game.\n  Keep the game open until the throw is complete.",
                idle = "?????????? ?????? ????????.",
                starting = "?????? ?????????????...",
                moving = "???????? ???? ? ???? ??????. ??????????, ?? ????????????.",
                initialWait = "???????? 6 ?????? ? ????????? ????. ??????????, ?? ???????? ??????.",
                cooldown = "???????? ??????????? / ?????? ??????. ?????? ?? ????????; ???????? ???????? ????? ????????? ???????.",
                marker = "???????? ?????????? ?????? ???? ?? ?????????? ??????.",
                throwing = "?????? ???? ??????????. ???????? ??????? ??????...",
                resetting = "?????? ????????. ???????? ???????????????...",
                stopped = "?????????? ??????????.",
                error = "????????? ??????: ",
                enabled = "???",
                disabled = "????",
                close = "???????"
            }
        }

        helpers.getLanguage = function()
            return "English"
        end

        helpers.tr = function(key)
            local language = translations[helpers.getLanguage()] or translations.English
            return language[key] or translations.English[key] or key
        end

        helpers.makeTween = function(object, duration, properties, style, direction)
            local tween = TweenService:Create(
                object,
                TweenInfo.new(
                    duration,
                    style or Enum.EasingStyle.Quint,
                    direction or Enum.EasingDirection.Out
                ),
                properties
            )
            tween:Play()
            return tween
        end

        local statusText
        local currentStatus = "idle"
        local currentStatusDetail = ""
        local hudGui
        local hudFill
        local hudStateText
        local hudInfoText
        local hudProgressTween
        local hudVisible = false

        helpers.setHudProgress = function(progress)
            if not hudFill or not hudFill.Parent then return end

            if hudProgressTween then
                hudProgressTween:Cancel()
                hudProgressTween = nil
            end

            local actualProgress = (type(progress) == "number") and progress or 0
            hudFill.Size = UDim2.new(math.clamp(actualProgress, 0, 1), 0, 1, 0)
        end

        helpers.updateHud = function(key, detail, progress)
            if not hudGui then return end
            if autoFarmRunning then
                hudGui.Enabled = false
                hudVisible = false
                return
            end
            if hudStateText then
                local mode = (activeHudMode == "train") and "AUTO TRAIN" or "AUTO THROW"
                local enabled = (activeHudMode == "train") and trainEnabled or isEnabled
                hudStateText.Text = mode .. "   /   " .. (enabled and "ON" or "OFF")
            end
            if hudInfoText then
                local message
                if key == "cooldown" then
                    message = detail ~= "" and ("Protection cooldown: " .. detail) or "Waiting for protection cooldown..."
                elseif key == "initialWait" then
                    message = detail ~= "" and ("Starting wait: " .. detail) or "Waiting at starting position..."
                elseif key == "moving" then
                    message = "Walking to position..."
                elseif key == "marker" then
                    message = "Waiting for throw power..."
                elseif key == "throwing" then
                    message = "Throwing..."
                elseif key == "resetting" then
                    message = "Respawning character..."
                elseif key == "starting" then
                    message = "Starting Auto Throw..."
                elseif key == "trainMoving" then
                    message = "Walking to TrainingSpot..."
                elseif key == "training" then
                    message = "Training is active."
                elseif key == "trainStopping" then
                    message = "Leaving the training area..."
                elseif key == "trainStopped" then
                    message = "Auto Train stopped."
                elseif key == "trainError" then
                    message = "Auto Train error: " .. tostring(detail or "")
                elseif key == "stopped" then
                    message = "Auto Throw stopped."
                elseif key == "error" then
                    message = "Error: " .. tostring(detail or "")
                else
                    message = helpers.tr(key)
                end
                hudInfoText.Text = message
            end
            local active = (activeHudMode == "train" and trainEnabled)
                or (activeHudMode == "throw" and isEnabled)

            if active then
                hudGui.Enabled = true
                hudVisible = true
                helpers.setHudProgress(progress)
            else
                hudGui.Enabled = false
                hudVisible = false
                if hudProgressTween then
                    hudProgressTween:Cancel()
                    hudProgressTween = nil
                end
                if hudFill and hudFill.Parent then
                    hudFill.Size = UDim2.new(0, 0, 1, 0)
                end
            end
        end

        helpers.setStatus = function(key, detail, progress)
            currentStatus = key
            currentStatusDetail = detail or ""

            helpers.updateHud(key, currentStatusDetail, progress)
        end

        --==================================================
        -- VERTICAL SCROLL CONTAINER (mouse wheel + middle mouse drag)
        --==================================================

        local farmScroll = Instance.new("ScrollingFrame")
        farmScroll.Name = "FarmVerticalScroll"
        farmScroll.Position = UDim2.fromOffset(0, 0)
        farmScroll.Size = UDim2.new(1, 0, 1, 0)
        farmScroll.BackgroundTransparency = 1
        farmScroll.BorderSizePixel = 0
        farmScroll.ScrollBarThickness = 4
        farmScroll.ScrollBarImageColor3 = Color3.fromRGB(105, 125, 150)
        farmScroll.ScrollingDirection = Enum.ScrollingDirection.Y
        farmScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        farmScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        farmScroll.Active = true
        farmScroll.Parent = page

        local farmContent = Instance.new("Frame")
        farmContent.Name = "FarmContent"
        farmContent.BackgroundTransparency = 1
        farmContent.Size = UDim2.new(1, -8, 0, 0)
        farmContent.AutomaticSize = Enum.AutomaticSize.Y
        farmContent.Parent = farmScroll

        local farmList = Instance.new("UIListLayout")
        farmList.Name = "VerticalLayout"
        farmList.SortOrder = Enum.SortOrder.LayoutOrder
        farmList.Padding = UDim.new(0, 10)
        farmList.Parent = farmContent

        local farmPadding = Instance.new("UIPadding")
        farmPadding.PaddingTop = UDim.new(0, 10)
        farmPadding.PaddingBottom = UDim.new(0, 12)
        farmPadding.PaddingLeft = UDim.new(0, 10)
        farmPadding.PaddingRight = UDim.new(0, 10)
        farmPadding.Parent = farmContent

        local middleDrag = false
        local middleDragStartY = 0
        local middleCanvasStartY = 0
        farmScroll.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton3 then
                middleDrag = true
                middleDragStartY = input.Position.Y
                middleCanvasStartY = farmScroll.CanvasPosition.Y
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if middleDrag and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position.Y - middleDragStartY
                local maxY = math.max(0, farmScroll.AbsoluteCanvasSize.Y - farmScroll.AbsoluteWindowSize.Y)
                farmScroll.CanvasPosition = Vector2.new(0, math.clamp(middleCanvasStartY - delta, 0, maxY))
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton3 then
                middleDrag = false
            end
        end)

        local farmHeader = Instance.new("Frame")
        farmHeader.Name = "AutoFarmHeader"
        farmHeader.Size = UDim2.new(1, 0, 0, 32)
        farmHeader.BackgroundTransparency = 1
        farmHeader.LayoutOrder = 1
        farmHeader.Parent = farmContent

        local title = Instance.new("TextLabel")
        title.Name = "AutoFarmTitle"
        title.Size = UDim2.new(1, -112, 1, 0)
        title.Position = UDim2.new(0, 0, 0, 0)
        title.BackgroundTransparency = 1
        title.Text = "AFK FARM"
        title.TextSize = 18
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextColor3 = TEXT
        title.Font = Enum.Font.GothamBold
        title.Parent = farmHeader

        local autoFarmButton = Instance.new("TextButton")
        autoFarmButton.Name = "AutoFarmStartStop"
        autoFarmButton.AnchorPoint = Vector2.new(1, 0.5)
        autoFarmButton.Position = UDim2.new(1, 0, 0.5, 0)
        autoFarmButton.Size = UDim2.fromOffset(92, 27)
        autoFarmButton.BackgroundColor3 = Color3.fromRGB(12, 25, 65)
        autoFarmButton.BorderSizePixel = 0
        autoFarmButton.Text = "START"
        autoFarmButton.TextColor3 = Color3.fromRGB(235, 250, 255)
        autoFarmButton.TextSize = 11
        autoFarmButton.Font = Enum.Font.GothamBold
        autoFarmButton.AutoButtonColor = false
        autoFarmButton.ZIndex = 5
        autoFarmButton.Parent = farmHeader

        local autoFarmButtonCorner = Instance.new("UICorner")
        autoFarmButtonCorner.CornerRadius = UDim.new(0, 8)
        autoFarmButtonCorner.Parent = autoFarmButton
        local autoFarmGradient = Instance.new("UIGradient")
        autoFarmGradient.Name = "AutoFarmGradient"

        local normalGradient = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 20, 65)),
            ColorSequenceKeypoint.new(0.35, Color3.fromRGB(15, 75, 160)),
            ColorSequenceKeypoint.new(0.7, Color3.fromRGB(15, 145, 210)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 220, 240))
        })

        local hoverGradient = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 55, 130)),
            ColorSequenceKeypoint.new(0.35, Color3.fromRGB(20, 125, 220)),
            ColorSequenceKeypoint.new(0.7, Color3.fromRGB(25, 195, 245)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 245, 255))
        })

        autoFarmGradient.Color = normalGradient
        autoFarmGradient.Rotation = 0
        autoFarmGradient.Offset = Vector2.new(-0.35, 0)
        autoFarmGradient.Parent = autoFarmButton

        local gradientTweenInfo = TweenInfo.new(
            5,
            Enum.EasingStyle.Sine,
            Enum.EasingDirection.InOut,
            -1,
            true
        )

        local gradientTween = TweenService:Create(
            autoFarmGradient,
            gradientTweenInfo,
            {Offset = Vector2.new(0.35, 0)}
        )

        gradientTween:Play()
        -- Layered strokes create a soft neon halo around the button itself.
        helpers.autoFarmGlowOuter = Instance.new("Frame")
        helpers.autoFarmGlowOuter.Name = "NeonGlowOuter"
        helpers.autoFarmGlowOuter.AnchorPoint = Vector2.new(0.5, 0.5)
        helpers.autoFarmGlowOuter.Position = UDim2.fromScale(0.5, 0.5)
        helpers.autoFarmGlowOuter.Size = UDim2.new(1, 18, 1, 16)
        helpers.autoFarmGlowOuter.BackgroundTransparency = 1
        helpers.autoFarmGlowOuter.BorderSizePixel = 0
        helpers.autoFarmGlowOuter.ZIndex = 2
        helpers.autoFarmGlowOuter.Parent = autoFarmButton
        helpers.autoFarmGlowOuterCorner = Instance.new("UICorner")
        helpers.autoFarmGlowOuterCorner.CornerRadius = UDim.new(0, 13)
        helpers.autoFarmGlowOuterCorner.Parent = helpers.autoFarmGlowOuter
        helpers.autoFarmGlowOuterStroke = Instance.new("UIStroke")
        helpers.autoFarmGlowOuterStroke.Color = Color3.fromRGB(0, 145, 255)
        helpers.autoFarmGlowOuterStroke.Thickness = 8
        helpers.autoFarmGlowOuterStroke.Transparency = 1
        helpers.autoFarmGlowOuterStroke.Parent = helpers.autoFarmGlowOuter

        helpers.autoFarmGlowInner = Instance.new("Frame")
        helpers.autoFarmGlowInner.Name = "NeonGlowInner"
        helpers.autoFarmGlowInner.AnchorPoint = Vector2.new(0.5, 0.5)
        helpers.autoFarmGlowInner.Position = UDim2.fromScale(0.5, 0.5)
        helpers.autoFarmGlowInner.Size = UDim2.new(1, 8, 1, 8)
        helpers.autoFarmGlowInner.BackgroundTransparency = 1
        helpers.autoFarmGlowInner.BorderSizePixel = 0
        helpers.autoFarmGlowInner.ZIndex = 3
        helpers.autoFarmGlowInner.Parent = autoFarmButton
        helpers.autoFarmGlowInnerCorner = Instance.new("UICorner")
        helpers.autoFarmGlowInnerCorner.CornerRadius = UDim.new(0, 11)
        helpers.autoFarmGlowInnerCorner.Parent = helpers.autoFarmGlowInner
        helpers.autoFarmGlowInnerStroke = Instance.new("UIStroke")
        helpers.autoFarmGlowInnerStroke.Color = Color3.fromRGB(70, 190, 255)
        helpers.autoFarmGlowInnerStroke.Thickness = 4
        helpers.autoFarmGlowInnerStroke.Transparency = 1
        helpers.autoFarmGlowInnerStroke.Parent = helpers.autoFarmGlowInner

        helpers.autoFarmButtonStroke = Instance.new("UIStroke")
        helpers.autoFarmButtonStroke.Color = Color3.fromRGB(45, 155, 255)
        helpers.autoFarmButtonStroke.Thickness = 1
        helpers.autoFarmButtonStroke.Transparency = 0.72
        helpers.autoFarmButtonStroke.Parent = autoFarmButton

        helpers.autoFarmButtonScale = Instance.new("UIScale")
        helpers.autoFarmButtonScale.Scale = 1
        helpers.autoFarmButtonScale.Parent = autoFarmButton
        print("AFK BUTTON HOVER ACTIVE")
        autoFarmButton.MouseEnter:Connect(function()
            -- Smooth hover gradient transition
            TweenService:Create(
                autoFarmGradient,
                TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                {
                    Color = hoverGradient
                }
            ):Play()

            -- Button scale
            TweenService:Create(
                helpers.autoFarmButtonScale,
                TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                {
                    Scale = 1.09
                }
            ):Play()

            -- Main neon stroke
            TweenService:Create(
                helpers.autoFarmButtonStroke,
                TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                {
                    Transparency = 0.02,
                    Thickness = 2
                }
            ):Play()

            -- Outer glow
            TweenService:Create(
                helpers.autoFarmGlowOuterStroke,
                TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                {
                    Transparency = 0.28,
                    Thickness = 10
                }
            ):Play()

            -- Inner glow
            TweenService:Create(
                helpers.autoFarmGlowInnerStroke,
                TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                {
                    Transparency = 0.12,
                    Thickness = 5
                }
            ):Play()
        end)

        autoFarmButton.MouseLeave:Connect(function()
            -- Smooth return to normal gradient
            TweenService:Create(
                autoFarmGradient,
                TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                {
                    Color = normalGradient
                }
            ):Play()

            -- Reset button scale
            TweenService:Create(
                helpers.autoFarmButtonScale,
                TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                {
                    Scale = 1
                }
            ):Play()

            -- Main neon stroke
            TweenService:Create(
                helpers.autoFarmButtonStroke,
                TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                {
                    Transparency = 0.72,
                    Thickness = 1
                }
            ):Play()

            -- Outer glow
            TweenService:Create(
                helpers.autoFarmGlowOuterStroke,
                TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                {
                    Transparency = 1,
                    Thickness = 8
                }
            ):Play()

            -- Inner glow
            TweenService:Create(
                helpers.autoFarmGlowInnerStroke,
                TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                {
                    Transparency = 1,
                    Thickness = 4
                }
            ):Play()
        end)
        autoFarmButton.MouseButton1Down:Connect(function()
            TweenService:Create(helpers.autoFarmButtonScale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Scale = 0.96
            }):Play()
        end)

        autoFarmButton.MouseButton1Up:Connect(function()
            TweenService:Create(helpers.autoFarmButtonScale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Scale = 1.09
            }):Play()
        end)

        -- Main combined card: toggle + power slider.
        local mainCard = Instance.new("Frame")
        mainCard.Name = "AutoThrowCard"
        mainCard.Position = UDim2.new(0, 0, 0, 0)
        mainCard.Size = UDim2.new(1, 0, 0, 132)
        mainCard.BackgroundColor3 = CARD
        mainCard.BorderSizePixel = 0
        mainCard.LayoutOrder = 2
        mainCard.Parent = farmContent

        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 12)
        cardCorner.Parent = mainCard

        local cardStroke = Instance.new("UIStroke")
        cardStroke.Color = Color3.fromRGB(242, 72, 82)
        cardStroke.Thickness = 1.35
        cardStroke.Transparency = 0.28
        cardStroke.Parent = mainCard

        local cardGradient = Instance.new("UIGradient")
        cardGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 31, 47)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 19, 28))
        })
        cardGradient.Rotation = 15
        cardGradient.Parent = mainCard

        local toggleLabel = Instance.new("TextLabel")
        toggleLabel.Name = "AutoThrowLabel"
        toggleLabel.Position = UDim2.fromOffset(12, 8)
        toggleLabel.Size = UDim2.fromOffset(112, 29)
        toggleLabel.BackgroundColor3 = Color3.fromRGB(75, 31, 42)
        toggleLabel.BackgroundTransparency = 0.05
        toggleLabel.Text = "Auto Throw"
        toggleLabel.TextColor3 = Color3.fromRGB(255, 190, 198)
        toggleLabel.TextStrokeColor3 = Color3.fromRGB(255, 55, 78)
        toggleLabel.TextStrokeTransparency = 0.48
        toggleLabel.TextSize = 14
        toggleLabel.Font = Enum.Font.GothamBold
        toggleLabel.TextXAlignment = Enum.TextXAlignment.Left
        toggleLabel.Parent = mainCard
        local throwLabelPadding = Instance.new("UIPadding")
        throwLabelPadding.PaddingLeft = UDim.new(0, 10)
        throwLabelPadding.Parent = toggleLabel
        local throwLabelGradient = Instance.new("UIGradient")
        throwLabelGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(91, 31, 48)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(43, 22, 36))
        })
        throwLabelGradient.Rotation = 0
        throwLabelGradient.Parent = toggleLabel
        local throwLabelCorner = Instance.new("UICorner")
        throwLabelCorner.CornerRadius = UDim.new(0, 8)
        throwLabelCorner.Parent = toggleLabel
        local throwLabelStroke = Instance.new("UIStroke")
        throwLabelStroke.Color = Color3.fromRGB(242, 72, 82)
        throwLabelStroke.Transparency = 0.35
        throwLabelStroke.Thickness = 1
        throwLabelStroke.Parent = toggleLabel

        local infoButton = Instance.new("TextButton")
        infoButton.Name = "InfoButton"
        infoButton.AnchorPoint = Vector2.new(1, 0)
        infoButton.Position = UDim2.new(1, -87, 0, 10)
        infoButton.Size = UDim2.fromOffset(29, 29)
        infoButton.BackgroundColor3 = Color3.fromRGB(24, 42, 62)
        infoButton.BorderSizePixel = 0
        infoButton.Text = "i"
        infoButton.TextColor3 = ACCENT_BRIGHT
        infoButton.TextSize = 15
        infoButton.Font = Enum.Font.GothamBold
        infoButton.AutoButtonColor = false
        infoButton.Parent = mainCard

        local infoCorner = Instance.new("UICorner")
        infoCorner.CornerRadius = UDim.new(1, 0)
        infoCorner.Parent = infoButton

        local infoStroke = Instance.new("UIStroke")
        infoStroke.Color = ACCENT
        infoStroke.Transparency = 0.25
        infoStroke.Thickness = 1
        infoStroke.Parent = infoButton

        local switchButton = Instance.new("TextButton")
        switchButton.Name = "AutoThrowSwitch"
        switchButton.AnchorPoint = Vector2.new(1, 0)
        switchButton.Position = UDim2.new(1, -12, 0, 10)
        switchButton.Size = UDim2.fromOffset(70, 29)
        switchButton.BackgroundColor3 = Color3.fromRGB(43, 53, 68)
        switchButton.BorderSizePixel = 0
        switchButton.Text = ""
        switchButton.AutoButtonColor = false
        switchButton.Parent = mainCard

        local switchCorner = Instance.new("UICorner")
        switchCorner.CornerRadius = UDim.new(1, 0)
        switchCorner.Parent = switchButton

        local switchStroke = Instance.new("UIStroke")
        switchStroke.Color = ACCENT
        switchStroke.Transparency = 0.55
        switchStroke.Thickness = 1
        switchStroke.Parent = switchButton

        local switchKnob = Instance.new("Frame")
        switchKnob.Name = "Knob"
        switchKnob.Position = UDim2.fromOffset(3, 3)
        switchKnob.Size = UDim2.fromOffset(23, 23)
        switchKnob.BackgroundColor3 = Color3.fromRGB(220, 230, 242)
        switchKnob.BorderSizePixel = 0
        switchKnob.Parent = switchButton

        local switchKnobCorner = Instance.new("UICorner")
        switchKnobCorner.CornerRadius = UDim.new(1, 0)
        switchKnobCorner.Parent = switchKnob

        local stateLabel = Instance.new("TextLabel")
        stateLabel.Name = "StateLabel"
        stateLabel.AnchorPoint = Vector2.new(1, 0)
        stateLabel.Position = UDim2.new(1, -13, 0, 43)
        stateLabel.Size = UDim2.fromOffset(95, 16)
        stateLabel.BackgroundTransparency = 1
        stateLabel.Text = helpers.tr("disabled")
        stateLabel.TextColor3 = MUTED
        stateLabel.TextSize = 9
        stateLabel.Font = Enum.Font.GothamBold
        stateLabel.TextXAlignment = Enum.TextXAlignment.Right
        stateLabel.Parent = mainCard

        local separator = Instance.new("Frame")
        separator.Position = UDim2.new(0, 12, 0, 63)
        separator.Size = UDim2.new(1, -24, 0, 1)
        separator.BackgroundColor3 = Color3.fromRGB(48, 62, 80)
        separator.BackgroundTransparency = 0.35
        separator.BorderSizePixel = 0
        separator.Parent = mainCard

        -- Power slider is integrated into the same card.
        local sliderContainer = Instance.new("CanvasGroup")
        sliderContainer.Name = "ClickSpeedSlider"
        sliderContainer.Position = UDim2.fromOffset(12, 69)
        sliderContainer.Size = UDim2.new(1, -24, 0, 54)
        sliderContainer.BackgroundTransparency = 1
        sliderContainer.Parent = mainCard

        local sliderLabel = Instance.new("TextLabel")
        sliderLabel.Name = "PowerLabel"
        sliderLabel.Size = UDim2.new(1, 0, 0, 18)
        sliderLabel.Position = UDim2.fromOffset(0, 0)
        sliderLabel.BackgroundTransparency = 1
        sliderLabel.TextColor3 = TEXT
        sliderLabel.TextSize = 11
        sliderLabel.Font = Enum.Font.GothamMedium
        sliderLabel.TextXAlignment = Enum.TextXAlignment.Left
        sliderLabel.Parent = sliderContainer

        local sliderTrack = Instance.new("Frame")
        sliderTrack.Name = "Track"
        sliderTrack.Position = UDim2.new(0, 0, 0, 34)
        sliderTrack.Size = UDim2.new(1, 0, 0, 5)
        sliderTrack.BackgroundColor3 = Color3.fromRGB(45, 57, 73)
        sliderTrack.BorderSizePixel = 0
        sliderTrack.Parent = sliderContainer

        local trackCorner = Instance.new("UICorner")
        trackCorner.CornerRadius = UDim.new(1, 0)
        trackCorner.Parent = sliderTrack

        local sliderFill = Instance.new("Frame")
        sliderFill.Name = "Fill"
        sliderFill.Size = UDim2.new(0, 0, 1, 0)
        sliderFill.BackgroundColor3 = ACCENT
        sliderFill.BorderSizePixel = 0
        sliderFill.Parent = sliderTrack

        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(1, 0)
        fillCorner.Parent = sliderFill

        local sliderKnob = Instance.new("TextButton")
        sliderKnob.Name = "Knob"
        sliderKnob.Size = UDim2.fromOffset(15, 15)
        sliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
        sliderKnob.Position = UDim2.new(0, 0, 0.5, 0)
        sliderKnob.BackgroundColor3 = Color3.fromRGB(238, 245, 255)
        sliderKnob.BorderSizePixel = 0
        sliderKnob.Text = ""
        sliderKnob.AutoButtonColor = false
        sliderKnob.Parent = sliderTrack

        local knobCorner = Instance.new("UICorner")
        knobCorner.CornerRadius = UDim.new(1, 0)
        knobCorner.Parent = sliderKnob

        --==================================================
        -- AUTO TRAIN CARD (UI CONTROL)
        --==================================================

        local TRAIN_RED = Color3.fromRGB(242, 72, 82)
        local TRAIN_RED_BRIGHT = Color3.fromRGB(255, 105, 112)
        local auto2xEnabled = false
        local auto2xWorkerId = 0

        local trainCard = Instance.new("Frame")
        trainCard.Name = "AutoTrainCard"
        trainCard.Position = UDim2.new(0, 0, 0, 0)
        trainCard.Size = UDim2.new(1, 0, 0, 62)
        trainCard.BackgroundColor3 = CARD
        trainCard.BorderSizePixel = 0
        trainCard.ClipsDescendants = true
        trainCard.LayoutOrder = 3
        trainCard.Parent = farmContent

        local trainCardCorner = Instance.new("UICorner")
        trainCardCorner.CornerRadius = UDim.new(0, 12)
        trainCardCorner.Parent = trainCard

        local trainCardStroke = Instance.new("UIStroke")
        trainCardStroke.Color = TRAIN_RED
        trainCardStroke.Thickness = 1.35
        trainCardStroke.Transparency = 0.3
        trainCardStroke.Parent = trainCard

        local trainCardGradient = Instance.new("UIGradient")
        trainCardGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(42, 23, 31)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(19, 18, 27))
        })
        trainCardGradient.Rotation = 15
        trainCardGradient.Parent = trainCard

        local trainLabel = Instance.new("TextLabel")
        trainLabel.Name = "AutoTrainLabel"
        trainLabel.Position = UDim2.fromOffset(12, 8)
        trainLabel.Size = UDim2.fromOffset(105, 29)
        trainLabel.BackgroundColor3 = Color3.fromRGB(75, 31, 42)
        trainLabel.BackgroundTransparency = 0.05
        trainLabel.Text = "Auto Train"
        trainLabel.TextColor3 = Color3.fromRGB(255, 190, 198)
        trainLabel.TextStrokeColor3 = Color3.fromRGB(255, 55, 78)
        trainLabel.TextStrokeTransparency = 0.48
        trainLabel.TextSize = 14
        trainLabel.Font = Enum.Font.GothamBold
        trainLabel.TextXAlignment = Enum.TextXAlignment.Left
        trainLabel.Parent = trainCard
        local trainLabelPadding = Instance.new("UIPadding")
        trainLabelPadding.PaddingLeft = UDim.new(0, 10)
        trainLabelPadding.Parent = trainLabel
        local trainLabelGradient = Instance.new("UIGradient")
        trainLabelGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(91, 31, 48)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(43, 22, 36))
        })
        trainLabelGradient.Rotation = 0
        trainLabelGradient.Parent = trainLabel
        local trainLabelCorner = Instance.new("UICorner")
        trainLabelCorner.CornerRadius = UDim.new(0, 8)
        trainLabelCorner.Parent = trainLabel
        local trainLabelStroke = Instance.new("UIStroke")
        trainLabelStroke.Color = TRAIN_RED
        trainLabelStroke.Transparency = 0.35
        trainLabelStroke.Thickness = 1
        trainLabelStroke.Parent = trainLabel

        local trainStateLabel = Instance.new("TextLabel")
        trainStateLabel.Name = "TrainState"
        trainStateLabel.AnchorPoint = Vector2.new(1, 0)
        trainStateLabel.Position = UDim2.new(1, -13, 0, 43)
        trainStateLabel.Size = UDim2.fromOffset(95, 16)
        trainStateLabel.BackgroundTransparency = 1
        trainStateLabel.Text = "OFF"
        trainStateLabel.TextColor3 = MUTED
        trainStateLabel.TextSize = 9
        trainStateLabel.Font = Enum.Font.GothamBold
        trainStateLabel.TextXAlignment = Enum.TextXAlignment.Right
        trainStateLabel.Parent = trainCard

        helpers.makeTrainSwitch = function(name, parent, position, size)
            local button = Instance.new("TextButton")
            button.Name = name
            button.AnchorPoint = Vector2.new(1, 0)
            button.Position = position
            button.Size = size
            button.BackgroundColor3 = Color3.fromRGB(53, 48, 59)
            button.BorderSizePixel = 0
            button.Text = ""
            button.AutoButtonColor = false
            button.Parent = parent

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(1, 0)
            corner.Parent = button

            local outline = Instance.new("UIStroke")
            outline.Color = TRAIN_RED
            outline.Transparency = 0.48
            outline.Thickness = 1
            outline.Parent = button

            local knob = Instance.new("Frame")
            knob.Name = "Knob"
            knob.Position = UDim2.fromOffset(3, 3)
            knob.Size = UDim2.fromOffset(23, 23)
            knob.BackgroundColor3 = Color3.fromRGB(235, 237, 244)
            knob.BorderSizePixel = 0
            knob.Parent = button

            local knobCorner = Instance.new("UICorner")
            knobCorner.CornerRadius = UDim.new(1, 0)
            knobCorner.Parent = knob

            return button, knob, outline
        end

        local trainSwitch, trainKnob, trainSwitchStroke = helpers.makeTrainSwitch(
            "AutoTrainSwitch", trainCard,
            UDim2.new(1, -12, 0, 10), UDim2.fromOffset(70, 29)
        )

        local auto2xRow = Instance.new("Frame")
        auto2xRow.Name = "Auto2xRow"
        auto2xRow.Position = UDim2.fromOffset(12, 66)
        auto2xRow.Size = UDim2.new(1, -24, 0, 38)
        auto2xRow.BackgroundColor3 = Color3.fromRGB(28, 22, 31)
        auto2xRow.BackgroundTransparency = 0.12
        auto2xRow.BorderSizePixel = 0
        auto2xRow.Visible = false
        auto2xRow.Parent = trainCard

        local auto2xCorner = Instance.new("UICorner")
        auto2xCorner.CornerRadius = UDim.new(0, 8)
        auto2xCorner.Parent = auto2xRow

        local auto2xStroke = Instance.new("UIStroke")
        auto2xStroke.Color = TRAIN_RED
        auto2xStroke.Thickness = 1
        auto2xStroke.Transparency = 0.58
        auto2xStroke.Parent = auto2xRow

        local auto2xLabel = Instance.new("TextLabel")
        auto2xLabel.Position = UDim2.fromOffset(11, 0)
        auto2xLabel.Size = UDim2.new(1, -105, 1, 0)
        auto2xLabel.BackgroundTransparency = 1
        auto2xLabel.Text = "Auto 2x"
        auto2xLabel.TextColor3 = TEXT
        auto2xLabel.TextSize = 11
        auto2xLabel.Font = Enum.Font.GothamMedium
        auto2xLabel.TextXAlignment = Enum.TextXAlignment.Left
        auto2xLabel.Parent = auto2xRow

        local auto2xSwitch, auto2xKnob, auto2xSwitchStroke = helpers.makeTrainSwitch(
            "Auto2xSwitch", auto2xRow,
            UDim2.new(1, -8, 0.5, -14), UDim2.fromOffset(62, 28)
        )
        auto2xKnob.Size = UDim2.fromOffset(22, 22)

        helpers.setRedSwitch = function(button, knob, outline, enabled, instant)
            local targetPosition = enabled
                and UDim2.new(1, -26, 0, 3)
                or UDim2.fromOffset(3, 3)
            local targetColor = enabled
                and Color3.fromRGB(137, 39, 53)
                or Color3.fromRGB(53, 48, 59)
            if instant then
                knob.Position = targetPosition
                button.BackgroundColor3 = targetColor
                outline.Transparency = enabled and 0.08 or 0.48
            else
                helpers.makeTween(knob, 0.2, {Position = targetPosition})
                helpers.makeTween(button, 0.2, {BackgroundColor3 = targetColor})
                helpers.makeTween(outline, 0.2, {Transparency = enabled and 0.08 or 0.48})
            end
        end

        trainSwitch.MouseButton1Click:Connect(function()
            if autoFarmRunning then return end
            if not trainEnabled and isEnabled then
                helpers.debugLog("Auto Train toggle blocked: Auto Throw is already enabled.")
                return
            end

            trainEnabled = not trainEnabled
            trainStateLabel.Text = trainEnabled and "ON" or "OFF"
            trainStateLabel.TextColor3 = trainEnabled and TRAIN_RED_BRIGHT or MUTED
            helpers.setRedSwitch(trainSwitch, trainKnob, trainSwitchStroke, trainEnabled, false)

            if trainEnabled then
                activeHudMode = "train"
                auto2xRow.Visible = true
                auto2xRow.BackgroundTransparency = 1
                auto2xRow.Position = UDim2.fromOffset(12, 55)
                helpers.makeTween(trainCard, 0.28, {Size = UDim2.new(1, 0, 0, 116)})
                helpers.makeTween(auto2xRow, 0.28, {
                    Position = UDim2.fromOffset(12, 66),
                    BackgroundTransparency = 0.12
                })
                helpers.makeTween(trainCardStroke, 0.22, {Transparency = 0.08, Thickness = 1.8})
                if startTrain then startTrain() end
            else
                auto2xEnabled = false
                helpers.setRedSwitch(auto2xSwitch, auto2xKnob, auto2xSwitchStroke, false, false)
                local collapse = helpers.makeTween(trainCard, 0.24, {Size = UDim2.new(1, 0, 0, 62)})
                helpers.makeTween(auto2xRow, 0.18, {
                    Position = UDim2.fromOffset(12, 54),
                    BackgroundTransparency = 1
                })
                helpers.makeTween(trainCardStroke, 0.22, {Transparency = 0.3, Thickness = 1.35})
                collapse.Completed:Connect(function()
                    if not trainEnabled then
                        auto2xRow.Visible = false
                    end
                end)
                if stopTrain then stopTrain() end
            end
        end)

        --==================================================
        -- AUTO EQUIP BEST PET CARD
        --==================================================

        local EQUIP_GREEN = Color3.fromRGB(65, 205, 125)
        local EQUIP_GREEN_BRIGHT = Color3.fromRGB(105, 235, 155)

        local equipBestCard = Instance.new("Frame")
        equipBestCard.Name = "AutoEquipBestPetCard"
        equipBestCard.Position = UDim2.new(0, 0, 0, 0)
        equipBestCard.Size = UDim2.new(1, 0, 0, 62)
        equipBestCard.BackgroundColor3 = CARD
        equipBestCard.BorderSizePixel = 0
        equipBestCard.LayoutOrder = 4
        equipBestCard.Parent = farmContent

        local equipBestCorner = Instance.new("UICorner")
        equipBestCorner.CornerRadius = UDim.new(0, 12)
        equipBestCorner.Parent = equipBestCard

        local equipBestStroke = Instance.new("UIStroke")
        equipBestStroke.Color = EQUIP_GREEN
        equipBestStroke.Thickness = 1.35
        equipBestStroke.Transparency = 0.3
        equipBestStroke.Parent = equipBestCard

        local equipBestGradient = Instance.new("UIGradient")
        equipBestGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 39, 32)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 24, 22))
        })
        equipBestGradient.Rotation = 15
        equipBestGradient.Parent = equipBestCard

        local equipBestLabel = Instance.new("TextLabel")
        equipBestLabel.Name = "AutoEquipBestPetLabel"
        equipBestLabel.Position = UDim2.fromOffset(12, 8)
        equipBestLabel.Size = UDim2.fromOffset(135, 29)
        equipBestLabel.BackgroundColor3 = Color3.fromRGB(31, 76, 54)
        equipBestLabel.BackgroundTransparency = 0.05
        equipBestLabel.Text = "Auto Equip Best Pet"
        equipBestLabel.TextColor3 = Color3.fromRGB(190, 255, 218)
        equipBestLabel.TextStrokeColor3 = Color3.fromRGB(42, 255, 142)
        equipBestLabel.TextStrokeTransparency = 0.5
        equipBestLabel.TextSize = 13
        equipBestLabel.Font = Enum.Font.GothamBold
        equipBestLabel.TextXAlignment = Enum.TextXAlignment.Left
        equipBestLabel.Parent = equipBestCard
        local equipBestLabelPadding = Instance.new("UIPadding")
        equipBestLabelPadding.PaddingLeft = UDim.new(0, 10)
        equipBestLabelPadding.Parent = equipBestLabel
        local equipBestLabelGradient = Instance.new("UIGradient")
        equipBestLabelGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(37, 104, 72)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 57, 48))
        })
        equipBestLabelGradient.Rotation = 0
        equipBestLabelGradient.Parent = equipBestLabel
        local equipBestLabelCorner = Instance.new("UICorner")
        equipBestLabelCorner.CornerRadius = UDim.new(0, 8)
        equipBestLabelCorner.Parent = equipBestLabel
        local equipBestLabelStroke = Instance.new("UIStroke")
        equipBestLabelStroke.Color = EQUIP_GREEN
        equipBestLabelStroke.Transparency = 0.35
        equipBestLabelStroke.Thickness = 1
        equipBestLabelStroke.Parent = equipBestLabel

        local equipBestSwitch = Instance.new("TextButton")
        equipBestSwitch.Name = "AutoEquipBestPetSwitch"
        equipBestSwitch.AnchorPoint = Vector2.new(1, 0)
        equipBestSwitch.Position = UDim2.new(1, -12, 0, 10)
        equipBestSwitch.Size = UDim2.fromOffset(60, 29)
        equipBestSwitch.BackgroundColor3 = Color3.fromRGB(48, 58, 55)
        equipBestSwitch.BorderSizePixel = 0
        equipBestSwitch.Text = ""
        equipBestSwitch.AutoButtonColor = false
        equipBestSwitch.Parent = equipBestCard

        local equipAllButton = Instance.new("TextButton")
        equipAllButton.Name = "EquipAllButton"
        equipAllButton.AnchorPoint = Vector2.new(1, 0)
        equipAllButton.Position = UDim2.new(1, -82, 0, 10)
        equipAllButton.Size = UDim2.fromOffset(66, 29)
        equipAllButton.BackgroundColor3 = Color3.fromRGB(28, 78, 55)
        equipAllButton.BorderSizePixel = 0
        equipAllButton.Text = "EQUIP BEST"
        equipAllButton.TextColor3 = Color3.fromRGB(190, 255, 218)
        equipAllButton.TextSize = 9
        equipAllButton.Font = Enum.Font.GothamBold
        equipAllButton.AutoButtonColor = false
        equipAllButton.Parent = equipBestCard

        local equipAllCorner = Instance.new("UICorner")
        equipAllCorner.CornerRadius = UDim.new(0, 7)
        equipAllCorner.Parent = equipAllButton

        local equipAllStroke = Instance.new("UIStroke")
        equipAllStroke.Color = EQUIP_GREEN
        equipAllStroke.Transparency = 0.35
        equipAllStroke.Thickness = 1
        equipAllStroke.Parent = equipAllButton

        local equipAllDivider = Instance.new("Frame")
        equipAllDivider.Name = "EquipAllDivider"
        equipAllDivider.AnchorPoint = Vector2.new(1, 0)
        equipAllDivider.Position = UDim2.new(1, -77, 0, 9)
        equipAllDivider.Size = UDim2.fromOffset(1, 31)
        equipAllDivider.BackgroundColor3 = Color3.fromRGB(78, 112, 94)
        equipAllDivider.BackgroundTransparency = 0.25
        equipAllDivider.BorderSizePixel = 0
        equipAllDivider.Parent = equipBestCard

        local equipStateLabel = Instance.new("TextLabel")
        equipStateLabel.Name = "EquipState"
        equipStateLabel.AnchorPoint = Vector2.new(1, 0)
        equipStateLabel.Position = UDim2.new(1, -13, 0, 43)
        equipStateLabel.Size = UDim2.fromOffset(95, 16)
        equipStateLabel.BackgroundTransparency = 1
        equipStateLabel.Text = "OFF"
        equipStateLabel.TextColor3 = MUTED
        equipStateLabel.TextSize = 9
        equipStateLabel.Font = Enum.Font.GothamBold
        equipStateLabel.TextXAlignment = Enum.TextXAlignment.Right
        equipStateLabel.Parent = equipBestCard

        local equipSwitchCorner = Instance.new("UICorner")
        equipSwitchCorner.CornerRadius = UDim.new(1, 0)
        equipSwitchCorner.Parent = equipBestSwitch

        local equipSwitchStroke = Instance.new("UIStroke")
        equipSwitchStroke.Color = EQUIP_GREEN
        equipSwitchStroke.Transparency = 0.48
        equipSwitchStroke.Thickness = 1
        equipSwitchStroke.Parent = equipBestSwitch

        local equipSwitchKnob = Instance.new("Frame")
        equipSwitchKnob.Name = "Knob"
        equipSwitchKnob.Position = UDim2.fromOffset(3, 3)
        equipSwitchKnob.Size = UDim2.fromOffset(23, 23)
        equipSwitchKnob.BackgroundColor3 = Color3.fromRGB(235, 242, 238)
        equipSwitchKnob.BorderSizePixel = 0
        equipSwitchKnob.Parent = equipBestSwitch

        local equipKnobCorner = Instance.new("UICorner")
        equipKnobCorner.CornerRadius = UDim.new(1, 0)
        equipKnobCorner.Parent = equipSwitchKnob

        helpers.setEquipSwitchVisual = function(enabled, instant)
            local knobPosition = enabled
                and UDim2.new(1, -26, 0, 3)
                or UDim2.fromOffset(3, 3)
            local switchColor = enabled
                and Color3.fromRGB(35, 112, 70)
                or Color3.fromRGB(48, 58, 55)
            if instant then
                equipSwitchKnob.Position = knobPosition
                equipBestSwitch.BackgroundColor3 = switchColor
                equipSwitchStroke.Transparency = enabled and 0.08 or 0.48
            else
                helpers.makeTween(equipSwitchKnob, 0.2, {Position = knobPosition})
                helpers.makeTween(equipBestSwitch, 0.2, {BackgroundColor3 = switchColor})
                helpers.makeTween(equipSwitchStroke, 0.2, {Transparency = enabled and 0.08 or 0.48})
            end
        end

        helpers.invokeEquipBest = function()
            local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
            local remote = remotes and remotes:FindFirstChild("Plot_EquipBest")
            if not remote or not remote:IsA("RemoteFunction") then
                helpers.debugLog("Equip Best failed: Plot_EquipBest RemoteFunction was not found.")
                return false
            end

            local success, result = pcall(function()
                return remote:InvokeServer()
            end)

            if success then
                helpers.debugLog("Equip Best invoked successfully. Result: " .. tostring(result))
                return true
            end

            warn("[BZHUB EQUIP BEST ERROR] " .. tostring(result))
            return false
        end

        local equipChangeQueued = false
        local equipChangeConnections = {}
        local equipCharacterConnections = {}
        local equipLastInventorySignature = nil
        local equipLastEquippedSignature = nil

        helpers.getPetStateSignatures = function()
            local inventoryIds = {}
            local equippedIds = {}
            local seen = {}

            local backpack = player:FindFirstChildOfClass("Backpack")
            local character = player.Character

            local function scan(container, isEquipped)
                if not container then return end
                for _, child in ipairs(container:GetChildren()) do
                    if child:IsA("Tool") then
                        local animalId = child:GetAttribute("AnimalId")
                        if animalId ~= nil then
                            local id = tostring(animalId)
                            if not seen[id] then
                                seen[id] = true
                                table.insert(inventoryIds, id)
                            end
                            if isEquipped then
                                table.insert(equippedIds, id)
                            end
                        end
                    end
                end
            end

            scan(backpack, false)
            scan(character, true)
            table.sort(inventoryIds)
            table.sort(equippedIds)
            return table.concat(inventoryIds, "|"), table.concat(equippedIds, "|")
        end

        helpers.invokeEquipAll = function()
            -- Use the game's original Equip Best remote so it compares owned pets
            -- against the pets already placed on the plot, exactly like the
            -- game's normal Equip Best action.
            return helpers.invokeEquipBest()
        end

        helpers.queueEquipBest = function(workerId)
            if equipChangeQueued then return end
            equipChangeQueued = true
            task.delay(0.55, function()
                equipChangeQueued = false
                if not autoEquipBestEnabled or workerId ~= autoEquipBestWorkerId then return end

                local inventorySignature, equippedSignature = helpers.getPetStateSignatures()
                if inventorySignature ~= equipLastInventorySignature
                    or equippedSignature ~= equipLastEquippedSignature then
                    helpers.invokeEquipBest()
                    equipLastInventorySignature, equipLastEquippedSignature =
                        helpers.getPetStateSignatures()
                end
            end)
        end

        helpers.AutoEquipBest = function()
            autoEquipBestWorkerId += 1
            local workerId = autoEquipBestWorkerId

            task.spawn(function()
                if not autoEquipBestEnabled or workerId ~= autoEquipBestWorkerId then return end

                helpers.invokeEquipBest()
                equipLastInventorySignature, equipLastEquippedSignature =
                    helpers.getPetStateSignatures()

                local function connectPetChanges(container, connectionBucket)
                    if not container then return end
                    table.insert(connectionBucket, container.ChildAdded:Connect(function()
                        helpers.queueEquipBest(workerId)
                    end))
                    table.insert(connectionBucket, container.ChildRemoved:Connect(function()
                        helpers.queueEquipBest(workerId)
                    end))
                end

                local backpack = player:FindFirstChildOfClass("Backpack")
                    or player:WaitForChild("Backpack", 5)
                connectPetChanges(backpack, equipChangeConnections)

                local function watchCharacter(character)
                    for _, connection in ipairs(equipCharacterConnections) do
                        pcall(function() connection:Disconnect() end)
                    end
                    table.clear(equipCharacterConnections)
                    connectPetChanges(character, equipCharacterConnections)
                end

                watchCharacter(player.Character)

                -- Rebind to respawned characters without retaining old character connections.
                table.insert(equipChangeConnections, player.CharacterAdded:Connect(function(character)
                    task.wait(0.5)
                    if not autoEquipBestEnabled or workerId ~= autoEquipBestWorkerId then return end
                    watchCharacter(character)
                    helpers.queueEquipBest(workerId)
                end))

                -- A quiet safety check catches missed replication events without polling the remote.
                while autoEquipBestEnabled and workerId == autoEquipBestWorkerId do
                    task.wait(15)
                    if autoEquipBestEnabled and workerId == autoEquipBestWorkerId then
                        helpers.queueEquipBest(workerId)
                    end
                end
            end)
        end

        helpers.stopAutoEquipBest = function()
            autoEquipBestWorkerId += 1
            for _, connection in ipairs(equipChangeConnections) do
                pcall(function() connection:Disconnect() end)
            end
            table.clear(equipChangeConnections)
            for _, connection in ipairs(equipCharacterConnections) do
                pcall(function() connection:Disconnect() end)
            end
            table.clear(equipCharacterConnections)
            equipChangeQueued = false
            equipLastInventorySignature = nil
            equipLastEquippedSignature = nil
        end

        local equipAllScale = Instance.new("UIScale")
        equipAllScale.Scale = 1
        equipAllScale.Parent = equipAllButton

        local equipAllAnimating = false
        local function animateEquipAllUnavailable()
            if equipAllAnimating then return end
            equipAllAnimating = true
            local grow = TweenService:Create(equipAllScale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.14})
            grow:Play()
            grow.Completed:Wait()
            for _, x in ipairs({-5, 5, -4, 4, -2, 2, 0}) do
                equipAllButton.Position = UDim2.new(1, -82 + x, 0, 10)
                task.wait(0.025)
            end
            local shrink = TweenService:Create(equipAllScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1})
            shrink:Play()
            shrink.Completed:Wait()
            equipAllButton.Position = UDim2.new(1, -82, 0, 10)
            equipAllAnimating = false
        end

        equipAllButton.MouseButton1Click:Connect(function()
            if autoFarmRunning then return end
            if autoEquipBestEnabled then
                task.spawn(animateEquipAllUnavailable)
                return
            end
            equipAllButton.Text = "..."
            local ok = helpers.invokeEquipAll()
            equipAllButton.Text = ok and "DONE" or "N/A"
            task.delay(0.8, function()
                if equipAllButton and equipAllButton.Parent then
                    equipAllButton.Text = autoEquipBestEnabled and "X" or "EQUIP BEST"
                end
            end)
        end)

        equipBestSwitch.MouseButton1Click:Connect(function()
            if autoFarmRunning then return end
            autoEquipBestEnabled = not autoEquipBestEnabled
            equipStateLabel.Text = autoEquipBestEnabled and "ON" or "OFF"
            equipStateLabel.TextColor3 = autoEquipBestEnabled and EQUIP_GREEN_BRIGHT or MUTED
            equipAllButton.Text = autoEquipBestEnabled and "X" or "EQUIP BEST"
            equipAllButton.BackgroundColor3 = autoEquipBestEnabled
                and Color3.fromRGB(70, 35, 42) or Color3.fromRGB(28, 78, 55)
            equipAllStroke.Color = autoEquipBestEnabled
                and Color3.fromRGB(255, 95, 105) or EQUIP_GREEN
            helpers.setEquipSwitchVisual(autoEquipBestEnabled, false)
            helpers.makeTween(equipBestStroke, 0.2, {
                Transparency = autoEquipBestEnabled and 0.08 or 0.3,
                Thickness = autoEquipBestEnabled and 1.8 or 1.35
            })

            if autoEquipBestEnabled then
                helpers.debugLog("Auto Equip Best Pet enabled.")
                helpers.AutoEquipBest()
            else
                helpers.stopAutoEquipBest()
                helpers.debugLog("Auto Equip Best Pet disabled.")
            end
        end)

        -- Auto 2x: use a non-mouse touch event first, then an event-connection
        -- activation if the executor exposes it. Mouse input is the last fallback.
        local auto2xTouchId = 100
        local touchInputSupported = nil

        helpers.findTapBonusButton = function()
            local trainingSequence = playerGui:FindFirstChild("TrainingSequence")
            if not trainingSequence then return nil, nil end

            local tapBonusLayer = trainingSequence:FindFirstChild("TapBonusLayer")
            if not tapBonusLayer then return nil, nil end

            local tapBonus = tapBonusLayer:FindFirstChild("TapBonus", true)
            if not tapBonus then return nil, nil end

            if tapBonus:IsA("GuiButton") then
                return tapBonus, tapBonus
            end

            local ancestor = tapBonus.Parent
            while ancestor and ancestor ~= tapBonusLayer do
                if ancestor:IsA("GuiButton") then
                    return ancestor, tapBonus
                end
                ancestor = ancestor.Parent
            end

            local nestedButton = tapBonus:FindFirstChildWhichIsA("GuiButton", true)
            if nestedButton then
                return nestedButton, tapBonus
            end

            return nil, tapBonus
        end

        helpers.tapBonusStillExists = function(expectedObject)
            local currentButton, currentObject = helpers.findTapBonusButton()
            return currentObject == expectedObject and currentButton ~= nil
                and currentButton.Visible and currentButton.Active, currentButton
        end

        -- Optional executor event-connection route. Solara may not expose getconnections.
        helpers.tryGetConnectionsActivation = function(button)
            if not button or not button:IsA("GuiButton") then
                return false
            end
            if type(getconnections) ~= "function" then
                return false
            end

            local function triggerSignalConnections(signal)
                local getOk, connections = pcall(function()
                    return getconnections(signal)
                end)
                if not getOk or type(connections) ~= "table" then
                    return false
                end

                local firedAny = false
                for _, connection in ipairs(connections) do
                    if connection then
                        local enabled = true
                        pcall(function()
                            enabled = connection.Enabled
                        end)

                        if enabled ~= false then
                            local firedThisConnection = false
                            local fireMethod
                            pcall(function()
                                fireMethod = connection.Fire
                            end)

                            if type(fireMethod) == "function" then
                                firedThisConnection = pcall(function()
                                    fireMethod(connection)
                                end)
                            end

                            if not firedThisConnection then
                                local callback
                                pcall(function()
                                    callback = connection.Function
                                end)
                                if type(callback) == "function" then
                                    firedThisConnection = pcall(callback)
                                end
                            end

                            if firedThisConnection then
                                firedAny = true
                            end
                        end
                    end
                end
                return firedAny
            end

            if triggerSignalConnections(button.Activated) then
                return true
            end
            return triggerSignalConnections(button.MouseButton1Click)
        end

        -- Try a touchscreen tap at the button center. This does not move the mouse
        -- and does not send MouseButton1. Some Solara builds block this Roblox service.
        helpers.touchTapBonus = function(button, expectedObject)
            if not button or not button:IsA("GuiButton") then
                return false
            end
            if touchInputSupported == false then
                return false
            end

            local virtualInputManager = VirtualInputManager
            if not virtualInputManager then
                touchInputSupported = false
                warn("[BZHUB AUTO 2X] VirtualInputManager is unavailable.")
                return false
            end

            local sendTouchEvent
            local methodOk = pcall(function()
                sendTouchEvent = virtualInputManager.SendTouchEvent
            end)
            if not methodOk or type(sendTouchEvent) ~= "function" then
                touchInputSupported = false
                warn("[BZHUB AUTO 2X] This Solara build does not expose SendTouchEvent.")
                return false
            end

            local center = button.AbsolutePosition + (button.AbsoluteSize / 2)
            auto2xTouchId += 1
            local touchId = auto2xTouchId
            local beginState = Enum.UserInputState.Begin.Value
            local endState = Enum.UserInputState.End.Value

            local beginOk, beginError = pcall(function()
                virtualInputManager:SendTouchEvent(touchId, beginState, center.X, center.Y)
            end)
            if not beginOk then
                touchInputSupported = false
                warn("[BZHUB AUTO 2X] Touch input is blocked by this Solara build: " .. tostring(beginError))
                return false
            end

            touchInputSupported = true
            task.wait(0.12)

            local endOk, endError = pcall(function()
                virtualInputManager:SendTouchEvent(touchId, endState, center.X, center.Y)
            end)
            if not endOk then
                pcall(function()
                    virtualInputManager:SendTouchEvent(
                        touchId,
                        Enum.UserInputState.Cancel.Value,
                        center.X,
                        center.Y
                    )
                end)
                warn("[BZHUB AUTO 2X] Touch release failed: " .. tostring(endError))
                return false
            end

            helpers.debugLog("Auto 2x: touchscreen tap sent without mouse input.")

            -- Give the game's Activated handler and UI update time to run.
            local deadline = os.clock() + 0.55
            repeat
                task.wait(0.05)
                local stillVisible = helpers.tapBonusStillExists(expectedObject)
                if not stillVisible then
                    return true
                end
            until os.clock() >= deadline

            return false
        end

        -- Last-resort mouse path. Press and release while still over the button,
        -- then wait for the input to be processed BEFORE restoring the old cursor.
        helpers.mouseClickTapBonus = function(button, expectedObject)
            if not button or not button:IsA("GuiButton") then return false end
            if not button.Visible or not button.Active then return false end
            if type(mousemoveabs) ~= "function" then
                warn("[BZHUB AUTO 2X] Mouse movement is unavailable in this executor.")
                return false
            end

            local oldPosition = UserInputService:GetMouseLocation()
            local center = button.AbsolutePosition + (button.AbsoluteSize / 2)
            local moved = false
            local isPressed = false

            local ok, err = pcall(function()
                mousemoveabs(center.X, center.Y)
                moved = true
                task.wait(0.18)

                if type(mouse1press) == "function" and type(mouse1release) == "function" then
                    mouse1press()
                    isPressed = true
                    task.wait(0.12)
                    mouse1release()
                    isPressed = false
                elseif type(mouse1click) == "function" then
                    mouse1click()
                else
                    error("No supported mouse click function is available")
                end
            end)

            if isPressed and type(mouse1release) == "function" then
                pcall(mouse1release)
                isPressed = false
            end

            if ok then
                -- Keep the pointer over the button until the click has had time
                -- to pass through Roblox input handling and the game UI reacts.
                local deadline = os.clock() + 0.65
                repeat
                    task.wait(0.05)
                    local stillVisible = helpers.tapBonusStillExists(expectedObject)
                    if not stillVisible then
                        break
                    end
                until os.clock() >= deadline
                task.wait(0.12)
            end

            -- Restore only after press+release and the processing window above.
            if moved then
                pcall(function()
                    mousemoveabs(oldPosition.X, oldPosition.Y)
                end)
            end

            if not ok then
                warn("[BZHUB AUTO 2X] Mouse fallback failed: " .. tostring(err))
                return false
            end
            return not helpers.tapBonusStillExists(expectedObject)
        end

        helpers.attemptAuto2x = function(button, tapBonusObject)
            if not button or not tapBonusObject then
                return false
            end

            -- Preferred non-MB1 route: send a touch tap to the ImageButton center.
            local touchWorked = helpers.touchTapBonus(button, tapBonusObject)
            if touchWorked then
                return true
            end

            -- Try executor event connections next, if this Solara build exposes them.
            local connectionAttempted = helpers.tryGetConnectionsActivation(button)
            if connectionAttempted then
                local deadline = os.clock() + 0.35
                repeat
                    task.wait(0.05)
                    local stillVisible = helpers.tapBonusStillExists(tapBonusObject)
                    if not stillVisible then return true end
                until os.clock() >= deadline
            end

            -- Fallback only if touch/event activation did not remove the bonus.
            helpers.debugLog("Auto 2x: non-mouse activation did not remove the button; trying mouse fallback.")
            local stillVisible, currentButton = helpers.tapBonusStillExists(tapBonusObject)
            if stillVisible and currentButton then
                helpers.mouseClickTapBonus(currentButton, tapBonusObject)
            end

            return not helpers.tapBonusStillExists(tapBonusObject)
        end

        helpers.setAuto2xEnabled = function(enabled, instant)
            if enabled and not trainEnabled then return false end
            auto2xEnabled = enabled
            helpers.setRedSwitch(auto2xSwitch, auto2xKnob, auto2xSwitchStroke, auto2xEnabled, instant == true)

            auto2xWorkerId += 1
            local thisWorkerId = auto2xWorkerId
            if auto2xEnabled then
                task.spawn(function()
                    while trainEnabled and auto2xEnabled and auto2xWorkerId == thisWorkerId do
                        local clickButton, tapBonusObject = helpers.findTapBonusButton()
                        if not tapBonusObject then
                            task.wait(0.1)
                        elseif not clickButton then
                            warn("[BZHUB AUTO 2X] TapBonus exists but no GuiButton was found.")
                            task.wait(0.2)
                        else
                            task.wait(0.22)
                            if not (trainEnabled and auto2xEnabled and auto2xWorkerId == thisWorkerId) then break end
                            helpers.attemptAuto2x(clickButton, tapBonusObject)
                            task.wait(0.35)
                            while trainEnabled and auto2xEnabled and auto2xWorkerId == thisWorkerId do
                                local remains, retryButton = helpers.tapBonusStillExists(tapBonusObject)
                                if not remains then break end
                                helpers.attemptAuto2x(retryButton, tapBonusObject)
                                task.wait(0.45)
                            end
                        end
                    end
                end)
            end
            return true
        end

        auto2xSwitch.MouseButton1Click:Connect(function()
            if autoFarmRunning then return end
            if not trainEnabled then return end
            helpers.setAuto2xEnabled(not auto2xEnabled, false)
        end)

        -- Animated information panel slides in from the right.
        local infoPanel = Instance.new("Frame")
        infoPanel.Name = "AutoThrowInfoPanel"
        infoPanel.AnchorPoint = Vector2.new(1, 0)
        infoPanel.Position = UDim2.new(1, 275, 0, 55)
        infoPanel.Size = UDim2.fromOffset(255, 190)
        infoPanel.BackgroundColor3 = PANEL
        infoPanel.BorderSizePixel = 0
        infoPanel.Visible = false
        infoPanel.ZIndex = 80
        infoPanel.Parent = page
        infoPanel.ZIndex = 80

        local infoPanelCorner = Instance.new("UICorner")
        infoPanelCorner.CornerRadius = UDim.new(0, 12)
        infoPanelCorner.Parent = infoPanel

        local infoPanelStroke = Instance.new("UIStroke")
        infoPanelStroke.Color = ACCENT
        infoPanelStroke.Thickness = 1.3
        infoPanelStroke.Transparency = 0.18
        infoPanelStroke.Parent = infoPanel

        local infoPanelTitle = Instance.new("TextLabel")
        infoPanelTitle.Position = UDim2.fromOffset(13, 12)
        infoPanelTitle.Size = UDim2.new(1, -48, 0, 20)
        infoPanelTitle.BackgroundTransparency = 1
        infoPanelTitle.Text = helpers.tr("infoTitle")
        infoPanelTitle.TextColor3 = ACCENT_BRIGHT
        infoPanelTitle.TextSize = 11
        infoPanelTitle.Font = Enum.Font.GothamBold
        infoPanelTitle.TextXAlignment = Enum.TextXAlignment.Left
        infoPanelTitle.ZIndex = 81
        infoPanelTitle.Parent = infoPanel

        local closeInfoButton = Instance.new("TextButton")
        closeInfoButton.AnchorPoint = Vector2.new(1, 0)
        closeInfoButton.Position = UDim2.new(1, -10, 0, 9)
        closeInfoButton.Size = UDim2.fromOffset(25, 25)
        closeInfoButton.BackgroundColor3 = Color3.fromRGB(32, 43, 58)
        closeInfoButton.BorderSizePixel = 0
        closeInfoButton.Text = " "
        closeInfoButton.TextColor3 = TEXT
        closeInfoButton.TextSize = 18
        closeInfoButton.Font = Enum.Font.GothamMedium
        closeInfoButton.ZIndex = 82
        closeInfoButton.Parent = infoPanel

        local closeCorner = Instance.new("UICorner")
        closeCorner.CornerRadius = UDim.new(1, 0)
        closeCorner.Parent = closeInfoButton

        --==================================================
        -- INDEPENDENT TOP STATUS HUD
        -- This ScreenGui is parented to PlayerGui, not the BZHUB page,
        -- so it remains visible when the main hub is minimized/hidden.
        --==================================================

        hudGui = Instance.new("ScreenGui")
        hudGui.Name = "BZHUB_AutoThrow_StatusHUD"
        hudGui.ResetOnSpawn = false
        hudGui.IgnoreGuiInset = true
        hudGui.DisplayOrder = 100000
        hudGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        hudGui.Enabled = false
        hudGui.Parent = playerGui

        -- Dedicated AFK Farm information panel (pet names only; no power values).
        local afkHudGui = Instance.new("ScreenGui")
        afkHudGui.Name = "BZHUB_AFK_Farm_Info"
        afkHudGui.ResetOnSpawn = false
        afkHudGui.IgnoreGuiInset = true
        afkHudGui.DisplayOrder = 100001
        afkHudGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        afkHudGui.Enabled = false
        afkHudGui.Parent = playerGui

        local afkPanel = Instance.new("Frame")
        afkPanel.Name = "AFKPanel"
        afkPanel.AnchorPoint = Vector2.new(0.5, 0)
        afkPanel.Position = UDim2.new(0.5, 0, 0, 88)
        afkPanel.Size = UDim2.fromOffset(390, 194)
        afkPanel.BackgroundColor3 = Color3.fromRGB(8, 13, 22)
        afkPanel.BackgroundTransparency = 0.08
        afkPanel.BorderSizePixel = 0
        afkPanel.Parent = afkHudGui
        local afkPanelCorner = Instance.new("UICorner")
        afkPanelCorner.CornerRadius = UDim.new(0, 12)
        afkPanelCorner.Parent = afkPanel
        local afkPanelStroke = Instance.new("UIStroke")
        afkPanelStroke.Color = Color3.fromRGB(70, 165, 245)
        afkPanelStroke.Thickness = 1.2
        afkPanelStroke.Transparency = 0.18
        afkPanelStroke.Parent = afkPanel

        local afkHeader = Instance.new("TextLabel")
        afkHeader.Position = UDim2.fromOffset(14, 8)
        afkHeader.Size = UDim2.new(1, -28, 0, 22)
        afkHeader.BackgroundTransparency = 1
        afkHeader.Text = "AFK FARM / ON"
        afkHeader.TextColor3 = Color3.fromRGB(245, 249, 255)
        afkHeader.TextSize = 12
        afkHeader.Font = Enum.Font.GothamBold
        afkHeader.TextXAlignment = Enum.TextXAlignment.Left
        afkHeader.Parent = afkPanel

        local afkDivider = Instance.new("Frame")
        afkDivider.Position = UDim2.fromOffset(12, 34)
        afkDivider.Size = UDim2.new(1, -24, 0, 1)
        afkDivider.BackgroundColor3 = Color3.fromRGB(95, 125, 155)
        afkDivider.BackgroundTransparency = 0.35
        afkDivider.BorderSizePixel = 0
        afkDivider.Parent = afkPanel

        helpers.makeAfkRow = function(name, y, initialText)
            local label = Instance.new("TextLabel")
            label.Name = name .. "Text"
            label.Position = UDim2.fromOffset(14, y)
            label.Size = UDim2.new(1, -28, 0, 16)
            label.BackgroundTransparency = 1
            label.Text = initialText
            label.TextColor3 = Color3.fromRGB(218, 230, 244)
            label.TextSize = 10
            label.Font = Enum.Font.GothamSemibold
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Parent = afkPanel

            local bar = Instance.new("Frame")
            bar.Name = name .. "Bar"
            bar.Position = UDim2.fromOffset(14, y + 18)
            bar.Size = UDim2.new(1, -28, 0, 7)
            bar.BackgroundColor3 = Color3.fromRGB(30, 43, 58)
            bar.BorderSizePixel = 0
            bar.ClipsDescendants = true
            bar.Parent = afkPanel
            local barCorner = Instance.new("UICorner")
            barCorner.CornerRadius = UDim.new(1, 0)
            barCorner.Parent = bar
            local fill = Instance.new("Frame")
            fill.Name = "Fill"
            fill.Size = UDim2.new(0, 0, 1, 0)
            fill.BackgroundColor3 = Color3.fromRGB(67, 169, 245)
            fill.BorderSizePixel = 0
            fill.Parent = bar
            local fillCorner = Instance.new("UICorner")
            fillCorner.CornerRadius = UDim.new(1, 0)
            fillCorner.Parent = fill
            return label, fill
        end

        local afkThrowsText, afkThrowsFill = helpers.makeAfkRow("Throws", 42, "ATI LAR: 3")
        local afkTrainingText, afkTrainingFill = helpers.makeAfkRow("Training", 78, "TRAINING: 60s")
        local afkPetsText = Instance.new("TextLabel")
        afkPetsText.Name = "EquipPetsText"
        afkPetsText.Position = UDim2.fromOffset(14, 119)
        afkPetsText.Size = UDim2.new(1, -28, 0, 62)
        afkPetsText.BackgroundTransparency = 1
        afkPetsText.Text = "EQUIP PETS: Bekleniyor..."
        afkPetsText.TextColor3 = Color3.fromRGB(218, 230, 244)
        afkPetsText.TextSize = 10
        afkPetsText.Font = Enum.Font.GothamSemibold
        afkPetsText.TextXAlignment = Enum.TextXAlignment.Left
        afkPetsText.TextYAlignment = Enum.TextYAlignment.Top
        afkPetsText.TextWrapped = true
        afkPetsText.Parent = afkPanel

        helpers.setAfkBar = function(fill, value)
            fill.Size = UDim2.new(math.clamp(value or 0, 0, 1), 0, 1, 0)
        end

        helpers.setAfkThrowCount = function(remaining)
            afkThrowsText.Text = "ATI LAR: " .. tostring(math.max(0, remaining))
            helpers.setAfkBar(afkThrowsFill, (autoFarmThrowTarget - math.max(0, remaining)) / autoFarmThrowTarget)
        end

        helpers.setAfkTraining = function(secondsLeft)
            local remaining = math.max(0, secondsLeft)
            afkTrainingText.Text = "TRAINING: " .. tostring(remaining) .. "s"
            helpers.setAfkBar(afkTrainingFill, (autoFarmTrainingSeconds - remaining) / autoFarmTrainingSeconds)
        end

        helpers.setAfkPets = function(names)
            if type(names) ~= "table" then
                afkPetsText.Text = "EQUIP PETS: Bekleniyor..."
            elseif #names == 0 then
                afkPetsText.Text = "EQUIP PETS:  sim bulunamad "
            else
                afkPetsText.Text = "EQUIP PETS: " .. table.concat(names, ", ")
            end
        end

        local hudContainer = Instance.new("Frame")
        hudContainer.Name = "StatusContainer"
        hudContainer.AnchorPoint = Vector2.new(0.5, 0)
        hudContainer.Position = UDim2.new(0.5, 0, 0, 88)
        hudContainer.Size = UDim2.fromOffset(390, 78)
        hudContainer.BackgroundColor3 = Color3.fromRGB(8, 13, 22)
        hudContainer.BackgroundTransparency = 0.12
        hudContainer.BorderSizePixel = 0
        hudContainer.Active = false
        hudContainer.Parent = hudGui

        local hudContainerCorner = Instance.new("UICorner")
        hudContainerCorner.CornerRadius = UDim.new(0, 12)
        hudContainerCorner.Parent = hudContainer

        local hudContainerStroke = Instance.new("UIStroke")
        hudContainerStroke.Color = Color3.fromRGB(48, 151, 245)
        hudContainerStroke.Thickness = 1.15
        hudContainerStroke.Transparency = 0.22
        hudContainerStroke.Parent = hudContainer

        local hudContainerGradient = Instance.new("UIGradient")
        hudContainerGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 29, 47)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(7, 12, 20))
        })
        hudContainerGradient.Rotation = 90
        hudContainerGradient.Parent = hudContainer

        local hudAccent = Instance.new("Frame")
        hudAccent.Name = "AccentLine"
        hudAccent.Position = UDim2.fromOffset(12, 10)
        hudAccent.Size = UDim2.fromOffset(3, 18)
        hudAccent.BackgroundColor3 = ACCENT_BRIGHT
        hudAccent.BorderSizePixel = 0
        hudAccent.Parent = hudContainer

        local hudAccentCorner = Instance.new("UICorner")
        hudAccentCorner.CornerRadius = UDim.new(1, 0)
        hudAccentCorner.Parent = hudAccent

        hudStateText = Instance.new("TextLabel")
        hudStateText.Name = "State"
        hudStateText.Position = UDim2.fromOffset(23, 7)
        hudStateText.Size = UDim2.new(1, -46, 0, 24)
        hudStateText.BackgroundTransparency = 1
        hudStateText.Text = "AUTO THROW  /  ON"
        hudStateText.TextColor3 = Color3.fromRGB(239, 246, 255)
        hudStateText.TextSize = 12
        hudStateText.Font = Enum.Font.GothamBold
        hudStateText.TextXAlignment = Enum.TextXAlignment.Left
        hudStateText.TextYAlignment = Enum.TextYAlignment.Center
        hudStateText.Active = false
        hudStateText.Parent = hudContainer

        local hudDivider = Instance.new("Frame")
        hudDivider.Name = "Divider"
        hudDivider.Position = UDim2.fromOffset(12, 34)
        hudDivider.Size = UDim2.new(1, -24, 0, 1)
        hudDivider.BackgroundColor3 = Color3.fromRGB(66, 126, 184)
        hudDivider.BackgroundTransparency = 0.45
        hudDivider.BorderSizePixel = 0
        hudDivider.Parent = hudContainer

        local hudBar = Instance.new("Frame")
        hudBar.Name = "ProgressBar"
        hudBar.Position = UDim2.fromOffset(12, 43)
        hudBar.Size = UDim2.new(1, -24, 0, 24)
        hudBar.BackgroundColor3 = Color3.fromRGB(5, 12, 22)
        hudBar.BackgroundTransparency = 0.08
        hudBar.BorderSizePixel = 0
        hudBar.ClipsDescendants = true
        hudBar.Parent = hudContainer

        local hudBarCorner = Instance.new("UICorner")
        hudBarCorner.CornerRadius = UDim.new(0, 7)
        hudBarCorner.Parent = hudBar

        local hudBarStroke = Instance.new("UIStroke")
        hudBarStroke.Color = Color3.fromRGB(42, 104, 161)
        hudBarStroke.Thickness = 1
        hudBarStroke.Transparency = 0.42
        hudBarStroke.Parent = hudBar

        hudFill = Instance.new("Frame")
        hudFill.Name = "BlueProgress"
        hudFill.Size = UDim2.new(0, 0, 1, 0)
        hudFill.BackgroundColor3 = ACCENT
        hudFill.BackgroundTransparency = 0.02
        hudFill.BorderSizePixel = 0
        hudFill.Parent = hudBar

        local hudFillCorner = Instance.new("UICorner")
        hudFillCorner.CornerRadius = UDim.new(0, 7)
        hudFillCorner.Parent = hudFill

        local hudFillGradient = Instance.new("UIGradient")
        hudFillGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(27, 112, 218)),
            ColorSequenceKeypoint.new(0.55, Color3.fromRGB(42, 157, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(104, 205, 255))
        })
        hudFillGradient.Parent = hudFill

        hudInfoText = Instance.new("TextLabel")
        hudInfoText.Name = "Status"
        hudInfoText.Position = UDim2.fromOffset(10, 0)
        hudInfoText.Size = UDim2.new(1, -20, 1, 0)
        hudInfoText.BackgroundTransparency = 1
        hudInfoText.Text = "Starting..."
        hudInfoText.TextColor3 = Color3.fromRGB(255, 255, 255)
        hudInfoText.TextSize = 10
        hudInfoText.Font = Enum.Font.GothamSemibold
        hudInfoText.TextXAlignment = Enum.TextXAlignment.Center
        hudInfoText.TextYAlignment = Enum.TextYAlignment.Center
        hudInfoText.TextWrapped = false
        hudInfoText.TextTruncate = Enum.TextTruncate.AtEnd
        hudInfoText.ZIndex = 3
        hudInfoText.Parent = hudBar

        local infoHint = Instance.new("TextLabel")
        infoHint.Position = UDim2.fromOffset(13, 39)
        infoHint.Size = UDim2.new(1, -26, 0, 0)
        infoHint.Visible = false
        infoHint.BackgroundTransparency = 1
        infoHint.Text = helpers.tr("infoHint")
        infoHint.TextColor3 = MUTED
        infoHint.TextSize = 9
        infoHint.Font = Enum.Font.Gotham
        infoHint.TextWrapped = true
        infoHint.TextXAlignment = Enum.TextXAlignment.Left
        infoHint.TextYAlignment = Enum.TextYAlignment.Top
        infoHint.ZIndex = 81
        infoHint.Parent = infoPanel

        local statusDot = Instance.new("Frame")
        statusDot.Visible = false
        statusDot.Position = UDim2.fromOffset(14, 82)
        statusDot.Size = UDim2.fromOffset(7, 7)
        statusDot.BackgroundColor3 = Color3.fromRGB(115, 130, 150)
        statusDot.BorderSizePixel = 0
        statusDot.ZIndex = 82
        statusDot.Parent = infoPanel

        local statusDotCorner = Instance.new("UICorner")
        statusDotCorner.CornerRadius = UDim.new(1, 0)
        statusDotCorner.Parent = statusDot

        statusText = Instance.new("TextLabel")
        statusText.Name = "StatusText"
        statusText.Position = UDim2.fromOffset(14, 48)
        statusText.Size = UDim2.new(1, -28, 0, 128)
        statusText.BackgroundTransparency = 1
        statusText.Text = helpers.tr("idle")
        statusText.TextColor3 = TEXT
        statusText.TextSize = 10
        statusText.Font = Enum.Font.Gotham
        statusText.Text = helpers.tr("infoHint")
        statusText.TextWrapped = true
        statusText.TextXAlignment = Enum.TextXAlignment.Left
        statusText.TextYAlignment = Enum.TextYAlignment.Top
        statusText.ZIndex = 81
        statusText.Parent = infoPanel

        local sliderVisible = true
        local sliderTween

        helpers.setPowerSliderVisible = function(visible, instant)
            sliderVisible = visible
            if sliderTween then
                sliderTween:Cancel()
                sliderTween = nil
            end

            if visible then
                sliderContainer.Visible = true
                sliderContainer.Active = true
                sliderTrack.Active = true
                sliderKnob.Active = true
                if instant then
                    sliderContainer.Position = UDim2.fromOffset(12, 69)
                    sliderContainer.Size = UDim2.new(1, -24, 0, 54)
                    sliderContainer.GroupTransparency = 0
                    mainCard.Size = UDim2.new(1, 0, 0, 132)
                    trainCard.Position = UDim2.fromOffset(10, 198)
                else
                    sliderContainer.Position = UDim2.fromOffset(12, 54)
                    sliderContainer.Size = UDim2.new(1, -24, 0, 0)
                    sliderContainer.GroupTransparency = 1
                    mainCard.Size = UDim2.new(1, -20, 0, 66)
                    trainCard.Position = UDim2.fromOffset(10, 132)
                    helpers.makeTween(mainCard, 0.3, {Size = UDim2.new(1, 0, 0, 132)})
                    helpers.makeTween(trainCard, 0.3, {Position = UDim2.fromOffset(10, 198)})
                    helpers.makeTween(sliderContainer, 0.28, {
                        Position = UDim2.fromOffset(12, 69),
                        Size = UDim2.new(1, -24, 0, 54)
                    })
                    sliderTween = TweenService:Create(
                        sliderContainer,
                        TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                        {GroupTransparency = 0}
                    )
                    sliderTween:Play()
                end
            else
                sliderContainer.Active = false
                sliderTrack.Active = false
                sliderKnob.Active = false
                isDragging = false
                if instant then
                    sliderContainer.Visible = false
                    sliderContainer.Position = UDim2.fromOffset(12, 54)
                    sliderContainer.Size = UDim2.new(1, -24, 0, 0)
                    sliderContainer.GroupTransparency = 1
                    mainCard.Size = UDim2.new(1, -20, 0, 66)
                    trainCard.Position = UDim2.fromOffset(10, 132)
                else
                    helpers.makeTween(mainCard, 0.28, {Size = UDim2.new(1, -20, 0, 66)})
                    helpers.makeTween(trainCard, 0.28, {Position = UDim2.fromOffset(10, 132)})
                    helpers.makeTween(sliderContainer, 0.25, {
                        Position = UDim2.fromOffset(12, 52),
                        Size = UDim2.new(1, -24, 0, 0)
                    })
                    sliderTween = TweenService:Create(
                        sliderContainer,
                        TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
                        {GroupTransparency = 1}
                    )
                    sliderTween:Play()
                    sliderTween.Completed:Connect(function()
                        if not sliderVisible and sliderContainer.Parent then
                            sliderContainer.Visible = false
                        end
                    end)
                end
            end
        end

        local infoOpen = false

        helpers.refreshLanguage = function()
            title.Text = "AFK FARM"
            infoPanelTitle.Text = helpers.tr("infoTitle")
            infoHint.Text = helpers.tr("infoHint")
            sliderLabel.Text = string.format("%s: %d", helpers.tr("power"), selectedSpeed)
            stateLabel.Text = isEnabled and "ON" or "OFF"
            statusText.Text = helpers.tr("infoHint")
        end

        helpers.setSwitchVisual = function(enabled, instant)
            local knobPosition = enabled
                and UDim2.fromOffset(44, 3)
                or UDim2.fromOffset(3, 3)

            local switchColor = enabled
                and Color3.fromRGB(20, 105, 180)
                or Color3.fromRGB(43, 53, 68)

            local strokeTransparency = enabled and 0.08 or 0.55
            local knobColor = enabled
                and Color3.fromRGB(255, 255, 255)
                or Color3.fromRGB(220, 230, 242)

            if instant then
                switchKnob.Position = knobPosition
                switchButton.BackgroundColor3 = switchColor
                switchStroke.Transparency = strokeTransparency
                switchKnob.BackgroundColor3 = knobColor
                cardStroke.Transparency = enabled and 0.05 or 0.28
            else
                helpers.makeTween(switchKnob, 0.22, {Position = knobPosition})
                helpers.makeTween(switchButton, 0.22, {BackgroundColor3 = switchColor})
                helpers.makeTween(switchStroke, 0.22, {Transparency = strokeTransparency})
                helpers.makeTween(switchKnob, 0.22, {BackgroundColor3 = knobColor})
                helpers.makeTween(cardStroke, 0.25, {
                    Transparency = enabled and 0.05 or 0.28,
                    Thickness = enabled and 1.8 or 1.35
                })
            end

            stateLabel.Text = enabled and "ON" or "OFF"
            stateLabel.TextColor3 = enabled and ACCENT_BRIGHT or MUTED
            helpers.setPowerSliderVisible(not enabled, instant)
            if hudStateText then
                hudStateText.Text = "AUTO THROW   /   " .. (enabled and "ON" or "OFF")
            end
            if hudGui then
                hudGui.Enabled = enabled and not autoFarmRunning
            end
        end

        helpers.openInfo = function()
            if infoOpen then return end
            helpers.refreshLanguage()
            infoOpen = true
            infoPanel.Visible = true
            infoPanel.Position = UDim2.new(1, 275, 0, 55)
            infoPanel.BackgroundTransparency = 0.15
            infoPanelStroke.Transparency = 0.7

            helpers.makeTween(infoPanel, 0.32, {
                Position = UDim2.new(1, -10, 0, 55),
                BackgroundTransparency = 0
            })
            helpers.makeTween(infoPanelStroke, 0.32, {Transparency = 0.18})
        end

        helpers.closeInfo = function()
            if not infoOpen then return end
            infoOpen = false

            local closeTween = helpers.makeTween(infoPanel, 0.26, {
                Position = UDim2.new(1, 275, 0, 55),
                BackgroundTransparency = 0.2
            }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

            helpers.makeTween(infoPanelStroke, 0.2, {Transparency = 0.75})
            closeTween.Completed:Connect(function()
                if not infoOpen and infoPanel.Parent then
                    infoPanel.Visible = false
                end
            end)
        end

        infoButton.MouseButton1Click:Connect(function()
            if infoOpen then
                helpers.closeInfo()
            else
                helpers.openInfo()
            end
        end)

        closeInfoButton.MouseButton1Click:Connect(helpers.closeInfo)

        infoButton.MouseEnter:Connect(function()
            helpers.makeTween(infoButton, 0.15, {
                BackgroundColor3 = Color3.fromRGB(32, 62, 91)
            })
        end)
        infoButton.MouseLeave:Connect(function()
            helpers.makeTween(infoButton, 0.15, {
                BackgroundColor3 = Color3.fromRGB(24, 42, 62)
            })
        end)

        helpers.updateSlider = function(value)
            if isEnabled then return end
            selectedSpeed = math.clamp(
                math.floor(value + 0.5),
                MIN_POWER,
                MAX_POWER
            )

            local percentage =
                (selectedSpeed - MIN_POWER) / (MAX_POWER - MIN_POWER)

            helpers.makeTween(sliderFill, 0.08, {
                Size = UDim2.new(percentage, 0, 1, 0)
            }, Enum.EasingStyle.Quad)

            helpers.makeTween(sliderKnob, 0.08, {
                Position = UDim2.new(percentage, 0, 0.5, 0)
            }, Enum.EasingStyle.Quad)

            sliderLabel.Text = string.format(
                "%s: %d",
                helpers.tr("power"),
                selectedSpeed
            )
        end

        helpers.updateSliderFromInput = function(input)
            local trackWidth = sliderTrack.AbsoluteSize.X
            if trackWidth <= 0 then return end

            local relativeX =
                input.Position.X - sliderTrack.AbsolutePosition.X

            local percentage = math.clamp(relativeX / trackWidth, 0, 1)
            local value = MIN_POWER + percentage * (MAX_POWER - MIN_POWER)
            helpers.updateSlider(value)
        end

        sliderTrack.InputBegan:Connect(function(input)
            if isEnabled or not sliderVisible then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                isDragging = true
                helpers.updateSliderFromInput(input)
            end
        end)

        sliderKnob.InputBegan:Connect(function(input)
            if isEnabled or not sliderVisible then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                isDragging = true
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if not isDragging or isEnabled or not sliderVisible then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then
                helpers.updateSliderFromInput(input)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                isDragging = false
            end
        end)

        switchButton.MouseEnter:Connect(function()
            helpers.makeTween(switchStroke, 0.15, {Transparency = isEnabled and 0 or 0.3})
        end)
        switchButton.MouseLeave:Connect(function()
            helpers.makeTween(switchStroke, 0.15, {Transparency = isEnabled and 0.08 or 0.55})
        end)

        helpers.updateSlider(selectedSpeed)
        helpers.setPowerSliderVisible(true, true)
        helpers.setSwitchVisual(false, true)
        helpers.refreshLanguage()
        if hudGui then hudGui.Enabled = false end

                --==================================================
        -- SESSION CHECK
        --==================================================

        helpers.stillRunning = function(currentId)
            return isEnabled and actionId == currentId
        end

        --==================================================
        -- CANCELLABLE WAIT
        --==================================================

        helpers.waitWhileEnabled = function(seconds, currentId)
            local startTime = os.clock()
            local lastSecond = -1

            while os.clock() - startTime < seconds do
                if not helpers.stillRunning(currentId) then
                    return false
                end

                local elapsed = os.clock() - startTime
                local remaining = math.max(0, seconds - elapsed)
                local shown = math.ceil(remaining)

                if shown ~= lastSecond then
                    lastSecond = shown
                    helpers.setStatus(currentStatus, string.format("%ds remaining", shown),
                        math.clamp(elapsed / math.max(seconds, 0.01), 0, 1))
                else
                    helpers.setHudProgress(math.clamp(elapsed / math.max(seconds, 0.01), 0, 1))
                end

                task.wait(0.01)
            end

            return helpers.stillRunning(currentId)
        end

        --==================================================
        -- THROW COOLDOWN
        --==================================================

        helpers.waitForThrowCooldown = function(currentId)
            helpers.setStatus("cooldown", "Waiting for the game cooldown...", 0)
            helpers.debugLog("Waiting for ThrowReadyAt cooldown...")

            local lastDisplayedSecond = -1

            while helpers.stillRunning(currentId) do
                local readyAt = player:GetAttribute("ThrowReadyAt")

                if type(readyAt) == "number" then
                    local remaining = math.max(
                        0,
                        readyAt - workspace:GetServerTimeNow()
                    )

                    local displayedSecond = math.ceil(remaining)

                    if displayedSecond ~= lastDisplayedSecond then
                        lastDisplayedSecond = displayedSecond
                        helpers.setStatus("cooldown", string.format("%ds remaining", displayedSecond), 0)
                        helpers.debugLog(string.format(
                            "Throw cooldown remaining: %.2f seconds",
                            remaining
                        ))
                    end

                    if remaining <= 0 then
                        helpers.debugLog("Throw cooldown finished! Starting movement.")
                        return true
                    end
                else
                    helpers.setStatus("cooldown", "Waiting for cooldown timer...", 0)
                    helpers.debugLog("ThrowReadyAt not available yet. Waiting...")
                end

                task.wait(0.05)
            end

            return false
        end

        --==================================================
        -- POWER TARGET CALCULATION
        --==================================================

        helpers.getTargetY = function(power)
            power = math.clamp(
                math.floor(power + 0.5),
                MIN_POWER,
                MAX_POWER
            )

            if power <= 10 then
                local alpha = power / 10

                return POWER_0_Y
                    + (POWER_10_Y - POWER_0_Y) * alpha
            end

            local alpha = (power - 10) / 10

            return POWER_10_Y
                + (POWER_20_Y - POWER_10_Y) * alpha
        end

        --==================================================
        -- FIND THROW MARKER
        --==================================================

        helpers.getThrowMarker = function()
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

        helpers.waitForMarker = function(currentId)
            helpers.setStatus("marker", "Waiting for the selected power marker...", 0)
            helpers.debugLog("Waiting for ThrowSequence Marker...")

            local startTime = os.clock()

            while helpers.stillRunning(currentId) do
                local marker = helpers.getThrowMarker()

                if marker and marker:IsA("GuiObject") then
                    helpers.debugLog("ThrowSequence Marker found!")
                    return marker
                end

                if os.clock() - startTime >= MARKER_TIMEOUT then
                    error("ThrowSequence Marker not found. Timed out.")
                end

                task.wait(0.01)
            end

            return nil
        end

        --==================================================
        -- REAL MARKER POWER DETECTION
        --==================================================

        helpers.waitForSelectedPower = function(power, currentId)
            local targetY = helpers.getTargetY(power)

            helpers.debugLog(string.format(
                "Power target: %d | Target Y: %.6f",
                power,
                targetY
            ))

            local marker = helpers.waitForMarker(currentId)

            if not marker then
                return false
            end

            local previousY = nil

            local sawDescending = false
            local sawAscending = false

            local startTime = os.clock()

            if power >= 10 then
                helpers.debugLog("Detection mode: FIRST PASS (Y decreasing).")
            else
                helpers.debugLog("Detection mode: SECOND PASS (Y increasing).")
            end

            while helpers.stillRunning(currentId) do
                if not marker.Parent then
                    marker = helpers.getThrowMarker()

                    if not marker then
                        error("ThrowSequence Marker disappeared.")
                    end
                end

                local currentY = marker.Position.Y.Scale
                -- The HUD bar follows the marker's real position in the game meter.
                helpers.setHudProgress(1 - math.clamp(currentY, 0, 1))

                if previousY ~= nil then
                    local difference = currentY - previousY

                    if difference < -DIRECTION_EPSILON then
                        sawDescending = true
                    end

                    if sawDescending
                        and difference > DIRECTION_EPSILON then

                        if not sawAscending then
                            sawAscending = true

                            helpers.debugLog(
                                "Marker reversed direction. Second pass started."
                            )
                        end
                    end

                    if power >= 10 and sawDescending then
                        if currentY <= targetY + MARKER_TOLERANCE then
                            helpers.debugLog(string.format(
                                "POWER %d CAUGHT! Y: %.6f",
                                power,
                                currentY
                            ))

                            return true
                        end
                    end

                    if power < 10 and sawAscending then
                        if currentY >= targetY - MARKER_TOLERANCE then
                            helpers.debugLog(string.format(
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

        helpers.performClick = function(currentId)
            if not helpers.stillRunning(currentId) then
                return false
            end

            helpers.setStatus("throwing", "Sending throw input...", 0)
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

            helpers.debugLog("MB1 click completed.")

            return true
        end

        --==================================================
        -- GET STARTERAREA POSITION
        --==================================================

        helpers.getStarterAreaPosition = function()
            local starterArea = workspace:WaitForChild("StarterArea")

            if starterArea:IsA("BasePart") then
                return starterArea.Position
            end

            return starterArea:GetPivot().Position
        end

        --==================================================
        -- GET CHARACTER REFERENCES
        --==================================================

        helpers.getCharacterReferences = function()
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

        helpers.getWaypointDistance = function(rootPart, waypoint)
            if not rootPart or not waypoint then
                return math.huge
            end

            return (rootPart.Position - waypoint.Position).Magnitude
        end

        helpers.hasReachedWaypoint = function(rootPart, waypoint)
            local distance =
                helpers.getWaypointDistance(rootPart, waypoint)

            helpers.debugLog(string.format(
                "Waypoint distance: %.2f studs",
                distance
            ))

            return distance <= WAYPOINT_REACH_DISTANCE
        end

        --==================================================
        -- FOLLOW PATH
        --==================================================

        helpers.followPath = function(path, character, humanoid, currentId)
            local waypoints = path:GetWaypoints()

            helpers.debugLog("Route found. Waypoints: " .. #waypoints)

            for index, waypoint in ipairs(waypoints) do
                if not helpers.stillRunning(currentId) then
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

                if helpers.hasReachedWaypoint(rootPart, waypoint) then
                    helpers.debugLog(
                        "Waypoint " .. index .. " already reached. Skipping."
                    )

                    continue
                end

                if waypoint.Action == Enum.PathWaypointAction.Jump then
                    humanoid.Jump = true
                    helpers.debugLog("Jumping over obstacle...")
                end

                helpers.debugLog(
                    "Moving to waypoint "
                    .. index
                    .. "/"
                    .. #waypoints
                )

                humanoid:MoveTo(waypoint.Position)

                local startTime = os.clock()
                local reached = false

                while helpers.stillRunning(currentId) do
                    if player.Character ~= character then
                        return false
                    end

                    rootPart =
                        character:FindFirstChild("HumanoidRootPart")

                    if not rootPart then
                        return false
                    end

                    local distance =
                        helpers.getWaypointDistance(rootPart, waypoint)

                    if distance <= WAYPOINT_REACH_DISTANCE then
                        reached = true

                        helpers.debugLog(string.format(
                            "Waypoint %d reached at %.2f studs.",
                            index,
                            distance
                        ))

                        break
                    end

                    if os.clock() - startTime >= WAYPOINT_TIMEOUT then
                        break
                    end

                    task.wait(0.02)
                end

                if not helpers.stillRunning(currentId) then
                    return false
                end

                if not reached then
                    helpers.debugLog(
                        "Waypoint timeout at "
                        .. index
                        .. ". Recalculation required."
                    )

                    return false
                end
            end

            return true
        end

        helpers.getWorldPosition = function(object)
            if not object then return nil end
            if object:IsA("BasePart") then return object.Position end
            if object:IsA("Model") then return object:GetPivot().Position end
            if object:IsA("Attachment") then return object.WorldPosition end
            local part = object:FindFirstChildWhichIsA("BasePart", true)
            return part and part.Position or nil
        end

        helpers.tryTeleportToPosition = function(targetPosition, isStillActive)
            local character, humanoid, rootPart = helpers.getCharacterReferences()
            if not character or not humanoid or not rootPart or humanoid.Health <= 0 then
                return false
            end

            local originalRotation = rootPart.CFrame - rootPart.Position
            local ok = pcall(function()
                rootPart.CFrame = CFrame.new(targetPosition) * originalRotation
                rootPart.AssemblyLinearVelocity = Vector3.zero
                rootPart.AssemblyAngularVelocity = Vector3.zero
            end)
            if not ok then return false end

            task.wait(0.25)
            if isStillActive and not isStillActive() then return false end
            if player.Character ~= character then return false end

            local currentRoot = character:FindFirstChild("HumanoidRootPart")
            if not currentRoot or (currentRoot.Position - targetPosition).Magnitude > 8 then
                return false
            end

            task.wait(0.35)
            if isStillActive and not isStillActive() then return false end
            currentRoot = character:FindFirstChild("HumanoidRootPart")
            if not currentRoot or (currentRoot.Position - targetPosition).Magnitude > 8 then
                helpers.debugLog("Teleport was rejected or rolled back; walking fallback will be used.")
                return false
            end
            return true
        end

        --==================================================
        -- PATHFINDING MOVEMENT
        --==================================================

        helpers.moveToStarterArea = function(currentId)
            helpers.setStatus("moving", nil)
            helpers.debugLog("Finding path to StarterArea...")

            local character, humanoid, rootPart =
                helpers.getCharacterReferences()

            if not character or not humanoid or not rootPart then
                error("Character references not found.")
            end

            local targetPosition = helpers.getStarterAreaPosition()

            if not helpers.stillRunning(currentId) then
                return false
            end

            -- Auto Throw: teleport 4 studs from CrossLine toward Lobby.Grass,
            -- then teleport to StarterArea. Pathfinding is the fallback.
            local starterArea = workspace:FindFirstChild("StarterArea")
            local crossLine = starterArea and starterArea:FindFirstChild("CrossLine")
            local lobby = workspace:FindFirstChild("Lobby")
            local grass = lobby and lobby:FindFirstChild("Grass")
            local crossPosition = helpers.getWorldPosition(crossLine)
            local grassPosition = helpers.getWorldPosition(grass)
            local teleported = false

            if crossPosition and grassPosition then
                local direction = grassPosition - crossPosition
                if direction.Magnitude > 0.001 then
                    local fourStudPoint = crossPosition + direction.Unit * 4
                    helpers.debugLog("Attempting CrossLine teleport 4 studs toward Lobby.Grass.")
                    local firstTeleport = helpers.tryTeleportToPosition(
                        fourStudPoint,
                        function() return helpers.stillRunning(currentId) end
                    )
                    if firstTeleport and helpers.stillRunning(currentId) then
                        teleported = helpers.tryTeleportToPosition(
                            targetPosition,
                            function() return helpers.stillRunning(currentId) end
                        )
                    end
                end
            else
                helpers.debugLog("CrossLine or Lobby.Grass missing; attempting direct StarterArea teleport.")
                teleported = helpers.tryTeleportToPosition(
                    targetPosition,
                    function() return helpers.stillRunning(currentId) end
                )
            end

            if teleported then
                helpers.debugLog("StarterArea teleport confirmed.")
                return true
            end

            helpers.debugLog("Teleport sequence failed; switching to pathfinding fallback.")

            for attempt = 1, MAX_PATH_RETRIES do
                if not helpers.stillRunning(currentId) then
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

                helpers.debugLog(string.format(
                    "StarterArea distance: %.2f studs",
                    targetDistance
                ))

                if targetDistance <= WAYPOINT_REACH_DISTANCE then
                    helpers.debugLog("Already near StarterArea. No extra movement.")
                    return true
                end

                local path = PathfindingService:CreatePath({
                    AgentRadius = 2,
                    AgentHeight = 5,
                    AgentCanJump = true,
                    AgentCanClimb = true,
                    WaypointSpacing = 4
                })

                helpers.debugLog(
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
                    helpers.debugLog(
                        "Path calculation error: "
                        .. tostring(computeError)
                    )

                    task.wait(0.05)
                    continue
                end

                if not helpers.stillRunning(currentId) then
                    return false
                end

                if path.Status ~= Enum.PathStatus.Success then
                    helpers.debugLog("Pathfinding status: " .. tostring(path.Status))
                    task.wait(0.05)
                    continue
                end

                local success = helpers.followPath(
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

                        helpers.debugLog(string.format(
                            "Final StarterArea distance: %.2f studs",
                            finalDistance
                        ))

                        if finalDistance <= WAYPOINT_REACH_DISTANCE then
                            helpers.debugLog("StarterArea reached successfully!")
                            return true
                        end
                    end
                end

                if not helpers.stillRunning(currentId) then
                    return false
                end

                helpers.debugLog("Recalculating route...")
                task.wait(0.05)
            end

            error("Could not reach StarterArea after path retries.")
        end

        --==================================================
        -- RESET CHARACTER
        --==================================================

        helpers.resetCharacter = function(currentId)
            if not helpers.stillRunning(currentId) then
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

            helpers.setStatus("resetting", "Respawning character...")
            helpers.debugLog("Resetting character...")

            humanoid.Health = 0

            while helpers.stillRunning(currentId) do
                local newCharacter = player.Character

                if newCharacter and newCharacter ~= oldCharacter then
                    local newHumanoid =
                        newCharacter:FindFirstChildOfClass("Humanoid")

                    local newRoot =
                        newCharacter:FindFirstChild("HumanoidRootPart")

                    if newHumanoid and newRoot
                        and newHumanoid.Health > 0 then

                        helpers.debugLog("Character respawned!")
                        return true
                    end
                end

                task.wait(0.02)
            end

            return false
        end

        --==================================================
        -- AUTO TRAIN: FIND TRAINING SPOT AND EXIT CONTROL
        --==================================================

        helpers.findTrainingSpot = function()
            local plotProps = workspace:FindFirstChild("LocalPlotProps")
            if not plotProps then
                plotProps = workspace:FindFirstChild("LocalPlotProps", true)
            end
            if not plotProps then
                return nil, "LocalPlotProps was not found in Workspace."
            end

            local trainingArea = plotProps:FindFirstChild("TrainingArea")
                or plotProps:FindFirstChild("TrainingArea", true)
            if not trainingArea then
                return nil, "TrainingArea was not found under LocalPlotProps."
            end

            local trainingSpot = trainingArea:FindFirstChild("TrainingSpot")
                or trainingArea:FindFirstChild("TrainingSpot", true)
            if not trainingSpot then
                return nil, "TrainingSpot was not found under TrainingArea."
            end

            return trainingSpot
        end

        helpers.getTrainingSpotPosition = function(spot)
            if spot:IsA("BasePart") then
                return spot.Position
            elseif spot:IsA("Model") then
                return spot:GetPivot().Position
            elseif spot:IsA("Attachment") then
                return spot.WorldPosition
            end
            local part = spot:FindFirstChildWhichIsA("BasePart", true)
            if part then return part.Position end
            return nil
        end

        helpers.findTrainingStopButton = function()
            -- Exact game UI path: Players > LocalPlayer > PlayerGui > TrainingSequence > Button
            local trainingSequence = playerGui:FindFirstChild("TrainingSequence")
            if not trainingSequence then
                return nil
            end

            local stopButton = trainingSequence:FindFirstChild("Button", true)
            if stopButton and stopButton:IsA("GuiButton") then
                return stopButton
            end

            return nil
        end

        helpers.isTrainingSequenceActive = function()
            return playerGui:FindFirstChild("TrainingSequence") ~= nil
        end

        helpers.pressTrainingStopWithoutMouse = function()
            local keyCode = Enum.KeyCode.Space

            if type(keypress) == "function" and type(keyrelease) == "function" then
                local ok, err = pcall(function()
                    keypress(0x20)
                    task.wait(0.08)
                    keyrelease(0x20)
                end)
                if ok then
                    helpers.debugLog("SPACE sent through executor keyboard input.")
                    return true
                end
                warn("[BZHUB AUTO TRAIN] Executor SPACE input failed: " .. tostring(err))
            end

            local virtualOk, virtualErr = pcall(function()
                VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
                task.wait(0.08)
                VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
            end)
            if virtualOk then
                helpers.debugLog("SPACE sent through VirtualInputManager.")
                return true
            end

            warn("[BZHUB AUTO TRAIN] Could not send SPACE: " .. tostring(virtualErr))
            return false, "SPACE input is unavailable: " .. tostring(virtualErr)
        end

        helpers.exitTrainingSequence = function(maxAttempts)
            maxAttempts = maxAttempts or 20

            for attempt = 1, maxAttempts do
                if not helpers.isTrainingSequenceActive() then
                    helpers.debugLog("TrainingSequence disappeared; training exit confirmed.")
                    return true
                end

                local sent, sendError = helpers.pressTrainingStopWithoutMouse()
                if not sent then
                    helpers.debugLog("SPACE attempt " .. attempt .. " failed: " .. tostring(sendError))
                end

                task.wait(0.4)
                if not helpers.isTrainingSequenceActive() then
                    helpers.debugLog("Training exit confirmed after SPACE attempt " .. attempt .. ".")
                    return true
                end
            end

            warn("[BZHUB AUTO TRAIN] TrainingSequence still exists after controlled SPACE retries.")
            return false
        end

        helpers.waitForTrainingExit = function(timeout)
            local started = os.clock()
            while helpers.isTrainingSequenceActive() and os.clock() - started < (timeout or 12) do
                task.wait(0.1)
            end
            return not helpers.isTrainingSequenceActive()
        end

        startTrain = function()
            trainActionId += 1
            local thisTrainId = trainActionId

            task.spawn(function()
                local ok, err = pcall(function()
                    activeHudMode = "train"
                    helpers.setStatus("trainMoving", "Walking to TrainingSpot...")

                    local spot, findError = helpers.findTrainingSpot()
                    if not spot then error(findError) end
                    local targetPosition = helpers.getTrainingSpotPosition(spot)
                    if not targetPosition then error("TrainingSpot has no usable position.") end

                    local character, humanoid, rootPart = helpers.getCharacterReferences()
                    if not character or not humanoid or not rootPart then
                        error("Character references are unavailable.")
                    end

                    local trainTeleported = helpers.tryTeleportToPosition(targetPosition, function()
                        return trainEnabled and trainActionId == thisTrainId
                    end)

                    if not trainTeleported then
                        helpers.debugLog("TrainingSpot teleport failed; walking fallback started.")
                        local path = PathfindingService:CreatePath({
                            AgentRadius = 2,
                            AgentHeight = 5,
                            AgentCanJump = true,
                            AgentCanClimb = true,
                            WaypointSpacing = 4
                        })
                        path:ComputeAsync(rootPart.Position, targetPosition)
                        if path.Status ~= Enum.PathStatus.Success then
                            error("Pathfinding failed: " .. tostring(path.Status))
                        end

                        local waypoints = path:GetWaypoints()
                    local totalPathDistance = 0
                    local previousPosition = rootPart.Position
                    for _, waypoint in ipairs(waypoints) do
                        totalPathDistance += (waypoint.Position - previousPosition).Magnitude
                        previousPosition = waypoint.Position
                    end
                    totalPathDistance = math.max(totalPathDistance, 0.001)
                    local completedPathDistance = 0

                    helpers.setStatus("trainMoving", "Calculating route...", 0)
                    for index, waypoint in ipairs(waypoints) do
                        if not trainEnabled or trainActionId ~= thisTrainId then return end
                        if player.Character ~= character then return end
                        rootPart = character:FindFirstChild("HumanoidRootPart")
                        if not rootPart then error("HumanoidRootPart disappeared.") end

                        humanoid:MoveTo(waypoint.Position)
                        local segmentStartDistance = (rootPart.Position - waypoint.Position).Magnitude
                        local started = os.clock()
                        while trainEnabled and trainActionId == thisTrainId do
                            if player.Character ~= character then return end
                            rootPart = character:FindFirstChild("HumanoidRootPart")
                            if not rootPart then return end
                            local remainingDistance = (rootPart.Position - waypoint.Position).Magnitude
                            local segmentProgress = 1 - math.clamp(remainingDistance / math.max(segmentStartDistance, 0.001), 0, 1)
                            local totalProgress = (completedPathDistance + segmentStartDistance * segmentProgress) / totalPathDistance
                            helpers.setStatus("trainMoving", string.format("Waypoint %d/%d", index, #waypoints), totalProgress)
                            if remainingDistance <= 3.5 then
                                break
                            end
                            if os.clock() - started > WAYPOINT_TIMEOUT then
                                error("Timed out while walking to TrainingSpot (waypoint " .. index .. ").")
                            end
                            task.wait(0.1)
                        end
                        completedPathDistance += segmentStartDistance
                    end
                    end -- teleport-fallback pathfinding block

                    if not trainEnabled or trainActionId ~= thisTrainId then return end
                    helpers.setStatus("training", "TrainingSpot reached. Training is active.", 1)
                    helpers.debugLog("TrainingSpot reached. Waiting until Auto Train is disabled.")
                    while trainEnabled and trainActionId == thisTrainId do
                        task.wait(0.2)
                    end
                end)

                if not ok and trainActionId == thisTrainId then
                    warn("[BZHUB AUTO TRAIN ERROR] " .. tostring(err))
                    helpers.setStatus("trainError", tostring(err))
                end
            end)
        end

        stopTrain = function()
            trainActionId += 1
            activeHudMode = isEnabled and "throw" or "train"
            if trainEnabled then return end

            if hudGui then hudGui.Enabled = false end
            helpers.setStatus("trainStopping", "Sending SPACE and checking TrainingSequence...", 0)
            task.spawn(function()
                local exited = helpers.exitTrainingSequence(20)
                if not exited then
                    helpers.debugLog("Training exit was not confirmed; TrainingSequence remains present.")
                end

                if isEnabled then
                    activeHudMode = "throw"
                    helpers.setStatus(currentStatus, currentStatusDetail)
                else
                    helpers.setStatus(exited and "trainStopped" or "trainError",
                        exited and "Training exited." or "Could not confirm training exit.")
                end
            end)
        end

        --==================================================
        -- MAIN FARM LOOP
        --==================================================

        helpers.startFarm = function()
            actionId += 1

            local currentId = actionId

            firstCycle = not autoFarmRunning or autoFarmFirstCycle

            task.spawn(function()
                local success, err = pcall(function()

                    helpers.setStatus("starting")
                    helpers.debugLog("Farm started.")

                    while helpers.stillRunning(currentId) do

                        -- 1. WALK TO STARTERAREA
                        if not helpers.moveToStarterArea(currentId) then
                            break
                        end

                        -- 2. ONLY FIRST CYCLE: WAIT 6 SECONDS
                        if firstCycle then
                            helpers.setStatus("initialWait", "6s remaining", 0)
                            helpers.debugLog("First cycle: waiting 6 seconds at StarterArea...")

                            if not helpers.waitWhileEnabled(
                                INITIAL_STARTER_WAIT,
                                currentId
                            ) then
                                break
                            end

                            firstCycle = false
                            if autoFarmRunning then autoFarmFirstCycle = false end
                        end

                        -- 3. GET SELECTED POWER
                        local targetPower = selectedSpeed

                        helpers.debugLog(
                            "StarterArea reached. Selected power: "
                            .. targetPower
                        )

                        -- 4. WAIT FOR MARKER POWER
                        if not helpers.waitForSelectedPower(
                            targetPower,
                            currentId
                        ) then
                            break
                        end

                        -- 5. CLICK / THROW
                        if not helpers.performClick(currentId) then
                            break
                        end
                        api.TotalThrows += 1

                        -- 6. WAIT BEFORE RESET
                        helpers.debugLog("Waiting 1 second before reset...")

                        if not helpers.waitWhileEnabled(
                            AFTER_CLICK_DELAY,
                            currentId
                        ) then
                            break
                        end

                        -- 7. RESET CHARACTER
                        if not helpers.resetCharacter(currentId) then
                            break
                        end

                        -- 8. WAIT UNTIL THROW COOLDOWN IS ZERO
                        if not helpers.waitForThrowCooldown(currentId) then
                            break
                        end

                        if autoFarmRunning then
                            autoFarmThrowCount += 1
                            helpers.setAfkThrowCount(autoFarmThrowTarget - autoFarmThrowCount)
                            if autoFarmThrowCount >= autoFarmThrowTarget then
                                autoFarmThrowDone = true
                                isEnabled = false
                                helpers.setSwitchVisual(false, false)
                                break
                            end
                        end

                        -- 9. LOOP RESTARTS AND WALKS TO STARTERAREA
                        helpers.debugLog("Cooldown finished. Moving to StarterArea...")

                        -- D ng  ba a d ner:
                        -- StarterArea'ya y r r, animasyon ba lar,
                        -- g   yakalan r, f rlat l r ve tekrar reset at l r.
                    end

                end)

                if not success then
                    warn("[BZHUB FARM ERROR] " .. tostring(err))

                    if currentId == actionId then
                        isEnabled = false
                        if autoFarmRunning then
                            autoFarmThrowDone = true
                            autoFarmRunning = false
                            autoFarmWorkerId += 1
                            autoFarmButton.Text = "START"
                            autoFarmButton.BackgroundColor3 = Color3.fromRGB(12, 25, 65)
                            afkHeader.Text = "AFK FARM / ERROR"
                        end
                        helpers.setSwitchVisual(false, false)
                        helpers.setStatus("error", tostring(err))
                        if hudGui then hudGui.Enabled = false end
                    end
                end

                helpers.debugLog("Farm loop stopped.")
            end)
        end

        --==================================================
        -- AFK FARM SEQUENCE
        --==================================================

        helpers.stopAutomationToggles = function()
            -- Stop Auto Throw in both the UI and game-side worker.
            if isEnabled then
                isEnabled = false
                actionId += 1
            end
            helpers.setSwitchVisual(false, true)

            -- Stop Auto Train and its in-game training session (SPACE), only if it was active.
            local wasTraining = trainEnabled
            if wasTraining then
                trainEnabled = false
                trainActionId += 1
            end
            trainStateLabel.Text = "OFF"
            trainStateLabel.TextColor3 = MUTED
            helpers.setRedSwitch(trainSwitch, trainKnob, trainSwitchStroke, false, true)
            if wasTraining and stopTrain then stopTrain() end

            -- Stop Auto 2X worker and reset its switch.
            helpers.setAuto2xEnabled(false, true)

            -- Stop Auto Equip Best Pet worker.
            autoEquipBestEnabled = false
            if helpers.stopAutoEquipBest then helpers.stopAutoEquipBest() else autoEquipBestWorkerId += 1 end
            equipAllButton.Text = "EQUIP BEST"
            equipAllButton.BackgroundColor3 = Color3.fromRGB(28, 78, 55)
            equipAllStroke.Color = EQUIP_GREEN
            equipStateLabel.Text = "OFF"
            equipStateLabel.TextColor3 = MUTED
            helpers.setEquipSwitchVisual(false, true)
            helpers.makeTween(equipBestStroke, 0.15, {Transparency = 0.3, Thickness = 1.35})

            if hudGui then hudGui.Enabled = false end
            if infoOpen then helpers.closeInfo() end
        end

        helpers.setTrainForAutoFarm = function(enabled)
            if enabled then
                trainEnabled = true
                activeHudMode = "train"
                trainStateLabel.Text = "ON"
                trainStateLabel.TextColor3 = TRAIN_RED_BRIGHT
                helpers.setRedSwitch(trainSwitch, trainKnob, trainSwitchStroke, true, true)
                auto2xRow.Visible = true
                auto2xRow.BackgroundTransparency = 0.12
                auto2xRow.Position = UDim2.fromOffset(12, 66)
                trainCard.Size = UDim2.new(1, 0, 0, 116)
                trainCardStroke.Transparency = 0.08
                trainCardStroke.Thickness = 1.8
                currentStatus = "trainMoving"
                startTrain()
                helpers.setAuto2xEnabled(true, true)
            else
                trainEnabled = false
                trainActionId += 1
                trainStateLabel.Text = "OFF"
                trainStateLabel.TextColor3 = MUTED
                helpers.setRedSwitch(trainSwitch, trainKnob, trainSwitchStroke, false, true)
                helpers.setAuto2xEnabled(false, true)
                auto2xRow.Visible = false
                trainCard.Size = UDim2.new(1, 0, 0, 62)
                trainCardStroke.Transparency = 0.3
                trainCardStroke.Thickness = 1.35
                if stopTrain then stopTrain() end
            end
        end

        helpers.readEquippedPetNames = function()
            local found, names = {}, {}
            local function scan(container)
                if not container then return end
                for _, child in ipairs(container:GetChildren()) do
                    if child:IsA("Tool") then
                        local animalId = child:GetAttribute("AnimalId")
                        if animalId ~= nil and not found[tostring(animalId)] then
                            found[tostring(animalId)] = true
                            table.insert(names, child.Name)
                        end
                    end
                end
            end
            scan(player:FindFirstChild("Backpack"))
            scan(player.Character)
            table.sort(names)
            return names
        end

        helpers.startAutoFarm = function()
            if autoFarmRunning then return end
            autoFarmRunning = true
            autoFarmWorkerId += 1
            local thisWorkerId = autoFarmWorkerId

            helpers.stopAutomationToggles()
            autoFarmButton.Text = "STOP"
            autoFarmButton.BackgroundColor3 = Color3.fromRGB(12, 25, 65)
            afkHudGui.Enabled = true
            afkHeader.Text = "AFK FARM / ON"
            helpers.setAfkThrowCount(autoFarmThrowTarget)
            helpers.setAfkTraining(autoFarmTrainingSeconds)
            autoFarmFirstCycle = true
            helpers.setAfkPets(nil)

            task.spawn(function()
                local ok, err = pcall(function()
                    while autoFarmRunning and autoFarmWorkerId == thisWorkerId do
                        -- Phase 1: three throws at 20 power.
                        helpers.stopAutomationToggles()
                        if not helpers.waitForTrainingExit(12) then
                            error("TrainingSequence is still present; AFK Farm cannot start Auto Throw.")
                        end
                        selectedSpeed = 20
                        helpers.updateSlider(selectedSpeed)
                        sliderLabel.Text = string.format("%s: %d", helpers.tr("power"), selectedSpeed)
                        autoFarmThrowCount = 0
                        autoFarmThrowDone = false
                        helpers.setAfkThrowCount(autoFarmThrowTarget)
                        isEnabled = true
                        activeHudMode = "throw"
                        helpers.setSwitchVisual(true, true)
                        helpers.startFarm()

                        while autoFarmRunning and autoFarmWorkerId == thisWorkerId and not autoFarmThrowDone do
                            task.wait(0.02)
                        end
                        if not autoFarmRunning or autoFarmWorkerId ~= thisWorkerId then break end

                        -- Phase 2: train for 60 seconds while Auto 2X is active.
                        helpers.setTrainForAutoFarm(true)
                        local trainingStarted = os.clock()
                        local trainingReady = false
                        while autoFarmRunning and autoFarmWorkerId == thisWorkerId do
                            if currentStatus == "training" then
                                trainingReady = true
                                break
                            elseif currentStatus == "trainError" then
                                error("Auto Train: " .. tostring(currentStatusDetail))
                            end
                            if os.clock() - trainingStarted > 120 then
                                error("TrainingSpot'a 120 saniye i inde ula  lamad .")
                            end
                            task.wait(0.02)
                        end
                        if not autoFarmRunning or autoFarmWorkerId ~= thisWorkerId then break end
                        if not trainingReady then error("Training ba lat lamad .") end

                        for remaining = autoFarmTrainingSeconds, 0, -1 do
                            if not autoFarmRunning or autoFarmWorkerId ~= thisWorkerId then break end
                            helpers.setAfkTraining(remaining)
                            task.wait(1)
                        end
                        if not autoFarmRunning or autoFarmWorkerId ~= thisWorkerId then break end

                        -- Phase 3: stop training, then equip best pets and list names.
                        helpers.setTrainForAutoFarm(false)
                        local trainingExited = helpers.waitForTrainingExit(12)
                        if not trainingExited then
                            error("TrainingSequence remained visible after Auto Train was stopped.")
                        end
                        local equipped = helpers.invokeEquipBest()
                        task.wait(0.1)
                        local petNames = helpers.readEquippedPetNames()
                        helpers.setAfkPets(petNames)
                        helpers.debugLog("AFK Farm Equip Best: " .. tostring(equipped) .. "; pets: " .. table.concat(petNames, ", "))
                    end
                end)

                if not ok then
                    warn("[BZHUB AFK FARM ERROR] " .. tostring(err))
                    autoFarmRunning = false
                    autoFarmWorkerId += 1
                    helpers.stopAutomationToggles()
                    autoFarmButton.Text = "START"
                    autoFarmButton.BackgroundColor3 = Color3.fromRGB(12, 25, 65)
                    afkHeader.Text = "AFK FARM / ERROR"
                    afkHudGui.Enabled = true
                end
            end)
        end

        helpers.stopAutoFarm = function()
            if not autoFarmRunning then return end
            autoFarmRunning = false
            autoFarmWorkerId += 1
            autoFarmThrowDone = true
            helpers.stopAutomationToggles()
            autoFarmButton.Text = "START"
            autoFarmButton.BackgroundColor3 = Color3.fromRGB(12, 25, 65)
            afkHeader.Text = "AFK FARM / OFF"
            afkHudGui.Enabled = false
            helpers.setAfkThrowCount(autoFarmThrowTarget)
            helpers.setAfkTraining(autoFarmTrainingSeconds)
        end

        autoFarmButton.MouseButton1Click:Connect(function()
            if autoFarmRunning then
                helpers.stopAutoFarm()
            else
                helpers.startAutoFarm()
            end
        end)

        --==================================================
        -- TOGGLE
        --==================================================

        switchButton.MouseButton1Click:Connect(function()
            if autoFarmRunning then return end
            if not isEnabled and trainEnabled then
                helpers.debugLog("Auto Throw toggle blocked: Auto Train is already enabled.")
                return
            end

            isEnabled = not isEnabled

            if isEnabled then
                activeHudMode = "throw"
                helpers.setSwitchVisual(true, false)
                helpers.setStatus("starting")
                helpers.debugLog("Farm enabled.")
                helpers.startFarm()
            else
                actionId += 1
                helpers.setSwitchVisual(false, false)
                if trainEnabled then
                    activeHudMode = "train"
                    helpers.setStatus("training")
                else
                    helpers.setStatus("stopped")
                    if hudGui then hudGui.Enabled = false end
                end
                helpers.debugLog("Farm disabled.")
            end
        end)

        helpers.debugLog("Farm module loaded.")

        -- Keep labels synchronized if the Roblox client language changes.
        LocalizationService:GetPropertyChangedSignal("RobloxLocaleId"):Connect(function()
            helpers.refreshLanguage()
        end)

        --==================================================
        -- AUTOMATION CATEGORY BUTTON SOUNDS
        --==================================================
        -- This category has its own callback, so its buttons must be
        -- connected here rather than relying on the Upgrades category.
        local automationSoundService = game:GetService("SoundService")
        local automationContentProvider = game:GetService("ContentProvider")
        local automationDebris = game:GetService("Debris")
        local AUTOMATION_SOUND_ID = "rbxassetid://12221967"
        local AUTOMATION_SOUND_VOLUME = 1
        local AUTOMATION_SOUND_SPEED = 1
        local AUTOMATION_SOUND_DEBOUNCE = 0.08

        local automationSoundTemplate = Instance.new("Sound")
        automationSoundTemplate.Name = "BZHUB_AutomationButtonClickTemplate"
        automationSoundTemplate.SoundId = AUTOMATION_SOUND_ID
        automationSoundTemplate.Volume = AUTOMATION_SOUND_VOLUME
        automationSoundTemplate.PlaybackSpeed = AUTOMATION_SOUND_SPEED
        automationSoundTemplate.Parent = automationSoundService

        task.spawn(function()
            local ok, err = pcall(function()
                automationContentProvider:PreloadAsync({automationSoundTemplate})
            end)
            if ok then
                print("[BZHUB AUTOMATION SOUND] Template loaded:", automationSoundTemplate.IsLoaded)
            else
                warn("[BZHUB AUTOMATION SOUND] Template preload failed:", err)
            end
        end)

        local automationConnectedButtons = setmetatable({}, {__mode = "k"})
        local automationButtonCount = 0

        local function playAutomationButtonSound(button)
            local sound = automationSoundTemplate:Clone()
            sound.Name = "BZHUB_AutomationButtonClick"
            sound.Volume = AUTOMATION_SOUND_VOLUME
            sound.PlaybackSpeed = AUTOMATION_SOUND_SPEED
            sound.Parent = automationSoundService

            task.spawn(function()
                local loaded, loadErr = pcall(function()
                    automationContentProvider:PreloadAsync({sound})
                end)
                if not loaded then
                    warn("[BZHUB AUTOMATION SOUND] Click preload failed:", loadErr)
                end

                local played, playErr = pcall(function()
                    sound:Play()
                end)
                if played then
                    print("[BZHUB AUTOMATION SOUND] PLAYED:", button.Name)
                    automationDebris:AddItem(sound, 4)
                else
                    warn("[BZHUB AUTOMATION SOUND] Playback failed:", button.Name, playErr)
                    sound:Destroy()
                end
            end)
        end

        local function attachAutomationButtonSound(object)
            if not object:IsA("GuiButton") or automationConnectedButtons[object] then
                return
            end

            automationConnectedButtons[object] = true
            automationButtonCount += 1
            local lastPlayedAt = 0
            print("[BZHUB AUTOMATION SOUND] CONNECTED:", object:GetFullName())

            local function onPressed()
                local now = os.clock()
                if now - lastPlayedAt < AUTOMATION_SOUND_DEBOUNCE then
                    return
                end
                lastPlayedAt = now
                print("[BZHUB AUTOMATION SOUND] CLICK:", object.Name)
                playAutomationButtonSound(object)
            end

            object.Activated:Connect(onPressed)
            object.MouseButton1Click:Connect(onPressed)
        end

        for _, object in ipairs(page:GetDescendants()) do
            attachAutomationButtonSound(object)
        end
        page.DescendantAdded:Connect(attachAutomationButtonSound)

        if hudGui then
            for _, object in ipairs(hudGui:GetDescendants()) do
                attachAutomationButtonSound(object)
            end
            hudGui.DescendantAdded:Connect(attachAutomationButtonSound)
        end
        if afkHudGui then
            for _, object in ipairs(afkHudGui:GetDescendants()) do
                attachAutomationButtonSound(object)
            end
            afkHudGui.DescendantAdded:Connect(attachAutomationButtonSound)
        end

        print("[BZHUB AUTOMATION SOUND] READY. Connected buttons:", automationButtonCount)
    end)
    
    api.AddCategory("Upgrades", "UPGRADES", function(page)
    
        --==================================================
        -- COLORS
        --==================================================
    
        local ACCENT = Color3.fromRGB(45, 155, 255)
        local ACCENT_BRIGHT = Color3.fromRGB(85, 190, 255)
        local PANEL = Color3.fromRGB(15, 20, 29)
        local CARD = Color3.fromRGB(17, 23, 33)
        local TEXT = Color3.fromRGB(225, 233, 245)
        local MUTED = Color3.fromRGB(145, 160, 180)
    
        local RED = Color3.fromRGB(255, 48, 65)
        local RED_LIGHT = Color3.fromRGB(255, 85, 95)
        local RED_DARK = Color3.fromRGB(145, 20, 35)
    
        --==================================================
        -- SERVICES
        --==================================================
    
        local Players = game:GetService("Players")
        local PathfindingService = game:GetService("PathfindingService")
        local VirtualInputManager = game:GetService("VirtualInputManager")
        local GuiService = game:GetService("GuiService")
    
        local player = Players.LocalPlayer
        local sellBusy = false
    
        local CHECK_DELAY = 0.015
    
        --==================================================
        -- GUI REFERENCES
        --==================================================
    
        local function getSellObjects()
    
            local playerGui = player:FindFirstChild("PlayerGui")
            if not playerGui then return nil end
    
            local sellGui = playerGui:FindFirstChild("SellShop")
            if not sellGui then return nil end
    
            local panel = sellGui:FindFirstChild("SellPanel")
            local body = panel and panel:FindFirstChild("Body")
            local content = body and body:FindFirstChild("Content")
    
            if not content then return nil end
    
            local summary = content:FindFirstChild("Summary")
            local sellAll = summary and summary:FindFirstChild("SellAll")
    
            local confirm = content:FindFirstChild("SellAllConfirm")
            local box = confirm and confirm:FindFirstChild("Box")
            local yes = box and box:FindFirstChild("Yes")
    
            return {
                Gui = sellGui,
                SellAll = sellAll,
                Yes = yes,
                Confirm = confirm
            }
        end
    
        local function getEventSellButton()
    
            local playerGui = player:FindFirstChild("PlayerGui")
            local eventGui = playerGui and playerGui:FindFirstChild("EventSellConfirm")
            local eventPanel = eventGui and eventGui:FindFirstChild("EventSellPanel")
            local body = eventPanel and eventPanel:FindFirstChild("Body")
            local content = body and body:FindFirstChild("Content")
    
            return content and content:FindFirstChild("Sell")
        end
    
        local function isVisible(object)
    
            if not object then return false end
    
            local current = object
    
            while current and current ~= game do
    
                if current:IsA("GuiObject") and not current.Visible then
                    return false
                end
    
                if current:IsA("ScreenGui") and not current.Enabled then
                    return false
                end
    
                current = current.Parent
            end
    
            return true
        end
    
        local function waitUntil(callback, timeout)
    
            local started = os.clock()
    
            repeat
    
                local success, result = pcall(callback)
    
                if success and result then
                    return result
                end
    
                task.wait(CHECK_DELAY)
    
            until os.clock() - started >= timeout
    
            return nil
        end
    
        local function isSellGuiOpen()
    
            local objects = getSellObjects()
    
            return objects
                and objects.SellAll
                and isVisible(objects.SellAll)
        end
    
        --==================================================
        -- FAST MOUSE CLICK
        --==================================================
    
        local function clickButton(button)
    
            if not button or not button:IsA("GuiButton") then
                return false
            end
    
            if not isVisible(button) or not button.Active then
                return false
            end
    
            local position = button.AbsolutePosition
            local size = button.AbsoluteSize
            local inset = GuiService:GetGuiInset()
    
            local x = math.floor(position.X + size.X / 2 + inset.X)
            local y = math.floor(position.Y + size.Y / 2 + inset.Y)
    
            VirtualInputManager:SendMouseMoveEvent(x, y, game)
            task.wait(0.03)
    
            VirtualInputManager:SendMouseButtonEvent(
                x, y, 0, true, game, 0
            )
    
            task.wait(0.03)
    
            VirtualInputManager:SendMouseButtonEvent(
                x, y, 0, false, game, 0
            )
    
            task.wait(0.04)
    
            return true
        end
    
        --==================================================
        -- CHARACTER HELPERS
        --==================================================
    
        local function getCharacter()
    
            local character = player.Character or player.CharacterAdded:Wait()
            local humanoid = character:WaitForChild("Humanoid")
            local root = character:WaitForChild("HumanoidRootPart")
    
            return character, humanoid, root
        end
    
        local function getSellPosition()
    
            local sellPlace = workspace:FindFirstChild("SellPlace")
            local zonePad = sellPlace and sellPlace:FindFirstChild("ZonePad")
    
            if not zonePad or not zonePad:IsA("BasePart") then
                error("SellPlace.ZonePad not found")
            end
    
            return zonePad.Position + Vector3.new(
                0,
                zonePad.Size.Y / 2 + 3,
                0
            )
        end
    
        --==================================================
        -- TELEPORT TO SELL PLACE
        --==================================================
    
        local function teleportToSellPlace()
    
            local character, humanoid, root = getCharacter()
            local targetPosition = getSellPosition()
    
            if humanoid.Health <= 0 then
                error("Character is dead")
            end
    
            local oldCFrame = root.CFrame
    
            local success = pcall(function()
                root.CFrame = CFrame.new(targetPosition) * (oldCFrame - oldCFrame.Position)
            end)
    
            if not success then
                return false, oldCFrame
            end
    
            task.wait(0.25)
    
            return true, oldCFrame
        end
    
        --==================================================
        -- RESTORE ORIGINAL POSITION
        --==================================================
    
        local function teleportBack(oldCFrame)

            if not oldCFrame then return false end

            local character = player.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if not root then return false end

            local success = pcall(function()
                root.CFrame = oldCFrame
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end)
            if not success then return false end

            task.wait(0.08)
            local currentCharacter = player.Character
            local currentRoot = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")
            if not currentRoot then return false end
            return (currentRoot.Position - oldCFrame.Position).Magnitude <= 8
        end


        --==================================================
        -- WALK TO POSITION
        --==================================================
    
        local function walkToPosition(destination)
    
            local character, humanoid, root = getCharacter()
    
            local path = PathfindingService:CreatePath({
                AgentRadius = 2,
                AgentHeight = 5,
                AgentCanJump = true,
                AgentCanClimb = true,
                WaypointSpacing = 4
            })
    
            for attempt = 1, 3 do
    
                if humanoid.Health <= 0 then
                    error("Character died")
                end
    
                path:ComputeAsync(root.Position, destination)
    
                if path.Status == Enum.PathStatus.Success then
    
                    local waypoints = path:GetWaypoints()
                    local reached = true
    
                    for _, waypoint in ipairs(waypoints) do
    
                        if humanoid.Health <= 0 then
                            error("Character died")
                        end
    
                        if waypoint.Action == Enum.PathWaypointAction.Jump then
                            humanoid.Jump = true
                        end
    
                        humanoid:MoveTo(waypoint.Position)
    
                        local started = os.clock()
    
                        while os.clock() - started < 8 do
    
                            if (root.Position - waypoint.Position).Magnitude < 3 then
                                break
                            end
    
                            if humanoid.Health <= 0 then
                                error("Character died")
                            end
    
                            task.wait(CHECK_DELAY)
                        end
    
                        if (root.Position - waypoint.Position).Magnitude >= 4 then
                            reached = false
                            break
                        end
                    end
    
                    if reached then
                        return true
                    end
                end
    
                task.wait(0.02)
            end
    
            return false
        end
    
        --==================================================
        -- WALK TO SELL PLACE
        --==================================================
    
        local function walkToSellPlace()
    
            local destination = getSellPosition()
    
            if not walkToPosition(destination) then
                error("Could not walk to SellPlace")
            end
    
            task.wait(0.03)
        end
    
        --==================================================
        -- SELL ALL
        --==================================================
    
        local function performSale(onConfirmed)
    
            local objects = getSellObjects()
    
            if not objects or not objects.SellAll then
                error("Sell All button not found")
            end
    
            --==================================================
            -- SELL ALL BUTTON
            --==================================================
    
            local sellClicked = false
            local sellStarted = os.clock()
    
            repeat
    
                local current = getSellObjects()
    
                if current and current.Yes and isVisible(current.Yes) then
                    sellClicked = true
                    break
                end
    
                if current and current.SellAll and isVisible(current.SellAll) then
                    clickButton(current.SellAll)
                end
    
                task.wait(CHECK_DELAY)
    
            until os.clock() - sellStarted >= 15
    
            if not sellClicked then
                error("Sell All confirmation did not appear")
            end
    
            --==================================================
            -- FIRST CONFIRMATION
            --==================================================
    
            local firstYes = waitUntil(function()
    
                local current = getSellObjects()
    
                if current and current.Yes and isVisible(current.Yes) then
                    return current.Yes
                end
    
            end, 12)
    
            if not firstYes then
                error("First confirmation button did not appear")
            end
    
            local firstConfirmed = false
            local firstStarted = os.clock()
    
            repeat
    
                local current = getSellObjects()
                local eventSell = getEventSellButton()
    
                if eventSell and isVisible(eventSell) then
                    firstConfirmed = true
                    break
                end
    
                if not current or not current.Yes or not isVisible(current.Yes) then
                    firstConfirmed = true
                    break
                end
    
                if current.Yes.Active then
                    clickButton(current.Yes)
                end
    
                task.wait(CHECK_DELAY)
    
            until os.clock() - firstStarted >= 15
    
            if not firstConfirmed then
                error("First confirmation was not accepted")
            end
    
            --==================================================
            -- OPTIONAL EVENT CONFIRMATION
            --==================================================
    
            local eventSellButton = waitUntil(function()
    
                local sell = getEventSellButton()
    
                if sell and isVisible(sell) then
                    return sell
                end
    
            end, 1.25)
    
            if eventSellButton then
    
                local buttonReady = waitUntil(function()
    
                    if not isVisible(eventSellButton) then
                        return nil
                    end
    
                    if not eventSellButton.Active then
                        return nil
                    end
    
                    if eventSellButton:IsA("TextButton")
                        and eventSellButton.TextTransparency >= 1 then
                        return nil
                    end
    
                    if eventSellButton:IsA("ImageButton")
                        and eventSellButton.ImageTransparency >= 1 then
                        return nil
                    end
    
                    return true
    
                end, 15)
    
                if not buttonReady then
                    error("Event Sell button did not become active")
                end
    
                local confirmed = false
                local started = os.clock()
    
                repeat
    
                    if not isVisible(eventSellButton) then
                        confirmed = true
                        break
                    end
    
                    if eventSellButton.Active then
                        clickButton(eventSellButton)
                    end
    
                    task.wait(CHECK_DELAY)
    
                until os.clock() - started >= 15
    
                if not confirmed and not isVisible(eventSellButton) then
                    confirmed = true
                end
    
                if not confirmed then
                    error("Event Sell confirmation did not close")
                end
            end
    
            if onConfirmed then
                pcall(onConfirmed)
            end
        end
    
        --==================================================
        -- MAIN AUTOMATION
        --==================================================
    
        local function runSellAutomation(onSaleConfirmed)
            local character, humanoid, root = getCharacter()
            local originalCFrame = root.CFrame
            local movedFromOriginal = false
            local returnByTeleport = false

            local ok, err = xpcall(function()
                -- If the sale window is already open, no travel is necessary.
                if isSellGuiOpen() then
                    performSale(onSaleConfirmed)
                    return
                end

                -- First try teleporting. Confirm the movement before using the GUI.
                local teleportCallOk, teleportResult, savedCFrame = pcall(teleportToSellPlace)
                if teleportCallOk and teleportResult then
                    originalCFrame = savedCFrame or originalCFrame
                    movedFromOriginal = true
                    returnByTeleport = true

                    local opened = waitUntil(function()
                        return isSellGuiOpen()
                    end, 5)

                    if not opened then
                        local restored = teleportBack(originalCFrame)
                        if not restored then
                            restored = walkToPosition(originalCFrame.Position)
                        end
                        if not restored then
                            error("Sell GUI did not open and the original position could not be restored.")
                        end
                        movedFromOriginal = false
                        returnByTeleport = false
                    end
                end

                -- If teleport failed or did not open the shop, use normal pathfinding.
                if not movedFromOriginal then
                    movedFromOriginal = true
                    returnByTeleport = false
                    walkToSellPlace()

                    local openedByWalking = waitUntil(function()
                        return isSellGuiOpen()
                    end, 8)

                    if not openedByWalking then
                        error("Sell GUI did not open")
                    end
                end

                performSale(onSaleConfirmed)
            end, debug.traceback)

            -- Always return after sale confirmation, even if a later step errors.
            if movedFromOriginal then
                local returned = false
                if returnByTeleport then
                    returned = teleportBack(originalCFrame)
                end
                if not returned then
                    returned = walkToPosition(originalCFrame.Position)
                end
                if not returned then
                    warn("[BZHUB SELL] Could not restore the original position.")
                    if ok then
                        ok = false
                        err = "Sale completed, but returning to the original position failed."
                    end
                end
            end

            if not ok then
                error(err)
            end
            return true
        end

        --==================================================
        -- MAIN CARD
        --==================================================
    
        local sellCard = Instance.new("Frame")
        sellCard.Name = "SellAllAnimalsCard"
        sellCard.Size = UDim2.new(1, -16, 0, 48)
        sellCard.Position = UDim2.fromOffset(8, 8)
        sellCard.BackgroundColor3 = CARD
        sellCard.BorderSizePixel = 0
        sellCard.ZIndex = 2
        sellCard.Parent = page
    
        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 9)
        cardCorner.Parent = sellCard
        
        
        --==================================================
        -- FULL SIZE ACTION CARD STYLE
        --==================================================
        
        local GREEN = Color3.fromRGB(35, 220, 125)
        local GREEN_BG = Color3.fromRGB(8, 45, 27)
        
        local function createLargeActionCard(name, text, position)
            local card = Instance.new("TextButton")
            card.Name = name
            card.Position = position
            card.Size = UDim2.new(1, 0, 0.5, -4)
            card.BackgroundColor3 = GREEN_BG
            card.BackgroundTransparency = 0.25
            card.BorderSizePixel = 0
            card.AutoButtonColor = false
            card.Text = text
            card.TextColor3 = Color3.fromRGB(255, 255, 255)
            card.TextSize = 25
            card.Font = Enum.Font.GothamBold
            card.TextWrapped = true
            card.ZIndex = 3
            card.Parent = page
        
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 12)
            corner.Parent = card
        
            local stroke = Instance.new("UIStroke")
            stroke.Color = GREEN
            stroke.Thickness = 2
            stroke.Transparency = 0.08
            stroke.Parent = card
        
            card.MouseEnter:Connect(function()
                card.BackgroundTransparency = 0.12
            end)
        
            card.MouseLeave:Connect(function()
                card.BackgroundTransparency = 0.25
            end)
        
            return card
        end
        
        --==================================================
        -- SELL ALL ANIMALS
        --==================================================
        
        local sellCard = createLargeActionCard(
            "SellAllAnimalsCard",
            "SELL ALL ANIMALS",
            UDim2.new(0, 2, 0, 2)
        )
        
        sellCard.Size = UDim2.new(1, -4, 0.5, -5)
        
        sellCard.Activated:Connect(function()
            if sellBusy then return end
        
            sellBusy = true
            sellCard.Text = "SELLING..."
        
            task.spawn(function()
                local success, err = pcall(function()
                    runSellAutomation(function()
                        sellCard.Text = "RETURNING..."
                    end)
                end)
        
                if success then
                    sellCard.Text = "SOLD"
                else
                    warn("[BZHUB SELL ERROR]:", err)
                    sellCard.Text = "FAILED"
                end
        
                task.wait(0.8)
        
                sellBusy = false
                sellCard.Text = "SELL ALL ANIMALS"
            end)
        end)

        --==================================================
        -- SMART AUTO UPGRADE: TRAIN BAR + FOOD (TOUCH / PC)
        --==================================================
        do
        -- Uses visible in-game prices and client ProximityPrompt input.
        -- It deliberately does not spam output: only state changes/errors are logged.
        local upgradePlayers = game:GetService("Players")
        local upgradePlayer = upgradePlayers.LocalPlayer
        local upgradePlayerGui = upgradePlayer:WaitForChild("PlayerGui")
        local upgradeRunning = { Food = false }
        local upgradeWorkers = { Food = 0 }
        local upgradeStatus = { Food = "OFF" }
        local SMART_WAIT_SECONDS = 5
        local UPGRADE_SCAN_INTERVAL = 0.35

        local function upgradeLog(key, message)
            if upgradeStatus[key] ~= message then
                upgradeStatus[key] = message
                print("[BZHUB SMART UPGRADE] " .. key .. ": " .. message)
            end
        end

        local function parseUpgradeNumber(raw)
            if type(raw) ~= "string" then return nil end
            local value = raw:upper():gsub(",", ""):gsub("%s", "")
            local number, suffix = value:match("([%d%.]+)([KMBTQ][A-Z]*)")
            if not number then
                number = value:match("([%d%.]+)")
                suffix = ""
            end
            number = tonumber(number)
            if not number then return nil end
            local multipliers = {
                [""] = 1, K = 1e3, M = 1e6, B = 1e9, T = 1e12,
                QA = 1e15, QI = 1e18, Q = 1e15, SX = 1e21,
                SP = 1e24, OC = 1e27, NO = 1e30, DC = 1e33,
                UD = 1e36, DD = 1e39, TD = 1e42
            }
            return number * (multipliers[suffix or ""] or 1)
        end

        local function getUpgradeCash()
            local leaderstats = upgradePlayer:FindFirstChild("leaderstats")
            if leaderstats then
                for _, value in ipairs(leaderstats:GetChildren()) do
                    if (value:IsA("NumberValue") or value:IsA("IntValue"))
                        and value.Name:lower():find("cash", 1, true)
                            or value.Name:lower():find("money", 1, true)
                            or value.Name:lower():find("coin", 1, true) then
                        if value:IsA("NumberValue") or value:IsA("IntValue") then
                            return value.Value
                        end
                    end
                end
            end
            -- Fallback: visible currency text in PlayerGui.
            for _, object in ipairs(upgradePlayerGui:GetDescendants()) do
                if object:IsA("TextLabel") or object:IsA("TextButton") then
                    local name = (object.Name .. " " .. object.Text):lower()
                    if name:find("cash", 1, true) or name:find("money", 1, true) then
                        local amount = parseUpgradeNumber(object.Text)
                        if amount then return amount end
                    end
                end
            end
            return nil
        end

        local function getUpgradeCashPerSecond()
            for _, object in ipairs(upgradePlayerGui:GetDescendants()) do
                if object:IsA("TextLabel") or object:IsA("TextButton") then
                    local text = object.Text
                    if text and text:find("/s", 1, true) then
                        local amount = parseUpgradeNumber(text)
                        if amount and amount > 0 then return amount end
                    end
                end
            end
            return nil
        end

        local function getTextFromTree(root)
            local parts = {}
            if root:IsA("TextLabel") or root:IsA("TextButton") then
                table.insert(parts, root.Text)
            end
            for _, child in ipairs(root:GetDescendants()) do
                if child:IsA("TextLabel") or child:IsA("TextButton") then
                    table.insert(parts, child.Text)
                end
            end
            return table.concat(parts, " ")
        end

        local function extractCost(text)
            if type(text) ~= "string" then return nil end
            local upper = text:upper():gsub(",", "")
            local candidates = {}
            for token in upper:gmatch("[%d%.]+%s*[KMBTQ][A-Z]*") do
                local amount = parseUpgradeNumber(token)
                if amount then table.insert(candidates, amount) end
            end
            if #candidates == 0 then
                for token in upper:gmatch("%d[%d%.]*") do
                    local amount = tonumber(token)
                    if amount and amount >= 100 then table.insert(candidates, amount) end
                end
            end
            table.sort(candidates)
            return candidates[1]
        end

        local function isObjectVisible(object)
            local current = object
            while current and current ~= upgradePlayerGui do
                if current:IsA("GuiObject") and not current.Visible then return false end
                if current:IsA("ScreenGui") and not current.Enabled then return false end
                current = current.Parent
            end
            return true
        end

        local function getFoodPurchaseButtons()
            local results = {}
            for _, object in ipairs(upgradePlayerGui:GetDescendants()) do
                if object:IsA("GuiButton") and object.Visible and object.Active then
                    local screen = object:FindFirstAncestorWhichIsA("ScreenGui")
                    local screenName = screen and screen.Name:lower() or ""
                    local context = getTextFromTree(object.Parent or object)
                    local contextLower = context:lower()
                    if (screenName:find("food", 1, true)
                        or contextLower:find("food shop", 1, true)
                        or contextLower:find("foodshop", 1, true)) then
                        local cost = extractCost(context)
                        local buttonText = object:IsA("TextButton") and object.Text:upper() or ""
                        if cost and (buttonText == "BUY" or buttonText == "PURCHASE"
                            or buttonText == "EQUIP" or buttonText == "") then
                            table.insert(results, { Button = object, Cost = cost, X = object.AbsolutePosition.X })
                        end
                    end
                end
            end
            table.sort(results, function(a, b) return a.X < b.X end)
            -- Remove duplicate buttons/cards with the same physical button instance.
            local unique, seen = {}, {}
            for _, item in ipairs(results) do
                if not seen[item.Button] then
                    seen[item.Button] = true
                    table.insert(unique, item)
                end
            end
            return unique
        end

        
        --==================================================
        -- FOOD MODULES
        --==================================================
        
        local Players = game:GetService("Players")
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        
        local LocalPlayer = Players.LocalPlayer
        
        local DataController = require(
            LocalPlayer.PlayerScripts.Client.Controllers.DataController
        )
        
        local FoodsConfig = require(
            ReplicatedStorage.Config.FoodsConfig
        )
        
        local BalanceCurve = require(
            ReplicatedStorage.Shared.BalanceCurve
        )
        
        local Remotes = require(
            ReplicatedStorage.Shared.Remotes
        )
        
        --==================================================
        -- TRY FOOD UPGRADE
        --==================================================
        
        local function tryFoodUpgrade()
        
            local ownedFoods = DataController:Get("OwnedFoods") or {}
            local money = tonumber(DataController:Get("Money")) or 0
        
            local selectedIndex = nil
        
            -- En yüksek indeksli satın alınabilir Food'u bul.
            for index = 1, FoodsConfig.CountAll() do
        
                if not FoodsConfig.IsLocked(index) then
        
                    local food = FoodsConfig.GetAny(index)
        
                    local isOwned =
                        ownedFoods[index] == true
                        or ownedFoods[tostring(index)] == true
        
                    if food and not isOwned then
        
                        local price = BalanceCurve.GetItemPrice(
                            LocalPlayer,
                            food
                        )
        
                        if price and price <= money then
                            selectedIndex = index
                        end
                    end
                end
            end
        
            if not selectedIndex then
                return false, "No affordable food available"
            end
        
            -- Satın al.
            local buySuccess, buyResult = pcall(function()
                return Remotes.Invoke("Shop_Buy", selectedIndex)
            end)
        
            if not buySuccess then
                warn("[BZHUB FOOD] Buy error:", buyResult)
                return false, "Purchase failed"
            end
        
            task.wait(0.4)
        
            -- Satın alınan Food'u kuşan.
            local equipSuccess, equipError = pcall(function()
                return Remotes.Invoke("Shop_Equip", selectedIndex)
            end)
        
            if not equipSuccess then
                warn("[BZHUB FOOD] Equip error:", equipError)
            end
        
            return true, "Food purchased: " .. tostring(selectedIndex)
        end
        

        local function startSmartUpgrade(key, worker)
            upgradeWorkers[key] += 1
            local workerId = upgradeWorkers[key]
            upgradeRunning[key] = true
            upgradeLog(key, "ON")
            task.spawn(function()
                while upgradeRunning[key] and upgradeWorkers[key] == workerId do
                    local ok, success, message = xpcall(worker, debug.traceback)
                    if not ok then
                        upgradeLog(key, "Error: " .. tostring(success))
                    elseif success then
                        upgradeLog(key, message or "Upgrade requested")
                        task.wait(0.65)
                    elseif message then
                        upgradeLog(key, message)
                    end
                    task.wait(UPGRADE_SCAN_INTERVAL)
                end
            end)
        end

        local function stopSmartUpgrade(key)
            upgradeRunning[key] = false
            upgradeWorkers[key] += 1
            upgradeLog(key, "OFF")
        end

       
        --==================================================
        -- FULL SIZE AUTO UPGRADE FOOD CARD
        --==================================================
        
        local foodCard = Instance.new("TextButton")
        foodCard.Name = "AutoUpgradeFoodCard"
        foodCard.Position = UDim2.new(0, 2, 0.5, 3)
        foodCard.Size = UDim2.new(1, -4, 0.5, -5)
        foodCard.BackgroundColor3 = GREEN_BG
        foodCard.BackgroundTransparency = 0.25
        foodCard.BorderSizePixel = 0
        foodCard.AutoButtonColor = false
        foodCard.Text = "AUTO UPGRADE FOOD\nOFF"
        foodCard.TextColor3 = Color3.fromRGB(255, 255, 255)
        foodCard.TextSize = 25
        foodCard.Font = Enum.Font.GothamBold
        foodCard.TextWrapped = true
        foodCard.ZIndex = 3
        foodCard.Parent = page
        
        local foodCorner = Instance.new("UICorner")
        foodCorner.CornerRadius = UDim.new(0, 12)
        foodCorner.Parent = foodCard
        
        local foodStroke = Instance.new("UIStroke")
        foodStroke.Color = GREEN
        foodStroke.Thickness = 2
        foodStroke.Transparency = 0.08
        foodStroke.Parent = foodCard
        
        local function refreshFoodCard()
            local FOOD_ON_COLOR = Color3.fromRGB(35, 220, 125)
            local FOOD_ON_BG = Color3.fromRGB(8, 45, 27)
            
            local FOOD_OFF_COLOR = Color3.fromRGB(245, 55, 65)
            local FOOD_OFF_BG = Color3.fromRGB(55, 12, 18)
            
            local function refreshFoodCard()
                local enabled = upgradeRunning.Food
            
                foodCard.Text = enabled
                    and "AUTO UPGRADE FOOD\nON"
                    or "AUTO UPGRADE FOOD\nOFF"
            
                foodCard.BackgroundColor3 = enabled
                    and FOOD_ON_BG
                    or FOOD_OFF_BG
            
                foodStroke.Color = enabled
                    and FOOD_ON_COLOR
                    or FOOD_OFF_COLOR
            
                foodCard.BackgroundTransparency = 0.2
            end
            
            foodCard.MouseEnter:Connect(function()
                foodCard.BackgroundTransparency = 0.08
            end)
            
            foodCard.MouseLeave:Connect(function()
                foodCard.BackgroundTransparency = 0.2
            end)
        end
        
        foodCard.MouseEnter:Connect(function()
            foodCard.BackgroundTransparency = 0.12
        end)
        
        foodCard.MouseLeave:Connect(function()
            foodCard.BackgroundTransparency = upgradeRunning.Food and 0.12 or 0.25
        end)
        
        foodCard.Activated:Connect(function()
            if upgradeRunning.Food then
                stopSmartUpgrade("Food")
            else
                startSmartUpgrade("Food", tryFoodUpgrade)
            end
        
            refreshFoodCard()
        end)
        
        refreshFoodCard()

        end -- closes smart auto-upgrade scope

        --==================================================
        -- GLOBAL UI BUTTON SOUNDS + DEBUG
        --==================================================
        -- Attach to every BZHUB button in this page, including buttons
        -- inserted after initialization. Activated covers touch/gamepad;
        -- MouseButton1Click is an additional desktop fallback.
        local SoundService = game:GetService("SoundService")
        local ContentProvider = game:GetService("ContentProvider")
        local Debris = game:GetService("Debris")

        local BUTTON_SOUND_ID = "rbxassetid://12221967"
        local BUTTON_SOUND_VOLUME = 1
        local BUTTON_SOUND_SPEED = 1
        local BUTTON_SOUND_DEBOUNCE = 0.08

        local buttonSoundTemplate = Instance.new("Sound")
        buttonSoundTemplate.Name = "BZHUB_ButtonClickTemplate"
        buttonSoundTemplate.SoundId = BUTTON_SOUND_ID
        buttonSoundTemplate.Volume = BUTTON_SOUND_VOLUME
        buttonSoundTemplate.PlaybackSpeed = BUTTON_SOUND_SPEED
        buttonSoundTemplate.Parent = SoundService

        print("[BZHUB SOUND] Initializing global BZHUB button audio...")
        print("[BZHUB SOUND] SoundId:", BUTTON_SOUND_ID, "Volume:", BUTTON_SOUND_VOLUME)

        task.spawn(function()
            local ok, err = pcall(function()
                ContentProvider:PreloadAsync({buttonSoundTemplate})
            end)
            if ok then
                print("[BZHUB SOUND] Template preload complete. IsLoaded:", buttonSoundTemplate.IsLoaded)
            else
                warn("[BZHUB SOUND] Template preload failed:", err)
            end
        end)

        local connectedSoundButtons = setmetatable({}, {__mode = "k"})
        local attachedButtonCount = 0

        local function playBzhubClickSound(button)
            local clickSound = buttonSoundTemplate:Clone()
            clickSound.Name = "BZHUB_ButtonClick_OneShot"
            clickSound.Volume = BUTTON_SOUND_VOLUME
            clickSound.PlaybackSpeed = BUTTON_SOUND_SPEED
            clickSound.Parent = SoundService

            task.spawn(function()
                local loaded, loadErr = pcall(function()
                    ContentProvider:PreloadAsync({clickSound})
                end)
                if not loaded then
                    warn("[BZHUB SOUND] Click sound preload failed:", loadErr)
                end

                local played, playErr = pcall(function()
                    clickSound:Play()
                end)
                if played then
                    print("[BZHUB SOUND] PLAYED:", button.Name, "Loaded:", clickSound.IsLoaded)
                    Debris:AddItem(clickSound, 4)
                else
                    warn("[BZHUB SOUND] Playback failed for", button.Name, playErr)
                    clickSound:Destroy()
                end
            end)
        end

        local function attachButtonSound(object)
            if not object:IsA("GuiButton") or connectedSoundButtons[object] then
                return
            end

            connectedSoundButtons[object] = true
            attachedButtonCount += 1
            local lastPlayedAt = 0
            print("[BZHUB SOUND] CONNECTED:", object:GetFullName())

            local function onButtonPressed()
                local now = os.clock()
                if now - lastPlayedAt < BUTTON_SOUND_DEBOUNCE then
                    return
                end
                lastPlayedAt = now
                print("[BZHUB SOUND] CLICK:", object.Name)
                playBzhubClickSound(object)
            end

            -- Activated supports mouse, touch and gamepad.
            object.Activated:Connect(onButtonPressed)
            -- Explicit desktop fallback for custom buttons whose Activated
            -- signal may not fire through the executor/UI wrapper.
            object.MouseButton1Click:Connect(onButtonPressed)
        end

        -- Existing buttons.
        for _, object in ipairs(page:GetDescendants()) do
            attachButtonSound(object)
        end
        -- Buttons created later.
        page.DescendantAdded:Connect(attachButtonSound)

        -- The independent BZHUB HUDs live outside the category page.
        if hudGui then
            for _, object in ipairs(hudGui:GetDescendants()) do
                attachButtonSound(object)
            end
            hudGui.DescendantAdded:Connect(attachButtonSound)
        end
        if afkHudGui then
            for _, object in ipairs(afkHudGui:GetDescendants()) do
                attachButtonSound(object)
            end
            afkHudGui.DescendantAdded:Connect(attachButtonSound)
        end

        print("[BZHUB SOUND] READY. Connected BZHUB buttons:", attachedButtonCount)
    end)
    
    --==================================================
    -- BZHUB DASHBOARD
    --==================================================
    
    api.AddCategory("Dashboard", "DASHBOARD", function(page)    
        local Players = game:GetService("Players")
        local player = Players.LocalPlayer
        local leaderstats = player:WaitForChild("leaderstats")
    
        local moneyValue = leaderstats:WaitForChild("Money")
        local cashPerSecondValue = leaderstats:WaitForChild("Money/s")
    
        local ACCENT = Color3.fromRGB(45, 155, 255)
        local CARD = Color3.fromRGB(17, 23, 33)
        local TEXT = Color3.fromRGB(225, 233, 245)
        local MUTED = Color3.fromRGB(145, 160, 180)
        local GREEN = Color3.fromRGB(55, 220, 130)
    
        local suffixes = {
            "", "K", "M", "B", "T",
            "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc",
            "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd",
            "Ocd", "Nod", "Vg", "Uvg", "Dvg", "Tvg",
            "Qavg", "Qivg", "Sxvg", "Spvg", "Ocvg", "Novg",
            "Tg", "Utg", "Dtg", "Tstg", "Qattg", "Qntg",
            "Sstg", "Setg", "Otrg", "Nvtg", "Qag", "Uqg",
            "Dqg", "Tqg", "Qaqg", "Qnqg", "Sxqg", "Spqg",
            "Oqg", "Nqg", "Qig"
        }
        
        local function formatNumber(value)
            if not value or value ~= value then
                return "N/A"
            end
        
            if value == 0 then
                return "0"
            end
        
            local exponent = math.floor(math.log10(math.abs(value)) / 3)
            exponent = math.max(0, exponent)
        
            if exponent >= #suffixes then
                return string.format("%.2e", value)
            end
        
            local scaled = value / (10 ^ (exponent * 3))
            local formatted = string.format("%.2f", scaled)
            formatted = formatted:gsub("%.?0+$", "")
        
            return formatted .. suffixes[exponent + 1]
        end
    
        local function formatTime(seconds)
            seconds = math.floor(seconds)
    
            local hours = math.floor(seconds / 3600)
            local minutes = math.floor((seconds % 3600) / 60)
            local secs = seconds % 60
    
            return string.format("%02d:%02d:%02d", hours, minutes, secs)
        end
    
        --==================================================
        -- SCROLL
        --==================================================
    
        local scroll = Instance.new("ScrollingFrame")
        scroll.Name = "DashboardScroll"
        scroll.Size = UDim2.fromScale(1, 1)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 4
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.Parent = page
    
        local content = Instance.new("Frame")
        content.Name = "DashboardContent"
        content.Position = UDim2.fromOffset(8, 8)
        content.Size = UDim2.new(1, -16, 0, 0)
        content.AutomaticSize = Enum.AutomaticSize.Y
        content.BackgroundTransparency = 1
        content.Parent = scroll
    
        local list = Instance.new("UIListLayout")
        list.Padding = UDim.new(0, 10)
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Parent = content
    
        --==================================================
        -- HEADER
        --==================================================
    
        local header = Instance.new("Frame")
        header.Name = "DashboardHeader"
        header.Size = UDim2.new(1, 0, 0, 48)
        header.BackgroundTransparency = 1
        header.LayoutOrder = 1
        header.Parent = content
    
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0, 23)
        title.BackgroundTransparency = 1
        title.Text = "GAME OVERVIEW"
        title.TextColor3 = TEXT
        title.TextSize = 17
        title.Font = Enum.Font.GothamBold
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = header
    
        local subtitle = Instance.new("TextLabel")
        subtitle.Position = UDim2.fromOffset(0, 25)
        subtitle.Size = UDim2.new(1, 0, 0, 17)
        subtitle.BackgroundTransparency = 1
        subtitle.Text = "Live game statistics"
        subtitle.TextColor3 = MUTED
        subtitle.TextSize = 10
        subtitle.Font = Enum.Font.Gotham
        subtitle.TextXAlignment = Enum.TextXAlignment.Left
        subtitle.Parent = header
    
        --==================================================
        -- STATISTICS GRID
        --==================================================
    
        local grid = Instance.new("Frame")
        grid.Name = "StatisticsGrid"
        grid.Size = UDim2.new(1, 0, 0, 284)
        grid.BackgroundTransparency = 1
        grid.LayoutOrder = 2
        grid.Parent = content
    
        local gridLayout = Instance.new("UIGridLayout")
        gridLayout.CellSize = UDim2.new(0.5, -5, 0, 88)
        gridLayout.CellPadding = UDim2.fromOffset(10, 10)
        gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
        gridLayout.Parent = grid
    
        local labels = {}
    
        local function createCard(name, heading, order)
            local card = Instance.new("Frame")
            card.Name = name
            card.BackgroundColor3 = CARD
            card.BorderSizePixel = 0
            card.LayoutOrder = order
            card.Parent = grid
    
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 10)
            corner.Parent = card
    
            local stroke = Instance.new("UIStroke")
            stroke.Color = ACCENT
            stroke.Transparency = 0.55
            stroke.Thickness = 1
            stroke.Parent = card
    
            local accent = Instance.new("Frame")
            accent.Size = UDim2.new(0, 3, 0, 35)
            accent.Position = UDim2.fromOffset(0, 13)
            accent.BackgroundColor3 = ACCENT
            accent.BorderSizePixel = 0
            accent.Parent = card
    
            local headingLabel = Instance.new("TextLabel")
            headingLabel.Position = UDim2.fromOffset(12, 12)
            headingLabel.Size = UDim2.new(1, -20, 0, 17)
            headingLabel.BackgroundTransparency = 1
            headingLabel.Text = heading
            headingLabel.TextColor3 = MUTED
            headingLabel.TextSize = 9
            headingLabel.Font = Enum.Font.GothamBold
            headingLabel.TextXAlignment = Enum.TextXAlignment.Left
            headingLabel.Parent = card
    
            local valueLabel = Instance.new("TextLabel")
            valueLabel.Name = "Value"
            valueLabel.Position = UDim2.fromOffset(12, 34)
            valueLabel.Size = UDim2.new(1, -20, 0, 30)
            valueLabel.BackgroundTransparency = 1
            valueLabel.Text = "Loading..."
            valueLabel.TextColor3 = TEXT
            valueLabel.TextSize = 17
            valueLabel.Font = Enum.Font.GothamBold
            valueLabel.TextXAlignment = Enum.TextXAlignment.Left
            valueLabel.Parent = card
    
            labels[name] = valueLabel
        end
    
        createCard("Session", "SESSION TIME", 1)
        createCard("Money", "CURRENT MONEY", 2)
        createCard("CashPerSecond", "CASH / S", 3)
        createCard("Earned", "MONEY EARNED (10S UPDATE)", 4)
        createCard("Throws", "TOTAL THROWS", 5)
        createCard("Script", "SCRIPT:", 6)
    
        --==================================================
        -- SCRIPT STATUS
        --==================================================
        
        labels.Script.Text = "● RUNNING"
        labels.Script.TextColor3 = GREEN
        --==================================================
        -- STAT VALUE PARSER
        --==================================================
        
        local statMultipliers = {
            K=1e3, M=1e6, B=1e9, T=1e12,
            QA=1e15, QI=1e18, SX=1e21, SP=1e24,
            OC=1e27, NO=1e30, DC=1e33,
            UD=1e36, DD=1e39, TD=1e42,
            QAD=1e45, QID=1e48, SXD=1e51,
            SPD=1e54, OCD=1e57, NOD=1e60,
            VG=1e63, UVG=1e66, DVG=1e69,
            TVG=1e72, QAVG=1e75, QIVG=1e78,
            SXVG=1e81, SPVG=1e84, OCVG=1e87,
            NOVG=1e90, TG=1e93, UTG=1e96,
            DTG=1e99, TSTG=1e102, QATTG=1e105,
            QNTG=1e108, SSTG=1e111, SETG=1e114,
            OTRG=1e117, NVTG=1e120, QAG=1e123,
            UQG=1e126, DQG=1e129, TQG=1e132,
            QAQG=1e135, QNQG=1e138, SXQG=1e141,
            SPQG=1e144, OQG=1e147, NQG=1e150,
            QIG=1e153
        }
        
        local function parseStatValue(valueObject)
            if not valueObject then return nil end
        
            local raw = tostring(valueObject.Value):upper()
            raw = raw:gsub("%$", "")
                :gsub(",", "")
                :gsub("%s", "")
                :gsub("/S", "")
        
            local number, suffix = raw:match("^([%d%.]+)(%a*)$")
            number = tonumber(number)
        
            if not number then return nil end
        
            return number * (statMultipliers[suffix or ""] or 1)
        end
        --==================================================
        -- LIVE DATA UPDATE
        --==================================================
        
        local function refreshDashboard()
        
            local currentMoney = parseStatValue(moneyValue)
            local currentCashPerSecond = parseStatValue(cashPerSecondValue)
        
            -- Money
            labels.Money.Text = currentMoney
                and "$" .. formatNumber(currentMoney)
                or "N/A"
        
            -- Cash / S
            labels.CashPerSecond.Text = currentCashPerSecond
                and "$" .. formatNumber(currentCashPerSecond) .. "/s"
                or "N/A"
        
            -- Session Time
            local elapsed = os.clock() - sessionStartedAt
            labels.Session.Text = formatTime(elapsed)
        
            -- Money Earned
            if currentCashPerSecond then
                labels.Earned.Text = "$" .. formatNumber(currentCashPerSecond * elapsed)
            else
                labels.Earned.Text = "N/A"
            end
        
            -- Total Throws
            labels.Throws.Text = tostring(api.TotalThrows or 0)
        end
        
        -- İlk açılışta hemen güncelle
        refreshDashboard()
        
        -- Sonrasında her 10 saniyede bir güncelle
        task.spawn(function()
            while page.Parent and content.Parent do
                task.wait(10)
        
                if not page.Parent or not content.Parent then
                    break
                end
        
                refreshDashboard()
            end
        end)
    
        print("[BZHUB DASHBOARD] Initialized")
    end)
end
return GameModule
