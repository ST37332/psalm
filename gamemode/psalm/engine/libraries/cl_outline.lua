---
-- @author https://github.com/WardenPotato and https://github.com/ShadowBonnieRUS
-- @module outline

local istable = istable
local render = render
local Material = Material
local CreateMaterial = CreateMaterial
local hook = hook
local cam = cam
local ScrW = ScrW
local ScrH = ScrH
local IsValid = IsValid
local surface = surface

if SERVER then
    AddCSLuaFile()

    return
end

outline = {}

OUTLINE_MODE_BOTH = 0
OUTLINE_MODE_NOTVISIBLE = 1
OUTLINE_MODE_VISIBLE = 2

OUTLINE_RENDERTYPE_BEFORE_VM = 0 -- Render before drawing the view model
OUTLINE_RENDERTYPE_BEFORE_EF = 1 -- Render before drawing all effects (after drawing the viewmodel)
OUTLINE_RENDERTYPE_AFTER_EF = 2  -- Render after drawing all effects

local Lists = {
    [OUTLINE_RENDERTYPE_BEFORE_VM] = {},
    [OUTLINE_RENDERTYPE_BEFORE_EF] = {},
    [OUTLINE_RENDERTYPE_AFTER_EF] = {},
}

local ListsSize = {
    [OUTLINE_RENDERTYPE_BEFORE_VM] = {},
    [OUTLINE_RENDERTYPE_BEFORE_EF] = {},
    [OUTLINE_RENDERTYPE_AFTER_EF] = {},
}

local RenderEnt = NULL
local RenderType = OUTLINE_RENDERTYPE_AFTER_EF
local OutlineThickness = 1
local texture_store = render.GetScreenEffectTexture(0)
local texture_draw = render.GetScreenEffectTexture(1)

local outline_mat_settings = {
    ["$basetexture"] = texture_draw:GetName(),
    ["$ignorez"] = 1,
    ["$alphatest"] = 1,
    ["$smooth"] = 0,
}
local outline_mat = CreateMaterial("ttt2_outline", "UnlitGeneric", outline_mat_settings)

local copy_mat = Material("pp/copy")

local ENTS = 1
local COLOR = 2
local MODE = 3

local function SetRenderType(render_type)
    if
        render_type ~= OUTLINE_RENDERTYPE_BEFORE_VM
        and render_type ~= OUTLINE_RENDERTYPE_BEFORE_EF
        and render_type ~= OUTLINE_RENDERTYPE_AFTER_EF
    then
        return
    end

    RenderType = render_type

    return true
end

local function GetRenderType()
    return RenderType
end

local function GetOutlineThickness()
    return OutlineThickness
end

local function SetOutlineThickness(thickness)
    if thickness < 1 then
        return
    end

    OutlineThickness = thickness

    return true
end

local function GetCurrentLists()
    return Lists[GetRenderType()]
end

local function GetCurrentListsSize()
    return ListsSize[GetRenderType()]
end

local function GetCurrentList()
    return Lists[GetRenderType()][GetOutlineThickness()]
end

local function GetCurrentListSize()
    return ListsSize[GetRenderType()][GetOutlineThickness()]
end

local function ResetCurrentLists()
    Lists[GetRenderType()] = {}
end

local function ResetCurrentListsSize()
    ListsSize[GetRenderType()] = {}
end

local function SetCurrentListSize(size)
    ListsSize[GetRenderType()][GetOutlineThickness()] = size
end

local function InitializeCurrentListIfNeeded()
    local render_type, outline_thickness = GetRenderType(), GetOutlineThickness()

    if not Lists[render_type] then
        Lists[render_type] = {}
    end

    if not ListsSize[render_type] then
        ListsSize[render_type] = {}
    end

    if not Lists[render_type][outline_thickness] then
        Lists[render_type][outline_thickness] = {}
    end

    if not ListsSize[render_type][outline_thickness] then
        ListsSize[render_type][outline_thickness] = 0
    end
end

---
-- Adds an outline to a given list of entities.
-- @param table ents List of @{Entity}
-- @param Color color The color of the added outline
-- @param number mode [OUTLINE_MODE_BOTH, OUTLINE_MODE_NOTVISIBLE, OUTLINE_MODE_VISIBLE]
-- @param number render_type [OUTLINE_RENDERTYPE_BEFORE_VM, OUTLINE_RENDERTYPE_BEFORE_EF, OUTLINE_RENDERTYPE_AFTER_EF]
-- @param number outline_thickness The thickness of the added outline in pixels
-- @realm client
function outline.Add(ents, color, mode, render_type, outline_thickness)
    -- Make the default behaviour comply with older revisions
    if not render_type then
        render_type = OUTLINE_RENDERTYPE_AFTER_EF
    end

    if not outline_thickness then
        outline_thickness = 1
    end

    -- Check for a validity
    if not SetRenderType(render_type) then
        return
    end

    if not SetOutlineThickness(outline_thickness) then
        return
    end

    -- Create list if it doesnt exist
    InitializeCurrentListIfNeeded()

    -- Get List and ListSize for this render type and outline thickness
    local List, ListSize = GetCurrentList(), GetCurrentListSize()

    -- Maximum 255 reference values
    if ListSize >= 255 then
        return
    end

    -- Support for passing Entity as first argument
    if not istable(ents) then
        ents = { ents }
    end

    -- Do not pass empty tables
    if ents[1] == nil then
        return
    end

    local t = {
        [ENTS] = ents,
        [COLOR] = color,
        [MODE] = mode or OUTLINE_MODE_BOTH,
    }

    ListSize = ListSize + 1
    SetCurrentListSize(ListSize)
    List[ListSize] = t
end

---
-- @return Entity The last rendered @{Entity}
-- @realm client
function outline.RenderedEntity()
    return RenderEnt
end

local function RenderModels(render_ents)
    for i = 1, #render_ents do
        local ent = render_ents[i]

        if IsValid(ent) then
            RenderEnt = ent
            ent:DrawModel(STUDIO_RENDER + STUDIO_NOSHADOWS)
        end
    end
end

local cvMaterialAntialias = GetConVar("mat_antialias")

local function Render()
    local scene = render.GetRenderTarget()

    -- Only draw inside of the actual main screen RT, prevents breaking addons and other rendering
    if scene ~= nil then
        return
    end

    render.CopyRenderTargetToTexture(texture_store)

    local w, h = ScrW(), ScrH()
    local List, ListSize = GetCurrentList(), GetCurrentListSize()
    local reference = 0

    -- Step 1: Render all entities into the stencil buffer
    render.ClearStencil()
    render.SetStencilEnable(true)
    render.SuppressEngineLighting(true)

    render.SetStencilWriteMask(0xFF)
    render.SetStencilTestMask(0xFF)
    render.SetStencilReferenceValue(0)
    render.SetStencilCompareFunction(STENCIL_GREATER)
    render.SetStencilPassOperation(STENCIL_KEEP)
    render.SetStencilFailOperation(STENCIL_KEEP)
    render.SetStencilZFailOperation(STENCIL_KEEP)

    -- FIX: No MaterialOverride, no OverrideColorWriteEnable, no OverrideDepthEnable.
    -- Drawing models normally into the stencil is sufficient and avoids the white flash.
    cam.Start3D()
        render.SetBlend(1)

        for i = 1, ListSize do
            reference = 0xFF - (i - 1)

            local data = List[i]
            local mode = data[MODE]
            local render_ents = data[ENTS]

            render.SetStencilReferenceValue(reference)

            if mode == OUTLINE_MODE_BOTH or mode == OUTLINE_MODE_VISIBLE then
                render.SetStencilCompareFunction(STENCIL_GREATER)
                render.SetStencilZFailOperation(
                    mode == OUTLINE_MODE_BOTH and STENCIL_REPLACE or STENCIL_KEEP
                )
                render.SetStencilFailOperation(STENCIL_KEEP)
                render.SetStencilPassOperation(STENCIL_REPLACE)

                RenderModels(render_ents)

            elseif mode == OUTLINE_MODE_NOTVISIBLE then
                -- First pass: mark pixels hidden by depth
                render.SetStencilCompareFunction(STENCIL_GREATER)
                render.SetStencilZFailOperation(STENCIL_REPLACE)
                render.SetStencilFailOperation(STENCIL_KEEP)
                render.SetStencilPassOperation(STENCIL_KEEP)

                RenderModels(render_ents)

                -- Second pass: erase pixels that are actually visible
                render.SetStencilCompareFunction(STENCIL_EQUAL)
                render.SetStencilZFailOperation(STENCIL_KEEP)
                render.SetStencilFailOperation(STENCIL_KEEP)
                render.SetStencilPassOperation(STENCIL_ZERO)

                RenderModels(render_ents)

                -- FIX: Restore compare function for subsequent list entries,
                -- otherwise the stencil state is corrupted for the next iteration.
                render.SetStencilCompareFunction(STENCIL_GREATER)
            end
        end

        RenderEnt = NULL
    cam.End3D()  -- FIX: End 3D context BEFORE Clear and 2D pass (was nested inside in original)

    -- Step 2: Configure stencil to only touch pixels we marked
    render.SetStencilCompareFunction(STENCIL_EQUAL)
    render.SetStencilZFailOperation(STENCIL_KEEP)
    render.SetStencilFailOperation(STENCIL_KEEP)
    render.SetStencilPassOperation(STENCIL_KEEP)

    -- Step 3: Clear screen to transparent (only affects pixels outside stencil)
    render.Clear(0, 0, 0, 0, false, false)

    -- Step 4: Draw solid colors over marked pixels
    cam.Start2D()
        for i = 1, ListSize do
            reference = 0xFF - (i - 1)
            render.SetStencilReferenceValue(reference)

            local col = List[i][COLOR]
            surface.SetDrawColor(col)
            surface.DrawRect(0, 0, w, h)
        end
    cam.End2D()

    render.SuppressEngineLighting(false)
    render.SetStencilEnable(false)

    -- Step 5: Copy solid-colored result into draw texture
    render.CopyRenderTargetToTexture(texture_draw)

    -- Step 6: Restore original screen
    copy_mat:SetTexture("$basetexture", texture_store)
    copy_mat:SetString("$color", "1 1 1")
    copy_mat:SetString("$alpha", "1")
    render.SetMaterial(copy_mat)
    render.DrawScreenQuad()

    -- Step 7: Draw outline by offsetting the solid-colored version 8 times
    -- Only on pixels outside the original entities (stencil == 0)
    render.SetStencilEnable(true)
    render.SetStencilReferenceValue(0)
    render.SetStencilCompareFunction(STENCIL_EQUAL)
    render.SetStencilZFailOperation(STENCIL_KEEP)
    render.SetStencilFailOperation(STENCIL_KEEP)
    render.SetStencilPassOperation(STENCIL_KEEP)

    outline_mat:SetTexture("$basetexture", texture_draw)
    render.SetMaterial(outline_mat)

    local outline_thickness = OutlineThickness
    if cvMaterialAntialias:GetInt() ~= 0 then
        outline_thickness = outline_thickness + 1
    end

    render.DrawScreenQuadEx(-outline_thickness, -outline_thickness, w, h)
    render.DrawScreenQuadEx(-outline_thickness, 0, w, h)
    render.DrawScreenQuadEx(-outline_thickness, outline_thickness, w, h)
    render.DrawScreenQuadEx(0, -outline_thickness, w, h)
    render.DrawScreenQuadEx(0, outline_thickness, w, h)
    render.DrawScreenQuadEx(outline_thickness, -outline_thickness, w, h)
    render.DrawScreenQuadEx(outline_thickness, 0, w, h)
    render.DrawScreenQuadEx(outline_thickness, outline_thickness, w, h)

    render.SetStencilEnable(false)
end

local function RenderOutlines()
    -- @realm client
    hook.Run("PreDrawOutlines", GetRenderType())

    local listSizes = GetCurrentListsSize()
    for outlineThickness, renderEnts in pairs(GetCurrentLists()) do
        if not listSizes[outlineThickness] or listSizes[outlineThickness] == 0 then
            continue
        end
        SetOutlineThickness(outlineThickness)
        Render()
    end

    ResetCurrentLists()
    ResetCurrentListsSize()
end

hook.Add("PreDrawViewModels", "RenderOutlines", function()
    SetRenderType(OUTLINE_RENDERTYPE_BEFORE_VM)
    RenderOutlines()
end)

hook.Add("PreDrawEffects", "RenderOutlines", function()
    SetRenderType(OUTLINE_RENDERTYPE_BEFORE_EF)
    RenderOutlines()
end)

hook.Add("PostDrawEffects", "RenderOutlines", function()
    SetRenderType(OUTLINE_RENDERTYPE_AFTER_EF)
    RenderOutlines()
end)