# Bomberzilla Smart Contracts (SKALE)

Smart contracts for the Bomberzilla token sale on the SKALE Network, featuring a multi-stage sale system with Uniswap V3 integration and a two-level referral program.

## Features

- **Multi-Stage Token Sale**: Flexible stage-based sale system with configurable caps and purchase limits
- **Uniswap V3 Integration**: Automatic token swapping to USDT through Uniswap V3 pools
- **Two-Level Referral System**: Earn rewards from direct and indirect referrals with configurable percentages
- **Payment Flexibility**: Accept USDT or any ERC20 token with automatic conversion
- **Stage Management**: Add, activate, deactivate, and update sale stages
- **Treasury Management**: Automated fund collection to treasury address
- **Safety Features**: Built with OpenZeppelin contracts including ReentrancyGuard and Ownable

## Contract Architecture

### Main Contract

- **TokenSaleSkale.sol**: Core token sale contract with stage management and referral system

### Utilities

- **PoolSelector.sol**: Automatically selects the best Uniswap V3 pool for token swaps
- **Rescueable.sol**: Emergency token rescue functionality

### Interfaces

- Uniswap V3 interfaces for swap routing, pool management, and position handling

## Installation

```bash
npm install
```

## Environment Setup

Create a `.env` file in the root directory:

```env
PRIVATE_KEY=your_private_key_here
SKALE_RPC_URL=your_skale_rpc_url
SKALE_TESTNET_RPC_URL=your_skale_testnet_rpc_url
```

## Deployment

### Deploy to SKALE Testnet

```bash
npm run deploy:token-sale-skale-testnet
```

### Deploy to SKALE Mainnet

```bash
npm run deploy:token-sale-skale
```

## Testing

Run the test suite:

```bash
npm test
```

## Configuration

Deployment parameters are configured in `ignition/config/` directory:
- `1444673419.json`: SKALE testnet configuration
- `2046399126.json`: SKALE mainnet configuration

## Key Functions

### Purchase

```solidity
function purchase(
    address token,
    uint256 amount,
    address level1Referrer,
    address level2Referrer
) public payable returns (uint256 usdtAmount)
```

### Stage Management

```solidity
function addStage(uint256 _usdtCap, uint256 _minPurchase, uint256 _maxPurchase) external onlyOwner
function activateStage(uint256 _stageId) external onlyOwner
function updateStage(uint256 _stageId, uint256 _usdtCap, uint256 _minPurchase, uint256 _maxPurchase) external onlyOwner
```

### Referral System

```solidity
function claimReferralEarnings() external
function setReferralPercentages(uint256 _level1Percentage, uint256 _level2Percentage) external onlyOwner
function setReferralClaimsEnabled(bool _enabled) external onlyOwner
```

### View Functions

```solidity
function getPublicSaleInfo() external view returns (PublicSaleInfo memory)
function getUserInfo(address _user) external view returns (UserInfo memory)
function getReferralInfo(address _user) external view returns (ReferralInfo memory)
```

## Referral System

The contract implements a two-level referral program:

- **Level 1**: Default 10% (1000 basis points) - Direct referrals
- **Level 2**: Default 3% (300 basis points) - Indirect referrals
- **Maximum**: 50% per level (configurable by owner)
- **Claiming**: Enabled/disabled by contract owner

## Security

- Built with OpenZeppelin v5.4.0 contracts
- ReentrancyGuard protection on critical functions
- Owner-only administrative functions
- Input validation on all parameters
- Custom error messages for gas efficiency

## Tech Stack

- **Solidity**: 0.8.20
- **Hardhat**: Smart contract development environment
- **OpenZeppelin**: Security-audited contract libraries
- **Viem**: TypeScript interface for Ethereum
- **Hardhat Ignition**: Declarative deployment system

## Network Configuration

Configured for SKALE Network with:
- High gas limits optimized for SKALE's architecture
- Custom RPC endpoints for mainnet and testnet
- Verification support through Hardhat

## License

MIT
