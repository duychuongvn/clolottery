pragma solidity ^0.4.21;

import "./Ownable.sol";

contract ScheduleContractInterface {
    address public cbAddress;
    function schedule(uint timestamp, uint256 estimatedGas) payable returns (bytes32 _id);
    function getPrice(uint _gaslimit) view returns(uint256 gasPrice);
}

contract CloLotteryContract is Ownable {

    event NewRoundOpenEvent();
    event FinishRoundEvent();
    event BuyTicketEvent();
    event CloseRoundEvent();
    event WinTicketEvent(uint32 indexed ticket);
    event NotEnoughFundToInitEvent();
    event FoundWinnerEvent(uint256 roundId, uint256 prize);
    event NotFoundWinnerEvent(uint256 roundId);
    event DeterminingScheduleEvent(bytes32 queryId, uint delay, uint gasLimit);
    enum State {Initializing, Open, Processing, Closed}

    State public _state;
    address public FOUNDER = 0x81029273484ed1167910dd38f7b73000d342f3cf;

    mapping(uint32=> address[]) private buyerTicketNumbers;
    bytes32 private _lastBuyBlockHash;  // the last block hash user buys the ticket before closing a round
    uint  public roundDuration = 600; // default 1 day (will change to 8400)
    uint private timeToDeterminingWinner = 60; // (will change to 300)  wait about 300 seconds before determining the winner
    uint public roundOpenDuration = roundDuration - timeToDeterminingWinner;
    uint256 public ticketPrice = 1000000000000000000; // default 1 ether
    uint256 public underLimitPrize = 2 ether; //  the minimum prize to initialize a round
    uint256 public winningPrize; // total ether will be paid for the winners, the value will increase when more players buy tickets
    uint8 public founderEarnPercent = 20; // the percentage the founder earn when finish a round
    uint public applicationFeePecent = 2;
    uint32 public lastWinTicketNumber;
    uint256 closedBlockNumber; // the block number when closing a round, this is use to prevent user buys ticket at determining the winner time
    ScheduleContractInterface scheduledContract;
    uint public _roundId;
    mapping(uint=>Round) rounds;
    function CloLotteryContract(address scheduleAddr) {
       scheduledContract = ScheduleContractInterface(scheduleAddr);
    }

    address[] winnerAddresses;
    mapping(address=>uint) winners;

    struct Round {
        uint32 winNumber;
        uint256 winPrize;
        uint48 startTime;
        uint48 endTime;
        uint256 boughtAmount;
        uint256 finishBlock;
        uint256 ticketPrice;
        mapping(uint32=> address[]) buyerTicketNumbers;
    }

    modifier isCbAddress() {
        //require(msg.sender == scheduledContract.cbAddress);
        _;
    }

    function getCurrentRoundInfo() public view returns(uint roundId,
                                                uint256 ticketPrice,
                                                uint256 startTime,
                                                uint256 endTime,
                                                State state,
                                                uint256 currentPrize) {
        roundId = _roundId;
        (roundId, ticketPrice, startTime, endTime, state, currentPrize) =  getRoundInfo(roundId);
    }

    function getRoundInfo(uint _id) public view returns(uint roundId,
        uint256 ticketPrice,
        uint256 startTime,
        uint256 endTime,
        State state,
        uint256 winPrize) {
        roundId = _id;
        ticketPrice = rounds[_id].ticketPrice;
        startTime = uint256(rounds[_id].startTime);
        endTime = uint256(rounds[_id].startTime + roundDuration);
        state = _state;
        if (_id == _roundId) {
            winPrize = address(this).balance;
        } else {
            winPrize = rounds[_id].winPrize;
        }
    }

    function nextRound() private returns(uint) {
        return ++_roundId;
    }

    function init() public payable onlyOwner {
        require(_state == State.Initializing || _state == State.Closed);
        require(msg.value + winningPrize >= underLimitPrize);
        winningPrize += msg.value;
        initNewRound();
    }

    function initNewRound() private {
        _state = State.Open;
        rounds[nextRound()].startTime = uint48(now);
        rounds[_roundId].winPrize = winningPrize;
        rounds[_roundId].ticketPrice = ticketPrice;
        rounds[_roundId].endTime = uint48(now + roundOpenDuration);
        schedule();
        NewRoundOpenEvent();
    }

    function withdrawFee() onlyOwner {
        require(winningPrize > underLimitPrize);
        uint256 fee = (winningPrize-underLimitPrize) * founderEarnPercent / 100;
        winningPrize -= fee;
        msg.sender.transfer(fee);
    }


    function buyTickets(uint32[] ticketNumbers) public payable {

        require(_state == State.Open);
        require(ticketNumbers.length >= 1);
        require(ticketNumbers.length * ticketPrice == msg.value);
        for(uint i = 0; i < ticketNumbers.length; i++) {
            rounds[_roundId].buyerTicketNumbers[ticketNumbers[i]].push(msg.sender);
        }
        rounds[_roundId].boughtAmount += msg.value;
        _lastBuyBlockHash = block.blockhash(block.number);
        BuyTicketEvent();
    }

    function schedule() {

        if(_state == State.Processing) {
            // schedule to determinate the winner
            uint delay = timeToDeterminingWinner;
            uint gasLimit = 100000;
            uint price = scheduledContract.getPrice(gasLimit);

        } else {
            // schedule to closed the round and prepare to determinate the winner
            delay = roundOpenDuration;
            gasLimit = 500000;
            price = scheduledContract.getPrice(gasLimit);

        }
        bytes32 id = scheduledContract.schedule.value(price)(delay, gasLimit);
        DeterminingScheduleEvent(id, delay, gasLimit);
    }

    function finish() private {

      //  lastWinTicketNumber = (random() << 2) / 10000; //  uncomment when goline, ticket number is from 0-999999
        lastWinTicketNumber = (random() << 2) / 1000000000;// remove when go line, current ticket number is 0-9
        uint winnerCount = rounds[_roundId].buyerTicketNumbers[lastWinTicketNumber].length;

        rounds[_roundId].winPrize = address(this).balance;
        rounds[_roundId].finishBlock = block.number;
        rounds[_roundId].winNumber = lastWinTicketNumber;
        rounds[_roundId].endTime = uint48(now);
        if (winnerCount > 0) {
            uint256 totalPaid = address(this).balance - (address(this).balance * (founderEarnPercent + applicationFeePecent)) / 100; // need to pay for founder and keep 2 percent to run contract
            uint founderEarns = address(this).balance * founderEarnPercent / 100;
            uint256 balanceToDistribute = totalPaid / winnerCount;
            for (uint i = 0; i < winnerCount; i++) {
                rounds[_roundId].buyerTicketNumbers[lastWinTicketNumber][i].transfer(balanceToDistribute);
            }
            FOUNDER.transfer(founderEarns);
            _state = State.Initializing;
            FoundWinnerEvent(_roundId, address(this).balance );
        } else {
            initNewRound();
            NotFoundWinnerEvent(_roundId);
        }
    }

    function random() private view returns (uint32) {
        return uint32(uint256(keccak256(_lastBuyBlockHash,
                                keccak256(block.blockhash(block.number),
                                    keccak256(block.timestamp, block.difficulty)))));
    }

    function __callback(bytes32 queryId) public isCbAddress {
        require(_state == State.Open || _state == State.Processing);
         if(_state == State.Open) {
             _state = State.Processing;
             schedule();
         } else {
             require(block.number >= closedBlockNumber + timeToDeterminingWinner/15);
             finish();
         }

    }

    function stopRound() public onlyOwner {
        //  can stop  contract if no user buys ticket
        require(rounds[_roundId].boughtAmount == 0);
        require(_state == State.Open);
        _state = State.Closed;
        CloseRoundEvent();
    }


    function kill() public onlyOwner {
        //  can destroy contract if no user buys ticket
        require(_state == State.Initializing || _state == State.Closed);
        selfdestruct(owner);
    }

}
