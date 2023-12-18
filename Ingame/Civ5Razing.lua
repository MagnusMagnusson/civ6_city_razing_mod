-- onCityRazed
-- Author: Magnus
-- DateCreated: 10/21/2023 11:49:34 PM
--------------------------------------------------------------

local CityWatch = {};
local settings = {};
local RAZING_BUILDING;

for building in GameInfo.Buildings() do
    if(building.BuildingType == 'BUILDING_CIV5_RAZE') then
        RAZING_BUILDING = building;
    end
end

function onCityRazed(cityInfo)
    local originalOwner = PlayerManager.GetPlayer(cityInfo.originalOwner);
    local city = originalOwner:GetCities():Create(cityInfo.x, cityInfo.y);
    local freeCityPlayer =PlayerManager.GetFreeCitiesPlayer():GetID();
    city:SetName(cityInfo.Name);
    city:ChangePopulation(cityInfo.population - 1);
    RestoreTerritory(city, cityInfo);
    RestoreDistricts(city, cityInfo);
    RestoreBuildings(city, cityInfo);
    CityManager.TransferCity(city, freeCityPlayer);
    CleanupFreeUnits(city, cityInfo);
end

function CleanupFreeUnits(city, cityInfo)
    -- Tranfering cities to the Free City Player spawns a couple of hostile units. We don't want this, so we kill them instantly --
    local freeCityPlayer = PlayerManager.GetFreeCitiesPlayer();
    local units = freeCityPlayer:GetUnits();
    local bannedPlots = Set(cityInfo.plots);

    for i, unit in units:Members() do 
        local plotId = Map.GetPlot(unit:GetX(), unit:GetY()):GetIndex();
        if(bannedPlots[plotId]) then
            UnitManager.Kill(unit);
        end
    end
end

function Set (list)
    -- Helper function, turns a list into set --
    local set = {}
    for _, l in ipairs(list) do set[l] = true end
    return set
end

  
function RestoreTerritory(city, cityInfo)    
    -- Restore Territory. By default cities only have their imminent territory, but we want to restore the entire territory --
	local freeCityPlayer = PlayerManager.GetFreeCitiesPlayer();
    for i, plotIndex in pairs(cityInfo.plots) do
        local pPlot = Map.GetPlotByIndex(plotIndex);
        WorldBuilder.CityManager():SetPlotOwner( pPlot:GetX(), pPlot:GetY(), cityInfo.originalOwner, city:GetID() );
    end
end

function RestoreDistricts(city, cityInfo)
    -- Rebuild all the lost districts of the city --
    local queue = city:GetBuildQueue();
    for i, district in pairs(cityInfo.Districts) do
        if(district.districtType ~= 0) then
            -- We skip the city center, but otherwise restore the other districts the city used to have --
            queue:CreateDistrict(district.districtType, Map.GetPlot(district.x, district.y):GetIndex());    
        end
    end
end

function RestoreBuildings(city, cityInfo)    
    -- Rebuild all the buildings the city used to have --
    local queue = city:GetBuildQueue();
    for i, buildingRow in pairs(cityInfo.Buildings) do
        local pPlot = Map.GetPlotByIndex(buildingRow.location);
        queue:CreateBuilding(buildingRow.index, pPlot:GetX(), pPlot:GetY());
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

function loadBoolSetting(key, default)	
	if(GameInfo.MCR_CONFIG[key] ~= nil) then	
		settings[key] = GameInfo.MCR_CONFIG[key].value == "1";
	else
		settings[key] = default
	end
end

function loadIntSetting(key, default)	
	if(GameInfo.MCR_CONFIG[key] ~= nil) then	
	settings[key] = tonumber(GameInfo.MCR_CONFIG[key].value);
	else
		settings[key] = default
	end
end

function OnTurnEnded()
    CityWatch = {}; --Done, all cities ought to have been razed or not razed by now.

    -- Scan over all free cities. If any of them have the razing city then that city is being razed, and we must decrement the pops it has (or destroy it) --
	local freeCityPlayer = PlayerManager.GetFreeCitiesPlayer();
    local cities = freeCityPlayer:GetCities();
    for i, city in cities:Members() do
        if(city:GetBuildings():HasBuilding(RAZING_BUILDING.Index)) then
            local pop = city:GetPopulation();
            if(pop == 1) then
                CityManager.DestroyCity(city);
            else
                city:ChangePopulation(-1);
            end
        end
    end
end

local debug = true;

function init()	
	loadBoolSetting("civ5_razing_style", false);
    -- Do nothing unless civ5 styled razing is enabled for the game --
    if(debug == true or settings["civ5_razing_style"] == true) then 
        GameEvents.CityConquered.Add(OnCityConquered);
        Events.CityRemovedFromMap.Add(onCityRemoved);
        Events.TurnEnd.Add(OnTurnEnded);
    end
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
            onCityRazed(cityInfo);
		end
	end
end

init();

function test(cityInfo) 
    print(cityInfo.Name);
    print(cityInfo.Name);
    print(cityInfo.Name);
    print(cityInfo.Name);
    print(cityInfo.Name);
    print(cityInfo.Name);
    print(cityInfo.Name);
    print(cityInfo.Name);
    print(cityInfo.Name);
    print(cityInfo.Name);
    print(cityInfo.Name);
    print(cityInfo.Name);
    print(cityInfo.Name);
end

print("Does CityRazed Exist?");
print(ExposedMembers.CityRazed.Add);
ExposedMembers.CityRazed.Add(test);
print("Added");