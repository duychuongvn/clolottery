pragma solidity ^0.4.21;

import "./Ownable.sol";

contract ScheduleContractInterface {
    address public cbAddress;
    function schedule(uint timestamp, uint256 estimatedGas) payable returns (bytes32 _id);
}

contract CloLotteryContract is Ownable {

    event NewRoundOpenEvent();
    event FinishRoundEvent();
    event BuyTicketEvent();
    event CloseRoundEvent();
    event WinTicketEvent(uint32 indexed ticket);
    event NotEnoughFundToInitEvent();
    enum State {Initializing, Open, Processing, Finished}

    //TODO will be change to uint32 once go line
    mapping(uint32=> address[]) buyers;
    State public state;
    uint lastBuyBlock;
    uint  public durationBlock = 8400;
    uint pinBlock = 20; // ~300 seconds
    uint256 public ticketPrice = 1000000000000000000; // 1 ether    uint256 public winningPrize; // in wei
    uint256 public underLimitPrize = 2 ether;
    uint256 public winningPrize;
    uint8 public founderEarnPercent = 25;
    uint32 public lastWinTicket;
    uint closedBlock;
    ScheduleContractInterface scheduledContract;
    uint public roundId;
    mapping(uint=>Round) rounds;
    function CloLotteryContract() {
      //  scheduledContract = ScheduleContractInterface(scheduleContractAddress);
    }

    struct Round {
        uint32 winNumber;
        uint256 winPrize;
        uint48 startTime;
        uint48 endTime;
        uint256 finishBlock;
        mapping(uint32=> address[]) buyers;
    }

    function nextRound() private returns(uint) {
        return ++roundId;
    }
    function init() public payable onlyOwner {
        require(state == State.Initializing);
        require(msg.value + winningPrize >= underLimitPrize);
        winningPrize += msg.value;
        initNewRound();
    }
    function initNewRound() private {
        state = State.Open;
        rounds[nextRound()].startTime = uint48(now);
        rounds[roundId].winPrize = winningPrize;
        NewRoundOpenEvent();
    }

    function withdrawFee() onlyOwner {
        require(winningPrize > underLimitPrize);
        uint256 fee = (winningPrize-underLimitPrize) * founderEarnPercent / 100;
        winningPrize -= fee;
        msg.sender.transfer(fee);
    }


    function buyTickets(uint32[] ticketNumbers) public payable {

        require(state == State.Open);
        require(ticketNumbers.length >= 1);
        require(ticketNumbers.length * ticketPrice == msg.value);
        for(uint i = 0; i < ticketNumbers.length; i++) {
            rounds[roundId].buyers[ticketNumbers[i]].push(msg.sender);
        }
        BuyTicketEvent();
    }

    function schedule() {
        if(state == State.Processing) {
            uint256 gasFee = 400000;
            scheduledContract.schedule(pinBlock*15, gasFee);
        } else {
            scheduledContract.schedule(durationBlock, gasFee);
        }
    }

    function finish() private {
        lastBuyBlock = block.number;
        lastWinTicket = random();
        lastWinTicket = (lastWinTicket << 2) / 10000;
        emit WinTicketEvent(lastWinTicket);
        uint winnerCount = rounds[roundId].buyers[lastWinTicket].length;
        uint256 totalPaid = this.balance - (this.balance * founderEarnPercent + 5) / 100;
        rounds[roundId].winPrize = totalPaid;
        rounds[roundId].finishBlock = block.number;
        rounds[roundId].winNumber = lastWinTicket;
        rounds[roundId].endTime = uint48(now);
        if (winnerCount > 0) {
            uint256 balanceToDistribute = totalPaid / winnerCount;
            for (uint i = 0; i < winnerCount; i++) {
                rounds[roundId].buyers[lastWinTicket][i].transfer(balanceToDistribute);
            }
            owner.transfer(this.balance * founderEarnPercent / 100);
        }
        state = State.Finished;
        initNewRound();
    }

    function random() private view returns (uint32) {
        return uint32(uint256(keccak256(lastBuyBlock,
                                keccak256(block.blockhash(block.number),
                                    keccak256(block.timestamp, block.difficulty)))));
    }

    event StateEvent(State state);
    function __callback(bytes32 queryId) {
        require(state == State.Open || state == State.Processing);
         if(state == State.Open) {
             state = State.Processing;
            // schedule();
             return;
         } else {
           //  require(block.number > closedBlock+pinBlock);
             finish();
         }
        StateEvent(state);



    }

}
