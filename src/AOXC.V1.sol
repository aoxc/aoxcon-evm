// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20VotesUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";

/**
 * @title AOXC Token V2
 * @notice Upgrade-safe extension of AOXC V1 with stronger operational controls and safer administration.
 *
 * @dev
 * Security and upgrade design principles:
 * - The V1 storage layout is preserved exactly and extended only through append-only storage.
 * - The V1 initializer must never be executed again after proxy deployment.
 * - V2-specific state must be initialized through {initializeV2} using reinitializer(2).
 * - Legacy administrative surfaces are intentionally preserved to avoid breaking existing tooling,
 *   multi-signature transaction templates, and operational runbooks.
 * - Transfer controls remain logically equivalent to V1 unless governance intentionally changes them.
 */
contract AOXC is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    AccessControlUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    // =============================================================
    //                            ROLES
    // =============================================================

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");

    // =============================================================
    //                          CONSTANTS
    // =============================================================

    uint256 public constant INITIAL_SUPPLY = 100_000_000_000 * 1e18;
    uint256 public constant YEAR_SECONDS = 365 days;
    uint256 public constant HARD_CAP_INFLATION_BPS = 600;
    uint256 public constant ABSOLUTE_SUPPLY_CAP = INITIAL_SUPPLY * 3;

    // =============================================================
    //                    V1 STORAGE (DO NOT REORDER)
    // =============================================================

    uint256 public yearlyMintLimit;
    uint256 public lastMintTimestamp;
    uint256 public mintedThisYear;
    uint256 public maxTransferAmount;
    uint256 public dailyTransferLimit;

    mapping(address => bool) private _blacklisted;
    mapping(address => string) public blacklistReason;
    mapping(address => bool) public isExcludedFromLimits;
    mapping(address => uint256) public dailySpent;
    mapping(address => uint256) public lastTransferDay;

    // =============================================================
    //                    V2 STORAGE (APPEND ONLY)
    // =============================================================

    bool public limitsEnabled;
    address public vaultContract;

    // =============================================================
    //                            EVENTS
    // =============================================================

    event Blacklisted(address indexed account, string reason);
    event Unblacklisted(address indexed account);
    event MonetaryLimitsUpdated(uint256 maxTransferAmount, uint256 dailyTransferLimit);
    event LimitsEnabledUpdated(bool enabled);
    event ExclusionFromLimitsUpdated(address indexed account, bool excluded);
    event FundsRescued(address indexed token, address indexed recipient, uint256 amount);
    event NativeFundsRescued(address indexed recipient, uint256 amount);
    event VaultContractUpdated(address indexed previousVault, address indexed newVault);
    event YearlyMintLimitUpdated(uint256 previousLimit, uint256 newLimit);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // =============================================================
    //                         INITIALIZATION
    // =============================================================

    /**
     * @notice Initializes the V1 deployment state.
     * @dev This function is intended to be executed exactly once by the proxy during initial deployment.
     *      It must never be called again during a V2 upgrade.
     */
    function initialize(address governor) external initializer {
        require(governor != address(0), "AOXC: zero governor");

        __ERC20_init("AOXC", "AOXC");
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __AccessControl_init();
        __ERC20Permit_init("AOXC");
        __ERC20Votes_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, governor);
        _grantRole(PAUSER_ROLE, governor);
        _grantRole(MINTER_ROLE, governor);
        _grantRole(UPGRADER_ROLE, governor);
        _grantRole(COMPLIANCE_ROLE, governor);

        yearlyMintLimit = (INITIAL_SUPPLY * HARD_CAP_INFLATION_BPS) / 10_000;
        lastMintTimestamp = block.timestamp;

        maxTransferAmount = 500_000_000 * 1e18;
        dailyTransferLimit = 1_000_000_000 * 1e18;

        isExcludedFromLimits[governor] = true;
        isExcludedFromLimits[address(this)] = true;

        _mint(governor, INITIAL_SUPPLY);
    }

    /**
     * @notice Initializes V2-only state after the proxy has been upgraded to this implementation.
     * @dev This function is required because newly appended storage variables are not initialized
     *      automatically during a proxy upgrade.
     *
     *      The chosen default preserves the effective V1 behavior where transfer limits were active.
     */
    function initializeV2() external reinitializer(2) onlyRole(DEFAULT_ADMIN_ROLE) {
        limitsEnabled = true;
    }

    // =============================================================
    //                         CORE TOKEN LOGIC
    // =============================================================

    /**
     * @notice Mints new tokens subject to annual issuance controls and the absolute supply cap.
     * @param to Recipient of the minted tokens.
     * @param amount Amount to mint.
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) whenNotPaused {
        require(to != address(0), "AOXC: zero recipient");
        require(!_blacklisted[to], "AOXC: blacklisted recipient");
        require(amount != 0, "AOXC: zero amount");

        _refreshMintWindowIfNeeded();

        require(mintedThisYear + amount <= yearlyMintLimit, "AOXC: yearly mint limit exceeded");
        require(totalSupply() + amount <= ABSOLUTE_SUPPLY_CAP, "AOXC: absolute cap exceeded");

        mintedThisYear += amount;
        _mint(to, amount);
    }

    /**
     * @dev Preserves the V1 annual mint window behavior.
     *      If multiple full yearly periods have elapsed, the reference timestamp advances by the number
     *      of full periods rather than snapping directly to block.timestamp.
     */
    function _refreshMintWindowIfNeeded() internal {
        if (block.timestamp >= lastMintTimestamp + YEAR_SECONDS) {
            uint256 elapsedPeriods = (block.timestamp - lastMintTimestamp) / YEAR_SECONDS;
            lastMintTimestamp += elapsedPeriods * YEAR_SECONDS;
            mintedThisYear = 0;
        }
    }

    /**
     * @dev Enforces blacklist and optional transfer velocity limits before delegating to parent logic.
     */
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20Upgradeable, ERC20PausableUpgradeable, ERC20VotesUpgradeable)
    {
        if (from != address(0)) {
            require(!_blacklisted[from], "AOXC: blacklisted sender");
        }

        if (to != address(0)) {
            require(!_blacklisted[to], "AOXC: blacklisted recipient");
        }

        if (limitsEnabled && from != address(0) && to != address(0) && !isExcludedFromLimits[from]) {
            require(value <= maxTransferAmount, "AOXC: max transfer exceeded");

            uint256 currentDay = block.timestamp / 1 days;
            if (lastTransferDay[from] != currentDay) {
                dailySpent[from] = 0;
                lastTransferDay[from] = currentDay;
            }

            require(dailySpent[from] + value <= dailyTransferLimit, "AOXC: daily transfer limit exceeded");
            dailySpent[from] += value;
        }

        super._update(from, to, value);
    }

    // =============================================================
    //                      COMPLIANCE / BLACKLIST
    // =============================================================

    /**
     * @notice Adds an account to the blacklist.
     * @dev Administrative accounts are intentionally protected from blacklisting to avoid self-inflicted governance lockout.
     */
    function addToBlacklist(address account, string calldata reason) external onlyRole(COMPLIANCE_ROLE) {
        require(account != address(0), "AOXC: zero account");
        require(!hasRole(DEFAULT_ADMIN_ROLE, account), "AOXC: admin immunity");
        require(!_blacklisted[account], "AOXC: already blacklisted");
        require(bytes(reason).length != 0, "AOXC: empty reason");

        _blacklisted[account] = true;
        blacklistReason[account] = reason;

        emit Blacklisted(account, reason);
    }

    /**
     * @notice Removes an account from the blacklist.
     */
    function removeFromBlacklist(address account) external onlyRole(COMPLIANCE_ROLE) {
        require(account != address(0), "AOXC: zero account");
        require(_blacklisted[account], "AOXC: not blacklisted");

        _blacklisted[account] = false;
        delete blacklistReason[account];

        emit Unblacklisted(account);
    }

    /**
     * @notice Returns blacklist status for an account.
     */
    function isBlacklisted(address account) external view returns (bool) {
        return _blacklisted[account];
    }

    // =============================================================
    //                     ADMINISTRATIVE CONTROLS
    // =============================================================

    /**
     * @notice Enables or disables transfer velocity limits globally.
     * @dev This control affects only non-mint and non-burn transfers that are not excluded.
     */
    function setLimitsEnabled(bool status) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(limitsEnabled != status, "AOXC: no state change");

        limitsEnabled = status;
        emit LimitsEnabledUpdated(status);
    }

    /**
     * @notice Preserves the V1 administrative interface for per-account transfer limit exclusion.
     */
    function setExclusionFromLimits(address account, bool status) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(account != address(0), "AOXC: zero account");
        require(isExcludedFromLimits[account] != status, "AOXC: no state change");

        isExcludedFromLimits[account] = status;
        emit ExclusionFromLimitsUpdated(account, status);
    }

    /**
     * @notice Preserves the V1 administrative interface for transfer velocity parameters.
     * @dev Governance may intentionally set either limit to zero to fully block applicable transfers.
     */
    function setTransferVelocity(uint256 newMaxTransferAmount, uint256 newDailyTransferLimit)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            maxTransferAmount != newMaxTransferAmount || dailyTransferLimit != newDailyTransferLimit,
            "AOXC: no state change"
        );

        maxTransferAmount = newMaxTransferAmount;
        dailyTransferLimit = newDailyTransferLimit;

        emit MonetaryLimitsUpdated(newMaxTransferAmount, newDailyTransferLimit);
    }

    /**
     * @notice Updates the vault contract and synchronizes associated operational permissions.
     * @dev The previous vault, if any, loses both MINTER_ROLE and transfer-limit exclusion.
     *      The new vault receives MINTER_ROLE and is excluded from transfer limits.
     */
    function setVaultContract(address newVault) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newVault != address(0), "AOXC: zero vault");
        require(newVault != vaultContract, "AOXC: same vault");

        address previousVault = vaultContract;

        if (previousVault != address(0)) {
            if (hasRole(MINTER_ROLE, previousVault)) {
                _revokeRole(MINTER_ROLE, previousVault);
            }

            if (isExcludedFromLimits[previousVault]) {
                isExcludedFromLimits[previousVault] = false;
                emit ExclusionFromLimitsUpdated(previousVault, false);
            }
        }

        vaultContract = newVault;

        if (!hasRole(MINTER_ROLE, newVault)) {
            _grantRole(MINTER_ROLE, newVault);
        }

        if (!isExcludedFromLimits[newVault]) {
            isExcludedFromLimits[newVault] = true;
            emit ExclusionFromLimitsUpdated(newVault, true);
        }

        emit VaultContractUpdated(previousVault, newVault);
    }

    /**
     * @notice Updates the annual mint limit.
     * @dev This function is intentionally bounded by the hard-cap inflation policy.
     *      Governance may reduce the limit below the current value, but may not exceed the policy ceiling.
     */
    function setYearlyMintLimit(uint256 newYearlyMintLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 maxAllowed = (INITIAL_SUPPLY * HARD_CAP_INFLATION_BPS) / 10_000;

        require(newYearlyMintLimit <= maxAllowed, "AOXC: exceeds policy cap");
        require(newYearlyMintLimit != yearlyMintLimit, "AOXC: no state change");

        uint256 previousLimit = yearlyMintLimit;
        yearlyMintLimit = newYearlyMintLimit;

        emit YearlyMintLimitUpdated(previousLimit, newYearlyMintLimit);
    }

    // =============================================================
    //                         RESCUE FUNCTIONS
    // =============================================================

    /**
     * @notice Recovers ERC20 tokens that were sent to this contract by mistake.
     * @dev Recovery of the native AOXC token itself is intentionally blocked.
     */
    function rescueERC20(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token != address(0), "AOXC: zero token");
        require(token != address(this), "AOXC: self rescue forbidden");
        require(amount != 0, "AOXC: zero amount");

        IERC20(token).safeTransfer(msg.sender, amount);

        emit FundsRescued(token, msg.sender, amount);
    }

    /**
     * @notice Recovers native currency held by the contract.
     */
    function rescueNative() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 amount = address(this).balance;
        require(amount != 0, "AOXC: no native balance");

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "AOXC: native transfer failed");

        emit NativeFundsRescued(msg.sender, amount);
    }

    // =============================================================
    //                     PAUSE / UPGRADE AUTHORITY
    // =============================================================

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Restricts UUPS implementation upgrades to the designated upgrader role.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {
        require(newImplementation != address(0), "AOXC: zero implementation");
    }

    // =============================================================
    //                      OPENZEPPELIN OVERRIDES
    // =============================================================

    function nonces(address owner)
        public
        view
        override(ERC20PermitUpgradeable, NoncesUpgradeable)
        returns (uint256)
    {
        return super.nonces(owner);
    }

    // =============================================================
    //                         STORAGE GAP
    // =============================================================

    /**
     * @dev Storage gap reserved for future upgrades.
     *
     * V1 gap: 43 slots
     * V2 adds:
     * - bool limitsEnabled
     * - address vaultContract
     *
     * These two values pack into a single 32-byte storage slot, so the gap is reduced by one slot.
     */
    uint256[42] private __gap;
}
