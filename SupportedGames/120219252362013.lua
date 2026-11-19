
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
