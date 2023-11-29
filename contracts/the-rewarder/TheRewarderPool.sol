// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./RewardToken.sol";
import "../DamnValuableToken.sol";
import "./AccountingToken.sol";

/**
 * @title TheRewarderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract TheRewarderPool {
    //次のラウンドまでの待機期間
    // Minimum duration of each round of rewards in seconds
    uint256 private constant REWARDS_ROUND_MIN_DURATION = 5 days;

    uint256 public lastSnapshotIdForRewards;
    uint256 public lastRecordedSnapshotTimestamp;

    mapping(address => uint256) public lastRewardTimestamps;

    // Token deposited into the pool by users
    DamnValuableToken public immutable liquidityToken;

    // Token used for internal accounting and snapshots
    // Pegged 1:1 with the liquidity token
    AccountingToken public accToken;

    // Token in which rewards are issued
    RewardToken public immutable rewardToken;

    // Track number of rounds
    uint256 public roundNumber;

    constructor(address tokenAddress) {
        // Assuming all three tokens have 18 decimals
        liquidityToken = DamnValuableToken(tokenAddress);
        accToken = new AccountingToken();
        rewardToken = new RewardToken();

        _recordSnapshot();
    }

    /**
     * @notice sender must have approved `amountToDeposit` liquidity tokens in advance
     */
    //msg.senderにaccTokenをmintさせ、更にrewardTokenを配る？
    //その後DVTokenをmsg.senderからこのコントラクトにdepositさせる
    function deposit(uint256 amountToDeposit) external {
        require(amountToDeposit > 0, "Must deposit tokens");

        accToken.mint(msg.sender, amountToDeposit);
        distributeRewards();

        require(liquidityToken.transferFrom(msg.sender, address(this), amountToDeposit));
    }

    function withdraw(uint256 amountToWithdraw) external {
        //msg.senderのaccTokenをburn
        accToken.burn(msg.sender, amountToWithdraw);
        //msg.senderがDVTokenを出金
        require(liquidityToken.transfer(msg.sender, amountToWithdraw));
    }

    function distributeRewards() public returns (uint256) {
        uint256 rewards = 0;

        //新しいラウンドが始まったら、スナップショットを記録する
        if (isNewRewardsRound()) {
            _recordSnapshot();
        }

        //最新のスナップショットの時点での全供給者の合計供給量を取得
        uint256 totalDeposits = accToken.totalSupplyAt(lastSnapshotIdForRewards);
        //最新のスナップショットの時点でのmsg.senderのbalanceを取得
        uint256 amountDeposited = accToken.balanceOfAt(msg.sender, lastSnapshotIdForRewards);

        if (amountDeposited > 0 && totalDeposits > 0) {
            //報酬金額を計算
            rewards = (amountDeposited * 100 * 10 ** 18) / totalDeposits;
            // msg.senderに報酬を配布
            if (rewards > 0 && !_hasRetrievedReward(msg.sender)) {
                rewardToken.mint(msg.sender, rewards);
                //報酬を配布した時刻を記録
                lastRewardTimestamps[msg.sender] = block.timestamp;
            }
        }

        return rewards;
    }

    function _recordSnapshot() private {
        //現在のスナップショットのidを取得
        lastSnapshotIdForRewards = accToken.snapshot();
        lastRecordedSnapshotTimestamp = block.timestamp;
        roundNumber++;
    }

    //報酬該当者且つ報酬期間かどうかを判定
    function _hasRetrievedReward(address account) private view returns (bool) {
        return (
            lastRewardTimestamps[account] >= lastRecordedSnapshotTimestamp
                && lastRewardTimestamps[account] <= lastRecordedSnapshotTimestamp + REWARDS_ROUND_MIN_DURATION
        );
    }

    function isNewRewardsRound() public view returns (bool) {
        return block.timestamp >= lastRecordedSnapshotTimestamp + REWARDS_ROUND_MIN_DURATION;
    }
}
