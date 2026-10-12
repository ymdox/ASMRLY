# Ambience sound files

Drop short, seamlessly loopable files here and they are picked up automatically
(the folder is synchronized with the Xcode target):

| Ambience  | File name (any one extension)                      |
|-----------|----------------------------------------------------|
| Rain      | `rain.m4a` / `rain.caf` / `rain.wav` / `rain.mp3`  |
| Fireplace | `fireplace.m4a` / `.caf` / `.wav` / `.mp3`         |
| Ocean     | `ocean.m4a` / `.caf` / `.wav` / `.mp3`             |

Tips: 30–120 s, 44.1 kHz, mono or stereo, peak around -6 dBFS, and make sure the
end flows into the start (crossfade the seam in your editor).

If a file is missing, Whisper generates a soft procedural loop instead
(`ProceduralAmbience.swift`), so the app always plays something.
