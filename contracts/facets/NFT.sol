// SPDX-License-Identifier: UNLICENSED
pragma solidity >0.8.0;

import "solmate/tokens/ERC721.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

error MintPriceNotPaid();
error MaxSupply();
error NonExistentTokenURI();
error WithdrawTransfer();

contract NFT is ERC721, Ownable {
    using Strings for uint256;

    uint256 public immutable TOTAL_SUPPLY = 10_000;
    uint256 public immutable MINT_PRICE = 0.08 ether;

    constructor() ERC721("JOENFT", "JOENFT") {}

    function mintTo(address recipient) public returns (uint256) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        uint256 newTokenId = ++ds.currentTokenId;
        if (newTokenId > TOTAL_SUPPLY) {
            revert MaxSupply();
        }
        _safeMint(recipient, newTokenId);
        return newTokenId;
    }

    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        if (ownerOf(tokenId) == address(0)) {
            revert NonExistentTokenURI();
        }
        return
            bytes(ds.baseURI).length > 0
                ? string(abi.encodePacked(ds.baseURI, tokenId.toString()))
                : "";
    }

    function withdrawPayments(address payable payee) external onlyOwner {
        uint256 balance = address(this).balance;
        (bool transferTx, ) = payee.call{value: balance}("");
        if (!transferTx) {
            revert WithdrawTransfer();
        }
    }
}
