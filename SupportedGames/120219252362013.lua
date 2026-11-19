
local GameModule = {}

function GameModule.Register(api)
    api.AddCategory("Automation", "AUTOMATION", function(page)

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
        local isDragging = false
        local actionId = 0
        local trainActionId = 0
        local activeHudMode = "throw"
        local startTrain
        local stopTrain

        -- İlk başlangıçta 6 saniye bekle.
        -- Sonraki döngülerde ThrowReadyAt beklenecek.
        local firstCycle = true

        --==================================================
        -- DEBUG
        --==================================================

        local function debugLog(message)
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
                title = "AUTO THROW",
                power = "Power Level",
                info = "i",
                infoTitle = "AUTO THROW - IMPORTANT NOTES",
                infoHint = "• The 6-second starting wait is normal.\n• Do not move or click while the automation is waiting.\n• Cooldown delays are part of the game.\n• Keep the game open until the throw is complete.",
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
                title = "AUTO THROW",
                power = "Güç Seviyesi",
                info = "i",
                infoTitle = "AUTO THROW - IMPORTANT NOTES",
                infoHint = "• The 6-second starting wait is normal.\n• Do not move or click while the automation is waiting.\n• Cooldown delays are part of the game.\n• Keep the game open until the throw is complete.",
                idle = "Auto Throw şu anda kapalı.",
                starting = "Otomasyon başlatılıyor...",
                moving = "Atış alanına yürünüyor. Lütfen müdahale etmeyin.",
                initialWait = "Başlangıç alanında 6 saniye bekleniyor. Lütfen dokunmayın.",
                cooldown = "Atış bekleme süresi / koruma bitene kadar bekleniyor. Hiçbir şeye dokunmayın; süre bitince hareket başlayacak.",
                marker = "Atış göstergesinde seçilen güç seviyesi bekleniyor.",
                throwing = "Seçilen güç yakalandı. Atış girdisi gönderiliyor...",
                resetting = "Atış tamamlandı. Karakter sıfırlanıyor...",
                stopped = "Auto Throw durduruldu.",
                error = "Bir hata oluştu: ",
                enabled = "AÇIK",
                disabled = "KAPALI",
                close = "KAPAT"
            },
            Russian = {
                title = "АВТО БРОСОК",
                power = "Уровень силы",
                info = "i",
                infoTitle = "AUTO THROW - IMPORTANT NOTES",
                infoHint = "• The 6-second starting wait is normal.\n• Do not move or click while the automation is waiting.\n• Cooldown delays are part of the game.\n• Keep the game open until the throw is complete.",
                idle = "Автобросок сейчас выключен.",
                starting = "Запуск автоматизации...",
                moving = "Персонаж идет к зоне броска. Пожалуйста, не вмешивайтесь.",
                initialWait = "Ожидание 6 секунд в стартовой зоне. Пожалуйста, не трогайте ничего.",
                cooldown = "Ожидание перезарядки / защиты броска. Ничего не трогайте; движение начнется после окончания таймера.",
                marker = "Ожидание выбранного уровня силы на индикаторе броска.",
                throwing = "Нужная сила достигнута. Отправка команды броска...",
                resetting = "Бросок завершен. Персонаж перезапускается...",
                stopped = "Автобросок остановлен.",
                error = "Произошла ошибка: ",
                enabled = "ВКЛ",
                disabled = "ВЫКЛ",
                close = "ЗАКРЫТЬ"
            }
        }

        local function getLanguage()
            return "English"
        end

        local function tr(key)
            local language = translations[getLanguage()] or translations.English
            return language[key] or translations.English[key] or key
        end

        local function makeTween(object, duration, properties, style, direction)
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

        local function setHudProgress(progress)
            if not hudFill or not hudFill.Parent then return end

            if hudProgressTween then
                hudProgressTween:Cancel()
                hudProgressTween = nil
            end

            local actualProgress = (type(progress) == "number") and progress or 0
            hudFill.Size = UDim2.new(math.clamp(actualProgress, 0, 1), 0, 1, 0)
        end

        local function updateHud(key, detail, progress)
            if not hudGui then return end
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
                    message = tr(key)
                end
                hudInfoText.Text = message
            end
            local active = (activeHudMode == "train" and trainEnabled)
                or (activeHudMode == "throw" and isEnabled)

            if active then
                hudGui.Enabled = true
                hudVisible = true
                setHudProgress(progress)
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

        local function setStatus(key, detail, progress)
            currentStatus = key
            currentStatusDetail = detail or ""

            updateHud(key, currentStatusDetail, progress)
        end

        local title = Instance.new("TextLabel")
        title.Name = "AutoThrowTitle"
        title.Size = UDim2.new(1, -20, 0, 30)
        title.Position = UDim2.fromOffset(10, 10)
        title.BackgroundTransparency = 1
        title.Text = tr("title")
        title.TextSize = 18
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextColor3 = TEXT
        title.Font = Enum.Font.GothamBold
        title.Parent = page

        -- Main combined card: toggle + power slider.
        local mainCard = Instance.new("Frame")
        mainCard.Name = "AutoThrowCard"
        mainCard.Position = UDim2.fromOffset(10, 55)
        mainCard.Size = UDim2.new(1, -20, 0, 132)
        mainCard.BackgroundColor3 = CARD
        mainCard.BorderSizePixel = 0
        mainCard.Parent = page

        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 12)
        cardCorner.Parent = mainCard

        local cardStroke = Instance.new("UIStroke")
        cardStroke.Color = ACCENT
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
        toggleLabel.Position = UDim2.fromOffset(14, 7)
        toggleLabel.Size = UDim2.new(1, -112, 0, 38)
        toggleLabel.BackgroundTransparency = 1
        toggleLabel.Text = "Auto Throw"
        toggleLabel.TextColor3 = TEXT
        toggleLabel.TextSize = 14
        toggleLabel.Font = Enum.Font.GothamSemibold
        toggleLabel.TextXAlignment = Enum.TextXAlignment.Left
        toggleLabel.Parent = mainCard

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
        stateLabel.Text = tr("disabled")
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
        trainCard.Position = UDim2.fromOffset(10, 198)
        trainCard.Size = UDim2.new(1, -20, 0, 62)
        trainCard.BackgroundColor3 = CARD
        trainCard.BorderSizePixel = 0
        trainCard.ClipsDescendants = true
        trainCard.Parent = page

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
        trainLabel.Position = UDim2.fromOffset(14, 7)
        trainLabel.Size = UDim2.new(1, -115, 0, 38)
        trainLabel.BackgroundTransparency = 1
        trainLabel.Text = "Auto Train"
        trainLabel.TextColor3 = TEXT
        trainLabel.TextSize = 14
        trainLabel.Font = Enum.Font.GothamSemibold
        trainLabel.TextXAlignment = Enum.TextXAlignment.Left
        trainLabel.Parent = trainCard

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

        local function makeTrainSwitch(name, parent, position, size)
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

        local trainSwitch, trainKnob, trainSwitchStroke = makeTrainSwitch(
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

        local auto2xSwitch, auto2xKnob, auto2xSwitchStroke = makeTrainSwitch(
            "Auto2xSwitch", auto2xRow,
            UDim2.new(1, -8, 0.5, -14), UDim2.fromOffset(62, 28)
        )
        auto2xKnob.Size = UDim2.fromOffset(22, 22)

        local function setRedSwitch(button, knob, outline, enabled, instant)
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
                makeTween(knob, 0.2, {Position = targetPosition})
                makeTween(button, 0.2, {BackgroundColor3 = targetColor})
                makeTween(outline, 0.2, {Transparency = enabled and 0.08 or 0.48})
            end
        end

        trainSwitch.MouseButton1Click:Connect(function()
            if not trainEnabled and isEnabled then
                debugLog("Auto Train toggle blocked: Auto Throw is already enabled.")
                return
            end

            trainEnabled = not trainEnabled
            trainStateLabel.Text = trainEnabled and "ON" or "OFF"
            trainStateLabel.TextColor3 = trainEnabled and TRAIN_RED_BRIGHT or MUTED
            setRedSwitch(trainSwitch, trainKnob, trainSwitchStroke, trainEnabled, false)

            if trainEnabled then
                activeHudMode = "train"
                auto2xRow.Visible = true
                auto2xRow.BackgroundTransparency = 1
                auto2xRow.Position = UDim2.fromOffset(12, 55)
                makeTween(trainCard, 0.28, {Size = UDim2.new(1, -20, 0, 116)})
                makeTween(auto2xRow, 0.28, {
                    Position = UDim2.fromOffset(12, 66),
                    BackgroundTransparency = 0.12
                })
                makeTween(trainCardStroke, 0.22, {Transparency = 0.08, Thickness = 1.8})
                if startTrain then startTrain() end
            else
                auto2xEnabled = false
                setRedSwitch(auto2xSwitch, auto2xKnob, auto2xSwitchStroke, false, false)
                local collapse = makeTween(trainCard, 0.24, {Size = UDim2.new(1, -20, 0, 62)})
                makeTween(auto2xRow, 0.18, {
                    Position = UDim2.fromOffset(12, 54),
                    BackgroundTransparency = 1
                })
                makeTween(trainCardStroke, 0.22, {Transparency = 0.3, Thickness = 1.35})
                collapse.Completed:Connect(function()
                    if not trainEnabled then
                        auto2xRow.Visible = false
                    end
                end)
                if stopTrain then stopTrain() end
            end
        end)

        -- Auto 2x: detect TapBonus continuously. After a short reaction delay,
        -- teleport the cursor to its center, pause briefly, click once, then
        -- immediately restore the previous cursor position.
        local function findTapBonusButton()
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

        local function clickTapBonusAndRestoreCursor(button)
            if not button or not button:IsA("GuiButton") then return false end
            if not button.Visible or not button.Active then return false end
            if button.AbsoluteSize.X <= 0 or button.AbsoluteSize.Y <= 0 then return false end
            if type(mousemoveabs) ~= "function" or type(mouse1click) ~= "function" then
                warn("[BZHUB AUTO 2X] Solara mousemoveabs/mouse1click is unavailable.")
                return false
            end

            local oldPosition = UserInputService:GetMouseLocation()
            local targetX = math.floor(button.AbsolutePosition.X + button.AbsoluteSize.X / 2)
            local targetY = math.floor(button.AbsolutePosition.Y + button.AbsoluteSize.Y / 2)
            local moved = false

            local ok, err = pcall(function()
                -- Give the bonus a brief moment to settle after it appears.
                task.wait(0.22)

                -- Solara moves the cursor directly to the target coordinates.
                mousemoveabs(targetX, targetY)
                moved = true

                -- Short, deliberate pause so the game registers the cursor position.
                task.wait(0.14)
                mouse1click()

                -- Tiny release pause, then restore the original cursor position.
                task.wait(0.08)
            end)

            -- Restore the cursor even if the click call errors.
            if moved then
                local restoreOk, restoreErr = pcall(function()
                    mousemoveabs(math.floor(oldPosition.X), math.floor(oldPosition.Y))
                end)
                if not restoreOk then
                    warn("[BZHUB AUTO 2X] Could not restore cursor position: " .. tostring(restoreErr))
                end
            end

            if not ok then
                warn("[BZHUB AUTO 2X] TapBonus click failed: " .. tostring(err))
                return false
            end
            return true
        end

        auto2xSwitch.MouseButton1Click:Connect(function()
            if not trainEnabled then return end
            auto2xEnabled = not auto2xEnabled
            setRedSwitch(auto2xSwitch, auto2xKnob, auto2xSwitchStroke, auto2xEnabled, false)

            auto2xWorkerId += 1
            local thisWorkerId = auto2xWorkerId
            if auto2xEnabled then
                task.spawn(function()
                    local lastClickedObject = nil
                    local warnedMissingButton = false

                    while trainEnabled and auto2xEnabled and auto2xWorkerId == thisWorkerId do
                        local clickButton, tapBonusObject = findTapBonusButton()

                        if not tapBonusObject then
                            lastClickedObject = nil
                            warnedMissingButton = false
                        elseif not clickButton then
                            if not warnedMissingButton then
                                warn("[BZHUB AUTO 2X] TapBonus exists but no GuiButton was found.")
                                warnedMissingButton = true
                            end
                        elseif tapBonusObject ~= lastClickedObject then
                            if clickTapBonusAndRestoreCursor(clickButton) then
                                debugLog("Auto 2x clicked TapBonus and restored cursor: " .. tapBonusObject:GetFullName())
                                lastClickedObject = tapBonusObject
                            end
                        end

                        task.wait(0.1)
                    end
                end)
            end
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
        infoPanelTitle.Text = tr("infoTitle")
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
        closeInfoButton.Text = "×"
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
        infoHint.Text = tr("infoHint")
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
        statusText.Text = tr("idle")
        statusText.TextColor3 = TEXT
        statusText.TextSize = 10
        statusText.Font = Enum.Font.Gotham
        statusText.Text = tr("infoHint")
        statusText.TextWrapped = true
        statusText.TextXAlignment = Enum.TextXAlignment.Left
        statusText.TextYAlignment = Enum.TextYAlignment.Top
        statusText.ZIndex = 81
        statusText.Parent = infoPanel

        local sliderVisible = true
        local sliderTween

        local function setPowerSliderVisible(visible, instant)
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
                    mainCard.Size = UDim2.new(1, -20, 0, 132)
                    trainCard.Position = UDim2.fromOffset(10, 198)
                else
                    sliderContainer.Position = UDim2.fromOffset(12, 54)
                    sliderContainer.Size = UDim2.new(1, -24, 0, 0)
                    sliderContainer.GroupTransparency = 1
                    mainCard.Size = UDim2.new(1, -20, 0, 66)
                    trainCard.Position = UDim2.fromOffset(10, 132)
                    makeTween(mainCard, 0.3, {Size = UDim2.new(1, -20, 0, 132)})
                    makeTween(trainCard, 0.3, {Position = UDim2.fromOffset(10, 198)})
                    makeTween(sliderContainer, 0.28, {
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
                    makeTween(mainCard, 0.28, {Size = UDim2.new(1, -20, 0, 66)})
                    makeTween(trainCard, 0.28, {Position = UDim2.fromOffset(10, 132)})
                    makeTween(sliderContainer, 0.25, {
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

        local function refreshLanguage()
            title.Text = tr("title")
            infoPanelTitle.Text = tr("infoTitle")
            infoHint.Text = tr("infoHint")
            sliderLabel.Text = string.format("%s: %d", tr("power"), selectedSpeed)
            stateLabel.Text = isEnabled and "ON" or "OFF"
            statusText.Text = tr("infoHint")
        end

        local function setSwitchVisual(enabled, instant)
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
                makeTween(switchKnob, 0.22, {Position = knobPosition})
                makeTween(switchButton, 0.22, {BackgroundColor3 = switchColor})
                makeTween(switchStroke, 0.22, {Transparency = strokeTransparency})
                makeTween(switchKnob, 0.22, {BackgroundColor3 = knobColor})
                makeTween(cardStroke, 0.25, {
                    Transparency = enabled and 0.05 or 0.28,
                    Thickness = enabled and 1.8 or 1.35
                })
            end

            stateLabel.Text = enabled and "ON" or "OFF"
            stateLabel.TextColor3 = enabled and ACCENT_BRIGHT or MUTED
            setPowerSliderVisible(not enabled, instant)
            if hudStateText then
                hudStateText.Text = "AUTO THROW   /   " .. (enabled and "ON" or "OFF")
            end
            if hudGui then
                hudGui.Enabled = enabled
            end
        end

        local function openInfo()
            if infoOpen then return end
            refreshLanguage()
            infoOpen = true
            infoPanel.Visible = true
            infoPanel.Position = UDim2.new(1, 275, 0, 55)
            infoPanel.BackgroundTransparency = 0.15
            infoPanelStroke.Transparency = 0.7

            makeTween(infoPanel, 0.32, {
                Position = UDim2.new(1, -10, 0, 55),
                BackgroundTransparency = 0
            })
            makeTween(infoPanelStroke, 0.32, {Transparency = 0.18})
        end

        local function closeInfo()
            if not infoOpen then return end
            infoOpen = false

            local closeTween = makeTween(infoPanel, 0.26, {
                Position = UDim2.new(1, 275, 0, 55),
                BackgroundTransparency = 0.2
            }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

            makeTween(infoPanelStroke, 0.2, {Transparency = 0.75})
            closeTween.Completed:Connect(function()
                if not infoOpen and infoPanel.Parent then
                    infoPanel.Visible = false
                end
            end)
        end

        infoButton.MouseButton1Click:Connect(function()
            if infoOpen then
                closeInfo()
            else
                openInfo()
            end
        end)

        closeInfoButton.MouseButton1Click:Connect(closeInfo)

        infoButton.MouseEnter:Connect(function()
            makeTween(infoButton, 0.15, {
                BackgroundColor3 = Color3.fromRGB(32, 62, 91)
            })
        end)
        infoButton.MouseLeave:Connect(function()
            makeTween(infoButton, 0.15, {
                BackgroundColor3 = Color3.fromRGB(24, 42, 62)
            })
        end)

        local function updateSlider(value)
            if isEnabled then return end
            selectedSpeed = math.clamp(
                math.floor(value + 0.5),
                MIN_POWER,
                MAX_POWER
            )

            local percentage =
                (selectedSpeed - MIN_POWER) / (MAX_POWER - MIN_POWER)

            makeTween(sliderFill, 0.08, {
                Size = UDim2.new(percentage, 0, 1, 0)
            }, Enum.EasingStyle.Quad)

            makeTween(sliderKnob, 0.08, {
                Position = UDim2.new(percentage, 0, 0.5, 0)
            }, Enum.EasingStyle.Quad)

            sliderLabel.Text = string.format(
                "%s: %d",
                tr("power"),
                selectedSpeed
            )
        end

        local function updateSliderFromInput(input)
            local trackWidth = sliderTrack.AbsoluteSize.X
            if trackWidth <= 0 then return end

            local relativeX =
                input.Position.X - sliderTrack.AbsolutePosition.X

            local percentage = math.clamp(relativeX / trackWidth, 0, 1)
            local value = MIN_POWER + percentage * (MAX_POWER - MIN_POWER)
            updateSlider(value)
        end

        sliderTrack.InputBegan:Connect(function(input)
            if isEnabled or not sliderVisible then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                isDragging = true
                updateSliderFromInput(input)
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
                updateSliderFromInput(input)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                isDragging = false
            end
        end)

        switchButton.MouseEnter:Connect(function()
            makeTween(switchStroke, 0.15, {Transparency = isEnabled and 0 or 0.3})
        end)
        switchButton.MouseLeave:Connect(function()
            makeTween(switchStroke, 0.15, {Transparency = isEnabled and 0.08 or 0.55})
        end)

        updateSlider(selectedSpeed)
        setPowerSliderVisible(true, true)
        setSwitchVisual(false, true)
        refreshLanguage()
        if hudGui then hudGui.Enabled = false end

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
            local lastSecond = -1

            while os.clock() - startTime < seconds do
                if not stillRunning(currentId) then
                    return false
                end

                local elapsed = os.clock() - startTime
                local remaining = math.max(0, seconds - elapsed)
                local shown = math.ceil(remaining)

                if shown ~= lastSecond then
                    lastSecond = shown
                    setStatus(currentStatus, string.format("%ds remaining", shown),
                        math.clamp(elapsed / math.max(seconds, 0.01), 0, 1))
                else
                    setHudProgress(math.clamp(elapsed / math.max(seconds, 0.01), 0, 1))
                end

                task.wait(0.05)
            end

            return stillRunning(currentId)
        end

        --==================================================
        -- THROW COOLDOWN
        --==================================================

        local function waitForThrowCooldown(currentId)
            setStatus("cooldown", "Waiting for the game cooldown...", 0)
            debugLog("Waiting for ThrowReadyAt cooldown...")

            local lastDisplayedSecond = -1

            while stillRunning(currentId) do
                local readyAt = player:GetAttribute("ThrowReadyAt")

                if type(readyAt) == "number" then
                    local remaining = math.max(
                        0,
                        readyAt - workspace:GetServerTimeNow()
                    )

                    local displayedSecond = math.ceil(remaining)

                    if displayedSecond ~= lastDisplayedSecond then
                        lastDisplayedSecond = displayedSecond
                        setStatus("cooldown", string.format("%ds remaining", displayedSecond), 0)
                        debugLog(string.format(
                            "Throw cooldown remaining: %.2f seconds",
                            remaining
                        ))
                    end

                    if remaining <= 0 then
                        debugLog("Throw cooldown finished! Starting movement.")
                        return true
                    end
                else
                    setStatus("cooldown", "Waiting for cooldown timer...", 0)
                    debugLog("ThrowReadyAt not available yet. Waiting...")
                end

                task.wait(0.05)
            end

            return false
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
            setStatus("marker", "Waiting for the selected power marker...", 0)
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
                debugLog("Detection mode: FIRST PASS (Y decreasing).")
            else
                debugLog("Detection mode: SECOND PASS (Y increasing).")
            end

            while stillRunning(currentId) do
                if not marker.Parent then
                    marker = getThrowMarker()

                    if not marker then
                        error("ThrowSequence Marker disappeared.")
                    end
                end

                local currentY = marker.Position.Y.Scale
                -- The HUD bar follows the marker's real position in the game meter.
                setHudProgress(1 - math.clamp(currentY, 0, 1))

                if previousY ~= nil then
                    local difference = currentY - previousY

                    if difference < -DIRECTION_EPSILON then
                        sawDescending = true
                    end

                    if sawDescending
                        and difference > DIRECTION_EPSILON then

                        if not sawAscending then
                            sawAscending = true

                            debugLog(
                                "Marker reversed direction. Second pass started."
                            )
                        end
                    end

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

            setStatus("throwing", "Sending throw input...", 0)
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
            setStatus("moving", nil)
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
                    debugLog("Pathfinding status: " .. tostring(path.Status))
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

            setStatus("resetting", "Respawning character...")
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
        -- AUTO TRAIN: FIND TRAINING SPOT AND EXIT CONTROL
        --==================================================

        local function findTrainingSpot()
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

        local function getTrainingSpotPosition(spot)
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

        local function findTrainingStopButton()
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

        local function pressTrainingStopWithoutMouse()
            local stopButton = findTrainingStopButton()
            if not stopButton then
                warn("[BZHUB AUTO TRAIN] STOP control was not found at PlayerGui.TrainingSequence.Button.")
                return false, "STOP button not found"
            end

            -- User requested SPACE instead of clicking the game's STOP button.
            -- This intentionally does not use mousemoveabs, mouse1click, firesignal,
            -- getconnections, or GuiButton:Activate().
            local keyCode = Enum.KeyCode.Space

            if type(keypress) == "function" and type(keyrelease) == "function" then
                local ok, err = pcall(function()
                    keypress(0x20)
                    task.wait(0.08)
                    keyrelease(0x20)
                end)
                if ok then
                    debugLog("Training stop requested with SPACE via Solara keyboard input.")
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
                debugLog("Training stop requested with SPACE via VirtualInputManager.")
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
                    setStatus("trainMoving", "Walking to TrainingSpot...")

                    local spot, findError = findTrainingSpot()
                    if not spot then error(findError) end
                    local targetPosition = getTrainingSpotPosition(spot)
                    if not targetPosition then error("TrainingSpot has no usable position.") end

                    local character, humanoid, rootPart = getCharacterReferences()
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

                    setStatus("trainMoving", "Calculating route...", 0)
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
                            setStatus("trainMoving", string.format("Waypoint %d/%d", index, #waypoints), totalProgress)
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
                    setStatus("training", "TrainingSpot reached. Training is active.", 1)
                    debugLog("TrainingSpot reached. Waiting until Auto Train is disabled.")
                    while trainEnabled and trainActionId == thisTrainId do
                        task.wait(0.2)
                    end
                end)

                if not ok and trainActionId == thisTrainId then
                    warn("[BZHUB AUTO TRAIN ERROR] " .. tostring(err))
                    setStatus("trainError", tostring(err))
                end
            end)
        end

        stopTrain = function()
            trainActionId += 1
            activeHudMode = isEnabled and "throw" or "train"
            if trainEnabled then return end

            if hudGui then hudGui.Enabled = false end
            setStatus("trainStopping", "Activating the game's STOP control...", 0)
            task.spawn(function()
                local stopped, stopError = pressTrainingStopWithoutMouse()
                if not stopped then
                    debugLog("Could not activate STOP control: " .. tostring(stopError))
                end
                if isEnabled then
                    activeHudMode = "throw"
                    setStatus(currentStatus, currentStatusDetail)
                else
                    setStatus("trainStopped")
                end
            end)
        end

        --==================================================
        -- MAIN FARM LOOP
        --==================================================

        local function startFarm()
            actionId += 1

            local currentId = actionId

            firstCycle = true

            task.spawn(function()
                local success, err = pcall(function()

                    setStatus("starting")
                    debugLog("Farm started.")

                    while stillRunning(currentId) do

                        -- 1. WALK TO STARTERAREA
                        if not moveToStarterArea(currentId) then
                            break
                        end

                        -- 2. ONLY FIRST CYCLE: WAIT 6 SECONDS
                        if firstCycle then
                            setStatus("initialWait", "6s remaining", 0)
                            debugLog("First cycle: waiting 6 seconds at StarterArea...")

                            if not waitWhileEnabled(
                                INITIAL_STARTER_WAIT,
                                currentId
                            ) then
                                break
                            end

                            firstCycle = false
                        end

                        -- 3. GET SELECTED POWER
                        local targetPower = selectedSpeed

                        debugLog(
                            "StarterArea reached. Selected power: "
                            .. targetPower
                        )

                        -- 4. WAIT FOR MARKER POWER
                        if not waitForSelectedPower(
                            targetPower,
                            currentId
                        ) then
                            break
                        end

                        -- 5. CLICK / THROW
                        if not performClick(currentId) then
                            break
                        end

                        -- 6. WAIT BEFORE RESET
                        debugLog("Waiting 1 second before reset...")

                        if not waitWhileEnabled(
                            AFTER_CLICK_DELAY,
                            currentId
                        ) then
                            break
                        end

                        -- 7. RESET CHARACTER
                        if not resetCharacter(currentId) then
                            break
                        end

                        -- 8. WAIT UNTIL THROW COOLDOWN IS ZERO
                        if not waitForThrowCooldown(currentId) then
                            break
                        end

                        -- 9. LOOP RESTARTS AND WALKS TO STARTERAREA
                        debugLog("Cooldown finished. Moving to StarterArea...")

                        -- Döngü başa döner:
                        -- StarterArea'ya yürür, animasyon başlar,
                        -- güç yakalanır, fırlatılır ve tekrar reset atılır.
                    end

                end)

                if not success then
                    warn("[BZHUB FARM ERROR] " .. tostring(err))

                    if currentId == actionId then
                        isEnabled = false

                        setSwitchVisual(false, false)
                        setStatus("error", tostring(err))
                        if hudGui then hudGui.Enabled = false end
                    end
                end

                debugLog("Farm loop stopped.")
            end)
        end

        --==================================================
        -- TOGGLE
        --==================================================

        switchButton.MouseButton1Click:Connect(function()
            if not isEnabled and trainEnabled then
                debugLog("Auto Throw toggle blocked: Auto Train is already enabled.")
                return
            end

            isEnabled = not isEnabled

            if isEnabled then
                activeHudMode = "throw"
                setSwitchVisual(true, false)
                setStatus("starting")
                debugLog("Farm enabled.")
                startFarm()
            else
                actionId += 1
                setSwitchVisual(false, false)
                if trainEnabled then
                    activeHudMode = "train"
                    setStatus("training")
                else
                    setStatus("stopped")
                    if hudGui then hudGui.Enabled = false end
                end
                debugLog("Farm disabled.")
            end
        end)

        debugLog("Farm module loaded.")

        -- Keep labels synchronized if the Roblox client language changes.
        LocalizationService:GetPropertyChangedSignal("RobloxLocaleId"):Connect(function()
            refreshLanguage()
        end)

    end)
end

return GameModule
