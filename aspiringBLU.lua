--[[
AspiringBLU v0.3

When a monster uses a Blue Magic spell, the spell is added to a list of spells that the player has not yet learned and an audio clip is played.
When the monster is defeated, the player is notified with an additional chat message and audio clip.
Users that are farming mobs in groups can use //targetblu command to target the monster that used the Blue Magic spell.

Created by roxasunbanned
https://github.com/roxasunbanned/aspiringBLU

Copyright © 2024, roxasunbanned
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.
    * Neither the name of Trusts nor the
    names of its contributors may be used to endorse or promote products
    derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL roxasunbanned BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]


_addon.name    = 'aspiringBLU'
_addon.author  = 'roxasunbanned'
_addon.version = '0.3'
_addon.commands = {'aspiringblu', 'aspblu'}
_addon.prefix = _addon.name .. ": "

local packets = require('packets')
local bit = require("bit")
local res = require('resources')
local spellsDB = require('data/spells')
local blu_magic_used = {}
local global_mob_list = {}
local silent_timer = 60
local silent_mode = false
local filter = false
local alert = false

-- Some BLU spells have a different name then the monster abilities they come from.
blu_different_names = {
    ["Everyone's Grudge"]     = "Evryone. Grudge",
    ["Nature's Meditation"]   = "Nat. Meditation",
    ["Orcish Counterstance"]  = "O. Counterstance",
    ["Tempestuous Upheaval"]  = "Tem. Upheaval",
    ["Atramentous Libations"] = "Atra. Libations",
    ["Winds of Promyvion"]    = "Winds of Promy.",
    ["Quadratic Continuum"]   = "Quad. Continuum",
}

-- Traverse through all of the BLU spells looking for the one with the given name.
blu_spells = res.spells:type('BlueMagic')
function find_blu_spell(monster_ability_name)
    for i,v in pairs(blu_spells) do
        if v.english == monster_ability_name then
            return v.id
        end
    end
end

-- Since the action packet gives monster abilities by ID, we'll want to create a
-- Monster Ability -> BLU Spell mapping to quickly find out which monster ability
-- corresponds to which spell.
spell_id_map = {}
for i,v in pairs(res.monster_abilities) do
    local monster_ability_name = blu_different_names[v.english] or v.english
    spell_id_map[i] = find_blu_spell(monster_ability_name)
end

-- Handle parsing and processing of chat commands
function aspiringBLUCommand(cmd, ...)
    if cmd == 'target' then
        targetBLUCommand()
    end
    if cmd == 'check' then
        updateAreaInfo(false)
    end

    -- Toggle filtering of wide scan packets
    if cmd == 'filter' then
        filter = not filter
        if filter and next(global_mob_list) == nil then
            updateAreaInfo(true)
        end
        windower.add_to_chat(123, _addon.prefix .. "Filtering is now " .. (filter and "enabled" or "disabled"))
    end

    -- Toggle alerting when a mob is close by
    if cmd == 'alert' then
        alert = not alert
        if alert and next(global_mob_list) == nil then
            updateAreaInfo(true)
        end
        windower.add_to_chat(123, _addon.prefix .. "Alert is now " .. (alert and "enabled" or "disabled"))
    end
end

-- Function to get spell name by spell_id
function getSpellName(spell_id)
    local spell = res.spells[spell_id]
    if spell then
        return spell.name
    else
        return "Unknown Spell"
    end
end

-- Function to wait for a specified amount of time
function wait(seconds)
    coroutine.sleep(seconds)
end

-- Function to handle targeting the BLU spell caster
function targetBLUCommand()
    if not is_main_job_blue_mage() then return end

    if #blu_magic_used == 0 then
        windower.add_to_chat(123,  _addon.prefix .. "No Blue Magic targets available.")
        return
    else
        local player = windower.ffxi.get_player()
        windower.add_to_chat(123, 'Attempting to target: ' .. tostring(blu_magic_used[1].actor))
        packets.inject(packets.new('incoming', 0x058, {
            ['Player'] = player.id,
            ['Target'] = blu_magic_used[1].actor,
            ['Player Index'] = player.index,
        }))
    end
end

function findMobsByZone(zone_id)
    local results = {}
    for key, spell in pairs(spellsDB) do
        local spellFound = false
        local mobResults = {}
        for _, mob in ipairs(spell.learned_from) do
            if string.find(mob.zone, zone_id) then
                table.insert(mobResults, mob)
                spellFound = true
            end
        end
        if spellFound then
            table.insert(results, { id = key, spellName = spell.en, mobs = mobResults})
        end
    end
    if #results == 0 then
        results = nil
    end
    return results
end

-- Function to add unknown blue magic if it doesn't already exist
function addNewBLUMagic(spell_id, actor_id)
    for _, entry in ipairs(blu_magic_used) do
        if entry.spell == spell_id and entry.actor == actor_id then
            return
        end
    end
    table.insert(blu_magic_used, {spell = spell_id, actor = actor_id})
end

function getActionID(targets)
    for i,v in pairs(targets) do
        for i2,v2 in pairs(v['actions']) do
            if v2['param'] then
                return v2['param']
            end
        end
    end
end

function actionCheck(action)
    -- Category 7 is the readies message for abilities.
    if action['category'] == 7 then
        local action_id = getActionID(action['targets'])
        local spell_id = spell_id_map[action_id]

        if spell_id and not windower.ffxi.get_spells()[spell_id] then
            local spell_name = getSpellName(spell_id)
            local mobData = windower.ffxi.get_mob_by_id(action.actor_id)
            windower.add_to_chat(123, _addon.prefix .. mobData.name .. " (" .. tostring(action.actor_id) ..  ") used a new Blue Magic Spell:  " .. spell_name .. " (" .. tostring(spell_id) .. ")!")
            windower.play_sound(windower.addon_path..'sounds/NewBlueMagicUsed.wav')
            addNewBLUMagic(spell_id, action.actor_id)
        end
    end
end

function checkChunk(id, data)
    if not is_main_job_blue_mage() then return end

    if id == 0x029 then -- Action Message
		actionMessageHandler(packets.parse('incoming', data))
    end
    if id==0xF4 then
        if not filter then return end
        local isBlueMagicAvailable = handleWideScanPackets(data)
        if not isBlueMagicAvailable then
            return true
        end
    end

    if id==0xE then
        if not alert then return end
        handleAlerts()
    end
end

function handleAlerts() 
    local mob_array = windower.ffxi.get_mob_array()
    local max_alerts = 5
    for _,v in pairs(mob_array) do
        local mob_name = v['name']
        if mob_name and (v['valid_target'] and v['status'] == 0) then
            for i in pairs(global_mob_list) do
                if mob_name:lower() == global_mob_list[i].mob:lower() then 
                    if not silent_mode then
                        windower.add_to_chat(123, _addon.prefix .. " " .. global_mob_list[i].mob .. ' is close by to learn ' .. global_mob_list[i].spell .. ' (' .. string.format('%.2f ', v['distance']) .. ' units away)')
                        silent_mode = true
                        return true
                    else
                        if silent_timer > 0 then
                            silent_timer = silent_timer - 1
                            return true
                        else
                            silent_mode = false
                            silent_timer = 120
                            return true
                        end
                    end
                end
            end
        end
    end
end

function handleWideScanPackets(data) 
    local packet = packets.parse('incoming', data)
    local index = packet['Index']
    local pos = '(%d,%d)':format(packet['X Offset'], packet['Y Offset'])
    local mob_id = 0x01000000 + (4096 * res.zones[windower.ffxi.get_info().zone].id) + index
    local mob_name = windower.ffxi.get_mob_name(mob_id)

    for i in pairs(global_mob_list) do
        if mob_name:lower() == global_mob_list[i].mob:lower() then 
            windower.add_to_chat(123, _addon.prefix .. "found " .. global_mob_list[i].mob .. ' at ' .. pos)
            return true
        end
        return false
    end
end

function actionMessageHandler(amPacket)
    
	-- If enemy defeated or falls to the ground message
	if amPacket.Message == 6 or amPacket.Message == 20 then
		local mobData = windower.ffxi.get_mob_by_id(amPacket.Target)
        for i, entry in ipairs(blu_magic_used) do
            if entry.actor == mobData.id then
                wait(2)
                if windower.ffxi.get_spells()[entry.spell] then
                    windower.add_to_chat(123, _addon.prefix .. "You have learned " .. getSpellName(entry.spell) .. "!")
                    windower.play_sound(windower.addon_path..'sounds/NewBlueMagicLearned.wav')
                else 
                    windower.add_to_chat(123, _addon.prefix .. "You have not learned " .. getSpellName(entry.spell) .. " from " .. mobData.name .. " (" .. tostring(mobData.id) .. ")!")
                end
                -- Remove the entry from the array after processing
                table.remove(blu_magic_used, i)
                updateAreaInfo(true)
                break
            end
        end
	end
end

function zoneChangeHandler()
    updateAreaInfo(false)
end

function updateAreaInfo(silent)
    if not is_main_job_blue_mage() then return end
    local zone_id = res.zones[windower.ffxi.get_info().zone].id
    local zone_spells = findMobsByZone(zone_id)

    if zone_spells then 
        local total_count = 0;
        local learned_count = 0;
        for i, spell in ipairs(zone_spells) do
            total_count = total_count + 1
            if windower.ffxi.get_spells()[spell.id] then
                learned_count = learned_count + 1
            else
                local mob_list = ""
                global_mob_list = {}
                for i, mob in ipairs(spell.mobs) do
                    table.insert(global_mob_list, { mob = mob.monster, spell = spell.spellName })
                    mob_list = mob_list .. mob.monster .. " (Level: " .. mob.level .. ")"
                    if mob.legion then
                        mob_list = mob_list .. " [Legion],"
                    else 
                        mob_list = mob_list .. ", "
                    end
                end
                -- Remove the trailing comma and space
                mob_list = mob_list:sub(1, -3)
                if not silent then
                    windower.add_to_chat(123, _addon.prefix .. spell.spellName .. " can be learned from: " .. mob_list)
                end
            end
        end
        if not silent then
            if total_count == learned_count then
                windower.add_to_chat(123, _addon.prefix .. "All spells in this zone have been learned.")
            else
                windower.play_sound(windower.addon_path..'sounds/BlueMagicAvailable.wav')
                windower.add_to_chat(123, _addon.prefix .. "You have learned " .. learned_count .. " out of " .. total_count .. " spells in this zone.")
            end
        end
    else
        if not silent then
            windower.add_to_chat(123, _addon.prefix .. "No spells found in this zone.")
        end
    end
end

function is_main_job_blue_mage()
    local player = windower.ffxi.get_player()
    if player and player.main_job == 'BLU' then
        return true
    else
        return false
    end
end

-- Register events and commands
windower.register_event('addon command', aspiringBLUCommand)
windower.register_event('incoming chunk', checkChunk)
windower.register_event('action', actionCheck)
windower.register_event ('zone change', zoneChangeHandler)
