#pragma once

namespace aaplcad::geometry {

struct Point2d {
    double x = 0.0;
    double y = 0.0;

    [[nodiscard]] constexpr Point2d translated(double dx, double dy) const noexcept {
        return {x + dx, y + dy};
    }
};

}  // namespace aaplcad::geometry
