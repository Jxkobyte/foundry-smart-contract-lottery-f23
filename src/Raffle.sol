/* 
    Layout of Contract:
        version
        imports
        errors
        interfaces, libraries, contracts
        Type declarations
        State variables
        Events
        Modifiers
        Function

    Layout of Functions:
        constructor
        receive function (if exists)
        fallback function (if exists)
        external
        public
        internal
        private
        internal & private view & pure functions
        external & public view & pure functions
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

/** @title Raffle
 *  @author Jacob F
 *  @notice This contract is for creating a sample raffle
 *  @dev Implements Chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2, ConfirmedOwner {
    error Raffle__NotEnoughEthSent(); // prefix error with contract name and two underscores
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__RaffleUpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        RaffleState raffleState
    );

    // type declarations
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    // @dev Draw interval in seconds
    uint256 private immutable i_drawInterval;
    uint256 private immutable i_ticketFee;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    // Events
    event RaffleEntered(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 requestId);

    constructor(
        uint256 ticketFee,
        uint256 drawInterval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) ConfirmedOwner(msg.sender) {
        i_ticketFee = ticketFee;
        i_drawInterval = drawInterval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    // When is the winner chosen?
    /**
     * @dev Chainlink automation calls this function to see if it's time to pick a winner
     * 1. The interval between raffles has passed
     * 2. The raffle is in state OPEN
     * 3. The contract has players
     * 4. (implied) The subscription is funded with link
     * @return upkeepNeeded returns true if all the conditions above are true
     * @return performData not used
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        // will return these values automatically
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >=
            i_drawInterval;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 1;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, bytes(""));
    }

    // 1. Get a random number
    // 2. Pick winner
    // 3. This function should be called automatically with chainlink automation
    function performUpkeep() external {
        (bool upKeepNeeded, ) = checkUpkeep("");
        if (!upKeepNeeded)
            revert Raffle__RaffleUpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                s_raffleState
            );

        // update raffle state
        s_raffleState = RaffleState.CALCULATING;

        // 1. Request the RNG
        // 2. Retrieve the random number
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, // gas lane
            i_subscriptionId,
            REQUEST_CONFIRMATIONS, // block confirmations
            i_callbackGasLimit,
            NUM_WORDS // no. of random numbers
        );
        emit RequestedRaffleWinner(requestId);
    }

    function enterRaffle() external payable {
        if (msg.value < i_ticketFee) revert Raffle__NotEnoughEthSent();
        if (s_raffleState != RaffleState.OPEN) revert Raffle__RaffleNotOpen();

        // add player to array
        s_players.push(payable(msg.sender));
        // emit event when updating storage variable
        emit RaffleEntered(msg.sender);
    }


    /**
     * @dev This function is called by a chainlink VRF node
     * @param randomWords random numbers generated by VRF
     */
    function fulfillRandomWords(
        uint256 /* _requestId */,
        uint256[] memory randomWords
    ) internal override {
        // Checks, Effects, Interactions: CEI

        uint256 indexOfWinner = randomWords[0] % s_players.length;

        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        // update raffle state
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit PickedWinner(winner);
    

        (bool success, ) = s_recentWinner.call{value: address(this).balance}(
            ""
        );

        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /* Getters */

    function getTicketFee() public view returns (uint256) {
        return i_ticketFee;
    }
}
