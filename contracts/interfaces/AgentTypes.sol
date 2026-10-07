// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Metadata structure for an AI Agent
struct AgentCard {
    string   name;
    string   description;
    string   version;
    string   endpoint;
    string[] capabilities;
    string   avatarURI;
    bytes    extra;
}

// User-supplied configuration for purchasing access to an agent
struct PassConfigParams {
    address tokenAddress;
    uint96  subscriptionFee;
    uint32  duration;
    uint64  maxRequests;
    bool    paused;
    string  metadataURI;
}

// Stored configuration. Field order intentionally packs the struct into two slots.
struct PassConfig {
    address tokenAddress;
    uint96  subscriptionFee;
    uint64  maxRequests;
    uint40  configuredAt;
    uint40  updatedAt;
    uint32  duration;
    bool    paused;
}
