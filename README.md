# BTCYieldFarm

BTCYieldFarm is a cross-chain AMM liquidity pool for Bitcoin yield farming on Stacks. This decentralized protocol allows users to provide liquidity and earn rewards through automated market making for BTC-based assets.

## Features

- **Automated Market Making (AMM)**: Create and manage liquidity pools with constant product formula
- **Yield Farming**: Stake liquidity tokens to earn BTC yield token rewards
- **Cross-chain Support**: Designed for Bitcoin-based assets on the Stacks blockchain
- **Fee Collection**: 0.3% trading fees distributed to liquidity providers
- **Slippage Protection**: Built-in slippage tolerance mechanisms
- **Reward Distribution**: Block-based reward system with configurable rates
- **Multi-pool Support**: Create and manage multiple trading pairs

## Technical Specifications

- **Blockchain**: Stacks
- **Language**: Clarity
- **Standard**: SIP-010 Fungible Token Standard
- **Fee Rate**: 0.3% (30 basis points)
- **Minimum Liquidity**: 1,000 tokens
- **Contract Version**: 1.0.0

### Architecture

The contract implements several key components:

- **Liquidity Pools**: Store trading pairs with reserves and metadata
- **Liquidity Providers**: Track user liquidity positions
- **Reward System**: Manage staking and reward distribution
- **Token Management**: Native BTC yield token for rewards

## Installation

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) v2.3.2+
- Node.js v18+
- TypeScript v5.3+

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd BTCYieldFarm
```

2. Install dependencies:
```bash
cd BTCYieldFarm_contract
npm install
```

3. Run tests:
```bash
npm test
```

4. Watch mode for development:
```bash
npm run test:watch
```

## Usage Examples

### Initialize Contract

```clarity
(contract-call? .BTCYieldFarm initialize)
```

### Create a Liquidity Pool

```clarity
(contract-call? .BTCYieldFarm create-pool
  'SP000000000000000000002Q6VF78.token-a
  'SP000000000000000000002Q6VF78.token-b
  u1000000  ;; initial amount of token-a
  u2000000) ;; initial amount of token-b
```

### Add Liquidity

```clarity
(contract-call? .BTCYieldFarm add-liquidity
  u1        ;; pool-id
  u500000   ;; amount of token-x
  u1000000  ;; amount of token-y
  u100000)  ;; minimum liquidity tokens expected
```

### Swap Tokens

```clarity
(contract-call? .BTCYieldFarm swap
  u1                                           ;; pool-id
  'SP000000000000000000002Q6VF78.token-a      ;; input token
  u100000                                      ;; input amount
  u95000)                                      ;; minimum output amount
```

### Stake for Rewards

```clarity
(contract-call? .BTCYieldFarm stake-liquidity
  u1       ;; pool-id
  u50000)  ;; amount of liquidity tokens to stake
```

### Claim Rewards

```clarity
(contract-call? .BTCYieldFarm claim-rewards u1) ;; pool-id
```

## Contract Functions Documentation

### Public Functions

#### `initialize()`
- Initializes the contract (owner only, one-time operation)
- **Returns**: `(response bool uint)`

#### `create-pool(token-x principal, token-y principal, initial-x uint, initial-y uint)`
- Creates a new liquidity pool with initial reserves
- **Parameters**:
  - `token-x`: First token contract address
  - `token-y`: Second token contract address
  - `initial-x`: Initial amount of token-x
  - `initial-y`: Initial amount of token-y
- **Returns**: `(response uint uint)` - Pool ID on success

#### `add-liquidity(pool-id uint, amount-x uint, amount-y uint, min-liquidity uint)`
- Adds liquidity to an existing pool
- **Parameters**:
  - `pool-id`: Target pool identifier
  - `amount-x`: Amount of token-x to add
  - `amount-y`: Amount of token-y to add
  - `min-liquidity`: Minimum liquidity tokens expected (slippage protection)
- **Returns**: `(response uint uint)` - Liquidity tokens minted

#### `remove-liquidity(pool-id uint, liquidity-tokens uint, min-x uint, min-y uint)`
- Removes liquidity from a pool
- **Parameters**:
  - `pool-id`: Target pool identifier
  - `liquidity-tokens`: Amount of liquidity tokens to burn
  - `min-x`: Minimum token-x expected
  - `min-y`: Minimum token-y expected
- **Returns**: `(response {amount-x: uint, amount-y: uint} uint)`

#### `swap(pool-id uint, token-in principal, amount-in uint, min-amount-out uint)`
- Executes a token swap within a pool
- **Parameters**:
  - `pool-id`: Target pool identifier
  - `token-in`: Input token contract address
  - `amount-in`: Input token amount
  - `min-amount-out`: Minimum output amount (slippage protection)
- **Returns**: `(response uint uint)` - Output amount

#### `stake-liquidity(pool-id uint, amount uint)`
- Stakes liquidity tokens to earn rewards
- **Parameters**:
  - `pool-id`: Target pool identifier
  - `amount`: Amount of liquidity tokens to stake
- **Returns**: `(response uint uint)`

#### `claim-rewards(pool-id uint)`
- Claims accumulated yield farming rewards
- **Parameters**:
  - `pool-id`: Target pool identifier
- **Returns**: `(response uint uint)` - Reward amount claimed

### Read-Only Functions

#### `get-pool-info(pool-id uint)`
- Retrieves complete pool information
- **Returns**: Pool data including reserves, tokens, and total supply

#### `get-user-liquidity(pool-id uint, user principal)`
- Gets user's liquidity position in a pool
- **Returns**: User's liquidity token balance

#### `get-user-rewards(user principal, pool-id uint)`
- Retrieves user's reward information
- **Returns**: Accumulated rewards and staking data

#### `get-swap-amount-out(pool-id uint, token-in principal, amount-in uint)`
- Calculates output amount for a potential swap
- **Returns**: Expected output amount after fees

#### `get-total-pools()`
- Returns the total number of pools created
- **Returns**: `uint` - Total pool count

#### `is-initialized()`
- Checks if the contract has been initialized
- **Returns**: `bool` - Initialization status

#### `get-btc-yield-balance(user principal)`
- Gets user's BTC yield token balance
- **Returns**: `uint` - Token balance

## Deployment Guide

### Local Development

1. Start Clarinet console:
```bash
clarinet console
```

2. Deploy contract:
```clarity
::deploy_contract BTCYieldFarm BTCYieldFarm_contract/contracts/BTCYieldFarm.clar
```

3. Initialize the contract:
```clarity
(contract-call? .BTCYieldFarm initialize)
```

### Testnet Deployment

1. Configure Clarinet.toml for testnet
2. Deploy using Clarinet:
```bash
clarinet deployments apply --network testnet
```

### Mainnet Deployment

1. Configure production settings in Clarinet.toml
2. Deploy with proper security review:
```bash
clarinet deployments apply --network mainnet
```

## Security Notes

### Important Considerations

- **Access Control**: Only contract owner can initialize the contract
- **Slippage Protection**: All trading functions include minimum output parameters
- **Integer Overflow**: Clarity provides built-in overflow protection
- **Reentrancy**: Contract design prevents reentrancy attacks
- **Fee Calculation**: Uses basis points for precise fee calculation

### Known Limitations

- **Square Root Implementation**: Uses iterative approximation (4 iterations max)
- **Minimum Liquidity**: 1,000 token minimum to prevent division by zero
- **Block-based Rewards**: Reward calculation depends on block height

### Audit Recommendations

- Conduct formal verification of mathematical operations
- Test edge cases with extreme token ratios
- Verify reward calculation accuracy over extended periods
- Review economic incentives and fee structures

### Best Practices

- Always use slippage protection when calling swap functions
- Monitor pool reserves before large transactions
- Claim rewards regularly to optimize gas costs
- Verify token contract addresses before creating pools

## Error Codes

- `u1001`: ERR_UNAUTHORIZED - Insufficient permissions
- `u1002`: ERR_INSUFFICIENT_BALANCE - Insufficient token balance
- `u1003`: ERR_INVALID_AMOUNT - Invalid amount specified
- `u1004`: ERR_POOL_NOT_FOUND - Pool does not exist
- `u1005`: ERR_INSUFFICIENT_LIQUIDITY - Not enough liquidity
- `u1006`: ERR_SLIPPAGE_TOO_HIGH - Slippage exceeds tolerance
- `u1007`: ERR_ALREADY_INITIALIZED - Contract already initialized

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add comprehensive tests
4. Submit a pull request

## License

ISC License - see package.json for details

## Version History

- **v1.0.0**: Initial release with core AMM and yield farming functionality