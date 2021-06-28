# ERC20Tweetable

A quest to create an ERC20-compliant token in the fewest number of bytes!

## WTF?

I want to be able to tweet the entire bytecode of an ERC20 token. No, I don't mean this:

```
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

First, by writing assembly in a Solidity contract's fallback function. You can find the source for that in [`ERC20Tweetable.sol`](#ERC20Tweetable.sol).

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