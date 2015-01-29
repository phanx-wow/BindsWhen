--[[--------------------------------------------------------------------
	Binds When?
	Shows BoA/BoE text on bag items.
	Copyright (c) 2015 Phanx <addons@phanx.net>. All rights reserved.
	https://github.com/Phanx/BindsWhen
----------------------------------------------------------------------]]
-- Text to show for each binding type

local BoA = "|cffe6cc80BoA|r" -- heirloom item color
local BoE = "|cff1eff00BoE|r" -- uncommon item color
local BoP = false -- not displayed

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

local textForItem = {}

local function GetBindText(arg1, arg2)
	local link
	if arg1 == "player" then
		link = GetInventoryItemLink(arg1, arg2)
	else
		link = GetContainerItemLink(arg1, arg2)
	end
	if not link then
		return
	end

	local text = textForItem[link]
	if text then
		return text
	end

	if arg1 == "player" then
		scanTip:SetInventoryItem(arg1, arg2)
	else
		scanTip:SetBagItem(arg1, arg2)
	end
	for i = 1, 5 do
		local bind = scanTip[i]:GetText()
		if bind and strmatch(bind, USE_COLON) then -- ignore recipes
			break
		end
		local text = bind and textForBind[bind]
		if text then
			textForItem[link] = text
			return text
		end
	end
	textForItem[link] = false
end

------------------------------------------------------------------------
-- Clear cached BoE items when confirming to bind something

local function ClearTempCache()
	for id, text in pairs(textForItem) do
		if temporary[text] then
			textForItem[id] = nil
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
		local text = not button.Count:IsShown() and GetBindText(bag, slot)
		SetItemButtonBindType(button, text)
	end
end)

hooksecurefunc("BankFrameItemButton_Update", function(button)
	local bag = button.isBag and -4 or button:GetParent():GetID()
	local slot = button:GetID()
	local text = not button.Count:IsShown() and GetBindText("player", button:GetInventorySlot())
	SetItemButtonBindType(button, text)
end)

------------------------------------------------------------------------
-- Addon support

local addons = {}

tinsert(addons, function()
	if not Bagnon then return true end

	local function UpdateItemSlot(self)
		local bag = self:GetBag()
		local slot = self:GetID()
		local text
		local getSlot = Bagnon:IsBank(bag) and BankButtonIDToInvSlotID or Bagnon:IsReagents(bag) and ReagentBankButtonIDToInvSlotID
		if getSlot then
			text = not self.Count:IsShown() and GetBindText("player", getSlot(slot))
		else
			text = not self.Count:IsShown() and GetBindText(bag, slot)
		end
		SetItemButtonBindType(self, text)
	end

	local CreateItemSlot = Bagnon.ItemSlot.Create
	function Bagnon.ItemSlot:Create()
		local button = CreateItemSlot(self)
		hooksecurefunc(button, "Update", UpdateItemSlot)
		return button
	end
end)

tinsert(addons, function()
	if not cargBags then return true end

	local function UpdateItemButton(self, item)
		if not self.bindsOnText then
			bindsOnText = self:CreateFontString(nil, "ARTWORK")
			bindsOnText:SetPoint("BOTTOMRIGHT", self.BottomString)
			bindsOnText:SetFont(self.BottomString:GetFont())
			self.bindsOnText = bindsOnText
		end
		local text = item and not self.Count:IsShown() and GetBindText(item.bagID, item.slotID)
		if text and self.BottomString:IsShown() then
			self.BottomString:SetText("")
		end
		SetItemButtonBindType(self, text)
	end
	
	local hooked = {}

	local Implementation = cargBags.classes.Implementation
	hooksecurefunc(Implementation, "UpdateSlot", function(self, bagID, slotID)
		local button = self:GetButton(bagID, slotID)
		if button and button.Update and not hooked[button] then
			hooksecurefunc(button, "Update", UpdateItemButton)
			hooked[button] = true
			button:Update(button:GetItemInfo())
		end
	end)
end)

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(f)
	for i = #addons, 1, -1 do
		if not addons[i]() then
			tremove(addons, i)
		end
	end
	if #addons == 0 then
		f:UnregisterAllEvents()
		f:SetScript("OnEvent", nil)
		f, addons = nil, nil
	else
		f:RegisterEvent("ADDON_LOADED")
	end
end)