pragma solidity ^0.4.21;

import "./Ownable.sol";
import "./strings.sol";
import "./safeMath.sol";
contract ScheduleContractInterface {
    address public cbAddress;
    function schedule(uint timestamp, uint256 estimatedGas) payable returns (bytes32 _id);
    function getPrice(uint _gaslimit) view returns(uint256 gasPrice);
}

contract EtherLotteryContract is Ownable {
    uint GAS_LIMIT_DETERMINATION_WINNER = 100000;
    uint GAS_LIMIT_ROUND_CLOSE = 80000;
    uint public MAX_TICKET_NUMER = 999999;
    address public FOUNDER = 0x81029273484ed1167910dd38f7b73000d342f3cf;

    using strings for *;
    event NewRoundOpenEvent();
    event FinishRoundEvent();
    event BuyTicketEvent();
    event CloseRoundEvent();
    event WinTicketEvent(uint32 indexed ticket);
    event NotEnoughFundToInitEvent();
    event FoundWinnerEvent(uint256 roundId, uint256 prize);
    event NotFoundWinnerEvent(uint256 roundId);
    event DeterminingScheduleEvent(bytes32 queryId, uint delay, uint gasLimit);
    event PaidForWinnersEvent(uint48 roundId);

    enum State {Initializing, Open, Processing, Closed, WaitingForPayment}

    State public _state;

    mapping(uint32=> address[]) private buyerTicketNumbers;
    bytes32 private _lastBuyBlockHash;  // the last block hash user buys the ticket before closing a round
    uint  public roundDuration = 600; // default 1 day (will change to 8400)
    uint private timeToDeterminingWinner = 60; // (will change to 300)  wait about 300 seconds before determining the winner
    uint public roundOpenDuration = roundDuration - timeToDeterminingWinner;
    uint256 public ticketPrice = 1000000000000000000; // default 1 ether
    uint256 public underLimitPrize = 2 ether; //  the minimum prize to init a round
    uint256 public totalBalance; // total ether will be paid for the winners, the value will increase when more players buy tickets
    uint8 public founderEarnPercent = 20; // the percentage the founder earns when finish a round
    uint8 public applicationFeePecent = 2;
    uint32 public lastWinTicketNumber;
    uint256 closedBlockNumber; // the block number when closing a round, this is use to prevent user buys ticket at determining the winner time
    uint256 openBlockNumber;
    uint48 public _roundId;
    uint48 private reportedRoundId;
    ScheduleContractInterface scheduledContract;

    mapping(uint=>Round) rounds;
    address[] winnerAddresses;
    mapping(address=>uint) winnerRecords;

    function EtherLotteryContract(address scheduleAddr) {
       scheduledContract = ScheduleContractInterface(scheduleAddr);
    }

    struct Round {
        bool paid;
        uint32 winNumber;
        uint48 startTime;
        uint48 endTime;
        uint256 winPrize;
        uint256 boughtAmount;
        uint256 totalPaid;
        uint256 finishBlock;
        uint256 ticketPrice;
        mapping(address=> uint32[]) userTickets;
        mapping(uint32=> address[]) buyerTicketNumbers;
    }

    modifier isCbAddress() {
        require( msg.sender == owner || msg.sender == scheduledContract.cbAddress());
        _;
    }

    function getWinners() public view returns(address[], uint256[] ) {
        uint256[] memory winnerAmounts = new uint256[](winnerAddresses.length);
        for(uint i= 0; i < winnerAddresses.length; i++) {
          winnerAmounts[i] = winnerRecords[winnerAddresses[i]];
        }
        return (winnerAddresses, winnerAmounts);
    }

    function getCurrentRoundInfo() public view returns(uint roundId,
                                                uint256 ticketPrice,
                                                uint256 startTime,
                                                uint256 endTime,
                                                State state,
                                                uint256 currentPrize) {
        roundId = _roundId;
        uint32 ticketNumber;
        (roundId, ticketPrice, startTime, endTime, state, currentPrize, ticketNumber) =  getRoundInfo(roundId);
    }

    function getRoundInfo(uint _id) public view returns(uint roundId,
        uint256 ticketPrice,
        uint256 startTime,
        uint256 endTime,
        State state,
        uint256 winPrize,
        uint32 ticketNumber) {
        roundId = _id;
        ticketPrice = rounds[_id].ticketPrice;
        startTime = uint256(rounds[_id].startTime);
        endTime = uint256(rounds[_id].startTime + roundDuration);
        state = _state;
        if (_id == _roundId && _state != State.WaitingForPayment ) {
            winPrize = address(this).balance;
        } else {
            winPrize = rounds[_id].winPrize;
            ticketNumber = rounds[_id].winNumber;
        }
    }

    function getUserRecords(address user) public view returns(uint32[] roundIds, string tickets, uint256[] amounts) {
        uint32[] memory _roundIds = new uint32[](_roundId);
        uint256[] memory _amounts = new uint256[](_roundId);
        uint32 myroundId=0;
        for(uint32 i = 0; i <= _roundId;i++ ) {
            if(rounds[i].userTickets[user].length > 0) {
                _roundIds[myroundId] = i;
                _amounts[myroundId] = SafeMath.safeMul(rounds[i].ticketPrice, rounds[i].userTickets[user].length);
                tickets = tickets.toSlice().concat("-R-".toSlice()).toSlice().concat(concatTickets(rounds[i].userTickets[user]).toSlice());
                myroundId++;
            }
        }

        if(myroundId == 0) {
            return (new uint32[](0), "", new uint256[](0));
        }
        roundIds = take(myroundId, _roundIds);
        amounts = take(myroundId, _amounts);
    }

    function concatTickets(uint32[] ticketNumbers) private view returns(string  tickets) {
        for(uint32 i=0; i < ticketNumbers.length; i++) {
            tickets = tickets.toSlice().concat(uint2str(ticketNumbers[i]).toSlice()).toSlice().concat("-T-".toSlice());
        }
    }

    function changeFounder(address newFounder) public onlyOwner {
        require(newFounder != 0x0);
        FOUNDER = newFounder;
    }

    function generateNextRoundId() private returns(uint) {
        return ++_roundId;
    }

    function init() public payable onlyOwner {
        require(_state == State.Initializing || _state == State.Closed);
        require(msg.value + totalBalance >= underLimitPrize);
        totalBalance += msg.value;
        startNewRound();
    }

    function startNewRound() private {
        _state = State.Open;
        generateNextRoundId();
        rounds[_roundId].startTime = uint48(now);
        rounds[_roundId].winPrize = totalBalance;
        rounds[_roundId].ticketPrice = ticketPrice;
        rounds[_roundId].endTime = uint48(now + roundOpenDuration);
        openBlockNumber = block.number;
        schedule();
        emit NewRoundOpenEvent();
    }

    function withdrawFee() public  onlyOwner {
        require(totalBalance > underLimitPrize);
        uint256 fee = (totalBalance-underLimitPrize) * founderEarnPercent / 100;
        require(totalBalance > fee);
        totalBalance -= fee;
        msg.sender.transfer(fee);
    }

    function updateReport() public onlyOwner returns(bool) {
        require(_roundId > 0);
        uint48 lastFinishedRound = _roundId - 1;
        if(_state == State.WaitingForPayment) {
            lastFinishedRound = _roundId;
        }
        for(uint48 i = reportedRoundId; i <= lastFinishedRound; i++) {
          address[] memory roundWinners = rounds[i].buyerTicketNumbers[rounds[i].winNumber];
            if(roundWinners.length > 0) {
              for(uint j = 0; j < roundWinners.length; j++) {
                  if(winnerRecords[roundWinners[j]] == 0) {
                      winnerAddresses.push(roundWinners[j]);
                  }
                  winnerRecords[roundWinners[j]] += rounds[i].totalPaid / roundWinners.length;
              }
            }

        }
        reportedRoundId = lastFinishedRound;
        return true;
    }

    /**

     * Method signature: 0xe1059fe5
     * Length of each ticket must be less than or equals 6
    **/
   function buyTickets(uint32[] ticketNumbers) public payable {

        require(_state == State.Open);
        require(ticketNumbers.length >= 1 && ticketNumbers.length <= 10);// limit maximum 10 tickets per time
        require(ticketNumbers.length * ticketPrice <= msg.value);
        uint256 diff =  msg.value - ticketNumbers.length * ticketPrice;
        if(diff > 0) {
            msg.sender.send(diff);
        }

        uint32[] storage buyTickets = rounds[_roundId].userTickets[msg.sender];
        for(uint i = 0; i < ticketNumbers.length; i++) {
            require(ticketNumbers[i] <= MAX_TICKET_NUMER);
            buyTickets.push(ticketNumbers[i]);
            rounds[_roundId].buyerTicketNumbers[ticketNumbers[i]].push(msg.sender);
        }
        rounds[_roundId].boughtAmount += msg.value;
        _lastBuyBlockHash = block.blockhash(block.number);
        emit BuyTicketEvent();
    }

    function schedule() {

        if(_state == State.Processing) {
            // schedule to determinate the winner
            uint delay = timeToDeterminingWinner;
            uint gasLimit = GAS_LIMIT_DETERMINATION_WINNER;
        } else {
            // schedule to close current round and prepare for determining  winners
            delay = roundOpenDuration;
            gasLimit = GAS_LIMIT_ROUND_CLOSE;
        }

        uint price = scheduledContract.getPrice(gasLimit);
        bytes32 id = scheduledContract.schedule.value(price)(delay, gasLimit);
        emit DeterminingScheduleEvent(id, delay, gasLimit);
    }

    /**
    * Everyone can call this function to send funds to winners
    *
    */
    function transferToWinners() public {
        require(_state == State.WaitingForPayment);
        require(!rounds[_roundId].paid);

        uint winnerCount = rounds[_roundId].buyerTicketNumbers[lastWinTicketNumber].length;
        require(winnerCount > 0);
        // need to pay for founder and keep 2 percent to run contract
        uint256 totalPaid = address(this).balance - (address(this).balance * (founderEarnPercent + applicationFeePecent) / 100);
        uint founderAmount = address(this).balance * founderEarnPercent / 100;
        uint256 balanceToDistribute = totalPaid / winnerCount;
        for (uint i = 0; i < winnerCount; i++) {
            rounds[_roundId].buyerTicketNumbers[lastWinTicketNumber][i].transfer(balanceToDistribute);
        }

        rounds[_roundId].paid = true;
        rounds[_roundId].totalPaid = totalPaid;
        FOUNDER.transfer(founderAmount);
        _state = State.Initializing;
        emit PaidForWinnersEvent(_roundId);

    }

    function finish() private {

      //  lastWinTicketNumber = (random() << 2) % 1000000; //  uncomment when goline, ticket number is from 0-999999
        lastWinTicketNumber = random() % 10;// remove when go line, current ticket number is 0-9

        rounds[_roundId].winPrize = address(this).balance;
        rounds[_roundId].finishBlock = block.number;
        rounds[_roundId].winNumber = lastWinTicketNumber;
        rounds[_roundId].endTime = uint48(now);
        emit WinTicketEvent(lastWinTicketNumber);
        if (rounds[_roundId].buyerTicketNumbers[lastWinTicketNumber].length > 0) {
            _state = State.WaitingForPayment;
            emit FoundWinnerEvent(_roundId, address(this).balance );
        } else {
            startNewRound();
            emit NotFoundWinnerEvent(_roundId);
        }
    }

    function random() private returns (uint32) {
        return uint32(keccak256(block.blockhash(closedBlockNumber),
                          keccak256(_lastBuyBlockHash,
                                keccak256(block.blockhash(block.number),
                                    keccak256(block.timestamp, block.difficulty)))));
    }

    function __callback(bytes32 queryId) public isCbAddress {
        require(_state == State.Open || _state == State.Processing);
         if(_state == State.Open) {
             require(block.number >= openBlockNumber + roundOpenDuration / 15);
             _state = State.Processing;
             closedBlockNumber = block.number;
             schedule();
         } else {
             require(block.number >= closedBlockNumber + timeToDeterminingWinner / 15);
             finish();
         }

    }

    /**
     * Method signature: 0x55b895eb
    **/
    function stopRound() public onlyOwner {
        //  can stop  contract if no user buys ticket
        require(rounds[_roundId].boughtAmount == 0);
        require(_state == State.Open);
        _state = State.Closed;
        emit CloseRoundEvent();
    }


    function kill() public onlyOwner {
        //  can destroy contract if no user buys ticket
        require(_state == State.Initializing || _state == State.Closed);
        selfdestruct(owner);
    }

    function uint2str(uint i) internal view returns (string){
        if (i == 0) return "0";
        uint j = i;
        uint len;
        while (j != 0){
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len - 1;
        while (i != 0){
            bstr[k--] = byte(48 + i % 10);
            i /= 10;
        }
        return string(bstr);
    }
    function take(uint n, uint32[] array) internal returns(uint32[] result) {
        if (n > array.length) {
            return array;
        }
        result = new uint32[](n);
        for (uint i = 0; i < n ; i++) {
            result[i] = array[i];
        }
        return result;
    }

    function take(uint n, uint256[] array) internal returns(uint256[] result) {
        if (n > array.length) {
            return array;
        }
        result = new uint256[](n);
        for (uint i = 0; i < n ; i++) {
            result[i] = array[i];
        }
        return result;
    }

}
