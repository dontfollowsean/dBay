pragma solidity ^0.4.18;


import "./owned.sol";
import "./FixedSupplyToken.sol";

contract Exchange is owned {

    struct Offer {
        uint amount;
        address buyer;
    }

    struct OrderBook {   
        uint higherPrice;
        uint lowerPrice;

        mapping (uint => Offer) offers;
        
        uint offersKey;
        uint offersLength;
    }

    struct Token {
        
        address tokenContract;

        string symbolName;
        
        
        mapping (uint => OrderBook) buyBook;
        
        uint curBuyPrice;
        uint lowestBuyPrice;
        uint amountBuyPrices;


        mapping (uint => OrderBook) sellBook;
        uint curSellPrice;
        uint highestSellPrice;
        uint amountSellPrices;

    }

    // maximum of 255 tokens can be supported.
    mapping (uint8 => Token) tokens;
    uint8 symbolNameIndex;

    // Balances    
    mapping (address => mapping (uint8 => uint)) tokenBalanceForAddress;
    mapping (address => uint) balanceEthForAddress;

    // Manage Tokens
    function addToken(string symbolName, address erc20TokenAddress) public onlyOwner {
        require(!hasToken(symbolName));
        symbolNameIndex++;
        tokens[symbolNameIndex].tokenContract = erc20TokenAddress;
        tokens[symbolNameIndex].symbolName = symbolName;
        // now will give timestamp of the miner
        TokenAddedToSystem(symbolNameIndex, symbolName, now);
    }

    function getSymbolIndex(string symbolName) internal view  returns (uint8) {
        for (uint8 i = 1; i <= symbolNameIndex; i++) {
            if (stringsEqual(tokens[i].symbolName, symbolName)) {
                return i;
            }
        }
        return 0;
    }

    function getSymbolIndexOrThrow(string symbolName) internal view returns (uint8) {
        uint8 index = getSymbolIndex(symbolName);
        require(index > 0);
        return index;
    }

    function hasToken(string symbolName) public constant returns (bool) {
        uint8 index = getSymbolIndex(symbolName);
        if (index == 0) {
            return false;
        }
        return true;
    }

    // String comparison TODO: put this function in an external contract or library
    function stringsEqual(string storage _a, string memory _b) internal view returns (bool) {
        // compare strings bit by bit
        bytes storage a = bytes(_a);
        bytes memory b = bytes(_b);
        if (a.length != b.length)
            return false;
        // TODO
        for (uint i = 0; i < a.length; i ++) {
            if (a[i] != b[i]) {
                return false;
            }
        }
        return true;
    }

    // Ether Deposits and Withdrawls
    function depositEther() public payable {
        require(balanceEthForAddress[msg.sender] + msg.value >= balanceEthForAddress[msg.sender]);
        balanceEthForAddress[msg.sender] += msg.value;
        DepositForEthReceived(msg.sender, msg.value, now);
    }

    function withdrawEther(uint amountInWei) public {
        require(balanceEthForAddress[msg.sender] - amountInWei >= 0);
        require(balanceEthForAddress[msg.sender] - amountInWei <= balanceEthForAddress[msg.sender]);
        balanceEthForAddress[msg.sender] -= amountInWei;
        msg.sender.transfer(amountInWei);
        WithdrawalEth(msg.sender, amountInWei, now);
    }

    function getEthBalanceInWei() public constant returns (uint) {
        return balanceEthForAddress[msg.sender];
    }

    // Token Deposits and Withdrawls
    function withdrawToken (string symbolName, uint amount)  public {
        uint8 symbolNameIdx = getSymbolIndexOrThrow(symbolName);
        require(tokens[symbolNameIdx].tokenContract != address(0));

        ERC20Interface token = ERC20Interface(tokens[symbolNameIdx].tokenContract);
        require(tokenBalanceForAddress[msg.sender][symbolNameIdx] - amount >= 0);
        require(tokenBalanceForAddress[msg.sender][symbolNameIdx] - amount <= tokenBalanceForAddress[msg.sender][symbolNameIdx]);
        
        tokenBalanceForAddress[msg.sender][symbolNameIdx] -= amount;
        require(token.transfer(msg.sender, amount) == true);
        WithdrawalToken(msg.sender, symbolNameIndex, amount, now);
    }

    function depositToken(string symbolName, uint amount) public {
        uint8 symbolNameIdx = getSymbolIndexOrThrow(symbolName);
        require(tokens[symbolNameIdx].tokenContract != address(0));
        
        ERC20Interface token = ERC20Interface(tokens[symbolNameIdx].tokenContract);
        
        require(token.transferFrom(msg.sender, address(this), amount) == true);
        require(tokenBalanceForAddress[msg.sender][symbolNameIdx] + amount >= tokenBalanceForAddress[msg.sender][symbolNameIdx]); 
        tokenBalanceForAddress[msg.sender][symbolNameIdx] += amount;
        DepositForTokenReceived(msg.sender, symbolNameIndex, amount, now);

    }

    function getBalance(string symbolName) public constant returns (uint) {
        uint8 symbolNameIdx = getSymbolIndexOrThrow(symbolName);
        return tokenBalanceForAddress[msg.sender][symbolNameIdx];
    }

    // New Bid Order
    function buyToken(string symbolName, uint priceInWei, uint amount) public {
        uint8 tokenNameIndex = getSymbolIndexOrThrow(symbolName);
        uint totalEtherNeeded = 0;
        // uint totalEtherAvailable = 0;

        //if we have enough ether, we can buy that:
        totalEtherNeeded = amount*priceInWei;

        //overflow check
        require(totalEtherNeeded >= amount);
        require(totalEtherNeeded >= priceInWei);
        require(balanceEthForAddress[msg.sender] >= totalEtherNeeded);
        require(balanceEthForAddress[msg.sender] - totalEtherNeeded >= 0);

        // first deduct the amount of ether from our balance
        balanceEthForAddress[msg.sender] -= totalEtherNeeded;

        if (tokens[tokenNameIndex].amountSellPrices == 0 || tokens[tokenNameIndex].curSellPrice > priceInWei) {
            // not enough offers to fufill so create limit order
            // add order to the orderBook
            addBuyOffer(tokenNameIndex, priceInWei, amount, msg.sender);
            LimitBuyOrderCreated(tokenNameIndex, msg.sender, amount, priceInWei, tokens[tokenNameIndex].buyBook[priceInWei].offersLength);
        } else {
            // sell price is less than current but price
            revert(); // TODO
        }
    }

    // Bid limit order
    function addBuyOffer(uint8 tokenIndex, uint priceInWei, uint amount, address who) internal {
        tokens[tokenIndex].buyBook[priceInWei].offersLength++;
        tokens[tokenIndex].buyBook[priceInWei].offers[tokens[tokenIndex].buyBook[priceInWei].offersLength] = Offer(amount, who);

        if (tokens[tokenIndex].buyBook[priceInWei].offersLength == 1) {
            tokens[tokenIndex].buyBook[priceInWei].offersKey = 1;
            // new buy order 
            tokens[tokenIndex].amountBuyPrices++;


            // set lowerPrice and higherPrice
            uint curBuyPrice = tokens[tokenIndex].curBuyPrice;

            uint lowestBuyPrice = tokens[tokenIndex].lowestBuyPrice;
            if (lowestBuyPrice == 0 || lowestBuyPrice > priceInWei) {
                if (curBuyPrice == 0) {
                    // insert the first buy order
                    tokens[tokenIndex].curBuyPrice = priceInWei;
                    tokens[tokenIndex].buyBook[priceInWei].higherPrice = priceInWei;
                    tokens[tokenIndex].buyBook[priceInWei].lowerPrice = 0;
                } else {
                    // lowest buy order
                    tokens[tokenIndex].buyBook[lowestBuyPrice].lowerPrice = priceInWei;
                    tokens[tokenIndex].buyBook[priceInWei].higherPrice = lowestBuyPrice;
                    tokens[tokenIndex].buyBook[priceInWei].lowerPrice = 0;
                }
                tokens[tokenIndex].lowestBuyPrice = priceInWei;
            } else if (curBuyPrice < priceInWei) {
                // offer to buy is the highest one
                tokens[tokenIndex].buyBook[curBuyPrice].higherPrice = priceInWei;
                tokens[tokenIndex].buyBook[priceInWei].higherPrice = priceInWei;
                tokens[tokenIndex].buyBook[priceInWei].lowerPrice = curBuyPrice;
                tokens[tokenIndex].curBuyPrice = priceInWei;

            } else {
                // walk linkedlist
                uint buyPrice = tokens[tokenIndex].curBuyPrice;
                bool inPosition = false;
                while (buyPrice > 0 && !inPosition) {
                    if (
                    buyPrice < priceInWei &&
                    tokens[tokenIndex].buyBook[buyPrice].higherPrice > priceInWei
                    ) {
                        // set new order-book entry higher/lowerPrice first right
                        tokens[tokenIndex].buyBook[priceInWei].lowerPrice = buyPrice;
                        tokens[tokenIndex].buyBook[priceInWei].higherPrice = tokens[tokenIndex].buyBook[buyPrice].higherPrice;

                        // set higherPrice order-book entries lowerPrice to current Price
                        tokens[tokenIndex].buyBook[tokens[tokenIndex].buyBook[buyPrice].higherPrice].lowerPrice = priceInWei;
                        // set lowerPrice order-book entries higherPrice to current Price
                        tokens[tokenIndex].buyBook[buyPrice].higherPrice = priceInWei;

                        inPosition = true;
                    }
                    buyPrice = tokens[tokenIndex].buyBook[buyPrice].lowerPrice;
                }
            }
        }
    }

    // New Ask Order
    function sellToken(string symbolName, uint priceInWei, uint amount) public {
        uint8 tokenNameIndex = getSymbolIndexOrThrow(symbolName);
        uint totalEtherNeeded = 0;
        totalEtherNeeded = amount * priceInWei;

        // overflow check
        require(totalEtherNeeded >= amount);
        require(totalEtherNeeded >= priceInWei);
        require(tokenBalanceForAddress[msg.sender][tokenNameIndex] >= amount);
        require(tokenBalanceForAddress[msg.sender][tokenNameIndex] - amount >= 0);
        require(balanceEthForAddress[msg.sender] + totalEtherNeeded >= balanceEthForAddress[msg.sender]);

        tokenBalanceForAddress[msg.sender][tokenNameIndex] -= amount;

        if (tokens[tokenNameIndex].amountBuyPrices == 0 || tokens[tokenNameIndex].curBuyPrice < priceInWei) {
            // not enough offers to fulfill the amount

            // add order to orderBook
            addSellOffer(tokenNameIndex, priceInWei, amount, msg.sender);
            LimitSellOrderCreated(tokenNameIndex, msg.sender, amount, priceInWei, tokens[tokenNameIndex].sellBook[priceInWei].offersLength);

        } else {
            revert(); // TODO
        }
    }



    // Ask limit order
    function addSellOffer(uint8 tokenIndex, uint priceInWei, uint amount, address who) internal {
        tokens[tokenIndex].sellBook[priceInWei].offersLength++;
        tokens[tokenIndex].sellBook[priceInWei].offers[tokens[tokenIndex].sellBook[priceInWei].offersLength] = Offer(amount, who);


        if (tokens[tokenIndex].sellBook[priceInWei].offersLength == 1) {
            tokens[tokenIndex].sellBook[priceInWei].offersKey = 1;
            // increment sell prices counter
            tokens[tokenIndex].amountSellPrices++;
        
            // set lowerPrice and higherPrice 
            uint curSellPrice = tokens[tokenIndex].curSellPrice;

            uint highestSellPrice = tokens[tokenIndex].highestSellPrice;
            if (highestSellPrice == 0 || highestSellPrice < priceInWei) {
                if (curSellPrice == 0) {
                    // add first sell order
                    tokens[tokenIndex].curSellPrice = priceInWei;
                    tokens[tokenIndex].sellBook[priceInWei].higherPrice = 0;
                    tokens[tokenIndex].sellBook[priceInWei].lowerPrice = 0;
                } else {
                    // highest sell order
                    tokens[tokenIndex].sellBook[highestSellPrice].higherPrice = priceInWei;
                    tokens[tokenIndex].sellBook[priceInWei].lowerPrice = highestSellPrice;
                    tokens[tokenIndex].sellBook[priceInWei].higherPrice = 0;
                }

                tokens[tokenIndex].highestSellPrice = priceInWei;

            } else if (curSellPrice > priceInWei) {
                // this offer is the lowest one
                tokens[tokenIndex].sellBook[curSellPrice].lowerPrice = priceInWei;
                tokens[tokenIndex].sellBook[priceInWei].higherPrice = curSellPrice;
                tokens[tokenIndex].sellBook[priceInWei].lowerPrice = 0;
                tokens[tokenIndex].curSellPrice = priceInWei;

            } else {
                // walk linked list
                uint sellPrice = tokens[tokenIndex].curSellPrice;
                bool inPosition = false;
                while (sellPrice > 0 && !inPosition) {
                    if (
                    sellPrice < priceInWei &&
                    tokens[tokenIndex].sellBook[sellPrice].higherPrice > priceInWei
                    ) {
                        // set new orderbook entry higher/lowerPrice first right
                        tokens[tokenIndex].sellBook[priceInWei].lowerPrice = sellPrice;
                        tokens[tokenIndex].sellBook[priceInWei].higherPrice = tokens[tokenIndex].sellBook[sellPrice].higherPrice;

                        // set higherPrice orderbook entries lowerPrice to current price
                        tokens[tokenIndex].sellBook[tokens[tokenIndex].sellBook[sellPrice].higherPrice].lowerPrice = priceInWei;
                        // set lowerPrice order-book entries higherPrice to current price
                        tokens[tokenIndex].sellBook[sellPrice].higherPrice = priceInWei;
                        // correct position
                        inPosition = true;
                    }
                    sellPrice = tokens[tokenIndex].sellBook[sellPrice].higherPrice;
                }
            }
        }
    }

    // Buy order book
    function getBuyOrderBook(string symbolName) public constant returns (uint[], uint[]) {
        uint8 tokenNameIndex = getSymbolIndexOrThrow(symbolName);
        uint[] memory arrPricesBuy = new uint[](tokens[tokenNameIndex].amountBuyPrices);
        uint[] memory arrVolumesBuy = new uint[](tokens[tokenNameIndex].amountBuyPrices);

        uint buyPrice = tokens[tokenNameIndex].lowestBuyPrice;
        uint counter = 0;
        if (tokens[tokenNameIndex].curBuyPrice > 0) {
            while (buyPrice <= tokens[tokenNameIndex].curBuyPrice) {
                arrPricesBuy[counter] = buyPrice;
                uint volumeAtPrice = 0;
                uint offersKey = 0;

                offersKey = tokens[tokenNameIndex].buyBook[buyPrice].offersKey;
                while (offersKey <= tokens[tokenNameIndex].buyBook[buyPrice].offersLength) {
                    volumeAtPrice += tokens[tokenNameIndex].buyBook[buyPrice].offers[offersKey].amount;
                    offersKey++;
                }

                arrVolumesBuy[counter] = volumeAtPrice;

                //next buyPrice
                if (buyPrice == tokens[tokenNameIndex].buyBook[buyPrice].higherPrice) {
                    break;
                } else {
                    buyPrice = tokens[tokenNameIndex].buyBook[buyPrice].higherPrice;
                }
                counter++;

            }
        }

        return (arrPricesBuy, arrVolumesBuy);

    }

    // Sell order book
    function getSellOrderBook(string symbolName) public constant returns (uint[], uint[]) {
        uint8 tokenNameIndex = getSymbolIndexOrThrow(symbolName);        
        uint[] memory arrPricesSell = new uint[](tokens[tokenNameIndex].amountSellPrices);
        uint[] memory arrVolumesSell = new uint[](tokens[tokenNameIndex].amountSellPrices);

        uint sellPrice = tokens[tokenNameIndex].curSellPrice;
        uint counter = 0;
        if (tokens[tokenNameIndex].curSellPrice > 0) {
            while (sellPrice <= tokens[tokenNameIndex].highestSellPrice) {
                arrPricesSell[counter] = sellPrice;
                uint sellVolumeAtPrice = 0;
                uint sellOffersKey = 0;
                sellOffersKey = tokens[tokenNameIndex].sellBook[sellPrice].offersKey;
                    while (sellOffersKey <= tokens[tokenNameIndex].sellBook[sellPrice].offersLength) {
                        sellVolumeAtPrice += tokens[tokenNameIndex].sellBook[sellPrice].offers[sellOffersKey].amount;
                        sellOffersKey++;
                    }

                    arrVolumesSell[counter] = sellVolumeAtPrice;

                    //next whilePrice
                    if (tokens[tokenNameIndex].sellBook[sellPrice].higherPrice == 0) {
                        break;
                    } else {
                        sellPrice = tokens[tokenNameIndex].sellBook[sellPrice].higherPrice;
                    }
                    counter++;
            } 
        }
        return (arrPricesSell, arrVolumesSell);
    }

    // Events
        // Token Management
    event TokenAddedToSystem(uint _symbolIndex, string _token, uint _timestamp);
        // Deposit/withdrawal
    event DepositForTokenReceived(address indexed _from, uint indexed _symbolIndex, uint _amount, uint _timestamp);
    event WithdrawalToken(address indexed _to, uint indexed _symbolIndex, uint _amount, uint _timestamp);
    event DepositForEthReceived(address indexed _from, uint _amount, uint _timestamp);
    event WithdrawalEth(address indexed _to, uint _amount, uint _timestamp);
        // Orders
    event LimitBuyOrderCreated(uint indexed _symbolIndex, address indexed _who, uint _amountTokens, uint _priceInWei, uint _orderKey);
    event LimitSellOrderCreated(uint indexed _symbolIndex, address indexed _who, uint _amountTokens, uint _priceInWei, uint _orderKey);

}