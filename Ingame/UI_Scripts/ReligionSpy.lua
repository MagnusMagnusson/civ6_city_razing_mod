function GetReligionPressureGlobal()
    print("Measuring out city religion status.");
    local religionData = {};
    local players = PlayerManager.GetAlive();
    for i, player in ipairs(players) do
        --print(player);
        --print(" CITIES ");
        local cities = player:GetCities();
        for j, city in cities:Members() do
            --print("   ",city:GetName());
            local cityReligion = city:GetReligion();
            local religions = cityReligion:GetReligionsInCity();
            local cityData = {};
            --print(religions);
            --print(#religions);
            --print(religions[1]);
            for xx, religionTable in pairs(religions) do
                table.insert(cityData, {
                    Pressure = religionTable.Pressure, 
                    Followers = religionTable.Pressure, 
                    Religion = religionTable.Religion,
                })
            end
            religionData[city:GetID()] = cityData;
            print("Added City to ID", city:GetID());
        end
    end
    return religionData;
end

function GetReligionPressure(_x, _y)
    print("Finding City Religious Pressure");
    local religionData = {};
    local players = PlayerManager.GetAlive();
    for i, player in ipairs(players) do
        --print(player);
        --print(" CITIES ");
        local cities = player:GetCities();

        for j, city in cities:Members() do
            if(city:GetX() == _x and city:GetY() == _y) then 
                print(player:GetID(), " OWNER!!!");
                print(city:GetName());
                local cityReligion = city:GetReligion();
                local religions = cityReligion:GetReligionsInCity();
                local cityData = {};
                --print(religions);
                --print(#religions);
                --print(religions[1]);
                for xx, religionTable in pairs(religions) do
                    print(religionTable.Religion, religionTable.Pressure);
                    table.insert(cityData, {
                        Pressure = religionTable.Pressure, 
                        Followers = religionTable.Pressure, 
                        Religion = religionTable.Religion,
                    });
                end
                return cityData;
            end
        end
        print(player:GetID(), " Does not own the city");
    end
    print("Did not find city!?");
    return nil;
end

ExposedMembers.CityRazed.GetReligionPressure = GetReligionPressure; 
