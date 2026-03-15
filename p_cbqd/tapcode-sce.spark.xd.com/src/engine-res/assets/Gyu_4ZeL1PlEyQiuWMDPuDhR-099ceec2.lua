-- Leaderboard and Cloud Variable Test Sample
-- This sample demonstrates:
--     - Client score (cloud variable) init, set, and add operations
--     - Client leaderboard query and display
--     - User rank query
--     - Async callback handling pattern

require "LuaScripts/Utilities/Sample"

-- UI Elements
local statusText = nil
local playerIdText = nil
local scoreText = nil
local rankText = nil
local leaderboardText = nil
local logText = nil

-- Score data
local currentPlayerId = nil  -- Will be set by common.get_user_id()
local currentScore = 0
local currentPlayCount = 0
local currentRank = nil
local currentRankTotal = 0

-- Log buffer
local logLines = {}
local MAX_LOG_LINES = 10

function Start()
    -- Execute the common startup for samples
    SampleStart()

    -- Get current player ID
    currentPlayerId = common.get_user_id()
    AddLog("Current player ID: " .. tostring(currentPlayerId))

    -- Enable OS cursor
    input.mouseVisible = true

    -- Load UI style
    local style = cache:GetResource("XMLFile", "UI/DefaultStyle.xml")
    ui.root.defaultStyle = style

    -- Create UI
    CreateUI()

    -- Initialize score data
    InitScoreData()

    -- Set the mouse mode
    SampleInitMouseMode(MM_FREE)

    -- Subscribe to events
    SubscribeToEvents()
end

function CreateUI()
    -- Create main window
    local window = Window:new()
    ui.root:AddChild(window)
    window.minWidth = 500
    window.minHeight = 400
    window:SetLayout(LM_VERTICAL, 10, IntRect(10, 10, 10, 10))
    window:SetAlignment(HA_CENTER, VA_CENTER)
    window:SetStyleAuto()

    -- Title
    local title = Text:new()
    title.text = "Leaderboard & Cloud Variable Test"
    title:SetFont(cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), 16)
    title.color = Color(1.0, 1.0, 0.0)
    title.horizontalAlignment = HA_CENTER
    window:AddChild(title)

    -- Status section
    statusText = CreateLabel(window, "Status: Initializing...")

    -- Score section
    local scoreSection = CreateSection(window, "Current Player Data")
    playerIdText = CreateLabel(scoreSection, "Player ID: --")
    scoreText = CreateLabel(scoreSection, "Score: 0")
    rankText = CreateLabel(scoreSection, "Rank: --")

    -- Leaderboard section
    local leaderboardSection = CreateSection(window, "Top 10 Leaderboard")
    leaderboardText = Text:new()
    leaderboardText.text = "Loading..."
    leaderboardText:SetFont(cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), 12)
    leaderboardText.color = Color(0.8, 0.8, 0.8)
    leaderboardSection:AddChild(leaderboardText)

    -- Button section
    local buttonContainer = UIElement:new()
    buttonContainer:SetLayout(LM_HORIZONTAL, 10, IntRect(0, 0, 0, 0))
    buttonContainer.layoutMode = LM_HORIZONTAL
    window:AddChild(buttonContainer)

    CreateButton(buttonContainer, "Add Score (+10)", "HandleAddScore")
    CreateButton(buttonContainer, "Add Play (+1)", "HandleAddPlay")
    CreateButton(buttonContainer, "Refresh", "HandleRefresh")

    -- Second row of buttons
    local buttonContainer2 = UIElement:new()
    buttonContainer2:SetLayout(LM_HORIZONTAL, 10, IntRect(0, 0, 0, 0))
    buttonContainer2.layoutMode = LM_HORIZONTAL
    window:AddChild(buttonContainer2)

    CreateButton(buttonContainer2, "Reset", "HandleReset")
    CreateButton(buttonContainer2, "Delete Score", "HandleDeleteScore")
    CreateButton(buttonContainer2, "Delete Play", "HandleDeletePlay")
    CreateButton(buttonContainer2, "Delete All", "HandleDeleteAll")

    -- Log section
    local logSection = CreateSection(window, "Log")
    logText = Text:new()
    logText.text = ""
    logText:SetFont(cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), 10)
    logText.color = Color(0.6, 1.0, 0.6)
    logSection:AddChild(logText)
end

function CreateSection(parent, titleStr)
    local section = UIElement:new()
    section:SetLayout(LM_VERTICAL, 5, IntRect(5, 5, 5, 5))
    section.layoutMode = LM_VERTICAL
    parent:AddChild(section)

    local sectionTitle = Text:new()
    sectionTitle.text = "=== " .. titleStr .. " ==="
    sectionTitle:SetFont(cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), 12)
    sectionTitle.color = Color(0.5, 0.8, 1.0)
    section:AddChild(sectionTitle)

    return section
end

function CreateLabel(parent, text)
    local label = Text:new()
    label.text = text
    label:SetFont(cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), 12)
    label.color = Color(1.0, 1.0, 1.0)
    parent:AddChild(label)
    return label
end

function CreateButton(parent, text, handler)
    local button = Button:new()
    button.minWidth = 100
    button.minHeight = 30
    button:SetStyleAuto()
    parent:AddChild(button)

    local buttonText = Text:new()
    buttonText.text = text
    buttonText:SetFont(cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), 11)
    buttonText.horizontalAlignment = HA_CENTER
    buttonText.verticalAlignment = VA_CENTER
    button:AddChild(buttonText)

    SubscribeToEvent(button, "Released", handler)
    return button
end

function AddLog(message)
    table.insert(logLines, os.date("[%H:%M:%S] ") .. message)
    while #logLines > MAX_LOG_LINES do
        table.remove(logLines, 1)
    end
    if logText then
        logText.text = table.concat(logLines, "\n")
    end
    print(message)
end

function UpdateStatus(status)
    if statusText then
        statusText.text = "Status: " .. status
    end
end

function InitScoreData()
    UpdateStatus("Loading score data...")
    AddLog("Initializing client score data...")

    -- Query client score data
    -- score.client_score_init(player, events, key1, key2, ...)
    -- 注意: 回调参数已简化为 (values, iscores)，sscores 已废弃
    score.client_score_init(currentPlayerId, {
        ok = function(values, iscores)
            currentScore = iscores.test_score or 0
            currentPlayCount = iscores.play_count or 0

            UpdateScoreDisplay()
            UpdateStatus("Score data loaded")
            AddLog("Score loaded: " .. currentScore .. ", PlayCount: " .. currentPlayCount)

            -- After loading score, query rank, total and leaderboard
            QueryUserRank()
            QueryRankTotal()
            QueryLeaderboard()
        end,
        error = function(code, reason)
            UpdateStatus("Error: " .. (reason or "Unknown"))
            AddLog("Error loading score: " .. (reason or code))
        end,
        timeout = function()
            UpdateStatus("Timeout loading score")
            AddLog("Timeout loading score data")
        end
    }, "test_score", "play_count")
end

function UpdateScoreDisplay()
    if playerIdText then
        playerIdText.text = string.format("Player ID: %s", tostring(currentPlayerId or "--"))
    end
    if scoreText then
        scoreText.text = string.format("Score: %d | Play Count: %d", currentScore, currentPlayCount)
    end
    if rankText then
        if currentRank then
            rankText.text = string.format("Your Rank: #%d / %d players", currentRank, currentRankTotal)
        else
            rankText.text = string.format("Your Rank: Not on leaderboard (%d players)", currentRankTotal)
        end
    end
end

function QueryUserRank()
    AddLog("Querying user rank...")

    -- score.client_get_user_rank(player_id, key, [type], [events])
    score.client_get_user_rank(currentPlayerId, "test_score", "iscore", {
        ok = function(rank, scoreValue)
            currentRank = rank
            UpdateScoreDisplay()
            if rank then
                AddLog("Your rank: #" .. rank .. " (score: " .. (scoreValue or 0) .. ")")
            else
                AddLog("Not on leaderboard yet")
            end
        end,
        error = function(code, reason)
            AddLog("Error querying rank: " .. (reason or code))
        end
    })
end

function QueryRankTotal()
    AddLog("Querying rank total...")

    -- score.client_get_rank_total(key, [type], events)
    score.client_get_rank_total("test_score", "iscore", {
        ok = function(total)
            currentRankTotal = total or 0
            UpdateScoreDisplay()
            AddLog("Rank total: " .. currentRankTotal .. " players")
        end,
        error = function(code, reason)
            AddLog("Error querying rank total: " .. (reason or code))
        end
    })
end

function QueryLeaderboard()
    AddLog("Querying leaderboard...")

    -- score.client_get_rank_list(key, start, count, [type], events, [other_key...])
    score.client_get_rank_list("test_score", 0, 10, "iscore", {
        ok = function(rankList)
            local text = ""
            if #rankList == 0 then
                text = "No data yet. Add some scores!"
            else
                -- Header
                text = string.format("%-4s %-12s %-8s %-8s\n", "Rank", "Player", "Score", "Plays")
                text = text .. string.rep("-", 36) .. "\n"
                -- Data rows
                for i, item in ipairs(rankList) do
                    local playerScore = item.iscore.test_score or 0
                    local playCount = item.iscore.play_count or 0
                    local playerId = tostring(item.player)
                    -- Highlight current player
                    local prefix = ""
                    if item.player == currentPlayerId then
                        prefix = ">"
                    end
                    text = text .. string.format("%s%-3d %-12s %-8d %-8d\n",
                        prefix, i, playerId, playerScore, playCount)
                end
            end
            if leaderboardText then
                leaderboardText.text = text
            end
            AddLog("Leaderboard loaded (" .. #rankList .. " entries)")
        end,
        error = function(code, reason)
            if leaderboardText then
                leaderboardText.text = "Error: " .. (reason or code)
            end
            AddLog("Error loading leaderboard: " .. (reason or code))
        end
    }, "play_count")  -- Also fetch play_count for each player
end

function CommitScoreChange(description)
    UpdateStatus("Saving...")
    AddLog("Committing: " .. description)

    local c = score.get_commit()

    -- Update both scores (client commit methods don't need player_id)
    c.client_score_seti("test_score", currentScore)
    c.client_score_seti("play_count", currentPlayCount)

    c.commit(description, {
        ok = function()
            UpdateStatus("Saved successfully")
            AddLog("Score saved successfully")
            -- Refresh rank and leaderboard after saving
            QueryUserRank()
            QueryLeaderboard()
        end,
        error = function(code, reason)
            UpdateStatus("Save failed: " .. (reason or "Unknown"))
            AddLog("Save failed: " .. (reason or code))
        end,
        timeout = function()
            UpdateStatus("Save timeout")
            AddLog("Save timeout")
        end
    })
end

-- Button handlers
function HandleAddScore(eventType, eventData)
    currentScore = currentScore + 10
    UpdateScoreDisplay()
    CommitScoreChange("Add score +10")
end

function HandleAddPlay(eventType, eventData)
    currentPlayCount = currentPlayCount + 1
    UpdateScoreDisplay()
    CommitScoreChange("Add play count +1")
end

function HandleRefresh(eventType, eventData)
    AddLog("Refreshing all data...")
    InitScoreData()
end

function HandleReset(eventType, eventData)
    currentScore = 0
    currentPlayCount = 0
    UpdateScoreDisplay()
    CommitScoreChange("Reset all scores")
end

function HandleDeleteScore(eventType, eventData)
    AddLog("Deleting test_score...")
    UpdateStatus("Deleting score...")

    local c = score.get_commit()
    -- client_score_deletei(key) - Delete integer score
    c.client_score_deletei("test_score")
    c.commit("Delete test_score", {
        ok = function()
            currentScore = 0
            UpdateScoreDisplay()
            UpdateStatus("Score deleted")
            AddLog("test_score deleted successfully")
            QueryUserRank()
            QueryRankTotal()
            QueryLeaderboard()
        end,
        error = function(code, reason)
            UpdateStatus("Delete failed: " .. (reason or "Unknown"))
            AddLog("Delete failed: " .. (reason or code))
        end
    })
end

function HandleDeletePlay(eventType, eventData)
    AddLog("Deleting play_count...")
    UpdateStatus("Deleting play count...")

    local c = score.get_commit()
    -- client_score_deletei(key) - Delete integer score
    c.client_score_deletei("play_count")
    c.commit("Delete play_count", {
        ok = function()
            currentPlayCount = 0
            UpdateScoreDisplay()
            UpdateStatus("Play count deleted")
            AddLog("play_count deleted successfully")
            QueryLeaderboard()
        end,
        error = function(code, reason)
            UpdateStatus("Delete failed: " .. (reason or "Unknown"))
            AddLog("Delete failed: " .. (reason or code))
        end
    })
end

function HandleDeleteAll(eventType, eventData)
    AddLog("Deleting all scores...")
    UpdateStatus("Deleting all...")

    local c = score.get_commit()
    -- Delete both scores in one commit
    c.client_score_deletei("test_score")
    c.client_score_deletei("play_count")
    c.commit("Delete all scores", {
        ok = function()
            currentScore = 0
            currentPlayCount = 0
            UpdateScoreDisplay()
            UpdateStatus("All scores deleted")
            AddLog("All scores deleted successfully")
            QueryUserRank()
            QueryRankTotal()
            QueryLeaderboard()
        end,
        error = function(code, reason)
            UpdateStatus("Delete failed: " .. (reason or "Unknown"))
            AddLog("Delete failed: " .. (reason or code))
        end
    })
end

function SubscribeToEvents()
    SubscribeToEvent("KeyDown", "HandleKeyDown")
end

function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()

    -- Press R to refresh
    if key == KEY_R then
        HandleRefresh(nil, nil)
    -- Press S to add score
    elseif key == KEY_S then
        HandleAddScore(nil, nil)
    -- Press P to add play count
    elseif key == KEY_P then
        HandleAddPlay(nil, nil)
    end
end

-- Screen joystick patch (hide joystick for this sample)
function GetScreenJoystickPatchString()
    return
        "<patch>" ..
        "    <add sel=\"/element/element[./attribute[@name='Name' and @value='Hat0']]\">" ..
        "        <attribute name=\"Is Visible\" value=\"false\" />" ..
        "    </add>" ..
        "</patch>"
end
