const CloLotteryContract = artifacts.require("CloLotteryContract");

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


    beforeEach('setup contract for each test', async () => {
      contract = await CloLotteryContract.new();
      contract.WinTicketEvent().watch((err, res)=>{
          console.log("Ticket number: "+res.args.ticket.toNumber())
      }) ;
      contract.StateEvent().watch((err, res)=>{
          console.log("State:"+res.args.state.toNumber())
      })
    })


    it('should query', async () => {
        contract.init({from:contractOwner, value:toWei(4)});
        contract.buyTickets([8,10,100], {from:accounts[1], value: toWei(3)})
        contract.buyTickets([92,93,94], {from:accounts[1], value: toWei(3)})
        contract.buyTickets([92,91,22], {from:accounts[2], value: toWei(3)})
        contract.buyTickets([9,50,51], {from:accounts[3], value: toWei(3)})
        contract.buyTickets([125,220,62], {from:accounts[4], value: toWei(3)})
        contract.buyTickets([54,53,52], {from:accounts[5], value: toWei(3)})
        contract.buyTickets([55,56,57], {from:accounts[6], value: toWei(3)})
        contract.buyTickets([120,123,101], {from:accounts[7], value: toWei(3)})

        console.log(contract.address)
        console.log(await toEther(web3.eth.getBalance(contract.address).toNumber()))
        console.log(await toEther(web3.eth.getBalance(contractOwner).toNumber()))
        console.log("A1: "+await toEther(web3.eth.getBalance(accounts[1]).toNumber()))
        console.log("A2: "+await toEther(web3.eth.getBalance(accounts[2]).toNumber()))
        console.log("A3: "+await toEther(web3.eth.getBalance(accounts[3]).toNumber()))
        console.log("A4: "+await toEther(web3.eth.getBalance(accounts[4]).toNumber()))
        console.log("A5: "+await toEther(web3.eth.getBalance(accounts[5]).toNumber()))
        console.log("A6: "+await toEther(web3.eth.getBalance(accounts[6]).toNumber()))
        console.log("A7: "+await toEther(web3.eth.getBalance(accounts[7]).toNumber()))

        contract.__callback(0x0);
        await sleep();
        contract.__callback(0x1);
        console.log("A1: "+await toEther(web3.eth.getBalance(accounts[1]).toNumber()))
        console.log("A2: "+await toEther(web3.eth.getBalance(accounts[2]).toNumber()))
        console.log("A3: "+await toEther(web3.eth.getBalance(accounts[3]).toNumber()))
        console.log("A4: "+await toEther(web3.eth.getBalance(accounts[4]).toNumber()))
        console.log("A5: "+await toEther(web3.eth.getBalance(accounts[5]).toNumber()))
        console.log("A6: "+await toEther(web3.eth.getBalance(accounts[6]).toNumber()))
        console.log("A7: "+await toEther(web3.eth.getBalance(accounts[7]).toNumber()))

    });
  })
})
