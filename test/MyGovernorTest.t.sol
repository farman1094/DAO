// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";

// SRC
import {MyGovernor} from "src/MyGovernor.sol";
import {Box} from "src/Box.sol";
import {GovernedToken} from "src/GovernedToken.sol";
import {TimeLock} from "src/TimeLock.sol";

contract MyGovernorTest is Test {
    MyGovernor governor;
    Box box;
    GovernedToken token;
    TimeLock timelock;

    address public USER = makeAddr("USER");
    uint256 public constant AMOUNT = 100 ether;

    // For Timelock
    address[] proposers;
    address[] executors;
    uint256[] values;
    address[] targets;
    bytes[] calldatas;

    uint256 public constant MIN_DELAY = 3600; // 1 hour after the vote passed
    uint256 public constant VOTING_DELAY = 7200; // shold be MIN_DELAY * 24 ; // how many blocks till a vote is active // 1 day
    uint256 public constant VOTING_PERIOD = 50400; // 3600 * 24 * 7 ; // voting period 7 days

    function setUp() public {
        token = new GovernedToken();
        token.mintForUser(USER, AMOUNT);

        vm.startPrank(USER);
        token.delegate(USER);

        timelock = new TimeLock(MIN_DELAY, proposers, executors);
        governor = new MyGovernor(token, timelock);

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, USER);
        vm.stopPrank();

        box = new Box();
        box.transferOwnership(address(timelock));
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        box.updateNum(1);
    }

    function testGovernanceCanUpdatesBox() public {
        /*  function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    )*/

        uint256 valueToUpdate = 888;
        bytes memory functionData = abi.encodeWithSignature("updateNum(uint256)", valueToUpdate);
        string memory description = "Update number of Box";

        targets.push(address(box));
        values.push(0);
        calldatas.push(functionData);

        // propose to the DAO
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // view the state
        console.log("Proposal State: ", uint256(governor.state(proposalId)));

        vm.warp(block.timestamp + VOTING_DELAY + 1); // 1 day passed
        vm.roll(block.number + VOTING_DELAY + 1); // 1 day passed

        console.log("Proposal State: ", uint256(governor.state(proposalId)));

        // 2. vote on the proposal
        string memory reason = "Patrick is the coolest teacher I've seen";

        uint8 voteWay = 1; // voting Yes
        vm.startPrank(USER);
        governor.castVoteWithReason(proposalId, voteWay, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1); // 7 day passed
        vm.roll(block.number + VOTING_PERIOD + 1); // 7 day passed

        //3. Queue the TX // GovernorTimeLockControl.sol
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        /*uint256 queueId = */
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1); // 1 hour passed
        vm.roll(block.number + MIN_DELAY + 1); // 1 hour passed

        //4 Execute
        governor.execute(targets, values, calldatas, descriptionHash);

        assert(box.getNumber() == valueToUpdate);
    }
}
