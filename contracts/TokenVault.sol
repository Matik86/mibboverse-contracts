// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @notice Importing OpenZeppelin libraries for ERC20 interface, ownership management, 
///         and cryptographic utilities (ECDSA and EIP-712) used for secure off-chain 
///         signature verification, access control, and token interactions.
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/**
 * @title TokenVault
 * @notice Vault contract for managing ERC20 tokens with admin-controlled deposits, claims via off-chain signatures, and owner withdrawals.
 *
 * @dev
 * Key features:
 *  - Admin system managed by owner for controlling claim permissions
 *  - EIP-712 signature-based token claims with nonces and optional deadlines to prevent replay attacks (`claim`)
 *  - Deposit functionality for allowed ERC20 tokens
 *  - Owner can withdraw tokens from the vault
 *  - Supports standard ERC20 token interactions via `transferFrom` and `transfer`
 *
 * Inherits from:
 *  - OpenZeppelin Ownable
 *  - OpenZeppelin EIP712
 *
 * Events:
 *  - AdminUpdated — admin added or removed
 *  - TokenAllowed — ERC20 token added or removed from allowed list
 *  - Deposited — user deposited tokens into the vault
 *  - Claimed — user claimed tokens using signed permit
 *  - Withdrawn — owner withdrew tokens from the vault
 *
 * Usage example:
 *  1. Owner adds an admin using `setAdmin`.
 *  2. Admins authorize claims off-chain using EIP-712 signed messages.
 *  3. Users deposit allowed ERC20 tokens using `deposit`.
 *  4. Users can claim tokens via `claim` with a valid signed message.
 *  5. Owner can withdraw tokens from the vault using `withdraw`.
 *
 * Author: Matik86 (Mibboverse)
 * Version: 1.0.0
 */

/// @title TokenVault
/// @notice Vault contract for managing allowed ERC20 tokens with admin-controlled deposits, off-chain signature-based claims, and owner withdrawals.
/// @dev Uses EIP-712 for secure signature-based claims and owner/admin system for managing allowed tokens.
contract TokenVault is Ownable, EIP712 {
    using ECDSA for bytes32;

    /// @notice Mapping of ERC20 tokens allowed in the vault
    mapping(address => bool) public allowedTokens;
    
    /// @notice Mapping of admin addresses
    mapping(address => bool) public admins;

    /// @notice Nonces for replay protection in EIP-712 claims
    mapping(address => uint256) public nonces;
    
    /// @notice Emitted when an admin is added or removed
    event AdminUpdated(address indexed admin, bool allowed);

    /// @notice Emitted when an ERC20 token is allowed or disallowed for deposits and claims
    event TokenAllowed(address indexed token, bool allowed);

    /// @notice Emitted when a user deposits ERC20 tokens into the vault
    event Deposited(address indexed user, address indexed token, uint256 amount);

    /// @notice Emitted when a user claims ERC20 tokens using a valid signature
    event Claimed(address indexed user, address indexed token, uint256 amount, address indexed signer);

    /// @notice Emitted when the owner withdraws ERC20 tokens from the vault
    event Withdrawn(address indexed token, address indexed to, uint256 amount);
    
    // EIP-712 typehash for signature-based claims
    bytes32 private constant CLAIM_TYPEHASH =
        keccak256("Claim(address to,address token,uint256 amount,uint256 nonce,uint256 deadline)");
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    /// @dev Sets deployer as initial owner and admin
    constructor() Ownable(msg.sender) EIP712("TokenVault", "1") {
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

    /// @notice Add or remove a token from the allowed list
    /// @param token Address of the ERC20 token
    /// @param allowed True to allow, false to disallow
    function setAllowedToken(address token, bool allowed) external onlyAdmin {
        allowedTokens[token] = allowed;
        emit TokenAllowed(token, allowed);
    }

    /// @notice Deposit allowed ERC20 tokens into the vault
    /// @param token Address of the ERC20 token
    /// @param amount Amount to deposit
    function deposit(address token, uint256 amount) external {
        require(allowedTokens[token], "Token not allowed");
        require(amount > 0, "Amount must be > 0");
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        emit Deposited(msg.sender, token, amount);
    }

    /// @notice Claim ERC20 tokens using a signed permit (EIP-712)
    /// @param token Address of the ERC20 token
    /// @param amount Amount to claim
    /// @param nonce User nonce for replay protection
    /// @param deadline Signature expiration timestamp (0 = no deadline)
    /// @param signature EIP-712 signature from admin or owner
    function claim(
        address token,
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external {
        require(allowedTokens[token], "Token not allowed");
        require(deadline == 0 || block.timestamp <= deadline, "Signature expired");
        require(nonces[msg.sender] == nonce, "Invalid nonce");

        bytes32 structHash = keccak256(
            abi.encode(
                CLAIM_TYPEHASH,
                msg.sender,
                token,
                amount,
                nonce,
                deadline
            )
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, signature);

        require(signer != address(0), "Invalid signature");
        require(admins[signer] || owner() == signer, "Signer not admin");

        nonces[msg.sender] += 1;

        IERC20(token).transfer(msg.sender, amount);

        emit Claimed(msg.sender, token, amount, signer);
    }

    /// @notice Withdraw ERC20 tokens from the vault
    /// @param token Address of the ERC20 token
    /// @param to Recipient address
    /// @param amount Amount to withdraw
    function withdraw(address token, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Zero address");
        IERC20(token).transfer(to, amount);
        emit Withdrawn(token, to, amount);
    }
}