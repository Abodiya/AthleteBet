
# Athlete Performance Betting Smart Contract

## Overview

This smart contract implements a decentralized betting system for athlete performance metrics on the Stacks blockchain. It allows users to place bets on athlete performance, manage their positions, and interact with the betting ecosystem in a trustless manner.

## Features

- Place performance bets with required stake
- Close performance bets
- Transfer bet positions between users
- Add stake to existing positions
- Force close positions that fall below margin call threshold
- Safe mathematical operations to prevent overflows
- Access control for administrative functions

## Contract Details

### Constants

- `CONTRACT-ADMINISTRATOR`: The address that has special permissions to update the performance metric
- `STATS-FEED-EXPIRY-BLOCKS`: The number of blocks after which the stats feed is considered expired (600 blocks, approximately 10 minutes)
- `REQUIRED-STAKE-RATIO`: The required stake ratio for placing bets (150%)
- `MARGIN-CALL-THRESHOLD`: The threshold below which a position can be force closed (120%)
- `MINIMUM-PERFORMANCE-BET`: The minimum bet amount (1.00 tokens, 8 decimal places)
- `MAXIMUM-PERFORMANCE-VALUE`: The maximum allowed performance metric value

### Error Codes

The contract defines several error codes for various scenarios, such as:

- Unauthorized access
- Insufficient balance
- Invalid bet amount
- Expired stats feed
- Insufficient stake deposit
- Arithmetic overflow

### Main Functions

1. `update-performance-metric`: Allows the contract administrator to update the current performance metric
2. `place-performance-bet`: Enables users to place a bet on the athlete's performance
3. `close-performance-bet`: Allows users to close their existing bets
4. `transfer-bet-position`: Permits users to transfer their bet positions to other users
5. `add-stake-to-position`: Allows users to add more stake to their existing positions
6. `force-close-position`: Enables anyone to force close a position that falls below the margin call threshold

### Read-Only Functions

- `get-bettor-balance`: Retrieves the balance of a specific bettor
- `get-total-active-bets`: Returns the total supply of active bets
- `get-current-performance-metric`: Fetches the current performance metric
- `get-position-details`: Retrieves the details of a bettor's position
- `calculate-position-stake-ratio`: Calculates the current stake ratio for a given position

## Usage

To interact with this smart contract, users need to call the public functions using a Stacks wallet or through a dApp interface that integrates with this contract.

## Security Considerations

- The contract implements safe math operations to prevent arithmetic overflows
- Access control is in place for administrative functions
- A stake ratio system ensures sufficient collateral for bets
- Margin calls are implemented to maintain system solvency

## Development and Testing

To further develop or test this smart contract:

1. Set up a Clarity development environment
2. Deploy the contract to a Stacks testnet
3. Interact with the contract using Clarity console or a front-end application
4. Thoroughly test all functions with various scenarios and edge cases

## Disclaimer

This smart contract is provided as-is. Users interact with the contract at their own risk. It is recommended to thoroughly audit and test the contract before any real-world usage.
