# ⚡ EV Charging System — Smart Contract

![Solidity](https://img.shields.io/badge/Solidity-^0.8.x-blue)
![Status](https://img.shields.io/badge/status-learning--project-orange)
![License](https://img.shields.io/badge/license-GPL--3.0-green)

## 📖 Overview

This project implements a **smart contract in Solidity** that simulates a decentralized electric vehicle charging system.

Users can reserve a charging slot by paying upfront, and the contract autonomously manages:

* Charger allocation
* Usage time tracking
* Automatic release of resources

> 🧪 This is a **learning-focused project**, designed to explore Solidity patterns, optimization techniques, and system modeling on-chain.

---

## 🧩 Key Features

### 🔌 Charger Management

* Configurable number of chargers (up to 32)
* Efficient tracking using a **bitmask (`uint32`)**
* Automatic assignment of the first available charger

### ⏱️ Time-Based Billing

* Fixed price per time unit (wei/minute)
* Payment determines charging duration
* Enforced:

  * Minimum time
  * Maximum time

### 👤 User Tracking

Each user is associated with:

* A specific charger
* Start time
* End time

Efficient mappings allow quick lookup and updates.

### ⚡ Automatic Release Mechanism

* The system checks for expired sessions
* Frees chargers when time is over
* Reassigns availability dynamically

### 📡 Event Emission

```solidity
event ChargerStarted(address indexed user, uint256 time);
```

* Enables external systems (UI, IoT devices) to react in real time

### 🔐 Admin Control

* Admin defined at deployment
* Exclusive access to withdraw contract funds

---

## 🏗️ Architecture & Design Decisions

### 🧠 Bitmask Optimization

A `uint32` is used to represent charger states:

* `1` → occupied
* `0` → available

This approach:

* Minimizes storage usage
* Reduces gas costs
* Enables fast bitwise operations

### 📊 Efficient Allocation

* First available charger is computed via bit operations
* Minimal iteration → better performance

### 🧾 Lightweight Scheduling

* Tracks the user with the **minimum remaining time**
* Allows efficient cleanup without scanning all users

---

## 🚀 How It Works

1. User calls `startCharge()` and sends ETH
2. Contract:

   * Calculates allowed charging time
   * Frees expired chargers
   * Assigns an available charger
3. Emits `ChargerStarted` event
4. After time expires:

   * Charger becomes available again

---

## ⚠️ Limitations

This implementation is intentionally simplified and **not production-ready**:

* No automated tests
* Partial queue handling (not a full priority queue)
* No refund or cancellation mechanism
* Limited scalability beyond 32 chargers
* Basic security considerations

---

## 🔧 Future Improvements

* ✅ Full priority queue for users
* ✅ Unit testing (Hardhat / Foundry)
* ✅ Frontend (DApp)
* ✅ Event indexing improvements
* ✅ Advanced access control
* ✅ Security audit
* ✅ Gas optimizations

---

## 🛠️ Tech Stack

* **Solidity** ^0.8.x
* Ethereum Virtual Machine (EVM)

---

## 🎓 Learning Goals

This project explores:

* Smart contract state management
* Gas optimization techniques
* Bit-level operations in Solidity
* Mapping-based data structures
* Real-world system modeling on blockchain

---

## 👨‍💻 Author

**Luis Miguel CG**

---

## 📄 License

GPL-3.0
