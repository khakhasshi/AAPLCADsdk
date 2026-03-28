#include "aaplcad/graphics/draw_list_2d.h"

#include "aaplcad/database/document.h"
#include "aaplcad/database/entity.h"
#include "aaplcad/database/line_entity.h"
#include "aaplcad/geometry/extents2d.h"
#include "aaplcad/graphics/view_state_2d.h"

namespace aaplcad::graphics {

namespace {

bool intersectsViewport(const geometry::Extents2d& extents, double viewportWidth, double viewportHeight) noexcept {
    if (extents.max.x < 0.0 || extents.max.y < 0.0) {
        return false;
    }

    if (extents.min.x > viewportWidth || extents.min.y > viewportHeight) {
        return false;
    }

    return true;
}

geometry::Extents2d makeScreenExtents(geometry::Point2d a, geometry::Point2d b) noexcept {
    return {
        {a.x < b.x ? a.x : b.x, a.y < b.y ? a.y : b.y},
        {a.x > b.x ? a.x : b.x, a.y > b.y ? a.y : b.y},
    };
}

}  // namespace

DrawList2d buildDrawList2d(const database::Document& document,
                           const ViewState2d& viewState,
                           double viewportWidth,
                           double viewportHeight) {
    DrawList2d drawList;

    if (viewportWidth <= 0.0 || viewportHeight <= 0.0) {
        return drawList;
    }

    for (const auto& entity : document.entities()) {
        if (entity == nullptr || entity->kind() != database::EntityKind::line) {
            continue;
        }

        const auto* lineEntity = static_cast<const database::LineEntity*>(entity.get());
        const auto screenStart = viewState.worldToScreen(lineEntity->geometry().start());
        const auto screenEnd = viewState.worldToScreen(lineEntity->geometry().end());
        const auto screenExtents = makeScreenExtents(screenStart, screenEnd);
        if (!intersectsViewport(screenExtents, viewportWidth, viewportHeight)) {
            continue;
        }

        drawList.lineSegments.push_back({screenStart, screenEnd});
    }

    return drawList;
}

}  // namespace aaplcad::graphics