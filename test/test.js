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

            const {UPGRADE} = await mainDeploy()

            // console.log(`Main contract and Proxy Deployed`)
            // await sleep(5*1000)

            // Deployed new contract logic
            const DotWAGMI2 = await hre.ethers.getContractFactory("DotWAGMI2")
            const UPGRADE2 = await hre.upgrades.upgradeProxy(UPGRADE.target,DotWAGMI2)
                
            await UPGRADE2.waitForDeployment()


            // Check new added function
            const increase = await UPGRADE2.increaseUID()

            // console.log(`New function used!`)
            // await sleep(5*1000)
            
            const machineId = await UPGRADE2.UID()
            expect(machineId).to.equal(10001)

        })

    })

    describe('Functions Testing', () => { 

        // Properly minting function working
        it("Is minting", async() => {
        
            const {UPGRADE,owner} = await mainDeploy()

            await UPGRADE.setMintConditions(
                "10000000000000000",
                3,
                5,
                owner.address
            )

            const message = "Hello World!"
            const messageHash = ethers.hashMessage(message)
            const signature = await owner.signMessage(ethers.getBytes(messageHash));

            await UPGRADE.mint(
                "0xan",
                "Rariko is best",
                "xyz@gmail.com",
                "7003335233",
                owner.address,
                "xyz.com",
                signature,
                messageHash
            )


            expect(await UPGRADE.tokenIdResolve(1)).to.equal("0xan")
            expect(await UPGRADE.ownerOf(1)).to.equal(owner.address)
            expect(await UPGRADE.userNameTaken("0xan")).to.equal(true)
            
        })

    })

})