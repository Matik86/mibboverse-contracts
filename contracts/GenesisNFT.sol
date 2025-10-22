// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @notice Importing OpenZeppelin libraries for ERC721 functionality, ownership control, string utilities, 
///         and cryptographic tools (ECDSA and EIP-712) used for signature-based minting and metadata handling
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/**
 * @title GenesisNFT
 * @notice ERC721 NFT contract with capped supply (max 333 tokens), supporting EIP-712 signature-based minting 
 *         by the owner or authorized admins.
 *
 * @dev
 * Key features:
 *  - Maximum total supply: 333 tokens
 *  - One-time mint per address
 *  - Minting via EIP-712 signature (`mintWithPermit`) signed by owner or admins
 *  - Metadata modes:
 *      1. Hidden metadata (`hiddenURI`)
 *      2. Single metadata file for all tokens (`singleMetadataMode = true`)
 *      3. Per-token metadata (`baseURI` or `_customTokenURIs`)
 *  - Admin system managed by owner
 *  - Manual reveal toggle (`revealed`)
 *  - Burn functionality for token owners
 *
 * Inherits from:
 *  - OpenZeppelin ERC721
 *  - OpenZeppelin Ownable
 *  - OpenZeppelin EIP712
 *
 * Events:
 *  - AdminAdded / AdminRemoved — admin management
 *  - HiddenURIChanged / RevealedURIChanged / BaseURIChanged — metadata updates
 *  - RevealedChanged / CollectionNameUpdated — collection state updates
 *  - CustomURIChanged — per-token metadata assignment
 *  - Minted — token successfully minted
 *  - MaxSupplyReached — maximum supply reached
 *
 * Usage example:
 *  1. Owner or admin signs a mint authorization off-chain using EIP-712.
 *  2. User calls `mintWithPermit` with the signed message.
 *  3. Contract verifies signature, nonce, and mint status.
 *  4. If valid, a new token is minted and assigned to the user.
 *
 * Author: Matik86 (Mibboverse)
 * Version: 1.0.0
 */

/// @title GenesisNFT
/// @notice ERC721 collection with capped supply, EIP-712 signature-based minting, admin control, and revealable metadata.
/// @dev Implements one-time minting per address and secure off-chain authorization via EIP-712.
contract GenesisNFT is ERC721, Ownable, EIP712 {
    using Strings for uint256;
    using ECDSA for bytes32;

    /// @notice Mapping of admin addresses with mint authorization rights
    mapping(address => bool) public admins;

    /// @notice Nonce tracking for each address to prevent replay attacks
    mapping(address => uint256) public nonces;

    /// @notice Mapping to ensure each address can mint only once
    mapping(address => bool) public hasMinted;

    /// @notice Counter for minted tokens
    uint256 private _tokenCounter;

    /// @notice Maximum total supply of the collection
    uint256 public constant MAX_SUPPLY = 333;

    /// @notice Human-readable name of the NFT collection
    string public collectionName;
    
    /// @notice URI for hidden (unrevealed) metadata
    string public hiddenURI;

    /// @notice URI for revealed metadata (used when singleMetadataMode is true)
    string public revealedURI;

    /// @notice Base URI for token-specific metadata
    string public baseURI;
    
    /// @notice Whether the collection has been revealed
    bool public revealed;
    
    /// @notice Metadata mode flag: true = single metadata file, false = per-token metadata
    bool public singleMetadataMode;
    
    /// @notice Optional custom metadata URIs for specific tokens
    mapping(uint256 => string) private _customTokenURIs;

    /// @notice Emitted when a new admin is added
    event AdminAdded(address indexed admin);

    /// @notice Emitted when an admin is removed
    event AdminRemoved(address indexed admin);

    /// @notice Emitted when the collection name is updated
    event CollectionNameUpdated(string name);

    /// @notice Emitted when the hidden metadata URI is updated
    event HiddenURIChanged(string hiddenURI);

    /// @notice Emitted when the revealed metadata URI is updated
    event RevealedURIChanged(string revealedURI);

    /// @notice Emitted when the revealed state is toggled
    event RevealedChanged(bool revealed);

    /// @notice Emitted when the base URI is updated
    event BaseURIChanged(string baseURI);

    /// @notice Emitted when a custom token URI is assigned
    event CustomURIChanged(uint256 indexed tokenId, string uri);

    /// @notice Emitted when a token is minted
    event Minted(address indexed to, uint256 indexed tokenId);

    /// @notice Emitted when the maximum supply is reached
    event MaxSupplyReached();

    /// @dev EIP-712 domain and version identifiers
    string private constant SIGNING_DOMAIN = "AdminMintableERC721";
    string private constant SIGNATURE_VERSION = "1";

    /// @notice Struct representing an authorized mint request
    struct MintRequest {
        address to;
        uint256 nonce;
    }
    
    /// @dev Typehash for MintRequest struct, used in EIP-712 encoding
    bytes32 private constant MINTREQUEST_TYPEHASH =
        keccak256("MintRequest(address to,uint256 nonce)");
    
    /// @notice Contract constructor initializing ERC721, EIP-712, and collection details
    /// @param name_ ERC721 token name
    /// @param symbol_ ERC721 token symbol
    /// @param collectionName_ Human-readable name for the NFT collection
    /// @param _hiddenURI Metadata URI for hidden state
    constructor(
        string memory name_,
        string memory symbol_,
        string memory collectionName_,
        string memory _hiddenURI
    ) ERC721(name_, symbol_) 
    EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) 
    Ownable(msg.sender) 
    {
        collectionName = collectionName_;
        hiddenURI = _hiddenURI;
        revealed = false;
        singleMetadataMode = true;
    }

    /// @notice Returns the metadata URI for a given token
    /// @param tokenId ID of the token to query
    /// @return The metadata URI depending on reveal state and mode
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");

        if (!revealed) {
            return hiddenURI;
        }

        if (singleMetadataMode) {
            return revealedURI;
        }

        if (bytes(_customTokenURIs[tokenId]).length > 0) {
            return _customTokenURIs[tokenId];
        }

        return string(abi.encodePacked(baseURI, tokenId.toString(), ".json"));
    }
    
    /// @notice Returns the collection name
    /// @return Collection name string
    function token_name(uint256) public view returns (string memory) {
        return collectionName;
    }

    /// @notice Updates the hidden metadata URI
    /// @param _hiddenURI New hidden URI
    function setHiddenURI(string memory _hiddenURI) external onlyOwner {
        hiddenURI = _hiddenURI;
        emit HiddenURIChanged(_hiddenURI);
    }
    
    /// @notice Updates the revealed metadata URI
    /// @param _revealedURI New revealed URI
    function setRevealedURI(string memory _revealedURI) external onlyOwner {
        revealedURI = _revealedURI;
        emit RevealedURIChanged(_revealedURI);
    }
    
    /// @notice Updates the base URI for per-token metadata
    /// @param _baseURI New base URI string
    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
        emit BaseURIChanged(_baseURI);
    }
    
    /// @notice Assigns a custom URI to a specific token
    /// @param tokenId ID of the token
    /// @param uri Custom URI string
    function setCustomTokenURI(uint256 tokenId, string memory uri) external onlyOwner {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        _customTokenURIs[tokenId] = uri;
        emit CustomURIChanged(tokenId, uri);
    }
   
    /// @notice Sets the reveal state of the collection
    /// @param _state Boolean indicating reveal state (true = revealed)
    function setRevealed(bool _state) external onlyOwner {
        revealed = _state;
        emit RevealedChanged(_state);
    }
    
    /// @notice Sets whether metadata is single or per-token
    /// @param _state Boolean flag (true = single metadata)
    function setSingleMetadataMode(bool _state) external onlyOwner {
        singleMetadataMode = _state;
    }
   
    /// @notice Updates the human-readable collection name
    /// @param name_ New name string
    function setCollectionName(string memory name_) external onlyOwner {
        collectionName = name_;
        emit CollectionNameUpdated(name_);
    }

    /// @notice Adds or removes an admin authorized to sign minting requests
    /// @param admin Address of the admin
    /// @param allowed Boolean flag (true = add, false = remove)
    function setAdmin(address admin, bool allowed) external onlyOwner {
        admins[admin] = allowed;
        if (allowed) emit AdminAdded(admin);
        else emit AdminRemoved(admin);
    }

    /// @notice Mints a new NFT using an authorized signature (EIP-712)
    /// @dev Each address can mint only once; verifies signature from owner or admin
    /// @param to Recipient address
    /// @param nonce Expected nonce (must match stored value)
    /// @param signature Signed authorization message
    function mintWithPermit(
        address to,
        uint256 nonce,
        bytes memory signature
    ) external {
        require(to != address(0), "Invalid address");
        require(nonce == nonces[to], "Invalid nonce");
        require(!hasMinted[to], "Address already minted");
        require(nonces[to] == 0, "Nonce already used");
        require(_tokenCounter < MAX_SUPPLY, "Max supply reached");

        MintRequest memory request = MintRequest({to: to, nonce: nonce});

        bytes32 structHash = keccak256(
            abi.encode(MINTREQUEST_TYPEHASH, request.to, request.nonce)
        );

        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, signature);
        require(signer == owner() || admins[signer], "Invalid signature");

        nonces[to]++;

        // Mark as minted (one-time)
        hasMinted[to] = true;

        _tokenCounter++;
        _mint(to, _tokenCounter);

        emit Minted(to, _tokenCounter);

        if (_tokenCounter == MAX_SUPPLY) {
            emit MaxSupplyReached();
        }
    }

    /// @notice Burns an existing token
    /// @dev Caller must be token owner or approved operator
    /// @param tokenId ID of the token to burn
    function burn(uint256 tokenId) external {
        require(
            ownerOf(tokenId) == msg.sender || isApprovedForAll(ownerOf(tokenId), msg.sender),
            "Caller is not owner nor approved"
        );
        _burn(tokenId);
    }

    /// @notice Returns the total number of minted tokens
    /// @return Current total supply of NFTs
    function totalSupply() external view returns (uint256) {
        return _tokenCounter;
    }
}