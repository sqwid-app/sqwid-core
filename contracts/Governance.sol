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

    struct OwnersChange {
        address ownerChanged;
        bool addToList;
        uint256 numConfirmations;
    }

    struct MinConfirmationsChange {
        uint256 newValue;
        uint256 numConfirmations;
    }

    address[] private owners;
    uint256 public minConfirmationsRequired;
    mapping(address => uint256) public addressBalance;
    mapping(address => bool) public isOwner;

    Transaction[] public transactions;
    // mapping from tx index => owner => bool
    mapping(uint256 => mapping(address => bool)) public txApproved;

    OwnersChange[] public ownersChanges;
    // mapping from owner change index => owner => bool
    mapping(uint256 => mapping(address => bool)) public ownersChangeApproved;

    MinConfirmationsChange[] public minConfirmationsChanges;
    // mapping from min confirmation change index => owner => bool
    mapping(uint256 => mapping(address => bool)) public minConfirmationsChangeApproved;

    event ProposeTransaction(
        address owner,
        uint256 indexed txIndex,
        address ownerChanged,
        uint256 value,
        bytes data
    );

    event ExecuteTransaction(address owner, uint256 indexed txIndex);

    event ProposeOwnersChange(
        address owner,
        uint256 indexed ownersChangeIndex,
        address ownerChanged,
        bool addToList
    );

    event ExecuteOwnersChange(address owner, uint256 indexed ownersChangeIndex);

    event ProposeMinConfirmationsChange(
        address owner,
        uint256 indexed minConfirmationsChangeIndex,
        uint256 newValue
    );

    event ExecuteMinConfirmationsChange(address owner, uint256 indexed minConfirmationsChangeIndex);

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Governance: Caller is not owner");
        _;
    }

    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "Governance: Tx does not exist");
        _;
    }

    modifier txNotExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "Governance: Tx already executed");
        _;
    }

    modifier ownersChangeExists(uint256 _ownersChangeIndex) {
        require(
            _ownersChangeIndex < ownersChanges.length,
            "Governance: Owners change does not exist"
        );
        _;
    }

    modifier minConfirmationsChangeExists(uint256 _minConfirmationsChangeIndex) {
        require(
            _minConfirmationsChangeIndex < minConfirmationsChanges.length,
            "Governance: Min confirmations change does not exist"
        );
        _;
    }

    constructor(address[] memory _owners, uint256 _minConfirmationsRequired) {
        require(_owners.length > 0, "Governance: Owners required");
        require(
            _minConfirmationsRequired > 0 && _minConfirmationsRequired <= _owners.length,
            "Governance: Invalid minimum confirmations"
        );

        for (uint256 i; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "Governance: Invalid owner");
            require(!isOwner[owner], "Governance: Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        minConfirmationsRequired = _minConfirmationsRequired;
    }

    receive() external payable {}

    ///////////////////////////// TX WITHOUT APPROVAL /////////////////////////////////////
    ///////////////////// Any of the owners can execute them //////////////////////////////

    /**
     * Withdraws available balance from marketplace contract.
     */
    function transferFromMarketplace(ISqwidMarketplace _marketplace) external onlyOwner {
        _marketplace.withdraw();
    }

    /**
     * Returns available balance to be shared among all the owners.
     */
    function getAvailableBalance() public view returns (uint256) {
        uint256 availableBalance = address(this).balance;
        for (uint256 i; i < owners.length; i++) {
            availableBalance -= addressBalance[owners[i]];
        }

        return availableBalance;
    }

    /**
     * Shares available balance (if any) among all the owners and increments their balances.
     * Withdraws balance of the caller.
     */
    function withdraw() external onlyOwner {
        uint256 availableBalance = getAvailableBalance();

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

    /**
     * Returns array of owners.
     */
    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    /**
     * Returns total number of transaction proposals.
     */
    function transactionsCount() external view returns (uint256) {
        return transactions.length;
    }

    /**
     * Returns total number of owners change proposals.
     */
    function ownersChangesCount() external view returns (uint256) {
        return ownersChanges.length;
    }

    /**
     * Returns total number of minimum confirmations change proposals.
     */
    function minConfirmationsChangesCount() external view returns (uint256) {
        return minConfirmationsChanges.length;
    }

    //////////////////////// EXTERNAL TX WITH APPROVAL ////////////////////////////////////
    ///////////// Requires a minimum of confirmations to be executed //////////////////////

    /**
     * Creates a proposal for an external transaction.
     *      `_to`: address to be called
     *      `_value`: value of Reef to be sent
     *      `_data`: data to be sent
     */
    function proposeTransaction(
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

        emit ProposeTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    /**
     * Approves a transaction.
     */
    function approveTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        txNotExecuted(_txIndex)
    {
        require(!txApproved[_txIndex][msg.sender], "Governance: Tx already approved");
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations++;
        txApproved[_txIndex][msg.sender] = true;
    }

    /**
     * Executes a transaction.
     * It should have the minimum number of confirmations required in order to be executed.
     */
    function executeTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        txNotExecuted(_txIndex)
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

    //////////////////////// INTERNAL TX WITH APPROVAL ////////////////////////////////////
    ///////////// Requires a minimum of confirmations to be executed //////////////////////

    /**
     * Creates a proposal for a change in the list of owners.
     *      `_ownerChanged`: address of the owner to be changed
     *      `_addToList`: true --> add new owner / false --> remove existing owner
     */
    function proposeOwnersChange(address _ownerChanged, bool _addToList) external onlyOwner {
        uint256 ownersChangeIndex = ownersChanges.length;

        ownersChanges.push(
            OwnersChange({
                ownerChanged: _ownerChanged,
                addToList: _addToList,
                numConfirmations: 0
            })
        );

        approveOwnersChange(ownersChangeIndex);

        emit ProposeOwnersChange(msg.sender, ownersChangeIndex, _ownerChanged, _addToList);
    }

    /**
     * Approves a change in the owners list.
     */
    function approveOwnersChange(uint256 _ownersChangeIndex)
        public
        onlyOwner
        ownersChangeExists(_ownersChangeIndex)
    {
        require(
            !ownersChangeApproved[_ownersChangeIndex][msg.sender],
            "Governance: Owners change already approved"
        );
        OwnersChange storage ownersChange = ownersChanges[_ownersChangeIndex];
        ownersChange.numConfirmations++;
        ownersChangeApproved[_ownersChangeIndex][msg.sender] = true;
    }

    /**
     * Executes a change in the owners list.
     * It should have the minimum number of confirmations required in order to do the change.
     */
    function executeOwnersChange(uint256 _ownersChangeIndex)
        public
        onlyOwner
        ownersChangeExists(_ownersChangeIndex)
    {
        OwnersChange storage ownersChange = ownersChanges[_ownersChangeIndex];

        require(
            ownersChange.numConfirmations >= minConfirmationsRequired,
            "Governance: Owners change not approved"
        );

        if (ownersChange.addToList) {
            require(!isOwner[ownersChange.ownerChanged], "Governance: Owner not unique");

            isOwner[ownersChange.ownerChanged] = true;
            owners.push(ownersChange.ownerChanged);
        } else {
            require(isOwner[ownersChange.ownerChanged], "Governance: Owner not found");

            isOwner[ownersChange.ownerChanged] = false;
            uint256 index;
            for (uint256 i; i < owners.length; i++) {
                if (owners[i] == ownersChange.ownerChanged) {
                    index = i;
                    break;
                }
            }
            owners[index] = owners[owners.length - 1];
            owners.pop();

            if (minConfirmationsRequired > owners.length) {
                minConfirmationsRequired = owners.length;
            }
        }

        _resetProposals();

        emit ExecuteOwnersChange(msg.sender, _ownersChangeIndex);
    }

    /**
     * Creates a proposal for a change in the minimum number of confirmations required to execute
     * transactions, changes in owners and changes in minum number of confirmations.
     *      `_newValue`: new value for the minimum number of confirmations required
     */
    function proposeMinConfirmationsChange(uint256 _newValue) external onlyOwner {
        uint256 minConfirmationsChangeIndex = minConfirmationsChanges.length;

        minConfirmationsChanges.push(
            MinConfirmationsChange({ newValue: _newValue, numConfirmations: 0 })
        );

        approveMinConfirmationsChange(minConfirmationsChangeIndex);

        emit ProposeMinConfirmationsChange(msg.sender, minConfirmationsChangeIndex, _newValue);
    }

    /**
     * Approves a change in the minimum number of confirmations required.
     */
    function approveMinConfirmationsChange(uint256 _minConfirmationsChangeIndex)
        public
        onlyOwner
        minConfirmationsChangeExists(_minConfirmationsChangeIndex)
    {
        require(
            !minConfirmationsChangeApproved[_minConfirmationsChangeIndex][msg.sender],
            "Governance: Min confirmations change already approved"
        );
        MinConfirmationsChange storage minConfirmationsChange = minConfirmationsChanges[
            _minConfirmationsChangeIndex
        ];
        minConfirmationsChange.numConfirmations++;
        minConfirmationsChangeApproved[_minConfirmationsChangeIndex][msg.sender] = true;
    }

    /**
     * Executes a change in the minimum number of confirmations required.
     * It should have the minimum number of confirmations required in order to be executed.
     */
    function executeMinConfirmationsChange(uint256 _minConfirmationsChangeIndex)
        public
        onlyOwner
        minConfirmationsChangeExists(_minConfirmationsChangeIndex)
    {
        MinConfirmationsChange storage minConfirmationsChange = minConfirmationsChanges[
            _minConfirmationsChangeIndex
        ];

        require(
            minConfirmationsChange.numConfirmations >= minConfirmationsRequired,
            "Governance: Min confirmations change not approved"
        );
        require(
            minConfirmationsChange.newValue > 0 && minConfirmationsChange.newValue <= owners.length,
            "Governance: Invalid minimum confirmations"
        );

        minConfirmationsRequired = minConfirmationsChange.newValue;

        _resetProposals();

        emit ExecuteMinConfirmationsChange(msg.sender, _minConfirmationsChangeIndex);
    }

    /**
     * Resets all proposals confirmations count after the owners list or the
     * minConfirmationsRequired value have been modified.
     * Existing approvals for those proposals are invalidated.
     */
    function _resetProposals() private {
        for (uint256 i; i < transactions.length; i++) {
            if (!transactions[i].executed) {
                transactions[i].numConfirmations = 0;
            }
        }

        for (uint256 i; i < ownersChanges.length; i++) {
            ownersChanges[i].numConfirmations = 0;
        }

        for (uint256 i; i < minConfirmationsChanges.length; i++) {
            minConfirmationsChanges[i].numConfirmations = 0;
        }
    }
}
