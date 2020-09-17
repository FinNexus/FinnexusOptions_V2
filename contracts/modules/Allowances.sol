pragma solidity =0.5.16;
import './Ownable.sol';
/**
 * @dev Contract module which provides a basic access control mechanism, where
 * each operator can be granted exclusive access to specific functions.
 *
 */
contract Allowances is Ownable {
    mapping (address => uint256) internal allowances;
    bool internal bValid = true;
    /**
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public onlyOwner{
        allowances[spender] = amount;
    }

    function setValid(bool _bValid) public onlyOwner{
        bValid = _bValid;
    }
    function checkAllowance(address spender, uint256 amount) internal view{
        require((!bValid) || allowances[spender] >= amount,"Allowances : user's allowance is unsufficient!");
    }
    modifier sufficientAllowance(address spender, uint256 amount){
        require((!bValid) || allowances[spender] >= amount,"Allowances : user's allowance is unsufficient!");
        _;
    }
}