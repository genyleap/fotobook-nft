const { ethers } = require("hardhat");

async function main() {
  const contractAddress = "0x"; // Contract address of the deployed FotobookNFT contract
  const [owner, addr1] = await ethers.getSigners(); // Get the owner and another account (addr1) from the signers

  // Log the addresses of the owner and addr1
  console.log("Testing contract at:", contractAddress);
  console.log("Owner address:", owner.address);
  console.log("Bidder address:", addr1.address);

  // Get the contract factory for FotobookNFT and attach it to the deployed contract address
  const FotobookNFT = await ethers.getContractFactory("FotobookNFT");
  const fotobookNFT = await FotobookNFT.attach(contractAddress);

  // Check addr1's balance and print it in ETH format
  const addr1BalanceBigInt = await ethers.provider.getBalance(addr1.address);
  const addr1BalanceEth = ethers.formatEther(addr1BalanceBigInt);
  console.log(`Addr1 balance: ${addr1BalanceEth} ETH`);

  // Define the required balance to mint an NFT
  const requiredBalance = ethers.parseEther("0.03");

  // If addr1 doesn't have enough ETH, fund it from the owner account
  if (addr1BalanceBigInt < requiredBalance) {
    const tx = await owner.sendTransaction({
      to: addr1.address,
      value: requiredBalance - addr1BalanceBigInt, // Send the difference to addr1
    });
    await tx.wait(); // Wait for the transaction to be mined
    console.log(`Funded addr1 with ${ethers.formatEther(requiredBalance - addr1BalanceBigInt)} ETH`);
  }

  console.log("Minting NFT...");
  try {
    // Mint the NFT for the owner and specify the metadata URI
    const mintTx = await fotobookNFT.mintNFT(owner.address, "ipfs://test_new_9", true);
    const mintReceipt = await mintTx.wait(); // Wait for the transaction to be mined

    // Log the details of the minting transaction
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

    // Search for the "NFTMinted" event in the logs to get the minted NFT's tokenId
    const mintedEvent = mintReceipt.logs.find(log => {
      try {
        const parsedLog = fotobookNFT.interface.parseLog(log);
        return parsedLog.name === "NFTMinted";
      } catch (e) {
        return false; // If parsing the log fails, return false
      }
    });

    // If the NFTMinted event is found, process the event and interact with the minted NFT
    if (mintedEvent) {
      const parsedLog = fotobookNFT.interface.parseLog(mintedEvent);
      const tokenId = parsedLog.args.tokenId.toString(); // Extract the tokenId from the event
      console.log(`NFT minted with tokenId ${tokenId}, owner:`, await fotobookNFT.ownerOf(tokenId));
      console.log("Is token public?", await fotobookNFT.isTokenPublic(tokenId));

      // Update the visibility of the NFT
      console.log("Updating visibility...");
      const visibilityTx = await fotobookNFT.updateVisibility(tokenId, false); // Set visibility to false
      await visibilityTx.wait();
      console.log("Is token public after update?", await fotobookNFT.isTokenPublic(tokenId));

      // Start an auction for the NFT if no auction is already active
      console.log("Starting auction...");
      const minBid = ethers.parseEther("0.01"); // Minimum bid for the auction
      const duration = 86400; // Auction duration (1 day in seconds)
      const auction = await fotobookNFT.auctions(tokenId);
      if (auction.active) {
        console.log(`Auction already active for tokenId ${tokenId}, skipping...`);
      } else {
        const auctionTx = await fotobookNFT.startAuction(tokenId, minBid, duration); // Start the auction
        await auctionTx.wait();
        console.log(`Auction started for tokenId ${tokenId}`);
      }

      // Place a bid on the NFT from addr1
      console.log("Placing bid...");
      const bidTx = await fotobookNFT.connect(addr1).placeBid(tokenId, { value: ethers.parseEther("0.02") }); // Place a bid of 0.02 ETH
      await bidTx.wait();
      console.log("Bid placed by:", addr1.address);

      // Try to end the auction and transfer the NFT to the winning bidder
      console.log("Ending auction...");
      try {
        const endAuctionTx = await fotobookNFT.endAuction(tokenId); // End the auction
        await endAuctionTx.wait();
        console.log("Auction ended, new owner:", await fotobookNFT.ownerOf(tokenId));
      } catch (error) {
        console.error("Failed to end auction (likely because auction hasn't ended yet):", error.message);
        console.log("Please wait until the auction duration has passed or test in Hardhat network.");
      }
    } else {
      console.log("No NFTMinted event found in logs"); // If the minting event wasn't found, log a message
    }
  } catch (error) {
    console.error("Error during minting or processing:", error.message);
    if (error.reason) {
      console.error("Revert reason:", error.reason); // Log the revert reason if available
    }
  }
}

main()
  .then(() => process.exit(0)) // Exit cleanly on success
  .catch((error) => {
    console.error("Error:", error); // Log any errors that occur during execution
    process.exit(1); // Exit with a failure status
  });
