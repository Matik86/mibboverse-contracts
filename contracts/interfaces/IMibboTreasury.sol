// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IMibboTreasury {
    error OnlyRegistry();
    error ZeroAddress();
    error NFTNotInTreasury(uint256 agentId);
    error UnauthorizedERC721Sender(address sender);

    event AgentRegistrySet(address indexed agentRegistry);
    event AgentWalletSet(uint256 indexed agentId, address indexed wallet);
    event AgentMetadataSet(uint256 indexed agentId, string key);
    event AgentURIUpdated(uint256 indexed agentId, string newURI);


    function initAgent(
        uint256 agentId,
        address userWallet,
        uint256 walletDeadline,
        bytes calldata walletSig
    ) external;

    function updateMetadata(
        uint256 agentId,
        string calldata key,
        bytes calldata value
    ) external;

    function updateAgentURI(
        uint256 agentId,
        string calldata newURI
    ) external;

    function agentRegistry() external view returns (address);
}
