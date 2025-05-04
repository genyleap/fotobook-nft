const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Ethers.js version:", ethers.version);
  console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH");

  // Deploy StreakLeaderboard
  const StreakLeaderboard = await ethers.getContractFactory("StreakLeaderboard");
  console.log("Deploying StreakLeaderboard...");
  const streakLeaderboard = await StreakLeaderboard.deploy("0x0000000000000000000000000000000000000000");
  await streakLeaderboard.waitForDeployment();
  const streakAddress = await streakLeaderboard.getAddress();
  console.log("StreakLeaderboard deployed to:", streakAddress);

  // Deploy FotobookNFT (non-upgradeable)
  const FotobookNFT = await ethers.getContractFactory("FotobookNFT");
  console.log("Deploying FotobookNFT...");
  const fotobookNFT = await FotobookNFT.deploy();
  await fotobookNFT.waitForDeployment();
  const nftAddress = await fotobookNFT.getAddress();
  console.log("FotobookNFT deployed to:", nftAddress);

  // Update StreakLeaderboard with FotobookNFT address
  console.log("Updating StreakLeaderboard with FotobookNFT address...");
  const txStreak = await streakLeaderboard.updateNftContract(nftAddress, { gasLimit: 200000 });
  await txStreak.wait();
  console.log("StreakLeaderboard updated with FotobookNFT address:", nftAddress);

  // Deploy FotobookMarketplace (upgradeable)
  const FotobookMarketplace = await ethers.getContractFactory("FotobookMarketplace");
  console.log("Deploying FotobookMarketplace proxy...");
  const fotobookMarketplace = await upgrades.deployProxy(
    FotobookMarketplace,
    [nftAddress, "0x0000000000000000000000000000000000000000"],
    { initializer: "initialize", gasLimit: 8000000 }
  );
  await fotobookMarketplace.waitForDeployment();
  const marketplaceAddress = await fotobookMarketplace.getAddress();
  console.log("FotobookMarketplace (proxy) deployed to:", marketplaceAddress);

  // Deploy FotobookAuction (upgradeable)
  const FotobookAuction = await ethers.getContractFactory("FotobookAuction");
  console.log("Deploying FotobookAuction proxy...");
  const fotobookAuction = await upgrades.deployProxy(
    FotobookAuction,
    [nftAddress, marketplaceAddress],
    { initializer: "initialize", gasLimit: 8000000 }
  );
  await fotobookAuction.waitForDeployment();
  const auctionAddress = await fotobookAuction.getAddress();
  console.log("FotobookAuction (proxy) deployed to:", auctionAddress);

  // Update FotobookMarketplace with FotobookAuction address
  console.log("Updating FotobookMarketplace with FotobookAuction address...");
  const txMarketplace = await fotobookMarketplace.updateAuctionContract(auctionAddress, { gasLimit: 200000 });
  await txMarketplace.wait();
  console.log("FotobookMarketplace updated with auction address:", auctionAddress);

  // Verify contract details
  const name = await fotobookNFT.name();
  const symbol = await fotobookNFT.symbol();
  console.log("FotobookNFT name:", name);
  console.log("FotobookNFT symbol:", symbol);

  // Optional: Add an ERC20 token (e.g., Geny) to allowed tokens
  // const genyTokenAddress = ""; // Replace with actual address
  // console.log("Adding Geny token to allowed tokens...");
  // const txToken = await fotobookAuction.addToken(genyTokenAddress, { gasLimit: 200000 });
  // await txToken.wait();
  // console.log("Geny token added to allowed tokens");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error:", error);
    if (error.reason) console.error("Revert reason:", error.reason);
    if (error.data) console.error("Revert data:", error.data);
    process.exit(1);
  });