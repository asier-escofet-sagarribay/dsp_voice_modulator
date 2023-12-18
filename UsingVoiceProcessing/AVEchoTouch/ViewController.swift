/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The ViewController class.
*/

import UIKit
import AVFoundation.AVFAudio

class ViewController: UIViewController {
    
    @IBOutlet weak var echoSwitch: UISwitch!
    @IBOutlet weak var reverbSwitch: UISwitch!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var pitchSlider: UISlider!
    @IBOutlet weak var rateSlider: UISlider!
    @IBOutlet weak var voiceIOMeter: LevelMeterView!
    
    private var audioEngine: AudioEngine!

    enum ButtonTitles: String {
        case record = "Record"
        case stop = "Stop"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupAudioEngine()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.handleInterruption(_:)),
                                               name: AVAudioSession.interruptionNotification,
                                               object: AVAudioSession.sharedInstance())
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.handleRouteChange(_:)),
                                               name: AVAudioSession.routeChangeNotification,
                                               object: AVAudioSession.sharedInstance())
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.handleMediaServicesWereReset(_:)),
                                               name: AVAudioSession.mediaServicesWereResetNotification,
                                               object: AVAudioSession.sharedInstance())
    }
    
    func setupAudioSession(sampleRate: Double) {
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(.playAndRecord, options: .defaultToSpeaker)
        } catch {
            print("Could not set the audio category: \(error.localizedDescription)")
        }

        do {
            try session.setPreferredSampleRate(sampleRate)
        } catch {
            print("Could not set the preferred sample rate: \(error.localizedDescription)")
        }
    }
    
    func setupAudioEngine() {
        do {
            audioEngine = try AudioEngine()

            voiceIOMeter.levelProvider = audioEngine.voiceIOPowerMeter
            

            setupAudioSession(sampleRate: audioEngine.voiceIOFormat.sampleRate)

            audioEngine.setup()
            audioEngine.start()
        } catch {
            fatalError("Could not set up the audio engine: \(error)")
        }
    }
    
    func resetUIStates() {
        pitchSlider.setValue(0, animated: true)
        rateSlider.setValue(0, animated: true)
        echoSwitch.setOn(false, animated: true)
        reverbSwitch.setOn(false, animated: true)
        recordButton.setTitle(ButtonTitles.record.rawValue, for: .normal)
        recordButton.isEnabled = true
    }
    
    func resetAudioEngine() {
        audioEngine = nil
    }
    
    @objc
    func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        
        switch type {
        case .began:
            // Interruption begins so you need to take appropriate actions.
            if let isRecording = audioEngine?.isRecording, isRecording {
                recordButton.setTitle(ButtonTitles.record.rawValue, for: .normal)
            }
            audioEngine?.stopRecordingAndPlayers()
        case .ended:
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Could not set the audio session to active: \(error)")
            }
            
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // Interruption ends. Resume playback.
                } else {
                    // Interruption ends. Don't resume playback.
                }
            }
        @unknown default:
            fatalError("Unknown type: \(type)")
        }
    }
    
    @objc
    func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
            let routeDescription = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription else { return }
        switch reason {
        case .newDeviceAvailable:
            print("newDeviceAvailable")
        case .oldDeviceUnavailable:
            print("oldDeviceUnavailable")
        case .categoryChange:
            print("categoryChange")
            print("New category: \(AVAudioSession.sharedInstance().category)")
        case .override:
            print("override")
        case .wakeFromSleep:
            print("wakeFromSleep")
        case .noSuitableRouteForCategory:
            print("noSuitableRouteForCategory")
        case .routeConfigurationChange:
            print("routeConfigurationChange")
        case .unknown:
            print("unknown")
        @unknown default:
            fatalError("Really unknown reason: \(reason)")
        }
        
        print("Previous route:\n\(routeDescription)")
        print("Current route:\n\(AVAudioSession.sharedInstance().currentRoute)")
    }
    
    @objc
    func handleMediaServicesWereReset(_ notification: Notification) {
        resetUIStates()
        resetAudioEngine()
        setupAudioEngine()
    }
    
    @IBAction func recordPressed(_ sender: UIButton) {
        print("Record button pressed.")
        audioEngine?.checkEngineIsRunning()
        audioEngine?.toggleRecording()
        if let isRecording = audioEngine?.isRecording, isRecording {
            sender.setTitle(ButtonTitles.stop.rawValue, for: .normal)
        } else {
            sender.setTitle(ButtonTitles.record.rawValue, for: .normal)
        }
    }
    
    @IBAction func reverbPressed(_ sender: UISwitch) {
        print("Echo Switch pressed.")
        audioEngine?.reverbChanged(active: sender.isOn)
        
    }
    
    @IBAction func echoPressed(_ sender: UISwitch) {
        print("Echo Switch pressed.")
        audioEngine?.echoChanged(active: sender.isOn)
        
    }
    
    @IBAction func pitchChanged(_ sender: UISlider) {
        print("Pitch changed.")
        audioEngine?.pitchChanged(value: sender.value)
        
    }
    
    @IBAction func rateChanged(_ sender: UISlider) {
        print("Pitch changed.")
        audioEngine?.rateChanged(value: sender.value)
        
    }
}

