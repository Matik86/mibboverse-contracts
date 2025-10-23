// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @notice Importing OpenZeppelin Upgradeable libraries
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

/**
 * @title CrystalsV2
 * @notice Upgradeable ERC20 token with admin-controlled minting, off-chain EIP-712 signature minting, 
 *         contract whitelist, and UUPS upgradeability.
 *
 * @dev
 * Key features:
 *  - Upgradeable via UUPS proxy pattern
 *  - Admin-controlled minting and burning
 *  - Signature-based minting via EIP-712 with nonces and optional deadlines to prevent replay
 *  - Contract whitelist restricting interactions via approve/transferFrom
 *  - Owner can manage admins and whitelisted contracts
 *  - Supports standard ERC20 functionality
 *
 * Inherits from:
 *  - OpenZeppelin ERC20Upgradeable
 *  - OpenZeppelin OwnableUpgradeable
 *  - OpenZeppelin EIP712Upgradeable
 *  - OpenZeppelin UUPSUpgradeable
 *
 * Events:
 *  - AdminUpdated — admin added or removed
 *  - ContractWhitelisted — contract added/removed from whitelist
 *  - AdminMint / AdminBurn — tokens minted/burned by admins
 *  - MintWithSignature — tokens minted via signed permit
 *
 * Usage example:
 *  1. Owner deploys contract via UUPS proxy and calls `initialize`.
 *  2. Owner or admin can mint tokens directly to any address using `mint`.
 *  3. Users can mint via `mintWithSignature` if they have an off-chain signed authorization.
 *  4. Admins or owner can burn tokens from any account using `adminBurnFrom`.
 *  5. Only whitelisted contracts can call `approve` or `transferFrom` if sender is a contract.
 *
 * Author: Matik86 (Mibboverse)
 * Version: 2.0.0
 */

/// @title CrystalsV2
/// @notice Upgradeable ERC20 token with admin-controlled minting, signature-based minting, and contract whitelist.
/// @dev Implements UUPS proxy pattern for upgradeability. Uses EIP-712 for off-chain signed mint approvals.
contract CrystalsV2 is ERC20Upgradeable, OwnableUpgradeable, EIP712Upgradeable, UUPSUpgradeable {
    using ECDSAUpgradeable for bytes32;
    
    /// @notice Whitelisted contracts that are allowed to interact with approve/transferFrom
    mapping(address => bool) public contractWhitelist;

    /// @notice Mapping of admin addresses (besides the owner)
    mapping(address => bool) public admins;

    /// @notice Nonces for replay protection in signature-based minting
    mapping(address => uint256) public nonces;
    
    /// @notice Emitted when a contract is added or removed from the whitelist
    event ContractWhitelisted(address indexed contractAddress, bool allowed);

    /// @notice Emitted when an admin is added or removed
    event AdminUpdated(address indexed admin, bool allowed);

    /// @notice Emitted when an admin mints tokens directly
    event AdminMint(address indexed to, uint256 amount);

    /// @notice Emitted when an admin burns tokens from an account
    event AdminBurn(address indexed from, uint256 amount);

    /// @notice Emitted when tokens are minted via an off-chain signature (EIP-712)
    event MintWithSignature(address indexed to, uint256 amount, address indexed signer);
    
    // EIP-712 typehash for signature-based minting
    bytes32 private constant MINT_TYPEHASH =
        keccak256("Mint(address to,uint256 amount,uint256 nonce,uint256 deadline)");

    /// @custom:oz-upgrades-unsafe-allow constructor
    /// @dev Required for upgradeable contracts. Prevents logic execution outside of proxy.
    constructor() initializer {}
    
    /// @notice Initializes the token (called only once)
    /// @param name_ ERC20 token name
    /// @param symbol_ ERC20 token symbol
    function initialize(string memory name_, string memory symbol_) public initializer {
        __ERC20_init(name_, symbol_);
        __Ownable_init();
        __EIP712_init(name_, "1");
        __UUPSUpgradeable_init();
       
       // The deployer is set as an initial admin
        admins[msg.sender] = true;
        emit AdminUpdated(msg.sender, true);
    }
    
    /// @dev Restricts access to only admins or owner
    modifier onlyAdmin() {
        require(admins[msg.sender] || owner() == msg.sender, "Not admin");
        _;
    }
    
    /// @notice Add or remove an admin
    /// @param admin Address to grant/revoke admin rights
    /// @param allowed True to add, false to remove
    function setAdmin(address admin, bool allowed) external onlyOwner {
        admins[admin] = allowed;
        emit AdminUpdated(admin, allowed);
    }
    
    /// @notice Add or remove contract from whitelist
    /// @param contractAddr Address of the contract
    /// @param allowed True to whitelist, false to blacklist
    function setContractWhitelist(address contractAddr, bool allowed) external onlyAdmin {
        require(contractAddr != address(0), "Zero address");
        contractWhitelist[contractAddr] = allowed;
        emit ContractWhitelisted(contractAddr, allowed);
    }
    
    /// @notice Mint tokens (admin-only)
    /// @param to Recipient address
    /// @param amount Amount of tokens to mint
    function mint(address to, uint256 amount) external onlyAdmin {
        require(to != address(0), "Mint to zero address");
        _mint(to, amount);
        emit AdminMint(to, amount);
    }
    
    /// @notice Mint tokens using an off-chain signature (EIP-712)
    /// @dev Prevents replay attacks using nonces and deadline
    /// @param amount Amount of tokens to mint
    /// @param nonce Unique nonce of the sender
    /// @param deadline Expiration timestamp (0 = no deadline)
    /// @param signature Off-chain signature from admin/owner
    function mintWithSignature(
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external {
        address to = msg.sender;
        require(to != address(0), "Zero address");
        
        // Check deadline validity
        require(deadline == 0 || block.timestamp <= deadline, "Signature expired");
        // Validate nonce
        require(nonces[to] == nonce, "Invalid nonce");
        
        // Create the struct hash for EIP-712
        bytes32 structHash = keccak256(abi.encode(
            MINT_TYPEHASH,
            to,
            amount,
            nonce,
            deadline
        ));
        // Final EIP-712 digest
        bytes32 hash = _hashTypedDataV4(structHash);

        // Recover signer from signature
        address signer = ECDSAUpgradeable.recover(hash, signature);
        require(signer != address(0), "Invalid signature");
        require(admins[signer] || owner() == signer, "Signer not admin");
        
        // Increment nonce to prevent replay
        nonces[to] += 1;
        // Mint tokens
        _mint(to, amount);
        emit MintWithSignature(to, amount, signer);
    } 
    
    /// @notice Burn tokens from caller's balance
    /// @param amount Amount of tokens to burn
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
    
    /// @notice Admin burns tokens from any account
    /// @param account Target account
    /// @param amount Amount of tokens to burn
    function adminBurnFrom(address account, uint256 amount) external onlyAdmin {
        _burn(account, amount);
        emit AdminBurn(account, amount);
    }

    /// @notice Check if an address is a contract
    /// @param addr Address to check
    /// @return True if the address is a contract
    function isContract(address addr) public view returns (bool) {
        return addr.code.length > 0;
    }
    
    /// @notice Override approve to restrict non-whitelisted contracts
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        if (isContract(msg.sender)) {
            require(contractWhitelist[msg.sender], "approve: contract not allowed");
        }
        return super.approve(spender, amount);
    }
    
    /// @notice Override transferFrom to restrict non-whitelisted contracts
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        if (isContract(msg.sender)) {
            require(contractWhitelist[msg.sender], "transferFrom: contract not allowed");
        }
        return super.transferFrom(from, to, amount);
    }
    
    /// @dev Authorization for upgrades (only owner can upgrade implementation)
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
