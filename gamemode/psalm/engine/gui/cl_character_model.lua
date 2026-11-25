FaceSkins = {
	[ "male01" ] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 },
	[ "male02" ] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 },
	[ "male03" ] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 },
	[ "male04" ] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 },
	[ "male05" ] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 },
	[ "male06" ] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 },
	[ "male07" ] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 },
	[ "male08" ] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 },
	[ "male09" ] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 },
	[ "male10" ] = { 0, 1, 2 }, -- Old man don't have too many faces
	[ "female_01" ] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 },
	[ "female_02" ] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 },
	[ "female_03" ] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 },
	[ "female_04" ] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 },
	[ "female_06" ] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 },
	[ "female_07" ] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 }
}

function SetFaceID( eEnt, nOverrideFaceID, nOverrideModelBase )
	local sModelBase = nOverrideModelBase or eEnt.GetModelBase and eEnt:GetModelBase()
	if not sModelBase then print("[ERROR] Tried to SetFaceID but sModelBase was not valid") return end

	local tFaceData = FaceSkins[ sModelBase ]
	if not tFaceData then print("[ERROR] Tried to SetFaceID but tFaceData was not valid") return end

	local nFaces = #tFaceData
	if nFaces <= 0 then print("[ERROR] Tried to SetFaceID but no faces found") return end

	local nFaceID = nOverrideFaceID or ( eEnt.GetFaceID and eEnt:GetFaceID() ) or 1

	local bFoundFace = false
	for i = 0, nFaces do
		if tFaceData[ i ] == nFaceID then
			bFoundFace = true
			break
		end
	end

	if not bFoundFace then return end

	eEnt:SetSkin( nFaceID )
end

function GetBodyGroups( pPlayer )
    if not IsValid( pPlayer ) or not pPlayer:IsPlayer() then return "000000000" end
    if not pPlayer.Inventory then return "000000000" end

    local tInventory = pPlayer.Inventory
    local sBodyGroups = "0"

    for iSlot, tSlotData, tItem in tInventory:GetEquippedApparel() do
        local sBodygroup = tItem and tItem.Bodygroup or 0

        sBodyGroups = sBodyGroups .. sBodygroup
    end

    return sBodyGroups
end

function CreateClientModel( pPos, aAng )
	local pLocalPlayer = LocalPlayer()
	local eClientModel = ClientsideModel( pLocalPlayer:GetModel() )
	eClientModel:SetModelScale( 1, 0 )
	if pPos then
		eClientModel:SetPos( pPos )
	end
	if aAng then
		eClientModel:SetAngles( aAng )
	end
	eClientModel:SetSkin( pLocalPlayer:GetSkin() )

	for _, tData in pairs( pLocalPlayer:GetBodyGroups() ) do
		eClientModel:SetBodygroup( tData.id, pLocalPlayer:GetBodygroup( tData.id ) )
	end

	return eClientModel
end

local CHARACTER_MODEL = { }

function CHARACTER_MODEL:Init()
	self.mx = 0
	self.my = 0
	timer.Simple( .1, function()
		if not IsValid( self ) then return end

		local centerx , centery = self:LocalToScreen( self:GetWide() * .5 , self:GetTall() * .5 )
		input.SetCursorPos( centerx , centery )

		self.mx = centerx
		self.my = centery
	end )

	self.mx = centerx
	self.my = centery
end

function CHARACTER_MODEL:GetBones( bBody )
	local eEnt = self:GetEntity()
	for i = 1 , eEnt:GetBoneCount() do
		local sBone = eEnt:GetBoneName( i )
		if sBone == "ValveBiped.Bip01_Head1" then
			self.HeadID = k
			self.HeadPos, self.HeadAng = eEnt:GetBonePosition( i )

			if not bBody then break end
		end
		if sBone == "ValveBiped.Bip01_Spine1" then
			self.SpineID = i

			if self.HeadID then break end
		end
	end

	if not self.HeadID then
		self.HeadID = -1
	end

	eEnt:SetColor( Color( 255, 255, 255, 255 ) )
end

function CHARACTER_MODEL:Think()
	if self.IsWaitingToBones then
		local eEnt = self:GetEntity()
		if eEnt:GetBoneName( 1 ) == "__INVALIDBONE__" then return end

		self.LayoutEntity = function( this, eLayoutEnt )
			if not self.HeadID then
				self:GetBones( self.follower )
			end

			eLayoutEnt:SetAngles( Angle( 0, 15, 0 ) )
			
			eLayoutEnt:SetSequence( self.sOverrideAnim or IsValid(self.Player) and self.Player:GetJobPreviewAnim() or "idle_subtle" )
		end

		self.IsWaitingToBones = false
	end
end

function CHARACTER_MODEL:SetFollower( bBodyRotation, sAnim )
	self.follower = bBodyRotation
	self.IsWaitingToBones = true
	self.sOverrideAnim = sAnim

	self:GetEntity():SetColor( Color( 255, 255, 255, 0 ) )
end

function CHARACTER_MODEL:SetPlayer( pPlayer )
	if not IsValid( pPlayer ) then return end

	local eEnt = CreateClientModel()
	eEnt:SetModel( pPlayer:GetModel() or "models/willardnetworks/citizens/male07.mdl" )
	
	if pPlayer:IsPlayer() and pPlayer:GetJobTable() and pPlayer:GetJobTable().allowCosmetics then
		eEnt:BuildCosmetics( true, nil, pPlayer )

		self.PostDrawModel = function( this, _ )
			eEnt:DrawCosmetics( pPlayer )
		end
	end

	self:SetEntity( eEnt )

	self:SetCamPos( Vector( 100, 0, 80 ) )
	self:SetLookAt( Vector( 0, 0, 38 ) )
	self:SetFOV( 24 )
	self:SetAmbientLight( Color( 20, 150, 255, 255 ) )
	self:SetDirectionalLight( BOX_FRONT, Color( 255, 150, 100 ) )
	self:SetAnimated( false )

	self:SetDirectionalLight( BOX_TOP, Color( 255, 255, 255 ) )
	self:SetDirectionalLight( BOX_FRONT, Color( 200, 200, 200 ) )
	self:SetDirectionalLight( BOX_RIGHT, Color( 100, 100, 100 ) )
	self:SetDirectionalLight( BOX_LEFT, Color( 100, 100, 100 ) )
	self:SetDirectionalLight( BOX_BOTTOM, Color( 100, 100, 100 ) )

	SetFaceID( eEnt, pPlayer:GetFaceID(), pPlayer:GetModelBase() )

	-- Assign the player's own body groups if they are a citizen
	if pPlayer:IsPlayer() and pPlayer:Team() == TEAM_CITIZEN then
		eEnt:SetBodyGroups( GetBodyGroups( pPlayer ) )
	else
		local tJob = pPlayer:GetJobTable()
		if tJob and tJob.bodyGroups then
			eEnt:SetBodyGroups( tJob.bodyGroups )
		end
	end

	self.Player = pPlayer
end

function CHARACTER_MODEL:OnRemove()
	local eEnt = self:GetEntity()
	if not IsValid( eEnt ) then return end

	eEnt:Remove()
end

vgui.Register( "psCharacterModel" , CHARACTER_MODEL , "DModelPanel" )


--[[
	© 2025 Thriving Ventures AB, do not share, re-distribute or modify

	without permission of its author (gustaf@thrivingventures.com).
]]

local PSALM_MODEL = { }

function PSALM_MODEL:Init()
	self:SetCamPos( Vector( 100, 0, 50 ) )
	self:SetLookAt( Vector( 0, 0, 20 ) )
	self:SetFOV( 55 )
	self:SetAmbientLight( Color( 20, 150, 255, 255 ) )
	self:SetDirectionalLight( BOX_FRONT, Color( 255, 150, 100 ) )
	self:SetAnimated( false )

	self:SetDirectionalLight( BOX_TOP, Color( 255, 255, 255 ) )
	self:SetDirectionalLight( BOX_FRONT, Color( 200, 200, 200 ) )
	self:SetDirectionalLight( BOX_RIGHT, Color( 100, 100, 100 ) )
	self:SetDirectionalLight( BOX_LEFT, Color( 100, 100, 100 ) )
	self:SetDirectionalLight( BOX_BOTTOM, Color( 100, 100, 100 ) )
end

function PSALM_MODEL:OnRemove()
	local eEnt = self:GetEntity()
	if not IsValid( eEnt ) then return end

	eEnt:Remove()
end

vgui.Register( "psModelPanel" , PSALM_MODEL , "DModelPanel" )
