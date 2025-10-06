// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ISwapRouter.sol";
import "./interfaces/IUniswapV3Pool.sol";
import "./interfaces/IUniswapV3Factory.sol";
import "./utils/PoolSelector.sol";
import "./utils/Rescueable.sol";

contract TokenSaleSkale is Ownable, ReentrancyGuard, PoolSelector, Rescueable {
    using SafeERC20 for IERC20;

    error SaleNotActive();
    error InvalidAmount();
    error NoLiquidityPool();
    error BelowMinimumPurchase();
    error ExceedsMaximumPurchase();
    error InvalidAddress();
    error InvalidLimits();
    error TransferFailed();
    error StageNotActive();
    error StageLimitExceeded();
    error InvalidStageId();
    error ReferralClaimsDisabled();
    error NoEarningsToClaim();
    error InvalidReferrer();
    error InvalidReferralPercentage();
    error InvalidPaymentToken();

    struct Stage {
        uint256 usdtCap;
        uint256 totalRaised;
        uint256 minimumPurchase;
        uint256 maximumPurchase;
        bool active;
    }

    struct StageInfo {
        uint256 stageId;
        uint256 usdtCap;
        uint256 totalRaised;
        uint256 minimumPurchase;
        uint256 maximumPurchase;
        bool active;
    }

    struct UserStageData {
        uint256 stageId;
        uint256 contribution;
        bool participated;
    }

    struct PublicSaleInfo {
        uint256 totalStages;
        uint256 activeStageId;
        uint256 globalTotalContributions;
        StageInfo currentStage;
        StageInfo[] allStages;
        bool saleActive;
    }

    struct UserInfo {
        uint256 totalContributions;
        uint256 numberOfStagesParticipated;
        uint256 currentStageContribution;
        UserStageData[] stageData;
        ReferralInfo referralEarnings;
    }

    struct ReferralInfo {
        uint256 totalEarned;
        uint256 claimedAmount;
        uint256 pendingAmount;
        uint256 level1Earnings;
        uint256 level2Earnings;
    }

    ISwapRouter public immutable swapRouter;
    IERC20 public immutable USDT;
    address public treasuryAddress;

    uint256 public totalContributions;
    bool public saleActive = true;
    bool public referralClaimsEnabled = false;

    // Dynamic referral percentages (in basis points: 1000 = 10%, 300 = 3%)
    uint256 public level1ReferralPercentage = 1000; // Default 10%
    uint256 public level2ReferralPercentage = 300; // Default 3%
    uint256 public constant MAX_REFERRAL_PERCENTAGE = 5000; // Maximum 50%

    // Referral tracking
    mapping(address => address) public referredBy; // user => referrer (level 1)
    mapping(address => uint256) public referralEarnings; // referrer => total USDT earned
    mapping(address => uint256) public claimedEarnings; // referrer => claimed USDT amount
    mapping(address => uint256) public level1Earnings; // referrer => level 1 earnings
    mapping(address => uint256) public level2Earnings; // referrer => level 2 earnings

    uint256 public currentStageId;
    uint256 public stageCount;

    mapping(uint256 => Stage) public stages;
    mapping(address => uint256) public userContributions;
    mapping(uint256 => mapping(address => uint256))
        public userStageContributions;

    event Purchase(
        address indexed user,
        address indexed paymentToken,
        uint256 paymentAmount,
        uint256 usdtAmount,
        uint256 indexed stageId
    );
    event SaleStatusChanged(bool active);
    event TreasuryUpdated(address newTreasury);
    event PurchaseLimitsUpdated(uint256 newMin, uint256 newMax);
    event StageAdded(
        uint256 indexed stageId,
        uint256 usdtCap,
        uint256 minPurchase,
        uint256 maxPurchase
    );
    event StageActivated(uint256 indexed stageId);
    event StageDeactivated(uint256 indexed stageId);
    event StageUpdated(
        uint256 indexed stageId,
        uint256 usdtCap,
        uint256 minPurchase,
        uint256 maxPurchase
    );
    event ReferralEarning(
        address indexed referrer,
        address indexed referred,
        uint256 level,
        uint256 usdtAmount,
        uint256 earnedAmount
    );
    event ReferralClaimed(address indexed referrer, uint256 amount);
    event ReferralClaimsStatusChanged(bool enabled);
    event ReferralPercentagesUpdated(
        uint256 level1Percentage,
        uint256 level2Percentage
    );

    constructor(
        address _swapRouter,
        address _factory,
        address _usdt,
        address _treasury,
        uint256 _usdtCap
    ) Ownable(msg.sender) PoolSelector(_factory) {
        if (_swapRouter == address(0)) revert InvalidAddress();
        if (_usdt == address(0)) revert InvalidAddress();
        if (_treasury == address(0)) revert InvalidAddress();

        swapRouter = ISwapRouter(_swapRouter);
        USDT = IERC20(_usdt);
        treasuryAddress = _treasury;
        saleActive = true;

        // Add first stage
        uint256 stageId = stageCount;

        stages[stageId] = Stage({
            usdtCap: _usdtCap,
            totalRaised: 0,
            minimumPurchase: 0,
            maximumPurchase: type(uint256).max,
            active: false
        });

        stageCount++;

        emit StageAdded(stageId, _usdtCap, 0, type(uint256).max);
    }

    function purchase(
        address token,
        uint256 amount,
        address level1Referrer,
        address level2Referrer
    ) public payable nonReentrant returns (uint256 usdtAmount) {
        if (!saleActive) revert SaleNotActive();

        // ETH payment
        if (token == address(0)) {
            revert InvalidPaymentToken();
        }
        // USDT payment
        if (token == address(USDT)) {
            if (amount == 0) revert InvalidAmount();
            IERC20(USDT).safeTransferFrom(msg.sender, treasuryAddress, amount);
            usdtAmount = amount;
        }
        // Token payment
        else {
            if (amount == 0) revert InvalidAmount();
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            usdtAmount = _swapToUSDT(token, amount, 0);
        }

        _processPurchase(
            msg.sender,
            usdtAmount,
            level1Referrer,
            level2Referrer
        );
        emit Purchase(msg.sender, token, amount, usdtAmount, currentStageId);
    }

    function _swapToUSDT(
        address tokenIn,
        uint256 amountIn,
        uint256 ethValue
    ) private returns (uint256) {
        ISwapRouter.ExactInputSingleParams memory params;
        // For direct swap to USDT
        address pool = getBestPool(tokenIn, address(USDT));
        if (pool == address(0)) revert NoLiquidityPool();

        uint24 fee = IUniswapV3Pool(pool).fee();

        params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: address(USDT),
            fee: fee,
            recipient: treasuryAddress,
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        return swapRouter.exactInputSingle{value: ethValue}(params);
    }

    function _processPurchase(
        address user,
        uint256 usdtAmount,
        address level1Referrer,
        address level2Referrer
    ) private {
        Stage storage currentStage = stages[currentStageId];

        if (!currentStage.active) revert StageNotActive();
        if (currentStage.totalRaised + usdtAmount > currentStage.usdtCap)
            revert StageLimitExceeded();

        uint256 newStageContribution = userStageContributions[currentStageId][
            user
        ] + usdtAmount;
        uint256 newTotalContribution = userContributions[user] + usdtAmount;

        if (newStageContribution < currentStage.minimumPurchase)
            revert BelowMinimumPurchase();
        if (newStageContribution > currentStage.maximumPurchase)
            revert ExceedsMaximumPurchase();

        // Set referrer if this is user's first purchase and referrer is valid
        if (
            userContributions[user] == 0 &&
            level1Referrer != address(0) &&
            level1Referrer != user
        ) {
            referredBy[user] = level1Referrer;
        }

        userStageContributions[currentStageId][user] = newStageContribution;
        userContributions[user] = newTotalContribution;
        currentStage.totalRaised += usdtAmount;
        totalContributions += usdtAmount;

        // Process referral earnings with provided referrers
        _processReferralEarnings(
            user,
            usdtAmount,
            level1Referrer,
            level2Referrer
        );
    }

    function _processReferralEarnings(
        address user,
        uint256 usdtAmount,
        address level1Referrer,
        address level2Referrer
    ) private {
        // Process level 1 referrer if provided and valid
        if (level1Referrer != address(0) && level1Referrer != user) {
            // Calculate earnings using dynamic percentage (basis points)
            uint256 level1Earning = (usdtAmount * level1ReferralPercentage) /
                10000;
            referralEarnings[level1Referrer] += level1Earning;
            level1Earnings[level1Referrer] += level1Earning;

            emit ReferralEarning(
                level1Referrer,
                user,
                1,
                usdtAmount,
                level1Earning
            );
        }

        // Process level 2 referrer if provided and valid
        if (
            level2Referrer != address(0) &&
            level2Referrer != user &&
            level2Referrer != level1Referrer
        ) {
            // Calculate earnings using dynamic percentage (basis points)
            uint256 level2Earning = (usdtAmount * level2ReferralPercentage) /
                10000;
            referralEarnings[level2Referrer] += level2Earning;
            level2Earnings[level2Referrer] += level2Earning;

            emit ReferralEarning(
                level2Referrer,
                user,
                2,
                usdtAmount,
                level2Earning
            );
        }
    }

    function claimReferralEarnings() external nonReentrant {
        if (!referralClaimsEnabled) revert ReferralClaimsDisabled();

        uint256 pendingAmount = referralEarnings[msg.sender] -
            claimedEarnings[msg.sender];
        if (pendingAmount == 0) revert NoEarningsToClaim();

        claimedEarnings[msg.sender] = referralEarnings[msg.sender];

        // Transfer USDT earnings to claimer
        USDT.safeTransfer(msg.sender, pendingAmount);

        emit ReferralClaimed(msg.sender, pendingAmount);
    }

    function setReferralClaimsEnabled(bool _enabled) external onlyOwner {
        referralClaimsEnabled = _enabled;
        emit ReferralClaimsStatusChanged(_enabled);
    }

    function setReferralPercentages(
        uint256 _level1Percentage,
        uint256 _level2Percentage
    ) external onlyOwner {
        if (
            _level1Percentage > MAX_REFERRAL_PERCENTAGE ||
            _level2Percentage > MAX_REFERRAL_PERCENTAGE
        ) {
            revert InvalidReferralPercentage();
        }

        level1ReferralPercentage = _level1Percentage;
        level2ReferralPercentage = _level2Percentage;

        emit ReferralPercentagesUpdated(_level1Percentage, _level2Percentage);
    }

    function setSaleStatus(bool _active) external onlyOwner {
        saleActive = _active;
        emit SaleStatusChanged(_active);
    }

    function updateTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert InvalidAddress();
        treasuryAddress = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    function addStage(
        uint256 _usdtCap,
        uint256 _minPurchase,
        uint256 _maxPurchase
    ) external onlyOwner returns (uint256) {
        if (_usdtCap == 0) revert InvalidLimits();
        if (_maxPurchase < _minPurchase) revert InvalidLimits();

        uint256 stageId = stageCount;

        stages[stageId] = Stage({
            usdtCap: _usdtCap,
            totalRaised: 0,
            minimumPurchase: _minPurchase,
            maximumPurchase: _maxPurchase,
            active: false
        });

        stageCount++;

        emit StageAdded(stageId, _usdtCap, _minPurchase, _maxPurchase);
        return stageId;
    }

    function activateStage(uint256 _stageId) external onlyOwner {
        if (_stageId >= stageCount) revert InvalidStageId();

        if (stages[currentStageId].active) {
            stages[currentStageId].active = false;
            emit StageDeactivated(currentStageId);
        }

        stages[_stageId].active = true;
        currentStageId = _stageId;

        emit StageActivated(_stageId);
    }

    function deactivateCurrentStage() external onlyOwner {
        if (stages[currentStageId].active) {
            stages[currentStageId].active = false;
            emit StageDeactivated(currentStageId);
        }
    }

    function updateStage(
        uint256 _stageId,
        uint256 _usdtCap,
        uint256 _minPurchase,
        uint256 _maxPurchase
    ) external onlyOwner {
        if (_stageId >= stageCount) revert InvalidStageId();
        if (_usdtCap == 0) revert InvalidLimits();
        if (_maxPurchase < _minPurchase) revert InvalidLimits();

        Stage storage stage = stages[_stageId];
        if (_usdtCap < stage.totalRaised) revert InvalidLimits();

        stage.usdtCap = _usdtCap;
        stage.minimumPurchase = _minPurchase;
        stage.maximumPurchase = _maxPurchase;

        emit StageUpdated(_stageId, _usdtCap, _minPurchase, _maxPurchase);
    }

    function getStageInfo(
        uint256 _stageId
    )
        external
        view
        returns (
            uint256 usdtCap,
            uint256 totalRaised,
            uint256 stageMinimumPurchase,
            uint256 stageMaximumPurchase,
            bool active
        )
    {
        if (_stageId >= stageCount) revert InvalidStageId();
        Stage storage stage = stages[_stageId];
        return (
            stage.usdtCap,
            stage.totalRaised,
            stage.minimumPurchase,
            stage.maximumPurchase,
            stage.active
        );
    }

    function getUserStageContribution(
        uint256 _stageId,
        address _user
    ) external view returns (uint256) {
        if (_stageId >= stageCount) revert InvalidStageId();
        return userStageContributions[_stageId][_user];
    }

    function getPublicSaleInfo()
        external
        view
        returns (PublicSaleInfo memory info)
    {
        // Build public sale information (no user data needed)
        info.totalStages = stageCount;
        info.activeStageId = currentStageId;
        info.globalTotalContributions = totalContributions;
        info.saleActive = saleActive;

        // Build current stage info
        if (stageCount > 0) {
            Stage storage currentStageData = stages[currentStageId];
            info.currentStage = StageInfo({
                stageId: currentStageId,
                usdtCap: currentStageData.usdtCap,
                totalRaised: currentStageData.totalRaised,
                minimumPurchase: currentStageData.minimumPurchase,
                maximumPurchase: currentStageData.maximumPurchase,
                active: currentStageData.active
            });
        }

        // Build all stages info
        info.allStages = new StageInfo[](stageCount);
        for (uint256 i = 0; i < stageCount; i++) {
            Stage storage stage = stages[i];
            info.allStages[i] = StageInfo({
                stageId: i,
                usdtCap: stage.usdtCap,
                totalRaised: stage.totalRaised,
                minimumPurchase: stage.minimumPurchase,
                maximumPurchase: stage.maximumPurchase,
                active: stage.active
            });
        }

        return info;
    }

    function getUserInfo(
        address _user
    ) external view returns (UserInfo memory info) {
        // Build user-specific information
        info.totalContributions = userContributions[_user];
        info.currentStageContribution = stageCount > 0
            ? userStageContributions[currentStageId][_user]
            : 0;

        // Build user stage data
        info.stageData = new UserStageData[](stageCount);
        uint256 participatedCount = 0;

        for (uint256 i = 0; i < stageCount; i++) {
            uint256 contribution = userStageContributions[i][_user];
            info.stageData[i] = UserStageData({
                stageId: i,
                contribution: contribution,
                participated: contribution > 0
            });

            if (contribution > 0) {
                participatedCount++;
            }
        }

        info.numberOfStagesParticipated = participatedCount;

        // Build referral earnings information
        info.referralEarnings = ReferralInfo({
            totalEarned: referralEarnings[_user],
            claimedAmount: claimedEarnings[_user],
            pendingAmount: referralEarnings[_user] - claimedEarnings[_user],
            level1Earnings: level1Earnings[_user],
            level2Earnings: level2Earnings[_user]
        });

        return info;
    }

    function getReferralInfo(
        address _user
    ) external view returns (ReferralInfo memory info) {
        info.totalEarned = referralEarnings[_user];
        info.claimedAmount = claimedEarnings[_user];
        info.pendingAmount = info.totalEarned - info.claimedAmount;
        info.level1Earnings = level1Earnings[_user];
        info.level2Earnings = level2Earnings[_user];
        return info;
    }

    function getUserReferrer(address _user) external view returns (address) {
        return referredBy[_user];
    }

    function getPendingReferralEarnings(
        address _user
    ) external view returns (uint256) {
        return referralEarnings[_user] - claimedEarnings[_user];
    }

    function getReferralPercentages()
        external
        view
        returns (uint256 level1, uint256 level2)
    {
        return (level1ReferralPercentage, level2ReferralPercentage);
    }
}
