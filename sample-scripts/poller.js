const express = require('express');
const { SorobanRpc, xdr, Address, nativeToScVal, scValToNative, TransactionBuilder, Contract, StrKey, Keypair, Networks } = require('@stellar/stellar-sdk');
const { execSync } = require('child_process');

const app = express();
const PORT = process.env.PORT || 3000;
const RPC_URL = process.env.RPC_URL;
const CONTRACT_ID = 'CC5TSJ3E26YUYGYQKOBNJQLPX4XMUHUY7Q26JX53CJ2YUIZB5HVXXRV6';
const rpc = new SorobanRpc.Server(RPC_URL);

// If you specify a valid signer key here, the code will submit tx via SDK
// otherwise it will use Stellar CLI
const signer = "SECRET...KEY";

let data = {
    hash: null,
    block: 0,
    difficulty: 0,
};

async function getContractData() {
    let result;
    try {
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

function cliSubmit(data) {
        const command = `PATH=$PATH:/root/.cargo/bin stellar contract invoke --id ${CONTRACT_ID} \
        --source ADMIN --network MAINNET -- mine --hash ${data.hash} --message ${data.message} --nonce ${data.nonce} \
        --miner ${data.address}`;
    const output = execSync(command, { encoding: 'utf8' });
    return { command, output };
}

async function sdkSubmit(data) {
    const account = await rpc.getAccount(data.address);
    const contract = new Contract(CONTRACT_ID);
    let transaction = new TransactionBuilder(account, { fee: '10000000', networkPassphrase: Networks.PUBLIC })
        .addOperation(contract.call("mine",
            xdr.ScVal.scvBytes(Buffer.from(data.hash, "hex")),
            xdr.ScVal.scvString(data.message),
            nativeToScVal(data.nonce, { type: "u64" }),
            new Address(data.address).toScVal()))
        .setTimeout(300)
        .build();
    transaction = await rpc.prepareTransaction(transaction);
    transaction.sign(Keypair.fromSecret(signer));
    return await rpc.sendTransaction(transaction);
}

app.get('/data', (_req, res) => {
    res.json(data);
});

app.get('/submit', async(req, res) => {
    const { hash, nonce, message, address } = req.query;
    try {
        if (StrKey.isValidEd25519SecretSeed(signer)) {
            res.json({ result : await sdkSubmit({ hash, nonce, message, address }) });
        } else {
            res.json({ result : cliSubmit({ hash, nonce, message, address }) });
        }      
    } catch (error) {
        console.error('Failed to execute command:', error.message);
        res.status(500).send(error.message);
    }
});

app.listen(PORT, () => {
    console.log(`Server running on ${PORT}`);
    fetchContent(1000);
});
