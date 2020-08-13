pragma solidity ^0.4.26;

import "./modules/Ownable.sol";
import "./modules/Fraction.sol";
import "./interfaces/IVolatility.sol";
contract OptionsPrice is ImportVolatility{
    using Fraction for Fraction.fractionNumber;
    constructor (address ivContract) public{
        setVolatilityAddress(ivContract);
    }
    uint256 constant internal Year = 365 days;
    Fraction.fractionNumber internal rate = Fraction.fractionNumber(5,1000);
    //B_S formulas r
    function getRate()public view returns(int256,int256){
        return (rate.numerator,rate.denominator);
    }
    function setRate(int256 numerator,int256 denominator)public onlyOwner{
        rate.numerator = numerator;
        rate.denominator = denominator;
    }
    function getOptionsPrice(uint256 currentPrice, uint256 strikePrice, uint256 expiration,uint32 underlying,uint8 optType)public view returns (uint256){
        (uint256 ivNumerator,uint256 ivDenominator) = _volatility.calculateIv(underlying,optType,expiration,currentPrice,strikePrice);
        Fraction.fractionNumber memory _iv = Fraction.fractionNumber(int256(ivNumerator),int256(ivDenominator));
        if (optType == 0) {
            return callOptionsPrice(currentPrice,strikePrice,expiration,rate,_iv);
        }else{
            return putOptionsPrice(currentPrice,strikePrice,expiration,rate,_iv);
        }
    }
    function getOptionsPrice_iv(uint256 currentPrice, uint256 strikePrice, uint256 expiration,
            uint256 ivNumerator,uint256 ivDenominator,uint8 optType)public view returns (uint256){
        Fraction.fractionNumber memory _iv = Fraction.fractionNumber(int256(ivNumerator),int256(ivDenominator));
        if (optType == 0) {
            return callOptionsPrice(currentPrice,strikePrice,expiration,rate,_iv);
        }else{
            return putOptionsPrice(currentPrice,strikePrice,expiration,rate,_iv);
        }
    }
    function calculateD1D2(uint256 currentPrice, uint256 strikePrice, uint256 expiration,
         Fraction.fractionNumber memory r, Fraction.fractionNumber memory derta) 
            internal pure returns (Fraction.fractionNumber, Fraction.fractionNumber) {
        Fraction.fractionNumber memory d1 = Fraction.fractionNumber(0,1);
        if (currentPrice != strikePrice){
            Fraction.fractionNumber memory lns = Fraction.ln(currentPrice);
            Fraction.fractionNumber memory lnl = Fraction.ln(strikePrice);
            d1 = lns.sub(lnl);
        }
        Fraction.fractionNumber memory derta2 = derta.mul(derta);
        derta2.denominator = derta2.denominator*2;
        derta2 = derta2.add(r);
        derta2 = derta2.mul(Fraction.fractionNumber(int256(expiration),int256(Year)));
        d1 = d1.add(derta2);
        derta2 = Fraction.fractionNumber(int256(expiration*1e10),int256(Year*1e10)).sqrt().mul(derta);
        d1 = d1.div(derta2);
        Fraction.fractionNumber memory d2 = d1.sub(derta2);
        return (d1, d2);
    }

    //L*pow(e,-rT)*(1-N(d2)) - S*(1-N(d1))
    function putOptionsPrice(uint256 currentPrice, uint256 strikePrice, uint256 expiration,
            Fraction.fractionNumber memory r, Fraction.fractionNumber memory derta) 
                internal pure returns (uint256) {
       (Fraction.fractionNumber memory d1, Fraction.fractionNumber memory d2) = calculateD1D2(currentPrice, strikePrice, expiration, r, derta);
        d1 = d1.normsDist();
        d2 = d2.normsDist();
        d1.numerator = (d1.denominator - d1.numerator)*int256(currentPrice);
        d2.numerator = (d2.denominator - d2.numerator)*int256(strikePrice);
        Fraction.fractionNumber memory rt = r.mul(Fraction.fractionNumber(int256(expiration),int256(Year)));
        rt = rt.exp().invert();
        Fraction.fractionNumber memory price = d2.mul(rt);
        price = price.sub(d1);
        return uint256(price.numerator/price.denominator);
    }

    /*
        r := FloatNum{
            big.NewInt(5),
            big.NewInt(1000)}
    */
    //S*N(d1)-L*pow(e,-rT)*N(d2)
    function callOptionsPrice(uint256 currentPrice, uint256 strikePrice, uint256 expiration,
            Fraction.fractionNumber memory r, Fraction.fractionNumber memory derta) 
                internal pure returns (uint256) {
       (Fraction.fractionNumber memory d1, Fraction.fractionNumber memory d2) = calculateD1D2(currentPrice, strikePrice, expiration, r, derta);
        d1 = d1.normsDist();
        d2 = d2.normsDist();
        d1.numerator = d1.numerator*int256(currentPrice);
        d2.numerator = d2.numerator*int256(strikePrice);
        Fraction.fractionNumber memory rt = r.mul(Fraction.fractionNumber(int256(expiration),int256(Year)));
        rt = rt.exp().invert();
        Fraction.fractionNumber memory price = d2.mul(rt);
        price = d1.sub(price);
        return uint256(price.numerator/price.denominator);
    }
}