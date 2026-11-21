
--==================================================
-- BZHUB TOOLS
-- THROW FOOD FOR ANIMALS v5
--==================================================

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
        local TweenService = game:GetService("TweenService")
        local LocalizationService = game:GetService("LocalizationService")
        local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
        local auto2xEnabled = false
        local autoEquipBestEnabled = false

        local autoEquipBestWorkerId = 0
        local auto2xWorkerId = 0
        local actionId = 0
        local trainActionId = 0
        local automationCycleId = 0

        local isDragging = false
        local activeHudMode = "throw"
        local firstCycle = true

        local automationRunning = false
        local automationStatus = "IDLE"
        local successfulThrows = 0
        local completedResets = 0

        local startTrain
        local stopTrain
        local startAuto2x
        local stopAuto2x
        local startAutoThrow
        local stopAutoThrow
        local invokeEquipBest
        local setAutoThrowEnabled
        local setAutoTrainEnabled
        local setAuto2xEnabled

        --==================================================
        -- DEBUG
        --==================================================

        local function debugLog(message)
            print("[BZHUB AUTOMATIONS] " .. tostring(message))
        end

        --==================================================
        -- COLORS
        --==================================================

        local ACCENT = Color3.fromRGB(45, 155, 255)
        local ACCENT_BRIGHT = Color3.fromRGB(85, 190, 255)

        local PANEL = Color3.fromRGB(15, 20, 29)
        local CARD = Color3.fromRGB(17, 23, 33)

        local TEXT = Color3.fromRGB(225, 233, 245)
        local MUTED = Color3.fromRGB(145, 160, 180)

        local TRAIN_RED = Color3.fromRGB(242, 72, 82)
        local TRAIN_RED_BRIGHT = Color3.fromRGB(255, 105, 112)

        local EQUIP_GREEN = Color3.fromRGB(65, 205, 125)
        local EQUIP_GREEN_BRIGHT = Color3.fromRGB(105, 235, 155)

        --==================================================
        -- TRANSLATIONS
        --==================================================

        local translations = {
            English = {
                title = "AUTOMATIONS",
                power = "Power Level",
                info = "i",

                infoTitle = "AUTOMATIONS STATUS",
                infoHint = "Live information about the automation.",

                idle = "Automation is currently disabled.",
                starting = "Starting the automation...",
                moving = "Moving to the throw area. Please do not interfere.",
                initialWait = "Waiting at the starting area.",
                cooldown = "Waiting for the throw cooldown.",
                marker = "Waiting for the selected power level.",
                throwing = "Sending the throw input...",
                resetting = "Resetting the character...",
                stopped = "Auto Throw has been stopped.",

                trainMoving = "Moving to TrainingSpot...",
                training = "Training is active.",
                trainStopping = "Leaving the training area...",
                trainStopped = "Auto Train stopped.",

                enabled = "ENABLED",
                disabled = "DISABLED",
                close = "CLOSE"
            },

            Turkish = {
                title = "AUTOMATIONS",
                power = "Güç Seviyesi",
                info = "i",

                infoTitle = "AUTOMATIONS DURUMU",
                infoHint = "Otomasyonun anlık durumu.",

                idle = "Otomasyon şu anda kapalı.",
                starting = "Otomasyon başlatılıyor...",
                moving = "Atış alanına gidiliyor.",
                initialWait = "Başlangıç alanında bekleniyor.",
                cooldown = "Atış bekleme süresi bekleniyor.",
                marker = "Seçilen güç seviyesi bekleniyor.",
                throwing = "Atış gerçekleştiriliyor...",
                resetting = "Karakter sıfırlanıyor...",
                stopped = "Auto Throw durduruldu.",

                trainMoving = "TrainingSpot konumuna gidiliyor...",
                training = "Antrenman aktif.",
                trainStopping = "Antrenmandan çıkılıyor...",
                trainStopped = "Auto Train durduruldu.",

                enabled = "AÇIK",
                disabled = "KAPALI",
                close = "KAPAT"
            },

            Russian = {
                title = "АВТОМАТИЗАЦИЯ",
                power = "Уровень силы",
                info = "i",

                infoTitle = "СТАТУС АВТОМАТИЗАЦИИ",
                infoHint = "Текущий статус автоматизации.",

                idle = "Автоматизация выключена.",
                starting = "Запуск автоматизации...",
                moving = "Персонаж идет к зоне броска.",
                initialWait = "Ожидание в стартовой зоне.",
                cooldown = "Ожидание перезарядки.",
                marker = "Ожидание выбранного уровня силы.",
                throwing = "Выполнение броска...",
                resetting = "Перезапуск персонажа...",
                stopped = "Автобросок остановлен.",

                trainMoving = "Перемещение к TrainingSpot...",
                training = "Тренировка активна.",
                trainStopping = "Выход из тренировки...",
                trainStopped = "Автотренировка остановлена.",

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

        --==================================================
        -- TWEEN HELPER
        --==================================================

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

        --==================================================
        -- STATUS VARIABLES
        --==================================================

        local statusText
        local currentStatus = "idle"
        local currentStatusDetail = ""

        local hudGui
        local hudFill
        local hudStateText
        local hudInfoText
        local hudProgressTween
        local hudVisible = false

        --==================================================
        -- HUD PROGRESS
        --==================================================

        local function setHudProgress(progress)
            if not hudFill or not hudFill.Parent then
                return
            end

            if hudProgressTween then
                hudProgressTween:Cancel()
                hudProgressTween = nil
            end

            if type(progress) == "number" then
                hudFill.Size = UDim2.new(
                    math.clamp(progress, 0, 1),
                    0,
                    1,
                    0
                )
            else
                hudFill.Size = UDim2.new(0, 0, 1, 0)
            end
        end

        local function updateHud(key, detail, progress)
            if not hudGui then
                return
            end

            if hudStateText then
                local mode = activeHudMode == "train"
                    and "AUTO TRAIN"
                    or "AUTO THROW"

                local enabled = activeHudMode == "train"
                    and trainEnabled
                    or isEnabled

                hudStateText.Text = mode .. "   /   " ..
                    (enabled and "ON" or "OFF")
            end

            if hudInfoText then
                local messages = {
                    cooldown = "Waiting for protection cooldown...",
                    initialWait = "Waiting at starting position...",
                    moving = "Walking to position...",
                    marker = "Waiting for throw power...",
                    throwing = "Throwing...",
                    resetting = "Respawning character...",
                    starting = "Starting Auto Throw...",
                    trainMoving = "Walking to TrainingSpot...",
                    training = "Training is active.",
                    trainStopping = "Leaving the training area...",
                    trainStopped = "Auto Train stopped.",
                    stopped = "Auto Throw stopped."
                }

                hudInfoText.Text = messages[key]
                    or (detail and tostring(detail))
                    or tr(key)
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
                statusText.Text = tr(key)

                if key == "error" and currentStatusDetail ~= "" then
                    statusText.Text ..= currentStatusDetail
                end
            end

            updateHud(key, currentStatusDetail, progress)
        end

        --==================================================
        -- MAIN TITLE
        --==================================================

        local title = Instance.new("TextLabel")
        title.Name = "AutomationsTitle"
        title.Size = UDim2.new(1, -125, 0, 30)
        title.Position = UDim2.fromOffset(10, 10)
        title.BackgroundTransparency = 1
        title.Text = tr("title")
        title.TextSize = 18
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextColor3 = TEXT
        title.Font = Enum.Font.GothamBold
        title.Parent = page

        --==================================================
        -- MAIN AUTOMATION START / STOP BUTTON
        --==================================================

        local automationButton = Instance.new("TextButton")
        automationButton.Name = "AutomationStartButton"
        automationButton.AnchorPoint = Vector2.new(1, 0)
        automationButton.Position = UDim2.new(1, -10, 0, 10)
        automationButton.Size = UDim2.fromOffset(92, 29)
        automationButton.BackgroundColor3 = Color3.fromRGB(238, 242, 248)
        automationButton.BorderSizePixel = 0
        automationButton.Text = "START"
        automationButton.TextColor3 = Color3.fromRGB(15, 20, 29)
        automationButton.TextSize = 11
        automationButton.Font = Enum.Font.GothamBold
        automationButton.AutoButtonColor = false
        automationButton.Parent = page

        local automationButtonCorner = Instance.new("UICorner")
        automationButtonCorner.CornerRadius = UDim.new(0, 8)
        automationButtonCorner.Parent = automationButton

        local automationButtonStroke = Instance.new("UIStroke")
        automationButtonStroke.Color = Color3.fromRGB(255, 255, 255)
        automationButtonStroke.Transparency = 0.25
        automationButtonStroke.Thickness = 1
        automationButtonStroke.Parent = automationButton

        local automationButtonScale = Instance.new("UIScale")
        automationButtonScale.Scale = 1
        automationButtonScale.Parent = automationButton

        automationButton.MouseEnter:Connect(function()
            makeTween(automationButtonScale, 0.14, {
                Scale = 1.07
            })
        end)

        automationButton.MouseLeave:Connect(function()
            makeTween(automationButtonScale, 0.14, {
                Scale = 1
            })
        end)

        local function updateAutomationButton()
            if automationRunning then
                automationButton.Text = "STOP"
                automationButton.BackgroundColor3 =
                    Color3.fromRGB(235, 75, 85)

                automationButton.TextColor3 =
                    Color3.fromRGB(255, 255, 255)
            else
                automationButton.Text = "START"
                automationButton.BackgroundColor3 =
                    Color3.fromRGB(238, 242, 248)

                automationButton.TextColor3 =
                    Color3.fromRGB(15, 20, 29)
            end
        end

        --==================================================
        -- MAIN COMBINED CARD
        --==================================================

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
            ColorSequenceKeypoint.new(
                0,
                Color3.fromRGB(20, 31, 47)
            ),

            ColorSequenceKeypoint.new(
                1,
                Color3.fromRGB(14, 19, 28)
            )
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
        local function setSwitchState(enabled, instant)
            local knobPosition = enabled
                and UDim2.new(1, -26, 0, 3)
                or UDim2.fromOffset(3, 3)
        
            local backgroundColor = enabled
                and Color3.fromRGB(45, 155, 255)
                or Color3.fromRGB(43, 53, 68)
        
            local strokeTransparency = enabled and 0.08 or 0.55
        
            if instant then
                switchKnob.Position = knobPosition
                switchButton.BackgroundColor3 = backgroundColor
                switchStroke.Transparency = strokeTransparency
            else
                makeTween(switchKnob, 0.2, {
                    Position = knobPosition
                })
        
                makeTween(switchButton, 0.2, {
                    BackgroundColor3 = backgroundColor
                })
        
                makeTween(switchStroke, 0.2, {
                    Transparency = strokeTransparency
                })
            end
        
            if stateLabel then
                stateLabel.Text = enabled and tr("enabled") or tr("disabled")
                stateLabel.TextColor3 = enabled and ACCENT_BRIGHT or MUTED
            end
        end
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

        --==================================================
        -- POWER SLIDER
        --==================================================

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

        -- DEVAM: PART 2
        --==================================================
        -- AUTO TRAIN / AUTO 2X WORKERS
        --==================================================
        
        local auto2xWorkerId = 0
        local auto2xRunning = false
        local trainWorkerId = 0
        
        local function isAutomationRunning()
            return automationRunning == true
        end
        
        local function waitWhileRunning(duration, workerId)
            local elapsed = 0
        
            while elapsed < duration do
                if not isAutomationRunning() then
                    return false
                end
        
                if workerId and workerId ~= automationWorkerId then
                    return false
                end
        
                local step = math.min(0.1, duration - elapsed)
                task.wait(step)
                elapsed += step
            end
        
            return isAutomationRunning()
        end
        
        local function getCharacter()
            return player.Character
        end
        
        local function getHumanoid()
            local character = getCharacter()
            return character and character:FindFirstChildOfClass("Humanoid")
        end
        
        local function pressSpace()
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            end)
        end
        
        local function findTrainingSpot()
            local candidates = {
                workspace:FindFirstChild("TrainingSpot", true),
                workspace:FindFirstChild("Training", true)
            }
        
            for _, candidate in ipairs(candidates) do
                if candidate then
                    if candidate:IsA("BasePart") then
                        return candidate
                    end
        
                    if candidate:IsA("Model") then
                        return candidate.PrimaryPart
                            or candidate:FindFirstChildWhichIsA("BasePart", true)
                    end
                end
            end
        
            return nil
        end
        
        local function moveToTrainingSpot()
            local character = getCharacter()
            local humanoid = getHumanoid()
            local spot = findTrainingSpot()
        
            if not character or not humanoid or not spot then
                return false
            end
        
            local root = character:FindFirstChild("HumanoidRootPart")
            if not root then
                return false
            end
        
            root.CFrame = spot.CFrame + Vector3.new(0, 3, 0)
            return true
        end
        
        startTrain = function()
            if trainWorkerId > 0 then
                return
            end
        
            trainWorkerId += 1
            local thisWorker = trainWorkerId
        
            task.spawn(function()
                while trainEnabled and thisWorker == trainWorkerId do
                    if not moveToTrainingSpot() then
                        task.wait(0.5)
                    else
                        break
                    end
                end
        
                while trainEnabled and thisWorker == trainWorkerId do
                    task.wait(0.2)
                end
            end)
        end
        
        stopTrain = function()
            trainWorkerId += 1
            trainEnabled = false
            pressSpace()
        end
        
        local function findTapBonus()
            local sequence = playerGui:FindFirstChild("TrainingSequence")
            if not sequence then
                return nil
            end
        
            local layer = sequence:FindFirstChild("TapBonusLayer")
            if not layer then
                return nil
            end
        
            local tapBonus = layer:FindFirstChild("TapBonus")
            if tapBonus and tapBonus.Visible then
                return tapBonus
            end
        
            return nil
        end
        
        local function clickTapBonus(target)
            if not target or not target.Parent then
                return false
            end
        
            local position = target.AbsolutePosition
            local size = target.AbsoluteSize
        
            if size.X <= 0 or size.Y <= 0 then
                return false
            end
        
            local x = position.X + size.X / 2
            local y = position.Y + size.Y / 2
        
            pcall(function()
                VirtualInputManager:SendMouseMoveEvent(x, y, game)
                VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
                task.wait(0.04)
                VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
            end)
        
            return true
        end
        
        local function startAuto2x()
            if auto2xRunning then
                return
            end
        
            auto2xRunning = true
            auto2xWorkerId += 1
        
            local thisWorker = auto2xWorkerId
        
            task.spawn(function()
                while auto2xEnabled
                    and auto2xRunning
                    and thisWorker == auto2xWorkerId
                    and isAutomationRunning()
                do
                    local target = findTapBonus()
        
                    if target then
                        clickTapBonus(target)
        
                        while auto2xEnabled
                            and auto2xRunning
                            and thisWorker == auto2xWorkerId
                            and target.Parent
                            and target.Visible
                            and isAutomationRunning()
                        do
                            task.wait(0.12)
                            if target.Parent and target.Visible then
                                clickTapBonus(target)
                            end
                        end
                    else
                        task.wait(0.08)
                    end
                end
        
                if thisWorker == auto2xWorkerId then
                    auto2xRunning = false
                end
            end)
        end
        
        local function stopAuto2x()
            auto2xEnabled = false
            auto2xRunning = false
            auto2xWorkerId += 1
        end
        
        --==================================================
        -- AUTOMATION CYCLE
        --==================================================
        
        local automationRunning = false
        local automationWorkerId = 0
        local successfulThrowCount = 0
        
        local function setAutoThrowEnabled(enabled)
            isEnabled = enabled
        
            if switchButton and switchButton.Parent then
                setSwitchState(enabled)
            end
        
            if enabled then
                startAutoThrow()
            else
                stopAutoThrow()
            end
        end
        
        local function setAutoTrainEnabled(enabled)
            trainEnabled = enabled
        
            if trainStateLabel then
                trainStateLabel.Text = enabled and "ON" or "OFF"
                trainStateLabel.TextColor3 = enabled and TRAIN_RED_BRIGHT or MUTED
            end
        
            if trainSwitch then
                setRedSwitch(
                    trainSwitch,
                    trainKnob,
                    trainSwitchStroke,
                    enabled,
                    false
                )
            end
        
            if enabled then
                startTrain()
            else
                stopTrain()
            end
        end
        
        local function setAuto2xEnabled(enabled)
            auto2xEnabled = enabled
        
            if auto2xSwitch then
                setRedSwitch(
                    auto2xSwitch,
                    auto2xKnob,
                    auto2xSwitchStroke,
                    enabled,
                    false
                )
            end
        
            if enabled then
                startAuto2x()
            else
                stopAuto2x()
            end
        end
        
        local function resetCharacter()
            local humanoid = getHumanoid()
        
            if humanoid then
                humanoid.Health = 0
            end
        
            local oldCharacter = player.Character
            local startTime = os.clock()
        
            while automationRunning
                and player.Character == oldCharacter
                and os.clock() - startTime < 12
            do
                task.wait(0.1)
            end
        
            return automationRunning and player.Character ~= oldCharacter
        end
        
        local function runAutomationCycle(workerId)
            if not waitWhileRunning(0.2, workerId) then
                return false
            end
        
            successfulThrowCount = 0
        
            while successfulThrowCount < 5 do
                if not automationRunning or workerId ~= automationWorkerId then
                    return false
                end
        
                setAutoThrowEnabled(true)
        
                local previousThrowCount = successfulThrowCount
                local startTime = os.clock()
        
                while automationRunning
                    and workerId == automationWorkerId
                    and successfulThrowCount == previousThrowCount
                    and os.clock() - startTime < 90
                do
                    task.wait(0.1)
                end
        
                if not automationRunning or workerId ~= automationWorkerId then
                    return false
                end
        
                if successfulThrowCount == previousThrowCount then
                    setAutoThrowEnabled(false)
                    return false
                end
        
                setAutoThrowEnabled(false)
        
                if not resetCharacter() then
                    return false
                end
            end
        
            setAutoTrainEnabled(true)
            setAuto2xEnabled(true)
        
            local trainingStartedAt = os.clock()
        
            while automationRunning
                and workerId == automationWorkerId
                and os.clock() - trainingStartedAt < 60
            do
                task.wait(0.1)
            end
        
            if not automationRunning or workerId ~= automationWorkerId then
                return false
            end
        
            setAuto2xEnabled(false)
            setAutoTrainEnabled(false)
        
            if equipBestAnimals then
                pcall(equipBestAnimals)
            end
        
            return true
        end
        
        local function stopAutomation()
            automationRunning = false
            automationWorkerId += 1
        
            setAutoThrowEnabled(false)
            setAuto2xEnabled(false)
            setAutoTrainEnabled(false)
        
            successfulThrowCount = 0
        end
        
        local function startAutomation()
            if automationRunning then
                return
            end
        
            automationRunning = true
            automationWorkerId += 1
        
            local thisWorker = automationWorkerId
        
            task.spawn(function()
                while automationRunning and thisWorker == automationWorkerId do
                    local completed = runAutomationCycle(thisWorker)
        
                    if not completed then
                        break
                    end
        
                    task.wait(0.15)
                end
        
                if thisWorker == automationWorkerId then
                    stopAutomation()
                end
            end)
        end
        
        --==================================================
        -- START / STOP BUTTON
        --==================================================
        
        local startButton = Instance.new("TextButton")
        startButton.Name = "AutomationStartButton"
        startButton.AnchorPoint = Vector2.new(1, 0)
        startButton.Position = UDim2.new(1, -10, 0, 10)
        startButton.Size = UDim2.fromOffset(76, 29)
        startButton.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
        startButton.BorderSizePixel = 0
        startButton.Text = "START"
        startButton.TextColor3 = Color3.fromRGB(18, 22, 29)
        startButton.TextSize = 11
        startButton.Font = Enum.Font.GothamBold
        startButton.AutoButtonColor = false
        startButton.Parent = page
        
        local startCorner = Instance.new("UICorner")
        startCorner.CornerRadius = UDim.new(0, 8)
        startCorner.Parent = startButton
        
        local startStroke = Instance.new("UIStroke")
        startStroke.Color = Color3.fromRGB(255, 255, 255)
        startStroke.Transparency = 0.45
        startStroke.Thickness = 1
        startStroke.Parent = startButton
        
        local startButtonSize = UDim2.fromOffset(76, 29)
        
        startButton.MouseEnter:Connect(function()
            makeTween(startButton, 0.14, {
                Size = UDim2.fromOffset(81, 32)
            })
        end)
        
        startButton.MouseLeave:Connect(function()
            makeTween(startButton, 0.14, {
                Size = startButtonSize
            })
        end)
        
        startButton.MouseButton1Click:Connect(function()
            if automationRunning then
                stopAutomation()
                startButton.Text = "START"
                startButton.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
            else
                startAutomation()
                startButton.Text = "STOP"
                startButton.BackgroundColor3 = Color3.fromRGB(245, 75, 75)
            end
        end)
        --==================================================
        -- AUTOMATION CLEANUP
        --==================================================
        
        local function cleanupAutomation()
            stopAutomation()
        
            if startButton and startButton.Parent then
                startButton.Text = "START"
                startButton.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
            end
        end
        
        --==================================================
        -- CHARACTER RESPAWN HANDLING
        --==================================================
        
        player.CharacterAdded:Connect(function(character)
            if not automationRunning then
                return
            end
        
            task.wait(0.5)
        
            if not automationRunning then
                return
            end
        
            if trainEnabled then
                moveToTrainingSpot()
            end
        end)
        
        --==================================================
        -- THROW PROGRESS TRACKING
        --==================================================
        
        local function registerSuccessfulThrow()
            if not automationRunning then
                return
            end
        
            successfulThrowCount += 1
        
            local progress = math.clamp(successfulThrowCount / 5, 0, 1)
        
            if setHudProgress then
                setHudProgress(progress)
            end
        
            if successfulThrowCount >= 5 then
                setAutoThrowEnabled(false)
            end
        end
        
        --==================================================
        -- INITIAL STATE
        --==================================================
        
        automationRunning = false
        successfulThrowCount = 0
        
        setAutoThrowEnabled(false)
        setAutoTrainEnabled(false)
        setAuto2xEnabled(false)
        
        if setHudProgress then
            setHudProgress(0)
        end
        
        if startButton then
            startButton.Text = "START"
        end
        
        --==================================================
        -- END OF AUTOMATIONS
        --==================================================
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
