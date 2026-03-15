-- LuaScripts/Utilities/Previews/Isolation_Server.lua
-- Server-mode file isolation: completely blocks ALL file system access.
-- On the server, game scripts have zero reason to touch the filesystem.

local iso = require('LuaScripts/Utilities/Previews/Isolation_Common')
local Warn = iso.Warn
local BlockMethod = iso.BlockMethod
local BlockProperty = iso.BlockProperty

-- ============================================================================
-- File: block all access
-- ============================================================================

BlockMethod(File, "Open",      false)
BlockMethod(File, "new",       nil)
BlockMethod(File, "new_local", nil)

-- File() call syntax — __call is a metamethod, BlockMethod can't handle it
local File_mt = getmetatable(File)
if File_mt and File_mt.__call then
    File_mt.__call = function()
        Warn("File() is not allowed")
        return nil
    end
end

-- ============================================================================
-- FileSystem: block all access
-- ============================================================================

BlockMethod(FileSystem, "CreateDir",           false)
BlockMethod(FileSystem, "Delete",              false)
BlockMethod(FileSystem, "Copy",                false)
BlockMethod(FileSystem, "Rename",              false)
BlockMethod(FileSystem, "FileExists",          false)
BlockMethod(FileSystem, "DirExists",           false)
BlockMethod(FileSystem, "ScanDir",             {})
BlockMethod(FileSystem, "SetCurrentDir",       false)
BlockMethod(FileSystem, "SetLastModifiedTime", false)
BlockMethod(FileSystem, "GetLastModifiedTime", false)

-- Block path getters that leak server directory structure
BlockMethod(FileSystem, "GetCurrentDir",        "")
BlockMethod(FileSystem, "GetProgramDir",        "")
BlockMethod(FileSystem, "GetUserDocumentsDir",  "")
BlockMethod(FileSystem, "GetAppPreferencesDir", "")
BlockMethod(FileSystem, "GetTemporaryDir",      "")

BlockProperty(FileSystem, "currentDir")
BlockProperty(FileSystem, "programDir")
BlockProperty(FileSystem, "userDocumentsDir")
BlockProperty(FileSystem, "temporaryDir")

-- ============================================================================
-- Image: block all save
-- ============================================================================

BlockMethod(Image, "SaveBMP",  false)
BlockMethod(Image, "SavePNG",  false)
BlockMethod(Image, "SaveTGA",  false)
BlockMethod(Image, "SaveJPG",  false)
BlockMethod(Image, "SaveDDS",  false)
BlockMethod(Image, "SaveWEBP", false)

-- ============================================================================
-- C++ direct file write API: block all
-- These C++ methods create File objects internally, bypassing the Lua File wrapper.
-- ============================================================================

BlockMethod(Scene,     "Save",             false)
BlockMethod(Scene,     "SaveXML",          false)
BlockMethod(Scene,     "SaveJSON",         false)
BlockMethod(JSONFile,  "Save",             false)
BlockMethod(XMLFile,   "Save",             false)
BlockMethod(Resource,  "Save",             false)
BlockMethod(UIElement, "SaveXML",          false)
BlockMethod(Input,     "SaveGestures",     false)
BlockMethod(Input,     "SaveGesture",      false)
BlockMethod(Graphics,  "BeginDumpShaders", false)

-- ============================================================================
-- ResourceCache / DownloadManager — block interfaces that leak filesystem paths
-- ============================================================================

BlockMethod(ResourceCache,   "GetResourceDirs",     {})
BlockMethod(ResourceCache,   "GetResourceFileName",  "")
BlockMethod(DownloadManager, "GetDefaultDirectory",  "")

BlockProperty(ResourceCache,   "resourceDirs")
BlockProperty(DownloadManager, "defaultDirectory")
