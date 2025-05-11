local GetEntityCoords = GetEntityCoords
local Wait = Wait
local GetEntityModel = GetEntityModel
local GetEntityType = GetEntityType
local PlayerPedId = PlayerPedId
local GetShapeTestResult = GetShapeTestResult
local StartShapeTestLosProbe = StartShapeTestLosProbe
local HasEntityClearLosToEntity = HasEntityClearLosToEntity
local currentResourceName = GetCurrentResourceName()
local Config = Config
local playerPed, pedsReady = PlayerPedId(), false
local screen = {}
local pairs = pairs
local pcall = pcall
local CheckOptions = CheckOptions
---------------------------------------
--- Source: https://github.com/citizenfx/lua/blob/luaglm-dev/cfx/libs/scripts/examples/scripting_gta.lua
--- Credits to gottfriedleibniz
local glm = require 'glm'

-- Cache common functions
local glm_rad = glm.rad
local glm_quatEuler = glm.quatEulerAngleZYX
local glm_rayPicking = glm.rayPicking

-- Cache direction vectors
local glm_up = glm.up()
local glm_forward = glm.forward()

local function ScreenPositionToCameraRay()
	local pos = GetFinalRenderedCamCoord()
	local rot = glm_rad(GetFinalRenderedCamRot(2))
	local q = glm_quatEuler(rot.z, rot.y, rot.x)
	return pos, glm_rayPicking(
		q * glm_forward,
		q * glm_up,
		glm_rad(screen.fov),
		screen.ratio,
		0.10000, -- GetFinalRenderedCamNearClip(),
		10000.0, -- GetFinalRenderedCamFarClip(),
		0, 0
	)
end
---------------------------------------

-- Functions

---@param qbto TargetOptions
---@return OxTargetOption[]
local function ConvertToOxTargetOptions(qbto)
	---@type OxTargetOption[]
	local oxto = {}
	for i, v in ipairs(qbto.options) do
		local canInteract = function (entity, distance, coords, name, bone)
			return CheckOptions(v, entity, distance)
		end
		local onSelect = function (data)
			---@diagnostic disable-next-line: inject-field
			v.entity = data.entity
			if v.action then
				v.action(data.entity) -- i dont know if it's an entityId (number) or a entity table (like SpawnPed's datatable). According to qb's docs it shows a entityId but in the code its shows as a table
			elseif v.event then
				if v.entity ~= nil then
					---@diagnostic disable-next-line: inject-field
					v.coords = GetEntityCoords(data.entity)
				end
				if v.type == 'client' then
					TriggerEvent(v.event, v)
				elseif v.type == 'server' then
					TriggerServerEvent(v.event, v)
				elseif v.type == 'command' then
					ExecuteCommand(v.event)
				elseif v.type == 'qbcommand' then
					TriggerServerEvent('QBCore:CallCommand', v.event, v)
				else
					TriggerEvent(v.event, v)
				end
			else
				error('No trigger setup')
			end
		end
		oxto[#oxto+1] = {
			name = v.label,
			label = v.label,
			icon = v.icon,
			distance = qbto.distance,
			items = v.item,
			canInteract = canInteract,
			onSelect = onSelect,
		}
	end
	return oxto
end

local function RaycastCamera(flag, playerCoords)
	if not playerPed then playerPed = PlayerPedId() end
	if not playerCoords then playerCoords = GetEntityCoords(playerPed) end

	local rayPos, rayDir = ScreenPositionToCameraRay()
	local destination = rayPos + 16 * rayDir
	local rayHandle = StartShapeTestLosProbe(rayPos.x, rayPos.y, rayPos.z, destination.x, destination.y, destination.z,
		flag or -1, playerPed, 4)

	while true do
		local result, _, endCoords, _, entityHit = GetShapeTestResult(rayHandle)

		if result ~= 1 then
			local distance = playerCoords and #(playerCoords - endCoords)

			if flag == 30 and entityHit then
				entityHit = HasEntityClearLosToEntity(entityHit, playerPed, 7) and entityHit
			end

			local entityType = entityHit and GetEntityType(entityHit)

			if entityType == 0 and pcall(GetEntityModel, entityHit) then
				entityType = 3
			end

			return endCoords, distance, entityHit, entityType or 0
		end

		Wait(0)
	end
end

exports('RaycastCamera', RaycastCamera)

local function DisableNUI() error("Cannot get NUI") end

exports('DisableNUI', DisableNUI)

local function EnableNUI(options) error("Cannot get NUI") end

exports('EnableNUI', EnableNUI)

local function LeftTarget() error("Cannot get NUI") end

exports('LeftTarget', LeftTarget)

local function DisableTarget(forcedisable) error("Cannot get NUI") end

exports('DisableTarget', DisableTarget)

local function DrawOutlineEntity(entity, bool)
	if not Config.EnableOutline or IsEntityAPed(entity) then return end
	SetEntityDrawOutline(entity, bool)
	SetEntityDrawOutlineColor(Config.OutlineColor[1], Config.OutlineColor[2], Config.OutlineColor[3], Config.OutlineColor[4])
end

exports('DrawOutlineEntity', DrawOutlineEntity)

local function CheckEntity(flag, datatable, entity, distance) error("Cannot get NUI") end

exports('CheckEntity', CheckEntity)

local function CheckBones(coords, entity, bonelist) error("Cannot translate Bones") end

exports('CheckBones', CheckBones)

local function AddCircleZone(name, center, radius, options, targetoptions)
	local centerType = type(center)
	center = (centerType == 'table' or centerType == 'vector4') and vec3(center.x, center.y, center.z) or center
	targetoptions.distance = targetoptions.distance or Config.MaxDistance
	local id = exports.ox_target:addSphereZone({
		coords = center,
		name = name,
		radius = radius,
		debug = options.debugPoly,
		options = ConvertToOxTargetOptions(targetoptions)
	})
	options.name = id
	options.data = options.data or {}
	options.isCircleZone = true
	options.targetoptions = targetoptions
	return options
end

exports('AddCircleZone', AddCircleZone)

local function AddBoxZone(name, center, length, width, options, targetoptions)
	local centerType = type(center)
	center = (centerType == 'table' or centerType == 'vector4') and vec3(center.x, center.y, center.z) or center
	targetoptions.distance = targetoptions.distance or Config.MaxDistance
	local height
	if options.minZ and options.maxZ then
		height = options.maxZ - options.minZ
	end
	local id = exports.ox_target:addBoxZone({
		coords = center,
		name = name,
		size = vector3(width, length, height or Config.MaxHeight),
		rotation = options.heading,
		debug = options.debugPoly,
		options = ConvertToOxTargetOptions(targetoptions)
	})
	options.name = id
	options.data = options.data or {}
	options.isBoxZone = true
	options.targetoptions = targetoptions
	return options
end

exports('AddBoxZone', AddBoxZone)

local function AddPolyZone(name, points, options, targetoptions)
	local _points = {}
	local pointsType = type(points[1])
	if pointsType == 'table' or pointsType == 'vector3' or pointsType == 'vector4' then
		for i = 1, #points do
			_points[i] = vec2(points[i].x, points[i].y)
		end
	end
	local height
	if options.minZ and options.maxZ then
		height = options.maxZ - options.minZ
	end
	targetoptions.distance = targetoptions.distance or Config.MaxDistance
	local id = exports.ox_target:addPolyZone({
		points = #_points > 0 and _points or points,
		name = name,
		thickness = height or 4.0,
		debug = options.debugPoly,
		options = ConvertToOxTargetOptions(targetoptions)
	})
	options.name = id
	options.data = options.data or {}
	options.isPolyZone = true
	options.targetoptions = targetoptions
	return options
end

exports('AddPolyZone', AddPolyZone)

local function AddComboZone(zones, options, targetoptions)
	error("Cannot translate ComboZones")
end

exports('AddComboZone', AddComboZone)

local function AddEntityZone(name, entity, options, targetoptions)
	targetoptions.distance = targetoptions.distance or Config.MaxDistance
	exports.ox_target:addLocalEntity(entity, ConvertToOxTargetOptions(targetoptions))
	options.entity = entity
	options.data = options.data or {}
	options.isEntityZone = true
	options.targetoptions = targetoptions
	return options
end

exports('AddEntityZone', AddEntityZone)

local function RemoveZone(name)
	exports.ox_target:removeZone(name)
end

exports('RemoveZone', RemoveZone)

local function SetOptions(tbl, distance, options)
	for _, v in pairs(options) do
		if v.required_item then
			v.item = v.required_item
			v.required_item = nil
		end
		if not v.distance or v.distance > distance then v.distance = distance end
		tbl[#tbl+1] = v
	end
end

local function AddTargetBone(bones, parameters) error("Cannot translate Bones") end

exports('AddTargetBone', AddTargetBone)

local function RemoveTargetBone(bones, labels) error("Cannot translate Bones") end

exports('RemoveTargetBone', RemoveTargetBone)

local function AddTargetEntity(entities, parameters)
	local distance, options = parameters.distance or Config.MaxDistance, parameters.options
	local targetoptions = {}
	SetOptions(targetoptions, distance, options)
	exports.ox_target:addLocalEntity(entities, ConvertToOxTargetOptions(targetoptions))
end

exports('AddTargetEntity', AddTargetEntity)

local function RemoveTargetEntity(entities, labels)
	exports.ox_target:removeLocalEntity(entities, labels)
end

exports('RemoveTargetEntity', RemoveTargetEntity)

local function AddTargetModel(models, parameters)
	local distance, options = parameters.distance or Config.MaxDistance, parameters.options
	local targetoptions = {}
	SetOptions(targetoptions, distance, options)
	exports.ox_target:addModel(models, ConvertToOxTargetOptions(targetoptions))
end

exports('AddTargetModel', AddTargetModel)

local function RemoveTargetModel(models, labels)
	exports.ox_target:removeLocalEntity(models, labels)
end

exports('RemoveTargetModel', RemoveTargetModel)

local function AddGlobalType(type, parameters)
	local distance, options = parameters.distance or Config.MaxDistance, parameters.options
	local targetoptions = {}
	SetOptions(targetoptions, distance, options)
	if type == 1 then -- Ped
		exports.ox_target:addGlobalPed(ConvertToOxTargetOptions(targetoptions))
		return
	end
	if type == 2 then -- Vehicle
		exports.ox_target:addGlobalVehicle(ConvertToOxTargetOptions(targetoptions))
		return
	end
	if type == 3 then -- Object
		exports.ox_target:addGlobalObject(ConvertToOxTargetOptions(targetoptions))
		return
	end
end

exports('AddGlobalType', AddGlobalType)

local function AddGlobalPed(parameters) AddGlobalType(1, parameters) end

exports('AddGlobalPed', AddGlobalPed)

local function AddGlobalVehicle(parameters) AddGlobalType(2, parameters) end

exports('AddGlobalVehicle', AddGlobalVehicle)

local function AddGlobalObject(parameters) AddGlobalType(3, parameters) end

exports('AddGlobalObject', AddGlobalObject)

local function AddGlobalPlayer(parameters)
	local distance, options = parameters.distance or Config.MaxDistance, parameters.options
	local targetoptions = {}
	SetOptions(targetoptions, distance, options)
	exports.ox_target:addGlobalPlayer(ConvertToOxTargetOptions(targetoptions))
end

exports('AddGlobalPlayer', AddGlobalPlayer)

local function RemoveGlobalType(typ, labels)
	if labels then
		error("labels is required for conversion")
	end
	if typ == 1 then -- Ped
		exports.ox_target:removeGlobalPed(labels)
		return
	end
	if typ == 2 then -- Vehicle
		exports.ox_target:removeGlobalVehicle(labels)
		return
	end
	if typ == 3 then -- Object
		exports.ox_target:removeGlobalObject(labels)
		return
	end
end

exports('RemoveGlobalType', RemoveGlobalType)

local function RemoveGlobalPlayer(labels)
	if labels then
		error("labels is required for conversion")
	end
	exports.ox_target:removeGlobalPlayer(labels)
end

exports('RemoveGlobalPlayer', RemoveGlobalPlayer)

local function _SpawnPed(data)
	local spawnedped
	RequestModel(data.model)
	while not HasModelLoaded(data.model) do
		Wait(0)
	end

	if type(data.model) == 'string' then data.model = joaat(data.model) end

	if data.minusOne then
		spawnedped = CreatePed(0, data.model, data.coords.x, data.coords.y, data.coords.z - 1.0, data.coords.w,
			data.networked or false, true)
	else
		spawnedped = CreatePed(0, data.model, data.coords.x, data.coords.y, data.coords.z, data.coords.w,
			data.networked or false, true)
	end

	if data.freeze then
		FreezeEntityPosition(spawnedped, true)
	end

	if data.invincible then
		SetEntityInvincible(spawnedped, true)
	end

	if data.blockevents then
		SetBlockingOfNonTemporaryEvents(spawnedped, true)
	end

	if data.animDict and data.anim then
		RequestAnimDict(data.animDict)
		while not HasAnimDictLoaded(data.animDict) do
			Wait(0)
		end

		TaskPlayAnim(spawnedped, data.animDict, data.anim, 8.0, 0, -1, data.flag or 1, 0, false, false, false)
	end

	if data.scenario then
		SetPedCanPlayAmbientAnims(spawnedped, true)
		TaskStartScenarioInPlace(spawnedped, data.scenario, 0, true)
	end

	if data.pedrelations then
		if type(data.pedrelations.groupname) ~= 'string' then
			error(data.pedrelations.groupname ..
				' is not a string')
		end

		local pedgrouphash = joaat(data.pedrelations.groupname)

		if not DoesRelationshipGroupExist(pedgrouphash) then
			AddRelationshipGroup(data.pedrelations.groupname)
		end

		SetPedRelationshipGroupHash(spawnedped, pedgrouphash)
		if data.pedrelations.toplayer then
			SetRelationshipBetweenGroups(data.pedrelations.toplayer, pedgrouphash, joaat('PLAYER'))
		end

		if data.pedrelations.toowngroup then
			SetRelationshipBetweenGroups(data.pedrelations.toowngroup, pedgrouphash, pedgrouphash)
		end
	end

	if data.weapon then
		if type(data.weapon.name) == 'string' then data.weapon.name = joaat(data.weapon.name) end

		if IsWeaponValid(data.weapon.name) then
			SetCanPedEquipWeapon(spawnedped, data.weapon.name, true)
			GiveWeaponToPed(spawnedped, data.weapon.name, data.weapon.ammo, data.weapon.hidden or false, true)
			SetPedCurrentWeaponVisible(spawnedped, not data.weapon.hidden or false, true)
		end
	end

	if data.target then
		if data.target.useModel then
			AddTargetModel(data.model, {
				options = data.target.options,
				distance = data.target.distance
			})
		else
			AddTargetEntity(spawnedped, {
				options = data.target.options,
				distance = data.target.distance
			})
		end
	end

	data.currentpednumber = spawnedped

	if data.action then
		data.action(data)
	end
end

function SpawnPeds()
	if pedsReady or not next(Config.Peds) then return end
	for k, v in pairs(Config.Peds) do
		if not v.currentpednumber or v.currentpednumber == 0 then
			_SpawnPed(v)
		end
	end
	pedsReady = true
end

function DeletePeds()
	if not pedsReady or not next(Config.Peds) then return end
	for k, v in pairs(Config.Peds) do
		DeletePed(v.currentpednumber)
		Config.Peds[k].currentpednumber = 0
	end
	pedsReady = false
end

exports('DeletePeds', DeletePeds)


local function SpawnPed(data)
	local key, value = next(data)
	if type(value) == 'table' and type(key) ~= 'string' then
		for _, v in pairs(data) do
			if v.spawnNow then
				_SpawnPed(v)
			end

			local nextnumber = #Config.Peds + 1
			if nextnumber <= 0 then nextnumber = 1 end

			Config.Peds[nextnumber] = v
		end
	else
		if data.spawnNow then
			_SpawnPed(data)
		end

		local nextnumber = #Config.Peds + 1
		if nextnumber <= 0 then nextnumber = 1 end

		Config.Peds[nextnumber] = data
	end
end

exports('SpawnPed', SpawnPed)

local function RemovePed(peds)
	if type(peds) == 'table' then
		for k, v in pairs(peds) do
			DeletePed(v)
			if Config.Peds[k] then Config.Peds[k].currentpednumber = 0 end
		end
	elseif type(peds) == 'number' then
		DeletePed(peds)
	end
end

exports('RemoveSpawnedPed', RemovePed)

-- Misc. Exports

local function RemoveGlobalPed(labels) RemoveGlobalType(1, labels) end
exports('RemoveGlobalPed', RemoveGlobalPed)

local function RemoveGlobalVehicle(labels) RemoveGlobalType(2, labels) end
exports('RemoveGlobalVehicle', RemoveGlobalVehicle)

local function RemoveGlobalObject(labels) RemoveGlobalType(3, labels) end
exports('RemoveGlobalObject', RemoveGlobalObject)

local function IsTargetActive() return error("Cannot Convert IsTargetActive") end
exports('IsTargetActive', IsTargetActive)

local function IsTargetSuccess() return error("Cannot Convert IsTargetSuccess") end
exports('IsTargetSuccess', IsTargetSuccess)

local function GetGlobalTypeData(type, label) return error("Cannot Convert GetGlobalTypeData") end
exports('GetGlobalTypeData', GetGlobalTypeData)

local function GetZoneData(name) return error("Cannot Get Target Info") end
exports('GetZoneData', GetZoneData)

local function GetTargetBoneData(bone, label) return error("Cannot Get Target Info") end
exports('GetTargetBoneData', GetTargetBoneData)

local function GetTargetEntityData(entity, label) return error("Cannot Get Target Info") end
exports('GetTargetEntityData', GetTargetEntityData)

local function GetTargetModelData(model, label) return error("Cannot Get Target Info") end
exports('GetTargetModelData', GetTargetModelData)

local function GetGlobalPedData(label) return error("Cannot Get Target Info") end
exports('GetGlobalPedData', GetGlobalPedData)

local function GetGlobalVehicleData(label) return error("Cannot Get Target Info") end
exports('GetGlobalVehicleData', GetGlobalVehicleData)

local function GetGlobalObjectData(label) return error("Cannot Get Target Info") end
exports('GetGlobalObjectData', GetGlobalObjectData)

local function GetGlobalPlayerData(label) return error("Cannot Get Target Info") end
exports('GetGlobalPlayerData', GetGlobalPlayerData)

local function UpdateGlobalTypeData(type, label, data) error("Cannot Get Target Info") end
exports('UpdateGlobalTypeData', UpdateGlobalTypeData)

local function UpdateZoneData(name, data) error("Cannot Get Target Info") end
exports('UpdateZoneData', UpdateZoneData)

local function UpdateTargetBoneData(bone, label, data) error("Cannot Get Target Info") end
exports('UpdateTargetBoneData', UpdateTargetBoneData)

local function UpdateTargetEntityData(entity, label, data) error("Cannot Get Target Info") end
exports('UpdateTargetEntityData', UpdateTargetEntityData)

local function UpdateTargetModelData(model, label, data) error("Cannot Get Target Info") end
exports('UpdateTargetModelData', UpdateTargetModelData)

local function UpdateGlobalPedData(label, data) error("Cannot Get Target Info") end
exports('UpdateGlobalPedData', UpdateGlobalPedData)

local function UpdateGlobalVehicleData(label, data) error("Cannot Get Target Info") end
exports('UpdateGlobalVehicleData', UpdateGlobalVehicleData)

local function UpdateGlobalObjectData(label, data) error("Cannot Get Target Info") end
exports('UpdateGlobalObjectData', UpdateGlobalObjectData)

local function UpdateGlobalPlayerData(label, data) error("Cannot Get Target Info") end
exports('UpdateGlobalPlayerData', UpdateGlobalPlayerData)

local function GetPeds() return Config.Peds end
exports('GetPeds', GetPeds)

local function UpdatePedsData(index, data) Config.Peds[index] = data end
exports('UpdatePedsData', UpdatePedsData)

local function AllowTargeting(bool)
	exports.ox_target:disableTargeting(bool)
end
exports('AllowTargeting', AllowTargeting)

-- Events

-- This is to make sure the peds spawn on restart too instead of only when you load/log-in.
AddEventHandler('onResourceStart', function(resource)
	if resource ~= currentResourceName then return end
	SpawnPeds()
end)

-- This will delete the peds when the resource stops to make sure you don't have random peds walking
AddEventHandler('onResourceStop', function(resource)
	if resource ~= currentResourceName then return end
	DeletePeds()
end)

-- qtarget interoperability

local qtargetExports = {
	['raycast'] = RaycastCamera,
	['DisableNUI'] = DisableNUI,
	['LeaveTarget'] = LeftTarget,
	['DisableTarget'] = DisableTarget,
	['DrawOutlineEntity'] = DrawOutlineEntity,
	['CheckEntity'] = CheckEntity,
	['CheckBones'] = CheckBones,
	['AddCircleZone'] = AddCircleZone,
	['AddBoxZone'] = AddBoxZone,
	['AddPolyZone'] = AddPolyZone,
	['AddComboZone'] = AddComboZone,
	['AddEntityZone'] = AddEntityZone,
	['RemoveZone'] = RemoveZone,
	['AddTargetBone'] = AddTargetBone,
	['RemoveTargetBone'] = RemoveTargetBone,
	['AddTargetEntity'] = AddTargetEntity,
	['RemoveTargetEntity'] = RemoveTargetEntity,
	['AddTargetModel'] = AddTargetModel,
	['RemoveTargetModel'] = RemoveTargetModel,
	['Ped'] = AddGlobalPed,
	['Vehicle'] = AddGlobalVehicle,
	['Object'] = AddGlobalObject,
	['Player'] = AddGlobalPlayer,
	['RemovePed'] = RemoveGlobalPed,
	['RemoveVehicle'] = RemoveGlobalVehicle,
	['RemoveObject'] = RemoveGlobalObject,
	['RemovePlayer'] = RemoveGlobalPlayer,
	['IsTargetActive'] = IsTargetActive,
	['IsTargetSuccess'] = IsTargetSuccess,
	['GetType'] = GetGlobalTypeData,
	['GetZone'] = GetZoneData,
	['GetTargetBone'] = GetTargetBoneData,
	['GetTargetEntity'] = GetTargetEntityData,
	['GetTargetModel'] = GetTargetModelData,
	['GetPed'] = GetGlobalPedData,
	['GetVehicle'] = GetGlobalVehicleData,
	['GetObject'] = GetGlobalObjectData,
	['GetPlayer'] = GetGlobalPlayerData,
	['UpdateType'] = UpdateGlobalTypeData,
	['UpdateZoneOptions'] = UpdateZoneData,
	['UpdateTargetBone'] = UpdateTargetBoneData,
	['UpdateTargetEntity'] = UpdateTargetEntityData,
	['UpdateTargetModel'] = UpdateTargetModelData,
	['UpdatePed'] = UpdateGlobalPedData,
	['UpdateVehicle'] = UpdateGlobalVehicleData,
	['UpdateObject'] = UpdateGlobalObjectData,
	['UpdatePlayer'] = UpdateGlobalPlayerData,
	['AllowTargeting'] = AllowTargeting
}

for exportName, func in pairs(qtargetExports) do
	AddEventHandler(('__cfx_export_qtarget_%s'):format(exportName), function(setCB)
		setCB(func)
	end)
end

-- qbtarget interoperability

local qbtargetExports = {
	['RaycastCamera'] = RaycastCamera,
	['DisableNUI'] = DisableNUI,
	['EnableNUI'] = EnableNUI,
	['LeftTarget'] = LeftTarget,
	['DisableTarget'] = DisableTarget,
	['DrawOutlineEntity'] = DrawOutlineEntity,
	['CheckEntity'] = CheckEntity,
	['CheckBones'] = CheckBones,
	['AddCircleZone'] = AddCircleZone,
	['AddBoxZone'] = AddBoxZone,
	['AddPolyZone'] = AddPolyZone,
	['AddComboZone'] = AddComboZone,
	['AddEntityZone'] = AddEntityZone,
	['RemoveZone'] = RemoveZone,
	['AddTargetBone'] = AddTargetBone,
	['RemoveTargetBone'] = RemoveTargetBone,
	['AddTargetEntity'] = AddTargetEntity,
	['RemoveTargetEntity'] = RemoveTargetEntity,
	['AddTargetModel'] = AddTargetModel,
	['RemoveTargetModel'] = RemoveTargetModel,
	['AddGlobalType'] = AddGlobalType,
	['AddGlobalPed'] = AddGlobalPed,
	['AddGlobalVehicle'] = AddGlobalVehicle,
	['AddGlobalObject'] = AddGlobalObject,
	['AddGlobalPlayer'] = AddGlobalPlayer,
	['RemoveGlobalType'] = RemoveGlobalType,
	['RemoveGlobalPlayer'] = RemoveGlobalPlayer,
	['DeletePeds'] = DeletePeds,
	['SpawnPed'] = SpawnPed,
	['RemoveSpawnedPed'] = RemovePed,
	['RemoveGlobalPed'] = RemoveGlobalPed,
	['RemoveGlobalVehicle'] = RemoveGlobalVehicle,
	['RemoveGlobalObject'] = RemoveGlobalObject,
	['IsTargetActive'] = IsTargetActive,
	['IsTargetSuccess'] = IsTargetSuccess,
	['GetGlobalTypeData'] = GetGlobalTypeData,
	['GetZoneData'] = GetZoneData,
	['GetTargetBoneData'] = GetTargetBoneData,
	['GetTargetEntityData'] = GetTargetEntityData,
	['GetTargetModelData'] = GetTargetModelData,
	['GetGlobalPedData'] = GetGlobalPedData,
	['GetGlobalVehicleData'] = GetGlobalVehicleData,
	['GetGlobalObjectData'] = GetGlobalObjectData,
	['GetGlobalPlayerData'] = GetGlobalPlayerData,
	['UpdateGlobalTypeData'] = UpdateGlobalTypeData,
	['UpdateZoneData'] = UpdateZoneData,
	['UpdateTargetBoneData'] = UpdateTargetBoneData,
	['UpdateTargetEntityData'] = UpdateTargetEntityData,
	['UpdateTargetModelData'] = UpdateTargetModelData,
	['UpdateGlobalPedData'] = UpdateGlobalPedData,
	['UpdateGlobalVehicleData'] = UpdateGlobalVehicleData,
	['UpdateGlobalObjectData'] = UpdateGlobalObjectData,
	['UpdateGlobalPlayerData'] = UpdateGlobalPlayerData,
	['GetPeds'] = GetPeds,
	['UpdatePedsData'] = UpdatePedsData,
	['AllowTargeting'] = AllowTargeting,
}

for exportName, func in pairs(qbtargetExports) do
	AddEventHandler(('__cfx_export_qb-target_%s'):format(exportName), function(setCB)
		setCB(func)
	end)
end
