#pragma once

#include <cstdint>

namespace aaplcad::core {

class ObjectId {
public:
    constexpr ObjectId() = default;
    explicit constexpr ObjectId(std::uint64_t value) noexcept
        : value_(value) {
    }

    [[nodiscard]] constexpr std::uint64_t value() const noexcept {
        return value_;
    }

    [[nodiscard]] constexpr bool isValid() const noexcept {
        return value_ != 0;
    }

    friend constexpr bool operator==(ObjectId lhs, ObjectId rhs) noexcept {
        return lhs.value_ == rhs.value_;
    }

    friend constexpr bool operator!=(ObjectId lhs, ObjectId rhs) noexcept {
        return !(lhs == rhs);
    }

private:
    std::uint64_t value_ = 0;
};

}  // namespace aaplcad::core
