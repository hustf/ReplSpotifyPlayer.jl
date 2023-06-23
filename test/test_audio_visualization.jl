using Test
push!(ENV, "SPOTIFY_NOINIT" => "true"); using ReplSpotifyPlayer
using ReplSpotifyPlayer: plot_audio_beats_bars_and_tatums, color_set, plot_audio
using ReplSpotifyPlayer: plot_audio_segments, plot_loudness_variation, plot_as_matrix_stretched_to_width
import ReplSpotifyPlayer.JSON3

ioc = color_set(IOContext(stdout, :print_ids => true), :green)
track_id = SpTrackId("11dFghVXANMlKmJXsNCbNl")

json_string = """{
    "meta": {\n    "analyzer_version": "4.0.0",\n    "platform": "Linux",\n    "detailed_status": "OK",\n    "status_code": 0,\n    "timestamp": 1495193577,\n    "analysis_time": 6.93906,\n    "input_process": "libvorbisfile L+R 44100->22050"\n  },
    "track": {\n    "num_samples": 4585515,\n    "duration": 207.95985,\n    "sample_md5": "string",\n    "offset_seconds": 0,\n    "window_seconds": 0,\n    "analysis_sample_rate": 22050,\n    "analysis_channels": 1,\n    "end_of_fade_in": 0,\n    "start_of_fade_out": 201.13705,\n    "loudness": -5.883,\n    "tempo": 118.211,\n    "tempo_confidence": 0.73,\n    "time_signature": 4,\n    "time_signature_confidence": 0.994,\n    "key": 9,\n    "key_confidence": 0.408,\n    "mode": 0,\n    "mode_confidence": 0.485,\n    "codestring": "string",\n    "code_version": 3.15,\n    "echoprintstring": "string",\n    "echoprint_version": 4.15,\n    "synchstring": "string",\n    "synch_version": 1,\n    "rhythmstring": "string",\n    "rhythm_version": 1\n  },
    "bars": [\n    {\n      "start": 0.49567,\n      "duration": 2.18749,\n      "confidence": 0.925\n    }\n  ],
    "beats": [\n    {\n      "start": 0.49567,\n      "duration": 2.18749,\n      "confidence": 0.925\n    }\n  ],
    "sections": [\n    {\n      "start": 0,\n      "duration": 6.97092,\n      "confidence": 1,\n      "loudness": -14.938,\n      "tempo": 113.178,\n      "tempo_confidence": 0.647,\n      "key": 9,\n      "key_confidence": 0.297,\n      "mode": -1,\n      "mode_confidence": 0.471,\n      "time_signature": 4,\n      "time_signature_confidence": 1\n    }\n  ],
    "segments": [{"start":0,"duration":0.42367,"confidence":0,"loudness_start":-60,"loudness_max_time":0,"loudness_max":-60,"loudness_end":0,"pitches":[0.764,0.956,1.0,0.981,0.783,0.619,0.577,0.442,0.321,0.152,0.151,0.367],"timbre":[0,171.13,9.469,-28.48,57.491,-50.067,14.833,5.359,-27.228,0.973,-10.64,-7.228]},{"start":0.42367,"duration":0.55764,"confidence":1,"loudness_start":-60,"loudness_max_time":0.044,"loudness_max":-12.76,"loudness_end":0,"pitches":[0.004,0.022,0.003,0.003,0.114,0.006,0.004,0.01,0.014,1.0,0.023,0.01],"timbre":[39.257,75.635,120.155,-21.931,70.006,161.637,-6.818,-4.919,-11.285,21.902,67.779,-4.607]}],
    "tatums": [\n    {\n      "start": 0.49567,\n      "duration": 2.18749,\n      "confidence": 0.925\n    }\n  ]\n}"""
  

audio_analysis = JSON3.read(json_string)

# Before precompilation with @compile_workload
# @ time plot_audio(ioc, track_id, audio_analysis)
#  4.908023 seconds (9.24 M allocations: 593.884 MiB, 4.22% gc time, 98.50% compilation time)
plot_audio(ioc, track_id, audio_analysis)

plot_audio_segments(ioc, audio_analysis.segments)
plot_loudness_variation(ioc, audio_analysis.segments)
ti = ["Lo", "Br", "Fl", "At", "5 ", "6 ", "7 ", "8 ", "9 ", "10", "11", "12"]
plot_as_matrix_stretched_to_width(ioc, audio_analysis.segments, :timbre, ti, "Timbre - time")
to = ["C ", "D♭", "D ", "E♭", "E ", "F ", "G♭", "G ", "A♭", "A ", "B♭", "H "]
plot_as_matrix_stretched_to_width(ioc, audio_analysis.segments, :pitches, to, "Pitches - time")

