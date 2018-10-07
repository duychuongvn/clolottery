var ethwallet = require('ethereumjs-wallet');
var ProviderEngine = require("web3-provider-engine");
var FiltersSubprovider = require('web3-provider-engine/subproviders/filters.js');
var HookedSubprovider = require('web3-provider-engine/subproviders/hooked-wallet.js');
var ProviderSubprovider = require("web3-provider-engine/subproviders/provider.js");
var Web3 = require("web3");
var Transaction = require('ethereumjs-tx');

function RpcProvider(privateKey, provider_url) {
  this.provider_url = provider_url;
  var wallet = ethwallet.fromPrivateKey(Buffer.from(privateKey, 'hex'));
  this.wallets = {};
  this.addresses = [];
  var addr = '0x' + wallet.getAddress().toString('hex');
  this.addresses.push(addr);
  this.wallets[addr] = wallet;


  const tmp_accounts = this.addresses;
  const tmp_wallets = this.wallets;
  this.engine = new ProviderEngine();
  this.engine.addProvider(new HookedSubprovider({
    getAccounts: function(cb) { cb(null, tmp_accounts) },
    getPrivateKey: function(address, cb) {
      if (!tmp_wallets[address]) { return cb('Account not found'); }
      else { cb(null, tmp_wallets[address].getPrivateKey().toString('hex')); }
    },
    signTransaction: function(txParams, cb) {
      let pkey;
      if (tmp_wallets[txParams.from]) { pkey = tmp_wallets[txParams.from].getPrivateKey(); }
      else { cb('Account not found'); }
      var tx = new Transaction(txParams);
      tx.sign(pkey);
      var rawTx = '0x' + tx.serialize().toString('hex');
      cb(null, rawTx);
    }
  }));
  this.engine.addProvider(new FiltersSubprovider());
  this.engine.addProvider(new ProviderSubprovider(new Web3.providers.HttpProvider(provider_url)));
  this.engine.start(); // Required by the provider engine.
};

RpcProvider.prototype.sendAsync = function () {
  this.engine.sendAsync.apply(this.engine, arguments);
};

RpcProvider.prototype.send = function () {
  return this.engine.send.apply(this.engine, arguments);
};
// returns the address of the given address_index, first checking the cache
RpcProvider.prototype.getAddress = function(idx) {
  console.log('getting addresses', this.addresses[0], idx)
  if (!idx) { return this.addresses[0]; }
  else { return this.addresses[idx]; }
}

// returns the addresses cache
RpcProvider.prototype.getAddresses = function() {
  return this.addresses;
}

// returns the address of the given address_index, first checking the cache
module.exports = RpcProvider;
