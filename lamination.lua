-- lamination
-- a substitution sequencer
--
-- v0.3 @alanza
-- llllllll.co/t/lamination/58652
--    ▼ instructions below ▼
--
-- E1 scrolls page
-- E2 scrolls in page
-- K2 on 'size' resets
-- K3 on rule opens editor

Scale_Names = {}

UI = require "ui"
MusicUtil = require "musicutil"
Lattice = require "lattice"
HalfSecond = include "../awake/lib/halfsecond"
FormantPerc = include "lib/formantperc_engine"

options = {}
options.OUT = {"audio", "midi", "audio + midi", "crow out 1+2", "crow ii jf", "crow ii er301"}

local midi_devices
local midi_device
local midi_channel

engine.name = "FormantPerc"

Alphabet = {'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p'}
Pages = {
    {
        prefix = "note",
        size = 5,
        max = 12,
        -- listens = {1, 3, 5, 7},
        data = {{5},{4},{4},{3,0,1},{2,1},{0},{0},{0},{0},{0},{0},{0}},
        rule = {},
        lamination = {1},
        position = 1
    },
    {
        prefix = "octave",
        size = 3,
        max = 5,
        -- listens = {1,2,3,1},
        data = {{2,1},{3},{1},{0},{0}},
        rule = {},
        lamination = {1},
        position = 1
    },
    {
        prefix = "repeats",
        size = 2,
        max = 4,
        -- listens = {1,1,1,1},
        data = {{2},{2,1},{0},{0}},
        rule = {},
        lamination = {1},
        position = 1
    }
}
Scale_Names = {}
Scale = {}

function init()
    -- install FormantTriPTR if not already installed
    if not util.file_exists("/home/we/.local/share/SuperCollider/Extensions/FormantTriPTR/FormantTriPTR_scsynth.so") then
        util.os_capture("mkdir /home/we/.local/share/SuperCollider/Extensions/FormantTriPTR")
        util.os_capture("cp /home/we/dust/code/lamination/bin/FormantTriPTR/FormantTriPTR_scsynth.so /home/we/.local/share/SuperCollider/Extensions/FormantTriPTR/FormantTriPTR_scsynth.so")
        print("installed FormantTriPTR, please restart norns")
    end

    for i = 1, #MusicUtil.SCALES do
        table.insert(Scale_Names, string.lower(MusicUtil.SCALES[i].name))
    end
    build_midi_device_list()
    notes_off_metro = metro.init()
    notes_off_metro.event = all_notes_off
    params:add_separator('lamination', "LAMINATION")
    params:add_group("outs", "outs", 3)
    params:add{
        type    = "option",
        id      = "out",
        name    = "out",
        options = options.OUT,
        action  = function(value)
            all_notes_off()
            if value == 4 then crow.output[2].action = "{to(5,0),to(0,0.25)}"
            elseif value == 5 then
                crow.ii.pullup(true)
                crow.ii.jf.mode(1)
            elseif value == 6 then
                crow.ii.pullup(true)
            end
        end
    }
    params:add{
        type    = "option",
        id      = "midi_device",
        name    = "midi out device",
        options = midi_devices,
        default = 1,
        action  = function(value)
            midi_device = midi.connect(value)
        end
    }
    params:add{
        type    = "number",
        id      = "midi_out_channel",
        name    = "midi out channel",
        min     = 1,
        max     = 16,
        default = 1,
        action  = function(value)
            all_notes_off()
            midi_channel = value
        end
    }
    params:add{
        type    = "option",
        id      = "scale",
        name    = "scale",
        options = Scale_Names,
        default = 5,
        action = function()
            Scale = MusicUtil.generate_scale_of_length(params:get("root_note"), params:get("scale"), 16)
        end
    }
    params:add{
        type    = "number",
        id      = "root_note",
        name    = "root note",
        min     = 0,
        max     = 127,
        default = 60,
        formatter = function(param)
            return MusicUtil.note_num_to_name(param:get(), true)
        end,
        action  = function()
            Scale = MusicUtil.generate_scale_of_length(params:get("root_note"), params:get("scale"), 16)
        end
    }
    params:add{
        type    = "number",
        id      = "probability",
        name    = "probability",
        min     = 0,
        max     = 100,
        default = 100
    }
    params:add{
        type    = "trigger",
        id      = "stop",
        name    = "stop",
        action  = function()
            stop()
            reset()
        end
    }
    params:add{
        type    = "trigger",
        id      = "start",
        name    = "start",
        action  = start
    }
    params:add{
        type    = "trigger",
        id      = "reset",
        name    = "reset",
        action  = reset
    }
    FormantPerc.params()
    HalfSecond.init()

    params:add_separator('rules_data', 'rules data')
    for j = 1, #Pages do
        params:add_group(Pages[j].prefix, Pages[j].prefix, 1 + Pages[j].max * 8)
        params:add{
            type    = "number",
            id      = Pages[j].prefix .. "_size",
            name    = "size",
            min     = 1,
            max     = Pages[j].max,
            default = Pages[j].size,
            action = function(x)
                Pages[j].size = x
                -- for i = 1, 4 do
                --    local p = params:lookup_param(Pages[j].prefix .. "_listen_" .. i)
                --    params.params[p].max = x
                -- end
                for i = 1, Pages[j].max do
                    for k = 1, 8 do
                        local p = params:lookup_param(Pages[j].prefix .. "_data_" .. i .. "_" .. k)
                        p.max = x
                        if i > x then
                            params:hide(Pages[j].prefix .. "_data_" .. i .. "_" .. k)
                        end
                    end
                end
                Pages[j].rule:update()
            end
        }
        -- for i = 1, 4 do
        --     params:add{
        --         type    = "number",
        --         id      = Pages[j].prefix .. "_listen_" .. i,
        --         name    = "listen " .. i,
        --         min     = 1,
        --         max     = Pages[j].size,
        --         default = Pages[j].listens[i],
        --         action  = function(x)
        --             Pages[j].listens[i] = x
        --             Pages[j].rule:update()
        --         end
        --     }
        -- end
        for i = 1, Pages[j].max do
            for k = 1, 8 do
                params:add{
                    type    = "number",
                    id      = Pages[j].prefix .. "_data_" .. i .. "_" .. k,
                    name    = Alphabet[i] .. " step " .. k,
                    min     = 0,
                    max     = Pages[j].size,
                    default = Pages[j].data[i][k] and Pages[j].data[i][k] or 0,
                    action  = function(x)
                        Pages[j].data[i][k] = x
                        Pages[j].rule:update()
                    end
                }
            end
        end
        Pages[j].rule = Rule.new(j)
    end

    for j = 1,#Pages do
        iterate(j,  true)
    end
    local counter = 1
    local lattice = Lattice:new()
    lattice:new_pattern{
        division = 1 / (8 * 12),
        action = function()
            counter = counter % (12) + 1
            if counter == 1 then
                for j = 1, #Pages do
                    Pages[j].position = Pages[j].position + 1
                    Screen_Dirty = true
                    if Pages[j].position > #Pages[j].lamination then
                        iterate(j)
                    end
                end
            end
            if Pages[3].lamination[Pages[3].position] ~= 0 then
                local div = 12 / Pages[3].lamination[Pages[3].position]
                if (counter - 1) % div + 1 == 1 then
                    all_notes_off()
                    local octave = Pages[2].lamination[Pages[2].position]
                    if octave ~= 0 then
                        octave = octave - (Pages[2].size // 2 + 1)
                        local pitch = Pages[1].lamination[Pages[1].position]
                        if pitch ~= 0 and Running then
                            if params:get("out") == 1 or params:get("out") == 3 then
                                engine.hz(MusicUtil.note_num_to_freq(Scale[pitch] + 12*octave))
                            elseif params:get("out") == 2 or params:get("out") == 3 then
                                midi_device:note_on(pitch + 12*octave, 96, midi_channel)
                                table.insert(active_notes, pitch + 12*octave)
                                notes_off_metro:start(60 / (params:get("clock_tempo") * 16))
                            elseif params:get("out") == 4 then
                                crow.output[1].volts = (pitch + 12*octave - 60)/12
                                crow.output[2].execute()
                            elseif params:get("out") == 5 then
                                crow.ii.jf.play_note((pitch + 12*octave - 60)/12, 5)
                            elseif params:get("out") == 6 then
                                crow.ii.er301.cv(1, (pitch + 12*octave - 60)/12)
                                crow.ii.er301.tr_pulse(1)
                            end
                        end
                    end
                end
            end
        end
    }

    Grid = grid.connect()
    Grid.key = grid_key
    grid_redraw_metro = metro.init()
    grid_redraw_metro.event = function()
        if Grid_Dirty then
            grid_redraw()
            Grid_Dirty = false
        end
    end
    grid_redraw_metro:start(1/25)

    Screens = UI.Pages.new(1,3)
    screen_redraw_metro = metro.init()
    screen_redraw_metro.event = function()
        if Screen_Dirty then
            redraw()
            Screen_Dirty = false
        end
    end
    screen_redraw_metro:start(1/15)
    Editing = 0
    Subediting = 1

    if Grid.device then
        Grid_Dirty = true
    end
    Screen_Dirty = true
    params:default()
    midi_device.event = midi_event
    Running = true
    lattice:start()
end

function enc(n, d)
    if n == 1 then
        Screens:set_index_delta(d)
        Screen_Dirty = true
    else
        Pages[Screens.index].rule:enc(n,d)
    end
end

function key(n, z)
    Pages[Screens.index].rule:key(n, z)
end

function redraw()
    screen.clear()
    Screens:redraw()
    if Editing == 0 then
        screen.move(4, 8)
        screen.level(15)
        screen.text(Pages[Screens.index].prefix)
        screen.move(40, 8)
        screen.level(9)
        local s = ""
        for j = Pages[Screens.index].position, #Pages[Screens.index].lamination do
            if Pages[Screens.index].lamination[j] == 0 then
                s = s .. " "
            else
                s = s .. Alphabet[Pages[Screens.index].lamination[j]]
            end
        end
        screen.text(s)
        screen.fill()
    end
    Pages[Screens.index].rule:redraw()
    screen.update()
end

function iterate(page, reset)
    if reset then
        Pages[page].lamination = {1}
    else
        local lamination = {}
        for i = 1, #Pages[page].lamination do
            if Pages[page].lamination[i] == 0 then
                table.insert(lamination, 0)
            else
                for _, v in ipairs(rulemap(page, Pages[page].lamination[i])) do
                    table.insert(lamination, v)
                end
            end
        end
        Pages[page].lamination = lamination
    end
    Pages[page].position = 1
    Screen_Dirty = true
end

function rulemap(page, letter)
    local k = 8
    local flag = true
    while flag and k > 0 do
        if Pages[page].data[letter][k] ~= 0 then
            flag = false
        else
            k = k - 1
        end
    end
    if k == 0 then return {0}
    else
        return table.pack(table.unpack(Pages[page].data[letter], 1, k))
    end
end

Rule = {}
Rule.__index = Rule

function Rule.new(index)
    local rules_list = UI.ScrollingList.new(25, 15)
    rules_list.num_visible = 5
    rules_list.num_above_selected = 0
    local alphabet = UI.ScrollingList.new(4, 15)
    alphabet.num_visible = 5
    alphabet.num_above_selected = 0
    local rule = {
        rules_list = rules_list,
        alphabet = alphabet,
        index = index
    }
    setmetatable(Rule, {__index = Rule})
    setmetatable(rule, Rule)

    rule:update(true)
    return rule
end

function Rule:update(flag)
    self.alphabet.entries = {
        "size",
    }
    self.rules_list.entries = {Pages[self.index].size}
    -- for i = 1, 4 do
    --     table.insert(self.alphabet.entries, "listen " .. i)
    --     table.insert(self.rules_list.entries, Pages[self.index].listens[i])
    -- end
    for i = 1, Pages[self.index].size do
        table.insert(self.alphabet.entries, Alphabet[i] .. " ->")
        local s = ""
        for k = 1,8 do
            local val = params:get(Pages[self.index].prefix .. "_data_" .. i .. "_" .. k)
            if val == 0 then
                s = s .. " "
            else
                s = s .. Alphabet[val]
            end
        end
        table.insert(self.rules_list.entries, s)
    end
    if not flag and Screens.index == self.index then
        Screen_Dirty = true
    end
end

function Rule:redraw()
    if Editing == 0 then
        self.alphabet:redraw()
        self.rules_list:redraw()
    else
        screen.level(15)
        screen.move(4,9)
        screen.text(Alphabet[Editing] .. " ->")
        for k = 1,8 do
            local scroll = UI.ScrollingList.new(4 + 10 * (k - 1), 15)
            scroll.num_visible = 5
            scroll.num_above_selected = 2
            scroll.entries = {"_"}
            for i = 1, Pages[self.index].size do
                table.insert(scroll.entries, Alphabet[i])
            end
            scroll:set_index(params:get(Pages[self.index].prefix .. "_data_" .. Editing .. "_" .. k) + 1)
            scroll:redraw()
        end
        screen.level(10)
        screen.move(3 + 10 * (Subediting - 1), 35)
        screen.line_rel(0, 10)
        screen.stroke()
    end
end

function Rule:enc(n, d)
    if Editing == 0 and n == 2 then
        self.alphabet:set_index_delta(d)
        self.rules_list:set_index_delta(d)
        Screen_Dirty = true
    elseif Editing == 0 and n == 3 then
        if self.rules_list.index == 1 then
            params:delta(Pages[self.index].prefix .. "_size", d)
            Screen_Dirty = true
            if Grid.device then
                Grid_Dirty = true
            end
        -- elseif self.rules_list.index <= 5 then
        --     params:delta(Pages[self.index].prefix .. "_listen_" .. self.rules_list.index - 1, d)
        --     Screen_Dirty = true
        end
    elseif n == 2 then
        Subediting = util.clamp(Subediting + d, 1, 8)
        Screen_Dirty = true
    elseif n == 3 then
        params:delta(Pages[self.index].prefix .. "_data_" .. Editing  .. "_" .. Subediting, d)
        Screen_Dirty = true
        if Grid.device then
            Grid_Dirty = true
        end
    end
end

function Rule:key(n, z)
    if n == 3 then
        if z == 1 and self.rules_list.index > 1 then
            Editing = self.rules_list.index - 1
            Subediting = 1
            Screen_Dirty = true
            if Grid.device then
                Grid_Dirty = true
            end
        end
    elseif n == 2 then
        if z == 1 and Editing == 0 and self.rules_list.index == 1 then
            iterate(self.index, true)
        elseif z == 1 and Editing ~= 0 then
            Editing = 0
            Screen_Dirty = true
            if Grid.device then
                Grid_Dirty = true
            end
        end
    end
end

function grid_key(x, y, z)
    if z == 1 then
        if Editing == 0 then
            local val = y + 8 * (x // 8) + 1
            Pages[Screens.index].rule.rules_list:set_index(val)
            Pages[Screens.index].rule.alphabet:set_index(val)
            Grid_Dirty = true
            Screen_Dirty = true
        else
            Subediting = y
            local current = Pages[Screens.index].data[Editing][y]
            params:set(Pages[Screens.index].prefix .. "_data_" .. Editing .. "_" .. y, x ~= current and x or 0)
            Grid_Dirty = true
            Screen_Dirty = true
        end
    end
end

function grid_redraw()
    Grid:all(0)
    if Editing == 0 then
        local current = math.max(Pages[Screens.index].rule.rules_list.index - 1,1)
        for y = 1, Pages[Screens.index].max do
            for x = 1, 8 do
                if Pages[Screens.index].data[y][x] ~= 0 then
                    Grid:led(8 * (y // 8) + x, (y - 1) % 8 + 1, y == current and 15 or 9)
                end
            end
        end
    else
        for y = 1, 8 do
            local x = Pages[Screens.index].data[Editing][y]
            if x and x ~= 0 then
                Grid:led(x, y, y == Subediting and 15 or 9)
            end
        end
    end
    Grid:refresh()
end

function stop()
    Running = false
    all_notes_off()
end

function start()
    Running = true
end

function reset()
    for i = 1,3 do
        iterate(i, true)
    end
end

function midi_event(data)
    msg = midi.to_msg(data)
    if msg.type == "start" then
        reset()
        start()
    elseif msg.type == "continue" then
        if Running then
            stop()
        else
            start()
        end
    elseif msg.type == "stop" then
        stop()
    end
end

function build_midi_device_list()
    midi_devices = {}
    for i = 1, #midi.vports do
        local long_name = midi.vports[i].name
        local short_name = string.len(long_name) > 15 and util.acronym(long_name) or long_name
        table.insert(midi_devices,i .. ": " .. short_name)
    end
end

function all_notes_off()
    if params:get("out") == 2 or params:get("out") == 3 then
        for _, a in pairs(active_notes) do
            midi_device:note_off(a, nil, midi_channel)
        end
    end
    active_notes = {}
end
