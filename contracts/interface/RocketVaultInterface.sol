pragma solidity 0.6.12;

// SPDX-License-Identifier: GPL-3.0-only

interface RocketVaultInterface {
    function balanceOf(address _contractAddress) external view returns (uint256);
    function depositEther() external payable;
    function withdrawEther(uint256 _amount) external;
    function depositToken(address _tokenAddress, uint256 _amount) external;
    function withdrawToken(address _tokenAddress, uint256 _amount) external;
}
