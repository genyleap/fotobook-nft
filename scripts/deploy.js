const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contract with account:", deployer.address);

  const FotobookNFT = await ethers.getContractFactory("FotobookNFT");
  const fotobookNFT = await FotobookNFT.deploy();
  await fotobookNFT.waitForDeployment();

  const contractAddress = await fotobookNFT.getAddress();
  console.log("FotobookNFT deployed to:", contractAddress);

  const name = await fotobookNFT.name();
  const symbol = await fotobookNFT.symbol();
  console.log("Contract name:", name);
  console.log("Contract symbol:", symbol);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error:", error);
    process.exit(1);
  });
