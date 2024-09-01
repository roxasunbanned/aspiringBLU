--[[
AspiringBLU v0.1

When a monster uses a Blue Magic spell, the spell is added to a list of spells that the player has not yet learned and an audio clip is played.
When the monster is defeated, the player is notified with an additional chat message and audio clip.
Users that are farming mobs in groups can use //targetblu command to target the monster that used the Blue Magic spell.

Created by roxasunbanned
https://github.com/roxasunbanned/aspiringBLU
]]

packets = require('packets')
local bit = require("bit")

res = require('resources')
chat = require('chat')

_addon.name    = 'AspiringBLU'
_addon.author  = 'roxasunbanned'
_addon.version = '0.1'
_addon.commands = {'targetblu'}

-- Global variable to store new Blue Magic spells used
blu_magic_used = {}

-- Function to get spell name by spell_id
function get_spell_name(spell_id)
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

-- Function to get a specific bit from a variable
function get_bit(value, bit_position)
    -- Shift the desired bit to the least significant position and mask it
    return bit.band(bit.rshift(value, bit_position), 1)
end

-- Function to handle targeting the BLU spell caster
function handle_target_blu_command()
    if #blu_magic_used == 0 then
        windower.add_to_chat(123, "No Blue Magic targets available.")
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
        if (v.english == monster_ability_name) then
            return v.id
        end
    end
end

-- Function to add unknown blue magic if it doesn't already exist
function add_new_blu_magic(spell_id, actor_id)
    for _, entry in ipairs(blu_magic_used) do
        if entry.spell == spell_id and entry.actor == actor_id then
            return
        end
    end
    table.insert(blu_magic_used, {spell = spell_id, actor = actor_id})
end

-- Since the action packet gives monster abilities by ID, we'll want to create a
-- Monster Ability -> BLU Spell mapping to quickly find out which monster ability
-- corresponds to which spell.
spell_id_map = {}
for i,v in pairs(res.monster_abilities) do
    local monster_ability_name = blu_different_names[v.english] or v.english
    spell_id_map[i] = find_blu_spell(monster_ability_name)
end

function get_action_id(targets)
    for i,v in pairs(targets) do
        for i2,v2 in pairs(v['actions']) do
            if v2['param'] then
                return v2['param']
            end
        end
    end
end


windower.register_event('action', function(action)
    -- Category 7 is the readies message for abilities.
    if (action['category'] == 7) then
        local action_id = get_action_id(action['targets'])
        local spell_id = spell_id_map[action_id]

        if spell_id and not windower.ffxi.get_spells()[spell_id] then
            local spell_name = get_spell_name(spell_id)
            local mobData = windower.ffxi.get_mob_by_id(action.actor_id)
            windower.add_to_chat(123, mobData.name .. " (" .. tostring(action.actor_id) ..  ") used a new Blue Magic Spell:  " .. spell_name .. " (" .. tostring(spell_id) .. ")!")
            windower.play_sound(windower.addon_path..'sounds/NewBlueMagicUsed.wav')
            add_new_blu_magic(spell_id, action.actor_id)
        end
    end
end)

-- Register an event to detect if an enemy is dead and get their actor_id
windower.register_event('incoming chunk', function(id, data)
    if id == 0x029 then -- Action Message
		actionMessageHandler(packets.parse('incoming', data))
    end
end)

function actionMessageHandler(amPacket)
	-- If enemy defeated or falls to the ground message
	if amPacket.Message == 6 or amPacket.Message == 20 then
		local mobData = windower.ffxi.get_mob_by_id(amPacket.Target)
        for i, entry in ipairs(blu_magic_used) do
            if entry.actor == mobData.id then
                wait(2)
                if windower.ffxi.get_spells()[entry.spell] then
                    windower.add_to_chat(123, "You have learned " .. get_spell_name(entry.spell) .. "!")
                    windower.play_sound(windower.addon_path..'sounds/NewBlueMagicLearned.wav')
                else 
                    windower.add_to_chat(123, "You have not learned " .. get_spell_name(entry.spell) .. " from " .. mobData.name .. " (" .. tostring(mobData.id) .. ")!")
                end
                -- Remove the entry from the array after processing
                table.remove(blu_magic_used, i)
                break
            end
        end
	end
end

windower.register_event('addon command',function(...)
    handle_target_blu_command()
end)