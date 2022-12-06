// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

// Any imports go here

// AggregatorV3Interface allows us to interact with price feeds
// As we are doing an import will need to add a dependency in config + remappings
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

// Another import
import "@openzeppelin/contracts/access/Ownable.sol";

contract Lottery is VRFConsumerBaseV2, Ownable {
    // Make an array of all the players
    address payable[] public players;
    address payable public recentWinner;
    uint256 public usdEntryFee;
    uint256[] public randomness;
    AggregatorV3Interface internal ethUsdPriceFeed;
    VRFCoordinatorV2Interface COORDINATOR;
    enum LOTTERY_STATE {
        OPEN,
        CLOSED,
        CALCULATING_WINNER
    }

    LOTTERY_STATE public lottery_state;

    // Grab the VRF variables
    uint64 s_subscriptionId;
    address vrfCoordinator = 0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D;
    bytes32 s_keyHash =
        0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;
    uint32 callbackGasLimit = 40000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;

    // Need an event
    event RequestedRandomness(uint256 requestId);

    // Constructor is used to initialize the state variables in a contract
    // As from before we want to pass in the address of the price feed
    // Can also add any inherited constructors
    constructor(address _priceFeedAddress, uint64 subscriptionId)
        VRFConsumerBaseV2(vrfCoordinator)
    {
        usdEntryFee = 50 * (10**18); // Define the entry fee
        ethUsdPriceFeed = AggregatorV3Interface(_priceFeedAddress); // Initialise the aggregator
        lottery_state = LOTTERY_STATE.CLOSED; // initialise this to closed

        // VRF Coordinator
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_subscriptionId = subscriptionId;
    }

    function enter() public payable {
        // Need a $50 minimum - developed the getEntranceFee function to get this
        require(
            msg.value >= getEntranceFee(),
            "You need to spend more ETH to enter ($50 min.)!"
        );
        // Another requirement is that the lottery state is open
        require(lottery_state == LOTTERY_STATE.OPEN);

        players.push(payable(msg.sender)); // add the sender to the array of player
    }

    // Function to get the price of Eth from the price feed
    function getEntranceFee() public view returns (uint256) {
        (, int256 price, , , ) = ethUsdPriceFeed.latestRoundData(); // this is the price per Ethereum (18 DP)

        // Adjust to the correct type, and the correct number of decimals
        uint256 adjustedPrice = uint256(price) * 10**10;
        // $50 @ $2000 per Eth
        // Then need 50/2000 - however can't do decimals
        // Therefore need 50 * big number / 2000
        uint256 costToEnter = (usdEntryFee * 10**18) / adjustedPrice;
        return costToEnter;
    }

    // Need to iterate through different phases of the contract
    // Can do this with Enums - these are a way to create user defined types in solidity
    // This function will start the lottery
    function startLottery() public onlyOwner {
        require(
            lottery_state == LOTTERY_STATE.CLOSED,
            "Cannot start new lottery until, old one is closed."
        );
        // Start the lottery now
        lottery_state = LOTTERY_STATE.OPEN;
    }

    function endLottery() public onlyOwner returns (uint256 requestId) {
        /////////////////////////////////////////////
        // Need to add some randomness here!
        // Cannot reach a consensus
        // Can get something pseudorandom
        // We don't want anything exploitable
        /////////////////////////////////////////////

        // Method 1 - Globally available variables - hashed
        //     uint256(
        //         keccack256(
        //             abi.encodePacked(
        //                 nonce,
        //                 msg.sender, // predictable
        //                 block.difficulty, // can actually be manipulated!
        //                 block.timestamp // predictable
        //             )
        //         )
        //     ) % players.length;
        // }

        // Method 2 - Need to look outside the blockchain - Chainlink VRF
        // Uses the response from a chainlink node

        // Change the state of lottery - will lock out the contract
        lottery_state = LOTTERY_STATE.CALCULATING_WINNER;

        require(
            lottery_state != LOTTERY_STATE.CLOSED,
            "Cannot end lottery if already closed."
        );

        // There are 2 things going on - firstly requesting from the oracle
        // Then need to fulfil the request - contract tag
        // We need to define this - what do I need to do once I have received a valid proof?
        // Call a second transaction itself - need to match the name

        // Will revert if subscription is not set and funded.
        requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        emit RequestedRandomness(requestId);
    }

    // We need to override this function now so it knows what to do
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
        internal
        override
    {
        require(
            lottery_state == LOTTERY_STATE.CALCULATING_WINNER,
            "You aren't there yet!"
        );

        require(randomWords.length > 0, "random-not-found");

        // Need to pick a winner from the list of players
        uint256 winningIndex = (randomWords[0] % players.length) + 1;
        // uint256 winningIndex = randomWords % players.length;

        // Pay the recent winner the balance of the contract
        recentWinner = players[winningIndex];
        recentWinner.transfer(address(this).balance);

        // Reset
        players = new address payable[](0);
        lottery_state = LOTTERY_STATE.CLOSED;

        // Store the randomness
        randomness = randomWords;
    }
}
