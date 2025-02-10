import dotenv from "dotenv";
dotenv.config();

import {
    createShieldedWalletClient,
    getShieldedContract,
} from "seismic-viem";
import { http } from "viem";
import { anvil } from "viem/chains";

import { BROADCAST_FILE, ABI_FILE } from "../lib/constants";
import { readContractAddress, readContractABI, sleep } from "../lib/utils";

async function main(): Promise<void> {
    const walletClient = await createShieldedWalletClient({
        chain: anvil,
        transport: http(process.env.RPC_URL),
        privateKey: process.env.ALICE_PRIVKEY as `0x${string}`,
    });
    const contract = getShieldedContract({
        abi: readContractABI(ABI_FILE),
        address: readContractAddress(BROADCAST_FILE),
        client: walletClient,
    });

    await contract.write.reset();
    await sleep(500);

    await contract.write.shake();
    await sleep(500);

    await contract.write.hit();
    await sleep(500);

    await contract.write.shake();
    await sleep(500);

    await contract.write.shake();
    await sleep(500);

    await contract.write.hit();
    await sleep(4000);

    console.log(">> RESULT: ", await contract.read.look());
}

main();
