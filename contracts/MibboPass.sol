// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IMibboRegistry.sol";
import "./interfaces/IMibboPass.sol";
import { PassConfig, PassConfigParams } from "./interfaces/AgentTypes.sol";

contract MibboPass is ERC1155, Ownable, IMibboPass {
    using SafeERC20 for IERC20;

    uint32 public constant MIN_DURATION = 1 days;
    uint32 public constant MAX_DURATION = 365 days;

    IMibboRegistry public immutable registry;

    string public name = "Mibboverse Agent Pass";
    string public symbol = "PASS";

    // Packed into one storage slot (25 bytes).
    struct UserPassState {
        uint64 maxRequests;
        uint64 requestsUsed;
        uint40 expiresAt;
        uint32 configVersion;
    }

    mapping(address => bool) public isRelayer;
    mapping(uint256 => mapping(address => UserPassState)) private _passMeta;
    mapping(address => uint256[]) private _userPasses;
    mapping(address => mapping(uint256 => bool)) private _hasPassRecord;
    // ERC-1155 has no holder enumeration. Track only zero/non-zero balance crossings
    // so this remains the number of unique current holders, not total token supply.
    mapping(uint256 => uint256) private _holderCounts;
    mapping(uint256 => mapping(uint32 => string)) private _configURIs;
    mapping(uint256 => uint32) public currentVersion;
    mapping(uint256 => mapping(uint32 => PassConfig)) private _configHistory;

    modifier onlyRelayer() {
        if (!isRelayer[msg.sender]) revert NotRelayer(msg.sender);
        _;
    }

    modifier onlyAgentOwner(uint256 agentId) {
        if (!registry.isOwner(agentId, msg.sender)) revert NotAgentOwner(agentId, msg.sender);
        _;
    }

    constructor(address _registry, address _relayer)
        ERC1155("")
        Ownable(msg.sender)
    {
        if (_registry == address(0)) revert ZeroAddress();
        registry = IMibboRegistry(_registry);
        if (_relayer != address(0)) {
            isRelayer[_relayer] = true;
        }
    }

    function setRelayer(address relayer, bool status) external onlyOwner {
        if (relayer == address(0)) revert ZeroRelayerAddress();
        isRelayer[relayer] = status;
        emit RelayerUpdated(relayer, status);
    }

    function setConfig(uint256 agentId, PassConfigParams calldata cfg)
        external override onlyAgentOwner(agentId)
    {
        if (cfg.tokenAddress == address(0)) revert ZeroAddress();
        if (cfg.subscriptionFee == 0) revert InvalidFee();
        if (cfg.maxRequests == 0) revert InvalidRequests();
        if (cfg.duration < MIN_DURATION || cfg.duration > MAX_DURATION) {
            revert InvalidPassConfig(MIN_DURATION, MAX_DURATION);
        }

        uint32 v = ++currentVersion[agentId];
        uint40 timestamp = uint40(block.timestamp);
        PassConfig memory storedConfig = PassConfig({
            tokenAddress: cfg.tokenAddress,
            subscriptionFee: cfg.subscriptionFee,
            maxRequests: cfg.maxRequests,
            configuredAt: timestamp,
            updatedAt: timestamp,
            duration: cfg.duration,
            paused: cfg.paused
        });
        _configHistory[agentId][v] = storedConfig;
        _configURIs[agentId][v] = cfg.metadataURI;
        emit ConfigUpdated(agentId, v, storedConfig);
        emit ConfigURIUpdated(agentId, v, cfg.metadataURI);
    }

    function setPaused(uint256 agentId, bool paused)
        external override onlyAgentOwner(agentId)
    {
        if (currentVersion[agentId] == 0) revert AgentNotConfigured(agentId);
        PassConfig storage cfg = _configHistory[agentId][currentVersion[agentId]];
        cfg.paused = paused;
        cfg.updatedAt = uint40(block.timestamp);
        emit AgentPaused(agentId, paused);
    }

    function purchasePass(uint256 agentId) external override {
        uint32 configV = currentVersion[agentId];
        if (configV == 0) revert AgentNotConfigured(agentId);

        PassConfig memory cfg = _configHistory[agentId][configV];
        if (cfg.paused) revert Paused(agentId);

        if (balanceOf(msg.sender, agentId) > 0) {
            _burn(msg.sender, agentId, 1);
            delete _passMeta[agentId][msg.sender];
        }

        IERC20 token = IERC20(cfg.tokenAddress);
        token.safeTransferFrom(msg.sender, registry.getAgentOwner(agentId), cfg.subscriptionFee);

        _mint(msg.sender, agentId, 1, "");
        uint40 expiresAt = uint40(block.timestamp + cfg.duration);
        _passMeta[agentId][msg.sender] = UserPassState({
            maxRequests: cfg.maxRequests,
            requestsUsed: 0,
            expiresAt: expiresAt,
            configVersion: configV
        });

        if (!_hasPassRecord[msg.sender][agentId]) {
            _userPasses[msg.sender].push(agentId);
            _hasPassRecord[msg.sender][agentId] = true;
        }

        emit Locked(agentId);
        emit PassPurchased(msg.sender, agentId, expiresAt, cfg.subscriptionFee);
    }

    function hasAccess(address user, uint256 agentId) public view override returns (bool) {
        uint32 configV = currentVersion[agentId];
        if (configV > 0 && _configHistory[agentId][configV].paused) return false;
        if (balanceOf(user, agentId) == 0) return false;

        UserPassState memory meta = _passMeta[agentId][user];

        return block.timestamp < meta.expiresAt &&
               meta.requestsUsed < meta.maxRequests;
    }

    function holderCount(uint256 agentId) external view override returns (uint256) {
        return _holderCounts[agentId];
    }

    function recordUsage(uint256 agentId, address user, uint256 count)
        external override onlyRelayer
    {
        _recordUsage(agentId, user, count);
    }

    function batchRecordUsage(
        uint256[] calldata agentIds,
        address[] calldata users,
        uint256[] calldata counts
    ) external override onlyRelayer {
        uint256 length = agentIds.length;
        if (length == 0 || users.length != length || counts.length != length) {
            revert InvalidUsageBatchLength(length, users.length, counts.length);
        }

        // Keep batch semantics identical to recordUsage. A failure in any item
        // reverts the whole transaction, so the backend never records a partial batch.
        for (uint256 i = 0; i < length; ++i) {
            _recordUsage(agentIds[i], users[i], counts[i]);
        }
    }

    function _recordUsage(uint256 agentId, address user, uint256 count) internal {
        if (!hasAccess(user, agentId)) revert NoActivePass(user, agentId);

        UserPassState storage meta = _passMeta[agentId][user];
        uint256 updatedRequests = uint256(meta.requestsUsed) + count;

        if (updatedRequests >= meta.maxRequests) {
            meta.requestsUsed = meta.maxRequests;
            emit PassExpired(user, agentId, "requests_limit");
        } else {
            meta.requestsUsed = uint64(updatedRequests);
        }
    }

    function getCurrentConfig(uint256 agentId) external view override returns (PassConfig memory) {
        return _configHistory[agentId][currentVersion[agentId]];
    }

    function getConfig(uint256 agentId, uint32 version) external view returns (PassConfig memory) {
        return _configHistory[agentId][version];
    }

    function getConfigURI(uint256 agentId, uint32 version)
        external view override returns (string memory)
    {
        return _configURIs[agentId][version];
    }

    function getPassStatus(address user, uint256 agentId)
        external view
        returns (
            bool    active,
            uint256 expiresAt,
            uint256 timeLeft,
            uint256 requestsUsed,
            uint256 maxRequests,
            uint256 configVersion
        )
    {
        UserPassState memory meta = _passMeta[agentId][user];
        active = hasAccess(user, agentId);
        expiresAt = meta.expiresAt;
        timeLeft = meta.expiresAt > block.timestamp ? meta.expiresAt - block.timestamp : 0;
        requestsUsed = meta.requestsUsed;
        maxRequests = meta.maxRequests;
        configVersion = meta.configVersion;
    }

    function getUserPasses(address user) external view returns (uint256[] memory) {
        return _userPasses[user];
    }

    function getActivePasses(address user) external view returns (uint256[] memory) {
        uint256[] memory all = _userPasses[user];
        uint256[] memory temp = new uint256[](all.length);
        uint256 count = 0;

        for (uint256 i = 0; i < all.length; i++) {
            if (hasAccess(user, all[i])) temp[count++] = all[i];
        }

        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) result[i] = temp[i];
        return result;
    }

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override {
        if (from != address(0) && to != address(0)) revert Soulbound();

        // MibboPass only mints and burns one ID at a time. Update before ERC-1155
        // mutates balances, allowing us to detect whether an address enters or leaves
        // the holder set for that ID.
        for (uint256 i = 0; i < ids.length; ++i) {
            if (values[i] == 0) continue;

            if (from == address(0) && balanceOf(to, ids[i]) == 0) {
                ++_holderCounts[ids[i]];
            } else if (to == address(0) && balanceOf(from, ids[i]) == values[i]) {
                --_holderCounts[ids[i]];
            }
        }
        super._update(from, to, ids, values);
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return _configURIs[tokenId][currentVersion[tokenId]];
    }

    function supportsInterface(bytes4 interfaceId)
        public view override(ERC1155)
        returns (bool)
    {
        return super.supportsInterface(interfaceId)
            || interfaceId == type(IMibboPass).interfaceId;
    }
}
