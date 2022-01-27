const { expect } = require("chai");

exports.getBalance = async (reefToken, address, name) => {
    const balance = await reefToken.balanceOf(address);
    if (name == "market") console.log(balance);
    const balanceFormatted = Number(ethers.utils.formatUnits(balance.toString(), "ether"));
    console.log(`\t\tBalance of ${name}:`, balanceFormatted);

    return balanceFormatted;
};

exports.formatBigNumber = (bigNumber) => {
    return Number(ethers.utils.formatUnits(bigNumber.toString(), "ether"));
};

exports.throwsException = async (promise, message) => {
    try {
        await promise;
        assert(false);
    } catch (error) {
        expect(error.message).contains(message);
    }
};

exports.logEvents = async (promise) => {
    const tx = await promise;
    const receipt = await tx.wait();

    let msg = "No events for this tx";
    if (receipt.events) {
        const eventsArgs = [];
        receipt.events.forEach((event) => {
            if (event.args) {
                eventsArgs.push(event.args);
            }
        });
        msg = eventsArgs;
    }
    console.log(msg);
};

exports.delay = (ms) => new Promise((res) => setTimeout(res, ms));
