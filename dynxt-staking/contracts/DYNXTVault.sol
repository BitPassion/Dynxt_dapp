//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./Utilities/contracts/token/BEP20/IBEP20.sol";
import "./Utilities/contracts/utils/EnumerableSet.sol";
import "./Utilities/contracts/token/BEP20/SafeBEP20.sol";
import "./Utilities//contracts/math/SafeMath.sol";
import "./Utilities//contracts/access/Ownable.sol"; 
import "./Utilities//contracts/utils/ReentrancyGuard.sol";

contract DYNXTVault is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    using SafeBEP20 for IBEP20;

    uint256 internal constant RATE_NOMINATOR = 10000; // rate nominator

    struct LockInfo {
        uint256 lockId; 
        uint256 minimumDeposit;
        uint256 percentage;
        uint256 duration;
        bool isEnabled;
    }

    struct StakeTracker {
        uint256[] stakes;
        uint256[] rewards;
        uint256[] claimedAt;
        uint256[] stakedAt;
        uint256[] lockId;
    }
    // Whether it is initialized
    bool public isInitialized;

    // The reward token
    IBEP20 public rewardToken;

    // The staked token
    IBEP20 public stakedToken;

    //total staking tokens
    uint256 public totalStakingTokens;

    //total reward tokens
    uint256 public totalRewardTokens;

    uint256 public lockId;
    mapping(uint256 => LockInfo) public lockInfo;
    mapping(address => mapping(uint256 => StakeTracker)) private accounts;

    mapping(address => bool) compound;

    event AdminTokenRecovery(address tokenRecovered, uint256 amount);
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event AddRewardTokens(address indexed user, uint256 amount);
    event Harvest(address indexed user, uint reward);

    /**
     * @notice Initialize the contract
     * @param _stakedToken: staked token address
     * @param _rewardToken: reward token address
     */
    function initialize(
        IBEP20 _stakedToken,
        IBEP20 _rewardToken
    ) external onlyOwner {
        require(!isInitialized, "Already initialized");
        
        // Make this contract initialized
        isInitialized = true;
        stakedToken = _stakedToken;
        rewardToken = _rewardToken;
    }

    /**
    * @dev get compound value against a user
    * @param _user address of user
    */
    function getUserCompund(address _user) external view returns(bool){
        return compound[_user];
    }

    /** 
    * @dev get lock against id
    * @param _lockId lock id
    */
    function getLock(uint256 _lockId) external view returns (uint256, uint256, uint256, uint256, bool ){
        LockInfo memory lock = lockInfo[_lockId];
        return (lock.lockId, lock.minimumDeposit, lock.percentage, lock.duration, lock.isEnabled);
    }

    /** 
    * @dev user can set compound value to true and false, on havest value will be automatically send to investment
    * @param _compound compound value
    */
    function setCompound(bool _compound) external {
        compound[msg.sender] = _compound;
    }
    /**
    * @dev add or update locks
    * @param _lockId add new lock id, send 0 for for new lock and lockId to update
    * @param _minimumDeposit add minimum Deposit
    * @param _percentage add percentage
    * @param _duration duration of locks in blocks
    * @param _isEnabled enable or disable lock
    */
    function addOrUpdateLock(uint256 _lockId, uint256 _minimumDeposit, uint256 _percentage, uint256 _duration, bool _isEnabled) external onlyOwner {
        //insert
        if(_lockId == 0) {
            lockId = lockId + 1;
            lockInfo[lockId] = LockInfo(lockId, _minimumDeposit, _percentage, _duration, _isEnabled);
        }else {
            LockInfo storage info = lockInfo[_lockId];
            info.minimumDeposit = _minimumDeposit;
            info.percentage = _percentage;
            info.duration = _duration;
            info.isEnabled = _isEnabled;
        }
    }

    /** 
    * @dev Deposit staked tokens and collect reward tokens (if any)
    * @param _amount: amount to withdraw (in rewardToken)
    * @param _lockId lockId where user needs to deposit
    */
    function deposit(uint256 _amount, uint256 _lockId) external nonReentrant {
        LockInfo memory lock = lockInfo[_lockId];
        require(_amount >= lock.minimumDeposit, "amount should be greater than minimum Deposit");

        StakeTracker storage account = accounts[msg.sender][_lockId];
        account.stakes.push(_amount);
        account.stakedAt.push(block.number);
        account.claimedAt.push(block.number);
        account.rewards.push(0);
        account.lockId.push(_lockId);

        stakedToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        totalStakingTokens = totalStakingTokens.add(_amount);
      
        emit Deposit(msg.sender, _amount);
    }

    /**
     * @notice Withdraw staked tokens and collect reward tokens
     * @param _amount: amount to withdraw (in rewardToken)
     * @param _lockId: lock id
     * @param _index index of the investment
     */
    function withdraw(uint256 _amount, uint256 _lockId, uint256 _index) public nonReentrant {
        StakeTracker storage account = accounts[msg.sender][_lockId];
        LockInfo memory lock = lockInfo[_lockId];
        require(_lockId == account.lockId[_index], "wrong lock id");
        require(account.stakes[_index] >= _amount, "withdraw amount must not more than staked amount");
        require(account.stakedAt[_index].add(lock.duration) < block.number, "unable to withdraw before the timelock");
        
        uint256 reward = rewardOf(msg.sender, _lockId, _index);
        account.stakes[_index] = account.stakes[_index].sub(_amount);
        account.rewards[_index] = 0;
        account.claimedAt[_index] = block.number;
        //transfer stake tokens
        stakedToken.safeTransfer(msg.sender, _amount);
        totalStakingTokens = totalStakingTokens.sub(_amount);
        //transfer pending reward
        _safeRewardTransfer(msg.sender, reward);
        emit Withdraw(msg.sender, _amount);
    }

    /** 
    * @dev withdraw all the rewards 
    * @param _lockId lock id 
    * @param _index investment id of the rewards
    */
    function withdrawAll(uint256 _lockId, uint256 _index) external {
        StakeTracker storage account = accounts[msg.sender][_lockId];
        withdraw(account.stakes[_index], _lockId, _index);
    }

    /**
    * @dev claim all funds
    */
    function harvestAll() external {
        for (uint256 i; i < lockId; i++) {
            uint256[] memory rewards = rewardsOfLockId(msg.sender, i+1);
            for(uint j; j < rewards.length; j++){
                harvest(i+1, j);
            }
        }
    }

    /**
    * @dev harvest token against lock id
    * @param _lockId lock id
    * @param _index investment index
    */
    function harvest(uint256 _lockId, uint256 _index) public {
        uint reward = rewardOf(msg.sender, _lockId, _index);
        require(reward > 0, "insufficient rewards");
        
        StakeTracker storage account = accounts[msg.sender][_lockId];
        account.rewards[_index] = 0;
        account.claimedAt[_index] = block.number;
        if(compound[msg.sender] == true) {
            account.stakes[_index] = account.stakes[_index] + reward;
            totalStakingTokens = totalStakingTokens.add(reward);
        }else{
            _safeRewardTransfer(msg.sender, reward);
        }
        emit Harvest(msg.sender, reward);
    }

    /**
    * @dev calculate rewards
    * @param _address user address
    * @param _lockId lock id
    * @param _index investment index
    */
    function rewardOf(address _address, uint256 _lockId, uint256 _index) public view returns (uint256) {
        StakeTracker memory account = accounts[_address][_lockId];
        LockInfo memory lock = lockInfo[_lockId];

        uint256 accumulator = block.number > account.stakedAt[_index] + lock.duration ?
        (account.stakedAt[_index] + lock.duration).sub(account.claimedAt[_index]):
        block.number.sub(account.claimedAt[_index]);
        
        uint reward = account.stakes[_index]
            .mul(accumulator)
            .mul(lock.percentage)
            .div(RATE_NOMINATOR);

        return account.rewards[_index].add(reward);
    }

    function rewardsOfLockId(address _address, uint256 _lockId) public view returns (uint256[] memory) {
        uint256 length = accounts[_address][_lockId].rewards.length;
        uint256[] memory rewards = new uint[](length);

        for(uint i=0;i <length; i++) {
            rewards[i] = rewardOf(_address, _lockId, i);
        }
        return rewards;
    }

    /**
     * @notice View function to see pending reward on frontend.
     * @param _user: user address
     * @return Pending reward for a given user
     */
    function pendingReward(address _user) external view returns (uint256) {
        uint256 reward;
        for (uint256 i = 0; i < lockId; i++) {
            uint256[] memory rewards = rewardsOfLockId(_user, i + 1);
            for(uint j; j < rewards.length; j++){
                reward = reward.add(rewards[j]);
            }
        }
        return reward;
    }

    /**
     * @notice emergency withdraw all tokens
     * @dev Only callable by owner. Needs to be for emergency.
     */
    function emergencyRewardWithdraw(uint256 _amount) external onlyOwner {
        totalRewardTokens = totalRewardTokens.sub(_amount);
        rewardToken.safeTransfer(address(msg.sender), _amount);
    }

    /**
     * @notice It allows the admin to reward tokens
     * @param _amount: amount of tokens
     * @dev This function is only callable by admin.
     */
    function addRewardTokens(uint256 _amount) external onlyOwner {
        totalRewardTokens = totalRewardTokens.add(_amount);
        rewardToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        emit AddRewardTokens(msg.sender, _amount);
    }
    /**
     * @notice It allows the admin to recover wrong tokens sent to the contract
     * @param _tokenAddress: the address of the token to withdraw
     * @param _tokenAmount: the number of tokens to withdraw
     * @dev This function is only callable by admin.
     */
    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        require(_tokenAddress != address(stakedToken), "Cannot be staked token");
        require(_tokenAddress != address(rewardToken), "Cannot be reward token");

        IBEP20(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);

        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    function getStakingAmount(address _user, uint256 _lockId, uint256 _index) external view returns(uint) {
        StakeTracker memory account = accounts[_user][_lockId];
        return account.stakes[_index];
    }
    /**
     * @notice transfer reward tokens.
     * @param _to: address where tokens will transfer
     * @param _amount: amount of tokens
     */
    function _safeRewardTransfer(address _to, uint256 _amount) internal {
        uint256 rewardTokenBal = totalRewardTokens;
        if (_amount > rewardTokenBal) {
            totalRewardTokens = totalRewardTokens.sub(rewardTokenBal);
            rewardToken.safeTransfer(_to, rewardTokenBal);
        } else {
            totalRewardTokens = totalRewardTokens.sub(_amount);
            rewardToken.safeTransfer(_to, _amount);
        }        
    }
}