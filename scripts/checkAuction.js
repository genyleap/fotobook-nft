const { ethers } = require("hardhat");

async function main() {
  const contractAddress = "0x";
  const [owner] = await ethers.getSigners();
  const FotobookNFT = await ethers.getContractFactory("FotobookNFT");
  const fotobookNFT = await FotobookNFT.attach(contractAddress);

  const tokenId = 1;
  const auction = await fotobookNFT.auctions(tokenId);
  console.log("Auction status for tokenId", tokenId, ":");
  console.log("Active:", auction.active);
  console.log("Seller:", auction.seller);
  console.log("End Time:", new Date(Number(auction.endTime) * 1000).toISOString());

  if (auction.active) {
    console.log("Attempting to end auction...");
    try {
      const endAuctionTx = await fotobookNFT.endAuction(tokenId);
      await endAuctionTx.wait();
      console.log("Auction ended successfully");
    } catch (error) {
      console.error("Failed to end auction:", error.message);
      console.log("You may need to wait until the auction end time or use a different tokenId.");
    }
  } else {
    console.log("No active auction for tokenId", tokenId);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error:", error);
    process.exit(1);
  });
