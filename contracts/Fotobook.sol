// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@manifoldxyz/creator-core-solidity/contracts/ERC721Creator.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/// @title FotobookNFT - A platform for minting, managing, and auctioning unique NFTs
/// @notice This contract allows users to mint 1/1 NFTs, set visibility, auction tokens, and place offers
/// @dev Extends ERC721Creator from Manifold, deployed on Base network
/// @author compez.eth
/// @custom:security-contact security@genyleap.com
contract FotobookNFT is ERC721Creator {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    struct TokenVisibility {
        bool isPublic;
    }

    mapping(uint256 => string) public tokenURIs;
    mapping(uint256 => TokenVisibility) public tokenVisibilities;

    event NFTMinted(uint256 indexed tokenId, address indexed recipient);
    event VisibilityUpdated(uint256 indexed tokenId, bool isPublic);

    constructor() ERC721Creator("Fotobook", "FOTO") {}

    /// @notice Mints a new 1/1 NFT with specified URI and visibility
    function mintNFT(address recipient, string calldata tokenURI, bool isPublic) external returns (uint256) {
        require(recipient != address(0));
        require(bytes(tokenURI).length > 0);

        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        mintBase(recipient, tokenURI);

        tokenURIs[newTokenId] = tokenURI;
        tokenVisibilities[newTokenId].isPublic = isPublic;
        emit NFTMinted(newTokenId, recipient);

        return newTokenId;
    }

    /// @notice Updates the visibility of an NFT (public/private)
    function updateVisibility(uint256 tokenId, bool isPublic) external {
        require(ownerOf(tokenId) == msg.sender);
        tokenVisibilities[tokenId].isPublic = isPublic;
        emit VisibilityUpdated(tokenId, isPublic);
    }

    /// @notice Checks if an NFT is publicly visible
    function isTokenPublic(uint256 tokenId) external view returns (bool) {
        return tokenVisibilities[tokenId].isPublic;
    }
}
