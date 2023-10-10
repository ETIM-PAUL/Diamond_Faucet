// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/NFTFacet.sol";

import "./helpers/DiamondUtils.sol";

contract DiamondDeployer is DiamondUtils, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    NFTFacet nftF;

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

        //upgrade diamond with facets

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](3);

        cut[0] = (
            FacetCut({
                facetAddress: address(dLoupe),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            FacetCut({
                facetAddress: address(ownerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("OwnershipFacet")
            })
        );
        cut[2] = (
            FacetCut({
                facetAddress: address(nftF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("NFTFacet")
            })
        );

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();
    }

    function testNameAndSymbol() public {
        string memory name = NFTFacet(address(diamond)).name();
        string memory symbol = NFTFacet(address(diamond)).symbol();

        assertEq(name, "Joe NFT");
        assertEq(symbol, "JOE");
    }

    function testMint() public {
        NFTFacet(address(diamond)).mintNFT(address(this), 1);
        address owner = NFTFacet(address(diamond)).ownerOf(1);
        assertEq(owner, address(this));
    }

    function testBalanceOf() public {
        vm.startPrank(address(0x11));
        NFTFacet(address(diamond)).mintNFT(address(0x11), 1);
        uint bal = NFTFacet(address(diamond)).balanceOf(address(0x11));
        assertGt(bal, 0);
    }

    function testTransferFrom() public {
        vm.startPrank(address(this));
        NFTFacet(address(diamond)).mintNFT(address(this), 1);
        NFTFacet(address(diamond)).approve(address(0x11), 1);
        vm.stopPrank();

        vm.startPrank(address(0x11));
        NFTFacet(address(diamond)).transferFrom(
            address(this),
            address(0x22),
            1
        );
        address owner = NFTFacet(address(diamond)).ownerOf(1);
        assertEq(owner, address(0x22));
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
