const { expect } = require("chai")
const { ethers } = require("hardhat")

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

describe('DotWAGMI', () => {

    async function mainDeploy(){

        const [owner,otherAccount] = await ethers.getSigners();

        const DotWAGMI = await hre.ethers.getContractFactory("DotWAGMI")
        const UPGRADE = await hre.upgrades.deployProxy(DotWAGMI ,
        [owner.address],
        {
          "initializer":"initialize",
          "kind":"uups"
        } 
        );
    
        await UPGRADE.waitForDeployment()
        return {UPGRADE,owner,otherAccount}

    }

    describe('Deployement Testing', () => { 

        // Properly deployed
        it("Is properly deployed", async() => {

            const {UPGRADE,owner} = await mainDeploy()

            // Check owner is initialized 
            const testOwner  = await UPGRADE.owner()
            expect(testOwner).to.equal(owner.address)

        })

        // Is upgradable 
        it("Is upgrading", async() => {

            const {UPGRADE,owner} = await mainDeploy()

            // console.log(`Main contract and Proxy Deployed`)
            // await sleep(5*1000)

            // Deployed new contract logic
            const DotWAGMI2 = await hre.ethers.getContractFactory("DotWAGMI2")
            const UPGRADE2 = await hre.upgrades.upgradeProxy(UPGRADE.target,DotWAGMI2)
                
            await UPGRADE2.waitForDeployment()
            console.log(`Proxy Contract 2 deployed at ${UPGRADE2.target}`)


            // Check new added function
            const increase = await UPGRADE2.increaseUID()

            // console.log(`New function used!`)
            // await sleep(5*1000)
            
            const machineId = await UPGRADE2.UID()
            expect(machineId).to.equal(10001)

        })

    })

})