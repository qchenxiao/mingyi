--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : ����ٿ�
-- @author   : ���� @˫���� @׷����Ӱ
-- @modifier : Emil Zhai (root@derzh.com)
-- @copyright: Copyright (c) 2013 EMZ Kingsoft Co., Ltd.
--------------------------------------------------------
-------------------------------------------------------------------------------------------------------
-- these global functions are accessed all the time by the event handler
-- so caching them is worth the effort
-------------------------------------------------------------------------------------------------------
local ipairs, pairs, next, pcall, select = ipairs, pairs, next, pcall, select
local string, math, table = string, math, table
-- lib apis caching
local X = MY
local UI, GLOBAL, CONSTANT, wstring, lodash = X.UI, X.GLOBAL, X.CONSTANT, X.wstring, X.lodash
-------------------------------------------------------------------------------------------------------
local PLUGIN_NAME = 'MY_Toolbox'
local PLUGIN_ROOT = X.PACKET_INFO.ROOT .. PLUGIN_NAME
local MODULE_NAME = 'MY_Toolbox'
local _L = X.LoadLangPack(PLUGIN_ROOT .. '/lang/')
--------------------------------------------------------------------------
if not X.AssertVersion(MODULE_NAME, _L[MODULE_NAME], '^9.0.0') then
	return
end
--------------------------------------------------------------------------

local O = X.CreateUserSettingsModule('MY_PetWiki', _L['General'], {
	bEnable = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Toolbox'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = false,
	},
	nW = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Toolbox'],
		xSchema = X.Schema.Number,
		xDefaultValue = 850,
	},
	nH = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Toolbox'],
		xSchema = X.Schema.Number,
		xDefaultValue = 610,
	},
})
local D = {}

function D.OnWebSizeChange()
	O.nW, O.nH = this:GetSize()
end

function D.Open(dwPetIndex)
	local tPet = Table_GetFellowPet(dwPetIndex)
	if not tPet then
		return
	end
	local szURL = 'https://page.j3cx.com/pet/' .. dwPetIndex .. '?'
		.. X.EncodePostData(X.UrlEncode({
			l = AnsiToUTF8(GLOBAL.GAME_LANG),
			L = AnsiToUTF8(GLOBAL.GAME_EDITION),
			player = AnsiToUTF8(GetUserRoleName()),
		}))
	local szKey = 'PetsWiki_' .. dwPetIndex
	local szTitle = tPet.szName .. ' - ' .. X.XMLGetPureText(tPet.szDesc)
	szKey = UI.OpenBrowser(szURL, {
		key = szKey,
		title = szTitle,
		w = O.nW, h = O.nH,
		readonly = true,
	})
	UI(UI.LookupBrowser(szKey)):Size(D.OnWebSizeChange)
end

function D.HookPetFrame(frame)
	----------------
	-- ���ɰ�
	----------------
	local hMyPets = frame:Lookup('PageSet_All/Page_MyPet/WndScroll_myPets', '')
	if hMyPets then
		local function OnPetItemLButtonClick()
			if O.bEnable and this.tPet and not IsCtrlKeyDown() and not IsAltKeyDown() and this:IsObjectSelected() then
				D.Open(this.tPet.dwPetIndex)
				return
			end
			return UI.FormatWMsgRet(false, true)
		end
		UI.HookHandleAppend(hMyPets, function(_, hMyPet)
			local hPets = hMyPet:Lookup('Handle_petsBox')
			X.DelayCall(function()
				if not hPets:IsValid() then
					return
				end
				UI.HookHandleAppend(hPets, function(_, hPet)
					X.DelayCall(function()
						if not hPet:IsValid() then
							return
						end
						local box = hPet:Lookup('Box_petItem')
						X.SetMemberFunctionHook(
							box,
							'OnItemLButtonClick',
							'MY_PetWiki',
							OnPetItemLButtonClick,
							{ bAfterOrigin = true, bPassReturn = true, bHookReturn = true })
						box:RegisterEvent(ITEM_EVENT.LBUTTONCLICK)
					end)
				end)
			end)
		end)
	end

	----------------
	-- ���ư�
	----------------
	local hMedalPets = frame:Lookup('PageSet_All/Page_MedalCollected/Wnd_MedalCollect', 'Handle_MedalPets')
	if hMedalPets then
		local function OnPetItemLButtonClick()
			if O.bEnable and this.tPet and not IsCtrlKeyDown() and not IsAltKeyDown() and this:IsObjectSelected() then
				D.Open(this.tPet.dwPetIndex)
				return
			end
			return UI.FormatWMsgRet(false, true)
		end
		for nNum = 1, 10 do
			local hMedal = hMedalPets:Lookup('Handle_MedalPet_' .. nNum)
			if hMedal then
				for nIndex = 1, nNum do
					local boxPet = hMedal:Lookup('Box_MedalPet_' .. nNum .. '_' .. nIndex)
					if boxPet then
						X.SetMemberFunctionHook(
							boxPet,
							'OnItemLButtonClick',
							'MY_PetWiki',
							OnPetItemLButtonClick,
							{ bAfterOrigin = true, bPassReturn = true, bHookReturn = true })
						boxPet:RegisterEvent(ITEM_EVENT.LBUTTONCLICK)
					end
				end
			end
		end
	end

	local hPreferList = frame:Lookup('PageSet_All/Page_MyPet/WndScroll_Pets/WndContainer_Pets/Wnd_Prefer', '')
	if hPreferList then
		local function OnPetItemLButtonClick()
			if O.bEnable and this.tPet and not IsCtrlKeyDown() and not IsAltKeyDown() and this:Lookup('Image_PreferSelect'):IsVisible() then
				D.Open(this.tPet.dwPetIndex)
				return
			end
			return UI.FormatWMsgRet(false, true)
		end
		for i = 0, hPreferList:GetItemCount() - 1 do
			local hPet = hPreferList:Lookup(i)
			X.SetMemberFunctionHook(
				hPet,
				'OnItemLButtonClick',
				'MY_PetWiki',
				OnPetItemLButtonClick,
				{ bAfterOrigin = true, bPassReturn = true, bHookReturn = true })
			hPet:RegisterEvent(ITEM_EVENT.LBUTTONCLICK)
		end
	end

	local hPets = frame:Lookup('PageSet_All/Page_MyPet/WndScroll_Pets/WndContainer_Pets/Wnd_Pets', '')
	if hPets then
		local function OnPetItemLButtonClick()
			if O.bEnable and this.tPet and not IsCtrlKeyDown() and not IsAltKeyDown() and this:IsObjectSelected() then
				D.Open(this.tPet.dwPetIndex)
				return
			end
			return UI.FormatWMsgRet(false, true)
		end
		UI.HookHandleAppend(hPets, function(_, hGroup)
			local hList = hGroup and hGroup:Lookup((hGroup:GetName():gsub('Handle_Pets', 'Handle_List')))
			if not hList then
				return
			end
			UI.HookHandleAppend(hList, function(_, hItem)
				X.DelayCall(function()
					local boxPet = hItem:IsValid() and hItem:Lookup('Box_PetItem')
					if not boxPet then
						return
					end
					X.SetMemberFunctionHook(
						boxPet,
						'OnItemLButtonClick',
						'MY_PetWiki',
						OnPetItemLButtonClick,
						{ bAfterOrigin = true, bPassReturn = true, bHookReturn = true })
					boxPet:RegisterEvent(ITEM_EVENT.LBUTTONCLICK)
				end)
			end)
		end)
	end
end

X.RegisterInit('MY_PetWiki', function()
	local frame = Station.Lookup('Normal/NewPet')
	if not frame then
		return
	end
	D.HookPetFrame(frame)
end)

X.RegisterFrameCreate('NewPet', 'MY_PetWiki', function(name, frame)
	D.HookPetFrame(frame)
end)

function D.OnPanelActivePartial(ui, nPaddingX, nPaddingY, nW, nH, nX, nY)
	nX = nX + ui:Append('WndCheckBox', {
		x = nX, y = nY, w = 'auto',
		text = _L['Pet wiki'],
		tip = _L['Click icon on pet panel to view pet wiki'],
		tippostype = UI.TIP_POSITION.BOTTOM_TOP,
		checked = MY_PetWiki.bEnable,
		oncheck = function(bChecked)
			MY_PetWiki.bEnable = bChecked
		end,
	}):Width() + 5
	return nX, nY
end

-- Global exports
do
local settings = {
	name = 'MY_PetWiki',
	exports = {
		{
			fields = {
				'Open',
				'OnPanelActivePartial',
			},
			root = D,
		},
		{
			fields = {
				'bEnable',
				'nW',
				'nH',
			},
			root = O,
		},
	},
	imports = {
		{
			fields = {
				'bEnable',
				'nW',
				'nH',
			},
			root = O,
		},
	},
}
MY_PetWiki = X.CreateModule(settings)
end
