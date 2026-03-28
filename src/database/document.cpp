#include "aaplcad/database/document.h"

namespace aaplcad::database {

Document::Document() {
    layers_.emplace_back("0");
}

std::size_t Document::entityCount() const noexcept {
    return entities_.size();
}

std::size_t Document::layerCount() const noexcept {
    return layers_.size();
}

aaplcad::core::Result<aaplcad::core::ObjectId> Document::addLayer(const std::string& name) {
    if (name.empty()) {
        return aaplcad::core::Error{"E_LAYER_NAME", "layer name must not be empty"};
    }

    if (findLayer(name) != nullptr) {
        return aaplcad::core::Error{"E_LAYER_EXISTS", "layer already exists"};
    }

    layers_.emplace_back(name);
    return aaplcad::core::ObjectId{nextObjectId_++};
}

aaplcad::core::Result<aaplcad::core::ObjectId> Document::addEntity(std::unique_ptr<Entity> entity) {
    if (entity == nullptr) {
        return aaplcad::core::Error{"E_ENTITY_NULL", "entity must not be null"};
    }

    if (findLayer(entity->layerName()) == nullptr) {
        return aaplcad::core::Error{"E_LAYER_MISSING", "entity layer does not exist"};
    }

    const auto id = aaplcad::core::ObjectId{nextObjectId_++};
    entity->assignId(id);
    entities_.push_back(std::move(entity));
    return id;
}

const Layer* Document::findLayer(const std::string& name) const noexcept {
    for (const auto& layer : layers_) {
        if (layer.name() == name) {
            return &layer;
        }
    }

    return nullptr;
}

const Entity* Document::findEntity(aaplcad::core::ObjectId id) const noexcept {
    for (const auto& entity : entities_) {
        if (entity->id() == id) {
            return entity.get();
        }
    }

    return nullptr;
}

Transaction Document::beginTransaction() const noexcept {
    return Transaction{};
}

}  // namespace aaplcad::database
