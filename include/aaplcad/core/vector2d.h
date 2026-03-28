#pragma once

namespace aaplcad::core {

struct Vector2d {
    double x = 0.0;
    double y = 0.0;

    [[nodiscard]] constexpr Vector2d translated(double dx, double dy) const noexcept {
        return {x + dx, y + dy};
    }
};

}  // namespace aaplcad::core
