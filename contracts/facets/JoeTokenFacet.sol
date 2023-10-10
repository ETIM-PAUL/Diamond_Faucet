// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;
import {LibDiamond} from "../libraries/LibDiamond.sol";

contract JoeTokenFacet {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    uint8 public immutable decimals;
    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(uint8 _decimals) {
        decimals = _decimals;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(
        address spender,
        uint256 amount
    ) public virtual returns (bool) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function name() external view returns (string memory tokenName) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        tokenName = ds.name;
    }

    function balanceOf(address _seeker) external view returns (uint _balance) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        _balance = ds.balanceOf[_seeker];
    }

    function allowance(
        address owner,
        address _seeker
    ) external view returns (uint _allowance) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        _allowance = ds.allowance[owner][_seeker];
    }

    function symbol() external view returns (string memory tokenSymbol) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        tokenSymbol = ds.symbol;
    }

    function totalSupply() external view returns (uint tokenTotalSupply) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        tokenTotalSupply = ds.totalSupply;
    }

    function transfer(
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.balanceOf[msg.sender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            ds.balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        uint256 allowed = ds.allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max)
            ds.allowance[from][msg.sender] = allowed - amount;

        ds.balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            ds.balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return
            block.chainid == INITIAL_CHAIN_ID
                ? INITIAL_DOMAIN_SEPARATOR
                : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes(ds.name)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            ds.balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.balanceOf[from] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            ds.totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }
}
