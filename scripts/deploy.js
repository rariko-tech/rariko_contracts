const {ethers,upgrades} = require("hardhat")

const main = async () => {
  try {

    const DotWAGMI = await ethers.getContractFactory("DotWAGMI")
    const UPGRADE = await upgrades.deployProxy(DotWAGMI ,
    ["0x5fbdb2315678afecb367f032d93f642f64180aa3"],
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