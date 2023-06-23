// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "./ComptrollerInterface.sol";
import "hardhat/console.sol";

interface TimelockInterface {
    function delay() external view returns (uint);

    function GRACE_PERIOD() external view returns (uint);

    function acceptAdmin() external;

    function queuedTransactions(bytes32 hash) external view returns (bool);

    function queueTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external returns (bytes32);

    function cancelTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external;

    function executeTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external payable returns (bytes memory);
}

contract Governor {
    ComptrollerInterface comptroller;
    TimelockInterface TimeLock;

    constructor(address _comptroller, address _timeLock) {
        comptroller = ComptrollerInterface(_comptroller);
        TimeLock = TimelockInterface(_timeLock);
    }

    function votingDelay() public pure returns (uint256) {
        return 1;
    } // 1 block

    function quorumVotes() public pure returns (uint256) {
        return 4;
    }

    /// @notice The duration of voting on a proposal, in blocks
    function votingPeriod() public pure virtual returns (uint256) {
        return 17280;
    } // ~3 days in blocks (assuming 15s blocks)

    /// @notice The address of the Compound Protocol Timelock
    // TimelockInterface public timelock;

    /// @notice The address of the Compound governance token
    // CompInterface public comp;

    /// @notice The address of the Governor Guardian
    address public guardian;

    /// @notice The total number of proposals
    uint256 public proposalCount;

    struct Proposal {
        /// @notice Unique id for looking up a proposal
        uint256 id;
        /// @notice Creator of the proposal
        address proposer;
        /// @notice The timestamp that the proposal will be available for execution, set once the vote succeeds
        uint256 eta;
        /// @notice The block at which voting begins: holders must delegate their votes prior to this block
        uint256 startBlock;
        /// @notice The block at which voting ends: votes must be cast prior to this block
        uint256 endBlock;
        /// @notice Current number of votes in favor of this proposal
        uint256 forVotes;
        /// @notice Current number of votes in opposition to this proposal
        uint256 againstVotes;
        /// @notice Flag marking whether the proposal has been canceled
        bool canceled;
        /// @notice Flag marking whether the proposal has been executed
        bool executed;
        /// @notice get receipt of every user
        mapping(address => Receipt) receipts;
    }

    /// @notice Possible states that a proposal may be in
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    /// @notice Receipts of ballots for the entire set of voters
    mapping(address => Receipt) receipts;

    /// @notice Ballot receipt record for a voter
    struct Receipt {
        /// @notice Whether or not a vote has been cast
        bool hasVoted;
        /// @notice Whether or not the voter supports the proposal or abstains
        bool support;
        /// @notice The number of votes the voter had, which were cast
        uint256 votes;
    }

    /// @notice The official record of all proposals ever proposed
    mapping(uint256 => Proposal) public proposals;

    event ProposalCreated(uint256 id, address proposer, string description);

    /// @notice An event emitted when a vote has been cast on a proposal
    event VoteCast(
        address voter,
        uint256 proposalId,
        bool support,
        uint256 votes
    );

    /// @notice An event emitted when a proposal has been canceled
    event ProposalCanceled(uint256 id);

    /// @notice An event emitted when a proposal has been queued in the Timelock
    event ProposalQueued(uint256 id, uint256 eta);

    /// @notice An event emitted when a proposal has been executed in the Timelock
    event ProposalExecuted(uint256 id);

    function state(uint256 proposalId) public view returns (ProposalState) {
        require(
            proposalCount >= proposalId && proposalId > 0,
            "GovernorAlpha::state: invalid proposal id"
        );

        Proposal storage proposal = proposals[proposalId];

        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (
            proposal.forVotes <= proposal.againstVotes ||
            proposal.forVotes < quorumVotes()
        ) {
            return ProposalState.Defeated;
        } else if (proposal.eta == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (
            block.timestamp >= (proposal.eta + TimeLock.GRACE_PERIOD())
        ) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    function propose(string memory description) public returns (uint256) {
        uint256 collateral = comptroller.getCollateralLength(msg.sender);
        require(
            collateral >= 2,
            "Proposer does not have enough collateral to propose"
        );

        uint256 startBlock = (block.number + votingDelay());
        uint256 endBlock = (startBlock + votingPeriod());

        proposalCount++;
        uint256 proposalId = proposalCount;
        Proposal storage newProposal = proposals[proposalId];

        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.eta = 0;
        newProposal.startBlock = startBlock;
        newProposal.endBlock = endBlock;
        newProposal.forVotes = 0;
        newProposal.againstVotes = 0;
        newProposal.canceled = false;
        newProposal.executed = false;

        emit ProposalCreated(newProposal.id, msg.sender, description);
        return newProposal.id;
    }

    function queue(uint256 proposalID) public {
        require(
            state(proposalID) == ProposalState.Succeeded,
            "GovernorAlpha::queue: proposal can only be queued if it is succeeded"
        );
        Proposal storage proposal = proposals[proposalID];
        uint256 eta = (block.timestamp + TimeLock.delay());
        proposal.eta = eta;
        emit ProposalQueued(proposalID, eta);
    }

    function execute(uint256 proposalId) public payable {
        require(
            state(proposalId) == ProposalState.Queued,
            "GovernorAlpha::execute: proposal can only be executed if it is queued"
        );
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;
        emit ProposalExecuted(proposalId);
    }

    function cancel(uint256 proposalId) public {
        ProposalState state = state(proposalId);
        require(
            state != ProposalState.Executed,
            "GovernorAlpha::cancel: cannot cancel executed proposal"
        );

        Proposal storage proposal = proposals[proposalId];

        proposal.canceled = true;
        emit ProposalCanceled(proposalId);
    }

    /**
     * @notice Gets the receipt for a voter on a given proposal
     * @param proposalId the id of proposal
     * @param voter The address of the voter
     * @return The voting receipt
     */
    function getReceipt(
        uint256 proposalId,
        address voter
    ) external view returns (Receipt memory) {
        return proposals[proposalId].receipts[voter];
    }

    function castVote(uint256 proposalId, bool support) external {
        require(proposalId <= proposalCount, "Invalid proposalId");
        require(state(proposalId) == ProposalState.Active, "Voting is closed");

        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[msg.sender];
        require(receipt.hasVoted == false, "Voter has already voted");

        ///checking for voting rights
        uint256 collateral = comptroller.getCollateralLength(msg.sender);
        require(collateral >= 1, "Voter has not right to vote");

        if (support) {
            proposal.forVotes += collateral;
        } else {
            proposal.againstVotes += collateral;
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = collateral;

        emit VoteCast(msg.sender, proposalId, support, collateral);
    }
}
