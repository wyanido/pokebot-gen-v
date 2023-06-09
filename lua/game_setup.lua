
function update_key_offsets(offset)
	-- -- Map Header
	-- local dword = 0
	-- local seek = 0x0226D420

	-- while dword ~= 0x5E744E55 do
	-- 	dword = mdword(seek)
	-- 	seek = seek + 0x4
	-- 	emu.frameadvance()
	-- end

	-- seek = seek + 156
	-- console.log("Found party offset at " .. string.format("%08X", seek) .. "!!")

	-- Party Data
	local dword = 0
	local seek = 0x0226D420

	while dword ~= 0x5E744E55 do
		dword = mdword(seek)
		seek = seek + 0x4
		emu.frameadvance()
	end

	seek = seek + 156

	offset.party_count = seek
	offset.party_data = seek + 4

	console.log("### Updated RAM offsets ###")

	return offset
end

local function get_offset_dp(game)
	-- Configured for Diamond

	local offset = { 
		-- Bag pockets
		-- items_pocket		= 0x0,
		-- medicine_pocket		= 0x0, 
		-- poke_balls_pocket	= 0x0, 
		-- tms_hms_pocket		= 0x0, 
		-- berries_pocket		= 0x0, 
		-- mail_pocket			= 0x0,
		-- battle_items_pocket = 0x0,
		-- key_items_pocket	= 0x0,
		
		-- Location
		trainer_x			= 0x0226E7A2,
		trainer_y			= 0x0226E7B0,
		trainer_z			= 0x0226E7A6,
		trainer_direction	= 0x02291DB4, -- 0: Up, 1: Down, 2: Left, 3: Right

		map_header 			= 0x0226E79C,
		map_matrix			= 0x0228FE26,

		-- Misc testing
		starters_ready		= 0x022AFE14, -- 0 before hand appears, random number afterwards
		selected_starter	= 0x022AFD90, -- 0: Turtwig, 1: Chimchar, 2: Piplup
	}

	-- The party data offset isn't consistent, so find it manually
	offset = update_key_offsets(offset)
	
	return offset
end

local function get_offset_bw(game)
	local wt = 0x20 * game -- White version is offset slightly

	return {
		-- Bag pouches, 4 byte pairs | 0001 0004 = 4x Master Ball
		items_pouch			= 0x02233FAC + wt, -- 1240 bytes long
		key_items_pouch		= 0x02234484 + wt, -- 332 bytes long
		tms_hms_case		= 0x022345D0 + wt, -- 436 bytes long
		medicine_pouch		= 0x02234784 + wt, -- 192 bytes long
		berries_pouch		= 0x02234844 + wt, -- 234 bytes long
		
		running_shoes		= 0x0223C054 + wt, -- 14 after receiving 

		-- Party
		party_count			= 0x022349B0 + wt, -- 4 bytes before first index
		party_data			= 0x022349B4 + wt, -- PID of first party member
		
		step_counter 		= 0x02235125 + wt,
		step_cycle	 		= 0x02235126 + wt,

		-- Location
		map_header 			= 0x0224F90C + wt,
		-- trainer_name		= 0x24FC00 + wt,
		-- Read the lower word for map-local coordinates
		trainer_x			= 0x0224F910 + wt,
		trainer_y			= 0x0224F914 + wt,
		trainer_z			= 0x0224F918 + wt,
		trainer_direction	= 0x0224F924 + wt, -- 0, 4, 8, 12 -> Up, Left, Down, Right
		on_bike				= 0x0224F94C + wt,
		encounter_table		= 0x0224FFE0 + wt,
		map_matrix			= 0x02250C1C + wt,

		phenomenon_x		= 0x02257018 + wt,
		phenomenon_z		= 0x0225701C + wt,

		egg_hatching		= 0x0226DF68 + wt,
		
		-- Map tile data
		-- 0x2000 bytes, 8 32x32 layers that can be in any order
		-- utilised layers prefixed with 0x20, unused 0x00
		-- layer order is not consistent, is specified by the byte above 0x20 flag
		-- C0 = Collision (Movement)
		-- 80 = Flags
		
		-- instances separated by 0x1B4D0 bytes
		-- nuvema_1 	= 0x2C4670, -- when exiting cheren's house
		-- nuvema_2		= 0x2DFB38, -- when exiting bianca's house
		-- nuvema_3 	= 0x2FB008, -- when loaded normally
		-- nuvema_4 	= 0x3164D0, -- when exiting home or juniper's lab or flying
		
		-- Battle
		battle_indicator	= 0x0226ACE6 + wt, -- 0x41 if during a battle
		foe_count			= 0x0226ACF0 + wt, -- 4 bytes before the first index
		current_foe			= 0x0226ACF4 + wt, -- PID of foe, set immediately after the battle transition ends

		-- Misc testing
		save_indicator		= 0x021F0100 + wt,
		starter_box_open 	= 0x022B0C40 + wt, -- 0 when opening gift, 1 at starter select
		battle_menu_state	= 0x022D6B04 + wt, -- 1 on FIGHT menu, 2 on move select, 4 on switch/run after faint, 0 otherwise
		battle_bag_page		= 0x022962C8 + wt,
		selected_starter 	= 0x02269994 + wt, -- Unconfirmed selection in gift box; 0 Snivy, 1 Tepig, 2 Oshawott, 4 Nothing
	}
end

-- Version data
local ver = {
	DIAMOND_U = {
		code = 0x45414441,
		name = "Pokemon Diamond Version (U)",
		gen = 4,
		version = 0,
	},
	PEARL_U = {
		code = 0x45415041,
		name = "Pokemon Pearl Version (U)",
		gen = 4,
		version = 1,
	},
	PLATINUM_U = {
		code = 0x45555043,
		name = "Pokemon Platinum Version (U)",
		gen = 4,
		version = 2,
	},
	HEARTGOLD_U = {
		code = 0x454B5049,
		name = "Pokemon HeartGold Version (U)",
		gen = 4,
		version = 0,
	},
	SOULSILVER_U = {
		code = 0x45475049,
		name = "Pokemon SoulSilver Version (U)",
		gen = 4,
		version = 1,
	},
	BLACK_U = {
		code = 0x4F425249,
		name = "Pokemon Black Version (U)",
		gen = 5,
		version = 0,
	},
	WHITE_U = {
		code = 0x4F415249,
		name = "Pokemon White Version (U)",
		gen = 5,
		version = 1,
	},
	BLACK2_U = {
		code = 0x4F455249,
		name = "Pokemon Black Version 2 (U)",
		gen = 5,
		version = 0,
	},
	WHITE2_U = {
		code = 0x4F445249,
		name = "Pokemon White Version 2 (U)",
		gen = 5,
		version = 1,
	},
}

-- Identify game version
local gamecode = mdword(0x023FFE0C) 

for k, _ in pairs(ver) do
	if gamecode == ver[k].code then
		game_name = ver[k].name
		game_version = ver[k].version
		gen = ver[k].gen
		break
	end
end

if not gen then
	console.log("Unsupported Game")
	return
end

console.log("Detected Game: " .. game_name)

-- Index game-specific map headers
if gen == 4 then
	dofile("lua\\methods_gen_iv.lua") -- Define Gen IV functions

	if gamecode == ver.HEARTGOLD_U.code or gamecode == ver.SOULSILVER_U.code then
		-- HG/SS have no differences in map headers
		map_names = json.load("lua\\data\\maps_hgss.json")
		MAP_HEADER_COUNT = 540 -- HGSS
	else
		map_names = json.load("lua\\data\\maps_dppt.json")
		MAP_HEADER_COUNT = 593 -- Pt

		-- DP uses Platinum headers with the name changes reverted
		if gamecode == ver.DIAMOND_U.code or gamecode == ver.PEARL_U.code then
			MAP_HEADER_COUNT = 559 -- DP

			map_names[29] = "GTS"
			map_names[73] = "Eterna City"
			map_names[74] = "Eterna City"
			map_names[75] = "Eterna City"
			map_names[76] = "Eterna City"
			map_names[455] = "Survival Area"
			map_names[465] = "Resort Area"
		end

		offset = get_offset_dp()
	end

	MON_DATA_SIZE = 236 -- Gen 4 has 16 extra trailing bytes of ball seals data
elseif gen == 5 then
	dofile("lua\\methods_gen_v.lua") -- Define Gen V functions

	map_names = json.load("lua\\data\\maps_gen_v.json")
	MAP_HEADER_COUNT = 615 -- B2W2

	-- BW uses B2W2 headers with the name changes reverted
	if gamecode == ver.BLACK_U.code  or gamecode == ver.WHITE_U.code then
		map_names[58] = "Castelia City"
		map_names[192] = "Cold Storage"
		map_names[193] = "Cold Storage"
		map_names[194] = "Cold Storage"
		map_names[415] = "Undella Town"

		MAP_HEADER_COUNT = 427 -- BW
	end

	MON_DATA_SIZE = 220

	offset = get_offset_bw(game_version)
end
