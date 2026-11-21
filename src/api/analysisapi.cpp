#include "analysisapi.h"
#include "helpers/logger.h"
#include "helpers/settings.h"
#include "src/services/helpers/tonalerror.h"
#include "src/services/helpers/vectorutils.h"
#include "src/services/umpservice.h"
#include <QPointF>
#include <algorithm>

AnalysisApi::AnalysisApi(QObject* parent)
    : QObject(parent)
{
}

QVariantMap AnalysisApi::compareUMP(const QVariantList& referenceUmp,
    const QVariantList& userUmp,
    const QVariantList& referenceCuePoints,
    const QVariantList& userCuePoints,
    double fullMin,
    double fullMax,
    bool useOnlyN)
{
    LOG_DEBUG() << "Start: AnalysisApi::compareUMP - reference.size="
                << referenceUmp.size() << ", user.size=" << userUmp.size();

    QVariantMap out;

    // Convert QVariantList -> std::vector<double>
    auto toVector = [](const QVariantList& list) {
        std::vector<double> vec;
        vec.reserve(list.size());
        for (const auto& v : list) {
            if (v.canConvert<QPointF>()) {
                vec.push_back(v.toPointF().y());
            } else {
                vec.push_back(v.toDouble());
            }
        }
        return vec;
    };

    auto buildNucleusMask = [](const QVariantList& cuePoints, size_t length) {
        std::vector<bool> mask(length, false);
        for (const auto& cp : cuePoints) {
            QVariantMap cpMap = cp.toMap();
            if (!cpMap.contains("type") || !cpMap["type"].canConvert<int>()) {
                continue;
            }
            int type = cpMap["type"].toInt();
            if (type != static_cast<int>(CuePointType::NUCLEUS)) {
                continue;
            }
            unsigned int pos = cpMap["position"].toUInt();
            unsigned int len = cpMap["length"].toUInt();
            if (pos >= length) {
                continue;
            }
            const size_t end = pos + std::min(length - pos, static_cast<size_t>(len));
            for (size_t i = pos; i < end; ++i) {
                mask[i] = true;
            }
        }
        return mask;
    };

    std::vector<double> refVec = toVector(referenceUmp);
    std::vector<double> userVec = toVector(userUmp);

    // Reject mismatched timelines before masking; truncation could hide a
    // failed alignment and make an incomplete take look valid.
    if (refVec.empty() || refVec.size() != userVec.size()) {
        return {{"valid", false}};
    }

    if (useOnlyN) {
        std::vector<bool> refMask = buildNucleusMask(referenceCuePoints, refVec.size());
        std::vector<bool> userMask = buildNucleusMask(userCuePoints, userVec.size());

        if (!refMask.empty() && !userMask.empty()) {
            std::vector<double> refNucleus;
            std::vector<double> userNucleus;
            size_t commonLength = std::min(refVec.size(), userVec.size());
            for (size_t i = 0; i < commonLength; ++i) {
                if (i < refMask.size() && i < userMask.size() && refMask[i] && userMask[i]) {
                    refNucleus.push_back(refVec[i]);
                    userNucleus.push_back(userVec[i]);
                }
            }
            if (!refNucleus.empty() && !userNucleus.empty()) {
                refVec.swap(refNucleus);
                userVec.swap(userNucleus);
            } else {
                LOG_WARNING() << "compareUMP: useOnlyN=true but no matching NUCLEUS frames found";
                return {{"valid", false}};
            }
        } else {
            LOG_WARNING() << "compareUMP: useOnlyN=true but cue point metadata is missing";
            return {{"valid", false}};
        }
    }

    // p is General/tonalErrorPower. Missing or invalid values use the cubic mean.
    const AppSettings settings = Settings::loadSettings();
    const double tonalErrorPower = settings.tonalErrorPower > 0.0
        ? settings.tonalErrorPower
        : kDefaultTonalErrorPower;
    UMPComparison cmp = UMPService::compareUMP(refVec, userVec, fullMin, fullMax, tonalErrorPower);

    out["valid"] = cmp.valid;
    if (!cmp.valid) {
        return out;
    }

    out["referenceRange"] = cmp.referenceRange;
    out["userRange"] = cmp.userRange;
    out["rangeSimilarity"] = cmp.rangeSimilarity;
    out["shapeSimilarity"] = cmp.shapeSimilarity;
    out["meanTonalError"] = cmp.meanTonalError;

    LOG_DEBUG() << "Finish: AnalysisApi::compareUMP - refRange="
                << cmp.referenceRange << ", userRange=" << cmp.userRange
                << ", rangeSim=" << cmp.rangeSimilarity
                << ", shapeSim=" << cmp.shapeSimilarity
                << ", meanTonalError=" << cmp.meanTonalError
                << ", p=" << tonalErrorPower;

    return out;
}
