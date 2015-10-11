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
for i = 1, 5 do
	local L = scanTip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	scanTip:AddFontStrings(L, scanTip:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
	scanTip[i] = L
end

------------------------------------------------------------------------
-- Keep a cache of which items are BoA or BoE

local textForItem = {}

local function GetBindText(arg1, arg2)
	local link, setTooltip, onlyBoA
	if arg1 == "player" then
		link = GetInventoryItemLink(arg1, arg2)
		setTooltip = scanTip.SetInventoryItem
	elseif arg2 then
		link = GetContainerItemLink(arg1, arg2)
		setTooltip = scanTip.SetBagItem
	else
		link = arg1
		setTooltip = scanTip.SetHyperlink
		onlyBoA = true
	end
	if not link then
		return
	end

	local item = onlyBoA and link or (arg1 .. arg2 .. link)
	local text = textForItem[item]
	if text then
		return text
	end

	scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
	setTooltip(scanTip, arg1, arg2)
	for i = 1, 5 do
		local bind = scanTip[i]:GetText()
		if bind and strmatch(bind, USE_COLON) then -- ignore recipes
			break
		end
		local text = bind and textForBind[bind]
		if text then
			if onlyBoA and text ~= BoA then -- don't save BoE text for non-recipe hyperlinks, eg. Bagnon cached items
				return
			end
			textForItem[item] = text
			return text
		end
	end
	textForItem[item] = false
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

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(f, e, name)
	for i = #addons, 1, -1 do
		if not addons[i](name) then
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

------------------------------------------------------------------------
-- AdiBags
-- http://www.wowace.com/addons/adibags/

tinsert(addons, function(name)
	if not AdiBags then return true end

	local ItemButton = AdiBags:GetClass("ItemButton")
	hooksecurefunc(ItemButton, "Update", function(self)
		local text
		if self.inventorySlot then
			text = not self.Count:IsShown() and GetBindText("player", self.inventorySlot)
		else
			text = not self.Count:IsShown() and GetBindText(self.bag, self.slot)
		end
		SetItemButtonBindType(self, text)
	end)
end)

------------------------------------------------------------------------
-- Bagnon
-- http://wow.curseforge.com/addons/bagnon/
-- http://wow.curseforge.com/addons/combuctor/

local function UpdateBagnonItemSlot(self)
	local bag = self.bag
	if type(bag) ~= "number" then return end

	local text
	local link = self.hasItem
	if link and not self.Count:IsShown() then
		if self:IsCached() then
			if link then
				if strfind(link, "battlepet:") then
					-- Caged battle pets don't bind and don't stack
					text = BoE
				else
					text = GetBindText(link)
				end
			end
		else
			local slot = self:GetID()
			local getInvSlot = bag == BANK_CONTAINER and BankButtonIDToInvSlotID or bag == REAGENTBANK_CONTAINER and ReagentBankButtonIDToInvSlotID
			if getInvSlot then
				text = GetBindText("player", getInvSlot(slot))
			else
				text = GetBindText(bag, slot)
			end
		end
	end
	SetItemButtonBindType(self, text)
end

tinsert(addons, function()
	local addon = Bagnon or Combuctor
	if not addon then return true end

	local CreateItemSlot = addon.ItemSlot.Create
	function addon.ItemSlot:Create()
		local button = CreateItemSlot(self)
		hooksecurefunc(button, "Update", UpdateBagnonItemSlot)
		return button
	end
end)

------------------------------------------------------------------------
-- cargBags
-- http://www.wowinterface.com/downloads/info22329-cargBagsNivayaRealUIstandalone.html

tinsert(addons, function(name)
	local cargBags = _G[name and GetAddOnMetadata(name, "X-cargBags") or "cargBags"]
	if not cargBags and not name then
		for i = 1, GetNumAddOns() do
			local global = GetAddOnMetadata(i, "X-cargBags")
			if global then
				cargBags = _G[global]
				break
			end
		end
	end
	if not cargBags then return true end

	local function UpdateItemButton(self, item)
		local text
		if item and not self.Count:IsShown() then
			if not self.bindsOnText then
				local bindsOnText = self:CreateFontString(nil, "ARTWORK")
				bindsOnText:SetPoint("BOTTOMRIGHT", self.BottomString)
				bindsOnText:SetFont(self.BottomString:GetFont())
				self.bindsOnText = bindsOnText
			end
			text = GetBindText(item.bagID, item.slotID)
			if text and self.BottomString:IsShown() then
				self.BottomString:SetText("")
			end
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

------------------------------------------------------------------------
-- DerpyStuffing
-- http://www.wowinterface.com/downloads/info22500-DerpyStuffingAuroraOneBags.html

tinsert(addons, function()
	if not Stuffing then return true end

	hooksecurefunc(Stuffing, "SlotUpdate", function(self, b)
		local button = b.frame
		if not button.bindsOnText then
			local bindsOnText = button:CreateFontString(nil, "ARTWORK")
			bindsOnText:SetPoint("TOPRIGHT", button.Count)
			bindsOnText:SetFont(button.Count:GetFont())
			button.bindsOnText = bindsOnText
		end
		local bag = b.bag
		local slot = b.slot
		--print("SlotUpdate", bag, slot)
		local text = not button.Count:IsShown() and GetBindText(bag, slot)
		SetItemButtonBindType(button, text)
	end)
end)

------------------------------------------------------------------------
-- LiteBag
-- http://wow.curseforge.com/addons/litebag/

tinsert(addons, function(name)
	if not LiteBagItemButton_Update then return true end

	hooksecurefunc("LiteBagItemButton_Update", function(button)
		local slot = button:GetID()
		local bag =  button:GetParent():GetID()
		local text = not button.Count:IsShown() and GetBindText(bag, slot)
		SetItemButtonBindType(button, text)
	end)
end)

------------------------------------------------------------------------
-- ElvUI
-- http://www.tukui.org/dl.php

tinsert(addons, function()
	if not ElvUI then return true end

	local Bags = LibStub("AceAddon-3.0"):GetAddon("ElvUI"):GetModule("Bags")
	hooksecurefunc(Bags, "UpdateSlot", function(self, bag, slot)
		local button = self.Bags[bag][slot]
		local text = not button.Count:IsShown() and GetBindText(bag, slot)
		SetItemButtonBindType(button, text)
	end)
end)

------------------------------------------------------------------------
-- TukUI
-- http://www.tukui.org/dl.php

tinsert(addons, function()
	if not Tukui then return true end

	hooksecurefunc(Tukui[2].Inventory.Bags, "SlotUpdate", function(self, bag, button)
		local slot = button:GetID()
		local _, count = GetContainerItemInfo(bag, slot)
		local text = (not count or count < 2) and GetBindText(bag, slot)
		SetItemButtonBindType(button, text)
	end)
end)
