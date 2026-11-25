local ADDON = ADDON

ADDON.Name        = "Base Module"
ADDON.Author      = "Psalm Team"
ADDON.Description = "Core gameplay primitives"
ADDON.Version     = "1.0.0"

-- Pull in files that live outside the conventional subfolders
ADDON:Include("extra/sv_custom.lua")
-- Equivalent to:
-- Psalm.Loader:Include("addons/base/extra/custom.lua")

-- If you need not standart auto loading, just use that
-- ADDON.LoadOrder = { "config", "libraries", "gui" }