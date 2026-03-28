#pragma once

#include "aaplcad/geometry/point2d.h"

#include <vector>

namespace aaplcad::database {
class Document;
}

namespace aaplcad::graphics {

class ViewState2d;

struct LineSegment2d {
    geometry::Point2d start;
    geometry::Point2d end;
};

struct DrawList2d {
    std::vector<LineSegment2d> lineSegments;
};

[[nodiscard]] DrawList2d buildDrawList2d(const database::Document& document,
                                         const ViewState2d& viewState,
                                         double viewportWidth,
                                         double viewportHeight);

}  // namespace aaplcad::graphics