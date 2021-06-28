# ERC20Tweetable

A quest to create an ERC20-compliant token in the fewest number of bytes!

## WTF?

I want to be able to tweet the entire bytecode of an ERC20 token. No, I don't mean this:

```solidity
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract YourToken is ERC20 {
  constructor() ERC20("Your Token", "YOUR") public {
    _mint(msg.sender,
      10000000000 * (10**uint256(decimals())));
  }
}
```

(Source: https://twitter.com/pi0neerpat/status/1407426157855657986)

No importing from OpenZeppelin, just raw bytecode, optimized to the limit for space 😎

## How TF?

First, by writing assembly in a Solidity contract's fallback function. You can find the source for that in [`ERC20Tweetable.sol`](/ERC20Tweetable.sol).

The assembly has been pruned repeatedly until the code features only 2 if statements, and no other branches whatsoever!

I did this by condensing ERC20 to a set of 7 operations required for ERC20 compliance:
- Balance / allowance requirements:
    - `require(transferAmt < fromBalance)`
    - `require(transferAmt < approvalAmt)`
- Storage writes:
    - `sstore(fromBalanceSlot, sload(fromBalanceSlot) - transferAmt)`
    - `sstore(toBalanceSlot, sload(toBalanceSlot) + transferAmt)`
    - `sstore(approvalSlot, approvalAmt)`
- Transfer or Approval event log:
    - `log3(amtPointer, 32, sload(eventSig), logFrom, logTo)`
- Return value

I removed branches by solving for all of the above variables, and using the first byte of the function selector to assign values to each variable. Example:

```solidity
// 1 if func is transfer; 0 otherwise
let isTransfer := eq(func, 0xA9)
// 1 if func is transferFrom; 0 otherwise
let isTransferFrom := eq(func, 0x23)
// 1 if func is approve; 0 otherwise
let isApprove := eq(func, 0x09)

/**
 * Set transferAmt:
 * transfer: p1
 * transferFrom: p2
 * approve: 0
 */
let transferAmt := or(
  mul(p1, isTransfer),
  mul(mload(0x80), isTransferFrom)
)
```

Some additional optimization of the runtime bytecode comes from storing a few important values in the constructor:
```solidity
    constructor () {
        assembly {
            sstore(2, 1) // Store "true" at slot 2
            sstore(3, 1000) // Set totalSupply at slot 3
            sstore(4, not(0)) // Set max uint at slot 4

            // give msg.sender total balance
            mstore(0, caller())
            sstore(keccak256(0, 32), 1000)

            // Store Transfer and Approval event topics:
            sstore(1, 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef)
            sstore(0, 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925)
        }
    }
```

Compiling `ERC20Tweetable.sol` produces 266 bytes of runtime bytecode:

```json
{
    "contracts": {
        "ERC20Tweetable.sol:ERC20Tweetable": {
            "bin-runtime": "6080604052348015600f57600080fd5b503660046000373360205236600460403760003560001a602060002060605160a98314602384146009851460708614850260dd8714604080200217601887146003021795508160805102838502178160406020200283604060002002178460021b1780548488028660208020021785602060602002878a0217985084871781548581108685101715609f57600080fd5b8b60e6578581038355858b54018b55868a02888786030217898502178555600051888a1754898c02848302178a8302853302178260208d60071b8860600217a3505060029b505b505050505050505050505080546000525060206000f3fea164736f6c6343000805000a"
        }
    },
    "version": "0.8.5+commit.a4f2e591.Linux.g++"
}
```

Once I got the assembly looking good, I moved this out of Solidity and into a raw Solidity assembly file ([`ERC20TweetableASM.txt`](/ERC20TweetableASM.txt)). `solc` likes to add all kinds of junk to `.sol` files, so this removed some unnecessary memory allocation from the start, as well as metadata from the end. It also appears to be slightly better optimized.

Assembling this (using `solc --assemble`) produces 238 bytes of runtime bytecode. After stripping off a bunch of useless stack cleanup, we're left with a final bytecode of 224 bytes! Here it is:

```
3660046000373360205236600460403760003560001a602060002060605160a98314602384146009851460708614850260dd87146040604020021760188714600302178260805102848602178260406020200284604060002002178560040217805484880286848303021787820217868a02886020602020021787602060602002898c0217878a1786835410878610171560995760006000fd5b87151560d557868354038355868254018255838655898c028160005102178a60005102823302178b8d175460208d6080028560600217a3600297505b875460005260206000f3
```

## Can I use it?

Yes, but you absolutely shouldn't. Aside from not supporting common, optional ERC20 methods (`name`, `symbol`, `decimals`), this is entirely for fun and using it may result in death.

If this doesn't deter you, you can use [`Deployer.sol`](/Deployer.sol), which takes care of the constructor and already includes the minimized 224-bytes bytecode.

## Tweeting an ERC20

224 bytes is actualy 548 characters, so we can't tweet the raw hex. To meet the character limit, we can encode the bytecode using base85. I used this online converter: [cryptii](https://cryptii.com/pipes/hex-to-ascii85). Passing in the minimized bytecode, we get exactly 280 characters back:

```
2IHYq!&l]A+At+*"COJR?iW&l!#f5f?iV<W?r:=2K+q]<KG7f#KbRp6L(o=C@,6SP?pJ*b+9E?e(l&f5!s09j@";)UKSBOEJm^iO+<U`=?pJ*"+9E@5?j$NIJ5h2X!euA\!s09oJcZaCM?8TA+CH<7!Z-W"+CJS"!f;j;(PdkaL4`G:LP??V'k!G2?iXR7rEG$l'k#QnL4`G-K2mYX;uqSNK8*B_MunQ<!)We6MI6E]!eN30(Q47h<+$i.@"8<4?sj$PUL4.i:g8]S?iX)4+CG3@
```

And that's just short enough for a [tweet](https://twitter.com/wadeAlexC/status/1409608216103854080)!
