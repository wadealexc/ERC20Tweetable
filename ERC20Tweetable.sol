// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ERC20Tweetable {

    constructor () {
        assembly {
            sstore(2, 1) // Store "true" at slot 2
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
             * Target memory layout:
             * 0x00: [param 0]
             * 0x20: [caller]
             * 0x40: [param 0]
             * 0x60: [param 1]
             * 0x80: [param 2]
             */

            // Copy p0, p1, p2 to mem[0x00:0x60)
            calldatacopy(0, 4, calldatasize())

            // Place caller at 0x20
            mstore(0x20, caller())

            // Copy p0, p1, p2 to mem[0x40:0xA0)
            calldatacopy(0x40, 4, calldatasize())

            // Get first byte of selector
            let func := byte(0, calldataload(0))

            /**
             * These two values are used 3 times each in the following code,
             * so it's more efficient to put them on the stack now and spend
             * a DUP instruction for each reference below.
             * shaP0: hash of param 0
             * p1: param 1
             */
            let shaP0 := keccak256(0x00, 32)
            let p1 := mload(0x60)

            /**
             * Check whether func is any of the state-changing methods:
             *
             * transfer(dest, amt)
             * transferFrom(from, dest, amt)
             * approve(dest, amt)
             * 
             * Only check the first byte, since they're all unique
             */

            // 1 if func is transfer; 0 otherwise
            let isTransfer := eq(func, 0xA9)
            // 1 if func is transferFrom; 0 otherwise
            let isTransferFrom := eq(func, 0x23)
            // 1 if func is approve; 0 otherwise
            let isApprove := eq(func, 0x09)

            /**
             * Handle view functions:
             * token.balanceOf(owner)
             * token.allowance(owner, spender)
             * token.totalSupply()
             */

            /**
             * Calc readSlot:
             * allowance: sha(p0, p1)
             * balanceOf: sha(p0)
             * totalSupply: 3
             * other methods: 0
             */
            let readSlot := or(
                mul(3, eq(func, 0x18)), // isTotalSupply := eq(func, 0x18)
                or(
                    mul(keccak256(0x40, 64), eq(func, 0xDD)), // isAllowance := eq(func, 0xDD)
                    mul(shaP0, eq(func, 0x70)) // isBalanceOf := eq(func, 0x70)
                )
            )

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

            /**
             * Set approvalSlot:
             * transfer: slot_max
             * transferFrom: sha(p0, caller)
             * approve: sha(caller, p0)
             */
            let approvalSlot := or(
                mul(4, isTransfer),
                or(
                    mul(keccak256(0x00, 64), isTransferFrom),
                    mul(keccak256(0x20, 64), isApprove)
                )
            )

            // We reference this 3 times, so place on stack
            let loadApprSlot := sload(approvalSlot)

            /**
             * Set approvalAmt:
             * transfer: sload(approvalSlot)
             * transferFrom: sload(approvalSlot) - transferAmt
             * approve: p1
             */
            let approvalAmt := or(
                mul(loadApprSlot, isTransfer),
                or(
                    mul(sub(loadApprSlot, transferAmt), isTransferFrom),
                    mul(p1, isApprove)
                )
            )

            /**
             * Set fromBalSlot:
             * transfer: sha(caller)
             * transferFrom: sha(p0)
             * approve: 0
             */
            let fromBalSlot := or(
                mul(keccak256(0x20, 32), isTransfer),
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
                mul(keccak256(0x60, 32), isTransferFrom)
            )

            // We reference this 3 times, so place on stack
            let isTransferOrApprove := or(isTransfer, isApprove)

            // Check balance/allowance requirements
            if or(
                lt(loadApprSlot, transferAmt), 
                lt(sload(fromBalSlot), transferAmt)
            ) {
                revert(0, 0)
            }

            /**
             * If we didn't call a view function, do sstores/log
             */
            if iszero(readSlot) {
                sstore(fromBalSlot, sub(sload(fromBalSlot), transferAmt)) // Update from balance
                sstore(toBalSlot, add(sload(toBalSlot), transferAmt)) // Update to balance
                sstore(approvalSlot, approvalAmt) // Update allowance

                // Log Transfer or Approval event
                log3(
                    or(
                        mul(0x60, isTransferOrApprove),
                        mul(0x80, isTransferFrom)
                    ), 
                    32, 
                    sload(or(isTransfer, isTransferFrom)), 
                    or(
                        mul(caller(), isTransferOrApprove),
                        mul(mload(0x00), isTransferFrom)
                    ), 
                    or(
                        mul(mload(0x00), isTransferOrApprove),
                        mul(p1, isTransferFrom)
                    )
                )

                // Set readSlot to 2 to return "true"
                readSlot := 2
            }

            // Load return value from storage and return
            mstore(0, sload(readSlot))
            return(0, 32)
        }
    }
}