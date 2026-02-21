// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title PreAllocation — Validator & Shareholder OICD Compound Allocation
/// @notice Implements Obsidian Capital's pre-allocation incentive system:
///
///         VALIDATOR TRACK (5 months, 4x compound):
///           Month 1: $2M OICD → Month 5: $2.048B OICD total
///           $2M, $8M, $32M, $128M, $512M cumulative unlock
///           Final allocation: $2.048B (2/3 locked = $1.372B, 1/3 free = $675M)
///
///         SHAREHOLDER TRACK (8 months, 2x compound):
///           $2M, $4M, $8M, $16M, $32M, $64M, $128M, $256M
///           Signup bonus: $150K OICD immediately on profile completion
///
///         Both tracks contribute locked OICD to network liquidity pool.
///         Target: 250,000 validators = $343T locked OICD.
contract PreAllocation is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {

    enum MemberType { None, Validator, Shareholder }
    enum MemberStatus { Registered, Active, Completed, Exited }

    // Validator monthly schedule: 2M, 8M, 32M, 128M, 512M (in OICD units * 1e18)
    uint256[5] public validatorSchedule;

    // Shareholder monthly schedule: 2M, 4M, 8M, 16M, 32M, 64M, 128M, 256M
    uint256[8] public shareholderSchedule;

    uint256 public constant SIGNUP_BONUS_OICD = 150_000 * 1e18; // $150K OICD on signup

    // Validator constants
    uint256 public constant VALIDATOR_LOCKED_PCT = 67;  // 2/3 locked
    uint256 public constant VALIDATOR_FREE_PCT   = 33;  // 1/3 free

    // Network target
    uint256 public constant TARGET_VALIDATORS = 250_000;

    struct Member {
        address addr;
        MemberType memberType;
        MemberStatus status;
        uint256 registeredAt;
        uint256 lastClaimAt;
        uint8   monthsClaimed;      // 0–5 (validator) or 0–8 (shareholder)
        uint256 totalAllocated;     // OICD total allocated to date
        uint256 lockedOICD;         // locked portion (validators)
        uint256 freeOICD;           // free/withdrawable portion
        uint256 signupBonus;        // $150K initial
        bool    signupBonusClaimed;
        string  country;            // member's region
        bool    exited;             // withdrew before completion
    }

    // -- Storage --
    uint256 public totalValidators;
    uint256 public totalShareholders;
    uint256 public totalMembersRegistered;
    uint256 public totalLockedOICD;    // network liquidity pool
    uint256 public totalAllocatedOICD;
    uint256 public networkLiquidityPool; // target $343T from 250K validators

    mapping(address => Member) public members;
    address[] public validatorList;
    address[] public shareholderList;

    // -- Events --
    event ValidatorRegistered(address indexed member, uint256 timestamp);
    event ShareholderRegistered(address indexed member, uint256 timestamp);
    event SignupBonusClaimed(address indexed member, uint256 amount);
    event MonthlyAllocationClaimed(address indexed member, uint8 month, uint256 amount, uint256 locked, uint256 free);
    event MemberExited(address indexed member, uint256 totalReceived);
    event NetworkMilestone(uint256 validatorCount, uint256 totalLocked);

    modifier onlyMember() {
        require(members[msg.sender].memberType != MemberType.None, "Not registered");
        _;
    }

    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        // Validator schedule: 4x compound for 5 months (values in raw OICD units)
        validatorSchedule[0] = 2_000_000  * 1e18;  // Month 1: $2M
        validatorSchedule[1] = 8_000_000  * 1e18;  // Month 2: $8M
        validatorSchedule[2] = 32_000_000 * 1e18;  // Month 3: $32M
        validatorSchedule[3] = 128_000_000* 1e18;  // Month 4: $128M
        validatorSchedule[4] = 512_000_000* 1e18;  // Month 5: $512M (total → $2.048B unlocked at 5 months)

        // Shareholder schedule: 2x compound for 8 months
        shareholderSchedule[0] = 2_000_000  * 1e18;  // Month 1: $2M
        shareholderSchedule[1] = 4_000_000  * 1e18;  // Month 2: $4M
        shareholderSchedule[2] = 8_000_000  * 1e18;  // Month 3: $8M
        shareholderSchedule[3] = 16_000_000 * 1e18;  // Month 4: $16M
        shareholderSchedule[4] = 32_000_000 * 1e18;  // Month 5: $32M
        shareholderSchedule[5] = 64_000_000 * 1e18;  // Month 6: $64M
        shareholderSchedule[6] = 128_000_000* 1e18;  // Month 7: $128M
        shareholderSchedule[7] = 256_000_000* 1e18;  // Month 8: $256M
    }

    // -- Registration --

    function registerAsValidator(string calldata country) external nonReentrant {
        require(members[msg.sender].memberType == MemberType.None, "Already registered");

        members[msg.sender] = Member({
            addr: msg.sender,
            memberType: MemberType.Validator,
            status: MemberStatus.Registered,
            registeredAt: block.timestamp,
            lastClaimAt: 0,
            monthsClaimed: 0,
            totalAllocated: 0,
            lockedOICD: 0,
            freeOICD: SIGNUP_BONUS_OICD,
            signupBonus: SIGNUP_BONUS_OICD,
            signupBonusClaimed: false,
            country: country,
            exited: false
        });

        validatorList.push(msg.sender);
        totalValidators++;
        totalMembersRegistered++;

        if (totalValidators % 10_000 == 0) {
            emit NetworkMilestone(totalValidators, totalLockedOICD);
        }

        emit ValidatorRegistered(msg.sender, block.timestamp);
    }

    function registerAsShareholder(string calldata country) external nonReentrant {
        require(members[msg.sender].memberType == MemberType.None, "Already registered");

        members[msg.sender] = Member({
            addr: msg.sender,
            memberType: MemberType.Shareholder,
            status: MemberStatus.Registered,
            registeredAt: block.timestamp,
            lastClaimAt: 0,
            monthsClaimed: 0,
            totalAllocated: 0,
            lockedOICD: 0,
            freeOICD: SIGNUP_BONUS_OICD,
            signupBonus: SIGNUP_BONUS_OICD,
            signupBonusClaimed: false,
            country: country,
            exited: false
        });

        shareholderList.push(msg.sender);
        totalShareholders++;
        totalMembersRegistered++;
        emit ShareholderRegistered(msg.sender, block.timestamp);
    }

    // -- Claim Signup Bonus ($150K OICD) --

    function claimSignupBonus() external onlyMember nonReentrant {
        Member storage m = members[msg.sender];
        require(!m.signupBonusClaimed, "Already claimed");
        m.signupBonusClaimed = true;
        m.totalAllocated += SIGNUP_BONUS_OICD;
        totalAllocatedOICD += SIGNUP_BONUS_OICD;
        emit SignupBonusClaimed(msg.sender, SIGNUP_BONUS_OICD);
    }

    // -- Monthly Compound Claim --

    function claimMonthlyAllocation() external onlyMember nonReentrant {
        Member storage m = members[msg.sender];
        require(!m.exited, "Exited");
        require(block.timestamp >= m.registeredAt + uint256(m.monthsClaimed + 1) * 30 days, "Month not elapsed");

        uint8 maxMonths = m.memberType == MemberType.Validator ? 5 : 8;
        require(m.monthsClaimed < maxMonths, "All months claimed");

        uint256 allocation;
        if (m.memberType == MemberType.Validator) {
            allocation = validatorSchedule[m.monthsClaimed];
        } else {
            allocation = shareholderSchedule[m.monthsClaimed];
        }

        uint256 locked = 0;
        uint256 free = allocation;

        // Validators: 2/3 locked into network liquidity, 1/3 free
        if (m.memberType == MemberType.Validator) {
            locked = (allocation * VALIDATOR_LOCKED_PCT) / 100;
            free   = allocation - locked;
            m.lockedOICD += locked;
            totalLockedOICD += locked;
            networkLiquidityPool += locked;
        }

        m.freeOICD += free;
        m.monthsClaimed++;
        m.lastClaimAt = block.timestamp;
        m.totalAllocated += allocation;
        totalAllocatedOICD += allocation;

        if (m.monthsClaimed == maxMonths) {
            m.status = MemberStatus.Completed;
        } else {
            m.status = MemberStatus.Active;
        }

        emit MonthlyAllocationClaimed(msg.sender, m.monthsClaimed, allocation, locked, free);
    }

    // -- Early Exit (forfeit locked) --

    function exitEarly() external onlyMember nonReentrant {
        Member storage m = members[msg.sender];
        require(!m.exited, "Already exited");
        m.exited = true;
        m.status = MemberStatus.Exited;
        // Locked OICD remains in network pool — they only keep free portion
        uint256 received = m.freeOICD;
        emit MemberExited(msg.sender, received);
    }

    // -- Views --

    function getMember(address addr) external view returns (Member memory) {
        return members[addr];
    }

    function getNextClaimAmount(address addr) external view returns (uint256 nextAmount, uint256 monthsRemaining) {
        Member memory m = members[addr];
        uint8 maxMonths = m.memberType == MemberType.Validator ? 5 : 8;
        if (m.monthsClaimed >= maxMonths) return (0, 0);

        if (m.memberType == MemberType.Validator) {
            nextAmount = validatorSchedule[m.monthsClaimed];
        } else {
            nextAmount = shareholderSchedule[m.monthsClaimed];
        }
        monthsRemaining = maxMonths - m.monthsClaimed;
    }

    function getValidatorSchedule() external view returns (uint256[5] memory) {
        return validatorSchedule;
    }

    function getShareholderSchedule() external view returns (uint256[8] memory) {
        return shareholderSchedule;
    }

    function networkStats() external view returns (
        uint256 validators,
        uint256 shareholders,
        uint256 total,
        uint256 lockedPool,
        uint256 totalAllocated,
        uint256 targetValidators,
        uint256 progressPct
    ) {
        validators    = totalValidators;
        shareholders  = totalShareholders;
        total         = totalMembersRegistered;
        lockedPool    = totalLockedOICD;
        totalAllocated = totalAllocatedOICD;
        targetValidators = TARGET_VALIDATORS;
        progressPct   = totalValidators * 100 / TARGET_VALIDATORS;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
