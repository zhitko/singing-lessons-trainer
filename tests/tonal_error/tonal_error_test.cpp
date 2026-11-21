#include "../../src/services/helpers/tonalerror.h"

#include <cmath>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <vector>

static void require(bool condition, const char* message)
{
    if (!condition) {
        throw std::runtime_error(message);
    }
}

static bool near(double value, double expected, double tol = 1e-9)
{
    return std::fabs(value - expected) <= tol;
}

int main()
{
    const std::vector<double> flat { 0.2, 0.2, 0.2, 0.2 };
    const std::vector<double> same { 0.2, 0.2, 0.2, 0.2 };
    require(near(meanAbsolutePower(flat, same, 3.0), 0.0), "identical curves must score 0");

    const std::vector<double> shifted { 0.4, 0.4, 0.4, 0.4 };
    require(near(meanAbsolutePower(flat, shifted, 1.0), 0.2), "p=1 is the arithmetic mean of |diff|");
    require(near(meanAbsolutePower(flat, shifted, 3.0), 0.2), "a constant difference is unchanged by p");

    // diffs 0, 0, 0, 1. Arithmetic mean is 0.25. Cubic mean is cbrt(0.25) ≈ 0.630,
    // which is larger: the single big miss outweighs the three perfect samples.
    const std::vector<double> reference { 0.0, 0.0, 0.0, 0.0 };
    const std::vector<double> user { 0.0, 0.0, 0.0, 1.0 };
    const double arithmetic = meanAbsolutePower(reference, user, 1.0);
    const double cubic = meanAbsolutePower(reference, user, 3.0);
    require(near(arithmetic, 0.25), "arithmetic mean of 0,0,0,1");
    require(near(cubic, std::pow(0.25, 1.0 / 3.0)), "cubic mean of 0,0,0,1");
    require(cubic > arithmetic, "p=3 must weigh the large error more than p=1");

    require(near(meanAbsolutePower(reference, user, 0.0), cubic), "non-positive p falls back to 3");
    require(near(meanAbsolutePower(reference, user, std::numeric_limits<double>::quiet_NaN()), cubic), "NaN p falls back to 3");
    require(near(meanAbsolutePower(reference, user, std::numeric_limits<double>::infinity()), cubic), "infinite p falls back to 3");
    require(near(meanAbsolutePower(reference, user, 4.0), std::pow(0.25, 0.25)), "higher powers use the configured exponent");
    require(near(meanAbsolutePower(reference, user, kDefaultTonalErrorPower), cubic), "default exponent is 3");
    require(near(meanAbsolutePower({}, {}, 3.0), 0.0), "empty input is 0");

    // Percent shown in the UI is the mean times 100.
    require(near(cubic * 100.0, std::pow(0.25, 1.0 / 3.0) * 100.0), "percent is mean x 100");

    std::cout << "tonal_error_test ok\n";
    return 0;
}
