var ScheduleContract = artifacts.require("./ScheduleContract.sol");
var EtherLotteryContract = artifacts.require("./EtherLotteryContract.sol");
module.exports = function(deployer) {

   deployer.deploy(ScheduleContract).then(function () {
       return  deployer.deploy(EtherLotteryContract, ScheduleContract.address);
   });

};
