const express = require('express');
const { SorobanRpc, xdr, Address, nativeToScVal, scValToNative } = require('@stellar/stellar-sdk');
const { execSync } = require('child_process');

const app = express();
const PORT = process.env.PORT || 3000;
const RPC_URL = process.env.RPC_URL;
const CONTRACT_ID = 'CC5TSJ3E26YUYGYQKOBNJQLPX4XMUHUY7Q26JX53CJ2YUIZB5HVXXRV6';

let data = {
    hash: null,
    block: 0,
    difficulty: 0,
};

async function getContractData() {
    let result;
    try {
        const rpc = new SorobanRpc.Server(RPC_URL);
        const { val } = await rpc.getContractData(
            CONTRACT_ID,
            xdr.ScVal.scvLedgerKeyContractInstance()
        );        
        
        val.contractData()
            .val()
            .instance()
            .storage()
            ?.forEach((entry) => {
                result = scValToNative(entry.val());
            });

        const coreDataLedgerKey = xdr.LedgerKey.contractData(
            new xdr.LedgerKeyContractData({
                contract: new Address(CONTRACT_ID).toScAddress(),
                key: xdr.ScVal.scvVec([xdr.ScVal.scvSymbol("Block"),
                    nativeToScVal(Number(result.current), { type: "u64" })]),
                durability: xdr.ContractDataDurability.persistent(),
            })
        );
        const blockData = await rpc.getLedgerEntries(coreDataLedgerKey);
        const entry = blockData.entries?.[0];
        if (entry) {
            result.hash = scValToNative(entry.val?._value.val())?.hash?.toString('base64');
        }

    } catch (error) {
        console.error("Error:", error);
    }   
    return result;
}

async function fetchContent(delay) {
    while (true) {
        const result = await getContractData();
        if (!result?.current) {
            await new Promise(resolve => setTimeout(resolve, delay));
            continue;
        }
        const block = Number(result.current);
        if (block !== data.block || result.hash !== data.hash) {
            Object.assign(data, {
                hash: result.hash,
                difficulty: result.difficulty,
                block
            });
            console.log(`Updated: ${data.block} ${data.difficulty} ${data.hash}`);
        }
        await new Promise(resolve => setTimeout(resolve, delay));
    }
}

function submit(data) {
    // I run the server on another machine to keep my private keys off the mining one
    // but the submit endpoint can also be replaced with a direct call to the CLI in the miner.sh file
    // Alternativaly you can also submit via the Stellar SDK directly.
    const command = `PATH=$PATH:/root/.cargo/bin stellar contract invoke --id ${CONTRACT_ID} \
        --source ADMIN --network MAINNET -- mine --hash ${data.hash} --message ${data.message} --nonce ${data.nonce} \
        --miner ${data.address}`;
    console.log(command);
    try {
        const output = execSync(command, { encoding: 'utf8' });
        console.log('Command:', output);
    } catch (error) {
        console.error('Failed:', error.message);
    }
    return command;
}

app.get('/data', (_req, res) => {
    res.json(data);
});

app.get('/submit', (req, res) => {
    const { hash, nonce, message, address } = req.query;
    res.json({ result : submit({ hash, nonce, message, address }) });
});

app.listen(PORT, () => {
    console.log(`Server running on ${PORT}`);
    fetchContent(1000);
});
