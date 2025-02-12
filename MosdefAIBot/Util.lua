-- Prints message in chatbox
function MaloWUtils_Print(msg)
    ChatFrame1:AddMessage(msg)
end

function MaloWUtils_PrintEditable(...)

    local myFrame = CreateFrame("Frame", "MyFrame", UIParent)
    myFrame:SetSize(400, 60)
    myFrame:SetFrameStrata("DIALOG")
    myFrame:SetPoint("CENTER", UIParent, "CENTER")
    myFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = {
            left = 11,
            right = 12,
            top = 12,
            bottom = 11
        }
    })

    -- Create the close button
    local closeButton = CreateFrame("Button", "MyFrameCloseButton", myFrame, "GameMenuButtonTemplate")
    closeButton:SetPoint("TOPRIGHT", myFrame, "TOPRIGHT", -7, -7)
    closeButton:SetSize(20, 20)
    closeButton:SetNormalTexture("Interface/Buttons/UI-Panel-CloseButton")
    closeButton:SetPushedTexture("Interface/Buttons/UI-Panel-CloseButton-Down")
    closeButton:SetHighlightTexture("Interface/Buttons/UI-Panel-CloseButton-Highlight")
    closeButton:SetText("X")
    closeButton:SetScript("OnClick", function()
        myFrame:Hide()
    end)

    local txt = select(1, ...)
    for i = 2, select('#', ...) do
        txt = txt .. ", " .. select(i, ...)
    end
    -- local editbox = CreateFrame("EditBox", "MyEditBox", myFrame, "InputBoxTemplate")
    local editbox = CreateFrame("EditBox", "MyEditBox", myFrame)
    editbox:SetSize(500, 40)
    editbox:SetPoint("TOPLEFT", myFrame, 20, -10)
    editbox:SetFontObject("GameFontNormal")
    editbox:SetAutoFocus(false)
    editbox:SetText(txt)

    myFrame:Show()
end

function MalowUtils_PrintScrollable(text)
    local myFrame = CreateFrame("Frame", "MyFrame", UIParent)
    myFrame:SetSize(800, 500)
    myFrame:SetFrameStrata("DIALOG")
    myFrame:SetPoint("CENTER", UIParent, "CENTER")
    myFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = {
            left = 11,
            right = 12,
            top = 12,
            bottom = 11
        }
    })

    -- Create the close button
    local closeButton = CreateFrame("Button", "MyFrameCloseButton", myFrame, "GameMenuButtonTemplate")
    closeButton:SetPoint("TOPRIGHT", myFrame, "TOPRIGHT", -7, -7)
    closeButton:SetSize(20, 20)
    closeButton:SetNormalTexture("Interface/Buttons/UI-Panel-CloseButton")
    closeButton:SetPushedTexture("Interface/Buttons/UI-Panel-CloseButton-Down")
    closeButton:SetHighlightTexture("Interface/Buttons/UI-Panel-CloseButton-Highlight")
    closeButton:SetText("X")
    closeButton:SetScript("OnClick", function()
        myFrame:Hide()
    end)

    -- Create the edit box
    local editBox = CreateFrame("EditBox", "MyFrameEditBox", myFrame)
    editBox:SetPoint("TOPLEFT", myFrame, 20, -10)
    editBox:SetWidth(700)
    editBox:SetText(text or "Lorem Ipsom");
    editBox:SetFontObject("GameFontNormal")
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)

    -- Show the frame
    myFrame:Show()
    myFrame:EnableMouse(true)
    myFrame:SetMovable(true)
end


function MalowUtils_ShowNearbyObjects(distanceFilter)
    local time = GetTime()
    
    local f = CreateFrame("Frame", "MyFrame"..time, UIParent, "UIPanelDialogTemplate")
    f:SetSize(650, 400)
    --f:SetFrameStrata("DIALOG")
    f:SetPoint("CENTER", UIParent)
    f:EnableMouse(true)
    f:SetMovable(true)
    -- f:SetResizable(true)
    -- f:SetMinResize(400, 400)
    f:RegisterForDrag("LeftButton");
    f:SetScript("OnDragStart", f.StartMoving);
    f:SetScript("OnDragStop", f.StopMovingOrSizing);
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = {
            left = 11,
            right = 12,
            top = 12,
            bottom = 11
        }
    })
    f.title:SetText("Nearby Objects")

    
    local ScrollFrame = CreateFrame("ScrollFrame", "MyScrollFrame"..time, f, "UIPanelScrollFrameTemplate");
    ScrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -30);
    ScrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 20);      
    
    -- Create the edit box
    local editBox = CreateFrame("EditBox", "MyFrameEditBox"..time, ScrollFrame)
    editBox:SetPoint("TOPLEFT", ScrollFrame, 5, -5)
    editBox:SetPoint("BOTTOMRIGHT", ScrollFrame, -5, 5)
    editBox:SetWidth(ScrollFrame:GetSize())
    editBox:SetText(text or "Lorem Ipsom");
    editBox:SetFontObject("GameFontNormal")
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    ScrollFrame:SetScrollChild(editBox);

    -- Show the frame    

    local total = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        total = total + elapsed
        if total >= 1 then
            local nearbyObjects = GetNearbyObjects()
            local s = ""
            for i, o in ipairs(nearbyObjects) do
                if not distanceFilter or AI.GetDistanceTo(o.x,o.y) <= distanceFilter then
                    -- s = s .. "name: " .. strpad(o.name, 50) .. "\n"
                    s = s .. "name: " .. strpad(o.name, 30) .. " x:" .. o.x .. " y:" .. o.y .. " z:" .. o.z .. "\n"
                end
                
            end
            editBox:SetText(s)
            total = 0
        end
    end)

    f:SetScript("OnLeave", function() editBox:ClearFocus() end)
    f:Show()
    
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

function table2str(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then
                k = '"' .. k .. '"'
            end
            s = s .. '[' .. k .. '] = ' .. table2str(v) .. ','
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

function strpad(s, len)
    local currLen = string.len(s)
    if currLen < len then
        local diff = len - currLen
        local filler = string.rep(" ", diff)
        return s .. filler
    end
    return s
end
