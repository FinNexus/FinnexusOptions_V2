pragma solidity =0.5.16;
import "../PhoenixModules/modules/SmallNumbers.sol";

contract testSmallNumbers {
    uint256 private test1;
    int256 private test2;
    event DebugEvent(address indexed sender,uint256 _test1,int256 _test2);
    function testExp(int256 value) public{
        test1 = SmallNumbers.exp(value);
        emit DebugEvent(msg.sender,test1,test2);
    } 
    function testPow(uint256 x,uint256 y) public pure returns (uint256){
        return SmallNumbers.pow(x, y);
    }
    function testNormSDist(int256 value) public pure returns (int256){
        return SmallNumbers.normsDist(value);
    } 
}