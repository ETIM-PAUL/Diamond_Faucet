// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "../interfaces/ERC721.sol";
import {Utils} from "../libraries/marketPlaceUtils.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

contract MarketPlace {
    event NFTSold(uint256 indexed orderId, LibDiamond.Order);

    event NFTListed(uint256 indexed orderId, LibDiamond.Order);

    event NFTOrderEdited(uint indexed orderId, LibDiamond.Order);

    struct Order {
        address owner;
        address tokenAddress;
        uint tokenId;
        uint nftPrice;
        uint deadline;
        bytes signature;
        bool active;
    }

    constructor() {}

    function putNFTForSale(
        address _tokenAddress,
        uint _tokenId,
        uint _price,
        uint _deadline,
        bytes memory _signature
    ) public returns (uint _orderId) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.orderId++;

        LibDiamond.Order storage newOrder = LibDiamond
            .diamondStorage()
            .allOrders[ds.orderId];

        //checks that the seller is the owner of the nft
        require(
            ERC721(_tokenAddress).ownerOf(_tokenId) == msg.sender,
            "Not Owner"
        );

        //checks that the seller has approves the marketplace to sell the nft
        require(
            ERC721(_tokenAddress).getApproved(_tokenId) == address(this),
            "Please approve NFT to be sold"
        );

        //require that price is greater than zero
        require(_price != 0, "Price must be greater than zero");

        //require that deadline is one hour later than present time
        require(
            _deadline > (block.timestamp + 3600),
            "Deadline must be one hour later than present time"
        );

        bytes32 hashedVal = hashedListing(_tokenAddress, _tokenId);

        //checks if the nft has not been listed before
        require(!ds.hashedToken[hashedVal], "token has been listed");

        bool isVerified = Utils.verify(
            msg.sender,
            _tokenAddress,
            _tokenId,
            _price,
            uint256(_deadline),
            _signature
        );
        require(isVerified, "Invalid Signature");

        newOrder.owner = msg.sender;
        newOrder.signature = _signature;
        newOrder.tokenId = _tokenId;
        newOrder.nftPrice = _price;
        newOrder.deadline = _deadline;
        newOrder.tokenAddress = _tokenAddress;
        newOrder.active = true;
        ds.hashedToken[hashedVal] = true;

        _orderId = ds.orderId;

        emit NFTListed(ds.orderId, newOrder);
    }

    function buyNFT(uint _orderId) public payable {
        LibDiamond.Order storage order = LibDiamond.diamondStorage().allOrders[
            _orderId
        ];
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        address owner = order.owner;
        address tokenAddress = order.tokenAddress;
        uint tokenId = order.tokenId;
        uint nftPrice = order.nftPrice;
        uint deadline = order.deadline;
        bool active = order.active;

        require(active, "Listing not active");
        require(deadline < block.timestamp, "Deadline passed");
        require(msg.value == nftPrice, "Incorrect Eth Value");

        bytes32 hashedVal = hashedListing(tokenAddress, tokenId);

        //to avoid re-entrancy attack, we reset the active state to false
        active = false;
        ds.hashedToken[hashedVal] = false;
        (bool callSuccess, ) = owner.call{value: msg.value}("");
        require(callSuccess, "NFT Purchased failed");
        ERC721(tokenAddress).safeTransferFrom(owner, msg.sender, tokenId);

        emit NFTSold(_orderId, order);
    }

    // add getter for listing
    function getOrder(
        uint256 _orderId
    ) public view returns (LibDiamond.Order memory) {
        LibDiamond.Order storage order = LibDiamond.diamondStorage().allOrders[
            _orderId
        ];

        // if (_listingId >= listingId)
        return order;
    }

    function editOrder(
        uint256 _orderId,
        uint256 _newPrice,
        bool _active
    ) public {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        LibDiamond.Order storage _order = LibDiamond.diamondStorage().allOrders[
            _orderId
        ];

        require(_orderId <= ds.orderId, "Order Doesn't Exist");
        require(_order.owner == msg.sender, "Not Owner");
        _order.nftPrice = _newPrice;
        _order.active = _active;
        emit NFTOrderEdited(_orderId, _order);
    }

    //function to hash token listing to avoind duplicate
    function hashedListing(
        address _tokenAddress,
        uint _tokenId
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_tokenAddress, _tokenId));
    }
}
