const { expectRevert, time } = require('@openzeppelin/test-helpers');
const { web3 } = require('@openzeppelin/test-helpers/src/setup');
const { assert } = require('chai');
const DYNXTChef = artifacts.require('DYNXTChef');
const MockBEP20 = artifacts.require('MocKBEP20');

const toWei = (amount) => {
    return web3.utils.toWei(amount);
}

const fromWei = (amount) => {
    return  web3.utils.fromWei(amount);
}

contract('DYNXTChef', ([alice, bob, carol, minter, adam]) => {

    beforeEach(async () => {
        
        this.rewardToken = await MockBEP20.new('Reward', 'RWD', toWei('200000'), {from: minter});        

        await this.rewardToken.transfer(bob, toWei('50'), {from: minter})
        await this.rewardToken.transfer(carol, toWei('50'), {from: minter})
        await this.rewardToken.transfer(adam, toWei('50'), {from: minter})

        this.pool = await DYNXTChef.new({from:minter})
        await this.pool.initialize(this.rewardToken.address, this.rewardToken.address, {from:minter})
        
        await this.rewardToken.approve(this.pool.address, toWei('100000'), {from:minter})
        await this.pool.addRewardTokens(toWei('1000'), {from: minter})

    });
    
    it('should divide reward in to 3 staker correctly', async () =>  {

        await this.pool.addOrUpdateLock(0, toWei('10'),'300','10', true, {from:minter})
        
        await this.rewardToken.approve((this.pool.address), toWei('50'), {from: bob})
        await this.rewardToken.approve((this.pool.address), toWei('50'), {from: carol})
        await this.rewardToken.approve((this.pool.address), toWei('50'), {from: adam})
        
        await this.pool.deposit(toWei('10'), 1, {from: bob})
        await this.pool.deposit(toWei('10'), 1, {from: carol})
        await this.pool.deposit(toWei('10'), 1, {from: adam})

        
        let bobReward = await this.pool.pendingReward(bob)
        let carolReward = await this.pool.pendingReward(carol)
        let adamReward = await this.pool.pendingReward(adam)
        
        
        assert.equal(fromWei(bobReward), '0.6')
        assert.equal(fromWei(carolReward), '0.3')
        assert.equal(fromWei(adamReward), '0')
        const block = await web3.eth.getBlockNumber()
        await time.advanceBlockTo((block + 5));
        bobReward = await this.pool.pendingReward(bob)
        carolReward = await this.pool.pendingReward(carol)
        adamReward = await this.pool.pendingReward(adam)

        assert.equal(fromWei(bobReward), '2.1')
        assert.equal(fromWei(carolReward), '1.8')
        assert.equal(fromWei(adamReward), '1.5')
        
        //before harvest
        assert.equal(fromWei(await this.rewardToken.balanceOf(bob)), '40');
        assert.equal(fromWei(await this.rewardToken.balanceOf(carol)), '40');
        assert.equal(fromWei(await this.rewardToken.balanceOf(adam)), '40');

        // //harvesting
        const x = await this.pool.harvestAll({from: bob})
        await this.pool.harvestAll({from: carol})
        await this.pool.harvestAll({from: adam})

        
        assert.equal(fromWei(await this.rewardToken.balanceOf(bob)), '42.4');
        assert.equal(fromWei(await this.rewardToken.balanceOf(carol)), '42.4');
        assert.equal(fromWei(await this.rewardToken.balanceOf(adam)), '42.4');
        // // withdraw 
        await expectRevert(this.pool.withdraw(toWei('10'),1, 0, {from: adam}), 'unable to withdraw before the timelock')
        await this.pool.withdraw(toWei('10'), 1, 0, {from: bob})
        
        // //after withdraw
        assert.equal(fromWei(await this.rewardToken.balanceOf(bob)), '53');
        
    });


    

    context('With pool functional correctly', () => {
        
        
    });
    
})