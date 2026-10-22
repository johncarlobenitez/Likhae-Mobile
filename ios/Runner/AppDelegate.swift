import Flutter
import AVFoundation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var notificationSoundPlayer: AVAudioPlayer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LikhaeNotificationSoundChannel")
    let channel = FlutterMethodChannel(
      name: "likhae/notification_sounds",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "play" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let self,
            let arguments = call.arguments as? [String: Any],
            let rawTones = arguments["tones"] as? [[NSNumber]] else {
        result(FlutterError(code: "INVALID_SOUND_PATTERN", message: "Sound pattern is missing.", details: nil))
        return
      }
      do {
        try self.playNotificationTones(rawTones)
        result(nil)
      } catch {
        result(FlutterError(code: "SOUND_PLAYBACK_FAILED", message: error.localizedDescription, details: nil))
      }
    }
  }

  private func playNotificationTones(_ tones: [[NSNumber]]) throws {
    let sampleRate = 44_100.0
    let amplitude = 0.14
    let parsedTones: [(frequency: Double, delay: Double, duration: Double)] = tones.compactMap { tone in
      guard tone.count >= 3 else { return nil }
      return (tone[0].doubleValue, tone[1].doubleValue / 1_000.0, tone[2].doubleValue / 1_000.0)
    }
    guard !parsedTones.isEmpty else { return }

    let duration = parsedTones.map { $0.delay + $0.duration }.max() ?? 0
    let sampleCount = Int((duration + 0.03) * sampleRate)
    var pcm = Data(capacity: sampleCount * 2)
    for sample in 0..<sampleCount {
      let time = Double(sample) / sampleRate
      var value = 0.0
      for tone in parsedTones where time >= tone.delay && time < tone.delay + tone.duration {
        let elapsed = time - tone.delay
        let progress = elapsed / tone.duration
        let attack = min(1.0, elapsed / 0.015)
        let envelope = attack * exp(-4.0 * progress)
        value += sin(2.0 * Double.pi * tone.frequency * elapsed) * amplitude * envelope
      }
      let clipped = max(-1.0, min(1.0, value))
      var pcmSample = Int16(clipped * Double(Int16.max)).littleEndian
      withUnsafeBytes(of: &pcmSample) { pcm.append(contentsOf: $0) }
    }

    var wav = Data()
    wav.append(contentsOf: "RIFF".utf8)
    appendLittleEndian(UInt32(36 + pcm.count), to: &wav)
    wav.append(contentsOf: "WAVEfmt ".utf8)
    appendLittleEndian(UInt32(16), to: &wav)
    appendLittleEndian(UInt16(1), to: &wav)
    appendLittleEndian(UInt16(1), to: &wav)
    appendLittleEndian(UInt32(sampleRate), to: &wav)
    appendLittleEndian(UInt32(sampleRate * 2), to: &wav)
    appendLittleEndian(UInt16(2), to: &wav)
    appendLittleEndian(UInt16(16), to: &wav)
    wav.append(contentsOf: "data".utf8)
    appendLittleEndian(UInt32(pcm.count), to: &wav)
    wav.append(pcm)

    let player = try AVAudioPlayer(data: wav)
    player.volume = 0.7
    player.prepareToPlay()
    notificationSoundPlayer?.stop()
    notificationSoundPlayer = player
    player.play()
  }

  private func appendLittleEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
    var littleEndianValue = value.littleEndian
    withUnsafeBytes(of: &littleEndianValue) { data.append(contentsOf: $0) }
  }
}
