#!/usr/bin/env python3
"""
Edits authlobby gamerules via NBT since RCON can't do it for custom dimensions.
Run after server creates the authlobby world (server must be stopped first).
"""
import nbtlib
import os
import sys

WORLD_PATH = "/opt/minecraft/world/dimensions/minecraft/authlobby/data/game_rules.dat"

def main():
    if not os.path.exists(WORLD_PATH):
        print(f"ERROR: {WORLD_PATH} not found. Did the server create the authlobby world?")
        sys.exit(1)

    nbt = nbtlib.load(WORLD_PATH)
    rules = nbt[""]

    rules["doDaylightCycle"] = nbtlib.String("false")
    rules["doMobSpawning"] = nbtlib.String("false")
    rules["fallDamage"] = nbtlib.String("false")
    rules["hunger"] = nbtlib.String("false")
    rules["doWeatherCycle"] = nbtlib.String("false")
    rules["keepInventory"] = nbtlib.String("true")

    nbt.save(WORLD_PATH)
    print("Authlobby gamerules set successfully.")

if __name__ == "__main__":
    main()
