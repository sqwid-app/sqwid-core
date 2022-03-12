// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./interface/ISqwidMarketplace.sol";

contract SqwidGovernance {
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
    }

    ISqwidMarketplace public immutable marketplace;
    uint256 public immutable minConfirmationsRequired;
    address[] public owners;
    Transaction[] public transactions;
    mapping(address => uint256) public addressBalance;
    mapping(address => bool) public isOwner;
    // mapping from tx index => owner => bool
    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);
    event SubmitTransaction(
        address indexed owner,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        bytes data
    );

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Governance: Caller is not owner");
        _;
    }

    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "Governance: Tx does not exist");
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "Governance: Tx already executed");
        _;
    }

    modifier notApproved(uint256 _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "Governance: Tx already approved");
        _;
    }

    constructor(
        address[] memory _owners,
        uint256 _minConfirmationsRequired,
        ISqwidMarketplace _marketplace
    ) {
        require(_owners.length > 0, "Governance: Owners required");
        require(
            _minConfirmationsRequired > 0 && _minConfirmationsRequired <= _owners.length,
            "Governance: Invalid minimum confirmations"
        );
        require(address(_marketplace) != address(0), "Governance: Invalid marketplace address");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "Governance: Invalid owner");
            require(!isOwner[owner], "Governance: Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        minConfirmationsRequired = _minConfirmationsRequired;
        marketplace = _marketplace;
    }

    receive() external payable {}

    // ********** Tx without approval ***********

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
        require(amount > 0, "Governance: No Reef to be claimed");

        addressBalance[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    // *********** Tx with approval **************

    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) external onlyOwner {
        uint256 txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0
            })
        );

        approveTransaction(txIndex);

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function approveTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notApproved(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations++;
        isConfirmed[_txIndex][msg.sender] = true;
    }

    function executeTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numConfirmations >= minConfirmationsRequired,
            "Governance: Tx not approved"
        );

        transaction.executed = true;

        (bool success, ) = transaction.to.call{ value: transaction.value }(transaction.data);
        require(success, "Governance: tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    function getTransaction(uint256 _txIndex)
        public
        view
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 numConfirmations
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }
}
