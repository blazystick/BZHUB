
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

--==================================================
-- CONFIGURATION
--==================================================

local SUPPORTED_GAMES = {
    [120219252362013] = "Throw Food for Animals",
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local NORMAL_SIZE = UDim2.fromOffset(775, 515)
local MIN_SIZE = Vector2.new(775, 515)
local MAX_SIZE = Vector2.new(1000, 750)

local NORMAL_POSITION = UDim2.fromScale(0.5, 0.5)
local ISLAND_SIZE = UDim2.fromOffset(125, 42)
local ISLAND_POSITION = UDim2.new(0.5, 0, 0, 38)

local ACCENT = Color3.fromRGB(75, 174, 255)
local BACKGROUND = Color3.fromRGB(5, 5, 5)
local PANEL = Color3.fromRGB(10, 12, 16)

local minimized = false
local animating = false
local destroyed = false
local dragging = false
local resizing = false
local switchingPage = false

local dragStart
local startPosition
local dragInputType

local resizeStart
local resizeStartSize
local resizeStartPosition
local resizeDirection

local savedPosition = NORMAL_POSITION
local savedSize = NORMAL_SIZE

local islandClickCount = 0
local islandClickSequence = 0

local currentCategory = "Home"
local detailOpen = false
local keybindsOpen = false
local languageOpen = false
local theme = "Blue"
local currentLanguage = "English"

--==================================================
-- LANGUAGE SYSTEM
--==================================================

local LANGUAGES = {
    English = {
        Flag = "🇺🇸",
        Name = "English",

        Home = "    HOME",
        Information = "    INFORMATION",
        Settings = "    SETTINGS",

        Welcome = "Welcome to BZHUB",
        WelcomeSubtitle = "Your interface is ready. Select a category to get started.",
        HomeCardTitle = "BZHUB INTERFACE",
        HomeCardDescription = "Explore the available sections using the navigation menu.",
        Unsupported = "THIS GAME IS NOT SUPPORTED FOR THIS GUI",

        InformationTitle = "Interface Guide",
        InformationSubtitle = "Quick tips to help you use BZHUB.",

        SettingsTitle = "Settings",
        SettingsSubtitle = "Customize your BZHUB experience.",
        ThemeTitle = "Appearance / Theme",

        Keybinds = "Keybinds",
        KeybindDescription = "View available keyboard shortcuts.",
        EmptyKeybind = "No keybinds have been added yet.",

        LanguageButton = "Language",
        LanguageDescription = "Change the interface language.",
        LanguageTitle = "LANGUAGE",
        LanguageSubtitle = "Choose your preferred language.",
        Select = "Select",
        Selected = "Selected",

        RestoreTitle = "Double Click to Restore",
        RestoreShort = "Double-click the Dynamic Island to reopen the GUI.",
        RestoreDetailTitle = "Restore Your GUI",
        RestoreDetail = "When minimized, BZHUB transforms into the Dynamic Island. Double-click it to restore the GUI to its previous size and position.",

        ResetTitle = "Triple Click to Reset",
        ResetShort = "Triple-click the Dynamic Island to reset the GUI.",
        ResetDetailTitle = "Reset GUI Size & Position",
        ResetDetail = "Triple-clicking the Dynamic Island restores the GUI to its default size and centered position.",

        ResizeTitle = "Resizable Interface",
        ResizeShort = "Drag the edges or corners to resize the GUI.",
        ResizeDetailTitle = "Resize Your Interface",
        ResizeDetail = "Drag any edge or corner to resize the interface. Minimum and maximum size limits keep the layout usable.",

        DetailHeading = "MORE INFORMATION",
        DetailSubtitle = "Feature explanation",
        DetailPlaceholder = "Select an information item",
        DetailPlaceholderDescription = "Click the question mark next to an item to learn more.",

        KeybindHeading = "KEYBINDS",
        KeybindSubtitle = "Keyboard shortcuts",

        Loading = "Loading GUI... ",
        Checking = "CHECKING GAME...",
        UnsupportedStatus = "NOT SUPPORTED GAME FOUND",
    },

    Turkish = {
        Flag = "🇹🇷",
        Name = "Türkçe",

        Home = "    ANA SAYFA",
        Information = "    BİLGİLER",
        Settings = "    AYARLAR",

        Welcome = "BZHUB'a Hoş Geldin",
        WelcomeSubtitle = "Arayüzün hazır. Başlamak için bir kategori seç.",
        HomeCardTitle = "BZHUB ARAYÜZÜ",
        HomeCardDescription = "Gezinme menüsünü kullanarak mevcut bölümleri keşfet.",
        Unsupported = "BU OYUN BU GUI TARAFINDAN DESTEKLENMİYOR",

        InformationTitle = "Arayüz Rehberi",
        InformationSubtitle = "BZHUB kullanımı için kısa ipuçları.",

        SettingsTitle = "Ayarlar",
        SettingsSubtitle = "BZHUB deneyimini özelleştir.",
        ThemeTitle = "Görünüm / Tema",

        Keybinds = "Tuş Atamaları",
        KeybindDescription = "Kullanılabilir klavye kısayollarını görüntüle.",
        EmptyKeybind = "Henüz herhangi bir tuş ataması eklenmedi.",

        LanguageButton = "Dil",
        LanguageDescription = "Arayüz dilini değiştir.",
        LanguageTitle = "DİL",
        LanguageSubtitle = "Tercih ettiğin dili seç.",
        Select = "Seç",
        Selected = "Seçildi",

        RestoreTitle = "Çift Tıklayarak Aç",
        RestoreShort = "GUI'yi yeniden açmak için Dynamic Island'a çift tıkla.",
        RestoreDetailTitle = "GUI'yi Geri Yükle",
        RestoreDetail = "Küçültüldüğünde BZHUB, Dynamic Island'a dönüşür. GUI'yi önceki boyutuna ve konumuna döndürmek için iki kez tıkla.",

        ResetTitle = "Üç Tıklamayla Sıfırla",
        ResetShort = "GUI'yi sıfırlamak için Dynamic Island'a üç kez tıkla.",
        ResetDetailTitle = "GUI Boyutunu ve Konumunu Sıfırla",
        ResetDetail = "Dynamic Island'a üç kez tıklamak GUI'yi varsayılan boyutuna ve ekranın ortasına getirir.",

        ResizeTitle = "Boyutlandırılabilir Arayüz",
        ResizeShort = "GUI'yi boyutlandırmak için kenarları veya köşeleri sürükle.",
        ResizeDetailTitle = "Arayüzü Boyutlandır",
        ResizeDetail = "Arayüzü yeniden boyutlandırmak için herhangi bir kenarı veya köşeyi sürükle. Minimum ve maksimum boyut sınırları kullanılabilirliği korur.",

        DetailHeading = "DAHA FAZLA BİLGİ",
        DetailSubtitle = "Özellik açıklaması",
        DetailPlaceholder = "Bir bilgi öğesi seç",
        DetailPlaceholderDescription = "Daha fazla bilgi almak için bir öğenin yanındaki soru işaretine tıkla.",

        KeybindHeading = "TUŞ ATAMALARI",
        KeybindSubtitle = "Klavye kısayolları",

        Loading = "GUI yükleniyor... ",
        Checking = "OYUN KONTROL EDİLİYOR...",
        UnsupportedStatus = "DESTEKLENMEYEN OYUN",
    },

    Russian = {
        Flag = "🇷🇺",
        Name = "Русский",

        Home = "    ГЛАВНАЯ",
        Information = "    ИНФОРМАЦИЯ",
        Settings = "    НАСТРОЙКИ",

        Welcome = "Добро пожаловать в BZHUB",
        WelcomeSubtitle = "Интерфейс готов. Выберите категорию, чтобы начать.",
        HomeCardTitle = "ИНТЕРФЕЙС BZHUB",
        HomeCardDescription = "Используйте меню навигации, чтобы изучить разделы.",
        Unsupported = "ЭТА ИГРА НЕ ПОДДЕРЖИВАЕТСЯ",

        InformationTitle = "Руководство",
        InformationSubtitle = "Краткие советы по использованию BZHUB.",

        SettingsTitle = "Настройки",
        SettingsSubtitle = "Настройте интерфейс BZHUB.",
        ThemeTitle = "Внешний вид / Тема",

        Keybinds = "Клавиши",
        KeybindDescription = "Посмотреть доступные сочетания клавиш.",
        EmptyKeybind = "Сочетания клавиш пока не добавлены.",

        LanguageButton = "Язык",
        LanguageDescription = "Изменить язык интерфейса.",
        LanguageTitle = "ЯЗЫК",
        LanguageSubtitle = "Выберите предпочитаемый язык.",
        Select = "Выбрать",
        Selected = "Выбрано",

        RestoreTitle = "Двойной щелчок для открытия",
        RestoreShort = "Дважды нажмите на Dynamic Island, чтобы открыть GUI.",
        RestoreDetailTitle = "Восстановить GUI",
        RestoreDetail = "В свёрнутом состоянии BZHUB превращается в Dynamic Island. Дважды нажмите на него, чтобы вернуть прежний размер и положение GUI.",

        ResetTitle = "Тройной щелчок для сброса",
        ResetShort = "Трижды нажмите на Dynamic Island, чтобы сбросить GUI.",
        ResetDetailTitle = "Сброс размера и положения",
        ResetDetail = "Тройное нажатие на Dynamic Island возвращает GUI к исходному размеру и в центр экрана.",

        ResizeTitle = "Изменяемый интерфейс",
        ResizeShort = "Перетаскивайте края или углы, чтобы изменить размер GUI.",
        ResizeDetailTitle = "Изменить размер интерфейса",
        ResizeDetail = "Перетаскивайте любой край или угол, чтобы изменить размер интерфейса. Ограничения минимального и максимального размера помогают сохранить удобство.",

        DetailHeading = "ПОДРОБНЕЕ",
        DetailSubtitle = "Описание функции",
        DetailPlaceholder = "Выберите информационный пункт",
        DetailPlaceholderDescription = "Нажмите на вопросительный знак рядом с пунктом, чтобы узнать больше.",

        KeybindHeading = "КЛАВИШИ",
        KeybindSubtitle = "Сочетания клавиш",

        Loading = "Загрузка GUI... ",
        Checking = "ПРОВЕРКА ИГРЫ...",
        UnsupportedStatus = "ИГРА НЕ ПОДДЕРЖИВАЕТСЯ",
    }
}

local function translate(key)
    local language = LANGUAGES[currentLanguage] or LANGUAGES.English
    return language[key] or LANGUAGES.English[key] or key
end

--==================================================
-- THEMES
--==================================================

local THEMES = {
    Blue = {
        Accent = Color3.fromRGB(75, 174, 255),
        Dark = Color3.fromRGB(10, 12, 16),
        Category = Color3.fromRGB(19, 24, 32),
        Panel = Color3.fromRGB(10, 12, 16),
        Header = Color3.fromRGB(16, 23, 33),
        Card = Color3.fromRGB(17, 21, 28),
    },

    Purple = {
        Accent = Color3.fromRGB(165, 105, 255),
        Dark = Color3.fromRGB(15, 10, 20),
        Category = Color3.fromRGB(28, 19, 38),
        Panel = Color3.fromRGB(15, 10, 20),
        Header = Color3.fromRGB(28, 18, 37),
        Card = Color3.fromRGB(25, 17, 33),
    },

    Green = {
        Accent = Color3.fromRGB(65, 220, 130),
        Dark = Color3.fromRGB(8, 17, 12),
        Category = Color3.fromRGB(16, 31, 23),
        Panel = Color3.fromRGB(8, 17, 12),
        Header = Color3.fromRGB(13, 29, 19),
        Card = Color3.fromRGB(15, 28, 20),
    },

    Red = {
        Accent = Color3.fromRGB(255, 85, 95),
        Dark = Color3.fromRGB(20, 9, 10),
        Category = Color3.fromRGB(34, 18, 19),
        Panel = Color3.fromRGB(20, 9, 10),
        Header = Color3.fromRGB(36, 17, 20),
        Card = Color3.fromRGB(31, 15, 17),
    },
}

--==================================================
-- HELPERS
--==================================================

local function create(class, properties, parent)
    local object = Instance.new(class)

    for property, value in pairs(properties) do
        object[property] = value
    end

    object.Parent = parent
    return object
end

local function round(object, radius)
    create("UICorner", {
        CornerRadius = UDim.new(0, radius)
    }, object)
end

local function stroke(object, color, transparency)
    return create("UIStroke", {
        Color = color,
        Thickness = 1,
        Transparency = transparency or 0.3
    }, object)
end

local function tween(object, duration, properties, style, direction)
    local animation = TweenService:Create(
        object,
        TweenInfo.new(
            duration,
            style or Enum.EasingStyle.Quint,
            direction or Enum.EasingDirection.Out
        ),
        properties
    )

    animation:Play()
    return animation
end

local function label(parent, name, text, position, size, textSize, color)
    return create("TextLabel", {
        Name = name,
        Text = text,
        Position = position,
        Size = size,
        BackgroundTransparency = 1,
        TextColor3 = color or Color3.fromRGB(235, 240, 250),
        TextSize = textSize,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true
    }, parent)
end

local function addScale(object)
    local existing = object:FindFirstChildOfClass("UIScale")
    if existing then
        return existing
    end

    return create("UIScale", {
        Scale = 1
    }, object)
end

local function animateButton(button)
    if not button:IsA("TextButton") then return end

    local scale = addScale(button)
    local hovering = false

    button.MouseEnter:Connect(function()
        if destroyed then return end
        hovering = true

        tween(scale, 0.16, {
            Scale = 1.045
        }, Enum.EasingStyle.Quint)
    end)

    button.MouseLeave:Connect(function()
        if destroyed then return end
        hovering = false

        tween(scale, 0.16, {
            Scale = 1
        }, Enum.EasingStyle.Quint)
    end)

    button.MouseButton1Down:Connect(function()
        if destroyed then return end

        tween(scale, 0.09, {
            Scale = 0.95
        }, Enum.EasingStyle.Quad)
    end)

    button.MouseButton1Up:Connect(function()
        if destroyed then return end

        tween(scale, 0.13, {
            Scale = hovering and 1.045 or 1
        }, Enum.EasingStyle.Back)
    end)
end

-- Forward declarations
local screenGui
local main
local informationPanel
local detailScale
local detailTitle
local detailDescription
local keybindPanel
local keybindScale
local informationContent
local languagePanel
local languageScale

local islandDot

local categoryButtons = {}
local pages = {}
local shadows = {}

--==================================================
-- SCREEN GUI (TOPMOST)
--==================================================

-- Prefer the executor's hidden UI container so BZHUB is not limited
-- to the normal PlayerGui display layer. Fall back to PlayerGui when
-- gethui is unavailable or cannot be accessed.
local bzhubGuiParent = playerGui

if typeof(gethui) == "function" then
    local success, hiddenGui = pcall(function()
        return gethui()
    end)

    if success and hiddenGui then
        bzhubGuiParent = hiddenGui
    end
end

screenGui = create("ScreenGui", {
    Name = "BZHUB",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 2147483647,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
}, bzhubGuiParent)

--==================================================
-- LOADING SCREEN
--==================================================

local intro = create("Frame", {
    Name = "LoadingOverlay",
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 200
}, screenGui)

local introPanel = create("Frame", {
    Size = UDim2.fromOffset(440, 230),
    Position = UDim2.fromScale(0.5, 0.5),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Color3.fromRGB(7, 8, 11),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 201
}, intro)

round(introPanel, 18)

local introStroke = stroke(introPanel, Color3.fromRGB(55, 65, 80), 1)

local introScale = create("UIScale", {
    Scale = 0.88
}, introPanel)

local introTitle = label(
    introPanel, "Title", "BLAZY HUB",
    UDim2.new(0, 15, 0.5, -43),
    UDim2.new(1, -30, 0, 42), 30
)

introTitle.TextXAlignment = Enum.TextXAlignment.Center
introTitle.Font = Enum.Font.GothamBold
introTitle.TextTransparency = 1
introTitle.ZIndex = 202

local introCredit = label(
    introPanel, "Credit", "made by blazystick",
    UDim2.new(0, 15, 0.5, -12),
    UDim2.new(1, -30, 0, 20), 12,
    Color3.fromRGB(115, 125, 142)
)

introCredit.TextXAlignment = Enum.TextXAlignment.Center
introCredit.TextTransparency = 1
introCredit.ZIndex = 202

local loadingLabel = label(
    introPanel, "Loading", translate("Loading") .. "0%",
    UDim2.fromOffset(30, 160),
    UDim2.new(1, -60, 0, 20), 11,
    Color3.fromRGB(155, 166, 184)
)

loadingLabel.TextTransparency = 1
loadingLabel.ZIndex = 202

local progressBack = create("Frame", {
    Position = UDim2.fromOffset(30, 195),
    Size = UDim2.new(1, -60, 0, 5),
    BackgroundColor3 = Color3.fromRGB(30, 37, 49),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 202
}, introPanel)

round(progressBack, 5)

local progressFill = create("Frame", {
    Size = UDim2.fromScale(0, 1),
    BackgroundColor3 = ACCENT,
    BorderSizePixel = 0,
    ZIndex = 203
}, progressBack)

round(progressFill, 5)

--==================================================
-- MAIN WINDOW
--==================================================

main = create("Frame", {
    Name = "Main",
    Size = NORMAL_SIZE,
    Position = NORMAL_POSITION,
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = BACKGROUND,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Visible = false,
    ZIndex = 10
}, screenGui)

round(main, 20)

create("UISizeConstraint", {
    MinSize = MIN_SIZE,
    MaxSize = MAX_SIZE
}, main)

--==================================================
-- SHADOW
--==================================================

for i = 1, 6 do
    local offset = i * 10

    local shadow = create("Frame", {
        Name = "Shadow_" .. i,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = NORMAL_POSITION,
        Size = UDim2.fromOffset(
            NORMAL_SIZE.X.Offset + offset,
            NORMAL_SIZE.Y.Offset + offset
        ),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.76 + (i * 0.035),
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = i
    }, screenGui)

    round(shadow, 30)

    table.insert(shadows, {
        Frame = shadow,
        Transparency = shadow.BackgroundTransparency,
        Offset = offset
    })
end

--==================================================
-- BRAND AND STATUS
--==================================================

local brand = label(
    main, "Brand", "BZHUB",
    UDim2.fromOffset(20, 13),
    UDim2.fromOffset(65, 27), 13
)

brand.Font = Enum.Font.GothamBold
brand.ZIndex = 25

local statusDot = create("Frame", {
    Size = UDim2.fromOffset(9, 9),
    Position = UDim2.fromOffset(85, 22),
    BackgroundColor3 = Color3.fromRGB(220, 55, 55),
    BorderSizePixel = 0,
    ZIndex = 25
}, main)

round(statusDot, 10)

local statusText = label(
    main, "GameStatus", translate("Checking"),
    UDim2.fromOffset(102, 13),
    UDim2.new(1, -200, 0, 27), 10,
    Color3.fromRGB(220, 75, 75)
)

statusText.ZIndex = 25

--==================================================
-- WINDOW BUTTONS
--==================================================

local function windowButton(name, text, position, color)
    local button = create("TextButton", {
        Name = name,
        Size = UDim2.fromOffset(30, 30),
        Position = position,
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 21,
        Font = Enum.Font.Gotham,
        ZIndex = 30
    }, main)

    round(button, 10)
    animateButton(button)

    return button
end

local minimize = windowButton(
    "Minimize", "−",
    UDim2.new(1, -72, 0, 9),
    Color3.fromRGB(25, 25, 25)
)

local destroy = windowButton(
    "Destroy", "×",
    UDim2.new(1, -36, 0, 9),
    Color3.fromRGB(35, 13, 13)
)

--==================================================
-- GAME DETECTION
--==================================================

local detectedGame = SUPPORTED_GAMES[game.PlaceId]
local gameSupported = detectedGame ~= nil

if gameSupported then
    statusDot.BackgroundColor3 = Color3.fromRGB(55, 220, 115)
    statusText.Text = detectedGame
    statusText.TextColor3 = Color3.fromRGB(70, 225, 125)

    TweenService:Create(
        statusDot,
        TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {
            Size = UDim2.fromOffset(13, 13),
            BackgroundTransparency = 0.15
        }
    ):Play()
else
    statusDot.BackgroundColor3 = Color3.fromRGB(225, 55, 55)
    statusText.Text = translate("UnsupportedStatus")
    statusText.TextColor3 = Color3.fromRGB(235, 75, 75)
end

--==================================================
-- NAVIGATION
--==================================================

local navigation = create("Frame", {
    Name = "Navigation",
    Position = UDim2.fromOffset(16, 60),
    Size = UDim2.new(0, 145, 1, -76),
    BackgroundTransparency = 1,
    ZIndex = 25
}, main)

local function createCategory(name, text, y, isBottom)
    local button = create("TextButton", {
        Name = name,
        Position = UDim2.new(
            0, 0,
            isBottom and 1 or 0,
            isBottom and -44 or y
        ),
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = Color3.fromRGB(12, 14, 18),
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = Color3.fromRGB(195, 205, 220),
        TextSize = 11,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
        ZIndex = 26
    }, navigation)

    round(button, 10)

    local indicator = create("Frame", {
        Name = "NeonIndicator",
        Position = UDim2.fromOffset(7, 9),
        Size = UDim2.fromOffset(3, 20),
        BackgroundColor3 = ACCENT,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 28
    }, button)

    round(indicator, 5)

    button.MouseEnter:Connect(function()
        if currentCategory ~= name then
            tween(button, 0.15, {
                BackgroundColor3 = Color3.fromRGB(25, 30, 39)
            })
        end
    end)

    button.MouseLeave:Connect(function()
        if currentCategory ~= name then
            tween(button, 0.15, {
                BackgroundColor3 = Color3.fromRGB(12, 14, 18)
            })
        end
    end)

    animateButton(button)
    categoryButtons[name] = button

    return button
end

local homeButton = createCategory("Home", translate("Home"), 0)

local informationButton
if gameSupported then
    informationButton = createCategory("Information", translate("Information"), 45)
end

local settingsButton = createCategory("Settings", translate("Settings"), 0, true)

--==================================================
-- CONTENT AREA
--==================================================

local content = create("Frame", {
    Name = "Content",
    Position = UDim2.fromOffset(175, 60),
    Size = UDim2.new(1, -195, 1, -76),
    BackgroundColor3 = PANEL,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 21
}, main)

round(content, 15)
stroke(content, Color3.fromRGB(34, 42, 54), 0.3)

--==================================================
-- HOME PAGE
--==================================================

local homePage = create("Frame", {
    Name = "HomePage",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    ZIndex = 22
}, content)

local welcome = label(
    homePage, "Welcome", translate("Welcome"),
    UDim2.fromOffset(20, 22),
    UDim2.new(1, -40, 0, 35), 23
)

welcome.Font = Enum.Font.GothamBold
welcome.ZIndex = 23

local welcomeSubtitle = label(
    homePage, "Subtitle",
    translate("WelcomeSubtitle"),
    UDim2.fromOffset(20, 62),
    UDim2.new(1, -40, 0, 28), 11,
    Color3.fromRGB(130, 143, 161)
)

welcomeSubtitle.ZIndex = 23

create("Frame", {
    Position = UDim2.fromOffset(20, 104),
    Size = UDim2.new(1, -40, 0, 1),
    BackgroundColor3 = Color3.fromRGB(40, 48, 61),
    BorderSizePixel = 0,
    ZIndex = 23
}, homePage)

local homeCard = create("Frame", {
    Position = UDim2.fromOffset(20, 125),
    Size = UDim2.new(1, -40, 0, 105),
    BackgroundColor3 = Color3.fromRGB(17, 21, 28),
    BorderSizePixel = 0,
    ZIndex = 23
}, homePage)

round(homeCard, 11)

local homeCardTitle = label(
    homeCard, "CardTitle", translate("HomeCardTitle"),
    UDim2.fromOffset(15, 15),
    UDim2.new(1, -30, 0, 22), 12
)

homeCardTitle.Font = Enum.Font.GothamBold

local homeCardDescription = label(
    homeCard, "CardDescription",
    translate("HomeCardDescription"),
    UDim2.fromOffset(15, 43),
    UDim2.new(1, -30, 0, 40), 10,
    Color3.fromRGB(135, 147, 165)
)

local unsupportedLabel

if not gameSupported then
    unsupportedLabel = label(
        homePage, "Unsupported",
        translate("Unsupported"),
        UDim2.new(0, 20, 0, 255),
        UDim2.new(1, -40, 0, 65), 15,
        Color3.fromRGB(235, 75, 75)
    )

    unsupportedLabel.Font = Enum.Font.GothamBold
    unsupportedLabel.TextXAlignment = Enum.TextXAlignment.Center
end

--==================================================
-- INFORMATION PAGE
--==================================================

local informationPage = create("Frame", {
    Name = "InformationPage",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Visible = false,
    ZIndex = 22
}, content)

local infoTitle = label(
    informationPage, "Title", translate("InformationTitle"),
    UDim2.fromOffset(15, 12),
    UDim2.new(1, -30, 0, 26), 17
)

infoTitle.Font = Enum.Font.GothamBold

local infoSubtitle = label(
    informationPage, "Subtitle",
    translate("InformationSubtitle"),
    UDim2.fromOffset(15, 39),
    UDim2.new(1, -30, 0, 18), 10,
    Color3.fromRGB(125, 137, 155)
)

create("Frame", {
    Position = UDim2.fromOffset(15, 67),
    Size = UDim2.new(1, -30, 0, 1),
    BackgroundColor3 = Color3.fromRGB(40, 48, 61),
    BorderSizePixel = 0
}, informationPage)

--==================================================
-- INFORMATION DETAIL PANEL
--==================================================

informationPanel = create("Frame", {
    Name = "InformationDetailPanel",
    Size = UDim2.fromOffset(280, 415),
    Position = UDim2.fromOffset(0, 0),
    BackgroundColor3 = Color3.fromRGB(9, 12, 17),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Visible = false,
    ClipsDescendants = true,
    ZIndex = 100
}, screenGui)

round(informationPanel, 15)

local detailStroke = stroke(informationPanel, ACCENT, 0.3)

detailScale = create("UIScale", {
    Scale = 0.93
}, informationPanel)

local panelHeader = create("Frame", {
    Size = UDim2.new(1, 0, 0, 52),
    BackgroundColor3 = Color3.fromRGB(16, 23, 33),
    BorderSizePixel = 0,
    ZIndex = 101
}, informationPanel)

round(panelHeader, 15)

create("Frame", {
    Position = UDim2.new(0, 0, 1, -14),
    Size = UDim2.new(1, 0, 0, 14),
    BackgroundColor3 = Color3.fromRGB(16, 23, 33),
    BorderSizePixel = 0,
    ZIndex = 101
}, panelHeader)

local detailHeaderTitle = label(
    panelHeader, "Heading", translate("DetailHeading"),
    UDim2.fromOffset(15, 9),
    UDim2.new(1, -60, 0, 18), 10
)

detailHeaderTitle.Font = Enum.Font.GothamBold

local detailHeaderSubtitle = label(
    panelHeader, "Subtitle", translate("DetailSubtitle"),
    UDim2.fromOffset(15, 27),
    UDim2.new(1, -60, 0, 15), 9,
    Color3.fromRGB(123, 140, 160)
)

local closeDetail = create("TextButton", {
    Position = UDim2.new(1, -38, 0, 11),
    Size = UDim2.fromOffset(26, 26),
    BackgroundColor3 = Color3.fromRGB(39, 24, 27),
    BorderSizePixel = 0,
    Text = "×",
    TextColor3 = Color3.fromRGB(235, 135, 140),
    TextSize = 19,
    ZIndex = 103
}, panelHeader)

round(closeDetail, 7)
animateButton(closeDetail)

create("Frame", {
    Position = UDim2.fromOffset(12, 62),
    Size = UDim2.new(1, -24, 0, 1),
    BackgroundColor3 = Color3.fromRGB(43, 53, 67),
    BorderSizePixel = 0,
    ZIndex = 102
}, informationPanel)

detailTitle = label(
    informationPanel, "DetailTitle",
    translate("DetailPlaceholder"),
    UDim2.fromOffset(14, 77),
    UDim2.new(1, -28, 0, 45), 14
)

detailTitle.Font = Enum.Font.GothamBold
detailTitle.ZIndex = 102

detailDescription = label(
    informationPanel, "DetailDescription",
    translate("DetailPlaceholderDescription"),
    UDim2.fromOffset(14, 132),
    UDim2.new(1, -28, 0, 190), 11,
    Color3.fromRGB(156, 169, 187)
)

detailDescription.TextYAlignment = Enum.TextYAlignment.Top
detailDescription.ZIndex = 102

local detailAnimationId = 0
local keybindAnimationId = 0
local languageAnimationId = 0

--==================================================
-- PANEL ANIMATION SYSTEM
--==================================================

local function captureVisuals(panel)
    local saved = {}

    for _, object in ipairs(panel:GetDescendants()) do
        local data = {}

        if object:IsA("GuiObject") then
            data.BackgroundTransparency = object.BackgroundTransparency
        end

        if object:IsA("TextLabel") or object:IsA("TextButton") then
            data.TextTransparency = object.TextTransparency
        end

        if object:IsA("ImageLabel") or object:IsA("ImageButton") then
            data.ImageTransparency = object.ImageTransparency
        end

        if object:IsA("UIStroke") then
            data.Transparency = object.Transparency
        end

        if next(data) then
            saved[object] = data
        end
    end

    return saved
end

local function animatePanelOpen(panel, scaleObject, savedVisuals)
    panel.Visible = true
    panel.BackgroundTransparency = 1
    scaleObject.Scale = 0.91

    for object, data in pairs(savedVisuals) do
        if object.Parent then
            if data.BackgroundTransparency ~= nil then
                object.BackgroundTransparency = 1
            end

            if data.TextTransparency ~= nil then
                object.TextTransparency = 1
            end

            if data.ImageTransparency ~= nil then
                object.ImageTransparency = 1
            end

            if data.Transparency ~= nil then
                object.Transparency = 1
            end
        end
    end

    tween(panel, 0.3, {
        BackgroundTransparency = 0
    })

    tween(scaleObject, 0.42, {
        Scale = 1
    }, Enum.EasingStyle.Back)

    local index = 0

    for object, data in pairs(savedVisuals) do
        if object.Parent then
            index += 1

            task.delay(index * 0.012, function()
                if not panel.Visible or destroyed then return end

                local properties = {}

                if data.BackgroundTransparency ~= nil then
                    properties.BackgroundTransparency = data.BackgroundTransparency
                end

                if data.TextTransparency ~= nil then
                    properties.TextTransparency = data.TextTransparency
                end

                if data.ImageTransparency ~= nil then
                    properties.ImageTransparency = data.ImageTransparency
                end

                if data.Transparency ~= nil then
                    properties.Transparency = data.Transparency
                end

                if next(properties) then
                    tween(object, 0.25, properties)
                end
            end)
        end
    end
end

local function animatePanelClose(panel, scaleObject, animationId, getCurrentId, setOpen)
    setOpen(false)

    local thisId = animationId

    tween(panel, 0.2, {
        BackgroundTransparency = 1
    })

    tween(scaleObject, 0.2, {
        Scale = 0.91
    })

    for _, object in ipairs(panel:GetDescendants()) do
        if object:IsA("TextLabel") or object:IsA("TextButton") then
            tween(object, 0.15, {
                TextTransparency = 1
            })
        elseif object:IsA("UIStroke") then
            tween(object, 0.15, {
                Transparency = 1
            })
        elseif object:IsA("GuiObject") then
            tween(object, 0.15, {
                BackgroundTransparency = 1
            })
        end
    end

    task.delay(0.23, function()
        if destroyed then return end

        if getCurrentId() == thisId then
            panel.Visible = false
        end
    end)
end

local detailVisuals = captureVisuals(informationPanel)

local informationData = {
    {
        Id = "restore",
        TitleKey = "RestoreTitle",
        ShortKey = "RestoreShort",
        DetailTitleKey = "RestoreDetailTitle",
        DetailKey = "RestoreDetail"
    },

    {
        Id = "reset",
        TitleKey = "ResetTitle",
        ShortKey = "ResetShort",
        DetailTitleKey = "ResetDetailTitle",
        DetailKey = "ResetDetail"
    },

    {
        Id = "resize",
        TitleKey = "ResizeTitle",
        ShortKey = "ResizeShort",
        DetailTitleKey = "ResizeDetailTitle",
        DetailKey = "ResizeDetail"
    }
}

local informationRows = {}

local function closeInformationPanel()
    if not detailOpen then
        informationPanel.Visible = false
        return
    end

    detailAnimationId += 1

    animatePanelClose(
        informationPanel,
        detailScale,
        detailAnimationId,
        function()
            return detailAnimationId
        end,
        function(value)
            detailOpen = value
        end
    )
end

closeDetail.MouseButton1Click:Connect(closeInformationPanel)

local function openInformationPanel(data)
    if minimized or destroyed then return end

    detailAnimationId += 1
    detailOpen = true

    detailTitle.Text = translate(data.DetailTitleKey)
    detailDescription.Text = translate(data.DetailKey)

    animatePanelOpen(
        informationPanel,
        detailScale,
        detailVisuals
    )
end

local function createInformationRow(data, index)
    local row = create("Frame", {
        Name = data.Id,
        Position = UDim2.fromOffset(12, 77 + (index - 1) * 62),
        Size = UDim2.new(1, -24, 0, 54),
        BackgroundColor3 = Color3.fromRGB(17, 21, 28),
        BorderSizePixel = 0,
        ZIndex = 23
    }, informationPage)

    round(row, 9)

    local accent = create("Frame", {
        Position = UDim2.fromOffset(9, 13),
        Size = UDim2.fromOffset(3, 27),
        BackgroundColor3 = ACCENT,
        BorderSizePixel = 0,
        ZIndex = 24
    }, row)

    round(accent, 5)

    local title = label(
        row, "Title", translate(data.TitleKey),
        UDim2.fromOffset(20, 7),
        UDim2.new(1, -70, 0, 20), 11
    )

    title.Font = Enum.Font.GothamBold
    title.ZIndex = 24

    local description = label(
        row, "Description", translate(data.ShortKey),
        UDim2.fromOffset(20, 28),
        UDim2.new(1, -70, 0, 17), 9,
        Color3.fromRGB(130, 143, 161)
    )

    description.ZIndex = 24

    local infoButton = create("TextButton", {
        Name = "MoreInfo",
        Position = UDim2.new(1, -38, 0.5, -13),
        Size = UDim2.fromOffset(27, 27),
        BackgroundColor3 = Color3.fromRGB(29, 39, 53),
        BorderSizePixel = 0,
        Text = "?",
        TextColor3 = ACCENT,
        TextSize = 15,
        Font = Enum.Font.Gotham,
        ZIndex = 26
    }, row)

    round(infoButton, 8)
    stroke(infoButton, ACCENT, 0.4)
    animateButton(infoButton)

    infoButton.MouseEnter:Connect(function()
        tween(infoButton, 0.15, {
            BackgroundColor3 = Color3.fromRGB(43, 75, 105)
        })
    end)

    infoButton.MouseLeave:Connect(function()
        tween(infoButton, 0.15, {
            BackgroundColor3 = Color3.fromRGB(29, 39, 53)
        })
    end)

    infoButton.MouseButton1Click:Connect(function()
        openInformationPanel(data)
    end)

    row.MouseEnter:Connect(function()
        tween(row, 0.18, {
            BackgroundColor3 = Color3.fromRGB(24, 31, 42)
        })
    end)

    row.MouseLeave:Connect(function()
        tween(row, 0.18, {
            BackgroundColor3 = Color3.fromRGB(17, 21, 28)
        })
    end)

    table.insert(informationRows, {
        Title = title,
        Description = description,
        Data = data
    })
end

if gameSupported then
    for index, data in ipairs(informationData) do
        createInformationRow(data, index)
    end
end

--==================================================
-- SETTINGS PAGE
--==================================================

local settingsPage = create("Frame", {
    Name = "SettingsPage",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Visible = false,
    ZIndex = 22
}, content)

local settingsTitle = label(
    settingsPage, "Title", translate("SettingsTitle"),
    UDim2.fromOffset(15, 12),
    UDim2.new(1, -30, 0, 26), 17
)

settingsTitle.Font = Enum.Font.GothamBold

local settingsSubtitle = label(
    settingsPage, "Subtitle",
    translate("SettingsSubtitle"),
    UDim2.fromOffset(15, 39),
    UDim2.new(1, -30, 0, 18), 10,
    Color3.fromRGB(125, 137, 155)
)

create("Frame", {
    Position = UDim2.fromOffset(15, 67),
    Size = UDim2.new(1, -30, 0, 1),
    BackgroundColor3 = Color3.fromRGB(40, 48, 61),
    BorderSizePixel = 0
}, settingsPage)

local themeTitle = label(
    settingsPage, "ThemeTitle", translate("ThemeTitle"),
    UDim2.fromOffset(15, 82),
    UDim2.new(1, -30, 0, 22), 12
)

themeTitle.Font = Enum.Font.Gotham

local themeNames = {"Blue", "Purple", "Green", "Red"}
local themeButtons = {}

for index, name in ipairs(themeNames) do
    local button = create("TextButton", {
        Name = "Theme_" .. name,
        Position = UDim2.fromOffset(15 + ((index - 1) * 88), 115),
        Size = UDim2.fromOffset(78, 32),
        BackgroundColor3 = THEMES[name].Category,
        BorderSizePixel = 0,
        Text = name,
        TextColor3 = THEMES[name].Accent,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        ZIndex = 24
    }, settingsPage)

    round(button, 8)
    stroke(button, THEMES[name].Accent, 0.35)
    animateButton(button)

    themeButtons[name] = button
end

--==================================================
-- LANGUAGE BUTTON IN SETTINGS
--==================================================

local languageButton = create("TextButton", {
    Name = "OpenLanguage",
    Position = UDim2.fromOffset(15, 160),
    Size = UDim2.new(1, -30, 0, 48),
    BackgroundColor3 = Color3.fromRGB(17, 21, 28),
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    ZIndex = 24
}, settingsPage)

round(languageButton, 10)
stroke(languageButton, Color3.fromRGB(45, 55, 70), 0.4)

local languageButtonTitle = label(
    languageButton, "LanguageTitle",
    translate("LanguageButton"),
    UDim2.fromOffset(13, 6),
    UDim2.new(1, -55, 0, 18), 11
)

languageButtonTitle.Font = Enum.Font.GothamBold

local languageButtonDescription = label(
    languageButton, "LanguageDescription",
    translate("LanguageDescription"),
    UDim2.fromOffset(13, 25),
    UDim2.new(1, -55, 0, 16), 9,
    Color3.fromRGB(130, 143, 161)
)

local languageArrow = label(
    languageButton, "Arrow", "›",
    UDim2.new(1, -36, 0, 5),
    UDim2.fromOffset(25, 35), 25,
    ACCENT
)

languageArrow.TextXAlignment = Enum.TextXAlignment.Center

animateButton(languageButton)

--==================================================
-- KEYBINDS
--==================================================

local keybindTitle = label(
    settingsPage, "KeybindTitle", translate("Keybinds"),
    UDim2.fromOffset(15, 225),
    UDim2.new(1, -100, 0, 24), 12
)

keybindTitle.Font = Enum.Font.GothamBold

local keybindDescription = label(
    settingsPage, "KeybindDescription",
    translate("KeybindDescription"),
    UDim2.fromOffset(15, 249),
    UDim2.new(1, -100, 0, 20), 9,
    Color3.fromRGB(130, 143, 161)
)

local keybindButton = create("TextButton", {
    Name = "OpenKeybinds",
    Position = UDim2.new(1, -58, 0, 229),
    Size = UDim2.fromOffset(38, 35),
    BackgroundColor3 = Color3.fromRGB(29, 39, 53),
    BorderSizePixel = 0,
    Text = "›",
    TextColor3 = ACCENT,
    TextSize = 25,
    Font = Enum.Font.GothamBold,
    ZIndex = 25
}, settingsPage)

round(keybindButton, 9)
stroke(keybindButton, ACCENT, 0.35)
animateButton(keybindButton)

--==================================================
-- KEYBINDS PANEL
--==================================================

keybindPanel = create("Frame", {
    Name = "KeybindPanel",
    Size = UDim2.fromOffset(280, 415),
    Position = UDim2.fromOffset(0, 0),
    BackgroundColor3 = Color3.fromRGB(9, 12, 17),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Visible = false,
    ClipsDescendants = true,
    ZIndex = 100
}, screenGui)

round(keybindPanel, 15)

local keybindStroke = stroke(keybindPanel, ACCENT, 0.3)

keybindScale = create("UIScale", {
    Scale = 0.93
}, keybindPanel)

local keyHeader = create("Frame", {
    Size = UDim2.new(1, 0, 0, 52),
    BackgroundColor3 = Color3.fromRGB(16, 23, 33),
    BorderSizePixel = 0,
    ZIndex = 101
}, keybindPanel)

round(keyHeader, 15)

create("Frame", {
    Position = UDim2.new(0, 0, 1, -14),
    Size = UDim2.new(1, 0, 0, 14),
    BackgroundColor3 = Color3.fromRGB(16, 23, 33),
    BorderSizePixel = 0,
    ZIndex = 101
}, keyHeader)

local keyHeaderTitle = label(
    keyHeader, "Heading", translate("KeybindHeading"),
    UDim2.fromOffset(15, 9),
    UDim2.new(1, -60, 0, 18), 10
)

keyHeaderTitle.Font = Enum.Font.GothamBold

local keyHeaderSubtitle = label(
    keyHeader, "Subtitle", translate("KeybindSubtitle"),
    UDim2.fromOffset(15, 27),
    UDim2.new(1, -60, 0, 15), 9,
    Color3.fromRGB(123, 140, 160)
)

local closeKeybinds = create("TextButton", {
    Position = UDim2.new(1, -38, 0, 11),
    Size = UDim2.fromOffset(26, 26),
    BackgroundColor3 = Color3.fromRGB(39, 24, 27),
    BorderSizePixel = 0,
    Text = "×",
    TextColor3 = Color3.fromRGB(235, 135, 140),
    TextSize = 19,
    ZIndex = 103
}, keyHeader)

round(closeKeybinds, 7)
animateButton(closeKeybinds)

local keybindList = create("Frame", {
    Position = UDim2.fromOffset(12, 67),
    Size = UDim2.new(1, -24, 1, -80),
    BackgroundTransparency = 1,
    ZIndex = 102
}, keybindPanel)

local emptyKeybind = label(
    keybindList, "Empty",
    translate("EmptyKeybind"),
    UDim2.new(0, 0, 0, 12),
    UDim2.new(1, 0, 0, 45), 11,
    Color3.fromRGB(130, 143, 161)
)

emptyKeybind.TextXAlignment = Enum.TextXAlignment.Center

local keybindVisuals = captureVisuals(keybindPanel)

local function closeKeybindPanel()
    if not keybindsOpen then
        keybindPanel.Visible = false
        return
    end

    keybindAnimationId += 1

    animatePanelClose(
        keybindPanel,
        keybindScale,
        keybindAnimationId,
        function()
            return keybindAnimationId
        end,
        function(value)
            keybindsOpen = value
        end
    )
end

local function openKeybindPanel()
    if minimized or destroyed then return end

    keybindAnimationId += 1
    keybindsOpen = true

    animatePanelOpen(
        keybindPanel,
        keybindScale,
        keybindVisuals
    )
end

closeKeybinds.MouseButton1Click:Connect(closeKeybindPanel)

keybindButton.MouseButton1Click:Connect(function()
    if keybindsOpen then
        closeKeybindPanel()
    else
        openKeybindPanel()
    end
end)

--==================================================
-- LANGUAGE SIDE PANEL
--==================================================

languagePanel = create("Frame", {
    Name = "LanguagePanel",
    Size = UDim2.fromOffset(280, 415),
    Position = UDim2.fromOffset(0, 0),
    BackgroundColor3 = Color3.fromRGB(9, 12, 17),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Visible = false,
    ClipsDescendants = true,
    ZIndex = 110
}, screenGui)

round(languagePanel, 15)

local languageStroke = stroke(languagePanel, ACCENT, 0.3)

languageScale = create("UIScale", {
    Scale = 0.93
}, languagePanel)

local languageHeader = create("Frame", {
    Size = UDim2.new(1, 0, 0, 58),
    BackgroundColor3 = Color3.fromRGB(16, 23, 33),
    BorderSizePixel = 0,
    ZIndex = 111
}, languagePanel)

round(languageHeader, 15)

create("Frame", {
    Position = UDim2.new(0, 0, 1, -14),
    Size = UDim2.new(1, 0, 0, 14),
    BackgroundColor3 = Color3.fromRGB(16, 23, 33),
    BorderSizePixel = 0,
    ZIndex = 111
}, languageHeader)

local languageHeaderTitle = label(
    languageHeader, "Heading", translate("LanguageTitle"),
    UDim2.fromOffset(15, 9),
    UDim2.new(1, -60, 0, 18), 11
)

languageHeaderTitle.Font = Enum.Font.GothamBold

local languageHeaderSubtitle = label(
    languageHeader, "Subtitle", translate("LanguageSubtitle"),
    UDim2.fromOffset(15, 29),
    UDim2.new(1, -60, 0, 16), 9,
    Color3.fromRGB(123, 140, 160)
)

local closeLanguage = create("TextButton", {
    Position = UDim2.new(1, -38, 0, 14),
    Size = UDim2.fromOffset(26, 26),
    BackgroundColor3 = Color3.fromRGB(39, 24, 27),
    BorderSizePixel = 0,
    Text = "×",
    TextColor3 = Color3.fromRGB(235, 135, 140),
    TextSize = 19,
    ZIndex = 113
}, languageHeader)

round(closeLanguage, 7)
animateButton(closeLanguage)

create("Frame", {
    Position = UDim2.fromOffset(12, 67),
    Size = UDim2.new(1, -24, 0, 1),
    BackgroundColor3 = Color3.fromRGB(43, 53, 67),
    BorderSizePixel = 0,
    ZIndex = 112
}, languagePanel)

local languageRows = {}

local function createLanguageRow(languageCode, y)
    local languageData = LANGUAGES[languageCode]

    local row = create("Frame", {
        Name = "Language_" .. languageCode,
        Position = UDim2.fromOffset(12, y),
        Size = UDim2.new(1, -24, 0, 67),
        BackgroundColor3 = Color3.fromRGB(17, 21, 28),
        BorderSizePixel = 0,
        ZIndex = 112
    }, languagePanel)

    round(row, 10)

    local flag = label(
        row, "Flag", languageData.Flag,
        UDim2.fromOffset(12, 0),
        UDim2.fromOffset(34, 67), 22
    )

    flag.TextXAlignment = Enum.TextXAlignment.Center
    flag.TextYAlignment = Enum.TextYAlignment.Center
    flag.ZIndex = 113

    local name = label(
        row, "LanguageName", languageData.Name,
        UDim2.fromOffset(55, 0),
        UDim2.new(1, -145, 1, 0), 11
    )

    name.Font = Enum.Font.GothamBold
    name.ZIndex = 113

    local selectButton = create("TextButton", {
        Name = "Select",
        Position = UDim2.new(1, -83, 0.5, -15),
        Size = UDim2.fromOffset(72, 30),
        BackgroundColor3 = Color3.fromRGB(29, 39, 53),
        BorderSizePixel = 0,
        Text = translate("Select"),
        TextColor3 = ACCENT,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        ZIndex = 114
    }, row)

    round(selectButton, 8)
    stroke(selectButton, ACCENT, 0.45)
    animateButton(selectButton)

    selectButton.MouseButton1Click:Connect(function()
        if destroyed then return end

        currentLanguage = languageCode

        -- Update all translated GUI elements.
        local function updateLanguage()
            homeButton.Text = translate("Home")
            settingsButton.Text = translate("Settings")

            if informationButton then
                informationButton.Text = translate("Information")
            end

            welcome.Text = translate("Welcome")
            welcomeSubtitle.Text = translate("WelcomeSubtitle")
            homeCardTitle.Text = translate("HomeCardTitle")
            homeCardDescription.Text = translate("HomeCardDescription")

            if unsupportedLabel then
                unsupportedLabel.Text = translate("Unsupported")
            end

            infoTitle.Text = translate("InformationTitle")
            infoSubtitle.Text = translate("InformationSubtitle")

            settingsTitle.Text = translate("SettingsTitle")
            settingsSubtitle.Text = translate("SettingsSubtitle")
            themeTitle.Text = translate("ThemeTitle")

            languageButtonTitle.Text = translate("LanguageButton")
            languageButtonDescription.Text = translate("LanguageDescription")

            keybindTitle.Text = translate("Keybinds")
            keybindDescription.Text = translate("KeybindDescription")

            detailHeaderTitle.Text = translate("DetailHeading")
            detailHeaderSubtitle.Text = translate("DetailSubtitle")

            keyHeaderTitle.Text = translate("KeybindHeading")
            keyHeaderSubtitle.Text = translate("KeybindSubtitle")
            emptyKeybind.Text = translate("EmptyKeybind")

            languageHeaderTitle.Text = translate("LanguageTitle")
            languageHeaderSubtitle.Text = translate("LanguageSubtitle")

            if not detailOpen then
                detailTitle.Text = translate("DetailPlaceholder")
                detailDescription.Text = translate("DetailPlaceholderDescription")
            else
                for _, data in ipairs(informationData) do
                    if detailTitle.Text == LANGUAGES.English[data.DetailTitleKey]
                        or detailTitle.Text == LANGUAGES.Turkish[data.DetailTitleKey]
                        or detailTitle.Text == LANGUAGES.Russian[data.DetailTitleKey] then

                        detailTitle.Text = translate(data.DetailTitleKey)
                        detailDescription.Text = translate(data.DetailKey)
                        break
                    end
                end
            end

            for _, rowData in ipairs(informationRows) do
                rowData.Title.Text = translate(rowData.Data.TitleKey)
                rowData.Description.Text = translate(rowData.Data.ShortKey)
            end

            for _, item in ipairs(languageRows) do
                if item.Code == currentLanguage then
                    item.Button.Text = translate("Selected")
                    item.Button.BackgroundColor3 = Color3.fromRGB(22, 65, 45)
                    item.Button.TextColor3 = Color3.fromRGB(75, 225, 135)
                else
                    item.Button.Text = translate("Select")
                    item.Button.BackgroundColor3 = Color3.fromRGB(29, 39, 53)
                    item.Button.TextColor3 = ACCENT
                end
            end

            if not gameSupported then
                statusText.Text = translate("UnsupportedStatus")
            end
        end

        updateLanguage()

        tween(row, 0.18, {
            BackgroundColor3 = Color3.fromRGB(25, 37, 49)
        })

        task.delay(0.15, function()
            if row.Parent then
                tween(row, 0.2, {
                    BackgroundColor3 = Color3.fromRGB(17, 21, 28)
                })
            end
        end)
    end)

    table.insert(languageRows, {
        Code = languageCode,
        Button = selectButton
    })

    row.MouseEnter:Connect(function()
        tween(row, 0.15, {
            BackgroundColor3 = Color3.fromRGB(24, 31, 42)
        })
    end)

    row.MouseLeave:Connect(function()
        tween(row, 0.15, {
            BackgroundColor3 = Color3.fromRGB(17, 21, 28)
        })
    end)
end

createLanguageRow("English", 82)
createLanguageRow("Turkish", 157)
createLanguageRow("Russian", 232)

local function updateLanguageSelection()
    for _, item in ipairs(languageRows) do
        if item.Code == currentLanguage then
            item.Button.Text = translate("Selected")
            item.Button.BackgroundColor3 = Color3.fromRGB(22, 65, 45)
            item.Button.TextColor3 = Color3.fromRGB(75, 225, 135)
        else
            item.Button.Text = translate("Select")
            item.Button.BackgroundColor3 = Color3.fromRGB(29, 39, 53)
            item.Button.TextColor3 = ACCENT
        end
    end
end

local languageVisuals = captureVisuals(languagePanel)

local function closeLanguagePanel()
    if not languageOpen then
        languagePanel.Visible = false
        return
    end

    languageAnimationId += 1

    animatePanelClose(
        languagePanel,
        languageScale,
        languageAnimationId,
        function()
            return languageAnimationId
        end,
        function(value)
            languageOpen = value
        end
    )
end

local function openLanguagePanel()
    if minimized or destroyed then return end

    closeInformationPanel()
    closeKeybindPanel()

    languageAnimationId += 1
    languageOpen = true

    updateLanguageSelection()

    animatePanelOpen(
        languagePanel,
        languageScale,
        languageVisuals
    )
end

closeLanguage.MouseButton1Click:Connect(closeLanguagePanel)

languageButton.MouseButton1Click:Connect(function()
    if languageOpen then
        closeLanguagePanel()
    else
        openLanguagePanel()
    end
end)

--==================================================
-- THEME APPLICATION
--==================================================

local function applyTheme(name)
    if not THEMES[name] then return end

    theme = name

    local colors = THEMES[name]
    ACCENT = colors.Accent

    main.BackgroundColor3 = colors.Dark
    content.BackgroundColor3 = colors.Panel
    homeCard.BackgroundColor3 = colors.Card

    informationPanel.BackgroundColor3 = colors.Dark
    keybindPanel.BackgroundColor3 = colors.Dark
    languagePanel.BackgroundColor3 = colors.Dark

    introTitle.TextColor3 = colors.Accent
    progressFill.BackgroundColor3 = colors.Accent

    detailStroke.Color = colors.Accent
    keybindStroke.Color = colors.Accent
    languageStroke.Color = colors.Accent

    for _, object in ipairs(screenGui:GetDescendants()) do
        if object.Name == "NeonIndicator" then
            object.BackgroundColor3 = colors.Accent
        elseif object:IsA("UIStroke") and object.Parent then
            if object.Parent.Name == "MoreInfo"
                or object.Parent.Name == "OpenKeybinds"
                or object.Parent.Name == "OpenLanguage" then
                object.Color = colors.Accent
            end
        end
    end

    for buttonName, button in pairs(categoryButtons) do
        local selected = buttonName == currentCategory

        button.BackgroundColor3 = selected
            and colors.Category
            or Color3.fromRGB(12, 14, 18)

        local indicator = button:FindFirstChild("NeonIndicator")

        if indicator then
            indicator.BackgroundColor3 = colors.Accent
        end
    end

    for themeName, button in pairs(themeButtons) do
        button.BackgroundColor3 = THEMES[themeName].Category
        button.TextColor3 = THEMES[themeName].Accent

        local outline = button:FindFirstChildOfClass("UIStroke")

        if outline then
            outline.Color = THEMES[themeName].Accent
        end

        tween(button, 0.2, {
            BackgroundTransparency = themeName == name and 0 or 0.25
        })
    end

    for _, object in ipairs(informationPage:GetChildren()) do
        if object:IsA("Frame") and object:FindFirstChild("MoreInfo") then
            local accent = object:FindFirstChildWhichIsA("Frame")

            if accent then
                accent.BackgroundColor3 = colors.Accent
            end

            local infoButton = object:FindFirstChild("MoreInfo")

            if infoButton then
                infoButton.TextColor3 = colors.Accent

                local outline = infoButton:FindFirstChildOfClass("UIStroke")

                if outline then
                    outline.Color = colors.Accent
                end
            end
        end
    end

    keybindButton.TextColor3 = colors.Accent
    languageArrow.TextColor3 = colors.Accent

    if islandDot then
        islandDot.BackgroundColor3 = colors.Accent
    end

    updateLanguageSelection()
end

for name, button in pairs(themeButtons) do
    button.MouseButton1Click:Connect(function()
        applyTheme(name)
    end)
end

--==================================================
-- PAGE SWITCHING
--==================================================

pages = {
    Home = homePage,
    Information = informationPage,
    Settings = settingsPage
}

local pageTransitionId = 0

local function selectCategory(name)
    print("[BZHUB DEBUG] Click:", name, "Switching:", switchingPage)
    if name == "Information" and not gameSupported then
        return
    end

    if switchingPage then
        return
    end

    if currentCategory == name then
        return
    end

    local newPage = pages[name]

    if not newPage then
        warn("[BZHUB] Page not found:", name)
        return
    end

    switchingPage = true
    pageTransitionId += 1

    local transitionId = pageTransitionId
    local oldPage = pages[currentCategory]

    currentCategory = name

    closeInformationPanel()
    closeKeybindPanel()
    closeLanguagePanel()

    for buttonName, button in pairs(categoryButtons) do
        local selected = buttonName == name
        local indicator = button:FindFirstChild("NeonIndicator")

        tween(button, 0.2, {
            BackgroundColor3 = selected
                and THEMES[theme].Category
                or Color3.fromRGB(12, 14, 18)
        })

        if indicator then
            indicator.Visible = selected
            indicator.BackgroundTransparency = selected and 0 or 1
        end
    end

    if oldPage then
        oldPage.Visible = false
        oldPage.Position = UDim2.fromOffset(0, 0)
    end

    newPage.Visible = true

    local direction = name == "Home" and -1 or 1

    newPage.Position = UDim2.fromOffset(direction * 30, 0)

    local success, moveAnimation = pcall(function()
        return tween(newPage, 0.32, {
            Position = UDim2.fromOffset(0, 0)
        }, Enum.EasingStyle.Quint)
    end)

    if not success or not moveAnimation then
        newPage.Position = UDim2.fromOffset(0, 0)
        switchingPage = false
        warn("[BZHUB] Page animation failed:", moveAnimation)
        return
    end

    moveAnimation.Completed:Connect(function()
        print("[BZHUB DEBUG] Animation completed:", name)
        if transitionId ~= pageTransitionId then
            return
        end

        newPage.Position = UDim2.fromOffset(0, 0)
        switchingPage = false
    end)

    task.delay(0.6, function()
        print("[BZHUB DEBUG] Unlock:", name)
        if transitionId == pageTransitionId then
            newPage.Position = UDim2.fromOffset(0, 0)
            switchingPage = false
        end
    end)
end
-- DEFAULT CATEGORY CONNECTIONS

homeButton.MouseButton1Click:Connect(function()
    selectCategory("Home")
end)

if informationButton then
    informationButton.MouseButton1Click:Connect(function()
        selectCategory("Information")
    end)
end

settingsButton.MouseButton1Click:Connect(function()
    selectCategory("Settings")
end)
currentCategory = "Home"
pages.Home.Visible = true
-- GAME MODULE SYSTEM
local gameModuleLoadFinished = not gameSupported
local BZHUB_API = {}

local gameCategoryCount = 0

function BZHUB_API.SetStatus(message, isError)
    if not statusText or not statusText.Parent then
        return
    end

    statusText.Text = tostring(message or "")
    statusText.TextColor3 = isError
        and Color3.fromRGB(235, 75, 75)
        or Color3.fromRGB(70, 225, 125)

    if statusDot and statusDot.Parent then
        statusDot.BackgroundColor3 = isError
            and Color3.fromRGB(225, 55, 55)
            or Color3.fromRGB(55, 220, 115)
    end
end

function BZHUB_API.AddCategory(name, text, callback)
    if not gameSupported then return end
    if pages[name] then return end

    assert(type(createCategory) == "function", "createCategory is nil")
    assert(type(create) == "function", "create is nil")

    gameCategoryCount += 1

    local button = createCategory(
        name,
        text,
        90 + ((gameCategoryCount - 1) * 45),
        false
    )


    local page = create("Frame", {
        Name = name .. "Page",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 22
    }, content)
    if name == "Automation" then
        button.Text = "    " .. string.upper(text)
    end
    if name == "Upgrades" then
        button.Text = "    " .. string.upper(text)
    end
    if name == "Dashboard" then
        button.Text = "    " .. string.upper(text)
    end
    if name == "EVENT" then
        button.Text = "    " .. string.upper(text)
    end
    pages[name] = page

    button.MouseButton1Click:Connect(function()
        selectCategory(name)
    end)

    if callback then
        local success, err = pcall(callback, page)
        if not success then
            warn("[BZHUB] Category error:", err)
        end
    end
end

--==================================================
-- EXECUTOR-COMPATIBLE GAME MODULE LOADER
--==================================================

local GAME_MODULE_URL =
    "https://raw.githubusercontent.com/blazystick/BZHUB/refs/heads/main/SupportedGames/120219252362013.lua"
    .. tostring(game.PlaceId)
    .. ".lua"

local function getResponseBody(response)
    if type(response) == "string" then
        return response
    end

    if type(response) == "table" then
        if type(response.Body) == "string" then
            return response.Body
        end

        if type(response.body) == "string" then
            return response.body
        end

        if type(response.ResponseBody) == "string" then
            return response.ResponseBody
        end
    end

    return nil
end

local function tryHttpRequest(requestFunction, requestName)
    if type(requestFunction) ~= "function" then
        return nil, requestName .. " is unavailable"
    end

    local success, response = pcall(requestFunction)

    if not success then
        return nil, requestName .. " failed: " .. tostring(response)
    end

    local body = getResponseBody(response)

    if type(body) ~= "string" or body == "" then
        return nil, requestName .. " returned an empty or invalid response"
    end

    return body
end

local function downloadGameModule(url)
    local errors = {}

    -- Roblox-style HttpGet is retained first for Solara compatibility.
    local body, err = tryHttpRequest(function()
        return game:HttpGet(url)
    end, "game:HttpGet")

    if body then
        return body
    end
    table.insert(errors, err)

    -- Executor request APIs are optional and are checked only when present.
    if type(request) == "function" then
        body, err = tryHttpRequest(function()
            return request({
                Url = url,
                Method = "GET"
            })
        end, "request")

        if body then
            return body
        end
        table.insert(errors, err)
    end

    if type(http_request) == "function" then
        body, err = tryHttpRequest(function()
            return http_request({
                Url = url,
                Method = "GET"
            })
        end, "http_request")

        if body then
            return body
        end
        table.insert(errors, err)
    end

    if type(syn) == "table" and type(syn.request) == "function" then
        body, err = tryHttpRequest(function()
            return syn.request({
                Url = url,
                Method = "GET"
            })
        end, "syn.request")

        if body then
            return body
        end
        table.insert(errors, err)
    end

    return nil, table.concat(errors, " | ")
end

local function setModuleLoadError(message)
    local readableError = tostring(message)

    warn("[BZHUB] Game module load failed:", readableError)

    if statusText and statusText.Parent then
        statusText.Text = "MODULE LOAD ERROR"
        statusText.TextColor3 = Color3.fromRGB(235, 75, 75)
    end

    if statusDot and statusDot.Parent then
        statusDot.BackgroundColor3 = Color3.fromRGB(225, 55, 55)
    end
end

if gameSupported then
    task.spawn(function()
        local success, err = pcall(function()
            local response, downloadError = downloadGameModule(GAME_MODULE_URL)

            if type(response) ~= "string" then
                error("Could not download game module. " .. tostring(downloadError))
            end

            if response:find("^404:") then
                error("GitHub returned 404. Check the module URL and repository file.")
            end

            if #response < 20 then
                error("Downloaded module is unexpectedly short.")
            end

            print("[BZHUB] Game module downloaded:", #response, "bytes")

            if type(loadstring) ~= "function" then
                error("This executor does not expose loadstring.")
            end

            local compiled, compileError = loadstring(response)

            if type(compiled) ~= "function" then
                error("Module compile failed: " .. tostring(compileError))
            end

            local moduleScript = compiled()

            if type(moduleScript) ~= "table" then
                error("Downloaded module did not return a table.")
            end

            if type(moduleScript.Register) ~= "function" then
                error("Downloaded module is missing Register(api).")
            end

            local registerSuccess, registerError = pcall(
                moduleScript.Register,
                BZHUB_API
            )

            if not registerSuccess then
                error("Module Register failed: " .. tostring(registerError))
            end

            print("[BZHUB] Game module registered successfully.")
        end)

        if not success then
            setModuleLoadError(err)
        end

        gameModuleLoadFinished = true
    end)
end

applyTheme("Blue")
local function createResizeHandle(name, position, size, direction)
    local handle = create("TextButton", {
        Name = name,
        Position = position,
        Size = size,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Active = true,
        ZIndex = 40
    }, main)

    handle.InputBegan:Connect(function(input)
        if minimized or animating then return end

        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            resizing = true
            resizeDirection = direction
            resizeStart = input.Position
            resizeStartSize = main.AbsoluteSize
            resizeStartPosition = main.Position
        end
    end)

    handle.MouseEnter:Connect(function()
        tween(handle, 0.15, {
            BackgroundTransparency = 0.7
        })
    end)

    handle.MouseLeave:Connect(function()
        tween(handle, 0.15, {
            BackgroundTransparency = 1
        })
    end)
end

createResizeHandle("NW", UDim2.new(0, 0, 0, 0), UDim2.fromOffset(14, 14), "NW")
createResizeHandle("NE", UDim2.new(1, -14, 0, 0), UDim2.fromOffset(14, 14), "NE")
createResizeHandle("SW", UDim2.new(0, 0, 1, -14), UDim2.fromOffset(14, 14), "SW")
createResizeHandle("SE", UDim2.new(1, -14, 1, -14), UDim2.fromOffset(14, 14), "SE")
createResizeHandle("N", UDim2.new(0, 14, 0, 0), UDim2.new(1, -28, 0, 6), "N")
createResizeHandle("S", UDim2.new(0, 14, 1, -6), UDim2.new(1, -28, 0, 6), "S")
createResizeHandle("W", UDim2.new(0, 0, 0, 14), UDim2.new(0, 6, 1, -28), "W")
createResizeHandle("E", UDim2.new(1, -6, 0, 14), UDim2.new(0, 6, 1, -28), "E")

--==================================================
-- DRAG HANDLE
--==================================================

local dragHandle = create("Frame", {
    Name = "DragHandle",
    Size = UDim2.new(1, -110, 0, 48),
    BackgroundTransparency = 1,
    Active = true,
    ZIndex = 20
}, main)

dragHandle.InputBegan:Connect(function(input)
    if minimized or animating then return end

    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        startPosition = main.Position
        dragInputType = input.UserInputType
        savedPosition = main.Position
    end
end)

--==================================================
-- INPUT HANDLING
--==================================================

local function updateResize(input)
    local delta = input.Position - resizeStart
    local dx, dy = delta.X, delta.Y

    local oldWidth = resizeStartSize.X
    local oldHeight = resizeStartSize.Y

    local newWidth = oldWidth
    local newHeight = oldHeight

    local shiftX = 0
    local shiftY = 0

    if resizeDirection:find("E") then
        newWidth = math.clamp(oldWidth + dx, MIN_SIZE.X, MAX_SIZE.X)
        shiftX = (newWidth - oldWidth) / 2
    elseif resizeDirection:find("W") then
        newWidth = math.clamp(oldWidth - dx, MIN_SIZE.X, MAX_SIZE.X)
        shiftX = (oldWidth - newWidth) / 2
    end

    if resizeDirection:find("S") then
        newHeight = math.clamp(oldHeight + dy, MIN_SIZE.Y, MAX_SIZE.Y)
        shiftY = (newHeight - oldHeight) / 2
    elseif resizeDirection:find("N") then
        newHeight = math.clamp(oldHeight - dy, MIN_SIZE.Y, MAX_SIZE.Y)
        shiftY = (oldHeight - newHeight) / 2
    end

    main.Size = UDim2.fromOffset(newWidth, newHeight)

    main.Position = UDim2.new(
        resizeStartPosition.X.Scale,
        resizeStartPosition.X.Offset + shiftX,
        resizeStartPosition.Y.Scale,
        resizeStartPosition.Y.Offset + shiftY
    )

    savedSize = main.Size
    savedPosition = main.Position
end

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    if resizing and not minimized and not animating then
        updateResize(input)
        return
    end

    if dragging and not minimized and not animating then
        local valid =
            input.UserInputType == Enum.UserInputType.MouseMovement
            or (
                dragInputType == Enum.UserInputType.Touch
                and input.UserInputType == Enum.UserInputType.Touch
            )

        if valid then
            local delta = input.Position - dragStart

            main.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )

            savedPosition = main.Position
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        resizing = false
        resizeDirection = nil

        if dragging and input.UserInputType == dragInputType then
            dragging = false
        end
    end
end)

--==================================================
-- DYNAMIC ISLAND
--==================================================

local island = create("Frame", {
    Name = "DynamicIsland",
    Size = UDim2.fromOffset(0, 0),
    Position = ISLAND_POSITION,
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = BACKGROUND,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 60
}, screenGui)

round(island, 21)
stroke(island, Color3.fromRGB(35, 35, 35), 1)

local islandButton = create("TextButton", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Text = "",
    ZIndex = 61
}, island)

islandDot = create("Frame", {
    Position = UDim2.new(0, 18, 0.5, -3.5),
    Size = UDim2.fromOffset(7, 7),
    BackgroundColor3 = Color3.fromRGB(235, 235, 235),
    BorderSizePixel = 0,
    ZIndex = 62
}, island)

round(islandDot, 10)
islandDot.BackgroundColor3 = THEMES[theme].Accent

local islandText = label(
    island, "IslandText", "BZHUB",
    UDim2.fromOffset(32, 0),
    UDim2.new(1, -45, 1, 0), 12,
    Color3.fromRGB(190, 190, 190)
)

islandText.TextTransparency = 1
islandText.ZIndex = 62

--==================================================
-- VISUAL STATE STORAGE
--==================================================

local function captureMainVisuals()
    local saved = {}

    for _, object in ipairs(main:GetDescendants()) do
        local data = {}

        if object:IsA("GuiObject") then
            data.BackgroundTransparency = object.BackgroundTransparency
        end

        if object:IsA("TextLabel") or object:IsA("TextButton") then
            data.TextTransparency = object.TextTransparency
        end

        if object:IsA("ImageLabel") or object:IsA("ImageButton") then
            data.ImageTransparency = object.ImageTransparency
        end

        if object:IsA("UIStroke") then
            data.Transparency = object.Transparency
        end

        if next(data) then
            saved[object] = data
        end
    end

    return saved
end

local mainVisuals = captureMainVisuals()

local function fadeVisuals(savedVisuals, duration, hide)
    for object, data in pairs(savedVisuals) do
        if object.Parent then
            local properties = {}

            if data.BackgroundTransparency ~= nil then
                properties.BackgroundTransparency = hide
                    and 1 or data.BackgroundTransparency
            end

            if data.TextTransparency ~= nil then
                properties.TextTransparency = hide
                    and 1 or data.TextTransparency
            end

            if data.ImageTransparency ~= nil then
                properties.ImageTransparency = hide
                    and 1 or data.ImageTransparency
            end

            if data.Transparency ~= nil then
                properties.Transparency = hide
                    and 1 or data.Transparency
            end

            if next(properties) then
                tween(object, duration, properties)
            end
        end
    end
end

--==================================================
-- ISLAND PULSE
--==================================================

local function islandPulse()
    if not minimized or destroyed then return end

    local pulse = tween(island, 0.22, {
        Size = UDim2.fromOffset(140, 49)
    }, Enum.EasingStyle.Sine)

    pulse.Completed:Once(function()
        if minimized and not destroyed then
            tween(island, 0.22, {
                Size = ISLAND_SIZE
            }, Enum.EasingStyle.Sine)
        end
    end)
end

--==================================================
-- MINIMIZE
--==================================================

local function minimizeGUI()
    if minimized or animating or destroyed then return end

    animating = true
    minimized = true

    dragging = false
    resizing = false

    savedPosition = main.Position
    savedSize = main.Size

    minimize.Visible = false
    destroy.Visible = false

    detailAnimationId += 1
    keybindAnimationId += 1
    languageAnimationId += 1

    detailOpen = false
    keybindsOpen = false
    languageOpen = false

    informationPanel.Visible = false
    keybindPanel.Visible = false
    languagePanel.Visible = false

    island.Visible = true
    island.Size = UDim2.fromOffset(0, 0)
    island.BackgroundTransparency = 1
    islandText.TextTransparency = 1

    fadeVisuals(mainVisuals, 0.38, true)

    for _, data in ipairs(shadows) do
        tween(data.Frame, 0.38, {
            BackgroundTransparency = 1
        })
    end

    tween(main, 0.55, {
        Size = UDim2.fromOffset(125, 42),
        Position = ISLAND_POSITION,
        BackgroundTransparency = 1
    })

    task.delay(0.12, function()
        if not minimized or destroyed then return end

        tween(island, 0.4, {
            Size = ISLAND_SIZE,
            BackgroundTransparency = 0
        }, Enum.EasingStyle.Back)

        task.delay(0.2, function()
            if minimized and not destroyed then
                tween(islandText, 0.25, {
                    TextTransparency = 0
                })
            end
        end)
    end)

    task.wait(0.58)

    if minimized and not destroyed then
        main.Visible = false
    end

    animating = false
end

--==================================================
-- RESTORE
--==================================================

local function restoreGUI(reset)
    if not minimized or animating or destroyed then return end

    animating = true
    minimized = false

    dragging = false
    resizing = false

    if reset then
        savedSize = NORMAL_SIZE
        savedPosition = NORMAL_POSITION
    end

    tween(islandText, 0.12, {
        TextTransparency = 1
    })

    tween(island, 0.28, {
        Size = UDim2.fromOffset(0, 0),
        BackgroundTransparency = 1
    })

    main.Visible = true
    main.Size = UDim2.fromOffset(125, 42)
    main.Position = ISLAND_POSITION
    main.BackgroundTransparency = 1

    for object, data in pairs(mainVisuals) do
        if object.Parent then
            if data.BackgroundTransparency ~= nil then
                object.BackgroundTransparency = 1
            end

            if data.TextTransparency ~= nil then
                object.TextTransparency = 1
            end

            if data.ImageTransparency ~= nil then
                object.ImageTransparency = 1
            end

            if data.Transparency ~= nil then
                object.Transparency = 1
            end
        end
    end

    local mainAnimation = tween(main, 0.65, {
        Size = savedSize,
        Position = savedPosition,
        BackgroundTransparency = 0
    }, Enum.EasingStyle.Quint)

    fadeVisuals(mainVisuals, 0.5, false)

    for _, data in ipairs(shadows) do
        tween(data.Frame, 0.6, {
            BackgroundTransparency = data.Transparency
        })
    end

    mainAnimation.Completed:Wait()

    if destroyed then return end

    island.Visible = false
    island.Size = UDim2.fromOffset(0, 0)

    minimize.Visible = true
    destroy.Visible = true

    informationPanel.Visible = false
    keybindPanel.Visible = false
    languagePanel.Visible = false

    detailOpen = false
    keybindsOpen = false
    languageOpen = false

    animating = false
end

--==================================================
-- DYNAMIC ISLAND CLICK SYSTEM
--==================================================

islandButton.MouseButton1Click:Connect(function()
    if not minimized or animating or destroyed then return end

    islandClickCount += 1
    islandClickSequence += 1

    local sequence = islandClickSequence

    if islandClickCount == 1 then
        islandPulse()
    end

    task.delay(0.24, function()
        if sequence ~= islandClickSequence then return end

        local clicks = islandClickCount
        islandClickCount = 0

        if not minimized or animating or destroyed then return end

        if clicks == 2 then
            restoreGUI(false)
        elseif clicks >= 3 then
            restoreGUI(true)
        end
    end)
end)

--==================================================
-- DESTROY ANIMATION
--==================================================

local function destroyGUI()
    if destroyed or animating then return end

    destroyed = true
    animating = true

    dragging = false
    resizing = false

    minimize.Visible = false
    destroy.Visible = false

    detailOpen = false
    keybindsOpen = false
    languageOpen = false

    local fadeInfo = TweenInfo.new(
        0.45,
        Enum.EasingStyle.Quint,
        Enum.EasingDirection.In
    )

    local function addFade(object, properties)
        local animation = TweenService:Create(
            object,
            fadeInfo,
            properties
        )

        animation:Play()
    end

    if main.Visible then
        addFade(main, {
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(500, 300)
        })
    end

    if island.Visible then
        addFade(island, {
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(0, 0)
        })
    end

    for _, object in ipairs(main:GetDescendants()) do
        if object:IsA("TextLabel") or object:IsA("TextButton") then
            addFade(object, {
                TextTransparency = 1,
                BackgroundTransparency = 1
            })
        elseif object:IsA("GuiObject") then
            addFade(object, {
                BackgroundTransparency = 1
            })
        elseif object:IsA("UIStroke") then
            addFade(object, {
                Transparency = 1
            })
        end
    end

    for _, panel in ipairs({
        informationPanel,
        keybindPanel,
        languagePanel
    }) do
        if panel.Visible then
            addFade(panel, {
                BackgroundTransparency = 1
            })
        end
    end

    for _, data in ipairs(shadows) do
        addFade(data.Frame, {
            BackgroundTransparency = 1
        })
    end

    task.wait(0.5)

    RunService:UnbindFromRenderStep("BZHUB_Render")

    screenGui:Destroy()
end

--==================================================
-- BUTTON EVENTS
--==================================================

minimize.MouseButton1Click:Connect(minimizeGUI)
destroy.MouseButton1Click:Connect(destroyGUI)

local function buttonHover(button, normal, hover)
    button.MouseEnter:Connect(function()
        tween(button, 0.15, {
            BackgroundColor3 = hover
        })
    end)

    button.MouseLeave:Connect(function()
        tween(button, 0.15, {
            BackgroundColor3 = normal
        })
    end)
end

buttonHover(
    minimize,
    Color3.fromRGB(25, 25, 25),
    Color3.fromRGB(48, 48, 48)
)

buttonHover(
    destroy,
    Color3.fromRGB(35, 13, 13),
    Color3.fromRGB(110, 25, 25)
)

--==================================================
-- MOUSE GLOW
--==================================================

local glow = create("Frame", {
    Name = "MouseGlow",
    Size = UDim2.fromOffset(40, 40),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    ZIndex = 50
}, screenGui)

local glowLayers = {}

local glowSettings = {
    {38, 0.97},
    {30, 0.93},
    {23, 0.84},
    {16, 0.62},
    {10, 0.25},
    {5, 0.02}
}

for index, setting in ipairs(glowSettings) do
    local circle = create("Frame", {
        Name = "Circle_" .. index,
        Size = UDim2.fromOffset(setting[1], setting[1]),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = index
    }, glow)

    round(circle, 100)

    table.insert(glowLayers, {
        Frame = circle,
        Transparency = setting[2]
    })
end

local hovering = false
local glowTweens = {}

local function setGlow(state)
    if hovering == state then return end

    hovering = state

    for _, animation in ipairs(glowTweens) do
        animation:Cancel()
    end

    table.clear(glowTweens)

    for _, data in ipairs(glowLayers) do
        local animation = TweenService:Create(
            data.Frame,
            TweenInfo.new(0.35, Enum.EasingStyle.Sine),
            {
                BackgroundTransparency = state
                    and data.Transparency or 1
            }
        )

        table.insert(glowTweens, animation)
        animation:Play()
    end
end

--==================================================
-- RENDER LOOP
--==================================================

RunService:BindToRenderStep(
    "BZHUB_Render",
    Enum.RenderPriority.Last.Value,
    function()
        if destroyed or not screenGui.Parent then
            return
        end

        -- SHADOW TRACKING
        for _, data in ipairs(shadows) do
            if main.Visible then
                data.Frame.Position = main.Position

                data.Frame.Size = UDim2.fromOffset(
                    main.AbsoluteSize.X + data.Offset,
                    main.AbsoluteSize.Y + data.Offset
                )
            end
        end

        -- SIDE PANEL POSITIONING
        local camera = workspace.CurrentCamera

        if camera and main.Visible and not minimized then
            local viewport = camera.ViewportSize
            local position = main.AbsolutePosition
            local size = main.AbsoluteSize

            local function positionSidePanel(panel)
                local width = panel.AbsoluteSize.X
                local height = panel.AbsoluteSize.Y

                local x = position.X + size.X + 12

                if x + width > viewport.X - 8 then
                    x = position.X - width - 12
                end

                x = math.clamp(
                    x,
                    8,
                    math.max(8, viewport.X - width - 8)
                )

                local y = math.clamp(
                    position.Y,
                    8,
                    math.max(8, viewport.Y - height - 8)
                )

                panel.Position = UDim2.fromOffset(x, y)
            end

            if detailOpen and informationPanel.Visible then
                positionSidePanel(informationPanel)
            end

            if keybindsOpen and keybindPanel.Visible then
                positionSidePanel(keybindPanel)
            end

            if languageOpen and languagePanel.Visible then
                positionSidePanel(languagePanel)
            end
        end

        -- EXACT MOUSE POSITION
        if main.Visible and not minimized then
            local mouse = UserInputService:GetMouseLocation()

            glow.Position = UDim2.fromOffset(mouse.X, mouse.Y)

            local position = main.AbsolutePosition
            local size = main.AbsoluteSize

            local inside =
                mouse.X >= position.X and
                mouse.X <= position.X + size.X and
                mouse.Y >= position.Y and
                mouse.Y <= position.Y + size.Y

            setGlow(inside)
        else
            setGlow(false)
        end
    end
)

--==================================================
-- STARTUP ANIMATION
--==================================================

task.spawn(function()
    tween(intro, 0.55, {
        BackgroundTransparency = 0.18
    })

    task.wait(0.35)

    tween(introPanel, 0.55, {
        BackgroundTransparency = 0
    })

    tween(introScale, 0.65, {
        Scale = 1
    }, Enum.EasingStyle.Back)

    tween(introStroke, 0.55, {
        Transparency = 0.55
    })

    task.wait(0.2)

    tween(introTitle, 0.45, {
        TextTransparency = 0
    })

    task.wait(0.12)

    tween(introCredit, 0.4, {
        TextTransparency = 0
    })

    tween(loadingLabel, 0.4, {
        TextTransparency = 0
    })

    tween(progressBack, 0.4, {
        BackgroundTransparency = 0
    })

    local progress = Instance.new("NumberValue")
    progress.Value = 0

    local connection = progress.Changed:Connect(function(value)
        progressFill.Size = UDim2.new(value / 100, 0, 1, 0)

        loadingLabel.Text =
            translate("Loading") .. math.floor(value) .. "%"
    end)

    -- Loading sırasında oyun Lua'sını bekle.
    local progressTween = TweenService:Create(
        progress,
        TweenInfo.new(1.75, Enum.EasingStyle.Quad),
        {Value = 95}
    )
    
    progressTween:Play()
    progressTween.Completed:Wait()
    
    -- Modül indirilip GUI'ye eklenene kadar %95'te bekle.
    while not gameModuleLoadFinished do
        task.wait(0.05)
    end
    
    -- Modül tamamlandı, yüklemeyi bitir.
    local finishTween = TweenService:Create(
        progress,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad),
        {Value = 100}
    )
    
    finishTween:Play()
    finishTween.Completed:Wait()

    connection:Disconnect()
    progress:Destroy()

    loadingLabel.Text = translate("Loading") .. "100%"

    task.wait(0.3)

    tween(intro, 0.45, {
        BackgroundTransparency = 1
    }, Enum.EasingStyle.Quint)

    tween(introPanel, 0.45, {
        BackgroundTransparency = 1
    }, Enum.EasingStyle.Quint)

    tween(introScale, 0.45, {
        Scale = 0.82
    }, Enum.EasingStyle.Quint)

    tween(introStroke, 0.45, {
        Transparency = 1
    })

    tween(introTitle, 0.45, {
        TextTransparency = 1
    })

    tween(introCredit, 0.45, {
        TextTransparency = 1
    })

    tween(loadingLabel, 0.45, {
        TextTransparency = 1
    })

    tween(progressBack, 0.45, {
        BackgroundTransparency = 1
    })

    tween(progressFill, 0.45, {
        BackgroundTransparency = 1
    })

    task.wait(0.48)

    intro:Destroy()

    if destroyed then return end

    main.Visible = true
    main.Size = UDim2.fromOffset(580, 350)
    main.BackgroundTransparency = 1

    local mainScale = create("UIScale", {
        Scale = 0.9
    }, main)

    for _, data in ipairs(shadows) do
        data.Frame.Visible = true
        data.Frame.BackgroundTransparency = 1
    end

    tween(main, 0.65, {
        Size = NORMAL_SIZE,
        BackgroundTransparency = 0
    })

    tween(mainScale, 0.65, {
        Scale = 1
    }, Enum.EasingStyle.Back)

    for _, data in ipairs(shadows) do
        tween(data.Frame, 0.65, {
            BackgroundTransparency = data.Transparency
        })
    end

    task.wait(0.7)

    if mainScale.Parent then
        mainScale:Destroy()
    end
end)
