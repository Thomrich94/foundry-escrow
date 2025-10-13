// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import { Test, console } from "forge-std/Test.sol";
import { DeployEscrow } from "../../script/DeployEscrow.s.sol";
import { Escrow } from "../../contracts/Escrow.sol";

contract EscrowTest is Test {
    Escrow public escrow;
    address public arbiter;
    address public payer;
    address public payee;
    uint64 futureTimelock;

    uint256 private constant STARTING_BALANCE = 10 ether;
    uint256 private constant ESCROW_VALUE = 1 ether;

    bytes32 private constant HASH_LOCK = keccak256("mysecretpreimage");
    bytes private constant PREIMAGE = "mysecretpreimage";

    event EscrowCreated(
        uint256 indexed id,
        address indexed payer,
        address indexed payee,
        uint256 value,
        bytes32 hashlock,
        uint64 timelock
    );

    function setUp() external {
        arbiter = makeAddr("arbiter");
        payer = makeAddr("payer");
        payee = makeAddr("payee");
        futureTimelock = uint64(block.timestamp + 1 days);

        DeployEscrow deployer = new DeployEscrow();
        escrow = deployer.run(arbiter);

        vm.deal(payer, STARTING_BALANCE);
    }

    function test_createEscrow_Success() public {
        vm.prank(payer);

        vm.expectEmit(true, true, true, true, address(escrow));
        emit EscrowCreated(0, payer, payee, ESCROW_VALUE, HASH_LOCK, futureTimelock);

        uint256 id = escrow.createEscrow{ value: ESCROW_VALUE }(payee, HASH_LOCK, futureTimelock);
        assertEq(id, 0);

        Escrow.EscrowDetails memory details = escrow.getEscrow(id);
        assertEq(details.payer, payer);
        assertEq(details.payee, payee);
        assertEq(details.value, ESCROW_VALUE);
        assertEq(details.hashlock, HASH_LOCK);
        assertEq(details.timelock, futureTimelock);
        assertEq(details.status, uint8(Escrow.Status.Created));
    }

    function test_createEscrow_RevertsIfValueIsZero() public {
        vm.prank(payer);

        vm.expectRevert(Escrow.Escrow__ValueMustBePositive.selector);

        escrow.createEscrow{ value: 0 }(payee, HASH_LOCK, futureTimelock);
    }

    function test_createEscrow_RevertsIfPayeeIsZeroAddress() public {
        vm.prank(payer);

        vm.expectRevert(Escrow.Escrow__InvalidPayee.selector);

        escrow.createEscrow{ value: ESCROW_VALUE }(address(0), HASH_LOCK, futureTimelock);
    }

    function test_createEscrow_revertsIfTimeLockIsInThePast() public {
        uint64 futureTimestamp = uint64(block.timestamp + 1 days);
        vm.warp(futureTimestamp);

        uint64 pastTimelock = futureTimestamp - 1;

        vm.prank(payer);

        vm.expectRevert(
            abi.encodeWithSelector(Escrow.Escrow__TimelockNotInFuture.selector, pastTimelock, futureTimestamp)
        );

        escrow.createEscrow{ value: ESCROW_VALUE }(payee, HASH_LOCK, pastTimelock);
    }
}
