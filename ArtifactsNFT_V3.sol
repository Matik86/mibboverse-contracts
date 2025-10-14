// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Importing OpenZeppelin libraries for ERC1155 standard, ownership, and cryptographic utilities
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/token/ERC1155/ERC1155.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/utils/cryptography/ECDSA.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/utils/cryptography/draft-EIP712.sol";

/// @title ArtifactsERC1155
/// @notice Custom ERC1155 contract with signature-based minting, admin roles, and metadata management.
/// @dev Uses EIP-712 typed structured data hashing and signing for secure mint authorization.
contract ArtifactsERC1155 is ERC1155, Ownable, EIP712 {
    // Token collection details
    string public name = "Artifacts of the Mibboverse";
    string public symbol = "ATF";

    // Importing ECDSA library for signature recovery
    using ECDSA for bytes32;

    // Mapping for contract admins (set by the owner)
    mapping(address => bool) public admins;

    // Nonce tracking for each user to prevent replay attacks in signature-based minting
    mapping(address => uint256) public nonces;

    // Token metadata storage
    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => string) private _tokenNames;

    // Events for better tracking on-chain
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
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
    constructor() ERC1155("") EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) {}

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

    /// @notice Mint tokens with a signed permit (EIP-712 based authorization)
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

        // Prepare the mint request struct
        MintRequest memory request = MintRequest({
            to: to,
            id: id,
            amount: amount,
            nonce: nonce
        });

        // Hash the request using EIP-712 typed data encoding
        bytes32 structHash = keccak256(abi.encode(
            MINTREQUEST_TYPEHASH,
            request.to,
            request.id,
            request.amount,
            request.nonce
        ));

        // Final EIP-712 digest
        bytes32 hash = _hashTypedDataV4(structHash);

        // Recover the signer from the signature
        address signer = ECDSA.recover(hash, signature);

        // Only owner or admins can authorize minting
        require(signer == owner() || admins[signer], "Invalid signature");

        // Increment nonce to prevent replay
        nonces[to]++;

        // Mint the tokens
        _mint(to, id, amount, "");
    }
}
