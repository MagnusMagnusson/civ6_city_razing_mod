-- CityMigration
-- Author: Magnús
--------------------------------------------------------------
local settings = {};

function onCityRazed(cityInfo)
	-- This file ought to only be loaded 
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
		print("Total distance was 0. return early");
		return;
	end
	

	local refs = {};
	local died = 0;
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
				if(refs[chosenCity:GetName()] == nil) then
					refs[chosenCity:GetName()] = 1;
				else
					refs[chosenCity:GetName()] = refs[chosenCity:GetName()] + 1;
				end
				chosenCity:ChangePopulation(1);
			end
			print("Pop migrated to ", chosenCity:GetName());
		else 
			died = died + 1;
			print("Refugee died.", i, r, chance);
		end
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


loadBoolSetting("guaranteeRefugee", false);
loadIntSetting("refugeePerc", 5);
ExposedMembers.CityRazed.Add(onCityRazed);