// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

// Interface for ERC721 token
interface IERC721 {
    function transferFrom(
        address _from,
        address _to,
        uint256 _id
    ) external;
}

// Escrow contract
contract Escrow {
    // Addresses of involved parties
    address public nftAddress;
    address payable public seller;
    address public inspector;
    address public lender;

    // Modifier: only buyer can call functions
    modifier onlyBuyer(uint256 _nftID) {
        require(msg.sender == buyer[_nftID], "Only buyer can call this method");
        _;
    }

    // Modifier: only seller can call functions
    modifier onlySeller() {
        require(msg.sender == seller, "Only seller can call this method");
        _;
    }

    // Modifier: only inspector can call functions
    modifier onlyInspector() {
        require(msg.sender == inspector, "Only inspector can call this method");
        _;
    }

    // Mapping to track listing status of each NFT
    mapping(uint256 => bool) public isListed;
    // Mapping to track purchase price of each NFT
    mapping(uint256 => uint256) public purchasePrice;
    // Mapping to track escrow amount of each NFT
    mapping(uint256 => uint256) public escrowAmount;
    // Mapping to track buyer of each NFT
    mapping(uint256 => address) public buyer;
    // Mapping to track inspection status of each NFT
    mapping(uint256 => bool) public inspectionPassed;
    // Mapping to track approval status from involved parties
    mapping(uint256 => mapping(address => bool)) public approval;

    // Constructor to initialize the escrow with addresses
    constructor(
        address _nftAddress,
        address payable _seller,
        address _inspector,
        address _lender
    ) {
        nftAddress = _nftAddress;
        seller = _seller;
        inspector = _inspector;
        lender = _lender;
    }

    // Function to list an NFT for sale
    function list(
        uint256 _nftID,
        address _buyer,
        uint256 _purchasePrice,
        uint256 _escrowAmount
    ) public payable onlySeller {
        // Transfer NFT from seller to this contract
        IERC721(nftAddress).transferFrom(msg.sender, address(this), _nftID);

        // Update listing status, purchase price, escrow amount, and buyer
        isListed[_nftID] = true;
        purchasePrice[_nftID] = _purchasePrice;
        escrowAmount[_nftID] = _escrowAmount;
        buyer[_nftID] = _buyer;
    }

    // Function for buyer to deposit earnest money
    function depositEarnest(uint256 _nftID) public payable onlyBuyer(_nftID) {
        // Require deposited amount to be at least escrow amount
        require(msg.value >= escrowAmount[_nftID]);
    }

    // Function for inspector to update inspection status
    function updateInspectionStatus(uint256 _nftID, bool _passed)
        public
        onlyInspector
    {
        // Update inspection status for the NFT
        inspectionPassed[_nftID] = _passed;
    }

    // Function for any party to approve sale
    function approveSale(uint256 _nftID) public {
        // Mark approval from the caller
        approval[_nftID][msg.sender] = true;
    }

    // Function to finalize sale
    function finalizeSale(uint256 _nftID) public {
        // Require inspection passed and approval from all parties
        require(inspectionPassed[_nftID]);
        require(approval[_nftID][buyer[_nftID]]);
        require(approval[_nftID][seller]);
        require(approval[_nftID][lender]);
        // Require enough funds in escrow
        require(address(this).balance >= purchasePrice[_nftID]);

        // Mark the NFT as not listed
        isListed[_nftID] = false;

        // Transfer funds to seller
        (bool success, ) = payable(seller).call{value: address(this).balance}("");
        require(success);

        // Transfer NFT to buyer
        IERC721(nftAddress).transferFrom(address(this), buyer[_nftID], _nftID);
    }

    // Function to cancel sale
    function cancelSale(uint256 _nftID) public {
        // If inspection failed, refund earnest money to buyer
        if (inspectionPassed[_nftID] == false) {
            payable(buyer[_nftID]).transfer(address(this).balance);
        } 
        // Otherwise, send earnest money to seller
        else {
            payable(seller).transfer(address(this).balance);
        }
    }

    // Fallback function to receive ether
    receive() external payable {}

    // Function to get contract balance
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
