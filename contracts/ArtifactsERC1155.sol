// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @notice Importing OpenZeppelin libraries for ERC1155 standard, ownership, and cryptographic utilities
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/**
 * @title ArtifactsERC1155
 * @notice Custom ERC1155 contract with admin-controlled roles, signature-based minting, and token metadata management.
 *
 * @dev
 * Key features:
 *  - Admin system managed by owner for controlling mint permissions
 *  - EIP-712 signature-based minting with nonces to prevent replay attacks (`mintWithPermit`)
 *  - Metadata management supporting custom names and URIs for each token
 *  - Burn functionality for token owners or approved operators
 *  - Standard ERC1155 multi-token functionality
 *
 * Inherits from:
 *  - OpenZeppelin ERC1155
 *  - OpenZeppelin Ownable
 *  - OpenZeppelin EIP712
 *
 * Events:
 *  - AdminAdded / AdminRemoved — admin management
 *  - TokenMetadataUpdated — updates token name and URI
 *  - Minted — (implicitly via mintWithPermit) token minted to an address
 *
 * Usage example:
 *  1. Owner adds an admin using `setAdmin`.
 *  2. Admin or owner signs an off-chain minting authorization using EIP-712.
 *  3. User calls `mintWithPermit` with the signed message.
 *  4. Contract verifies signature, nonce, and mints the requested token(s).
 *  5. Owner can set or update token metadata using `setTokenMetadata`.
 *  6. Tokens can be burned by their owners or approved operators.
 *
 * Author: <Your Name or Team>
 * Version: 1.0.0
 */

/// @title ArtifactsERC1155
/// @notice Custom ERC1155 contract with signature-based minting, admin roles, and metadata management.
/// @dev Uses EIP-712 typed structured data hashing and signing for secure mint authorization.
contract ArtifactsERC1155 is ERC1155, Ownable, EIP712 {
    // Token collection details
    string public name = "Artifacts of the Mibboverse";
    string public symbol = "ATF";

    // Importing ECDSA library for signature recovery
    using ECDSA for bytes32;
    
    /// @notice Mapping for contract admins (set by the owner)
    mapping(address => bool) public admins;

    /// @notice Nonce tracking for each user to prevent replay attacks in signature-based minting
    mapping(address => uint256) public nonces;
    
    /// @notice Token metadata storage
    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => string) private _tokenNames;
    
    /// @notice Emitted when a new admin is added
    event AdminAdded(address indexed admin);

    /// @notice Emitted when an existing admin is removed
    event AdminRemoved(address indexed admin);

    /// @notice Emitted when token metadata is updated
    event TokenMetadataUpdated(uint256 indexed tokenId, string name, string uri);
    
    // EIP-712 domain and version identifiers
    string private constant SIGNING_DOMAIN = "AdminMintableERC1155";
    string private constant SIGNATURE_VERSION = "1";
    
    // Struct used for signature-based minting requests
    struct MintRequest {
        address to;      // Recipient address
        uint256 id;      // Token ID
        uint256 amount;  // Amount to mint
        uint256 nonce;   // Unique nonce per recipient
    }
    
    // Typehash for MintRequest struct, used in EIP-712 encoding
    bytes32 private constant MINTREQUEST_TYPEHASH = keccak256(
        "MintRequest(address to,uint256 id,uint256 amount,uint256 nonce)"
    );
    
    /// @notice Contract constructor initializes ERC1155 and EIP712
    constructor() ERC1155("") EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) Ownable(msg.sender) {}
    
    /// @notice Set or revoke admin privileges
    /// @param admin Address to set as admin
    /// @param allowed Boolean flag (true = add admin, false = remove admin)
    function setAdmin(address admin, bool allowed) external onlyOwner {
        admins[admin] = allowed;
        if (allowed) {
            emit AdminAdded(admin);
        } else {
            emit AdminRemoved(admin);
        }
    }
    
    /// @notice Update token metadata (name and URI)
    /// @param tokenId ID of the token
    /// @param name_ Human-readable token name
    /// @param uri_ Token URI (metadata location, usually IPFS or HTTPS)
    function setTokenMetadata(
        uint256 tokenId,
        string memory name_,
        string memory uri_
    ) external onlyOwner {
        _tokenNames[tokenId] = name_;
        _tokenURIs[tokenId] = uri_;
        emit TokenMetadataUpdated(tokenId, name_, uri_);
    }
    
    /// @notice Returns token URI
    /// @param tokenId ID of the token
    function uri(uint256 tokenId) public view override returns (string memory) {
        return _tokenURIs[tokenId];
    }
    
    /// @notice Returns token name
    /// @param tokenId ID of the token
    function token_name(uint256 tokenId) public view returns (string memory) {
        return _tokenNames[tokenId];
    }
    
    /// @notice Burn a specific amount of a token
    /// @dev Caller must be token owner or approved operator
    function burn(address account, uint256 id, uint256 amount) external {
    require(
        account == msg.sender || isApprovedForAll(account, msg.sender),
        "Caller is not owner nor approved"
    );
    _burn(account, id, amount);
    }
 
    // @notice Mint tokens with a signed permit (EIP-712 based authorization)
    /// @dev Prevents replay attacks using nonces
    /// @param to Recipient address
    /// @param id Token ID
    /// @param amount Amount of tokens to mint
    /// @param nonce Nonce for replay protection
    /// @param signature Off-chain signature by owner or admin
    function mintWithPermit(
        address to,               
        uint256 id,               
        uint256 amount,           
        uint256 nonce,            
        bytes memory signature    
    ) external {
        require(to != address(0), "Invalid address");
        require(nonce == nonces[to], "Invalid nonce");
        require(amount > 0, "Amount must be > 0");

        MintRequest memory request = MintRequest({
            to: to,
            id: id,
            amount: amount,
            nonce: nonce
        });

        bytes32 structHash = keccak256(abi.encode(
            MINTREQUEST_TYPEHASH,
            request.to,
            request.id,
            request.amount,
            request.nonce
        ));

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSA.recover(hash, signature);
        require(signer == owner() || admins[signer], "Invalid signature");

        nonces[to]++;

        _mint(to, id, amount, "");
    }
}