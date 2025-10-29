# Smart Contract Lottery

A decentralized lottery system built with Solidity and Foundry.

## Overview

This project implements a provably fair lottery (raffle) system using Chainlink VRF for randomness and Chainlink Automation for automatic winner selection.

## Features

- Users can enter the raffle by paying an entrance fee
- Automated periodic draws using Chainlink Automation
- Provably random winner selection using Chainlink VRF v2.5
- Winner receives the entire prize pool

## Smart Contracts

- `Raffle.sol` - Main lottery contract

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/)

### Installation

```shell
git clone <repository-url>
cd smart-contract-lottery
forge install
```

### Build

```shell
forge build
```

### Test

```shell
forge test
```

### Format

```shell
forge fmt
```

### Deploy

```shell
forge script script/DeployRaffle.s.sol --rpc-url <your_rpc_url> --private-key <your_private_key>
```

## License

MIT
