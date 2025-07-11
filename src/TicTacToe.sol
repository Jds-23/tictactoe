// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
// contract updates
// 1. proxy
// 2. event log
// read solady code add best practices

contract TicTacToe {
    event NewGame(address indexed player1, address indexed player2, uint256 gameId);
    event Played(uint256 indexed gameId, bytes3 board);

    error SameAddress();
    error CallFailed();
    error InvalidIndex();
    error NotYourTurn();
    error CellAlreadyPlayed();
    error OpponentWon();

    struct Game {
        bytes3 board;
        address player1;
        address player2;
    }

    mapping(uint256 => Game) public games;
    uint256 public gameCount;
    mapping(bytes3 => bool) public winningMarks;

    constructor() {
        gameCount = 0;
        initializeWinningMarks();
    }

    function initializeWinningMarks() internal {
        winningMarks[bytes3(0x000007)] = true; // [0, 1, 2] - 0b000000111
        winningMarks[bytes3(0x000038)] = true; // [3, 4, 5] - 0b000111000
        winningMarks[bytes3(0x0001C0)] = true; // [6, 7, 8] - 0b111000000
        winningMarks[bytes3(0x000049)] = true; // [0, 3, 6] - 0b001001001
        winningMarks[bytes3(0x000092)] = true; // [1, 4, 7] - 0b010010010
        winningMarks[bytes3(0x000124)] = true; // [2, 5, 8] - 0b100100100
        winningMarks[bytes3(0x000111)] = true; // [0, 4, 8] - 0b100010001
        winningMarks[bytes3(0x000054)] = true; // [2, 4, 6] - 0b001010100
    }

    function newGame(address player1, address player2) public returns (uint256) {
        assembly {
            if eq(player1, player2) {
                mstore(0x00, 0x367558c300000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }
            let gc := sload(1)
            sstore(1, add(gc, 1))
            let ptr := mload(0x40)
            mstore(ptr, add(gc, 1))
            mstore(add(ptr, 32), 0)
            sstore(keccak256(ptr, 64), shl(24, player1))
            sstore(add(keccak256(ptr, 0x40), 1), player2)
            mstore(0x00, gc)
            let eventId := 0xc4490dfb76823bf820ad165c61a9db7902f1074fbe5954bbffac953275678dd7
            log3(0x00, 0x20, eventId, player1, player2)
            return(0x00, 0x20)
        }
    }

    function getBoard(uint256 gameId) public view returns (bytes3) {
        assembly {
            mstore(0x80, gameId)
            mstore(0xA0, 0)
            let slot0 := sload(keccak256(0x80, 0x40))
            let board := and(sub(shl(24, 1), 1), slot0)
            mstore(0, shl(232, board))
            return(0x00, 0x20)
        }
    }

    function check(bytes3 key) external view returns (bool result) {
        assembly {
            // Calculate the storage slot of the mapping
            // Assume the mapping is stored at slot 0
            // keccak256(pad(key, 32) . pad(slot, 32))
            let ptr := mload(0x40) // get free memory pointer
            mstore(ptr, key) // left-align bytes3 in 32 bytes
            mstore(add(ptr, 32), winningMarks.slot) // slot of the mapping is 0
            let storageKey := keccak256(ptr, 64)

            // Load the bool value (stored as uint256: 0 or 1)
            result := sload(storageKey)
        }
    }

    function ifWon(uint256 gameId, address player) public view returns (bool result) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, gameId)
            mstore(add(ptr, 32), 0)
            let slot0 := sload(keccak256(ptr, 64))
            let board := and(sub(shl(24, 1), 1), slot0)
            if eq(player, shr(24, slot0)) { result := shl(232, and(511, board)) } // 511 = 0x1FF = bits 0-8 for player 1
            if eq(player, sload(add(keccak256(ptr, 0x40), 1))) { result := shl(223, and(261632, board)) } // 261632 = 0x3FE00 = bits 9-17 for player 2
            mstore(add(ptr, 64), 0x042a6bd000000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 68), result)
            let callSuccess :=
                staticcall(
                    gas(), // Gas
                    address(), // Target contract
                    add(ptr, 64), // Value (0 for ERC20)
                    0x24,
                    add(ptr, 64),
                    0x20
                )
            if iszero(callSuccess) {
                mstore(0x00, 0x3204506f00000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }
            result := mload(add(ptr, 64))
        }
    }

    function whoWon(uint256 gameId) public view returns (address player) {
        bytes32 temp;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, gameId)
            mstore(add(ptr, 32), 0)
            let slot0 := sload(keccak256(ptr, 64))
            let board := and(sub(shl(24, 1), 1), slot0)
            mstore(add(ptr, 64), 0x042a6bd000000000000000000000000000000000000000000000000000000000)
            temp := shl(232, and(511, board))
            mstore(add(ptr, 68), shl(232, and(511, board)))
            let callSuccess :=
                staticcall(
                    gas(), // Gas
                    address(), // Target contract
                    add(ptr, 64), // Value (0 for ERC20)
                    0x24,
                    add(ptr, 64),
                    0x20
                )
            if iszero(callSuccess) {
                mstore(0x00, 0x3204506f00000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }
            if mload(add(ptr, 64)) { player := shr(24, slot0) }
            mstore(add(ptr, 64), 0x042a6bd000000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 68), shl(223, and(261632, board)))
            callSuccess :=
                staticcall(
                    gas(), // Gas
                    address(), // Target contract
                    add(ptr, 64), // Value (0 for ERC20)
                    0x24,
                    add(ptr, 64),
                    0x20
                )
            if iszero(callSuccess) {
                mstore(0x00, 0x3204506f00000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }
            if mload(add(ptr, 64)) { player := sload(add(keccak256(ptr, 0x40), 1)) }
        }
    }

    function play(uint256 gameId, uint8 index) public {
        assembly {
            if gt(index, 8) {
                mstore(0x00, 0x63df817100000000000000000000000000000000000000000000000000000000)
                revert(0, 4) // if the player is not the one to play, revert
            }
            let ptr := mload(0x40)
            mstore(ptr, gameId)
            mstore(add(ptr, 32), 0)
            let slot0 := sload(keccak256(ptr, 64))
            let board := and(sub(shl(24, 1), 1), slot0)
            let player := 0
            let mark := 0
            let playerBoard := 0
            switch iszero(and(shl(23, 1), board))
            case 0 {
                // zero means player 0's turn
                player := sload(add(keccak256(ptr, 0x40), 1))
                mark := 512 // 1024 is player 0's mark, as 1024 is 10000000000 in binary ending with 0
                playerBoard := shl(232, and(511, board)) // 261632 in binary is 1 1111 1111 0 0000 0000
                    // mask := shl(index, 1) // adding 9 to the index, to check if the cell is already played
            }
            default {
                // checking other player won
                // not zero means player 1's turn
                player := shr(24, slot0)
                mark := 1 // 1024 is player 1's mark, as 1024 is 10000000001 in binary ending with 1
                playerBoard := shl(223, and(261632, board)) // 261632 in binary is 1 1111 1111 0 0000 0000
                    // mask := shl(add(9, index), 1) // adding 9 to the index, to check if the cell is already played
            }
            if iszero(eq(player, caller())) {
                mstore(0x00, 0xe60c8f5800000000000000000000000000000000000000000000000000000000)
                revert(0, 4) // if the player is not the one to play, revert
            }
            if iszero(iszero(and(shl(index, 513), board))) {
                // if the cell is already played, revert. already played cell would be 1
                mstore(0x00, 0xcdc3a47600000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }
            mstore(add(ptr, 64), 0x042a6bd000000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 68), playerBoard)
            let callSuccess :=
                staticcall(
                    gas(), // Gas
                    address(), // Target contract
                    add(ptr, 64), // Value (0 for ERC20)
                    0x24,
                    add(ptr, 64),
                    0x20
                )
            if iszero(callSuccess) {
                mstore(0x00, 0x3204506f00000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }
            let result := mload(add(ptr, 64))
            if result {
                mstore(0x00, 0x7112a0f800000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }
            board := or(board, shl(index, mark)) // add the mark to the board
            board := xor(board, shl(23, 1)) // invert turn
            slot0 := or(and(not(sub(shl(24, 1), 1)), slot0), board) // update the board in the slot
            sstore(keccak256(ptr, 64), slot0) // update the storage
            mstore(ptr, shl(232, board))
            let eventId := 0x96c4bbea6f5ce0ef05d982c51fd274ab114c9e6239b73839f8d7d2c31679f129
            log2(ptr, 0x20, eventId, gameId)
        }
    }
}
