#pragma once

#include "aaplcad/geometry/extents2d.h"
#include "aaplcad/geometry/point2d.h"

namespace aaplcad::geometry {

class Line2d {
public:
    constexpr Line2d() = default;
    constexpr Line2d(Point2d start, Point2d end) noexcept
        : start_(start), end_(end) {
    }

    [[nodiscard]] constexpr Point2d start() const noexcept {
        return start_;
    }

    [[nodiscard]] constexpr Point2d end() const noexcept {
        return end_;
    }

    [[nodiscard]] constexpr Extents2d extents() const noexcept {
        return {
            {start_.x < end_.x ? start_.x : end_.x, start_.y < end_.y ? start_.y : end_.y},
            {start_.x > end_.x ? start_.x : end_.x, start_.y > end_.y ? start_.y : end_.y},
        };
    }

private:
    Point2d start_{};
    Point2d end_{};
};

}  // namespace aaplcad::geometry
