#include "aaplcad/platform/platform.h"

#include <sstream>

namespace aaplcad::platform {

std::string PlatformInfo::description() const {
    std::ostringstream stream;
    stream << operatingSystem << " / " << architecture;
    stream << " / Metal " << (metalAvailable ? "available" : "planned");
    return stream.str();
}

PlatformInfo currentPlatform() {
#if defined(__APPLE__) && defined(__aarch64__)
    return {"macOS", "arm64", true};
#elif defined(__APPLE__)
    return {"macOS", "x86_64", true};
#elif defined(_WIN32)
    return {"Windows", "unknown", false};
#else
    return {"Unknown", "unknown", false};
#endif
}

}  // namespace aaplcad::platform
