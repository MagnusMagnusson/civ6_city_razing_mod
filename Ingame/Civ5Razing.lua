-- Civ5Razing.lua
-- Author: Magnús
-- Handles implementing the Civ5 raze over time functionality
--------------------------------------------------------------
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

ExposedMembers.CityRazed.Add(onCityRazed);
Events.TurnEnd.Add(OnTurnEnded);