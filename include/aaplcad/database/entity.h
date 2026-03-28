#pragma once

#include "aaplcad/core/object_id.h"

#include <string>
#include <utility>

namespace aaplcad::database {

enum class EntityKind {
    unknown,
    line,
    circle,
};

class Entity {
public:
    Entity() = default;
    virtual ~Entity() = default;

    [[nodiscard]] aaplcad::core::ObjectId id() const noexcept {
        return id_;
    }

    [[nodiscard]] const std::string& layerName() const noexcept {
        return layerName_;
    }

    [[nodiscard]] virtual EntityKind kind() const noexcept {
        return EntityKind::unknown;
    }

    void assignId(aaplcad::core::ObjectId id) noexcept {
        id_ = id;
    }

    void setLayerName(std::string layerName) {
        layerName_ = std::move(layerName);
    }

private:
    aaplcad::core::ObjectId id_{};
    std::string layerName_ = "0";
};

}  // namespace aaplcad::database
