#include "aaplcad/aaplcad.h"
#include "aaplcad/core/log.h"
#include "aaplcad/database/document.h"
#include "aaplcad/database/line_entity.h"
#include "aaplcad/geometry/line2d.h"
#include "aaplcad/platform/platform.h"

#include <iostream>
#include <memory>

int main() {
    const auto platform = aaplcad::platform::currentPlatform();
    aaplcad::core::logMessage(aaplcad::core::LogLevel::info, "AAPLCAD minimal scaffold starting");

    aaplcad::database::Document document;
    const auto layerResult = document.addLayer("demo");
    if (!layerResult.ok()) {
        std::cerr << "failed to add layer: " << layerResult.error().message << '\n';
        return 1;
    }

    auto line = std::make_unique<aaplcad::database::LineEntity>(
        aaplcad::geometry::Line2d{{0.0, 0.0}, {100.0, 25.0}});
    line->setLayerName("demo");

    const auto entityResult = document.addEntity(std::move(line));
    if (!entityResult.ok()) {
        std::cerr << "failed to add entity: " << entityResult.error().message << '\n';
        return 1;
    }

    std::cout << "AAPLCAD SDK " << aaplcad::kVersionString << '\n';
    std::cout << "Platform: " << platform.description() << '\n';
    std::cout << "Document layers: " << document.layerCount() << ", entities: " << document.entityCount() << '\n';
    std::cout << "Next step: expand viewer navigation, picking, and input semantics." << '\n';
    return 0;
}
