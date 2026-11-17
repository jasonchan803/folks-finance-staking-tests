// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.30;

import {ERC20Permit, ERC20} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {Pausable} from "openzeppelin-contracts/contracts/utils/Pausable.sol";
import {IERC20Errors} from "openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol";
import {Test} from "forge-std/Test.sol";
import {Staking} from "../src/Staking.sol";
import {IStakingV1} from "../src/interfaces/IStakingV1.sol";
import {IMigratorV1} from "../src/interfaces/IMigratorV1.sol";

contract Token is ERC20Permit {
    constructor() ERC20Permit("TestToken") ERC20("TestToken", "TTKN") {}
}

contract UnsupportedToken is ERC20Permit {
    constructor() ERC20Permit("UnsupportedToken") ERC20("UnsupportedToken", "UTKN") {}
}

contract Mytest is Test {
    Staking public staking;

    address public admin = address(2);
    address public manager = address(3);
    address public migrator = address(4);
    address public pauser = address(5);
    address public alice = address(6);
    address public bob = address(7);
    uint256 public charliePrivateKey = 0xca51;
    address public charlie = vm.addr(charliePrivateKey);

    Token public token;
    UnsupportedToken public unsupportedToken;

    function setUp() public {
        token = new Token();
        unsupportedToken = new UnsupportedToken();
        staking = new Staking(admin, manager, pauser, address(token));

        vm.prank(admin);
        staking.grantRole(keccak256("MIGRATOR"), migrator);
    }

    function test_Staking_RevertWhen_DifferentPersonSignature() public {
        deal(address(token), address(staking), 1000 ether);
        deal(address(token), charlie, 100 ether);

        uint8 periodIndex = addStakingPeriodByManager(50 ether, 20, 10, 5000, true);

        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = signCharliePermit(10 ether, deadline);

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(staking), 0, 10 ether)
        );
        stakeWithPermit(alice, periodIndex, 10 ether, 20, 10, 5000, address(0), deadline, v, r, s);
    }

    function test_Staking_When_PermitExpired() public {
        // 1. Setup: Authorize Charlie and generate a signature in advance
        deal(address(token), address(staking), 1000 ether);
        deal(address(token), charlie, 100 ether);

        uint8 periodIndex = addStakingPeriodByManager(50 ether, 20, 10, 5000, true);

        vm.prank(charlie);
        token.approve(address(staking), 50 ether);

        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = signCharliePermit(10 ether, deadline);

        // 2. Fast forward past the deadline to make permit invalid.
        vm.warp(block.timestamp + 2 hours);

        // 3. Execute: Permit fails silently, but stake succeeds due to allowance.
        assertEq(staking.getUserStakes(charlie).length, 0);
        stakeWithPermit(charlie, periodIndex, 10 ether, 20, 10, 5000, address(0), deadline, v, r, s);

        // 4. Assertion: User successfully staked despite permit failure.
        assertEq(staking.getUserStakes(charlie).length, 1);
        assertEq(staking.getUserStake(charlie, periodIndex).amount, 10 ether);
    }

    function test_Staking_less_Withdrawnone() public {
        deal(address(token), address(staking), 1000 ether);
        deal(address(token), alice, 100 ether);

        uint8 periodIndex = addStakingPeriodByManager(50 ether, 365 days, 10, 1000, true);

        vm.prank(alice);
        token.approve(address(staking), 50 ether);

        vm.warp(0);
        uint256 initialamount = 1;
        stake(alice, periodIndex, initialamount, 365 days, 10, 1000, address(0));

        vm.warp(366 days);

        uint256 aliceReward = calculateReward(1, 365 days, 1000);
        assertEq(aliceReward, 0);
        assertEq(staking.getClaimable(alice, periodIndex), initialamount);
    }

    function test_exploit_revokePermitBlockedAfterMigratorRoleRevoked() public {
        deal(address(token), address(staking), 1000 ether);
        deal(address(token), alice, 100 ether);

        uint8 periodIndex = addStakingPeriodByManager(50 ether, 365 days, 10, 1000, true);

        vm.startPrank(alice);
        token.approve(address(staking), 50 ether);
        staking.setMigrationPermit(migrator, true);
        vm.stopPrank();

        stake(alice, periodIndex, 10 ether, 365 days, 10, 1000, address(0));

        vm.prank(admin);
        staking.revokeRole(keccak256("MIGRATOR"), migrator);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IStakingV1.MigratorNotFound.selector, migrator)
        );
        staking.setMigrationPermit(migrator, false);  // REVERTS — stuck at true

        assertTrue(staking.migrationPermits(migrator, alice));
        assertEq(staking.getUserStakes(alice).length, 1);

        vm.prank(admin);
        staking.grantRole(keccak256("MIGRATOR"), migrator);

        vm.prank(migrator);
        staking.migratePositionsFrom(alice);

        assertEq(staking.getUserStakes(alice).length, 0);
    }

    // Helpers

    function addStakingPeriodByManager(
        uint256 cap,
        uint64 stakingDurationSeconds,
        uint64 unlockDurationSeconds,
        uint32 aprBps,
        bool isActive
    ) internal returns (uint8 periodIndex) {
        vm.prank(manager);
        periodIndex = staking.addStakingPeriod(cap, stakingDurationSeconds, unlockDurationSeconds, aprBps, isActive);
    }

    function approveAndStake(
        address user,
        uint8 periodIndex,
        uint256 amount,
        uint64 maxStakingDurationSeconds,
        uint64 maxUnlockDurationSeconds,
        uint32 minAprBps,
        address referrer
    ) internal returns (uint8 stakeIndex) {
        vm.startPrank(user);
        token.approve(address(staking), amount);
        stakeIndex = staking.stake(
            periodIndex,
            amount,
            IStakingV1.StakeParams({
                maxStakingDurationSeconds: maxStakingDurationSeconds,
                maxUnlockDurationSeconds: maxUnlockDurationSeconds,
                minAprBps: minAprBps,
                referrer: referrer
            })
        );
        vm.stopPrank();
    }

    function stake(
        address user,
        uint8 periodIndex,
        uint256 amount,
        uint64 maxStakingDurationSeconds,
        uint64 maxUnlockDurationSeconds,
        uint32 minAprBps,
        address referrer
    ) internal returns (uint8 stakeIndex) {
        vm.prank(user);
        stakeIndex = staking.stake(
            periodIndex,
            amount,
            IStakingV1.StakeParams({
                maxStakingDurationSeconds: maxStakingDurationSeconds,
                maxUnlockDurationSeconds: maxUnlockDurationSeconds,
                minAprBps: minAprBps,
                referrer: referrer
            })
        );
    }

    function stakeWithPermit(
        address user,
        uint8 periodIndex,
        uint256 amount,
        uint64 maxStakingDurationSeconds,
        uint64 maxUnlockDurationSeconds,
        uint32 minAprBps,
        address referrer,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal returns (uint8 stakeIndex) {
        vm.prank(user);
        stakeIndex = staking.stakeWithPermit(
            periodIndex,
            amount,
            IStakingV1.StakeParams({
                maxStakingDurationSeconds: maxStakingDurationSeconds,
                maxUnlockDurationSeconds: maxUnlockDurationSeconds,
                minAprBps: minAprBps,
                referrer: referrer
            }),
            deadline,
            v,
            r,
            s
        );
    }

    function signCharliePermit(uint256 amount, uint256 deadline) internal view returns (uint8 v, bytes32 r, bytes32 s) {
        return vm.sign(
            charliePrivateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            keccak256(
                                "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                            ),
                            charlie,
                            address(staking),
                            amount,
                            token.nonces(charlie),
                            deadline
                        )
                    )
                )
            )
        );
    }

    function calculateReward(uint256 stakingAmount, uint256 stakingTime, uint256 stakingApyBps)
        internal
        pure
        returns (uint256)
    {
        return (stakingAmount * stakingTime * stakingApyBps) / (365 days * 10000);
    }
}
