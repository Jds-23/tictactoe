// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;

import "forge-std/Script.sol";

import "forge-std/console2.sol";

import "../src/TicTacToe.sol";

contract TicTacToeScript is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address owner = vm.addr(deployerPrivateKey);

    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        TicTacToe ttt = new TicTacToe();
        console2.log("TicTacToe deployed to", address(ttt));
        vm.stopBroadcast();
    }
}

contract TicTacToeDebugScript is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address owner = vm.addr(deployerPrivateKey);

    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        TicTacToe ttt = TicTacToe(0xc7f70973c290585fA3Fda16970B3F46a5283c39e);
        (, address player1, address player2) = ttt.games(1);
        console2.log("TicTacToe player1", player1);
        console2.log("TicTacToe player2", player2);
        vm.stopBroadcast();

        vm.startPrank(owner);
        ttt.play(1, 0);
    }
}
