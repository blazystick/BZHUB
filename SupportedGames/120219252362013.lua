
local GameModule = {}

function GameModule.Register(api)
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
        local minimumCashPerSecond = 0
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

        -- �lk ba�lang��ta 6 saniye bekle.
        -- Sonraki d�ng�lerde ThrowReadyAt beklenecek.
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
                infoHint = "� The 6-second starting wait is normal.\n� Do not move or click while the automation is waiting.\n� Cooldown delays are part of the game.\n� Keep the game open until the throw is complete.",
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
                power = "G�� Seviyesi",
                info = "i",
                infoTitle = "AUTO THROW - IMPORTANT NOTES",
                infoHint = "� The 6-second starting wait is normal.\n� Do not move or click while the automation is waiting.\n� Cooldown delays are part of the game.\n� Keep the game open until the throw is complete.",
                idle = "Auto Throw �u anda kapal�.",
                starting = "Otomasyon ba�lat�l�yor...",
                moving = "At�� alan�na y�r�n�yor. L�tfen m�dahale etmeyin.",
                initialWait = "Ba�lang�� alan�nda 6 saniye bekleniyor. L�tfen dokunmay�n.",
                cooldown = "At�� bekleme s�resi / koruma bitene kadar bekleniyor. Hi�bir �eye dokunmay�n; s�re bitince hareket ba�layacak.",
                marker = "At�� g�stergesinde se�ilen g�� seviyesi bekleniyor.",
                throwing = "Se�ilen g�� yakaland�. At�� girdisi g�nderiliyor...",
                resetting = "At�� tamamland�. Karakter s�f�rlan�yor...",
                stopped = "Auto Throw durduruldu.",
                error = "Bir hata olu�tu: ",
                enabled = "A�IK",
                disabled = "KAPALI",
                close = "KAPAT"
            },
            Russian = {
                title = "???? ??????",
                power = "??????? ????",
                info = "i",
                infoTitle = "AUTO THROW - IMPORTANT NOTES",
                infoHint = "� The 6-second starting wait is normal.\n� Do not move or click while the automation is waiting.\n� Cooldown delays are part of the game.\n� Keep the game open until the throw is complete.",
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
                elseif key == "sellMoving" then
                    message = "Walking to the sell area..."
                elseif key == "sellWaiting" then
                    message = "Waiting for you to manually sell low-income pets..."
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
        mainCard.Size = UDim2.new(1, 0, 0, 178)
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


        -- Minimum pet income filter (Cash/S).
        local incomeFilterLabel = Instance.new("TextLabel")
        incomeFilterLabel.Name = "MinimumIncomeLabel"
        incomeFilterLabel.Position = UDim2.fromOffset(12, 133)
        incomeFilterLabel.Size = UDim2.new(1, -142, 0, 28)
        incomeFilterLabel.BackgroundTransparency = 1
        incomeFilterLabel.Text = "Minimum Cash/S"
        incomeFilterLabel.TextColor3 = TEXT
        incomeFilterLabel.TextSize = 11
        incomeFilterLabel.Font = Enum.Font.GothamMedium
        incomeFilterLabel.TextXAlignment = Enum.TextXAlignment.Left
        incomeFilterLabel.Parent = mainCard

        local incomeFilterBox = Instance.new("TextBox")
        incomeFilterBox.Name = "MinimumIncomeInput"
        incomeFilterBox.AnchorPoint = Vector2.new(1, 0)
        incomeFilterBox.Position = UDim2.new(1, -12, 0, 130)
        incomeFilterBox.Size = UDim2.fromOffset(112, 32)
        incomeFilterBox.BackgroundColor3 = Color3.fromRGB(24, 34, 48)
        incomeFilterBox.BorderSizePixel = 0
        incomeFilterBox.Text = "0"
        incomeFilterBox.PlaceholderText = "e.g. 1K / 1M"
        incomeFilterBox.PlaceholderColor3 = MUTED
        incomeFilterBox.TextColor3 = TEXT
        incomeFilterBox.TextSize = 12
        incomeFilterBox.Font = Enum.Font.GothamBold
        incomeFilterBox.ClearTextOnFocus = false
        incomeFilterBox.TextXAlignment = Enum.TextXAlignment.Center
        incomeFilterBox.Parent = mainCard

        local incomeInputCorner = Instance.new("UICorner")
        incomeInputCorner.CornerRadius = UDim.new(0, 8)
        incomeInputCorner.Parent = incomeFilterBox

        local incomeInputStroke = Instance.new("UIStroke")
        incomeInputStroke.Color = ACCENT
        incomeInputStroke.Transparency = 0.45
        incomeInputStroke.Thickness = 1
        incomeInputStroke.Parent = incomeFilterBox

        local incomeFilterHint = Instance.new("TextLabel")
        incomeFilterHint.Name = "MinimumIncomeHint"
        incomeFilterHint.Position = UDim2.fromOffset(12, 158)
        incomeFilterHint.Size = UDim2.new(1, -24, 0, 14)
        incomeFilterHint.BackgroundTransparency = 1
        incomeFilterHint.Text = '"0" is disabled; suffixes like K, M, B, T, Qa, Qi, Sx, Sp, Oc, etc. are supported.'
        incomeFilterHint.TextColor3 = MUTED
        incomeFilterHint.TextSize = 9
        incomeFilterHint.Font = Enum.Font.Gotham
        incomeFilterHint.TextXAlignment = Enum.TextXAlignment.Left
        incomeFilterHint.Parent = mainCard

        local incomeSuffixMultipliers = {
            [""] = 1,
            K = 1e3, M = 1e6, B = 1e9, T = 1e12,
            QA = 1e15, QI = 1e18, SX = 1e21, SP = 1e24,
            OC = 1e27, NO = 1e30, DC = 1e33,
            UD = 1e36, DD = 1e39, TD = 1e42,
            QAD = 1e45, QID = 1e48, SXD = 1e51, SPD = 1e54,
            OCD = 1e57, NOD = 1e60, VG = 1e63,
            UVG = 1e66, DVG = 1e69, TVG = 1e72,
            QAVG = 1e75, QIVG = 1e78, SXVG = 1e81, SPVG = 1e84,
            OCVG = 1e87, NOVG = 1e90, TG = 1e93,
            UTG = 1e96, DTG = 1e99, TTG = 1e102,
            QATG = 1e105, QITG = 1e108, SXTG = 1e111,
            SPTG = 1e114, OCTG = 1e117, NOTG = 1e120,
            QAG = 1e123, QIG = 1e126, SXG = 1e129, SPG = 1e132,
            OCG = 1e135, NOG = 1e138, CT = 1e303
        }

        local function parseIncomeThreshold(raw)
            local cleaned = tostring(raw or ""):upper():gsub("[%s,]", "")
            if cleaned == "" or cleaned == "0" then return 0 end

            local numberPart, suffix = cleaned:match("^(%d+%.?%d*)([A-Z]*)$")
            if not numberPart then return nil end

            local number = tonumber(numberPart)
            local multiplier = incomeSuffixMultipliers[suffix]
            if not number or number < 0 or not multiplier then return nil end

            local result = number * multiplier
            if result ~= result or result == math.huge then
                return math.huge
            end
            return math.floor(result + 0.5)
        end

        incomeFilterBox.FocusLost:Connect(function()
            local parsed = parseIncomeThreshold(incomeFilterBox.Text)
            if parsed == nil then
                incomeFilterBox.Text = tostring(minimumCashPerSecond)
                incomeFilterHint.Text = "Invalid value. Example: 100 / 1K / 1M"
                incomeFilterHint.TextColor3 = Color3.fromRGB(255, 120, 130)
                return
            end

            minimumCashPerSecond = parsed
            incomeFilterBox.Text = tostring(parsed)
            incomeFilterHint.Text = parsed == 0
                and '"0" is disabled; suffixes like K, M, B, T, Qa, Qi, Sx, Sp, Oc, etc. are supported.'
                or ("Minimum: " .. tostring(parsed) .. " Cash/S")
            incomeFilterHint.TextColor3 = MUTED
        end)

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
        equipBestLabel.Size = UDim2.fromOffset(165, 29)
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

        helpers.AutoEquipBest = function()
            autoEquipBestWorkerId += 1
            local workerId = autoEquipBestWorkerId

            task.spawn(function()
                while autoEquipBestEnabled and workerId == autoEquipBestWorkerId do
                    helpers.invokeEquipBest()
                    for _ = 1, 10 do
                        if not autoEquipBestEnabled or workerId ~= autoEquipBestWorkerId then
                            break
                        end
                        task.wait(0.5)
                    end
                end
            end)
        end

        equipBestSwitch.MouseButton1Click:Connect(function()
            if autoFarmRunning then return end
            autoEquipBestEnabled = not autoEquipBestEnabled
            equipStateLabel.Text = autoEquipBestEnabled and "ON" or "OFF"
            equipStateLabel.TextColor3 = autoEquipBestEnabled and EQUIP_GREEN_BRIGHT or MUTED
            helpers.setEquipSwitchVisual(autoEquipBestEnabled, false)
            helpers.makeTween(equipBestStroke, 0.2, {
                Transparency = autoEquipBestEnabled and 0.08 or 0.3,
                Thickness = autoEquipBestEnabled and 1.8 or 1.35
            })

            if autoEquipBestEnabled then
                helpers.debugLog("Auto Equip Best Pet enabled.")
                helpers.startAutoEquipBest()
            else
                autoEquipBestWorkerId += 1
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
        closeInfoButton.Text = "�"
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

        local afkThrowsText, afkThrowsFill = helpers.makeAfkRow("Throws", 42, "ATI�LAR: 3")
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
            afkThrowsText.Text = "ATI�LAR: " .. tostring(math.max(0, remaining))
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
                afkPetsText.Text = "EQUIP PETS: �sim bulunamad�"
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

            -- Keep the income filter visible at all times; only lock editing while Auto Throw is ON.
            incomeFilterLabel.Visible = true
            incomeFilterBox.Visible = true
            incomeFilterHint.Visible = true
            incomeFilterBox.Active = visible
            incomeFilterBox.TextEditable = visible
            incomeFilterBox.BackgroundColor3 = visible
                and Color3.fromRGB(24, 34, 48)
                or Color3.fromRGB(31, 39, 51)
            incomeInputStroke.Transparency = visible and 0.45 or 0.72
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
                    mainCard.Size = UDim2.new(1, 0, 0, 178)
                    trainCard.Position = UDim2.fromOffset(10, 244)
                else
                    sliderContainer.Position = UDim2.fromOffset(12, 54)
                    sliderContainer.Size = UDim2.new(1, -24, 0, 0)
                    sliderContainer.GroupTransparency = 1
                    mainCard.Size = UDim2.new(1, -20, 0, 62)
                    trainCard.Position = UDim2.fromOffset(10, 128)
                    helpers.makeTween(mainCard, 0.3, {Size = UDim2.new(1, 0, 0, 178)})
                    helpers.makeTween(trainCard, 0.3, {Position = UDim2.fromOffset(10, 244)})
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
                    mainCard.Size = UDim2.new(1, 0, 0, 178)
                    trainCard.Position = UDim2.fromOffset(10, 244)
                else
                    helpers.makeTween(mainCard, 0.28, {Size = UDim2.new(1, 0, 0, 178)})
                    helpers.makeTween(trainCard, 0.28, {Position = UDim2.fromOffset(10, 244)})
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

                task.wait(0.05)
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

                task.wait(0.03)
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

                    task.wait(0.1)
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

                    task.wait(0.5)
                    continue
                end

                if not helpers.stillRunning(currentId) then
                    return false
                end

                if path.Status ~= Enum.PathStatus.Success then
                    helpers.debugLog("Pathfinding status: " .. tostring(path.Status))
                    task.wait(0.5)
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
                task.wait(0.5)
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

                task.wait(0.1)
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

        helpers.pressTrainingStopWithoutMouse = function()
            local stopButton = helpers.findTrainingStopButton()
            if not stopButton then
                warn("[BZHUB AUTO TRAIN] STOP control was not found at PlayerGui.TrainingSequence.Button.")
                return false, "STOP button not found"
            end

            -- User requested SPACE instead of clicking the game's STOP button.
            -- This intentionally sends SPACE directly through keyboard input,
            -- without using mouse input or GUI event injection.
            local keyCode = Enum.KeyCode.Space

            if type(keypress) == "function" and type(keyrelease) == "function" then
                local ok, err = pcall(function()
                    keypress(0x20)
                    task.wait(0.08)
                    keyrelease(0x20)
                end)
                if ok then
                    helpers.debugLog("Training stop requested with SPACE via Solara keyboard input.")
                    return true
                end
                warn("[BZHUB AUTO TRAIN] Solara SPACE input failed: " .. tostring(err))
            end

            local virtualOk, virtualErr = pcall(function()
                VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
                task.wait(0.08)
                VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
            end)
            if virtualOk then
                helpers.debugLog("Training stop requested with SPACE via VirtualInputManager.")
                return true
            end

            warn("[BZHUB AUTO TRAIN] Could not send SPACE: " .. tostring(virtualErr))
            return false, "SPACE input is unavailable: " .. tostring(virtualErr)
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
            helpers.setStatus("trainStopping", "Activating the game's STOP control...", 0)
            task.spawn(function()
                local stopped, stopError = helpers.pressTrainingStopWithoutMouse()
                if not stopped then
                    helpers.debugLog("Could not activate STOP control: " .. tostring(stopError))
                end
                if isEnabled then
                    activeHudMode = "throw"
                    helpers.setStatus(currentStatus, currentStatusDetail)
                else
                    helpers.setStatus("trainStopped")
                end
            end)
        end

        --==================================================
        -- MAIN FARM LOOP
        --==================================================

        --==================================================
        -- PET INCOME FILTER / MANUAL SELL WAIT
        --==================================================

        local cachedDataController
        local cachedMutations

        helpers.getPetDataModules = function()
            if cachedDataController and cachedMutations then
                return cachedDataController, cachedMutations
            end

            local playerScripts = player:FindFirstChild("PlayerScripts")
            local clientFolder = playerScripts and playerScripts:FindFirstChild("Client")
            local controllers = clientFolder and clientFolder:FindFirstChild("Controllers")
            local dataControllerModule = controllers and controllers:FindFirstChild("DataController")

            local replicatedStorage = game:GetService("ReplicatedStorage")
            local sharedFolder = replicatedStorage:FindFirstChild("Shared")
            local mutationsModule = sharedFolder and sharedFolder:FindFirstChild("Mutations")

            if not dataControllerModule or not mutationsModule then
                return nil, nil, "DataController or Shared.Mutations module was not found."
            end

            local dataOk, dataResult = pcall(require, dataControllerModule)
            if not dataOk then
                return nil, nil, "DataController require failed: " .. tostring(dataResult)
            end

            local mutationsOk, mutationsResult = pcall(require, mutationsModule)
            if not mutationsOk then
                return nil, nil, "Mutations require failed: " .. tostring(mutationsResult)
            end

            cachedDataController = dataResult
            cachedMutations = mutationsResult
            return cachedDataController, cachedMutations
        end

        helpers.waitForDataControllerReady = function(dataController, currentId)
            local function isReady()
                local readyValue = dataController.IsReady

                if type(readyValue) == "function" then
                    local ok, result = pcall(function()
                        return dataController:IsReady()
                    end)
                    return ok and result == true
                end

                return readyValue == true
            end

            if isReady() then
                return true
            end

            -- DataController exposes WaitForReady; call it once, then verify its ready flag.
            if type(dataController.WaitForReady) == "function" then
                pcall(function()
                    dataController:WaitForReady()
                end)
            end

            while not isReady() do
                if currentId and not helpers.stillRunning(currentId) then
                    return false
                end
                task.wait(0.25)
            end

            return true
        end

        helpers.getLowIncomeAnimals = function(currentId)
            if minimumCashPerSecond <= 0 then
                return {}
            end

            local dataController, mutations, moduleError = helpers.getPetDataModules()
            if not dataController or not mutations then
                error(moduleError or "Pet data modules are unavailable.")
            end

            if not helpers.waitForDataControllerReady(dataController, currentId) then
                return nil
            end

            local ok, animals = pcall(function()
                return dataController:Get("Animals") or {}
            end)
            if not ok then
                error("Could not read Animals inventory: " .. tostring(animals))
            end

            local bestIncome = player:GetAttribute("BestIncome") or 0
            local lowIncomeAnimals = {}

            for key, record in pairs(animals) do
                local entry = record
                local animalId = key

                if type(record) == "table" then
                    if record.Entry then
                        entry = record.Entry
                    end
                    animalId = record.Id or key
                end

                if type(entry) == "table" and not entry.Placed then
                    local incomeOk, income = pcall(function()
                        return mutations.IncomeOf(entry, bestIncome)
                    end)

                    if not incomeOk then
                        error("IncomeOf failed for animal " .. tostring(animalId) .. ": " .. tostring(income))
                    end

                    income = tonumber(income) or 0
                    if income < minimumCashPerSecond then
                        table.insert(lowIncomeAnimals, {
                            Id = tostring(animalId),
                            Income = income,
                            ModelName = tostring(entry.ModelName or "Unknown")
                        })
                    end
                end
            end

            return lowIncomeAnimals
        end

        helpers.getSellZonePosition = function()
            local sellPlace = workspace:FindFirstChild("SellPlace")
            local zonePad = sellPlace and sellPlace:FindFirstChild("ZonePad", true)
            if not zonePad then
                error("Workspace.SellPlace.ZonePad was not found.")
            end

            if zonePad:IsA("BasePart") then
                return zonePad.Position
            end

            if zonePad:IsA("Model") then
                return zonePad:GetPivot().Position
            end

            error("SellPlace.ZonePad is not a BasePart or Model.")
        end

        helpers.moveToSellPlace = function(currentId)
            helpers.setStatus("sellMoving", nil)
            helpers.debugLog("Finding path to Workspace.SellPlace.ZonePad...")

            local character, humanoid, rootPart = helpers.getCharacterReferences()
            if not character or not humanoid or not rootPart then
                error("Character references not found before moving to SellPlace.")
            end

            local targetPosition = helpers.getSellZonePosition()

            for attempt = 1, MAX_PATH_RETRIES do
                if not helpers.stillRunning(currentId) then
                    return false
                end
                if player.Character ~= character then
                    return false
                end

                rootPart = character:FindFirstChild("HumanoidRootPart")
                if not rootPart then
                    return false
                end

                if (rootPart.Position - targetPosition).Magnitude <= WAYPOINT_REACH_DISTANCE then
                    return true
                end

                local path = PathfindingService:CreatePath({
                    AgentRadius = 2,
                    AgentHeight = 5,
                    AgentCanJump = true,
                    AgentCanClimb = true,
                    WaypointSpacing = 4
                })

                local computed, computeError = pcall(function()
                    path:ComputeAsync(rootPart.Position, targetPosition)
                end)

                if computed and path.Status == Enum.PathStatus.Success then
                    local followed = helpers.followPath(path, character, humanoid, currentId)
                    if followed then
                        rootPart = character:FindFirstChild("HumanoidRootPart")
                        if rootPart and (rootPart.Position - targetPosition).Magnitude <= WAYPOINT_REACH_DISTANCE then
                            helpers.debugLog("SellPlace.ZonePad reached.")
                            return true
                        end
                    end
                else
                    helpers.debugLog("SellPlace path attempt " .. attempt .. " failed: " .. tostring(computeError or path.Status))
                end

                if not helpers.stillRunning(currentId) then
                    return false
                end
                task.wait(0.5)
            end

            error("Could not reach Workspace.SellPlace.ZonePad after path retries.")
        end

        helpers.waitForManualLowIncomeSale = function(currentId)
            -- This filter belongs to the normal Auto Throw toggle, not AFK FARM.
            if autoFarmRunning or minimumCashPerSecond <= 0 then
                return true
            end

            local lowAnimals = helpers.getLowIncomeAnimals(currentId)
            if not lowAnimals then
                return false
            end
            if #lowAnimals == 0 then
                return true
            end

            helpers.debugLog("Found " .. #lowAnimals .. " pet(s) below the Cash/S threshold.")
            if not helpers.moveToSellPlace(currentId) then
                return false
            end

            while helpers.stillRunning(currentId) do
                lowAnimals = helpers.getLowIncomeAnimals(currentId)
                if not lowAnimals then
                    return false
                end
                if #lowAnimals == 0 then
                    helpers.debugLog("All low-income pets were removed from inventory. Resuming Auto Throw.")
                    return true
                end

                helpers.setStatus(
                    "sellWaiting",
                    tostring(#lowAnimals) .. " low-income pet(s) remaining",
                    0
                )
                task.wait(0.5)
            end

            return false
        end

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

                        -- 8. CHECK PET CASH/S AFTER EVERY RESPAWN.
                        -- The filter waits for DataController.IsReady before reading inventory.
                        task.wait(0.25)
                        -- Low-income pets are never sold automatically:
                        -- walk to SellPlace.ZonePad and wait for manual sale.
                        if not helpers.waitForManualLowIncomeSale(currentId) then
                            break
                        end

                        -- 9. WAIT UNTIL THROW COOLDOWN IS ZERO
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

                        -- 10. LOOP RESTARTS AND WALKS TO STARTERAREA
                        helpers.debugLog("Cooldown finished. Moving to StarterArea...")

                        -- D�ng� ba�a d�ner:
                        -- StarterArea'ya y�r�r, animasyon ba�lar,
                        -- g�� yakalan�r, f�rlat�l�r ve tekrar reset at�l�r.
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
            autoEquipBestWorkerId += 1
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
                            task.wait(0.1)
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
                                error("TrainingSpot'a 120 saniye i�inde ula��lamad�.")
                            end
                            task.wait(0.1)
                        end
                        if not autoFarmRunning or autoFarmWorkerId ~= thisWorkerId then break end
                        if not trainingReady then error("Training ba�lat�lamad�.") end

                        for remaining = autoFarmTrainingSeconds, 0, -1 do
                            if not autoFarmRunning or autoFarmWorkerId ~= thisWorkerId then break end
                            helpers.setAfkTraining(remaining)
                            task.wait(1)
                        end
                        if not autoFarmRunning or autoFarmWorkerId ~= thisWorkerId then break end

                        -- Phase 3: stop training, then equip best pets and list names.
                        helpers.setTrainForAutoFarm(false)
                        task.wait(1)
                        local equipped = helpers.invokeEquipBest()
                        task.wait(1)
                        local petNames = helpers.readEquippedPetNames()
                        helpers.setAfkPets(petNames)
                        helpers.debugLog("AFK Farm Equip Best: " .. tostring(equipped) .. "; pets: " .. table.concat(petNames, ", "))
                        task.wait(1)
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
        -- CARD BORDER
        --==================================================
    
        local cardStroke = Instance.new("UIStroke")
        cardStroke.Color = RED
        cardStroke.Thickness = 1.4
        cardStroke.Transparency = 0.12
        cardStroke.Parent = sellCard
    
        --==================================================
        -- PAW CONTAINER
        --==================================================
    
        local pawContainer = Instance.new("Frame")
        pawContainer.Name = "PawLogo"
        pawContainer.Size = UDim2.fromOffset(34, 34)
        pawContainer.Position = UDim2.fromOffset(10, 7)
        pawContainer.BackgroundTransparency = 1
        pawContainer.ZIndex = 4
        pawContainer.Parent = sellCard
    
        --==================================================
        -- PAW SHAPE HELPER
        --==================================================
    
        local function createPawPart(name, x, y, width, height, rotation, color, zIndex)
    
            local part = Instance.new("Frame")
            part.Name = name
            part.AnchorPoint = Vector2.new(0.5, 0.5)
            part.Position = UDim2.fromOffset(x, y)
            part.Size = UDim2.fromOffset(width, height)
            part.Rotation = rotation or 0
            part.BackgroundColor3 = color or RED
            part.BorderSizePixel = 0
            part.ZIndex = zIndex or 5
            part.Parent = pawContainer
    
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(1, 0)
            corner.Parent = part
    
            return part
        end
    
        --==================================================
        -- PAW SHAPE
        --==================================================
    
        -- Main paw pad
        createPawPart("MainPad", 17, 24, 22, 16, 0, RED, 5)
    
        -- Four toes: moved closer to the main pad
        createPawPart("Toe1", 5, 12, 7, 10, -25, RED, 5)
        createPawPart("Toe2", 12, 7, 7, 10, -8, RED_LIGHT, 5)
        createPawPart("Toe3", 22, 7, 7, 10, 8, RED_LIGHT, 5)
        createPawPart("Toe4", 29, 12, 7, 10, 25, RED, 5)
    
       
        --==================================================
        -- DIVIDER
        --==================================================
    
        local divider = Instance.new("Frame")
        divider.Name = "LogoDivider"
        divider.Position = UDim2.fromOffset(49, 10)
        divider.Size = UDim2.new(0, 1, 1, -20)
        divider.BackgroundColor3 = MUTED
        divider.BackgroundTransparency = 0.75
        divider.BorderSizePixel = 0
        divider.ZIndex = 4
        divider.Parent = sellCard
    
        --==================================================
        -- TITLE
        --==================================================
    
        local sellTitle = Instance.new("TextLabel")
        sellTitle.Name = "Title"
        sellTitle.BackgroundTransparency = 1
        sellTitle.Position = UDim2.fromOffset(60, 0)
        sellTitle.Size = UDim2.new(1, -120, 1, 0)
        sellTitle.Font = Enum.Font.GothamBold
        sellTitle.Text = "SELL ALL ANIMALS"
        sellTitle.TextColor3 = TEXT
        sellTitle.TextSize = 11
        sellTitle.TextXAlignment = Enum.TextXAlignment.Left
        sellTitle.ZIndex = 4
        sellTitle.Parent = sellCard
    
        --==================================================
        -- TOGGLE TRACK
        --==================================================
    
        local toggleTrack = Instance.new("Frame")
        toggleTrack.Name = "ToggleTrack"
        toggleTrack.AnchorPoint = Vector2.new(1, 0.5)
        toggleTrack.Position = UDim2.new(1, -11, 0.5, 0)
        toggleTrack.Size = UDim2.fromOffset(37, 20)
        toggleTrack.BackgroundColor3 = Color3.fromRGB(35, 42, 56)
        toggleTrack.BorderSizePixel = 0
        toggleTrack.ZIndex = 4
        toggleTrack.Parent = sellCard
    
        local toggleCorner = Instance.new("UICorner")
        toggleCorner.CornerRadius = UDim.new(1, 0)
        toggleCorner.Parent = toggleTrack
    
        local toggleStroke = Instance.new("UIStroke")
        toggleStroke.Color = MUTED
        toggleStroke.Thickness = 1
        toggleStroke.Transparency = 0.65
        toggleStroke.Parent = toggleTrack
    
        --==================================================
        -- TOGGLE KNOB
        --==================================================
    
        local toggleKnob = Instance.new("Frame")
        toggleKnob.Name = "ToggleKnob"
        toggleKnob.Position = UDim2.fromOffset(3, 3)
        toggleKnob.Size = UDim2.fromOffset(14, 14)
        toggleKnob.BackgroundColor3 = Color3.fromRGB(220, 225, 235)
        toggleKnob.BorderSizePixel = 0
        toggleKnob.ZIndex = 5
        toggleKnob.Parent = toggleTrack
    
        local knobCorner = Instance.new("UICorner")
        knobCorner.CornerRadius = UDim.new(1, 0)
        knobCorner.Parent = toggleKnob
    
    end)
end

return GameModule
