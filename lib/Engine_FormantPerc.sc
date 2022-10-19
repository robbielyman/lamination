// CroneEngine_FormantPerc
// pulse and formant waves with perc envelopes, triggered on freq
Engine_FormantPerc : CroneEngine {
    var pg;
    var formant_amp = 0.5;
    var square_amp = 0.0;
    var gain = 1.0;
    var am = 0.0;
    var slope = 0.5;
    var formant = 800.0;
    var mode = 0.0;
    var release = 1.2;
    var cutoff = 800.0;
    var pan = 0;

      *new { arg context, doneCallback;
              ^super.new(context, doneCallback);
      }

      alloc {
          pg = ParGroup.tail(context.xg);

          SynthDef("FormantPerc", {
            arg out, freq = 440, formant = formant, mode = mode, slope = slope, formant_amp = formant_amp, square_amp = square_amp, gain = gain, am = am, cutoff = cutoff, pan = pan, release =release;
            var form = FormantTriPTR.ar(freq, formant + (0.5 * mode * freq), slope);
            var square = Pulse.ar(freq);
            var snd = 0.0;
            var filt = 0.0;
            var env = Env.perc(releaseTime: release).kr(2);
            form = SineShaper.ar(Clip.ar(MulAdd.new(square, 0.5 * am, gain), 0.0, 3.0) * LeakDC.ar(form));
            snd = (form * formant_amp) + (square * square_amp);
            filt = MoogFF.ar(snd, cutoff);
            Out.ar(out, Pan2.ar((filt*env),pan));
          }).add;

          this.addCommand("hz", "f", {
            arg msg;
            var val = msg[1];
            Synth("FormantPerc", [\out, context.out_b, \freq, val, \formant, formant, \mode, mode, \slope, slope, \formant_amp, formant_amp, \square_amp, square_amp, \gain, gain, \am, am, \cutoff, cutoff, \pan, pan, \release, release], target:pg);
          });

          this.addCommand("formant_amp", "f", { 
            arg msg;
            formant_amp = msg[1];
          });

          this.addCommand("square_amp", "f", {
            arg msg;
            square_amp = msg[1];
          });

          this.addCommand("gain", "f", {
            arg msg;
            gain = msg[1];
          });

          this.addCommand("am", "f", {
            arg msg;
            am = msg[1];
          });

          this.addCommand("slope", "f", {
            arg msg;
            slope = msg[1];
          });

          this.addCommand("formant", "f", {
            arg msg;
            formant = msg[1];
          });

          this.addCommand("mode", "f", {
            arg msg;
            mode = msg[1];
          });

          this.addCommand("release", "f", {
            arg msg;
            release = msg[1];
          });

          this.addCommand("cutoff", "f", {
            arg msg;
            cutoff = msg[1];
          });

          this.addCommand("pan", "f", {
            arg msg;
            pan = msg[1];
          })
      }

      free {
          pg.free;
      }
}
