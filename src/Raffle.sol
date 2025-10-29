// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.26;

/**
 * @title Raffle Contract
 * @author Calvin Kimani
 * @notice This is just a PoC Smart Contract Lottery
 */
contract Raffle {
    /* Types */
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
        address winner;
        mapping(uint256 => Entry) entries;
    }

    /* State Variables */
    mapping(uint256 => Round) public rounds;
    uint256 public currentRound;
    uint256 private immutable I_ENTRANCE_FEE;

    /**
     * @dev Interval in seconds between current round and next round
     */
    uint256 private immutable I_ROUND_INTERVAL;

    /* Events */
    event NewRound(uint256 _roundId);
    event NewEntry(uint256 _roundId, Entry _entry);
    event RoundEnded(uint256 _roundId, Entry _entry, uint256 _winnings);

    /* Errors */
    error Raffle__ErrInsufficientEntranceFee();
    error Raffle__ErrRoundNotExpired();

    /* Modifiers */
    modifier checkRoundIsExpired() {
        _checkRoundIsExpired();
        _;
    }

    /* Functions */
    constructor(uint256 _entranceFee, uint256 _roundInterval) {
        I_ENTRANCE_FEE = _entranceFee;
        I_ROUND_INTERVAL = _roundInterval;
        _createRound(0);
    }

    function enterRaffle() external payable {
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

    function pickWinner() public checkRoundIsExpired {}

    function _startRound() internal checkRoundIsExpired {
        uint256 newRoundId = currentRound + 1;

        _createRound(newRoundId);

        emit NewRound(newRoundId);
    }

    function _createRound(uint256 _roundId) internal {
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

    function _checkRoundIsExpired() internal view {
        Round storage round = rounds[currentRound];

        if (block.timestamp > round.endTime) {
            revert Raffle__ErrRoundNotExpired();
        }
    }
}
