// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./interface/ISqwidMarketplace.sol";

contract SqwidGovernance {
    ISqwidMarketplace public immutable marketplace;
    address[] public owners;
    mapping(address => uint256) public addressBalance;
    mapping(address => bool) public isOwner;
    // mapping from newMarketOwner => owner => bool
    mapping(address => mapping(address => bool)) public isApproved;
    mapping(address => uint256) public marketOwnerApprovals;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Governance: Caller is not owner");
        _;
    }

    constructor(address[] memory _owners, ISqwidMarketplace _marketplace) {
        require(_owners.length > 0, "Governance: Oowners required");
        marketplace = _marketplace;

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "Governance: Invalid owner");
            require(!isOwner[owner], "Governance: Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }
    }

    receive() external payable {}

    function setMarketFee(uint16 marketFee, ISqwidMarketplace.PositionState typeFee)
        external
        onlyOwner
    {
        marketplace.setMarketFee(marketFee, typeFee);
    }

    function setMimeTypeFee(uint256 mimeTypeFee) external onlyOwner {
        marketplace.setMimeTypeFee(mimeTypeFee);
    }

    function setNftContractAddress(ISqwidERC1155 sqwidERC1155) external onlyOwner {
        marketplace.setNftContractAddress(sqwidERC1155);
    }

    function setMigratorAddress(ISqwidMigrator sqwidMigrator) external onlyOwner {
        marketplace.setMigratorAddress(sqwidMigrator);
    }

    function transferFromMarketplace() external onlyOwner {
        marketplace.withdraw();
    }

    function transferMarketplaceOwnership(address newMarketOwner) external onlyOwner {
        require(
            marketOwnerApprovals[newMarketOwner] == owners.length,
            "Governance: New owner not approved"
        );

        marketOwnerApprovals[newMarketOwner] = 0;
        for (uint256 i; i < owners.length; i++) {
            isApproved[newMarketOwner][owners[i]] = false;
        }

        marketplace.transferOwnership(newMarketOwner);
    }

    function withdraw() external onlyOwner {
        uint256 availableBalance = address(this).balance;
        for (uint256 i; i < owners.length; i++) {
            availableBalance -= addressBalance[owners[i]];
        }

        if (availableBalance >= owners.length) {
            uint256 share = availableBalance / owners.length;
            for (uint256 i; i < owners.length; i++) {
                addressBalance[owners[i]] += share;
            }
        }

        uint256 amount = addressBalance[msg.sender];
        require(amount > 0, "No Reef to be claimed");

        addressBalance[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function approveNewMarketOwner(address newMarketOwner) public onlyOwner {
        require(!isApproved[newMarketOwner][msg.sender], "Governance: Already approved");

        marketOwnerApprovals[newMarketOwner] += 1;
        isApproved[newMarketOwner][msg.sender] = true;
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }
}
