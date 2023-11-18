// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";


contract RaffleTest is Test {

    /* Events */
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);

    Raffle raffle;
    HelperConfig helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;



    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    function setUp() external { // This runs before every single test function
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (entranceFee,
        interval,
        vrfCoordinator,
        gasLane,
        subscriptionId,
        callbackGasLimit,
        link,
        ) = helperConfig.activeNetworkConfig();

        vm.deal(PLAYER, STARTING_USER_BALANCE);

    }

    function testRaffleStartsOpen() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRevertsInsufficientFunds() public {
        vm.prank(PLAYER);
        
        vm.expectRevert(Raffle.Raffle__InsufficientFunds.selector);
        raffle.enter();
        
    }

    function testSufficientFunds() public {
        vm.prank(PLAYER);
        raffle.enter{value: entranceFee}();

        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
        
    }

    function testEntranceEvent() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enter{value: entranceFee}();

    }

    function testRevertWhenCalculating() public {
        //First set up a calculating raffle
        vm.prank(PLAYER);
        raffle.enter{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enter{value: entranceFee}();


    }

    function testNoNeedEarlyUpkeep() public {
        vm.prank(PLAYER);
        raffle.enter{value: entranceFee}();
        vm.warp(block.timestamp + interval/2);
        vm.roll(block.number + 1);
        vm.prank(PLAYER);
        (bool needUpkeep, ) = raffle.checkUpkeep("");
        assert (!needUpkeep);
    }

    function testPUKOnlyIfCheckUpkeep() public raffleEnteredAndTimePassed {
        raffle.performUpkeep("");
    }

    function testPUKFails() public {
     
        uint256 currentBalance = 4e16;
        uint256 numPlayers = 0;
        uint256 raffleState = uint256(raffle.getRaffleState());

        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, raffleState)
        );
        raffle.performUpkeep("");
    }
     

    // EVENTS (let PUK = PerformUpkeep)
    function testPUKUpdatesRaffleState() raffleEnteredAndTimePassed skipFork public {

        // gets events in future
        vm.recordLogs(); 
        raffle.performUpkeep("");

        // Accessing events
        Vm.Log[] memory logEntries = vm.getRecordedLogs();
        bytes32 requestId = logEntries[1].topics[1]; // the 2nd topic from the 2nd logEntry 

        assert(uint256(requestId) > 0); // we have a requestId emitted (so the event happened!)
        assert(uint256(raffle.getRaffleState()) == 1); // 'CALCULATING' state
    }

    function test_FRW_Only_After_PUK(uint256 randomRequestId)  skipFork public {
        vm.expectRevert("nonexistent request");

        // Trying to fulfill random words without requesting random words
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId, address(raffle)
        );
    }
    function testFullContract() public raffleEnteredAndTimePassed skipFork {
        // Do everything basically
        uint256 STARITNG_USER_BALANCE = 1 ether;
        // Arrange
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;

        // let bunch of people join the raffle
        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
             address player = address(uint160(i));
             hoax(player, STARITNG_USER_BALANCE);
             raffle.enter{value: entranceFee}();
        }

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // now that we got the requestID, since performUpkeep already requested for us, now we gotta act as chainlink and fulfill it
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        assert(uint256(raffle.getRaffleState()) == 0); // state should be 'OPEN' because we fulfilled

        address winner = raffle.getRecentWinner();
        assert(winner != address(0));
        console.log(raffle.getNumPlayers());
        assert(raffle.getNumPlayers() == 0); // since raffle is over, the array should be reset to empty

        console.log(winner.balance);
        console.log(entranceFee * (additionalEntrants+1));
        assert(winner.balance == STARITNG_USER_BALANCE + entranceFee * (additionalEntrants));




    }

    modifier raffleEnteredAndTimePassed()  {
        vm.prank(PLAYER);
        raffle.enter{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != 31337) {return;}
        _;
    }
}