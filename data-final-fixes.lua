local required_rocketparts = {}

for name, silo in pairs(data.raw["rocket-silo"]) do
    required_rocketparts[name] = silo.rocket_parts_required
end

data:extend({
    {
        type = "mod-data",
        name = "ml-required_rocketparts",
        data_type = "machine-levelup.required_rocketparts",
        data = required_rocketparts
    }
})
