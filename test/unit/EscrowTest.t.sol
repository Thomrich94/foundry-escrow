// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import { Test, console } from "forge-std/Test.sol";
import { DeployEscrow } from "../../script/DeployEscrow.s.sol";
import { Escrow } from "../../contracts/Escrow.sol";

//==============================================================
//           Base Contract for Shared State
//==============================================================
abstract contract EscrowTestBase is Test {
    address public arbiter;
    address public payer;
    address public payee;
    uint64 futureTimelock;

    uint256 internal constant STARTING_BALANCE = 10 ether;
    uint256 internal constant ESCROW_VALUE = 1 ether;
    bytes32 internal constant HASH_LOCK = keccak256(bytes("mysecretpreimage"));
    bytes internal constant PREIMAGE = "mysecretpreimage";

    function _baseSetUp() internal {
        arbiter = makeAddr("arbiter");
        payer = makeAddr("payer");
        payee = makeAddr("payee");
        futureTimelock = uint64(block.timestamp + 1 days);
        vm.deal(payer, STARTING_BALANCE);
    }
}

//==============================================================
//           Function Integration Tests
//==============================================================
contract FunctionUnitTests is EscrowTestBase {
    Escrow public escrow;

    modifier escrowCreated() {
        vm.prank(payer);
        escrow.createEscrow{ value: ESCROW_VALUE }(payee, HASH_LOCK, futureTimelock);
        _;
    }

    event EscrowCreated(
        uint256 indexed id,
        address indexed payer,
        address indexed payee,
        uint256 value,
        bytes32 hashlock,
        uint64 timelock
    );
    event Released(uint256 indexed id, bytes preimage);
    event Refunded(uint256 indexed id);

    function setUp() external {
        _baseSetUp();
        DeployEscrow deployer = new DeployEscrow();
        escrow = deployer.run(arbiter);
    }

    //==============================================================
    //           Tests for create Escrow Function
    //==============================================================
    function testFuzz_createEscrow_SuccessInvariants(
        address _payee,
        bytes32 _hashlock,
        uint64 _timelock,
        uint256 _value
    ) public {
        vm.assume(_value > 0 && _value < 1000 ether);
        vm.assume(_payee != address(0) && _payee != payer);
        vm.assume(_timelock > block.timestamp && _timelock < block.timestamp + (10 * 365 days));
        vm.deal(payer, _value);

        uint256 nextIdBefore = escrow.getNextEscrowId();
        uint256 contractBalanceBefore = address(escrow).balance;

        vm.prank(payer);
        uint256 newId = escrow.createEscrow{ value: _value }(_payee, _hashlock, _timelock);

        uint256 contractBalanceAfter = address(escrow).balance;

        assertEq(newId, nextIdBefore);
        assertEq(contractBalanceAfter, contractBalanceBefore + _value);

        Escrow.EscrowDetails memory details = escrow.getEscrow(newId);
        assertEq(details.payer, payer);
        assertEq(details.payee, _payee);
        assertEq(details.value, _value);
        assertEq(details.hashlock, _hashlock);
        assertEq(details.timelock, _timelock);
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

    //==============================================================
    //           Tests for release Function
    //==============================================================
    function testFuzz_release_SuccessInvariants(
        address _payee,
        uint64 _timelock,
        uint256 _value,
        bytes calldata _preimage
    ) public {
        vm.assume(_value > 0 && _value < 1000 ether);
        vm.assume(_timelock > block.timestamp && _timelock < block.timestamp + (10 * 365 days));
        vm.assume(_preimage.length > 0 && _preimage.length < 64);
        vm.assume(_payee != payer);
        // 2. Enforce EVM constraints by whitelisting ONLY Externally Owned Accounts (EOAs).
        vm.assume(_payee.code.length == 0);
        // This filters out the zero address AND all precompiles.
        vm.assume(uint160(_payee) > 0x1000);

        vm.deal(payer, _value);

        bytes32 _hashlock = keccak256(_preimage);
        vm.prank(payer);
        uint256 newId = escrow.createEscrow{ value: _value }(_payee, _hashlock, _timelock);

        uint256 payeeStartingBalance = _payee.balance;
        uint256 contractStartingBalance = address(escrow).balance;

        vm.expectEmit(true, false, false, false, address(escrow));
        emit Released(newId, _preimage);

        escrow.release(newId, _preimage);

        Escrow.EscrowDetails memory details = escrow.getEscrow(newId);
        assertEq(details.status, uint8(Escrow.Status.Released));
        assertEq(_payee.balance, payeeStartingBalance + _value);
        assertEq(address(escrow).balance, contractStartingBalance - _value);
    }

    function test_release_RevertsIfPreimageIsInvalid() public escrowCreated {
        uint256 escrowId = 0;
        bytes memory wrongPreimage = "this is the wrong secret";
        vm.expectRevert(abi.encodeWithSelector(Escrow.Escrow__InvalidPreimage.selector, escrowId));
        escrow.release(escrowId, wrongPreimage);
    }

    function test_release_RevertsIfTransferFails() public {
        RevertingReceiver badPayee = new RevertingReceiver();
        vm.prank(payer);
        uint256 id = escrow.createEscrow{ value: ESCROW_VALUE }(address(badPayee), HASH_LOCK, futureTimelock);

        vm.expectRevert(
            abi.encodeWithSelector(Escrow.Escrow__TransferFailed.selector, id, address(badPayee), ESCROW_VALUE)
        );

        escrow.release(id, PREIMAGE);
    }

    //==============================================================
    //           Tests for refund Function
    //==============================================================
    function testFuzz_refund_SuccessInvariants(address _payee, uint64 _timelock, uint256 _value) public {
        vm.assume(_value > 0 && _value < 1000 ether);
        vm.assume(_timelock > block.timestamp && _timelock < block.timestamp + (10 * 365 days));
        vm.assume(_payee != address(0) && _payee != payer);
        vm.deal(payer, _value);

        vm.prank(payer);
        uint256 newId = escrow.createEscrow{ value: _value }(_payee, HASH_LOCK, _timelock);

        vm.warp(_timelock + 1);
        uint256 payerStartingBalance = payer.balance;
        uint256 contractStartingBalance = address(escrow).balance;

        vm.expectEmit(true, false, false, false, address(escrow));
        emit Refunded(newId);

        vm.prank(payer);
        escrow.refund(newId);

        Escrow.EscrowDetails memory details = escrow.getEscrow(newId);
        assertEq(details.status, uint8(Escrow.Status.Refunded));
        assertEq(payer.balance, payerStartingBalance + _value);
        assertEq(address(escrow).balance, contractStartingBalance - _value);
    }

    function test_refund_RevertsIfNotCalledByPayer() public escrowCreated {
        address attacker = makeAddr("attacker");

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(Escrow.Escrow__NotThePayer.selector, attacker, payer));
        escrow.refund(0);
    }

    function test_refund_RevertsIfTimelockHasNotExpired() public escrowCreated {
        vm.prank(payer);
        vm.expectRevert(
            abi.encodeWithSelector(Escrow.Escrow__TimelockNotExpired.selector, block.timestamp, futureTimelock)
        );
        escrow.refund(0);
    }

    function test_refund_RevertsIfTransferFails() public {
        RevertingReceiver badPayer = new RevertingReceiver();
        vm.deal(address(badPayer), ESCROW_VALUE);

        vm.prank(address(badPayer));
        uint256 id = escrow.createEscrow{ value: ESCROW_VALUE }(payee, HASH_LOCK, futureTimelock);

        vm.warp(futureTimelock + 1);
        vm.prank(address(badPayer));
        vm.expectRevert(
            abi.encodeWithSelector(Escrow.Escrow__TransferFailed.selector, id, address(badPayer), ESCROW_VALUE)
        );
        escrow.refund(id);
    }
}

contract ModifierUnitTests is EscrowTestBase {
    TestableEscrow public escrow;

    function setUp() external {
        _baseSetUp();
        escrow = new TestableEscrow(arbiter);
    }

    modifier escrowCreated() {
        vm.prank(payer);
        escrow.createEscrow{ value: ESCROW_VALUE }(payee, HASH_LOCK, futureTimelock);
        _;
    }

    function test_modifier_escrowExists_RevertsIfIdDoesNotExist() public {
        uint256 nonExistentId = 999;
        vm.expectRevert(abi.encodeWithSelector(Escrow.Escrow__NotFound.selector, nonExistentId));
        escrow.test_escrowExists_Modifier(nonExistentId);
    }

    function test_modifier_inStatus_RevertsIfStatusIsWrong() public escrowCreated {
        uint256 escrowId = 0;
        escrow.release(escrowId, PREIMAGE);
        vm.expectRevert(
            abi.encodeWithSelector(
                Escrow.Escrow__InvalidState.selector,
                escrowId,
                uint8(Escrow.Status.Released),
                uint8(Escrow.Status.Created)
            )
        );
        escrow.test_inStatus_Modifier(escrowId, Escrow.Status.Created);
    }
}

contract TestableEscrow is Escrow {
    constructor(address _arbiter) Escrow(_arbiter) { }
    function test_escrowExists_Modifier(uint256 _id) external view escrowExists(_id) { }
    function test_inStatus_Modifier(uint256 _id, Status _requiredStatus) external view inStatus(_id, _requiredStatus) { }
}

contract RevertingReceiver {
    receive() external payable {
        revert("Payment rejected");
    }
}
