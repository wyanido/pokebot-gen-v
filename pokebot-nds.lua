-----------------------
-- INITIALIZATION
-----------------------
local BOT_VERSION = "0.2.3-alpha"

console.clear()
console.log("Running Lua " .. _VERSION)
console.log("Pokebot NDS version " .. BOT_VERSION)

mbyte = memory.read_u8
mword = memory.read_u16_le
mdword = memory.read_u32_le

-- Requirements
json = require("lua\\json")
dofile("lua\\input.lua")
dofile("lua\\game_setup.lua")

pokemon = require("lua\\pokemon")

dofile("lua\\dashboard.lua")

-----------------------
-- LOGGING
-----------------------

os.execute("mkdir logs")

encounters = json.load("logs/encounters.json")
if not encounters then
    encounters = {}
else
    -- Send full encounter list to the dashboard to initialize
    comm.socketServerSend(json.encode({
        type = "encounters",
        data = encounters
    }) .. "\x00")
end

stats = json.load("logs/stats.json")
if not stats then
    stats = {
        total = {
            max_iv_sum = 0,
            shiny = 0,
            seen = 0
        },
        phase = {
            lowest_sv = 65535,
            seen = 0
        }
    }
end

target_log = json.load("logs/target_log.json")
if not target_log then
    target_log = {}
end

-- Also send stats and game info to the dashboard
comm.socketServerSend(json.encode({
    type = "stats",
    data = stats
}) .. "\x00")

comm.socketServerSend(json.encode({
    type = "init",
    data = {
        gen = gen,
        game = game_name
    }
}) .. "\x00")

-----------------------
-- GAME INFO POLLING
-----------------------

last_party_checksums = {}
party = {}

function get_party(force)
    local party_size = mbyte(offset.party_count)

    -- Get the checksums of all party members
    local checksums = {}
    for i = 0, party_size - 1 do
        table.insert(checksums, mword(offset.party_data + i * MON_DATA_SIZE + 0x06))
    end

    -- Check for changes in the party data
    -- Necessary for only sending data to the socket when things have changed
    if party_size == #party and not force then
        local party_changed = false

        for i = 1, #checksums, 1 do
            if checksums[i] ~= last_party_checksums[i] then
                party_changed = true
                break
            end
        end

        if not party_changed then
            return false
        end
    end

    -- Party changed, update info
    console.log("- Party updated ")
    last_party_checksums = checksums
    local new_party = {}

    for i = 1, party_size do
        local mon = pokemon.read_data(offset.party_data + (i - 1) * MON_DATA_SIZE)

        if mon then
            mon = pokemon.enrich_data(mon)

            -- Friendship is used to track egg cycles
            -- Converts cycles to steps
            if mon.isEgg == 1 then
                mon.friendship = mon.friendship * 256
                mon.friendship = math.max(0,
                    mon.friendship - mbyte(offset.step_counter) - mbyte(offset.step_cycle) * 256)
            end

            table.insert(new_party, mon)
        else
            -- If any party checksums fail, wait a frame and try again
            console.log("### Party checksum failed at slot " .. i .. ", retrying ###")
            emu.frameadvance()
            return get_party(true)
        end
    end

    party = new_party

    return true
end

function get_current_foes()
    if gen == 4 then
        foe = nil
    end

    -- Make sure it's not reading garbage non-battle data
    if mbyte(offset.battle_indicator) ~= 0x41 or mbyte(offset.foe_count) == 0 then
        foe = nil
    elseif not foe then -- Only update foe on battle start
        ::retry::
        local foe_table = {}
        local foe_count = mbyte(offset.foe_count)

        for i = 1, foe_count do
            local mon = pokemon.read_data(offset.current_foe + (i - 1) * MON_DATA_SIZE)

            if mon then
                mon = pokemon.enrich_data(mon)

                table.insert(foe_table, mon)
            else 
                console.log("### Foe checksum failed at slot " .. i .. ", retrying ### ")
                emu.frameadvance()
                goto retry
            end
        end

        foe = foe_table
    end
end

function get_game_state()
    local state = {}
    local map = mword(offset.map_header)
    local in_game = map ~= 0x0 and map <= MAP_HEADER_COUNT

    -- Set default values for the dashboard
    state = {
        map_matrix = 0,
        map_header = 0,
        map_name = "--",
        trainer_x = 0,
        trainer_y = 0,
        trainer_z = 0,
        phenomenon_x = 0,
        phenomenon_z = 0
    }

    -- Update in-game values
    if in_game then
        if gen == 4 then
            state = {
                map_matrix = mdword(offset.map_matrix),
                map_header = map,
                map_name = map_names[map + 1],
                trainer_x = mword(offset.trainer_x + 2),
                trainer_y = mword(offset.trainer_y + 2),
                trainer_z = mword(offset.trainer_z + 2)
            }
        else
            state = {
                selected_starter = mbyte(offset.selected_starter),
                starter_box_open = mbyte(offset.starter_box_open),
                map_matrix = mdword(offset.map_matrix),
                map_header = map,
                map_name = map_names[map + 1],
                trainer_x = mword(offset.trainer_x + 2),
                trainer_y = mword(offset.trainer_y + 2),
                trainer_z = mword(offset.trainer_z + 2),
                phenomenon_x = mword(offset.phenomenon_x + 2),
                phenomenon_z = mword(offset.phenomenon_z + 2),
                trainer_dir = mdword(offset.trainer_direction),
                in_battle = mbyte(offset.battle_indicator) == 0x41 and mbyte(offset.foe_count) > 0
            }
        end
    end

    state.in_game = in_game

    return state
end

function update_dashboard_recents()
    -- Send the latest encounter and updated bot stats to the dashboard
    comm.socketServerSend(json.encode({
        type = "encounters",
        data = {encounters[#encounters]}
    }) .. "\x00")

    comm.socketServerSend(json.encode({
        type = "stats",
        data = stats
    }) .. "\x00")
end

function frames_per_move()
    if gen == 4 then -- Temporary
        return 16
    end

    if mbyte(offset.on_bike) == 1 then
        return 4
    elseif mbyte(offset.running_shoes) == 0xE then
        return 8
    end

    return 16
end

function update_game_info(force)
    -- Refresh data at the rate it takes to move 1 tile
    local refresh_frames = frames_per_move() / 2

    if emu.framecount() % refresh_frames == 0 or force then
        game_state = get_game_state()
        comm.socketServerSend(json.encode({
            type = "game",
            data = game_state
        }) .. "\x00")
        
        get_current_foes()
    end

    local party_changed = get_party()
    if party_changed then
        comm.socketServerSend(json.encode({
            type = "party",
            data = party
        }) .. "\x00")
    end
end

function pause_bot(reason)
    clear_all_inputs()
    client.clearautohold()

    console.log("###################################")
    console.log(reason .. ". Pausing bot! (Make sure to disable the lua script before intervening)")
    
    -- Do nothing ever again
    while true do
        emu.frameadvance()
    end
end

-----------------------
-- MAIN BOT LOGIC
-----------------------

input = input_init()
update_game_info(true)

::begin::
clear_all_inputs()
client.clearautohold()

console.log("Bot mode set to " .. config.mode)
mode_real = config.mode

if config.save_game_on_start then
    save_game()
end

local mode = string.lower(config.mode)
local starter = -1

while true do
    if mode == "starters" then
        -- Alternate between starters specified in config and reset until one is a target
        if not config.starter0 and not config.starter1 and not config.starter2 then
            console.log("### At least one starter selection must be enabled in config for this bot mode ###")
            return
        end

        -- Cycle to next enabled starter
        starter = (starter + 1) % 3

        while not config["starter" .. tostring(starter)] do
            starter = (starter + 1) % 3
        end

        mode_starters(starter)
    elseif mode == "random encounters" then
        mode_random_encounters()
        -- Run back and forth until a random encounter is triggered, run if not a target
    elseif mode == "phenomenon encounters" then
        -- Run back and forth until a phenomenon spawns, then encounter it
        -- https://bulbapedia.bulbagarden.net/wiki/Phenomenon
        mode_phenomenon_encounters()
    elseif mode == "gift" then
        -- Receive a gift Pokemon and reset if not a target
        mode_gift()
    elseif mode == "daycare eggs" then
        -- Cycle to hatch and collect eggs until party is full, then release and repeat until a target is found
        mode_daycare_eggs()
    elseif mode == "manual" then
        -- No bot logic, just manual gameplay with a dashboard
        while true do
            while not game_state.in_battle do
                update_game_info()
                emu.frameadvance()
                poll_dashboard_response()

                -- Restart if config changed
                if mode_real ~= config.mode then
                    goto begin
                end
            end

            for i = 1, #foe, 1 do
                pokemon.log(foe[i])
                update_dashboard_recents()
            end

            while game_state.in_battle do
                update_game_info()
                emu.frameadvance()
                poll_dashboard_response()

                -- Restart if config changed
                if mode_real ~= config.mode then
                    goto begin
                end
            end
        end
    else
        console.log("Unknown bot mode: " .. config.mode)
        return
    end

    -- Restart if config changed
    if mode_real ~= config.mode then
        goto begin
    end

    joypad.set(input)
    emu.frameadvance()
    poll_dashboard_response()
    clear_unheld_inputs()
    update_game_info()
end
