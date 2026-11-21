#ifndef TONALERROR_H
#define TONALERROR_H

#include <cmath>
#include <cstddef>
#include <vector>

// Exponent of the mean tonal error.
// p = 3 is the cubic mean: a large miss weighs more than it would in an
// arithmetic mean. Change this constant, or General/tonalErrorPower in
// settings.ini (the settings value wins when it is a positive finite number).
//
// Boris Lobanov's exact formula was a picture in "Доработки-1.docx" and that
// picture was lost. This power mean is the reading of his written request
// ("average the per-sample differences, as a cubic or higher mean") and still
// needs his confirmation.
inline constexpr double kDefaultTonalErrorPower = 3.0;

// Power mean of the absolute per-sample difference of two curves:
//
//   M_p = ( (1/n) * sum_i |r_i - u_i|^p ) ^ (1/p)
//
// Callers pass the same aligned samples used for melodic similarity (after
// the optional nucleus-only cut). Those samples are the normalized pitch
// curves, not raw hertz. The training screen shows M_p * 100.
// Unequal lengths use the shared prefix; an empty input returns 0.
inline double meanAbsolutePower(const std::vector<double>& reference,
    const std::vector<double>& user,
    double power)
{
    const std::size_t n = reference.size() < user.size() ? reference.size() : user.size();
    if (n == 0) {
        return 0.0;
    }
    if (!(power > 0.0) || !std::isfinite(power)) {
        power = kDefaultTonalErrorPower;
    }
    double sum = 0.0;
    for (std::size_t i = 0; i < n; ++i) {
        const double diff = std::fabs(reference[i] - user[i]);
        sum += std::pow(diff, power);
    }
    return std::pow(sum / static_cast<double>(n), 1.0 / power);
}

#endif // TONALERROR_H
