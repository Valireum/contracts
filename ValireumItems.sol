// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


interface VUNI is IERC721 {
    function craftItem(address _to, string memory tokenURI) external returns (uint256);
}


contract ValireumItems is ERC1155URIStorage, Ownable {

    string public name;
    string public symbol;
    address factory;
    address uniqueContract;

    uint256 totalSupply;

    using Counters for Counters.Counter;
    Counters.Counter tokenIds;
    
    

    modifier onlyFactory {
      require(msg.sender == factory);
      _;
   }

    struct requirements {
        uint256[] ids;
        uint256[] amounts;
    }

    struct recipData {
        bool unique;
        uint256 target;
        uint256 amount;
        requirements requiredIds;
    }

    
   
    mapping (uint256 => uint256) tokenUnits;
    mapping (uint256 => recipData) recipes;
    


    constructor() ERC1155("") {
        name = "Valireum Items";
        symbol = "VITEM";

        factory = msg.sender;
        _setBaseURI("https://valireum.net/metadata/items/");

    }


    // Item creation

    function createNewItem (string memory _ItemUri) external onlyOwner {
        uint256 tokenID = tokenIds.current();
        _setURI(tokenID, _ItemUri);
        tokenIds.increment();
    }


    // recipe crafting

    function createRecipe (uint256 _source, bool _unique, uint256 _target, uint256 _amount, uint256[] memory _consumablesIds, uint256[] memory _amounts) external onlyOwner {
        recipes[_source] = recipData(_unique, _target, _amount, requirements(_consumablesIds, _amounts));
    }

    function craftRecipe (address _to, uint256 _source) external onlyFactory {
        require(balanceOf(_to, _source) > 0, "You have to own a shard first to use this recipe");
        requirements memory consumable = recipes[_source].requiredIds;
        for (uint i = 0; i < consumable.ids.length; i++) {
            require(balanceOf(_to, consumable.ids[i]) >= consumable.amounts[i], "Balance too low");
        }

        
        _burnBatch(_to, consumable.ids, consumable.amounts);
        setItemsSupply(consumable.ids, consumable.amounts, false);

        if (recipes[_source].unique) {
            VUNI(uniqueContract).craftItem(_to, uri(recipes[_source].target));
        } else {
            _mint(_to, recipes[_source].target, recipes[_source].amount, "");
        }

    }


    // minting

    function mintOne(address _to, uint256 _item, uint256 _amount) external onlyFactory {
        _mint(_to, _item, _amount, "");
        tokenUnits[_item] += _amount;
    }

    function mintOneToMany(address[] memory _to, uint256 _item, uint256 _amount) external onlyFactory {
        for (uint i = 0; i < _to.length; i++) {
            _mint(_to[i], _item, _amount, "");
            tokenUnits[_item] += _amount;
        }
    }


    function mintMany(address _to, uint256[] memory _item, uint256[] memory _amount) external onlyFactory {    
        _mintBatch(_to, _item, _amount, "");
        setItemsSupply(_item, _amount, true);
    }

    function mintManyToMany(address[] memory _to, uint256[] memory _item, uint256[] memory _amount) external onlyFactory {
        for (uint i = 0; i < _to.length; i++) {
            _mintBatch(_to[i], _item, _amount, "");
            setItemsSupply(_item, _amount, true);
        }
    }



    // Public views
    function getItemSupply (uint256 _itemId) public view returns (uint256) {
        
        return tokenUnits[_itemId];
    }



    // Internal

    function setItemsSupply (uint256[] memory _itemId, uint256[] memory _amount, bool _add) internal {
        for (uint i = 0; i < _itemId.length; i++) {
            _add ? tokenUnits[_itemId[i]] += _amount[i] : tokenUnits[_itemId[i]] -= _amount[i];
        }
        
    }


    // set contracts

    function setFactory (address _newFactory) external onlyOwner {
        factory = _newFactory;
    }

    
}