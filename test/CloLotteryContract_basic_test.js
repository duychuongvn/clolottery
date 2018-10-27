const CloLotteryContract = artifacts.require("CloLotteryContract");
const ScheduleContract = artifacts.require("ScheduleContract");

toGwei = (wei) => {
  return parseInt(wei / 1000000000000);
}

toWei = (ether) =>{
  return ether*1000000000000000000;
}
toEther =(wei) => {
  return wei/1000000000000000000;
}

var assertThrow = async (fn, args) => {
  try {
    await fn.apply(null, args)
    assert(false, 'the contract should throw here')
  } catch (error) {
    assert(
      /invalid opcode/.test(error) || /revert/.test(error),
      `the error message should be invalid opcode or revert, the error was ${error}`
    )
  }
}
sleep = () => {
    setTimeout(function () {

    }, 5000);
}

describe('Test', async () => {

  contract("CloLotteryContract", accounts => {
    const [firstAccount] = accounts;
    const contractOwner = accounts[0]
    const feeOwner = contractOwner;

    let contract;
      let sContract;

      beforeEach('setup contract for each test', async () => {
      sContract = await ScheduleContract.new();
      contract = await CloLotteryContract.new(sContract.address);
      contract.WinTicketEvent().watch((err, res)=>{
          console.log("Ticket number: "+res.args.ticket.toNumber())

      }) ;
          contract.LogRandomEvent().watch((err, res)=>{
              console.log("Ticket number: "+res.args.amount.toNumber())

          }) ;

      contract.FoundWinnerEvent().watch(async (err, res)=> {
          console.log("Found winner, transfer fund")
          try {
              await contract.transferToWinners();
              console.log("===Balance after transfer fund for winners ====")
              console.log("A1: "+await toEther(web3.eth.getBalance(accounts[1]).toNumber()))
              console.log("A2: "+await toEther(web3.eth.getBalance(accounts[2]).toNumber()))
              console.log("A3: "+await toEther(web3.eth.getBalance(accounts[3]).toNumber()))
              console.log("A4: "+await toEther(web3.eth.getBalance(accounts[4]).toNumber()))
              console.log("A5: "+await toEther(web3.eth.getBalance(accounts[5]).toNumber()))
              console.log("A6: "+await toEther(web3.eth.getBalance(accounts[6]).toNumber()))
              console.log("A7: "+await toEther(web3.eth.getBalance(accounts[7]).toNumber()))

          }catch (e) {
              console.log('Cannot transfer funds', e);
          }
      })
    })


    it('should query', async () => {
        console.log("===Balance before buying ticket====")
        console.log("A1: "+await toEther(web3.eth.getBalance(accounts[1]).toNumber()))
        console.log("A2: "+await toEther(web3.eth.getBalance(accounts[2]).toNumber()))
        console.log("A3: "+await toEther(web3.eth.getBalance(accounts[3]).toNumber()))
        console.log("A4: "+await toEther(web3.eth.getBalance(accounts[4]).toNumber()))
        console.log("A5: "+await toEther(web3.eth.getBalance(accounts[5]).toNumber()))
        console.log("A6: "+await toEther(web3.eth.getBalance(accounts[6]).toNumber()))
        console.log("A7: "+await toEther(web3.eth.getBalance(accounts[7]).toNumber()))
        contract.init({from:contractOwner, value:toWei(4)});
        contract.buyTickets([8,9,7], {from:accounts[1], value: toWei(3)})
        contract.buyTickets([8,7], {from:accounts[1], value: toWei(3)})
        contract.buyTickets([6,2], {from:accounts[2], value: toWei(3)})
        contract.buyTickets([8,1], {from:accounts[3], value: toWei(3)})
        contract.buyTickets([6], {from:accounts[4], value: toWei(3)})
        contract.buyTickets([7,2], {from:accounts[5], value: toWei(3)})
        contract.buyTickets([2], {from:accounts[6], value: toWei(3)})
        contract.buyTickets([2,6, 0], {from:accounts[7], value: toWei(3)})

        console.log("===Balance after buying ticket====")
        console.log(await toEther(web3.eth.getBalance(contract.address).toNumber()))
        console.log(await toEther(web3.eth.getBalance(contractOwner).toNumber()))
        console.log("A1: "+await toEther(web3.eth.getBalance(accounts[1]).toNumber()))
        console.log("A2: "+await toEther(web3.eth.getBalance(accounts[2]).toNumber()))
        console.log("A3: "+await toEther(web3.eth.getBalance(accounts[3]).toNumber()))
        console.log("A4: "+await toEther(web3.eth.getBalance(accounts[4]).toNumber()))
        console.log("A5: "+await toEther(web3.eth.getBalance(accounts[5]).toNumber()))
        console.log("A6: "+await toEther(web3.eth.getBalance(accounts[6]).toNumber()))
        console.log("A7: "+await toEther(web3.eth.getBalance(accounts[7]).toNumber()))


        // .then(function(e, e1){
        //     console.log(e, e1)
        // });
        for(var i = 0; i < 50;i++) {
            try{
                await contract.__callback('0x01', {from: contractOwner});
                console.log('callback success at', i);
            } catch (e) {
                // ignore error when callback not reach required blocks
            }
        }


        // contract.transferToWinners().then((err, result)=>{
        //     console.log(err, result);
        // });

    });
  })
})
