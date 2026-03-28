#include "aaplcad/core/object_id.h"
#include "aaplcad/core/result.h"
#include "aaplcad/core/vector2d.h"
#include "aaplcad/platform/platform.h"

#include <cstdlib>
#include <iostream>

namespace {

void require(bool condition, const char* message) {
    if (!condition) {
        std::cerr << "test failure: " << message << '\n';
        std::exit(1);
    }
}

}  // namespace

int main() {
    const aaplcad::core::ObjectId invalidId;
    const aaplcad::core::ObjectId validId{42};
    require(!invalidId.isValid(), "default object id should be invalid");
    require(validId.isValid(), "explicit object id should be valid");
    require(validId.value() == 42, "object id should preserve numeric value");

    const aaplcad::core::Result<int> okResult{7};
    require(okResult.ok(), "value result should be ok");
    require(okResult.value() == 7, "value result should expose stored value");

    const aaplcad::core::Result<void> errorResult{{"E_PHASE1", "phase 1 placeholder error"}};
    require(!errorResult.ok(), "error result should not be ok");
    require(errorResult.error().code == "E_PHASE1", "error result should expose error code");

    const auto point = aaplcad::core::Vector2d{1.0, 2.0}.translated(3.0, -1.0);
    require(point.x == 4.0 && point.y == 1.0, "vector translation should work");

    const auto platform = aaplcad::platform::currentPlatform();
    require(!platform.operatingSystem.empty(), "platform info should expose operating system");

    std::cout << "aaplcad_tests passed\n";
    return 0;
}
