#pragma once

#include "aaplcad/core/object_id.h"
#include "aaplcad/graphics/draw_list_2d.h"

#include <algorithm>
#include <optional>
#include <vector>

namespace aaplcad::graphics {

class SelectionState2d {
public:
    [[nodiscard]] bool hasSelection() const noexcept {
        return !selectedEntityIds_.empty();
    }

    [[nodiscard]] core::ObjectId selectedEntityId() const noexcept {
        return selectedEntityIds_.empty() ? core::ObjectId{} : selectedEntityIds_.front();
    }

    [[nodiscard]] std::size_t selectionCount() const noexcept {
        return selectedEntityIds_.size();
    }

    [[nodiscard]] const std::vector<core::ObjectId>& selectedEntityIds() const noexcept {
        return selectedEntityIds_;
    }

    void select(core::ObjectId entityId) noexcept {
        if (!entityId.isValid()) {
            clear();
            return;
        }

        selectedEntityIds_ = {entityId};
    }

    bool replaceWith(std::vector<core::ObjectId> entityIds) noexcept {
        entityIds.erase(std::remove_if(entityIds.begin(), entityIds.end(), [](core::ObjectId id) {
            return !id.isValid();
        }), entityIds.end());

        entityIds.erase(std::unique(entityIds.begin(), entityIds.end()), entityIds.end());

        const bool changed = entityIds != selectedEntityIds_;
        selectedEntityIds_ = std::move(entityIds);
        return changed;
    }

    void clear() noexcept {
        selectedEntityIds_.clear();
    }

    [[nodiscard]] bool isSelected(core::ObjectId entityId) const noexcept {
        return entityId.isValid() && std::find(selectedEntityIds_.begin(), selectedEntityIds_.end(), entityId) != selectedEntityIds_.end();
    }

    [[nodiscard]] bool applyHit(const std::optional<SelectionHit2d>& hit) noexcept {
        if (!hit.has_value()) {
            const bool changed = !selectedEntityIds_.empty();
            clear();
            return changed;
        }

        return replaceWith({hit->entityId});
    }

private:
    std::vector<core::ObjectId> selectedEntityIds_{};
};

}  // namespace aaplcad::graphics