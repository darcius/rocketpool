pragma solidity 0.6.12;

// SPDX-License-Identifier: GPL-3.0-only

import "../RocketBase.sol";
import "../../interface/dao/RocketDAOInterface.sol";
import "../../interface/dao/RocketDAOProposalInterface.sol";


import "@openzeppelin/contracts/math/SafeMath.sol";


// A DAO proposal
contract RocketDAOProposal is RocketBase, RocketDAOProposalInterface {

    using SafeMath for uint;

    // Events
    event ProposalAdded(address indexed proposer, uint256 indexed proposalID, uint256 indexed proposalType, bytes payload, uint256 time);  
    event ProposalVoted(uint256 indexed proposalID, address indexed voter, bool indexed supported, uint256 time);  
    event ProposalExecuted(uint256 indexed proposalID, address indexed executer, uint256 time);
    event ProposalCancelled(uint256 indexed proposalID, address indexed canceller, uint256 time);    

    // Calculate using this as the base
    uint256 calcBase = 1 ether;

    // The namespace for any data stored in the trusted node DAO (do not change)
    string daoProposalNameSpace = 'dao.proposal';

    // The voting delay for a proposal to start
    uint256 proposalStartDelayBlocks = 1;                   // 1 block
    // The voting period for a proposal to pass
    uint256 proposalVotingBlocks = 92550;                   // Approx. 2 weeks worth of blocks
    // The time for a successful proposal to be executed, 
    // Will need to be resubmitted if this deadline passes
    uint256 proposalVotingExecuteBlocks = 185100;           // Approx. 4 weeks worth of blocks

    
    // Only allow the DAO contract that created this proposal to access
    modifier onlyDAOContract(string memory _daoName) {
        // Load contracts
        require(keccak256(abi.encodePacked(getContractName(msg.sender))) == keccak256(abi.encodePacked(_daoName)), "Sender is not the required DAO contract");
        _;
    }


    // Construct
    constructor(address _rocketStorageAddress) RocketBase(_rocketStorageAddress) public {
        // Version
        version = 1;
    }


    /*** Proposals ****************/
  
    // Get the current total proposals
    function getTotal() override public view returns (uint256) {
        return getUint(keccak256(abi.encodePacked(daoProposalNameSpace, "total"))); 
    }

    // Get the DAO that this proposal belongs too
    function getDAO(uint256 _proposalID) override public view returns (string memory) { 
        return getString(keccak256(abi.encodePacked(daoProposalNameSpace, "dao", _proposalID))); 
    }

    // Get the member who proposed
    function getProposer(uint256 _proposalID) override public view returns (address) {
        return getAddress(keccak256(abi.encodePacked(daoProposalNameSpace, "proposer", _proposalID))); 
    }

    // Get the start block of this proposal
    function getStart(uint256 _proposalID) override public view returns (uint256) {
        return getUint(keccak256(abi.encodePacked(daoProposalNameSpace, "start", _proposalID))); 
    } 

    // Get the end block of this proposal
    function getEnd(uint256 _proposalID) override public view returns (uint256) {
        return getUint(keccak256(abi.encodePacked(daoProposalNameSpace, "end", _proposalID))); 
    }

    // The block that the proposal will be available for execution, set once the vote succeeds
    function getETA(uint256 _proposalID) override public view returns (uint256) {
        return getUint(keccak256(abi.encodePacked(daoProposalNameSpace, "eta", _proposalID))); 
    }

    // Get the created status of this proposal
    function getCreated(uint256 _proposalID) override public view returns (uint256) {
        return getUint(keccak256(abi.encodePacked(daoProposalNameSpace, "created", _proposalID))); 
    }

    // Get the votes for count of this proposal
    function getVotesFor(uint256 _proposalID) override public view returns (uint256) {
        return getUint(keccak256(abi.encodePacked(daoProposalNameSpace, "votes.for", _proposalID))); 
    }

    // Get the votes against count of this proposal
    function getVotesAgainst(uint256 _proposalID) override public view returns (uint256) {
        return getUint(keccak256(abi.encodePacked(daoProposalNameSpace, "votes.against", _proposalID))); 
    }

    // Get the cancelled status of this proposal
    function getCancelled(uint256 _proposalID) override public view returns (bool) {
        return getBool(keccak256(abi.encodePacked(daoProposalNameSpace, "cancelled", _proposalID))); 
    }

    // Get the executed status of this proposal
    function getExecuted(uint256 _proposalID) override public view returns (bool) {
        return getBool(keccak256(abi.encodePacked(daoProposalNameSpace, "executed", _proposalID))); 
    }

    // A successful proposal needs to be execute before it ends (set amount of blocks), if it expires the proposal needs to be resubmitted
    function getExecutedEnded(uint256 _proposalID) override public view returns (bool) {
        return getEnd(_proposalID).add(proposalVotingExecuteBlocks) < block.number ? true : false; 
    }

    // Get the votes against count of this proposal
    function getPayload(uint256 _proposalID) override public view returns (bytes memory) {
        return getBytes(keccak256(abi.encodePacked(daoProposalNameSpace, "payload", _proposalID))); 
    }

    // Returns true if this proposal has already been voted on by a member
    function getReceiptHasVoted(uint256 _proposalID, address _nodeAddress) override public view returns (bool) {
        return getBool(keccak256(abi.encodePacked(daoProposalNameSpace, "receipt.hasVoted", _proposalID, _nodeAddress))); 
    }

    // Returns true if this proposal was supported by this member
    function getReceiptSupported(uint256 _proposalID, address _nodeAddress) override public view returns (bool) {
        return getBool(keccak256(abi.encodePacked(daoProposalNameSpace, "receipt.supported", _proposalID, _nodeAddress))); 
    }
    

    // Return the state of the specified proposal
    function getState(uint256 _proposalID) override public view returns (ProposalState) {
        // Load contracts
        RocketDAOInterface dao = RocketDAOInterface(getContractAddress(getDAO(_proposalID)));
        // Check the proposal ID is legit
        require(getTotal() >= _proposalID && _proposalID > 0, "Invalid proposal ID");
        // Get the amount of votes for and against
        uint256 votesFor = getVotesFor(_proposalID);
        uint256 votesAgainst = getVotesAgainst(_proposalID);
        // Now return the state of the current proposal
        if (getCancelled(_proposalID)) {
            // Cancelled by the proposer?
            return ProposalState.Cancelled;
            // Is the proposal pending? Eg. waiting to be voted on
        } else if (block.number <= getStart(_proposalID)) {
            return ProposalState.Pending;
            // The proposal is active and can be voted on
        } else if (block.number <= getEnd(_proposalID)) {
            return ProposalState.Active;
            // Check the votes, was it defeated?
        } else if (votesFor <= votesAgainst || votesFor < dao.getProposalQuorumVotesRequired()) {
            return ProposalState.Defeated;
            // If the ETA is 0, it means it has succeeded, but the block it will be available for execution has not been set yet
        } else if (getETA(_proposalID) == 0) {
            return ProposalState.Succeeded;
            // Has it been executed?
        } else if (getExecuted(_proposalID)) {
            return ProposalState.Executed;
            // Has it expired?
        } else if (block.number >= getETA(_proposalID).add(proposalVotingExecuteBlocks)) {
            return ProposalState.Expired;
        } else {
            // It is queued, awaiting execution
            return ProposalState.Queued;
        }
    }


    // Add a proposal to the an RP DAO, immeditately becomes active
    // Calldata is passed as the payload to execute upon passing the proposal
    // TODO: Add required checks
    function add(string memory _proposalDAO, uint256 _proposalType, string memory _proposalMessage, bytes memory _payload) override public onlyDAOContract(_proposalDAO) returns (bool) {
        // TODO: Move 2 lines below to DAO contract resposible
        // Check this user can make a proposal now
        //require(getValid(msg.sender), "Member cannot make a proposal or has not waited long enough to make another proposal");
        // Save the last time they made a proposal
        //setUint(keccak256(abi.encodePacked(daoProposalNameSpace, "member.last", msg.sender)), block.number);
        // Get the total proposal count
        uint256 proposalCount = getTotal(); 
        // Get the proposal ID
        uint256 proposalID = proposalCount.add(1);
        // The data structure for a proposal
        setString(keccak256(abi.encodePacked(daoProposalNameSpace, "dao", proposalID)), _proposalDAO);
        setUint(keccak256(abi.encodePacked(daoProposalNameSpace, "type", proposalID)), _proposalType);
        setString(keccak256(abi.encodePacked(daoProposalNameSpace, "message", proposalID)), _proposalMessage);
        setAddress(keccak256(abi.encodePacked(daoProposalNameSpace, "proposer", proposalID)), msg.sender);
        setUint(keccak256(abi.encodePacked(daoProposalNameSpace, "start", proposalID)), block.number.add(proposalStartDelayBlocks));
        setUint(keccak256(abi.encodePacked(daoProposalNameSpace, "end", proposalID)), block.number.add(proposalVotingBlocks));
        setUint(keccak256(abi.encodePacked(daoProposalNameSpace, "created", proposalID)), block.number);
        setUint(keccak256(abi.encodePacked(daoProposalNameSpace, "votes.for", proposalID)), 0);
        setUint(keccak256(abi.encodePacked(daoProposalNameSpace, "votes.against", proposalID)), 0);
        setBool(keccak256(abi.encodePacked(daoProposalNameSpace, "cancelled", proposalID)), false);
        setBool(keccak256(abi.encodePacked(daoProposalNameSpace, "executed", proposalID)), false);
        setBytes(keccak256(abi.encodePacked(daoProposalNameSpace, "payload", proposalID)), _payload);
        // Update the total proposals
        setUint(keccak256(abi.encodePacked(daoProposalNameSpace, "total")), proposalID);
        // Log it
        emit ProposalAdded(msg.sender, proposalID, _proposalType, _payload, now);
    }


    // Voting for or against a proposal
    function vote(uint256 _proposalID, bool _support) override public onlyDAOContract(getDAO(_proposalID)) {
        // Check the proposal is in a state that can be voted on
        require(getState(_proposalID) == ProposalState.Active, "Voting is closed for this proposal");
        // Has this member already voted on this proposal?
        require(!getReceiptHasVoted(_proposalID, msg.sender), "Member has already voted on proposal");
        // Add votes to proposal
        if(_support) {
            setUint(keccak256(abi.encodePacked(daoProposalNameSpace, "votes.for", _proposalID)), getVotesFor(_proposalID).add(1));
        }else{
            setUint(keccak256(abi.encodePacked(daoProposalNameSpace, "votes.against", _proposalID)), getVotesAgainst(_proposalID).add(1));
        }
        // Record the vote receipt now
        setBool(keccak256(abi.encodePacked(daoProposalNameSpace, "receipt.hasVoted", _proposalID, msg.sender)), true);
        setBool(keccak256(abi.encodePacked(daoProposalNameSpace, "receipt.supported", _proposalID, msg.sender)), _support);
        // Log it
        emit ProposalVoted(_proposalID, msg.sender, _support, now);
    }
    

    // Execute a proposal if it has passed
    // Anyone can run this if they are willing to pay the gas costs for it
    // A proposal can be executed as soon as it hits a majority in favour
    // The original proposer must still be a member for it to be executed
    function execute(uint256 _proposalID) override public onlyDAOContract(getDAO(_proposalID)) {
        // Firstly make sure this proposal has passed
        require(getState(_proposalID) == ProposalState.Succeeded, "Proposal has not succeeded or has already been executed");
        // Check that the time period to execute hasn't expired (1 month to execute by default after voting period)
        require(!getExecutedEnded(_proposalID), "Time to execute successful proposal has expired, please resubmit proposal for voting");
        // Set as executed now before running payload
        setBool(keccak256(abi.encodePacked(daoProposalNameSpace, "executed", _proposalID)), true);
        // Ok all good, lets run the payload, it should execute one of the methods on this contract
        (bool success,) = address(this).call(getPayload(_proposalID));
        // Verify it was successful
        require(success, "Payload call was not successful");
        // Log it
        emit ProposalExecuted(_proposalID, msg.sender, now);
    }


    // Cancel a proposal, can be cancelled by the original proposer only if it hasn't been executed yet
    function cancel(uint256 _proposalID) override public onlyDAOContract(getDAO(_proposalID)) {
        // Firstly make sure this proposal that hasn't already been executed
        require(getState(_proposalID) != ProposalState.Executed, "Proposal has not succeeded or has already been executed");
        // Only allow the proposer to cancel
        require(getProposer(_proposalID) == msg.sender, "Proposal can only be cancelled by the proposer");
        // Set as cancelled now
        setBool(keccak256(abi.encodePacked(daoProposalNameSpace, "cancelled", _proposalID)), true);
        // Log it
        emit ProposalCancelled(_proposalID, msg.sender, now);
    }

        

}