// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title Artifacts of the Mibboverse (ATF)
 * @notice Custom ERC1155 token with signature-based minting (EIP-712), admin roles, and metadata management.
 * @dev Built using OpenZeppelin Contracts 4.8+ and follows professional ERC1155 standards.
 * @author ...
 */

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract ArtifactsERC1155 is ERC1155, Ownable, EIP712 {
    using ECDSA for bytes32;

    // Token collection details
    string public name = "Artifacts of the Mibboverse";
    string public symbol = "ATF";

    // Mapping for contract admins (set by the owner)
    mapping(address => bool) public admins;

    // Nonce tracking for each user to prevent replay attacks
    mapping(address => uint256) public nonces;

    // Token metadata
    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => string) private _tokenNames;

    // Events
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    event TokenMetadataUpdated(uint256 indexed tokenId, string name, string uri);

    // EIP-712 domain
    string private constant SIGNING_DOMAIN = "AdminMintableERC1155";
    string private constant SIGNATURE_VERSION = "1";

    struct MintRequest {
        address to;
        uint256 id;
        uint256 amount;
        uint256 nonce;
    }

    bytes32 private constant MINTREQUEST_TYPEHASH =
        keccak256("MintRequest(address to,uint256 id,uint256 amount,uint256 nonce)");

    constructor() ERC1155("") EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) {}

    // ============ Admin Management ============

    function setAdmin(address admin, bool allowed) external onlyOwner {
        admins[admin] = allowed;
        if (allowed) emit AdminAdded(admin);
        else emit AdminRemoved(admin);
    }

    // ============ Metadata ============

    function setTokenMetadata(
        uint256 tokenId,
        string memory name_,
        string memory uri_
    ) external onlyOwner {
        _tokenNames[tokenId] = name_;
        _tokenURIs[tokenId] = uri_;
        emit TokenMetadataUpdated(tokenId, name_, uri_);
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return _tokenURIs[tokenId];
    }

    function token_name(uint256 tokenId) public view returns (string memory) {
        return _tokenNames[tokenId];
    }

    // ============ Burn ============

    function burn(address account, uint256 id, uint256 amount) external {
        require(
            account == msg.sender || isApprovedForAll(account, msg.sender),
            "Caller is not owner nor approved"
        );
        _burn(account, id, amount);
    }

    // ============ Mint with Signature (EIP-712) ============

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

        MintRequest memory request = MintRequest({to: to, id: id, amount: amount, nonce: nonce});

        bytes32 structHash = keccak256(
            abi.encode(
                MINTREQUEST_TYPEHASH,
                request.to,
                request.id,
                request.amount,
                request.nonce
            )
        );

        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, signature);

        require(signer == owner() || admins[signer], "Invalid signature");

        nonces[to]++;
        _mint(to, id, amount, "");
    }
}
