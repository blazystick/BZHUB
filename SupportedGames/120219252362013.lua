local GameModule = {}

function GameModule.Register(api)
    local farmButton = api.AddCategory("Farm", "FARM", function(page)
        local title = Instance.new("TextLabel")
        title.Name = "FarmTitle"
        title.Size = UDim2.new(1, -20, 0, 30)
        title.Position = UDim2.new(0, 5, 0, 5)
        title.BackgroundTransparency = 1
        title.Text = "Farm"
        title.TextSize = 18
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = page
    end)

    if farmButton then
        farmButton.Text = "FARM"
    end
end

return GameModule
