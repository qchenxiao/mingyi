--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : 变量监控
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
local PLUGIN_NAME = 'MYDev_VarWatch'
local PLUGIN_ROOT = X.PACKET_INFO.ROOT .. PLUGIN_NAME
local MODULE_NAME = 'MYDev_VarWatch'
local _L = X.LoadLangPack(PLUGIN_ROOT .. '/lang/')
--------------------------------------------------------------------------
if not X.AssertVersion(MODULE_NAME, _L[MODULE_NAME], '^9.0.0') then
	return
end
--------------------------------------------------------------------------
local _C = {}
local DATA_PATH = {'config/dev_varwatch.jx3dat', X.PATH_TYPE.GLOBAL}
_C.tVarList = X.LoadLUAData(DATA_PATH) or {}

local function var2str_x(var, indent, level) -- 只解析一层table且不解析方法
	local function table_r(var, level, indent)
		local t = {}
		local szType = type(var)
		if szType == 'nil' then
			table.insert(t, 'nil')
		elseif szType == 'number' then
			table.insert(t, tostring(var))
		elseif szType == 'string' then
			table.insert(t, string.format('%q', var))
		elseif szType == 'boolean' then
			table.insert(t, tostring(var))
		elseif szType == 'table' then
			table.insert(t, '{')
			local s_tab_equ = ']='
			if indent then
				s_tab_equ = '] = '
				if not X.IsEmpty(var) then
					table.insert(t, '\n')
				end
			end
			for key, val in pairs(var) do
				if indent then
					table.insert(t, string.rep(indent, level + 1))
				end
				table.insert(t, '[')
				table.insert(t, tostring(key))
				table.insert(t, s_tab_equ) --'] = '
				table.insert(t, tostring(val))
				table.insert(t, ',')
				if indent then
					table.insert(t, '\n')
				end
			end
			if indent and not X.IsEmpty(var) then
				table.insert(t, string.rep(indent, level))
			end
			table.insert(t, '}')
		else --if (szType == 'userdata') then
			table.insert(t, '"')
			table.insert(t, tostring(var))
			table.insert(t, '"')
		end
		return table.concat(t)
	end
	return table_r(var, level or 0, indent)
end

X.RegisterPanel(_L['Development'], 'Dev_VarWatch', _L['VarWatch'], 'ui/Image/UICommon/BattleFiled.UITex|7', {
	IsRestricted = function()
		return not X.IsDebugClient('Dev_VarWatch')
	end,
	OnPanelActive = function(wnd)
		local ui = UI(wnd)
		local x, y = 10, 10
		local w, h = ui:Size()
		local nLimit = 20

		local tWndEditK = {}
		local tWndEditV = {}

		for i = 1, nLimit do
			tWndEditK[i] = ui:Append('WndEditBox', {
				name = 'WndEditBox_K' .. i,
				text = _C.tVarList[i],
				x = x, y = y + (i - 1) * 25,
				w = 150, h = 25,
				color = {255, 255, 255},
				onchange = function(text)
					_C.tVarList[i] = X.TrimString(text)
					X.SaveLUAData(DATA_PATH, _C.tVarList)
				end,
			})

			tWndEditV[i] = ui:Append('WndEditBox', {
				name = 'WndEditBox_V' .. i,
				x = x + 150, y = y + (i - 1) * 25,
				w = w - 2 * x - 150, h = 25,
				color = {255, 255, 255},
			})
		end

		X.BreatheCall('DEV_VARWATCH', function()
			for i = 1, nLimit do
				local szKey = _C.tVarList[i]
				local hFocus = Station.GetFocusWindow()
				if not X.IsEmpty(szKey) and -- 忽略空白的Key
				wnd:GetRoot():IsVisible() and ( -- 主界面隐藏了就不要解析了
					not hFocus or (
						not hFocus:GetTreePath():find(tWndEditK[i]:Name()) and  -- 忽略K编辑中的
						not hFocus:GetTreePath():find(tWndEditV[i]:Name()) -- 忽略V编辑中的
					)
				) then
					if loadstring then
						local t = {select(2, X.XpCall(loadstring('return ' .. szKey)))}
						for k, v in pairs(t) do
							t[k] = tostring(v)
						end
						tWndEditV[i]:Text(table.concat(t, ', '))
					else
						tWndEditV[i]:Text(var2str_x(X.GetGlobalValue(szKey)))
					end
				end
			end
		end)
	end,
	OnPanelDeactive = function()
		X.BreatheCall('DEV_VARWATCH', false)
	end,
})
