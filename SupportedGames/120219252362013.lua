
local GameModule = {}

function GameModule.Register(api)
    api.AddCategory("Farm", "AUTO THROW", function(page)

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
        local isDragging = false
        local actionId = 0

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
            -- Ana GUI isterse api.GetLanguage() veya api.GetCurrentLanguage()
            -- fonksiyonlarından biriyle seçili dili bu modüle aktarabilir.
            for _, methodName in ipairs({"GetLanguage", "GetCurrentLanguage"}) do
                local method = api and api[methodName]
                if type(method) == "function" then
                    local ok, result = pcall(method, api)
                    if ok and type(result) == "string" then
                        local lowered = string.lower(result)
                        if lowered == "turkish" or lowered == "tr" or lowered == "tr-tr" then
                            return "Turkish"
                        elseif lowered == "russian" or lowered == "ru" or lowered == "ru-ru" then
                            return "Russian"
                        elseif lowered == "english" or lowered == "en" or lowered == "en-us" then
                            return "English"
                        end
                    end
                end
            end

            local locale = string.lower(LocalizationService.RobloxLocaleId or "en-us")
            if string.sub(locale, 1, 2) == "tr" then
                return "Turkish"
            elseif string.sub(locale, 1, 2) == "ru" then
                return "Russian"
            end
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

        local function setStatus(key, detail)
            currentStatus = key
            currentStatusDetail = detail or ""

            if statusText and statusText.Parent then
                local message = tr(key)
                if key == "error" and currentStatusDetail ~= "" then
                    message = message .. currentStatusDetail
                end
                statusText.Text = message
            end
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
        infoButton.Position = UDim2.new(1, -53, 0, 10)
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
        switchButton.Size = UDim2.fromOffset(34, 29)
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
        local sliderContainer = Instance.new("Frame")
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

        local infoOpen = false

        local function refreshLanguage()
            title.Text = tr("title")
            infoPanelTitle.Text = tr("infoTitle")
            infoHint.Text = tr("infoHint")
            sliderLabel.Text = string.format("%s: %d", tr("power"), selectedSpeed)
            stateLabel.Text = isEnabled and tr("enabled") or tr("disabled")
            local message = tr(currentStatus)
            if currentStatus == "error" and currentStatusDetail ~= "" then
                message = message .. currentStatusDetail
            end
            statusText.Text = message
        end

        local function setSwitchVisual(enabled, instant)
            local knobPosition = enabled
                and UDim2.fromOffset(8, 3)
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

            stateLabel.Text = enabled and tr("enabled") or tr("disabled")
            stateLabel.TextColor3 = enabled and ACCENT_BRIGHT or MUTED
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
            if not isDragging then return end
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
        setSwitchVisual(false, true)
        refreshLanguage()

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

            setStatus("throwing")
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
            setStatus("moving")
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

            setStatus("resetting")
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
                            setStatus("initialWait")
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
                setSwitchVisual(true, false)
                setStatus("starting")
                debugLog("Farm enabled.")
                startFarm()
            else
                actionId += 1
                setSwitchVisual(false, false)
                setStatus("stopped")
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
