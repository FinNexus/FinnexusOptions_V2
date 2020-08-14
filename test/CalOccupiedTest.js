const OptionsManagerV2 = artifacts.require("OptionsManagerV2");
const OptionsPool = artifacts.require("OptionsPoolTest");
const ImpliedVolatility = artifacts.require("ImpliedVolatility");
const OptionsPrice = artifacts.require("OptionsPrice");
let FNXCoin = artifacts.require("FNXCoin");
let FNXMinePool = artifacts.require("FNXMinePool");
let month = 30*60*60*24;
let collateral0 = "0x0000000000000000000000000000000000000000";
const BN = require("bn.js");
let testFunc = require("./testFunction.js")
contract('OptionsManagerV2', function (accounts){
    it('OptionsManagerV2 add collateral', async function (){
        let OptionsManger = await OptionsManagerV2.deployed();
        let options = await OptionsPool.deployed();
//        let ivInstance = await ImpliedVolatility.at("0x54E8BB9dEC82B695C0Fa977070e74a06BE68001d");
//        let iv = await ivInstance.calculateIv(month,10000000000);
//        console.log(iv[0].toString(10),iv[1].toString(10))
//        let optionPrice = await OptionsPrice.deployed();
//        let temp = await optionPrice.getOptionsPrice_iv(20000000000,20000000000,month,iv[0],iv[1],0);
//        console.log(temp.toString(10))
        let fnx = await FNXCoin.deployed();
        let tx = await OptionsManger.addWhiteList(collateral0);
        tx = await OptionsManger.addWhiteList(fnx.address);
        await options.addUnderlyingAsset(1);
        await OptionsManger.addWhiteList(fnx.address); 
        await options.addExpiration(month);      
        let minePool = await FNXMinePool.deployed();
        let mineInfo = await minePool.getMineInfo(collateral0);
        console.log (mineInfo);
        mineInfo = await minePool.getMineInfo(fnx.address);
        console.log (mineInfo);
        for (var i=0;i<10;i++){
            for (var j=0;j<5;j++){
                OptionsManger.addCollateral(collateral0,1000000000000000,{value : 1000000000000000});
                OptionsManger.addCollateral(collateral0,1000000000000000,{value : 1000000000000000});
                OptionsManger.addCollateral(collateral0,1000000000000000,{value : 1000000000000000});
                OptionsManger.addCollateral(collateral0,1000000000000000,{value : 1000000000000000});
                OptionsManger.buyOption(collateral0,1000000000000000,9150*1e8,1,month,10000000000,0,{value : 1000000000000000});
                OptionsManger.buyOption(collateral0,1000000000000000,8250*1e8,1,month,10000000000,0,{value : 1000000000000000});
                OptionsManger.buyOption(collateral0,1000000000000000,9257*1e8,1,month,10000000000,0,{value : 1000000000000000});
                OptionsManger.buyOption(collateral0,1000000000000000,9251*1e8,1,month,10000000000,0,{value : 1000000000000000});
                OptionsManger.buyOption(collateral0,1000000000000000,11250*1e8,1,month,10000000000,0,{value : 1000000000000000});
                OptionsManger.buyOption(collateral0,1000000000000000,9253*1e8,1,month,10000000000,0,{value : 1000000000000000});
                OptionsManger.buyOption(collateral0,1000000000000000,9260*1e8,1,month,10000000000,0,{value : 1000000000000000});

                OptionsManger.buyOption(collateral0,1000000000000000,11050*1e8,1,month,10000000000,1,{value : 1000000000000000});
                OptionsManger.buyOption(collateral0,1000000000000000,9056*1e8,1,month,10000000000,1,{value : 1000000000000000});
        //        console.log(tx);
                await OptionsManger.buyOption(collateral0,200000000000000,9258*1e8,1,month,10000000000,1,{value : 200000000000000});
        //        console.log(tx);
            }
            await calculateNetWroth(options,OptionsManger,fnx);
            return;
        }
     });
});
async function calculateNetWroth(options,OptionsManger,fnx){
    let whiteList = [collateral0,fnx.address];
    optionsLen = await options.getOptionCalRangeAll(whiteList);
    console.log(optionsLen[0].toString(10),optionsLen[1].toString(10),optionsLen[2].toString(10),optionsLen[4].toString(10));

    let result =  await options.calculatePhaseOccupiedCollateral(optionsLen[4],optionsLen[0],optionsLen[4]);
    console.log(result[0].toString(10),result[1].toString(10));
    let tx = await options.setOccupiedCollateral();
//    result =  await options.calRangeSharedPayment(optionsLen[4],optionsLen[2],optionsLen[4],whiteList);
//    console.log(result[0][0].toString(10),result[0][1].toString(10));

//                return;q
    tx = await OptionsManger.calSharedPayment();
    console.log(tx);
}