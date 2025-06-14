// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "../src/TicTacToe.sol";

contract SlotMachine {
    struct Game {
        bytes3 board;
        address player1;
        address player2;
    }

    mapping(uint256 => Game) public games;

    constructor() {
        games[1] = Game(bytes3(0), address(1), address(2));
    }

    function getBoard(uint256 gameId) public returns (bytes3) {
        assembly {
            mstore(0x80, gameId)
            mstore(0xA0, 0)
            let slot0 := sload(keccak256(0x80, 0x40))
            let board := and(sub(shl(24, 1), 1), slot0)
            mstore(0, shl(232, board))
            return(0x00, 0x20)
        }
    }

    // function testMemory() public returns (bytes3) {
    //     assembly {
    //         mstore(0x80, 0x123456) // Store value
    //         return(0x80, 0x03) // Return only 3 bytes
    //     }
    // }
}

contract BytesCheck {
    mapping(bytes3 => bool) public winningMarks;

    constructor() {
        initializeWinningMarks();
    }

    function initializeWinningMarks() public {
        winningMarks[bytes3(0x000007)] = true; // [0, 1, 2] - 0b000000111
        winningMarks[bytes3(0x000038)] = true; // [3, 4, 5] - 0b000111000
        winningMarks[bytes3(0x0001C0)] = true; // [6, 7, 8] - 0b111000000
        winningMarks[bytes3(0x000049)] = true; // [0, 3, 6] - 0b001001001
        winningMarks[bytes3(0x000092)] = true; // [1, 4, 7] - 0b010010010
        winningMarks[bytes3(0x000124)] = true; // [2, 5, 8] - 0b100100100
        winningMarks[bytes3(0x000111)] = true; // [0, 4, 8] - 0b100010001
        winningMarks[bytes3(0x000054)] = true; // [2, 4, 6] - 0b001010100
    }

    function boringCheck(bytes3 key) external view returns (bool result) {
        result = winningMarks[key];
    }
    function check(bytes3 key) external view returns (bool result) {
        // console2.logBytes(msg.data);
        assembly {
            // Calculate the storage slot of the mapping
            // Assume the mapping is stored at slot 0
            // keccak256(pad(key, 32) . pad(slot, 32))
            // let ptr := mload(0x40) // get free memory pointer
            mstore(0x80, key) // left-align bytes3 in 32 bytes
            mstore(0xA0, 0) // slot of the mapping is 0
            let storageKey := keccak256(0x80, 0x40)

            // Load the bool value (stored as uint256: 0 or 1)
            result := sload(storageKey)
        }
    }

    function check2(bytes3 key) external returns (bool result) {
        // check using call()
        // bytes4 first;
        // bytes32 second;
        assembly {
            let ptr := mload(0x40)
            mstore(
                ptr,
                0x042a6bd000000000000000000000000000000000000000000000000000000000
            )
            mstore(add(ptr, 0x04), key)
            // first := mload(ptr)
            // second := mload(add(ptr, 0x04))
            let callSuccess := staticcall(
                gas(),
                address(),
                ptr,
                0x24,
                ptr,
                0x20
            )
            if iszero(callSuccess) {
                mstore(
                    0x00,
                    0xAA00000000000000000000000000000000000000000000000000000000000000
                )
                revert(0, 4)
            }
            result := mload(ptr)
        }
        // console2.logBytes4(first);
        // console2.logBytes32(second);
    }
}

contract TicTacToeTest is Test {
    TicTacToe public ticTacToe;

    function setUp() public {
        ticTacToe = new TicTacToe();
    }

    function testGetsCorrectBoard() public {
        SlotMachine slotMachine = new SlotMachine();
        vm.store(
            address(slotMachine),
            keccak256(abi.encode(1, 0)),
            bytes32(
                0x0000000000000000000000000000000000000000000000000000000000000001
            )
        );
        bytes3 board = slotMachine.getBoard(1);
        console2.logBytes3(board);
    }

    function testSetsCorrectCell() public {
        uint256 gameId = ticTacToe.newGame(address(1), address(2));
        console2.log("gameId", gameId);
        play(address(1), gameId, 1);
        play(address(2), gameId, 0);
        play(address(1), gameId, 3);
        play(address(2), gameId, 4);
        play(address(1), gameId, 5);
        play(address(2), gameId, 8);
        // play(address(1), gameId, 6);
        assertEq(ticTacToe.whoWon(gameId), address(2));
        // assertEq(ticTacToe.getBoard(gameId), bytes3(0x001010));
    }

    function test_check_player_won() public {
        uint256 gameId = ticTacToe.newGame(address(1), address(2));
        // console2.logBytes32(
        bytes32 slot0 = vm.load(
            address(ticTacToe),
            keccak256(abi.encode(gameId, 0))
        );
        assembly {
            slot0 := or(slot0, shl(9, 0x000111))
        }
        vm.store(address(ticTacToe), keccak256(abi.encode(gameId, 0)), slot0);
        console2.logBytes32(
            vm.load(address(ticTacToe), keccak256(abi.encode(gameId, 0)))
        );
        assert(ticTacToe.ifWon(gameId, address(2)));
        // console2.logBytes32(
        //     vm.load(address(ticTacToe), keccak256(abi.encode(gameId, 0)))
        // );
        // vm.store(
        //     address(ticTacToe),
        //     keccak256(abi.encode(gameId, 0)),
        //     bytes32(
        //         0x0000000000000000000000000000000000000000000000000000000000000001
        //     )
        // );
        // assert(ticTacToe.ifWon(gameId, address(1)));
        // assert(ticTacToe.ifWon(gameId, address(2)));
    }

    function test_check() public {
        bytes3[8] memory keys = [
            bytes3(0x000007),
            bytes3(0x000038),
            bytes3(0x0001C0),
            bytes3(0x000049),
            bytes3(0x000092),
            bytes3(0x000124),
            bytes3(0x000111),
            bytes3(0x000054)
        ];
        BytesCheck c = new BytesCheck();
        for (uint i = 0; i < keys.length; i++) {
            bytes3 key = keys[i];
            assert(c.check2(key));
        }
        // c.check(0x000124);
        // c.check2(0x000124);
        // wow(0x000124);
    }

    function wow(bytes3 q) public {
        bytes32 ans;
        assembly {
            ans := shl(232, q)
        }
        console2.logBytes32(ans);
    }

    function play(address player, uint256 gameId, uint8 index) public {
        bytes32 mask;
        assembly {
            mask := shl(add(9, index), 1)
        }
        console2.log("mask");
        console2.logBytes32(mask);
        console2.log("board");
        console2.logBytes3(ticTacToe.getBoard(gameId));

        vm.prank(player);
        ticTacToe.play(gameId, index);
    }
}
