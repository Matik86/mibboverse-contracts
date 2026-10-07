// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./interfaces/IERC8004Registry.sol";
import "./interfaces/IMibboTreasury.sol";

contract MibboTreasury is Ownable, IMibboTreasury, IERC721Receiver {
    IERC8004Registry public immutable erc8004;
    address public agentRegistry;

    modifier onlyRegistry() {
        if (msg.sender != agentRegistry) revert OnlyRegistry();
        _;
    }

    constructor(address _erc8004) Ownable(msg.sender) {
        if (_erc8004 == address(0)) revert ZeroAddress();
        erc8004 = IERC8004Registry(_erc8004);
    }

    // Sets the MibboRegistry address. Can only be called once by the owner.
    function setAgentRegistry(address _agentRegistry) external onlyOwner {
        if (_agentRegistry == address(0)) revert ZeroAddress();
        agentRegistry = _agentRegistry;
        emit AgentRegistrySet(_agentRegistry);
    }

    function initAgent(
        uint256 agentId,
        address userWallet,
        uint256 walletDeadline,
        bytes calldata walletSig
    ) external override onlyRegistry {
        if (erc8004.ownerOf(agentId) != address(this)) revert NFTNotInTreasury(agentId);
        erc8004.setAgentWallet(agentId, userWallet, walletDeadline, walletSig);
        emit AgentWalletSet(agentId, userWallet);
    }

    function updateMetadata(
        uint256 agentId,
        string calldata key,
        bytes calldata value
    ) external override onlyRegistry {
        erc8004.setMetadata(agentId, key, value);
        emit AgentMetadataSet(agentId, key);
    }

    function updateAgentURI(
        uint256 agentId,
        string calldata newURI
    ) external override onlyRegistry {
        erc8004.setAgentURI(agentId, newURI);
        emit AgentURIUpdated(agentId, newURI);
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external view override returns (bytes4)
    {
        if (msg.sender != address(erc8004)) revert UnauthorizedERC721Sender(msg.sender);
        return IERC721Receiver.onERC721Received.selector;
    }
}
