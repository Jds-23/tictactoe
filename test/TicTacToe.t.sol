// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "../src/TicTacToe.sol";

contract TicTacToeFuzzTest is Test {
    TicTacToe public ttt;

    address player1 = makeAddr("player1");
    address player2 = makeAddr("player2");
    address notPlayer = makeAddr("notPlayer");

    uint256 gameId;

    // Event definitions for testing
    event NewGame(address indexed player1, address indexed player2, uint256 gameId);
    event Played(uint256 indexed gameId, bytes3 board);

    function setUp() public {
        ttt = new TicTacToe();
        gameId = ttt.newGame(player1, player2);
    }

    /// @notice Check if position is empty
    function isPositionEmpty(bytes3 board, uint8 index, bool isPlayer1) internal pure returns (bool) {
        if (index > 8) {
            revert("Invalid index");
        }
        if (isPlayer1) {
            console2.logBytes32(bytes32(1 << index));
            return (uint256(uint24(board)) & (1 << (index))) == 0;
        } else {
            return (uint256(uint24(board)) & (512 << (index))) == 0;
        }
    }

    /// @notice Count total moves made by a player
    function countMoves(bytes3 board, bool isPlayer1) internal pure returns (uint8) {
        uint8 count = 0;
        for (uint8 i = 0; i < 9; i++) {
            if (!isPositionEmpty(board, i, isPlayer1)) {
                console2.log("index", i);
                console2.log("isPlayer1", isPlayer1);
                count++;
            }
        }
        return count;
    }

    /// @notice Count total moves made by both players
    function countTotalMoves(bytes3 board) internal pure returns (uint8) {
        return countMoves(board, true) + countMoves(board, false);
    }

    /// @notice Determine whose turn it is
    function whoseTurn(bytes3 board) internal view returns (address) {
        return (uint256(uint24(board)) & (1 << 23)) == 0 ? player1 : player2;
    }

    /// @notice Create a fresh game for testing
    function createFreshGame() internal returns (uint256 newGameId) {
        return ttt.newGame(player1, player2);
    }

    /// @notice Get the board after a move without playing
    function getBoardAfterMove(uint256 gameId, uint8 position) internal returns (bytes3) {
        bytes3 board = ttt.getBoard(gameId);
        address currentPlayer = whoseTurn(board);
        if (currentPlayer == player1) {
            board = bytes3(uint24((uint24(board) | (1 << position)) ^ (1 << 23)));
        } else {
            board = bytes3(uint24((uint24(board) | (512 << position)) ^ (1 << 23)));
        }
        return board;
    }

    // =============================================
    // FUZZ TESTS - VALID SCENARIOS
    // =============================================

    /// @notice Fuzz test valid moves on empty positions
    function testFuzz_ValidMoves(uint8 position) public {
        vm.assume(position < 9);

        uint256 freshGameId = createFreshGame();
        bytes3 boardBefore = ttt.getBoard(freshGameId);

        address currentPlayer = whoseTurn(boardBefore);
        vm.prank(currentPlayer);

        // Only test if position is empty
        vm.assume(isPositionEmpty(boardBefore, position, currentPlayer == player1));

        // Should not revert
        ttt.play(freshGameId, position);

        // Verify position is now occupied
        bytes3 boardAfter = ttt.getBoard(freshGameId);
        assertFalse(isPositionEmpty(boardAfter, position, currentPlayer == player1));
        // Verify move count increased
        assertEq(countTotalMoves(boardAfter), countTotalMoves(boardBefore) + 1);
    }

    /// @notice Fuzz test alternating players
    function testFuzz_AlternatingPlayers(uint8[4] memory positions) public {
        uint256 freshGameId = createFreshGame();

        // Ensure all positions are valid and unique
        for (uint8 i = 0; i < 4; i++) {
            vm.assume(positions[i] < 9);
            for (uint8 j = i + 1; j < 4; j++) {
                vm.assume(positions[i] != positions[j]);
            }
        }

        // Player 1 moves
        vm.prank(player1);
        ttt.play(freshGameId, positions[0]);

        // Player 2 moves
        vm.prank(player2);
        ttt.play(freshGameId, positions[1]);

        // Player 1 moves again
        vm.prank(player1);
        ttt.play(freshGameId, positions[2]);

        // Player 2 moves again
        vm.prank(player2);
        ttt.play(freshGameId, positions[3]);

        // Verify 4 moves were made
        bytes3 finalBoard = ttt.getBoard(freshGameId);
        assertEq(countTotalMoves(finalBoard), 4);
    }

    // =============================================
    // FUZZ TESTS - INVALID GAME IDS
    // =============================================

    /// @notice Fuzz test with invalid game IDs
    function testFuzz_InvalidGameId(uint256 invalidGameId, uint8 position) public {
        vm.assume(position < 9);
        vm.assume(invalidGameId > ttt.gameCount()); // Non-existent game

        vm.prank(player1);
        vm.expectRevert();
        ttt.play(invalidGameId, position);
    }

    /// @notice Fuzz test with very large game IDs
    function testFuzz_ExtremeGameIds(uint256 extremeGameId, uint8 position) public {
        vm.assume(position < 9);
        vm.assume(extremeGameId > 1000000); // Very large game ID

        vm.prank(player1);
        vm.expectRevert();
        ttt.play(extremeGameId, position);
    }

    // =============================================
    // FUZZ TESTS - INVALID POSITIONS
    // =============================================

    /// @notice Fuzz test with out-of-bounds positions
    function testFuzz_OutOfBoundsPosition(uint8 invalidPosition) public {
        vm.assume(invalidPosition >= 9);
        vm.assume(invalidPosition <= 255); // Keep it reasonable

        uint256 freshGameId = createFreshGame();

        vm.prank(player1);
        vm.expectRevert();
        ttt.play(freshGameId, invalidPosition);
    }

    /// @notice Fuzz test playing on occupied positions
    function testFuzz_OccupiedPosition(uint8 position) public {
        vm.assume(position < 9);

        uint256 freshGameId = createFreshGame();

        // Player 1 makes first move
        vm.prank(player1);
        ttt.play(freshGameId, position);

        // Player 2 tries to play same position - should revert
        vm.prank(player2);
        vm.expectRevert();
        ttt.play(freshGameId, position);

        // Player 1 tries to play same position again - should also revert
        vm.prank(player1);
        vm.expectRevert();
        ttt.play(freshGameId, position);
    }

    // =============================================
    // FUZZ TESTS - WRONG PLAYERS
    // =============================================

    /// @notice Fuzz test unauthorized players
    function testFuzz_UnauthorizedPlayer(address randomPlayer, uint8 position) public {
        vm.assume(position < 9);
        vm.assume(randomPlayer != player1);
        vm.assume(randomPlayer != player2);
        vm.assume(randomPlayer != address(0));

        uint256 freshGameId = createFreshGame();

        vm.prank(randomPlayer);
        vm.expectRevert();
        ttt.play(freshGameId, position);
    }

    /// @notice Fuzz test wrong turn order
    function testFuzz_WrongTurnOrder(uint8 position) public {
        vm.assume(position < 9);

        uint256 freshGameId = createFreshGame();

        // Player 2 tries to go first (should be player 1's turn)
        vm.prank(player2);
        vm.expectRevert();
        ttt.play(freshGameId, position);
    }

    /// @notice Fuzz test player playing twice in a row
    function testFuzz_DoubleMove(uint8[2] memory positions) public {
        vm.assume(positions[0] < 9 && positions[1] < 9);
        vm.assume(positions[0] != positions[1]);

        uint256 freshGameId = createFreshGame();

        // Player 1 makes first move
        vm.prank(player1);
        ttt.play(freshGameId, positions[0]);

        // Player 1 tries to move again immediately - should revert
        vm.prank(player1);
        vm.expectRevert();
        ttt.play(freshGameId, positions[1]);
    }

    // =============================================
    // FUZZ TESTS - GAME STATE INVARIANTS
    // =============================================

    /// @notice Fuzz test that game state is preserved correctly
    function testFuzz_GameStateInvariants(uint8[5] memory moves) public {
        uint256 freshGameId = createFreshGame();

        // Ensure all moves are valid positions and unique
        for (uint8 i = 0; i < 5; i++) {
            for (uint8 j = i + 1; j < 5; j++) {
                vm.assume(moves[i] % 9 != moves[j] % 9);
            }
        }

        bytes3 initialBoard = ttt.getBoard(freshGameId);
        uint8 initialMoves = countTotalMoves(initialBoard);

        // Make alternating moves
        for (uint8 i = 0; i < 5; i++) {
            address currentPlayer = i % 2 == 0 ? player1 : player2;
            vm.prank(currentPlayer);
            ttt.play(freshGameId, moves[i] % 9);

            // Verify move count is correct after each move
            bytes3 currentBoard = ttt.getBoard(freshGameId);
            assertEq(countTotalMoves(currentBoard), initialMoves + i + 1);
        }
    }

    /// @notice Fuzz test that players can't modify other games
    function testFuzz_GameIsolation(uint8 position1, uint8 position2) public {
        vm.assume(position1 < 9 && position2 < 9);

        // Create two separate games
        uint256 game1 = createFreshGame();
        uint256 game2 = ttt.newGame(player1, player2);

        // Make move in game 1
        vm.prank(player1);
        ttt.play(game1, position1);

        // Verify game 2 is unaffected
        bytes3 game2Board = ttt.getBoard(game2);
        assertEq(countTotalMoves(game2Board), 0);

        // Make move in game 2
        vm.prank(player1);
        ttt.play(game2, position2);

        // Verify both games have exactly 1 move
        assertEq(countTotalMoves(ttt.getBoard(game1)), 1);
        assertEq(countTotalMoves(ttt.getBoard(game2)), 1);
    }

    // =============================================
    // FUZZ TESTS - EVENT LOGS
    // =============================================

    /// @notice Fuzz test event log for newGame
    function testFuzz_EventLog_NewGame(address p1, address p2) public {
        // Only test for valid, non-equal, non-zero addresses
        vm.assume(p1 != address(0) && p2 != address(0) && p1 != p2);
        vm.expectEmit(true, true, false, true, address(ttt));
        emit NewGame(p1, p2, ttt.gameCount());
        ttt.newGame(p1, p2);
    }

    /// @notice Fuzz test event log for play
    function testFuzz_EventLog_Play(uint8 position) public {
        vm.assume(position < 9);
        uint256 freshGameId = createFreshGame();
        bytes3 boardBefore = ttt.getBoard(freshGameId);
        bytes3 boardAfter = getBoardAfterMove(freshGameId, position);
        address currentPlayer = whoseTurn(boardBefore);
        vm.assume(isPositionEmpty(boardBefore, position, currentPlayer == player1));
        vm.prank(currentPlayer);
        vm.expectEmit(true, true, false, true, address(ttt));
        emit Played(freshGameId, boardAfter);
        ttt.play(freshGameId, position);
    }
}
