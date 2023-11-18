// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;
import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {

    function createSubscription(address vrfCoordinator, uint256 key) public returns (uint64) {
        console.log("Creating subscription on ChainId:", block.chainid);
        vm.startBroadcast(key);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Your subId is : ", subId);
        console.log("Please update subscriptionId in HelperConfig.s.sol");
        return subId;
    }

    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, , , , ,uint256 key) = helperConfig.activeNetworkConfig();
        return createSubscription(vrfCoordinator, key);
    }

    

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }

    
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;
    
    function fundSubscription (
        address vrfCoordinator,
        uint64 subId,
        address link,
        uint256 key
    ) public {
        console.log("Funding subscription: ", subId);
        console.log("using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainID: ", link);

        if (block.chainid == 31337) {
            vm.startBroadcast(key);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(subId, FUND_AMOUNT);
            vm.stopBroadcast();
        }
        else {
            vm.startBroadcast(key);
            LinkToken(link).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subId));
            vm.stopBroadcast();
        }

    }
    function fundSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, , uint64 subId , , address link, uint256 key) = helperConfig.activeNetworkConfig();
        fundSubscription(vrfCoordinator, subId, link, key);
    }
    
    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {

    function addConsumer(address raffle, address vrfCoordinator, uint64 subId, uint256 key) public {
        vm.startBroadcast(key); // use this key on mainnet/testnet
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }
    function addConsumerUsingConfig(address raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, , uint64 subId, ,, uint256 key) = helperConfig.activeNetworkConfig();
        addConsumer(raffle, vrfCoordinator, subId, key);

    }
    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment("raffle", block.chainid);
        addConsumerUsingConfig(raffle);
    }

}