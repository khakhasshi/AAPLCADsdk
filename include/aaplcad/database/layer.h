#pragma once

#include <string>
#include <utility>

namespace aaplcad::database {

class Layer {
public:
    Layer() = default;
    explicit Layer(std::string name)
        : name_(std::move(name)) {
    }

    [[nodiscard]] const std::string& name() const noexcept {
        return name_;
    }

private:
    std::string name_ = "0";
};

}  // namespace aaplcad::database
