#pragma once

#include "aaplcad/core/object_id.h"
#include "aaplcad/geometry/point2d.h"

#include <optional>
#include <vector>

namespace aaplcad::database {
class Document;
}

namespace aaplcad::graphics {

class ViewState2d;

struct LineSegment2d {
    core::ObjectId entityId;
    geometry::Point2d start;
    geometry::Point2d end;
};

struct DrawList2d {
    std::vector<LineSegment2d> lineSegments;
};

struct SelectionHit2d {
    core::ObjectId entityId;
    double distance = 0.0;
};

[[nodiscard]] DrawList2d buildDrawList2d(const database::Document& document,
                                         const ViewState2d& viewState,
                                         double viewportWidth,
                                         double viewportHeight);

[[nodiscard]] std::optional<SelectionHit2d> pickLineSegmentAtScreenPoint(const DrawList2d& drawList,
                                                                          geometry::Point2d screenPoint,
                                                                          double tolerance);

}  // namespace aaplcad::graphics