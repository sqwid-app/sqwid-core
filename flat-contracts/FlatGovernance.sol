// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface ISqwidMigrator {
    function positionClosed(
        uint256 positionId,
        address receiver,
        bool saleCreated
    ) external;
}

interface ISqwidERC1155 {
    function mint(
        address to,
        uint256 amount,
        string memory tokenURI,
        string calldata mimeType_,
        address royaltyRecipient,
        uint256 royaltyValue
    ) external returns (uint256);

    function mintBatch(
        address to,
        uint256[] memory amounts,
        string[] memory tokenURIs,
        string[] calldata mimeTypes,
        address[] memory royaltyRecipients,
        uint256[] memory royaltyValues
    ) external returns (uint256[] memory);

    function burn(
        address account,
        uint256 id,
        uint256 amount
    ) external;

    function wrapERC721(
        address extNftContract,
        uint256 extTokenId,
        string calldata mimeType_
    ) external returns (uint256);

    function wrapERC1155(
        address extNftContract,
        uint256 extTokenId,
        string calldata mimeType_,
        uint256 amount
    ) external returns (uint256);

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;

    function balanceOf(address account, uint256 id) external view returns (uint256);

    function setApprovalForAll(address operator, bool approved) external;

    function isApprovedForAll(address account, address operator) external view returns (bool);

    function mimeType(uint256 tokenId) external view returns (string memory);
}

interface ISqwidMarketplace {
    enum PositionState {
        Available,
        RegularSale,
        Auction,
        Raffle,
        Loan
    }

    struct Item {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address creator;
        uint256 positionCount;
        ItemSale[] sales;
    }

    struct Position {
        uint256 positionId;
        uint256 itemId;
        address payable owner;
        uint256 amount;
        uint256 price;
        uint256 marketFee;
        PositionState state;
    }

    struct ItemSale {
        address seller;
        address buyer;
        uint256 price;
        uint256 amount;
    }

    struct AuctionData {
        uint256 deadline;
        uint256 minBid;
        address highestBidder;
        uint256 highestBid;
        mapping(address => uint256) addressToAmount;
        mapping(uint256 => address) indexToAddress;
        uint256 totalAddresses;
    }

    struct RaffleData {
        uint256 deadline;
        uint256 totalValue;
        mapping(address => uint256) addressToAmount;
        mapping(uint256 => address) indexToAddress;
        uint256 totalAddresses;
    }

    struct LoanData {
        uint256 loanAmount;
        uint256 feeAmount;
        uint256 numMinutes;
        uint256 deadline;
        address lender;
    }

    struct AuctionDataResponse {
        uint256 deadline;
        uint256 minBid;
        address highestBidder;
        uint256 highestBid;
        uint256 totalAddresses;
    }

    struct RaffleDataResponse {
        uint256 deadline;
        uint256 totalValue;
        uint256 totalAddresses;
    }

    function transferOwnership(address newOwner) external;

    function setMarketFee(uint16 marketFee_, PositionState typeFee) external;

    function setMimeTypeFee(uint256 mimeTypeFee_) external;

    function setNftContractAddress(ISqwidERC1155 sqwidERC1155_) external;

    function setMigratorAddress(ISqwidMigrator sqwidMigrator_) external;

    function withdraw() external;

    function currentItemId() external view returns (uint256);

    function currentPositionId() external view returns (uint256);

    function fetchItem(uint256 itemId) external view returns (Item memory);

    function fetchPosition(uint256 positionId) external view returns (Position memory);

    function fetchStateCount(PositionState state) external view returns (uint256);

    function fetchAuctionData(uint256 positionId)
        external
        view
        returns (AuctionDataResponse memory);

    function fetchBid(uint256 positionId, uint256 bidIndex)
        external
        view
        returns (address, uint256);

    function fetchRaffleData(uint256 positionId) external view returns (RaffleDataResponse memory);

    function fetchRaffleEntry(uint256 positionId, uint256 entryIndex)
        external
        view
        returns (address, uint256);

    function fetchLoanData(uint256 positionId) external view returns (LoanData memory);
}

contract SqwidGovernance {
    struct Transaction {
        uint256 id;
        address proposer;
        address to;
        uint256 value;
        bytes data;
        uint256 deadline;
        uint256 numConfirmations;
        bool executed;
        bool cancelled;
    }

    struct OwnersChange {
        uint256 id;
        address proposer;
        address ownerChanged;
        bool addToList;
        uint256 deadline;
        uint256 numConfirmations;
        bool executed;
        bool cancelled;
    }

    struct MinConfirmationsChange {
        uint256 id;
        address proposer;
        uint256 newValue;
        uint256 deadline;
        uint256 numConfirmations;
        bool executed;
        bool cancelled;
    }

    uint256 public constant DURATION = 1 weeks;
    uint256 public constant MAX_ACTIVE_PROPOSALS_PER_OWNER = 10;

    address[] private owners;
    uint256 public minConfirmationsRequired;
    mapping(address => uint256) public addressBalance;
    mapping(address => bool) public isOwner;
    mapping(address => uint256) public ownerActiveProposalsCount;

    uint256 public transactionsCount;
    // tx id => Transaction
    mapping(uint256 => Transaction) public transactions;
    uint256[] public activeTransactionsIds;
    // tx id => (owner => approved)
    mapping(uint256 => mapping(address => bool)) public txApproved;

    uint256 public ownersChangesCount;
    // owner change id => OwnersChange
    mapping(uint256 => OwnersChange) public ownersChanges;
    uint256[] public activeOwnersChangesIds;
    // owner change id => (owner => approved)
    mapping(uint256 => mapping(address => bool)) public ownersChangeApproved;

    uint256 public minConfirmationsChangesCount;
    // min confirmation change id => MinConfirmationsChange
    mapping(uint256 => MinConfirmationsChange) public minConfirmationsChanges;
    uint256[] public activeMinConfirmationsChangesIds;
    // min confirmation change id => (owner => approved)
    mapping(uint256 => mapping(address => bool)) public minConfirmationsChangeApproved;

    event ProposeTransaction(
        address indexed proposer,
        uint256 indexed txId,
        address to,
        uint256 value,
        bytes data,
        uint256 deadline
    );

    event ExecuteTransaction(address indexed executor, uint256 indexed txId);

    event ProposeOwnersChange(
        address indexed proposer,
        uint256 indexed ownersChangeId,
        address ownerChanged,
        bool addToList,
        uint256 deadline
    );

    event ExecuteOwnersChange(address indexed executor, uint256 indexed ownersChangeId);

    event ProposeMinConfirmationsChange(
        address indexed proposer,
        uint256 indexed minConfirmationsChangeId,
        uint256 newValue,
        uint256 deadline
    );

    event ExecuteMinConfirmationsChange(
        address indexed executor,
        uint256 indexed minConfirmationsChangeId
    );

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Governance: Caller is not owner");
        _;
    }

    modifier activeTx(uint256 _txId) {
        Transaction memory transaction = transactions[_txId];
        require(_txId > 0 && transaction.id == _txId, "Governance: Tx does not exist");
        require(!transaction.executed, "Governance: Tx already executed");
        require(!transaction.cancelled, "Governance: Tx cancelled");
        require(transaction.deadline > block.timestamp, "Governance: Tx deadline has passed");
        _;
    }

    modifier activeOwnersChange(uint256 _ownersChangeId) {
        OwnersChange memory ownersChange = ownersChanges[_ownersChangeId];
        require(
            _ownersChangeId > 0 && ownersChange.id == _ownersChangeId,
            "Governance: Owners change does not exist"
        );
        require(!ownersChange.executed, "Governance: Owners change already executed");
        require(!ownersChange.cancelled, "Governance: Owners change cancelled");
        require(
            ownersChange.deadline > block.timestamp,
            "Governance: Owners change deadline has passed"
        );
        _;
    }

    modifier activeMinConfirmationsChange(uint256 _minConfirmationsChangeId) {
        MinConfirmationsChange memory minConfirmationsChange = minConfirmationsChanges[
            _minConfirmationsChangeId
        ];
        require(
            _minConfirmationsChangeId > 0 && minConfirmationsChange.id == _minConfirmationsChangeId,
            "Governance: Min confirmations change does not exist"
        );
        require(
            !minConfirmationsChange.executed,
            "Governance: Min confirmations change already executed"
        );
        require(
            !minConfirmationsChange.cancelled,
            "Governance: Min confirmations change cancelled"
        );
        require(
            minConfirmationsChange.deadline > block.timestamp,
            "Governance: Min confirmations change deadline has passed"
        );
        _;
    }

    modifier maxProposalLimitNotExceeded() {
        _cleanExpiredProposals();
        require(
            ownerActiveProposalsCount[msg.sender] < MAX_ACTIVE_PROPOSALS_PER_OWNER,
            "Governance: Active proposals limit reached"
        );
        _;
    }

    constructor(address[] memory _owners, uint256 _minConfirmationsRequired) {
        require(_owners.length > 0, "Governance: Owners required");
        require(
            _minConfirmationsRequired > 0 && _minConfirmationsRequired <= _owners.length,
            "Governance: Invalid minimum confirmations"
        );

        for (uint256 i; i < _owners.length; ++i) {
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
        for (uint256 i; i < owners.length; ++i) {
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
            for (uint256 i; i < owners.length; ++i) {
                addressBalance[owners[i]] += share;
            }
        }

        uint256 amount = addressBalance[msg.sender];
        require(amount > 0, "Governance: No Reef to be claimed");

        addressBalance[msg.sender] = 0;
        (bool success, ) = msg.sender.call{ value: amount }("");
        require(success, "Governance: Error sending REEF");
    }

    /**
     * Returns array of owners.
     */
    function getOwners() external view returns (address[] memory) {
        return owners;
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
    ) external onlyOwner maxProposalLimitNotExceeded {
        uint256 txId = ++transactionsCount;

        transactions[txId] = Transaction({
            id: txId,
            proposer: msg.sender,
            to: _to,
            value: _value,
            data: _data,
            deadline: block.timestamp + DURATION,
            numConfirmations: 0,
            executed: false,
            cancelled: false
        });

        approveTransaction(txId);

        activeTransactionsIds.push(txId);
        ++ownerActiveProposalsCount[msg.sender];

        emit ProposeTransaction(msg.sender, txId, _to, _value, _data, block.timestamp + DURATION);
    }

    /**
     * Approves a transaction.
     */
    function approveTransaction(uint256 _txId) public onlyOwner activeTx(_txId) {
        require(!txApproved[_txId][msg.sender], "Governance: Tx already approved");
        ++transactions[_txId].numConfirmations;
        txApproved[_txId][msg.sender] = true;
    }

    /**
     * Executes a transaction.
     * It should have the minimum number of confirmations required in order to be executed.
     */
    function executeTransaction(uint256 _txId) public onlyOwner activeTx(_txId) {
        Transaction memory transaction = transactions[_txId];
        require(
            transaction.numConfirmations >= minConfirmationsRequired,
            "Governance: Tx not approved"
        );

        transactions[_txId].executed = true;

        _removeFromActiveTransactionsIds(_txId);

        (bool success, ) = transaction.to.call{ value: transaction.value }(transaction.data);
        require(success, "Governance: tx failed");

        emit ExecuteTransaction(msg.sender, _txId);
    }

    //////////////////////// INTERNAL TX WITH APPROVAL ////////////////////////////////////
    ///////////// Requires a minimum of confirmations to be executed //////////////////////

    /**
     * Creates a proposal for a change in the list of owners.
     *      `_ownerChanged`: address of the owner to be changed
     *      `_addToList`: true --> add new owner / false --> remove existing owner
     */
    function proposeOwnersChange(address _ownerChanged, bool _addToList)
        external
        onlyOwner
        maxProposalLimitNotExceeded
    {
        _addToList
            ? require(!isOwner[_ownerChanged], "Governance: Owner not unique")
            : require(isOwner[_ownerChanged], "Governance: Owner not found");

        uint256 ownersChangeId = ++ownersChangesCount;

        ownersChanges[ownersChangeId] = OwnersChange({
            id: ownersChangeId,
            proposer: msg.sender,
            ownerChanged: _ownerChanged,
            addToList: _addToList,
            deadline: block.timestamp + DURATION,
            numConfirmations: 0,
            executed: false,
            cancelled: false
        });

        approveOwnersChange(ownersChangeId);

        activeOwnersChangesIds.push(ownersChangeId);
        ++ownerActiveProposalsCount[msg.sender];

        emit ProposeOwnersChange(
            msg.sender,
            ownersChangeId,
            _ownerChanged,
            _addToList,
            block.timestamp + DURATION
        );
    }

    /**
     * Approves a change in the owners list.
     */
    function approveOwnersChange(uint256 _ownersChangeId)
        public
        onlyOwner
        activeOwnersChange(_ownersChangeId)
    {
        require(
            !ownersChangeApproved[_ownersChangeId][msg.sender],
            "Governance: Owners change already approved"
        );
        ++ownersChanges[_ownersChangeId].numConfirmations;
        ownersChangeApproved[_ownersChangeId][msg.sender] = true;
    }

    /**
     * Executes a change in the owners list.
     * It should have the minimum number of confirmations required in order to do the change.
     */
    function executeOwnersChange(uint256 _ownersChangeId)
        public
        onlyOwner
        activeOwnersChange(_ownersChangeId)
    {
        OwnersChange memory ownersChange = ownersChanges[_ownersChangeId];

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
            for (uint256 i; i < owners.length; ++i) {
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

        ownersChanges[_ownersChangeId].executed = true;

        _cancelActiveProposals();

        emit ExecuteOwnersChange(msg.sender, _ownersChangeId);
    }

    /**
     * Creates a proposal for a change in the minimum number of confirmations required to execute
     * transactions, changes in owners and changes in minum number of confirmations.
     *      `_newValue`: new value for the minimum number of confirmations required
     */
    function proposeMinConfirmationsChange(uint256 _newValue)
        external
        onlyOwner
        maxProposalLimitNotExceeded
    {
        require(
            _newValue > 0 && _newValue <= owners.length,
            "Governance: Invalid minimum confirmations"
        );

        uint256 minConfirmationsChangeId = ++minConfirmationsChangesCount;

        minConfirmationsChanges[minConfirmationsChangeId] = MinConfirmationsChange({
            id: minConfirmationsChangeId,
            proposer: msg.sender,
            newValue: _newValue,
            deadline: block.timestamp + DURATION,
            numConfirmations: 0,
            executed: false,
            cancelled: false
        });

        approveMinConfirmationsChange(minConfirmationsChangeId);

        activeMinConfirmationsChangesIds.push(minConfirmationsChangeId);
        ++ownerActiveProposalsCount[msg.sender];

        emit ProposeMinConfirmationsChange(
            msg.sender,
            minConfirmationsChangeId,
            _newValue,
            block.timestamp + DURATION
        );
    }

    /**
     * Approves a change in the minimum number of confirmations required.
     */
    function approveMinConfirmationsChange(uint256 _minConfirmationsChangeId)
        public
        onlyOwner
        activeMinConfirmationsChange(_minConfirmationsChangeId)
    {
        require(
            !minConfirmationsChangeApproved[_minConfirmationsChangeId][msg.sender],
            "Governance: Min confirmations change already approved"
        );
        ++minConfirmationsChanges[_minConfirmationsChangeId].numConfirmations;
        minConfirmationsChangeApproved[_minConfirmationsChangeId][msg.sender] = true;
    }

    /**
     * Executes a change in the minimum number of confirmations required.
     * It should have the minimum number of confirmations required in order to be executed.
     */
    function executeMinConfirmationsChange(uint256 _minConfirmationsChangeId)
        public
        onlyOwner
        activeMinConfirmationsChange(_minConfirmationsChangeId)
    {
        MinConfirmationsChange memory minConfirmationsChange = minConfirmationsChanges[
            _minConfirmationsChangeId
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

        minConfirmationsChanges[_minConfirmationsChangeId].executed = true;

        _cancelActiveProposals();

        emit ExecuteMinConfirmationsChange(msg.sender, _minConfirmationsChangeId);
    }

    //////////////////////// PRIVATE FUNCTIONS ////////////////////////////////////
    /**
     * Looks for active proposals and removes them if the deadline has passed.
     */
    function _cleanExpiredProposals() private {
        for (uint256 i = activeTransactionsIds.length; i > 0; --i) {
            Transaction memory transaction = transactions[activeTransactionsIds[i - 1]];
            if (transaction.deadline < block.timestamp) {
                activeTransactionsIds[i - 1] = activeTransactionsIds[
                    activeTransactionsIds.length - 1
                ];
                activeTransactionsIds.pop();
                --ownerActiveProposalsCount[transaction.proposer];
            }
        }

        for (uint256 i = activeOwnersChangesIds.length; i > 0; --i) {
            OwnersChange memory ownersChange = ownersChanges[activeOwnersChangesIds[i - 1]];
            if (ownersChange.deadline < block.timestamp) {
                activeOwnersChangesIds[i - 1] = activeOwnersChangesIds[
                    activeOwnersChangesIds.length - 1
                ];
                activeOwnersChangesIds.pop();
                --ownerActiveProposalsCount[ownersChange.proposer];
            }
        }

        for (uint256 i = activeMinConfirmationsChangesIds.length; i > 0; --i) {
            MinConfirmationsChange storage minConfirmationsChange = minConfirmationsChanges[
                activeMinConfirmationsChangesIds[i - 1]
            ];
            if (minConfirmationsChange.deadline < block.timestamp) {
                activeMinConfirmationsChangesIds[i - 1] = activeMinConfirmationsChangesIds[
                    activeMinConfirmationsChangesIds.length - 1
                ];
                activeMinConfirmationsChangesIds.pop();
                --ownerActiveProposalsCount[minConfirmationsChange.proposer];
            }
        }
    }

    /**
     * Cancels all active proposals after the owners list or the minConfirmationsRequired value
     * have been modified.
     * Existing approvals for those proposals are invalidated.
     */
    function _cancelActiveProposals() private {
        for (uint256 i = activeTransactionsIds.length; i > 0; --i) {
            uint256 txId = activeTransactionsIds[i - 1];
            Transaction memory transaction = transactions[txId];
            if (transaction.deadline > block.timestamp) {
                transactions[txId].cancelled = true;
            }
            activeTransactionsIds.pop();
            --ownerActiveProposalsCount[transaction.proposer];
        }

        for (uint256 i = activeOwnersChangesIds.length; i > 0; --i) {
            uint256 ownerChangeId = activeOwnersChangesIds[i - 1];
            OwnersChange memory ownersChange = ownersChanges[ownerChangeId];
            if (ownersChange.deadline > block.timestamp && !ownersChange.executed) {
                ownersChanges[ownerChangeId].cancelled = true;
            }
            activeOwnersChangesIds.pop();
            --ownerActiveProposalsCount[ownersChange.proposer];
        }

        for (uint256 i = activeMinConfirmationsChangesIds.length; i > 0; --i) {
            uint256 minConfirmationsChangeId = activeMinConfirmationsChangesIds[i - 1];
            MinConfirmationsChange memory minConfirmationsChange = minConfirmationsChanges[
                minConfirmationsChangeId
            ];
            if (
                minConfirmationsChange.deadline > block.timestamp &&
                !minConfirmationsChange.executed
            ) {
                minConfirmationsChanges[minConfirmationsChangeId].cancelled = true;
            }
            activeMinConfirmationsChangesIds.pop();
            --ownerActiveProposalsCount[minConfirmationsChange.proposer];
        }
    }

    /**
     * Removes a transaction id from the activeTransactionsIds array.
     */
    function _removeFromActiveTransactionsIds(uint256 _txId) private {
        for (uint256 i; i < activeTransactionsIds.length; ++i) {
            if (activeTransactionsIds[i] == _txId) {
                activeTransactionsIds[i] = activeTransactionsIds[activeTransactionsIds.length - 1];
                activeTransactionsIds.pop();
                --ownerActiveProposalsCount[transactions[_txId].proposer];
                break;
            }
        }
    }
}
