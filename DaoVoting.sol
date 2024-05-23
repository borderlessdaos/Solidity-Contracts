// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FractionalNFTWithVoting is ERC1155, Ownable {
    struct Fraction {
        uint256 tokenId;
        uint256 amount;
        uint256 totalSupply;
        address owner;
        mapping(address => uint256) votes;
    }

    enum GovernanceModel { SimpleMajority, Supermajority, Consensus }

    struct Proposal {
        string title;
        string description;
        string[] options;
        uint deadline;
        bool votingStarted;
        mapping(address => bool) hasVoted;
        mapping(string => uint) votes;
    }

    mapping(uint256 => Fraction) public fractions;
    mapping(uint256 => uint256) public tokenIdToFractionId;
    uint256 public fractionCounter;
    address public factory;
    uint256 public decisionThreshold;
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;

    event FractionCreated(uint256 indexed tokenId, uint256 indexed fractionId, uint256 amount);
    event FractionTransferred(uint256 indexed fractionId, address indexed from, address indexed to, uint256 amount);
    event VoteCasted(uint256 indexed fractionId, address indexed voter, bool vote);
    event ProposalCreated(uint proposalId, string title);
    event VotingStarted(uint proposalId, uint deadline);
    event VoteRecorded(uint proposalId, string option, address voter);

    constructor(address _factory, uint256 _decisionThreshold) ERC1155("") {
        factory = _factory;
        decisionThreshold = _decisionThreshold;
    }

    function createFraction(uint256 _tokenId, uint256 _amount) external {
        require(msg.sender == factory, "Only factory can create fractions");
        require(_amount > 0, "Amount must be greater than zero");
        require(fractions[fractionCounter].totalSupply == 0, "Fraction already exists for this token");

        fractions[fractionCounter] = Fraction({
            tokenId: _tokenId,
            amount: _amount,
            totalSupply: _amount,
            owner: msg.sender
        });

        tokenIdToFractionId[_tokenId] = fractionCounter;
        _mint(msg.sender, fractionCounter, _amount, "");

        emit FractionCreated(_tokenId, fractionCounter, _amount);
        fractionCounter++;
    }

    function transferFraction(address _to, uint256 _fractionId, uint256 _amount) external {
        require(fractions[_fractionId].owner == msg.sender, "You don't own this fraction");
        require(_to != address(0), "Invalid address");
        require(_amount > 0 && _amount <= balanceOf(msg.sender, _fractionId), "Invalid amount");

        _safeTransferFrom(msg.sender, _to, _fractionId, _amount, "");
        fractions[_fractionId].amount -= _amount;

        emit FractionTransferred(_fractionId, msg.sender, _to, _amount);
    }

    function castVote(uint256 _fractionId, bool _vote) external {
        require(fractions[_fractionId].owner != address(0), "Fraction does not exist");
        require(balanceOf(msg.sender, _fractionId) > 0, "You don't own any fraction of this NFT");

        fractions[_fractionId].votes[msg.sender] = _vote ? 1 : 0;

        emit VoteCasted(_fractionId, msg.sender, _vote);
    }

    function calculateDecision(uint256 _fractionId, GovernanceModel _model) external view returns (bool) {
        require(fractions[_fractionId].owner != address(0), "Fraction does not exist");

        uint256 totalVotes = 0;
        uint256 totalSupply = fractions[_fractionId].totalSupply;

        // Count votes by iterating over all token holders
        for (uint256 i = 0; i < fractionCounter; i++) {
            address owner = fractions[i].owner;
            if (fractions[_fractionId].votes[owner] == 1) {
                totalVotes++;
            }
        }

        if (_model == GovernanceModel.SimpleMajority) {
            return totalVotes > (totalSupply / 2);
        } else if (_model == GovernanceModel.Supermajority) {
            return totalVotes >= ((totalSupply * 2) / 3);
        } else if (_model == GovernanceModel.Consensus) {
            return totalVotes == totalSupply;
        }

        return false;
    }

    function createProposal(
        string memory _title,
        string memory _description,
        string[] memory _options
    ) public returns (uint) {
        proposalCount++;
        Proposal storage proposal = proposals[proposalCount];
        proposal.title = _title;
        proposal.description = _description;
        proposal.options = _options;
        emit ProposalCreated(proposalCount, _title);
        return proposalCount;
    }

    function startVoting(uint _proposalId, uint _duration) public {
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.votingStarted, "Voting already started");
        proposal.votingStarted = true;
        proposal.deadline = block.timestamp + _duration;
        emit VotingStarted(_proposalId, proposal.deadline);
    }

    function vote(uint _proposalId, string memory _option) public {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp < proposal.deadline, "Voting has ended");
        require(!proposal.hasVoted[msg.sender], "You have already voted");

        proposal.votes[_option]++;
        proposal.hasVoted[msg.sender] = true;
        emit VoteRecorded(_proposalId, _option, msg.sender);
    }

    function getVotes(uint _proposalId, string memory _option) public view returns (uint) {
        Proposal storage proposal = proposals[_proposalId];
        return proposal.votes[_option];
    }

    function getProposal(uint _proposalId) public view returns (
        string memory title,
        string memory description,
        string[] memory options,
        uint deadline,
        bool votingStarted,
        uint[] memory voteCounts
    ) {
        Proposal storage proposal = proposals[_proposalId];
        voteCounts = new uint[](proposal.options.length);
        for (uint i = 0; i < proposal.options.length; i++) {
            voteCounts[i] = proposal.votes[proposal.options[i]];
        }
        return (
            proposal.title,
            proposal.description,
            proposal.options,
            proposal.deadline,
            proposal.votingStarted,
            voteCounts
        );
    }
} 