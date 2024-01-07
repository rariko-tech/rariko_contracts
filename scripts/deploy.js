const hre = require("hardhat")

const main = async () => {
  try {

    const [owner] = await ethers.getSigners();

    const DotWAGMI = await hre.ethers.getContractFactory("DotWAGMI")
    const UPGRADE = await hre.upgrades.deployProxy(DotWAGMI ,
    [owner.address],
    {
      "initializer":"initialize",
      "kind":"uups"
    } 
    );

    await UPGRADE.waitForDeployment()
    console.log(`Proxy Contract deployed at ${UPGRADE.target}`)

  } catch (error) {
    console.error(error);
  }
}

main()