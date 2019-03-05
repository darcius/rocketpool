pragma solidity 0.5.0;


import "../../RocketBase.sol";
import "../../interface/minipool/RocketMinipoolInterface.sol";
import "../../interface/token/RocketBETHTokenInterface.sol";


/// @title RocketNodeWatchtower - Handles watchtower (trusted) node functions
/// @author Jake Pospischil

contract RocketNodeWatchtower is RocketBase {


    /*** Contracts **************/


    RocketBETHTokenInterface rocketBETHToken = RocketBETHTokenInterface(0);


    /*** Modifiers **************/


    /// @dev Only passes if the sender is a trusted node account
    modifier onlyTrustedNode() {
        require(rocketStorage.getBool(keccak256(abi.encodePacked("node.trusted", msg.sender))), "Caller is not a trusted node account.");
        _;
    }


    /*** Methods ****************/


    /// @dev Set a minipool to LoggedOut status
    /// @param _minipool The address of the minipool to log out
    function logoutMinipool(address _minipool) public onlyTrustedNode returns (bool) {
        // Set minipool status to LoggedOut, reverts if already at status
        RocketMinipoolInterface minipool = RocketMinipoolInterface(_minipool);
        minipool.setStatusTo(3);
        // Success
        return true;
    }


    /// @dev Set a minipool to Withdrawn status and mint RPB tokens to it
    /// @param _minipool The address of the minipool to withdraw
    /// @param _balance The balance of the minipool to mint as RPB tokens
    function withdrawMinipool(address _minipool, uint256 _balance) public onlyTrustedNode returns (bool) {
        // Mint RPB tokens to minipool
        rocketBETHToken = RocketBETHTokenInterface(getContractAddress("rocketBETHToken"));
        rocketBETHToken.mint(_minipool, _balance);
        // Set minipool status to Withdrawn, reverts if already at status
        RocketMinipoolInterface minipool = RocketMinipoolInterface(_minipool);
        minipool.setStatusTo(4);
        // Success
        return true;
    }


}