# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a gas-optimized smart contract implementing an on-chain Tic-Tac-Toe game on Ethereum. The contract uses extensive Yul assembly for optimization and bit manipulation for efficient board state storage.

## Common Commands

### Build and Test
- `forge build` - Compile smart contracts
- `forge test` - Run all tests
- `forge test --match-test testFunctionName` - Run specific test
- `forge test -vvvv` - Run tests with verbose output for debugging
- `forge fmt` - Format Solidity code

### Development
- `forge script script/TicTacToe.s.sol` - Run deployment script
- `forge coverage` - Generate test coverage report

## Architecture

### Core Contract Structure
The main `TicTacToe.sol` contract uses a highly optimized approach:

- **Board Representation**: Uses `bytes3` (24 bits) to store game state
  - Bits 0-8: Player 1 marks
  - Bits 9-17: Player 2 marks  
  - Bit 23: Turn indicator (0 = player1, 1 = player2)
- **Assembly Optimization**: Extensive use of Yul inline assembly for gas efficiency
- **Winning Patterns**: Pre-computed winning combinations stored in `winningMarks` mapping

### Key Components
- `src/TicTacToe.sol` - Main game contract with assembly optimizations
- `test/TicTacToe.t.sol` - Comprehensive fuzz testing suite
- `script/TicTacToe.s.sol` - Deployment and debug scripts

### Events and Errors
- `NewGame(address indexed player1, address indexed player2, uint256 gameId)`
- `Played(uint256 indexed gameId, bytes3 board)`
- Custom errors: `SameAddress`, `InvalidIndex`, `NotYourTurn`, `CellAlreadyPlayed`, `OpponentWon`

### Testing Strategy
The test suite uses extensive fuzz testing to verify:
- Game state consistency
- Player turn validation
- Winning condition detection
- Event emission verification
- Edge case handling

### Dependencies
- **forge-std**: Foundry standard library for testing
- **solady**: Gas-optimized Solidity utilities library

## Development Notes

### Gas Optimization Focus
This contract prioritizes gas efficiency through:
- Bit manipulation instead of arrays for board state
- Yul assembly for core game logic
- Pre-computed winning patterns
- Optimized storage layouts

### Assembly Usage
The contract contains significant inline assembly code. When modifying assembly sections:
- Understand the bit layout for player marks
- Test thoroughly with fuzz testing
- Verify gas consumption doesn't increase significantly
- Maintain the existing optimization patterns