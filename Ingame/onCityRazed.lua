-- onCityRazed
-- Author: Magnus
-- DateCreated: 10/21/2023 11:49:34 PM
--------------------------------------------------------------

local CityWatch = {};
local settings = {};

function onCityRazed(cityInfo)
	--Grant Settler if the owner isn't out--
	print("OnCityRazed");
	if(settings["giveSettler"] == true) then
		print("giveSettler enabled");
		giveSettler(cityInfo.oldOwner, 1);
	else 
		print("giveSettler not enabled");
	end

	if(settings["refugeePerc"] ~= "0") then 
		MigratePop(cityInfo, settings["refugeePerc"]);
	end
end

function MigratePop(cityInfo, chance)
	print("Trying to migrate pops!");
	local pop = cityInfo.population;
	local razed_x = cityInfo.x;
	local razed_y = cityInfo.y;
	local oldOwner = cityInfo.oldOwner;
	if(playerExists(oldOwner) == false or pop <= 1) then 
		return;
	end
	local totalDistances = 0;
	local candidates = {};
	local owner = PlayerManager.GetPlayer(oldOwner);
	print("Calculating distances to nearby cities");
	--Get Nearby Cities--
	for i,city in owner:GetCities():Members() do 
		local _x, _y, d;
		_x = city:GetX();
		_y = city:GetY();
		d = (math.abs(razed_x - _x) + math.abs(razed_y - _y));
		local dScore = math.max(1, 50 - d);
		dScore = dScore * dScore;
		totalDistances = totalDistances + dScore;
		table.insert(candidates, {
			city = city,
			distanceScore = dScore
		});
	end

	if(totalDistances == 0) then
		--Somehow we had no cities?--
		print("Total distance was 0?! return early");
		return;
	end
	

	print("Distributing refugees");
	if(settings["guaranteeRefugee"]) then
		chance = chance / 10;
	end
	-- Start Distributing Pops --
	for i = 0, pop - 1 do 
		local r;
		if(settings["guaranteeRefugee"]) then
			r = i / (pop - 1);
		else
			r = Game.GetRandNum(10, "Migrating Razed Pop");
		end
		if(r < chance) then 
			print("Refugee made it!", i, r, chance);
			local roll = Game.GetRandNum(totalDistances, "Deciding where migrated pop goes");
			local x = 0;
			local chosenCity = nil;
			for i, city in ipairs(candidates) do 
				x = x + city.distanceScore;
				if(x >= roll) then 
					chosenCity = city.city;
					break;
				end
			end
			if(chosenCity ~= nil) then 
				chosenCity:ChangePopulation(1);
			end
			print("Pop migrated to ", chosenCity:GetName());
		else 
			print("Refugee died.", i, r, chance);
		end
	end
end

function giveSettler(playerId, count)
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

function CityConquered(newOwner, oldOwner, cityId)
	-- Safety check -- 
	if(newOwner == nil or playerExists(oldOwner) == false or cityId == nil) then
		print("One or both players involved are not eligable for razing benefits", newOwner, oldOwner, cityId);
		return;
	end

	print("City was just captured, ", newOwner, oldOwner, cityId);

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

	local row = {
		newOwner = newOwner,
		oldOwner = oldOwner,
		cityId = cityId,
		population = pop,
		x = city:GetX(),
		y = city:GetY(),
		razed = false,
	}
	table.insert(CityWatch, row);
end


function GetCityId(ownerId, cityId) 
	local p = PlayerManager.GetPlayer(ownerId);
	return p:GetCities():FindID(cityId)
end

function playerExists(playerId) 
	return playerId ~= nil 
	and PlayerManager.GetPlayer(playerId) ~= nil
	and PlayerManager.GetPlayer(playerId):IsAlive() ~= false
	and PlayerManager.GetPlayer(playerId):IsMajor() == true;
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
	print("Turn Ended!");
	for i, cityInfo in ipairs(CityWatch) do
		--Because the various events are in a bad order, just check at the end of a turn if any captured cities are still there. 
		print("Testing", cityInfo.cityId);
		print(cityInfo.x, cityInfo.y)
		local plot = Map.GetPlot(cityInfo.x, cityInfo.y);
		if(plot:IsCity()) then
			print("City survived", cityInfo.cityId);
		else
			print("City razed, giving benefits", cityInfo.cityId);
			onCityRazed(cityInfo);
		end
	end
	CityWatch = {};
end

function init()	
	loadBoolSetting("giveSettler", false);
	loadBoolSetting("guaranteeRefugee", false);
	loadIntSetting("refugeePerc", 5);
end

GameEvents.CityConquered.Add(CityConquered);
Events.TurnEnd.Add(OnTurnEnded);
init();