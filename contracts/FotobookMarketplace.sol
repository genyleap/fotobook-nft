// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./FotobookNFT.sol";
import "./FotobookAuction.sol";

/// @title FotobookMarketplace - Helper contract for indexing and filtering NFTs
/// @notice Manages metadata indexing and provides filtering for marketplace
/// @dev Interacts with FotobookNFT and FotobookAuction, uses OpenZeppelin upgradeable proxy
/// @author compez.eth
/// @custom:security-contact security@genyleap.com
contract FotobookMarketplace is Initializable, OwnableUpgradeable {
    FotobookNFT private _nftContract;
    FotobookAuction private _auctionContract;

    // Structure for NFT metadata
    struct NFTMetadata {
        uint256 tokenId;
        string[] tags; // e.g., ["landscape", "photography"]
        string category; // e.g., "photo", "art", "video"
        bool isPublic; // Synced with FotobookNFT visibility
    }

    // Mapping for NFT metadata
    mapping(uint256 => NFTMetadata) public nftMetadata;
    // Array of all public NFT token IDs
    uint256[] public publicNFTs;
    // Mapping to track if tokenId is in publicNFTs
    mapping(uint256 => bool) public isPublicNFT;
    // Array of active auction token IDs
    uint256[] public activeAuctions;
    // Mapping to track if tokenId is in activeAuctions
    mapping(uint256 => bool) public isActiveAuction;

    event MetadataUpdated(uint256 indexed tokenId, string[] tags, string category);
    event NFTPublicStatusChanged(uint256 indexed tokenId, bool isPublic);
    event AuctionIndexed(uint256 indexed tokenId);
    event AuctionRemoved(uint256 indexed tokenId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract
    function initialize(address nftContract, address auctionContract) external initializer {
        require(nftContract != address(0), "Invalid NFT contract address");
        __Ownable_init();
        _nftContract = FotobookNFT(nftContract);
        _auctionContract = FotobookAuction(auctionContract); // Works with zero address
    }

    /// @notice Updates the auction contract address (optional for later initialization)
    function updateAuctionContract(address auctionContract) external onlyOwner {
        _auctionContract = FotobookAuction(auctionContract);
    }

    /// @notice Updates metadata for an NFT
    function updateMetadata(uint256 tokenId, string[] memory tags, string memory category) external {
        require(_nftContract.ownerOf(tokenId) == msg.sender, "Not token owner");
        require(bytes(category).length > 0, "Category cannot be empty");

        nftMetadata[tokenId] = NFTMetadata({
            tokenId: tokenId,
            tags: tags,
            category: category,
            isPublic: _nftContract.isTokenPublic(tokenId)
        });

        emit MetadataUpdated(tokenId, tags, category);
    }

    /// @notice Syncs public status with FotobookNFT
    function syncPublicStatus(uint256 tokenId) external {
        bool isPublic = _nftContract.isTokenPublic(tokenId);
        if (isPublic && !isPublicNFT[tokenId]) {
            publicNFTs.push(tokenId);
            isPublicNFT[tokenId] = true;
        } else if (!isPublic && isPublicNFT[tokenId]) {
            for (uint256 i = 0; i < publicNFTs.length; i++) {
                if (publicNFTs[i] == tokenId) {
                    publicNFTs[i] = publicNFTs[publicNFTs.length - 1];
                    publicNFTs.pop();
                    break;
                }
            }
            isPublicNFT[tokenId] = false;
        }
        emit NFTPublicStatusChanged(tokenId, isPublic);
    }

    /// @notice Indexes an auction when it starts
    function indexAuction(uint256 tokenId) external {
        require(msg.sender == address(_auctionContract), "Only auction contract");
        if (!isActiveAuction[tokenId]) {
            activeAuctions.push(tokenId);
            isActiveAuction[tokenId] = true;
            emit AuctionIndexed(tokenId);
        }
    }

    /// @notice Removes an auction when it ends or is cancelled
    function removeAuction(uint256 tokenId) external {
        require(msg.sender == address(_auctionContract), "Only auction contract");
        if (isActiveAuction[tokenId]) {
            for (uint256 i = 0; i < activeAuctions.length; i++) {
                if (activeAuctions[i] == tokenId) {
                    activeAuctions[i] = activeAuctions[activeAuctions.length - 1];
                    activeAuctions.pop();
                    break;
                }
            }
            isActiveAuction[tokenId] = false;
            emit AuctionRemoved(tokenId);
        }
    }

    /// @notice Gets all public NFTs
    function getPublicNFTs() external view returns (uint256[] memory) {
        return publicNFTs;
    }

    /// @notice Filters NFTs by category
    function filterByCategory(string memory category) external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < publicNFTs.length; i++) {
            if (keccak256(abi.encodePacked(nftMetadata[publicNFTs[i]].category)) == keccak256(abi.encodePacked(category))) {
                count++;
            }
        }

        uint256[] memory result = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < publicNFTs.length; i++) {
            if (keccak256(abi.encodePacked(nftMetadata[publicNFTs[i]].category)) == keccak256(abi.encodePacked(category))) {
                result[index] = publicNFTs[i];
                index++;
            }
        }
        return result;
    }

    /// @notice Filters NFTs by tag
    function filterByTag(string memory tag) external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < publicNFTs.length; i++) {
            for (uint256 j = 0; j < nftMetadata[publicNFTs[i]].tags.length; j++) {
                if (keccak256(abi.encodePacked(nftMetadata[publicNFTs[i]].tags[j])) == keccak256(abi.encodePacked(tag))) {
                    count++;
                    break;
                }
            }
        }

        uint256[] memory result = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < publicNFTs.length; i++) {
            for (uint256 j = 0; j < nftMetadata[publicNFTs[i]].tags.length; j++) {
                if (keccak256(abi.encodePacked(nftMetadata[publicNFTs[i]].tags[j])) == keccak256(abi.encodePacked(tag))) {
                    result[index] = publicNFTs[i];
                    index++;
                    break;
                }
            }
        }
        return result;
    }

    /// @notice Gets active auctions
    function getActiveAuctions() external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < activeAuctions.length; i++) {
            if (_auctionContract.isAuctionActive(activeAuctions[i]) && block.timestamp < _auctionContract.getAuctionEndTime(activeAuctions[i])) {
                count++;
            }
        }

        uint256[] memory result = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < activeAuctions.length; i++) {
            if (_auctionContract.isAuctionActive(activeAuctions[i]) && block.timestamp < _auctionContract.getAuctionEndTime(activeAuctions[i])) {
                result[index] = activeAuctions[i];
                index++;
            }
        }
        return result;
    }
}
