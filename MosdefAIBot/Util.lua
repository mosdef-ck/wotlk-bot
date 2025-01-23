-- Prints message in chatbox
function MaloWUtils_Print(msg)
    ChatFrame1:AddMessage(msg)
end

function MaloWUtils_PrintEditable(...)

	local txt = select(1, ...)
	for i = 2, select('#', ...) do
		txt = txt .. ", ".. select(i, ...)
	end
    local editbox = CreateFrame("EditBox", "MyEditBox", UIParent, "InputBoxTemplate")
    editbox:SetSize(300, 50)
    editbox:SetPoint("CENTER", 0, 0)
    editbox:SetAutoFocus(false)
    editbox:SetText(txt)

    local closeButton = CreateFrame("Button", "MyCloseButton", editbox)
    closeButton:SetPoint("RIGHT", editbox, "RIGHT", -5, 0)
    closeButton:SetWidth(40)
    closeButton:SetHeight(40)
    closeButton:SetText("X")

    closeButton:SetScript("OnClick", function()
        editbox:Hide()
    end)

	editbox:Show()
	closeButton:Show()
end

function MaloWUtils_SplitStringOnSpace(s)
    t = {}
    index = 1
    for value in string.gmatch(s, "%S+") do
        t[index] = string.lower(value)
        index = index + 1
    end
    return t
end

function MaloWUtils_TableLength(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

function MaloWUtils_GetEquippedAndInventoryItemState()
    local itemState = {}
    itemState["bags"] = {}
    for bag = 0, 4 do
        if itemState["bags"][bag] == nil then
            itemState["bags"][bag] = {}
        end
        for bagSlot = 1, GetContainerNumSlots(bag) do
            local itemId = GetContainerItemID(bag, bagSlot)
            if itemId then
                local texture, itemCount, locked, quality, readable, lootable = GetContainerItemInfo(bag, bagSlot)
                local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
                    itemEquipLoc, itemTexture, itemSellPrice = GetItemInfo(itemId)
                local itemLinkWithRE = GetContainerItemLink(bag, bagSlot)
                local item = {}
                item.link = itemLinkWithRE
                item.count = itemCount
                itemState["bags"][bag][bagSlot] = item
            end
        end
    end

    itemState["equipped"] = {}
    for slot = 0, 23 do
        itemId = GetInventoryItemID("player", slot);
        if itemId then
            local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
                itemEquipLoc, itemTexture, itemSellPrice = GetItemInfo(itemId)
            local itemLinkWithRE = GetInventoryItemLink("player", slot)
            local item = {}
            item.link = itemLinkWithRE
            itemState["equipped"][slot] = item
        end
    end
    return itemState
end

function MaloWUtils_ConvertTableToString(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then
                k = '"' .. k .. '"'
            end
            s = s .. '[' .. k .. '] = ' .. MaloWUtils_ConvertTableToString(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

function MaloWUtils_StrStartsWith(fullString, startString)
    if string.sub(fullString, 1, string.len(startString)) == startString then
        return true, string.sub(fullString, string.len(startString) + 1)
    end
    return false, nil
end

function MaloWUtils_StrContains(fullString, substr)
    return (fullString or ""):lower():find((substr or ""):lower(), 1, true) ~= nil
end
