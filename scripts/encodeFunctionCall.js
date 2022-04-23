async function main() {
    functionName = "setNftContractAddress";
    params = ["0xE3c13deC43Ad58F95f964Acd0461450AD0C35649"];

    Marketplace = await hre.reef.getContractFactory("SqwidMarketplace");
    encodedFunctionCall = Marketplace.interface.encodeFunctionData(functionName, params);
    console.log("Encoded function call:", encodedFunctionCall);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
