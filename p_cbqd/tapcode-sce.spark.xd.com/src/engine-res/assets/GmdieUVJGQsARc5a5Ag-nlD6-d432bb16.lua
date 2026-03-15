-- ============================================================================
-- VideoPlayer Widget
-- UrhoX Video Library - WASM Video Playback
-- ============================================================================
--
-- A widget for playing videos in WASM builds.
-- Uses HTML5 video element for decoding and WebGL texture for rendering.
--
-- Usage:
--   local Video = require("urhox-libs/Video")
--   local player = Video.VideoPlayer {
--       src = "https://example.com/video.mp4",
--       width = "100%",
--       height = 400,
--       autoPlay = false,
--       loop = false,
--       muted = false,
--       volume = 1.0,
--       onPlay = function(self) print("Playing") end,
--       onPause = function(self) print("Paused") end,
--       onEnded = function(self) print("Ended") end,
--       onTimeUpdate = function(self, time, duration) end,
--   }
--
-- ============================================================================

local Widget = require("urhox-libs/UI/Core/Widget")
local Theme = require("urhox-libs/UI/Core/Theme")

---@class VideoPlayerProps : WidgetProps
---@field src string Video source URL
---@field autoPlay boolean|nil Auto play on load (default: false)
---@field loop boolean|nil Loop playback (default: false)
---@field muted boolean|nil Muted state (default: false)
---@field volume number|nil Volume 0-1 (default: 1.0)
---@field textureWidth number|nil Initial texture width (default: 1920)
---@field textureHeight number|nil Initial texture height (default: 1080)
---@field objectFit string|nil "contain", "cover", or "fill" (default: "contain")
---@field backgroundColor table|nil Background color {r, g, b, a}
---@field onPlay fun(self: VideoPlayerWidget)|nil Callback when play starts
---@field onPause fun(self: VideoPlayerWidget)|nil Callback when paused
---@field onEnded fun(self: VideoPlayerWidget)|nil Callback when video ends
---@field onTimeUpdate fun(self: VideoPlayerWidget, time: number, duration: number)|nil Time update callback
---@field onReady fun(self: VideoPlayerWidget)|nil Callback when video is ready

---@class VideoPlayerWidget : Widget
---@operator call(VideoPlayerProps?): VideoPlayerWidget
---@field props VideoPlayerProps
---@field new fun(self, props: VideoPlayerProps?): VideoPlayerWidget
local VideoPlayerWidget = Widget:Extend("VideoPlayer")

-- ============================================================================
-- Constructor
-- ============================================================================

---@param props VideoPlayerProps?
function VideoPlayerWidget:Init(props)
    props = props or {}

    -- Default properties
    props.textureWidth = props.textureWidth or 1920
    props.textureHeight = props.textureHeight or 1080
    props.autoPlay = props.autoPlay or false
    props.loop = props.loop or false
    props.muted = props.muted or false
    props.volume = props.volume or 1.0
    props.objectFit = props.objectFit or "contain"
    props.backgroundColor = props.backgroundColor or {0, 0, 0, 255}

    -- Default size
    props.height = props.height or 400

    -- Initialize state
    self.state = {
        ready = false,
        playing = false,
        currentTime = 0,
        duration = 0,
        wasPlaying = false,
    }

    -- C++ VideoPlayer instance
    self.player_ = nil
    self.nvgImageHandle_ = nil
    self.lastTimeUpdate_ = 0

    -- Create C++ VideoPlayer
    if VideoPlayer then
        self.player_ = VideoPlayer:new()

        -- Load video if src is provided
        if props.src then
            self:LoadVideo(props.src)
        end
    else
        print("[VideoPlayer] Warning: VideoPlayer class not available (WASM only)")
    end

    Widget.Init(self, props)
end

--- Destroy widget and release resources
function VideoPlayerWidget:Destroy()
    -- Clean up C++ player
    if self.player_ then
        self.player_:Stop()
        self.player_ = nil
    end

    -- Clean up NanoVG image handle
    self.nvgImageHandle_ = nil

    Widget.Destroy(self)
end

-- ============================================================================
-- Video Control Methods
-- ============================================================================

---Load video from URL
---@param src string Video source URL
---@return boolean success
function VideoPlayerWidget:LoadVideo(src)
    if not self.player_ then
        print("[VideoPlayer] Player not initialized")
        return false
    end

    local width = self.props.textureWidth
    local height = self.props.textureHeight

    -- Load video
    local success = self.player_:Load(src, width, height)

    if success then
        -- Apply initial settings
        self.player_:SetVolume(self.props.volume)
        self.player_:SetMuted(self.props.muted)
        self.player_:SetLoop(self.props.loop)

        -- Reset NanoVG image handle (will be recreated on next render)
        self.nvgImageHandle_ = nil

        -- Auto play if requested
        if self.props.autoPlay then
            self.player_:Play()
        end

        self:SetState({ ready = false })
    end

    return success
end

---Play video
function VideoPlayerWidget:Play()
    if self.player_ then
        self.player_:Play()
        self:SetState({ playing = true })

        if self.props.onPlay then
            self.props.onPlay(self)
        end
    end
end

---Pause video
function VideoPlayerWidget:Pause()
    if self.player_ then
        self.player_:Pause()
        self:SetState({ playing = false })

        if self.props.onPause then
            self.props.onPause(self)
        end
    end
end

---Stop video
function VideoPlayerWidget:Stop()
    if self.player_ then
        self.player_:Stop()
        self:SetState({ playing = false, currentTime = 0 })
    end
end

---Seek to time
---@param time number Time in seconds
function VideoPlayerWidget:Seek(time)
    if self.player_ then
        self.player_:Seek(time)
    end
end

---Set volume
---@param volume number Volume 0-1
function VideoPlayerWidget:SetVolume(volume)
    self.props.volume = volume
    if self.player_ then
        self.player_:SetVolume(volume)
    end
end

---Set muted state
---@param muted boolean
function VideoPlayerWidget:SetMuted(muted)
    self.props.muted = muted
    if self.player_ then
        self.player_:SetMuted(muted)
    end
end

---Get current playback time
---@return number time Time in seconds
function VideoPlayerWidget:GetCurrentTime()
    if self.player_ then
        return self.player_:GetCurrentTime()
    end
    return 0
end

---Get video duration
---@return number duration Duration in seconds
function VideoPlayerWidget:GetDuration()
    if self.player_ then
        return self.player_:GetDuration()
    end
    return 0
end

---Check if video is playing
---@return boolean
function VideoPlayerWidget:IsPlaying()
    if self.player_ then
        return self.player_:IsPlaying()
    end
    return false
end

---Check if video is ready
---@return boolean
function VideoPlayerWidget:IsReady()
    if self.player_ then
        return self.player_:IsReady()
    end
    return false
end

-- ============================================================================
-- Update
-- ============================================================================

function VideoPlayerWidget:Update(dt)
    if self.player_ then
        -- Update texture from video frame
        self.player_:Update()

        -- Check if video became ready
        if not self.state.ready and self.player_:IsReady() then
            self:SetState({ ready = true })
            if self.props.onReady then
                self.props.onReady(self)
            end
        end

        -- Check playback state
        local nowPlaying = self.player_:IsPlaying()
        if nowPlaying ~= self.state.playing then
            self:SetState({ playing = nowPlaying })
        end

        -- Check for ended state
        local state = self.player_:GetState()
        if state == VIDEO_ENDED and self.state.wasPlaying then
            self:SetState({ wasPlaying = false })
            if self.props.onEnded then
                self.props.onEnded(self)
            end
        end

        if nowPlaying then
            self.state.wasPlaying = true
        end

        -- Time update callback (throttled to ~10 updates per second)
        if self.props.onTimeUpdate then
            local currentTime = self.player_:GetCurrentTime()
            if math.abs(currentTime - self.lastTimeUpdate_) > 0.1 then
                self.lastTimeUpdate_ = currentTime
                local duration = self.player_:GetDuration()
                self:SetState({ currentTime = currentTime, duration = duration })
                self.props.onTimeUpdate(self, currentTime, duration)
            end
        end
    end
end

-- ============================================================================
-- Rendering
-- ============================================================================

function VideoPlayerWidget:Render(nvg)
    local l = self:GetAbsoluteLayout()
    local props = self.props

    -- Draw background
    if props.backgroundColor then
        nvgBeginPath(nvg)
        nvgRect(nvg, l.x, l.y, l.w, l.h)
        nvgFillColor(nvg, nvgRGBA(
            props.backgroundColor[1],
            props.backgroundColor[2],
            props.backgroundColor[3],
            props.backgroundColor[4] or 255
        ))
        nvgFill(nvg)
    end

    -- Draw video texture
    if self.player_ and self.state.ready then
        local texture = self.player_:GetTexture()
        if texture then
            -- Get or create NanoVG image handle
            local imgHandle = self:GetOrCreateNvgImage(nvg, texture)
            if imgHandle and imgHandle > 0 then
                -- Get video dimensions
                local videoW = self.player_:GetVideoWidth()
                local videoH = self.player_:GetVideoHeight()

                if videoW > 0 and videoH > 0 then
                    -- Calculate draw rectangle based on objectFit
                    local drawX, drawY, drawW, drawH = self:CalculateDrawRect(
                        l.x, l.y, l.w, l.h,
                        videoW, videoH,
                        props.objectFit
                    )

                    -- Draw video frame
                    local imgPaint = nvgImagePattern(nvg, drawX, drawY, drawW, drawH, 0, imgHandle, 1)
                    nvgBeginPath(nvg)
                    nvgRect(nvg, drawX, drawY, drawW, drawH)
                    nvgFillPaint(nvg, imgPaint)
                    nvgFill(nvg)
                end
            end
        end
    end

    -- Draw "loading" indicator if not ready
    if self.player_ and not self.state.ready then
        nvgFontSize(nvg, 16)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 180))
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(nvg, l.x + l.w / 2, l.y + l.h / 2, "Loading...", nil)
    end

    -- Note: Children (overlays, controls, etc.) are rendered automatically
    -- by the UI framework's renderWidgetTree() after this Render() call
end

---Get or create NanoVG image from texture
---@param nvg userdata NanoVG context
---@param texture VideoTexture
---@return number|nil imageHandle
function VideoPlayerWidget:GetOrCreateNvgImage(nvg, texture)
    if not self.nvgImageHandle_ then
        if nvgCreateVideo then
            self.nvgImageHandle_ = nvgCreateVideo(nvg, texture)
            if not self.nvgImageHandle_ or self.nvgImageHandle_ <= 0 then
                self.nvgImageHandle_ = nil
            end
        end
    end
    return self.nvgImageHandle_
end

---Calculate draw rectangle based on objectFit mode
---@param containerX number
---@param containerY number
---@param containerW number
---@param containerH number
---@param videoW number
---@param videoH number
---@param objectFit string "contain", "cover", or "fill"
---@return number, number, number, number drawX, drawY, drawW, drawH
function VideoPlayerWidget:CalculateDrawRect(containerX, containerY, containerW, containerH, videoW, videoH, objectFit)
    if videoW <= 0 or videoH <= 0 then
        return containerX, containerY, containerW, containerH
    end

    if objectFit == "fill" then
        -- Stretch to fill container
        return containerX, containerY, containerW, containerH
    end

    local containerRatio = containerW / containerH
    local videoRatio = videoW / videoH

    local drawW, drawH

    if objectFit == "cover" then
        -- Scale to cover (may crop)
        if videoRatio > containerRatio then
            drawH = containerH
            drawW = containerH * videoRatio
        else
            drawW = containerW
            drawH = containerW / videoRatio
        end
    else
        -- "contain" - Scale to fit (letterbox/pillarbox)
        if videoRatio > containerRatio then
            drawW = containerW
            drawH = containerW / videoRatio
        else
            drawH = containerH
            drawW = containerH * videoRatio
        end
    end

    local drawX = containerX + (containerW - drawW) / 2
    local drawY = containerY + (containerH - drawH) / 2

    return drawX, drawY, drawW, drawH
end

-- ============================================================================
-- Event Handlers
-- ============================================================================

function VideoPlayerWidget:OnPointerUp(event)
    Widget.OnPointerUp(self, event)

    -- Toggle play/pause on click
    if self.player_ then
        if self.player_:IsPlaying() then
            self:Pause()
        else
            self:Play()
        end
    end
end

return VideoPlayerWidget
