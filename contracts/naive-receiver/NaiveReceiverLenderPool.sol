// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title NaiveReceiverLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract NaiveReceiverLenderPool is ReentrancyGuard {
    using Address for address;

    uint256 private constant FIXED_FEE = 1 ether; // not the cheapest flash loan

    function fixedFee() external pure returns (uint256) {
        return FIXED_FEE;
    }

    //ユーザーがReceiverpoolを介さずとも0 amountでも実行できる
    //その結果、FIXED_FEEの1 etherがFlashloanReceiverから
    //NaiveReceiverに何度も送られてしまう。
    function flashLoan(address borrower, uint256 borrowAmount) external nonReentrant {
        uint256 balanceBefore = address(this).balance;
        require(balanceBefore >= borrowAmount, "Not enough ETH in pool");

        require(borrower.isContract(), "Borrower must be a deployed contract");
        // Transfer ETH and handle control to receiver
        /**
         * functionCallWithValueはOpenZeppelinのライブラリに
         * 含まれるAddressライブラリのメソッドです。
         * このメソッドは、指定したアドレスに対してEtherを
         * 送信しながら関数を呼び出すために使用されます
         *
         */
        borrower.functionCallWithValue(abi.encodeWithSignature("receiveEther(uint256)", FIXED_FEE), borrowAmount);

        require(address(this).balance >= balanceBefore + FIXED_FEE, "Flash loan hasn't been paid back");
    }

    // Allow deposits of ETH
    receive() external payable {}
}
