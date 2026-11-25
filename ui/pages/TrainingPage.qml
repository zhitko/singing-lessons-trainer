import QtQuick 6.8
import QtQuick.Controls 6.8
import QtQuick.Controls.Material 6.8
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Effects

import by.intontrainer.wavfile 1.0
import by.intontrainer.file 1.0
import by.intontrainer.analysis 1.0
import by.intontrainer.statistics 1.0
import by.intontrainer.audio 1.0

import "../components"
import "../utils"

Page {
    id: root
    padding: 0

    readonly property bool isTrainingPage: true

    // ── Page state ──────────────────────────────────────────────────────────
    property string referenceFilePath: ""
    property string userFilePath:      ""
    readonly property string referenceFileName: referenceFilePath.substring(referenceFilePath.lastIndexOf('/') + 1).replace(".wav", "")
    property string titleText: {
        var match = referenceFileName.match(/\(([^)]*)\)/)
        return (match && match[1] !== "") ? match[1] : referenceFileName
    }

    title: titleText

    // Shorthand computed accessors for repeated index→string lookups
    readonly property string amplitudeSmoothingName: settingsApi ? ["None", "MovingAverage", "Median", "Gaussian"][window.settingsApi.amplitudeSmoothing]           : "None"

    // ── Reference audio data ───────────────────────────────────────────────
    property var referenceUMP:                null
    property var referenceCuePoints:          null
    property var referenceWaveData:           null
    property var referencePitchData:          null
    property var referenceLogPitchData:       null
    property var referenceAmplitudeData:      null
    property var referenceAmplitudeDerivData: null
    property var referencePitchDerivData:     null
    property var referenceSpecData:           null
    property var referenceCepstrData:         null

    // ── User results ─────────────────────────────────────────────────────
    property var    userUMP:                   null
    property double shapeSimilarity:           0
    property bool   hasSimilarityScore:        false
    // Mean tonal error times 100. Stored with each result; older results have none (null).
    property double tonalErrorPercent:         0
    property bool   hasTonalError:             false
    // Most recent first, aligned with each other; error entries may be null.
    property var    previousShapeSimilarities: []
    property var    previousTonalErrors:       []

    property var userVadA:     []
    property var userVadU:     []
    property var userVadV:     []
    property var userVadCorr:  []
    property var userVadCorrU: []

    WavFileApi {
        id: wavFileApi
    }

    AnalysisApi {
        id: analysisApi
    }

    FileApi {
        id: fileApi
    }

    StatisticsApi {
        id: statisticsApi
    }

    AudioApi {
        id: trainingAudioApi
        onPermissionResultReceived: function(granted) {
            if (granted) {
                Logger.debug("Microphone permission granted, starting recording");
                if (root.pendingStartRecording) {
                    root.pendingStartRecording = false;
                    root.startRecording();
                }
            } else {
                Logger.warning("Microphone permission denied");
                root.pendingStartRecording = false;
                if (root.guidedState === root.gsPending)
                    root.guidedState = root.gsIdle;
            }
        }
        onBeepFinished: {
            if (root._pendingBeepRecording) {
                root._pendingBeepRecording = false;
                if (root.visible && !root._isExiting) {
                    root.doStartRecording();
                }
            } else if (root._pendingAfterBeep) {
                root._pendingAfterBeep = false;
                if (root.trainingMode === 0 && root.visible && !root._isExiting && !isAnyPlaybackActive
                        && window.settingsApi && window.settingsApi.autoStopRecording) {
                    restartRecordingTimer.start();
                }
            }
        }
    }

    // Set to true when we're waiting for the async permission prompt
    property bool pendingStartRecording: false

    property bool _isExiting: false
    property bool _wasRecordingBeforeDialog: false
    property bool _isVadPaused: false

    // ── Guided mode state ────────────────────────────────────────────────────
    // 0 = Auto (existing continuous VAD), 1 = Guided (Play & Listen)
    property int trainingMode: (window.settingsApi && window.settingsApi.guidedModeEnabled) ? 1 : 0
    readonly property int gsIdle       : 0
    readonly property int gsPlaying    : 1
    readonly property int gsPending    : 2
    readonly property int gsListening  : 3
    readonly property int gsProcessing : 4
    property int  guidedState: 0
    // True when the last listen window timed out without a capture
    property bool guidedTimedOut: false

    // ── Responsive layout (page pixels; works for Android and resized desktop) ─
    readonly property bool isNarrow: AppScale.isNarrow
    readonly property bool isCompact: AppScale.isCompact
    readonly property bool isShort: AppScale.isShort
    readonly property int pagePadding: AppScale.pagePadding
    readonly property int sideSlotMinWidth: isCompact ? 56 : 72
    // Just the play button and its one-line hint. Extra padding here
    // would come out of the chart.
    readonly property int controlFooterMinHeight: isCompact ? (isShort ? 64 : 72) : 84
    // Smallest plot that still shows the contour. The card fills whatever
    // height is left after the result card and the on-screen controls.
    readonly property int graphFloor: (isShort && isCompact) ? 120 : (isShort ? 160 : (isCompact ? 180 : (isNarrow ? 220 : 280)))
    readonly property int graphMinHeight: {
        const card = isCompact ? 48 : 64
        const gaps = (isCompact ? 10 : 16) * 2 + (isCompact ? 4 : 8) * 2
        const available = scrollView.availableHeight
        if (available > 0)
            return Math.max(100, Math.min(graphFloor, available - card - controlFooterMinHeight - gaps))
        return graphFloor
    }

    onTrainingModeChanged: {
        cancelPendingRecording();
        if (trainingAudioApi.isRecording) {
            root._isExiting = true;
            trainingAudioApi.stopRecording();
            root._isExiting = false;
        }
        root.guidedState = root.gsIdle;
        root.guidedTimedOut = false;

        if (trainingMode === 0 && visible && window.settingsApi
                && window.settingsApi.autoStopRecording
                && !trainingAudioApi.isRecording
                && !root._isVadPaused && !isAnyPlaybackActive) {
            root._isExiting = false;
            startRecording();
        }
    }

    // Starts recording without VAD calibration (calibration is performed on HomePage).
    function canStartRecording() {
        return root.visible && !root._isExiting && !root._isVadPaused
            && !isAnyPlaybackActive && !trainingAudioApi.isRecording
            && (root.trainingMode === 0 || root.guidedState === root.gsPending);
    }

    function cancelPendingRecording() {
        pendingStartRecording = false;
        root._pendingBeepRecording = false;
        root._pendingAfterBeep = false;
        restartRecordingTimer.stop();
        guidedDelayTimer.stop();
        guidedTimeoutTimer.stop();
        trainingAudioApi.stopBeep();
    }

    function startRecording() {
        if (!canStartRecording() || pendingStartRecording || root._pendingBeepRecording) return;
        // On Android, request mic permission first (async). If pending,
        // startRecording() will resume the beep sequence from the callback.
        if (!trainingAudioApi.requestAudioPermission()) {
            pendingStartRecording = true;
            return;
        }

        // Play a short beep before recording starts if enabled
        if (window.settingsApi && window.settingsApi.playSignalBeforeRecording) {
            root._pendingBeepRecording = true;
            trainingAudioApi.playBeep(
                window.settingsApi.beepBeforeFreq,
                window.settingsApi.beepBeforeDuration,
                window.settingsApi.beepBeforeAmplitude);
            return;
        }
        doStartRecording();
    }

    function doStartRecording() {
        if (!canStartRecording()) return;
        let minimumLength = -1;
        if (root.referenceWaveData && window.settingsApi) {
            minimumLength = Math.max(0, Math.floor(root.referenceWaveData.length * window.settingsApi.minimumRecordLengthPercent));
        }
        trainingAudioApi.startRecording(-1, minimumLength);
        if (root.trainingMode === 1) {
            if (trainingAudioApi.isRecording) {
                root.guidedState = root.gsListening;
                root.guidedTimedOut = false;
                guidedTimeoutTimer.interval = window.settingsApi
                    ? window.settingsApi.guidedListenTimeoutMs : 4000;
                guidedTimeoutTimer.restart();
            } else {
                root.guidedState = root.gsIdle;
            }
        }
    }

    // When true, recording will start as soon as the beep finishes playing
    property bool _pendingBeepRecording: false
    // When true, the auto-restart cycle waits for the after-recording beep to finish
    property bool _pendingAfterBeep: false

    onVisibleChanged: {
        if (visible) {
            _isExiting = false
            startIfNeeded();
        } else {
            _isExiting = true;
            // Cancel any pending guided activity when navigating away
            cancelPendingRecording();
            root.guidedState = root.gsIdle;
            root._pendingBeepRecording = false;
            root._pendingAfterBeep = false;
            if (trainingAudioApi.isRecording) {
                trainingAudioApi.stopRecording();
            }
        }
    }

    // Helper: start recording if conditions are right (auto mode, auto-stop enabled, not already recording)
    function startIfNeeded() {
        if (root.trainingMode === 0
                && window.settingsApi && window.settingsApi.autoStopRecording
                && !trainingAudioApi.isRecording && !root._isVadPaused) {
            startRecording();
        }
    }

    Component.onDestruction: {
        _isExiting = true;
        cancelPendingRecording();
        if (trainingAudioApi.isRecording) {
            trainingAudioApi.stopRecording();
        }
    }

    Connections {
        target: trainingAudioApi
        function onIsVoiceDetectedChanged() {
            if (root.trainingMode !== 1 || root.guidedState !== root.gsListening
                    || !trainingAudioApi.isRecording || root._isExiting) return;
            if (trainingAudioApi.isVoiceDetected) {
                guidedTimeoutTimer.stop();
            } else {
                // A too-short utterance was rejected by VAD: open a fresh window.
                guidedTimeoutTimer.restart();
            }
        }
        function onIsRecordingChanged() {
            if (!trainingAudioApi.isRecording && !root._isExiting) {

                // ── AUTO MODE ──────────────────────────────────────────────
                if (root.trainingMode === 0
                        && window.settingsApi && window.settingsApi.autoStopRecording) {
                    let tempFilePath = trainingAudioApi.saveWavFile();
                    if (tempFilePath !== "") {
                        let userWavHandle = wavFileApi.openWavFile(tempFilePath);
                        let userWaveData = wavFileApi.getWaveData(userWavHandle);
                        if (userWaveData) {
                            Logger.info("Recording successful, backend minimum length enforced.");
                            updateUserUMP(tempFilePath, true);
                        } else {
                            Logger.info("Recording save failed or no wave data available.");
                        }
                    }

                    // Play after-recording double-beep if enabled (before restart logic)
                    if (window.settingsApi && window.settingsApi.playSignalAfterRecording
                            && !root._isExiting) {
                        root._pendingAfterBeep = true;
                        trainingAudioApi.playDoubleBeep(
                            window.settingsApi.beepAfterDoubleFreq1,
                            window.settingsApi.beepAfterDoubleDur1,
                            window.settingsApi.beepAfterDoubleFreq2,
                            window.settingsApi.beepAfterDoubleDur2,
                            window.settingsApi.beepAfterDoubleAmplitude);
                    } else if (!root._isExiting && !isAnyPlaybackActive
                            && window.settingsApi && window.settingsApi.autoStopRecording) {
                        restartRecordingTimer.start();
                    }
                }

                // ── GUIDED MODE ─────────────────────────────────────────────
                else if (root.trainingMode === 1
                         && root.guidedState === root.gsListening) {
                    guidedTimeoutTimer.stop();
                    root.guidedState = root.gsProcessing;
                    let tempFilePath = trainingAudioApi.saveWavFile();
                    if (tempFilePath !== "") {
                        let userWavHandle = wavFileApi.openWavFile(tempFilePath);
                        let userWaveData = wavFileApi.getWaveData(userWavHandle);
                        if (userWaveData) {
                            Logger.info("Guided: attempt captured — processing");
                            updateUserUMP(tempFilePath, true);
                            // Play after-recording double-beep if enabled
                            if (window.settingsApi && window.settingsApi.playSignalAfterRecording) {
                                trainingAudioApi.playDoubleBeep(
                                    window.settingsApi.beepAfterDoubleFreq1,
                                    window.settingsApi.beepAfterDoubleDur1,
                                    window.settingsApi.beepAfterDoubleFreq2,
                                    window.settingsApi.beepAfterDoubleDur2,
                                    window.settingsApi.beepAfterDoubleAmplitude);
                            }
                        }
                    }
                    root.guidedState = root.gsIdle;
                    root.guidedTimedOut = false;
                }
            }
        }
    }

    Timer {
        id: restartRecordingTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (root.trainingMode === 0 && root.visible && !root._isExiting && !root._isVadPaused
                    && window.settingsApi && window.settingsApi.autoStopRecording) {
                root.startRecording();
            }
        }
    }

    // Post-playback delay before LISTEN opens (Guided mode)
    Timer {
        id: guidedDelayTimer
        repeat: false
        onTriggered: {
            if (root.trainingMode !== 1 || root.guidedState !== root.gsPending) return;
            root.guidedTimedOut = false;
            startRecording();
        }
    }

    // Timeout: close LISTEN window if no speech onset within limit (Guided mode)
    Timer {
        id: guidedTimeoutTimer
        repeat: false
        onTriggered: {
            if (root.trainingMode !== 1 || root.guidedState !== root.gsListening) return;
            Logger.info("Guided: listen window timed out — no speech detected");
            root._isExiting = true;  // prevent saving empty recording
            cancelPendingRecording();
            trainingAudioApi.stopRecording();
            root._isExiting = false;
            root.guidedState = root.gsIdle;
            root.guidedTimedOut = true;
        }
    }

    // Tracks whether any audio (reference or user) is currently playing.
    property bool isAnyPlaybackActive: playReferenceBtn.isPlaying || playUserBtn.isPlaying
    // Remember if we were recording before playback started. Used to decide whether to auto‑restart recording after playback finishes.
    property bool _wasRecordingBeforePlayback: false

    onIsAnyPlaybackActiveChanged: {
        if (isAnyPlaybackActive) {
            // Playback started – remember if we were recording so we can resume later if appropriate.
            _wasRecordingBeforePlayback = trainingAudioApi.isRecording;
            cancelPendingRecording();
            root.guidedState = root.gsIdle;
            if (trainingAudioApi.isRecording) {
                _isExiting = true; // Prevent saving an aborted recording
                trainingAudioApi.stopRecording();
            }
            _isExiting = !root.visible;

            // Only enter guided cycle when reference audio is played, not user recording
            if (root.trainingMode === 1 && playReferenceBtn.isPlaying) {
                root.guidedState = root.gsPlaying;
                root.guidedTimedOut = false;
            }
        } else {
            // Playback stopped

            // Auto mode: restart recording if we were recording before playback
            if (root.trainingMode === 0) {
                if (_wasRecordingBeforePlayback && !trainingAudioApi.isRecording && !root._isVadPaused) {
                    _isExiting = false;
                    restartRecordingTimer.start();
                }
                _wasRecordingBeforePlayback = false;
            }

            // Only start guided listen cycle when reference playback finished
            if (root.visible && !root._isExiting && root.trainingMode === 1 && root.guidedState === root.gsPlaying && !playReferenceBtn.isPlaying) {
                root.guidedState = root.gsPending;
                guidedDelayTimer.interval = window.settingsApi
                    ? window.settingsApi.guidedPrePlayListenDelayMs : 150;
                guidedDelayTimer.start();
            }
        }
    }

    Component.onCompleted: {
        updateReferenceUMP();
        loadPreviousResults();

        if (root.trainingMode === 0
                && visible && window.settingsApi && window.settingsApi.autoStopRecording
                && !trainingAudioApi.isRecording && !root._isVadPaused) {
            _isExiting = false;
            startRecording();
        }
    }

    Connections {
        target: window.settingsApi

        function onSettingsChanged() {
            Logger.debug("TrainingPage onSettingsChanged: refreshing reference UMP");
            root.updateReferenceUMP();
        }
    }

    function loadPreviousResults() {
        let results = statisticsApi.getResultsForFile(root.referenceFilePath);
        let errors = statisticsApi.getErrorsForFile(root.referenceFilePath);
        if (results && results.length > 0) {
            // Exclude the latest (current) result, take up to 5 previous ones
            // Reverse so index 0 = most recent previous
            root.previousShapeSimilarities = results.slice(0, -1).slice(-5).reverse().map(v => Math.round(v));
            root.previousTonalErrors = errors.slice(0, -1).slice(-5).reverse()
                .map(v => (v === null || v === undefined) ? null : Math.round(v));
            // Show the latest stored result if no new recording yet
            if (root.shapeSimilarity === 0) {
                root.shapeSimilarity = results[results.length - 1];
                root.hasSimilarityScore = true;
                let lastError = errors[errors.length - 1];
                if (lastError !== null && lastError !== undefined) {
                    root.tonalErrorPercent = lastError;
                    root.hasTonalError = true;
                }
            }
        }
    }

    function openTestFile() {
        _wasRecordingBeforeDialog = trainingAudioApi.isRecording;
        cancelPendingRecording();
        root.guidedState = root.gsIdle;
        if (_wasRecordingBeforeDialog) {
            console.log("Stopping recording before opening test file dialog");
            _isExiting = true; // Prevent automatic restart when stopping
            trainingAudioApi.stopRecording();
        }

        var testFolderPath = fileApi.getApplicationDirPath() + "/data/test";
        console.log("Opening test file dialog: " + testFolderPath);
        if (!fileApi.directoryExists(testFolderPath)) {
            console.warn("Directory does not exist: " + testFolderPath);
        } else {
            // Use FileApi helper to get properly formatted URL (crucial for Windows to avoid UNC timeout)
            testFileDialog.currentFolder = fileApi.getUrlFromPath(testFolderPath);
            testFileDialog.open();
        }
    }

    function openAdvancedTemplatePage() {
        let sv = StackView.view;
        if (!sv)
            return;
        sv.push("TemplatePage.qml", {
            referenceFilePath: root.referenceFilePath,
            userFilePath: root.userFilePath,
            userVadA: root.userVadA,
            userVadU: root.userVadU,
            userVadV: root.userVadV,
            userVadCorr: root.userVadCorr,
            userVadCorrU: root.userVadCorrU
        });
    }

    function updateReferenceUMP() {
        Logger.info("Loading reference file: " + referenceFilePath);

        let referenceWavFileHandle = wavFileApi.openWavFile(referenceFilePath);
        referenceCuePoints = wavFileApi.getCuePoints(referenceWavFileHandle);
        referenceWaveData  = wavFileApi.getWaveData(referenceWavFileHandle);

        // ── Pitch ───────────────────────────────────────────────────────────
        referencePitchData = wavFileApi.getScoringPitch(referenceWavFileHandle);
        Logger.debug("Reference pitch frames: " + referencePitchData.length);

        // Log pitch — only when dpUsePitchLog or dpUsePitchLogAsMask is active
        if (settingsApi.dpUsePitchLog || settingsApi.dpUsePitchLogAsMask) {
            Logger.debug("Extracting reference log pitch");
            referenceLogPitchData = wavFileApi.getPitch(
                referenceWavFileHandle,
                window.settingsApi.algorithm,
                window.settingsApi.frameShift,
                window.settingsApi.sampleRate,
                window.settingsApi.minF0,
                window.settingsApi.maxF0,
                window.settingsApi.voicingThreshold,
                "LOG_F0", "None", "None", "None", 0, 0, 0
            );
            Logger.debug("Reference log pitch frames: " + referenceLogPitchData.length);
        } else {
            referenceLogPitchData = [];
        }

        // Pitch derivative — only when dpUsePitchDerivative is active
        if (settingsApi.dpUsePitchDerivative) {
            Logger.debug("Extracting reference pitch derivative");
            referencePitchDerivData = wavFileApi.getPitchDerivative(
                referenceWavFileHandle,
                window.settingsApi.algorithm,
                window.settingsApi.frameShift,
                window.settingsApi.sampleRate,
                window.settingsApi.minF0,
                window.settingsApi.maxF0,
                window.settingsApi.voicingThreshold,
                "LOG_F0"
            );
            Logger.debug("Reference pitch derivative frames: " + referencePitchDerivData.length);
        } else {
            referencePitchDerivData = [];
        }

        // ── Amplitude ── only when dpUseAmplitude / dpUseAmplitudeDerivative is active
        if (settingsApi.dpUseAmplitude) {
            referenceAmplitudeData = wavFileApi.getAmplitude(
                referenceWavFileHandle,
                window.settingsApi.amplitudeWindow,
                window.settingsApi.amplitudeShift,
                amplitudeSmoothingName,
                window.settingsApi.amplitudeSmoothingWindowSize,
                window.settingsApi.amplitudeGaussianSmoothingSigma
            );
        } else {
            referenceAmplitudeData = [];
        }

        if (settingsApi.dpUseAmplitudeDerivative) {
            referenceAmplitudeDerivData = wavFileApi.getAmplitudeDerivative(
                referenceWavFileHandle,
                window.settingsApi.amplitudeWindow,
                window.settingsApi.amplitudeShift,
                amplitudeSmoothingName,
                window.settingsApi.amplitudeSmoothingWindowSize,
                window.settingsApi.amplitudeGaussianSmoothingSigma
            );
        } else {
            referenceAmplitudeDerivData = [];
        }

        // ── UMP ───────────────────────────────────────────────────────────
        root.referenceUMP = wavFileApi.getScoringUMP(
            referencePitchData,
            referenceCuePoints,
            referenceWaveData.length
        );
        umpGraph.waveData  = root.referenceUMP.ump;
        umpGraph.cuePoints = root.referenceUMP.cuePoints;

        // ── Spectrum / Cepstrum ── only when dpUseSpectrum / dpUseCepstrum is active
        if (settingsApi.dpUseCepstrum) {
            Logger.debug("Extracting cepstrum (order: " + window.settingsApi.cepstrNumOrder + ")");
            referenceCepstrData = wavFileApi.getCepstr(
                referenceWavFileHandle,
                window.settingsApi.specFftLength,
                window.settingsApi.frameShift,
                window.settingsApi.sampleRate,
                window.settingsApi.cepstrNumOrder,
                window.settingsApi.algorithm,
                window.settingsApi.minF0,
                window.settingsApi.maxF0,
                window.settingsApi.voicingThreshold,
                window.settingsApi.specF0Refinement
            );
            Logger.debug("Cepstrum frames: " + referenceCepstrData.length);
        } else {
            referenceCepstrData = [];
        }

        if (settingsApi.dpUseSpectrum) {
            Logger.debug("Extracting spectrum (FFT: " + window.settingsApi.specFftLength + ")");
            referenceSpecData = wavFileApi.getSpec(
                referenceWavFileHandle,
                window.settingsApi.specFftLength,
                window.settingsApi.frameShift,
                window.settingsApi.sampleRate,
                window.settingsApi.algorithm,
                window.settingsApi.minF0,
                window.settingsApi.maxF0,
                window.settingsApi.voicingThreshold,
                window.settingsApi.specF0Refinement
            );
            Logger.debug("Reference spectrum frames: " + referenceSpecData.length);
        } else {
            referenceSpecData = [];
        }
    }

    function invalidateComparison() {
        root.userUMP = null;
        root.hasSimilarityScore = false;
        root.hasTonalError = false;
        root.tonalErrorPercent = 0;
        umpGraph.waveData = root.referenceUMP ? root.referenceUMP.ump : [];
        umpGraph.cuePoints = root.referenceUMP ? root.referenceUMP.cuePoints : [];
    }

    function updateUserUMP(fileFullPath, isMicrophoneRecording) {
        Logger.info("Updating user UMP for file: " + fileFullPath + " isMicrophone: " + isMicrophoneRecording);

        root.userFilePath = fileFullPath;
        let userWavFileHandle = wavFileApi.openWavFile(root.userFilePath);
        let userCuePoints = wavFileApi.getCuePoints(userWavFileHandle);
        let userWaveData = wavFileApi.getWaveData(userWavFileHandle);

        // ── Pitch ───────────────────────────────────────────────────────────
        let userPitchData = wavFileApi.getScoringPitch(userWavFileHandle);
        Logger.debug("Pitch data frames: " + userPitchData.length);

        if (!root.referenceUMP || !root.referenceUMP.ump.length || !userPitchData.length) {
            invalidateComparison();
            return;
        }

        // Log pitch — only when dpUsePitchLog or dpUsePitchLogAsMask is active
        let userLogPitchData = [];
        if (settingsApi.dpUsePitchLog || settingsApi.dpUsePitchLogAsMask) {
            Logger.debug("Extracting user log pitch");
            userLogPitchData = wavFileApi.getPitch(
                userWavFileHandle,
                window.settingsApi.algorithm,
                window.settingsApi.frameShift,
                window.settingsApi.sampleRate,
                window.settingsApi.minF0,
                window.settingsApi.maxF0,
                window.settingsApi.voicingThreshold,
                "LOG_F0", "None", "None", "None", 0, 0, 0
            );
            Logger.debug("Log pitch data frames: " + userLogPitchData.length);
        }

        // ── Amplitude ── only when dpUseAmplitude / dpUseAmplitudeDerivative is active
        let userAmplitudeData = [];
        if (settingsApi.dpUseAmplitude) {
            Logger.debug("Extracting user amplitude");
            userAmplitudeData = wavFileApi.getAmplitude(
                userWavFileHandle,
                window.settingsApi.amplitudeWindow,
                window.settingsApi.amplitudeShift,
                amplitudeSmoothingName,
                window.settingsApi.amplitudeSmoothingWindowSize,
                window.settingsApi.amplitudeGaussianSmoothingSigma
            );
        }

        let userAmplitudeDerivData = [];
        if (settingsApi.dpUseAmplitudeDerivative) {
            Logger.debug("Extracting user amplitude derivative");
            userAmplitudeDerivData = wavFileApi.getAmplitudeDerivative(
                userWavFileHandle,
                window.settingsApi.amplitudeWindow,
                window.settingsApi.amplitudeShift,
                amplitudeSmoothingName,
                window.settingsApi.amplitudeSmoothingWindowSize,
                window.settingsApi.amplitudeGaussianSmoothingSigma
            );
        }

        // ── Cepstrum ── only when dpUseCepstrum is active
        let userCepstrData = [];
        if (settingsApi.dpUseCepstrum) {
            Logger.debug("Extracting cepstrum with order: " + window.settingsApi.cepstrNumOrder);
            userCepstrData = wavFileApi.getCepstr(
                userWavFileHandle,
                window.settingsApi.specFftLength,
                window.settingsApi.frameShift,
                window.settingsApi.sampleRate,
                window.settingsApi.cepstrNumOrder,
                window.settingsApi.algorithm,
                window.settingsApi.minF0,
                window.settingsApi.maxF0,
                window.settingsApi.voicingThreshold,
                window.settingsApi.specF0Refinement
            );
            Logger.debug("Cepstrum data frames: " + userCepstrData.length);
        }

        // ── Spectrum ── only when dpUseSpectrum is active
        let userSpecData = [];
        if (settingsApi.dpUseSpectrum) {
            Logger.debug("Extracting spectrum with FFT length: " + window.settingsApi.specFftLength);
            userSpecData = wavFileApi.getSpec(
                userWavFileHandle,
                window.settingsApi.specFftLength,
                window.settingsApi.frameShift,
                window.settingsApi.sampleRate,
                window.settingsApi.algorithm,
                window.settingsApi.minF0,
                window.settingsApi.maxF0,
                window.settingsApi.voicingThreshold,
                window.settingsApi.specF0Refinement
            );
            Logger.debug("User spectrum data frames: " + userSpecData.length);
        }

        // ── Pitch derivative ── only when dpUsePitchDerivative is active
        let userPitchDerivData = [];
        if (settingsApi.dpUsePitchDerivative) {
            Logger.debug("Extracting pitch derivative data for user");
            userPitchDerivData = wavFileApi.getPitchDerivative(
                userWavFileHandle,
                window.settingsApi.algorithm,
                window.settingsApi.frameShift,
                window.settingsApi.sampleRate,
                window.settingsApi.minF0,
                window.settingsApi.maxF0,
                window.settingsApi.voicingThreshold,
                "LOG_F0"
            );
            Logger.debug("User pitch derivative data frames: " + userPitchDerivData.length);
        }

        // Generate UMP from DP result
        // Scale loadedCuePoints to match user pitch data length
        let scaledLoadedCuePoints = referenceCuePoints.map(cp => {
            return {
                position: Math.round(cp.position * referencePitchData.length / referenceWaveData.length),
                label: cp.label,
                length: Math.round(cp.length * referencePitchData.length / referenceWaveData.length)
            };
        });
        Logger.debug("Calculating DP...");
        let dpResult = wavFileApi.getDP(
            referenceAmplitudeData, 
            referenceAmplitudeDerivData, 
            referencePitchData, 
            referenceLogPitchData, 
            referencePitchDerivData, 
            referenceSpecData, 
            referenceCepstrData, 
            userAmplitudeData, 
            userAmplitudeDerivData, 
            userPitchData, 
            userLogPitchData, 
            userPitchDerivData, 
            userSpecData, 
            userCepstrData, 
            userPitchData, 
            scaledLoadedCuePoints
        );

        // Skip microphone recording if DTW distance exceeds the configured limit.
        // File-based results are always accepted regardless of distance.
        if (isMicrophoneRecording) {
            let distanceLimit = (window.settingsApi && window.settingsApi.dtwDistanceLimit > 0)
                ? window.settingsApi.dtwDistanceLimit : Infinity;
            if (dpResult.minFinalCost >= distanceLimit) {
                Logger.info("Recording skipped: DTW distance (" + dpResult.minFinalCost + ") >= limit (" + distanceLimit + ")");
                invalidateComparison();
                return;
            }
        }
        let scaledPitch = dpResult.pitch;
        if (!scaledPitch || !scaledPitch.length) {
            invalidateComparison();
            return;
        }
        Logger.debug("DP result pitch length: " + scaledPitch.length);

        Logger.debug("Calculating UMP...");
        root.userUMP = wavFileApi.getScoringUMP(
            scaledPitch,
            referenceCuePoints,
            referenceWaveData.length
        );
        Logger.debug("UMP calculated with " + root.userUMP.cuePoints.length + " cue points");

        umpGraph.waveData = [root.referenceUMP.ump, root.userUMP.ump];
        umpGraph.cuePoints = root.userUMP.cuePoints;

        // Compare UMPs using AnalysisApi to get similarity
        var cmp = analysisApi.compareUMP(
            root.referenceUMP.ump,
            root.userUMP.ump,
            root.referenceUMP.cuePoints,
            root.userUMP.cuePoints,
            window.settingsApi.minF0,
            window.settingsApi.maxF0,
            window.settingsApi.useOnlyN
        );
        if (!cmp.valid || !isFinite(cmp.shapeSimilarity) || !isFinite(cmp.meanTonalError)) {
            invalidateComparison();
            return;
        }
        var newShapeSimilarity = cmp.shapeSimilarity;
        // meanTonalError is the power mean on the normalized curves; the
        // screen shows that mean times 100. p comes from settings.
        var newTonalErrorPercent = cmp.meanTonalError * 100;

        root.shapeSimilarity = newShapeSimilarity;
        root.hasSimilarityScore = true;
        root.tonalErrorPercent = newTonalErrorPercent;
        root.hasTonalError = true;

        root.userVadA = trainingAudioApi.getVadA();
        root.userVadU = trainingAudioApi.getVadU();
        root.userVadV = trainingAudioApi.getVadV();
        root.userVadCorr = trainingAudioApi.getVadCorr();
        root.userVadCorrU = trainingAudioApi.getVadCorrU();
        console.log("VAD A: " + root.userVadA.length);
        console.log("VAD U: " + root.userVadU.length);
        console.log("VAD V: " + root.userVadV.length);
        console.log("VAD Corr: " + root.userVadCorr.length);
        console.log("VAD Corr U: " + root.userVadCorrU.length);

        // Register the result in statistics FIRST
        statisticsApi.registerResult(root.referenceFilePath, root.shapeSimilarity, root.tonalErrorPercent);

        // Register history entry for the user record only if it was a microphone recording
        if (isMicrophoneRecording) {
            statisticsApi.registerHistoryEntry(root.userFilePath, root.referenceFilePath, root.shapeSimilarity);
        }

        // Then reload history so previous results reflect the newly saved state
        loadPreviousResults();
    }

    background: Rectangle {
        color: Theme.background(root.Material.theme)
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true
        ScrollBar.vertical.policy: (window.settingsApi && !window.settingsApi.showNavigationMenu)
                                   ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            id: pageLayout
            width: Math.max(0, Math.min(AppScale.maxContentWidth, scrollView.availableWidth - root.pagePadding * 2))
            x: (scrollView.availableWidth - width) / 2
            y: root.isCompact ? 4 : 8
            // No extra gap under the play controls; that height goes to the chart.
            height: Math.max(implicitHeight, scrollView.availableHeight - y)
            spacing: root.isCompact ? 10 : 16

            // Result card: similarity and tonal error, each with recent history
            Rectangle {
                id: shapeSimilarityCard
                Layout.fillWidth: true
                Layout.preferredHeight: resultRow.implicitHeight + (root.isCompact ? 8 : 12)
                radius: root.isCompact ? 20 : 28
                clip: true
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.primaryContainer(root.Material.theme) }
                    GradientStop { position: 1.0; color: Theme.tertiaryContainer(root.Material.theme) }
                }

                RowLayout {
                    id: resultRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: root.isCompact ? 6 : 8
                    spacing: 0

                    ResultMetric {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        label: qsTr("Melodic Similarity")
                        value: root.shapeSimilarity
                        hasValue: root.hasSimilarityScore
                        history: root.previousShapeSimilarities
                        lowerIsBetter: false
                    }

                    Rectangle {
                        Layout.fillHeight: true
                        Layout.topMargin: 6
                        Layout.bottomMargin: 6
                        width: 1
                        color: Theme.onPrimaryContainer(root.Material.theme)
                        opacity: 0.15
                    }

                    ResultMetric {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        label: qsTr("Tonal Error")
                        value: root.tonalErrorPercent
                        hasValue: root.hasTonalError
                        history: root.previousTonalErrors
                        lowerIsBetter: true
                    }
                }
            }

            // Main graph — fills the space above the on-screen controls.
            SurfaceCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: root.graphMinHeight
                radius: root.isCompact ? 20 : 28
                baseColor: Theme.surfaceContainerLowest(root.Material.theme)

            WaveFormGraph {
                id: umpGraph
                anchors.fill: parent
                anchors.margins: root.isCompact ? 6 : 8
                anchors.topMargin: root.isCompact ? 2 : 4
                anchors.bottomMargin: 2
                plotTopPadding: 2
                independentScale: true
                // Reference is dark purple, the take is vermillion. Same stroke
                // width so the two contours are comparable.
                datasetColors: ["#4B2A83", "#D55E00"]
                datasetWidthScales: [1.0, 1.0]
                datasetOpacities: [1.0, 1.0]
                lineWidth: root.isCompact ? 3 : 4
                // Shade the gap between reference and user curves to show
                // where the take deviates. Only drawn once both curves exist.
                fillBetween: true
                fillBetweenColor: "#D55E00"
                fillBetweenOpacity: 0.2
                showCueLabels: false
                showYAxis: false
                cueNLabels: root.referenceFileName.replace(/\([^)]*\)/g, "").replace(/^[^,]*?\s-\s*/, "").replace(/^\s*\d+\s*/, "").split(",").map(s => s.trim())
            }
            }



            // Controls — three equal-stretch slots so the center play/record
            // control stays page-centered on every width (phone, tablet, desktop).
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                Layout.minimumHeight: root.controlFooterMinHeight
                Layout.topMargin: root.isCompact ? -6 : -10
                spacing: root.isCompact ? 4 : 8

                Item {
                    id: leftSlot
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 120
                    Layout.minimumWidth: root.sideSlotMinWidth
                    implicitHeight: Math.max(
                        playReferenceBtn.visible ? playReferenceBtn.implicitHeight : 0,
                        playUserBtn.implicitHeight,
                        56)

                    PlayRoundButton {
                        id: playReferenceBtn
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(parent.width, 200)
                        compact: root.isCompact
                        filePath: root.referenceFilePath
                        text: qsTr("Play\nReference")
                        visible: root.trainingMode !== 1
                        enabled: root.trainingMode !== 1
                                 || root.guidedState === root.gsIdle
                                 || root.guidedState === root.gsPlaying
                    }
                }

                ColumnLayout {
                    id: centerControls
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 200
                    Layout.minimumWidth: 96
                    Layout.maximumWidth: root.isNarrow ? 100000 : 280
                    spacing: 2
                    visible: window.settingsApi ? window.settingsApi.autoStopRecording : false

                    // ── Recording indicator with waveform bars ─────────────────
                    Item {
                        id: micLevelIndicator
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        Layout.preferredHeight: (trainingAudioApi.isRecording || isAnyPlaybackActive)
                                                ? (root.isCompact ? (root.isShort ? 40 : 48) : 64) : 0
                        implicitHeight: Layout.preferredHeight
                        opacity: (trainingAudioApi.isRecording || isAnyPlaybackActive) ? 1.0 : 0.0
                        clip: true

                        Behavior on Layout.preferredHeight {
                            NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: 200 }
                        }

                        property color activeColor: trainingAudioApi.isRecording
                            ? Theme.success(root.Material.theme)
                            : (isAnyPlaybackActive
                                ? Theme.primary(root.Material.theme)
                                : Theme.error(root.Material.theme))

                        property int barCount: root.isNarrow ? 10 : 20
                        property var levelHistory: {
                            let arr = [];
                            for (let i = 0; i < barCount; i++) arr.push(0);
                            return arr;
                        }

                        Timer {
                            id: waveformTimer
                            interval: 50
                            repeat: true
                            running: trainingAudioApi.isRecording
                            onTriggered: {
                                let lvl = trainingAudioApi.audioLevel;
                                let arr = micLevelIndicator.levelHistory.slice(1);
                                arr.push(lvl);
                                micLevelIndicator.levelHistory = arr;
                            }
                        }

                        Connections {
                            target: trainingAudioApi
                            function onIsRecordingChanged() {
                                if (!trainingAudioApi.isRecording) {
                                    let arr = [];
                                    for (let i = 0; i < micLevelIndicator.barCount; i++) arr.push(0);
                                    micLevelIndicator.levelHistory = arr;
                                }
                            }
                        }

                        Row {
                            anchors.right: centerDot.left
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            layoutDirection: Qt.RightToLeft

                            Repeater {
                                model: micLevelIndicator.barCount
                                delegate: Rectangle {
                                    property real lvl: micLevelIndicator.levelHistory[micLevelIndicator.barCount - 1 - index] || 0
                                    property real logLvl: Math.log1p(lvl * 3) / Math.log1p(3)
                                    width: 2 + Math.pow(lvl, 1.8) * 3
                                    height: Math.max(3, logLvl * (root.isCompact ? (root.isShort ? 36 : 48) : 64))
                                    radius: width / 2
                                    color: micLevelIndicator.activeColor
                                    opacity: 0.25 + 0.75 * logLvl
                                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                                    antialiasing: true

                                    Behavior on height  { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                                    Behavior on width   { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                                    Behavior on opacity { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                                }
                            }
                        }

                        Rectangle {
                            id: centerDot
                            anchors.centerIn: parent
                            width: root.isCompact ? (root.isShort ? 36 : 44) : 56
                            height: width
                            radius: width / 2
                            color: micLevelIndicator.activeColor

                            SequentialAnimation on opacity {
                                running: trainingAudioApi.isRecording || isAnyPlaybackActive
                                loops: Animation.Infinite
                                NumberAnimation { from: 1.0; to: 0.2; duration: 800; easing.type: Easing.InOutQuad }
                                NumberAnimation { from: 0.2; to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                            }
                        }

                        Row {
                            anchors.left: centerDot.right
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Repeater {
                                model: micLevelIndicator.barCount
                                delegate: Rectangle {
                                    property real lvl: micLevelIndicator.levelHistory[micLevelIndicator.barCount - 1 - index] || 0
                                    property real logLvl: Math.log1p(lvl * 9) / Math.log1p(9)
                                    width: 3
                                    height: Math.max(3, logLvl * (root.isCompact ? (root.isShort ? 32 : 44) : 58))
                                    radius: 1.5
                                    color: micLevelIndicator.activeColor
                                    opacity: 0.25 + 0.75 * logLvl
                                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                                    antialiasing: true

                                    Behavior on height  { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                                    Behavior on opacity { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                                }
                            }
                        }
                    }

                    Text {
                        id: statusLabel
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        Layout.preferredHeight: visible ? implicitHeight : 0
                        visible: !(root.trainingMode === 1 && root.guidedState === root.gsIdle) || isAnyPlaybackActive
                        text: {
                            if (root._isVadPaused) return qsTr("Paused");
                            if (root.trainingMode === 1) {
                                switch (root.guidedState) {
                                    case root.gsPlaying:    return qsTr("Playing...");
                                    case root.gsPending:    return qsTr("Get ready...");
                                    case root.gsListening:  return qsTr("Listening...");
                                    case root.gsProcessing: return qsTr("Processing...");
                                    default: return isAnyPlaybackActive ? qsTr("Playing...") : "";
                                }
                            }
                            return isAnyPlaybackActive ? qsTr("Playing...") :
                                   (trainingAudioApi.isRecording ? qsTr("Listening...") : qsTr("Processing..."));
                        }
                        font.pixelSize: AppScale.fs(root.isCompact ? (root.isShort ? 16 : 18) : 26)
                        font.weight: 600
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        color: {
                            if (root._isVadPaused) return Theme.error(root.Material.theme);
                            if (root.trainingMode === 1) {
                                if (root.guidedState === root.gsListening)
                                    return Theme.success(root.Material.theme);
                                if (root.guidedTimedOut)
                                    return Theme.error(root.Material.theme);
                                return Theme.primary(root.Material.theme);
                            }
                            return isAnyPlaybackActive ? Theme.primary(root.Material.theme) :
                                   (trainingAudioApi.isRecording ? Theme.success(root.Material.theme) : Theme.error(root.Material.theme));
                        }
                    }

                    Item {
                        id: guidedPlayBtn
                        Layout.alignment: Qt.AlignHCenter
                        readonly property int btnSize: root.isCompact ? (root.isShort ? 56 : 64) : 76
                        Layout.preferredWidth: btnSize
                        Layout.preferredHeight: btnSize
                        Layout.minimumWidth: btnSize
                        Layout.minimumHeight: btnSize
                        implicitWidth: btnSize
                        implicitHeight: btnSize
                        visible: root.trainingMode === 1 && root.guidedState === root.gsIdle && !isAnyPlaybackActive && !trainingAudioApi.isRecording

                        Rectangle {
                            id: guidedOuterCircle
                            anchors.fill: parent
                            radius: width / 2
                            color: Qt.alpha(root.guidedTimedOut ? Theme.error(Material.theme) : Theme.primary(Material.theme), 0.14)
                        }

                        Rectangle {
                            id: guidedInnerCircle
                            anchors.centerIn: parent
                            width: parent.width - 10
                            height: width
                            radius: width / 2
                            color: root.guidedTimedOut ? Theme.error(Material.theme) : Theme.primary(Material.theme)

                            Text {
                                anchors.centerIn: parent
                                text: root.guidedTimedOut ? Icons.faRedo : Icons.faPlay
                                font.family: Icons.familySolid
                                font.weight: Font.Black
                                font.pixelSize: AppScale.fs(root.isCompact ? 18 : 22)
                                color: root.guidedTimedOut ? Theme.onError(Material.theme) : Theme.onPrimary(Material.theme)
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    playReferenceBtn.trigger();
                                }
                            }
                        }
                    }

                    Text {
                        id: hintLabel
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        Layout.preferredHeight: visible ? implicitHeight : 0
                        visible: hintLabel.text.length > 0
                        opacity: 0.7
                        text: {
                            if (root._isVadPaused) return qsTr("Press Continue to continue recording.");
                            if (isAnyPlaybackActive) return qsTr("Listen carefully");
                            if (root.trainingMode === 1 && root.guidedState === root.gsIdle && !isAnyPlaybackActive) {
                                return root.guidedTimedOut
                                    ? qsTr("No speech detected — press to try again")
                                    : qsTr("Press to start");
                            }
                            return "";
                        }
                        font.pixelSize: AppScale.fs(root.isCompact ? (root.isShort ? 11 : 12) : 14)
                        color: Theme.onSurface(root.Material.theme)
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }

                RecordRoundButton {
                    id: manualRecordBtn
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    Layout.preferredWidth: root.isCompact ? 96 : 160
                    visible: window.settingsApi ? !window.settingsApi.autoStopRecording : false
                    onRecordingFinished: function(filePath) {
                        if (filePath !== "") {
                            root.updateUserUMP(filePath, true);
                        }
                    }
                }

                Item {
                    id: rightSlot
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 120
                    Layout.minimumWidth: root.sideSlotMinWidth
                    implicitHeight: playUserBtn.implicitHeight

                    PlayRoundButton {
                        id: playUserBtn
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(parent.width, 200)
                        compact: root.isCompact
                        filePath: root.userFilePath
                        text: qsTr("Listen to\nYours")
                        opacity: root.userFilePath !== "" ? 1.0 : 0.0
                        enabled: root.userFilePath !== ""

                        Behavior on opacity {
                            NumberAnimation { duration: 250 }
                        }
                    }
                }
            }


            // Pause stays on its own row. Open file lives in the bottom bar.
            RowLayout {
                id: secondaryActions
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.maximumWidth: implicitWidth
                spacing: root.isCompact ? 8 : 12
                visible: pauseVadButton.visible

                // Pause/Resume VAD Button
                Button {
                    id: pauseVadButton
                    Layout.fillWidth: true
                    Layout.preferredWidth: root.isCompact ? 140 : 160
                    Layout.maximumWidth: Layout.preferredWidth
                    Layout.preferredHeight: 48
                    flat: false
                    visible: (window.settingsApi ? window.settingsApi.autoStopRecording : false)
                             && root.trainingMode === 0

                    contentItem: Text {
                        text: root._isVadPaused ? qsTr("Continue") : qsTr("Pause")
                        font.pixelSize: AppScale.fs(16)
                        font.weight: 600
                        color: Theme.onSecondaryContainer(root.Material.theme)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        Behavior on text {
                            enabled: false
                        }
                    }

                    background: Rectangle {
                        radius: height / 2
                        color: Theme.secondaryContainer(root.Material.theme)
                        border.width: pauseVadButton.visualFocus ? 2 : 0
                        border.color: Theme.primary(root.Material.theme)
                        scale: pauseVadButton.pressed ? 0.97 : 1.0
                        Behavior on scale {
                            NumberAnimation { duration: 100 }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Theme.onSecondaryContainer(root.Material.theme)
                            opacity: pauseVadButton.pressed ? 0.12 : (pauseVadButton.hovered ? 0.08 : 0)
                        }
                    }

                    onClicked: {
                        if (root._isVadPaused) {
                            // Resume VAD without recalibration (calibration already performed on HomePage)
                            root._isVadPaused = false;
                            startRecording();
                        } else {
                            // Pause VAD
                            root._isVadPaused = true;
                            cancelPendingRecording();
                            trainingAudioApi.stopRecording();
                        }
                    }
                }

            }

            FileDialog {
                id: testFileDialog
                title: qsTr("Open test file")
                nameFilters: ["WAV files (*.wav)"]
                onAccepted: {
                    console.log("testFileDialog accepted: " + testFileDialog.selectedFile);
                    var selectedPath = fileApi.getPathFromUrl(testFileDialog.selectedFile);
                    if (selectedPath) {
                        updateUserUMP(selectedPath, false);
                    }
                    // Pause VAD recording after loading a file so the user can review
                    // the result before the microphone starts again.
                    if (root.trainingMode === 0 && window.settingsApi && window.settingsApi.autoStopRecording) {
                        root._isVadPaused = true;
                        // Recording is already stopped (it was stopped before opening the dialog);
                        // just leave _isExiting reset so the page stays in a clean state.
                        _isExiting = false;
                    }
                    _isExiting = false;
                }
                onRejected: {
                    console.log("testFileDialog rejected");
                    // Resume recording if it was active before opening the dialog and VAD is not paused
                    _isExiting = false;
                    if (root.trainingMode === 0 && _wasRecordingBeforeDialog && !root._isVadPaused && window.settingsApi && window.settingsApi.autoStopRecording) {
                        console.log("Resuming recording after opening test file dialog");
                        _isExiting = false; // Allow recording to auto-restart
                        root.startRecording();
                    }
                }
            }
        }
    }
}
