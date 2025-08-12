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

function MalowUtils_PrintScrollable(...)
    local time = GetTime()
    local myFrame = CreateFrame("Frame", "MyFrame" .. time, UIParent, "UIPanelDialogTemplate")
    myFrame:SetSize(650, 400)
    -- myFrame:SetFrameStrata("DIALOG")
    myFrame:SetPoint("CENTER", UIParent)
    myFrame:EnableMouse(true)
    myFrame:SetMovable(true)
    myFrame:RegisterForDrag("LeftButton");
    myFrame:SetScript("OnDragStart", myFrame.StartMoving);
    myFrame:SetScript("OnDragStop", myFrame.StopMovingOrSizing);
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

    local ScrollFrame = CreateFrame("ScrollFrame", "MyScrollFrame" .. time, myFrame, "UIPanelScrollFrameTemplate");
    ScrollFrame:SetPoint("TOPLEFT", myFrame, "TOPLEFT", 20, -30);
    ScrollFrame:SetPoint("BOTTOMRIGHT", myFrame, "BOTTOMRIGHT", -20, 20);

    -- Create the edit box
    local txt = select(1, ...)
    for i = 2, select('#', ...) do
        txt = txt .. ", " .. select(i, ...)
    end
    local editBox = CreateFrame("EditBox", "MyFrameEditBox" .. time, ScrollFrame)
    editBox:SetPoint("TOPLEFT", ScrollFrame, 5, -5)
    editBox:SetPoint("BOTTOMRIGHT", ScrollFrame, -5, 5)
    editBox:SetWidth(ScrollFrame:GetSize())
    editBox:SetText(txt or "Lorem Ipsom");
    editBox:SetFontObject("GameFontNormal")
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    ScrollFrame:SetScrollChild(editBox);
    -- Show the frame
    myFrame:Show()
    myFrame:SetScript("OnLeave", function()
        editBox:ClearFocus()
    end)

end

function MalowUtils_ShowNearbyObjects(distanceFilter, ...)
    local time = GetTime()

    local f = CreateFrame("Frame", "MyFrame" .. time, UIParent, "UIPanelDialogTemplate")
    f:SetSize(550, 400)
    -- f:SetFrameStrata("DIALOG")
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

    local ScrollFrame = CreateFrame("ScrollFrame", "MyScrollFrame" .. time, f, "UIPanelScrollFrameTemplate");
    ScrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -30);
    ScrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 20);

    -- Create the edit box
    local editBox = CreateFrame("EditBox", "MyFrameEditBox" .. time, ScrollFrame)
    editBox:SetPoint("TOPLEFT", ScrollFrame, 5, -5)
    editBox:SetPoint("BOTTOMRIGHT", ScrollFrame, -5, 5)
    editBox:SetWidth(ScrollFrame:GetSize())
    editBox:SetText("Lorem Ipsom");
    editBox:SetFontObject("GameFontNormal")
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    ScrollFrame:SetScrollChild(editBox);

    -- Show the frame 
    local args = {}
    for i = 1, select('#', ...) do
        local arg = select(i, ...)
        if type(arg) == "string" then
            args[i] = string.lower(arg)
        end
    end

    local matchesName = function(o)
        if #args == 0 then
            return true
        end
        if not o.name then
            return true
        end
        for i, name in ipairs(args) do
            if strcontains(o.name, name) then
                return true
            end
        end
        return false
    end

    local total = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        total = total + elapsed
        if total >= 1 then
            local nearbyObjects = AI.GetNearbyObjects()
            local s = ""
            for i, o in ipairs(nearbyObjects) do
                if not distanceFilter or AI.GetDistanceTo(o.x, o.y) <= distanceFilter and matchesName(o) then
                    if o.name and not strcontains(o.name, "dark rune") and not strcontains(o.name, "invisible") then
                        s = s .. "t:" .. o.objectType .. " id:" .. o.objectEntry .. " n: " .. strpad(o.name, 20) ..
                                " x:" .. o.x .. " y:" .. o.y .. " z:" .. o.z .. "\n"
                                -- " targetGUID: ".. (o.targetGUID or "") .. "\n"
                    end
                    if o.objectType == 6 then
                        s = s .. "spellName:" .. o.spellName .. " spellId " .. o.spellId .. " r " .. o.radius ..
                                " bytes:" .. o.bytes .. " caster:" .. o.casterGUID .. "\n"
                    end
                end

            end
            editBox:SetText(s)
            total = 0
        end
    end)

    f:SetScript("OnLeave", function()
        editBox:ClearFocus()
    end)
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

function strcontains(fs, substr)
    return MaloWUtils_StrContains(fs, substr)
end

function strstartswith(fs, substr)
    return MaloWUtils_StrStartsWith(fs, substr)
end

function ternary(cond, left, right)
    if cond then
        return left
    else
        return right
    end
end

function splitstr(text, pattern)
    local t = {}
    for w in string.gmatch(text, "([^" .. pattern .. "]+)") do
        table.insert(t, w)
    end
    return t
end

function splitstr2(text, sep)
    local nsep = sep or ","
    local pattern = "([^" .. nsep .. "]+)," .. "([^" .. nsep .. "]+)"
    local v1, v2 = string.match(text, pattern)
    return v1, v2
end

function splitstr3(text, sep)
    local nsep = sep or ","
    local pattern = "([^" .. nsep .. "]+)," .. "([^" .. nsep .. "]+)," .. "([^" .. nsep .. "]+)"
    local v1, v2, v3 = string.match(text, pattern)
    return v1, v2, v3
end
function splitstr4(text, sep)
    local nsep = sep or ","
    local pattern = "([^" .. nsep .. "]+)," .. "([^" .. nsep .. "]+)," .. "([^" .. nsep .. "]+)," .. "([^" .. nsep .. "]+)"
    local v1, v2, v3, v4 = string.match(text, pattern)
    return v1, v2, v3, v4
end

function normalizeAngle(angle)
    local pi2 = math.pi * 2
    -- if angle > pi2 then
    --     angle = angle - pi2
    -- elseif angle < 0.0 then
    --     angle = angle + pi2
    -- end
    local nAngle = math.fmod(angle, pi2)
    if nAngle < 0.0 then
        nAngle = nAngle + pi2
    end
    return nAngle
end

function findClosestPointInList(pointList, ref)
    local dist = 100
    local point = nil
    for i, d in ipairs(pointList) do
        if not ref then
            if AI.GetDistanceTo(d.x, d.y) < dist then
                point = d
                dist = AI.GetDistanceTo(d.x, d.y)
            end
        else
            if AI.CalcDistance(ref.x, ref.y, d.x, d.y) < dist then
                point = d
                dist = AI.CalcDistance(ref.x, ref.y, d.x, d.y)
            end
        end
    end
    return point
end

function table_removeif(t, f)
    for i = #t, 1, -1 do
        if f(t[i]) then
            table.remove(t, i)
        end
    end
end

function normalizeObstacleRadius(radius)
    local plrInfo = AI.GetObjectInfo("player")
    -- local boundingRadius = plrInfo.boundingRadius or 0.5
    local scale = 1.1
    if plrInfo.objectScale and plrInfo.objectScale > scale then
        scale = plrInfo.objectScale    
    end
    return (radius * scale)
end
