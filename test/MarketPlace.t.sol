// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../contracts/facets/NFTFacet.sol";
import "../contracts/facets/MarketPlace.sol";
import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/Diamond.sol";
import "./helpers/DiamondUtils.sol";

import "./Helper.sol";

contract TestHelpers is Helpers {
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    NFTFacet nftF;
    MarketPlace private marketF;

    struct Order {
        address owner;
        address tokenAddress;
        uint tokenId;
        uint nftPrice;
        uint deadline;
        bytes signature;
        bool active;
    }

    address accountA;
    address accountB;

    uint256 privKeyA;
    uint256 privKeyB;

    Order newOrder;

    event NFTLISTED(uint orderId);
    event NFTSOLD(uint orderId);

    uint _deadline = block.timestamp + 3601;

    function setUp() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(
            address(this),
            address(dCutFacet),
            "Joe NFT",
            "JOE"
        );
        dLoupe = new DiamondLoupeFacet();
        nftF = new NFTFacet();
        ownerF = new OwnershipFacet();
        marketF = new MarketPlace();

        (accountA, privKeyA) = mkaddr("USERA");
        (accountB, privKeyB) = mkaddr("USERB");

        newOrder = Order({
            owner: accountA,
            tokenAddress: address(nftF),
            tokenId: 1,
            nftPrice: 0.1 ether,
            deadline: 0,
            signature: bytes(""),
            active: false
        });
        nftF.mintNFT(accountA, 1);
    }

    function test_AccountListingOwnsNFT() external {
        switchSigner(accountB);
        vm.expectRevert("Not Owner");
        marketF.putNFTForSale(
            newOrder.tokenAddress,
            newOrder.tokenId,
            newOrder.nftPrice,
            newOrder.deadline,
            newOrder.signature
        );
    }

    function test_IsNFTApproved() external {
        switchSigner(accountA);
        vm.expectRevert("Please approve NFT to be sold");
        marketF.putNFTForSale(
            newOrder.tokenAddress,
            newOrder.tokenId,
            newOrder.nftPrice,
            newOrder.deadline,
            newOrder.signature
        );
    }

    function test_PriceMustBeGreatherThanZero() external {
        switchSigner(accountA);
        nftF.approve(address(marketF), 1);
        vm.expectRevert("Price must be greater than zero");
        newOrder.nftPrice = 0;
        marketF.putNFTForSale(
            newOrder.tokenAddress,
            newOrder.tokenId,
            newOrder.nftPrice,
            newOrder.deadline,
            newOrder.signature
        );
    }

    function test_DeadlineMustBeOneHourAhead() external {
        switchSigner(accountA);
        nftF.approve(address(marketF), 1);
        vm.expectRevert("Deadline must be one hour later than present time");
        newOrder.deadline = block.timestamp + 100;
        marketF.putNFTForSale(
            newOrder.tokenAddress,
            newOrder.tokenId,
            newOrder.nftPrice,
            newOrder.deadline,
            newOrder.signature
        );
    }

    function testFailTokenHasBeenListed() external {
        switchSigner(accountA);
        nftF.approve(address(marketF), 1);
        newOrder.deadline = block.timestamp + 36001;
        marketF.putNFTForSale(
            newOrder.tokenAddress,
            newOrder.tokenId,
            newOrder.nftPrice,
            newOrder.deadline,
            newOrder.signature
        );
        marketF.putNFTForSale(
            newOrder.tokenAddress,
            newOrder.tokenId,
            newOrder.nftPrice,
            newOrder.deadline,
            newOrder.signature
        );
    }

    function testIfSignatureIsInValid() public {
        switchSigner(accountA);
        nftF.approve(address(marketF), 1);
        newOrder.active = true;
        newOrder.deadline = block.timestamp + 36001;
        newOrder.signature = constructSig(
            newOrder.tokenAddress,
            newOrder.tokenId,
            newOrder.nftPrice,
            newOrder.deadline,
            newOrder.owner,
            privKeyB
        );
        vm.expectRevert("Invalid Signature");

        marketF.putNFTForSale(
            newOrder.tokenAddress,
            newOrder.tokenId,
            uint(0.2 ether),
            newOrder.deadline,
            newOrder.signature
        );
    }

    function test_InactiveListing() external {
        switchSigner(accountA);
        newOrder.deadline = block.timestamp + 36001;
        nftF.approve(address(marketF), 1);
        newOrder.signature = constructSig(
            newOrder.tokenAddress,
            newOrder.tokenId,
            newOrder.nftPrice,
            newOrder.deadline,
            newOrder.owner,
            privKeyA
        );
        uint order_id = marketF.putNFTForSale(
            newOrder.tokenAddress,
            newOrder.tokenId,
            newOrder.nftPrice,
            newOrder.deadline,
            newOrder.signature
        );
        marketF.editOrder(order_id, 0.1 ether, false);
        vm.expectRevert("Listing not active");
        marketF.buyNFT{value: 0.1 ether}(1);
    }

    function test_ExpertDeadlinePassed() external {
        switchSigner(accountA);
        newOrder.active = true;
        newOrder.deadline = block.timestamp + 36001;
        nftF.approve(address(marketF), 1);
        newOrder.signature = constructSig(
            newOrder.tokenAddress,
            newOrder.tokenId,
            newOrder.nftPrice,
            newOrder.deadline,
            newOrder.owner,
            privKeyA
        );
        uint order_id = marketF.putNFTForSale(
            newOrder.tokenAddress,
            newOrder.tokenId,
            newOrder.nftPrice,
            newOrder.deadline,
            newOrder.signature
        );
        switchSigner(accountB);
        vm.expectRevert("Deadline passed");
        marketF.buyNFT{value: 0.1 ether}(order_id);
    }

    function test_IncorrectValue() external {
        switchSigner(accountA);
        newOrder.active = true;
        newOrder.deadline = block.timestamp + 120 minutes;
        nftF.approve(address(marketF), 1);
        newOrder.signature = constructSig(
            newOrder.tokenAddress,
            newOrder.tokenId,
            newOrder.nftPrice,
            newOrder.deadline,
            newOrder.owner,
            privKeyA
        );
        uint order_id = marketF.putNFTForSale(
            newOrder.tokenAddress,
            newOrder.tokenId,
            newOrder.nftPrice,
            newOrder.deadline,
            newOrder.signature
        );
        switchSigner(accountB);
        vm.expectRevert("Incorrect Eth Value");
        vm.warp(1641070800);
        marketF.buyNFT{value: 0.2 ether}(order_id);
    }

    function test_BuyNFT() external {
        switchSigner(accountA);
        newOrder.deadline = block.timestamp + 120 minutes;
        newOrder.active = true;
        nftF.approve(address(marketF), 1);
        newOrder.signature = constructSig(
            newOrder.tokenAddress,
            newOrder.tokenId,
            newOrder.nftPrice,
            newOrder.deadline,
            newOrder.owner,
            privKeyA
        );
        uint order_id = marketF.putNFTForSale(
            newOrder.tokenAddress,
            newOrder.tokenId,
            newOrder.nftPrice,
            newOrder.deadline,
            newOrder.signature
        );
        switchSigner(accountB);
        vm.warp(1641070800);
        marketF.buyNFT{value: 0.1 ether}(order_id);
        assertEq(nftF.ownerOf(order_id), accountB);
    }

    function test_TestIfOrderExistBeforeEditing() external {
        switchSigner(accountA);
        vm.expectRevert("Order Doesn't Exist");
        marketF.editOrder(1, 0.1 ether, true);
    }

    function test_TestIfOrderOwnerBeforeEditing() external {
        switchSigner(accountA);
        newOrder.deadline = block.timestamp + 120 minutes;
        nftF.approve(address(marketF), 1);
        newOrder.signature = constructSig(
            newOrder.tokenAddress,
            newOrder.tokenId,
            newOrder.nftPrice,
            newOrder.deadline,
            newOrder.owner,
            privKeyA
        );
        uint order_id = marketF.putNFTForSale(
            newOrder.tokenAddress,
            newOrder.tokenId,
            newOrder.nftPrice,
            newOrder.deadline,
            newOrder.signature
        );
        switchSigner(accountB);
        vm.expectRevert("Not Owner");
        marketF.editOrder(order_id, 0.1 ether, true);
    }

    function testHashedListing() external {
        bytes32 hashed = keccak256(abi.encodePacked(address(nftF), uint(1)));
        bytes32 _hashedListing = marketF.hashedListing(address(nftF), uint(1));
        assertEq(hashed, _hashedListing);
    }
}
