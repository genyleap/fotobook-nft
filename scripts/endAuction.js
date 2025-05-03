const { ethers } = require("hardhat");

async function main() {
  const contractAddress = "0x";
  const [owner] = await ethers.getSigners();
  const FotobookNFT = await ethers.getContractFactory("FotobookNFT");
  const fotobookNFT = await FotobookNFT.attach(contractAddress);

  const tokenId = 5;
  console.log(`Ending auction for tokenId ${tokenId}...`);
  try {
    const endAuctionTx = await fotobookNFT.endAuction(tokenId);
    await endAuctionTx.wait();
    console.log(`Auction ended for tokenId ${tokenId}, new owner:`, await fotobookNFT.ownerOf(tokenId));
  } catch (error) {
    console.error("Failed to end auction:", error.message);
    if (error.reason) {
      console.error("Revert reason:", error.reason);
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error:", error);
    process.exit(1);
  });
