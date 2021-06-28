// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Deployer {
    
    // Contains bytecode from asm_bytecode.txt
    bytes constant code = hex"3660046000373360205236600460403760003560001a602060002060605160a98314602384146009851460708614850260dd87146040604020021760188714600302178260805102848602178260406020200284604060002002178560040217805484880286848303021787820217868a02886020602020021787602060602002898c0217878a1786835410878610171560995760006000fd5b87151560d557868354038355868254018255838655898c028160005102178a60005102823302178b8d175460208d6080028560600217a3600297505b875460005260206000f3";
    
    constructor () public {
        bytes memory ret = code;
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
            
            return(add(32, ret), mload(ret))
        }
    }
}