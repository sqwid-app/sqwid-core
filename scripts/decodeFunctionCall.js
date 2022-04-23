async function main() {
    functionName = "setNftContractAddress";
    encodedData = "0xda31d640000000000000000000000000e3c13dec43ad58f95f964acd0461450ad0c35649";

    Marketplace = await hre.reef.getContractFactory("SqwidMarketplace");
    decodedFunctionCall = Marketplace.interface.decodeFunctionData(functionName, encodedData);
    console.log("Decoded function call:", decodedFunctionCall);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
