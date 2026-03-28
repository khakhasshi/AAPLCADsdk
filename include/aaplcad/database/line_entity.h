#pragma once

#include "aaplcad/database/entity.h"
#include "aaplcad/geometry/line2d.h"

namespace aaplcad::database {

class LineEntity final : public Entity {
public:
    explicit LineEntity(aaplcad::geometry::Line2d geometry) noexcept
        : geometry_(geometry) {
    }

    [[nodiscard]] EntityKind kind() const noexcept override {
        return EntityKind::line;
    }

    [[nodiscard]] const aaplcad::geometry::Line2d& geometry() const noexcept {
        return geometry_;
    }

private:
    aaplcad::geometry::Line2d geometry_{};
};

}  // namespace aaplcad::database
