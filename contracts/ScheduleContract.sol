pragma solidity ^0.4.21;
contract Ownable {

    address public owner;


    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    function Ownable() public {
        owner = msg.sender;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

}
contract ScheduleContract is Ownable {

    event ScheduledEvent(address indexed target, bytes32  indexed queryId, uint indexed timestamp, uint gasLimit);
    uint gasprice = 20000000000;
    address public cbAddress = 0x911EAc91a26019F968bBBA2a7b7aaa9aFa12aB3d;
    bytes32[] dsources;
    mapping (address => uint) reqc;

    function ScheduleContract() {

    }
    modifier costs(uint gaslimit) {
        uint price = gasprice * gaslimit;
        if (msg.value >= price){
            uint diff = msg.value - price;
            if (diff > 0) msg.sender.transfer(diff);
            _;
        } else throw;
    }


    function setCbAddress(address callbackAddress) onlyOwner {
        cbAddress= callbackAddress;
    }

    function getPrice(uint _gaslimit) view returns(uint256 gasPrice) {
        return gasprice * _gaslimit;
    }
    function getGasPrice() public view returns(uint256) {
        return gasprice;
    }
    function setGasPrice() public onlyOwner payable {
        require(msg.value > 10000000000 wei);
        gasprice = msg.value;
    }
    function withdrawFunds(address _addr) onlyOwner {
        _addr.transfer(address(this).balance);
    }
    function schedule(uint _timestamp, uint256 _gaslimit) payable  costs(_gaslimit) returns (bytes32 _id){

        if ((_timestamp > now + 3600*24*60) || (_gaslimit > block.gaslimit)) throw;
        _id = keccak256(this, msg.sender, reqc[msg.sender]);
        reqc[msg.sender]++;
        ScheduledEvent(msg.sender, _id, _timestamp, _gaslimit);
    }

}
