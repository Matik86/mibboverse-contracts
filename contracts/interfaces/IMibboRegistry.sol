// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { AgentCard } from "./AgentTypes.sol";

interface IMibboRegistry {
    error ZeroAddress();
    error AgentNotFound(uint256 agentId);
    error NotAgentOwner(uint256 agentId, address caller);
    error IndexOutOfBounds(address owner, uint256 index);
    error UnauthorizedERC721Sender(address sender);

    event AgentRegistered(uint256 indexed agentId, address indexed beneficialOwner);
    event AgentURIUpdated(uint256 indexed agentId, string newURI);

    function registerAgent(
        AgentCard calldata card, uint256 walletDeadline, bytes calldata walletSig
    ) external returns (uint256 agentId);

    function updateAgentMetadata(
        uint256 agentId, string calldata key, bytes calldata value
    ) external;

    function updateAgentURI(uint256 agentId, string calldata newURI) external;

    function getAgentOwner(uint256 agentId) external view returns (address);

    function getAgentInfo(uint256 agentId) external view returns (
        address beneficialOwner,
        address agentWallet,
        uint256 createdAt
    );

    function getAgentsByOwner(address owner) external view returns (uint256[] memory);

    function isOwner(uint256 agentId, address addr) external view returns (bool);
}
