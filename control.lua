local buckets = require("buckets")

local crafting_machines = {
    "assembling-machine", "rocket-silo", "furnace",
}

---@class Storage
---@field machines BucketsHandler<LuaEntity>
---@field levelup_threshold table<QualityID, uint>

local function calculate_thresholds()
    local thresholds = {}

    local exp = settings.global["ml-exp"].value --[[@as number]]
    local fac = settings.global["ml-fac"].value --[[@as number]]

    for name, quality in pairs(prototypes.quality) do
        local next = quality.next
        if not next then goto continue end

        thresholds[name] = math.ceil(math.pow(math.log(next.level + 1), exp) * fac)

        ::continue::
    end

    storage.levelup_threshold = thresholds
end

local function init()
    ---@type Storage
    storage = storage or {}
    storage.machines = storage.machines or buckets.new(120) --[[@as BucketsHandler<LuaEntity>]]

    calculate_thresholds()

    for _, surface in pairs(game.surfaces) do
        local existing_machines = surface.find_entities_filtered({ type = crafting_machines })

        for _, machine in pairs(existing_machines) do
            buckets.insert(storage.machines, machine)
        end
    end
end

script.on_init(init)
script.on_configuration_changed(calculate_thresholds)

local ev = defines.events
script.on_event(ev.on_runtime_mod_setting_changed, calculate_thresholds)

---@param event
---| EventData.on_built_entity
---| EventData.on_robot_built_entity
---| EventData.on_space_platform_built_entity
---| EventData.script_raised_built
---| EventData.script_raised_revive
---| EventData.on_entity_cloned
local function track_machine(event)
    local entity = event.entity or event.destination
    if not entity.valid then return end

    buckets.insert(storage.machines, entity)
end

local filter = { { filter = "crafting-machine" } }
for _, e in pairs({
    ev.on_built_entity,
    ev.on_robot_built_entity,
    ev.on_space_platform_built_entity,
    ev.script_raised_built,
    ev.script_raised_revive,
    ev.on_entity_cloned
}) do
    script.on_event(e, track_machine, filter)
end

local required_rocketparts = prototypes.mod_data["ml-required_rocketparts"].data --[[@as table<string, uint>]]

---@param machine LuaEntity
---@return boolean
local function upgrade_machine(machine)
    if not machine.valid then return false end

    local current_q = machine.quality
    local threshold = storage.levelup_threshold[current_q.name]
    if not threshold then return false end

    local finished = machine.products_finished * (required_rocketparts[machine.name] or 1)
    if finished < threshold then
        return true
    end

    -- threshold reached, check if next quality is unlocked
    if not machine.force.is_quality_unlocked(current_q.next) then
        return true
    end

    -- next quality is available, upgrade machine
    machine.order_upgrade({
        target = {
            name = machine.name,
            quality = current_q.next,
        },
        force = machine.force,
    })

    machine.apply_upgrade()
    return false
end

script.on_event(ev.on_tick, function()
    buckets.filter_bucket(storage.machines, upgrade_machine)
end)

script.on_nth_tick(60 * 60 * 30, function()
    buckets.rebalance(storage.machines)
end)
