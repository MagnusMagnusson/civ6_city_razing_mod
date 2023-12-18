-- onCityRazed
-- Author: Magnus
-- DateCreated: 10/21/2023 11:49:34 PM
--------------------------------------------------------------

local CityWatch = {};
local settings = {};
print("Civ Razing!");

function onCityRazed(cityInfo)
	local freeCityPlayer = PlayerManager.GetFreeCitiesPlayer();
    local city = freeCityPlayer:GetCities():Create(cityInfo.x, cityInfo.y);
    city:SetName(cityInfo.Name);
    city:ChangePopulation(cityInfo.population - 1);
    RestoreTerritory(city, cityInfo);
    RestoreDistricts(city, cityInfo);
    RestoreBuildings(city, cityInfo);
end

function RestoreTerritory(city, cityInfo)    
    --Restore Territory
	local freeCityPlayer = PlayerManager.GetFreeCitiesPlayer();
    for i, plotIndex in pairs(cityInfo.plots) do
        local pPlot = Map.GetPlotByIndex(plotIndex);
        WorldBuilder.CityManager():SetPlotOwner( pPlot:GetX(), pPlot:GetY(), freeCityPlayer:GetID(), city:GetID() );
    end
end

function RestoreDistricts(city, cityInfo)
    local queue = city:GetBuildQueue();
    for i, district in pairs(cityInfo.Districts) do
        if(district.districtType ~= 0) then
            print(Map.GetPlot(district.x, district.y));
            queue:CreateDistrict(district.districtType, Map.GetPlot(district.x, district.y):GetIndex());    
        else
            print("Skipping city center!");
        end
    end
end

function RestoreBuildings(city, cityInfo)    
    local queue = city:GetBuildQueue();
    print("Restore Buildings start");
    for i, buildingRow in pairs(cityInfo.Buildings) do
        print(buildingRow.index, buildingRow.location);
        local pPlot = Map.GetPlotByIndex(buildingRow.location);
        print(pPlot:GetX(), pPlot:GetY());
        queue:CreateBuilding(buildingRow.index, pPlot:GetX(), pPlot:GetY());
    end
end

function giveSettler(playerId)
	print("giveSettler()");
	if(playerExists(playerId)) then 	
		local owner = PlayerManager.GetPlayer(playerId)
		for i = 0, count - 1 do 
			local capital = owner:GetCities():GetCapitalCity();
			local settler = GameInfo.Units["UNIT_SETTLER"];
			owner:GetUnits():Create(settler, capital:GetX(), capital:GetY());
		end
	end
end

function OnCityConquered(newOwner, oldOwner, cityId)
    print("CityConquered!", newOwner, oldOwner, cityId)
	-- Safety check -- 
	if(newOwner == nil or cityId == nil) then
		print("Someone is missing!", newOwner, cityId);
		return;
	end

	--print("City was just captured, ", newOwner, oldOwner, cityId);

	local city = GetCityId(newOwner, cityId);
	local pop = city:GetPopulation();

	for i,cityInfo in ipairs(CityWatch) do
		if(cityInfo.x == city:GetX() and cityInfo.y == city:GetY()) then
			cityInfo.oldOwner = oldOwner;
			cityInfo.newOwner = newOwner;
			cityInfo.cityId = cityId;
			cityInfo.population = pop;
			print("City recaptured in one turn, updating watch");
			return;
		end
	end

	print("City not transferred, adding to watch list");

    local districts = {};
    local distNum = city:GetDistricts():GetNumDistricts();
    print(distNum);
	for i = 0, distNum - 1  do 
        local dist = city:GetDistricts():GetDistrictByIndex(i);
        local distRow = {
            districtType = dist:GetType(),
            x = dist:GetX(),
            y = dist:GetY()
        }
        table.insert(districts, distRow);
    end
    
    local buildings = GetCityBuildings(city);
        
    local plots = {};
	for i, plot in pairs(city:GetOwnedPlots()) do 
        table.insert(plots, plot:GetIndex());
    end

	local row = {
		newOwner = newOwner,
		oldOwner = oldOwner,
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


function GetCityBuildings(city)
    local buildings = {};
    for building in GameInfo.Buildings() do
        local buildingIndex = building.Index
        if city:GetBuildings():HasBuilding(buildingIndex) then
            local b = {
                index = buildingIndex,
                location = city:GetBuildings():GetBuildingLocation(buildingIndex)
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
	print("Ended Turn");
end

function init()	
    print("Initi civ5");
	--loadBoolSetting("giveSettler", false);
	--loadBoolSetting("guaranteeRefugee", false);
	--loadIntSetting("refugeePerc", 5);
end

function onCityRemoved(pid, cid)     
    print("City Removed", playerId, cityId);

    for i, cityInfo in ipairs(CityWatch) do
		--Because the various events are in a bad order, just check at the end of a turn if any captured cities are still there. 
		print("Testing", cityInfo.cityId);
		print(cityInfo.x, cityInfo.y)
		local plot = Map.GetPlot(cityInfo.x, cityInfo.y);
		if(plot:IsCity()) then
			print("Removal: City there", cityInfo.cityId);
		else
			print("Removal: City gone", cityInfo.cityId);
            onCityRazed(cityInfo);
		end
	end
end

GameEvents.CityConquered.Add(OnCityConquered);
Events.CityRemovedFromMap.Add(onCityRemoved);
Events.TurnEnd.Add(OnTurnEnded);
init();