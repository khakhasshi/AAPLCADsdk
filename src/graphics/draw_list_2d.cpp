#include "aaplcad/graphics/draw_list_2d.h"

#include <cmath>

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

double squaredDistanceToSegment(geometry::Point2d point, const LineSegment2d& segment) noexcept {
    const double deltaX = segment.end.x - segment.start.x;
    const double deltaY = segment.end.y - segment.start.y;
    const double segmentLengthSquared = deltaX * deltaX + deltaY * deltaY;

    if (segmentLengthSquared == 0.0) {
        const double pointDeltaX = point.x - segment.start.x;
        const double pointDeltaY = point.y - segment.start.y;
        return pointDeltaX * pointDeltaX + pointDeltaY * pointDeltaY;
    }

    const double projection = ((point.x - segment.start.x) * deltaX + (point.y - segment.start.y) * deltaY) / segmentLengthSquared;
    const double clampedProjection = projection < 0.0 ? 0.0 : (projection > 1.0 ? 1.0 : projection);
    const double nearestX = segment.start.x + clampedProjection * deltaX;
    const double nearestY = segment.start.y + clampedProjection * deltaY;
    const double nearestDeltaX = point.x - nearestX;
    const double nearestDeltaY = point.y - nearestY;
    return nearestDeltaX * nearestDeltaX + nearestDeltaY * nearestDeltaY;
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

        drawList.lineSegments.push_back({entity->id(), screenStart, screenEnd});
    }

    return drawList;
}

std::optional<SelectionHit2d> pickLineSegmentAtScreenPoint(const DrawList2d& drawList,
                                                           geometry::Point2d screenPoint,
                                                           double tolerance) {
    if (tolerance < 0.0) {
        return std::nullopt;
    }

    const double toleranceSquared = tolerance * tolerance;
    std::optional<SelectionHit2d> closestHit;

    for (const auto& segment : drawList.lineSegments) {
        const double squaredDistance = squaredDistanceToSegment(screenPoint, segment);
        if (squaredDistance > toleranceSquared) {
            continue;
        }

        const double distance = std::sqrt(squaredDistance);
        if (!closestHit.has_value() || distance < closestHit->distance) {
            closestHit = SelectionHit2d{segment.entityId, distance};
        }
    }

    return closestHit;
}

}  // namespace aaplcad::graphics