// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library Utils {
    function getOrderHash(
        address _tokenAddress,
        uint _tokenId,
        uint _price,
        uint deadline,
        address _nftOwner
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _tokenAddress,
                    _tokenId,
                    _price,
                    deadline,
                    _nftOwner
                )
            );
    }

    function getEthSignedOrderHash(
        bytes32 _messageHash
    ) public pure returns (bytes32) {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    _messageHash
                )
            );
    }

    function verify(
        address _nftOwner,
        address _tokenAddress,
        uint _tokenId,
        uint _price,
        uint _deadline,
        bytes memory signature
    ) public pure returns (bool) {
        bytes32 messageHash = getOrderHash(
            _tokenAddress,
            _tokenId,
            _price,
            _deadline,
            _nftOwner
        );
        bytes32 ethSignedOrderHash = getEthSignedOrderHash(messageHash);

        return recoverSigner(ethSignedOrderHash, signature) == _nftOwner;
    }

    function recoverSigner(
        bytes32 ethSignedOrderHash,
        bytes memory _signature
    ) public pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(ethSignedOrderHash, v, r, s);
    }

    function splitSignature(
        bytes memory sig
    ) public pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");

        assembly {
            /*
            First 32 bytes stores the length of the signature

            add(sig, 32) = pointer of sig + 32
            effectively, skips first 32 bytes of signature

            mload(p) loads next 32 bytes starting at the memory address p into memory
            */

            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }
    }

    //check if an account is a contract
    function isContract(address _add) internal view returns (bool) {
        return (_add.code.length > 0);
    }
}
