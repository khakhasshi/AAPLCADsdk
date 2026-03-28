#pragma once

#include "aaplcad/geometry/extents2d.h"
#include "aaplcad/geometry/point2d.h"

namespace aaplcad::geometry {

class Circle2d {
public:
    constexpr Circle2d() = default;
    constexpr Circle2d(Point2d center, double radius) noexcept
        : center_(center), radius_(radius) {
    }

    [[nodiscard]] constexpr Point2d center() const noexcept {
        return center_;
    }

    [[nodiscard]] constexpr double radius() const noexcept {
        return radius_;
    }

    [[nodiscard]] constexpr Extents2d extents() const noexcept {
        return {
            {center_.x - radius_, center_.y - radius_},
            {center_.x + radius_, center_.y + radius_},
        };
    }

private:
    Point2d center_{};
    double radius_ = 0.0;
};

}  // namespace aaplcad::geometry
