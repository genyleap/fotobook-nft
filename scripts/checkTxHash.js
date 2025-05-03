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
    const mintTx = await fotobookNFT.mintNFT(owner.address, "ipfs://test_new_12", true);
    console.log("Transaction sent, hash:", mintTx.hash);
    const mintReceipt = await mintTx.wait();
    console.log("Mint transaction receipt:", {
      transactionHash: mintReceipt.transactionHash,
      blockNumber: mintReceipt.blockNumber,
      gasUsed: mintReceipt.gasUsed.toString(),
      status: mintReceipt.status
    });
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
