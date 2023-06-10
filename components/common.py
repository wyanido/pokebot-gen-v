import io
import time
import mmap
import json
import traceback
from pokemon import enrich_mon_data

def load_json_mmap(size, file): 
    # BizHawk writes game information to memory mapped files every few frames (see pokebot.lua)
    # See https://tasvideos.org/Bizhawk/LuaFunctions (comm.mmfWrite)
    shmem = mmap.mmap(0, size, file)
    bytes_io = io.BytesIO(shmem)
    byte_str = bytes_io.read().decode('utf-8').split("\x00")[0]

    try:
        if byte_str != "":
            return json.loads(byte_str)
    except Exception as e:
        traceback.print_exc()
        print(byte_str)
        return False

def mem_get_game_info():
    global trainer_info, game_info, opponent_info

    while True:
        try:
            game_info_mmap = load_json_mmap(4096, "bizhawk_game_info")
            
            if game_info_mmap:
                trainer_info =  game_info_mmap["trainer"]
                game_info =     game_info_mmap["game_state"]

                if "opponent" in game_info_mmap:
                    opponent_info = game_info_mmap["opponent"]

                    for foe in opponent_info:
                        foe = enrich_mon_data(foe)
                else:
                    opponent_info = None

            time.sleep(0.016)
        except Exception as e:
            traceback.print_exc()
            pass

def mem_get_party_info():
    global party_info

    while True:
        try:
            party_info_mmap = load_json_mmap(8192, "bizhawk_party_info")

            if party_info_mmap:
                party_info = party_info_mmap["party"]

                if len(party_info) > 0:
                    for pokemon in party_info:
                        pokemon = enrich_mon_data(pokemon)
            time.sleep(0.016)
        except Exception as e:
            traceback.print_exc()
            pass

trainer_info, game_info, opponent_info, party_info = None, None, None, None