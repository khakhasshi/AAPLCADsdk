#pragma once

#include "aaplcad/core/result.h"
#include "aaplcad/database/entity.h"
#include "aaplcad/database/layer.h"
#include "aaplcad/database/transaction.h"

#include <memory>
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace aaplcad::database {

class Document {
public:
    Document();

    [[nodiscard]] std::size_t entityCount() const noexcept;
    [[nodiscard]] std::size_t layerCount() const noexcept;

    aaplcad::core::Result<aaplcad::core::ObjectId> addLayer(const std::string& name);
    aaplcad::core::Result<aaplcad::core::ObjectId> addEntity(std::unique_ptr<Entity> entity);

    [[nodiscard]] const Layer* findLayer(const std::string& name) const noexcept;
    [[nodiscard]] const Entity* findEntity(aaplcad::core::ObjectId id) const noexcept;

    [[nodiscard]] Transaction beginTransaction() const noexcept;

private:
    std::vector<Layer> layers_;
    std::vector<std::unique_ptr<Entity>> entities_;
    std::uint64_t nextObjectId_ = 1;
};

}  // namespace aaplcad::database
