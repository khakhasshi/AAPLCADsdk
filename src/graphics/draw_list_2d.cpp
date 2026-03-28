#include "aaplcad/graphics/draw_list_2d.h"

#include <algorithm>
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

geometry::Extents2d normalizedExtents(geometry::Extents2d extents) noexcept {
    return {
        {std::min(extents.min.x, extents.max.x), std::min(extents.min.y, extents.max.y)},
        {std::max(extents.min.x, extents.max.x), std::max(extents.min.y, extents.max.y)},
    };
}

bool containsPoint(const geometry::Extents2d& extents, geometry::Point2d point) noexcept {
    return point.x >= extents.min.x && point.x <= extents.max.x &&
           point.y >= extents.min.y && point.y <= extents.max.y;
}

double crossProduct(geometry::Point2d a, geometry::Point2d b, geometry::Point2d c) noexcept {
    return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
}

bool onSegment(geometry::Point2d a, geometry::Point2d b, geometry::Point2d point) noexcept {
    return point.x >= std::min(a.x, b.x) && point.x <= std::max(a.x, b.x) &&
           point.y >= std::min(a.y, b.y) && point.y <= std::max(a.y, b.y);
}

bool segmentsIntersect(geometry::Point2d a0, geometry::Point2d a1, geometry::Point2d b0, geometry::Point2d b1) noexcept {
    const double d1 = crossProduct(a0, a1, b0);
    const double d2 = crossProduct(a0, a1, b1);
    const double d3 = crossProduct(b0, b1, a0);
    const double d4 = crossProduct(b0, b1, a1);

    if (((d1 > 0.0 && d2 < 0.0) || (d1 < 0.0 && d2 > 0.0)) &&
        ((d3 > 0.0 && d4 < 0.0) || (d3 < 0.0 && d4 > 0.0))) {
        return true;
    }

    if (d1 == 0.0 && onSegment(a0, a1, b0)) {
        return true;
    }
    if (d2 == 0.0 && onSegment(a0, a1, b1)) {
        return true;
    }
    if (d3 == 0.0 && onSegment(b0, b1, a0)) {
        return true;
    }
    if (d4 == 0.0 && onSegment(b0, b1, a1)) {
        return true;
    }

    return false;
}

bool segmentIntersectsExtents(const LineSegment2d& segment, const geometry::Extents2d& extents) noexcept {
    if (containsPoint(extents, segment.start) || containsPoint(extents, segment.end)) {
        return true;
    }

    const geometry::Point2d topLeft{extents.min.x, extents.max.y};
    const geometry::Point2d bottomRight{extents.max.x, extents.min.y};

    return segmentsIntersect(segment.start, segment.end, extents.min, topLeft) ||
           segmentsIntersect(segment.start, segment.end, topLeft, extents.max) ||
           segmentsIntersect(segment.start, segment.end, extents.max, bottomRight) ||
           segmentsIntersect(segment.start, segment.end, bottomRight, extents.min);
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

std::vector<core::ObjectId> pickLineSegmentsInScreenRect(const DrawList2d& drawList,
                                                         geometry::Extents2d screenRect) {
    std::vector<core::ObjectId> entityIds;
    const auto rect = normalizedExtents(screenRect);
    if (rect.width() <= 0.0 || rect.height() <= 0.0) {
        return entityIds;
    }

    for (const auto& segment : drawList.lineSegments) {
        if (!segmentIntersectsExtents(segment, rect)) {
            continue;
        }

        if (std::find(entityIds.begin(), entityIds.end(), segment.entityId) == entityIds.end()) {
            entityIds.push_back(segment.entityId);
        }
    }

    return entityIds;
}

}  // namespace aaplcad::graphics