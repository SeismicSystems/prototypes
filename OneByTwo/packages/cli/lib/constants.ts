import { join } from "path";

const CHAIN_ID = "31337";
const CONTRACT_NAME = "Walnut";
const CONTRACT_DIR = join(__dirname, "../../contracts");

const BROADCAST_FILE = join(
    CONTRACT_DIR,
    "broadcast",
    `${CONTRACT_NAME}.s.sol`,
    CHAIN_ID,
    "run-latest.json",
);
const ABI_FILE = join(
    CONTRACT_DIR,
    "out",
    `${CONTRACT_NAME}.sol`,
    `${CONTRACT_NAME}.json`,
);

export { BROADCAST_FILE, ABI_FILE };
