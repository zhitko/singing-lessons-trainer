#include "src/api/analysisapi.h"
#include "src/api/helpers/settings.h"
#include "src/api/wavfileapi.h"
#include "src/services/umpservice.h"

#include <QCoreApplication>
#include <QDirIterator>
#include <QFile>
#include <QPointF>
#include <QTemporaryDir>
#include <cmath>
#include <iostream>
#include <limits>
#include <memory>
#include <stdexcept>

namespace {
void require(bool condition, const QString& message)
{
    if (!condition)
        throw std::runtime_error(message.toStdString());
}

bool near(double actual, double expected)
{
    return std::abs(actual - expected) < 1e-8;
}

QVariantMap nucleus(uint position, uint length)
{
    return {{"position", position}, {"length", length},
        {"type", static_cast<int>(CuePointType::NUCLEUS)}};
}

void checkInvalidAndMaskedComparisons(AnalysisApi& analysis)
{
    const QVariantList curve {0.0, 0.25, 1.0};
    const QVariantList mask {nucleus(0, 2)};
    const auto invalid = [&](const QVariantList& ref, const QVariantList& user,
                             const QVariantList& refCues, const QVariantList& userCues,
                             bool onlyN, double min = 70, double max = 700) {
        const auto result = analysis.compareUMP(ref, user, refCues, userCues, min, max, onlyN);
        require(!result.value("valid").toBool(), "Invalid comparison accepted");
        require(!result.contains("meanTonalError") && !result.contains("shapeSimilarity"),
            "Invalid comparison exposed numeric scores");
    };
    invalid({}, {}, {}, {}, false);
    invalid(curve, {}, {}, {}, false);
    invalid(curve, {0.0, 0.25}, mask, mask, true);
    invalid(curve, curve, {}, {}, true);
    invalid(curve, curve, {nucleus(0, 1)}, {nucleus(1, 1)}, true);
    invalid(curve, curve, {}, {}, false, 700, 70);
    invalid(curve, curve, {}, {}, false, 70, std::numeric_limits<double>::infinity());
    invalid(curve, {0.0, std::numeric_limits<double>::quiet_NaN(), 1.0}, {}, {}, false);
    invalid(curve, {0.0, std::numeric_limits<double>::infinity(), 1.0}, {}, {}, false);

    const QVariantList different {0.0, 0.25, 0.0};
    const auto masked = analysis.compareUMP(curve, different, mask, mask, 70, 700, true);
    const auto full = analysis.compareUMP(curve, different, mask, mask, 70, 700, false);
    require(masked.value("valid").toBool() && near(masked.value("meanTonalError").toDouble(), 0),
        "Nucleus mask did not exclude differences outside the shared nucleus");
    require(full.value("valid").toBool()
            && near(full.value("meanTonalError").toDouble(), std::cbrt(1.0 / 3.0)),
        "Unmasked API result did not match the cubic mean");

    const auto reversed = analysis.compareUMP(curve, {1.0, 0.25, 0.0}, {}, {}, 70, 700, false);
    require(reversed.value("valid").toBool() && near(reversed.value("shapeSimilarity").toDouble(), 0),
        "Negative correlation must remain a valid zero similarity");

    auto settings = Settings::loadSettings();
    const double originalPower = settings.tonalErrorPower;
    settings.tonalErrorPower = 4;
    Settings::saveSettings(settings);
    const auto fourth = analysis.compareUMP(curve, different, {}, {}, 70, 700, false);
    require(fourth.value("valid").toBool()
            && near(fourth.value("meanTonalError").toDouble(), std::pow(1.0 / 3.0, 0.25)),
        "Scoring API ignored the configured power");
    settings.tonalErrorPower = originalPower;
    Settings::saveSettings(settings);
}

void checkShortCueStructures()
{
    CuePointData cue {};
    cue.type = CuePointType::NUCLEUS;
    cue.label = "n";
    cue.length = 4;
    const auto single = UMPService::getUMP("Linear", {0.2, 0.4, 0.6, 0.8}, {cue}, 50, 100, 50, 4);
    require(single.ump.size() == 100 && single.processedCuePoints.size() == 1,
        "Single-cue lesson must produce one region");
    cue.length = 2;
    auto second = cue;
    second.position = 2;
    const auto two = UMPService::getUMP("Linear", {0.2, 0.4, 0.6, 0.8}, {cue, second}, 50, 100, 50, 4);
    require(two.ump.size() == 200 && two.processedCuePoints.size() == 2,
        "Two-cue lesson must preserve both regions");
    const auto zeros = UMPService::getUMP("Linear", {0.0, 0.0, 0.0, 0.0}, {cue}, 50, 100, 50, 4);
    require(zeros.ump.size() == 100, "All-zero single-cue input must remain bounded");
    for (double value : zeros.ump)
        require(value == 0, "All-zero region must not read nonexistent interpolation boundaries");
    require(UMPService::getUMP("Linear", {0.2}, {cue}, 50, 100, 50, 0).ump.empty(),
        "Zero waveform length must be rejected");
}

void checkLessons(const QString& sourceDir, WavFileApi& wav, AnalysisApi& analysis)
{
    auto settings = Settings::loadSettings();
    QStringList paths;
    QDirIterator files(sourceDir + "/data/patterns", {"*.wav"}, QDir::Files, QDirIterator::Subdirectories);
    while (files.hasNext())
        paths.append(files.next());
    require(!paths.empty(), "No bundled lessons found");

    int comparisons = 0;
    bool checkedSingleCue = false;
    for (bool onlyN : {false, true}) {
        settings.useOnlyN = onlyN;
        Settings::saveSettings(settings);
        for (const QString& path : paths) {
            const QString context = path + (onlyN ? " (nucleus only)" : " (all frames)");
            std::unique_ptr<WaveFile, decltype(&waveCloseFile)> file(wav.openWavFile(path), waveCloseFile);
            require(file != nullptr, "Cannot open " + context);
            const auto cues = wav.getCuePoints(file.get());
            const int waveSize = wav.getWaveData(file.get()).size();

            // These are the same entry points used by TrainingPage for each side.
            const auto referencePitch = wav.getScoringPitch(file.get());
            const auto userPitch = wav.getScoringPitch(file.get());
            const auto ref = wav.getScoringUMP(referencePitch, cues, waveSize);
            require(!ref.value("ump").toList().isEmpty(), "Empty reference UMP: " + context);
            if (cues.size() == 1) {
                checkedSingleCue = true;
                require(ref.value("cuePoints").toList().size() == 1, "Duplicated single cue: " + context);
            }

            const auto derivative = wav.getPitchDerivative(file.get(), QString::fromStdString(settings.algorithm),
                settings.frameShift, settings.sampleRate, settings.minF0, settings.maxF0,
                settings.voicingThreshold, "LOG_F0");
            const auto cepstrum = wav.getCepstr(file.get(), settings.specFftLength, settings.frameShift,
                settings.sampleRate, settings.cepstrNumOrder, QString::fromStdString(settings.algorithm),
                settings.minF0, settings.maxF0, settings.voicingThreshold, settings.specF0Refinement);
            const auto aligned = wav.getDP({}, {}, referencePitch, {}, derivative, {}, cepstrum,
                {}, {}, userPitch, {}, derivative, {}, cepstrum, userPitch, {});
            require(!aligned.value("pitch").toList().isEmpty(), "Empty DTW output: " + context);
            const auto user = wav.getScoringUMP(aligned.value("pitch").toList(), cues, waveSize);
            const auto score = analysis.compareUMP(ref.value("ump").toList(), user.value("ump").toList(),
                ref.value("cuePoints").toList(), user.value("cuePoints").toList(),
                settings.minF0, settings.maxF0, onlyN);
            require(score.value("valid").toBool(), "Invalid self-comparison: " + context);
            require(near(score.value("shapeSimilarity").toDouble(), 100), "Self-similarity below 100: " + context);
            require(near(score.value("meanTonalError").toDouble(), 0), "Nonzero self-error: " + context);
            ++comparisons;
        }
    }
    require(checkedSingleCue, "Single-cue bundled lesson was not exercised");
    std::cout << "Passed " << comparisons << " self-comparisons across " << paths.size()
              << " bundled lessons, in both scoring modes.\n";
}
} // namespace

int main(int argc, char** argv)
{
    QCoreApplication app(argc, argv);
    // Use an isolated portable data directory, never the user's saved settings.
    QTemporaryDir temporary;
    try {
        require(argc == 2 && temporary.isValid(), "Expected source directory and writable temporary storage");
        app.setOrganizationName("ScoringTests");
        app.setApplicationName("Regression");
        qputenv("APPIMAGE", temporary.filePath("test.AppImage").toLocal8Bit());
        const QString sourceDir = QString::fromLocal8Bit(argv[1]);
        require(QFile::copy(sourceDir + "/settings.ini", Settings::getAppDataDir() + "/settings.ini"), "Cannot seed test defaults");
        qInstallMessageHandler([](QtMsgType, const QMessageLogContext&, const QString&) {});
        WavFileApi wav;
        AnalysisApi analysis;
        checkShortCueStructures();
        checkInvalidAndMaskedComparisons(analysis);
        checkLessons(sourceDir, wav, analysis);
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
