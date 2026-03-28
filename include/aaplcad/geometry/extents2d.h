#pragma once

#include "aaplcad/geometry/point2d.h"

namespace aaplcad::geometry {

struct Extents2d {
    Point2d min;
    Point2d max;

    [[nodiscard]] constexpr double width() const noexcept {
        return max.x - min.x;
    }

    [[nodiscard]] constexpr double height() const noexcept {
        return max.y - min.y;
    }
};

}  // namespace aaplcad::geometry
