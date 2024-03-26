import {
  sum,
  div,
  addToCallback,
  CircuitValue,
  constant,
  witness,
  mul,
  add,
  checkLessThan,
  getReceipt,
  checkEqual,
  mulAdd,
  log,
  selectFromIdx,
  sub,
  isLessThan,
  isZero,
  or,
  mod,
  getHeader,
  rangeCheck,
  isEqual,
  and
} from "@axiom-crypto/client";

/// For type safety, define the input types to your circuit here.
/// These should be the _variable_ inputs to your circuit. Constants can be hard-coded into the circuit itself.
export interface CircuitInputs {
  blockNumbers: CircuitValue[];
  txIdxs: CircuitValue[];
  logIdxs: CircuitValue[];
  numClaims: CircuitValue;
}

export const defaultInputs = {
  "blockNumbers": [5203518, 5203518, 5203518, 5203518, 5203518, 5203518, 5203518, 5203518, 5203518],
  "txIdxs": [112, 112, 112, 112, 112, 112, 112, 112, 112],
  "logIdxs": [1, 1, 1, 1, 1, 1, 1, 1, 1],
  "numClaims": 1
}

export const circuit = async ({
  blockNumbers,
  txIdxs,
  logIdxs,
  numClaims
}: CircuitInputs) => {

  const MAX_CLAIMS = 9;
  const ENS_CONTRACT_ADDR = "0xFED6a969AaA60E4961FCD3EBF1A2e8913ac65B72";
  const RENEWAL_EVENT_SCHEMA = "0x3da24c024582931cfaf8267d8ed24d13a82a8068d5bd337d30ec45cea4e506ae";

  let numClaimsVal = Number(numClaims.value());
  if (numClaimsVal > MAX_CLAIMS) {
    throw new Error("Too many claims");
  }

  checkLessThan(0, numClaims)
  checkLessThan(numClaims, MAX_CLAIMS + 1)

  if (blockNumbers.length !== MAX_CLAIMS || txIdxs.length !== MAX_CLAIMS || logIdxs.length !== MAX_CLAIMS) {
    throw new Error("Incorrect number of claims (make sure every array has `MAX_CLAIMS` claims)");
  }

  let claimIds: CircuitValue[] = [];
  let inRange: CircuitValue[] = [];
  for (let i = 0; i < MAX_CLAIMS; i++) {
    const id_1 = mulAdd(blockNumbers[i], BigInt(2 ** 64), txIdxs[i]);
    const id = mulAdd(id_1, BigInt(2 ** 64), logIdxs[i]);
    const isInRange = isLessThan(i, numClaims, "20");
    inRange.push(isInRange);
    const idOrZero = mul(id, isInRange);
    claimIds.push(idOrZero);
  }

  for (let i = 1; i < MAX_CLAIMS; i++) {
    const isLess = isLessThan(claimIds[i - 1], claimIds[i]);
    const isLessOrNotInRange = or(isLess, isZero(claimIds[i]));
    checkEqual(isLessOrNotInRange, 1);
  }

  let totalValue = witness(0);

  const splitHexIntoBytes = (hexString) => {
    const bytes: string[] = [];
    for (let i = 0; i < 64; i += 2) {
      bytes.push("0x" + hexString.substring(i, i + 2));
    }
    return bytes;
  }

  let referrerId = constant(0);
  //event: https://sepolia.etherscan.io/tx/0xcae128087515abfcff4731ccd815f2c19611f882842c030af1e1bdb6e485af97#eventlog
  //NameRenewed (string name, index_topic_1 bytes32 label, uint256 cost, uint256 expires)
  for (let i = 0; i < MAX_CLAIMS; i++) {
    let expires = (await getReceipt(blockNumbers[i], txIdxs[i]).log(logIdxs[i]).data(2, RENEWAL_EVENT_SCHEMA)).toCircuitValue();
    let referrerIdFromExpires = mod(expires, 86400, "50", "20");

    if (i === 0) {
      referrerId = referrerIdFromExpires;
    }
    else {
      checkEqual(referrerId, referrerIdFromExpires);
    }

    const emitter = (await getReceipt(blockNumbers[i], txIdxs[i]).log(logIdxs[i]).address()).toCircuitValue();
    checkEqual(ENS_CONTRACT_ADDR, emitter);

    let name = await getReceipt(blockNumbers[i], txIdxs[i]).log(logIdxs[i]).data(4);
    let nameLen = (await getReceipt(blockNumbers[i], txIdxs[i]).log(logIdxs[i]).data(3)).toCircuitValue();
    const nameStrBytes = splitHexIntoBytes(name.hex().substring(2));

    let nameBytes = nameStrBytes.map(byte => {
      let x = witness(byte)
      rangeCheck(x, 8)
      return x
    })

    let nameHi = constant(0);
    for (let i = 0; i < 16; i++) {
      nameHi = add(nameHi, mul(BigInt(256 ** (15 - i)), nameBytes[i]))
    }
    checkEqual(name.hi(), nameHi);

    let nameLo = constant(0)
    for (let i = 0; i < 8; i++) {
      const x = BigInt(256 ** (7 - i));
      nameLo = add(nameLo, mul(x, nameBytes[i + 16]))
    }
    checkEqual(div(name.lo(), 2 ** 64, "128", "80"), nameLo);

    // See https://etherscan.io/address/0x253553366da8546fc250f225fe3d25d0c782303b#code#F19#L1 for the ENS strlen function
    // Pseudocode:
    // bytes = name[0..24] //if name byte len is less than 24, the remaining bytes are 0
    // byteLen = len(name)
    // strlen, bytesToSkip = 0
    // for byte in bytes:
    //      if (bytesToSkip == 0 and i < byteLen):
    //          strlen += 1
    //          bytesToSkip = ... // if condition to determine how many chars to skip based on byte
    //      else:
    //          bytesToSkip -= 1       
    let len = witness(0);
    let skip = witness(0);
    for (let i = 0; i < 24; i++) {
      let byte = nameBytes[i];
      let checks = [0x80, 0xe0, 0xf0, 0xf8, 0xfc];
      let isLessThanChecks = checks.map(check => isLessThan(byte, check, "8"))
      let checkSum = sum(isLessThanChecks)

      let inBounds = isLessThan(i, nameLen, "8");
      let shouldNotSkip = isZero(skip);
      let shouldAddLen = and(inBounds, shouldNotSkip);

      let charNumBytesOrZero = mul(sub(6, checkSum), shouldNotSkip)
      skip = add(sub(skip, 1), charNumBytesOrZero)
      len = add(shouldAddLen, len);
    }

    let isFullPrice = isLessThan(4, len, "8");
    let isThree = isEqual(len, 3);
    let isFour = isEqual(len, 4);

    let paid = (await getReceipt(blockNumbers[i], txIdxs[i]).log(logIdxs[i]).data(1)).toCircuitValue();
    let fullPriceOrZero = mul(isFullPrice, paid);

    let threeCharScaledPrice = div(paid, 640 / 5, "80", "10");
    let threePriceOrZero = mul(isThree, threeCharScaledPrice);

    let fourCharScaledPrice = div(paid, 160 / 5, "80", "10");
    let fourPriceOrZero = mul(isFour, fourCharScaledPrice);

    let amount = sum([fullPriceOrZero, threePriceOrZero, fourPriceOrZero]);
    let amountOrZero = mul(amount, inRange[i]);

    totalValue = add(totalValue, amountOrZero);
  }

  const lastClaimId = selectFromIdx(claimIds, sub(numClaims, constant(1)));

  addToCallback(claimIds[0]);
  addToCallback(lastClaimId);
  addToCallback(referrerId);
  addToCallback(totalValue);
};
