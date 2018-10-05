pragma solidity ^0.4.21;
import "./Ownable.sol";

contract ScheduleContract is Ownable {

    event ScheduledEvent(bytes32  indexed queryId, uint indexed timestamp, uint estimatedGas, address indexed target);

    function ScheduleContract(){

    }

    function schedule(uint timestamp, uint256 estimatedGas) payable  returns (bytes32 _id){
            require(timestamp > 0);
            ScheduledEvent(_id, timestamp, estimatedGas, msg.sender);
    }
}
