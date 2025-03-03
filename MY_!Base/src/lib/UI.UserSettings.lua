--------------------------------------------------------
-- This file is part of the JX3 Plugin Project.
-- @desc     : 用户设置导入导出界面
-- @copyright: Copyright (c) 2009 Kingsoft Co., Ltd.
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
local _L = X.LoadLangPack(X.PACKET_INFO.FRAMEWORK_ROOT .. 'lang/lib/')

local D = {}
local FRAME_NAME = X.NSFormatString('{$NS}_UserSettings')

function D.Open(bImport)
	local tSettings = {}
	if bImport then
		local szRoot = X.FormatPath({'export/settings', X.PATH_TYPE.GLOBAL})
		local szPath = GetOpenFileName(_L['Please select import user settings file.'], 'User Settings File(*.us.jx3dat)\0*.us.jx3dat\0\0', szRoot)
		if X.IsEmpty(szPath) then
			return
		end
		tSettings = X.LoadLUAData(szPath, { passphrase = false }) or {}
	end
	Wnd.CloseWindow(FRAME_NAME)
	local W, H = 400, 600
	local uiFrame = UI.CreateFrame(FRAME_NAME, {
		w = W, h = H,
		text = bImport
			and _L['Import User Settings']
			or _L['Export User Settings'],
		esc = true,
	})
	local uiContainer = uiFrame:Append('WndScrollWindowBox', {
		x = 10, y = 50,
		w = W - 20, h = H - 60 - 40,
		containertype = UI.WND_CONTAINER_STYLE.LEFT_TOP,
	})
	local nW = select(2, uiContainer:Width())
	local aGroup, tItemAll = {}, {}
	for _, us in ipairs(X.GetRegisterUserSettingsList()) do
		if us.szGroup and us.szLabel and (not bImport or tSettings[us.szKey]) then
			local tGroup = lodash.find(aGroup, function(p) return p.szGroup == us.szGroup end)
			if not tGroup then
				tGroup = {
					szGroup = us.szGroup,
					aItem = {},
				}
				table.insert(aGroup, tGroup)
			end
			local tItem = lodash.find(tGroup.aItem, function(p) return p.szLabel == us.szLabel end)
			if not tItem then
				tItem = {
					szID = wstring.gsub(X.GetUUID(), '-', ''),
					szLabel = us.szLabel,
					aKey = {},
				}
				table.insert(tGroup.aItem, tItem)
				tItemAll[tItem.szID] = tItem
			end
			table.insert(tItem.aKey, us.szKey)
		end
	end
	-- 排序
	local tGroupRank = {}
	for i, category in ipairs(X.GetPanelCategoryList()) do
		tGroupRank[category.szName] = i
	end
	table.sort(aGroup, function(g1, g2) return (tGroupRank[g1.szGroup] or math.huge) < (tGroupRank[g2.szGroup] or math.huge) end)
	-- 绘制
	local tItemChecked = {}
	for _, tGroup in ipairs(aGroup) do
		local uiGroupChk, tUiItemChk = nil, {}
		local function UpdateCheckboxState()
			local bCheckAll = true
			for _, tItem in ipairs(tGroup.aItem) do
				local bCheck = tItemChecked[tItem.szID]
				if not bCheck then
					bCheckAll = false
				end
				tUiItemChk[tItem.szID]:Check(bCheck, WNDEVENT_FIRETYPE.PREVENT)
			end
			uiGroupChk:Check(bCheckAll, WNDEVENT_FIRETYPE.PREVENT)
		end
		uiGroupChk = uiContainer:Append('WndWindow', { w = nW, h = 30 })
			:Append('WndCheckBox', {
				w = nW,
				text = tGroup.szGroup,
				color = {255, 255, 0},
				checked = true,
				oncheck = function (bCheck)
					for _, tItem in ipairs(tGroup.aItem) do
						tItemChecked[tItem.szID] = bCheck
					end
					UpdateCheckboxState()
				end,
			})
		for _, tItem in ipairs(tGroup.aItem) do
			tUiItemChk[tItem.szID] = uiContainer:Append('WndWindow', { w = nW / 3, h = 30 })
				:Append('WndCheckBox', {
					x = 0, w = nW / 3,
					text = tItem.szLabel,
					checked = true,
					oncheck = function(bCheck)
						tItemChecked[tItem.szID] = bCheck
						UpdateCheckboxState()
					end,
				})
			tItemChecked[tItem.szID] = true
		end
		uiContainer:Append('WndWindow', { w = nW, h = 10 })
	end
	uiFrame:Append('WndButtonBox', {
		x = (W - 200) / 2, y = H - 40,
		w = 200, h = 25,
		buttonstyle = 'FLAT',
		text = bImport and _L['Import'] or _L['Export'],
		onclick = function()
			local aKey, tKvp = {}, {}
			for szID, bCheck in pairs(tItemChecked) do
				if bCheck then
					local tItem = tItemAll[szID]
					for _, szKey in ipairs(tItem.aKey) do
						table.insert(aKey, szKey)
						tKvp[szKey] = tSettings[szKey]
					end
				end
			end
			if bImport then
				local nSuccess = X.ImportUserSettings(tKvp)
				X.Systopmsg(_L('%d settings imported.', nSuccess))
			else
				if #aKey == 0 then
					X.Systopmsg(_L['No custom setting selected, nothing to export.'], CONSTANT.MSG_THEME.ERROR)
					return
				end
				tKvp = X.ExportUserSettings(aKey)
				local nExport = lodash.size(tKvp)
				if nExport == 0 then
					X.Systopmsg(_L['No custom setting found, nothing to export.'], CONSTANT.MSG_THEME.ERROR)
					return
				end
				local szPath = X.FormatPath({'export/settings/' .. X.GetUserRoleName() .. '_' .. X.FormatTime(GetCurrentTime(), '%yyyy%MM%dd%hh%mm%ss') .. '.us.jx3dat', X.PATH_TYPE.GLOBAL})
				X.SaveLUAData(szPath, tKvp, { compress = false, crc = false, passphrase = false })
				X.Systopmsg(_L('%d settings exported, file saved in %s.', nExport, szPath))
			end
			uiFrame:Remove()
		end,
	})
	uiFrame:Anchor('CENTER')
end

-- Global exports
do
local settings = {
	name = FRAME_NAME,
	exports = {
		{
			preset = 'UIEvent',
			fields = {
				'Open',
			},
			root = D,
		},
	},
}
_G[FRAME_NAME] = X.CreateModule(settings)
end

function X.OpenUserSettingsExportPanel()
	D.Open()
end

function X.OpenUserSettingsImportPanel()
	D.Open(true)
end
