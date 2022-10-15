-- formantperc

local formantperc = {}
local controlspec = require "controlspec"

function formantperc.params()
    params:add{
        type    = "control",
        id      = "fp_formant_amp",
        name    = "formant amp",
        controlspec = controlspec.new(0, 1, 'lin', 0, 0.5, ''),
        action  = function(x)
            engine.formant_amp(x)
        end
    }

    params:add{
        type    = "control",
        id      = "fp_square_amp",
        name    = "square amp",
        controlspec = controlspec.new(0, 1, 'lin', 0, 0, ''),
        action  = function(x)
            engine.square_amp(x)
        end
    }

    params:add{
        type    = "control",
        id      = "fp_gain",
        name    = "formant gain",
        controlspec = controlspec.new(0, 2, 'lin', 0, 1, ''),
        action  = function(x)
            engine.gain(x)
        end
    }

    params:add{
        type    = "control",
        id      = "fp_am",
        name    = "square > formant gain",
        controlspec = controlspec.new(0, 2, 'lin', 0, 0, ''),
        action  = function(x)
            engine.am(x)
        end
    }

    params:add{
        type    = "control",
        id      = "fp_slope",
        name    = "slope",
        controlspec = controlspec.new(0, 1, 'lin', 0, 0.5, ''),
        action  = function(x)
            engine.slope(x)
        end
    }

    params:add{
        type    = "control",
        id      = "fp_formant",
        name    = "formant",
        controlspec = controlspec.new(50, 5000, 'exp', 0, 800, 'hz'),
        action  = function(x)
            engine.formant(x)
        end
    }

    params:add{
        type    = "option",
        id      = "fp_formant_mode",
        name    = "pitch > formant",
        options = {"off", "on"},
        default = 1,
        action  = function(x)
            engine.mode(x-1)
        end
    }

    params:add{
        type    = "control",
        id      = "fp_release",
        name    = "release",
        controlspec = controlspec.new(0.1, 3.2, 'lin', 0, 1.2, 's'),
        action  = function(x)
            engine.release(x)
        end
    }

    params:add{
        type    = "control",
        id      = "fp_cutoff",
        name    = "cutoff",
        controlspec = controlspec.new(50, 5000, 'exp', 0, 800, 'hz'),
        action  = function(x)
            engine.cutoff(x)
        end
    }

    params:add{
        type    = "control",
        id      = "fp_pan",
        name    = "pan",
        controlspec = controlspec.new(-1, 1, 'lin', 0, 0, ''),
        action  = function(x)
            engine.pan(x)
        end
    }

end

return formantperc
