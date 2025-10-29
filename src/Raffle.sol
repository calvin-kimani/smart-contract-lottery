// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/* Imports */
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title Raffle Contract
 * @author Calvin Kimani
 * @notice This is just a PoC Smart Contract Lottery
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /* Types */
    enum State {
        CLOSED,
        OPEN,
        CALCULATING,
        ERROR
    }

    struct Entry {
        uint256 id;
        address participant;
        uint256 amount;
    }

    struct Round {
        uint256 id;
        uint256 startTime;
        uint256 endTime;
        uint256 totalEntries;
        uint256 totalAmount;
        uint256 winner;
        uint256 requestId;
        uint256 randomNumber;
        mapping(uint256 => Entry) entries;
    }

    /* State Variables */
    mapping(uint256 => Round) public rounds;
    uint256 public currentRound;
    State public raffleState = State.CLOSED;
    uint256 public immutable I_ENTRANCE_FEE;
    uint256 public immutable I_ROUND_INTERVAL;

    uint32 private constant NUM_WORDS = 1;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant CALLBACK_GAS_LIMIT = 40000;
    bytes32 private immutable I_KEYHASH;
    uint256 private immutable I_SUBSCRIPTION_ID;

    /* Events */
    event NewRound(uint256 _roundId);
    event NewEntry(uint256 _roundId, Entry _entry);
    event WinnerPicked(address _winner);
    event RoundEnded(uint256 _roundId, address _winner, uint256 _winnings);
    event DiceRolled(uint256 _requestId, uint256 _roundId);

    /* Errors */
    error Raffle__ErrRaffleNotOpen();
    error Raffle__ErrInsufficientEntranceFee();
    error Raffle__ErrRoundNotExpired();
    error Raffle__ErrPickWinnerRequestIdDoNotMatch(uint256 _requestId, uint256 _roundId);
    error Raffle__ErrPayWinner();
    error Raffle__ErrDiceAlreadyRolled(uint256 _roundId);

    /* Modifiers */
    modifier checkRoundIsExpired() {
        _checkRoundIsExpired();
        _;
    }

    /* Functions */
    constructor(
        uint256 _entranceFee,
        uint256 _roundInterval,
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint256 _subscriptionId
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        I_ENTRANCE_FEE = _entranceFee;
        I_ROUND_INTERVAL = _roundInterval;
        I_KEYHASH = _keyHash;
        I_SUBSCRIPTION_ID = _subscriptionId;

        _createRound(0);

        raffleState = State.OPEN;
    }

    function enterRaffle() external payable {
        if (raffleState != State.OPEN) {
            revert Raffle__ErrRaffleNotOpen();
        }

        if (msg.value < I_ENTRANCE_FEE) {
            revert Raffle__ErrInsufficientEntranceFee();
        }

        // Get Current round
        Round storage round = rounds[currentRound];
        uint256 currentEntry = round.totalEntries + 1;

        // create a new entry
        Entry memory newEntry = Entry({id: currentEntry, participant: msg.sender, amount: msg.value});

        round.entries[currentEntry] = newEntry;

        // Track Changes
        round.totalEntries = currentEntry;
        round.totalAmount = round.totalAmount + msg.value;

        // Log new entry
        emit NewEntry(round.id, newEntry);
    }

    function rollDice() external {
        Round storage round = rounds[currentRound];

        if (round.requestId != 0) {
            revert Raffle__ErrDiceAlreadyRolled(round.id);
        }

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: I_KEYHASH,
            subId: I_SUBSCRIPTION_ID,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: CALLBACK_GAS_LIMIT,
            numWords: NUM_WORDS,
            // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);

        round.requestId = requestId;

        emit DiceRolled(requestId, round.id);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        _pickWinner(randomWords[0], requestId);
    }

    function _startRound() internal checkRoundIsExpired {
        uint256 newRoundId = currentRound + 1;

        _createRound(newRoundId);

        raffleState = State.OPEN;

        emit NewRound(newRoundId);
    }

    function _pickWinner(uint256 _randomNumber, uint256 _requestId) internal checkRoundIsExpired {
        if (raffleState != State.OPEN) {
            revert Raffle__ErrRaffleNotOpen();
        }

        raffleState = State.CALCULATING;

        Round storage round = rounds[currentRound];

        if (_requestId != round.requestId) {
            revert Raffle__ErrPickWinnerRequestIdDoNotMatch(_requestId, round.id);
        }

        round.randomNumber = _randomNumber;

        if (round.totalEntries > 0) {
            uint256 winner = (_randomNumber % round.totalEntries) + 1;
            round.winner = winner;

            address winnerAddress = (round.entries[winner]).participant;
            emit WinnerPicked(winnerAddress);

            (bool success,) = payable(winnerAddress).call{value: round.totalAmount}("");
            if (!success) {
                raffleState = State.ERROR;
                revert Raffle__ErrPayWinner();
            }

            emit RoundEnded(currentRound, winnerAddress, round.totalAmount);
        }

        _startRound();
    }

    function _checkRoundIsExpired() internal view {
        Round storage round = rounds[currentRound];

        if (block.timestamp < round.endTime) {
            revert Raffle__ErrRoundNotExpired();
        }
    }

    function _createRound(uint256 _roundId) private {
        uint256 id = _roundId;

        Round storage newRound = rounds[id];

        uint256 currentTime = block.timestamp;
        newRound.id = id;
        newRound.startTime = currentTime;
        newRound.endTime = currentTime + I_ROUND_INTERVAL;
        newRound.totalEntries = 0;
        newRound.totalAmount = 0;

        currentRound = id;
    }
}
