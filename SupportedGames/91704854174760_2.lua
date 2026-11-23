local GameModule = {}

function GameModule.Register(api)
    api.AddCategory("Automation", "AUTOMATION", function(page)
        local TweenService = game:GetService("TweenService")

        local CARD = Color3.fromRGB(17, 23, 33)
        local PANEL = Color3.fromRGB(14, 19, 28)
        local TEXT = Color3.fromRGB(235, 242, 250)
        local MUTED = Color3.fromRGB(145, 160, 180)
        local WHITE = Color3.fromRGB(255, 255, 255)

        local completeWordsEnabled = false

        -- English single-word dictionary (A-Z only).
        local WORDS = {
            "apple", "animal", "answer", "amazing", "always", "about", "above", "action", "active", "address", "adventure", "after", "again", "against", "age", "agent", "agree", "air", "airport", "album", "alive", "allow", "almost", "alone", "along", "already", "also", "although", "among", "amount", "ancient", "angle", "angry", "another", "anyone", "anything", "appear", "area", "argue", "arm", "around", "arrive", "artist", "ask", "attack", "attempt", "attention", "author", "avoid", "awake", "baby", "back", "bad", "balance", "ball", "banana", "bank", "base", "basic", "basket", "beautiful", "because", "become", "before", "begin", "behind", "believe", "best", "better", "between", "beyond", "bird", "black", "blue", "board", "body", "book", "both", "brain", "brave", "bread", "break", "bright", "bring", "brother", "build", "building", "business", "button", "camera", "camp", "capital", "captain", "care", "career", "careful", "carry", "case", "castle", "cat", "catch", "cause", "center", "certain", "chance", "change", "character", "charge", "check", "cheese", "child", "choice", "choose", "circle", "city", "class", "clean", "clear", "climb", "clock", "close", "cloud", "coffee", "cold", "collect", "color", "come", "comfort", "common", "company", "complete", "computer", "condition", "connect", "consider", "continue", "control", "cook", "cool", "copy", "corner", "correct", "cost", "country", "course", "cover", "create", "culture", "cup", "curious", "current", "cut", "dance", "danger", "dark", "data", "date", "daughter", "day", "dead", "deal", "death", "decide", "deep", "degree", "depend", "describe", "design", "desk", "detail", "develop", "different", "difficult", "dinner", "direction", "discover", "discuss", "distance", "doctor", "dog", "door", "down", "draw", "dream", "dress", "drink", "drive", "drop", "dry", "during", "each", "early", "earth", "east", "easy", "eat", "education", "effect", "effort", "egg", "eight", "either", "electric", "elephant", "else", "email", "empty", "end", "energy", "engine", "enjoy", "enough", "enter", "environment", "equal", "escape", "especially", "even", "evening", "event", "ever", "every", "everyone", "everything", "example", "excellent", "except", "exercise", "exist", "expect", "experience", "explain", "eye", "face", "fact", "factory", "fail", "fair", "fall", "family", "famous", "far", "farm", "fast", "father", "fear", "feel", "few", "field", "fight", "figure", "fill", "film", "final", "find", "fine", "finger", "finish", "fire", "first", "fish", "fit", "five", "floor", "flower", "fly", "focus", "follow", "food", "foot", "forest", "forget", "form", "forward", "four", "free", "friend", "front", "fruit", "full", "fun", "future", "game", "garden", "general", "get", "girl", "give", "glass", "go", "goal", "gold", "good", "government", "great", "green", "ground", "group", "grow", "guess", "guide", "gun", "hair", "half", "hand", "happen", "happy", "hard", "hat", "have", "head", "health", "hear", "heart", "heavy", "help", "here", "high", "history", "hit", "hold", "holiday", "home", "hope", "horse", "hospital", "hot", "hotel", "hour", "house", "human", "hundred", "hungry", "hunt", "hurry", "ice", "idea", "identify", "if", "image", "imagine", "important", "improve", "include", "income", "increase", "indeed", "inside", "instead", "interest", "interesting", "international", "internet", "interview", "into", "introduce", "invent", "invite", "island", "issue", "item", "jacket", "job", "join", "journey", "joy", "judge", "jump", "just", "keep", "key", "keyboard", "kick", "kid", "kill", "kind", "king", "kitchen", "knee", "know", "knowledge", "label", "lake", "land", "language", "large", "last", "late", "laugh", "law", "lead", "learn", "leave", "left", "leg", "lesson", "letter", "level", "library", "life", "light", "like", "line", "lion", "list", "listen", "little", "live", "local", "long", "look", "lose", "love", "low", "machine", "magic", "main", "major", "make", "man", "manage", "many", "map", "market", "marry", "match", "material", "matter", "maybe", "meal", "mean", "measure", "meat", "medicine", "meet", "member", "memory", "message", "middle", "might", "mile", "milk", "mind", "minute", "miss", "mistake", "model", "modern", "moment", "money", "month", "moon", "more", "morning", "mother", "mountain", "mouse", "mouth", "move", "movie", "much", "music", "must", "name", "nation", "nature", "near", "necessary", "neck", "need", "neighbor", "never", "new", "news", "next", "nice", "night", "nine", "no", "noise", "none", "north", "nose", "not", "note", "nothing", "notice", "number", "object", "ocean", "of", "off", "offer", "office", "often", "oil", "old", "once", "one", "only", "open", "operation", "opinion", "opportunity", "orange", "order", "other", "our", "out", "outside", "over", "own", "page", "pain", "paint", "pair", "paper", "parent", "park", "part", "party", "pass", "past", "pay", "peace", "people", "perfect", "perhaps", "person", "phone", "photo", "pick", "picture", "piece", "place", "plan", "planet", "plant", "play", "player", "please", "point", "police", "popular", "position", "possible", "power", "practice", "prepare", "present", "pretty", "price", "problem", "process", "produce", "product", "program", "project", "promise", "protect", "prove", "public", "pull", "purple", "purpose", "push", "put", "quality", "question", "quick", "quiet", "quite", "race", "radio", "rain", "raise", "range", "reach", "read", "ready", "real", "reason", "receive", "record", "red", "remember", "remove", "repeat", "reply", "report", "rest", "result", "return", "rich", "ride", "right", "river", "road", "rock", "rocket", "room", "round", "rule", "run", "safe", "same", "save", "say", "school", "science", "sea", "search", "season", "seat", "second", "secret", "see", "seem", "sell", "send", "sense", "sentence", "serve", "service", "set", "seven", "several", "shape", "share", "she", "ship", "shirt", "shoe", "shoot", "short", "should", "show", "side", "sign", "simple", "since", "sing", "sister", "sit", "six", "size", "skill", "sky", "sleep", "slow", "small", "smile", "snow", "so", "social", "society", "soft", "some", "someone", "something", "song", "soon", "sorry", "sound", "south", "space", "speak", "special", "speed", "spell", "spend", "sport", "spring", "stand", "star", "start", "state", "stay", "step", "still", "stone", "stop", "story", "street", "strong", "student", "study", "subject", "success", "such", "sudden", "sugar", "summer", "sun", "support", "sure", "surprise", "sweet", "system", "table", "take", "talk", "tall", "task", "teach", "teacher", "team", "technology", "tell", "ten", "test", "than", "thank", "that", "the", "their", "them", "then", "there", "these", "they", "thing", "think", "third", "this", "those", "though", "thought", "three", "through", "throw", "time", "today", "together", "tomorrow", "tonight", "too", "tool", "top", "total", "touch", "town", "trade", "train", "travel", "tree", "trip", "trouble", "true", "try", "turn", "two", "type", "under", "understand", "unit", "universe", "university", "until", "up", "use", "useful", "usual", "value", "various", "very", "video", "view", "village", "visit", "voice", "wait", "walk", "wall", "want", "war", "warm", "wash", "watch", "water", "way", "we", "wear", "weather", "week", "welcome", "well", "west", "what", "when", "where", "which", "while", "white", "who", "whole", "why", "wide", "wife", "wild", "will", "win", "wind", "window", "winter", "wish", "with", "woman", "wonder", "word", "work", "world", "worry", "write", "writer", "wrong", "year", "yellow", "yes", "yesterday", "yet", "you", "young", "your", "zero", "zebra", "zone"
        }
        local usedWords = {}
        local eventAPI
        pcall(function()
            eventAPI = _G.import("event")
        end)

        local function getRequiredPrefix()
            local player = game:GetService("Players").LocalPlayer
            local gui = player and player:FindFirstChildOfClass("PlayerGui")
            local screen = gui and gui:FindFirstChild("ScreenGui")
            local topBar = screen and screen:FindFirstChild("TopBar")
            local answerInput = topBar and topBar:FindFirstChild("AnswerInput")
            local keys = answerInput and answerInput:FindFirstChild("Keys")
            if not keys then return nil end

            local labels = {}
            for _, object in ipairs(keys:GetDescendants()) do
                if object:IsA("TextLabel") or object:IsA("TextButton") then
                    local value = tostring(object.Text or ""):lower()
                    if value:match("^[a-z]+$") then
                        table.insert(labels, object)
                    end
                end
            end
            table.sort(labels, function(a, b)
                if a.LayoutOrder == b.LayoutOrder then
                    return a.Name < b.Name
                end
                return a.LayoutOrder < b.LayoutOrder
            end)

            local prefix = ""
            for _, label in ipairs(labels) do
                prefix = prefix .. tostring(label.Text):lower()
            end
            prefix = prefix:gsub("[^a-z]", "")
            if #prefix < 1 or #prefix > 3 then return nil end
            return prefix
        end

        local function findWord(prefix)
            local candidates = {}
            for _, word in ipairs(WORDS) do
                if #word > #prefix and word:sub(1, #prefix) == prefix and not usedWords[word] then
                    table.insert(candidates, word)
                end
            end
            if #candidates == 0 then return nil end
            -- Prefer familiar, shorter answers to reduce typing time.
            table.sort(candidates, function(a, b)
                if #a == #b then return a < b end
                return #a < #b
            end)
            return candidates[1]
        end

        local automationRunning = false
        local function runCompleteWords()
            if automationRunning then return end
            automationRunning = true
            task.spawn(function()
                local Players = game:GetService("Players")
                local player = Players.LocalPlayer
                local lastPrefix = nil

                while completeWordsEnabled do
                    local screen = player:FindFirstChildOfClass("PlayerGui")
                    screen = screen and screen:FindFirstChild("ScreenGui")
                    local choiceList = screen and screen:FindFirstChild("ChoiceList")
                    local isTurn = player:GetAttribute("IsTurn") == true

                    if not isTurn or (choiceList and choiceList.Visible) then
                        lastPrefix = nil
                        task.wait(0.2)
                    else
                        local prefix = getRequiredPrefix()
                        if prefix and prefix ~= lastPrefix then
                            local word = findWord(prefix)
                            lastPrefix = prefix
                            if word and eventAPI and type(eventAPI.fire) == "function" then
                                usedWords[word] = true
                                for index = #prefix + 1, #word do
                                    if not completeWordsEnabled or player:GetAttribute("IsTurn") ~= true then
                                        break
                                    end
                                    eventAPI.fire("keyStroke", word:sub(index, index))
                                    task.wait(0.09)
                                end
                                if completeWordsEnabled and player:GetAttribute("IsTurn") == true then
                                    task.wait(0.15)
                                    eventAPI.fire("tryAnswer")
                                end
                            end
                        end
                        task.wait(0.12)
                    end
                end
                automationRunning = false
            end)
        end


        local scroll = Instance.new("ScrollingFrame")
        scroll.Name = "CompleteWordsScroll"
        scroll.Position = UDim2.fromOffset(0, 0)
        scroll.Size = UDim2.new(1, 0, 1, 0)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 4
        scroll.ScrollBarImageColor3 = Color3.fromRGB(105, 125, 150)
        scroll.ScrollingDirection = Enum.ScrollingDirection.Y
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.Active = true
        scroll.Parent = page

        local content = Instance.new("Frame")
        content.Name = "CompleteWordsContent"
        content.Position = UDim2.fromOffset(10, 10)
        content.Size = UDim2.new(1, -20, 0, 0)
        content.AutomaticSize = Enum.AutomaticSize.Y
        content.BackgroundTransparency = 1
        content.Parent = scroll

        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 10)
        layout.Parent = content

        local card = Instance.new("Frame")
        card.Name = "CompleteWordsCard"
        card.Size = UDim2.new(1, 0, 0, 66)
        card.BackgroundColor3 = CARD
        card.BorderSizePixel = 0
        card.LayoutOrder = 1
        card.Parent = content

        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 12)
        cardCorner.Parent = card

        local cardGradient = Instance.new("UIGradient")
        cardGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 31, 47)),
            ColorSequenceKeypoint.new(1, PANEL)
        })
        cardGradient.Rotation = 15
        cardGradient.Parent = card

        local cardStroke = Instance.new("UIStroke")
        cardStroke.Name = "WhiteOutline"
        cardStroke.Color = WHITE
        cardStroke.Thickness = 1.35
        cardStroke.Transparency = 0.28
        cardStroke.Parent = card

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "CompleteWordsLabel"
        nameLabel.Position = UDim2.fromOffset(14, 0)
        nameLabel.Size = UDim2.new(1, -112, 1, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = "Complete Words"
        nameLabel.TextColor3 = TEXT
        nameLabel.TextSize = 14
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = card

        local stateLabel = Instance.new("TextLabel")
        stateLabel.Name = "CompleteWordsState"
        stateLabel.AnchorPoint = Vector2.new(1, 0.5)
        stateLabel.Position = UDim2.new(1, -91, 0.5, 0)
        stateLabel.Size = UDim2.fromOffset(64, 16)
        stateLabel.BackgroundTransparency = 1
        stateLabel.Text = "OFF"
        stateLabel.TextColor3 = MUTED
        stateLabel.TextSize = 9
        stateLabel.Font = Enum.Font.GothamBold
        stateLabel.TextXAlignment = Enum.TextXAlignment.Right
        stateLabel.Parent = card

        local switch = Instance.new("TextButton")
        switch.Name = "CompleteWordsSwitch"
        switch.AnchorPoint = Vector2.new(1, 0.5)
        switch.Position = UDim2.new(1, -12, 0.5, 0)
        switch.Size = UDim2.fromOffset(62, 28)
        switch.BackgroundColor3 = Color3.fromRGB(43, 53, 68)
        switch.BorderSizePixel = 0
        switch.Text = ""
        switch.AutoButtonColor = false
        switch.Parent = card

        local switchCorner = Instance.new("UICorner")
        switchCorner.CornerRadius = UDim.new(1, 0)
        switchCorner.Parent = switch

        local switchStroke = Instance.new("UIStroke")
        switchStroke.Color = WHITE
        switchStroke.Transparency = 0.35
        switchStroke.Thickness = 1
        switchStroke.Parent = switch

        local knob = Instance.new("Frame")
        knob.Name = "Knob"
        knob.Position = UDim2.fromOffset(3, 3)
        knob.Size = UDim2.fromOffset(22, 22)
        knob.BackgroundColor3 = WHITE
        knob.BorderSizePixel = 0
        knob.Parent = switch

        local knobCorner = Instance.new("UICorner")
        knobCorner.CornerRadius = UDim.new(1, 0)
        knobCorner.Parent = knob

        local function updateSwitch(instant)
            local knobPosition = completeWordsEnabled
                and UDim2.new(1, -25, 0, 3)
                or UDim2.fromOffset(3, 3)
            local switchColor = completeWordsEnabled
                and WHITE
                or Color3.fromRGB(43, 53, 68)
            local knobColor = completeWordsEnabled
                and Color3.fromRGB(18, 24, 34)
                or WHITE

            stateLabel.Text = completeWordsEnabled and "ON" or "OFF"
            stateLabel.TextColor3 = completeWordsEnabled and WHITE or MUTED

            if instant then
                knob.Position = knobPosition
                knob.BackgroundColor3 = knobColor
                switch.BackgroundColor3 = switchColor
                switchStroke.Transparency = completeWordsEnabled and 0.05 or 0.35
            else
                TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {
                    Position = knobPosition,
                    BackgroundColor3 = knobColor
                }):Play()
                TweenService:Create(switch, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {
                    BackgroundColor3 = switchColor
                }):Play()
                TweenService:Create(switchStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {
                    Transparency = completeWordsEnabled and 0.05 or 0.35
                }):Play()
            end
        end

        switch.MouseButton1Click:Connect(function()
            completeWordsEnabled = not completeWordsEnabled
            updateSwitch(false)
            if completeWordsEnabled then
                runCompleteWords()
            end
        end)

        updateSwitch(true)
    end)
end

return GameModule
