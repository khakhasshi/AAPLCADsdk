#pragma once

#define AAPLCAD_STRINGIFY_INNER(x) #x
#define AAPLCAD_STRINGIFY(x) AAPLCAD_STRINGIFY_INNER(x)

namespace aaplcad {

inline constexpr int kVersionMajor = AAPLCAD_VERSION_MAJOR;
inline constexpr int kVersionMinor = AAPLCAD_VERSION_MINOR;
inline constexpr int kVersionPatch = AAPLCAD_VERSION_PATCH;
inline constexpr const char* kVersionString =
    AAPLCAD_STRINGIFY(AAPLCAD_VERSION_MAJOR) "."
    AAPLCAD_STRINGIFY(AAPLCAD_VERSION_MINOR) "."
    AAPLCAD_STRINGIFY(AAPLCAD_VERSION_PATCH);

}  // namespace aaplcad
