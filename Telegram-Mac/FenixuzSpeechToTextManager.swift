//
//  FenixuzSpeechToTextManager.swift
//  Telegram-Mac
//
//  iOS portasi: submodules/Fenixuz/SpeechToText/Sources/SpeechToTextManager.swift
//
//  Mac uses the same `SFSpeechRecognizer` API (Speech framework, macOS 10.15+).
//  Differences from iOS:
//    - No `AVAudioSession` on macOS — we wire `AVAudioEngine` directly without
//      session activation/deactivation.
//    - The "managed audio session" Telegram-iOS uses to coordinate with other
//      audio doesn't exist on Mac in the same form, so we configure the engine
//      input ourselves and accept the tradeoff that simultaneous mic use with
//      a voice-call could fight for the input device.
//    - The Info.plist already declares `NSMicrophoneUsageDescription`. Add
//      `NSSpeechRecognitionUsageDescription` for Apple Review.

import Foundation
import AVFoundation
import Speech
import SwiftSignalKit

public final class FenixuzSpeechToTextManager {
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var isStopping = false

    public var onTextUpdate: ((String) -> Void)?
    public var onStop: (() -> Void)?
    public var onError: ((String) -> Void)?

    public var isRecording: Bool {
        return audioEngine.isRunning
    }

    public init() {
        let saved = UserDefaults(suiteName: "pro_messager")?.string(forKey: "stt_language") ?? "en-US"
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: saved))
        if recognizer?.isAvailable == true {
            self.speechRecognizer = recognizer
        } else {
            self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        }
    }

    public func updateLocale(_ localeId: String) {
        if audioEngine.isRunning {
            stopRecording()
        }
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeId))
        if recognizer?.isAvailable == true {
            self.speechRecognizer = recognizer
        } else {
            self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        }
    }

    public func toggleRecording() {
        if audioEngine.isRunning {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isStopping = false

        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch authStatus {
                case .authorized:
                    self.startRecordingEngine()
                case .denied:
                    self.onError?(FenixuzL10n.current.stt_error_denied)
                    self.onStop?()
                case .restricted:
                    self.onError?(FenixuzL10n.current.stt_error_restricted)
                    self.onStop?()
                case .notDetermined:
                    self.onError?(FenixuzL10n.current.stt_error_pending)
                    self.onStop?()
                @unknown default:
                    self.onStop?()
                }
            }
        }
    }

    private func startRecordingEngine() {
        guard let recognizer = self.speechRecognizer, recognizer.isAvailable else {
            self.onError?(FenixuzL10n.current.stt_error_unavailable)
            self.onStop?()
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            self.onError?(FenixuzL10n.current.stt_error_setup)
            self.onStop?()
            return
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false

        let inputNode = self.audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            self.onError?(String(format: "Audio format invalid: sampleRate=%.0f, channels=%d", recordingFormat.sampleRate, recordingFormat.channelCount))
            self.onStop?()
            return
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        self.audioEngine.prepare()

        do {
            try self.audioEngine.start()
        } catch {
            self.onError?("Audio engine failed to start: \(error.localizedDescription)")
            self.onStop?()
            return
        }

        self.recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            if self.isStopping { return }

            if let result = result {
                self.onTextUpdate?(result.bestTranscription.formattedString)
                if result.isFinal {
                    self.cleanupRecording()
                }
            }

            if let error = error {
                let nsError = error as NSError
                // Ignored codes mirror the iOS module's list (intentional cancellations).
                let ignored: Set<Int> = [7, 1110, 216, 209, 301]
                if !ignored.contains(nsError.code) {
                    self.onError?("Error \(nsError.code): \(error.localizedDescription)")
                }
                self.cleanupRecording()
            }
        }
    }

    public func stopRecording() {
        isStopping = true
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        onStop?()
    }

    private func cleanupRecording() {
        isStopping = true
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask = nil
        recognitionRequest = nil
        onStop?()
    }

    public static var currentLanguageName: String {
        let locale = UserDefaults(suiteName: "pro_messager")?.string(forKey: "stt_language") ?? "en-US"
        return FenixuzL10n.sttLanguageName(for: locale)
    }
}
