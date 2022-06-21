// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ValireumToken is ERC20, ERC20Burnable {
    uint256 public seedPrice = 0.025 ether;
    uint256 public pubPrice = 0.035 ether;
    uint256 public seedSupply = 100000000 ether;
    uint256 _package = 100000 ether;

    bool public preSale = true;
    bool public publicSale = false;
    bool public seedMinting = true;

    address factory;
    uint256 _paymentMatches = 100;

    using Counters for Counters.Counter;
    Counters.Counter private _matchPayments;
    Counters.Counter private _seederIds;
    Counters.Counter private _Payments;
    
    struct SeederAccount {
        uint256 totalAmount;
        uint256 paidAmount;
        bool paid;
    }


    mapping (uint => address) seederList;
    mapping (address => SeederAccount) seederBalance;


    constructor() ERC20 ("Valireum Token", "VLM") {
        factory = msg.sender;
    }

    


    function buySeed(uint256 _amountId, address _ref) public payable {
        require(preSale || publicSale, "Sorry the token sales has ended");
        uint256 total = _package * _amountId;
        require(total <= seedSupply, "Amount not available!");
        uint256 buyPrice = preSale? seedPrice : pubPrice;
        uint256 totalToPay = total / 10**18  * buyPrice;
        require(msg.value == totalToPay, "Please send the correct amount.");

        if (seederBalance[msg.sender].totalAmount == 0) {
            _seederIds.increment();
            seederList[_seederIds.current()] = msg.sender;
        } 
        
        
        seederBalance[msg.sender].totalAmount += total;
        if (seederBalance[_ref].totalAmount > 0) {
            uint256 refbonus = total * 5 / 100;
            seederBalance[_ref].totalAmount += refbonus;
        }
        seedSupply -= total;

        if (_seederIds.current() >= 100) {
            preSale = false;
            publicSale = true;
        }
        
    }

    function getSalePrice () public view returns (uint256){
        return preSale? seedPrice : pubPrice;
    }

    function getSeedBalance(address _address) public view returns (uint256) {
        return seederBalance[_address].totalAmount - seederBalance[_address].paidAmount;
    }

    function matchMint(address[] memory _addresses, uint256[] memory _amounts) external {
        require(msg.sender == factory, "Transaction not authorized");
        for (uint i = 0; i < _addresses.length; i++) {
            _mint(_addresses[i], _amounts[i]);
        }
        if (seedMinting) {
            _matchPayments.increment();
            if (_matchPayments.current() == _paymentMatches) {
                _matchPayments.reset();
                seederPayment();
                _Payments.increment();
                if (_Payments.current() >= 100) { seedMinting = false; }
            }
        }
        

    }

    function seederPayment() internal {
        for (uint i = 0; i < _seederIds.current(); i++) {
            address _to = seederList[i+1];
            if (!seederBalance[_to].paid) {
                uint256 _amount = seederBalance[_to].totalAmount / 100;
                if (_amount < 100) {
                    _amount = seederBalance[_to].totalAmount - seederBalance[_to].paidAmount;
                }
                _mint(_to, _amount);
                seederBalance[_to].paidAmount += _amount;
                
                seederBalance[_to].paid = true;
            }
        }
        
    }


    // update factory contract address
    function setFactory (address _newFactory) external {
        require(msg.sender == factory, "Transaction not authorized");
        factory = _newFactory;
    }


}