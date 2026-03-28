#pragma once

#include <string>
#include <utility>

namespace aaplcad::core {

struct Error {
    std::string code;
    std::string message;

    [[nodiscard]] bool empty() const noexcept {
        return code.empty() && message.empty();
    }

    static Error none() {
        return {};
    }
};

template <typename T>
class Result {
public:
    Result(T value)
        : value_(std::move(value)) {
    }

    Result(Error error)
        : error_(std::move(error)), hasValue_(false) {
    }

    [[nodiscard]] bool ok() const noexcept {
        return hasValue_;
    }

    [[nodiscard]] const T& value() const {
        return value_;
    }

    [[nodiscard]] T& value() {
        return value_;
    }

    [[nodiscard]] const Error& error() const noexcept {
        return error_;
    }

private:
    T value_{};
    Error error_{};
    bool hasValue_ = true;
};

template <>
class Result<void> {
public:
    Result() = default;

    Result(Error error)
        : error_(std::move(error)), hasValue_(false) {
    }

    [[nodiscard]] bool ok() const noexcept {
        return hasValue_;
    }

    [[nodiscard]] const Error& error() const noexcept {
        return error_;
    }

private:
    Error error_{};
    bool hasValue_ = true;
};

}  // namespace aaplcad::core
