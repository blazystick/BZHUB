local GameModule = {}
--123123123
function GameModule.Register(api)
    api.AddCategory("Automation", "AUTOMATION", function(page)
        local TweenService = game:GetService("TweenService")

        local CARD = Color3.fromRGB(17, 23, 33)
        local PANEL = Color3.fromRGB(14, 19, 28)
        local TEXT = Color3.fromRGB(235, 242, 250)
        local MUTED = Color3.fromRGB(145, 160, 180)
        local WHITE = Color3.fromRGB(255, 255, 255)

        local completeWordsEnabled = false

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
            -- UI-only at this stage. The word-solving engine will be connected later.
        end)

        updateSwitch(true)
    end)
end

return GameModule
