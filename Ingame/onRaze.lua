
local CityWatch = {};      
local Callbacks = {};
local RAZING_BUILDING;

for building in GameInfo.Buildings() do
    if(building.BuildingType == 'BUILDING_CIV5_RAZE') then
        RAZING_BUILDING = building;
    end
end


function OnCityConquered(newOwner, oldOwner, cityId)
	-- The city has been captured and changed hands. This is explicitly not destruction, that comes later. --
    -- This is where we note down the city that got captured and details about it, and then start paying attention to it in case it gets razed--
	if(newOwner == nil or cityId == nil or oldOwner == nil) then
	    -- Safety check to make sure we aren't missing info we need --
		print("Error: Safety check failed: newOwner, oldOwner, or CityId is missing", newOwner, oldOwner, cityId);
		return;
	end

	local city = GetCityId(newOwner, cityId);
	local pop = city:GetPopulation();
	for i,cityInfo in ipairs(CityWatch) do
		if(cityInfo.x == city:GetX() and cityInfo.y == city:GetY()) then
            -- If the city is recaptured in a single turn we must adjust the city watch, as the city ID may change.
			cityInfo.newOwner = newOwner;
			cityInfo.cityId = cityId;
			cityInfo.population = pop;
            cityInfo.Name = city:GetName();
			return;
		end
	end

    -- Capture the current state of the city: Territory, District, Buildings
    local districts = GetCityDistricts(city);
    local buildings = GetCityBuildings(city);
    local plots = GetCityPlots(city);

    -- Save city data to the city watch, so if the city is razed and all the data is lost we can recreate it -- 
	local row = {
		newOwner = newOwner,
		originalOwner = city:GetOriginalOwner(),
		cityId = cityId,
		population = pop,
		x = city:GetX(),
		y = city:GetY(),
		Name = city:GetName(),
        Districts = districts,
        Buildings = buildings,
        plots = plots
	}
	table.insert(CityWatch, row);
end


function GetCityPlots(city)
    -- Technically we don't need much beyond GetOwnedPlots(), but dragging this out in case we want to capture other plot data later, like features --
    local plots = {};
	for i, plot in pairs(city:GetOwnedPlots()) do 
        table.insert(plots, plot:GetIndex());
    end
    return plots;
end

function GetCityDistricts(city)
    local districts = {};
    local distNum = city:GetDistricts():GetNumDistricts();
	for i = 0, distNum - 1  do 
        local dist = city:GetDistricts():GetDistrictByIndex(i);
        local distRow = {
            districtType = dist:GetType(),
            x = dist:GetX(),
            y = dist:GetY()
        }
        table.insert(districts, distRow);
    end
    return districts;
end

function GetCityBuildings(city)
    local buildings = {};
    for building in GameInfo.Buildings() do
        local buildingIndex = building.Index
        if city:GetBuildings():HasBuilding(buildingIndex) or building.Index == RAZING_BUILDING.Index then
            local location;
            if(city:GetBuildings():HasBuilding(buildingIndex)) then
                -- A normal building. Note where it is located --
                location = city:GetBuildings():GetBuildingLocation(buildingIndex)
            else
                -- Razing building. Cities aren't supposed to have it, so we explicity target the city center --
                location = city:GetPlot():GetIndex() 
            end
            local b = {
                index = buildingIndex,
                location = location
            }
            table.insert(buildings, b);
        end
    end
    return buildings;
end

function GetCityId(ownerId, cityId) 
	local p = PlayerManager.GetPlayer(ownerId);
	return p:GetCities():FindID(cityId)
end


function onCityRemoved(pid, cid)    
    -- A city has been removed from the map. Now to check if there is still a city on the plot. 
    -- When cities change ownership they are temporarily removed from the map and added again, triggering this function 
    -- Therefore we must go over the cities we marked as having been captured this turn, and if the city is gone we presume it has been razed.
    -- If it is still there then it probably wasn't razed.
    -- We just hope that nobody nuked the captured city and accidentally trigger this function. 
    for i, cityInfo in ipairs(CityWatch) do
		local plot = Map.GetPlot(cityInfo.x, cityInfo.y);
		if(plot:IsCity() ~= true) then
            --City razed, let's recreate it--
            for i, func in ipairs(Callbacks) do
                func(cityInfo);
            end
		end
	end
end

function onTurnEnded()
    -- At this point we ought to have already determined if a city is razed or not, since you must raze the same turn you capture. --
    CityWatch = {};
end

GameEvents.CityConquered.Add(OnCityConquered);
Events.CityRemovedFromMap.Add(onCityRemoved);
Events.TurnEnd.Add(OnTurnEnded);

function Add(func)
    table.insert(Callbacks, func);
end
ExposedMembers.CityRazed = {
    Add = Add 
};