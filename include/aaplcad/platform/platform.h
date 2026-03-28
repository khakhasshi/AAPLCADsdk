#pragma once

#include <string>

namespace aaplcad::platform {

struct PlatformInfo {
    std::string operatingSystem;
    std::string architecture;
    bool metalAvailable = false;

    [[nodiscard]] std::string description() const;
};

[[nodiscard]] PlatformInfo currentPlatform();

}  // namespace aaplcad::platform
