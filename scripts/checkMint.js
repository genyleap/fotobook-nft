const { ethers } = require("hardhat");

async function main() {
  const contractAddress = "0x";
  const [owner] = await ethers.getSigners();

  console.log("Testing mint at:", contractAddress);
  console.log("Owner address:", owner.address);

  const FotobookNFT = await ethers.getContractFactory("FotobookNFT");
  const fotobookNFT = await FotobookNFT.attach(contractAddress);

  console.log("Minting NFT...");
  try {
    const mintTx = await fotobookNFT.mintNFT(owner.address, "ipfs://test_new_6", true);
    const mintReceipt = await mintTx.wait();
    console.log("Mint transaction receipt:", {
      transactionHash: mintReceipt.transactionHash,
      blockNumber: mintReceipt.blockNumber,
      gasUsed: mintReceipt.gasUsed.toString(),
      status: mintReceipt.status,
      logs: mintReceipt.logs.map(log => ({
        address: log.address,
        topics: log.topics,
        data: log.data
      }))
    });

    // Try to find NFTMinted event
    const mintedEvent = mintReceipt.logs.find(log => {
      try {
        const parsedLog = fotobookNFT.interface.parseLog(log);
        return parsedLog.name === "NFTMinted";
      } catch (e) {
        return false;
      }
    });

    if (mintedEvent) {
      const parsedLog = fotobookNFT.interface.parseLog(mintedEvent);
      const tokenId = parsedLog.args.tokenId.toString(); // Avoid toNumber() for safety
      console.log(`NFT minted with tokenId ${tokenId}, owner:`, await fotobookNFT.ownerOf(tokenId));
    } else {
      console.log("No NFTMinted event found in logs");
    }
  } catch (error) {
    console.error("Mint failed:", error.message);
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
