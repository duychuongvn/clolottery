pragma solidity ^0.4.21;
import "./Ownable.sol";

contract ScheduleContract is Ownable {

    event ScheduledEvent(bytes32  indexed queryId, uint indexed timestamp, uint gasLimit, address indexed target);
    uint gasePrice = 20000000000;
    address public cbAddress;
    bytes32[] dsources;
    mapping (address => uint) reqc;
    function ScheduleContract(){

    }

    function getGasPrice() public view returns(uint256) {
        return gasPrice;
    }
    function setGasPrice() public onlyOwner payable {
        require(msg.value > 1000000000 wei)
        gasPrice = msg.value;
    }

    function schedule(uint _timestamp, uint256 gasLimit) payable  returns (bytes32 _id){
        require(msg.value == gasLimit * gasPrice);
        if ((_timestamp > now+3600*24*60)||(_gaslimit > block.gaslimit)) throw;

        _id = keccak256(this, msg.sender, reqc[msg.sender]);
        reqc[msg.sender]++;
        ScheduledEvent(msg.sender, _id, _timestamp, _datasource, _arg, _gaslimit, addr_proofType[msg.sender], addr_gasPrice[msg.sender]);
        return _id;

            require(msg.value > gasLimit* gasePrice * 3);
            ScheduledEvent(_id, timestamp, gasLimit, msg.sender);
            owner.transfer(msg.value);
    }
}
