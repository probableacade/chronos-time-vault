// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IERC20.sol";

/**
 * @title TimeLockVault
 * @notice Time-weighted staking and programmatic token vesting protocol with multiplier logic.
 */
contract TimeLockVault {
    struct StakePosition {
        uint256 amount;
        uint256 unlockTimestamp;
        uint256 rewardMultiplier; // in basis points (10000 = 1x)
        bool claimed;
    }

    IERC20 public immutable stakingToken;
    address public owner;
    bool public paused;
    uint256 public totalStaked;

    // user => positions array
    mapping(address => StakePosition[]) public userPositions;

    event Staked(address indexed user, uint256 positionId, uint256 amount, uint256 duration, uint256 multiplier);
    event Unstaked(address indexed user, uint256 positionId, uint256 amount);
    event PauseToggled(bool isPaused);

    modifier onlyOwner() {
        require(msg.sender == owner, "TimeLockVault: caller is not the owner");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "TimeLockVault: protocol paused");
        _;
    }

    constructor(address _stakingToken) {
        require(_stakingToken != address(0), "Invalid token");
        stakingToken = IERC20(_stakingToken);
        owner = msg.sender;
    }

    function calculateMultiplier(uint256 durationSeconds) public pure returns (uint256) {
        if (durationSeconds >= 365 days) {
            return 20000; // 2x
        } else if (durationSeconds >= 180 days) {
            return 15000; // 1.5x
        } else if (durationSeconds >= 30 days) {
            return 11000; // 1.1x
        }
        return 10000; // 1.0x baseline
    }

    function stake(uint256 amount, uint256 durationSeconds) external whenNotPaused returns (uint256 positionId) {
        require(amount > 0, "Cannot stake 0");
        require(durationSeconds >= 1 days, "Min lock 1 day");

        uint256 multiplier = calculateMultiplier(durationSeconds);
        uint256 unlockAt = block.timestamp + durationSeconds;

        positionId = userPositions[msg.sender].length;
        userPositions[msg.sender].push(StakePosition({
            amount: amount,
            unlockTimestamp: unlockAt,
            rewardMultiplier: multiplier,
            claimed: false
        }));

        totalStaked += amount;
        // Security Fix (#1): SafeERC20 transferFrom check
        require(stakingToken.transferFrom(msg.sender, address(this), amount), "SafeERC20: Transfer failed");

        emit Staked(msg.sender, positionId, amount, durationSeconds, multiplier);
    }

    function unstake(uint256 positionId) external {
        require(positionId < userPositions[msg.sender].length, "Invalid position");
        StakePosition storage pos = userPositions[msg.sender][positionId];

        require(!pos.claimed, "Already claimed");
        require(block.timestamp >= pos.unlockTimestamp, "Tokens still timelocked");

        pos.claimed = true;
        totalStaked -= pos.amount;

        require(stakingToken.transfer(msg.sender, pos.amount), "Transfer failed");
        emit Unstaked(msg.sender, positionId, pos.amount);
    }

    function getPositionCount(address user) external view returns (uint256) {
        return userPositions[user].length;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PauseToggled(_paused);
    }
}
