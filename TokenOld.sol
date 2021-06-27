// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract A {

    uint totalSupply;

    constructor () {
        assembly {
            sstore(3, 420) // Set totalSupply at slot 0
            sstore(4, not(0)) // Set max uint at slot 3

            mstore(0, caller())
            sstore(keccak256(0, 32), 420)

            // Store function selectors:
            sstore(5, 0xDD62ED3E) // allowance
            sstore(6, 0xA9059CBB) // transfer
            sstore(7, 0x095EA7B3) // approve
            sstore(8, 0x70A08231) // balanceOf
            sstore(9, 0x23B872DD) // transferFrom
            sstore(10, 0x18160DDD) // totalSupply

            // Store Transfer and Approval event topics:
            sstore(1, 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef)
            sstore(0, 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925)
        }
    }

    fallback () external {
        assembly {
            
            /**
             * Max calldata size is transferFrom(addr, addr, uint)
             * selector + params = 4 + 3*32 = 0x64
             * 
             * This copy places function selector at 0x20 - 4 = 0x1c
             * I can access the selector using mload(0)
             * 
             * The other parameters are copied to memory, starting at 0x20
             */
            calldatacopy(0x1C, 0, calldatasize())

            // Place caller at 0x80
            mstore(0x80, caller())

            // Second copy places parameters again, starting at 0xA0
            calldatacopy(0xA0, 4, calldatasize())

            // Overwrite 0xC0 with caller
            mstore(0xC0, caller())

            // Get function selector
            let sel := mload(0)
            // Get first byte of selector
            let sB := byte(28, sel)

            /**
             * Set up stack assuming the call is transfer or approve:
             *
             * Current memory layout:
             * 0x00: [return value]
             * 0x20: [param 0]
             * 0x40: [param 1]
             * 0x60: [param 2]
             * 0x80: [caller]
             * 0xA0: [param 0]
             * 0xC0: [caller]
             * 0xE0: [param 2]
             */
            let fbSlot := keccak256(0x80, 32) // from balance: sha(caller)
            let tbSlot := keccak256(0x20, 32) // to balance: sha(p0)
            let apSlot := keccak256(0x80, 64) // approval slot: sha(caller, p0)
            
            let ptrAmt := 0x40
            let apAmt := mload(ptrAmt)

            let from := mload(0x80)
            let dest := mload(0x20)

            {
                /**
                 * Handle view functions:
                 * token.balanceOf(owner)
                 * token.allowance(owner, spender)
                 * token.totalSupply()
                 */
            
                // 1 if sB is allowance; 0 otherwise
                let isAllowance := eq(sB, 0xDD)
                // 1 if sB is balanceOf; 0 otherwise
                let isBalanceOf := eq(sB, 0x70)
                // 1 if sB is totalSupply; 0 otherwise
                let isTotalSupply := eq(sB, 0x18)
                
                // ret will be 0 if sB is none of these functions
                // otherwise, ret will have some nonzero value
                let ret := or(mul(isTotalSupply, 3),
                    or(
                        mul(isAllowance, keccak256(0x20, 64)),
                        mul(isBalanceOf, tbSlot)
                    )
                )

                // if sB is a view function, load slot and return value
                if ret {
                    doRet(sload(ret))
                }
            }

            /**
             * Handle token.transfer(dest, amt)
             * Selector: 0xA9059CBB
             * The following is equivalent to:
             * 
             * if transfer:
             *   apSlot := 4
             *   apAmt := sload(apSlot)
             */

            // 0 if sB is transfer; 1 otherwise
            let isTransfer := iszero(eq(sB, 0xA9))
            // apSlot is 0 if transfer; no change otherwise
            apSlot := mul(apSlot, isTransfer)
            // apSlot is 4 if transfer; no change otherwise
            apSlot := add(apSlot, mul(4, iszero(isTransfer)))
            // apAmt is 0 if transfer; no change otherwise
            apAmt := mul(apAmt, isTransfer)
            // apAmt is sload(apSlot) if transfer; no change otherwise
            apAmt := add(apAmt, mul(sload(apSlot), iszero(isTransfer)))

            /**
             * Handle token.transferFrom(from, dest, amt)
             * Selector: 0x23B872DD
             * The following is equivalent to:
             * 
             * if transferFrom:
             *   fbSlot := tbSlot
             *   tbSlot := keccak256(0x40, 32)
             *   apSlot := keccak256(0xA0, 64)
             *   ptrAmt := 0x60
             *   apAmt := sub(sload(apSlot), mload(ptrAmt))
             */

            // 0 if sB is transferFrom; 1 otherwise
            let isTransferFrom := iszero(eq(sB, 0x23))

            // fbSlot is 0 if transferFrom; no change otherwise
            fbSlot := mul(fbSlot, isTransferFrom)
            // fbSlot is tbSlot if transferFrom; no change otherwise
            fbSlot := add(fbSlot, mul(tbSlot, iszero(isTransferFrom)))

            // tbSlot is 0 if transferFrom; no change otherwise
            tbSlot := mul(tbSlot, isTransferFrom)
            // tbSlot is keccak256(0x40, 32) if transferFrom; no change otherwise
            tbSlot := add(tbSlot, mul(keccak256(0x40, 32), iszero(isTransferFrom)))

            // apSlot is 0 if transferFrom; no change otherwise
            apSlot := mul(apSlot, isTransferFrom)
            // apSlot is keccak256(0xA0, 64) if transferFrom; no change otherwise
            apSlot := add(apSlot, mul(keccak256(0xA0, 64), iszero(isTransferFrom)))

            // ptrAmt is 0 if transferFrom; no change otherwise
            ptrAmt := mul(ptrAmt, isTransferFrom)
            // ptrAmt is 0x60 if transferFrom; no change otherwise
            ptrAmt := add(ptrAmt, mul(0x60, iszero(isTransferFrom)))

            // apAmt is 0 if transferFrom; no change otherwise
            apAmt := mul(apAmt, isTransferFrom)
            // apAmt is sub(sload(apSlot), mload(ptrAmt)) if transferFrom; no change otherwise
            apAmt := add(apAmt, mul(sub(sload(apSlot), mload(ptrAmt)), iszero(isTransferFrom)))

            let amt := mload(ptrAmt)

            /**
             * Handle token.approve(spender, amt)
             * Selector: 0x095EA7B3
             * The following is equivalent to:
             * 
             * if approve:
             *   amt := 0
             */

            // 0 if sB is approve; 1 otherwise
            let isApprove := iszero(eq(sB, 0x09))
            // Set amt to 0 if approve; amt otherwise
            amt := mul(amt, isApprove)

            // Check balance/allowance requirements
            if or(
                lt(sload(apSlot), amt), 
                lt(sload(fbSlot), amt)
            ) {
                revert(0,0)
            }

            sstore(fbSlot, sub(sload(fbSlot), amt)) // Update from balance
            sstore(tbSlot, add(sload(tbSlot), amt)) // Update to balance
            sstore(apSlot, apAmt) // Update allowance

            // Log Transfer or Approval events
            log3(ptrAmt, 32, sload(isApprove), from, dest)

            doRet(1)

            function doRet(val) {
                mstore(0, val)
                return(0,32)
            }
        }
    }
}