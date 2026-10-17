# Whisper

An AI ASMR companion you can talk to. Open the app, tap **Start ASMR**, talk to Luna,
and she answers in a calm, whispery voice over a soft soundscape. The session
gradually gets quieter and fades out.

This is an MVP of the core experience only. There's no onboarding, accounts,
subscriptions, history or analytics.

> Whisper is for relaxation only. It is not a medical or mental-health service.

## Requirements

- Xcode 16 or later (the project uses synchronized folders)
- iOS 17+ simulator or device
- No third-party dependencies

## Run

1. Open `Whisper.xcodeproj`.
2. Select the **Whisper** scheme and an iOS 17+ simulator.
3. Build and run (⌘R).

It works with **zero keys**: the companion uses pre-written calm responses
(`MockAIConversationService`) and the on-device Apple voice.

To run on a device, choose your team under *Signing & Capabilities* and, if
needed, change `PRODUCT_BUNDLE_IDENTIFIER` in `Config/Base.xcconfig`.

**Quick testing:** a full session is 20 minutes. To shorten it, add the launch
argument `-WhisperSessionMinutes 2` under *Product → Scheme → Edit Scheme → Run →
Arguments*. To change the default for everyone, edit
`SessionConfiguration.defaultTotalMinutes`. The phases are always split 25% / 50% / 25%
(conversation / relaxation / ambience).

**Simulator notes:** speech recognition uses your Mac's microphone and can be
unreliable in the simulator. Background audio and phone-call interruptions are
best tested on a device.

## Set up ElevenLabs (the companion's voice)

ElevenLabs is Whisper's voice provider. Without a key the app still works and
uses the on-device Apple voice, but it's meant to run on ElevenLabs.

1. In ElevenLabs, open the **Voice Library**, find a soft voice (search for
   "ASMR", "whisper" or "soft"), add it to **My Voices** and copy its **Voice ID**.
2. Create an API key (*Developers → API Keys*). It needs text-to-speech access.
3. Create your local secrets file:

   ```sh
   cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
   ```

4. Fill in `Config/Secrets.xcconfig` (git-ignored):

   ```
   ELEVENLABS_API_KEY = ...
   ELEVENLABS_VOICE_ID = ...
   ELEVENLABS_MODEL_ID =        # optional: eleven_v4 recommended (default eleven_multilingual_v2)
   OPENAI_API_KEY = sk-...      # optional, for real conversation instead of mock lines
   OPENAI_MODEL =               # optional, defaults to gpt-4o-mini
   ```

5. Clean the build folder (⇧⌘K) and run. The Xcode console logs which providers
   are active, e.g. `Voice: ElevenLabs (eleven_multilingual_v2) with Apple fallback`.

The keys flow `Secrets.xcconfig → Info.plist → APIConfiguration`.

How the ElevenLabs voice is used:

- Audio is requested as MP3 (`mp3_44100_128`), decoded, and played through the
  app's voice chain, so it ducks the ambience, gets the warmth EQ and limiter, and
  fades like everything else.
- Voice settings are tuned for calm delivery: stability 0.7, no style
  exaggeration, no speaker boost. Speed is about 0.88 and slows further during
  relaxation, never going below the API minimum of 0.7.
- With `eleven_v4`, `eleven_v4_turbo` or `eleven_v3`, each line gets a `[whispers]` audio tag
  and only stability and similarity are sent, since these models don't take speed or style.
  `eleven_v4` gives the best whisper; `eleven_v4_turbo` responds faster.
- Latency: the opening line downloads while the soundscape fades in, and the
  goodnight line downloads during relaxation. Up to 24 lines stay cached in memory,
  so repeated lines play instantly and don't cost credits again.
- Reliability: if a line fails, it's spoken by the Apple voice instead. After 3
  failures in a row, such as a wrong key or no credits left, the session stays on
  the Apple voice.

| Keys present                 | Companion text          | Voice                                    |
|------------------------------|-------------------------|------------------------------------------|
| none                         | Mock responses          | Apple `AVSpeechSynthesizer`              |
| ElevenLabs key + voice ID    | Mock responses          | ElevenLabs, with Apple fallback per line |
| + `OPENAI_API_KEY`           | OpenAI Chat Completions | ElevenLabs, with Apple fallback per line |

If the conversation call fails or you're offline, a soft message appears
("Voice isn't available right now. Your soundscape can keep playing.") and the
ambience keeps playing.

> **Production:** never ship API keys inside the app binary. Put these calls behind
> a backend you control (for ElevenLabs, a small proxy that adds the `xi-api-key`
> header). Embedding keys is acceptable only for this MVP.

## Add ambience sound files (optional)

Drop loopable files into `Whisper/Resources/Sounds/`. The folder is synchronized
with the target, so nothing else is needed:

- `rain.m4a`
- `fireplace.m4a`
- `ocean.m4a`

`.caf`, `.wav`, `.mp3` and `.aiff` also work. Without files, Whisper generates
a soft procedural loop for each soundscape (`ProceduralAmbience.swift`), so
something always plays. See `Whisper/Resources/Sounds/SOUNDS.md` for tips.

## How a session works

| Time (20 min default) | Phase       | What happens                                                         |
|-----------------------|-------------|----------------------------------------------------------------------|
| 0–5 min               | Conversation| Talk (hold or tap the mic), or switch to *Just Listen* for a monologue |
| 5–15 min              | Relaxation  | Shorter whispers, longer pauses, voice gets softer and slower        |
| 15–20 min             | Ambient     | A goodnight line, then ambience only, slowly fading to silence       |

Audio is never cut off. Fades last 2–5 s, and the last part of the ambient phase
fades out slowly. The ambience ducks while Luna speaks. Pause, End, phone calls
and route changes all fade too.

## Architecture

```
Whisper/
├── App/              WhisperApp, RootView, AppCoordinator (flow), AppDependencies (service wiring)
├── Configuration/    APIConfiguration (keys from Info.plist)
├── DesignSystem/     Theme tokens (colors, type, spacing, radii), button styles
├── Models/           Companion, Ambience, SessionConfiguration, session enums
├── Session/          SessionManager: the state machine and all live-session logic
├── Features/
│   ├── Home/         HomeView, CompanionCard, AmbiencePicker
│   ├── Session/      LiveSessionView and its small subviews, SafetySupportView
│   └── Permissions/  MicrophonePrimerView
├── Services/
│   ├── AI/           AIConversationService protocol, Mock + OpenAI, CompanionPrompt
│   ├── Speech/       SpeechRecognitionService protocol, AppleSpeechRecognitionService
│   ├── Voice/        VoiceSynthesisService protocol, ElevenLabs (primary) + Apple + Fallback
│   ├── Audio/        AudioEngineService (AVAudioEngine), ambience loader, procedural loops
│   ├── Safety/       SafetyService (crisis keyword screen)
│   └── Permissions/  PermissionsService
└── Resources/Sounds/ Optional ambience files
```

- **SessionManager** (`@MainActor @Observable`) owns phases
  (`preparing → conversation → relaxation → ambientOnly → completed`, plus
  `paused` and `error`), the companion's turns, listening, transcript and notices.
  Views only read its state and call intent methods. All tasks are cancelled when
  the session ends.
- **AudioEngineService**: one `AVAudioEngine`.
  - Ambience: a looping player feeding a fade mixer.
  - Voice: a player feeding EQ (warmth) and a peak limiter (no clipping).
  - Separate ramped gain stages handle fades, ducking and the master pause/fade-out.
  - Handles interruptions and route changes.
  - The `.playAndRecord` session plus the `audio` background mode keep playing when
    the screen locks.
- **Providers are protocols.** `AppDependencies.live()` picks the real ones when
  keys exist and falls back otherwise.

## Privacy, permissions and safety

- Before the system prompt, a short sheet explains that the microphone is only
  used during an active session when you choose to speak. If you skip it or deny
  access, the session runs in **Just Listen** mode.
- Speech recognition runs on-device when the device supports it.
- `SafetyService` screens what you say for crisis or self-harm language. If it
  triggers, the session stops, the audio fades out, and a calm message points to
  emergency services, someone you trust, 988 (US & Canada) and findahelpline.com.

## Accessibility

- VoiceOver labels and hints on all controls. The mic also works with a VoiceOver
  double-tap.
- All text uses Dynamic Type text styles.
- With Reduce Motion on, the background and orb are static.
- Tap targets are at least 44 pt.
