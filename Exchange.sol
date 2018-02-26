pragma solidity ^0.4.18;


import "./owned.sol";
import "./FixedSupplyToken.sol";

contract Exchange is owned {
  struct Offer {
        
        uint amount;
        address who;
    }

    struct OrderBook {
        
        uint higherPrice;
        uint lowerPrice;
        
        mapping (uint => Offer) offers;
        
        uint offers_key;
        uint offers_length;
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

    //Balances    
    mapping (address => mapping (uint8 => uint)) tokenBalanceForAddress;
    mapping (address => uint) balanceEthForAddress;

    
}