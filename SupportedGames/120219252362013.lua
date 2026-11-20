
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
        local THROW_WAYPOINT_TIMEOUT = 10
        local THROW_PATH_CHECK_INTERVAL = 0.04
        local TELEPORT_VERIFY_DELAY = 0.15
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
                infoTitle = "AUTO THROW STATUS",
                infoHint = "Live information about the automation.",
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
                infoTitle = "AUTO THROW DURUMU",
                infoHint = "Otomasyonun anlık durumu.",
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
                infoTitle = "СТАТУС АВТОБРОСКА",
                infoHint = "Текущий статус автоматизации.",
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

            if type(progress) == "number" then
                hudFill.Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0)
            else
                hudFill.Size = UDim2.new(0.18, 0, 1, 0)
                hudProgressTween = TweenService:Create(
                    hudFill,
                    TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                    {Size = UDim2.new(0.88, 0, 1, 0)}
                )
                hudProgressTween:Play()
            end
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
            if isEnabled or trainEnabled then
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
            end
        end

        local function setStatus(key, detail, progress)
            currentStatus = key
            currentStatusDetail = detail or ""

            if statusText and statusText.Parent then
                local message = tr(key)
                if key == "error" and currentStatusDetail ~= "" then
                    message = message .. currentStatusDetail
                end
                statusText.Text = message
            end

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
            trainEnabled = not trainEnabled
            trainStateLabel.Text = trainEnabled and "ON" or "OFF"
            trainStateLabel.TextColor3 = trainEnabled and TRAIN_RED_BRIGHT or MUTED
            setRedSwitch(trainSwitch, trainKnob, trainSwitchStroke, trainEnabled, false)

            if trainEnabled then
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

        auto2xSwitch.MouseButton1Click:Connect(function()
            if not trainEnabled then return end
            auto2xEnabled = not auto2xEnabled
            setRedSwitch(auto2xSwitch, auto2xKnob, auto2xSwitchStroke, auto2xEnabled, false)
        end)

        --==================================================
        -- AUTO EQUIP BEST PET CARD
        --==================================================

        local EQUIP_GREEN = Color3.fromRGB(65, 205, 125)
        local EQUIP_GREEN_BRIGHT = Color3.fromRGB(105, 235, 155)

        local equipBestCard = Instance.new("Frame")
        equipBestCard.Name = "AutoEquipBestPetCard"
        equipBestCard.Position = UDim2.fromOffset(10, 326)
        equipBestCard.Size = UDim2.new(1, -20, 0, 62)
        equipBestCard.BackgroundColor3 = CARD
        equipBestCard.BorderSizePixel = 0
        equipBestCard.Parent = page

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
        equipBestLabel.Position = UDim2.fromOffset(14, 7)
        equipBestLabel.Size = UDim2.new(1, -198, 0, 38)
        equipBestLabel.BackgroundTransparency = 1
        equipBestLabel.Text = "Auto Equip Best Pet"
        equipBestLabel.TextColor3 = TEXT
        equipBestLabel.TextSize = 13
        equipBestLabel.Font = Enum.Font.GothamSemibold
        equipBestLabel.TextXAlignment = Enum.TextXAlignment.Left
        equipBestLabel.Parent = equipBestCard

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

        local equipDivider = Instance.new("Frame")
        equipDivider.Name = "ControlsDivider"
        equipDivider.AnchorPoint = Vector2.new(1, 0.5)
        equipDivider.Position = UDim2.new(1, -80, 0.5, 0)
        equipDivider.Size = UDim2.fromOffset(1, 27)
        equipDivider.BackgroundColor3 = Color3.fromRGB(150, 170, 160)
        equipDivider.BackgroundTransparency = 0.62
        equipDivider.BorderSizePixel = 0
        equipDivider.Parent = equipBestCard

        local equipOnceButton = Instance.new("TextButton")
        equipOnceButton.Name = "EquipBestOnceButton"
        equipOnceButton.AnchorPoint = Vector2.new(1, 0)
        equipOnceButton.Position = UDim2.new(1, -88, 0, 10)
        equipOnceButton.Size = UDim2.fromOffset(96, 29)
        equipOnceButton.BackgroundColor3 = Color3.fromRGB(31, 76, 54)
        equipOnceButton.BorderSizePixel = 0
        equipOnceButton.Text = "EQUIP BEST"
        equipOnceButton.TextColor3 = EQUIP_GREEN_BRIGHT
        equipOnceButton.TextSize = 10
        equipOnceButton.Font = Enum.Font.GothamBold
        equipOnceButton.AutoButtonColor = false
        equipOnceButton.Parent = equipBestCard

        local equipOnceCorner = Instance.new("UICorner")
        equipOnceCorner.CornerRadius = UDim.new(0, 8)
        equipOnceCorner.Parent = equipOnceButton

        local equipOnceStroke = Instance.new("UIStroke")
        equipOnceStroke.Color = EQUIP_GREEN
        equipOnceStroke.Transparency = 0.5
        equipOnceStroke.Thickness = 1
        equipOnceStroke.Parent = equipOnceButton

        local function setEquipSwitchVisual(enabled, instant)
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
                makeTween(equipSwitchKnob, 0.2, {Position = knobPosition})
                makeTween(equipBestSwitch, 0.2, {BackgroundColor3 = switchColor})
                makeTween(equipSwitchStroke, 0.2, {Transparency = enabled and 0.08 or 0.48})
            end
        end

        local function invokeEquipBest()
            local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
            local remote = remotes and remotes:FindFirstChild("Plot_EquipBest")
            if not remote or not remote:IsA("RemoteFunction") then
                debugLog("Equip Best failed: Plot_EquipBest RemoteFunction was not found.")
                return false
            end

            local success, result = pcall(function()
                return remote:InvokeServer()
            end)

            if success then
                debugLog("Equip Best invoked successfully. Result: " .. tostring(result))
                return true
            end

            warn("[BZHUB EQUIP BEST ERROR] " .. tostring(result))
            return false
        end

        local function startAutoEquipBest()
            autoEquipBestWorkerId += 1
            local workerId = autoEquipBestWorkerId

            task.spawn(function()
                while autoEquipBestEnabled and workerId == autoEquipBestWorkerId do
                    invokeEquipBest()
                    for _ = 1, 80 do
                        if not autoEquipBestEnabled or workerId ~= autoEquipBestWorkerId then
                            break
                        end
                        task.wait(0.1)
                    end
                end
            end)
        end

        equipBestSwitch.MouseButton1Click:Connect(function()
            autoEquipBestEnabled = not autoEquipBestEnabled
            equipOnceButton.Visible = not autoEquipBestEnabled
            equipDivider.Visible = not autoEquipBestEnabled
            setEquipSwitchVisual(autoEquipBestEnabled, false)
            makeTween(equipBestStroke, 0.2, {
                Transparency = autoEquipBestEnabled and 0.08 or 0.3,
                Thickness = autoEquipBestEnabled and 1.8 or 1.35
            })

            if autoEquipBestEnabled then
                debugLog("Auto Equip Best Pet enabled.")
                startAutoEquipBest()
            else
                autoEquipBestWorkerId += 1
                debugLog("Auto Equip Best Pet disabled.")
            end
        end)

        equipOnceButton.MouseButton1Click:Connect(function()
            if not autoEquipBestEnabled then
                invokeEquipBest()
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
        -- This ScreenGui is independent from the BZHUB page and prefers
        -- the executor/CoreGui layer so it can sit above ordinary game GUIs.
        --==================================================

        hudGui = Instance.new("ScreenGui")
        hudGui.Name = "BZHUB_AutoThrow_StatusHUD"
        hudGui.ResetOnSpawn = false
        hudGui.IgnoreGuiInset = true
        -- Use the highest practical DisplayOrder so the HUD stays above
        -- other ScreenGuis sharing the same GUI layer.
        hudGui.DisplayOrder = 2147483647
        hudGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
        hudGui.Enabled = false

        -- Prefer the executor's hidden UI container (usually hosted under
        -- CoreGui). This can place the HUD above ordinary PlayerGui menus.
        -- If unavailable, fall back safely without breaking the module.
        local hudParent
        local getHiddenUI = gethui or get_hidden_gui
        if type(getHiddenUI) == "function" then
            local ok, hiddenUI = pcall(getHiddenUI)
            if ok and typeof(hiddenUI) == "Instance" then
                hudParent = hiddenUI
            end
        end

        if not hudParent then
            local coreGui = game:GetService("CoreGui")
            local coreGuiOk = pcall(function()
                hudGui.Parent = coreGui
            end)
            if coreGuiOk and hudGui.Parent == coreGui then
                hudParent = coreGui
            end
        end

        if hudParent then
            hudGui.Parent = hudParent
        else
            hudGui.Parent = playerGui
        end

        local hudContainer = Instance.new("Frame")
        hudContainer.Name = "StatusContainer"
        hudContainer.ZIndex = 100000
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

        -- Keep every HUD element on a high ZIndex inside its ScreenGui.
        for _, hudObject in ipairs(hudContainer:GetDescendants()) do
            if hudObject:IsA("GuiObject") then
                hudObject.ZIndex = math.max(hudObject.ZIndex, 100001)
            end
        end

        local infoHint = Instance.new("TextLabel")
        infoHint.Position = UDim2.fromOffset(13, 39)
        infoHint.Size = UDim2.new(1, -26, 0, 28)
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
        statusText.Position = UDim2.fromOffset(28, 75)
        statusText.Size = UDim2.new(1, -42, 0, 100)
        statusText.BackgroundTransparency = 1
        statusText.Text = tr("idle")
        statusText.TextColor3 = TEXT
        statusText.TextSize = 10
        statusText.Font = Enum.Font.Gotham
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
            local message = tr(currentStatus)
            if currentStatus == "error" and currentStatusDetail ~= "" then
                message = message .. currentStatusDetail
            end
            statusText.Text = message
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
            setStatus("cooldown")
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
                        setStatus("cooldown", string.format("%ds remaining", displayedSecond))
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
                    setStatus("cooldown", "Waiting for cooldown timer...")
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
            setStatus("marker")
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

            setStatus("throwing", "Sending throw input...", 0.9)
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

                    if os.clock() - startTime >= THROW_WAYPOINT_TIMEOUT then
                        break
                    end

                    task.wait(THROW_PATH_CHECK_INTERVAL)
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
            debugLog("Trying a quick teleport to StarterArea first...")

            local character, humanoid, rootPart = getCharacterReferences()

            if not character or not humanoid or not rootPart then
                error("Character references not found.")
            end

            local targetPosition = getStarterAreaPosition()

            if not stillRunning(currentId) then
                return false
            end

            local initialDistance = (rootPart.Position - targetPosition).Magnitude

            if initialDistance <= WAYPOINT_REACH_DISTANCE then
                debugLog("Already near StarterArea. No movement needed.")
                return true
            end

            -- First attempt: teleport directly to the throw area.
            local originalCFrame = rootPart.CFrame
            local teleportWorked = pcall(function()
                rootPart.CFrame = CFrame.new(targetPosition) * (originalCFrame - originalCFrame.Position)
            end)

            if teleportWorked then
                task.wait(TELEPORT_VERIFY_DELAY)

                if not stillRunning(currentId) then
                    return false
                end

                character, humanoid, rootPart = getCharacterReferences()

                if character and rootPart
                    and (rootPart.Position - targetPosition).Magnitude <= WAYPOINT_REACH_DISTANCE then
                    debugLog("Teleport to StarterArea succeeded.")
                    return true
                end

                debugLog("Teleport was rejected or did not reach StarterArea. Falling back to pathfinding.")

                -- Restore the starting point before normal pathfinding.
                if player.Character == character and rootPart then
                    pcall(function()
                        rootPart.CFrame = originalCFrame
                    end)
                end
                task.wait(0.08)
            else
                debugLog("Teleport attempt failed. Falling back to pathfinding.")
            end

            -- Fallback: preserve the existing obstacle-aware walking route.
            character, humanoid, rootPart = getCharacterReferences()

            if not character or not humanoid or not rootPart then
                error("Character references not found after teleport attempt.")
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

                local targetDistance = (rootPart.Position - targetPosition).Magnitude

                if targetDistance <= WAYPOINT_REACH_DISTANCE then
                    debugLog("StarterArea reached. No extra movement needed.")
                    return true
                end

                local path = PathfindingService:CreatePath({
                    AgentRadius = 2,
                    AgentHeight = 5,
                    AgentCanJump = true,
                    AgentCanClimb = true,
                    WaypointSpacing = 4
                })

                debugLog("Calculating walking route. Attempt " .. attempt .. "/" .. MAX_PATH_RETRIES)

                local computed, computeError = pcall(function()
                    path:ComputeAsync(rootPart.Position, targetPosition)
                end)

                if not computed then
                    debugLog("Path calculation error: " .. tostring(computeError))
                    task.wait(0.1)
                    continue
                end

                if not stillRunning(currentId) then
                    return false
                end

                if path.Status ~= Enum.PathStatus.Success then
                    debugLog("Pathfinding status: " .. tostring(path.Status))
                    task.wait(0.1)
                    continue
                end

                local pathSuccess = followPath(path, character, humanoid, currentId)

                if pathSuccess then
                    rootPart = character:FindFirstChild("HumanoidRootPart")

                    if rootPart then
                        local finalDistance = (rootPart.Position - targetPosition).Magnitude

                        if finalDistance <= WAYPOINT_REACH_DISTANCE then
                            debugLog("StarterArea reached successfully by walking!")
                            return true
                        end
                    end
                end

                if not stillRunning(currentId) then
                    return false
                end

                debugLog("Recalculating walking route...")
                task.wait(0.1)
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
            local roots = {playerGui, workspace}
            for _, root in ipairs(roots) do
                for _, object in ipairs(root:GetDescendants()) do
                    if object:IsA("GuiButton") then
                        local buttonText = ""
                        if object:IsA("TextButton") then
                            buttonText = string.upper((object.Text or ""):gsub("%s+", ""))
                        end
                        local objectName = string.upper(object.Name or "")
                        if buttonText == "STOP" or objectName == "STOP" or objectName:find("STOPTRAIN", 1, true) then
                            return object
                        end
                    end
                end
            end
            return nil
        end

        local function pressTrainingStopWithoutMouse()
            local stopButton = findTrainingStopButton()
            if not stopButton then
                warn("[BZHUB AUTO TRAIN] STOP button was not found in PlayerGui or Workspace.")
                return false, "STOP button not found"
            end

            debugLog("Training STOP control found: " .. stopButton:GetFullName())

            -- Fire the GUI's click signal directly. This does not move/click the real mouse (MB1).
            if typeof(firesignal) == "function" then
                local ok, err = pcall(function()
                    firesignal(stopButton.MouseButton1Click)
                end)
                if ok then
                    debugLog("Training STOP signal fired without MB1.")
                    return true
                end
                warn("[BZHUB AUTO TRAIN] Could not fire STOP signal: " .. tostring(err))
                return false, tostring(err)
            end

            -- Some executors expose the button connections but not firesignal.
            if typeof(getconnections) == "function" then
                local ok, connections = pcall(function()
                    return getconnections(stopButton.MouseButton1Click)
                end)
                if ok and type(connections) == "table" and #connections > 0 then
                    local fired = false
                    for _, connection in ipairs(connections) do
                        if connection.Enabled and type(connection.Function) == "function" then
                            local success = pcall(connection.Function)
                            fired = fired or success
                        end
                    end
                    if fired then
                        debugLog("Training STOP callback invoked without MB1.")
                        return true
                    end
                end
            end

            warn("[BZHUB AUTO TRAIN] Executor has no supported signal-fire function; STOP was not activated.")
            return false, "Executor does not support signal firing"
        end

        startTrain = function()
            trainActionId += 1
            local thisTrainId = trainActionId

            task.spawn(function()
                local ok, err = pcall(function()
                    activeHudMode = "train"
                    setStatus("trainMoving", "Trying a quick teleport to TrainingSpot...")

                    local spot, findError = findTrainingSpot()
                    if not spot then error(findError) end
                    local targetPosition = getTrainingSpotPosition(spot)
                    if not targetPosition then error("TrainingSpot has no usable position.") end

                    local character, humanoid, rootPart = getCharacterReferences()
                    if not character or not humanoid or not rootPart then
                        error("Character references are unavailable.")
                    end

                    if not trainEnabled or trainActionId ~= thisTrainId then return end

                    local initialDistance = (rootPart.Position - targetPosition).Magnitude
                    local reachedTrainingSpot = initialDistance <= WAYPOINT_REACH_DISTANCE

                    if reachedTrainingSpot then
                        debugLog("Already near TrainingSpot. No movement needed.")
                    else
                        -- First attempt: teleport directly to TrainingSpot.
                        local originalCFrame = rootPart.CFrame
                        local teleportWorked = pcall(function()
                            rootPart.CFrame = CFrame.new(targetPosition)
                                * (originalCFrame - originalCFrame.Position)
                        end)

                        if teleportWorked then
                            task.wait(TELEPORT_VERIFY_DELAY)

                            if not trainEnabled or trainActionId ~= thisTrainId then return end

                            character, humanoid, rootPart = getCharacterReferences()
                            if character and rootPart
                                and (rootPart.Position - targetPosition).Magnitude <= WAYPOINT_REACH_DISTANCE then
                                reachedTrainingSpot = true
                                debugLog("Teleport to TrainingSpot succeeded.")
                            else
                                debugLog("TrainingSpot teleport failed. Falling back to pathfinding.")
                                if character == player.Character and rootPart then
                                    pcall(function()
                                        rootPart.CFrame = originalCFrame
                                    end)
                                end
                                task.wait(0.08)
                            end
                        else
                            debugLog("TrainingSpot teleport attempt failed. Falling back to pathfinding.")
                        end
                    end

                    -- Fallback: use obstacle-aware pathfinding with jumping.
                    if not reachedTrainingSpot then
                        character, humanoid, rootPart = getCharacterReferences()
                        if not character or not humanoid or not rootPart then
                            error("Character references are unavailable after teleport attempt.")
                        end

                        local arrived = false

                        for attempt = 1, MAX_PATH_RETRIES do
                            if not trainEnabled or trainActionId ~= thisTrainId then return end
                            if player.Character ~= character then return end

                            rootPart = character:FindFirstChild("HumanoidRootPart")
                            if not rootPart then error("HumanoidRootPart disappeared.") end

                            if (rootPart.Position - targetPosition).Magnitude <= WAYPOINT_REACH_DISTANCE then
                                arrived = true
                                break
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

                            if not computed then
                                debugLog("Auto Train path calculation failed: " .. tostring(computeError))
                                task.wait(0.1)
                                continue
                            end

                            if path.Status ~= Enum.PathStatus.Success then
                                debugLog("Auto Train path status: " .. tostring(path.Status))
                                task.wait(0.1)
                                continue
                            end

                            local waypoints = path:GetWaypoints()
                            local pathReached = true

                            for index, waypoint in ipairs(waypoints) do
                                if not trainEnabled or trainActionId ~= thisTrainId then return end
                                if player.Character ~= character then return end

                                rootPart = character:FindFirstChild("HumanoidRootPart")
                                if not rootPart then error("HumanoidRootPart disappeared.") end

                                if (rootPart.Position - waypoint.Position).Magnitude <= 3.5 then
                                    continue
                                end

                                if waypoint.Action == Enum.PathWaypointAction.Jump then
                                    humanoid.Jump = true
                                end

                                humanoid:MoveTo(waypoint.Position)
                                local waypointStarted = os.clock()
                                local waypointReached = false

                                while trainEnabled and trainActionId == thisTrainId do
                                    if player.Character ~= character then return end
                                    rootPart = character:FindFirstChild("HumanoidRootPart")
                                    if not rootPart then return end

                                    if (rootPart.Position - waypoint.Position).Magnitude <= 3.5 then
                                        waypointReached = true
                                        break
                                    end

                                    if os.clock() - waypointStarted >= WAYPOINT_TIMEOUT then
                                        break
                                    end

                                    task.wait(THROW_PATH_CHECK_INTERVAL)
                                end

                                if not trainEnabled or trainActionId ~= thisTrainId then return end
                                if not waypointReached then
                                    pathReached = false
                                    debugLog("Auto Train waypoint timeout at " .. index .. "; recalculating path.")
                                    break
                                end
                            end

                            if pathReached then
                                rootPart = character:FindFirstChild("HumanoidRootPart")
                                if rootPart and (rootPart.Position - targetPosition).Magnitude <= WAYPOINT_REACH_DISTANCE then
                                    arrived = true
                                    break
                                end
                            end

                            task.wait(0.1)
                        end

                        if not arrived then
                            error("Could not reach TrainingSpot after teleport and pathfinding attempts.")
                        end
                    end

                    if not trainEnabled or trainActionId ~= thisTrainId then return end
                    setStatus("training", "TrainingSpot reached. Training is active.")
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

            setStatus("trainStopping", "Activating the game's STOP control...")
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
    
        local CHECK_DELAY = 0.05
    
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
            end)
    
            task.wait(0.2)
    
            return success
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
    
                task.wait(0.1)
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
    
            task.wait(0.2)
        end
    
        --==================================================
        -- SELL ALL
        --==================================================
    
        local function performSale()
    
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
    
            end, 10)
    
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
    
            task.wait(0.2)
        end
    
        --==================================================
        -- MAIN AUTOMATION
        --==================================================
    
        local function runSellAutomation()
    
            local character, humanoid, root = getCharacter()
            local originalCFrame = root.CFrame
    
            -- GUI already open: sell immediately.
    
            if isSellGuiOpen() then
                performSale()
                return
            end
    
            -- First try teleporting.
    
            local teleportSuccess = false
    
            local success, savedCFrame = pcall(function()
    
                local result, oldCFrame = teleportToSellPlace()
                teleportSuccess = result
    
                return oldCFrame
            end)
    
            if success and teleportSuccess then
    
                originalCFrame = savedCFrame or originalCFrame
    
                local opened = waitUntil(function()
                    return isSellGuiOpen()
                end, 5)
    
                if opened then
    
                    performSale()
                    teleportBack(originalCFrame)
    
                    return
                end
    
                teleportBack(originalCFrame)
            end
    
            -- Fallback: walk normally.
    
            walkToSellPlace()
    
            local openedByWalking = waitUntil(function()
                return isSellGuiOpen()
            end, 8)
    
            if not openedByWalking then
    
                if not walkToPosition(originalCFrame.Position) then
                    error("GUI did not open and return path failed")
                end
    
                error("Sell GUI did not open")
            end
    
            performSale()
    
            if not walkToPosition(originalCFrame.Position) then
                error("Sale completed, but return path failed")
            end
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
    
        createPawPart("MainPad", 17, 24, 22, 16, 0, RED, 5)
    
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
        sellTitle.Size = UDim2.new(1, -150, 1, 0)
        sellTitle.Font = Enum.Font.GothamBold
        sellTitle.Text = "SELL ALL ANIMALS"
        sellTitle.TextColor3 = TEXT
        sellTitle.TextSize = 11
        sellTitle.TextXAlignment = Enum.TextXAlignment.Left
        sellTitle.ZIndex = 4
        sellTitle.Parent = sellCard
    
        --==================================================
        -- SELL BUTTON
        --==================================================
    
        local sellButton = Instance.new("TextButton")
        sellButton.Name = "SellButton"
        sellButton.AnchorPoint = Vector2.new(1, 0.5)
        sellButton.Position = UDim2.new(1, -10, 0.5, 0)
        sellButton.Size = UDim2.fromOffset(75, 27)
        sellButton.BackgroundColor3 = RED_DARK
        sellButton.BorderSizePixel = 0
        sellButton.AutoButtonColor = false
        sellButton.Font = Enum.Font.GothamBold
        sellButton.Text = "SELL"
        sellButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        sellButton.TextSize = 10
        sellButton.ZIndex = 5
        sellButton.Parent = sellCard
    
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 6)
        buttonCorner.Parent = sellButton
    
        local buttonStroke = Instance.new("UIStroke")
        buttonStroke.Color = RED_LIGHT
        buttonStroke.Thickness = 1
        buttonStroke.Transparency = 0.2
        buttonStroke.Parent = sellButton
    
        --==================================================
        -- BUTTON HOVER
        --==================================================
    
        sellButton.MouseEnter:Connect(function()
    
            if not sellBusy then
                sellButton.BackgroundColor3 = RED
            end
        end)
    
        sellButton.MouseLeave:Connect(function()
    
            if not sellBusy then
                sellButton.BackgroundColor3 = RED_DARK
            end
        end)
    
        --==================================================
        -- SELL BUTTON ACTION
        --==================================================
    
        sellButton.MouseButton1Click:Connect(function()
    
            if sellBusy then
                return
            end
    
            sellBusy = true
            sellButton.Text = "WORKING..."
            sellButton.BackgroundColor3 = Color3.fromRGB(65, 70, 85)
    
            task.spawn(function()
    
                local success, err = pcall(runSellAutomation)
    
                if success then
                    sellButton.Text = "SOLD"
                else
                    warn("[BZHUB SELL ERROR]:", err)
                    sellButton.Text = "FAILED"
                end
    
                task.wait(1)
    
                sellBusy = false
                sellButton.Text = "SELL"
                sellButton.BackgroundColor3 = RED_DARK
            end)
        end)
    
    end)
end
return GameModule
