ffxiv_task_fish = inheritsFrom(ml_task)
ffxiv_task_fish.name = "LT_FISH"

function ffxiv_task_fish:Create()
    local newinst = inheritsFrom(ffxiv_task_fish)
    
    --ml_task members
    newinst.valid = true
    newinst.completed = false
    newinst.subtask = nil
    newinst.auxiliary = false
    newinst.process_elements = {}
    newinst.overwatch_elements = {}
    
    --ffxiv_task_fish members
    newinst.castTimer = 0
    newinst.markerTime = 0
    newinst.currentMarker = false
    newinst.previousMarker = false
    newinst.baitName = ""
    newinst.castFailTimer = 0
    
    return newinst
end

c_cast = inheritsFrom( ml_cause )
e_cast = inheritsFrom( ml_effect )
function c_cast:evaluate()
    local castTimer = ml_task_hub:CurrentTask().castTimer
    if (ml_global_information.Now > castTimer) then
        local fs = tonumber(Player:GetFishingState())
        if (fs == 0 or fs == 4) then
            return true
        end
    end
    return false
end
function e_cast:execute()
    local mooch = ActionList:Get(297,1)
    if (mooch) and gUseMooch == "1" and Player.level > 24 and (mooch.isready) then
        mooch:Cast()
    else
        local cast = ActionList:Get(289,1)
        if (cast and cast.isready) then			
            cast:Cast()
        end
    end
end

-- Has to get called, else the dude issnot moving thanks to "runforward" usage ;)
c_finishcast = inheritsFrom( ml_cause )
e_finishcast = inheritsFrom( ml_effect )
function c_finishcast:evaluate()
    local castTimer = ml_task_hub:CurrentTask().castTimer
    if (ml_global_information.Now > castTimer) then
        local fs = tonumber(Player:GetFishingState())
        if (fs ~= 0 and c_returntomarker:evaluate()) then
            return true
        end
    end
    return false
end
function e_finishcast:execute()
    local finishcast = ActionList:Get(299,1)
    if (finishcast and finishcast.isready) then
        finishcast:Cast()
    end
end

c_bite = inheritsFrom( ml_cause )
e_bite = inheritsFrom( ml_effect )
function c_bite:evaluate()
    local castTimer = ml_task_hub:CurrentTask().castTimer
    if (ml_global_information.Now > castTimer) then
        local fs = tonumber(Player:GetFishingState())
        if( fs == 5 ) then -- FISHSTATE_BITE
            return true
        end
    end
    return false
end
function e_bite:execute()
    local bite = ActionList:Get(296,1)
    if (bite and bite.isready) then
        bite:Cast()
    end
end

c_setbait = inheritsFrom( ml_cause )
e_setbait = inheritsFrom( ml_effect )
function c_setbait:evaluate()
    if (gGMactive == "1") then
        local fs = tonumber(Player:GetFishingState())
        if (fs == 0 or fs == 4) then
            local marker = ml_task_hub:CurrentTask().currentMarker
            if (marker ~= nil and marker ~= false) then
                local data = GatherMgr.GetMarkerData(marker)
                if data[1] ~="None" and data[1] ~= ml_task_hub:CurrentTask().baitName then
                    return true
                end
            end
        end
    end
    return false
end
function e_setbait:execute()
	ml_debug("Attempting to set bait for marker "..ml_task_hub:CurrentTask().currentMarker)
    local marker = ml_task_hub:CurrentTask().currentMarker
    if (marker ~= nil and marker ~= false) then
        local data = GatherMgr.GetMarkerData(marker)
        if (data ~= nil and data ~= 0) then
            local _,bait = next(data)
            if (bait ~= nil and bait ~= "") then
				ml_debug("Looking for bait named "..bait)
				local found = false
                for i = 0,4 do
                    local inventory = Inventory("type="..tostring(i))
                    if (inventory ~= nil and inventory ~= 0) then
                        for _,item in ipairs(inventory) do
                            if item.name == bait then
                                Player:SetBait(item.id)
                                ml_task_hub:CurrentTask().baitName = item.name
								found = true
                            end
                        end
                    end
                end
				
				if not found then
					ml_error("Could not find bait! Deactivating gather manager and attempting to use current bait")
					gGMactive = "0"
				end
            end
        end
    end
end

function ffxiv_task_fish:Init()

    --init ProcessOverwatch() cnes
    local ke_dead = ml_element:create( "Dead", c_dead, e_dead, 20 )
    self:add( ke_dead, self.overwatch_elements)
    
    local ke_stealth = ml_element:create( "Stealth", c_stealth, e_stealth, 15 )
    self:add( ke_stealth, self.overwatch_elements)
  
    --init Process() cnes
    local ke_finishcast = ml_element:create( "FinishingCast", c_finishcast, e_finishcast, 30 )
    self:add(ke_finishcast, self.process_elements)
    
    local ke_returnToMarker = ml_element:create( "ReturnToMarker", c_returntomarker, e_returntomarker, 25 )
    self:add( ke_returnToMarker, self.process_elements)
    
    --nextmarker defined in ffxiv_task_gather.lua
    local ke_nextMarker = ml_element:create( "NextMarker", c_nextmarker, e_nextmarker, 20 )
    self:add( ke_nextMarker, self.process_elements)
    
    local ke_setbait = ml_element:create( "SetBait", c_setbait, e_setbait, 10 )
    self:add(ke_setbait, self.process_elements)
    
    local ke_cast = ml_element:create( "Cast", c_cast, e_cast, 5 )
    self:add(ke_cast, self.process_elements)
    
    local ke_bite = ml_element:create( "Bite", c_bite, e_bite, 5 )
    self:add(ke_bite, self.process_elements)
   
    
    self:AddTaskCheckCEs()
end

function ffxiv_task_fish:OnSleep()

end

function ffxiv_task_fish:OnTerminate()

end

function ffxiv_task_fish:IsGoodToAbort()

end

-- UI settings etc
function ffxiv_task_fish.UIInit()
    GUI_NewCheckbox(ml_global_information.MainWindow.Name, strings[gCurrentLanguage].ignoreMarkerLevels, "gIgnoreFishLvl",strings[gCurrentLanguage].fishMode)
	GUI_NewCheckbox(ml_global_information.MainWindow.Name, strings[gCurrentLanguage].useMooch, "gUseMooch",strings[gCurrentLanguage].fishMode)
    GUI_NewCheckbox(ml_global_information.MainWindow.Name, strings[gCurrentLanguage].useStealth, "gDoStealthFish",strings[gCurrentLanguage].fishMode)
    GUI_SizeWindow(ml_global_information.MainWindow.Name,250,400)
    
    if (Settings.FFXIVMINION.gIgnoreFishLvl == nil) then
        Settings.FFXIVMINION.gIgnoreFishLvl = "0"
    end
	
	if (Settings.FFXIVMINION.gUseMooch == nil) then
        Settings.FFXIVMINION.gUseMooch = "1"
    end
    
    if (Settings.FFXIVMINION.gDoStealthFish == nil) then
        Settings.FFXIVMINION.gDoStealthFish = "0"
    end
    
    gIgnoreFishLvl = Settings.FFXIVMINION.gIgnoreFishLvl
	gUseMooch = Settings.FFXIVMINION.gUseMooch
	gDoStealthFish = Settings.FFXIVMINION.gDoStealthFish
    
    RegisterEventHandler("GUI.Update",ffxiv_task_fish.GUIVarUpdate)
end

function ffxiv_task_fish.GUIVarUpdate(Event, NewVals, OldVals)
    for k,v in pairs(NewVals) do
        if 	( k == "gIgnoreFishLvl" ) or
			( k == "gUseMooch" ) or
            ( k == "gDoStealthFish" )
        then
            Settings.FFXIVMINION[tostring(k)] = v
        end
    end
    GUI_RefreshWindow(ml_global_information.MainWindow.Name)
end