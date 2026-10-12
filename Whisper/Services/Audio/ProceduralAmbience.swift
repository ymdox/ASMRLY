import AVFoundation

/// Generates soft, seamlessly looping ambience when no sound files are bundled.
/// Everything is filtered noise — low, warm and never harsh.
enum ProceduralAmbience {
    private static let sampleRate: Double = 44_100
    private static let crossfadeSeconds: Double = 1.5
    /// Ocean swells repeat every 8 s, so its 16 s loop contains exactly two waves.
    private static let oceanWavePeriod: Double = 8

    static func makeBuffer(for ambience: Ambience) -> AVAudioPCMBuffer? {
        guard ambience != .none else { return nil }
        let loopSeconds: Double = ambience == .ocean ? oceanWavePeriod * 2 : 12
        let loopFrames = Int(loopSeconds * sampleRate)
        let fadeFrames = Int(crossfadeSeconds * sampleRate)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(loopFrames)),
              let channels = buffer.floatChannelData else { return nil }

        var peak: Float = 0
        for channel in 0..<2 {
            var random = SplitMix64(seed: UInt64(17 + channel * 7_919))
            var raw = [Float](repeating: 0, count: loopFrames + fadeFrames)
            switch ambience {
            case .rain: renderRain(into: &raw, random: &random)
            case .fireplace: renderFireplace(into: &raw, random: &random)
            case .ocean: renderOcean(into: &raw, random: &random, phaseOffset: channel == 0 ? 0 : 0.35)
            case .none: break
            }

            // Equal-power crossfade of the tail into the head makes the loop seamless:
            // the last frame (raw[loop-1]) flows straight into the first (raw[loop]).
            let output = channels[channel]
            for index in 0..<loopFrames {
                var sample = raw[index]
                if index < fadeFrames {
                    let t = Float(index) / Float(fadeFrames) * .pi / 2
                    sample = raw[index] * sin(t) + raw[loopFrames + index] * cos(t)
                }
                output[index] = sample
                peak = max(peak, abs(sample))
            }
        }

        buffer.frameLength = AVAudioFrameCount(loopFrames)
        if peak > 0 {
            let gain = 0.6 / peak
            for channel in 0..<2 {
                let output = channels[channel]
                for index in 0..<loopFrames { output[index] *= gain }
            }
        }
        return buffer
    }

    // MARK: - Soundscapes

    /// Soft pink-noise rainfall with scattered droplets.
    private static func renderRain(into samples: inout [Float], random: inout SplitMix64) {
        var pink = PinkNoise()
        var smooth: Float = 0
        var dropEnvelope: Float = 0
        var dropAmplitude: Float = 0
        var previousWhite: Float = 0
        let dropProbability = Float(28 / sampleRate)

        for index in samples.indices {
            let white = random.nextSigned()
            smooth += 0.45 * (pink.next(white) - smooth)

            if random.nextUnit() < dropProbability {
                dropEnvelope = 1
                dropAmplitude = 0.15 + random.nextUnit() * 0.35
            }
            dropEnvelope *= 0.995
            let droplet = (white - previousWhite) * dropEnvelope * dropAmplitude
            previousWhite = white

            samples[index] = smooth * 0.9 + droplet * 0.25
        }
    }

    /// Low rumbling fire with gentle, sparse crackles.
    private static func renderFireplace(into samples: inout [Float], random: inout SplitMix64) {
        var brown: Float = 0
        var rumble: Float = 0
        var flicker: Float = 0.7
        var crackleEnvelope: Float = 0
        var crackleAmplitude: Float = 0
        var previousWhite: Float = 0
        let crackleProbability = Float(7 / sampleRate)

        for index in samples.indices {
            let white = random.nextSigned()
            brown = 0.995 * brown + 0.05 * white
            rumble += 0.06 * (brown - rumble)

            // Slow random walk so the fire breathes.
            flicker += (random.nextSigned()) * 0.0004
            flicker = min(max(flicker, 0.45), 1)

            if random.nextUnit() < crackleProbability {
                crackleEnvelope = 1
                crackleAmplitude = 0.2 + random.nextUnit() * 0.6
            }
            crackleEnvelope *= 0.985
            let crackle = (white - previousWhite) * crackleEnvelope * crackleAmplitude
            previousWhite = white

            samples[index] = rumble * 1.4 * flicker + crackle * 0.35
        }
    }

    /// Slow swelling waves: filtered noise whose level and brightness follow the swell.
    private static func renderOcean(into samples: inout [Float], random: inout SplitMix64, phaseOffset: Double) {
        var brown: Float = 0
        var wash: Float = 0
        let periodFrames = oceanWavePeriod * sampleRate

        for index in samples.indices {
            let white = random.nextSigned()
            brown = 0.997 * brown + 0.04 * white

            let phase = 2 * Double.pi * Double(index) / periodFrames + phaseOffset
            let swell = Float(0.5 - 0.5 * cos(phase))
            let envelope = 0.15 + 0.85 * swell * swell
            let brightness = 0.02 + 0.22 * swell

            wash += brightness * ((brown * 0.7 + white * 0.3) - wash)
            samples[index] = wash * envelope
        }
    }
}

/// Paul Kellet's economy pink-noise filter.
private struct PinkNoise {
    private var b0: Float = 0
    private var b1: Float = 0
    private var b2: Float = 0

    mutating func next(_ white: Float) -> Float {
        b0 = 0.99765 * b0 + white * 0.0990460
        b1 = 0.96300 * b1 + white * 0.2965164
        b2 = 0.57000 * b2 + white * 1.0526913
        return (b0 + b1 + b2 + white * 0.1848) * 0.2
    }
}

/// Small, fast deterministic RNG so loops are identical every launch.
struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in 0..<1.
    mutating func nextUnit() -> Float {
        Float(next() >> 40) / Float(1 << 24)
    }

    /// Uniform in -1..<1.
    mutating func nextSigned() -> Float {
        nextUnit() * 2 - 1
    }
}
