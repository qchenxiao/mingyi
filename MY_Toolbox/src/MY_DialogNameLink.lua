--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : 玩家名字变成link方便组队
-- @author   : 茗伊 @双梦镇 @追风蹑影
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

local O = X.CreateUserSettingsModule('MY_DialogNameLink', _L['General'], {
	bEnable = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Toolbox'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = true,
	},
})
local D = {}

function D.Apply()
	if D.bReady and O.bEnable then
		X.RegisterEvent('OPEN_WINDOW', 'NAMELINKER', function(event)
			local h
			for _, p in ipairs({
				{'Normal/DialoguePanel', '', 'Handle_Message'},
				{'Lowest2/PlotDialoguePanel', 'Wnd_Dialogue', 'Handle_Dialogue'},
			}) do
				local frame = Station.Lookup(p[1])
				if frame and frame:IsVisible() then
					h = frame:Lookup(p[2], p[3])
					if h then
						break
					end
				end
			end
			if not h then
				return
			end
			for i = 0, h:GetItemCount() - 1 do
				local hItem = h:Lookup(i)
				if hItem:GetType() == 'Text' then
					local szText = hItem:GetText()
					for _, szPattern in ipairs(_L.NAME_PATTERN_LIST) do
						local _, _, szName = szText:find(szPattern)
						if szName then
							local nPos1, nPos2 = szText:find(szName)
							h:InsertItemFromString(i, true, GetFormatText(szText:sub(nPos2 + 1), hItem:GetFontScheme()))
							h:InsertItemFromString(i, true, GetFormatText('[' .. szText:sub(nPos1, nPos2) .. ']', nil, nil, nil, nil, nil, nil, 'namelink'))
							local txtName = h:Lookup(i + 1)
							X.RenderChatLink(txtName)
							if MY_Farbnamen and MY_Farbnamen.Render then
								MY_Farbnamen.Render(txtName, { bColor = false })
							end
							hItem:SetText(szText:sub(1, nPos1 - 1))
							hItem:SetFontColor(0, 0, 0)
							hItem:AutoSize()
							break
						end
					end
				end
			end
			h:FormatAllItemPos()
		end)
	else
		X.RegisterEvent('OPEN_WINDOW', 'NAMELINKER', false)
	end
end
X.RegisterUserSettingsUpdate('@@INIT@@', 'MY_DialogNameLink', function()
	D.bReady = true
	D.Apply()
end)

function D.OnPanelActivePartial(ui, nPaddingX, nPaddingY, nW, nH, nX, nY)
	return nX, nY
end

-- Global exports
do
local settings = {
	name = 'MY_DialogNameLink',
	exports = {
		{
			fields = {
				'OnPanelActivePartial',
			},
			root = D,
		},
		{
			fields = {
				'bEnable',
			},
			root = O,
		},
	},
	imports = {
		{
			fields = {
				'bEnable',
			},
			triggers = {
				bEnable = D.Apply,
			},
			root = O,
		},
	},
}
MY_DialogNameLink = X.CreateModule(settings)
end
