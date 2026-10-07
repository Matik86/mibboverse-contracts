// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./interfaces/IERC8004Registry.sol";
import "./interfaces/IMibboTreasury.sol";
import "./interfaces/IMibboRegistry.sol";
import { AgentCard } from "./interfaces/AgentTypes.sol";

contract MibboRegistry is IMibboRegistry, IERC721Receiver {
    IERC8004Registry public immutable erc8004;
    IMibboTreasury public immutable agentTreasury;

    // Onchain record mapping an agentId to its beneficial owner
    struct AgentRecord {
        address beneficialOwner;
        uint256 createdAt;
        bool    exists;
    }

    uint256 public totalAgents;

    mapping(uint256 => AgentRecord) private _agents;
    mapping(address => uint256[]) private _ownerAgents;

    modifier agentExists(uint256 agentId) {
        if (!_agents[agentId].exists) revert AgentNotFound(agentId);
        _;
    }
    modifier onlyAgentOwner(uint256 agentId) {
        if (!_agents[agentId].exists) revert AgentNotFound(agentId);
        if (_agents[agentId].beneficialOwner != msg.sender) revert NotAgentOwner(agentId, msg.sender);
        _;
    }

    constructor(address _erc8004, address _treasury) {
        if (_erc8004 == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        erc8004 = IERC8004Registry(_erc8004);
        agentTreasury = IMibboTreasury(_treasury);
    }

    function registerAgent(
        AgentCard calldata card,
        uint256 walletDeadline,
        bytes calldata walletSig
    )
        external override returns (uint256 agentId)
    {
        agentId = erc8004.register(card.endpoint);
        erc8004.safeTransferFrom(address(this), address(agentTreasury), agentId);
        agentTreasury.initAgent(agentId, msg.sender, walletDeadline, walletSig);
        _agents[agentId] = AgentRecord({
            beneficialOwner: msg.sender,
            createdAt: block.timestamp,
            exists: true
        });

        _ownerAgents[msg.sender].push(agentId);

        totalAgents++;
        emit AgentRegistered(agentId, msg.sender);
    }

    function updateAgentMetadata(
        uint256 agentId,
        string calldata key,
        bytes calldata value
    )
        external override onlyAgentOwner(agentId)
    {
        agentTreasury.updateMetadata(agentId, key, value);
    }

    function updateAgentURI(
        uint256 agentId,
        string calldata newURI
    )
        external override onlyAgentOwner(agentId)
    {
        agentTreasury.updateAgentURI(agentId, newURI);
        emit AgentURIUpdated(agentId, newURI);
    }

    function getAgentOwner(uint256 agentId) external view override returns (address) {
        return _agents[agentId].beneficialOwner;
    }

    function getAgentInfo(uint256 agentId)
        external view override agentExists(agentId) returns (
            address beneficialOwner,
            address agentWallet,
            uint256 createdAt
        )
    {
        AgentRecord memory record = _agents[agentId];
        beneficialOwner = record.beneficialOwner;
        agentWallet = erc8004.getAgentWallet(agentId);
        createdAt = record.createdAt;
    }

    function getAgentsByOwner(address owner) external view override returns (uint256[] memory) {
        return _ownerAgents[owner];
    }

    function isOwner(uint256 agentId, address addr) external view override returns (bool) {
        return _agents[agentId].beneficialOwner == addr;
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external view override returns (bytes4)
    {
        if (msg.sender != address(erc8004)) revert UnauthorizedERC721Sender(msg.sender);
        return IERC721Receiver.onERC721Received.selector;
    }
}
