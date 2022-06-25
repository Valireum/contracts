// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";


contract ValireumMarketplace is ERC1155Holder {

    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;
    Counters.Counter private _itemSold;
    Counters.Counter private _currencies;

    address factory;
    

    // 1 == ERC721. 2 == ERC1155
    enum template {
        undefined,
        ERC1155,
        ERC721
    }


    mapping (address => template) nftContracts;
    mapping (uint256 => address) currencyContracts;


    struct item {
        uint256 itemId;
        address nftContract;
        uint256 currency;
        uint256 tokenId;
        address payable seller;
        uint256 price;
        uint256 amount;
        template template;
        bool sold;
    }

    
    event marketItemCreated (
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 currency,
        uint256 indexed tokenId,
        address payable seller,
        uint256 price,
        uint256 amount,
        template template,
        bool sold
    );

    event marketItemSold (
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 currency,
        uint256 indexed tokenId,
        address payable seller,
        address payable buyer,
        uint256 price,
        uint256 amount,
        uint256 total,
        template template,
        bool sold
    );



    mapping (uint256 => item) private marketItems;
    


    constructor() {
        factory = msg.sender;
    }

    function createMarketItem (address _nftContract, uint256 _tokenId, uint256 _amount, uint256 _price, uint256 _currency) external {
        require(_price > 0.01 ether, "Price must be at least 0.01");
        
        
        _itemIds.increment();
        uint256 itemId = _itemIds.current();
        uint256 amount = _amount; 
        

        
        
        require(IERC1155(_nftContract).balanceOf(msg.sender, _tokenId) >= amount, "low balance of NFTs");
        require(IERC1155(_nftContract).isApprovedForAll(msg.sender, address(this)), "please approve the marketplace address before creating items");
        

        
        marketItems[itemId] = item(
            itemId,
            _nftContract,
            _currency,
            _tokenId,
            payable(msg.sender),
            _price,
            amount,
            template(2),
            false
        );

        
        transferToken(template(2), _nftContract, msg.sender, address(this), _tokenId, _amount);
        

        emit marketItemCreated (
            itemId,
            _nftContract,
            _currency,
            _tokenId,
            payable(msg.sender),
            _price,
            _amount,
            template(2),
            false
        ); 
    }


    function createMarketSale (uint256 _itemId, uint _amount) public payable {
        uint256 amount = marketItems[_itemId].amount;
        require(amount >= _amount);
        uint256 price = marketItems[_itemId].price;
        uint256 total = price * _amount;
        uint256 tokenId = marketItems[_itemId].tokenId;
        uint256 currency = marketItems[_itemId].currency;
        address payable seller = marketItems[_itemId].seller;
        address nftContract = marketItems[_itemId].nftContract;
         
    
        if (currency < 1) {
            require(msg.value == total, "Please send the correct amount");
            seller.transfer(msg.value);
        } else {
            
            address currencyAddress = currencyContracts[currency];
            require(IERC20(currencyAddress).balanceOf(msg.sender) >= total);
            require(IERC20(currencyAddress).allowance(msg.sender, address(this)) >= total);
            require(IERC20(currencyAddress).transferFrom(msg.sender, seller, total));
            
        }

        transferToken(template(2), nftContract, address(this), msg.sender, tokenId, _amount);


        emit marketItemSold (
            _itemId,
            nftContract,
            currency,
            tokenId,
            payable(seller),
            payable(msg.sender),
            price,
            amount,
            total,
            template(2),
            true
        ); 

        marketItems[_itemId].amount -= amount;
        if (marketItems[_itemId].amount < 1) {
            marketItems[_itemId].sold = true;
            _itemSold.increment();
        } 

    }



    function transferToken (template _template, address _nftContract, address _from, address _to, uint256 _tokenId, uint256 _amount) internal {
        if (_template > template(2)) {
            IERC721(_nftContract).transferFrom(_from, _to, _tokenId);
        } else {
            IERC1155(_nftContract).safeTransferFrom(_from, _to, _tokenId, _amount, "");
        }
    }


    
    function getItems () public view returns (item[] memory) {
        uint256 itemCount = _itemIds.current();
        uint256 currentIndex = 0;
        uint256 unsolItemCount = _itemIds.current() - _itemSold.current();

        item[] memory items = new item[](unsolItemCount);
        for (uint i = 0; i < itemCount; i++) {
            if (!marketItems[i+1].sold) {
                uint currentId = marketItems[i+1].itemId;
                item storage currentItem = marketItems[currentId];
                items[currentIndex] = currentItem;
                currentIndex++;

            }
        }
        return items;
    }

    function seTNftContract (address _newnftContract, uint8 _template) external {
        require(msg.sender == factory);
        nftContracts[_newnftContract] = template(_template);

    }

    function addCurrency (address _newCurrency) external {
        require(msg.sender == factory);
        _currencies.increment();
        currencyContracts[_currencies.current()] = _newCurrency;
        
    }

}