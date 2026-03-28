#pragma once

#include <string_view>

namespace aaplcad::core {

enum class LogLevel {
    debug,
    info,
    warning,
    error,
};

void logMessage(LogLevel level, std::string_view message);

}  // namespace aaplcad::core
