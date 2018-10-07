var ScheduleContract = artifacts.require("./ScheduleContract.sol");
var CloLotteryContract = artifacts.require("./CloLotteryContract.sol");
module.exports = function(deployer) {

   deployer.deploy(ScheduleContract).then(function () {
       return  deployer.deploy(CloLotteryContract, ScheduleContract.address);
   });

};
