// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @notice Shared interface for ERC-8004 Identity Registry
interface IERC8004Registry {
    function register(string calldata agentURI) external returns (uint256 agentId);
    function setAgentWallet(uint256 agentId, address newWallet, uint256 deadline, bytes calldata walletSig) external;
    function setMetadata(uint256 agentId, string calldata key, bytes calldata value) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
    function getAgentWallet(uint256 agentId) external view returns (address);
    function setAgentURI(uint256 agentId, string calldata newURI) external;
}
