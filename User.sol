pragma solidity ^0.8.0;

import "./ERC20Tweetable.sol";

interface IERC20 {
    function totalSupply() external view returns (uint);
    function balanceOf(address) external view returns (uint);
    function allowance(address, address) external view returns (uint);

    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
    function approve(address, uint) external returns (bool);
    
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

contract User {
    
    IERC20 t = IERC20(address(new ERC20Tweetable()));

    address targetA = address(0xDEADBEEF);
    address targetB = address(0xBADDDADD);

    function deploy() internal returns (IERC20) {
        return IERC20(address(new ERC20Tweetable()));
    }

    // should return (1000, 1000)
    function testViewFuncs() public view returns (uint supply, uint balance) {
        // IERC20 token = deploy();
        supply = t.totalSupply();
        balance = t.balanceOf(address(this));
    }

    // should succeed
    function tryTransfer() public {
        IERC20 token = deploy();
        uint prevBal = token.balanceOf(address(this));
        bool success = token.transfer(targetA, prevBal - 1);
        require(success, "0");
        success = token.transfer(targetB, 1);
        require(success, "1");

        require(token.balanceOf(targetA) == prevBal - 1, "2");
        require(token.balanceOf(targetB) == 1, "3");
        require(token.balanceOf(address(this)) == 0, "4");
    }
    
    // should succeed
    function tryApprove() public {
        IERC20 token = deploy();
        uint bal = token.balanceOf(address(this));
        bool success = token.approve(address(this), bal);
        require(success, "1");
        require(token.allowance(address(this), address(this)) == bal, "2");

        success = token.approve(targetA, bal);
        require(success, "3");
        require(token.allowance(address(this), targetA) == bal, "4");

        success = token.approve(targetB, 1);
        require(success, "5");
        require(token.allowance(address(this), targetB) == 1, "6");
    }
    
    // should fail
    function tryTransferFromFAIL() public {
        IERC20 token = deploy();
        uint bal = token.balanceOf(address(this));

        bool success = token.approve(address(this), 1);
        require(success);
        success = token.transferFrom(address(this), targetA, 2);
        require(!success);
    }

    // should succeed
    function tryTransferFromSUCC() public {
        IERC20 token = deploy();
        uint bal = token.balanceOf(address(this));

        uint prevA = token.balanceOf(targetA);
        uint prevB = token.balanceOf(targetB);
        require(prevA == 0 && prevB == 0, "1");

        bool success = token.approve(address(this), bal + 1);
        require(success, "2");
        require(token.allowance(address(this), address(this)) == bal + 1, "3");

        success = token.transferFrom(address(this), targetA, 1);
        require(success, "4");
        require(token.balanceOf(targetA) == 1, "5");
        require(token.balanceOf(address(this)) == bal - 1, "6");
        require(token.allowance(address(this), address(this)) == bal, "7");

        success = token.transferFrom(address(this), address(this), 1);
        require(success, "8");
        require(token.balanceOf(address(this)) == bal - 1, "9");
        require(token.allowance(address(this), address(this)) == bal - 1, "10");

        success = token.transferFrom(address(this), targetB, bal - 1);
        require(success, "11");
        require(token.balanceOf(targetB) == bal - 1, "12");
        require(token.balanceOf(address(this)) == 0, "13");
        require(token.allowance(address(this), address(this)) == 0, "14");
    }
}