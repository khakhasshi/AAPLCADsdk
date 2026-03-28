#pragma once

namespace aaplcad::database {

class Transaction {
public:
    Transaction() = default;

    void commit() noexcept {
        committed_ = true;
        active_ = false;
    }

    void rollback() noexcept {
        committed_ = false;
        active_ = false;
    }

    [[nodiscard]] bool isActive() const noexcept {
        return active_;
    }

    [[nodiscard]] bool isCommitted() const noexcept {
        return committed_;
    }

private:
    bool active_ = true;
    bool committed_ = false;
};

}  // namespace aaplcad::database
