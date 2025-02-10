import fs from "fs";

import { Abi } from "viem";

function readContractAddress(broadcastFile: string): `0x${string}` {
    const broadcast = JSON.parse(fs.readFileSync(broadcastFile, "utf8"));
    if (!broadcast.transactions?.[0]?.contractAddress) {
        throw new Error("Invalid broadcast file format");
    }
    return broadcast.transactions[0].contractAddress;
}

function readContractABI(abiFile: string): Abi {
    const abi = JSON.parse(fs.readFileSync(abiFile, "utf8"));
    if (!abi.abi) {
        throw new Error("Invalid ABI file format");
    }
    return abi.abi;
}

function sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

export { readContractAddress, readContractABI, sleep };
