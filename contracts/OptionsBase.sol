pragma solidity ^0.4.26;
import "./modules/SafeMath.sol";
import "./modules/Managerable.sol";
import "./interfaces/IFNXOracle.sol";
import "./modules/underlyingAssets.sol";
import "./interfaces/IVolatility.sol";
import "./modules/tuple64.sol";
contract OptionsBase is UnderlyingAssets,Managerable,ImportOracle,ImportVolatility {
    using whiteListUint256 for uint256[];
    using SafeMath for uint256;
    struct OptionsInfo {
        uint64     optionID;
        address     owner;
        uint8   	optType;    //0 for call, 1 for put
        uint32		underlying;
        uint256		expiration;
        uint256     strikePrice;
        uint256     amount;
    }

    struct OptionsInfoEx{
        uint256		 createdTime;
        address      settlement;
        uint256      tokenTimePrice;
        uint256      underlyingPrice;
        uint256      fullPrice;
        uint256      ivNumerator;
        uint256      ivDenominator;
    }
    //options information
    OptionsInfo[] internal allOptions;
    mapping(uint256=>OptionsInfoEx) internal optionExtraMap;
    uint256 constant internal calDecimals = 1e18;
    //user options balances
    mapping(address=>uint256[]) internal optionsBalances;
    //expiration whitelist
    uint256[] internal expirationList;
    uint256 internal burnTimeLimit = 1 hours;


    event CreateOption(address indexed owner,uint256 indexed optionID,uint8 optType,uint32 underlying,uint256 expiration,uint256 strikePrice,uint256 amount);
    event BurnOption(address indexed owner,uint256 indexed optionID,uint amount);
    event DebugEvent(uint256 value1,uint256 value2,uint256 value3);
    constructor () public{
        expirationList =  [1 days,3 days, 7 days, 10 days, 15 days, 30 days,90 days];
        underlyingAssets = [1,2];
    }
    function getBurnTimeLimit()public view returns(uint256){
        return burnTimeLimit;
    }
    function setBurnTimeLimit(uint256 timeLimit)public onlyOwner{
        burnTimeLimit = timeLimit;
    }
    function getUserOptionsID(address user)public view returns(uint256[]){
        return optionsBalances[user];
    }
    function getUserOptionsID(address user,uint256 from,uint256 size)public view returns(uint256[]){
        uint256[] memory userIdAry = new uint256[](size);
        if (from+size>optionsBalances[user].length){
            size = optionsBalances[user].length.sub(from);
        }
        for (uint256 i= 0;i<size;i++){
            userIdAry[i] = optionsBalances[user][from+i];
        }
        return userIdAry;
    }
    function getOptionInfoLength()public view returns (uint256){
        return allOptions.length;
    }
    function getOptionInfoList(uint256 from,uint256 size)public view 
                returns(address[],uint256[],uint256[],uint256[],uint256[]){
        if (from+size>allOptions.length){
            size = allOptions.length.sub(from);
        }
        if (size>0){
            address[] memory ownerArr = new address[](size);
            uint256[] memory typeAndUnderArr = new uint256[](size);
            uint256[] memory expArr = new uint256[](size);
            uint256[] memory priceArr = new uint256[](size);
            uint256[] memory amountArr = new uint256[](size);
            for (uint i=0;i<size;i++){
                OptionsInfo storage info = allOptions[from+i];
                ownerArr[i] = info.owner;
                typeAndUnderArr[i] = (info.underlying << 16) + info.optType;
                expArr[i] = info.expiration;
                priceArr[i] = info.strikePrice;
                amountArr[i] = info.amount;
            }
            return (ownerArr,typeAndUnderArr,expArr,priceArr,amountArr);
        }
    }
    function getOptionInfoListFromID(uint256[] ids)public view 
                returns(address[],uint256[],uint256[],uint256[],uint256[]){
        uint256 size = ids.length;
        address[] memory ownerArr = new address[](size);
        uint256[] memory typeAndUnderArr = new uint256[](size);
        uint256[] memory expArr = new uint256[](size);
        uint256[] memory priceArr = new uint256[](size);
        uint256[] memory amountArr = new uint256[](size);
        for (uint i=0;i<size;i++){
            OptionsInfo storage info = _getOptionsById(ids[i]);
            ownerArr[i] = info.owner;
            typeAndUnderArr[i] = (info.underlying << 16) + info.optType;
            expArr[i] = info.expiration;
            priceArr[i] = info.strikePrice;
            amountArr[i] = info.amount;
        }
        return (ownerArr,typeAndUnderArr,expArr,priceArr,amountArr);
    }
    function getOptionsLimitTimeById(uint256 optionsId)public view returns(uint256){
        require(optionsId>0 && optionsId <= allOptions.length,"option id is not exist");
        return optionExtraMap[optionsId-1].createdTime + burnTimeLimit;
    }
    function getOptionsById(uint256 optionsId)public view returns(uint256,address,uint8,uint32,uint256,uint256,uint256){
        OptionsInfo storage info = _getOptionsById(optionsId);
        return (info.optionID,info.owner,info.optType,info.underlying,info.expiration,info.strikePrice,info.amount);
    }
    function getUnderlyingPrices()internal view returns(uint256[] memory){
        uint256 underlyingLen = underlyingAssets.length;
        uint256[] memory prices = new uint256[](underlyingLen);
        for (uint256 i = 0;i<underlyingLen;i++){
            prices[i] = _oracle.getUnderlyingPrice(underlyingAssets[i]);
        }
        return prices;
    }

    function _createOptions(address from,address settlement,uint256 type_ly_exp,uint256 strikePrice,uint256 optionPrice,
                uint256 amount) internal {
        uint256 optionID = allOptions.length;
        uint8 optType = uint8(tuple64.getValue0(type_ly_exp));
        uint32 underlying = uint32(tuple64.getValue1(type_ly_exp));
        allOptions.push(OptionsInfo(uint64(optionID+1),from,optType,underlying,tuple64.getValue2(type_ly_exp)+now,strikePrice,amount));
        optionsBalances[from].push(optionID+1);
        OptionsInfo memory info = allOptions[optionID];
        setOptionsExtra(info,settlement,optionPrice,strikePrice,underlying);
        emit CreateOption(from,optionID+1,optType,underlying,tuple64.getValue2(type_ly_exp)+now,strikePrice,amount);
    }
    function setOptionsExtra(OptionsInfo memory info,address settlement,uint256 optionPrice,uint256 strikePrice,uint256 underlying) internal{
        uint256 underlyingPrice = _oracle.getUnderlyingPrice(underlying);
        uint256 expiration = info.expiration - now;
        (uint256 ivNumerator,uint256 ivDenominator) = _volatility.calculateIv(info.underlying,info.optType,expiration,underlyingPrice,strikePrice);
        uint256 tokenTimePrice = calDecimals/_oracle.getPrice(settlement);
        optionExtraMap[info.optionID-1]= OptionsInfoEx(now,settlement,tokenTimePrice,underlyingPrice,optionPrice,ivNumerator,ivDenominator);
    }
    function _burnOptions(address from,uint256 id,uint256 amount)internal{
        OptionsInfo storage info = _getOptionsById(id);
        checkEligible(info);
        checkBurnable(info.optionID);
        checkOwner(info,from);
        checkSufficient(info,amount);
        info.amount = info.amount-amount;
        emit BurnOption(from,id,amount);
    }
    function getExerciseWorth(uint256 optionsId,uint256 amount)public view returns(uint256){
        OptionsInfo memory info = _getOptionsById(optionsId);
        checkEligible(info);
        checkSufficient(info,amount);
        uint256 underlyingPrice = _oracle.getUnderlyingPrice(info.underlying);
        uint256 tokenPayback = _getOptionsPayback(info.optType,info.strikePrice,underlyingPrice);
        if (tokenPayback == 0 ){
            return 0;
        } 
        return tokenPayback.mul(amount);
    }
    function _getOptionsPayback(uint8 optType,uint256 strikePrice,uint256 underlyingPrice)internal pure returns(uint256){
        if ((optType == 0) == (strikePrice>underlyingPrice)){ // call
            return 0;
        } else {
            return (optType == 0) ? underlyingPrice - strikePrice : strikePrice - underlyingPrice;
        }
    }
    function _getOptionsById(uint256 id)internal view returns(OptionsInfo storage){
        require(id>0 && id <= allOptions.length,"option id is not exist");
        return allOptions[id-1];
    }
    function checkBurnable(uint256 optionID)internal view{
        require(optionExtraMap[optionID-1].createdTime+burnTimeLimit<now,"option lock limitation is not expired");
    }
    function checkEligible(OptionsInfo memory info)internal view{
        require(info.expiration>now,"option is expired");
    }
    function checkOwner(OptionsInfo memory info,address owner)internal pure{
        require(info.owner == owner,"caller is not the options owner");
    }
    function checkSufficient(OptionsInfo memory info,uint256 amount) internal pure{
        require(info.amount >= amount,"option amount is insufficient");
    }
    function buyOptionCheck(uint256 expiration,uint32 underlying)public view{
        require(isEligibleUnderlyingAsset(underlying) , "underlying is unsupported asset");
        checkExpiration(expiration);
    }
        /**
     * @dev Implementation of add an eligible expiration into the expirationList.
     * @param expiration new eligible expiration.
     */
    function addExpiration(uint256 expiration)public onlyOwner{
        expirationList.addWhiteListUint256(expiration);
    }
    /**
     * @dev Implementation of revoke an invalid expiration from the expirationList.
     * @param removeExpiration revoked expiration.
     */
    function removeExpirationList(uint256 removeExpiration)public onlyOwner returns(bool) {
        return expirationList.removeWhiteListUint256(removeExpiration);
    }
    /**
     * @dev Implementation of getting the eligible expirationList.
     */
    function getExpirationList()public view returns (uint256[]){
        return expirationList;
    }
    /**
     * @dev Implementation of testing whether the input expiration is eligible.
     * @param expiration input expiration for testing.
     */    
    function isEligibleExpiration(uint256 expiration) public view returns (bool){
        return expirationList.isEligibleUint256(expiration);
    }
    function checkExpiration(uint256 expiration) public view{
        return require(isEligibleExpiration(expiration),"expiration value is not supported");
    }
    function _getEligibleExpirationIndex(uint256 expiration) internal view returns (uint256){
        return expirationList._getEligibleIndexUint256(expiration);
    }
    function getFirstOption(uint256 begin,uint256 latestBegin,uint256 end) internal view returns(uint256,uint256){
        uint256 newFirstOption = latestBegin;
        if (begin > newFirstOption){
            //if in other phase, begin != new begin
            return (begin,newFirstOption);
        }
        begin = newFirstOption;
        for (;begin<end;begin++){
            OptionsInfo storage info = allOptions[begin];
            if(info.expiration<now || info.amount == 0){
                continue;
            }
            break;
        }
        //if in first phase, begin = new begin
        return (begin,begin);
    }
    function calOptionsCollateral(OptionsInfo memory option,uint256 underlyingPrice)internal view returns(uint256){
        if (option.expiration<=now || option.amount == 0){
            return 0;
        }
        uint256 totalOccupied = _getOptionsWorth(option.optType,option.strikePrice,underlyingPrice).mul(option.amount);
        return totalOccupied;
    }
    function _getOptionsWorth(uint8 optType,uint256 strikePrice,uint256 underlyingPrice)internal pure returns(uint256){
        if ((optType == 0) == (strikePrice>underlyingPrice)){ // call
            return strikePrice;
        } else {
            return underlyingPrice;
        }
    }
    function getBurnedFullPay(uint256 optionID,uint256 amount) public view returns(address,uint256){
        OptionsInfoEx storage optionEx = optionExtraMap[optionID-1];
        return (optionEx.settlement,optionEx.fullPrice.mul(optionEx.tokenTimePrice).mul(amount)/calDecimals);
    }
}