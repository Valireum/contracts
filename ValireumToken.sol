// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";



contract ValireumToken is ERC20, ERC20Burnable {
    
    uint256 public preSalePrice = 0.025 ether; // PreSale Price -- Limited to the first 100 participant
    uint256 public pubSalePrice = 0.035 ether; // Public Sale Price --

    uint256 public SaleSupply = 100000000 ether; // Sales available supply
    uint256 public cap = 500000000 ether; // VLM Maximum supply
        
    bool public preSale = true; // Is presale is active?
    bool public publicSale = false; // Is Public sale is active?
    bool public seedMinting = true; // Is the seed mining is active?

    uint256 saleStart; // timestamp of the deployment of the contract

    address payable factory; // The factory contract address.
    address payable devFunds; // The team wallet address. recieve 25% of the collected funds from the sales
    address payable liquidityFunds; // The liquidity wallet address. recieve 50% of the collected funds from the sales
    address payable marketingFunds; // The marketing wallet address. recieve 25% of the collected funds from the sales

    uint256 _paymentMatches = 300; // How many match payment required for the seeders to get paid
    uint256 _maxPayment = 100; // Seed payment percentage a 100 of 1%
    uint256 oldSeedCount = 198; // number of old VLM holders

    using Counters for Counters.Counter;
    Counters.Counter private _matchPayments; // Track match payments
    Counters.Counter private _seederIds; // Count of sales participants + the VLM holders of the old contract
    Counters.Counter private _Payments; // Count of payments made to the seeders.
    
    struct SeederAccount {
        uint256 totalAmount; // The seeder total balance (Vested)
        uint256 paidAmount; // Paid amount.
        bool paid; // Is the seeder is paid?
    }


    mapping (uint => address) seederList; // List of Seeders addresses
    mapping (address => SeederAccount) seederBalance; // List of the seeders balances

    // Constructor 
    // Params Old VLM contract holders and balances
    constructor(address[] memory _holders, uint256[] memory amounts) ERC20 ("Valireum Token", "VLM") {
        factory = payable(msg.sender); // Set the factory to msg.sender temporary until the factory contract is deployed.
        saleStart = block.timestamp; // We use this timestamp to determine when the end of the sales (30 days after deployment)

        // Add the Old VLM contract to the seeders list and balances
        for (uint i = 0; i < oldSeedCount; i++) {
            _seederIds.increment();
            seederList[_seederIds.current()] = _holders[i];
            seederBalance[_holders[i]].totalAmount = amounts[i] * 10**18;
            //console.log(_holders[i], seederBalance[_holders[i]].totalAmount);
        }

        // Set the Dev/Liquidity/Marketing Addresses
        devFunds = payable(address(0x4504e2eF4916A496F87916429a30148bb3Df35f3));
        liquidityFunds = payable(address(0x75De219411ffD93B107a911DdD6264B622100cd2));
        marketingFunds = payable(address(0x87f731B2f8201a0a219902850013Fc1F4bA55Be8));
    }


    // Allow anyone to buy tokens during the sales period
    // Params amount of tokens in Wei, referral address
    // If the referral address is already in the seeder list, he will receive 5% of the amount.
    function buyToken(uint256 _amount, address _ref) public payable {
        require(_amount >= 10000 ether, "Minimum amount is 10000 VLM");
        // Check if the sales is active.
        require(preSale || publicSale, "Sorry the token sales has ended");
        require(block.timestamp < saleStart + 30 days, "Sorry the token sales has ended");
        // Check if the amount requested is available
        require(_amount <= SaleSupply, "This amount is not available!");
        // Set the price depending on the active stage of the sale
        uint256 buyPrice = preSale? preSalePrice : pubSalePrice;
        // Calculate the payment amount in MATIC
        uint256 totalToPay = _amount / 10**18  * buyPrice;
        //console.log(totalToPay);
        // Check if the payment amount is correct.
        require(msg.value == totalToPay, "Please send the exact amount.");

        // Check if the seeder is buying for the first time before adding the address to the seeders list
        if (seederBalance[msg.sender].totalAmount == 0) {
            _seederIds.increment();
            seederList[_seederIds.current()] = msg.sender;
        } 
        
        // Check if the referral bought VLM before referring others.
        
        if (seederBalance[_ref].totalAmount > 0) {
            uint256 refbonus = _amount * 5 / 100;
            seederBalance[_ref].totalAmount += refbonus;
        }

        // Add the amount to the seeder balance

        seederBalance[msg.sender].totalAmount += _amount;

        // Remove the amount from SaleSupply
        SaleSupply -= _amount;

        // Check if we switch to Public sale
        if (_seederIds.current() >= oldSeedCount + 100) {
            preSale = false;
            publicSale = true;
        }

        // Check if the sales has ended
        if (SaleSupply <= 0) {
            preSale = false;
            publicSale = false;
        }

        // transfer and mint liquidity funds 50% matic / 50% VLM
        liquidityFunds.transfer(msg.value / 2);
        _mint(liquidityFunds, _amount / 2);

        // transfer devfunds 25%
        devFunds.transfer(msg.value / 4);

        // transfer marketing funds 25%
        marketingFunds.transfer(msg.value / 4);
        
    }

    // get sale info view

    function getSaleInfo () public view returns (uint256 price, bool saleLive, string memory activeStage, uint256 available, uint256 SaleProgress){
        price = preSale? preSalePrice : pubSalePrice;
        saleLive = preSale || publicSale;
        activeStage = preSale? "Presale" : "Public Sale";
        available = SaleSupply;
        uint256 sold = 100000000 ether - SaleSupply;
        uint256 preSaleCount = _seederIds.current() - oldSeedCount; // oldSeedCount is the number of old VLM contract holders we added in the constructor.
        SaleProgress = preSale? preSaleCount : sold * 100 / 100000000 ether;
        
        
        return (price, saleLive, activeStage, available, SaleProgress);
    }

    
    //  Check the seeder balance of the sender

    function getVestedBalance() public view returns (uint256) {
        return seederBalance[msg.sender].totalAmount - seederBalance[msg.sender].paidAmount;
    }

    // Mint VLMs for the winners and the servers when a match is over
    // Called only by the factory contract

    function matchMint(address[] memory _addresses, uint256[] memory _amounts) external {
        require(msg.sender == factory, "Transaction not authorized");
        uint256 currentSupply = totalSupply();
        uint256 totalAmount = 0;

        for (uint i = 0; i < _amounts.length; i++) {
            totalAmount += _amounts[i];
        }
        // We check if the we reach cap before minting tokens
        require(currentSupply + totalAmount <= cap, "The amount is too big");

        for (uint i = 0; i < _addresses.length; i++) {
            _mint(_addresses[i], _amounts[i]);
        }
        if (seedMinting) { // Check if the seeders payments didn't reach 100%
            _matchPayments.increment(); // increase the match payments count
            if (_matchPayments.current() >= _paymentMatches) { // Check if we should pay the seeders
                //console.log("Seedpayment");
                _matchPayments.reset(); // Reset the match payments count every 300 payment
                seederPayment(); // We pay the seeders 1% each
                _Payments.increment(); // Keep track of the payments percentage
                if (_Payments.current() >= _maxPayment) { seedMinting = false; }  // If the seeders is fully paid, we disable this block of code above from seedMinting check.
            }
        }
        

    }

    // We pay the seeders 1 % at time, if the balance of a seeder is less than 10000 VLM, we release the whole balance.

    function seederPayment() internal {
        for (uint i = 0; i < _seederIds.current(); i++) {
            address _to = seederList[i+1];
            if (!seederBalance[_to].paid) { // Check if the seeder is not paid
                uint256 currentBalance = seederBalance[_to].totalAmount - seederBalance[_to].paidAmount; // Get balance
                uint256 _amount = seederBalance[_to].totalAmount / _maxPayment; // Update the amount to 1% of the total amount
                if (currentBalance < 10000 ether) { // Check if the balance is less than 10000 VLM
                    _amount = currentBalance; // Update the amount to be minted to the whole balance
                }
                _mint(_to, _amount); // Mint the tokens
                seederBalance[_to].paidAmount += _amount; // add the minted amount to the paid amount
                if (seederBalance[_to].paidAmount >= seederBalance[_to].totalAmount) { // check if the seeder reach 100%
                    seederBalance[_to].paid = true; // The seeder is fully paid
                }
                
            }
        }
        
    }


    // update factory contract address
    function setFactory (address _newFactory) external {
        require(msg.sender == factory, "Transaction not authorized");
        factory = payable(_newFactory);
    }

    

}