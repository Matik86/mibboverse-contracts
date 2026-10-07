// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { PassConfig, PassConfigParams } from "./AgentTypes.sol";

interface IMibboPass {
    error Soulbound();
    error ZeroAddress();
    error InvalidFee();
    error InvalidRequests();
    error AgentNotConfigured(uint256 agentId);
    error Paused(uint256 agentId);
    error InvalidPassConfig(uint256 minDuration, uint256 maxDuration);
    error NoActivePass(address user, uint256 agentId);
    error NotAgentOwner(uint256 agentId, address caller);
    error NotRelayer(address caller);
    error ZeroRelayerAddress();
    error InvalidUsageBatchLength(
        uint256 agentIdsLength,
        uint256 usersLength,
        uint256 countsLength
    );

    event Locked(uint256 indexed tokenId);
    event PassPurchased(
        address indexed user,
        uint256 indexed agentId,
        uint256 expiresAt,
        uint256 fee
    );
    event PassExpired(address indexed user, uint256 indexed agentId, string reason);
    event RelayerUpdated(address indexed relayer, bool status);
    event ConfigURIUpdated(uint256 indexed agentId, uint32 indexed version, string newURI);
    event ConfigUpdated(uint256 indexed agentId, uint32 version, PassConfig cfg);
    event AgentPaused(uint256 indexed agentId, bool paused);

    function setConfig(uint256 agentId, PassConfigParams calldata cfg) external;

    function setPaused(uint256 agentId, bool paused) external;

    function purchasePass(uint256 agentId) external;

    function hasAccess(address user, uint256 agentId) external view returns (bool);

    /// @notice Returns the number of addresses whose ERC-1155 balance for an agent pass is non-zero.
    /// @dev This is a MibboPass extension: ERC-1155 itself does not enumerate token holders.
    function holderCount(uint256 agentId) external view returns (uint256);

    function recordUsage(uint256 agentId, address user, uint256 count) external;

    function batchRecordUsage(
        uint256[] calldata agentIds,
        address[] calldata users,
        uint256[] calldata counts
    ) external;

    function getCurrentConfig(uint256 agentId) external view returns (PassConfig memory);

    function getConfigURI(uint256 agentId, uint32 version) external view returns (string memory);
}
