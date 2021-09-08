
const DYNXTERC20 = artifacts.require('DYNXTERC20')
const DYNXTFactory = artifacts.require('DYNXTFactory')
const DYNXTPair = artifacts.require('DYNXTPair')

module.exports = async (deployer, network, addresses) => {
  let [owner] = addresses
  //user = '0xcF01971DB0CAB2CBeE4A8C21BB7638aC1FA1c38c';

  console.log('user: ', owner)
  console.log('network: ', network)

  const devaddr = owner
  await deployer.deploy(
    DYNXTFactory,
    devaddr
  )

  const factory = await DYNXTFactory.deployed()
  await factory.setFeeTo(devaddr)
  console.log('INIT HASH FROM FACTORY: ', await factory.INIT_CODE_PAIR_HASH());
}