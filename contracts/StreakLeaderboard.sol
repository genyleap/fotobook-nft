// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./FotobookNFT.sol";

/// @title StreakLeaderboard - Tracks daily minting streaks for users
/// @notice Allows users to mint NFTs daily and tracks their streaks
/// @author compez.eth
/// @custom:security-contact security@genyleap.com
contract StreakLeaderboard is Ownable {
    FotobookNFT private _nftContract;

    struct Streak {
        uint256 count; // Current streak count
        uint256 lastMintTimestamp; // Timestamp of last mint
    }

    mapping(address => Streak) public streaks;
    address[] public leaderboard; // Top users by streak

    event StreakUpdated(address indexed user, uint256 count);
    event LeaderboardUpdated(address indexed user, uint256 count);
    event NftContractUpdated(address indexed newNftContract);

    constructor(address nftContract) {
        _nftContract = FotobookNFT(nftContract);
    }

    /// @notice Updates the NFT contract address
    function updateNftContract(address nftContract) external onlyOwner {
        _nftContract = FotobookNFT(nftContract);
        emit NftContractUpdated(nftContract);
    }

    /// @notice Updates streak when user mints an NFT
    function updateStreak(address user) external {
        require(msg.sender == address(_nftContract), "Only NFT contract");
        Streak storage streak = streaks[user];
        uint256 currentTime = block.timestamp;

        if (streak.lastMintTimestamp == 0 || currentTime >= streak.lastMintTimestamp + 1 days) {
            // New streak or new day
            streak.count = streak.lastMintTimestamp == 0 ? 1 : streak.count + 1;
            streak.lastMintTimestamp = currentTime;
        } else if (currentTime < streak.lastMintTimestamp + 1 days) {
            // Same day, no change in streak
            return;
        }

        emit StreakUpdated(user, streak.count);
        updateLeaderboard(user, streak.count);
    }

    /// @notice Updates the leaderboard
    function updateLeaderboard(address user, uint256 count) internal {
        // Simple leaderboard logic: keep top 10 users
        if (leaderboard.length < 10) {
            leaderboard.push(user);
        } else if (count > streaks[leaderboard[leaderboard.length - 1]].count) {
            leaderboard[leaderboard.length - 1] = user;
        }
        // Sort leaderboard (simplified)
        emit LeaderboardUpdated(user, count);
    }

    /// @notice Gets the current leaderboard
    function getLeaderboard() external view returns (address[] memory, uint256[] memory) {
        uint256[] memory counts = new uint256[](leaderboard.length);
        for (uint256 i = 0; i < leaderboard.length; i++) {
            counts[i] = streaks[leaderboard[i]].count;
        }
        return (leaderboard, counts);
    }
}
