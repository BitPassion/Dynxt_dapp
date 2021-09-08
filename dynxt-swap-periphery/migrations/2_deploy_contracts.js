
const DYNXTMigrator = artifacts.require('DYNXTMigrator')
const DYNXTRouter = artifacts.require('DYNXTRouter')
const DYNXTRouter01 = artifacts.require('DYNXTRouter01')
const IDYNXTFactory = artifacts.require('IDYNXTFactory')
const IERC20 = artifacts.require('IERC20')


const testnetDeployScript = async (deployer, user, accounts) => {
  

}

module.exports = async (deployer, network, addresses) => {
  let [owner] = addresses

  console.log('owner: ', owner)
  console.log('network: ', network)
  
  const factoryAddress = '0x8F9ce3b55e564586a9AaE9a37850bbf70f560F2c'
  const wbnbAddress = '0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd'

  await deployer.deploy(
    DYNXTRouter,
    factoryAddress,
    wbnbAddress
  )

  const router = await DYNXTRouter.deployed()
  console.log('router: ', router.address)
}