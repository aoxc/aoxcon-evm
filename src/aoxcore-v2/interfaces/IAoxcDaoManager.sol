// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title IAoxcDaoManager
 * @author AOXCAN
 * @notice Interface for the Armored DAO Management Layer.
 * @dev Supports Ghost Proposal protection, Signature-based voting, and Staking logic.
 */
interface IAoxcDaoManager {
    /*//////////////////////////////////////////////////////////////
                            DATA STRUCTURES
    //////////////////////////////////////////////////////////////*/

    struct Transaction {
        address to;
        uint256 value;
        uint256 totalPowerConfirmed;
        uint256 createdAt;
        bool exists; // Ghost Proposal Protection
        bool executed;
        bytes data;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function transactions(uint256 txIndex)
        external
        view
        returns (
            address to,
            uint256 value,
            uint256 totalPowerConfirmed,
            uint256 createdAt,
            bool exists,
            bool executed,
            bytes memory data
        );

    function stakedBalances(address member) external view returns (uint256);
    function lastVoteTxIndex(address member) external view returns (uint256);
    function nonces(address member) external view returns (uint256);
    function minExecutionPower() external view returns (uint256);
    function proposalLifespan() external view returns (uint256);
    function nextTxIndex() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                            STAKING OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Join the DAO by staking AOXC tokens.
     * @param amount The amount of tokens to stake.
     */
    function joinAndStake(uint256 amount) external;

    /**
     * @notice Exit the DAO and withdraw staked tokens.
     * @dev Subject to active vote locking.
     * @param amount The amount of tokens to withdraw.
     */
    function exitStake(uint256 amount) external;

    /*//////////////////////////////////////////////////////////////
                            GOVERNANCE CORE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Submit a new proposal for action.
     * @param to Target contract or address.
     * @param value Native currency value (if any).
     * @param data The calldata to be executed.
     * @return txIndex The index of the created proposal.
     */
    function proposeAction(address to, uint256 value, bytes calldata data) external returns (uint256 txIndex);

    /**
     * @notice Vote on a proposal using an EIP-712 signature.
     * @param txIndex The index of the transaction to vote on.
     * @param deadline The signature expiry timestamp.
     * @param signature The ECDSA signature.
     */
    function voteWithSignature(uint256 txIndex, uint256 deadline, bytes calldata signature) external;

    /*//////////////////////////////////////////////////////////////
                            ADMIN OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function setMinExecutionPower(uint256 newPower) external;
    function pause() external;
    function unpause() external;
}
