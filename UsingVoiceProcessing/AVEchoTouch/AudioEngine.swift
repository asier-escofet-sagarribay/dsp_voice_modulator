/*
Abstract:
The class for handling AVAudioEngine.
*/

import AVFoundation
import Foundation

class AudioEngine {
    //Declarar el directory i format del archiu digital generat
    private var recordedFile: AVAudioFile?
    private var recordedFileURL = URL(fileURLWithPath: "input.wav", 
                                      isDirectory: false, relativeTo: URL(fileURLWithPath: NSTemporaryDirectory()))
    public private(set) var voiceIOFormat: AVAudioFormat
    
    //Inicialitzar un AudioPlayer encarregat de reproduir el audio grabat
    private var recordedFilePlayer = AVAudioPlayerNode()
    
    //Inicialitzar un AudioEngine encarregat de fer les transformacions a l'audio
    private var avAudioEngine = AVAudioEngine()
    
    //Inicialitzar les AudioUnits que utilitzara el AudioEngine per modificar l'audio
    private var reverbEffect = AVAudioUnitReverb()
    private var timePitchEffect = AVAudioUnitTimePitch()
    private var echoEffect = AVAudioUnitDistortion()
    
    //Inicialitzar el powerMeter per representar la intensitat del audio entrant
    public private(set) var voiceIOPowerMeter = PowerMeter()
    
    //Inicialitzar la variable per saber l'estat de l'AudioEngine
    public private(set) var isRecording = false
    


    enum AudioEngineError: Error {
        case bufferRetrieveError
        case fileFormatError
        case audioFileNotFound
    }
    
    

    init() throws {
        //Adjuntar els efectes al engine
        avAudioEngine.attach(recordedFilePlayer)
        avAudioEngine.attach(reverbEffect)
        avAudioEngine.attach(timePitchEffect)
        avAudioEngine.attach(echoEffect)
        
        //Inicializar els valors dels efectes
        //Assignar valors predefinits per produir reverb i echo
        reverbEffect.loadFactoryPreset(.cathedral)
        echoEffect.loadFactoryPreset(.multiEcho1)
        
        //WetDry mix fa referencia a la relacio entre el modificat i el que no
        //posant-ho a 0 aconseguim ignorar modificacions
        reverbEffect.wetDryMix = 0
        echoEffect.wetDryMix = 0
    
        //Assignar al format I/O el valor del AudioEngine
        voiceIOFormat = avAudioEngine.inputNode.outputFormat(forBus: 0)
    }
    
    @objc
    func configChanged(_ notification: Notification) {
        checkEngineIsRunning()
    }
    


    func setup() {
        
        //Inicial el proces de grabació
        do {
            try avAudioEngine.inputNode.setVoiceProcessingEnabled(true)
        } catch {
            print("Could not enable voice processing \(error)")
            return
        }
        
        //Connectar el nodes player -> mainMixer -> filters (echo, reverb, pitch&rate) -> output
        avAudioEngine.connect(recordedFilePlayer, to: avAudioEngine.mainMixerNode, format: voiceIOFormat)
        avAudioEngine.connect(avAudioEngine.mainMixerNode, to: reverbEffect, format: voiceIOFormat)
        avAudioEngine.connect(reverbEffect, to: echoEffect, format: voiceIOFormat)
        avAudioEngine.connect(echoEffect, to: timePitchEffect, format: voiceIOFormat)
        avAudioEngine.connect(timePitchEffect, to: avAudioEngine.outputNode, format: voiceIOFormat)
        
        //Crear un cicle amb un buffer de tamany bufferSize amb el audio ja modificat pels filtres
        avAudioEngine.inputNode.installTap(onBus: 0, bufferSize: 256, format: voiceIOFormat) { buffer, when in
            if self.isRecording {
                //Passar el buffer al PowerMeter perque pugui representar la intensitat
                self.voiceIOPowerMeter.process(buffer: buffer)
                //Preparar i reproduir el buffer
                self.recordedFilePlayer.scheduleBuffer(buffer, at: nil)
                self.recordedFilePlayer.play()
            }
        }
        avAudioEngine.prepare()
    }
    

    func start() {
        do {
            try avAudioEngine.start()
        } catch {
            print("Could not start audio engine: \(error)")
        }
    }

    func toggleRecording() {
        if isRecording {
            isRecording = false
            recordedFile = nil // Close the file.
        } else {
            recordedFilePlayer.stop()

            do {
                let settings: [String: Any] = [
                    AVFormatIDKey: Int(kAudioFormatLinearPCM),
                    AVLinearPCMIsNonInterleaved: false,
                    AVSampleRateKey: 44_100.0,
                    AVNumberOfChannelsKey: 2,
                    AVLinearPCMBitDepthKey: 16
                ]
                recordedFile = try AVAudioFile(forWriting: recordedFileURL, settings: settings)
                isRecording = true
            } catch {
                print("Could not create file for recording: \(error)")
            }
        }
    }
    
    func checkEngineIsRunning() {
        if !avAudioEngine.isRunning {
            start()
        }
    }

    func stopRecordingAndPlayers() {
        if isRecording {
            isRecording = false
        }
        recordedFilePlayer.stop()
    }
    
    func reverbChanged(active: Bool){
        reverbEffect.wetDryMix = active ? 50 : 0
    }
    func echoChanged(active: Bool){
        echoEffect.wetDryMix = active ? 50 : 0
    }
    func pitchChanged(value: Float){
        timePitchEffect.pitch = value
    }
    func mapValue(fromRange value: Float, fromMin: Float, fromMax: Float, toMin: Float, toMax: Float) -> Float {
        let normalizedValue = (value - fromMin) / (fromMax - fromMin)
        let mappedValue = normalizedValue * (toMax - toMin) + toMin
        return mappedValue
    }

    func rateChanged(value: Float) {
        let mappedValue = mapValue(fromRange: value, fromMin: -1, fromMax: 1, toMin: 0.75, toMax: 1.25)
        timePitchEffect.rate = mappedValue
    }
    
 
}
