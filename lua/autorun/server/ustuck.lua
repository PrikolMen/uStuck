local GetPos, SetPos, IsValid, GetMoveType, GetPhysicsObject, GetCollisionBounds
do
	local _obj_0 = FindMetaTable("Entity")
	GetPos, SetPos, IsValid, GetMoveType, GetPhysicsObject, GetCollisionBounds = _obj_0.GetPos, _obj_0.SetPos, _obj_0.IsValid, _obj_0.GetMoveType, _obj_0.GetPhysicsObject, _obj_0.GetCollisionBounds
end
local Alive, IsPlayingTaunt
do
	local _obj_0 = FindMetaTable("Player")
	Alive, IsPlayingTaunt = _obj_0.Alive, _obj_0.IsPlayingTaunt
end
local SetUnpacked
do
	local _obj_0 = FindMetaTable("Vector")
	SetUnpacked = _obj_0.SetUnpacked
end
local resume, yield, wait = coroutine.resume, coroutine.yield, coroutine.wait
local sqrt, sin, cos, random = math.sqrt, math.sin, math.cos, math.random
local MOVETYPE_WALK = MOVETYPE_WALK
local Iterator = player.Iterator
local TraceHull = util.TraceHull
local Run = hook.Run
local addonName = "Unknown Stuck - AntiPlayerStuck Solution"
local phi = math.pi * (sqrt(5) - 1)
local downOffset = Vector(0, 0, -128)
local traceResult = { }
local trace = {
	collisiongroup = COLLISION_GROUP_PLAYER,
	mask = MASK_PLAYERSOLID,
	output = traceResult
}
local samples, y, theta, radius = 0, 0, 0, 0
local tempVector = Vector()
local stuckType = 0
local entity, start, phys, phys2
local thread = coroutine.create(function()
	while true do
		for _, ply in Iterator() do
			if not IsValid(ply) then
				goto solved
			end
			if ply.m_iOldStuckCollisionGroup ~= nil then
				ply:SetCollisionGroup(ply.m_iOldStuckCollisionGroup or 5)
			end
			if not Alive(ply) then
				goto solved
			end
			if GetMoveType(ply) ~= MOVETYPE_WALK or IsPlayingTaunt(ply) then
				goto solved
			end
			phys = GetPhysicsObject(ply)
			if not (phys and phys:IsValid()) then
				goto solved
			end
			trace.mins, trace.maxs = GetCollisionBounds(ply)
			start = GetPos(ply)
			trace.endpos = start
			trace.start = start
			trace.filter = ply
			TraceHull(trace)
			if not traceResult.Hit then
				goto solved
			end
			entity = traceResult.Entity
			if IsValid(entity) then
				if entity:IsRagdoll() then
					goto solved
				end
				if entity:IsPlayer() then
					if not (entity:Alive() and entity:GetAvoidPlayers()) then
						goto solved
					end
					stuckType = 3
				else
					phys2 = GetPhysicsObject(entity)
					if phys2 and phys2:IsValid() then
						if phys2:IsMoveable() and phys2:IsMotionEnabled() then
							if not (phys2:IsPenetrating() and phys2:GetMass() >= phys:GetMass()) then
								goto solved
							end
							stuckType = 2
						else
							stuckType = 1
						end
					end
				end
			else
				stuckType = 1
			end
			if Run("PlayerStuck", ply, traceResult, stuckType) == false then
				goto solved
			end
			if stuckType == 3 then
				entity.m_iOldStuckCollisionGroup = entity:GetCollisionGroup()
				entity:SetCollisionGroup(15)
				ply.m_iOldStuckCollisionGroup = ply:GetCollisionGroup()
				ply:SetCollisionGroup(15)
				SetUnpacked(tempVector, random(0, 1) == 0 and -512 or 512, random(0, 1) == 0 and -512 or 512, 128)
				ply:SetVelocity(tempVector)
				wait(0.25)
				goto solved
			end
			if stuckType == 2 then
				goto solved
			end
			if stuckType == 1 then
				for j = 1, 3 do
					samples = 16 * j
					for i = 0, samples do
						y, theta = 1 - (i / (samples - 1)) * 2, phi * i
						radius = sqrt(1 - y * y)
						SetUnpacked(tempVector, cos(theta) * radius, y, sin(theta) * radius)
						trace.start = start + tempVector * 128 * j
						trace.endpos = trace.start
						TraceHull(trace)
						if not traceResult.Hit then
							trace.endpos = trace.start + downOffset
							TraceHull(trace)
							SetPos(ply, traceResult.HitPos)
							stuckType = 0
							break
						end
					end
					if stuckType == 0 then
						break
					end
				end
			end
			if stuckType ~= 0 then
				local spawnPoint = Run("PlayerSelectSpawn", ply, false)
				if spawnPoint and IsValid(spawnPoint) then
					SetPos(ply, GetPos(spawnPoint))
				else
					SetPos(ply, vector_origin)
				end
			end
			::solved::
			yield()
		end
		yield()
	end
end)
do
	local ustuck_enabled = CreateConVar("ustuck_enabled", "1", FCVAR_ARCHIVE, "Enable unstuck logic for players."):GetBool()
	cvars.AddChangeCallback("ustuck_enabled", function(_, __, value)
		ustuck_enabled = value == "1"
	end, addonName)
	local ok, msg = false, nil
	return timer.Create(addonName, 0.05, 0, function()
		if not ustuck_enabled then
			return
		end
		ok, msg = resume(thread)
		if not ok then
			return ErrorNoHaltWithStack(msg)
		end
	end)
end
