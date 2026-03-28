#include "aaplcad/core/log.h"

#include <iostream>

namespace aaplcad::core {

namespace {

[[nodiscard]] const char* toString(LogLevel level) {
    switch (level) {
    case LogLevel::debug:
        return "debug";
    case LogLevel::info:
        return "info";
    case LogLevel::warning:
        return "warning";
    case LogLevel::error:
        return "error";
    }

    return "unknown";
}

}  // namespace

void logMessage(LogLevel level, std::string_view message) {
    std::clog << "[aaplcad][" << toString(level) << "] " << message << '\n';
}

}  // namespace aaplcad::core
