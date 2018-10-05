var CloLotteryContract = artifacts.require("./CloLotteryContract.sol");
module.exports = function(deployer) {
    deployer.deploy(CloLotteryContract);
};
