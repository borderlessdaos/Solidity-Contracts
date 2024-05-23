// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract DAOVoting is ERC1155, Ownable {
    using Counters for Counters.Counter;

    uint256 public currentTokenID = 0;
    uint256 public constant TOTAL_SHARES = 1000000;

    struct Proposal {
        string description;
        uint256 deadline;
        uint256 votingStart;
        mapping(address => bool) hasVoted;
        uint256 yesVotes;
        uint256 noVotes;
        bool finalized;
    }

    mapping(uint256 => Proposal) public proposals;

    Counters.Counter private proposalCounter;

    event ProposalCreated(uint256 indexed tokenID, string description, uint256 deadline);
    event VotingStarted(uint256 indexed tokenID, uint256 votingStart);
    event VoteSubmitted(uint256 indexed proposalID, address indexed voter, bool choice);
    event ProposalFinalized(uint256 indexed proposalID, uint256 yesVotes, uint256 noVotes);

    constructor(string memory uri) ERC1155(uri) Ownable(0x7e2eD6241f395E32c2fcEdCE0829e0506cbCFc79) {
        // Fractionalize the NFT "borderlesspower.dao" into 1,000,000 shares
        _mint(msg.sender, currentTokenID, TOTAL_SHARES, "");
        currentTokenID++;
    }

    function fractionalize(uint256 tokenID, uint256 amount) public onlyOwner {
        require(balanceOf(msg.sender, tokenID) >= amount, "Insufficient token balance to fractionalize");
        _mint(msg.sender, tokenID, amount, "");
    }

    function distributeFractionalShares(uint256 tokenID, address[] memory recipients, uint256[] memory amounts) public onlyOwner {
        require(recipients.length == amounts.length, "Recipients and amounts arrays must have the same length");
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], tokenID, amounts[i], "");
        }
    }

    function createProposal(string memory description, uint256 deadline) public onlyOwner {
        require(deadline > block.timestamp, "Deadline should be in the future");
        uint256 proposalID = proposalCounter.current();
        proposals[proposalID].description = description;
        proposals[proposalID].deadline = deadline;
        emit ProposalCreated(proposalID, description, deadline);
        _mint(msg.sender, proposalID, 1, "");
        proposalCounter.increment();
    }

    function startVoting(uint256 proposalID, uint256 votingStart) public onlyOwner {
        require(votingStart < proposals[proposalID].deadline, "Voting start time must be before the proposal deadline");
        proposals[proposalID].votingStart = votingStart;
        emit VotingStarted(proposalID, votingStart);
    }

    function submitVote(uint256 proposalID, bool choice) public {
        Proposal storage proposal = proposals[proposalID];
        require(proposal.votingStart > 0 && block.timestamp >= proposal.votingStart && block.timestamp <= proposal.deadline, "Voting period has not started or has ended");
        require(!proposal.hasVoted[msg.sender], "You have already voted for this proposal");
        proposal.hasVoted[msg.sender] = true;
        if (choice) {
            proposal.yesVotes++;
        } else {
            proposal.noVotes++;
        }
        emit VoteSubmitted(proposalID, msg.sender, choice);
    }

    function finalizeProposal(uint256 proposalID) public onlyOwner {
        Proposal storage proposal = proposals[proposalID];
        require(block.timestamp > proposal.deadline, "Voting period has not ended");
        require(!proposal.finalized, "Proposal has already been finalized");
        proposal.finalized = true;
        emit ProposalFinalized(proposalID, proposal.yesVotes, proposal.noVotes);
    }

    function getVotingHistory(uint256 proposalID) public view returns (uint256 yesVotes, uint256 noVotes, bool finalized) {
        Proposal storage proposal = proposals[proposalID];
        return (proposal.yesVotes, proposal.noVotes, proposal.finalized);
    }

    function getCurrentProposalID() public view returns (uint256) {
        return proposalCounter.current();
    }

    function getCurrentTimestamp() public view returns (uint256) {
        return block.timestamp;
    }

    function getRandomNumber(uint256 range) public view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, blockhash(block.number - 1), range))) % range;
    }
}
