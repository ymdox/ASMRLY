import AVFoundation

enum AudioBufferTools {
    /// Converts a buffer (sample rate and/or sample format) into `format`.
    static func convert(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        if buffer.format == format { return buffer }
        guard buffer.frameLength > 0,
              let converter = AVAudioConverter(from: buffer.format, to: format) else { return nil }

        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 4_096
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }

        var didProvideInput = false
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            if didProvideInput {
                inputStatus.pointee = .endOfStream
                return nil
            }
            didProvideInput = true
            inputStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, conversionError == nil else { return nil }
        return output
    }

    /// Concatenates buffers that share the same format (e.g. chunks from AVSpeechSynthesizer.write).
    static func merge(_ buffers: [AVAudioPCMBuffer]) -> AVAudioPCMBuffer? {
        guard let format = buffers.first?.format else { return nil }
        let usable = buffers.filter { $0.format == format && $0.frameLength > 0 }
        let totalFrames = usable.reduce(0) { $0 + Int($1.frameLength) }
        guard totalFrames > 0,
              let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrames)) else { return nil }

        let bytesPerFrame = Int(format.streamDescription.pointee.mBytesPerFrame)
        let outputList = UnsafeMutableAudioBufferListPointer(output.mutableAudioBufferList)
        var frameOffset = 0

        for buffer in usable {
            let inputList = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
            let byteCount = Int(buffer.frameLength) * bytesPerFrame
            for index in 0..<min(inputList.count, outputList.count) {
                guard let source = inputList[index].mData, let destination = outputList[index].mData else { continue }
                memcpy(destination.advanced(by: frameOffset * bytesPerFrame), source, byteCount)
            }
            frameOffset += Int(buffer.frameLength)
        }
        output.frameLength = AVAudioFrameCount(frameOffset)
        return output
    }
}
