--[[ *************************************************************
 * Context menu for mpv using Tcl/Tk. Mostly proof of concept.
 * Avi Halachmi (:avih) https://github.com/avih
 * 
 * Features:
 * - Simple construction: ["<some text>", "<mpv-command>"] is a complete menu item.
 * - Possibly dynamic menu items and commands, disabled items, separators.
 * - Possibly keeping the menu open after clicking an item (via re-launch).
 * - Hacky pseudo sub menus. Really, this is an ugly hack.
 * - Reasonably well behaved/integrated considering it's an external application.
 * 
 * TODO-ish:
 * - Proper sub menus (TBD protocol, tk relaunch), tooltips, other widgets (not).
 * - Possibly different menus for different bindings or states.
 *
 * Setup:
 * - Make sure Tcl/Tk is installed and `wish` is accessible and works.
 *   - Alternatively, configure `interpreter` below to `tclsh`, which may work smoother.
 *   - For windows, download a zip from http://www.tcl3d.org/html/appTclkits.html
 *     extract and then rename to wish.exe and put it at the path or at the mpv.exe dir.
 *     - Or, tclsh/wish from git/msys2(mingw) works too - set `interpreter` below.
 * - Put context.lua (this file) and context.tcl at the mpv scripts dir.
 * - Add a key/mouse binding at input.conf, e.g. "MOUSE_BTN2 script_message contextmenu"
 * - Once it works, configure the context_menu items below to your liking.
 *
 * 2017-02-02 - Version 0.1 - initial version
 * 
 ***************************************************************
--]]

local verbose = false  -- true -> dump console messages also without -v
function info(x) mp.msg[verbose and "info" or "verbose"](x) end
function debug(x) mp.msg.info(x) end

--[[ ************ CONFIG: start ************ ]]--

-- context_menu is an array of items, where each item is an array of:
-- - Display string or a function which returns such string, or "-" for separator.
-- - Command string or a function which is executed on click. Empty to disable/gray.
-- - Optional re-launch: a submenu array, or true to "keep" the same menu open.

function noop() end
local propNative = mp.get_property_native
local boxChecked, boxUnchecked = "[X] ", "[ ] "
local radioSelect, radioUnselect = "(x) ", "( ) "
local boxA, boxB = "[A] ", "[B] "
local emptyPre = "    "
local menuArr = ""
local menuWidth = 36
local extraSpaces = 4

function round(num, numDecimalPlaces)
  return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
end

local function addSpaces(menuItem, shortcut, addExtra)
    -- shortcut is not always a shortcut (in the instance of a menu arrow) but we'll
    --   just use the name shortcut here anyway as that's what it's there for.
    local spacesCount = menuWidth

    if (menuItem) then spacesCount = spacesCount - string.len(menuItem) end

    -- The menu arrow is only 1 character, so let's ensure that the length check
    --   for the string only comes back as a length of 1 character.
    if (shortcut) then
        if (shortcut == menuArr) then shortcut = "1" end
        spacesCount = spacesCount - string.len(shortcut)
    end
    
    -- For some of the customised checkbox items, we'll need to add extra 
    if (addExtra) then spacesCount = spacesCount + addExtra end
    
    return string.rep(" ", spacesCount)
end

local function menuLabel(itemLabel, itemShortcut)
    local builtItem = ""
    builtItem = emptyPre .. itemLabel .. addSpaces(itemLabel, itemShortcut) .. itemShortcut
    return builtItem
end

local function togABLoop()
    local defLabel, abloopLabel, abShortcut = "Set/Clear A-B Loop", "", "R"
    local abLoopA, abLoopB = propNative("ab-loop-a"), propNative("ab-loop-b")
    
    if (abLoopA == "no") and (abLoopB == "no") then abloopLabel = boxUnchecked .. defLabel
    elseif not (abLoopA == "no") and (abLoopB == "no") then abloopLabel = boxA .. defLabel
    elseif not (abLoopA == "no") and not (abLoopB == "no") then abloopLabel = boxB .. defLabel end
    
    abloopLabel = abloopLabel .. addSpaces(abloopLabel, abShortcut, extraSpaces) .. abShortcut
    return abloopLabel
end

local function togInfLoop()
    local defLabel, infLabel, infShortcut = "Toggle Infinite Loop", "", "Shift+R"
    
    if (propNative("loop-file") == false) then infLabel = boxUnchecked .. defLabel
    elseif (propNative("loop-file") == true) then infLabel = boxChecked .. defLabel end
    
    infLabel = infLabel .. addSpaces(infLabel, infShortcut, extraSpaces) .. infShortcut
    return infLabel
end

-- Edition menu functions
local function checkEdition(radioItem)
    local editionLabel, editionSuffix, editionVal = "", "", propNative("edition")
    local editionTitle = propNative("edition-list/" .. radioItem .. "/title")
    
    if (editionTitle) then editionSuffix = editionTitle
    else editionSuffix = "Edition " .. (radioItem + 1) end
    
    if (radioItem == editionVal) then editionLabel = radioSelect .. editionSuffix
    else editionLabel = radioUnselect .. editionSuffix end
    
    return editionLabel
end

local function editionList()
    local editionCount, editionListVal = propNative("edition-list/count"), {}

    for i=0, (editionCount - 1), 1 do
        local editionNum = i
        local editionCommand = "set edition " .. editionNum
        table.insert(editionListVal, {function() return checkEdition(editionNum) end, editionCommand, true})
    end

    return editionListVal
end

local function editionMenu()
    local editionMenuVal = {}
    
    if (propNative("edition-list/count") < 1) then
        editionMenuVal = {menuLabel("Title/Edition", menuArr)}
    else
        editionMenuVal = {menuLabel("Title/Edition", menuArr), noop, {
            editionList(),
        }}
    end
    
    return editionMenuVal
end

-- Chapter menu functions
local function checkChapter(radioItem)
    local chapterLabel, chapterSuffix, chapterVal = "", "", propNative("chapter")
    local chapterTitle = propNative("chapter-list/" .. radioItem .. "/title")
    
    if (chapterTitle) then chapterSuffix = chapterTitle
    else chapterSuffix = "Chapter " .. (radioItem + 1) end
    
    if (radioItem == chapterVal) then chapterLabel = radioSelect .. chapterSuffix
    else chapterLabel = radioUnselect .. chapterSuffix end
    
    return chapterLabel
end

local function chapterList()
    local chapterCount, chapterListVal = propNative("chapter-list/count"), {}
    
    for i=0, (chapterCount - 1), 1 do
        local chapterNum = i
        local chapterCommand = "set chapter " .. chapterNum
        table.insert(chapterListVal, {function() return checkChapter(chapterNum) end, chapterCommand, true})
    end

    return chapterListVal
end

local function chapterMenu()
    local chapterMenuVal = {}
    
    if (propNative("chapter-list/count") < 1) then chapterMenuVal = {menuLabel("Chapter", menuArr)}
    else
        chapterMenuVal = {menuLabel("Chapter", menuArr), noop, {
            {menuLabel("Previous", "PgUp"), "no-osd add chapter -1", true},
            {menuLabel("Next", "PgDown"), "no-osd add chapter 1", true},
            {"-"},
            chapterList(),
        }}
    end
    
    return chapterMenuVal
end

-- Track type count function to iterate through the track-list and get the number of
--   tracks of the type specified. Types are:  video / audio / sub. This actually
--   returns an array of track numbers of the given type so that the track-list/N/
--   properties can be obtained.

local function trackCount(checkType)
    local tracksCount = propNative("track-list/count")
    local trackCountVal = {}
    
    if not (tracksCount < 1) then 
        for i = 0, (tracksCount - 1), 1 do
            local trackType = propNative("track-list/" .. i .. "/type")
            if (trackType == checkType) then table.insert(trackCountVal, i) end
        end
    end
    
    return trackCountVal
end

-- Video > Track menu functions
local function checkVidTrack(radioNum, radioID)
    local vidTrackLabel, vidTrackSuffix = ""
    local vidTrackVal = propNative("track-list/" .. radioNum .. "/id")
    local vidTrackTitle = propNative("track-list/" .. radioNum .. "/title")
    
    if (vidTrackTitle) then vidTrackSuffix = vidTrackTitle
    else vidTrackSuffix = "Video Track " .. (radioNum + 1) end
    
    if (radioID == vidTrackVal) then vidTrackLabel = radioSelect .. vidTrackSuffix
    else vidTrackLabel = radioUnselect .. vidTrackSuffix end
    
    return vidTrackLabel
end

local function vidTrackList()
    local vidTrackCount, vidTrackListVal = trackCount("video"), {}
    
    for i = 1, (#vidTrackCount), 1 do
        local vidTrackNum = vidTrackCount[i]
        local vidTrackID = propNative("track-list/" .. vidTrackNum .. "/id")
        local vidTrackCommand = "set vid " .. vidTrackID
        table.insert(vidTrackListVal, {function() return checkVidTrack(vidTrackNum, vidTrackID) end, vidTrackCommand, true})
    end
    
    return vidTrackListVal
end

local function vidTrackMenu()
    local vidTrackMenuVal, vidTracksCount = {}, trackCount("video")
    
    if (#vidTracksCount < 1) then vidTrackMenuVal = {menuLabel("Track", menuArr)}
    else
        vidTrackMenuVal = {menuLabel("Track", menuArr), noop, {
            vidTrackList(),
        }}
    end
    
    return vidTrackMenuVal
end

-- Aspect Ratio radio item check and labeling
local function checkRatio(radioItem)
    -- Ratios and Decimal equivalents
    -- Ratios:    "4:3" "16:10"  "16:9" "1.85:1" "2.35:1"
    -- Decimal: "1.333" "1.600" "1.778"  "1.850"  "2.350"
    local ratioLabel, ratioLabelSuffix = ""
    local ratioVal = round(propNative("video-aspect"), 3)
    
    if (radioItem == "4:3") then
        ratioLabelSuffix = radioItem .. " (TV)"
        if (ratioVal == round(4/3, 3)) then ratioLabel = radioSelect .. ratioLabelSuffix
        else ratioLabel = radioUnselect .. ratioLabelSuffix end
    elseif (radioItem == "16:10") then
        ratioLabelSuffix = radioItem .. " (Wide Monitor)"
        if (ratioVal == round(16/10, 3)) then ratioLabel = radioSelect .. ratioLabelSuffix
        else ratioLabel = radioUnselect .. ratioLabelSuffix end
    elseif (radioItem == "16:9") then
        ratioLabelSuffix = radioItem .. " (HDTV)"
        if (ratioVal == round(16/9, 3)) then ratioLabel = radioSelect .. ratioLabelSuffix
        else ratioLabel = radioUnselect .. ratioLabelSuffix end
    elseif (radioItem == "1.85:1") then
        ratioLabelSuffix = radioItem .. " (Wide Vision)"
        if (ratioVal == round(1.85/1, 3)) then ratioLabel = radioSelect .. ratioLabelSuffix
        else ratioLabel = radioUnselect .. ratioLabelSuffix end
    elseif (radioItem == "2.35:1") then
        ratioLabelSuffix = radioItem .. " (CinemaScope)"
        if (ratioVal == round(2.35/1, 3)) then ratioLabel = radioSelect .. ratioLabelSuffix
        else ratioLabel = radioUnselect .. ratioLabelSuffix end
    end
    
    return ratioLabel
end

-- Video Rotate radio item check and labeling
local function checkRotate(radioItem)
    local rotateLabel, rotateDegree, rotateVal = "", "°", propNative("video-rotate")
    
    if (radioItem == rotateVal) then rotateLabel = radioSelect .. radioItem .. rotateDegree
    else rotateLabel = radioUnselect .. radioItem .. rotateDegree end
    
    return rotateLabel
end

-- Video Alignment radio item checks and labeling
local function checkAlign(alignAxis, alignPos)
    local alignLabel, alignText, alignAxisPre = ""
    local alignValY, alignValX = propNative("video-align-y"), propNative("video-align-x")
    
    -- This seems a bit unwieldy. Should look at simplifying if possible.
    if (alignPos == -1) then       
        if (alignAxis == "y") then
           if (alignValY == alignPos) then alignText = radioSelect .. "Top"
           else alignText = radioUnselect .. "Top" end
        elseif (alignAxis == "x") then
           if (alignValX == alignPos) then alignText = radioSelect .. "Left"
           else alignText = radioUnselect .. "Left" end
        end
    elseif (alignPos == 0) then
        if (alignAxis == "y") then
           if (alignValY == alignPos) then alignAxisPre = radioSelect .. "Vertical "
           else alignAxisPre = radioUnselect .. "Vertical " end
        elseif (alignAxis == "x") then
           if (alignValX == alignPos) then alignAxisPre = radioSelect .. "Horizontal "
           else alignAxisPre = radioUnselect .. "Horizontal " end
        end
        alignText = alignAxisPre .. "Center"
    elseif (alignPos == 1) then
        if (alignAxis == "y") then
           if (alignValY == alignPos) then alignText = radioSelect .. "Bottom"
           else alignText = radioUnselect .. "Bottom" end
        elseif (alignAxis == "x") then
           if (alignValX == alignPos) then alignText = radioSelect .. "Right"
           else alignText = radioUnselect .. "Right" end
        end
    end
    
    alignLabel = alignText
    return alignLabel
end

-- Deinterlacing radio item check and labeling
local function checkDeInt(radioItem)
    local deIntLabel, deIntPrefix, deIntVal = "", "", propNative("deinterlace")
    
    if (radioItem == deIntVal) then deIntPrefix = radioSelect
    else deIntPrefix = radioUnselect end
    
    if (radioItem == false) then deIntLabel = deIntPrefix .. "Off"
    elseif (radioItem == true) then deIntLabel = deIntPrefix .. "On" end
    
    return deIntLabel
end


-- NOTE: Look into converting ISO 639-2 codes for audio/subtitle track langages
-- Audio > Track menu functions
local function checkAudTrack(radioNum, radioID)
    local audTrackLabel, audTrackSuffix = ""
    local audTrackVal = propNative("aid")
    local audTrackTitle = propNative("track-list/" .. radioNum .. "/title")
    local audTrackLang = propNative("track-list/" .. radioNum .. "/lang")

    if (audTrackTitle) then audTrackSuffix = audTrackTitle .. " (" .. audTrackLang .. ")"
    elseif (audTrackLang) then audTrackSuffix = audTrackLang
    else audTrackSuffix = "Audio Track " .. (radioID) end
    
    if (radioID == audTrackVal) then audTrackLabel = radioSelect .. audTrackSuffix
    else audTrackLabel = radioUnselect .. audTrackSuffix end
    
    return audTrackLabel
end

local function audTrackList()
    local audTrackCount, audTrackListVal = trackCount("audio"), {}
    
    for i = 1, (#audTrackCount), 1 do
        local audTrackNum = audTrackCount[i]
        local audTrackID = propNative("track-list/" .. audTrackNum .. "/id")
        local audTrackCommand = "set aid " .. audTrackID
        table.insert(audTrackListVal, {function() return checkAudTrack(audTrackNum, audTrackID) end, audTrackCommand, true})
    end
    
    return audTrackListVal
end

local function audTrackMenu()
    local audTrackMenuVal, audTracksCount = {}, trackCount("audio")
    
    if (#audTracksCount < 1) then 
        audTrackMenuVal = {menuLabel("Track", menuArr), noop, {
             {menuLabel("Open File", "")},
             {menuLabel("Auto-load File", "")},
             {menuLabel("Reload File", "")},
             {"-"},
             {menuLabel("Select Next", "Ctrl+A")},
        }}
    else
        audTrackMenuVal = {menuLabel("Track", menuArr), noop, {
             {menuLabel("Open File", "")},
             {menuLabel("Auto-load File", "")},
             {menuLabel("Reload File", "")},
             {"-"},
             {menuLabel("Select Next", "Ctrl+A"), "cycle audio", true},
             -- Change this to be disabled only from here, put lines above in
             {"-"},
             audTrackList(),
        }}
    end
    
    return audTrackMenuVal
end

-- Mute checkbox toggle and labeling
local function togMute()
    local muteLabel, muteShortcut, mutePrefix, muteVal = "", "M", "", propNative("mute")
    
    if (muteVal == true) then  mutePrefix = boxChecked .. "Un-mute"
    else mutePrefix = boxUnchecked .. "Mute" end
    
    muteLabel = mutePrefix .. addSpaces(mutePrefix, muteShortcut, extraSpaces) .. muteShortcut
    return muteLabel
end

-- Subtitle Visibility checkbox toggle and labeling
local function togSubVis()
    local subLabel, subShortcut, subPrefix, subVal = "", "V", "", propNative("sub-visibility")
    
    if (subVal == true) then  subPrefix = boxChecked .. "Hide"
    else subPrefix = boxUnchecked .. "Un-hide" end
    
    subLabel = subPrefix .. addSpaces(subPrefix, subShortcut, extraSpaces) .. subShortcut
    return subLabel
end

-- NOTE: Look into converting ISO 639-2 codes for audio/subtitle track langages
-- Subtitle > Track menu functions
local function checkSubTrack(radioNum, radioID)
    local subTrackLabel, subTrackSuffix = ""
    local subTrackVal = propNative("sid")
    local subTrackTitle = propNative("track-list/" .. radioNum .. "/title")
    local subTrackLang = propNative("track-list/" .. radioNum .. "/lang")
    
    if (subTrackTitle) then subTrackSuffix = subTrackTitle .. " (" .. subTrackLang .. ")"
    elseif (subTrackLang) then subTrackSuffix = subTrackLang
    else subTrackSuffix = "Subtitle Track " .. (radioID) end
    
    if (radioID == subTrackVal) then subTrackLabel = radioSelect .. subTrackSuffix
    else subTrackLabel = radioUnselect .. subTrackSuffix end
    
    return subTrackLabel
end

local function subTrackList()
    local subTrackCount, subTrackListVal = trackCount("sub"), {}
    
    for i = 1, (#subTrackCount), 1 do
        local subTrackNum = subTrackCount[i]
        local subTrackID = propNative("track-list/" .. subTrackNum .. "/id")
        local subTrackCommand = "set sid " .. subTrackID
        table.insert(subTrackListVal, {function() return checkSubTrack(subTrackNum, subTrackID) end, subTrackCommand, true})
    end
    
    return subTrackListVal
end

local function subTrackMenu()
    local subTrackMenuVal, subTracksCount = {}, trackCount("sub")
    
    if (#subTracksCount < 1) then
        subTrackMenuVal = {menuLabel("Track", menuArr), noop, {
            {menuLabel("Open File", "(Shift+F)")},
            {menuLabel("Auto-load File", "")},
            {menuLabel("Reload File", "(Shift+R)")},
            {menuLabel("Clear File", "")},
            {menuLabel("Separator", "")},
            {menuLabel("Select Next", "Shift+N")},
            {menuLabel("Select Previous", "Ctrl+Shift+N")},
        }}
    else
        subTrackMenuVal = {menuLabel("Track", menuArr), noop, {
            {menuLabel("Open File", "(Shift+F)")},
            {menuLabel("Auto-load File", "")},
            {menuLabel("Reload File", "(Shift+R)")},
            {menuLabel("Clear File", "")},
            {menuLabel("Separator", "")},
            {menuLabel("Select Next", "Shift+N"), "cycle sub", true},
            {menuLabel("Select Previous", "Ctrl+Shift+N"), "cycle sub down", true},
            {function() return togSubVis() end, "cycle sub-visibility", true},
            {"-"},
            subTrackList(),
        }}
    end
    
    return subTrackMenuVal
end

-- Subtitle Alignment radio item check and labeling
local function checkSubAlign(radioItem)
    local subAlignLabel, subAlignPrefix, subAlignVal = "", "", propNative("sub-align-y")
    
    if (radioItem == subAlignVal) then subAlignPrefix = radioSelect
    else subAlignPrefix = radioUnselect end
    
    if (radioItem == "top") then subAlignLabel = subAlignPrefix .. "Top"
    elseif (radioItem == "bottom") then subAlignLabel = subAlignPrefix .. "Bottom" end
    
    return subAlignLabel
end

-- Subtitle Position radio item check and labeling
local function checkSubPos(radioItem)
    local subPosLabel, subPosPrefix, subPosVal = "", "", propNative("image-subs-video-resolution")
    
    if (radioItem == subPosVal) then subPosPrefix = radioSelect
    else subPosPrefix = radioUnselect end
    
    if (radioItem == false) then subPosLabel = subPosPrefix .. "Display on Letterbox"
    elseif (radioItem == true) then subPosLabel = subPosPrefix .. "Display in Video" end
    
    return subPosLabel
end

-- Template sub-menu item
-- {menuLabel("", menuArr)},

-- Template menu item
-- {menuLabel("", "")},

local context_menu = {}

-- DO NOT create the context_menu table until AFTER the file has loaded as we're unable to
--   dynamically create menus if it tries to build the table before the file is loaded.
-- A prime example is the chapter-list or track-list values, which are unavailable until
--   the file has been loaded.
mp.register_event("file-loaded", function()
    context_menu = {
    --{menuLabel("Chapters", menuArr), noop, {
    --  
    --}},
    {menuLabel("Open", menuArr), noop, {
        -- Some of these to be changed when I've developed some Zenity stuff
        {menuLabel("File", "Ctrl+F"), "script-binding navigator"},
        {menuLabel("Folder", "(Unbound)")},
        {menuLabel("URL", "")},
        {menuLabel("DVD", "")},
        {menuLabel("Bluray", "")},
        {menuLabel("From Clipboard", "(Unbound)")},
        {"-"},
        {menuLabel("Recent", menuArr)},
    }},
    {"-"},
    {menuLabel("Play", menuArr), noop, {
        {menuLabel("Play/Pause", "Space"), "cycle pause", true},
        {menuLabel("Stop", "Ctrl+Shift+Space"), "stop"},
        {"-"},
        {menuLabel("Previous", "<"), "playlist-prev", true},
        {menuLabel("Next", ">"), "playlist-next", true},
        {"-"},
        {menuLabel("Speed", menuArr), noop, {
            {menuLabel("Reset", "Backspace"), "no-osd set speed 1.0 ; show-text \"Play Speed - Reset\""},
            {"-"},
            {menuLabel("+5%", "="), "multiply speed 1.05", true},
            {menuLabel("-5%", "-"), "multiply speed 0.95", true},
        }},
        {menuLabel("A-B Repeat", menuArr), noop, {
            {function() return togABLoop() end, "ab-loop", true},
            {function() return togInfLoop() end, "cycle-values loop-file \"inf\" \"no\"", true},
            -- I'll look at this later with Zenity stuff
            {menuLabel("Set Loop Points...", "")},
        }},
        {"-"},
        {menuLabel("Seek", menuArr), noop, {
            {menuLabel("Beginning", "Ctrl+Home"), "no-osd seek 0 absolute", true},
            {menuLabel("Previous Playback", "")},
            {"-"},
            {menuLabel("+5 Sec", "Right"), "no-osd seek 5", true},
            {menuLabel("-5 Sec", "Left"), "no-osd seek -5", true},
            {menuLabel("+30 Sec", "Up"), "no-osd seek 30", true},
            {menuLabel("-30 Sec", "Down"), "no-osd seek -30", true},
            {menuLabel("+60 Sec", "End"), "no-osd seek 60", true},
            {menuLabel("-60 Sec", "Home"), "no-osd seek -60", true},
            {"-"},
            {menuLabel("Previous Frame", "Alt+Left"), "frame-back-step", true},
            {menuLabel("Next Frame", "Alt+Right"), "frame-step", true},
            {menuLabel("Next Black Frame", "Alt+b"), "script-binding skip_scene"},
            {"-"},
            {menuLabel("Previous Subtitle", ""), "no-osd sub-seek -1", true},
            {menuLabel("Current Subtitle", ""), "no-osd sub-seek 0", true},
            {menuLabel("Next Subtitle", ""), "no-osd sub-seek 1", true},
        }},
        -- Use functions returning arrays/tables, since we don't need these menus if there
        -- aren't any editions or any chapters to seek through.
        editionMenu(),
        chapterMenu(),
        --{"-"},
        -- For now, reference the overarching m3u8 of HLS streams to change stream by using
        --   the playlist functionality. Seems like --playlist works best for HLS streams.
        -- Maybe look at this later
        --{menuLabel("Streaming Format", menuArr)},
        -- I don't know what Show State even does in Bomi, so I'll hide this for now
        --{menuLabel("Show State", "")},
    }},
    {menuLabel("Video", menuArr), noop, {
        -- Use function to return list of Video Tracks
        vidTrackMenu(),
        {"-"},
        {menuLabel("Take Screenshot", menuArr), noop, {
            {menuLabel("Screenshot", "Ctrl+S"), "async screenshot"},
            {menuLabel("Screenshot (No Subs)", "Alt+S"), "async screenshot video"},
            {menuLabel("Screenshot (Subs/OSD/Scaled)", ""), "async screenshot window"},
            {menuLabel("Screenshot Tool", "")},
        }},
        {menuLabel("Make Video Clip", menuArr)},
        {"-"},
        {menuLabel("Aspect Ratio", menuArr), noop, {
            {menuLabel("Reset", "Ctrl+Shift+R"), "no-osd set video-aspect \"-1\" ; no-osd set video-aspect \"-1\" ; show-text \"Video Aspect Ratio - Reset\""},
            {menuLabel("Select Next", ""), "cycle-values video-aspect \"4:3\" \"16:10\" \"16:9\" \"1.85:1\" \"2.35:1\" \"-1\" \"-1\"", true},
            {"-"},
            {menuLabel("Same as Window", "")},
            {function() return checkRatio("4:3") end, "set video-aspect \"4:3\"", true},
            {function() return checkRatio("16:10") end, "set video-aspect \"16:10\"", true},
            {function() return checkRatio("16:9") end, "set video-aspect \"16:9\"", true},
            {function() return checkRatio("1.85:1") end, "set video-aspect \"1.85:1\"", true},
            {function() return checkRatio("2.35:1") end, "set video-aspect \"2.35:1\"", true},
            {"-"},
            {menuLabel("+0.001", "Ctrl+Shift+A"), "add video-aspect 0.001", true},
            {menuLabel("-0.001", "Ctrl+Shift+D"), "add video-aspect -0.001", true},
        }},
        {menuLabel("Crop", menuArr)},
        {menuLabel("Zoom", menuArr), noop, {
            {menuLabel("Reset", "Shift+R"), "no-osd set panscan 0 ; show-text \"Pan/Scan - Reset\""},
            {"-"},
            {menuLabel("+0.1 %", "Shift+T"), "add panscan 0.001", true},
            {menuLabel("-0.1 %", "Shift+G"), "add panscan -0.001", true},
        }},
        {menuLabel("Rotate", menuArr), noop, {
            {menuLabel("Reset", ""), "set video-rotate \"0\""},
            {menuLabel("Select Next", ""), "cycle-values video-rotate \"0\" \"90\" \"180\" \"270\"", true},
            {"-"},
            {function() return checkRotate(0) end, "set video-rotate \"0\"", true},
            {function() return checkRotate(90) end, "set video-rotate \"90\"", true},
            {function() return checkRotate(180) end, "set video-rotate \"180\"", true},
            {function() return checkRotate(270) end, "set video-rotate \"270\"", true},
        }},
        {menuLabel("Screen Position", menuArr), noop, {
            {menuLabel("Reset", "Shift+X"), "no-osd set video-pan-x 0 ; no-osd set video-pan-y 0 ; show-text \"Video Pan - Reset\""},
            {"-"},
            {menuLabel("Horizontally +0.1%", "Shift+D"), "add video-pan-x 0.001", true},
            {menuLabel("Horizontally -0.1%", "Shift+A"), "add video-pan-x -0.001", true},
            {"-"},
            {menuLabel("Vertically +0.1%", "Shift+S"), "add video-pan-y -0.001", true},
            {menuLabel("Vertically -0.1%", "Shift+W"), "add video-pan-y 0.001", true},
        }},
        {menuLabel("Screen Alignment", menuArr), noop, {
            -- Y Values: -1 = Top, 0 = Vertical Center, 1 = Bottom
            -- X Values: -1 = Left, 0 = Horizontal Center, 1 = Right
            {function() return checkAlign("y",-1) end, "set video-align-y -1", true},
            {function() return checkAlign("y",0) end, "set video-align-y 0", true},
            {function() return checkAlign("y",1) end, "set video-align-y 1", true},
            {"-"},
            {function() return checkAlign("x",-1) end, "set video-align-x -1", true},
            {function() return checkAlign("x",0) end, "set video-align-x 0", true},
            {function() return checkAlign("x",1) end, "set video-align-x 1", true},
        }},
        {"-"},
        {menuLabel("Color Space", menuArr)},
        {menuLabel("Color Range", menuArr)},
        {"-"},
        {menuLabel("Quality Preset", menuArr)},
        {menuLabel("Texture Format", menuArr)},
        {menuLabel("Chroma Upscaler", menuArr)},
        {menuLabel("Interpolater", menuArr)},
        {menuLabel("Interpolater (Downscale)", menuArr)},
        {menuLabel("High Quality Scaling", menuArr)},
        {menuLabel("Dithering", menuArr)},
        {"-"},
        {menuLabel("Motion Smoothing", "")},
        {menuLabel("Deinterlacing", menuArr), noop, {
            {menuLabel("Toggle", "Ctrl+D"), "cycle deinterlace", true},
            {menuLabel("Auto", ""), "set deinterlace \"auto\""},
            {"-"},
            {function() return checkDeInt(false) end, "set deinterlace \"no\"", true},
            {function() return checkDeInt(true) end, "set deinterlace \"yes\"", true},
        }},
        {menuLabel("Filter", menuArr)},
        {menuLabel("Adjust Color", menuArr), noop, {
            {menuLabel("Color Editor", "")},
            {menuLabel("Reset", "O"), "no-osd set brightness 0 ; no-osd set contrast 0 ; no-osd set hue 0 ; no-osd set saturation 0 ; show-text \"Colors - Reset\""},
            {"-"},
            {menuLabel("Brightness +1%", "T"), "add brightness 1", true},
            {menuLabel("Brightness -1%", "G"), "add brightness -1", true},
            {menuLabel("Contrast +1%", "Y"), "add contrast 1", true},
            {menuLabel("Contrast -1%", "H"), "add contrast -1", true},
            {menuLabel("Saturation +1%", "U"), "add saturation 1", true},
            {menuLabel("Saturation -1%", "J"), "add saturation -1", true},
            {menuLabel("Hue +1%", "I"), "add hue 1", true},
            {menuLabel("Hue -1%", "K"), "add hue -1", true},
            {menuLabel("Red +1%", "")},
            {menuLabel("Red -1%", "")},
            {menuLabel("Green +1%", "")},
            {menuLabel("Green -1%", "")},
            {menuLabel("Blue +1%", "")},
            {menuLabel("Blue -1%", "")},
        }},
    }},
    {menuLabel("Audio", menuArr), noop, {
        -- Use function to return list of Audio Tracks
        audTrackMenu(),
        {menuLabel("Sync", menuArr), noop, {
            {menuLabel("Reset", "\\"), "no-osd set audio-delay 0 ; show-text \"Audio Sync - Reset\""},
            {"-"},
            {menuLabel("+0.1 Sec", "]"), "add audio-delay 0.100", true},
            {menuLabel("-0.1 Sec", "["), "add audio-delay -0.100", true},
        }},
        {"-"},
        {menuLabel("Volume", menuArr), noop, {
            {function() return togMute() end, "cycle mute", true},
            {"-"},
            {menuLabel("+2%", "Shift+Up"), "add volume 2", true},
            {menuLabel("-2%", "Shift+Down"), "add volume -2", true},
        }},
        {menuLabel("Amp", menuArr)},
        {menuLabel("Equalizer", "")},
        {menuLabel("Channel Layout", menuArr)},
        {"-"},
        {menuLabel("Visualization", menuArr)},
        -- Need to figure out how to apply/remove filters to make the Normalizer toggle work
        {menuLabel("Normalizer", "N")},
        {menuLabel("Temp Scalar", "")},
    }},
    {menuLabel("Subtitle", menuArr), noop, {
        -- Use function to return list of Subtitle Tracks
        subTrackMenu(),
        {"-"},
        {menuLabel("Override ASS", menuArr)},
        {menuLabel("Alightment", menuArr), noop, {
            {menuLabel("Select Next", ""), "cycle-values sub-align-y \"top\" \"bottom\"", true},
            {"-"},
            {function() return checkSubAlign("top") end, "set sub-align-y \"top\"", true},
            {function() return checkSubAlign("bottom") end, "set sub-align-y \"bottom\"", true},
        }},
        {menuLabel("Position", menuArr), noop, {
            {menuLabel("Reset", "Alt+S"), "no-osd set sub-pos 100 ; no-osd set sub-scale 1 ; show-text \"Subitle Position - Reset\""},
            {"-"},
            {menuLabel("+1%", "S"), "add sub-pos 1", true},
            {menuLabel("-1%", "W"), "add sub-pos -1", true},
            {"-"},
            {function() return checkSubPos(false) end, "set image-subs-video-resolution \"no\"", true},
            {function() return checkSubPos(true) end, "set image-subs-video-resolution \"yes\"", true},
        }},
        {menuLabel("Scale", menuArr), noop, {
            {menuLabel("Reset", ""), "no-osd set sub-pos 100 ; no-osd set sub-scale 1 ; show-text \"Subitle Position - Reset\""},
            {"-"},
            {menuLabel("+1%", "Shift+L"), "add sub-scale 0.01", true},
            {menuLabel("-1%", "Shift+K"), "add sub-scale -0.01", true},
        }},
        {"-"},
        {menuLabel("Sync", menuArr), noop, {
            {menuLabel("Reset", "Q"), "no-osd set sub-delay 0 ; show-text \"Subtitle Delay - Reset\""},
            {"-"},
            {menuLabel("+0.1 Sec", "D"), "add sub-delay +0.1", true},
            {menuLabel("-0.1 Sec", "A"), "add sub-delay -0.1", true},
            {"-"},
            {menuLabel("Bring Previous Lines", "")},
            {menuLabel("Bring Next Lines", "")},
        }},
    }},
    {"-"},
    {menuLabel("Tools", menuArr), noop, {
        {menuLabel("Undo", "")},
        {menuLabel("Redo", "")},
        {"-"},
        {menuLabel("Playlist", menuArr), noop, {
            {menuLabel("Show", "l"), "script-binding showplaylist"},
            {"-"},
            {menuLabel("Open", "")},
            {menuLabel("Save", ""), "script-binding saveplaylist"},
            {menuLabel("Regenerate", "script-binding loadfiles")},
            {menuLabel("Clear", "Shift+L")},
            {"-"},
            {menuLabel("Append File", "")},
            {menuLabel("Append Folder", "")},
            {menuLabel("Append URL", "")},
            {menuLabel("Remove", "Shift+R")},
            {"-"},
            {menuLabel("Move Up", "")},
            {menuLabel("Move Down", "")},
            {"-"},
            -- These following two are checkboxes
            {menuLabel("Shuffle", "")},
            {menuLabel("Repeat", "")},
        }},
        -- Not sure if I need this, mpv doesn't really keep a recent history beyond watch_later
        --   config files, which is not quite the same thing.
        {menuLabel("History", menuArr), noop, {
            {menuLabel("Show/Hide", "")},
            {menuLabel("Clear", "")},
        }},
        {menuLabel("Find Subtitle (Subit)", ""), "script-binding subit"},
        {menuLabel("Subitle Viewer", "")},
        {menuLabel("Playback Information", "Tab"), "script-binding display-stats-toggle", true},
        {menuLabel("Log Viewer", "")},
        {"-"},
        {menuLabel("Preferences", "")},
        {menuLabel("Reload Skin", "")},
        {"-"},
        -- These following two are checkboxes
        {menuLabel("Auto-exit", "")},
        {menuLabel("Auto-shutdown", "")},
    }},
    {menuLabel("Window", menuArr), noop, {
        {menuLabel("Stays on Top", menuArr), noop, {
            {menuLabel("Empty", "")},
            {"-"},
            -- Radio buttons
            {menuLabel("Off", "")},
            {menuLabel("Playing", "")},
            {menuLabel("Always", "")},
        }},
        -- Remove Frame is a checkbox (use "set border "yes"")
        {menuLabel("Remove Frame", "")},
        {"-"},
        {menuLabel("Display Size x10%", "")},
        {menuLabel("Display Size x20%", "")},
        {menuLabel("Display Size x30%", "")},
        {menuLabel("Display Size x40%", "")},
        {menuLabel("Video Size x100%", "")},
        {"-"},
        {menuLabel("Toggle Fullscreen", "")},
        {menuLabel("Enter Fullscreen", "")},
        {menuLabel("Exit Fullscreen", "")},
        {"-"},
        {menuLabel("Maximize", "")},
        {menuLabel("Minimize", "")},
        {menuLabel("Close", "Ctrl+W")},
    }},
    {"-"},
    {emptyPre .. "Dismiss Menu", noop},
    {emptyPre .. "Quit", "quit"},
    }
end)

local interpreter = "wish";  -- tclsh/wish/full-path
local menuscript = mp.find_config_file("scripts/context.tcl")

--[[ ************ CONFIG: end ************ ]]--

local utils = require 'mp.utils'

local function do_menu(items, x, y)
    local args = {interpreter, menuscript, tostring(x), tostring(y)}
    -- This gets table objects and expands them before they're built into the menu
    for i = 1, #items do
        local item = items[i]
        if (type(item[1]) == "table") then
          for subi = 1, #item do
              table.insert(items, i + subi, item[subi])
          end
          table.remove(items, i)
          i = i - 1
        end
    end
    
    for i = 1, #items do
        local item = items[i]
        args[#args+1] = (type(item[1]) == "string") and item[1] or item[1]()
        args[#args+1] = item[2] and tostring(i) or ""
    end
    local ret = utils.subprocess({
        args = args,
        cancellable = true
    })

    if (ret.status ~= 0) then
        mp.osd_message("Something happened ...")
        return
    end

    info("ret: " .. ret.stdout)
    local res = utils.parse_json(ret.stdout)
    x = tonumber(res.x)
    y = tonumber(res.y)
    res.rv = tonumber(res.rv)
    if (res.rv == -1) then
        info("Context menu cancelled")
        return
    end

    local item = items[res.rv]
    if (not (item and item[2])) then
        mp.msg.error("Unknown menu item index: " .. tostring(res.rv))
        return
    end

    -- run the command
    if (type(item[2]) == "string") then
        mp.command(item[2])
    else
        item[2]()
    end

    -- re-launch
    if (item[3]) then
        if (type(item[3]) ~= "boolean") then
            items = item[3]  -- sub-menu, launch at mouse position
            x = -1
            y = -1
        end
        -- Break direct recursion with async, stack overflow can come quick.
        -- Also allow to un-congest the events queue.
        mp.add_timeout(0, function() do_menu(items, x, y) end)
    end
end

mp.register_script_message("contextmenu", function()
    do_menu(context_menu, -1, -1)
end)
