// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract ValireumUnique is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    address marketplace;
    address factory;

    constructor() ERC721("Valireum Unique", "VUNI") {}

    function craftItem(address _to, string memory tokenURI) external returns (uint256) {
        require(msg.sender == factory, "Transaction Not authorized");
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(_to, newItemId);
        _setTokenURI(newItemId, tokenURI);
        setApprovalForAll(marketplace, true);
        return newItemId;
    }

    function setMarketplace (address _new) external onlyOwner {
        marketplace = _new;
    }

    function setFactory (address _new) external onlyOwner {
        factory = _new;
    }

    


}

