// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/ERC1155.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract ValireumLicence is ERC1155, Ownable {
    
  string public name;
  string public symbol;

  struct TokenInfo {
      uint price;
      uint maxSupply;
      uint minted;
      string uri;
  }

  mapping(uint => TokenInfo) public tokenData;
  address payable private fundsManager;
  constructor() ERC1155("") {
    name = "ValireumLicence";
    symbol = "VKEY";

    tokenData[0] = TokenInfo(79, 1000, 0, "https://valireum.net/metadata/licences/founder.json");
    tokenData[1] = TokenInfo(49, 5000, 0, "https://valireum.net/metadata/licences/craftmaster.json");
    tokenData[2] = TokenInfo(29, 10000, 0, "https://valireum.net/metadata/licences/exchanger.json");
    tokenData[3] = TokenInfo(79, 10**18, 0, "https://valireum.net/metadata/licences/premium.json");
    tokenData[4] = TokenInfo(49, 10**18, 0, "https://valireum.net/metadata/licences/standard.json");

    fundsManager = payable(msg.sender);
  }

    

    function uri(uint _id) public override view returns (string memory) {
    return tokenData[_id].uri;
    }

    function stock(uint _id) public view returns (uint) {
        return tokenData[_id].maxSupply - tokenData[_id].minted;
    }
    // Public mint
    function mint(uint _id, uint _amount) public payable {
        uint256 total = tokenData[_id].price * _amount;
        require(total > 0, 'Please enter a valid amount');
        require(_id < 5, 'Invalid ID');
        require(total == msg.value, 'Value must be equal the token price');
        require(_amount <= stock(_id), 'Sorry, Sold out');
        _mint(msg.sender, _id, _amount, "");
        fundsManager.transfer(msg.value);
        tokenData[_id].minted += _amount;
    }

    

    // Change Fund manager contract address -- OwnerOnly
    function changeFundManager(address _newOwner) external onlyOwner {
        fundsManager = payable(_newOwner);
    }

    // price change
    function setPrice(uint _id, uint _price) external onlyOwner{
        tokenData[_id].price = _price;
    }

    // Mint item for owner -- OwnerOnly
    function ownerMint(uint _id, uint256 _amount) external onlyOwner {
        require(_amount <= stock(_id), 'Sorry, Sold out');
        _mint(msg.sender, _id, _amount, "");
        tokenData[_id].minted += _amount;
    }

    // set uri
    function setURI(uint _id, string memory _uri) external onlyOwner {
        tokenData[_id].uri = _uri;
        emit URI(_uri, _id);
    }

  

}