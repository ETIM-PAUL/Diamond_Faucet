// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/JoeTokenFacet.sol";
import "../contracts/Diamond.sol";

import "./helpers/DiamondUtils.sol";

contract DiamondDeployer is DiamondUtils, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    JoeTokenFacet tokenF;

    function setUp() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(
            address(this),
            address(dCutFacet),
            "Joe Tokens",
            "JOE"
        );
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        tokenF = new JoeTokenFacet(18);

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
                facetAddress: address(tokenF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("JoeTokenFacet")
            })
        );

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();
    }

    function testNameAndSymbol() public {
        string memory name = JoeTokenFacet(address(diamond)).name();
        string memory symbol = JoeTokenFacet(address(diamond)).symbol();

        assertEq(name, "Joe Tokens");
        assertEq(symbol, "JOE");
    }

    function testMint() public {
        vm.startPrank(address(this));
        JoeTokenFacet(address(diamond)).mint(address(0x11), 100e18);
        uint bal = JoeTokenFacet(address(diamond)).balanceOf(address(0x11));
        assertEq(bal, 100e18);
    }

    function testTransfer() public {
        vm.startPrank(address(this));
        JoeTokenFacet(address(diamond)).mint(address(this), 100e18);
        JoeTokenFacet(address(diamond)).transfer(address(0x11), 10e18);
        uint bal = JoeTokenFacet(address(diamond)).balanceOf(address(0x11));
        assertEq(bal, 10e18);
    }

    function testTransferFrom() public {
        vm.startPrank(address(this));
        JoeTokenFacet(address(diamond)).mint(address(this), 1000e18);
        JoeTokenFacet(address(diamond)).approve(address(0x11), 100e18);
        vm.stopPrank();

        vm.startPrank(address(0x11));
        JoeTokenFacet(address(diamond)).transferFrom(
            address(this),
            address(0x22),
            10e18
        );
        uint bal = JoeTokenFacet(address(diamond)).balanceOf(address(0x22));
        assertEq(bal, 10e18);

        //check allowance of spender
        uint allowance = JoeTokenFacet(address(diamond)).allowance(
            address(this),
            address(0x11)
        );
        assertEq(allowance, 90e18);
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
