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

    // Events
    event RaffleEntered(address indexed player);

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
        s_lastTimeStamp = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
    }

    function enterRaffle() external payable {
        if (msg.value < i_ticketFee) revert Raffle__NotEnoughEthSent();
        // add player to array
        s_players.push(payable(msg.sender));
        // emit event when updating storage variable
        emit RaffleEntered(msg.sender);
    }

    // 1. Get a random number
    // 2. Pick winner
    // 3. This function should be called automatically with chainlink automation
    function pickWinner() external {
        // time elapsed < draw interval
        if ((block.timestamp - s_lastTimeStamp) < i_drawInterval) {
            revert();
        }
        // 1. Request the RNG
        // 2. Retrieve the random number
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, // gas lane
            i_subscriptionId,
            REQUEST_CONFIRMATIONS, // block confirmations
            i_callbackGasLimit,
            NUM_WORDS // no. of random numbers
        );
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        (bool success, ) = s_recentWinner.call{value: address(this).balance}("");

        if (!success) {
            revert Raffle__TransferFailed();
        }
        
    }

    /* Getters */

    function getTicketFee() public view returns (uint256) {
        return i_ticketFee;
    }
}
