--[[--------------------------------------------------------------------
	Binds When?
	Shows BoA/BoE text on bag items.
	Copyright (c) 2015 Phanx <addons@phanx.net>. All rights reserved.
	https://github.com/Phanx/BindsWhen
----------------------------------------------------------------------]]
-- Text to show for each binding type

local BoA = "|cffe6cc80BoA|r" -- heirloom item color
local BoE = "|cff1eff00BoE|r" -- uncommon item color
local BoP = false -- "BoP" -- not displayed

------------------------------------------------------------------------
-- Map tooltip text to display text

local textForBind = {
	[ITEM_ACCOUNTBOUND]        = BoA,
	[ITEM_BNETACCOUNTBOUND]    = BoA,
	[ITEM_BIND_TO_ACCOUNT]     = BoA,
	[ITEM_BIND_TO_BNETACCOUNT] = BoA,
	[ITEM_BIND_ON_EQUIP]       = BoE,
	[ITEM_BIND_ON_USE]         = BoE,
	[ITEM_SOULBOUND]           = BoP,
	[ITEM_BIND_ON_PICKUP]      = BoP,
}

------------------------------------------------------------------------
-- Which binding types can change during gameplay (BoE)

local temporary = {
	[BoE] = true,
}

------------------------------------------------------------------------
-- Tooltip for scanning for Binds on X text

local scanTip = CreateFrame("GameTooltip", "BindsWhenScanTooltip")
scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
for i = 1, 5 do
	local L = scanTip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	local R = scanTip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	scanTip:AddFontStrings(L, R)
	scanTip[i] = L
end

------------------------------------------------------------------------
-- Keep a cache of which items are BoA or BoE

local textForItem = setmetatable({}, { __index = function(t, link)
	scanTip:SetHyperlink(link)
	for i = 1, 5 do
		local bind = scanTip[i]:GetText()
		local text = bind and textForBind[bind]
		if text then
			t[link] = text
			return text
		end
	end
	t[link] = false
end })

------------------------------------------------------------------------
-- Clear cached BoE items when confirming to bind something

local function ClearTempCache()
	for link, text in pairs(textForItem) do
		if temporary[text] then
			textForItem[link] = nil
		end
	end
end

hooksecurefunc("BindEnchant", ClearTempCache)
hooksecurefunc("ConfirmBindOnUse", ClearTempCache)

------------------------------------------------------------------------
-- Add text string to an item button

local function SetItemButtonBindType(button, text)
	local bindsOnText = button.bindsOnText
	if not text and not bindsOnText then return end
	if not text then
		return bindsOnText:SetText("")
	end
	if not bindsOnText then
		-- see ItemButtonTemplate.Count @ ItemButtonTemplate.xml#13
		bindsOnText = button:CreateFontString(nil, "ARTWORK", "GameFontNormalOutline")
		bindsOnText:SetPoint("BOTTOMRIGHT", -5, 2)
		button.bindsOnText = bindsOnText
	end
	bindsOnText:SetText(text)
end

------------------------------------------------------------------------
-- Update default bag and bank frames

hooksecurefunc("ContainerFrame_Update", function(frame)
	local bag = frame:GetID()
	local name = frame:GetName()
	for i = 1, frame.size do
		local button = _G[name.."Item"..i]
		local slot = button:GetID()
		local link = GetContainerItemLink(bag, slot)
		local text = link and not button.Count:IsShown() and textForItem[link]
		SetItemButtonBindType(button, text)
	end
end)

hooksecurefunc("BankFrameItemButton_Update", function(button)
	local bag = button:GetParent():GetID()
	local slot = button:GetID()
	local link = GetContainerItemLink(bag, slot)
	local text = link and not button.Count:IsShown() and textForItem[link]
	SetItemButtonBindType(button, text)
end)

------------------------------------------------------------------------
-- Bagnon support

if Bagnon then
	local function UpdateItemSlot(button)
		local _, _, _, _, _, _, link = button:GetInfo()
		local text = link and not button.Count:IsShown() and textForItem[link]
		SetItemButtonBindType(button, text)
	end

	local CreateItemSlot = Bagnon.ItemSlot.Create
	function Bagnon.ItemSlot:Create()
		local button = CreateItemSlot(self)
		hooksecurefunc(button, "Update", UpdateItemSlot)
		return button
	end
end
