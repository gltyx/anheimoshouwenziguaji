-- ============================================================================
-- FileUpload Widget
-- File upload interface with drag-and-drop support
-- ============================================================================

local Widget = require("urhox-libs/UI/Core/Widget")
local Theme = require("urhox-libs/UI/Core/Theme")
local UI = require("urhox-libs/UI/Core/UI")

---@class FileUploadProps : WidgetProps
---@field variant string|nil "dropzone" | "button" | "inline" (default: "dropzone")
---@field multiple boolean|nil Allow multiple file selection (default: false)
---@field accept string|nil Accepted file types e.g. "image/*", ".pdf,.doc" (default: "*")
---@field maxSize number|nil Max file size in bytes
---@field maxFiles number|nil Max number of files (default: 10)
---@field showFileList boolean|nil Show uploaded file list (default: true)
---@field showProgress boolean|nil Show upload progress (default: false)
---@field icon string|nil Upload icon (default: "📁")
---@field label string|nil Upload label text
---@field hint string|nil Hint text below label
---@field disabled boolean|nil Disabled state (default: false)
---@field onFileSelect fun(upload: FileUpload, file: table)|nil File selection callback
---@field onFileRemove fun(upload: FileUpload, file: table)|nil File removal callback
---@field onUploadProgress fun(upload: FileUpload, file: table, progress: number)|nil Progress callback
---@field onUploadComplete fun(upload: FileUpload, file: table)|nil Upload complete callback
---@field onError fun(upload: FileUpload, message: string)|nil Error callback

---@class FileUpload : Widget
---@operator call(FileUploadProps?): FileUpload
---@field props FileUploadProps
---@field new fun(self, props: FileUploadProps?): FileUpload
local FileUpload = Widget:Extend("FileUpload")

-- ============================================================================
-- Constructor
-- ============================================================================

---@param props FileUploadProps?
function FileUpload:Init(props)
    props = props or {}

    -- FileUpload props
    self.variant_ = props.variant or "dropzone"  -- dropzone, button, inline
    self.multiple_ = props.multiple or false
    self.accept_ = props.accept or "*"  -- File types: "image/*", ".pdf,.doc", etc.
    self.maxSize_ = props.maxSize  -- Max file size in bytes
    self.maxFiles_ = props.maxFiles or 10

    -- Visual
    self.showFileList_ = props.showFileList ~= false  -- default true
    self.showProgress_ = props.showProgress or false
    self.icon_ = props.icon or "📁"
    self.label_ = props.label or "Drop files here or click to upload"
    self.hint_ = props.hint

    -- State
    self.files_ = {}  -- { name, size, type, progress, status }
    self.isDragging_ = false
    self.isHovered_ = false

    -- Callbacks
    self.onFileSelect_ = props.onFileSelect
    self.onFileRemove_ = props.onFileRemove
    self.onUploadProgress_ = props.onUploadProgress
    self.onUploadComplete_ = props.onUploadComplete
    self.onError_ = props.onError

    -- Disabled state
    self.disabled_ = props.disabled or false

    -- Sizes
    self.fileItemHeight_ = 48
    self.dropzoneHeight_ = 100
    self.baseHeight_ = nil  -- Will be set after Init

    Widget.Init(self, props)

    -- Store base height (without file list)
    self.baseHeight_ = self:GetBaseHeight()
    self:UpdateTotalHeight()
end

-- ============================================================================
-- Height Management
-- ============================================================================

function FileUpload:GetBaseHeight()
    if self.variant_ == "dropzone" then
        return self.dropzoneHeight_
    elseif self.variant_ == "button" then
        return 36
    else
        return 36
    end
end

function FileUpload:CalculateTotalHeight()
    local baseHeight = self.baseHeight_ or self:GetBaseHeight()
    local fileListHeight = 0

    if self.showFileList_ and #self.files_ > 0 then
        -- Add spacing between dropzone/button and file list
        local listOffset = self.variant_ == "dropzone" and 20 or 8
        fileListHeight = listOffset + #self.files_ * self.fileItemHeight_
    end

    return baseHeight + fileListHeight
end

function FileUpload:UpdateTotalHeight()
    local height = self:CalculateTotalHeight()
    self:SetStyle({ height = height })  -- SetStyle auto-triggers layout dirty
end

-- ============================================================================
-- File Management
-- ============================================================================

function FileUpload:GetFiles()
    return self.files_
end

function FileUpload:AddFile(file)
    -- Validate file
    if self.maxSize_ and file.size > self.maxSize_ then
        if self.onError_ then
            self.onError_(self, "File too large: " .. file.name)
        end
        return false
    end

    if not self.multiple_ and #self.files_ > 0 then
        self.files_ = {}
    end

    if #self.files_ >= self.maxFiles_ then
        if self.onError_ then
            self.onError_(self, "Maximum files reached")
        end
        return false
    end

    file.status = file.status or "pending"
    file.progress = file.progress or 0
    table.insert(self.files_, file)

    -- Update height to accommodate file list
    self:UpdateTotalHeight()

    if self.onFileSelect_ then
        self.onFileSelect_(self, file)
    end

    return true
end

function FileUpload:RemoveFile(index)
    local file = self.files_[index]
    if file then
        table.remove(self.files_, index)

        -- Update height after removing file
        self:UpdateTotalHeight()

        if self.onFileRemove_ then
            self.onFileRemove_(self, file)
        end
    end
end

function FileUpload:ClearFiles()
    self.files_ = {}
    -- Update height after clearing all files
    self:UpdateTotalHeight()
end

function FileUpload:SetFileProgress(index, progress)
    if self.files_[index] then
        self.files_[index].progress = progress
        self.files_[index].status = progress >= 1 and "complete" or "uploading"

        if self.onUploadProgress_ then
            self.onUploadProgress_(self, self.files_[index], progress)
        end

        if progress >= 1 and self.onUploadComplete_ then
            self.onUploadComplete_(self, self.files_[index])
        end
    end
end

function FileUpload:SetFileError(index, error)
    if self.files_[index] then
        self.files_[index].status = "error"
        self.files_[index].error = error
    end
end

-- ============================================================================
-- Drag State
-- ============================================================================

function FileUpload:SetDragging(dragging)
    self.isDragging_ = dragging
end

-- ============================================================================
-- Helpers
-- ============================================================================

function FileUpload:FormatFileSize(bytes)
    if bytes < 1024 then
        return bytes .. " B"
    elseif bytes < 1024 * 1024 then
        return string.format("%.1f KB", bytes / 1024)
    elseif bytes < 1024 * 1024 * 1024 then
        return string.format("%.1f MB", bytes / (1024 * 1024))
    else
        return string.format("%.1f GB", bytes / (1024 * 1024 * 1024))
    end
end

function FileUpload:GetFileIcon(fileType)
    if fileType:match("^image/") then
        return "🖼️"
    elseif fileType:match("^video/") then
        return "🎬"
    elseif fileType:match("^audio/") then
        return "🎵"
    elseif fileType:match("pdf") then
        return "📄"
    elseif fileType:match("zip") or fileType:match("rar") or fileType:match("7z") then
        return "📦"
    else
        return "📁"
    end
end

-- ============================================================================
-- Render
-- ============================================================================

function FileUpload:Render(nvg)
    local x, y = self:GetAbsolutePosition()
    local w, h = self:GetComputedSize()
    local theme = Theme.GetTheme()

    Widget.Render(self, nvg)

    if self.variant_ == "dropzone" then
        self:RenderDropzone(nvg, x, y, w, h)
    elseif self.variant_ == "button" then
        self:RenderButton(nvg, x, y, w, h)
    else
        self:RenderInline(nvg, x, y, w, h)
    end

    -- Render file list
    if self.showFileList_ and #self.files_ > 0 then
        local baseHeight = self.baseHeight_ or self:GetBaseHeight()
        local listOffset = self.variant_ == "dropzone" and 20 or 8
        local listY = y + baseHeight + listOffset
        self:RenderFileList(nvg, x, listY, w)
    end
end

function FileUpload:RenderDropzone(nvg, x, y, w, h)
    local theme = Theme.GetTheme()
    local dropzoneH = 100

    -- Store bounds
    self.dropzoneBounds_ = { x = x, y = y, w = w, h = dropzoneH }

    -- Background
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, dropzoneH, 8)

    if self.disabled_ then
        nvgFillColor(nvg, Theme.NvgColor("surfaceDisabled"))
    elseif self.isDragging_ then
        local primaryColor = Theme.Color("primary")
        nvgFillColor(nvg, nvgRGBA(primaryColor[1], primaryColor[2], primaryColor[3], 30))
    elseif self.isHovered_ then
        nvgFillColor(nvg, Theme.NvgColor("surfaceHover"))
    else
        nvgFillColor(nvg, Theme.NvgColor("surfaceVariant"))
    end
    nvgFill(nvg)

    -- Dashed border
    nvgStrokeColor(nvg, self.isDragging_ and Theme.NvgColor("primary") or Theme.NvgColor("border"))
    nvgStrokeWidth(nvg, 2)
    -- Note: NanoVG doesn't support dashed lines directly, so we draw a solid line
    nvgStroke(nvg)

    -- Icon
    local iconY = y + dropzoneH / 2 - 20
    nvgFontSize(nvg, Theme.FontSizeOf("display"))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER_VISUAL + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, self.disabled_ and Theme.NvgColor("textDisabled") or Theme.NvgColor("textSecondary"))
    nvgText(nvg, x + w / 2, iconY, self.icon_)

    -- Label
    nvgFontSize(nvg, Theme.FontSizeOf("body"))
    nvgFontFace(nvg, Theme.FontFamily())
    nvgTextAlign(nvg, NVG_ALIGN_CENTER_VISUAL + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, self.disabled_ and Theme.NvgColor("textDisabled") or Theme.NvgColor("text"))
    nvgText(nvg, x + w / 2, y + dropzoneH / 2 + 10, self.label_)

    -- Hint
    if self.hint_ then
        nvgFontSize(nvg, Theme.FontSizeOf("small"))
        nvgFillColor(nvg, Theme.NvgColor("textSecondary"))
        nvgText(nvg, x + w / 2, y + dropzoneH / 2 + 30, self.hint_)
    end
end

function FileUpload:RenderButton(nvg, x, y, w, h)
    local theme = Theme.GetTheme()
    local btnH = 36

    self.buttonBounds_ = { x = x, y = y, w = w, h = btnH }

    -- Button background
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, btnH, 4)

    if self.disabled_ then
        nvgFillColor(nvg, Theme.NvgColor("surfaceDisabled"))
    elseif self.isHovered_ then
        nvgFillColor(nvg, Theme.NvgColor("primaryHover"))
    else
        nvgFillColor(nvg, Theme.NvgColor("primary"))
    end
    nvgFill(nvg)

    -- Button text
    nvgFontSize(nvg, Theme.FontSizeOf("body"))
    nvgFontFace(nvg, Theme.FontFamily())
    nvgTextAlign(nvg, NVG_ALIGN_CENTER_VISUAL + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
    nvgText(nvg, x + w / 2, y + btnH / 2, self.label_)
end

function FileUpload:RenderInline(nvg, x, y, w, h)
    local theme = Theme.GetTheme()
    local inlineH = 36

    self.inlineBounds_ = { x = x, y = y, w = w, h = inlineH }

    -- Icon
    nvgFontSize(nvg, Theme.FontSizeOf("subtitle"))
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, Theme.NvgColor("textSecondary"))
    nvgText(nvg, x, y + inlineH / 2, self.icon_)

    -- Label
    nvgFontSize(nvg, Theme.FontSizeOf("body"))
    nvgFontFace(nvg, Theme.FontFamily())

    if self.isHovered_ then
        nvgFillColor(nvg, Theme.NvgColor("primary"))
    else
        nvgFillColor(nvg, Theme.NvgColor("text"))
    end
    nvgText(nvg, x + 28, y + inlineH / 2, self.label_)
end

function FileUpload:RenderFileList(nvg, x, y, w)
    local theme = Theme.GetTheme()
    local fileItemHeight = self.fileItemHeight_

    self.fileItemBounds_ = {}

    for i, file in ipairs(self.files_) do
        local itemY = y + (i - 1) * fileItemHeight

        self.fileItemBounds_[i] = { x = x, y = itemY, w = w, h = fileItemHeight }

        -- Item background
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, x, itemY, w, fileItemHeight - 4, 4)
        nvgFillColor(nvg, Theme.NvgColor("surfaceVariant"))
        nvgFill(nvg)

        -- File icon
        local icon = self:GetFileIcon(file.type or "")
        nvgFontSize(nvg, Theme.FontSizeOf("title"))
        nvgTextAlign(nvg, NVG_ALIGN_CENTER_VISUAL + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, Theme.NvgColor("textSecondary"))
        nvgText(nvg, x + 20, itemY + fileItemHeight / 2, icon)

        -- File name
        nvgFontSize(nvg, Theme.FontSizeOf("bodySmall"))
        nvgFontFace(nvg, Theme.FontFamily())
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, Theme.NvgColor("text"))
        nvgText(nvg, x + 44, itemY + fileItemHeight / 2 - 8, file.name)

        -- File size
        nvgFontSize(nvg, Theme.FontSizeOf("caption"))
        nvgFillColor(nvg, Theme.NvgColor("textSecondary"))
        nvgText(nvg, x + 44, itemY + fileItemHeight / 2 + 8, self:FormatFileSize(file.size or 0))

        -- Status indicator
        local statusX = x + w - 60
        if file.status == "complete" then
            nvgFillColor(nvg, Theme.NvgColor("success"))
            nvgText(nvg, statusX, itemY + fileItemHeight / 2, "✓ Done")
        elseif file.status == "error" then
            nvgFillColor(nvg, Theme.NvgColor("error"))
            nvgText(nvg, statusX, itemY + fileItemHeight / 2, "✗ Error")
        elseif file.status == "uploading" and self.showProgress_ then
            -- Progress bar
            local progressW = 50
            local progressH = 4
            local progressY = itemY + fileItemHeight / 2 - progressH / 2

            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, statusX, progressY, progressW, progressH, 2)
            nvgFillColor(nvg, Theme.NvgColor("border"))
            nvgFill(nvg)

            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, statusX, progressY, progressW * file.progress, progressH, 2)
            nvgFillColor(nvg, Theme.NvgColor("primary"))
            nvgFill(nvg)
        end

        -- Remove button
        local removeBtnX = x + w - 24
        self.removeButtonBounds_ = self.removeButtonBounds_ or {}
        self.removeButtonBounds_[i] = { x = removeBtnX, y = itemY + 12, w = 20, h = 20 }

        nvgFontSize(nvg, Theme.FontSizeOf("body"))
        nvgTextAlign(nvg, NVG_ALIGN_CENTER_VISUAL + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, Theme.NvgColor("textSecondary"))
        nvgText(nvg, removeBtnX + 10, itemY + fileItemHeight / 2, "✕")
    end
end

-- ============================================================================
-- Input Handling
-- ============================================================================

function FileUpload:PointInBounds(px, py, bounds)
    if not bounds then return false end
    return px >= bounds.x and px <= bounds.x + bounds.w and
           py >= bounds.y and py <= bounds.y + bounds.h
end

function FileUpload:OnPointerMove(event)
    if not event then return end

    -- Get offset between render coords and screen coords
    local renderX, renderY = self:GetAbsolutePosition()
    local hitTest = self:GetAbsoluteLayoutForHitTest()
    local offsetX = renderX - hitTest.x
    local offsetY = renderY - hitTest.y
    local px = event.x + offsetX
    local py = event.y + offsetY

    local bounds = self.dropzoneBounds_ or self.buttonBounds_ or self.inlineBounds_
    self.isHovered_ = self:PointInBounds(px, py, bounds)
end

function FileUpload:OnMouseLeave()
    self.isHovered_ = false
    self.isDragging_ = false
end

function FileUpload:OnClick(event)
    if not event then return end
    if self.disabled_ then return false end

    -- Get offset between render coords and screen coords
    local renderX, renderY = self:GetAbsolutePosition()
    local hitTest = self:GetAbsoluteLayoutForHitTest()
    local offsetX = renderX - hitTest.x
    local offsetY = renderY - hitTest.y
    local px = event.x + offsetX
    local py = event.y + offsetY

    -- Check remove buttons
    if self.removeButtonBounds_ then
        for i, bounds in pairs(self.removeButtonBounds_) do
            if self:PointInBounds(px, py, bounds) then
                self:RemoveFile(i)
                return true
            end
        end
    end

    -- Check main interaction area
    local bounds = self.dropzoneBounds_ or self.buttonBounds_ or self.inlineBounds_
    if self:PointInBounds(px, py, bounds) then
        -- In a real implementation, this would trigger a file dialog
        -- For now, we simulate adding a file
        self:AddFile({
            name = "sample_file_" .. (#self.files_ + 1) .. ".txt",
            size = math.random(1000, 5000000),
            type = "text/plain",
        })
        return true
    end

    return false
end

-- ============================================================================
-- Static Helpers
-- ============================================================================

--- Create a dropzone file upload
---@param props table|nil
---@return FileUpload
function FileUpload.Dropzone(props)
    props = props or {}
    props.variant = "dropzone"
    return FileUpload(props)
end

--- Create a button file upload
---@param props table|nil
---@return FileUpload
function FileUpload.Button(props)
    props = props or {}
    props.variant = "button"
    props.label = props.label or "Choose File"
    return FileUpload(props)
end

--- Create an image upload
---@param props table|nil
---@return FileUpload
function FileUpload.Image(props)
    props = props or {}
    props.accept = "image/*"
    props.icon = "🖼️"
    props.label = props.label or "Drop images here or click to upload"
    props.hint = props.hint or "Supports: JPG, PNG, GIF"
    return FileUpload(props)
end

--- Create a multi-file upload
---@param props table|nil
---@return FileUpload
function FileUpload.Multiple(props)
    props = props or {}
    props.multiple = true
    return FileUpload(props)
end

--- Create a document upload
---@param props table|nil
---@return FileUpload
function FileUpload.Document(props)
    props = props or {}
    props.accept = ".pdf,.doc,.docx,.txt"
    props.icon = "📄"
    props.label = props.label or "Drop documents here or click to upload"
    props.hint = props.hint or "Supports: PDF, DOC, DOCX, TXT"
    return FileUpload(props)
end

return FileUpload
