// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
// import {VRFCoordinatorV2Mock} from "../mocks/VRFCoordinatorV2Mock.sol";
// import {CreateSubscription} from "../../script/Interactions.s.sol";

contract RaffleTest is  StdCheats, Test {
    Raffle raffle;
    HelperConfig hc;

    uint256 ticketFee = 0.01 ether;
    uint256 drawInterval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, hc) = deployer.run();

        (ticketFee,
        drawInterval,
        vrfCoordinator,
        gasLane,
        subscriptionId,
        callbackGasLimit) = hc.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    // enter raffle //
    function testRaffleRevertsWhenYouDontPayEnough() public {
        // arrange
        vm.prank(PLAYER); // Sets msg.sender to the specified address for the next call
        // act + assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector); // If the next call does not revert with the expected data message, then expectRevert will
        raffle.enterRaffle();
    }

    function testPlayerIsAddedToPlayerArray() public {
        // arrange
        vm.prank(PLAYER); // same as prank but gives balance
        
        // act 
        raffle.enterRaffle{value: ticketFee}();

        // assert
        address playerRecorded = raffle.getPlayerFromPlayerArray(0);
        assert(playerRecorded == PLAYER);

    }
}