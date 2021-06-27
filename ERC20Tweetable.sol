// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ERC20Tweetable {

    constructor () {
        assembly {
            sstore(3, 1000) // Set totalSupply at slot 0
            sstore(4, not(0)) // Set max uint at slot 3

            // give msg.sender total balance
            mstore(0, caller())
            sstore(keccak256(0, 32), 1000)

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

            // Get first byte of selector
            let sB := byte(28, mload(0))

            // Hash first param
            let shaP0 := keccak256(0x20, 32)

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

            // 1 if sB is transfer; 0 otherwise
            let isTransfer := eq(sB, 0xA9)
            // 1 if sB is transferFrom; 0 otherwise
            let isTransferFrom := eq(sB, 0x23)
            // 1 if sB is approve; 0 otherwise
            let isApprove := eq(sB, 0x09)

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
                        mul(isBalanceOf, shaP0)
                    )
                )

                // if sB is a view function, load slot and return value
                if ret {
                    doRet(sload(ret))
                }
            }

            // get rid of unneeded vars
            pop(sB)

            /**
             * Handle state changing functions:
             * token.transfer(dest, amt)
             * token.transferFrom(from, dest, amt)
             * token.approve(dest, amt)
             */

            /**
             * Set transferAmt:
             * transfer: p1
             * transferFrom: p2
             * approve: 0
             */
            let transferAmt := or(
                mul(mload(0x40), isTransfer),
                mul(mload(0x60), isTransferFrom)
            )

            /**
             * Set approvalSlot:
             * transfer: slot_max
             * transferFrom: sha(p0, caller)
             * approve: sha(caller, p0)
             */
            let approvalSlot := or(
                mul(4, isTransfer),
                or(
                    mul(keccak256(0xA0, 64), isTransferFrom),
                    mul(keccak256(0x80, 64), isApprove)
                )
            )

            /**
             * Set approvalAmt:
             * transfer: sload(approvalSlot)
             * transferFrom: sload(approvalSlot) - transferAmt
             * approve: p1
             */
            let approvalAmt := or(
                mul(sload(approvalSlot), isTransfer),
                or(
                    mul(sub(sload(approvalSlot), transferAmt), isTransferFrom),
                    mul(mload(0x40), isApprove)
                )
            )

            /**
             * Set fromBalSlot:
             * transfer: sha(caller)
             * transferFrom: sha(p0)
             * approve: 0
             */
            let fromBalSlot := or(
                mul(keccak256(0x80, 32), isTransfer),
                mul(shaP0, isTransferFrom)
            )

            /**
             * Set toBalSlot:
             * transfer: sha(p0)
             * transferFrom: sha(p1)
             * approve: 0
             */
            let toBalSlot := or(
                mul(shaP0, isTransfer),
                mul(keccak256(0x40, 32), isTransferFrom)
            )

            /**
             * Set eventSigSlot:
             * transfer: 1
             * transferFrom: 1
             * approve: 0
             */
            let eventSigSlot := or(isTransfer, isTransferFrom)

            /**
             * Set logAmtPtr:
             * transfer: p1
             * transferFrom: p2
             * approve: p1
             */
            let logAmtPtr := or(
                mul(0x40, or(isTransfer, isApprove)),
                mul(0x60, isTransferFrom)
            )

            /**
             * Set logFromParam:
             * transfer: caller
             * transferFrom: p0
             * approve: caller
             */
            let logFromParam := or(
                mul(caller(), or(isTransfer, isApprove)),
                mul(mload(0x20), isTransferFrom)
            )

            /**
             * Set logToParam:
             * transfer: p0
             * transferFrom: p1
             * approve: p0
             */
            let logToParam := or(
                mul(mload(0x20), or(isTransfer, isApprove)),
                mul(mload(0x40), isTransferFrom)
            )

            // Check balance/allowance requirements
            if or(
                lt(sload(approvalSlot), transferAmt), 
                lt(sload(fromBalSlot), transferAmt)
            ) {
                revert(0, 0)
            }

            sstore(fromBalSlot, sub(sload(fromBalSlot), transferAmt)) // Update from balance
            sstore(toBalSlot, add(sload(toBalSlot), transferAmt)) // Update to balance
            sstore(approvalSlot, approvalAmt) // Update allowance

            // Log Transfer or Approval events
            log3(logAmtPtr, 32, sload(eventSigSlot), logFromParam, logToParam)

            doRet(1)

            function doRet(val) {
                mstore(0, val)
                return(0, 32)
            }
        }
    }
}