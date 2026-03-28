#include "aaplcad/aaplcad.h"
#include "aaplcad/core/log.h"
#include "aaplcad/platform/platform.h"

#include <iostream>

int main() {
    const auto platform = aaplcad::platform::currentPlatform();
    aaplcad::core::logMessage(aaplcad::core::LogLevel::info, "AAPLCAD minimal scaffold starting");

    std::cout << "AAPLCAD SDK " << aaplcad::kVersionString << '\n';
    std::cout << "Platform: " << platform.description() << '\n';
    std::cout << "Next step: replace this console app with an AppKit + Metal viewer shell." << '\n';
    return 0;
}
