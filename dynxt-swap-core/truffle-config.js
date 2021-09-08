var HDWalletProvider = require("truffle-hdwallet-provider");

require('dotenv').config()
const package = require('./package')
const MNEMONIC = process.env.MNEMONIC
const token =  process.env.INFURA_TOKEN
const etherscanKey = process.env.ETHERSCAN_KEY

module.exports = {
  // Uncommenting the defaults below
  // provides for an easier quick-start with Ganache.
  // You can also follow this format for other networks;
  // see <http://truffleframework.com/docs/advanced/configuration>
  // for more details on how to specify configuration options!
  //
  networks: {
   development: {
     host: "127.0.0.1",
     port: 8545,
     network_id: "*",
     gas: 6721975
   },
   test: {
     host: "127.0.0.1",
     port: 8545,
     network_id: "*",
     
   },
   bscTestnet:{
     provider: function() {
       // 0x25449306F743E252720cC03540773423513f5FEf
      //  ganache-cli --fork https://data-seed-prebsc-1-s1.binance.org:8545
       return new HDWalletProvider(MNEMONIC, "https://data-seed-prebsc-1-s1.binance.org:8545")
     },
     network_id: "97",
     networkCheckTimeout: 999999
     //  gas: 30000000
    //       6721975
   },

   bscMainnet: {
     provider: function() {
       return new HDWalletProvider(MNEMONIC, "https://bsc-dataseed.binance.org")
     },
     network_id: "56"
   },

   ropsten:{
     provider: function() {
      return new HDWalletProvider(MNEMONIC, "https://ropsten.infura.io/v3/" + token)
     },
     network_id: "3"
   },
  },
  plugins: [
    'truffle-plugin-verify'
  ],
  api_keys: {
    etherscan: 'MJSK17NM3DJWE9N65MRE2NCZ69G9APZ9PG'
  },
  compilers: {
    solc: {
      version: "0.5.16",
      settings: { 
        optimizer: {
          enabled: true,
          runs: 200 
        }
      }
    }
  }
};
