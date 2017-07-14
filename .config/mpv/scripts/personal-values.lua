-- This file is here so that I can source the values from other lua scripts, but keep my
--   personal paths out of them. If you're seeing this in a repository, the values are
--   merely original template values taken from the various files.

local publicClass={};

-- For navigator.lua
function publicClass.defaultPath()
    return "/"
end

-- For navigator.lua

function publicClass.favorites()
    return {
        '/media/HDD2/music/music/',
        '/media/HDD/users/anon/Downloads/',
        '/home/anon/',
    }
end

-- For playlistmanager.lua
function publicClass.playlistSavepath()
    return "/home/anon/Documents/"
end

return publicClass;
